# -*- coding: utf-8 -*-
# Recompute and diagnose the J3,K5,L9 EQ1 Hopf-born periodic-orbit branch.

if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "../.."))
end

ENV["GKSwstype"] = get(ENV, "GKSwstype", "100")

using CairoMakie
using CSV
using CloudAtlas
using ChannelflowWrapper
using DataFrames
using DifferentialEquations
using LinearAlgebra
using Printf
import BifurcationKit as BK

parse_int_env(name, default) = parse(Int, strip(get(ENV, name, string(default))))
parse_float_env(name, default) = parse(Float64, strip(get(ENV, name, string(default))))

function parse_bool_env(name::AbstractString, default::Bool)
    raw = lowercase(strip(get(ENV, name, default ? "true" : "false")))
    raw in ("1", "true", "t", "yes", "y") && return true
    raw in ("0", "false", "f", "no", "n") && return false
    error("Invalid boolean ENV[$name]='$raw'")
end

function parse_jkl_env(name::AbstractString, default::NTuple{3, Int})
    raw = strip(get(ENV, name, ""))
    isempty(raw) && return default
    parts = split(lowercase(raw), "x")
    length(parts) == 3 || error("Invalid $name='$raw'. Expected JxKxL.")
    return (parse(Int, parts[1]), parse(Int, parts[2]), parse(Int, parts[3]))
end

function load_coeff_vector(path::AbstractString)
    isfile(path) || error("Missing coefficient file: $path")
    vals = Float64[]
    for line in readlines(path)
        s = strip(line)
        isempty(s) && continue
        startswith(s, "#") && continue
        startswith(s, "%") && continue
        for tok in split(s)
            value = tryparse(Float64, tok)
            value === nothing && continue
            push!(vals, value)
        end
    end
    isempty(vals) && error("No numeric coefficients in $path")
    return vals
end

function save_coeff_vector(path::AbstractString, x::AbstractVector)
    mkpath(dirname(path))
    open(path, "w") do io
        for value in x
            @printf(io, "%.17e\n", Float64(value))
        end
    end
end

function append_csv_row(path::AbstractString, header::Vector{String}, values::Vector)
    mkpath(dirname(path))
    needs_header = !isfile(path) || filesize(path) == 0
    open(path, "a") do io
        needs_header && println(io, join(header, ","))
        println(io, join(string.(values), ","))
    end
end

function span_class(I_span::Real, D_span::Real)
    s = min(I_span, D_span)
    s < 0.05 && return "tiny"
    s < 0.10 && return "small"
    s < 0.25 && return "medium"
    return "large"
end

energy(model::ODEModel, x::AbstractVector) = 0.5 * dot(x, model.B * x)

function ode_problem(model::ODEModel, x0::AbstractVector; Re::Real, tspan)
    function rhs!(du, u, p, t)
        du .= model.f(u, p[1])
        return nothing
    end
    return ODEProblem(rhs!, collect(x0), tspan, [Float64(Re)])
end

function orbit_diagnostics(model::ODEModel, Dmat, x0::AbstractVector, Re::Real, T::Real;
                           abstol::Real, reltol::Real, nsamples::Int)
    times = collect(range(0.0, Float64(T); length = nsamples))
    sol = solve(
        ode_problem(model, x0; Re = Re, tspan = (0.0, Float64(T))),
        Tsit5();
        abstol = abstol,
        reltol = reltol,
        saveat = times,
        dense = false,
    )
    sol.retcode == ReturnCode.Success || return nothing
    xs = [collect(Float64, u) for u in sol.u]
    Ivals = [power_input(model, x) for x in xs]
    Dvals = [dissipation_rate(Dmat, x) for x in xs]
    Evals = [energy(model, x) for x in xs]
    closure = norm(xs[end] .- x0)
    return (
        closure = closure,
        relative_closure = closure / max(norm(x0), eps(Float64)),
        I_min = minimum(Ivals),
        I_max = maximum(Ivals),
        I_span = maximum(Ivals) - minimum(Ivals),
        I_mean = sum(Ivals) / length(Ivals),
        D_min = minimum(Dvals),
        D_max = maximum(Dvals),
        D_span = maximum(Dvals) - minimum(Dvals),
        D_mean = sum(Dvals) / length(Dvals),
        E_min = minimum(Evals),
        E_max = maximum(Evals),
        E_span = maximum(Evals) - minimum(Evals),
        E_mean = sum(Evals) / length(Evals),
        t = times,
        I = Ivals,
        D = Dvals,
        E = Evals,
    )
end

function plot_branch_diagnostics(df::DataFrame, outdir::AbstractString, Re_hopf::Real)
    mkpath(outdir)

    fig1 = Figure(size = (900, 620))
    ax1 = Axis(fig1[1, 1], xlabel = "Re", ylabel = "period T", title = "Hopf-born PO branch: period")
    for label in unique(df.direction)
        sub = df[df.direction .== label, :]
        scatterlines!(ax1, sub.Re, sub.period; label = label, markersize = 8)
    end
    vlines!(ax1, [Re_hopf]; color = :red, linestyle = :dash, label = "Hopf")
    axislegend(ax1)
    CairoMakie.save(joinpath(outdir, "po_period_vs_Re.png"), fig1)

    fig2 = Figure(size = (900, 620))
    ax2 = Axis(fig2[1, 1], xlabel = "Re", ylabel = "span", title = "Hopf-born PO branch: diagnostic spans")
    for label in unique(df.direction)
        sub = df[df.direction .== label, :]
        scatterlines!(ax2, sub.Re, sub.I_span; label = "I_span $label", markersize = 8)
        scatterlines!(ax2, sub.Re, sub.D_span; label = "D_span $label", markersize = 8, linestyle = :dash)
    end
    vlines!(ax2, [Re_hopf]; color = :red, linestyle = :dash, label = "Hopf")
    axislegend(ax2)
    CairoMakie.save(joinpath(outdir, "po_spans_vs_Re.png"), fig2)

    fig3 = Figure(size = (900, 620))
    ax3 = Axis(fig3[1, 1], xlabel = "abs(Re - Re_Hopf)", ylabel = "sqrt(I_span^2 + D_span^2)",
               title = "Hopf-born PO amplitude")
    scatter!(ax3, abs.(df.Re .- Re_hopf), sqrt.(df.I_span .^ 2 .+ df.D_span .^ 2);
             color = :black, markersize = 9)
    CairoMakie.save(joinpath(outdir, "po_amplitude_vs_hopf_distance.png"), fig3)
end

function plot_equilibrium_branch(br, hopf_indices, outdir::AbstractString)
    branch_Re = Float64.(br.branch.param)
    branch_I = Float64.(br.branch.x)
    fig = Figure(size = (900, 620))
    ax = Axis(fig[1, 1], xlabel = "Re", ylabel = "power input", title = "EQ1 branch with Hopf point")
    lines!(ax, branch_Re, branch_I; color = :black, linewidth = 2, label = "EQ1")
    for idx in hopf_indices
        sp = br.specialpoint[idx]
        Re_h = Float64(getfield(sp, :param))
        step = clamp(Int(getfield(sp, :step)) + 1, 1, length(branch_I))
        scatter!(ax, [Re_h], [branch_I[step]]; color = :red, marker = :star5, markersize = 18, label = "Hopf")
    end
    axislegend(ax)
    CairoMakie.save(joinpath(outdir, "eq1_branch_with_hopf_diagnostic.png"), fig)
end

function save_id_loops(loop_rows::Vector{NamedTuple}, outdir::AbstractString, basename::AbstractString)
    isempty(loop_rows) && return
    loop_df = DataFrame(loop_rows)
    CSV.write(joinpath(outdir, "$(basename).csv"), loop_df)
    fig = Figure(size = (900, 720))
    ax = Axis(fig[1, 1], xlabel = "I", ylabel = "D", title = "Representative Hopf-born PO I-D loops")
    for label in unique(loop_df.label)
        sub = loop_df[loop_df.label .== label, :]
        lines!(ax, sub.I, sub.D; label = label, linewidth = 2)
    end
    axislegend(ax)
    CairoMakie.save(joinpath(outdir, "$(basename).png"), fig)
end

function select_hopf_index(br, hopf_indices, target_Re::Union{Nothing, Float64})
    isempty(hopf_indices) && error("No Hopf points detected")
    target_Re === nothing && return hopf_indices[1]
    distances = [abs(Float64(getfield(br.specialpoint[idx], :param)) - target_Re) for idx in hopf_indices]
    return hopf_indices[argmin(distances)]
end

function save_po_checkpoint!(z, step::Int, label::String, m::Int, model::ODEModel,
                             state_dir::AbstractString, summary_path::AbstractString)
    x_coll = Float64.(z.u)
    Re_po = Float64(z.p)
    T = Float64(x_coll[end])
    x0 = x_coll[1:m]
    raw_path = joinpath(state_dir, @sprintf("raw_%s_contstep%04d_Re%.8f_T%.8f.asc", label, step, Re_po, T))
    x0_path = joinpath(state_dir, @sprintf("x0_%s_contstep%04d_Re%.8f_T%.8f.asc", label, step, Re_po, T))
    save_coeff_vector(raw_path, x_coll)
    save_coeff_vector(x0_path, x0)
    append_csv_row(
        summary_path,
        ["direction", "continuation_step", "Re", "period", "norm", "shear", "power", "raw_state_path", "x0_state_path"],
        [label, step, Re_po, T, norm(x0), shear(x0, model), power_input(model, x0), raw_path, x0_path],
    )
    return nothing
end

function continue_po_direction(br, hopf_idx, prob_coll, opts_po, δp::Real, label::String, m::Int,
                               model::ODEModel, checkpoint_dir::AbstractString, checkpoint_csv::AbstractString)
    try
        @printf("\nContinuing PO branch direction=%s δp=%+.3f\n", label, δp)
        br_po = BK.continuation(
            br, hopf_idx, opts_po, prob_coll;
            δp = Float64(δp),
            ampfactor = 1.0,
            verbosity = 1,
            plot = false,
            record_from_solution = (x, p; k...) -> begin
                u0 = x[1:m]
                (period = x[end], norm = norm(u0), shear = shear(u0, model), power = power_input(model, u0))
            end,
            finalise_solution = (z, tau, step, contResult; k...) -> begin
                state = get(k, :state, nothing)
                if state === nothing || BK.converged(state)
                    save_po_checkpoint!(z, step, label, m, model, checkpoint_dir, checkpoint_csv)
                end
                return true
            end,
        )
        @printf("  direction=%s steps=%d\n", label, length(br_po.branch))
        return br_po
    catch err
        @printf("  direction=%s failed: %s\n", label, sprint(showerror, err))
        return nothing
    end
end

const HERE = @__DIR__
alpha = parse_float_env("HOPF_ALPHA", 1.0)
gamma = parse_float_env("HOPF_GAMMA", 2.0)
J, K, L = parse_jkl_env("HOPF_JKL", (3, 5, 9))
Re0 = parse_float_env("HOPF_RE0", 300.0)
Re_min = parse_float_env("HOPF_RE_MIN", 100.0)
Re_max = parse_float_env("HOPF_RE_MAX", 700.0)
target_hopf_Re_raw = strip(get(ENV, "HOPF_TARGET_RE", ""))
target_hopf_Re = isempty(target_hopf_Re_raw) ? nothing : parse(Float64, target_hopf_Re_raw)
eq_max_steps = parse_int_env("HOPF_EQ_MAX_STEPS", 800)
po_max_steps = parse_int_env("HOPF_PO_MAX_STEPS", 50)
po_mesh = parse_int_env("HOPF_PO_MESH", 30)
po_order = parse_int_env("HOPF_PO_ORDER", 3)
po_dsmax = parse_float_env("HOPF_PO_DSMAX", 5.0)
eq_nev = parse_int_env("HOPF_EQ_NEV", 8)
diag_samples = parse_int_env("HOPF_DIAG_SAMPLES", 201)
abstol = parse_float_env("HOPF_SOLVER_ABSTOL", 1e-9)
reltol = parse_float_env("HOPF_SOLVER_RELTOL", 1e-9)
run_natural = parse_bool_env("HOPF_RUN_NATURAL", true)
run_lower = parse_bool_env("HOPF_RUN_LOWER", true)
start_state_path = strip(get(ENV, "HOPF_START_STATE", ""))

outdir = abspath(get(ENV, "HOPF_OUT_DIR", joinpath(HERE, "eqb_hopf_outputs_$(J)_$(K)_$(L)", "diagnostics")))
mkpath(outdir)
base_out = dirname(outdir)

sx, sy, sz, tx, tz = halfbox_symmetries()
H = [sx * sy * sz, sz * tx * tz]
@printf("Building model J,K,L=(%d,%d,%d)\n", J, K, L)
model = ODEModel(alpha, gamma, J, K, L, H, normalize = true)
m = length(model)
Dmat = build_dissipation_matrix(model)
@printf("Model dimension m=%d\n", m)

if !isempty(start_state_path)
    xguess = load_coeff_vector(abspath(start_state_path))
    @printf("Using saved EQ seed %s at Re0=%.8f\n", abspath(start_state_path), Re0)
else
    proj_asc = joinpath(base_out, "xeq1_dns_projection_$(J)_$(K)_$(L).asc")
    if isfile(proj_asc)
        xguess = load_coeff_vector(proj_asc)
    else
        dns_file = joinpath(HERE, "EQ1Re300-32x49x40.nc")
        isfile(dns_file) || error("Missing DNS projection source $dns_file")
        x_proj = ChannelflowWrapper.field2coeff(model.ijkl, dns_file, proj_asc; workdir = base_out)
        xguess = size(x_proj, 2) == 1 ? vec(Float64.(x_proj[:, 1])) : vec(Float64.(x_proj))
    end
end
length(xguess) == m || error("Seed length $(length(xguess)) does not match model dimension $m")

hookparams = SearchParams(ftol = 1e-8, xtol = 1e-12, Nnewton = 30, Nhook = 8, verbosity = 0)
xeq, ok = hookstepsolve(x -> model.f(x, Re0), x -> model.Df(x, Re0), xguess, hookparams)
ok || error("EQ hookstep failed at Re=$Re0")
@printf("EQ seed converged: |f|=%.3e |x|=%.6f I=%.6f\n", norm(model.f(xeq, Re0)), norm(xeq), power_input(model, xeq))

fp(x, p) = model.f(x, p[1])
prob = BK.BifurcationProblem(
    fp,
    xeq,
    [Float64(Re0)],
    1;
    record_from_solution = (x, p; k...) -> power_input(model, x),
    plot_solution = (x, p; k...) -> power_input(model, x),
)

newton_opts = BK.NewtonPar(1e-10, 30, false, BK.DefaultLS(), BK.DefaultEig(), false, 1.0, 0.01)
cont_opts = BK.ContinuationPar(
    p_min = Re_min,
    p_max = Re_max,
    n_inversion = 20,
    dsmin = 1e-7,
    dsmax = 2.0,
    max_steps = eq_max_steps,
    newton_options = newton_opts,
    detect_bifurcation = 3,
    nev = eq_nev,
    save_eigenvectors = false,
)

println("Running equilibrium continuation...")
br = BK.continuation(prob, BK.PALC(), cont_opts, bothside = true)
hopf_indices = findall(sp -> Symbol(getfield(sp, :type)) == :hopf, br.specialpoint)
hopf_idx = select_hopf_index(br, hopf_indices, target_hopf_Re)
Re_hopf = Float64(getfield(br.specialpoint[hopf_idx], :param))
@printf("Using Hopf at Re=%.12f specialpoint=%d target=%s\n",
        Re_hopf, hopf_idx, target_hopf_Re === nothing ? "first" : string(target_hopf_Re))
plot_equilibrium_branch(br, hopf_indices, outdir)

prob_coll = BK.PeriodicOrbitOCollProblem(po_mesh, po_order)
newton_po = BK.NewtonPar(1e-8, 40, true, BK.DefaultLS(), BK.DefaultEig(), false, 1.0, 0.01)
opts_po = BK.ContinuationPar(
    p_min = Re_min,
    p_max = Re_max,
    dsmin = 1e-5,
    dsmax = po_dsmax,
    max_steps = po_max_steps,
    newton_options = newton_po,
    save_sol_every_step = 1,
)

branches = Pair{String, Any}[]
po_checkpoint_dir = joinpath(outdir, "restartable_po_branch", "states")
po_checkpoint_csv = joinpath(outdir, "restartable_po_branch", "po_branch_summary_checkpointed.csv")
isfile(po_checkpoint_csv) && rm(po_checkpoint_csv)

if run_natural
    natural = continue_po_direction(br, hopf_idx, prob_coll, opts_po, +0.5, "natural", m, model, po_checkpoint_dir, po_checkpoint_csv)
    natural !== nothing && push!(branches, "natural" => natural)
end
if run_lower
    lower = continue_po_direction(br, hopf_idx, prob_coll, opts_po, -0.5, "lower_Re_attempt", m, model, po_checkpoint_dir, po_checkpoint_csv)
    lower !== nothing && push!(branches, "lower_Re_attempt" => lower)
end

all_rows = NamedTuple[]
loop_rows = NamedTuple[]
state_dir = joinpath(outdir, "states")
mkpath(state_dir)

for (label, br_po) in branches
    n_po = length(br_po.branch)
    for i in 1:n_po
        x_coll = br_po.sol[i].x
        x0 = Float64.(x_coll[1:m])
        T = Float64(x_coll[end])
        Re_po = Float64(br_po.branch.param[i])
        diag = orbit_diagnostics(model, Dmat, x0, Re_po, T; abstol = abstol, reltol = reltol, nsamples = diag_samples)
        diag === nothing && continue
        cls = span_class(diag.I_span, diag.D_span)
        amp = sqrt(diag.I_span^2 + diag.D_span^2)
        save_coeff_vector(joinpath(state_dir, @sprintf("x0_%s_step%03d_Re%.6f_T%.6f.asc", label, i, Re_po, T)), x0)
        push!(all_rows, (
            direction = label,
            step = i,
            Re = Re_po,
            period = T,
            closure = diag.closure,
            relative_closure = diag.relative_closure,
            I_min = diag.I_min,
            I_max = diag.I_max,
            I_span = diag.I_span,
            I_mean = diag.I_mean,
            D_min = diag.D_min,
            D_max = diag.D_max,
            D_span = diag.D_span,
            D_mean = diag.D_mean,
            E_min = diag.E_min,
            E_max = diag.E_max,
            E_span = diag.E_span,
            E_mean = diag.E_mean,
            amplitude_ID = amp,
            distance_from_Hopf = abs(Re_po - Re_hopf),
            span_class = cls,
        ))
    end
end

df = DataFrame(all_rows)
sort!(df, [:direction, :step])
diag_path = joinpath(outdir, "po_branch_diagnostics_J$(J)_K$(K)_L$(L).csv")
CSV.write(diag_path, df)
@printf("Wrote %s\n", diag_path)

if !isempty(df)
    plot_branch_diagnostics(df, outdir, Re_hopf)

    solved = df[(df.closure .< 1e-6) .& (df.I_span .>= 0.05) .& (df.D_span .>= 0.05), :]
    representative = isempty(solved) ? df[argmax(df.amplitude_ID), :] : solved[argmax(solved.amplitude_ID), :]
    rep_path = joinpath(outdir, "representative_po_summary.txt")
    open(rep_path, "w") do io
        for name in names(df)
            println(io, "$name=$(representative[name])")
        end
    end

    rep_indices = unique(vcat(
        [argmin(abs.(df.Re .- Re_hopf))],
        [argmax(df.amplitude_ID)],
        [nrow(df) ÷ 2 > 0 ? nrow(df) ÷ 2 : 1],
        [findfirst((df.direction .== representative.direction) .& (df.step .== representative.step))],
    ))
    for ridx in rep_indices
        row = df[ridx, :]
        state_file = joinpath(state_dir, @sprintf("x0_%s_step%03d_Re%.6f_T%.6f.asc", row.direction, row.step, row.Re, row.period))
        x0 = load_coeff_vector(state_file)
        diag = orbit_diagnostics(model, Dmat, x0, row.Re, row.period; abstol = abstol, reltol = reltol, nsamples = diag_samples)
        diag === nothing && continue
        loop_label = @sprintf("%s step %d Re %.3f", row.direction, row.step, row.Re)
        for k in eachindex(diag.t)
            push!(loop_rows, (label = loop_label, t = diag.t[k], I = diag.I[k], D = diag.D[k], E = diag.E[k]))
        end
    end
    save_id_loops(loop_rows, outdir, "representative_id_loops")
end

println("Diagnostics complete: $outdir")

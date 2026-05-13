# -*- coding: utf-8 -*-
# Refine accepted Gibson ODE periodic-orbit candidates and plot I-D loops.
#
# This consumes the output of `ode_recurrence_search.jl`. It reads accepted
# refinement rows, optionally polishes the saved coefficient vectors with one
# more collocation Newton solve, integrates each ODE orbit over one period, and
# plots its input-dissipation loop against the corresponding Gibson DNS orbit
# using DNS diagnostics from the saved flowfields or `energy.asc`.
#
# Example:
#   CLOUDATLAS_SKIP_ACTIVATE=true \
#   GIBSON_ORBIT_IDS=1 \
#   GIBSON_JKL=2x4x7 \
#   julia --startup-file=no --project=. notebooks/periodic_orbits/gibson/refine_and_plot_ode_orbits.jl
#
# If the DNS overlay is missing, first generate it separately:
#   CLOUDATLAS_SKIP_ACTIVATE=true \
#   GIBSON_ORBIT_IDS=1 \
#   GIBSON_DNS_SNAPSHOTS=61 \
#   julia --startup-file=no --project=. notebooks/periodic_orbits/gibson/generate_gibson_dns_timeseries.jl
#
# By default this also plots the ODE trajectory launched from the projected DNS
# `ubest.nc` for one DNS period. That curve is often the fastest way to tell
# whether the ODE dynamics initially follows the DNS loop or immediately peels
# away to a different small-amplitude object.

if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "..", "..", ".."))
end

using CSV
using CairoMakie
using CloudAtlas
import BifurcationKit as BK
import Channelflow_jll
using ChannelflowWrapper
using DataFrames
using DelimitedFiles
using DifferentialEquations
using LinearAlgebra
using Printf

function parse_bool_env(name::AbstractString, default::Bool)
    raw = lowercase(strip(get(ENV, name, default ? "true" : "false")))
    raw in ("1", "true", "t", "yes", "y") && return true
    raw in ("0", "false", "f", "no", "n") && return false
    error("Invalid boolean ENV[$name]='$raw'")
end

function parse_float_env(name::AbstractString, default::Float64)
    parse(Float64, strip(get(ENV, name, string(default))))
end

function parse_int_env(name::AbstractString, default::Int)
    parse(Int, strip(get(ENV, name, string(default))))
end

function parse_jkl_env(name::AbstractString, default::NTuple{3, Int})
    raw = strip(get(ENV, name, ""))
    isempty(raw) && return default
    parts = split(lowercase(raw), "x")
    length(parts) == 3 || error("Invalid $name='$raw'. Expected JxKxL.")
    return (parse(Int, parts[1]), parse(Int, parts[2]), parse(Int, parts[3]))
end

function parse_orbit_ids_env(name::AbstractString, default::Vector{Int})
    raw = strip(get(ENV, name, ""))
    isempty(raw) && return default
    ids = [parse(Int, strip(x)) for x in split(raw, ",") if !isempty(strip(x))]
    all(id -> 1 <= id <= 4, ids) || error("$name must contain ids in 1:4")
    return unique(ids)
end

function parse_rank_filter(name::AbstractString)
    raw = strip(get(ENV, name, ""))
    isempty(raw) && return nothing
    return Set(parse(Int, strip(x)) for x in split(raw, ",") if !isempty(strip(x)))
end

as_vector(x) = x isa AbstractMatrix ? vec(Float64.(x)) : vec(Float64.(x))

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

function truthy(x)
    x isa Bool && return x
    raw = lowercase(strip(string(x)))
    return raw in ("1", "true", "t", "yes", "y")
end

const HERE = @__DIR__
archive = joinpath(HERE, "orbits-1-4-Re200-2pi1pi.tgz")
isfile(archive) || error("Missing Gibson orbit archive: $archive")

outdir = abspath(get(ENV, "GIBSON_ODE_OUT_DIR", joinpath(HERE, "ode_recurrence_attempt")))
extract_dir = joinpath(outdir, "dns_orbits")
plot_dir = abspath(get(ENV, "GIBSON_PLOT_OUT_DIR", joinpath(outdir, "plots")))
mkpath(extract_dir)
mkpath(plot_dir)

Re = parse_float_env("GIBSON_RE", 200.0)
alpha = parse_float_env("GIBSON_ALPHA", 1.0)
gamma = parse_float_env("GIBSON_GAMMA", 2.0)
J, K, L = parse_jkl_env("GIBSON_JKL", (2, 4, 7))
orbit_ids = parse_orbit_ids_env("GIBSON_ORBIT_IDS", [1])
rank_filter = parse_rank_filter("GIBSON_CANDIDATE_RANKS")

normalize_basis = parse_bool_env("GIBSON_NORMALIZE", true)
project_normalized = parse_bool_env("GIBSON_PROJECT_NRM", normalize_basis)
solver_abstol = parse_float_env("GIBSON_SOLVER_ABSTOL", 1e-10)
solver_reltol = parse_float_env("GIBSON_SOLVER_RELTOL", 1e-10)
plot_dt = parse_float_env("GIBSON_PLOT_DT", 0.25)
max_candidates = parse_int_env("GIBSON_MAX_PLOT_CANDIDATES", 6)
accepted_only = parse_bool_env("GIBSON_ACCEPTED_ONLY", true)
max_closing = parse_float_env("GIBSON_MAX_CLOSING", 1e-3)
include_projected_start = parse_bool_env("GIBSON_INCLUDE_PROJECTED_START", true)
min_refined_i_span = parse_float_env("GIBSON_MIN_REFINED_I_SPAN", 0.0)
min_refined_d_span = parse_float_env("GIBSON_MIN_REFINED_D_SPAN", 0.0)
include_anchored = parse_bool_env("GIBSON_INCLUDE_ANCHORED", false)
anchored_max_closing = parse_float_env("GIBSON_ANCHORED_MAX_CLOSING", 1e-2)
anchored_min_i_span = parse_float_env("GIBSON_ANCHORED_MIN_I_SPAN", 0.0)
anchored_min_d_span = parse_float_env("GIBSON_ANCHORED_MIN_D_SPAN", 0.0)
anchored_max_rows = parse_int_env("GIBSON_ANCHORED_MAX_ROWS", 6)

polish = parse_bool_env("GIBSON_POLISH", false)
polish_ntst = parse_int_env("GIBSON_POLISH_NTST", 30)
polish_degree = parse_int_env("GIBSON_POLISH_DEGREE", 3)
polish_maxiters = parse_int_env("GIBSON_POLISH_MAXITERS", 8)
polish_tol = parse_float_env("GIBSON_POLISH_TOL", 1e-7)
polish_accept_tol = parse_float_env("GIBSON_POLISH_ACCEPT_TOL", max(polish_tol, 1e-6))
polish_verbose = parse_bool_env("GIBSON_POLISH_VERBOSE", true)

include_dns = parse_bool_env("GIBSON_INCLUDE_DNS", true)
generate_dns_series = parse_bool_env("GIBSON_GENERATE_DNS_SERIES", false)
dns_snapshots = parse_int_env("GIBSON_DNS_SNAPSHOTS", 61)
dns_label = strip(get(ENV, "GIBSON_DNS_LABEL", "u"))
dns_dt = parse_float_env("GIBSON_DNS_DT", 0.03125)
dns_np0 = parse_int_env("GIBSON_DNS_NP0", 4)
dns_np1 = parse_int_env("GIBSON_DNS_NP1", 1)
dns_symms = strip(get(ENV, "GIBSON_DNS_SYMMS", ""))

plot_dt > 0 || error("GIBSON_PLOT_DT must be positive")
max_candidates > 0 || error("GIBSON_MAX_PLOT_CANDIDATES must be positive")

@printf("Output directory: %s\n", outdir)
@printf("Plot directory: %s\n", plot_dir)
@printf("ODE model: Re=%.6g alpha=%.6g gamma=%.6g JKL=(%d,%d,%d)\n", Re, alpha, gamma, J, K, L)
@printf("Orbit ids: %s\n", join(orbit_ids, ", "))
@printf("Candidate filters: accepted_only=%s max_closing=%.3e min_refined_I_span=%.3e min_refined_D_span=%.3e max_candidates=%d ranks=%s\n",
        accepted_only, max_closing, max_candidates,
        min_refined_i_span, min_refined_d_span,
        rank_filter === nothing ? "all" : join(sort(collect(rank_filter)), ","))
@printf("Include projected DNS start trajectory: %s\n", include_projected_start)
if include_anchored
    @printf("Include anchored shooting: max_closing=%.3e min_I_span=%.3e min_D_span=%.3e max_rows=%d\n",
            anchored_max_closing, anchored_min_i_span, anchored_min_d_span, anchored_max_rows)
end
if polish
    @printf("Polish: Ntst=%d degree=%d maxiters=%d tol=%.3e accept_tol=%.3e\n",
            polish_ntst, polish_degree, polish_maxiters, polish_tol, polish_accept_tol)
end

function ensure_orbit_archive_extracted(archive::AbstractString, extract_dir::AbstractString)
    needed = [joinpath(extract_dir, "orbit$(id)-Re200-2pi1pi", "ubest.nc") for id in 1:4]
    all(isfile, needed) && return
    mkpath(extract_dir)
    run(`tar -xzf $archive -C $extract_dir`)
end

orbit_dir(id::Int) = joinpath(extract_dir, "orbit$(id)-Re200-2pi1pi")
orbit_ubest(id::Int) = joinpath(orbit_dir(id), "ubest.nc")
orbit_period(id::Int) = parse(Float64, strip(read(joinpath(orbit_dir(id), "Tbest.asc"), String)))
orbit_workdir(id::Int) = joinpath(outdir, "orbit$(id)")
refinement_csv(id::Int) = joinpath(orbit_workdir(id), "ode_recurrence_refinements_J$(J)_K$(K)_L$(L).csv")
anchored_csv() = joinpath(outdir, "anchored_shooting_summary_J$(J)_K$(K)_L$(L).csv")
dns_series_dir(id::Int) = joinpath(orbit_workdir(id), "dns_series")

ensure_orbit_archive_extracted(archive, extract_dir)

sx, sy, sz, tx, tz = halfbox_symmetries()
H = [sx * sy * sz, sz * tx * tz]
model = ODEModel(alpha, gamma, J, K, L, H; normalize = normalize_basis)
m = length(model)
@printf("Model dimension: %d\n", m)

@printf("Building ODE dissipation matrix...\n")
Dmat = build_dissipation_matrix(model)

function ode_problem(model::ODEModel, x0::AbstractVector; Re::Real, tspan)
    function rhs!(du, u, p, t)
        du .= model.f(u, p[1])
        return nothing
    end
    return ODEProblem(rhs!, collect(x0), tspan, [Float64(Re)])
end

function integrate_orbit(model::ODEModel, x0::AbstractVector, T::Real; Re::Real)
    times = collect(0.0:plot_dt:T)
    if times[end] < T
        push!(times, T)
    end
    prob = ode_problem(model, x0; Re = Re, tspan = (0.0, T))
    sol = solve(prob, Tsit5(); abstol = solver_abstol, reltol = solver_reltol, saveat = times)
    sol.retcode == ReturnCode.Success || error("ODE integration failed with retcode $(sol.retcode)")
    return sol
end

function closing_residual(model::ODEModel, x0::AbstractVector, T::Real; Re::Real)
    prob = ode_problem(model, x0; Re = Re, tspan = (0.0, T))
    sol = solve(prob, Tsit5(); abstol = solver_abstol, reltol = solver_reltol, saveat = [T])
    sol.retcode == ReturnCode.Success || return Inf
    return norm(sol.u[end] .- x0)
end

function polish_candidate(model::ODEModel, x0::Vector{Float64}, T::Float64; Re::Real)
    seed_sol = solve(
        ode_problem(model, x0; Re = Re, tspan = (0.0, T)),
        Tsit5();
        abstol = solver_abstol,
        reltol = solver_reltol,
        dense = true,
    )
    seed_sol.retcode == ReturnCode.Success || error("polish seed integration failed: $(seed_sol.retcode)")

    F(x, p) = model.f(x, p[1])
    Jfun(x, p) = model.Df(x, p[1])
    prob_vf = BK.BifurcationProblem(
        F,
        x0,
        [Float64(Re)],
        1;
        J = Jfun,
        record_from_solution = (x, p; k...) -> norm(x),
    )
    coll = BK.PeriodicOrbitOCollProblem(
        polish_ntst,
        polish_degree;
        prob_vf = prob_vf,
        N = length(model),
        ϕ = zeros(length(model) * (1 + polish_degree * polish_ntst)),
        xπ = zeros(length(model) * (1 + polish_degree * polish_ntst)),
        jacobian = BK.FullSparse(),
    )
    ci = BK.generate_solution(coll, t -> seed_sol(t), T)
    BK.updatesection!(coll, ci, [Float64(Re)])

    residual0 = norm(BK.residual(coll, ci, [Float64(Re)]))
    best_u = copy(ci)
    best_residual = residual0
    best_step = 0
    function keep_best_callback(state; kwargs...)
        if state.residual < best_residual
            best_u = copy(state.x)
            best_residual = Float64(state.residual)
            best_step = Int(state.step)
        end
        return !(state.residual <= polish_accept_tol)
    end

    newton_options = BK.NewtonPar(
        tol = max(polish_tol, polish_accept_tol),
        max_iterations = polish_maxiters,
        verbose = polish_verbose,
        linsolver = BK.COPLS(),
        linesearch = true,
    )
    sol = BK.newton(coll, ci, newton_options; callback = keep_best_callback)
    final_residual = norm(BK.residual(coll, sol.u, [Float64(Re)]))
    if final_residual < best_residual
        best_u = copy(sol.u)
        best_residual = Float64(final_residual)
        best_step = Int(sol.itnewton)
    end
    x = collect(Float64, best_u[1:m])
    Tbest = Float64(best_u[end])
    return (
        x = x,
        T = Tbest,
        residual0 = residual0,
        residual_final = final_residual,
        residual_best = best_residual,
        best_step = best_step,
        accepted = best_residual <= polish_accept_tol,
    )
end

function read_candidates(id::Int)
    path = refinement_csv(id)
    isfile(path) || error("Missing refinement CSV for orbit $id: $path")
    df = DataFrame(CSV.File(path))
    required = [:rank, :T_refined, :closing_residual, :coeff_path]
    missing = setdiff(required, Symbol.(names(df)))
    isempty(missing) || error("Missing columns in $path: $(join(missing, ", "))")
    if accepted_only && :accepted in Symbol.(names(df))
        df = df[[truthy(v) for v in df.accepted], :]
    end
    df = df[isfinite.(Float64.(df.T_refined)) .& isfinite.(Float64.(df.closing_residual)), :]
    df = df[Float64.(df.closing_residual) .<= max_closing, :]
    if min_refined_i_span > 0 && :refined_I_span in Symbol.(names(df))
        df = df[isfinite.(Float64.(df.refined_I_span)) .& (Float64.(df.refined_I_span) .>= min_refined_i_span), :]
    end
    if min_refined_d_span > 0 && :refined_D_span in Symbol.(names(df))
        df = df[isfinite.(Float64.(df.refined_D_span)) .& (Float64.(df.refined_D_span) .>= min_refined_d_span), :]
    end
    if rank_filter !== nothing
        df = df[[Int(r) in rank_filter for r in df.rank], :]
    end
    sort!(df, [:closing_residual, :rank])
    n = min(max_candidates, nrow(df))
    return df[1:n, :]
end

function read_anchored_candidates(id::Int)
    path = anchored_csv()
    isfile(path) || return DataFrame()
    df = DataFrame(CSV.File(path))
    isempty(df) && return df
    df = df[df.orbit_id .== id, :]
    isempty(df) && return df
    df = df[isfinite.(Float64.(df.T)) .& isfinite.(Float64.(df.closing_residual)), :]
    df = df[Float64.(df.closing_residual) .<= anchored_max_closing, :]
    df = df[isfinite.(Float64.(df.I_span)) .& (Float64.(df.I_span) .>= anchored_min_i_span), :]
    df = df[isfinite.(Float64.(df.D_span)) .& (Float64.(df.D_span) .>= anchored_min_d_span), :]
    sort!(df, [:closing_residual, :rank, :anchor_weight])
    return df[1:min(anchored_max_rows, nrow(df)), :]
end

function project_orbit_state(model::ODEModel, orbit_id::Int, outdir::AbstractString)
    src = orbit_ubest(orbit_id)
    isfile(src) || error("Missing orbit state: $src")

    workdir = orbit_workdir(orbit_id)
    mkpath(workdir)
    coeff_path = joinpath(workdir, "x0_projected_J$(J)_K$(K)_L$(L).asc")
    if isfile(coeff_path)
        return load_coeff_vector(coeff_path), coeff_path
    end
    kwargs = project_normalized ? (nrm = true,) : NamedTuple()
    raw = ChannelflowWrapper.field2coeff(model.ijkl, src, coeff_path; workdir = workdir, kwargs...)
    return as_vector(raw), coeff_path
end

function flowfield_sort_key(path::AbstractString, label::AbstractString)
    base = basename(path)
    m = match(Regex("^" * label * "([0-9]+(?:\\.[0-9]+)?)\\.nc\$"), base)
    m === nothing && return Inf
    return parse(Float64, m.captures[1])
end

function snapshot_time(path::AbstractString, label::AbstractString)
    t = flowfield_sort_key(path, label)
    return isfinite(t) ? t : nothing
end

function dns_series_files(id::Int; label::AbstractString = dns_label)
    dir = dns_series_dir(id)
    isdir(dir) || return String[]
    files = filter(path -> isfile(path) && startswith(basename(path), label) && endswith(path, ".nc"),
                   joinpath.(Ref(dir), readdir(dir)))
    return sort(files; by = path -> flowfield_sort_key(path, label))
end

function default_symm_file(outdir::AbstractString)
    path = joinpath(outdir, "symm_E_sxyz_sztxz.asc")
    isfile(path) && return path
    open(path, "w") do io
        println(io, "% 2")
        println(io, "1 -1 -1 -1 0.0 0.0")
        println(io, "1 1 1 -1 0.5 0.5")
    end
    return path
end

function ensure_dns_series(id::Int)
    files = dns_series_files(id)
    if length(files) >= max(2, dns_snapshots - 1)
        return files
    end
    generate_dns_series || return String[]

    dir = dns_series_dir(id)
    mkpath(dir)
    symms = isempty(dns_symms) ? default_symm_file(outdir) : abspath(dns_symms)
    isfile(symms) || error("DNS symmetry file not found: $symms")
    T = orbit_period(id)
    dT = T / max(dns_snapshots - 1, 1)
    @printf("  generating DNS series for orbit %d: snapshots=%d T=%.12f dT=%.12f\n",
            id, dns_snapshots, T, dT)
    ChannelflowWrapper.simulateflow(
        orbit_ubest(id);
        np0 = dns_np0,
        np1 = dns_np1,
        R = Re,
        symms = symms,
        T = T,
        dT = dT,
        dt = dns_dt,
        o = dir,
        l = dns_label,
        D = true,
        I = true,
    )
    return dns_series_files(id)
end

function read_dns_energy_table(path::AbstractString)
    isfile(path) || return DataFrame()
    raw = readdlm(path, comments = true, comment_char = '#')
    isempty(raw) && return DataFrame()
    A = raw isa AbstractVector ? reshape(Float64.(raw), :, 1) : Float64.(raw)
    size(A, 2) >= 13 || return DataFrame()
    return DataFrame(
        t = vec(A[:, 1]),
        wallshear = vec(A[:, 10]),
        dissipation = vec(A[:, 13]),
    )
end

function fieldprops_energy_text(path::AbstractString)
    return read(`$(Channelflow_jll.fieldprops()) -e -R $Re $(abspath(path))`, String)
end

function parse_first_metric(text::AbstractString, label::AbstractString)
    for line in split(text, '\n')
        occursin(label, line) || continue
        m = match(r"==\s*([0-9eE+\-.]+)", line)
        m === nothing && continue
        value = tryparse(Float64, m.captures[1])
        value === nothing || return value
    end
    return NaN
end

function dns_snapshot_id(path::AbstractString)
    text = fieldprops_energy_text(path)
    I = parse_first_metric(text, "wallshear(u+U)")
    D = parse_first_metric(text, "dissip (u+U)")
    return I, D
end

function dns_id_rows!(rows::DataFrame, id::Int)
    energy_path = joinpath(dns_series_dir(id), "energy.asc")
    energy = read_dns_energy_table(energy_path)
    if nrow(energy) > 0
        for r in eachrow(energy)
            push!(rows, (
                orbit_id = id,
                source = "DNS",
                rank = 0,
                label = "DNS orbit $id",
                t = Float64(r.t),
                T = Float64(orbit_period(id)),
                I = Float64(r.wallshear + 1.0),
                D = Float64(r.dissipation + 1.0),
            ))
        end
        @printf("  added DNS overlay from energy.asc with %d rows\n", nrow(energy))
        return
    end

    files = ensure_dns_series(id)
    if isempty(files)
        @printf("  DNS overlay skipped for orbit %d: no %s*.nc files in %s\n",
                id, dns_label, dns_series_dir(id))
        return
    end

    T = orbit_period(id)
    n = length(files)
    for (i, field) in enumerate(files)
        parsed_t = snapshot_time(field, dns_label)
        t = parsed_t === nothing ? (n == 1 ? 0.0 : T * (i - 1) / (n - 1)) : Float64(parsed_t)
        I, D = dns_snapshot_id(field)
        push!(rows, (
            orbit_id = id,
            source = "DNS",
            rank = 0,
            label = "DNS orbit $id",
            t = Float64(t),
            T = Float64(T),
            I = Float64(I),
            D = Float64(D),
        ))
    end
    @printf("  added DNS overlay from fieldprops on %d snapshots\n", n)
end

function add_ode_id_rows!(rows::DataFrame, id::Int, rank::Int, label::String, x::Vector{Float64}, T::Float64)
    sol = integrate_orbit(model, x, T; Re = Re)
    for (t, u) in zip(sol.t, sol.u)
        xu = collect(Float64, u)
        push!(rows, (
            orbit_id = id,
            source = "ODE",
            rank = rank,
            label = label,
            t = Float64(t),
            T = Float64(T),
            I = Float64(power_input(model, xu)),
            D = Float64(dissipation_rate(Dmat, xu)),
        ))
    end
end

function print_id_ranges(rows::DataFrame, id::Int)
    suball = rows[rows.orbit_id .== id, :]
    isempty(suball) && return
    for label in unique(String.(suball.label))
        sub = suball[suball.label .== label, :]
        @printf("  I-D range %-18s I=[%.6f, %.6f] ΔI=%.6e  D=[%.6f, %.6f] ΔD=%.6e  n=%d\n",
                label,
                minimum(sub.I), maximum(sub.I), maximum(sub.I) - minimum(sub.I),
                minimum(sub.D), maximum(sub.D), maximum(sub.D) - minimum(sub.D),
                nrow(sub))
    end
end

function plot_id_trajectory(path_base::AbstractString, rows::DataFrame, id::Int)
    fig = Figure(size = (1100, 800))
    ax = Axis(fig[1, 1], xlabel = "I (input/shear)", ylabel = "D (dissipation)",
              title = "Gibson orbit $id: ODE candidates vs DNS projection")

    palette = [:black, :dodgerblue3, :orangered3, :darkgreen, :purple4, :goldenrod3, :gray40, :teal]
    labels = unique(String.(rows.label))
    for (i, label) in enumerate(labels)
        sub = rows[rows.label .== label, :]
        sort!(sub, :t)
        isdns = all(sub.source .== "DNS")
        isstart = all(sub.source .== "ODE projected start")
        isanchored = all(sub.source .== "ODE anchored")
        color = isdns ? :black : (isstart ? :gray35 : palette[1 + mod(i - 1, length(palette))])
        width = isdns ? 3 : (isstart ? 2 : 2)
        style = isdns ? :solid : (isstart ? :dot : (isanchored ? :dashdot : :dash))
        lines!(ax, sub.I, sub.D; color = color, linewidth = width, linestyle = style, label = label)
        scatter!(ax, [first(sub.I)], [first(sub.D)]; color = color, markersize = 8)
        scatter!(ax, [last(sub.I)], [last(sub.D)]; color = color, markersize = 10, marker = :utriangle)
    end

    axislegend(ax, position = :rb)
    png_path = path_base * ".png"
    pdf_path = path_base * ".pdf"
    CairoMakie.save(png_path, fig)
    CairoMakie.save(pdf_path, fig)
    return (png = png_path, pdf = pdf_path)
end

all_rows = DataFrame(
    orbit_id = Int[],
    source = String[],
    rank = Int[],
    label = String[],
    t = Float64[],
    T = Float64[],
    I = Float64[],
    D = Float64[],
)

summary = DataFrame(
    orbit_id = Int[],
    rank = Int[],
    source_coeff_path = String[],
    plotted_coeff_path = String[],
    T = Float64[],
    closing_residual = Float64[],
    polish_residual_best = Float64[],
    polish_accepted = Bool[],
)

for id in orbit_ids
    @printf("\nOrbit %d\n", id)
    candidates = read_candidates(id)
    @printf("  selected %d ODE candidates\n", nrow(candidates))
    if include_dns
        dns_id_rows!(all_rows, id)
    end
    if include_projected_start
        xstart, start_coeffs = project_orbit_state(model, id, outdir)
        Tdns = orbit_period(id)
        add_ode_id_rows!(all_rows, id, -1, "ODE from projected DNS start", xstart, Tdns)
        @printf("  added ODE trajectory from projected DNS start: T=%.12f coeffs=%s\n",
                Tdns, start_coeffs)
    end

    for row in eachrow(candidates)
        rank = Int(row.rank)
        src_path = String(row.coeff_path)
        x = load_coeff_vector(src_path)
        T = Float64(row.T_refined)
        plotted_path = src_path
        polish_best = NaN
        polish_accepted = false

        if polish
            @printf("  polishing rank %d: T=%.12f source=%s\n", rank, T, src_path)
            result = polish_candidate(model, x, T; Re = Re)
            x = result.x
            T = result.T
            polish_best = result.residual_best
            polish_accepted = result.accepted
            plotted_path = joinpath(orbit_workdir(id), "x_recurrence_rank$(rank)_polished_J$(J)_K$(K)_L$(L).asc")
            CloudAtlas.save(x, plotted_path)
            @printf("    polished: T=%.12f residual_best=%.6e accepted=%s coeffs=%s\n",
                    T, polish_best, polish_accepted, plotted_path)
        end

        closing = closing_residual(model, x, T; Re = Re)
        label = "ODE rank $rank"
        add_ode_id_rows!(all_rows, id, rank, label, x, T)
        push!(summary, (
            orbit_id = id,
            rank = rank,
            source_coeff_path = src_path,
            plotted_coeff_path = plotted_path,
            T = T,
            closing_residual = closing,
            polish_residual_best = polish_best,
            polish_accepted = polish_accepted,
        ))
        @printf("  rank %d plotted: T=%.12f closing=%.6e\n", rank, T, closing)
    end

    if include_anchored
        anchored = read_anchored_candidates(id)
        @printf("  selected %d anchored shooting candidates\n", nrow(anchored))
        for row in eachrow(anchored)
            rank = Int(row.rank)
            weight = Float64(row.anchor_weight)
            x = load_coeff_vector(String(row.coeff_path))
            T = Float64(row.T)
            label = "anchored r$(rank) w=$(weight)"
            add_ode_id_rows!(all_rows, id, rank, label, x, T)
            @printf("  anchored rank %d weight %.3e plotted: T=%.12f closing=%.6e I_span=%.6e D_span=%.6e\n",
                    rank, weight, T, Float64(row.closing_residual), Float64(row.I_span), Float64(row.D_span))
        end
    end

    sub = all_rows[all_rows.orbit_id .== id, :]
    if nrow(sub) > 0
        print_id_ranges(all_rows, id)
        base = joinpath(plot_dir, "gibson_orbit$(id)_id_J$(J)_K$(K)_L$(L)")
        paths = plot_id_trajectory(base, sub, id)
        @printf("  wrote plot: %s\n", paths.png)
    end
end

traj_csv = joinpath(plot_dir, "gibson_id_trajectories_J$(J)_K$(K)_L$(L).csv")
summary_csv = joinpath(plot_dir, "gibson_id_orbit_summary_J$(J)_K$(K)_L$(L).csv")
CSV.write(traj_csv, all_rows)
CSV.write(summary_csv, summary)

@printf("\nWrote trajectory CSV: %s\n", traj_csv)
@printf("Wrote summary CSV: %s\n", summary_csv)

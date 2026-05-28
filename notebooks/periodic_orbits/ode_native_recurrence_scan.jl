# -*- coding: utf-8 -*-
# ODE-native recurrence scan for CloudAtlas coherent structures.

if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "..", ".."))
end

using CairoMakie
using CSV
using CloudAtlas
using DataFrames
using DifferentialEquations
using LinearAlgebra
using Printf
using Random

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

function ode_problem(model::ODEModel, x0::AbstractVector; Re::Real, tspan)
    function rhs!(du, u, p, t)
        du .= model.f(u, p[1])
        return nothing
    end
    return ODEProblem(rhs!, collect(x0), tspan, [Float64(Re)])
end

function integrate_trajectory(model::ODEModel, x0::AbstractVector, T_final::Real, save_dt::Real; Re::Real, abstol::Real, reltol::Real)
    times = collect(0.0:save_dt:T_final)
    times[end] < T_final && push!(times, T_final)
    sol = solve(
        ode_problem(model, x0; Re = Re, tspan = (0.0, T_final)),
        Tsit5();
        abstol = abstol,
        reltol = reltol,
        saveat = times,
        dense = false,
    )
    sol.retcode == ReturnCode.Success || error("trajectory integration failed: $(sol.retcode)")
    return sol
end

function integrate_endpoint(model::ODEModel, x0::AbstractVector, T::Real; Re::Real, abstol::Real, reltol::Real)
    sol = solve(
        ode_problem(model, x0; Re = Re, tspan = (0.0, T)),
        Tsit5();
        abstol = abstol,
        reltol = reltol,
        saveat = [T],
        dense = false,
    )
    sol.retcode == ReturnCode.Success || return nothing
    return collect(Float64, sol.u[end])
end

function segment_stats_from_integration(model::ODEModel, Dmat, x0::AbstractVector, T::Real; Re::Real, abstol::Real, reltol::Real)
    times = collect(range(0.0, T; length = 121))
    sol = solve(
        ode_problem(model, x0; Re = Re, tspan = (0.0, T)),
        Tsit5();
        abstol = abstol,
        reltol = reltol,
        saveat = times,
        dense = false,
    )
    sol.retcode == ReturnCode.Success || return nothing
    Ivals = Float64[]
    Dvals = Float64[]
    for u in sol.u
        x = collect(Float64, u)
        push!(Ivals, power_input(model, x))
        push!(Dvals, dissipation_rate(Dmat, x))
    end
    return (
        I_min = minimum(Ivals),
        I_max = maximum(Ivals),
        I_mean = sum(Ivals) / length(Ivals),
        I_span = maximum(Ivals) - minimum(Ivals),
        D_min = minimum(Dvals),
        D_max = maximum(Dvals),
        D_mean = sum(Dvals) / length(Dvals),
        D_span = maximum(Dvals) - minimum(Dvals),
    )
end

function refine_T(model::ODEModel, x0::AbstractVector, T_center::Float64, halfwidth::Float64; Re::Real, abstol::Real, reltol::Real, iterations::Int)
    a = max(1e-6, T_center - halfwidth)
    b = T_center + halfwidth
    ϕ = (sqrt(5.0) - 1.0) / 2.0
    evalT(T) = begin
        xend = integrate_endpoint(model, x0, T; Re = Re, abstol = abstol, reltol = reltol)
        xend === nothing ? Inf : norm(xend .- x0)
    end
    c = b - ϕ * (b - a)
    d = a + ϕ * (b - a)
    fc, fd = evalT(c), evalT(d)
    for _ in 1:iterations
        if fc < fd
            b, d, fd = d, c, fc
            c = b - ϕ * (b - a)
            fc = evalT(c)
        else
            a, c, fc = c, d, fd
            d = a + ϕ * (b - a)
            fd = evalT(d)
        end
    end
    return fc < fd ? (T = c, closure = fc) : (T = d, closure = fd)
end

function span_class(I_span::Real, D_span::Real)
    s = min(I_span, D_span)
    s < 0.05 && return "tiny"
    s < 0.10 && return "small"
    s < 0.25 && return "medium"
    return "large"
end

function pareto_frontier(df::DataFrame)
    isempty(df) && return copy(df)
    tmp = copy(df)
    tmp.min_span = min.(tmp.I_span, tmp.D_span)
    sort!(tmp, [:min_span, :closure], rev = [true, false])
    keep = Bool[]
    best = Inf
    for row in eachrow(tmp)
        if row.closure < best
            push!(keep, true)
            best = row.closure
        else
            push!(keep, false)
        end
    end
    out = tmp[keep, :]
    sort!(out, :min_span)
    return out
end

function recurrence_candidates_from_solution(model::ODEModel, Dmat, sol, seed_label::String, seed_kind::String;
                                             Re::Real, abstol::Real, reltol::Real, t_min::Real, t_max::Real,
                                             max_per_seed::Int, refine_iters::Int, refine_halfwidth::Real)
    times = Float64.(sol.t)
    states = [collect(Float64, u) for u in sol.u]
    shears = [power_input(model, x) for x in states]
    dissipations = [dissipation_rate(Dmat, x) for x in states]
    candidates = NamedTuple[]

    for i in 1:length(times)-1
        j0 = searchsortedfirst(times, times[i] + t_min)
        j1 = searchsortedlast(times, times[i] + t_max)
        j0 <= j1 || continue
        xi = states[i]
        denom = max(norm(xi), eps(Float64))
        for j in j0:j1
            T = times[j] - times[i]
            raw_closure = norm(states[j] .- xi)
            rel = raw_closure / denom
            Iview = @view shears[i:j]
            Dview = @view dissipations[i:j]
            push!(candidates, (
                seed_label = seed_label,
                seed_kind = seed_kind,
                phase_index = i,
                phase_time = times[i],
                coarse_T = T,
                coarse_closure = raw_closure,
                relative_closure = rel,
                coarse_I_span = maximum(Iview) - minimum(Iview),
                coarse_D_span = maximum(Dview) - minimum(Dview),
                x0 = xi,
            ))
        end
    end

    sort!(candidates; by = c -> (c.relative_closure, c.coarse_closure))
    selected = NamedTuple[]
    for c in candidates
        separated = all(s -> abs(c.phase_time - s.phase_time) > 3.0 || abs(c.coarse_T - s.coarse_T) > 3.0, selected)
        separated || continue
        push!(selected, c)
        length(selected) >= max_per_seed && break
    end

    rows = NamedTuple[]
    for (rank, c) in enumerate(selected)
        refined = refine_T(model, c.x0, c.coarse_T, refine_halfwidth; Re = Re, abstol = abstol, reltol = reltol, iterations = refine_iters)
        stats = segment_stats_from_integration(model, Dmat, c.x0, refined.T; Re = Re, abstol = abstol, reltol = reltol)
        stats === nothing && continue
        push!(rows, (
            seed_label = c.seed_label,
            seed_kind = c.seed_kind,
            rank_within_seed = rank,
            phase_index = c.phase_index,
            phase_time = c.phase_time,
            best_T = refined.T,
            closure = refined.closure,
            relative_closure = refined.closure / max(norm(c.x0), eps(Float64)),
            I_span = stats.I_span,
            D_span = stats.D_span,
            I_mean = stats.I_mean,
            D_mean = stats.D_mean,
            I_min = stats.I_min,
            I_max = stats.I_max,
            D_min = stats.D_min,
            D_max = stats.D_max,
            span_class = span_class(stats.I_span, stats.D_span),
        ))
    end
    return rows
end

function plot_best_by_class(df::DataFrame, outdir::AbstractString)
    isempty(df) && return
    mkpath(outdir)
    classes = ["tiny", "small", "medium", "large"]
    fig = Figure(size = (1000, 760))
    ax = Axis(fig[1, 1], xlabel = "I", ylabel = "D", title = "ODE-native recurrence candidates: closure vs span classes")
    colors = Dict("tiny" => :gray45, "small" => :goldenrod3, "medium" => :dodgerblue3, "large" => :orangered3)
    for cls in classes
        sub = df[df.span_class .== cls, :]
        isempty(sub) && continue
        scatter!(ax, sub.I_span, sub.closure; color = colors[cls], label = cls, markersize = 10)
    end
    axislegend(ax, position = :rt)
    CairoMakie.save(joinpath(outdir, "closure_vs_Ispan_by_class.png"), fig)

    fig2 = Figure(size = (1000, 760))
    ax2 = Axis(fig2[1, 1], xlabel = "min(I_span,D_span)", ylabel = "closure", title = "ODE-native recurrence Pareto view")
    minspan = min.(df.I_span, df.D_span)
    scatter!(ax2, minspan, df.closure; color = :black, markersize = 8)
    CairoMakie.save(joinpath(outdir, "closure_vs_minspan.png"), fig2)
end

const HERE = @__DIR__
outdir = abspath(get(ENV, "ODE_NATIVE_OUT_DIR", joinpath(HERE, "ode_native_recurrence")))
mkpath(outdir)

Re = parse_float_env("ODE_NATIVE_RE", 200.0)
alpha = parse_float_env("ODE_NATIVE_ALPHA", 1.0)
gamma = parse_float_env("ODE_NATIVE_GAMMA", 2.0)
J, K, L = parse_jkl_env("ODE_NATIVE_JKL", (2, 4, 7))
normalize_basis = parse_bool_env("ODE_NATIVE_NORMALIZE", true)
abstol = parse_float_env("ODE_NATIVE_SOLVER_ABSTOL", 1e-8)
reltol = parse_float_env("ODE_NATIVE_SOLVER_RELTOL", 1e-8)
T_final = parse_float_env("ODE_NATIVE_T_FINAL", 240.0)
save_dt = parse_float_env("ODE_NATIVE_SAVE_DT", 1.0)
t_min = parse_float_env("ODE_NATIVE_T_MIN", 20.0)
t_max = parse_float_env("ODE_NATIVE_T_MAX", 100.0)
max_per_seed = parse_int_env("ODE_NATIVE_MAX_PER_SEED", 8)
refine_iters = parse_int_env("ODE_NATIVE_REFINE_ITERS", 5)
refine_halfwidth = parse_float_env("ODE_NATIVE_REFINE_HALFWIDTH", save_dt)
random_count = parse_int_env("ODE_NATIVE_RANDOM_COUNT", 2)
random_amp = parse_float_env("ODE_NATIVE_RANDOM_AMP", 0.05)

sx, sy, sz, tx, tz = halfbox_symmetries()
H = [sx * sy * sz, sz * tx * tz]
@printf("Building model J,K,L=(%d,%d,%d)\n", J, K, L)
model = ODEModel(alpha, gamma, J, K, L, H; normalize = normalize_basis, tw = false)
@printf("Model dimension: %d\n", length(model))
Dmat = build_dissipation_matrix(model)

gibson_out = joinpath(HERE, "gibson", "ode_recurrence_attempt")
seed_specs = [
    (label = "projected_gibson_orbit1", kind = "projected_dns", path = joinpath(gibson_out, "orbit1", "x0_projected_J$(J)_K$(K)_L$(L).asc")),
    (label = "guarded_large_loop", kind = "large_loop_candidate", path = joinpath(gibson_out, "orbit1", "x_guarded_direct_w1p0_J$(J)_K$(K)_L$(L).asc")),
    (label = "ms_large_loop_T57", kind = "large_loop_candidate", path = joinpath(gibson_out, "multiple_shooting_continuation", "x_ms_guarded_w1p0_N8_T57p581175_J$(J)_K$(K)_L$(L).asc")),
    (label = "near_equilibrium_direct", kind = "near_equilibrium", path = joinpath(gibson_out, "orbit1", "x_hookstep_po_direct_J$(J)_K$(K)_L$(L).asc")),
]

seeds = NamedTuple[]
for spec in seed_specs
    if isfile(spec.path)
        x = load_coeff_vector(spec.path)
        length(x) == length(model) && push!(seeds, (label = spec.label, kind = spec.kind, x = x))
    end
end

Random.seed!(20260514)
for n in 1:random_count
    push!(seeds, (label = "random_symmetry_$n", kind = "random", x = random_amp .* randn(length(model))))
end

@printf("Scanning %d seeds, T_final=%.3f save_dt=%.3f recurrence window=[%.3f, %.3f]\n",
        length(seeds), T_final, save_dt, t_min, t_max)

all_rows = NamedTuple[]
for seed in seeds
    @printf("\nSeed %s (%s), norm=%.6e\n", seed.label, seed.kind, norm(seed.x))
    sol = integrate_trajectory(model, seed.x, T_final, save_dt; Re = Re, abstol = abstol, reltol = reltol)
    rows = recurrence_candidates_from_solution(
        model,
        Dmat,
        sol,
        seed.label,
        seed.kind;
        Re = Re,
        abstol = abstol,
        reltol = reltol,
        t_min = t_min,
        t_max = t_max,
        max_per_seed = max_per_seed,
        refine_iters = refine_iters,
        refine_halfwidth = refine_halfwidth,
    )
    append!(all_rows, rows)
    !isempty(rows) && @printf("  best: T=%.6f closure=%.6e Ispan=%.6e Dspan=%.6e class=%s\n",
                              rows[1].best_T, rows[1].closure, rows[1].I_span, rows[1].D_span, rows[1].span_class)
end

df = DataFrame(all_rows)
sort!(df, :closure)
candidate_path = joinpath(outdir, "ode_native_recurrence_candidates_J$(J)_K$(K)_L$(L).csv")
CSV.write(candidate_path, df)

front = pareto_frontier(df)
front_path = joinpath(outdir, "ode_native_recurrence_pareto_J$(J)_K$(K)_L$(L).csv")
CSV.write(front_path, front)
plot_best_by_class(df, outdir)

@printf("\nWrote %s\nWrote %s\n", candidate_path, front_path)
if !isempty(df)
    for cls in ["tiny", "small", "medium", "large"]
        sub = df[df.span_class .== cls, :]
        isempty(sub) && continue
        row = first(sub, 1)
        @printf("Best %-6s closure=%.6e T=%.6f seed=%s Ispan=%.6e Dspan=%.6e\n",
                cls, row.closure[1], row.best_T[1], row.seed_label[1], row.I_span[1], row.D_span[1])
    end
end

# -*- coding: utf-8 -*-
# Search for ODE periodic-orbit candidates from one projected Gibson DNS state.
#
# This script uses the DNS archive only to choose an initial ODE state. It then
# integrates the CloudAtlas ODE model, ranks near recurrences in the resulting
# trajectory, and optionally refines the best recurrence segments with
# BifurcationKit collocation.
#
# Example quick scan:
#   CLOUDATLAS_SKIP_ACTIVATE=true \
#   GIBSON_ORBIT_IDS=1 \
#   GIBSON_JKL=2x4x7 \
#   GIBSON_T_FINAL=500 \
#   GIBSON_SAVE_DT=1 \
#   GIBSON_T_MIN=20 \
#   GIBSON_T_MAX=200 \
#   julia --startup-file=no --project=. notebooks/periodic_orbits/gibson/ode_recurrence_search.jl
#
# Add `GIBSON_REFINE_RECURRENCES=true` after the recurrence CSV shows promising
# candidates.

if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "..", "..", ".."))
end

using CloudAtlas
import BifurcationKit as BK
using ChannelflowWrapper
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

as_vector(x) = x isa AbstractMatrix ? vec(Float64.(x)) : vec(Float64.(x))

const HERE = @__DIR__
archive = joinpath(HERE, "orbits-1-4-Re200-2pi1pi.tgz")
isfile(archive) || error("Missing Gibson orbit archive: $archive")

outdir = abspath(get(ENV, "GIBSON_ODE_OUT_DIR", joinpath(HERE, "ode_recurrence_attempt")))
extract_dir = joinpath(outdir, "dns_orbits")
mkpath(extract_dir)

Re = parse_float_env("GIBSON_RE", 200.0)
alpha = parse_float_env("GIBSON_ALPHA", 1.0)
gamma = parse_float_env("GIBSON_GAMMA", 2.0)
J, K, L = parse_jkl_env("GIBSON_JKL", (2, 4, 7))
orbit_ids = parse_orbit_ids_env("GIBSON_ORBIT_IDS", [1])

normalize_basis = parse_bool_env("GIBSON_NORMALIZE", true)
project_normalized = parse_bool_env("GIBSON_PROJECT_NRM", normalize_basis)
solver_abstol = parse_float_env("GIBSON_SOLVER_ABSTOL", 1e-9)
solver_reltol = parse_float_env("GIBSON_SOLVER_RELTOL", 1e-9)

t_final = parse_float_env("GIBSON_T_FINAL", 500.0)
t_transient = parse_float_env("GIBSON_T_TRANSIENT", 0.0)
save_dt = parse_float_env("GIBSON_SAVE_DT", 1.0)
t_min = parse_float_env("GIBSON_T_MIN", 20.0)
t_max = parse_float_env("GIBSON_T_MAX", min(250.0, t_final))
top_k = parse_int_env("GIBSON_TOP_K", 12)
dedup_dt = parse_float_env("GIBSON_RECURRENCE_DEDUP_DT", 5.0)
candidate_buffer_factor = parse_int_env("GIBSON_CANDIDATE_BUFFER_FACTOR", 50)
candidate_start_max = parse_float_env("GIBSON_RECURRENCE_T_START_MAX", Inf)
target_dns_period = parse_bool_env("GIBSON_TARGET_DNS_PERIOD", false)
target_period = parse_float_env("GIBSON_TARGET_PERIOD", NaN)
period_tol = parse_float_env("GIBSON_PERIOD_TOL", Inf)
min_i_span = parse_float_env("GIBSON_MIN_I_SPAN", 0.0)
min_d_span = parse_float_env("GIBSON_MIN_D_SPAN", 0.0)

refine_recurrences = parse_bool_env("GIBSON_REFINE_RECURRENCES", false)
max_refine = parse_int_env("GIBSON_MAX_REFINE", min(3, top_k))
collocation_ntst = parse_int_env("GIBSON_COLLOCATION_NTST", 20)
collocation_degree = parse_int_env("GIBSON_COLLOCATION_DEGREE", 3)
collocation_maxiters = parse_int_env("GIBSON_COLLOCATION_MAXITERS", 10)
collocation_tol = parse_float_env("GIBSON_COLLOCATION_TOL", 1e-8)
collocation_accept_tol = parse_float_env("GIBSON_COLLOCATION_ACCEPT_TOL", max(collocation_tol, 1e-5))
collocation_stop_at_accept = parse_bool_env("GIBSON_COLLOCATION_STOP_AT_ACCEPT", true)
collocation_newton_tol = if collocation_stop_at_accept
    max(collocation_tol, collocation_accept_tol)
else
    collocation_tol
end
collocation_verbose = parse_bool_env("GIBSON_COLLOCATION_VERBOSE", true)

t_final > 0 || error("GIBSON_T_FINAL must be positive")
save_dt > 0 || error("GIBSON_SAVE_DT must be positive")
0 <= t_transient < t_final || error("Require 0 <= GIBSON_T_TRANSIENT < GIBSON_T_FINAL")
0 < t_min <= t_max || error("Require 0 < GIBSON_T_MIN <= GIBSON_T_MAX")
top_k > 0 || error("GIBSON_TOP_K must be positive")
candidate_start_max >= 0 || error("GIBSON_RECURRENCE_T_START_MAX must be nonnegative")
period_tol >= 0 || error("GIBSON_PERIOD_TOL must be nonnegative")
min_i_span >= 0 || error("GIBSON_MIN_I_SPAN must be nonnegative")
min_d_span >= 0 || error("GIBSON_MIN_D_SPAN must be nonnegative")

@printf("Output directory: %s\n", outdir)
@printf("ODE model: Re=%.6g alpha=%.6g gamma=%.6g JKL=(%d,%d,%d)\n", Re, alpha, gamma, J, K, L)
@printf("Orbit ids: %s\n", join(orbit_ids, ", "))
@printf("Trajectory scan: T_final=%.6g transient=%.6g save_dt=%.6g recurrence_window=[%.6g, %.6g]\n",
        t_final, t_transient, save_dt, t_min, t_max)
@printf("Recurrence filters: t_start_max=%s target_dns_period=%s target_period=%s period_tol=%s min_I_span=%.3e min_D_span=%.3e\n",
        isfinite(candidate_start_max) ? string(candidate_start_max) : "Inf",
        target_dns_period,
        isfinite(target_period) ? string(target_period) : "none",
        isfinite(period_tol) ? string(period_tol) : "Inf",
        min_i_span,
        min_d_span)
if refine_recurrences
    @printf("Collocation refinement: max_refine=%d Ntst=%d degree=%d maxiters=%d tol=%.3e newton_tol=%.3e accept_tol=%.3e stop_at_accept=%s\n",
            max_refine, collocation_ntst, collocation_degree, collocation_maxiters,
            collocation_tol, collocation_newton_tol, collocation_accept_tol,
            collocation_stop_at_accept)
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

ensure_orbit_archive_extracted(archive, extract_dir)

sx, sy, sz, tx, tz = halfbox_symmetries()
H = [sx * sy * sz, sz * tx * tz]
model = ODEModel(alpha, gamma, J, K, L, H; normalize = normalize_basis)
m = length(model)
@printf("Model dimension: %d\n", m)

recurrence_Dmat = if min_d_span > 0
    @printf("Building dissipation matrix for recurrence D-span filter...\n")
    build_dissipation_matrix(model)
else
    nothing
end

function project_orbit_state(model::ODEModel, orbit_id::Int, outdir::AbstractString)
    src = orbit_ubest(orbit_id)
    isfile(src) || error("Missing orbit state: $src")

    workdir = joinpath(outdir, "orbit$(orbit_id)")
    mkpath(workdir)
    coeff_path = joinpath(workdir, "x0_projected_J$(J)_K$(K)_L$(L).asc")
    kwargs = project_normalized ? (nrm = true,) : NamedTuple()
    raw = ChannelflowWrapper.field2coeff(model.ijkl, src, coeff_path; workdir = workdir, kwargs...)
    x = as_vector(raw)
    length(x) == length(model) || error("Projected length $(length(x)) != model dimension $(length(model))")
    return x, coeff_path
end

function ode_problem(model::ODEModel, x0::AbstractVector; Re::Real, tspan)
    function rhs!(du, u, p, t)
        du .= model.f(u, p[1])
        return nothing
    end
    ODEProblem(rhs!, collect(x0), tspan, [Float64(Re)])
end

function integrate_trajectory(model::ODEModel, x0::AbstractVector; Re::Real)
    times = collect(0.0:save_dt:t_final)
    if times[end] < t_final
        push!(times, t_final)
    end
    prob = ode_problem(model, x0; Re = Re, tspan = (0.0, t_final))
    return solve(
        prob,
        Tsit5();
        abstol = solver_abstol,
        reltol = solver_reltol,
        saveat = times,
        dense = false,
    )
end

function closing_residual(model::ODEModel, x0::AbstractVector, T::Real; Re::Real)
    prob = ode_problem(model, x0; Re = Re, tspan = (0.0, T))
    sol = solve(prob, Tsit5(); abstol = solver_abstol, reltol = solver_reltol, saveat = [T])
    sol.retcode == ReturnCode.Success || return Inf
    return norm(sol.u[end] .- x0)
end

function orbit_observable_spans(model::ODEModel, x0::AbstractVector, T::Real; Re::Real, D_matrix = nothing)
    times = collect(range(0.0, T; length = 101))
    prob = ode_problem(model, x0; Re = Re, tspan = (0.0, T))
    sol = solve(prob, Tsit5(); abstol = solver_abstol, reltol = solver_reltol, saveat = times)
    sol.retcode == ReturnCode.Success || return (i_span = NaN, d_span = NaN)
    xs = [collect(Float64, u) for u in sol.u]
    I = [shear(x, model) for x in xs]
    D = D_matrix === nothing ? Float64[] : [dissipation_rate(D_matrix, x) for x in xs]
    return (
        i_span = maximum(I) - minimum(I),
        d_span = D_matrix === nothing ? NaN : maximum(D) - minimum(D),
    )
end

struct RecurrenceCandidate
    i::Int
    j::Int
    ti::Float64
    tj::Float64
    T::Float64
    dist::Float64
    rel::Float64
    norm_i::Float64
    norm_j::Float64
    shear_i::Float64
    shear_j::Float64
    i_span::Float64
    d_span::Float64
end

function maybe_trim!(candidates::Vector{RecurrenceCandidate}, keep_limit::Int)
    length(candidates) <= 2 * keep_limit && return
    sort!(candidates; by = c -> c.rel)
    resize!(candidates, keep_limit)
    return
end

function range_span(vals::AbstractVector{<:Real}, i::Int, j::Int)
    view_vals = @view vals[i:j]
    return Float64(maximum(view_vals) - minimum(view_vals))
end

function recurrence_candidates(model::ODEModel, sol, top_k::Int; target_period::Real = NaN, D_matrix = nothing)
    times = Float64.(sol.t)
    states = [collect(Float64, u) for u in sol.u]
    norms = [norm(x) for x in states]
    shears = [shear(x, model) for x in states]
    dissipations = D_matrix === nothing ? nothing : [dissipation_rate(D_matrix, x) for x in states]
    has_target_period = isfinite(Float64(target_period))

    keep_limit = max(top_k * max(candidate_buffer_factor, 1), top_k)
    candidates = RecurrenceCandidate[]
    first_i = searchsortedfirst(times, t_transient)

    for i in first_i:length(times)-1
        times[i] <= candidate_start_max || continue
        j0 = max(i + 1, searchsortedfirst(times, times[i] + t_min))
        j1 = searchsortedlast(times, times[i] + t_max)
        j0 <= j1 || continue
        xi = states[i]
        ni = norms[i]
        denom = max(ni, eps(Float64))
        for j in j0:j1
            T = times[j] - times[i]
            if has_target_period && abs(T - Float64(target_period)) > period_tol
                continue
            end
            i_span = range_span(shears, i, j)
            i_span >= min_i_span || continue
            d_span = NaN
            if dissipations !== nothing
                d_span = range_span(dissipations, i, j)
                d_span >= min_d_span || continue
            end
            d = norm(states[j] .- xi)
            rel = d / denom
            push!(candidates, RecurrenceCandidate(
                i, j, times[i], times[j], T,
                d, rel, ni, norms[j], shears[i], shears[j], i_span, d_span,
            ))
        end
        maybe_trim!(candidates, keep_limit)
    end

    sort!(candidates; by = c -> c.rel)
    selected = RecurrenceCandidate[]
    for c in candidates
        separated = all(s -> hypot(c.ti - s.ti, c.tj - s.tj) >= dedup_dt, selected)
        separated || continue
        push!(selected, c)
        length(selected) >= top_k && break
    end
    return selected
end

function write_candidates(path::AbstractString, candidates::Vector{RecurrenceCandidate})
    open(path, "w") do io
        println(io, "rank,i,j,t_i,t_j,T,distance,relative_distance,norm_i,norm_j,shear_i,shear_j,I_span,D_span")
        for (rank, c) in enumerate(candidates)
            println(io, join((
                rank, c.i, c.j,
                c.ti, c.tj, c.T,
                c.dist, c.rel,
                c.norm_i, c.norm_j,
                c.shear_i, c.shear_j,
                c.i_span, c.d_span,
            ), ","))
        end
    end
end

function refine_with_collocation(model::ODEModel, sol_ode, candidate::RecurrenceCandidate; Re::Real)
    xstart = collect(Float64, sol_ode.u[candidate.i])
    segment_prob = ode_problem(model, xstart; Re = Re, tspan = (0.0, candidate.T))
    segment_sol = solve(
        segment_prob,
        Tsit5();
        abstol = solver_abstol,
        reltol = solver_reltol,
        dense = true,
    )
    segment_sol.retcode == ReturnCode.Success ||
        error("candidate segment integration failed with retcode $(segment_sol.retcode)")

    F(x, p) = model.f(x, p[1])
    Jfun(x, p) = model.Df(x, p[1])
    prob_vf = BK.BifurcationProblem(
        F,
        xstart,
        [Float64(Re)],
        1;
        J = Jfun,
        record_from_solution = (x, p; k...) -> norm(x),
    )

    orbit_seed = t -> segment_sol(t)
    coll = BK.PeriodicOrbitOCollProblem(
        collocation_ntst,
        collocation_degree;
        prob_vf = prob_vf,
        N = length(model),
        ϕ = zeros(length(model) * (1 + collocation_degree * collocation_ntst)),
        xπ = zeros(length(model) * (1 + collocation_degree * collocation_ntst)),
        jacobian = BK.FullSparse(),
    )
    ci = BK.generate_solution(coll, orbit_seed, candidate.T)
    BK.updatesection!(coll, ci, [Float64(Re)])

    residual0 = norm(BK.residual(coll, ci, [Float64(Re)]))
    @printf("    seed residual %.6e\n", residual0)

    best_u = copy(ci)
    best_residual = residual0
    best_step = 0
    function keep_best_callback(state; kwargs...)
        if state.residual < best_residual
            best_u = copy(state.x)
            best_residual = Float64(state.residual)
            best_step = Int(state.step)
        end
        return !(collocation_stop_at_accept && state.residual <= collocation_accept_tol)
    end

    newton_options = BK.NewtonPar(
        tol = collocation_newton_tol,
        max_iterations = collocation_maxiters,
        verbose = collocation_verbose,
        linsolver = BK.COPLS(),
        linesearch = true,
    )
    newton_sol = BK.newton(coll, ci, newton_options; callback = keep_best_callback)
    residual = norm(BK.residual(coll, newton_sol.u, [Float64(Re)]))
    if residual < best_residual
        best_u = copy(newton_sol.u)
        best_residual = Float64(residual)
        best_step = Int(newton_sol.itnewton)
    end
    return (
        sol = newton_sol,
        u = best_u,
        residual0 = residual0,
        residual_final = residual,
        residual_best = best_residual,
        best_step = best_step,
        converged = BK.converged(newton_sol),
        accepted = best_residual <= collocation_accept_tol,
    )
end

summary_path = joinpath(outdir, "ode_recurrence_summary_J$(J)_K$(K)_L$(L).csv")
open(summary_path, "w") do io
    println(io, join([
        "orbit_id", "J", "K", "L", "m", "dns_period", "x0_norm", "x0_shear",
        "trajectory_retcode", "trajectory_points", "best_T", "best_relative_distance",
        "best_distance", "candidates_path",
    ], ","))

    for id in orbit_ids
        Tdns = orbit_period(id)
        @printf("\nOrbit %d: DNS period %.12f\n", id, Tdns)

        x0, coeff_path = project_orbit_state(model, id, outdir)
        @printf("  projected x0: |x|=%.6e shear=%.9f coeffs=%s\n",
                norm(x0), shear(x0, model), coeff_path)

        sol_ode = nothing
        elapsed = @elapsed begin
            sol_ode = integrate_trajectory(model, x0; Re = Re)
        end
        @printf("  ODE integration: retcode=%s saved_points=%d elapsed=%.2f s\n",
                sol_ode.retcode, length(sol_ode.t), elapsed)
        sol_ode.retcode == ReturnCode.Success || error("ODE integration failed with retcode $(sol_ode.retcode)")

        period_target = isfinite(target_period) ? target_period : (target_dns_period ? Tdns : NaN)
        if isfinite(period_target)
            @printf("  recurrence target period: %.12f ± %.6g\n", period_target, period_tol)
        end
        candidates = recurrence_candidates(model, sol_ode, top_k; target_period = period_target, D_matrix = recurrence_Dmat)
        candidate_path = joinpath(outdir, "orbit$(id)", "ode_recurrences_J$(J)_K$(K)_L$(L).csv")
        write_candidates(candidate_path, candidates)
        @printf("  wrote %d recurrence candidates: %s\n", length(candidates), candidate_path)

        if isempty(candidates)
            println(io, join((id, J, K, L, m, Tdns, norm(x0), shear(x0, model),
                              sol_ode.retcode, length(sol_ode.t), NaN, NaN, NaN, candidate_path), ","))
            continue
        end

        best = candidates[1]
        @printf("  best recurrence: t=[%.6f, %.6f] T=%.6f dist=%.6e rel=%.6e I_span=%.6e D_span=%.6e\n",
                best.ti, best.tj, best.T, best.dist, best.rel, best.i_span, best.d_span)
        println(io, join((id, J, K, L, m, Tdns, norm(x0), shear(x0, model),
                          sol_ode.retcode, length(sol_ode.t), best.T, best.rel,
                          best.dist, candidate_path), ","))

        if refine_recurrences
            refine_path = joinpath(outdir, "orbit$(id)", "ode_recurrence_refinements_J$(J)_K$(K)_L$(L).csv")
            open(refine_path, "w") do rio
                println(rio, "rank,t_i,t_j,T_seed,seed_distance,seed_relative_distance,seed_I_span,seed_D_span,residual0,residual_final,residual_best,best_step,converged,accepted,T_refined,norm_refined,shear_refined,closing_residual,refined_I_span,refined_D_span,span_accepted,coeff_path")
                for (rank, c) in enumerate(candidates[1:min(max_refine, length(candidates))])
                    @printf("  refining rank %d: t=[%.6f, %.6f] T=%.6f rel=%.6e\n",
                            rank, c.ti, c.tj, c.T, c.rel)
                    residual0 = NaN
                    residual_final = NaN
                    residual_best = NaN
                    best_step = -1
                    converged = false
                    accepted = false
                    T_refined = NaN
                    norm_refined = NaN
                    shear_refined = NaN
                    closing = NaN
                    refined_i_span = NaN
                    refined_d_span = NaN
                    span_accepted = false
                    sol_path = ""
                    try
                        result = refine_with_collocation(model, sol_ode, c; Re = Re)
                        residual0 = result.residual0
                        residual_final = result.residual_final
                        residual_best = result.residual_best
                        best_step = result.best_step
                        converged = result.converged
                        accepted = result.accepted
                        x_refined = collect(Float64, result.u[1:m])
                        T_refined = Float64(result.u[end])
                        norm_refined = norm(x_refined)
                        shear_refined = shear(x_refined, model)
                        closing = closing_residual(model, x_refined, T_refined; Re = Re)
                        spans = orbit_observable_spans(model, x_refined, T_refined; Re = Re, D_matrix = recurrence_Dmat)
                        refined_i_span = spans.i_span
                        refined_d_span = spans.d_span
                        span_accepted = refined_i_span >= min_i_span &&
                            (recurrence_Dmat === nothing || refined_d_span >= min_d_span)
                        sol_path = joinpath(outdir, "orbit$(id)",
                                            "x_recurrence_rank$(rank)_J$(J)_K$(K)_L$(L).asc")
                        CloudAtlas.save(x_refined, sol_path)
                        @printf("    refined: T=%.12f residual_final=%.6e residual_best=%.6e best_step=%d accepted=%s closing=%.6e I_span=%.6e D_span=%.6e span_accepted=%s coeffs=%s\n",
                                T_refined, residual_final, residual_best, best_step, accepted, closing,
                                refined_i_span, refined_d_span, span_accepted, sol_path)
                    catch err
                        @printf("    refinement failed: %s\n", sprint(showerror, err))
                    end
                    println(rio, join((rank, c.ti, c.tj, c.T, c.dist, c.rel,
                                       c.i_span, c.d_span,
                                       residual0, residual_final, residual_best,
                                       best_step, converged, accepted, T_refined,
                                       norm_refined, shear_refined, closing,
                                       refined_i_span, refined_d_span, span_accepted, sol_path), ","))
                end
            end
            @printf("  wrote refinement summary: %s\n", refine_path)
        end
    end
end

@printf("\nWrote summary: %s\n", summary_path)

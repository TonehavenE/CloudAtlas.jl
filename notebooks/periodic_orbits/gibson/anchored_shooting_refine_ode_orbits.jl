# -*- coding: utf-8 -*-
# Shape-anchored shooting refinement for Gibson ODE recurrence candidates.
#
# Free collocation has been converging to tiny nearby ODE periodic orbits. This
# script tries a different continuation: solve an overdetermined shooting
# least-squares problem with soft anchors on the I(t), D(t) waveform of the
# large recurrence segment. Decreasing `GIBSON_ANCHOR_WEIGHTS` tests whether the
# large loop can survive once the shape anchor is relaxed.

if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "..", "..", ".."))
end

using CSV
using CloudAtlas
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

function parse_float_list_env(name::AbstractString, default::Vector{Float64})
    raw = strip(get(ENV, name, ""))
    isempty(raw) && return default
    return [parse(Float64, strip(x)) for x in split(raw, ",") if !isempty(strip(x))]
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
rank_filter = parse_rank_filter("GIBSON_CANDIDATE_RANKS")

normalize_basis = parse_bool_env("GIBSON_NORMALIZE", true)
project_normalized = parse_bool_env("GIBSON_PROJECT_NRM", normalize_basis)
solver_abstol = parse_float_env("GIBSON_SOLVER_ABSTOL", 1e-9)
solver_reltol = parse_float_env("GIBSON_SOLVER_RELTOL", 1e-9)

max_candidates = parse_int_env("GIBSON_MAX_ANCHORED_CANDIDATES", 2)
anchor_weights = parse_float_list_env("GIBSON_ANCHOR_WEIGHTS", [100.0, 10.0, 1.0, 0.1])
period_anchor_weight = parse_float_env("GIBSON_PERIOD_ANCHOR_WEIGHT", 1.0)
sample_count = parse_int_env("GIBSON_ANCHOR_SAMPLES", 16)

hook_ftol = parse_float_env("GIBSON_HOOK_FTOL", 1e-5)
hook_xtol = parse_float_env("GIBSON_HOOK_XTOL", 1e-7)
hook_delta = parse_float_env("GIBSON_HOOK_DELTA", 0.005)
hook_newton = parse_int_env("GIBSON_HOOK_NEWTON", 6)
hook_nhook = parse_int_env("GIBSON_HOOK_NHOOK", 4)
hook_nmusearch = parse_int_env("GIBSON_HOOK_NMUSEARCH", 6)
hook_verbosity = parse_int_env("GIBSON_HOOK_VERBOSITY", 1)

max_candidates > 0 || error("GIBSON_MAX_ANCHORED_CANDIDATES must be positive")
sample_count >= 4 || error("GIBSON_ANCHOR_SAMPLES must be at least 4")
all(w -> w >= 0, anchor_weights) || error("GIBSON_ANCHOR_WEIGHTS must be nonnegative")

@printf("Output directory: %s\n", outdir)
@printf("ODE model: Re=%.6g alpha=%.6g gamma=%.6g JKL=(%d,%d,%d)\n", Re, alpha, gamma, J, K, L)
@printf("Orbit ids: %s\n", join(orbit_ids, ", "))
@printf("Anchored shooting: candidates=%d ranks=%s samples=%d weights=%s period_weight=%.3e\n",
        max_candidates,
        rank_filter === nothing ? "top" : join(sort(collect(rank_filter)), ","),
        sample_count,
        join(anchor_weights, ","),
        period_anchor_weight)
@printf("Hookstep: ftol=%.3e xtol=%.3e delta=%.3e Nnewton=%d Nhook=%d\n",
        hook_ftol, hook_xtol, hook_delta, hook_newton, hook_nhook)

function ensure_orbit_archive_extracted(archive::AbstractString, extract_dir::AbstractString)
    needed = [joinpath(extract_dir, "orbit$(id)-Re200-2pi1pi", "ubest.nc") for id in 1:4]
    all(isfile, needed) && return
    mkpath(extract_dir)
    run(`tar -xzf $archive -C $extract_dir`)
end

orbit_dir(id::Int) = joinpath(extract_dir, "orbit$(id)-Re200-2pi1pi")
orbit_ubest(id::Int) = joinpath(orbit_dir(id), "ubest.nc")
orbit_workdir(id::Int) = joinpath(outdir, "orbit$(id)")
recurrence_csv(id::Int) = joinpath(orbit_workdir(id), "ode_recurrences_J$(J)_K$(K)_L$(L).csv")

ensure_orbit_archive_extracted(archive, extract_dir)

sx, sy, sz, tx, tz = halfbox_symmetries()
H = [sx * sy * sz, sz * tx * tz]
model = ODEModel(alpha, gamma, J, K, L, H; normalize = normalize_basis)
m = length(model)
@printf("Model dimension: %d\n", m)

@printf("Building dissipation matrix...\n")
Dmat = build_dissipation_matrix(model)

function project_orbit_state(model::ODEModel, orbit_id::Int)
    workdir = orbit_workdir(orbit_id)
    mkpath(workdir)
    coeff_path = joinpath(workdir, "x0_projected_J$(J)_K$(K)_L$(L).asc")
    if isfile(coeff_path)
        return load_coeff_vector(coeff_path), coeff_path
    end
    kwargs = project_normalized ? (nrm = true,) : NamedTuple()
    raw = ChannelflowWrapper.field2coeff(model.ijkl, orbit_ubest(orbit_id), coeff_path; workdir = workdir, kwargs...)
    return as_vector(raw), coeff_path
end

function ode_problem(model::ODEModel, x0::AbstractVector; Re::Real, tspan)
    function rhs!(du, u, p, t)
        du .= model.f(u, p[1])
        return nothing
    end
    return ODEProblem(rhs!, collect(x0), tspan, [Float64(Re)])
end

function integrate_dense(model::ODEModel, x0::AbstractVector, T::Real; Re::Real)
    sol = solve(ode_problem(model, x0; Re = Re, tspan = (0.0, T)),
                Tsit5(); abstol = solver_abstol, reltol = solver_reltol, dense = true)
    sol.retcode == ReturnCode.Success || error("ODE integration failed with retcode $(sol.retcode)")
    return sol
end

function integrate_saveat(model::ODEModel, x0::AbstractVector, T::Real, times; Re::Real)
    sol = solve(ode_problem(model, x0; Re = Re, tspan = (0.0, T)),
                Tsit5(); abstol = solver_abstol, reltol = solver_reltol, saveat = times)
    sol.retcode == ReturnCode.Success || return nothing
    return sol
end

function observables(xs)
    I = [shear(x, model) for x in xs]
    D = [dissipation_rate(Dmat, x) for x in xs]
    return I, D
end

function closure_norm(x0::AbstractVector, T::Real)
    sol = integrate_saveat(model, x0, T, [T]; Re = Re)
    sol === nothing && return Inf
    return norm(collect(sol.u[end]) .- x0)
end

function span_tuple(x0::AbstractVector, T::Real)
    times = collect(range(0.0, T; length = 101))
    sol = integrate_saveat(model, x0, T, times; Re = Re)
    sol === nothing && return (i_span = NaN, d_span = NaN)
    xs = [collect(Float64, u) for u in sol.u]
    I, D = observables(xs)
    return (i_span = maximum(I) - minimum(I), d_span = maximum(D) - minimum(D))
end

function select_candidates(id::Int)
    path = recurrence_csv(id)
    isfile(path) || error("Missing recurrence CSV: $path")
    df = DataFrame(CSV.File(path))
    if rank_filter !== nothing
        df = df[[Int(r) in rank_filter for r in df.rank], :]
    end
    sort!(df, :relative_distance)
    return df[1:min(max_candidates, nrow(df)), :]
end

function anchored_residual_factory(seed_x::Vector{Float64}, seed_T::Float64, θ, seed_I, seed_D, anchor_weight::Float64)
    sqrt_anchor = sqrt(anchor_weight)
    sqrt_period = sqrt(period_anchor_weight)
    xref = copy(seed_x)

    function residual(ξ::AbstractVector)
        x = collect(Float64, ξ[1:m])
        T = Float64(ξ[m + 1])
        out_len = m + 1 + 2 * length(θ) + 1
        if !(isfinite(T) && T > 0)
            return fill(1e6, out_len)
        end
        times = T .* θ
        sol = integrate_saveat(model, x, T, times; Re = Re)
        if sol === nothing || length(sol.u) != length(times)
            return fill(1e6, out_len)
        end

        xs = [collect(Float64, u) for u in sol.u]
        xend = xs[end]
        I, D = observables(xs)

        r = Float64[]
        append!(r, xend .- x)
        push!(r, dot(model.f(x, Re), x .- xref))
        for k in eachindex(θ)
            push!(r, sqrt_anchor * (I[k] - seed_I[k]))
            push!(r, sqrt_anchor * (D[k] - seed_D[k]))
        end
        push!(r, sqrt_period * (T - seed_T))
        return r
    end
    return residual
end

function anchored_refine(seed_x::Vector{Float64}, seed_T::Float64; orbit_id::Int, rank::Int)
    θ = collect(range(0.0, 1.0; length = sample_count))
    seed_sol = integrate_saveat(model, seed_x, seed_T, seed_T .* θ; Re = Re)
    seed_sol === nothing && error("Failed to integrate seed segment for rank $rank")
    seed_xs = [collect(Float64, u) for u in seed_sol.u]
    seed_I, seed_D = observables(seed_xs)

    ξ = [seed_x; seed_T]
    rows = NamedTuple[]
    for weight in anchor_weights
        @printf("    anchor weight %.3e\n", weight)
        residual = anchored_residual_factory(seed_x, seed_T, θ, seed_I, seed_D, weight)
        params = SearchParams(
            ftol = hook_ftol,
            xtol = hook_xtol,
            δ = hook_delta,
            Nnewton = hook_newton,
            Nhook = hook_nhook,
            Nmusearch = hook_nmusearch,
            verbosity = hook_verbosity,
        )
        ξ, ok = hookstepsolve(residual, ξ, params)
        x = collect(Float64, ξ[1:m])
        T = Float64(ξ[m + 1])
        resnorm = norm(residual(ξ))
        close = closure_norm(x, T)
        spans = span_tuple(x, T)
        sol_path = joinpath(orbit_workdir(orbit_id),
                            "x_anchor_rank$(rank)_w$(replace(string(weight), "." => "p"))_J$(J)_K$(K)_L$(L).asc")
        CloudAtlas.save(x, sol_path)
        @printf("      ok=%s T=%.12f residual=%.6e closing=%.6e I_span=%.6e D_span=%.6e coeffs=%s\n",
                ok, T, resnorm, close, spans.i_span, spans.d_span, sol_path)
        push!(rows, (
            orbit_id = orbit_id,
            rank = rank,
            anchor_weight = weight,
            hook_success = ok,
            residual_norm = resnorm,
            closing_residual = close,
            T = T,
            I_span = spans.i_span,
            D_span = spans.d_span,
            coeff_path = sol_path,
        ))
    end
    return rows
end

summary_rows = NamedTuple[]
for id in orbit_ids
    @printf("\nOrbit %d\n", id)
    x_projected, coeff_path = project_orbit_state(model, id)
    candidates = select_candidates(id)
    max_start = maximum(Float64.(candidates.t_i))
    full_sol = integrate_dense(model, x_projected, max_start; Re = Re)
    @printf("  projected start coeffs=%s selected_candidates=%d\n", coeff_path, nrow(candidates))

    for row in eachrow(candidates)
        rank = Int(row.rank)
        ti = Float64(row.t_i)
        Tseed = Float64(row.T)
        seed_x = collect(Float64, full_sol(ti))
        @printf("  rank %d seed: t_i=%.6f T=%.6f rel=%.6e I_span=%.6e D_span=%.6e\n",
                rank, ti, Tseed, Float64(row.relative_distance), Float64(row.I_span), Float64(row.D_span))
        append!(summary_rows, anchored_refine(seed_x, Tseed; orbit_id = id, rank = rank))
    end
end

summary = DataFrame(summary_rows)
summary_path = joinpath(outdir, "anchored_shooting_summary_J$(J)_K$(K)_L$(L).csv")
CSV.write(summary_path, summary)
@printf("\nWrote anchored shooting summary: %s\n", summary_path)

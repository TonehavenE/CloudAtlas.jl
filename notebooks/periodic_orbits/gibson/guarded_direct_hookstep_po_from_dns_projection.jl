# -*- coding: utf-8 -*-
# Guarded direct shooting solve from projected Gibson DNS states.
#
# The unguarded phase-fixed shooting problem can reduce the PO closure by
# collapsing onto a tiny loop. This script uses the same projected DNS starting
# point and DNS period, but solves an overdetermined shooting problem with soft
# anchors on the I(t), D(t) waveform of the projected ODE trajectory. A sequence
# of decreasing anchor weights lets us test whether the large loop survives as
# the shape guard is relaxed.
#
# Example:
#   CLOUDATLAS_SKIP_ACTIVATE=true \
#   GIBSON_ORBIT_IDS=1 \
#   GIBSON_JKL=2x4x7 \
#   GIBSON_DIRECT_ANCHOR_WEIGHTS=100,10,1,0.1 \
#   GIBSON_HOOK_NEWTON=3 \
#   GIBSON_HOOK_DELTA=0.002 \
#   julia --startup-file=no --project=. notebooks/periodic_orbits/gibson/guarded_direct_hookstep_po_from_dns_projection.jl
#
# To resume an expensive ladder from an earlier output weight:
#   GIBSON_DIRECT_START_FROM_WEIGHT=1 \
#   GIBSON_DIRECT_ANCHOR_WEIGHTS=0.3,0.1,0.03

if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "..", "..", ".."))
end

using CSV
using CloudAtlas
using ChannelflowWrapper
using DataFrames
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

function parse_float_list_env(name::AbstractString, default::Vector{Float64})
    raw = strip(get(ENV, name, ""))
    isempty(raw) && return default
    return [parse(Float64, strip(x)) for x in split(raw, ",") if !isempty(strip(x))]
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

normalize_basis = parse_bool_env("GIBSON_NORMALIZE", true)
project_normalized = parse_bool_env("GIBSON_PROJECT_NRM", normalize_basis)
solver_abstol = parse_float_env("GIBSON_SOLVER_ABSTOL", 1e-10)
solver_reltol = parse_float_env("GIBSON_SOLVER_RELTOL", 1e-10)

anchor_weights = parse_float_list_env("GIBSON_DIRECT_ANCHOR_WEIGHTS", [100.0, 10.0, 1.0, 0.1])
period_anchor_weight = parse_float_env("GIBSON_DIRECT_PERIOD_WEIGHT", 1.0)
sample_count = parse_int_env("GIBSON_DIRECT_ANCHOR_SAMPLES", 16)
append_summary = parse_bool_env("GIBSON_DIRECT_APPEND_SUMMARY", true)
start_coeff_override = strip(get(ENV, "GIBSON_DIRECT_START_COEFF", ""))
start_t_override = strip(get(ENV, "GIBSON_DIRECT_START_T", ""))
start_from_weight = strip(get(ENV, "GIBSON_DIRECT_START_FROM_WEIGHT", ""))

hook_ftol = parse_float_env("GIBSON_HOOK_FTOL", 1e-5)
hook_xtol = parse_float_env("GIBSON_HOOK_XTOL", 1e-7)
hook_delta = parse_float_env("GIBSON_HOOK_DELTA", 0.002)
hook_newton = parse_int_env("GIBSON_HOOK_NEWTON", 3)
hook_nhook = parse_int_env("GIBSON_HOOK_NHOOK", 4)
hook_nmusearch = parse_int_env("GIBSON_HOOK_NMUSEARCH", 6)
hook_verbosity = parse_int_env("GIBSON_HOOK_VERBOSITY", 1)

sample_count >= 4 || error("GIBSON_DIRECT_ANCHOR_SAMPLES must be at least 4")
all(w -> w >= 0, anchor_weights) || error("GIBSON_DIRECT_ANCHOR_WEIGHTS must be nonnegative")

@printf("Output directory: %s\n", outdir)
@printf("ODE model: Re=%.6g alpha=%.6g gamma=%.6g JKL=(%d,%d,%d)\n", Re, alpha, gamma, J, K, L)
@printf("Orbit ids: %s\n", join(orbit_ids, ", "))
@printf("Guarded direct PO: samples=%d weights=%s period_weight=%.3e\n",
        sample_count, join(anchor_weights, ","), period_anchor_weight)
!isempty(start_from_weight) && @printf("Resume from previous anchor weight: %s\n", start_from_weight)
!isempty(start_coeff_override) && @printf("Resume from coefficient file: %s\n", start_coeff_override)
@printf("Hookstep: ftol=%.3e xtol=%.3e delta=%.3e Nnewton=%d Nhook=%d Nmusearch=%d\n",
        hook_ftol, hook_xtol, hook_delta, hook_newton, hook_nhook, hook_nmusearch)

if !isempty(start_coeff_override) && length(orbit_ids) != 1
    error("GIBSON_DIRECT_START_COEFF can only be used with one orbit id")
end
if !isempty(start_t_override) && isempty(start_coeff_override)
    error("GIBSON_DIRECT_START_T requires GIBSON_DIRECT_START_COEFF")
end
if !isempty(start_coeff_override) && !isempty(start_from_weight)
    error("Use only one of GIBSON_DIRECT_START_COEFF and GIBSON_DIRECT_START_FROM_WEIGHT")
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
summary_path = joinpath(outdir, "guarded_direct_hookstep_po_summary_J$(J)_K$(K)_L$(L).csv")

ensure_orbit_archive_extracted(archive, extract_dir)

sx, sy, sz, tx, tz = halfbox_symmetries()
H = [sx * sy * sz, sz * tx * tz]
model = ODEModel(alpha, gamma, J, K, L, H; normalize = normalize_basis, tw = false)
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

function phase_fixed_residual_norm(x0::Vector{Float64}, T::Real, xref::Vector{Float64})
    sol = integrate_saveat(model, x0, T, [T]; Re = Re)
    sol === nothing && return Inf
    close = collect(sol.u[end]) .- x0
    phase = dot(model.f(x0, Re), x0 .- xref)
    return norm([close; phase])
end

function resume_from_previous_weight(orbit_id::Int, weight::Float64)
    isfile(summary_path) || error("Cannot resume from weight $weight; missing summary: $summary_path")
    df = DataFrame(CSV.File(summary_path))
    keep = [
        Int(row.orbit_id) == orbit_id &&
        Int(row.J) == J &&
        Int(row.K) == K &&
        Int(row.L) == L &&
        isapprox(Float64(row.anchor_weight), weight; atol = 1e-12, rtol = 1e-12)
        for row in eachrow(df)
    ]
    any(keep) || error("No previous guarded-direct row for orbit $orbit_id, JKL=($J,$K,$L), weight=$weight")
    row = df[findlast(keep), :]
    coeff = String(row.coeff_solution)
    isfile(coeff) || error("Previous coefficient file is missing: $coeff")
    return load_coeff_vector(coeff), coeff, Float64(row.T_solution)
end

function initial_guess_for_orbit(orbit_id::Int, x_projected::Vector{Float64}, Tref::Float64, coeff_projected::AbstractString)
    if !isempty(start_coeff_override)
        coeff = abspath(start_coeff_override)
        T = isempty(start_t_override) ? Tref : parse(Float64, start_t_override)
        return load_coeff_vector(coeff), coeff, T
    elseif !isempty(start_from_weight)
        return resume_from_previous_weight(orbit_id, parse(Float64, start_from_weight))
    else
        return copy(x_projected), String(coeff_projected), Tref
    end
end

function guarded_residual_factory(xref::Vector{Float64}, Tref::Float64, θ, target_I, target_D, anchor_weight::Float64)
    sqrt_anchor = sqrt(anchor_weight)
    sqrt_period = sqrt(period_anchor_weight)
    out_len = m + 1 + 2 * length(θ) + 1

    function residual(ξ::AbstractVector)
        x = collect(Float64, ξ[1:m])
        T = Float64(ξ[m + 1])
        if !(isfinite(T) && T > 0)
            return fill(1e6, out_len)
        end

        times = T .* θ
        sol = integrate_saveat(model, x, T, times; Re = Re)
        if sol === nothing || length(sol.u) != length(times)
            return fill(1e6, out_len)
        end

        xs = [collect(Float64, u) for u in sol.u]
        I, D = observables(xs)

        r = Float64[]
        append!(r, xs[end] .- x)
        push!(r, dot(model.f(x, Re), x .- xref))
        for k in eachindex(θ)
            push!(r, sqrt_anchor * (I[k] - target_I[k]))
            push!(r, sqrt_anchor * (D[k] - target_D[k]))
        end
        push!(r, sqrt_period * (T - Tref))
        return r
    end
    return residual
end

base_params() = SearchParams(
    ftol = hook_ftol,
    xtol = hook_xtol,
    δ = hook_delta,
    Nnewton = hook_newton,
    Nhook = hook_nhook,
    Nmusearch = hook_nmusearch,
    verbosity = hook_verbosity,
)

summary_rows = NamedTuple[]
for id in orbit_ids
    @printf("\nOrbit %d\n", id)
    x_projected, coeff_projected = project_orbit_state(model, id)
    Tref = orbit_period(id)
    θ = collect(range(0.0, 1.0; length = sample_count))
    seed_sol = integrate_saveat(model, x_projected, Tref, Tref .* θ; Re = Re)
    seed_sol === nothing && error("Failed to integrate projected seed for orbit $id")
    seed_xs = [collect(Float64, u) for u in seed_sol.u]
    target_I, target_D = observables(seed_xs)
    seed_spans = span_tuple(x_projected, Tref)
    seed_closing = closure_norm(x_projected, Tref)
    seed_phase = phase_fixed_residual_norm(x_projected, Tref, x_projected)

    @printf("  projected x0: |x|=%.6e shear=%.9f T_dns=%.12f coeffs=%s\n",
            norm(x_projected), shear(x_projected, model), Tref, coeff_projected)
    @printf("  seed: closing=%.6e phase_fixed_residual=%.6e I_span=%.6e D_span=%.6e\n",
            seed_closing, seed_phase, seed_spans.i_span, seed_spans.d_span)

    x_initial, coeff_initial, T_initial = initial_guess_for_orbit(id, x_projected, Tref, coeff_projected)
    initial_spans = span_tuple(x_initial, T_initial)
    initial_closing = closure_norm(x_initial, T_initial)
    initial_phase = phase_fixed_residual_norm(x_initial, T_initial, x_projected)
    @printf("  starting Newton from: T=%.12f closing=%.6e phase_fixed=%.6e I_span=%.6e D_span=%.6e coeffs=%s\n",
            T_initial, initial_closing, initial_phase, initial_spans.i_span, initial_spans.d_span, coeff_initial)

    ξ = [x_initial; T_initial]
    for weight in anchor_weights
        @printf("  anchor weight %.3e\n", weight)
        residual = guarded_residual_factory(x_projected, Tref, θ, target_I, target_D, weight)
        elapsed = @elapsed begin
            ξ, ok = hookstepsolve(residual, ξ, base_params())
        end

        x = collect(Float64, ξ[1:m])
        T = Float64(ξ[m + 1])
        resnorm = norm(residual(ξ))
        close = closure_norm(x, T)
        phase_res = phase_fixed_residual_norm(x, T, x_projected)
        spans = span_tuple(x, T)
        sol_path = joinpath(orbit_workdir(id),
                            "x_guarded_direct_w$(replace(string(weight), "." => "p"))_J$(J)_K$(K)_L$(L).asc")
        CloudAtlas.save(x, sol_path)

        @printf("    ok=%s elapsed=%.2f s T=%.12f residual=%.6e closing=%.6e phase_fixed=%.6e I_span=%.6e D_span=%.6e coeffs=%s\n",
                ok, elapsed, T, resnorm, close, phase_res, spans.i_span, spans.d_span, sol_path)

        push!(summary_rows, (
            orbit_id = id,
            J = J,
            K = K,
            L = L,
            m = m,
            anchor_weight = weight,
            hook_success = ok,
            elapsed_seconds = elapsed,
            coeff_projected = coeff_projected,
            coeff_solution = sol_path,
            T_seed = Tref,
            T_solution = T,
            closing_seed = seed_closing,
            phase_fixed_residual_seed = seed_phase,
            I_span_seed = seed_spans.i_span,
            D_span_seed = seed_spans.d_span,
            residual_solution = resnorm,
            closing_solution = close,
            phase_fixed_residual_solution = phase_res,
            I_span_solution = spans.i_span,
            D_span_solution = spans.d_span,
        ))
    end
end

summary = DataFrame(summary_rows)
append_this_run = append_summary && isfile(summary_path)
CSV.write(summary_path, summary; append = append_this_run, writeheader = !append_this_run)
@printf("\n%s guarded direct summary: %s\n", append_this_run ? "Appended" : "Wrote", summary_path)

# -*- coding: utf-8 -*-
# Direct phase-fixed shooting solve from projected Gibson DNS states.
#
# This script tries the classic exact periodic-orbit formulation directly:
#
#   phi_T(x0) - x0 = 0
#   dot(f(xref), x0 - xref) = 0
#
# using CloudAtlas.hookstepsolve_rpo with identity symmetry. The initial guess is
# the ODE projection of Gibson's DNS `ubest.nc`, and the initial period is
# `Tbest.asc`.
#
# Example:
#   CLOUDATLAS_SKIP_ACTIVATE=true \
#   GIBSON_ORBIT_IDS=1 \
#   GIBSON_JKL=2x4x7 \
#   GIBSON_HOOK_NEWTON=3 \
#   GIBSON_HOOK_DELTA=0.002 \
#   julia --startup-file=no --project=. notebooks/periodic_orbits/gibson/direct_hookstep_po_from_dns_projection.jl

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

hook_ftol = parse_float_env("GIBSON_HOOK_FTOL", 1e-6)
hook_xtol = parse_float_env("GIBSON_HOOK_XTOL", 1e-8)
hook_delta = parse_float_env("GIBSON_HOOK_DELTA", 0.002)
hook_newton = parse_int_env("GIBSON_HOOK_NEWTON", 3)
hook_nhook = parse_int_env("GIBSON_HOOK_NHOOK", 4)
hook_nmusearch = parse_int_env("GIBSON_HOOK_NMUSEARCH", 6)
hook_verbosity = parse_int_env("GIBSON_HOOK_VERBOSITY", 1)

@printf("Output directory: %s\n", outdir)
@printf("ODE model: Re=%.6g alpha=%.6g gamma=%.6g JKL=(%d,%d,%d)\n", Re, alpha, gamma, J, K, L)
@printf("Orbit ids: %s\n", join(orbit_ids, ", "))
@printf("Hookstep PO: ftol=%.3e xtol=%.3e delta=%.3e Nnewton=%d Nhook=%d Nmusearch=%d\n",
        hook_ftol, hook_xtol, hook_delta, hook_newton, hook_nhook, hook_nmusearch)

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

function integrate_at(model::ODEModel, x0::AbstractVector, T::Real, times; Re::Real)
    sol = solve(ode_problem(model, x0; Re = Re, tspan = (0.0, T)),
                Tsit5(); abstol = solver_abstol, reltol = solver_reltol, saveat = times)
    sol.retcode == ReturnCode.Success || return nothing
    return sol
end

function closing_residual(model::ODEModel, x0::AbstractVector, T::Real; Re::Real)
    sol = integrate_at(model, x0, T, [T]; Re = Re)
    sol === nothing && return Inf
    return norm(collect(sol.u[end]) .- x0)
end

function observable_spans(model::ODEModel, x0::AbstractVector, T::Real; Re::Real)
    times = collect(range(0.0, T; length = 101))
    sol = integrate_at(model, x0, T, times; Re = Re)
    sol === nothing && return (i_span = NaN, d_span = NaN)
    xs = [collect(Float64, u) for u in sol.u]
    I = [shear(x, model) for x in xs]
    D = [dissipation_rate(Dmat, x) for x in xs]
    return (
        i_span = maximum(I) - minimum(I),
        d_span = maximum(D) - minimum(D),
    )
end

function phase_fixed_residual_norm(model::ODEModel, x0::Vector{Float64}, T::Real, xref::Vector{Float64}; Re::Real)
    sol = integrate_at(model, x0, T, [T]; Re = Re)
    sol === nothing && return Inf
    close = collect(sol.u[end]) .- x0
    phase = dot(model.f(x0, Re), x0 .- xref)
    return norm([close; phase])
end

hookparams = SearchParams(
    ftol = hook_ftol,
    xtol = hook_xtol,
    δ = hook_delta,
    Nnewton = hook_newton,
    Nhook = hook_nhook,
    Nmusearch = hook_nmusearch,
    verbosity = hook_verbosity,
)

rows = NamedTuple[]
for id in orbit_ids
    @printf("\nOrbit %d\n", id)
    x0, coeff_path = project_orbit_state(model, id)
    Tguess = orbit_period(id)
    initial_closing = closing_residual(model, x0, Tguess; Re = Re)
    initial_phase_residual = phase_fixed_residual_norm(model, x0, Tguess, x0; Re = Re)
    initial_spans = observable_spans(model, x0, Tguess; Re = Re)

    @printf("  projected x0: |x|=%.6e shear=%.9f T_dns=%.12f coeffs=%s\n",
            norm(x0), shear(x0, model), Tguess, coeff_path)
    @printf("  initial: closing=%.6e phase_fixed_residual=%.6e I_span=%.6e D_span=%.6e\n",
            initial_closing, initial_phase_residual, initial_spans.i_span, initial_spans.d_span)

    elapsed = @elapsed begin
        x_sol, ax_sol, az_sol, T_sol, success =
            hookstepsolve_rpo(model, Re, Symmetry(), x0, Tguess, hookparams)
    end

    x_sol = collect(Float64, x_sol)
    T_sol = Float64(T_sol)
    final_closing = closing_residual(model, x_sol, T_sol; Re = Re)
    final_phase_residual = phase_fixed_residual_norm(model, x_sol, T_sol, x0; Re = Re)
    final_spans = observable_spans(model, x_sol, T_sol; Re = Re)

    sol_path = joinpath(orbit_workdir(id), "x_hookstep_po_direct_J$(J)_K$(K)_L$(L).asc")
    CloudAtlas.save(x_sol, sol_path)

    @printf("  hookstep result: success=%s elapsed=%.2f s T=%.12f closing=%.6e phase_fixed_residual=%.6e I_span=%.6e D_span=%.6e coeffs=%s\n",
            success, elapsed, T_sol, final_closing, final_phase_residual,
            final_spans.i_span, final_spans.d_span, sol_path)

    push!(rows, (
        orbit_id = id,
        J = J,
        K = K,
        L = L,
        m = m,
        coeff_projected = coeff_path,
        coeff_solution = sol_path,
        T_guess = Tguess,
        norm_guess = norm(x0),
        shear_guess = shear(x0, model),
        closing_guess = initial_closing,
        phase_fixed_residual_guess = initial_phase_residual,
        I_span_guess = initial_spans.i_span,
        D_span_guess = initial_spans.d_span,
        hook_success = success,
        elapsed_seconds = elapsed,
        T_solution = T_sol,
        norm_solution = norm(x_sol),
        shear_solution = shear(x_sol, model),
        closing_solution = final_closing,
        phase_fixed_residual_solution = final_phase_residual,
        I_span_solution = final_spans.i_span,
        D_span_solution = final_spans.d_span,
    ))
end

summary = DataFrame(rows)
summary_path = joinpath(outdir, "direct_hookstep_po_summary_J$(J)_K$(K)_L$(L).csv")
CSV.write(summary_path, summary)
@printf("\nWrote summary: %s\n", summary_path)

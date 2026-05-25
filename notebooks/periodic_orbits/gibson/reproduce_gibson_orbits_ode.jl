# -*- coding: utf-8 -*-
# ---
# jupyter:
#   jupytext:
#     text_representation:
#       extension: .jl
#       format_name: percent
#       format_version: '1.3'
#       jupytext_version: 1.17.2
#   kernelspec:
#     display_name: Julia 1.11
#     language: julia
#     name: julia-1.11
# ---

# %% [markdown]
# # Reproduce Gibson Periodic Orbits With the ODE Model
#
# This is an initial bridge from the DNS periodic-orbit data in
# `orbits-1-4-Re200-2pi1pi.tgz` to the CloudAtlas ODE model.
#
# The script:
# 1. extracts the four DNS `ubest.nc` orbit states,
# 2. builds the ODE model at `Re=200`, `alpha=1`, `gamma=2`, with isotropy
#    `<sxyz, sztxz>`,
# 3. projects each DNS orbit state into the ODE basis,
# 4. measures the one-period ODE closing error, and
# 5. optionally refines the projected guess with `PeriodicOrbits.OptimizedShooting`.
#
# Useful environment overrides:
# - `GIBSON_JKL=1x2x5`
# - `GIBSON_ORBIT_IDS=1,2,3,4`
# - `GIBSON_REFINE=true` to run the costly `PeriodicOrbits` refinement
# - `GIBSON_REFINER=periodicorbits` or `GIBSON_REFINER=collocation`
# - `GIBSON_FORCE_REFINE=true` to bypass the refinement cost guard
# - `GIBSON_REFINE_COST_LIMIT_SECONDS=600`
# - `GIBSON_SHOOTING_N=2`
# - `GIBSON_SHOOTING_DT=1e-3`
# - `GIBSON_SHOOTING_MAXITERS=50`
# - `GIBSON_COLLOCATION_NTST=20`
# - `GIBSON_COLLOCATION_DEGREE=3`
# - `GIBSON_COLLOCATION_SEED=dns` to seed collocation from projected DNS snapshots
# - `GIBSON_GENERATE_DNS_SERIES=true`
# - `GIBSON_DNS_SNAPSHOTS=31`
# - `GIBSON_DNS_SYMMS=/path/to/symm_E.asc`
# - `GIBSON_ODE_OUT_DIR=/tmp/gibson_ode_attempt`

# %%
if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "..", "..", ".."))
end

# %%
using CloudAtlas
import BifurcationKit as BK
using ChannelflowWrapper
using DifferentialEquations
using LinearAlgebra
using PeriodicOrbits
using Printf

# %%
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

# %%
const HERE = @__DIR__
archive = joinpath(HERE, "orbits-1-4-Re200-2pi1pi.tgz")
isfile(archive) || error("Missing Gibson orbit archive: $archive")

outdir = abspath(get(ENV, "GIBSON_ODE_OUT_DIR", joinpath(HERE, "ode_reproduction_attempt")))
extract_dir = joinpath(outdir, "dns_orbits")
mkpath(extract_dir)

Re = parse_float_env("GIBSON_RE", 200.0)
alpha = parse_float_env("GIBSON_ALPHA", 1.0)
gamma = parse_float_env("GIBSON_GAMMA", 2.0)
J, K, L = parse_jkl_env("GIBSON_JKL", (1, 2, 5))
orbit_ids = parse_orbit_ids_env("GIBSON_ORBIT_IDS", [1, 2, 3, 4])

normalize_basis = parse_bool_env("GIBSON_NORMALIZE", true)
project_normalized = parse_bool_env("GIBSON_PROJECT_NRM", normalize_basis)
do_refine = parse_bool_env("GIBSON_REFINE", false)
refiner = lowercase(strip(get(ENV, "GIBSON_REFINER", "periodicorbits")))
refiner in ("periodicorbits", "collocation") || error("GIBSON_REFINER must be 'periodicorbits' or 'collocation'")
force_refine = parse_bool_env("GIBSON_FORCE_REFINE", false)
refine_cost_limit_seconds = parse_float_env("GIBSON_REFINE_COST_LIMIT_SECONDS", 600.0)

solver_abstol = parse_float_env("GIBSON_SOLVER_ABSTOL", 1e-9)
solver_reltol = parse_float_env("GIBSON_SOLVER_RELTOL", 1e-9)
shooting_dt = parse_float_env("GIBSON_SHOOTING_DT", 1e-3)
shooting_n = parse_int_env("GIBSON_SHOOTING_N", 2)
shooting_maxiters = parse_int_env("GIBSON_SHOOTING_MAXITERS", 50)
shooting_abstol = parse_float_env("GIBSON_SHOOTING_ABSTOL", 1e-8)
shooting_reltol = parse_float_env("GIBSON_SHOOTING_RELTOL", 1e-8)
collocation_ntst = parse_int_env("GIBSON_COLLOCATION_NTST", 20)
collocation_degree = parse_int_env("GIBSON_COLLOCATION_DEGREE", 3)
collocation_maxiters = parse_int_env("GIBSON_COLLOCATION_MAXITERS", 10)
collocation_tol = parse_float_env("GIBSON_COLLOCATION_TOL", 1e-8)
collocation_verbose = parse_bool_env("GIBSON_COLLOCATION_VERBOSE", true)
collocation_seed = lowercase(strip(get(ENV, "GIBSON_COLLOCATION_SEED", "ode")))
collocation_seed in ("ode", "dns") || error("GIBSON_COLLOCATION_SEED must be 'ode' or 'dns'")
generate_dns_series = parse_bool_env("GIBSON_GENERATE_DNS_SERIES", false)
dns_snapshots = parse_int_env("GIBSON_DNS_SNAPSHOTS", collocation_ntst * collocation_degree + 1)
dns_series_label = strip(get(ENV, "GIBSON_DNS_LABEL", "u"))
dns_symms = strip(get(ENV, "GIBSON_DNS_SYMMS", ""))
dns_dt = parse_float_env("GIBSON_DNS_DT", 0.03125)

@printf("Output directory: %s\n", outdir)
@printf("ODE model: Re=%.6g alpha=%.6g gamma=%.6g JKL=(%d,%d,%d)\n", Re, alpha, gamma, J, K, L)
@printf("Orbit ids: %s\n", join(orbit_ids, ", "))
if do_refine
    @printf("Refiner: %s\n", refiner)
    refiner == "collocation" && @printf("Collocation seed: %s\n", collocation_seed)
    @printf("Refinement cost guard: %.1f seconds%s\n",
            refine_cost_limit_seconds, force_refine ? " (forced)" : "")
end

# %%
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

# %%
sx, sy, sz, tx, tz = halfbox_symmetries()
H = [sx * sy * sz, sz * tx * tz]
model = ODEModel(alpha, gamma, J, K, L, H; normalize = normalize_basis)
m = length(model)
@printf("Model dimension: %d\n", m)

# %%
function project_orbit_state(model::ODEModel, orbit_id::Int, outdir::AbstractString)
    src = orbit_ubest(orbit_id)
    isfile(src) || error("Missing orbit state: $src")

    workdir = joinpath(outdir, "orbit$(orbit_id)")
    mkpath(workdir)
    coeff_path = joinpath(workdir, "x_projected_J$(J)_K$(K)_L$(L).asc")
    kwargs = project_normalized ? (nrm = true,) : NamedTuple()
    raw = ChannelflowWrapper.field2coeff(model.ijkl, src, coeff_path; workdir = workdir, kwargs...)
    x = as_vector(raw)
    length(x) == length(model) || error("Projected length $(length(x)) != model dimension $(length(model))")
    return x, coeff_path
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

function flowfield_sort_key(path::AbstractString, label::AbstractString)
    base = basename(path)
    m = match(Regex("^" * label * "([0-9]+(?:\\.[0-9]+)?)\\.nc\$"), base)
    m === nothing && return Inf
    return parse(Float64, m.captures[1])
end

function dns_series_dir(orbit_id::Int, outdir::AbstractString)
    return joinpath(outdir, "orbit$(orbit_id)", "dns_series")
end

function dns_series_files(orbit_id::Int, outdir::AbstractString; label::AbstractString = dns_series_label)
    dir = dns_series_dir(orbit_id, outdir)
    isdir(dir) || return String[]
    files = filter(path -> isfile(path) &&
                         endswith(path, ".nc") &&
                         startswith(basename(path), label),
                   joinpath.(Ref(dir), readdir(dir)))
    sort(files; by = path -> flowfield_sort_key(path, label))
end

function ensure_dns_series(orbit_id::Int, Tguess::Real, outdir::AbstractString)
    dir = dns_series_dir(orbit_id, outdir)
    files = dns_series_files(orbit_id, outdir)
    if length(files) >= max(2, dns_snapshots - 1)
        return files
    end
    generate_dns_series || error(
        "DNS series for orbit $orbit_id not found in $dir. " *
        "Set GIBSON_GENERATE_DNS_SERIES=true or place $(dns_series_label)*.nc files there."
    )
    mkpath(dir)
    symms = isempty(dns_symms) ? default_symm_file(outdir) : abspath(dns_symms)
    isfile(symms) || error("DNS symmetry file not found: $symms")
    nsave = max(dns_snapshots, 2)
    dT = Tguess / (nsave - 1)
    @printf("  generating DNS series: snapshots=%d T=%.12f dT=%.12f out=%s\n", nsave, Tguess, dT, dir)
    ChannelflowWrapper.simulateflow(
        orbit_ubest(orbit_id);
        np0 = 4,
        np1 = 1,
        R = Re,
        symms = symms,
        T = Tguess,
        dT = dT,
        dt = dns_dt,
        o = dir,
        l = dns_series_label,
        I = orbit_ubest(orbit_id),
    )
    files = dns_series_files(orbit_id, outdir)
    length(files) >= 2 || error("simulateflow did not produce at least two $(dns_series_label)*.nc files in $dir")
    return files
end

function project_dns_series(model::ODEModel, orbit_id::Int, Tguess::Real, outdir::AbstractString)
    files = ensure_dns_series(orbit_id, Tguess, outdir)
    coeff_dir = joinpath(outdir, "orbit$(orbit_id)", "dns_series_projected_J$(J)_K$(K)_L$(L)")
    mkpath(coeff_dir)
    xs = Vector{Vector{Float64}}()
    for (i, field) in enumerate(files)
        coeff_path = joinpath(coeff_dir, replace(basename(field), ".nc" => ".asc"))
        raw = ChannelflowWrapper.field2coeff(model.ijkl, field, coeff_path; workdir = coeff_dir,
                                             (project_normalized ? (nrm = true,) : NamedTuple())...)
        x = as_vector(raw)
        length(x) == length(model) || error("Projected length $(length(x)) != model dimension $(length(model)) for $field")
        push!(xs, x)
        @printf("    projected DNS snapshot %d/%d: %s\n", i, length(files), basename(field))
    end
    times = collect(range(0.0, Tguess; length = length(xs)))
    return times, xs
end

function periodic_linear_interpolant(times::AbstractVector, xs::Vector{Vector{Float64}}, period::Real)
    function interp(t::Real)
        τ = mod(Float64(t), Float64(period))
        if τ <= times[1] || τ >= times[end]
            return xs[1]
        end
        j = searchsortedlast(times, τ)
        j = clamp(j, 1, length(times) - 1)
        θ = (τ - times[j]) / (times[j + 1] - times[j])
        return (1 - θ) .* xs[j] .+ θ .* xs[j + 1]
    end
    return interp
end

function closing_residual(model::ODEModel, x0::AbstractVector, T::Real; Re::Real)
    sol = integrate_flow(model, collect(x0), (0.0, T); R = Re, saveat = [T])
    if sol.retcode != ReturnCode.Success
        return Inf
    end
    return norm(sol.u[end] .- x0)
end

function cloudatlas_dynamical_system(model::ODEModel, x0::AbstractVector; Re::Real)
    function rhs!(du, u, p, t)
        du .= model.f(u, p)
        return nothing
    end
    return CoupledODEs(
        rhs!,
        collect(x0),
        Re;
        diffeq = (abstol = solver_abstol, reltol = solver_reltol),
    )
end

function ode_solution(model::ODEModel, x0::AbstractVector, T::Real; Re::Real)
    function rhs!(du, u, p, t)
        du .= model.f(u, p[1])
        return nothing
    end
    prob = ODEProblem(rhs!, collect(x0), (0.0, T), [Float64(Re)])
    saveat = LinRange(0.0, T, max(2, collocation_ntst * collocation_degree + 1))
    return solve(prob, Tsit5(); abstol = solver_abstol, reltol = solver_reltol, saveat = saveat)
end

function refine_with_periodicorbits(model::ODEModel, x0::AbstractVector, Tguess::Real; Re::Real)
    ds = cloudatlas_dynamical_system(model, x0; Re = Re)
    ig = InitialGuess(collect(x0), Tguess)
    alg = PeriodicOrbits.OptimizedShooting(
        Δt = shooting_dt,
        n = shooting_n,
        nonlinear_solve_kwargs = (
            abstol = shooting_abstol,
            reltol = shooting_reltol,
            maxiters = shooting_maxiters,
        ),
    )
    return periodic_orbit(ds, alg, ig)
end

function refine_with_collocation(model::ODEModel, x0::AbstractVector, Tguess::Real, orbit_id::Int, outdir::AbstractString; Re::Real)
    F(x, p) = model.f(x, p[1])
    J(x, p) = model.Df(x, p[1])
    prob_vf = BK.BifurcationProblem(
        F,
        collect(x0),
        [Float64(Re)],
        1;
        J = J,
        record_from_solution = (x, p; k...) -> norm(x),
    )

    orbit_seed = if collocation_seed == "dns"
        times, xs = project_dns_series(model, orbit_id, Tguess, outdir)
        periodic_linear_interpolant(times, xs, Tguess)
    else
        sol_ode = ode_solution(model, x0, Tguess; Re = Re)
        sol_ode.retcode == ReturnCode.Success || error("ODE seed integration failed with retcode $(sol_ode.retcode)")
        t0 = sol_ode.t[begin]
        t -> sol_ode(t0 + t)
    end

    coll_seed = BK.PeriodicOrbitOCollProblem(
        collocation_ntst,
        collocation_degree;
        jacobian = BK.FullSparse(),
    )
    coll = BK.PeriodicOrbitOCollProblem(
        collocation_ntst,
        collocation_degree;
        prob_vf = prob_vf,
        N = length(model),
        ϕ = zeros(length(model) * (1 + collocation_degree * collocation_ntst)),
        xπ = zeros(length(model) * (1 + collocation_degree * collocation_ntst)),
        jacobian = BK.FullSparse(),
    )
    ci = BK.generate_solution(coll, orbit_seed, Tguess)
    BK.updatesection!(coll, ci, [Float64(Re)])

    residual0 = norm(BK.residual(coll, ci, [Float64(Re)]))
    @printf("  collocation seed: Ntst=%d degree=%d unknowns=%d residual=%.6e\n",
            collocation_ntst, collocation_degree, length(ci), residual0)

    newton_options = BK.NewtonPar(
        tol = collocation_tol,
        max_iterations = collocation_maxiters,
        verbose = collocation_verbose,
        linsolver = BK.COPLS(),
        linesearch = true,
    )
    sol = BK.newton(coll, ci, newton_options)
    residual = norm(BK.residual(coll, sol.u, [Float64(Re)]))
    return sol, coll, residual0, residual
end

function estimated_periodicorbits_seconds(residual_seconds::Real, m::Int, maxiters::Int)
    # OptimizedShooting uses NonlinearSolve Levenberg-Marquardt on m+1 unknowns.
    # With finite-difference Jacobians this is roughly one residual evaluation per
    # unknown per nonlinear iteration, plus overhead and trial steps.
    return residual_seconds * (m + 2) * maxiters
end

# %%
summary_path = joinpath(outdir, "ode_reproduction_summary_J$(J)_K$(K)_L$(L).csv")
open(summary_path, "w") do io
    println(io, join([
        "orbit_id", "J", "K", "L", "m", "T_guess", "norm_guess", "shear_guess",
        "residual_guess", "residual_seconds", "estimated_refine_seconds",
        "po_found", "T_refined", "norm_refined", "shear_refined",
        "residual_refined", "refine_skipped", "coeff_path",
    ], ","))

    for id in orbit_ids
        Tguess = orbit_period(id)
        @printf("\nOrbit %d: DNS period %.12f\n", id, Tguess)

        x0, coeff_path = project_orbit_state(model, id, outdir)
        guess_norm = norm(x0)
        guess_shear = shear(x0, model)
        guess_residual = NaN
        residual_seconds = @elapsed begin
            guess_residual = closing_residual(model, x0, Tguess; Re = Re)
        end
        estimated_refine_seconds =
            estimated_periodicorbits_seconds(residual_seconds, length(model), shooting_maxiters)
        @printf("  projected: |x|=%.6e shear=%.9f closing_residual=%.6e residual_time=%.2f s\n",
                guess_norm, guess_shear, guess_residual, residual_seconds)

        po_found = false
        T_refined = NaN
        norm_refined = NaN
        shear_refined = NaN
        residual_refined = NaN
        refine_skipped = false

        if do_refine
            if refiner == "periodicorbits"
                @printf("  PeriodicOrbits cost estimate: %.1f s for maxiters=%d at m=%d\n",
                        estimated_refine_seconds, shooting_maxiters, length(model))
                if !force_refine && estimated_refine_seconds > refine_cost_limit_seconds
                    refine_skipped = true
                    @printf("  skipping PeriodicOrbits refinement; set GIBSON_FORCE_REFINE=true to override\n")
                else
                    @printf("  PeriodicOrbits.OptimizedShooting: n=%d DeltaT=%.3e maxiters=%d\n",
                            shooting_n, shooting_dt, shooting_maxiters)
                    elapsed = @elapsed begin
                        po = refine_with_periodicorbits(model, x0, Tguess; Re = Re)
                    end
                    if po === nothing
                        @printf("  no periodic orbit returned after %.2f s\n", elapsed)
                    else
                        x_refined = collect(po.points[1])
                        T_refined = Float64(po.T)
                        norm_refined = norm(x_refined)
                        shear_refined = shear(x_refined, model)
                        residual_refined = closing_residual(model, x_refined, T_refined; Re = Re)
                        po_found = isfinite(residual_refined)

                        sol_path = joinpath(outdir, "orbit$(id)", "x_periodicorbits_J$(J)_K$(K)_L$(L).asc")
                        CloudAtlas.save(x_refined, sol_path)
                        @printf("  refined: T=%.12f |x|=%.6e shear=%.9f closing_residual=%.6e elapsed=%.2f s\n",
                                T_refined, norm_refined, shear_refined, residual_refined, elapsed)
                    end
                end
            elseif refiner == "collocation"
                @printf("  BifurcationKit collocation Newton: Ntst=%d degree=%d maxiters=%d\n",
                        collocation_ntst, collocation_degree, collocation_maxiters)
                elapsed = @elapsed begin
                    sol_coll, coll, residual0_coll, residual_coll =
                        refine_with_collocation(model, x0, Tguess, id, outdir; Re = Re)
                end
                if BK.converged(sol_coll)
                    x_refined = collect(sol_coll.u[1:m])
                    T_refined = Float64(sol_coll.u[end])
                    norm_refined = norm(x_refined)
                    shear_refined = shear(x_refined, model)
                    residual_refined = closing_residual(model, x_refined, T_refined; Re = Re)
                    po_found = isfinite(residual_refined)

                    sol_path = joinpath(outdir, "orbit$(id)", "x_collocation_J$(J)_K$(K)_L$(L).asc")
                    CloudAtlas.save(x_refined, sol_path)
                    @printf("  collocation converged: residual %.6e -> %.6e T=%.12f closing_residual=%.6e elapsed=%.2f s\n",
                            residual0_coll, residual_coll, T_refined, residual_refined, elapsed)
                else
                    @printf("  collocation did not converge: residual %.6e -> %.6e after %d Newton steps, elapsed=%.2f s\n",
                            residual0_coll, residual_coll, sol_coll.itnewton, elapsed)
                end
            end
        end

        row = [
            id, J, K, L, m, Tguess, guess_norm, guess_shear, guess_residual,
            residual_seconds, estimated_refine_seconds, po_found, T_refined,
            norm_refined, shear_refined, residual_refined, refine_skipped, coeff_path,
        ]
        println(io, join(row, ","))
        flush(io)
    end
end

@printf("\nWrote summary: %s\n", summary_path)

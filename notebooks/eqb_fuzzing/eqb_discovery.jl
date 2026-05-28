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

# %%
if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "..", ".."))
end

# %%
using CloudAtlas
using LinearAlgebra
using Random
using Dates
using Serialization
using Statistics
using Base.Threads

# Top-level defaults (override via ENV vars below)
const DEFAULT_RE = 400.0
const DEFAULT_LX = 10.0
const DEFAULT_LZ = 6.0
const DEFAULT_ATTEMPTS_LEVEL1 = 100_000
const DEFAULT_APPEND_ATTEMPTS_LEVEL1 = 0
const DEFAULT_RESUME_FROM_SAVED = true
const DEFAULT_LADDER_PERTURB_TRIALS_EARLY = 10_000
const DEFAULT_LADDER_PERTURB_TRIALS_LATE = 500
const DEFAULT_LADDER_PERTURB_SWITCH_JKL = (2, 4, 5)
const DEFAULT_LADDER_PERTURB_SCALE = 0.05
const DEFAULT_HOMOTOPY_ENABLED = true
const DEFAULT_HOMOTOPY_INITIAL_DMU = 0.1
const DEFAULT_HOMOTOPY_MIN_DMU = 1e-3
const DEFAULT_HOMOTOPY_MAX_DMU = 0.2
const DEFAULT_HOMOTOPY_GROWTH = 1.4
const DEFAULT_HOMOTOPY_SHRINK = 0.5
const DEFAULT_HOMOTOPY_MAX_FAILURES = 20
const DEFAULT_XNORM = 0.4
const DEFAULT_SHEAR_TARGET = 5.0
const DEFAULT_SHEAR_TOL = 0.1
const DEFAULT_SHEAR_MIN = 3.0
const DEFAULT_SHEAR_MAX = 7.0
const DEFAULT_NORM_THRESHOLD = 1e-3

# %% [markdown]
# # Equilibrium Discovery (Parallel Fuzzing + Ladder Promotion)
#
# Finds equilibrium solutions (`tw=false`) by:
# 1. Fuzzing many Hookstep solves at the coarsest discretization.
# 2. Deduplicating converged solutions.
# 3. Promoting the unique set up a discretization ladder via projection + Hookstep.
#
# Per-symmetry outputs are written to separate directories. Each symmetry directory contains:
# - `solution_statistics.csv`
# - `jkl_J_K_L/solutions_summary.csv`
# - `jkl_J_K_L/solutions.bin`
# - `jkl_J_K_L/solN.asc`

# %%
function parse_bool_env(name::AbstractString, default::Bool)
    raw = get(ENV, name, default ? "true" : "false")
    v = lowercase(strip(raw))
    if v in ("1", "true", "t", "yes", "y")
        return true
    elseif v in ("0", "false", "f", "no", "n")
        return false
    end
    error("Invalid boolean for ENV[$name]='$raw'")
end

function parse_int_env(name::AbstractString, default::Int)
    raw = get(ENV, name, string(default))
    return parse(Int, raw)
end

function parse_float_env(name::AbstractString, default::Float64)
    raw = get(ENV, name, string(default))
    return parse(Float64, raw)
end

function parse_ladder_env(raw::AbstractString, default)
    s = strip(raw)
    isempty(s) && return default
    vals = Tuple{Int, Int, Int}[]
    for token in split(s, ",")
        t = strip(token)
        isempty(t) && continue
        parts = split(lowercase(t), "x")
        length(parts) == 3 || error("Invalid ladder token '$t' (expected JxKxL)")
        push!(vals, (parse(Int, parts[1]), parse(Int, parts[2]), parse(Int, parts[3])))
    end
    isempty(vals) && return default
    return vals
end

function parse_jkl_env(name::AbstractString, default::NTuple{3, Int})
    raw = get(ENV, name, "")
    s = strip(raw)
    isempty(s) && return default
    parts = split(lowercase(s), "x")
    length(parts) == 3 || error("Invalid JxKxL tuple for ENV[$name]='$raw'")
    return (parse(Int, parts[1]), parse(Int, parts[2]), parse(Int, parts[3]))
end

# %% [markdown]
# ## Configuration

# %%
# Domain
Lx = parse_float_env("EQB_LX", DEFAULT_LX)
Lz = parse_float_env("EQB_LZ", DEFAULT_LZ)
α = parse_float_env("EQB_ALPHA", 2π / Lx)
γ = parse_float_env("EQB_GAMMA", 2π / Lz)

# Reynolds number parameter (set this before runs)
Re = parse_float_env("EQB_RE", DEFAULT_RE)

# Discretization ladder
# NOTE: duplicate entries are preserved as requested.
discretization_ladder_default = [
    (1, 3, 5),
    (1, 4, 5),
    (2, 4, 5),
    (2, 4, 6),
    (2, 4, 7),
    (2, 4, 8),
    (2, 4, 9),
    (3, 4, 9),
    (3, 5, 9),
    (3, 5, 9),
    (3, 5, 10),
    (3, 5, 11),
]
discretization_ladder = parse_ladder_env(get(ENV, "EQB_LADDER", ""), discretization_ladder_default)

# Coarsest-level fuzzing attempts
attempts_level1 = parse_int_env("EQB_ATTEMPTS", DEFAULT_ATTEMPTS_LEVEL1)
append_attempts_level1 = parse_int_env("EQB_APPEND_ATTEMPTS", DEFAULT_APPEND_ATTEMPTS_LEVEL1)
resume_from_saved = parse_bool_env("EQB_RESUME", DEFAULT_RESUME_FROM_SAVED)

# Projection refinement settings
ladder_perturb_trials_early = parse_int_env(
    "EQB_LADDER_PERTURB_TRIALS_EARLY",
    DEFAULT_LADDER_PERTURB_TRIALS_EARLY,
)
ladder_perturb_trials_late = parse_int_env(
    "EQB_LADDER_PERTURB_TRIALS_LATE",
    DEFAULT_LADDER_PERTURB_TRIALS_LATE,
)
ladder_perturb_switch_jkl = parse_jkl_env(
    "EQB_LADDER_PERTURB_SWITCH_JKL",
    DEFAULT_LADDER_PERTURB_SWITCH_JKL,
)
ladder_perturb_scale = parse_float_env("EQB_LADDER_PERTURB_SCALE", DEFAULT_LADDER_PERTURB_SCALE)
ladder_perturb_switch_idx = something(findfirst(==(ladder_perturb_switch_jkl), discretization_ladder), length(discretization_ladder))

# Residual homotopy fallback for ODE promotion. Given projected x0 at the new
# resolution, solve f(x) - (1-mu)f(x0) = 0 from mu=0 to mu=1.
homotopy_enabled = parse_bool_env("EQB_HOMOTOPY", DEFAULT_HOMOTOPY_ENABLED)
homotopy_initial_dmu = parse_float_env("EQB_HOMOTOPY_INITIAL_DMU", DEFAULT_HOMOTOPY_INITIAL_DMU)
homotopy_min_dmu = parse_float_env("EQB_HOMOTOPY_MIN_DMU", DEFAULT_HOMOTOPY_MIN_DMU)
homotopy_max_dmu = parse_float_env("EQB_HOMOTOPY_MAX_DMU", DEFAULT_HOMOTOPY_MAX_DMU)
homotopy_growth = parse_float_env("EQB_HOMOTOPY_GROWTH", DEFAULT_HOMOTOPY_GROWTH)
homotopy_shrink = parse_float_env("EQB_HOMOTOPY_SHRINK", DEFAULT_HOMOTOPY_SHRINK)
homotopy_max_failures = parse_int_env("EQB_HOMOTOPY_MAX_FAILURES", DEFAULT_HOMOTOPY_MAX_FAILURES)

# Hookstep parameters
hookparams = SearchParams(
    ftol = 1e-8,
    xtol = 1e-10,
    δ = 0.02,
    Nnewton = 20,
    Nhook = 4,
    Nmusearch = 6,
    verbosity = 0,
)

# Guessing strategy (shear band, high target shear)
guess_strategy = :shear_band
xnorm = parse_float_env("EQB_XNORM", DEFAULT_XNORM)
shear_target = parse_float_env("EQB_SHEAR_TARGET", DEFAULT_SHEAR_TARGET)
shear_tol = parse_float_env("EQB_SHEAR_TOL", DEFAULT_SHEAR_TOL)
shear_min = parse_float_env("EQB_SHEAR_MIN", DEFAULT_SHEAR_MIN)
shear_max = parse_float_env("EQB_SHEAR_MAX", DEFAULT_SHEAR_MAX)

# Dedup tolerances
fp_tol = (
    cx = 1e-3,
    cz = 1e-3,
    nm = 2e-2,
    shear = 2e-2,
)

# Acceptance thresholds
norm_threshold = parse_float_env("EQB_NORM_THRESHOLD", DEFAULT_NORM_THRESHOLD)

# Output root
default_out = joinpath(@__DIR__, "eqb_discovery_re$(round(Int, Re))")
out_dir = get(ENV, "EQB_OUT_DIR", default_out)
mkpath(out_dir)

# Symmetry groups
sx, sy, sz, tx, tz = CloudAtlas.halfbox_symmetries()

symmetry_groups = [
    (name = "A", desc = "<sxyz, txz>", H = [sx * sy * sz, tx * tz]),
    (name = "B", desc = "<sxy, sz>", H = [sx * sy, sz]),
    (name = "C", desc = "<sxytz, sz>", H = [sx * sy * tz, sz]),
    (name = "D", desc = "<sxy, sztx>", H = [sx * sy, sz * tx]),
    (name = "E", desc = "<sxyz, sztxz>", H = [sx * sy * sz, sz * tx * tz]),
    (name = "F", desc = "<sxy, sz, txz>", H = [sx * sy, sz, tx * tz]),
    (name = "G", desc = "<sxyz>", H = [sx * sy * sz]),
    (name = "SigmaGHC", desc = "<sztx, sxy*txz>", H = [sz * tx, sx * sy * tx * tz]),
    (name = "ThetaGHC", desc = "<sxy, sztx, txz>", H = [sx * sy, sz * tx, tx * tz]),
    (name = "Theta6", desc = "<sxyz*tz>", H = [sx * sy * sz * tz]),
    (name = "K", desc = "<sxy, sz> (Sharma K; alias of B)", H = [sx * sy, sz]),
    (name = "Rxz", desc = "<sxyz, sztxz> (canonical GHC R_xz; alias of E)", H = [sx * sy * sz, sz * tx * tz]),
]

selected_symmetry_names = begin
    raw = strip(get(ENV, "EQB_SYMMETRIES", ""))
    if isempty(raw)
        String[]
    else
        requested = [strip(x) for x in split(raw, ",") if !isempty(strip(x))]
        unique!(requested)
        requested
    end
end
if !isempty(selected_symmetry_names)
    by_name = Dict(s.name => s for s in symmetry_groups)
    missing = [name for name in selected_symmetry_names if !haskey(by_name, name)]
    isempty(missing) || error("Unknown symmetry names in EQB_SYMMETRIES: $(join(missing, ", "))")
    symmetry_groups = [by_name[name] for name in selected_symmetry_names]
end

# %%
function save_level_summary(path::AbstractString, solutions, model)
    open(path, "w") do io
        println(io, "id,norm,shear")
        for (i, ξ) in enumerate(solutions)
            x, _, _ = extract_components(ξ, model)
            println(io, "$(i),$(norm(x)),$(shear(x, model))")
        end
    end
end

function write_solution_asc_files(level_dir::AbstractString, solutions, model)
    for (i, ξ) in enumerate(solutions)
        x, _, _ = extract_components(ξ, model)
        CloudAtlas.save(x, joinpath(level_dir, "sol$(i).asc"))
    end
end

function project_solution(ξ_from, model_from::ODEModel, model_to::ODEModel)
    x_from, _, _ = extract_components(ξ_from, model_from)
    x_to = changebasis(x_from, model_from.ijkl, model_to.ijkl)
    return state_to_xi(model_to, ODEState(x_to))
end

function merge_unique_solutions(existing, additions, model; fp_tol)
    fps = SolutionFingerprint[]
    merged = Vector{Vector{Float64}}()
    for ξ in existing
        fp = fingerprint(model, ξ)
        if is_distinct(fp, fps; tol = fp_tol)
            push!(fps, fp)
            push!(merged, ξ)
        end
    end
    for ξ in additions
        fp = fingerprint(model, ξ)
        if is_distinct(fp, fps; tol = fp_tol)
            push!(fps, fp)
            push!(merged, ξ)
        end
    end
    return merged
end

function fuzz_eqb_solutions(model::ODEModel, Re::Real;
    n_attempts::Int = 1000,
    xnorm::Real = 0.4,
    strategy::Symbol = :shear_band,
    shear_target::Real = 5.0,
    shear_tol::Real = 0.1,
    shear_min::Real = 3.0,
    shear_max::Real = 7.0,
    hookparams = SearchParams(),
    norm_threshold::Real = 1e-3,
)
    solutions = Vector{Vector{Float64}}()
    fingerprints = Vector{SolutionFingerprint}()

    data_lock = ReentrantLock()
    io_lock = ReentrantLock()

    rngs = [MersenneTwister(0xEA71 + i) for i in 1:Threads.maxthreadid()]
    progress = Threads.Atomic{Int}(0)
    hookstep_converged = Threads.Atomic{Int}(0)
    accepted_postfilter = Threads.Atomic{Int}(0)
    rejected_norms = Float64[]
    rejected_shears = Float64[]
    progress_every = max(1, n_attempts ÷ 100)

    @threads for attempt in 1:n_attempts
        tid = threadid()
        rng = tid <= length(rngs) ? rngs[tid] : Random.default_rng()

        ξ_guess = build_guess(model, rng;
            strategy = strategy,
            xnorm = xnorm,
            target = shear_target,
            tol = shear_tol,
            shear_min = shear_min,
            shear_max = shear_max,
        )

        f = x -> model.f(x, Re)
        Df = x -> model.Df(x, Re)
        ξ_star, converged = CloudAtlas.hookstepsolve(f, Df, ξ_guess, hookparams)

        if converged
            Threads.atomic_add!(hookstep_converged, 1)
            x, _, _ = extract_components(ξ_star, model)
            if norm(x) > norm_threshold
                Threads.atomic_add!(accepted_postfilter, 1)
                fp = fingerprint(model, ξ_star)
                lock(data_lock) do
                    if is_distinct(fp, fingerprints; tol = fp_tol)
                        push!(fingerprints, fp)
                        push!(solutions, ξ_star)
                        lock(io_lock) do
                            println("[Thread $(threadid())] Unique EQB: |x|=$(round(fp.nm, digits=4)), shear=$(round(fp.shear, digits=4))")
                        end
                    end
                end
            else
                lock(data_lock) do
                    push!(rejected_norms, Float64(norm(x)))
                    push!(rejected_shears, Float64(shear(x, model)))
                end
            end
        end

        done = Threads.atomic_add!(progress, 1) + 1
        if done % progress_every == 0 || done == n_attempts
            local_unique = lock(data_lock) do
                length(solutions)
            end
            lock(io_lock) do
                pct = round(100 * done / n_attempts; digits = 1)
                println("Progress: $(done)/$(n_attempts) ($(pct)%) (unique=$(local_unique))")
            end
        end
    end

    println("Done. Hookstep converged=$(hookstep_converged[]), accepted=$(accepted_postfilter[]), unique=$(length(solutions))")
    rejected_stats = summarize_rejected_convergences(rejected_norms, rejected_shears)
    stats = (
        attempted_seeds = n_attempts,
        hookstep_converged = hookstep_converged[],
        accepted_postfilter = accepted_postfilter[],
        rejected_postfilter = rejected_stats.rejected_postfilter,
        rejected_norm_min = rejected_stats.rejected_norm_min,
        rejected_norm_median = rejected_stats.rejected_norm_median,
        rejected_norm_max = rejected_stats.rejected_norm_max,
        rejected_shear_min = rejected_stats.rejected_shear_min,
        rejected_shear_median = rejected_stats.rejected_shear_median,
        rejected_shear_max = rejected_stats.rejected_shear_max,
        unique_solutions = length(solutions),
        promotions_reconverged = 0,
    )
    return solutions, fingerprints, stats
end

function refine_projected_solutions(model_from::ODEModel, model_to::ODEModel, Re::Real;
    solutions_from,
    hookparams,
    norm_threshold::Real = 1e-3,
    perturb_trials::Int = 1,
    perturb_scale::Real = 0.0,
)
    refined = Vector{Vector{Float64}}()
    fingerprints = Vector{SolutionFingerprint}()
    data_lock = ReentrantLock()
    io_lock = ReentrantLock()

    attempted = length(solutions_from)
    hookstep_converged = Threads.Atomic{Int}(0)
    accepted_postfilter = Threads.Atomic{Int}(0)

    rngs = [MersenneTwister(0xBEEF + i) for i in 1:Threads.maxthreadid()]
    progress = Threads.Atomic{Int}(0)
    rejected_norms = Float64[]
    rejected_shears = Float64[]
    progress_every = max(1, attempted ÷ 100)

    @threads for i in eachindex(solutions_from)
        tid = threadid()
        rng = tid <= length(rngs) ? rngs[tid] : Random.default_rng()

        ξ_base = project_solution(solutions_from[i], model_from, model_to)

        for trial in 1:perturb_trials
            ξ_guess = if trial == 1 || perturb_scale == 0.0
                ξ_base
            else
                x, _, _ = extract_components(ξ_base, model_to)
                noise = (rand(rng, length(x)) .- 0.5) .* (2 * perturb_scale)
                state_to_xi(model_to, ODEState(x .+ noise))
            end

            f = x -> model_to.f(x, Re)
            Df = x -> model_to.Df(x, Re)
            ξ_star, converged = CloudAtlas.hookstepsolve(f, Df, ξ_guess, hookparams)
            if converged
                Threads.atomic_add!(hookstep_converged, 1)
                x, _, _ = extract_components(ξ_star, model_to)
                if norm(x) > norm_threshold
                    Threads.atomic_add!(accepted_postfilter, 1)
                    fp = fingerprint(model_to, ξ_star)
                    lock(data_lock) do
                        if is_distinct(fp, fingerprints; tol = fp_tol)
                            push!(fingerprints, fp)
                            push!(refined, ξ_star)
                        end
                    end
                else
                    lock(data_lock) do
                        push!(rejected_norms, Float64(norm(x)))
                        push!(rejected_shears, Float64(shear(x, model_to)))
                    end
                end
                break
            end
        end

        done = Threads.atomic_add!(progress, 1) + 1
        if done % progress_every == 0 || done == attempted
            local_unique = lock(data_lock) do
                length(refined)
            end
            lock(io_lock) do
                pct = round(100 * done / attempted; digits = 1)
                println("Promotion progress: $(done)/$(attempted) ($(pct)%) (unique=$(local_unique))")
            end
        end
    end

    rejected_stats = summarize_rejected_convergences(rejected_norms, rejected_shears)
    stats = (
        attempted_seeds = attempted,
        hookstep_converged = hookstep_converged[],
        accepted_postfilter = accepted_postfilter[],
        rejected_postfilter = rejected_stats.rejected_postfilter,
        rejected_norm_min = rejected_stats.rejected_norm_min,
        rejected_norm_median = rejected_stats.rejected_norm_median,
        rejected_norm_max = rejected_stats.rejected_norm_max,
        rejected_shear_min = rejected_stats.rejected_shear_min,
        rejected_shear_median = rejected_stats.rejected_shear_median,
        rejected_shear_max = rejected_stats.rejected_shear_max,
        unique_solutions = length(refined),
        promotions_reconverged = length(refined),
    )
    return refined, fingerprints, stats
end

function homotopy_promote_seed(
    ξ_base,
    model_to::ODEModel,
    Re::Real;
    hookparams,
    initial_dmu::Real,
    min_dmu::Real,
    max_dmu::Real,
    growth::Real,
    shrink::Real,
    max_failures::Int,
)
    residual0 = model_to.f(ξ_base, Re)
    μ = 0.0
    dμ = Float64(initial_dmu)
    ξ_current = copy(ξ_base)
    successes = 0
    failures = 0

    while μ < 1.0 - 10eps(Float64)
        μ_next = min(1.0, μ + dμ)
        fμ = x -> model_to.f(x, Re) .- (1.0 - μ_next) .* residual0
        Dfμ = x -> model_to.Df(x, Re)
        ξ_star, converged = CloudAtlas.hookstepsolve(fμ, Dfμ, ξ_current, hookparams)
        if converged
            ξ_current = ξ_star
            μ = μ_next
            successes += 1
            dμ = min(Float64(max_dmu), dμ * Float64(growth))
        else
            failures += 1
            dμ *= Float64(shrink)
            if dμ < min_dmu || failures > max_failures
                return (
                    converged = false,
                    ξ = ξ_current,
                    μ = μ,
                    successes = successes,
                    failures = failures,
                    final_residual = norm(model_to.f(ξ_current, Re)),
                )
            end
        end
    end

    return (
        converged = true,
        ξ = ξ_current,
        μ = μ,
        successes = successes,
        failures = failures,
        final_residual = norm(model_to.f(ξ_current, Re)),
    )
end

function refine_projected_solutions_with_homotopy(model_from::ODEModel, model_to::ODEModel, Re::Real;
    solutions_from,
    hookparams,
    norm_threshold::Real = 1e-3,
    perturb_trials::Int = 1,
    perturb_scale::Real = 0.0,
    homotopy_enabled::Bool = true,
    homotopy_initial_dmu::Real = 0.1,
    homotopy_min_dmu::Real = 1e-3,
    homotopy_max_dmu::Real = 0.2,
    homotopy_growth::Real = 1.4,
    homotopy_shrink::Real = 0.5,
    homotopy_max_failures::Int = 20,
    homotopy_summary_path::AbstractString = "",
)
    refined = Vector{Vector{Float64}}()
    fingerprints = Vector{SolutionFingerprint}()
    data_lock = ReentrantLock()
    io_lock = ReentrantLock()

    attempted = length(solutions_from)
    hookstep_converged = Threads.Atomic{Int}(0)
    accepted_postfilter = Threads.Atomic{Int}(0)
    direct_converged = Threads.Atomic{Int}(0)
    homotopy_converged = Threads.Atomic{Int}(0)
    homotopy_attempted = Threads.Atomic{Int}(0)
    homotopy_steps = Threads.Atomic{Int}(0)

    rngs = [MersenneTwister(0xBEEF + i) for i in 1:Threads.maxthreadid()]
    progress = Threads.Atomic{Int}(0)
    rejected_norms = Float64[]
    rejected_shears = Float64[]
    homotopy_rows = NamedTuple[]
    progress_every = max(1, attempted ÷ 100)

    @threads for i in eachindex(solutions_from)
        tid = threadid()
        rng = tid <= length(rngs) ? rngs[tid] : Random.default_rng()

        ξ_base = project_solution(solutions_from[i], model_from, model_to)
        accepted = false
        accepted_source = ""
        accepted_ξ = ξ_base
        final_residual = Inf
        hμ = 0.0
        hsuccesses = 0
        hfailures = 0

        for trial in 1:perturb_trials
            ξ_guess = if trial == 1 || perturb_scale == 0.0
                ξ_base
            else
                x, _, _ = extract_components(ξ_base, model_to)
                noise = (rand(rng, length(x)) .- 0.5) .* (2 * perturb_scale)
                state_to_xi(model_to, ODEState(x .+ noise))
            end

            f = x -> model_to.f(x, Re)
            Df = x -> model_to.Df(x, Re)
            ξ_star, converged = CloudAtlas.hookstepsolve(f, Df, ξ_guess, hookparams)
            if converged
                Threads.atomic_add!(hookstep_converged, 1)
                Threads.atomic_add!(direct_converged, 1)
                accepted = true
                accepted_source = "direct"
                accepted_ξ = ξ_star
                final_residual = norm(f(ξ_star))
                break
            end
        end

        if !accepted && homotopy_enabled
            Threads.atomic_add!(homotopy_attempted, 1)
            result = homotopy_promote_seed(
                ξ_base,
                model_to,
                Re;
                hookparams = hookparams,
                initial_dmu = homotopy_initial_dmu,
                min_dmu = homotopy_min_dmu,
                max_dmu = homotopy_max_dmu,
                growth = homotopy_growth,
                shrink = homotopy_shrink,
                max_failures = homotopy_max_failures,
            )
            hμ = result.μ
            hsuccesses = result.successes
            hfailures = result.failures
            final_residual = result.final_residual
            Threads.atomic_add!(homotopy_steps, result.successes)
            if result.converged
                Threads.atomic_add!(hookstep_converged, 1)
                Threads.atomic_add!(homotopy_converged, 1)
                accepted = true
                accepted_source = "homotopy"
                accepted_ξ = result.ξ
            end
        end

        if accepted
            x, _, _ = extract_components(accepted_ξ, model_to)
            if norm(x) > norm_threshold
                Threads.atomic_add!(accepted_postfilter, 1)
                fp = fingerprint(model_to, accepted_ξ)
                lock(data_lock) do
                    if is_distinct(fp, fingerprints; tol = fp_tol)
                        push!(fingerprints, fp)
                        push!(refined, accepted_ξ)
                    end
                end
            else
                lock(data_lock) do
                    push!(rejected_norms, Float64(norm(x)))
                    push!(rejected_shears, Float64(shear(x, model_to)))
                end
            end
        end

        lock(data_lock) do
            push!(homotopy_rows, (
                seed_index = i,
                status = accepted ? "accepted" : "failed",
                source = accepted_source,
                final_mu = hμ,
                homotopy_success_steps = hsuccesses,
                homotopy_failures = hfailures,
                final_residual = final_residual,
            ))
        end

        done = Threads.atomic_add!(progress, 1) + 1
        if done % progress_every == 0 || done == attempted
            local_unique = lock(data_lock) do
                length(refined)
            end
            lock(io_lock) do
                pct = round(100 * done / attempted; digits = 1)
                println("Promotion progress: $(done)/$(attempted) ($(pct)%) (unique=$(local_unique), homotopy=$(homotopy_converged[])/$(homotopy_attempted[]))")
            end
        end
    end

    if !isempty(homotopy_summary_path)
        open(homotopy_summary_path, "w") do io
            println(io, "seed_index,status,source,final_mu,homotopy_success_steps,homotopy_failures,final_residual")
            for r in sort(homotopy_rows; by = x -> x.seed_index)
                println(io, "$(r.seed_index),$(r.status),$(r.source),$(r.final_mu),$(r.homotopy_success_steps),$(r.homotopy_failures),$(r.final_residual)")
            end
        end
    end

    rejected_stats = summarize_rejected_convergences(rejected_norms, rejected_shears)
    stats = (
        attempted_seeds = attempted,
        hookstep_converged = hookstep_converged[],
        accepted_postfilter = accepted_postfilter[],
        rejected_postfilter = rejected_stats.rejected_postfilter,
        rejected_norm_min = rejected_stats.rejected_norm_min,
        rejected_norm_median = rejected_stats.rejected_norm_median,
        rejected_norm_max = rejected_stats.rejected_norm_max,
        rejected_shear_min = rejected_stats.rejected_shear_min,
        rejected_shear_median = rejected_stats.rejected_shear_median,
        rejected_shear_max = rejected_stats.rejected_shear_max,
        unique_solutions = length(refined),
        promotions_reconverged = length(refined),
        direct_converged = direct_converged[],
        homotopy_attempted = homotopy_attempted[],
        homotopy_converged = homotopy_converged[],
        homotopy_steps = homotopy_steps[],
    )
    return refined, fingerprints, stats
end

function summarize_rejected_convergences(norms::Vector{Float64}, shears::Vector{Float64})
    if isempty(norms)
        return (
            rejected_postfilter = 0,
            rejected_norm_min = NaN,
            rejected_norm_median = NaN,
            rejected_norm_max = NaN,
            rejected_shear_min = NaN,
            rejected_shear_median = NaN,
            rejected_shear_max = NaN,
        )
    end
    return (
        rejected_postfilter = length(norms),
        rejected_norm_min = minimum(norms),
        rejected_norm_median = median(norms),
        rejected_norm_max = maximum(norms),
        rejected_shear_min = minimum(shears),
        rejected_shear_median = median(shears),
        rejected_shear_max = maximum(shears),
    )
end

function rejected_fields(stats)
    has_rejected = hasproperty(stats, :rejected_postfilter)
    return (
        has_rejected ? stats.rejected_postfilter : 0,
        has_rejected ? stats.rejected_norm_min : NaN,
        has_rejected ? stats.rejected_norm_median : NaN,
        has_rejected ? stats.rejected_norm_max : NaN,
        has_rejected ? stats.rejected_shear_min : NaN,
        has_rejected ? stats.rejected_shear_median : NaN,
        has_rejected ? stats.rejected_shear_max : NaN,
    )
end

function merge_rejected_fields(a, b)
    af = rejected_fields(a)
    bf = rejected_fields(b)
    rejected = af[1] + bf[1]
    rejected == 0 && return rejected_fields((;))
    only_a = af[1] > 0 && bf[1] == 0
    only_b = bf[1] > 0 && af[1] == 0
    finite_min(x, y) = isfinite(x) && isfinite(y) ? min(x, y) : (isfinite(x) ? x : y)
    finite_max(x, y) = isfinite(x) && isfinite(y) ? max(x, y) : (isfinite(x) ? x : y)
    return (
        rejected,
        finite_min(af[2], bf[2]),
        only_a ? af[3] : (only_b ? bf[3] : NaN),
        finite_max(af[4], bf[4]),
        finite_min(af[5], bf[5]),
        only_a ? af[6] : (only_b ? bf[6] : NaN),
        finite_max(af[7], bf[7]),
    )
end

function write_group_statistics(path::AbstractString, rows)
    open(path, "w") do io
        println(io, "timestamp,level_idx,J,K,L,source,attempted_seeds,hookstep_converged,accepted_postfilter,rejected_postfilter,rejected_norm_min,rejected_norm_median,rejected_norm_max,rejected_shear_min,rejected_shear_median,rejected_shear_max,unique_solutions,promotions_reconverged")
        for r in rows
            rejected = rejected_fields(r)
            println(io,
                "$(r.timestamp),$(r.level_idx),$(r.J),$(r.K),$(r.L),$(r.source)," *
                "$(r.attempted_seeds),$(r.hookstep_converged),$(r.accepted_postfilter)," *
                "$(rejected[1]),$(rejected[2]),$(rejected[3]),$(rejected[4]),$(rejected[5]),$(rejected[6]),$(rejected[7])," *
                "$(r.unique_solutions),$(r.promotions_reconverged)"
            )
        end
    end
end

function write_markdown_summary(path::AbstractString, group_rows::Dict{String, Vector{NamedTuple}})
    open(path, "w") do io
        println(io, "# Equilibrium Discovery Summary")
        println(io)
        println(io, "Generated: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")
        println(io)
        println(io, "- Lx=$(Lx), Lz=$(Lz), alpha=$(α), gamma=$(γ)")
        println(io, "- Re=$(Re)")
        println(io, "- Shear band = [$(shear_min), $(shear_max)]")
        println(io, "- Threads = $(Threads.nthreads())")
        println(io)

        for symm in symmetry_groups
            name = symm.name
            rows = get(group_rows, name, NamedTuple[])
            println(io, "## Symmetry $(name) $(symm.desc)")
            println(io)
            if isempty(rows)
                println(io, "No levels completed yet.")
                println(io)
                continue
            end
            println(io, "| Level | J | K | L | Source | Hookstep Converged | Unique | Promotions Reconverged |")
            println(io, "|---|---:|---:|---:|---|---:|---:|---:|")
            for r in rows
                println(io,
                    "| $(r.level_idx) | $(r.J) | $(r.K) | $(r.L) | $(r.source) | $(r.hookstep_converged) | $(r.unique_solutions) | $(r.promotions_reconverged) |"
                )
            end
            println(io)
        end
    end
end

# %%
println("EQB config:")
println("  out_dir=$(out_dir)")
println("  α=$(α), γ=$(γ), Lx=$(Lx), Lz=$(Lz), Re=$(Re)")
println("  symmetries=$(join([s.name for s in symmetry_groups], ","))")
println("  ladder=$(join(["$(j)x$(k)x$(l)" for (j, k, l) in discretization_ladder], ","))")
println("  attempts_level1=$(attempts_level1), append_attempts_level1=$(append_attempts_level1), resume=$(resume_from_saved)")
println(
    "  ladder_perturb_trials_early=$(ladder_perturb_trials_early), " *
    "ladder_perturb_trials_late=$(ladder_perturb_trials_late), " *
    "ladder_perturb_switch_jkl=$(ladder_perturb_switch_jkl), " *
    "ladder_perturb_switch_idx=$(ladder_perturb_switch_idx), " *
    "ladder_perturb_scale=$(ladder_perturb_scale)",
)
println(
    "  homotopy_enabled=$(homotopy_enabled), homotopy_initial_dmu=$(homotopy_initial_dmu), " *
    "homotopy_min_dmu=$(homotopy_min_dmu), homotopy_max_dmu=$(homotopy_max_dmu), " *
    "homotopy_growth=$(homotopy_growth), homotopy_shrink=$(homotopy_shrink), " *
    "homotopy_max_failures=$(homotopy_max_failures)",
)
println("  shear_band=[$(shear_min), $(shear_max)]")
println("  julia_threads=$(Threads.nthreads())")
println("  blas_threads=$(LinearAlgebra.BLAS.get_num_threads())")

group_rows = Dict{String, Vector{NamedTuple}}()
summary_md = joinpath(out_dir, "run_summary.md")

for symm in symmetry_groups
    symm_name = symm.name
    H = symm.H

    println("\n=== Symmetry: $(symm_name) $(symm.desc) ===")

    group_dir = joinpath(out_dir, symm_name)
    mkpath(group_dir)
    stats_path = joinpath(group_dir, "solution_statistics.csv")

    rows = NamedTuple[]
    prev_model = nothing
    prev_solutions = Vector{Vector{Float64}}()

    for (level_idx, (J, K, L)) in enumerate(discretization_ladder)
        println("\n--- Ladder level $(level_idx): J,K,L = $(J),$(K),$(L) ---")

        model = ODEModel(α, γ, J, K, L, H; normalize = false, tw = false)

        level_dir = joinpath(group_dir, "jkl_$(J)_$(K)_$(L)")
        mkpath(level_dir)
        summary_path = joinpath(level_dir, "solutions_summary.csv")
        serialized_path = joinpath(level_dir, "solutions.bin")

        loaded = Vector{Vector{Float64}}()
        if resume_from_saved && isfile(serialized_path)
            loaded = open(serialized_path, "r") do io
                deserialize(io)
            end
            println("[resume] loaded $(length(loaded)) solutions from $(serialized_path)")
        end

        source = ""
        level_stats = (
            attempted_seeds = 0,
            hookstep_converged = 0,
            accepted_postfilter = 0,
            unique_solutions = 0,
            promotions_reconverged = 0,
        )

        if level_idx == 1
            new_solutions = Vector{Vector{Float64}}()
            stats_fuzz = (
                attempted_seeds = 0,
                hookstep_converged = 0,
                accepted_postfilter = 0,
                unique_solutions = 0,
                promotions_reconverged = 0,
            )
            if attempts_level1 > 0
                new_solutions, _, stats_fuzz = fuzz_eqb_solutions(
                    model,
                    Re;
                    n_attempts = attempts_level1,
                    xnorm = xnorm,
                    strategy = guess_strategy,
                    shear_target = shear_target,
                    shear_tol = shear_tol,
                    shear_min = shear_min,
                    shear_max = shear_max,
                    hookparams = hookparams,
                    norm_threshold = norm_threshold,
                )
            end

            merged = merge_unique_solutions(loaded, new_solutions, model; fp_tol = fp_tol)

            stats_append = (
                attempted_seeds = 0,
                hookstep_converged = 0,
                accepted_postfilter = 0,
                unique_solutions = 0,
                promotions_reconverged = 0,
            )

            if append_attempts_level1 > 0
                extra_solutions, _, stats_append = fuzz_eqb_solutions(
                    model,
                    Re;
                    n_attempts = append_attempts_level1,
                    xnorm = xnorm,
                    strategy = guess_strategy,
                    shear_target = shear_target,
                    shear_tol = shear_tol,
                    shear_min = shear_min,
                    shear_max = shear_max,
                    hookparams = hookparams,
                    norm_threshold = norm_threshold,
                )
                merged = merge_unique_solutions(merged, extra_solutions, model; fp_tol = fp_tol)
            end

            prev_solutions = merged
            rejected = merge_rejected_fields(stats_fuzz, stats_append)
            level_stats = (
                attempted_seeds = stats_fuzz.attempted_seeds + stats_append.attempted_seeds,
                hookstep_converged = stats_fuzz.hookstep_converged + stats_append.hookstep_converged,
                accepted_postfilter = stats_fuzz.accepted_postfilter + stats_append.accepted_postfilter,
                rejected_postfilter = rejected[1],
                rejected_norm_min = rejected[2],
                rejected_norm_median = rejected[3],
                rejected_norm_max = rejected[4],
                rejected_shear_min = rejected[5],
                rejected_shear_median = rejected[6],
                rejected_shear_max = rejected[7],
                unique_solutions = length(prev_solutions),
                promotions_reconverged = 0,
            )
            source = isempty(loaded) ? "fuzz" : "resume+fuzz"
        else
            if !isempty(loaded)
                prev_solutions = loaded
                source = "resume"
                level_stats = (
                    attempted_seeds = length(loaded),
                    hookstep_converged = 0,
                    accepted_postfilter = 0,
                    unique_solutions = length(prev_solutions),
                    promotions_reconverged = 0,
                )
            else
                seeds = prev_solutions
                level_perturb_trials =
                    level_idx <= ladder_perturb_switch_idx ?
                    ladder_perturb_trials_early : ladder_perturb_trials_late
                println(
                    "[promotion config] level=$(level_idx) JKL=($(J),$(K),$(L)) " *
                    "perturb_trials=$(level_perturb_trials), perturb_scale=$(ladder_perturb_scale), " *
                    "homotopy_enabled=$(homotopy_enabled)",
                )
                promoted, _, stats_promote = refine_projected_solutions_with_homotopy(
                    prev_model,
                    model,
                    Re;
                    solutions_from = seeds,
                    hookparams = hookparams,
                    norm_threshold = norm_threshold,
                    perturb_trials = level_perturb_trials,
                    perturb_scale = ladder_perturb_scale,
                    homotopy_enabled = homotopy_enabled,
                    homotopy_initial_dmu = homotopy_initial_dmu,
                    homotopy_min_dmu = homotopy_min_dmu,
                    homotopy_max_dmu = homotopy_max_dmu,
                    homotopy_growth = homotopy_growth,
                    homotopy_shrink = homotopy_shrink,
                    homotopy_max_failures = homotopy_max_failures,
                    homotopy_summary_path = joinpath(level_dir, "homotopy_promotion_summary.csv"),
                )
                prev_solutions = promoted
                source = stats_promote.homotopy_converged > 0 ? "promotion+homotopy" : "promotion"
                level_stats = (
                    attempted_seeds = stats_promote.attempted_seeds,
                    hookstep_converged = stats_promote.hookstep_converged,
                    accepted_postfilter = stats_promote.accepted_postfilter,
                    rejected_postfilter = stats_promote.rejected_postfilter,
                    rejected_norm_min = stats_promote.rejected_norm_min,
                    rejected_norm_median = stats_promote.rejected_norm_median,
                    rejected_norm_max = stats_promote.rejected_norm_max,
                    rejected_shear_min = stats_promote.rejected_shear_min,
                    rejected_shear_median = stats_promote.rejected_shear_median,
                    rejected_shear_max = stats_promote.rejected_shear_max,
                    unique_solutions = stats_promote.unique_solutions,
                    promotions_reconverged = stats_promote.promotions_reconverged,
                )
            end
        end

        save_level_summary(summary_path, prev_solutions, model)
        open(serialized_path, "w") do io
            serialize(io, prev_solutions)
        end
        write_solution_asc_files(level_dir, prev_solutions, model)

        push!(rows, (
            timestamp = Dates.format(now(), "yyyy-mm-ddTHH:MM:SS"),
            level_idx = level_idx,
            J = J,
            K = K,
            L = L,
            source = source,
            attempted_seeds = level_stats.attempted_seeds,
            hookstep_converged = level_stats.hookstep_converged,
            accepted_postfilter = level_stats.accepted_postfilter,
            rejected_postfilter = hasproperty(level_stats, :rejected_postfilter) ? level_stats.rejected_postfilter : 0,
            rejected_norm_min = hasproperty(level_stats, :rejected_postfilter) ? level_stats.rejected_norm_min : NaN,
            rejected_norm_median = hasproperty(level_stats, :rejected_postfilter) ? level_stats.rejected_norm_median : NaN,
            rejected_norm_max = hasproperty(level_stats, :rejected_postfilter) ? level_stats.rejected_norm_max : NaN,
            rejected_shear_min = hasproperty(level_stats, :rejected_postfilter) ? level_stats.rejected_shear_min : NaN,
            rejected_shear_median = hasproperty(level_stats, :rejected_postfilter) ? level_stats.rejected_shear_median : NaN,
            rejected_shear_max = hasproperty(level_stats, :rejected_postfilter) ? level_stats.rejected_shear_max : NaN,
            unique_solutions = level_stats.unique_solutions,
            promotions_reconverged = level_stats.promotions_reconverged,
        ))
        write_group_statistics(stats_path, rows)

        group_rows[symm_name] = rows
        write_markdown_summary(summary_md, group_rows)

        if isempty(prev_solutions)
            println("[warn] no solutions at level $(level_idx); stopping ladder for symmetry $(symm_name)")
            break
        end

        prev_model = model
    end
end

write_markdown_summary(summary_md, group_rows)
println("\nCompleted equilibrium discovery sweep.")
println("Summary markdown: $(summary_md)")

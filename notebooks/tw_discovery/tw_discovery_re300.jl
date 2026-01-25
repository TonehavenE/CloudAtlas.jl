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
# # Traveling-Wave Discovery (Re=300)
#
# Goal: find novel traveling-wave solutions by fuzzing TWModel seeds, deduplicating by
# wave speeds + norms + shear, and then promoting unique candidates to a full Channelflow
# `findsoln` run.
#
# This notebook is designed to handle multiple symmetry groups and discretizations.
#
# Notes:
# - The default guess strategy is random. You can enable shear-targeted guesses or
#   trajectory-sampled guesses by toggling `guess_strategy` below.
# - The `findsoln` stage will write results to `out_dir`.

# %%
using CloudAtlas
using LinearAlgebra
using Statistics
using Random
using Dates
using DelimitedFiles
using Serialization
using Base.Threads
using ChannelflowWrapper

# %% [markdown]
# ## Configuration

# %%
# Domain sizes (α = 2π/Lx, γ = 2π/Lz)
# Choose these to match the target Channelflow DNS box.
α, γ = 2π/6.0, 2π/4.0

Re = 300.0

# Discretizations: (J, K, L)
discretizations = [
    (2, 4, 7),
    (3, 5, 7),
    (3, 5, 9),
]

# Symmetry groups to explore
sx, sy, sz, tx, tz = CloudAtlas.halfbox_symmetries()

symmetry_groups = [
    (
        name = "sxytxz",
        H = [(sx * sy) * (tx * tz)],
        symm_file = joinpath(@__DIR__, "sxytxz.asc"),
    ),
    (
        name = "sztx",
        H = [sz * tx],
        symm_file = joinpath(@__DIR__, "sztx.asc"),
    ),
    (
        name = "tx",
        H = [tx],
        symm_file = joinpath(@__DIR__, "tx.asc"),
    ),
    (
        name = "tz",
        H = [tz],
        symm_file = joinpath(@__DIR__, "tz.asc"),
    ),
    (
        name = "txtz",
        H = [tx * tz],
        symm_file = joinpath(@__DIR__, "txtz.asc"),
    ),
    (
        name = "sx_tx",
        H = [sx * tx],
        symm_file = joinpath(@__DIR__, "sxtx.asc"),
    ),
    (
        name = "sztx",
        H = [sz * tx],
        symm_file = joinpath(@__DIR__, "sztx.asc"),
    ),
    (
        name = "sxtz",
        H = [sx * tz],
        symm_file = joinpath(@__DIR__, "sxtz.asc"),
    ),
    (
        name = "sztz",
        H = [sz * tz],
        symm_file = joinpath(@__DIR__, "sztz.asc"),
    ),
]

# Attempts per symmetry/discretization
attempts_per_level = 10_000

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

# Guess strategy options: :random, :shear_target, :trajectory
guess_strategy = :random
xnorm = 0.4
shear_target = 1.2
shear_tol = 0.05

# Dedup tolerances
fp_tol = (
    cx = 1e-3,
    cz = 1e-3,
    nm = 2e-2,
    shear = 2e-2,
)

# Accept/reject thresholds
norm_threshold = 1e-3
speed_threshold = 1e-5

# Channelflow promotion settings
T = 10.0
out_dir = joinpath(@__DIR__, "tw_discovery_re300")
mkpath(out_dir)

# Reference field for Channelflow conversions
reference_path = joinpath(@__DIR__, "TW1-2pi1piRe200-40x49x40.nc")
reference_field_converted = joinpath(out_dir, "reference_field_$(α)_$(γ).nc")

# %% [markdown]
# ## Helper types and functions

# %%
struct SolutionFingerprint
    cx::Float64
    cz::Float64
    nm::Float64
    shear::Float64
end

function fingerprint(model, ξ)
    x, cx, cz = extract_components(ξ, model)
    return SolutionFingerprint(cx, cz, norm(x), shear(x, model))
end

function is_distinct(new_fp::SolutionFingerprint, archive::Vector{SolutionFingerprint}; tol = fp_tol)
    for fp in archive
        if isapprox(new_fp.cx, fp.cx, atol = tol.cx) &&
           isapprox(new_fp.cz, fp.cz, atol = tol.cz) &&
           isapprox(new_fp.nm, fp.nm, atol = tol.nm) &&
           isapprox(new_fp.shear, fp.shear, atol = tol.shear)
            return false
        end
    end
    return true
end

function random_guess(model, rng; xnorm = 0.4)
    m = length(model)
    x = randn(rng, m)
    x = xnorm / norm(x) * x
    cx = randn(rng) * 0.1
    cz = randn(rng) * 0.1
    return [x; cx; cz]
end

function shear_target_guess(model, rng; xnorm = 0.4, target = 1.2, tol = 0.05, max_tries = 100)
    for _ in 1:max_tries
        ξ = random_guess(model, rng; xnorm = xnorm)
        x = ξ[1:length(model)]
        if abs(shear(x, model) - target) <= tol
            return ξ
        end
    end
    # fallback
    return random_guess(model, rng; xnorm = xnorm)
end

function build_guess(model, rng; strategy = :random, xnorm = 0.4, target = 1.2, tol = 0.05)
    if strategy == :random
        return random_guess(model, rng; xnorm = xnorm)
    elseif strategy == :shear_target
        return shear_target_guess(model, rng; xnorm = xnorm, target = target, tol = tol)
    else
        error("Unknown strategy: $(strategy)")
    end
end

function save_summary(path, solutions, model)
    rows = Vector{Vector{Float64}}(undef, length(solutions))
    for (i, ξ) in enumerate(solutions)
        x, cx, cz = extract_components(ξ, model)
        rows[i] = [i, cx, cz, norm(x), shear(x, model)]
    end
    header = ["id" "cx" "cz" "norm" "shear"]
    writedlm(path, vcat(header, rows), ',')
end

# %% [markdown]
# ## Fuzzing + deduplication

# %%
function fuzz_tw_solutions(model::TWModel, Re::Real;
    n_attempts = 1000,
    xnorm = 0.4,
    strategy = :random,
    shear_target = 1.2,
    shear_tol = 0.05,
    hookparams = SearchParams(),
    norm_threshold = 1e-3,
    speed_threshold = 1e-5,
)
    m = length(model)
    solutions = Vector{Vector{Float64}}()
    fingerprints = Vector{SolutionFingerprint}()

    data_lock = ReentrantLock()
    io_lock = ReentrantLock()

    rngs = [MersenneTwister(0xC0FFEE + i) for i in 1:Threads.maxthreadid()]
    progress = Threads.Atomic{Int}(0)
    progress_every = max(1, n_attempts ÷ 100)

    @threads for attempt in 1:n_attempts
        tid = threadid()
        rng = tid <= length(rngs) ? rngs[tid] : Random.default_rng()
        ξ_guess = build_guess(model, rng;
            strategy = strategy,
            xnorm = xnorm,
            target = shear_target,
            tol = shear_tol,
        )

        f(ξ) = model.g(ξ, Re)
        Df(ξ) = model.Dg(ξ, Re)

        ξ_star, converged = CloudAtlas.hookstepsolve(f, Df, ξ_guess, hookparams)

        if converged
            x, cx, cz = extract_components(ξ_star, model)
            if norm(x) > norm_threshold && (abs(cx) > speed_threshold || abs(cz) > speed_threshold)
                fp = fingerprint(model, ξ_star)
                lock(data_lock) do
                    if is_distinct(fp, fingerprints)
                        push!(fingerprints, fp)
                        push!(solutions, ξ_star)
                        lock(io_lock) do
                            println("[Thread $(threadid())] Unique TW: cx=$(round(fp.cx, digits=4)), cz=$(round(fp.cz, digits=4)), |x|=$(round(fp.nm, digits=4)), shear=$(round(fp.shear, digits=4))")
                        end
                    end
                end
            end
        end

        done = Threads.atomic_add!(progress, 1)
        if done % progress_every == 0 || done == n_attempts
            lock(io_lock) do
                pct = round(100 * done / n_attempts; digits=1)
                println("Progress: $(done)/$(n_attempts) ($(pct)%) (unique=$(length(solutions)))")
            end
        end
    end

    println("Done. Found $(length(solutions)) unique solutions.")
    return solutions, fingerprints
end

# %% [markdown]
# ## Channelflow promotion

# %%
function ensure_reference_field(reference_path, reference_field_converted; α, γ)
    if !isfile(reference_field_converted)
        changegrid(reference_path, reference_field_converted; al = α, ga = γ)
    end
    return reference_field_converted
end

function promote_with_findsoln!(solutions, model, Re;
    symm_file,
    out_dir,
    reference_field_converted,
    T = 10.0,
)
    m = length(model)
    mkpath(out_dir)
    for (idx, ξ) in enumerate(solutions)
        timestamp = Dates.format(now(), "MM-DD-HHMMSS")
        sol_dir = joinpath(out_dir, "sol_$(idx)_$(timestamp)")
        mkpath(sol_dir)

        guess_path = joinpath(sol_dir, "u_guess.nc")
        sigma_file = joinpath(sol_dir, "sigma.asc")

        coeff2field(ξ[1:m], model.ijkl, reference_field_converted, guess_path)
        save_sigma(model, ξ[end - 1], ξ[end], T, sigma_file)

        try
            findsoln(guess_path;
                R = Re,
                eqb = true,
                xrel = model.keep_cx,
                zrel = model.keep_cz,
                symms = abspath(symm_file),
                sigma = sigma_file,
                od = sol_dir,
                T = T,
            )
        catch e
            println("findsoln failed: $(e)")
        end
    end
end

# %% [markdown]
# ## Main sweep

# %%
reference_field_converted = ensure_reference_field(reference_path, reference_field_converted; α = α, γ = γ)

for symm in symmetry_groups
    symm_name = symm.name
    H = symm.H
    symm_file = symm.symm_file

    println("\n=== Symmetry: $(symm_name) ===")
    println("symm_file: $(symm_file)")

    for (J, K, L) in discretizations
        println("\n--- J,K,L = $(J),$(K),$(L) ---")

        model = ODEModel(α, γ, J, K, L, H; normalize = false, tw = true)

        level_dir = joinpath(out_dir, symm_name, "jkl_$(J)_$(K)_$(L)")
        mkpath(level_dir)

        solutions, fingerprints = fuzz_tw_solutions(
            model,
            Re;
            n_attempts = attempts_per_level,
            xnorm = xnorm,
            strategy = guess_strategy,
            shear_target = shear_target,
            shear_tol = shear_tol,
            hookparams = hookparams,
            norm_threshold = norm_threshold,
            speed_threshold = speed_threshold,
        )

        # Save summary of unique solutions
        summary_path = joinpath(level_dir, "solutions_summary.csv")
        save_summary(summary_path, solutions, model)

        # Save raw solutions (for later reuse)
        serialized_path = joinpath(level_dir, "solutions.bin")
        open(serialized_path, "w") do io
            serialize(io, solutions)
        end

        # Promote to Channelflow
        promote_with_findsoln!(
            solutions,
            model,
            Re;
            symm_file = symm_file,
            out_dir = joinpath(level_dir, "findsoln"),
            reference_field_converted = reference_field_converted,
            T = T,
        )
    end
end

# %% [markdown]
# ## Notes
#
# - To change the guess strategy, set `guess_strategy = :shear_target` or add your own
#   generator in `build_guess`.
# - For trajectory-based guesses (like state_space_geography), consider precomputing a
#   pool of snapshots and sampling from that in `build_guess`.
# - If `findsoln` is too heavy, comment out the `promote_with_findsoln!` call and run
#   it later using the saved `solutions.bin`.

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
# # Boxsize Sweep for Traveling-Wave Discovery (Re=300)
#
# Goal: for a fixed discretization (J,K,L) = (1,2,3), sweep a grid of (α, γ)
# values, run many random TW guesses per grid point, and build a heatmap of
# solution-yield (unique solutions per guess) as a proxy for "easiness".
#
# Notes:
# - Uses TWModel + hookstepsolve only (no Channelflow findsoln).
# - Multi-threading uses `Threads.@threads` over attempts. Adjust `JULIA_NUM_THREADS`.

# %%
import Pkg; Pkg.activate("../../.")

# %%
using CloudAtlas
using LinearAlgebra
using Statistics
using Random
using Dates
using DelimitedFiles
using Serialization
using Base.Threads
using CairoMakie

# %% [markdown]
# ## Configuration

# %%
Re = 300.0
J, K, L = 1, 2, 3

# Grid of (α, γ). Edit as needed.
# α = 2π/Lx, γ = 2π/Lz
Lx_vals = range(1.0, 10.0, length=10)
Lz_vals = range(1.0, 10.0, length=10)
alpha_vals = 2π ./ Lx_vals
gamma_vals = 2π ./ Lz_vals

# Attempts per grid point
attempts_per_point = 10_000  # set to 100_000 if you have time

# Symmetry groups (combined generators only)
sx, sy, sz, tx, tz = CloudAtlas.halfbox_symmetries()

symmetry_groups = [
    (
        name = "sxytxz",
        H = [(sx * sy) * (tx * tz)],
    ),
    (
        name = "sztx",
        H = [sz * tx],
    ),
    (
        name = "tx",
        H = [tx],
    ),
    (
        name = "tz",
        H = [tz],
    ),
    (
        name = "txtz",
        H = [tx * tz],
    ),
    (
        name = "sxtx",
        H = [sx * tx],
    ),
    (
        name = "sxtz",
        H = [sx * tz],
    ),
    (
        name = "sztz",
        H = [sz * tz],
    ),
]

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

# Guess parameters
xnorm = 0.4
norm_threshold = 1e-3
speed_threshold = 1e-5

# Dedup tolerances
fp_tol = (
    cx = 1e-3,
    cz = 1e-3,
    nm = 2e-2,
)

# Output directory
out_dir = joinpath(@__DIR__, "tw_boxsize_fuzzing_re300")
mkpath(out_dir)

# %% [markdown]
# ## Helpers

# %%
struct SolutionFingerprint
    cx::Float64
    cz::Float64
    nm::Float64
end

function fingerprint(model, ξ)
    x, cx, cz = extract_components(ξ, model)
    return SolutionFingerprint(cx, cz, norm(x))
end

function is_distinct(new_fp::SolutionFingerprint, archive::Vector{SolutionFingerprint}; tol = fp_tol)
    for fp in archive
        if isapprox(new_fp.cx, fp.cx, atol = tol.cx) &&
           isapprox(new_fp.cz, fp.cz, atol = tol.cz) &&
           isapprox(new_fp.nm, fp.nm, atol = tol.nm)
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

function fuzz_once(model, Re; n_attempts = 1000)
    m = length(model)
    solutions = Vector{Vector{Float64}}()
    fingerprints = Vector{SolutionFingerprint}()

    data_lock = ReentrantLock()
    rngs = [MersenneTwister(0xBADC0DE + i) for i in 1:Threads.maxthreadid()]
    progress = Threads.Atomic{Int}(0)
    progress_every = max(1, n_attempts ÷ 100)
    g = model.g
    Dg = model.Dg
    g === nothing && error("model.g is nothing. Make sure you built the model with TWModel (tw=true).")
    use_jac = Dg !== nothing

    @threads for attempt in 1:n_attempts
        tid = threadid()
        rng = tid <= length(rngs) ? rngs[tid] : Random.default_rng()
        ξ_guess = random_guess(model, rng; xnorm = xnorm)

        f(ξ) = g(ξ, Re)
        if use_jac
            Df(ξ) = Dg(ξ, Re)
            ξ_star, converged = CloudAtlas.hookstepsolve(f, Df, ξ_guess, hookparams)
        else
            ξ_star, converged = CloudAtlas.hookstepsolve(f, ξ_guess, hookparams)
        end

        if converged
            x, cx, cz = extract_components(ξ_star, model)
            if norm(x) > norm_threshold && (abs(cx) > speed_threshold || abs(cz) > speed_threshold)
                fp = fingerprint(model, ξ_star)
                lock(data_lock) do
                    if is_distinct(fp, fingerprints)
                        push!(fingerprints, fp)
                        push!(solutions, ξ_star)
                    end
                end
            end
        end

        done = Threads.atomic_add!(progress, 1)
        if done % progress_every == 0 || done == n_attempts
            pct = round(100 * done / n_attempts; digits=1)
            println("Progress: $(done)/$(n_attempts) ($(pct)%)")
        end
    end

    return length(solutions)
end

# %% [markdown]
# ## Sweep + Heatmaps

# %%
function sweep_boxsizes(symm; alpha_vals, gamma_vals)
    nα = length(alpha_vals)
    nγ = length(gamma_vals)
    counts = zeros(Int, nα, nγ)
    total = nα * nγ
    idx = 0

    for (i, α) in enumerate(alpha_vals)
        for (j, γ) in enumerate(gamma_vals)
            idx += 1
            pct = round(100 * idx / total; digits=1)
            println("α=$(round(α, digits=4)), γ=$(round(γ, digits=4)), symm=$(symm.name)")
            println("Grid progress: $(idx)/$(total) ($(pct)%)")
            model = ODEModel(α, γ, J, K, L, symm.H; normalize=false, tw=true)
            counts[i, j] = fuzz_once(model, Re; n_attempts = attempts_per_point)
        end
    end

    return counts
end

function plot_heatmap(counts; title, alpha_vals, gamma_vals)
    rate = counts ./ attempts_per_point

    fig = Figure(size=(900, 700))
    ax = Axis(
        fig[1, 1],
        title = title,
        xlabel = "α",
        ylabel = "γ",
    )

    hm = heatmap!(ax, alpha_vals, gamma_vals, rate'; colormap = :viridis)
    Colorbar(fig[1, 2], hm, label = "unique solutions / guess")

    return fig
end

# %%
results = Dict{String, Matrix{Int}}()

for symm in symmetry_groups
    counts = sweep_boxsizes(symm; alpha_vals = alpha_vals, gamma_vals = gamma_vals)
    results[symm.name] = counts

    # Save raw counts
    out_path = joinpath(out_dir, "counts_$(symm.name).csv")
    writedlm(out_path, counts, ',')

    # Plot heatmap
    fig = plot_heatmap(
        counts;
        title = "TW yield @ Re=$(Re), JKL=$(J),$(K),$(L), symm=$(symm.name)",
        alpha_vals = alpha_vals,
        gamma_vals = gamma_vals,
    )
    save(joinpath(out_dir, "heatmap_$(symm.name).png"), fig)
end

# %% [markdown]
# ## Notes
# - Increase `attempts_per_point` for more stable rates.
# - Reduce the α/γ grid or the symmetry set to keep runtime manageable.
# - If `Threads.@threads` is not using multiple cores, start Julia with
#   `JULIA_NUM_THREADS` set (e.g. `JULIA_NUM_THREADS=8`).

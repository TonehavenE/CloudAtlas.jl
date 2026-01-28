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
# # TW Atlas + Clustering (Re=300)
#
# Load previously discovered TW solutions, compute fingerprints, deduplicate,
# and visualize an atlas of unique TWs.

# %%
using CloudAtlas
using LinearAlgebra
using Statistics
using Random
using Dates
using Serialization
using CairoMakie

# %% [markdown]
# ## Configuration

# %%
Re = 300.0

# Domain sizes and discretization (for metrics)
α, γ = 2π/6.0, 2π/4.0
J, K, L = 2, 4, 7

sx, sy, sz, tx, tz = CloudAtlas.halfbox_symmetries()
H = [sz * tx]

# Where to load solution archives (solutions.bin) from
search_dirs = [
    joinpath(@__DIR__, "tw_discovery_re300"),
    joinpath(@__DIR__, "tw_trajectory_seeded_re300"),
]

# Fingerprint tolerance for clustering
fp_tol = (
    cx = 1e-3,
    cz = 1e-3,
    nm = 2e-2,
    shear = 2e-2,
)

# Output
out_dir = joinpath(@__DIR__, "tw_atlas_re300")
mkpath(out_dir)

# %% [markdown]
# ## Helper types

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
        if isapprox(new_fp.cx, fp.cx, atol=tol.cx) &&
           isapprox(new_fp.cz, fp.cz, atol=tol.cz) &&
           isapprox(new_fp.nm, fp.nm, atol=tol.nm) &&
           isapprox(new_fp.shear, fp.shear, atol=tol.shear)
            return false
        end
    end
    return true
end

# %% [markdown]
# ## Load solutions

# %%
paths = String[]
for d in search_dirs
    for (root, _, files) in walkdir(d)
        for f in files
            f == "solutions.bin" && push!(paths, joinpath(root, f))
        end
    end
end

println("Found $(length(paths)) solution archives")

solutions = Vector{Vector{Float64}}()
for p in paths
    open(p, "r") do io
        sols = deserialize(io)
        append!(solutions, sols)
    end
end

println("Loaded $(length(solutions)) raw solutions")

# %% [markdown]
# ## Deduplicate + cluster by fingerprint

# %%
model = ODEModel(α, γ, J, K, L, H; normalize=false, tw=true)

unique_solutions = Vector{Vector{Float64}}()
fp_archive = Vector{SolutionFingerprint}()

progress = 0
progress_every = max(1, length(solutions) ÷ 100)
for (i, ξ) in enumerate(solutions)
    fp = fingerprint(model, ξ)
    if is_distinct(fp, fp_archive)
        push!(fp_archive, fp)
        push!(unique_solutions, ξ)
    end
    progress += 1
    if progress % progress_every == 0 || progress == length(solutions)
        pct = round(100 * progress / length(solutions); digits=1)
        println("Dedup progress: $(progress)/$(length(solutions)) ($(pct)%)")
    end
end

println("Unique TWs: $(length(unique_solutions))")

# %% [markdown]
# ## Save summary table

# %%
summary_path = joinpath(out_dir, "solutions_summary.csv")
open(summary_path, "w") do io
    println(io, "id,cx,cz,norm,shear")
    for (i, ξ) in enumerate(unique_solutions)
        x, cx, cz = extract_components(ξ, model)
        println(io, "$(i),$(cx),$(cz),$(norm(x)),$(shear(x, model))")
    end
end

# %% [markdown]
# ## Visualizations

# %%
if !isempty(unique_solutions)
    # (cx, cz) scatter
    cx_vals = [extract_components(ξ, model)[2] for ξ in unique_solutions]
    cz_vals = [extract_components(ξ, model)[3] for ξ in unique_solutions]

    fig1 = Figure(size=(700, 500))
    ax1 = Axis(fig1[1, 1], xlabel="c_x", ylabel="c_z", title="TW speed atlas")
    scatter!(ax1, cx_vals, cz_vals, color=:teal, markersize=8)
    save(joinpath(out_dir, "tw_speed_atlas.png"), fig1)

    # I-D plane
    D_matrix = build_dissipation_matrix(model)
    I_vals = [power_input(model, extract_components(ξ, model)[1]) for ξ in unique_solutions]
    D_vals = [dissipation_rate(D_matrix, extract_components(ξ, model)[1]) for ξ in unique_solutions]

    fig2 = Figure(size=(700, 500))
    ax2 = Axis(fig2[1, 1], xlabel="Dissipation (D)", ylabel="Power Input (I)", title="TW atlas in I-D plane")
    scatter!(ax2, D_vals, I_vals, color=:darkorange, markersize=8)
    save(joinpath(out_dir, "tw_id_atlas.png"), fig2)
end

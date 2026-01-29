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
# # Shear mode exploration
# Identify which basis modes contribute most to wall shear and experiment with shear-band guesses.

# %%
using CloudAtlas
using LinearAlgebra
using Statistics
using Random
using CairoMakie

# %% [markdown]
# ## Model setup (edit as needed)

# %%
sx, sy, sz, tx, tz = halfbox_symmetries()

α = 1.0
γ = 2.0
J, K, L = 3, 3, 6
H = [sx*sy*sz]  # example symmetry subgroup

model = ODEModel(α, γ, J, K, L, H; tw=true)

# %% [markdown]
# ## Dominant shear contributors (raw + sanity checks)

# %%
s = model.Ψshear
abs_s = abs.(s)
nonzero = [i for i in eachindex(s) if !iszero(s[i])]
println("Nonzero shear modes: $(length(nonzero))")

sorted_idx = sortperm(abs_s, rev = true)
sorted_abs = abs_s[sorted_idx]
cum = cumsum(sorted_abs) ./ sum(sorted_abs)
k90 = findfirst(>=(0.9), cum)

dominant = shear_dominant_indices(model; frac = 0.9)
dominant_set = Set(dominant)
println("Dominant indices (90% |shear| mass): $(length(dominant)) (k90=$(k90))")

println("Top 10 shear contributors:")
for i in sorted_idx[1:min(10, length(sorted_idx))]
    ijkl = model.ijkl[i, :]
    println("i=$(i) ijkl=$(collect(ijkl)) shear_coeff=$(s[i])")
end

# %% [markdown]
# ## Visualize shear contribution by mode

# %%
colors_sorted = [i in dominant_set ? :tomato : :steelblue for i in sorted_idx]

fig1 = Figure(size = (900, 600))
ax1 = Axis(fig1[1, 1], xlabel = "Mode rank (sorted by |shear|)", ylabel = "|shear coeff|")
barplot!(ax1, 1:length(sorted_abs), sorted_abs; color = colors_sorted)

ax2 = Axis(fig1[2, 1], xlabel = "Mode rank (sorted by |shear|)", ylabel = "Cumulative |shear| fraction")
lines!(ax2, 1:length(cum), cum; color = :black)
hlines!(ax2, [0.9]; color = :red, linestyle = :dash)
vlines!(ax2, [k90]; color = :red, linestyle = :dash)
display(fig1)

# %%
fig2 = Figure(size = (900, 400))
ax3 = Axis(fig2[1, 1], xlabel = "Mode index", ylabel = "shear coeff (signed)")
colors_raw = [i in dominant_set ? :tomato : :gray for i in 1:length(s)]
scatter!(ax3, 1:length(s), s; color = colors_raw, markersize = 6)
display(fig2)

# %% [markdown]
# ## Shear-band guess example

# %%
rng = Random.default_rng()
ξ_guess = shear_band_guess(model, rng; shear_min = 1.0, shear_max = 3.0, rest_scale = 0.1)
x, cx, cz = extract_components(ξ_guess, model)
println("shear(x) = ", shear(x, model), "  cx=$(cx)  cz=$(cz)")

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
# # Visualization Showcase
# 2025-11-23
#
# This notebook showcases some of the functionality of visualizing velocity fields, using the CloudAtlasVisualizationExt.
#
# In order to use the visualization tools of CloudAtlas, you need to be `using CairoMakie`. 
# CairoMakie is kept as a weak dependency to maintain the independence of the main CloudAtlas software.
#
# By default, the laminar baseflow is disabled. You might be surprised by the streamwise velocity because of that.
# All plotting functions have an optional `add_baseflow` flag which enables the laminar flow by just adding the $y$ coordinate to $u$.

# %%
using Revise, DelimitedFiles, BenchmarkTools, LinearAlgebra, Polynomials
using CairoMakie # this triggers the extension to load
using CloudAtlas

"""
    myreaddlm(filename, cc='%')

Read matrix or vector from a file, dropping comments marked with cc.
"""
function myreaddlm(filename; cc='%')
    X = readdlm(filename, comments=true, comment_char=cc)
    if size(X,2) == 1
        X = X[:,1]
    end
    X
end

sx, sy, sz, tx, tz = halfbox_symmetries()

pwd()

# %% [markdown]
# ## Visualizing a Field
# The following showcases the visualization of a field equilibrium. First, we find the eqb.

# %%
# Define symmetry group (e.g., σy symmetry)
H = [sx*sy*sz, sz*tx*tz]

# Create ODE model
α = 1.0  # 2π/Lx
γ = 2.0  # 2π/Lz
J, K, L = 1, 2, 3
model = ODEModel(α, γ, J, K, L, H)

xguess = myreaddlm("data/xeq1projection-Re200-1-2-3-27d.asc")

R = 200

fr = x -> model.f(x,R)    # define function  f(x) = f(x,R)  for fixed R
Dfr = x -> model.Df(x,R)  # define function Df(x) = Df(x,R) for fixed R

@time xeq1, eq1success = hookstepsolve(fr, Dfr, xguess)
eq1success

# %%
# Visualize velocity field
settings = PlotSettings(num_points=25, arrow_scale=0.5)
fig = velocity_fields(model, xeq1, settings=settings)

# %% [markdown]
# ## Comparison to DNS Data
# An important comparison is visualizing how the velocity field relates to the DNS data. The following demonstrates such a comparison.
#
# This uses a fairly high resolution model, with a 320 variable ODE model. 
#
# The DNS data is generated with the `plotfield` Channelflow utility, which is included in the `chflow-programs` directory.

# %%
α, γ = 1.0, 2.0                     # Fourier wavenumbers α, γ = 2π/Lx, 2π/Lz
J,K,L = 3,3,6                       # Bounds on Fourier modes (J,K) and wall-normal polynomials (L)
H = [(sx*sy)*(tx*tz)]               # Generators of the symmetric subspace of TW1
normalize = false                   # Normalize the basis set or not?
model = ODEModel(α, γ, J, K, L, H, normalize=normalize)  # Construct ODE model by Galerkin projection 
@show m = length(model)             # dimension of ODE model

# %%
# Parameters
hookparams = SearchParams(ftol=1e-08, xtol=1e-12, Nnewton=30,Nhook=8,δ=0.01, verbosity=0)
R = 200
x0 = myreaddlm("data/xtw1projection-Re200-3-3-6-320d.asc")

# Create closures for g and Dg that capture R
f_closure(x) = model.f(x, R)
Df_closure(x) = model.Df(x, R)

# Use hookstep to find a solution
ξ_final, converged = hookstepsolve(f_closure, Df_closure, x0, hookparams)
x_sol = ξ_final[1:m]
println("Norm of solution: ", norm(x_sol))
println("Converged: ", converged)

# %%
settings = PlotSettings(num_points = 40)
fig1, fig2, fig3 = velocity_fields_comparison(model, x_sol, "./data/tw1_plots/TW1-2pi1piRe200-40x49x40"; settings=settings, add_baseflow = false)

# %%
display(fig1)

# %%
display(fig2)

# %%
display(fig3)

# %% [markdown]
# ## Adding Baseflow
# The following graphs demonstrate what changes when we enable the `add_baseflow` flag. Notably, you need DNS data that also has the laminar profile added, which could be done with the `addfield` Channelflow utility. 

# %%
fig1, fig2, fig3 = velocity_fields_comparison(model, x_sol, "./data/tw1_plots/TW1_Re200_with_baseflow"; settings=settings, add_baseflow = true)

# %%
display(fig1)

# %%
display(fig2)

# %%
display(fig3)

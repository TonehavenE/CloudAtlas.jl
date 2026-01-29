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
# # Finding Traveling Waves
# 2025-11-18
#
# This notebook shows the procedure for finding a traveling wave solution to the Navier-Stokes.
#
# The naming here -- TW1 -- is based off of this paper: https://arxiv.org/pdf/0808.3375

# %%
using LinearAlgebra, Polynomials, Plots
using Revise, DelimitedFiles, BenchmarkTools
using CloudAtlas, BifurcationKit

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
# ## Finding a Traveling Wave Solution

# %%
α, γ = 1.0, 2.0                     # Fourier wavenumbers α, γ = 2π/Lx, 2π/Lz
J,K,L = 3,3,6                       # Bounds on Fourier modes (J,K) and wall-normal polynomials (L)
H = [(sx*sy)*(tx*tz)]               # Generators of the symmetric subspace of TW1
normalize = false                   # Normalize the basis set or not?

model = TWModel(α, γ, J, K, L, H, normalize=normalize)  # Construct ODE model by Galerkin projection 

@show m = length(model)             # dimension of ODE model

# %%
# Parameters
hookparams = SearchParams(ftol=1e-08, xtol=1e-12, Nnewton=30,Nhook=8,δ=0.01, verbosity=0)
R = 200
cx0 = 0.000 # values from paper
cz0 = 0.009
## Optional: using ChannelflowWrapper to generate the initial guess from a Channelflow flowfield file.
# using ChannelflowWrapper
# x0 = field2coeff(model.ijkl, "data/TW1-2pi1piRe200-40x49x40.nc", "data/xtw1projection-Re$(R)-$(J)-$(K)-$(L)-$(m)d.asc")
# otherwise, read data from existing file
x0 = myreaddlm("data/xtw1projection-Re$(R)-$(J)-$(K)-$(L)-$(m)d.asc")
ξ0 = [x0; cx0; cz0] # combine everything into initial guess

# %%
# Use hookstep to find a solution with fixed-reference phase constraints
ξ_final, converged = hookstepsolve(model, R, ξ0, hookparams)

# %%
x_sol = ξ_final[1:m]
cx_sol = ξ_final[m+1]
cz_sol = ξ_final[m+2]
println("Norm of solution: ", norm(x_sol))
println("Wave speed in x: ", cx_sol)
println("Wave speed in z: ", cz_sol)
println("Converged: ", converged)

# %% [markdown]
# ## 2. Bifurcation Analysis

# %%
"""
Continue a z-traveling wave (cx=0) solution branch in Reynolds number.
"""
function tw_z_branch_continuation(model, ξ_0, Re0;
                                  Re_min=100.0, Re_max=500.0,
                                  max_steps=1000, tol=1e-10, dsmin=1e-7)
    m = model.m
    x0 = ξ_0[1:m]
    cx0 = ξ_0[m+1]
    cz0 = ξ_0[m+2]
    
    # Pack state as [x; cz]
    u0 = vcat(x0, cz0) # State vector is length n+1
    
    # Define the fixed phase condition vector
    Du0_z = model.Cz * x0
    
    # Define residual function
    function f_tw_z(u, p)
        (; Re) = p
        x  = u[1:m]
        cz = u[end] 

        # Standard residual
        res_flow = (cz .* (model.Cz * x)) .- (model.A1 * x) .- ((1/Re) .* (model.A2 * x)) .- model.N(x)
        
        # Compute phase condition
        res_phase = dot(x .- x0, Du0_z)
        
        # Return combined vector
        return [res_flow; res_phase]
    end

    # Set up bifurcation problem
    params = (Re = Re0, x0_param = x0, Du0_param = Du0_z)
    
    prob = BifurcationProblem(
        f_tw_z, u0, params, (@optic _.Re);
        record_from_solution = (u, p_val; k...) -> (R=p_val, x=u[1:m], cx=0.0, cz=u[m+1], pow=shear(u[1:m], model))
    )
    
    # Continuation options
    opts = ContinuationPar(
        p_max=Re_max,
        p_min=Re_min,
        detect_bifurcation = 0, # Skip expensive stability/eigenvalue checks for speed
        n_inversion=20,
        max_steps=max_steps,
        newton_options=NewtonPar(tol=tol, max_iterations=20),
        dsmin=dsmin
    )
    
    println("Starting Z-TW continuation from Re = $Re0...")
    branch = continuation(prob, PALC(), opts, bothside=true)
    println("Continuation complete. Found $(length(branch.branch)) points.")
    return branch
end


# %%
branch = tw_z_branch_continuation(model, ξ_final, 200.0)

# %%
# Plot Re (branch.param) vs Power (branch.pow)
plot(branch.param, branch.pow,
    xlabel = "Reynolds Number (Re)",
    ylabel = "Power Input",
    title = "TW1 Bifurcation Diagram",
    linewidth = 2,
    marker = :circle,
    markersize = 3,
    legend = :topright,
    label = "TW1 (J=$(J), K=$(K), L=$(L))"
)

# Optional: Add DNS comparison
if isfile("data/tw1Re-DNS.asc")
    data, _ = readdlm("data/tw1Re-DNS.asc", header=true)
    plot!(data[:,1], data[:,2], 
        label = "DNS Data", 
        color = :red, 
        # markershape = :cross
    )
end

# %%

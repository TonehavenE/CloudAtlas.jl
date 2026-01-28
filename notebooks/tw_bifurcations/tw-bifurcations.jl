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
using CloudAtlas, BifurcationKit, ChannelflowWrapper

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

macro suppress(ex)
    quote
        # Generate a unique name for the old stdout to avoid variable collision
        local old_stdout = stdout
        redirect_stdout(devnull)
        try
            # We use esc(ex) to run the expression in the caller's scope
            $(esc(ex))
        finally
            redirect_stdout(old_stdout)
        end
    end
end

sx, sy, sz, tx, tz = halfbox_symmetries()

pwd()

# %% [markdown]
# ## Finding a Traveling Wave Solution

# %%
# Parameters
hookparams = SearchParams(ftol=1e-08, xtol=1e-12, Nnewton=30,Nhook=8,δ=0.01, verbosity=0)
R = 200
cx0 = 0.000 # values from paper
cz0 = 0.009

α, γ = 1.0, 2.0                     # Fourier wavenumbers α, γ = 2π/Lx, 2π/Lz
H = [(sx*sy)*(tx*tz)]               # Generators of the symmetric subspace of TW1
normalize = true                    # Normalize the basis set or not?

# The DNS file to project from (ensure this path is correct)
dns_file = "TW1-2pi1piRe200-40x49x40.nc" 

# List of resolutions to test: [(J, K, L), ...]
# discretizations = [(1, 1, 1), (1, 1, 2), (1, 1, 3), (1, 2, 3), (1, 3, 5), (2, 4, 7), (3, 5, 9)]
discretizations = [(1, 1, 2), (1, 1, 3), (1, 2, 3), (1, 3, 5), (2, 4, 7)]
# discretizations = [(1, 1, 3), (1, 2, 3), (1, 3, 5), (2, 4, 7)]
# discretizations = [(1, 1, 3), (1, 2, 3)]


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
function compute_branch(J, K, L, udns_file; Re_start=200.0, α=1.0, γ=2.0, H=[(sx*sy)*(tx*tz)])
    model = TWModel(α, γ, J, K, L, H, normalize=true)
    m = length(model)
    println("Model dimension m = $m")

    #  Generate Initial Guess (Project DNS onto THIS basis)
    filename_guess = "tmp_projection_J$(J)K$(K)L$(L).asc"
    x0 = field2coeff(model.ijkl, udns_file, filename_guess)
    # Construct state vector ξ = [x; cx; cz]
    cx0, cz0 = 0.000, 0.009
    ξ0 = [x0; cx0; cz0]

    # 3. Solve for Fixed Point (Newton/Hookstep) at Re_start
    println("Finding fixed point at Re=$Re_start...")
    
    ξ_final, converged = hookstepsolve_tw(model, Re_start, ξ0, hookparams)
    
    if !converged
        println("WARNING: Newton solver did not converge for $J,$K,$L")
        return nothing
    end

    # Run Continuation
    println("Running continuation...")
    branch = tw_z_branch_continuation(model, ξ_final, Re_start; 
                                    Re_min=100.0, Re_max=500.0, max_steps=1000)
    
    return branch
end

# %%
# --- Plotting ---
p = plot(
    xlabel = "Reynolds Number (Re)",
    ylabel = "Power Input",
    title = "Convergence to DNS",
    legend = :topright,
    grid = true,
    size=(1920, 1080)
)

# Plot DNS Data
if isfile("tw1Re-DNS.asc")
    dns_data = myreaddlm("tw1Re-DNS.asc")
    plot!(p, dns_data[:,1], dns_data[:,2], 
        label="DNS", color=:black, linewidth=2, linestyle=:dash)
end

# %%
# Storage for results
branches = Dict()

colors = [:blue, :green, :red, :purple, :orange, :pink, :teal]
for (i, jkl) in enumerate(discretizations)
    J, K, L = jkl
    println("\n" * "="^60)
    println("Starting analysis for Resolution: J=$J, K=$K, L=$L")
    println("="^60)
    br = @suppress compute_branch(J, K, L, dns_file)
    println("Branch complete!")
    if br !== nothing
        branches[(J,K,L)] = br
        
        # Plot the branch
        plot!(p, br.param, br.pow, 
            label="J,K,L = $jkl", 
            linewidth=2, 
            color=colors[mod1(i, length(colors))]
        )
    end
    display(p)
end

# %%
display(p)
savefig("convergence_plot.png")

# %%

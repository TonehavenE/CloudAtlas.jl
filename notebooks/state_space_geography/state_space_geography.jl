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
using CloudAtlas
using LinearAlgebra
using Base.Threads
using CairoMakie
using DifferentialEquations
using Dates
using LinearAlgebra
using Statistics

# %%
# Using shared fingerprint utilities from CloudAtlas

# %%
"""
    find_fixed_points(model, Re; n_attempts=50, xnorm=0.4)

Searches for unique Traveling Wave solutions for a specific model/discretization.
Returns a vector of solution vectors ξ (state + speeds).
"""
function find_fixed_points(model::TWModel, Re::Real; n_attempts=50, xnorm=0.4, hookparams=CloudAtlas.SearchParams())
    
    m = length(model)
    solutions = Vector{Vector{Float64}}()
    fingerprints = Vector{SolutionFingerprint}()
    
    # Thread-safe locks
    data_lock = ReentrantLock()
    io_lock = ReentrantLock()
    
    println("Starting search for TW solutions (Re=$Re, Attempts=$n_attempts)...")
    
    @threads for i in 1:n_attempts
        print(".")
        # 1. Random Initial Guess
        x_guess = randn(m)
        x_guess = xnorm / norm(x_guess) * x_guess
        
        # Small random wave speeds to break symmetry
        cx_guess = model.keep_cx ? randn() * 0.1 : 0
        cz_guess = model.keep_cz ? randn() * 0.1 : 0
        ξ_guess = [x_guess; cx_guess; cz_guess]

        # 2. Solve with fixed-reference phase constraints
        ξ_star, converged = CloudAtlas.hookstepsolve(model, Re, ξ_guess, hookparams)
        
        # 4. Validation & Storage
        if converged
            # Check basic physical properties (non-trivial solution)
            x_sol = ξ_star[1:m]
            cx = ξ_star[m+1]
            cz = ξ_star[m+2]
            if norm(x_sol) > 1e-2 && (cx > 0 || cz > 0)
                fp = fingerprint(model, ξ_star; include_shear = false)
                
                lock(data_lock) do
                    if is_distinct(fp, fingerprints; tol = (cx = 1e-2, cz = 1e-2, nm = 1e-2, shear = 1e-2), compare_shear = false)
                        push!(fingerprints, fp)
                        push!(solutions, ξ_star)
                        lock(io_lock) do 
                            println("  \n[Thread $(threadid())] Found unique TW: cx=$(round(fp.cx, digits=4)), |x|=$(round(fp.nm, digits=4))")
                        end
                    end
                end
            end
        end
    end
    
    println("Search complete. Found $(length(solutions)) unique solutions.")
    return solutions
end

# %%
"""
    generate_turbulent_trajectory(model, Re, tspan; xnorm=0.4)

Generates a time-evolution trajectory starting from a random initial condition.
Returns the ODE solution object.
"""
function generate_turbulent_trajectory(model::TWModel, Re::Real, tspan; xnorm=0.4)
    println("Integrating turbulent trajectory over t=$tspan...")
    
    m = length(model)
    
    # Random initial condition for state x (no wave speeds needed for ODE init x0)
    x0 = randn(m)
    x0 = xnorm / norm(x0) * x0
    
    # We must construct a full ξ vector for integrate_flow, even if we assume cx=cz=0 initially
    # integrate_flow handles the ξ unpacking internally.
    ξ_init = [x0; 0.0; 0.0] 
    
    # Run integration (lab_frame=true effectively simulates DNS)
    sol = integrate_flow(model, ODEState(extract_components(ξ_init, model)...), tspan; R=Re, saveat=0.5, lab_frame=true)
    
    return sol
end

# %%
"""
    plot_phase_space_map(model, tw_solutions, traj_sol)

Plots the (I, D) phase portrait.
- Blue dots: Traveling Wave solutions (Fixed Points)
- Black line: Time evolution trajectory
- Dashed line: Laminar/Equilibrium (I=D)
"""
function plot_phase_space_map(model::TWModel, tw_solutions::Vector, traj_sol, D_matrix = nothing)
    
    # 1. Build Dissipation Matrix (expensive, do once)
    if isnothing(D_matrix)
        println("Building dissipation matrix...")
        D_matrix = build_dissipation_matrix(model)
    end
    
    # 2. Calculate I/D for Fixed Points (TWs)
    I_tws = Float64[]
    D_tws = Float64[]
    
    for ξ in tw_solutions
        x, _, _ = extract_components(ξ, model)
        push!(I_tws, power_input(model, x))
        push!(D_tws, dissipation_rate(D_matrix, x))
    end
    
    # 3. Calculate I/D for Trajectory
    println("Calculating metrics for trajectory...")
    I_traj = [CloudAtlas.power_input(model, u) for u in traj_sol.u]
    D_traj = [CloudAtlas.dissipation_rate(D_matrix, u) for u in traj_sol.u]
    
    # 4. Plotting
    fig = Figure(size=(800, 600))
    ax = Axis(fig[1, 1], 
        title="State Space: Power Input vs Dissipation",
        xlabel="Dissipation Rate (D)", 
        ylabel="Power Input (I)"
    )
    
    # Plot Trajectory
    lines!(ax, D_traj, I_traj, color=:black, alpha=0.6, label="Turbulent Trajectory")
    # Mark start and end of trajectory
    scatter!(ax, [D_traj[1]], [I_traj[1]], color=:green, marker=:circle, label="Start")
    scatter!(ax, [D_traj[end]], [I_traj[end]], color=:red, marker=:x, label="End")

    # Plot Fixed Points (TWs)
    scatter!(ax, D_tws, I_tws, color=:blue, markersize=20, label="TW Solutions")
    
    # Plot I=D Line (Equilibrium)
    # Find plot limits to draw the line nicely
    all_D = [D_tws; D_traj]
    all_I = [I_tws; I_traj]
    min_val = min(minimum(all_D), minimum(all_I)) * 0.9
    max_val = max(maximum(all_D), maximum(all_I)) * 1.1
    
    lines!(ax, [min_val, max_val], [min_val, max_val], linestyle=:dash, color=:grey, label="Laminar (I=D)")
    
    axislegend(ax, position=:lt)
    
    return fig
end

# %%
# --- Configuration ---
α, γ = 2π/6.0, 2π/4.0 
Re = 400.0
# Define Discretization
J, K, L = 2, 2, 5
sx, sy, sz, tx, tz = CloudAtlas.halfbox_symmetries()
H = [sz*tx]

# --- 1. Initialize Model ---
model = TWModel(α, γ, J, K, L, H)
model.m

# %%
# --- 2. Find Unique Solutions ---
# This runs the fuzzing search in memory
tw_solutions = find_fixed_points(model, Re; n_attempts=1000);
if isempty(tw_solutions)
    println("No TW solutions found. Try increasing attempts or checking parameters.")
end

# %%
D_matrix = build_dissipation_matrix(model);

# %%
trajectory_sol = generate_turbulent_trajectory(model, Re, (0.0, 1000.0); xnorm=0.1)
plot_id_series(model, trajectory_sol, D_matrix)

# %%
# visualize fixed points nearby
fig = plot_phase_space_map(model, tw_solutions, trajectory_sol, D_matrix)
display(fig)

# %%
"""
    find_trajectory_minima(model, sol, D_matrix)

Analyzes a trajectory to find 'Slow Points' in the I-D phase plane.
Returns a list of (time_index, state_vector) tuples to use as Newton guesses.
"""
function find_trajectory_minima(model, sol, D_matrix; window=5)
    # Compute I and D time series
    I_vals = [CloudAtlas.power_input(model, u) for u in sol.u]
    D_vals = [CloudAtlas.dissipation_rate(D_matrix, u) for u in sol.u]
    
    # compute "Phase Velocity" in I-D plane (simple finite difference)
    # velocity ~ sqrt((dI/dt)^2 + (dD/dt)^2)
    vel_id = zeros(length(sol.t))
    
    for i in 2:length(sol.t)
        dt = sol.t[i] - sol.t[i-1]
        dI = (I_vals[i] - I_vals[i-1]) / dt
        dD = (D_vals[i] - D_vals[i-1]) / dt
        vel_id[i] = sqrt(dI^2 + dD^2)
    end
    
    # Find Local Minima (The system is "lingering" near a solution)
    guesses = []
    
    # Simple peak/trough detection
    for i in 1+window : length(vel_id)-window
        # Check if this point is smaller than its neighbors in the window
        local_segment = vel_id[i-window : i+window]
        if vel_id[i] == minimum(local_segment) && vel_id[i] < 0.5 # Threshold helps filter noise
            
            # Construct the guess vector ξ for the Newton solver
            x_guess = sol.u[i]
            
            # small random perturbations help avoid singular jacobians
            cx_guess = model.keep_cx ? randn() * 0.01 : 0
            cz_guess = model.keep_cz ? randn() * 0.01 : 0
            
            ξ_guess = [x_guess; cx_guess; cz_guess]
            
            push!(guesses, (sol.t[i], ξ_guess))
        end
    end
    
    return guesses, I_vals, D_vals, vel_id
end

# %%
"""
    harvest_solutions_from_trajectory(model, Re, sol)

Runs the Newton solver starting from "Slow Points" in the trajectory.
"""
function harvest_solutions_from_trajectory(model::TWModel, Re::Real, sol)
    # 1. Precompute matrix
    D_mat = CloudAtlas.build_dissipation_matrix(model)
    
    # 2. Find promising start points
    candidates, I_vals, D_vals, vel = find_trajectory_minima(model, sol, D_mat)
    
    println("Found $(length(candidates)) candidate snapshots from trajectory.")
    
    solutions = []
    
    # 3. Newton Search
    # Reuse the logic from your fuzzing code
    hookparams = CloudAtlas.SearchParams(Nnewton=40, Nhook=5) # More generous for these guesses
    
    for (t_val, ξ_guess) in candidates
        print("  Searching from snapshot at t=$t_val... ")
        ξ_star, converged = CloudAtlas.hookstepsolve(model, Re, ξ_guess, hookparams)
        
        if converged
            # Check if it's a trivial solution (Laminar flow has norm ≈ 0 usually, depending on basis)
            # Assuming basis is perturbation, laminar is 0.
            m = length(model)
            x_sol = ξ_star[1:m]
            cx = ξ_star[m+1]
            cz = ξ_star[m+2]
            if norm(x_sol) > 1e-3 && (cx > 0 || cz > 0)
                println("Converged! (Speeds: $(ξ_star[end-1]), $(ξ_star[end]))")
                push!(solutions, ξ_star)
            else
                println("Converged to Laminar (trivial).")
            end
        else
            println("Failed.")
        end
    end
    
    return unique(solutions), I_vals, D_vals, candidates
end

# %%
# 1. Generate a long turbulent trajectory (e.g., T=500 or 1000)
# Start from a random kick if you don't have one yet.
long_sol = generate_turbulent_trajectory(model, Re, (0.0, 1000.0); xnorm=0.3)

# 2. Harvest solutions
new_solutions, I, D, candidates = harvest_solutions_from_trajectory(model, Re, long_sol)

# 3. Plot the results
# This will show the trajectory, the points you picked (Slow Points), and the final converged solutions
fig = plot_phase_space_map(model, new_solutions, long_sol)

# (Optional) Overlay the candidate start points to verify logic
# You'll need to manually add scatter points for the candidates' I/D values

# %%
using ChannelflowWrapper
reference_field_converted = "reference_field_$(α)_$(γ).nc"
reference_path = "./TW1-2pi1piRe200-40x49x40.nc"
changegrid(reference_path, reference_field_converted; al=α, ga=γ)

# %% jupyter={"outputs_hidden": true}
base_dir="cont_results"
m = model.m
T = 10.0
symm_file = "./sztx.asc"

for ξ_star in new_solutions
    timestamp = Dates.format(now(), "MM-DD-HHMMSS")
    sol_dir = joinpath(base_dir, "sol_$(J)_$(K)_$(L)_$(timestamp)")
    mkpath(sol_dir)
    guess_path = joinpath(sol_dir, "u_guess.nc")
    sigma_file = joinpath(sol_dir, "sigma.asc")
    
    coeff2field(ξ_star[1:m], model.ijkl, reference_field_converted, guess_path)
    save_sigma(model, ξ_star[end - 1], ξ_star[end], T, sigma_file)
    
    try
        findsoln(guess_path;
            R = Re, eqb = true, xrel = model.keep_cx, zrel = model.keep_cz,
            symms = abspath(symm_file), sigma = sigma_file, od = sol_dir, T = T
        )
    catch e
        println("findsoln failed: $e")
    end
end

# %%

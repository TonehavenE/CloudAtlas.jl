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
# # Trajectory-Seeded Traveling-Wave Discovery (Re=300)
#
# This notebook uses a turbulent trajectory to generate “slow points” as
# initial guesses for TW hookstep refinement. It complements random fuzzing
# by focusing on dynamically relevant regions of state space.

# %%
using CloudAtlas
using LinearAlgebra
using Statistics
using Random
using Dates
using DelimitedFiles
using Serialization
using Base.Threads
using DifferentialEquations
using CairoMakie

# %% [markdown]
# ## Configuration

# %%
Re = 300.0

# Domain sizes (α = 2π/Lx, γ = 2π/Lz)
α, γ = 2π/6.0, 2π/4.0

# Discretization
J, K, L = 2, 4, 7

# Symmetry group (combined generators)
sx, sy, sz, tx, tz = CloudAtlas.halfbox_symmetries()
H = [sz * tx]

# Trajectory settings
traj_tspan = (0.0, 500.0)
traj_saveat = 0.5
xnorm = 0.2
slow_window = 5
slow_vel_threshold = 0.5

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

# Acceptance thresholds
norm_threshold = 1e-3
speed_threshold = 1e-5

# Output
out_dir = joinpath(@__DIR__, "tw_trajectory_seeded_re300")
mkpath(out_dir)

# %% [markdown]
# ## Helper types and functions

function find_trajectory_minima(model, sol, D_matrix; window=5, vel_threshold=0.5)
    I_vals = [CloudAtlas.power_input(model, u) for u in sol.u]
    D_vals = [CloudAtlas.dissipation_rate(D_matrix, u) for u in sol.u]

    vel_id = zeros(length(sol.t))
    for i in 2:length(sol.t)
        dt = sol.t[i] - sol.t[i-1]
        dI = (I_vals[i] - I_vals[i-1]) / dt
        dD = (D_vals[i] - D_vals[i-1]) / dt
        vel_id[i] = sqrt(dI^2 + dD^2)
    end

    guesses = []
    for i in 1+window : length(vel_id)-window
        local_segment = vel_id[i-window : i+window]
        if vel_id[i] == minimum(local_segment) && vel_id[i] < vel_threshold
            x_guess = sol.u[i]
            cx_guess = model.keep_cx ? randn() * 0.01 : 0.0
            cz_guess = model.keep_cz ? randn() * 0.01 : 0.0
            ξ_guess = [x_guess; cx_guess; cz_guess]
            push!(guesses, (sol.t[i], ξ_guess))
        end
    end

    return guesses, I_vals, D_vals, vel_id
end

# %% [markdown]
# ## Build model and generate trajectory

# %%
model = ODEModel(α, γ, J, K, L, H; normalize=false, tw=true)

# Integrate a turbulent trajectory (lab_frame=true gives drift in lab frame)
println("Integrating trajectory over t = $(traj_tspan)...")
seed_state = begin
    x0 = randn(length(model))
    x0 = xnorm / norm(x0) * x0
    ODEState(x0)
end
traj = integrate_flow(model, seed_state, traj_tspan; R=Re, saveat=traj_saveat, lab_frame=true)

# %% [markdown]
# ## Plot trajectory + select slow points

# %%
D_matrix = build_dissipation_matrix(model)
guesses, I_vals, D_vals, vel_id = find_trajectory_minima(model, traj, D_matrix; window=slow_window, vel_threshold=slow_vel_threshold)
println("Selected $(length(guesses)) candidate slow points")

fig_traj = Figure(size=(800, 600))
ax = Axis(fig_traj[1, 1], xlabel="Dissipation (D)", ylabel="Power Input (I)", title="Trajectory in I-D plane")
lines!(ax, D_vals, I_vals, color=:black, alpha=0.6)
scatter!(ax, [D_vals[1]], [I_vals[1]], color=:green, marker=:circle)
scatter!(ax, [D_vals[end]], [I_vals[end]], color=:red, marker=:x)
save(joinpath(out_dir, "trajectory_id_plane.png"), fig_traj)

# %% [markdown]
# ## Refine slow points into TWs

# %%
solutions = Vector{Vector{Float64}}()
fp_archive = Vector{SolutionFingerprint}()
data_lock = ReentrantLock()

progress = Threads.Atomic{Int}(0)
progress_every = max(1, length(guesses) ÷ 100)

@threads for i in 1:length(guesses)
    _, ξ_guess = guesses[i]

    ξ_star, converged = CloudAtlas.hookstepsolve(model, Re, ξ_guess, hookparams)

    if converged
        x, cx, cz = extract_components(ξ_star, model)
        if norm(x) > norm_threshold && (abs(cx) > speed_threshold || abs(cz) > speed_threshold)
            fp = fingerprint(model, ξ_star)
            lock(data_lock) do
                if is_distinct(fp, fp_archive)
                    push!(fp_archive, fp)
                    push!(solutions, ξ_star)
                end
            end
        end
    end

    done = Threads.atomic_add!(progress, 1)
    if done % progress_every == 0 || done == length(guesses)
        pct = round(100 * done / length(guesses); digits=1)
        println("Progress: $(done)/$(length(guesses)) ($(pct)%) (unique=$(length(solutions)))")
    end
end

println("Found $(length(solutions)) unique TWs from trajectory seeding.")

# %% [markdown]
# ## Save results

# %%
summary_path = joinpath(out_dir, "solutions_summary.csv")
open(summary_path, "w") do io
    println(io, "id,cx,cz,norm,shear")
    for (i, ξ) in enumerate(solutions)
        x, cx, cz = extract_components(ξ, model)
        println(io, "$(i),$(cx),$(cz),$(norm(x)),$(shear(x, model))")
    end
end

serialized_path = joinpath(out_dir, "solutions.bin")
open(serialized_path, "w") do io
    serialize(io, solutions)
end

# %% [markdown]
# ## Quick visualization

# %%
if !isempty(solutions)
    D_matrix = build_dissipation_matrix(model)
    I_vals = [power_input(model, extract_components(ξ, model)[1]) for ξ in solutions]
    D_vals = [dissipation_rate(D_matrix, extract_components(ξ, model)[1]) for ξ in solutions]

    fig = Figure(size=(700, 500))
    ax = Axis(fig[1, 1], xlabel="Dissipation (D)", ylabel="Power Input (I)", title="Trajectory-seeded TWs")
    scatter!(ax, D_vals, I_vals, color=:dodgerblue, markersize=10)
    save(joinpath(out_dir, "tw_seeded_id_plane.png"), fig)
end

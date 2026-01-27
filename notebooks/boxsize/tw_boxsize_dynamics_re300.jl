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
# # Boxsize Dynamics Sweep (Re=300)
#
# Instead of TW yield, score box sizes by how "alive" their trajectories are
# in the (I, D) plane. Boxes that integrate cleanly and show rich dynamics
# are likely better targets for TW discovery.

# %%
using CloudAtlas
using LinearAlgebra
using Statistics
using Random
using Dates
using DelimitedFiles
using Base.Threads
using CairoMakie

# %% [markdown]
# ## Configuration

# %%
Re = 300.0
J, K, L = 1, 2, 3

# α = 2π/Lx, γ = 2π/Lz
alpha_vals = range(2π/8.0, 2π/4.0, length=6)
gamma_vals = range(2π/8.0, 2π/4.0, length=6)

# Integration settings
traj_tspan = (0.0, 200.0)
traj_saveat = 0.5
xnorm = 0.2

# Turbulence indicator threshold in D (relative to laminar D=1)
D_turb_threshold = 1.02

# Symmetry groups (combined generators)
sx, sy, sz, tx, tz = CloudAtlas.halfbox_symmetries()

symmetry_groups = [
    (name = "sxytxz", H = [(sx * sy) * (tx * tz)]),
    (name = "sztx",   H = [sz * tx]),
    (name = "tx",     H = [tx]),
    (name = "tz",     H = [tz]),
    (name = "txtz",   H = [tx * tz]),
    (name = "sxtx",   H = [sx * tx]),
    (name = "sxtz",   H = [sx * tz]),
    (name = "sztz",   H = [sz * tz]),
]

out_dir = joinpath(@__DIR__, "tw_boxsize_dynamics_re300")
mkpath(out_dir)

# %% [markdown]
# ## Helpers

# %%
function seeded_state(model; xnorm=0.2, seed=0x51A)
    rng = MersenneTwister(seed)
    x0 = randn(rng, length(model))
    x0 = xnorm / norm(x0) * x0
    return ODEState(x0)
end

function trajectory_metrics(model, sol, D_matrix; D_threshold=1.02)
    I_vals = [power_input(model, u) for u in sol.u]
    D_vals = [dissipation_rate(D_matrix, u) for u in sol.u]

    std_I = std(I_vals)
    std_D = std(D_vals)
    range_D = maximum(D_vals) - minimum(D_vals)
    turb_frac = count(>(D_threshold), D_vals) / length(D_vals)

    return (; std_I, std_D, range_D, turb_frac, I_vals, D_vals)
end

function plot_id_trajectory(I_vals, D_vals; title)
    fig = Figure(size=(700, 500))
    ax = Axis(fig[1, 1], xlabel="Dissipation (D)", ylabel="Power Input (I)", title=title)
    lines!(ax, D_vals, I_vals, color=:black, alpha=0.7)
    scatter!(ax, [D_vals[1]], [I_vals[1]], color=:green, marker=:circle)
    scatter!(ax, [D_vals[end]], [I_vals[end]], color=:red, marker=:x)
    return fig
end

function heatmap_metric(metric, alpha_vals, gamma_vals; title, label, outpath)
    fig = Figure(size=(900, 700))
    ax = Axis(fig[1, 1], xlabel="α", ylabel="γ", title=title)
    hm = heatmap!(ax, alpha_vals, gamma_vals, metric'; colormap=:viridis)
    Colorbar(fig[1, 2], hm, label=label)
    save(outpath, fig)
    return fig
end

# %% [markdown]
# ## Sweep (threaded over grid points)

# %%
function sweep_dynamics(symm; alpha_vals, gamma_vals)
    nα = length(alpha_vals)
    nγ = length(gamma_vals)

    stdD = fill(NaN, nα, nγ)
    rangeD = fill(NaN, nα, nγ)
    turbfrac = fill(NaN, nα, nγ)
    failures = zeros(Int, nα, nγ)

    total = nα * nγ
    progress = Threads.Atomic{Int}(0)
    progress_every = max(1, total ÷ 100)

    @threads for idx in 1:total
        i, j = ind2sub((nα, nγ), idx)
        α = alpha_vals[i]
        γ = gamma_vals[j]

        try
            model = ODEModel(α, γ, J, K, L, symm.H; normalize=false, tw=true)
            D_matrix = build_dissipation_matrix(model)

            state0 = seeded_state(model; xnorm=xnorm, seed=0x51A + idx)
            sol = integrate_flow(model, state0, traj_tspan; R=Re, saveat=traj_saveat, lab_frame=true)

            metrics = trajectory_metrics(model, sol, D_matrix; D_threshold=D_turb_threshold)
            stdD[i, j] = metrics.std_D
            rangeD[i, j] = metrics.range_D
            turbfrac[i, j] = metrics.turb_frac

            # Save one representative trajectory per symmetry (center grid)
            if i == ceil(Int, nα/2) && j == ceil(Int, nγ/2)
                fig = plot_id_trajectory(metrics.I_vals, metrics.D_vals; title="I-D trajectory: $(symm.name) @ α=$(round(α,digits=3)), γ=$(round(γ,digits=3))")
                save(joinpath(out_dir, "trajectory_id_$(symm.name).png"), fig)
            end
        catch err
            failures[i, j] = 1
            @warn "Dynamics sweep failed at α=$(α), γ=$(γ), symm=$(symm.name)" exception=(err, catch_backtrace())
        end

        done = Threads.atomic_add!(progress, 1)
        if done % progress_every == 0 || done == total
            pct = round(100 * done / total; digits=1)
            println("Grid progress ($(symm.name)): $(done)/$(total) ($(pct)%)")
        end
    end

    return (; stdD, rangeD, turbfrac, failures)
end

# %% [markdown]
# ## Run sweep + plot heatmaps

# %%
results = Dict{String, Any}()

for symm in symmetry_groups
    println("\n=== Symmetry: $(symm.name) ===")
    res = sweep_dynamics(symm; alpha_vals=alpha_vals, gamma_vals=gamma_vals)
    results[symm.name] = res

    # Save raw metrics
    writedlm(joinpath(out_dir, "stdD_$(symm.name).csv"), res.stdD, ',')
    writedlm(joinpath(out_dir, "rangeD_$(symm.name).csv"), res.rangeD, ',')
    writedlm(joinpath(out_dir, "turbfrac_$(symm.name).csv"), res.turbfrac, ',')
    writedlm(joinpath(out_dir, "failures_$(symm.name).csv"), res.failures, ',')

    # Heatmaps
    heatmap_metric(res.stdD, alpha_vals, gamma_vals;
        title="std(D): $(symm.name)",
        label="std(D)",
        outpath=joinpath(out_dir, "heatmap_stdD_$(symm.name).png"),
    )
    heatmap_metric(res.rangeD, alpha_vals, gamma_vals;
        title="range(D): $(symm.name)",
        label="range(D)",
        outpath=joinpath(out_dir, "heatmap_rangeD_$(symm.name).png"),
    )
    heatmap_metric(res.turbfrac, alpha_vals, gamma_vals;
        title="turbulent fraction: $(symm.name)",
        label="frac(D > $(D_turb_threshold))",
        outpath=joinpath(out_dir, "heatmap_turbfrac_$(symm.name).png"),
    )
end

# %% [markdown]
# ## Notes
# - Set `JULIA_NUM_THREADS` before launching Jupyter to enable threading.
# - `build_dissipation_matrix` is expensive; keep the grid modest at first.
# - Boxes with high `std(D)` and `turbfrac` are good TW hunting grounds.

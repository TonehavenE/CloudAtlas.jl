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
import Pkg
Pkg.activate("../../.")

# %% [markdown]
# # Minimal findsoln debug (Re=300)
#
# This notebook loads a single candidate from `solutions.bin` and runs one
# Channelflow `findsoln` in an isolated output directory.

# %%
using CloudAtlas
using Serialization
using Dates
using ChannelflowWrapper
using Base.Threads

# %% [markdown]
# ## Configuration

# %%
# Domain sizes (α = 2π/Lx, γ = 2π/Lz)
α, γ = 2π/6.0, 2π/4.0
Re = 300.0

# Pick the symmetry group and discretization you want to test
symm_name = "sxytxz"
J, K, L = 1, 2, 3

# Which solutions in solutions.bin?
solution_idx = 1
solution_idx2 = 2

# Paths
base_dir = @__DIR__
solutions_path = joinpath(base_dir, "tw_discovery_re300", symm_name, "jkl_$(J)_$(K)_$(L)", "solutions.bin")
reference_path = joinpath(base_dir, "TW1-2pi1piRe200-40x49x40.nc")
reference_field_converted = joinpath(base_dir, "tw_discovery_re300", "reference_field_$(α)_$(γ).nc")

symm_file = joinpath(base_dir, "$(symm_name).asc")

# findsoln settings
T = 10.0

# %% [markdown]
# ## Load one candidate

# %%
solutions = open(solutions_path, "r") do io
    deserialize(io)
end

@assert 1 <= solution_idx <= length(solutions)
@assert 1 <= solution_idx2 <= length(solutions)

# %% [markdown]
# ## Build model + run two findsoln jobs

# %%
sx, sy, sz, tx, tz = CloudAtlas.halfbox_symmetries()
H = [(sx * sy) * (tx * tz)]

model = ODEModel(α, γ, J, K, L, H;
    normalize = false,
    tw = true,
)

# Ensure reference field exists at the requested α,γ
if !isfile(reference_field_converted)
    changegrid(reference_path, reference_field_converted; al = α, ga = γ)
end

function run_findsoln(idx::Int)
    ξ = solutions[idx]
    x, cx, cz = extract_components(ξ, model)

    stamp = Dates.format(now(), "MM-DD-HHMMSS")
    sol_dir = joinpath(base_dir, "tw_discovery_re300", "debug_findsoln", "sol_$(idx)_$(stamp)")
    mkpath(sol_dir)

    guess_path = joinpath(sol_dir, "u_guess.nc")
    sigma_file = joinpath(sol_dir, "sigma.asc")

    println("[Thread $(threadid())] coeff2field idx=$(idx)")
    coeff2field(x, model.ijkl, reference_field_converted, guess_path; workdir = sol_dir)
    println("[Thread $(threadid())] save_sigma idx=$(idx)")
    save_sigma(model, cx, cz, T, sigma_file)

    println("[Thread $(threadid())] findsoln start idx=$(idx)")
    findsoln(guess_path;
        workdir = sol_dir,
        R = Re,
        eqb = true,
        xrel = model.keep_cx,
        zrel = model.keep_cz,
        symms = abspath(symm_file),
        sigma = sigma_file,
        od = sol_dir,
        T = T,
    )
    println("[Thread $(threadid())] findsoln done idx=$(idx)")
end

indices = [solution_idx, solution_idx2]
Threads.@threads for i in 1:length(indices)
    run_findsoln(indices[i])
end

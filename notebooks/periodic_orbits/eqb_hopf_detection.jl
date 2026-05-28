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
# # EQ1 Hopf Detection
#
# Continues the EQ1 equilibrium branch with full eigenvalue computation enabled
# (`detect_bifurcation = 3`) to find Hopf bifurcation points on the upper branch.
#
# Once a Hopf is found, attempts to continue the periodic orbit branch from it
# using single-shooting (BK.ShootingProblem + DifferentialEquations.jl).
#
# ## Sections
# 1. Setup
# 2. Configuration
# 3. Build model and converge EQ1 seed
# 4. Equilibrium continuation with Hopf detection
# 5. Eigenvalue landscape along the branch
# 6. Periodic orbit continuation from Hopf

# %%
if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "../.."))
end

# %%
using CloudAtlas
using ChannelflowWrapper
using DifferentialEquations
using LinearAlgebra
using Plots
using Printf
using DelimitedFiles
import BifurcationKit as BK

ENV["GKSwstype"] = get(ENV, "GKSwstype", "100")
gr()

# %% [markdown]
# ## Configuration

# %%
# Domain / symmetry group (matches EQ1 seed file)
alpha = 1.0
gamma = 2.0
J = 1
K = 2
L = 5

# DNS EQ1 flowfield used as projection source (Re=300, 32x49x40 grid)
Re0      = 300.0
dns_file = joinpath(@__DIR__, "EQ1Re300-32x49x40.nc")

# Continuation range — extend well past the saddle-node to hunt for Hopf
Re_min    = 100.0
Re_max    = 700.0
max_steps = 800
dsmin     = 1e-7
dsmax     = 2.0

# Output directory
outdir = joinpath(@__DIR__, "eqb_hopf_outputs_$(J)_$(K)_$(L)")
mkpath(outdir)

# %% [markdown]
# ## Build model and converge EQ1 seed

# %%
sx, sy, sz, tx, tz = halfbox_symmetries()
H = [sx * sy * sz, sz * tx * tz]
model = ODEModel(alpha, gamma, J, K, L, H, normalize=true)
m = length(model)
println("Model dimension m = $m")

# %%
# Project the DNS flowfield onto the ODE basis via L2 inner products.
# This calls the Channelflow `projectfield` binary through ChannelflowWrapper,
# giving a proper initial guess at any (J,K,L) resolution.
isfile(dns_file) || error("DNS file not found: $dns_file")

proj_asc = joinpath(outdir, "xeq1_dns_projection_$(J)_$(K)_$(L).asc")
x_proj = ChannelflowWrapper.field2coeff(model.ijkl, dns_file, proj_asc; workdir = outdir)
xguess = size(x_proj, 2) == 1 ? vec(Float64.(x_proj[:, 1])) : vec(Float64.(x_proj))
@printf("Projected DNS → ODE basis: %dd  |x|=%.4f\n", length(xguess), norm(xguess))

hookparams = SearchParams(ftol = 1e-8, xtol = 1e-12, Nnewton = 30, Nhook = 8, verbosity = 0)
f_eq  = x -> model.f(x, Re0)
Df_eq = x -> model.Df(x, Re0)
xeq, ok = hookstepsolve(f_eq, Df_eq, xguess, hookparams)
ok || error("Hookstep failed to converge EQ1 seed at Re=$Re0 in ($J,$K,$L) basis")
@printf("EQ1 converged: |f|=%.2e  |x|=%.4f  power_input=%.6f\n",
        norm(model.f(xeq, Re0)), norm(xeq), power_input(model, xeq))

# %% [markdown]
# ## Equilibrium continuation with Hopf detection
#
# Key settings vs. the standard `eqb_bifurcation_triads` notebook:
# - `detect_bifurcation = 3`: full detection including Hopf (complex eigenvalue crossings)
# - `nev = m`: compute the full spectrum at each step (feasible for small ODE models)
# - Extended `Re_max` to search for Hopf on the upper branch

# %%
fp(x, p) = model.f(x, p[1])
prob = BK.BifurcationProblem(
    fp,
    xeq,
    [Float64(Re0)],
    1;
    record_from_solution = (x, p; k...) -> power_input(model, x),
    plot_solution        = (x, p; k...) -> power_input(model, x),
)

newton_opts = BK.NewtonPar(1e-10, 30, false, BK.DefaultLS(), BK.DefaultEig(), false, 1.0, 0.01)
cont_opts = BK.ContinuationPar(
    p_min               = Re_min,
    p_max               = Re_max,
    n_inversion         = 20,
    dsmin               = dsmin,
    dsmax               = dsmax,
    max_steps           = max_steps,
    newton_options      = newton_opts,
    detect_bifurcation  = 3,     # full detection: fold, branch, Hopf
    nev                 = 8,     # track leading 8 eigenvalues — enough to catch a Hopf pair
    save_eigenvectors   = false, # don't store eigenvector matrices at every step
)

println("Running equilibrium continuation (Re ∈ [$(Re_min), $(Re_max)]) ...")
br = BK.continuation(prob, BK.PALC(), cont_opts, bothside = true)
println("Done. $(length(br.branch)) steps, $(length(br.specialpoint)) special points.")

# %% [markdown]
# ## Special points detected

# %%
println("All special points on EQ1 branch:")
for (i, sp) in enumerate(br.specialpoint)
    t     = String(Symbol(getfield(sp, :type)))
    param = Float64(getfield(sp, :param))
    step  = Int(getfield(sp, :step))
    @printf("  [%2d]  %-12s  step=%4d  Re=%.5f\n", i, t, step, param)
end

hopf_indices = findall(sp -> Symbol(getfield(sp, :type)) == :hopf, br.specialpoint)
println("\nHopf points found: $(length(hopf_indices))")
for idx in hopf_indices
    sp = br.specialpoint[idx]
    Re_h = Float64(getfield(sp, :param))
    @printf("  Hopf #%d at Re = %.5f  (specialpoint index %d)\n", idx, Re_h, idx)
end

# %% [markdown]
# ## Branch and eigenvalue landscape

# %%
# Reconstruct Re and power_input along the branch
branch_Re = Float64.(br.branch.param)
branch_I  = Float64.(br.branch.x)  # record_from_solution scalar → stored as .x

p_branch = plot(
    branch_Re, branch_I;
    lw = 2, color = :black,
    xlabel = "Re", ylabel = "power input",
    title  = "EQ1 branch (α=$alpha, γ=$gamma, J=$J K=$K L=$L)",
    label  = "EQ1",
)
for idx in hopf_indices
    sp    = br.specialpoint[idx]
    Re_h  = Float64(getfield(sp, :param))
    step  = Int(getfield(sp, :step))
    I_h   = length(branch_I) > step ? branch_I[clamp(step+1, 1, end)] : NaN
    scatter!([Re_h], [I_h];
             markersize = 9, markershape = :star5, color = :red,
             label = "Hopf (Re≈$(round(Re_h, digits=1)))")
end
savefig(p_branch, joinpath(outdir, "eq1_branch_with_hopf.png"))
display(p_branch)

# %%
# Eigenvalue landscape — max real part of spectrum at each step
if !isempty(br.eig)
    n_eig_steps  = length(br.eig)
    eig_steps    = 1:n_eig_steps
    max_real_eig = [maximum(real.(br.eig[i].eigenvals)) for i in eig_steps]

    # Also track the pair of eigenvalues with largest imaginary part
    # (these are the ones that go through the imaginary axis at a Hopf)
    leading_imag = [begin
        evs = br.eig[i].eigenvals
        # pick the eigenvalue with the largest imaginary magnitude
        evs[argmax(abs.(imag.(evs)))]
    end for i in eig_steps]

    p_stability = plot(
        eig_steps, max_real_eig;
        lw = 2, color = :black,
        xlabel = "continuation step", ylabel = "max Re(λ)",
        title  = "Stability along EQ1 branch",
        label  = "max Re(λ)",
    )
    hline!([0.0]; color = :red, lw = 1, ls = :dash, label = "Re(λ)=0")
    for idx in hopf_indices
        step = clamp(Int(getfield(br.specialpoint[idx], :step)) + 1, 1, n_eig_steps)
        scatter!([step], [max_real_eig[step]];
                 color = :red, markersize = 8, markershape = :star5,
                 label = "Hopf (step $step)")
    end
    savefig(p_stability, joinpath(outdir, "eigenvalue_landscape.png"))
    display(p_stability)

    # Imaginary part of the leading eigenvalue (oscillation frequency at Hopf)
    p_imag = plot(
        eig_steps, imag.(leading_imag);
        lw = 2, color = :blue,
        xlabel = "continuation step", ylabel = "Im(λ) of leading eigenvalue",
        title  = "Hopf frequency indicator",
        label  = "Im(λ_lead)",
    )
    hline!([0.0]; color = :black, lw = 1, ls = :dash, label = "")
    for idx in hopf_indices
        step = clamp(Int(getfield(br.specialpoint[idx], :step)) + 1, 1, n_eig_steps)
        scatter!([step], [imag(leading_imag[step])];
                 color = :red, markersize = 8, markershape = :star5,
                 label = "")
    end
    savefig(p_imag, joinpath(outdir, "hopf_frequency.png"))
    display(p_imag)

    println("\nEigenvalue summary at Hopf points:")
    for idx in hopf_indices
        step = clamp(Int(getfield(br.specialpoint[idx], :step)) + 1, 1, n_eig_steps)
        evs  = br.eig[step].eigenvals
        Re_h = Float64(getfield(br.specialpoint[idx], :param))
        # Sort by real part descending
        sorted = sort(evs, by = λ -> -real(λ))
        @printf("\n  Hopf at Re=%.4f (step %d):\n", Re_h, step)
        for (k, λ) in enumerate(sorted[1:min(6, end)])
            @printf("    λ_%d = %+.4f %+.4f i\n", k, real(λ), imag(λ))
        end
    end
end

# %% [markdown]
# ## Periodic orbit continuation from Hopf
#
# Uses `BK.ShootingProblem` (single shooting, M=1) via DifferentialEquations.jl.
# The ODE is integrated by Tsit5; the full Jacobian is handled by AutoDiff.
#
# If you get convergence issues, try:
# - Reducing `δp` (initial step along the PO branch)
# - Increasing `abstol`/`reltol` for the ODE integrator
# - Switching to `Rodas4()` if the ODE becomes stiff near the Hopf

# %%
if isempty(hopf_indices)
    println("No Hopf points found in Re ∈ [$(Re_min), $(Re_max)]. " *
            "Consider extending Re_max or checking the symmetry group.")
else
    hopf_idx = hopf_indices[1]
    Re_hopf  = Float64(getfield(br.specialpoint[hopf_idx], :param))
    @printf("Continuing POs from Hopf at Re = %.4f (specialpoint index %d)\n", Re_hopf, hopf_idx)

    # Use orthogonal collocation rather than shooting.
    #
    # Single-shooting integrates the orbit for its full period T≈215 with unstable
    # dynamics (multiple positive eigenvalues, max Re(λ)≈0.04), causing the
    # trajectory to blow up by ~e^9 per Newton step. Collocation discretizes the
    # orbit directly as a BVP, so there is no long-time integration and it stays
    # well-conditioned regardless of the stability of the underlying equilibrium.
    #
    # 30 time mesh points, polynomial order 3.
    # (100 points × order 4 at m≈65 modes → ~26000-variable dense Jacobian ≈ 5 GB)
    prob_coll = BK.PeriodicOrbitOCollProblem(30, 3)

    newton_po = BK.NewtonPar(1e-7, 30, true, BK.DefaultLS(), BK.DefaultEig(), false, 1.0, 0.01)
    opts_po = BK.ContinuationPar(
        p_min          = Re_min,
        p_max          = Re_max,
        dsmin          = 1e-5,
        dsmax          = 5.0,
        max_steps      = 200,
        newton_options = newton_po,
    )

    # For PeriodicOrbitOCollProblem the state vector x is the flattened collocation
    # array; the period T is the last element x[end], and the initial state is x[1:m].
    br_po = BK.continuation(
        br, hopf_idx, opts_po, prob_coll;
        δp          = 0.5,
        ampfactor   = 1.0,
        verbosity   = 2,
        plot        = false,
        record_from_solution = (x, p; k...) -> begin
            T  = x[end]
            u0 = x[1:m]
            (period = T, norm = norm(u0), shear = shear(u0, model),
             power  = power_input(model, u0))
        end,
    )

    println("\nPeriodic orbit branch:")
    n_po = length(br_po.branch)
    println("  Steps: $n_po")

    if n_po > 0
        periods = Float64.(br_po.branch.period)
        Re_po   = Float64.(br_po.branch.param)

        p_po = plot(
            Re_po, periods;
            lw = 2, color = :blue,
            xlabel = "Re", ylabel = "period T",
            title  = "Periodic orbit branch from EQ1 Hopf",
            label  = "PO period",
        )
        vline!([Re_hopf]; color = :red, ls = :dash, lw = 1, label = "Hopf")
        savefig(p_po, joinpath(outdir, "po_branch_period.png"))
        display(p_po)

        println("\n  Re range of PO branch: [$(minimum(Re_po)), $(maximum(Re_po))]")
        @printf("  Period range: [%.2f, %.2f]\n", minimum(filter(isfinite, periods)),
                                                    maximum(filter(isfinite, periods)))

        # Save PO branch summary
        open(joinpath(outdir, "po_branch_summary.csv"), "w") do io
            println(io, "step,Re,period,norm,shear,power")
            for i in 1:n_po
                println(io, "$(i),$(Re_po[i]),$(br_po.branch.period[i]),$(br_po.branch.norm[i]),$(br_po.branch.shear[i]),$(br_po.branch.power[i])")
            end
        end
        println("Saved: $(joinpath(outdir, "po_branch_summary.csv"))")
    end
end

# %% [markdown]
# ## Hookstep Newton convergence from BK branch seeds
#
# Strategy: the PO from the subcritical Hopf is likely unstable, so ODE
# integration won't find it. Instead we use the BK collocation branch directly
# as Newton seeds.
#
# For each target Re:
#   1. Try the N_neighbors closest branch points as seeds simultaneously.
#   2. If all fail, walk in Re from near the Hopf (small amplitude, easiest to
#      converge) toward the target in small steps, using each converged solution
#      as the seed for the next step.

# %%
if !isempty(hopf_indices) && @isdefined(br_po) && length(br_po.branch) > 0

    Re_targets  = [300.0]   # add more values here if needed
    N_neighbors = 5         # number of nearby branch points to try as seeds

    σ = Symmetry()  # exact PO (identity spatio-temporal symmetry)
    hookparams_rpo = SearchParams(
        ftol      = 1e-8,
        xtol      = 1e-10,
        δ         = 0.02,
        Nnewton   = 30,
        Nhook     = 6,
        Nmusearch = 6,
        verbosity = 1,
    )

    Re_po_vals = Float64.(br_po.branch.param)
    n_branch   = length(Re_po_vals)

    # Helper: extract (x0, T) from a collocation branch step
    function branch_seed(i)
        x_coll = br_po.sol[i].x
        Float64.(x_coll[1:m]), Float64(x_coll[end])
    end

    for Re_target in Re_targets
        @printf("\n─── Targeting Re = %.1f ───\n", Re_target)
        converged = false
        x0_sol = zeros(m); T_sol = NaN

        # --- Attempt 1: N closest branch points as direct seeds ---
        order = sortperm(abs.(Re_po_vals .- Re_target))
        for rank in 1:min(N_neighbors, n_branch)
            idx = order[rank]
            x0_seed, T_seed = branch_seed(idx)
            @printf("  Seed %d: branch step %d  Re=%.4f  T=%.2f\n",
                    rank, idx, Re_po_vals[idx], T_seed)
            x0_sol, _, _, T_sol, converged = hookstepsolve_rpo(
                model, Re_target, σ, x0_seed, 0.0, 0.0, T_seed, hookparams_rpo)
            if converged
                @printf("  ✓ Converged (seed %d): T=%.4f  |x0|=%.4f  shear=%.4f\n",
                        rank, T_sol, norm(x0_sol), shear(x0_sol, model))
                break
            end
        end

        # --- Attempt 2: Re-stepping from near the Hopf ---
        # Near the Hopf the amplitude is small so Newton has a wide basin.
        # Walk from there toward Re_target in steps of dRe.
        if !converged
            println("  Direct seeds failed — stepping in Re from near Hopf")

            # Start from the branch point closest to the Hopf
            Re_hopf_val = Float64(getfield(br.specialpoint[hopf_indices[1]], :param))
            idx_start   = argmin(abs.(Re_po_vals .- Re_hopf_val))
            x0_walk, T_walk = branch_seed(idx_start)
            Re_walk = Re_po_vals[idx_start]
            @printf("  Walk start: Re=%.4f  T=%.2f\n", Re_walk, T_walk)

            dRe   = sign(Re_target - Re_walk) * 2.0   # step size toward target
            steps = round(Int, abs(Re_target - Re_walk) / abs(dRe)) + 1
            for _ in 1:steps
                Re_next = clamp(Re_walk + dRe, min(Re_walk, Re_target),
                                               max(Re_walk, Re_target))
                x0_try, _, _, T_try, ok = hookstepsolve_rpo(
                    model, Re_next, σ, x0_walk, 0.0, 0.0, T_walk, hookparams_rpo)
                if ok
                    x0_walk, T_walk, Re_walk = x0_try, T_try, Re_next
                    @printf("  Walk Re=%.4f  T=%.4f  |x|=%.4f\n",
                            Re_walk, T_walk, norm(x0_walk))
                else
                    @printf("  Walk failed at Re=%.4f — stopping\n", Re_next)
                    break
                end
                abs(Re_walk - Re_target) < abs(dRe) / 2 && break
            end

            if abs(Re_walk - Re_target) < 5.0
                x0_sol, _, _, T_sol, converged = hookstepsolve_rpo(
                    model, Re_target, σ, x0_walk, 0.0, 0.0, T_walk, hookparams_rpo)
                converged && @printf("  ✓ Converged after walk: T=%.4f  |x0|=%.4f  shear=%.4f\n",
                                     T_sol, norm(x0_sol), shear(x0_sol, model))
            end
        end

        if converged
            out_name = @sprintf("po_re%d_T%.1f.asc", round(Int, Re_target), T_sol)
            CloudAtlas.save(x0_sol, joinpath(outdir, out_name))
            println("  Saved: $(joinpath(outdir, out_name))")
        else
            @printf("  No PO found at Re=%.1f\n", Re_target)
        end
    end
end

# %%
println("\nOutputs written to: $outdir")
println("  eq1_branch_with_hopf.png")
println("  eigenvalue_landscape.png")
println("  hopf_frequency.png")
isempty(hopf_indices) || println("  po_branch_period.png\n  po_branch_summary.csv")

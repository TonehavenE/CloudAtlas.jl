using LinearAlgebra, Polynomials, Plots, DelimitedFiles, Printf, Statistics
using CloudAtlas
import BifurcationKit as BK

# Headless plotting
ENV["GKSwstype"] = "100"

# --- Configuration ---
α, γ = 1.0, 2.0
Re_start = 200.0
sx, sy, sz, tx, tz = halfbox_symmetries()
H = [sx*sy*sz, sz*tx*tz]

# Representative ladder to reach high resolution efficiently
discretization_ladder = [
    (1, 1, 3), # 17d
    (1, 3, 5), # 59d
    (2, 4, 7), # 169d
    (3, 5, 9), # 367d
    (3, 5, 11) # 444d
]

# Initial guess for (1,1,3)
xguess_17d = [0.105, -0.0539, 0.388, -0.0172, -0.0133, 0.0113, -0.00706, 0.0240, -0.0344, 
              -0.00868, -0.01264, -0.0234, -0.0320, -0.0180, -0.00464, 0.0106, 0.0235]

# --- Analysis Functions ---

function modal_energy(model, x)
    Bx = model.B * x
    return 0.5 .* x .* Bx
end

function participation_ratio(v)
    s2 = sum(abs2, v)
    s4 = sum(abs2, abs2.(v))
    return s2^2 / (s4 + 1e-20)
end

function triad_energy_flux(model, x)
    N = model.N
    nnz = length(N.val)
    flux = Vector{Float64}(undef, nnz)
    for r in 1:nnz
        i = N.ijk[r,1]; j = N.ijk[r,2]; k = N.ijk[r,3]
        flux[r] = x[i] * N.val[r] * x[j] * x[k]
    end
    return flux
end

function eigenvalue_sensitivity(model, x, R)
    Df_mat = model.Df(x, R)
    vals, vecs = eigen(Df_mat)
    p = sortperm(real.(vals), rev=true)
    λ = vals[p[1]]
    v = vecs[:, p[1]]
    
    vals_l, vecs_l = eigen(Df_mat')
    idx_l = argmin(abs.(vals_l .- conj(λ)))
    w = conj.(vecs_l[:, idx_l])
    
    w = w / dot(w, v)
    w_tilde = (model.Bfact \ w) 
    
    N = model.N
    nnz = length(N.val)
    S = Vector{ComplexF64}(undef, nnz)
    for r in 1:nnz
        i = N.ijk[r,1]; j = N.ijk[r,2]; k = N.ijk[r,3]
        S[r] = w_tilde[i] * (v[j] * x[k] + v[k] * x[j])
    end
    return λ, S
end

function get_core_set(model, x, fraction=0.99)
    e = modal_energy(model, x)
    p = sortperm(abs.(e), rev=true)
    total_abs = sum(abs.(e))
    if total_abs < 1e-15; return Int[]; end
    cum = cumsum(abs.(e[p])) / total_abs
    idx = findfirst(c -> c >= fraction, cum)
    return p[1:(idx === nothing ? length(p) : idx)]
end

function closure_metric(model, x, S)
    N = model.N
    nnz = length(N.val)
    total_abs_flux = 0.0
    core_abs_flux = 0.0
    S_set = Set(S)
    for r in 1:nnz
        i = N.ijk[r,1]; j = N.ijk[r,2]; k = N.ijk[r,3]
        flux_abs = abs(x[i] * N.val[r] * x[j] * x[k])
        total_abs_flux += flux_abs
        if i in S_set && j in S_set && k in S_set
            core_abs_flux += flux_abs
        end
    end
    return core_abs_flux / (total_abs_flux + 1e-20)
end

function run_continuation(model, xeq, Re0)
    fp(x, p) = model.f(x, p[1])
    prob = BK.BifurcationProblem(fp, xeq, [Float64(Re0)], 1; 
                                 record_from_solution = (x, p; k...) -> power_input(model, x))
    # Disable eigenvalue computation during PALC to prevent timeouts
    newton_opts = BK.NewtonPar(tol = 1e-8, max_iterations = 25)
    cont_opts = BK.ContinuationPar(p_min = 100.0, p_max = 350.0, dsmin = 1e-4, dsmax = 2.0, 
                                   max_steps = 150, newton_options = newton_opts,
                                   detect_bifurcation = 0) # 0 = off, we'll find min Re manually
    br = BK.continuation(prob, BK.PALC(), cont_opts, bothside = true)
    return br
end

# --- Main ---

function main()
    results = []
    xsoln = xguess_17d
    model_prev = nothing

    base_dir = "nagata_structural_outputs"
    mkpath(base_dir)

    for (idx, (J, K, L)) in enumerate(discretization_ladder)
        model = ODEModel(α, γ, J, K, L, H, normalize=false)
        m = length(model)
        res_dir = joinpath(base_dir, "m_$m")
        mkpath(res_dir)
        
        println("\n--- Processing m=$m (Ladder Level $idx) ---")
        
        xguess = (idx > 1) ? changebasis(xsoln, model_prev.ijkl, model.ijkl) : xsoln
        
        # 1. Equilibrium Solve
        hookparams = SearchParams(ftol=1e-08, xtol=1e-12, Nnewton=30, Nhook=8, verbosity=0)
        xsoln, success = hookstepsolve(x -> model.f(x, Re_start), x -> model.Df(x, Re_start), xguess, hookparams)
        
        if !success
            println("Warning: Equilibrium solve failed at m=$m")
        end
        
        # 2. Re-Continuation
        println("  Running continuation...")
        br = run_continuation(model, xsoln, Re_start)
        Re_vals = [s.p for s in br.sol]
        I_vals = [power_input(model, s.x) for s in br.sol]
        
        p_cont = plot(Re_vals, I_vals, xlabel="Re", ylabel="I", title="Nagata Branch (m=$m)", marker=:circle, markersize=2)
        savefig(p_cont, joinpath(res_dir, "bifurcation_curve.png"))
        
        bif_idx = argmin(Re_vals)
        Re_bif = Re_vals[bif_idx]
        x_bif = br.sol[bif_idx].x
        
        # 3. Flux Analysis
        println("  Analyzing energy flux...")
        flux_start = triad_energy_flux(model, xsoln)
        flux_bif = triad_energy_flux(model, x_bif)
        
        mode_flux_start = zeros(m)
        mode_flux_bif = zeros(m)
        for r in 1:length(model.N.val)
            i, j, k = model.N.ijk[r, :]
            mode_flux_start[i] += flux_start[r]
            mode_flux_bif[i] += flux_bif[r]
        end
        
        p_flux = plot(1:m, [mode_flux_start mode_flux_bif], label=["Re=$Re_start" "Re=$Re_bif"], 
                      xlabel="Mode i", ylabel="Net Flux Π_i", title="Net Flux per Mode (m=$m)")
        savefig(p_flux, joinpath(res_dir, "mode_net_flux.png"))
        
        # 4. Core & Stability Analysis
        println("  Computing stability and core metrics...")
        S_99 = get_core_set(model, xsoln, 0.99)
        closure = closure_metric(model, xsoln, S_99)
        λ, S_sens = eigenvalue_sensitivity(model, xsoln, Re_start)
        
        open(joinpath(res_dir, "detailed_analysis.txt"), "w") do io
            @printf(io, "Model: m=%d (J,K,L)=(%d,%d,%d)\n", m, J, K, L)
            @printf(io, "Bifurcation Point: Re_min ≈ %.4f\n", Re_bif)
            @printf(io, "Energy Core Size (99%%): %d\n", length(S_99))
            @printf(io, "Nonlinear Closure on Core: %.4f\n", closure)
            @printf(io, "Lead Eigenvalue (at Re=200): %.6f + %.6fi\n", real(λ), imag(λ))
            
            println(io, "\nTop 20 Sensitivity Triads:")
            p_s = sortperm(abs.(S_sens), rev=true)
            for r in 1:20
                idx_t = p_s[r]
                i, j, k = model.N.ijk[idx_t, :]
                @printf(io, "%2d) (%3d,%3d,%3d) S=%.4e ijkl=[%s, %s, %s]\n", r, i, j, k, abs(S_sens[idx_t]), 
                        string(model.ijkl[i,:]), string(model.ijkl[j,:]), string(model.ijkl[k,:]))
            end
        end
        
        push!(results, (m=m, Re_min=Re_bif, Core99=length(S_99), Closure=closure, λ=λ, 
                        families=Dict((abs(model.ijkl[i,2]), abs(model.ijkl[i,3])) => 1 for i in S_99)))
        
        model_prev = model
    end

    # --- Global Summary Graphs ---
    println("\nGenerating summary graphs...")
    ms = [r.m for r in results]
    
    p1 = plot(ms, [r.Core99 for r in results], marker=:circle, label="Core99 Size", xlabel="m", title="Core Resolution Invariance")
    savefig(p1, joinpath(base_dir, "summary_core_size.png"))
    
    p2 = plot(ms, [r.Re_min for r in results], marker=:square, label="Re_min", xlabel="m", title="Bifurcation Convergence")
    savefig(p2, joinpath(base_dir, "summary_re_min.png"))
    
    p3 = plot(ms, [r.Closure for r in results], marker=:diamond, label="Closure", xlabel="m", title="Nonlinear Closure Convergence")
    savefig(p3, joinpath(base_dir, "summary_closure.png"))

    println("\nAll resolutions complete. Data stored in subdirectories of $base_dir")
end

main()

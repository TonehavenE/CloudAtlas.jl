using LinearAlgebra, Polynomials, Plots, DelimitedFiles, Printf, Statistics
using CloudAtlas
import BifurcationKit as BK

# Headless plotting for server/terminal execution
ENV["GKSwstype"] = "100"

# --- Configuration ---
α, γ = 1.0, 2.0
Re_start = 200.0
sx, sy, sz, tx, tz = halfbox_symmetries()
H = [sx*sy*sz, sz*tx*tz]

# Requested discretization ladder
# (J, K, L) 
discretization_ladder = [
    (1, 2, 3), # m=27
    (1, 3, 5), # m=59
    (2, 3, 5), # m=97
    (2, 4, 7), # m=169
    (2, 4, 9), # m=214
    (3, 5, 9)  # m=367
]

guess_27d_path = "notebooks/data/xeq1projection-Re200-1-2-3-27d.asc"
dns_data_path = "notebooks/data/eq1ReD-DNS.asc"

# --- Analysis Helpers ---

function myreaddlm(filename; cc='%')
    X = readdlm(filename, comments=true, comment_char=cc)
    if size(X,2) == 1
        X = X[:,1]
    end
    X
end

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

function get_core_set(model, x, fraction=0.99)
    e = modal_energy(model, x)
    p = sortperm(abs.(e), rev=true)
    total_abs = sum(abs.(e))
    if total_abs < 1e-15; return Int[]; end
    cum = cumsum(abs.(e[p])) / total_abs
    idx = findfirst(c -> c >= fraction, cum)
    return p[1:(idx === nothing ? length(p) : idx)]
end

function run_continuation_exact(model, xeq, Re0)
    fp(x, p) = model.f(x, p[1])
    prob = BK.BifurcationProblem(fp, xeq, [Float64(Re0)], 1; 
                                 record_from_solution = (x, p; k...) -> shear(x, model))
    
    # Exact parameters from continue-eqb.ipynb
    newton_opts = BK.NewtonPar(tol = 1e-10, max_iterations = 25, verbose = false)
    cont_opts = BK.ContinuationPar(
        p_min = 100.0, 
        p_max = 400.0, 
        n_inversion = 20, 
        dsmin = 1e-7, 
        dsmax = 1.0, 
        max_steps = 200, 
        newton_options = newton_opts
    )
    
    br = BK.continuation(prob, BK.PALC(), cont_opts, bothside = true)
    return br
end

function solve_with_perturbation(model, Re, xguess; max_trials=500, noise_scale=0.01)
    f = x -> model.f(x, Re)
    Df = x -> model.Df(x, Re)
    hookparams = SearchParams(ftol=1e-08, xtol=1e-12, Nnewton=30, Nhook=8, verbosity=0)
    
    # Try initial guess
    xsoln, success = hookstepsolve(f, Df, xguess, hookparams)
    if success; return xsoln, true; end
    
    println("  Initial refinement failed. Attempting perturbations (max $max_trials)...")
    for i in 1:max_trials
        noise = (rand(length(xguess)) .- 0.5) .* (2.0 * noise_scale)
        x_p = xguess .+ noise
        xsoln, success = hookstepsolve(f, Df, x_p, hookparams)
        if success
            println("  Converged after $i perturbation trials.")
            return xsoln, true
        end
    end
    return xguess, false
end

# --- Main Logic ---

function main()
    base_dir = "nagata_comprehensive_analysis"
    mkpath(base_dir)
    
    results_summary = []
    local xsoln = nothing
    local model_prev = nothing

    # Load DNS
    dns_raw = myreaddlm(dns_data_path, cc='#')
    p_combined = plot(dns_raw[:,1], dns_raw[:,2], color=:black, lw=2, label="DNS", 
                      xlabel="Re", ylabel="Shear", title="Nagata Bifurcation Ladder", 
                      xlim=(140, 350), ylim=(1.2, 3.0))

    for (idx, (J, K, L)) in enumerate(discretization_ladder)
        model = ODEModel(α, γ, J, K, L, H, normalize=false)
        m = length(model)
        m_dir = joinpath(base_dir, "m_$m")
        mkpath(m_dir)
        
        println("
>>> Processing Level $idx: m=$m (J,K,L)=($J,$K,$L)")
        
        # 1. Setup Guess
        if idx == 1
            xguess = myreaddlm(guess_27d_path)
        else
            xguess = changebasis(xsoln, model_prev.ijkl, model.ijkl)
        end
        
        # 2. Refine at Re=200
        xsoln, success = solve_with_perturbation(model, Re_start, xguess)
        if !success
            @warn "Solve failed at m=$m. Stopping."
            break
        end
        
        # 3. Continuation
        println("  Running PALC continuation...")
        br = run_continuation_exact(model, xsoln, Re_start)
        
        # Save branch
        Re_vals = [s.p for s in br.sol]
        Shear_vals = [shear(s.x, model) for s in br.sol]
        writedlm(joinpath(m_dir, "bifurcation_curve.csv"), hcat(Re_vals, Shear_vals), ',')
        plot!(p_combined, Re_vals, Shear_vals, label="m=$m", alpha=0.7)
        
        # 4. Energy and Flux
        println("  Calculating energy distribution...")
        e = modal_energy(model, xsoln)
        S_99 = get_core_set(model, xsoln, 0.99)
        fluxes = triad_energy_flux(model, xsoln)
        
        # Mode-level net flux
        mode_flux = zeros(m)
        for r in 1:length(model.N.val)
            mode_flux[model.N.ijk[r,1]] += fluxes[r]
        end
        
        # Save structural report
        open(joinpath(m_dir, "report.txt"), "w") do io
            @printf(io, "m: %d
Re_min: %.4f
Core99 Size: %d
Energy PR: %.4f
", 
                    m, minimum(Re_vals), length(S_99), participation_ratio(e))
            println(io, "
Top 20 Modes by Net Flux:")
            pm = sortperm(abs.(mode_flux), rev=true)
            for r in 1:min(20, m)
                i = pm[r]
                @printf(io, "%2d) Mode %3d %s Π=% .6e
", r, i, string(model.ijkl[i,:]), mode_flux[i])
            end
            println(io, "
Top 20 Triads by Flux Magnitude:")
            pf = sortperm(abs.(fluxes), rev=true)
            for r in 1:min(20, length(fluxes))
                idx_t = pf[r]
                i,j,k = model.N.ijk[idx_t,:]
                @printf(io, "%2d) (%3d,%3d,%3d) flux=% .6e ijkl(i)=%s
", r, i, j, k, fluxes[idx_t], string(model.ijkl[i,:]))
            end
        end
        
        # Pareto Energy Plot
        pe_sort = sortperm(abs.(e), rev=true)
        cum_e = cumsum(abs.(e[pe_sort])) / sum(abs.(e))
        pe_plot = plot(1:length(cum_e), cum_e, xlabel="Modes", ylabel="Cum. Energy", title="Energy Pareto (m=$m)", marker=:circle)
        savefig(pe_plot, joinpath(m_dir, "energy_pareto.png"))
        
        push!(results_summary, (m=m, core=length(S_99), re_min=minimum(Re_vals), pr=participation_ratio(e)))
        model_prev = model
        
        # Save combined plot progress
        savefig(p_combined, joinpath(base_dir, "combined_bifurcation_curves.png"))
    end
    
    # Final Summary Plots
    if !isempty(results_summary)
        ms = [r.m for r in results_summary]
        p_core = plot(ms, [r.core for r in results_summary], marker=:circle, xlabel="m", ylabel="Core Size", title="Resolution Invariance of Core")
        savefig(p_core, joinpath(base_dir, "summary_core_size.png"))
        
        p_re = plot(ms, [r.re_min for r in results_summary], marker=:square, label="Re_min", xlabel="m", title="Bifurcation Point Convergence")
        savefig(p_re, joinpath(base_dir, "summary_re_min.png"))
    end

    println("
Ladder complete. Results stored in $base_dir/")
end

main()

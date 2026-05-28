using LinearAlgebra, Plots, DelimitedFiles, Printf, Statistics
using CloudAtlas
using Plots.Measures # For margins

# Headless plotting
ENV["GKSwstype"] = "100"

# --- Configuration ---
α, γ = 1.0, 2.0
Re_start = 200.0
sx, sy, sz, tx, tz = halfbox_symmetries()
H = [sx*sy*sz, sz*tx*tz]

# Dense ladder for scaling analysis
discretization_ladder = [
    (1, 1, 3), # 17d
    (1, 2, 3), # 27d
    (1, 3, 5), # 59d
    (2, 3, 5), # 97d
    (2, 4, 7), # 169d
    (2, 5, 9), # 262d
    (3, 5, 9)  # 367d
]

# Initial guess for (1,1,3)
xguess_17d = [0.105, -0.0539, 0.388, -0.0172, -0.0133, 0.0113, -0.00706, 0.0240, -0.0344, 
              -0.00868, -0.01264, -0.0234, -0.0320, -0.0180, -0.00464, 0.0106, 0.0235]

"""
Participation Ratio (PR):
Calculates the "effective number of active modes" in a vector v.
PR = (Σ |v_i|^2)^2 / Σ |v_i|^4
- If v has 1 non-zero entry, PR = 1.0.
- If v has k identical entries and rest zero, PR = k.
- This represents the statistical "dimensionality" of the support.
"""
function calculate_pr(v)
    v2 = abs2.(v)
    s2 = sum(v2)
    s4 = sum(abs2, v2)
    return (s2^2 / (s4 + 1e-30))
end

"""
Energy Support Size:
Find the smallest number of modes that carry 'fraction' of the total energy (L2 norm squared).
"""
function energy_support_size(v, fraction=0.95)
    v2 = abs2.(v)
    total = sum(v2)
    if total < 1e-20; return 0; end
    p = sortperm(v2, rev=true)
    cum = cumsum(v2[p]) / total
    idx = findfirst(c -> c >= fraction, cum)
    return (idx === nothing ? length(v) : idx)
end

function get_active_triads_95(model, x)
    m = length(model)
    N = model.N
    ijk = N.ijk
    val = N.val
    
    triads_by_i = [Int[] for _ in 1:m]
    for r in 1:length(val)
        push!(triads_by_i[ijk[r,1]], r)
    end
    
    active_indices = Int[]
    for i in 1:m
        r_list = triads_by_i[i]
        if isempty(r_list) continue end
        
        # c_i(j,k) = |N_ijk x_j x_k|
        contribs = [abs(val[r] * x[ijk[r,2]] * x[ijk[r,3]]) for r in r_list]
        total_abs = sum(contribs)
        if total_abs < 1e-15 continue end
        
        p = sortperm(contribs, rev=true)
        cum = cumsum(contribs[p]) / total_abs
        idx = findfirst(c -> c >= 0.95, cum)
        count = (idx === nothing ? length(p) : idx)
        
        append!(active_indices, r_list[p[1:count]])
    end
    return active_indices
end

function find_scc_core(model, active_triad_indices)
    m = length(model)
    ijk = model.N.ijk
    A = zeros(Bool, m, m)
    for r in active_triad_indices
        i, j, k = ijk[r, 1], ijk[r, 2], ijk[r, 3]
        A[j, i] = true; A[k, i] = true
    end
    R = I(m) .| A
    for _ in 1:m
        R_new = (R * R) .> 0
        if all(R_new .== R) break end
        R .= R_new
    end
    core_nodes = Int[]
    for i in 1:m
        is_loop = false
        for j in 1:m
            if i != j && R[i, j] && R[j, i]
                is_loop = true; break
            end
        end
        if is_loop push!(core_nodes, i) end
    end
    return core_nodes
end

function main()
    results = []
    xsoln = xguess_17d
    model_prev = nothing
    
    output_dir = "nagata_ladder_analysis_v3"
    mkpath(output_dir)
    
    # Combined Bifurcation Plot Initialization
    p_bif = plot(xlabel="Reynolds Number (Re)", ylabel="Power Input (I)", 
                 title="Bifurcation Branch Convergence", legend=:outerright,
                 size=(1920, 1080), dpi=300, left_margin=20mm, bottom_margin=10mm)

    println("Starting Rigorous Ladder Analysis...")
    @printf("%-10s %-6s %-10s %-10s %-10s %-10s %-10s\n", 
            "J,K,L", "m", "Triads95", "CoreSize", "EngSupp95", "PR_unst", "λ_lead")

    for (idx, (J, K, L)) in enumerate(discretization_ladder)
        model = ODEModel(α, γ, J, K, L, H, normalize=false)
        m = length(model)
        
        # 1. Equilibrium Solve
        xguess = (idx > 1) ? changebasis(xsoln, model_prev.ijkl, model.ijkl) : xsoln
        xsoln, success = hookstepsolve(x -> model.f(x, Re_start), x -> model.Df(x, Re_start), xguess, SearchParams(ftol=1e-08, verbosity=0))
        
        # 2. Adaptive Core & Triad Analysis
        active_triads = get_active_triads_95(model, xsoln)
        core_nodes = find_scc_core(model, active_triads)
        
        # 3. Stability & Localization Analysis
        Df_mat = model.Df(xsoln, Re_start)
        evals, vecs = eigen(Df_mat)
        p_evals = sortperm(real.(evals), rev=true)
        λ_lead = evals[p_evals[1]]
        uvec = vecs[:, p_evals[1]]
        
        pr_unst = calculate_pr(uvec)
        es_95 = energy_support_size(xsoln, 0.95)
        
        @printf("%-10s %-6d %-10d %-10d %-10d %-10.2f %-10.4f\n", 
                "$J,$K,$L", m, length(active_triads), length(core_nodes), es_95, pr_unst, real(λ_lead))
        
        # 4. Continuation for Bifurcation Plot
        # (Simplified continuation to show the 'nose')
        Res = range(150, 250, length=20)
        Inputs = Float64[]
        x_cont = copy(xsoln)
        for R in reverse(Res)
            xc, ok = hookstepsolve(x -> model.f(x, R), x -> model.Df(x, R), x_cont, SearchParams(ftol=1e-6, verbosity=0))
            if ok
                push!(Inputs, power_input(model, xc))
                x_cont .= xc
            else
                break
            end
        end
        plot!(p_bif, reverse(Res[1:length(Inputs)]), Inputs, label="m=$m", lw=2)
        
        push!(results, (m=m, JKL=(J,K,L), triads=length(active_triads), core=length(core_nodes), 
                        es_95=es_95, pr_unst=pr_unst, λ=λ_lead))
        
        model_prev = model
    end
    
    savefig(p_bif, joinpath(output_dir, "combined_bifurcation_curves.png"))
    
    # Summary Plots with fixed margins
    ms = [r.m for r in results]
    
    p1 = plot(ms, [r.core for r in results], marker=:circle, label="SCC Core Nodes", 
              xlabel="System Size (m)", ylabel="Count", title="Topological Core Scaling",
              size=(1920, 1080), dpi=300, lw=2, left_margin=20mm, bottom_margin=10mm)
    plot!(p1, ms, [r.triads / 1000 for r in results], marker=:square, label="Active Triads (thousands)")
    savefig(p1, joinpath(output_dir, "summary_structural_scaling.png"))
    
    p2 = plot(ms, [r.pr_unst for r in results], marker=:diamond, label="Participation Ratio (Unstable λ)",
              xlabel="System Size (m)", ylabel="Effective Mode Count", title="Dynamical Localization",
              size=(1920, 1080), dpi=300, lw=2, left_margin=20mm, bottom_margin=10mm)
    plot!(p2, ms, [r.es_95 for r in results], marker=:hexagon, label="95% Energy Support")
    savefig(p2, joinpath(output_dir, "summary_localization_plateau.png"))

    println("\nAnalysis complete. High-res summary plots in $output_dir")
end

main()

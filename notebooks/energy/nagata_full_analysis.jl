using LinearAlgebra, Plots, DelimitedFiles, Printf, Statistics
using CloudAtlas
import BifurcationKit as BK

# Headless plotting
ENV["GKSwstype"] = "100"

# --- Configuration ---
α, γ = 1.0, 2.0
Re_start = 200.0
sx, sy, sz, tx, tz = halfbox_symmetries()
H = [sx*sy*sz, sz*tx*tz]

# Representative ladder
discretization_ladder = [
    (1, 1, 3), # 17d
    (1, 2, 3), # 27d
    (1, 3, 5), # 59d
    (2, 4, 7), # 169d
    (3, 5, 9)  # 367d
]

# Initial guess for (1,1,3) - Nagata EQB
xguess_17d = [0.105, -0.0539, 0.388, -0.0172, -0.0133, 0.0113, -0.00706, 0.0240, -0.0344, 
              -0.00868, -0.01264, -0.0234, -0.0320, -0.0180, -0.00464, 0.0106, 0.0235]

"""
Step G: Build active triad list using per-equation normalization.
Keep smallest set of triads whose cumulative |N_ijk x_j x_k| accounts for `fraction` 
of the total nonlinear input to each equation i.
"""
function get_active_triads_adaptive(model, x, fraction=0.80)
    m = length(model)
    N = model.N
    ijk = N.ijk
    val = N.val
    
    # Group triads by receiver i
    triads_by_i = [Int[] for _ in 1:m]
    for r in 1:length(val)
        push!(triads_by_i[ijk[r,1]], r)
    end
    
    active_indices = Int[]
    
    for i in 1:m
        r_list = triads_by_i[i]
        if isempty(r_list) continue end
        
        # Contributions c_i(j,k) = |N_ijk x_j x_k|
        contribs = [abs(val[r] * x[ijk[r,2]] * x[ijk[r,3]]) for r in r_list]
        total_abs = sum(contribs)
        if total_abs < 1e-15 continue end
        
        # Sort descending
        p = sortperm(contribs, rev=true)
        sorted_r = r_list[p]
        sorted_c = contribs[p]
        
        cum = cumsum(sorted_c) / total_abs
        idx = findfirst(c -> c >= fraction, cum)
        count = (idx === nothing ? length(sorted_r) : idx)
        
        append!(active_indices, sorted_r[1:count])
    end
    
    return active_indices
end

"""
Step H: Iterative core elimination on the adaptive triad graph.
"""
function find_adaptive_core(model, active_triad_indices; max_iters=100)
    m = length(model)
    active_nodes = Set(1:m)
    
    # Indices of active triads
    ijk = model.N.ijk
    
    iteration = 0
    while iteration < max_iters
        iteration += 1
        
        # Filter triads by nodes currently in the potential core
        valid_triads = []
        for r in active_triad_indices
            i, j, k = ijk[r, 1], ijk[r, 2], ijk[r, 3]
            if i in active_nodes && j in active_nodes && k in active_nodes
                push!(valid_triads, (i, j, k))
            end
        end
        
        # Count connections in this subgraph
        # We use the same source/sink/degree logic
        node_monomials = [Set{Set{Int}}() for _ in 1:m]
        receivers = Set{Int}()
        donors = Set{Int}()
        
        for (i, j, k) in valid_triads
            push!(node_monomials[j], Set([j, k]))
            push!(node_monomials[k], Set([j, k]))
            push!(receivers, i)
            push!(donors, j)
            push!(donors, k)
        end
        
        to_remove = Set{Int}()
        for node in active_nodes
            # Same criteria as Step B
            if length(node_monomials[node]) <= 1
                push!(to_remove, node)
                continue
            end
            
            is_source = (node in donors) && !(node in receivers)
            is_sink = (node in receivers) && !(node in donors)
            
            if is_source || is_sink
                push!(to_remove, node)
            end
        end
        
        if isempty(to_remove) break end
        for node in to_remove delete!(active_nodes, node) end
    end
    
    return sort(collect(active_nodes))
end

function analyze_jacobian(model, x, R)
    Df_mat = model.Df(x, R)
    vals, vecs = eigen(Df_mat)
    
    # Leading eigenvalues
    p = sortperm(real.(vals), rev=true)
    sorted_vals = vals[p]
    unstable_vec = vecs[:, p[1]]
    
    unstable_count = count(real.(vals) .> 1e-7)
    
    # Participation ratio of the leading unstable eigenvector
    # Normalizing by model.B to get physical "energy" support if possible
    # but let's just use raw components for now as a proxy for modal complexity
    pr_vec = participation_ratio(unstable_vec)
    
    return sorted_vals, unstable_count, unstable_vec, pr_vec
end

function participation_ratio(v)
    v_abs = abs.(v)
    s1 = sum(v_abs)
    s2 = sum(v_abs .^ 2)
    return (s1^2 / s2) / length(v) # Normalized to [0, 1]
end

function main()
    results = []
    xsoln = xguess_17d
    model_prev = nothing
    
    base_dir = "nagata_full_analysis"
    mkpath(base_dir)
    
    for (idx, (J, K, L)) in enumerate(discretization_ladder)
        model = ODEModel(α, γ, J, K, L, H, normalize=false)
        m = length(model)
        res_dir = joinpath(base_dir, "m_$m")
        mkpath(res_dir)
        
        println("\n--- Processing m=$m ---")
        
        xguess = (idx > 1) ? changebasis(xsoln, model_prev.ijkl, model.ijkl) : xsoln
        hookparams = SearchParams(ftol=1e-08, verbosity=0)
        xsoln, success = hookstepsolve(x -> model.f(x, Re_start), x -> model.Df(x, Re_start), xguess, hookparams)
        
        if !success
            println("  Warning: EQB solve failed.")
        end
        
        # Step G: Adaptive active triads (80% rule)
        active_triads = get_active_triads_adaptive(model, xsoln, 0.80)
        println("  Active Triads (80%): $(length(active_triads)) / $(length(model.N.val))")
        
        # Step H: Adaptive Core
        core = find_adaptive_core(model, active_triads)
        println("  Adaptive Core Size: $(length(core)) / $m")
        
        # Step I: Stability
        evals, unstable_dim, uvec, pr_vec = analyze_jacobian(model, xsoln, Re_start)
        println("  Unstable Manifold Dim: $unstable_dim")
        println("  Leading λ: $(evals[1])")
        @printf("  Eigenvector PR (normed): %.4f\n", pr_vec)
        
        # Report
        open(joinpath(res_dir, "report.txt"), "w") do io
            @printf(io, "Model m=%d, (J,K,L)=(%d,%d,%d)\n", m, J, K, L)
            @printf(io, "Active Triads (80%%): %d\n", length(active_triads))
            @printf(io, "Adaptive Core Size: %d\n", length(core))
            @printf(io, "Unstable Dim: %d\n", unstable_dim)
            @printf(io, "Leading Eigenvector PR: %.4f\n", pr_vec)
            println(io, "\nCore Nodes (ijkl):")
            for node in core
                println(io, "  $node: $(model.ijkl[node,:])")
            end
            println(io, "\nLeading Eigenvalues:")
            for i in 1:min(10, length(evals))
                @printf(io, "  %d) %.6f + %.6fi\n", i, real(evals[i]), imag(evals[i]))
            end
        end
        
        push!(results, (m=m, core_size=length(core), unstable_dim=unstable_dim, leading_λ=evals[1], pr_vec=pr_vec))
        model_prev = model
    end
    
    # Summary Plots
    ms = [r.m for r in results]
    p1 = plot(ms, [r.core_size for r in results], marker=:circle, label="Adaptive Core", xlabel="m", ylabel="Size", title="Core vs Unstable Manifold")
    p1 = plot!(p1, ms, [r.unstable_dim for r in results], marker=:square, label="Unstable Dim")
    savefig(p1, joinpath(base_dir, "summary_core_size.png"))
    
    p2 = plot(ms, [r.pr_vec for r in results], marker=:diamond, label="Eigenvector PR", xlabel="m", ylabel="PR", title="Unstable Manifold Localization")
    savefig(p2, joinpath(base_dir, "summary_energy_pr.png"))
    
    println("\nAnalysis complete. Summary plots saved to $base_dir")
end

main()

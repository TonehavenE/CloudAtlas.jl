using CloudAtlas
using LinearAlgebra
using DelimitedFiles
using Printf
include("quadratic_core_analysis.jl")

"""
Step E: Build flux-weighted triad list.
F_ijk = |x_i * N_ijk * x_j * x_k|
"""
function build_flux_triads(model, x, epsilon_flux)
    N = model.N
    ijk = N.ijk
    val = N.val
    
    flux_triads = []
    for r in 1:length(val)
        i, j, k = ijk[r, 1], ijk[r, 2], ijk[r, 3]
        f = abs(x[i] * val[r] * x[j] * x[k])
        if f > epsilon_flux
            push!(flux_triads, (i, j, k, f))
        end
    end
    return flux_triads
end

"""
Step F: Iterative core elimination on the flux-weighted graph.
"""
function find_active_flux_core(model, x, epsilon_flux; max_iters=100)
    m = length(model)
    active_nodes = Set(1:m)
    
    # Pre-calculate all fluxes
    N = model.N
    ijk = N.ijk
    val = N.val
    all_fluxes = [abs(x[ijk[r,1]] * val[r] * x[ijk[r,2]] * x[ijk[r,3]]) for r in 1:length(val)]
    
    iteration = 0
    while iteration < max_iters
        iteration += 1
        
        # Filter triads by currently active nodes AND flux
        current_triads = []
        for r in 1:length(val)
            i, j, k = ijk[r, 1], ijk[r, 2], ijk[r, 3]
            if all_fluxes[r] > epsilon_flux && i in active_nodes && j in active_nodes && k in active_nodes
                push!(current_triads, (i, j, k))
            end
        end
        
        node_monomials = [Set{Set{Int}}() for _ in 1:m]
        receivers = Set{Int}()
        donors = Set{Int}()
        
        for (i, j, k) in current_triads
            push!(node_monomials[j], Set([j, k]))
            push!(node_monomials[k], Set([j, k]))
            push!(receivers, i)
            push!(donors, j)
            push!(donors, k)
        end
        
        to_remove = Set{Int}()
        for node in active_nodes
            # PROTECT: Don't remove the top energy-containing modes (often the "drivers")
            # For this system, the first few modes are usually the largest.
            if node <= 3
                continue
            end
            
            # Prune if not part of a feedback loop
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
        
        if isempty(to_remove)
            break
        end
        
        for node in to_remove
            delete!(active_nodes, node)
        end
    end
    
    return sort(collect(active_nodes))
end

function print_core_details(model, core_nodes)
    println("Active Core Nodes (m=$(length(model))):")
    @printf("%-6s %-15s %-15s\n", "Index", "ijkl", "Symmetry")
    for node in core_nodes
        ijkl = model.ijkl[node, :]
        @printf("%-6d %-15s\n", node, string(ijkl))
    end
end

function run_flux_analysis()
    # Configuration
    α, γ = 1.0, 2.0
    sx, sy, sz, tx, tz = halfbox_symmetries()
    H = [sx*sy*sz, sz*tx*tz]
    
    # 1. 27-mode analysis
    model27 = ODEModel(α, γ, 1, 2, 3, H, normalize=false)
    guess27 = "notebooks/data/xeq1projection-Re200-1-2-3-27d.asc"
    x27 = vec(readdlm(guess27, comments=true, comment_char='%'))
    
    # Find a threshold where the core is small but non-zero
    # Total flux is roughly sum(|x_i N_ijk x_j x_k|)
    # Let's try epsilon_flux = 1e-4
    eps_flux = 5e-5
    
    println("\n--- Flux Core Analysis (m=27) ---")
    core27 = find_active_flux_core(model27, x27, eps_flux)
    print_core_details(model27, core27)
    
    # 2. 59-mode analysis (Interpolate x27 to m=59)
    model59 = ODEModel(α, γ, 1, 3, 5, H, normalize=false)
    x59 = changebasis(x27, model27.ijkl, model59.ijkl)
    
    println("\n--- Flux Core Analysis (m=59, Interpolated) ---")
    core59 = find_active_flux_core(model59, x59, eps_flux)
    print_core_details(model59, core59)
    
    # Check for resolution invariance
    core27_ijkl = Set([string(model27.ijkl[i, :]) for i in core27])
    core59_ijkl = Set([string(model59.ijkl[i, :]) for i in core59])
    
    common = intersect(core27_ijkl, core59_ijkl)
    println("\nResolution-Invariant Core Modes (Common ijkl):")
    for s in sort(collect(common))
        println("  ", s)
    end
    
    @printf("\nCore Size m=27: %d\nCore Size m=59: %d\nCommon Modes: %d\n", 
            length(core27), length(core59), length(common))
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    run_flux_analysis()
end

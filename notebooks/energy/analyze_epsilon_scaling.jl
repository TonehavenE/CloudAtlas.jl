using CloudAtlas
using Plots
using Printf
include("quadratic_core_analysis.jl")

# Headless plotting
ENV["GKSwstype"] = "100"

function analyze_epsilon_scaling(; α=1.0, γ=2.0, J=1, K=3, L=5)
    sx, sy, sz, tx, tz = halfbox_symmetries()
    H = [sx*sy*sz, sz*tx*tz]
    model = ODEModel(α, γ, J, K, L, H, normalize=false)
    m = length(model)
    
    epsilons = 10.0 .^ range(-4, 1.8, length=50)
    core_sizes = Int[]
    
    println("Analyzing epsilon scaling for m=$m...")
    for eps in epsilons
        core = find_quadratic_core(model, eps)
        push!(core_sizes, length(core))
    end
    
    p = plot(epsilons, core_sizes, 
             xscale=:log10, 
             marker=:circle, 
             markersize=3,
             linewidth=2,
             xlabel="Epsilon (Threshold)", 
             ylabel="Core Size (Nodes)",
             title="Quadratic Core Scaling vs Epsilon (m=$m)",
             label="Core Size")
    
    # Add horizontal line at m
    hline!(p, [m], linestyle=:dash, color=:grey, label="Full System ($m)")
    
    output_plot = "core_size_vs_epsilon_m$m.png"
    savefig(p, output_plot)
    println("Plot saved to $output_plot")
    
    # Print a summary table
    println("\n--- Epsilon Scaling Summary ---")
    @printf("%-12s %-10s\n", "Epsilon", "Core Size")
    for i in 1:5:length(epsilons)
        @printf("%-12.2e %-10d\n", epsilons[i], core_sizes[i])
    end
    
    return epsilons, core_sizes
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    analyze_epsilon_scaling(J=1, K=3, L=5) # 59-mode model
end

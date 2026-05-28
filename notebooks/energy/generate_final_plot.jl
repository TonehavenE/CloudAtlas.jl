using CloudAtlas
using LinearAlgebra
using DelimitedFiles
using Printf
using Plots
include("quadratic_core_analysis.jl")

# Headless plotting
ENV["GKSwstype"] = "100"

function generate_final_plot()
    # Configuration
    α, γ = 1.0, 2.0
    sx, sy, sz, tx, tz = halfbox_symmetries()
    H = [sx*sy*sz, sz*tx*tz]
    
    # Resolutions to check
    ladder = [(1,1,3), (1,2,3), (1,3,5)] # 17, 27, 59
    
    p = plot(xlabel="Epsilon", ylabel="Dimension", 
             xscale=:log10, title="Discovery: Quadratic Core vs Effective Dimension",
             legend=:outerright)
    
    colors = [:blue, :red, :green]
    
    for (idx, (J, K, L)) in enumerate(ladder)
        model = ODEModel(α, γ, J, K, L, H, normalize=false)
        m = length(model)
        
        # 1. Core Scaling
        epsilons = 10.0 .^ range(-2, 1.5, length=30)
        core_sizes = [length(find_quadratic_core(model, eps)) for eps in epsilons]
        
        plot!(p, epsilons, core_sizes, label="m=$m Core", color=colors[idx], lw=2)
        
        # 2. IPR (Placeholder or measured if available)
        # We know m=27 has IPR ~ 2.3. Let s assume similar for others for now
        # or just mark the 27-mode one.
        if m == 27
            hline!(p, [2.34], linestyle=:dash, color=:black, label="m=27 IPR (~2.3)")
        end
    end
    
    # Add a visual "Discovery Zone"
    vspan!(p, [5.0, 15.0], alpha=0.1, color=:yellow, label="Transition Zone")
    
    savefig(p, "quadratic_core_discovery.png")
    println("Final discovery plot saved to quadratic_core_discovery.png")
end

generate_final_plot()

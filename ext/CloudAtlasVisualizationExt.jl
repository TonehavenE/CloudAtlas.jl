module CloudAtlasVisualizationExt
# Visualization tools
using CairoMakie
using CloudAtlas
using Statistics
using DelimitedFiles
using LinearAlgebra

export velocity_fields, velocity_fields_dns, velocity_fields_comparison, PlotSettings, DNSData, VelocityField

"""
    myreaddlm(filename)

Read delimited file with comments (lines starting with %).
"""
myreaddlm(filename) = readdlm(filename, comments=true, comment_char='%')

# Convenience methods for all three components at once
function (vf::VelocityField)(x::Real, y::Real, z::Real)
    u = vf(:u, x, y, z)
    v = vf(:v, x, y, z)
    w = vf(:w, x, y, z)
    return (u, v, w)
end

"""
    plot_xz_plane!(ax, vf::VelocityField, settings::CloudAtlas.PlotSettings; Lx=2π, Lz=π, y_slice=0.0)

Plot (u, w) velocity field in the xz-plane at fixed y.
"""
function CloudAtlas.plot_xz_plane!(ax, vf::VelocityField, settings::CloudAtlas.PlotSettings; 
                        Lx=2π, Lz=π, y_slice=0.0)
    xs = range(0, Lx, settings.num_points)
    zs = range(0, Lz, settings.num_points)
    
    points = [Point2f(x, z) for x in xs for z in zs]
    
    if y_slice == :mean
        ys = range(-1, 1, settings.num_points)
        arrows_data = [(
            mean(vf(:u, x, y, z) for y in ys) * settings.arrow_scale,
            mean(vf(:w, x, y, z) for y in ys) * settings.arrow_scale
        ) for x in xs for z in zs]
    else
        arrows_data = [(
            vf(:u, x, y_slice, z) * settings.arrow_scale,
            vf(:w, x, y_slice, z) * settings.arrow_scale
        ) for x in xs for z in zs]
    end
    
    # Uses shaftwidth, tiplength, tipwidth
    arrows2d!(ax, points, arrows_data, 
            lengthscale=settings.arrow_lengthscale,
            tiplength=settings.arrow_tiplength,
            tipwidth=settings.arrow_tipwidth,
            shaftwidth=settings.arrow_shaftwidth)
end

"""
    plot_xy_plane!(ax, vf::VelocityField, settings::CloudAtlas.PlotSettings; Lx=2π, z_slice=0.0)

Plot (u, v) velocity field in the xy-plane at fixed z.
"""
function CloudAtlas.plot_xy_plane!(ax, vf::VelocityField, settings::CloudAtlas.PlotSettings; 
                        Lx=2π, z_slice=0.0)
    xs = range(0, Lx, settings.num_points)
    ys = range(-1, 1, settings.num_points)
    
    points = [Point2f(x, y) for x in xs for y in ys]
    arrows_data = [(
        vf(:u, x, y, z_slice) * settings.arrow_scale,
        vf(:v, x, y, z_slice) * settings.arrow_scale
    ) for x in xs for y in ys]
    
    arrows2d!(ax, points, arrows_data,
            lengthscale=settings.arrow_lengthscale,
            tiplength=settings.arrow_tiplength,
            tipwidth=settings.arrow_tipwidth,
            shaftwidth=settings.arrow_shaftwidth)
end

"""
    plot_yz_plane!(ax, vf::VelocityField, settings::CloudAtlas.PlotSettings; Lz=π, x_slice=0.0)

Plot (v, w) velocity field in the yz-plane at fixed x, with u heatmap background.
"""
function CloudAtlas.plot_yz_plane!(ax, vf::VelocityField, settings::CloudAtlas.PlotSettings; 
                        Lz=π, x_slice=0.0)
    zs = range(0, Lz, settings.num_points)
    ys = range(-1, 1, settings.num_points)
    
    # Background heatmap of u velocity
    u_field = [vf(:u, x_slice, y, z) for z in zs, y in ys]
    heatmap!(ax, zs, ys, u_field, colormap=settings.colormap)
    
    # Overlay (v, w) arrows
    points = [Point2f(z, y) for z in zs for y in ys]
    arrows_data = [(
        vf(:w, x_slice, y, z) * settings.arrow_scale,
        vf(:v, x_slice, y, z) * settings.arrow_scale
    ) for z in zs for y in ys]
    
    arrows2d!(ax, points, arrows_data,
            lengthscale=settings.arrow_lengthscale,
            tiplength=settings.arrow_tiplength,
            tipwidth=settings.arrow_tipwidth,
            shaftwidth=settings.arrow_shaftwidth,
            color=:black)
end

"""
    velocity_fields(model::ODEModel, x::Vector; 
                    settings=PlotSettings(), Lx=2π, Lz=π, save_path=nothing, add_baseflow=false)

Create a three-panel visualization of velocity field (xz, xy, yz planes).

# Arguments
- `model`: ODEModel instance
- `x`: Solution vector
- `settings`: PlotSettings for customization
- `Lx`: Domain length in x-direction (default: 2π)
- `Lz`: Domain length in z-direction (default: π)
- `save_path`: Optional path to save figure
- `add_baseflow`: If true, adds laminar Couette baseflow u = y (default: false)
"""
function CloudAtlas.velocity_fields(model::CloudAtlas.ODEModel, x::Vector;
                        settings::CloudAtlas.PlotSettings=CloudAtlas.PlotSettings(),
                        Lx::Real=2π, Lz::Real=π,
                        save_path::Union{String,Nothing}=nothing,
                        add_baseflow::Bool=false)
    
    vf = VelocityField(model, x; add_baseflow=add_baseflow)
    fig = Figure(size=settings.fig_size)
    
    # XZ plane: mean (u, w) averaged over y
    ax1 = Axis(fig[1, 1],
        title="Mean (u, w) in xz-plane",
        xlabel="X", ylabel="Z",
        aspect=DataAspect())
    plot_xz_plane!(ax1, vf, settings, Lx=Lx, Lz=Lz, y_slice=:mean)
    
    # XY plane: (u, v) at z = 0
    ax2 = Axis(fig[2, 1],
        title="(u, v) in xy-plane at z = 0",
        xlabel="X", ylabel="Y",
        aspect=DataAspect())
    plot_xy_plane!(ax2, vf, settings, Lx=Lx, z_slice=0.0)
    
    # YZ plane: (v, w) at x = 0 with u heatmap
    ax3 = Axis(fig[3, 1],
        title="(v, w) in yz-plane at x = 0",
        xlabel="Z", ylabel="Y",
        aspect=DataAspect())
    plot_yz_plane!(ax3, vf, settings, Lz=Lz, x_slice=0.0)
    
    Colorbar(fig[3, 2], 
             colormap=settings.colormap,
             limits=(-1, 1),
             label="Streamwise velocity u")
    
    if save_path !== nothing
        CairoMakie.save(save_path, fig)
        println("Saved figure to: $save_path")
    end
    
    return fig
end

"""
    DNSData

Container for DNS velocity field data.
"""
struct DNSData{T<:Real}
    u_xy::Matrix{T}
    v_xy::Matrix{T}
    w_xy::Matrix{T}
    u_xz::Matrix{T}
    v_xz::Matrix{T}
    w_xz::Matrix{T}
    u_yz::Matrix{T}
    v_yz::Matrix{T}
    w_yz::Matrix{T}
    
    function DNSData(root::String)
        u_xy = myreaddlm(root * "_u_xy.asc")
        v_xy = myreaddlm(root * "_v_xy.asc")
        w_xy = myreaddlm(root * "_w_xy.asc")
        u_xz = myreaddlm(root * "_u_xz.asc")
        v_xz = myreaddlm(root * "_v_xz.asc")
        w_xz = myreaddlm(root * "_w_xz.asc")
        u_yz = myreaddlm(root * "_u_yz.asc")
        v_yz = myreaddlm(root * "_v_yz.asc")
        w_yz = myreaddlm(root * "_w_yz.asc")
        
        T = promote_type(eltype(u_xy), eltype(v_xy), eltype(w_xy))
        new{T}(u_xy, v_xy, w_xy, u_xz, v_xz, w_xz, u_yz, v_yz, w_yz)
    end
end

"""
    plot_dns_xz_plane!(ax, dns::DNSData, settings::CloudAtlas.PlotSettings; Lx=2π, Lz=π)

Plot DNS (u, w) field in xz-plane.
"""
function plot_dns_xz_plane!(ax, dns::DNSData, settings::CloudAtlas.PlotSettings; 
                            Lx::Real=2π, Lz::Real=π)
    nz, nx = size(dns.u_xz)
    xs = range(0, Lx, length=nx)
    zs = range(0, Lz, length=nz)
    
    points = [Point2f(x, z) for x in xs, z in zs] |> vec
    arrows_data = [(
        dns.u_xz[j, i] * settings.arrow_scale,
        dns.w_xz[j, i] * settings.arrow_scale
    ) for i in 1:nx, j in 1:nz] |> vec
    
    arrows2d!(ax, points, arrows_data,
            lengthscale=settings.arrow_lengthscale,
            tiplength=settings.arrow_tiplength,
            tipwidth=settings.arrow_tipwidth,
            shaftwidth=settings.arrow_shaftwidth)
end

"""
    plot_dns_xy_plane!(ax, dns::DNSData, settings::CloudAtlas.PlotSettings; Lx=2π)

Plot DNS (u, v) field in xy-plane at z=0.
"""
function plot_dns_xy_plane!(ax, dns::DNSData, settings::CloudAtlas.PlotSettings; Lx::Real=2π)
    ny, nx = size(dns.u_xy)
    xs = range(0, Lx, length=nx)
    ys = range(-1, 1, length=ny)
    
    points = [Point2f(x, y) for y in ys, x in xs] |> vec
    arrows_data = [(
        dns.u_xy[ny-j+1, i] * settings.arrow_scale,
        dns.v_xy[ny-j+1, i] * settings.arrow_scale
    ) for j in 1:ny, i in 1:nx] |> vec
    
    arrows2d!(ax, points, arrows_data,
            lengthscale=settings.arrow_lengthscale,
            tiplength=settings.arrow_tiplength,
            tipwidth=settings.arrow_tipwidth,
            shaftwidth=settings.arrow_shaftwidth)
end

"""
    plot_dns_yz_plane!(ax, dns::DNSData, settings::CloudAtlas.PlotSettings; Lz=π)

Plot DNS (v, w) field in yz-plane at x=0 with u heatmap.
"""
function plot_dns_yz_plane!(ax, dns::DNSData, settings::CloudAtlas.PlotSettings; Lz::Real=π)
    ny, nz = size(dns.v_yz)
    zs = range(0, Lz, length=nz)
    ys = range(-1, 1, length=ny)
    
    # Background heatmap
    heatmap!(ax, reverse(zs), ys, reverse(transpose(dns.u_yz)), 
             colormap=settings.colormap)
    
    # Overlay arrows
    points = [Point2f(z, y) for z in zs, y in ys] |> vec
    arrows_data = [(
        dns.w_yz[ny-i+1, j] * settings.arrow_scale,
        dns.v_yz[ny-i+1, j] * settings.arrow_scale
    ) for j in 1:nz, i in 1:ny] |> vec
    
    arrows2d!(ax, points, arrows_data,
            lengthscale=settings.arrow_lengthscale,
            tiplength=settings.arrow_tiplength,
            tipwidth=settings.arrow_tipwidth,
            shaftwidth=settings.arrow_shaftwidth,
            color=:black)
end

"""
    velocity_fields_dns(root::String; 
                        settings=PlotSettings(), Lx=2π, Lz=π, save_path=nothing)

Visualize DNS velocity field data.
"""
function CloudAtlas.velocity_fields_dns(root::String;
                            settings::CloudAtlas.PlotSettings=CloudAtlas.PlotSettings(),
                            Lx::Real=2π, Lz::Real=π,
                            save_path::Union{String,Nothing}=nothing)
    
    dns = DNSData(root)
    fig = Figure(size=settings.fig_size)
    
    # XZ plane
    ax1 = Axis(fig[1, 1],
        title="DNS (u, w) in xz-plane",
        xlabel="X", ylabel="Z",
        aspect=DataAspect())
    plot_dns_xz_plane!(ax1, dns, settings, Lx=Lx, Lz=Lz)
    
    # XY plane
    ax2 = Axis(fig[2, 1],
        title="DNS (u, v) in xy-plane at z = 0",
        xlabel="X", ylabel="Y",
        aspect=DataAspect())
    plot_dns_xy_plane!(ax2, dns, settings, Lx=Lx)
    
    # YZ plane
    ax3 = Axis(fig[3, 1],
        title="DNS (v, w) in yz-plane at x = 0",
        xlabel="Z", ylabel="Y",
        aspect=DataAspect())
    plot_dns_yz_plane!(ax3, dns, settings, Lz=Lz)
    
    Colorbar(fig[3, 2],
             colormap=settings.colormap,
             limits=(-1, 1),
             label="Streamwise velocity u")
    
    ny, nx = size(dns.u_xy)
    nz = size(dns.u_xz, 1)
    println("DNS grid: Nx × Ny × Nz = $nx × $ny × $nz")
    
    if save_path !== nothing
        CairoMakie.save(save_path, fig)
        println("Saved figure to: $save_path")
    end
    
    return fig
end

"""
    velocity_fields_comparison(model::ODEModel, x::Vector, root::String;
                               settings=PlotSettings(), Lx=2π, Lz=π, save_path=nothing, add_baseflow=false)

Create side-by-side comparison plots of model solution and DNS data.
Saves three separate figures (xz, xy, yz) if save_path is provided.

# Arguments
- `model`: ODEModel instance
- `x`: Solution vector
- `root`: Root path for DNS data files (without extension)
- `settings`: PlotSettings for customization
- `Lx`: Domain length in x-direction (default: 2π)
- `Lz`: Domain length in z-direction (default: π)
- `save_path`: Optional directory path to save figures
- `add_baseflow`: If true, adds laminar Couette baseflow u = y to model (default: false)
"""
function CloudAtlas.velocity_fields_comparison(model::CloudAtlas.ODEModel, 
                                    x::Vector,
                                    root::String;
                                    settings::CloudAtlas.PlotSettings=CloudAtlas.PlotSettings(),
                                    Lx::Real=2π, Lz::Real=π,
                                    save_path::Union{String,Nothing}=nothing,
                                    add_baseflow::Bool=false)
    
    vf = VelocityField(model, x; add_baseflow=add_baseflow)
    dns = DNSData(root)
    
    # Use explicit keyword arguments to avoid positional errors
    comparison_settings = CloudAtlas.PlotSettings(
        num_points = settings.num_points,
        arrow_scale = settings.arrow_scale,
        arrow_lengthscale = settings.arrow_lengthscale,
        arrow_tiplength = settings.arrow_tiplength,
        arrow_tipwidth = settings.arrow_tipwidth,
        arrow_shaftwidth = settings.arrow_shaftwidth,
        colormap = settings.colormap,
        fig_size = (1600, 1100)  # Wider format for side-by-side
    )

    # Use explicit keyword arguments to avoid positional errors
    comparison_settings_vertical = CloudAtlas.PlotSettings(
        num_points = settings.num_points,
        arrow_scale = settings.arrow_scale,
        arrow_lengthscale = settings.arrow_lengthscale,
        arrow_tiplength = settings.arrow_tiplength,
        arrow_tipwidth = settings.arrow_tipwidth,
        arrow_shaftwidth = settings.arrow_shaftwidth,
        colormap = settings.colormap,
        fig_size = (1080, 1080)  # Vertical format for stacked layout
    )
    
    
    # === XZ PLANE ===
    fig_xz = Figure(size=comparison_settings.fig_size)
    ax_xz_ode = Axis(fig_xz[1, 1],
        title="Model (u, w) in xz-plane",
        xlabel="X", ylabel="Z",
        aspect=DataAspect())
    ax_xz_dns = Axis(fig_xz[1, 2],
        title="DNS (u, w) in xz-plane",
        xlabel="X", ylabel="Z",
        aspect=DataAspect())
    
    plot_xz_plane!(ax_xz_ode, vf, comparison_settings, Lx=Lx, Lz=Lz, y_slice=0.0)
    plot_dns_xz_plane!(ax_xz_dns, dns, comparison_settings, Lx=Lx, Lz=Lz)
    
    # === XY PLANE ===
    fig_xy = Figure(size=comparison_settings.fig_size)
    ax_xy_ode = Axis(fig_xy[1, 1],
        title="Model (u, v) in xy-plane",
        xlabel="X", ylabel="Y",
        aspect=DataAspect())
    ax_xy_dns = Axis(fig_xy[1, 2],
        title="DNS (u, v) in xy-plane",
        xlabel="X", ylabel="Y",
        aspect=DataAspect())
    
    plot_xy_plane!(ax_xy_ode, vf, comparison_settings, Lx=Lx, z_slice=0.0)
    plot_dns_xy_plane!(ax_xy_dns, dns, comparison_settings, Lx=Lx)
    
    # === YZ PLANE ===
    fig_yz = Figure(size=comparison_settings.fig_size, fontsize=30)
    ax_yz_ode = Axis(fig_yz[1, 1],
        title="Model in yz-plane",
        xlabel="Z", ylabel="Y",
        aspect=DataAspect())
    ax_yz_dns = Axis(fig_yz[1, 2],
        title="DNS in yz-plane",
        xlabel="Z", ylabel="Y",
        aspect=DataAspect())

    yz_comparison_settings = CloudAtlas.PlotSettings(
        num_points = settings.num_points,
        arrow_scale = settings.arrow_scale*1.2,
        arrow_lengthscale = settings.arrow_lengthscale,
        arrow_tiplength = settings.arrow_tiplength,
        arrow_tipwidth = settings.arrow_tipwidth,
        arrow_shaftwidth = settings.arrow_shaftwidth,
        colormap = settings.colormap,
        fig_size = (1600, 1100)  # Wider format for side-by-side
    )
    
    plot_yz_plane!(ax_yz_ode, vf, yz_comparison_settings, Lz=Lz, x_slice=0.0)
    plot_dns_yz_plane!(ax_yz_dns, dns, comparison_settings, Lz=Lz)
    
    Colorbar(fig_yz[1, 3],
             colormap=comparison_settings.colormap,
             limits=(-1, 1),
             label="Streamwise velocity u"
            )
    # Force the row to match the axis height
    rowsize!(fig_yz.layout, 1, Fixed(400))  # Adjust 600 for desired height...
    
    ny, nx = size(dns.u_xy)
    nz = size(dns.u_xz, 1)
    println("DNS grid: Nx × Ny × Nz = $nx × $ny × $nz")

    resize_to_layout!(fig_yz)
    
    # Save if directory provided
    if save_path !== nothing
        mkpath(save_path)
        base_name = basename(root)
        CairoMakie.save(joinpath(save_path, "$(base_name)_xz_comparison.png"), fig_xz)
        CairoMakie.save(joinpath(save_path, "$(base_name)_xy_comparison.png"), fig_xy)
        CairoMakie.save(joinpath(save_path, "$(base_name)_yz_comparison.png"), fig_yz)
        println("Saved comparison figures to: $save_path")
    end
    
    return (fig_xz, fig_xy, fig_yz)
end

"""
    animate_flow(model, sol, filename; settings=PlotSettings(), Lx=2π, Lz=π)

Generates an MP4 animation of the flow evolution from an ODE solution.
"""
function CloudAtlas.animate_flow(model, sol, filename::String; 
                                 settings::CloudAtlas.PlotSettings=CloudAtlas.PlotSettings(), add_baseflow::Bool=false)

    Lx=2π/model.α
    Lz=2π/model.γ
    
    # settings = PlotSettings()
    fig = Figure(size=settings.fig_size)
    # XZ plane: mean (u, w) averaged over y
    ax_xz = Axis(fig[1, 1],
        title="Mean (u, w) in xz-plane",
        xlabel="X", ylabel="Z", limits = (0, Lx, 0, Lz))
    
    # XY plane: (u, v) at z = 0
    ax_xy = Axis(fig[2, 1],
        title="(u, v) in xy-plane at z = 0",
        xlabel="X", ylabel="Y", limits = (0, Lx, -1, 1))
    
    # YZ plane: (v, w) at x = 0 with u heatmap
    ax_yz = Axis(fig[3, 1],
        title="(v, w) in yz-plane at x = 0",
        xlabel="Z", ylabel="Y",
        aspect=DataAspect(), limits = (0, Lz, -1, 1))
    
    Colorbar(fig[3, 2], 
             colormap=settings.colormap,
             limits=(-1, 1),
             label="Streamwise velocity u")
        
    frames = 1:length(sol.t)
    
    println("Rendering animation with $(length(frames)) frames...")
    
    record(fig, filename, frames; framerate=15) do i
        t = sol.t[i]
        x_state = sol.u[i]
        
        # Update the title with current time
        ax_xz.title = "XZ Plane - t = $(round(t, digits=2))"
        ax_xy.title = "XY Plane - t = $(round(t, digits=2))"
        ax_yz.title = "YZ Plane - t = $(round(t, digits=2))"

        
        # 1. Construct VelocityField for current state
        #    Set add_baseflow=true to see the physical flow, or false to see just perturbations
        vf = VelocityField(model, x_state; add_baseflow=add_baseflow) 
        
        # 2. Clear previous arrows/heatmaps
        empty!(ax_xz)
        empty!(ax_xy)
        empty!(ax_yz)
        
        # 3. Plot new frame using your utilities
        #    Note: We pass the axes we created above
        plot_xz_plane!(ax_xz, vf, settings, Lx=2π/model.α, Lz=2π/model.γ, y_slice=:mean)
        plot_xy_plane!(ax_xy, vf, settings, Lx=2π/model.α, z_slice=0.0)
        plot_yz_plane!(ax_yz, vf, settings, Lz=2π/model.γ, x_slice=0.0)
    end
    
    println("Animation saved to $(filename).")

end

"""
    plot_id_series(model, sol, D_matrix; filename=nothing)

Plots the Power Input (I) vs Dissipation (D) time series and trajectory.
"""
function CloudAtlas.plot_id_series(model, sol, D_matrix; filename::Union{String, Nothing}=nothing)
    # 1. Compute I and D for all time steps
    I_vals = [CloudAtlas.power_input(model, u) for u in sol.u]
    D_vals = [CloudAtlas.dissipation_rate(D_matrix, u) for u in sol.u]
    t = sol.t

    fig = Figure(size=(1000, 500))

    # Panel 1: Time Series
    ax1 = Axis(fig[1, 1], title="Energy Balance Time Series", xlabel="Time", ylabel="Magnitude")
    lines!(ax1, t, I_vals, label="Power Input (I)", color=:blue)
    lines!(ax1, t, D_vals, label="Dissipation (D)", color=:red)
    axislegend(ax1)

    # Panel 2: I vs D Plane
    ax2 = Axis(fig[1, 2], title="I vs D Trajectory", xlabel="Dissipation (D)", ylabel="Power Input (I)")
    lines!(ax2, D_vals, I_vals, color=t, colormap=:viridis)
    
    # Add diagonal line (Equilibrium condition I=D)
    limits = (min(minimum(I_vals), minimum(D_vals)), max(maximum(I_vals), maximum(D_vals)))
    lines!(ax2, [limits...], [limits...], color=:black, linestyle=:dash, label="Equilibrium (I=D)")
    
    if !isnothing(filename)
        save(filename, fig)
    end
    return fig
end

"""
    get_fluctuations_only(model, x)

Returns a copy of the state vector x with all streamwise-invariant modes (Streaks/Mean) set to zero.
"""
function get_fluctuations_only(model::ODEModel{T}, x::Vector{T}) where T
    x_fluct = copy(x)
    
    for i in eachindex(x_fluct)
        # Access the streamwise component (u[1]) and its x-mode (ejx)
        # We assume u, v, w share the same periodicity for a given basis index.
        wave_idx_x = model.Ψ[i].u[1].ejx.waveindex
        
        # If waveindex is 0, the function is constant in x (Streak or Mean Flow)
        if wave_idx_x == 0
            x_fluct[i] = zero(T)
        end
    end
    
    return x_fluct
end

function CloudAtlas.animate_tw_fluctuations(model::ODEModel, state::TWState, filename::String; 
                                            t_span::Tuple=(0.0, 20.0),
                                            fps=15,
                                            settings::CloudAtlas.PlotSettings=CloudAtlas.PlotSettings())
    
    # Extract components
    x_full, cx, cz = extract_components(state)

    # Filter out static streaks to see the wave
    x_wave = get_fluctuations_only(model, x_full)
    
    println("Animating TW fluctuations (Streaks removed).")
    println("Wave speeds: cx = $cx, cz = $cz")

    # Setup Figure
    Lx = 2π/model.α
    Lz = 2π/model.γ
    fig = Figure(size=settings.fig_size)

    # settings = PlotSettings()
    fig = Figure(size=settings.fig_size)
    # XZ plane: mean (u, w) averaged over y
    ax_xz = Axis(fig[1, 1],
        title="Fluctations (u', w') in xz-plane",
        xlabel="X", ylabel="Z", limits = (0, Lx, 0, Lz))
    
    # XY plane: (u, v) at z = 0
    ax_xy = Axis(fig[2, 1],
        title="Fluctuations (u', v') in xy-plane at z = 0",
        xlabel="X", ylabel="Y", limits = (0, Lx, -1, 1))
    
    # YZ plane: (v, w) at x = 0 with u heatmap
    ax_yz = Axis(fig[3, 1],
        title="Fluctuations (v', w') in yz-plane at x = 0",
        xlabel="Z", ylabel="Y",
        aspect=DataAspect(), limits = (0, Lz, -1, 1))
    
    Colorbar(fig[3, 2], 
             colormap=settings.colormap,
             limits=(-1, 1),
             label="Streamwise fluctuation u")

    # Animation Loop
    times = range(t_span[1], t_span[2], step=1/fps)
    
    record(fig, filename, times; framerate=fps) do t_current
        ax_xz.title = "XZ Fluctuations - t = $(round(t_current, digits=2))"
        
        # Pass t, cx, cz to VelocityField. 
        # It handles the coordinate shift u(x-cx*t) internally.
        vf = VelocityField(model, x_wave; 
                           add_baseflow=false, 
                           cx=cx, cz=cz, t=t_current)
        
        empty!(ax_xz); empty!(ax_xy); empty!(ax_yz)
        
        plot_xz_plane!(ax_xz, vf, settings, Lx=Lx, Lz=Lz, y_slice=0.0)
        plot_xy_plane!(ax_xy, vf, settings, Lx=Lx, z_slice=0.0)
        plot_yz_plane!(ax_yz, vf, settings, Lz=Lz, x_slice=0.0)
    end
    
    println("Saved fluctuation animation to $filename")
end

"""
    plot_coefficient_evolution(model, sol; filename=nothing)

Creates a single heatmap showing the evolution of ALL spectral coefficients over time.
X-axis: Time
Y-axis: Basis Function Index (1:m)
Color: log10 magnitude
"""
function CloudAtlas.plot_coefficient_evolution(model, sol; filename::Union{String, Nothing}=nothing)
    # 1. Extract Data
    t = sol.t
    # hcat(sol.u...) creates [Coeffs x Time], so transpose ' makes it [Time x Coeffs]
    # This matches the (x, y) dimensions required by heatmap!
    u_matrix = hcat(sol.u...)' 
    m = size(u_matrix, 2)
    
    # 2. Plotting
    fig = Figure(size=(1000, 600))
    
    ax = Axis(fig[1, 1], 
              title="Spectral Coefficient Evolution (All Modes)", 
              xlabel="Time", 
              ylabel="Basis Function Index")
    
    # Log scale for visibility
    data = log10.(abs.(u_matrix) .+ 1e-12)
    
    # Plot everything on one axis
    hm = heatmap!(ax, t, 1:m, data, colormap=:inferno)
    
    Colorbar(fig[1, 2], hm, label="log10(|coeff|)")

    if !isnothing(filename)
        save(filename, fig)
    end
    
    return fig
end

"""
    plot_stability_spectrum(model, ξ, Re; filename=nothing)

Computes and plots the eigenvalues of the linearized Jacobian.
- ξ: The fixed point solution (includes wave speeds)
- Re: Reynolds number
"""
function CloudAtlas.plot_stability_spectrum(model::ODEModel, state::TWState, Re; filename::Union{String, Nothing}=nothing)
    # 1. Extract State
    x, cx, cz = extract_components(state)
    
    # 2. Get Jacobian of the DYNAMICAL system
    # Note: model.Df gives the Jacobian of dx/dt = f(...)
    # We use this, NOT model.Dg (which is the residual Jacobian and has wrong signs/constraints)
    model.Df_tw === nothing && error("model has no TW dynamics")
    J = model.Df_tw(x, cx, cz, Re)
    
    # 3. Compute Eigenvalues
    println("Computing eigenvalues for m=$(length(model.Ψ)) system...")
    λ = eigen(Matrix(J)).values
    
    # Sort by real part (most unstable first)
    sort!(λ, by = x -> real(x), rev=true)
    
    # 4. Plotting
    fig = Figure(size=(600, 600))
    ax = Axis(fig[1, 1], 
              title="Linear Stability Spectrum (Re=$Re)", 
              xlabel="Real(λ) (Growth Rate)", 
              ylabel="Imag(λ) (Frequency)")
    
    # Draw axes
    lines!(ax, [0, 0], [-maximum(imag(λ)), maximum(imag(λ))], color=:black, linestyle=:dash)
    lines!(ax, [-maximum(real(λ)), maximum(real(λ))], [0, 0], color=:black, linestyle=:dash)
    
    # Plot Stable vs Unstable
    unstable = filter(z -> real(z) > 1e-5, λ)
    stable   = filter(z -> real(z) <= 1e-5, λ)
    
    scatter!(ax, real(stable), imag(stable), color=:blue, label="Stable", markersize=6)
    scatter!(ax, real(unstable), imag(unstable), color=:red, label="Unstable", markersize=10)
    
    axislegend(ax)
    
    # Annotate the "Leading Eigenvalue"
    if !isempty(unstable)
        leading = unstable[1]
        text!(ax, real(leading), imag(leading), 
              text=" λ = $(round(real(leading), digits=4))", 
              align=(:left, :bottom))
    end

    if !isnothing(filename)
        save(filename, fig)
    end
    
    return fig
end

end

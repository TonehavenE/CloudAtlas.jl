using CloudAtlas
using CairoMakie
using LinearAlgebra
using DelimitedFiles

# Setup model (same as 27-mode case)
α, γ = 1.0, 2.0
J, K, L = 1, 2, 3
sx, sy, sz, tx, tz = halfbox_symmetries()
H = [sx*sy*sz, sz*tx*tz]
model = ODEModel(α, γ, J, K, L, H)

# Modes of interest
requested_modes = [
    (ijkl = [1, 0, 0, 1], name = "Mode"),
    (ijkl = [1, 0, 0, 3], name = "Mode"),
    (ijkl = [1, 0, 1, 0], name = "Mode"),
    (ijkl = [1, 0, 0, 5], name = "Mode"),
    (ijkl = [5, -1, -1, 0], name = "Mode")
]

function find_mode(model, ijkl_target)
    for n in 1:length(model)
        if collect(model.ijkl[n, :]) == ijkl_target
            return n
        end
    end
    return nothing
end

mkpath("requested_mode_plots")

function plot_mode_2d(m_info)
    idx = find_mode(model, m_info.ijkl)
    m_local = model
    if idx === nothing
        m_local = ODEModel(α, γ, 1, 3, 5, H)
        idx = find_mode(m_local, m_info.ijkl)
    end
    if idx === nothing; return; end

    x = zeros(length(m_local))
    x[idx] = 1.0
    
    # Arrows a little larger (0.08)
    settings = CloudAtlas.PlotSettings(
        num_points = 40,
        arrow_scale = 0.08, 
        colormap = :balance,
        fig_size = (1200, 900)
    )

    fig = Figure(size=settings.fig_size)
    vf = VelocityField(m_local, x)

    # YZ Plane at x=0
    ax_yz = Axis(fig[1, 1], title="YZ (x=0)", xlabel="Z", ylabel="Y", aspect=DataAspect())
    CloudAtlas.plot_yz_plane!(ax_yz, vf, settings, x_slice=0.0)

    # XZ Plane at y=0.5
    ax_xz = Axis(fig[1, 2], title="XZ (y=0.5)", xlabel="X", ylabel="Z", aspect=DataAspect())
    CloudAtlas.plot_xz_plane!(ax_xz, vf, settings, y_slice=0.5)

    # XY Plane at z=0.25
    ax_xy = Axis(fig[2, 1], title="XY (z=0.25)", xlabel="X", ylabel="Y", aspect=DataAspect())
    CloudAtlas.plot_xy_plane!(ax_xy, vf, settings, z_slice=0.25)

    ijkl_str = join(string.(m_info.ijkl), "_")
    save_path = "requested_mode_plots/mode_$(ijkl_str).png"

    CairoMakie.save(save_path, fig)
    println("Saved 2D: $save_path")
end

function plot_mode_3d(m_info)
    idx = find_mode(model, m_info.ijkl)
    m_local = model
    if idx === nothing
        m_local = ODEModel(α, γ, 1, 3, 5, H)
        idx = find_mode(m_local, m_info.ijkl)
    end
    if idx === nothing; return; end

    x_vec = zeros(length(m_local))
    x_vec[idx] = 1.0
    vf = VelocityField(m_local, x_vec)
    
    Lx = 2π/α
    Lz = 2π/γ
    
    # Grid for contouring
    Nx, Nz, Ny = 50, 50, 40
    xg = range(0, Lx, length=Nx)
    zg = range(0, Lz, length=Nz)
    yu = range(-1, 1, length=Ny)

    uu = fill(0.0, Nx, Nz, Ny)
    vu = fill(0.0, Nx, Nz, Ny)
    wu = fill(0.0, Nx, Nz, Ny)

    for i in 1:Nx, j in 1:Nz, k in 1:Ny
        uu[i,j,k] = vf(:u, xg[i], yu[k], zg[j])
        vu[i,j,k] = vf(:v, xg[i], yu[k], zg[j])
        wu[i,j,k] = vf(:w, xg[i], yu[k], zg[j])
    end

    # Arrow logic: Swirls on YZ plane (x=0)
    stride = 4
    yu2 = yu[1:stride:end]
    zg2 = zg[1:stride:end]
    pos = [Point3f(0.0, z, y) for z in zg2, y in yu2] |> vec
    # Mapping: Axis3(x, y, z) -> (streamwise, spanwise, wall-normal)
    # dir = (dx, dz, dy) -> (0, w, v)
    dirs = [Vec3f(0.0, vf(:w, 0.0, y, z), vf(:v, 0.0, y, z)) for z in zg2, y in yu2] |> vec

    # Normalize arrows for clean look
    max_d = maximum(norm.(dirs))
    if max_d > 1e-10; dirs = dirs ./ max_d .* (0.15 * Lz); end

    fig = Figure(size=(1000, 800))
    ax = Axis3(fig[1, 1], title="3D Mode $(m_info.ijkl)", 
               aspect=:data, azimuth=1.2π,
               xlabel="x", ylabel="z", zlabel="y", zticks=[-1, 0, 1])

    # 1. 3D Visualization of Streamwise Velocity (u) via Slices
    # Volume contours are not supported well in CairoMakie, so we use orthogonal slices.
    nx, nz, ny = 40, 40, 30
    xg = range(0, Lx, length=nx)
    zg = range(0, Lz, length=nz)
    yg = range(-1, 1, length=ny)
    
    # We plot 3 slices in Z and 3 in Y to show the structure
    z_slices = [0.25*Lz, 0.5*Lz, 0.75*Lz]
    y_slices = [-0.5, 0.0, 0.5]
    
    umax = 0.0
    for x in xg, y in yg, z in zg
        umax = max(umax, abs(vf(:u, x, y, z)))
    end
    if umax < 1e-10; umax = 1.0; end

    # Y-slices (Streamwise-Spanwise planes)
    for ys in y_slices
        u_slice = [vf(:u, x, ys, z) for x in xg, z in zg]
        surface!(ax, repeat(xg, 1, nz), repeat(zg', nx, 1), fill(ys, nx, nz), 
                 color=u_slice, colormap=:balance, alpha=0.4, colorrange=(-umax, umax), shading=NoShading)
    end

    # Z-slices (Streamwise-Wall-normal planes)
    for zs in z_slices
        u_slice = [vf(:u, x, y, zs) for x in xg, y in yg]
        surface!(ax, repeat(xg, 1, ny), fill(zs, nx, ny), repeat(yg', nx, 1), 
                 color=u_slice, colormap=:balance, alpha=0.4, colorrange=(-umax, umax), shading=NoShading)
    end

    # 2. Arrows for "Swirls" (v, w) on the YZ Plane at x = 0
    # Note: In this mapping, Y-axis is physical Z, Z-axis is physical Y.
    # So arrow vector is (0, w, v)
    stride = 5
    zg_arr = zg[1:stride:end]
    yg_arr = yg[1:stride:end]
    
    pts_yz = [Point3f(0.0, z, y) for z in zg_arr, y in yg_arr] |> vec
    dirs_yz = [Vec3f(0.0, vf(:w, 0.0, y, z), vf(:v, 0.0, y, z)) for z in zg_arr, y in yg_arr] |> vec
    
    # Normalizing arrows for visibility
    max_swirl = maximum(norm.(dirs_yz))
    if max_swirl > 1e-10
        dirs_yz = dirs_yz ./ max_swirl .* (0.15 * Lz)
    end

    if !isempty(dirs_yz)
        arrows!(ax, pts_yz, dirs_yz, color=:yellow, linewidth=1.5, 
                tiplength=0.08, tipradius=0.03)
    end

    tightlimits!(ax)

    ijkl_str = join(string.(m_info.ijkl), "_")
    save_path = "requested_mode_plots/mode_$(ijkl_str)_3d.png"

    CairoMakie.save(save_path, fig)
    println("Saved 3D (Wireframe): $save_path")
end

for m in requested_modes
    plot_mode_2d(m)
    plot_mode_3d(m)
end

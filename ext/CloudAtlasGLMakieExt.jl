module CloudAtlasGLMakieExt
using GLMakie
using CloudAtlas
using LinearAlgebra
using NCDatasets
using FastChebInterp
using Printf

# ── helpers ───────────────────────────────────────────────────────────────────

"""
    _build_basis_matrices(Ψ, xg, yu, zg)

Precompute basis evaluations on the 3D grid.  Returns `(Bu, Bv, Bw)`, each of
size `(m, Nx*Nz*Ny)`, so that the full velocity field for a coefficient vector
`xi` is just `reshape(Bu' * xi, Nx, Nz, Ny)` — a single BLAS matrix-vector
call per frame instead of a nested loop over grid points.

The flat index runs as `(nx, nz, ny)` — innermost x, then z, then y — matching
the `(Nx, Nz, Ny)` reshape used throughout.
"""
function _build_basis_matrices(Ψ, xg, yu, zg)
    Nx, Nz, Ny = length(xg), length(zg), length(yu)
    m  = length(Ψ)
    Bu = zeros(m, Nx*Nz*Ny)
    Bv = zeros(m, Nx*Nz*Ny)
    Bw = zeros(m, Nx*Nz*Ny)
    for i in 1:m
        idx = 1
        for iy in 1:Ny, iz in 1:Nz, ix in 1:Nx
            uvw = Ψ[i](xg[ix], yu[iy], zg[iz])
            Bu[i, idx] = uvw[1]
            Bv[i, idx] = uvw[2]
            Bw[i, idx] = uvw[3]
            idx += 1
        end
    end
    return Bu, Bv, Bw
end

"""
    _eval_uvw(xi, Bu, Bv, Bw, yu, Nx, Nz, Ny; baseflow=true)

Evaluate velocity components for coefficient vector `xi` using precomputed
basis matrices.  Returns `(u, v, w)` each of size `(Nx, Nz, Ny)`.
"""
function _eval_uvw(xi, Bu, Bv, Bw, yu, Nx, Nz, Ny; baseflow::Bool=true)
    u = reshape(Bu' * xi, Nx, Nz, Ny)
    v = reshape(Bv' * xi, Nx, Nz, Ny)
    w = reshape(Bw' * xi, Nx, Nz, Ny)
    if baseflow
        u .+= reshape(collect(yu), 1, 1, Ny)
    end
    return u, v, w
end

function _periodic_linear_map(nsrc::Int, ndst::Int)
    lo = Vector{Int}(undef, ndst)
    hi = Vector{Int}(undef, ndst)
    w = Vector{Float64}(undef, ndst)
    scale = nsrc / ndst
    for i in 1:ndst
        pos = (i - 1) * scale
        ilo = floor(Int, pos) + 1
        frac = pos - floor(pos)
        lo[i] = ilo
        hi[i] = mod1(ilo + 1, nsrc)
        w[i] = frac
    end
    return lo, hi, w
end

# ── flowfield3d ───────────────────────────────────────────────────────────────

"""
    flowfield3d(model, xi; baseflow=true, Nx=24, Nz=33, Ny=24,
                levels=6, colormap=:jet, azimuth=1.2π, ymax=1,
                title="", size=(1920,700))

Render a 3D contour visualisation of the velocity field for coefficient vector
`xi`, showing u, v, w side-by-side in a single Figure.
"""
function CloudAtlas.flowfield3d(model::CloudAtlas.ODEModel, xi::Vector;
                                baseflow::Bool = true,
                                Nx::Int = 24, Nz::Int = 33, Ny::Int = 24,
                                levels::Int = 6,
                                colormap = :jet,
                                azimuth::Real = 1.2π,
                                ymax::Real = 1,
                                title::String = "",
                                size = (1920, 700))
    Lx = 2π / model.α
    Lz = 2π / model.γ
    xg = range(0.0, Lx * (Nx-1)/Nx, Nx)
    zg = range(0.0, Lz * (Nz-1)/Nz, Nz)
    yu = range(-1.0, Float64(ymax), Ny)

    println("Precomputing basis on grid ($Nx×$Nz×$Ny)...")
    Bu, Bv, Bw = _build_basis_matrices(model.Ψ, xg, yu, zg)
    println("Done.")

    u, v, w = _eval_uvw(xi, Bu, Bv, Bw, yu, Nx, Nz, Ny; baseflow=baseflow)

    axis_kw = (; aspect=:data, azimuth=Float64(azimuth),
                 xlabel="x", ylabel="z", zlabel="y",
                 zticks=[-1, 0, Int(ymax)])
    cont_kw = (; levels=levels, colormap=colormap)

    fig = Figure(; size=size)
    isempty(title) || Label(fig[0, 1:3], title; fontsize=20, tellwidth=false)

    a1 = Axis3(fig[1,1]; title="u (streamwise)", axis_kw...)
    a2 = Axis3(fig[1,2]; title="v (wall-normal)", axis_kw...)
    a3 = Axis3(fig[1,3]; title="w (spanwise)",    axis_kw...)

    pu = contour!(a1, 0..Lx, 0..Lz, -1.0..Float64(ymax), u; cont_kw...)
    pv = contour!(a2, 0..Lx, 0..Lz, -1.0..Float64(ymax), v; cont_kw...)
    pw = contour!(a3, 0..Lx, 0..Lz, -1.0..Float64(ymax), w; cont_kw...)

    Colorbar(fig[2,1], pu; vertical=false, label="u")
    Colorbar(fig[2,2], pv; vertical=false, label="v")
    Colorbar(fig[2,3], pw; vertical=false, label="w")

    tightlimits!(a1); tightlimits!(a2); tightlimits!(a3)
    return fig
end

"""
    flowfield3d_comparison(model, xi, dns_file;
        baseflow=true, Nx=24, Nz=33, Ny=24,
        levels=6, colormap=:jet, azimuth=1.2π, ymax=1,
        title="", size=(1920,1080))

Static side-by-side 3D comparison between one DNS NetCDF snapshot and one ODE
state. DNS is shown on the top row, ODE on the bottom row, with shared color
limits per component.
"""
function CloudAtlas.flowfield3d_comparison(model::CloudAtlas.ODEModel, xi::Vector, dns_file::AbstractString;
                                           baseflow::Bool = true,
                                           Nx::Int = 24, Nz::Int = 33, Ny::Int = 24,
                                           levels::Int = 6,
                                           colormap = :jet,
                                           azimuth::Real = 1.2π,
                                           ymax::Real = 1,
                                           title::String = "",
                                           size = (1920, 1080))
    Lx = 2π / model.α
    Lz = 2π / model.γ
    xg = range(0.0, Lx * (Nx-1)/Nx, Nx)
    zg = range(0.0, Lz * (Nz-1)/Nz, Nz)
    yu = range(-1.0, Float64(ymax), Ny)

    println("Precomputing ODE basis on grid ($Nx×$Nz×$Ny)...")
    Bu, Bv, Bw = _build_basis_matrices(model.Ψ, xg, yu, zg)
    println("Done.")

    u_ode, v_ode, w_ode = _eval_uvw(xi, Bu, Bv, Bw, yu, Nx, Nz, Ny; baseflow=baseflow)
    u_dns, v_dns, w_dns = _load_dns_field(dns_file, Nx, Nz, Ny; ymax=ymax, baseflow=baseflow)

    u_lo = min(minimum(u_ode), minimum(u_dns))
    u_hi = max(maximum(u_ode), maximum(u_dns))
    v_lo = min(minimum(v_ode), minimum(v_dns))
    v_hi = max(maximum(v_ode), maximum(v_dns))
    w_lo = min(minimum(w_ode), minimum(w_dns))
    w_hi = max(maximum(w_ode), maximum(w_dns))

    u_lim = (-max(abs(u_lo), abs(u_hi)), max(abs(u_lo), abs(u_hi)))
    v_lim = (-max(abs(v_lo), abs(v_hi)), max(abs(v_lo), abs(v_hi)))
    w_lim = (-max(abs(w_lo), abs(w_hi)), max(abs(w_lo), abs(w_hi)))

    axis_kw = (; aspect=:data, azimuth=Float64(azimuth),
                 xlabel="x", ylabel="z", zlabel="y",
                 zticks=[-1, 0, Int(ymax)])

    fig = Figure(size=size)
    isempty(title) || Label(fig[0, 1:3], title; fontsize=22, tellwidth=false)

    Label(fig[1, 0], "DNS"; rotation=π/2, fontsize=16, tellheight=false)
    ad1 = Axis3(fig[1,1]; title="u (streamwise)", axis_kw...)
    ad2 = Axis3(fig[1,2]; title="v (wall-normal)", axis_kw...)
    ad3 = Axis3(fig[1,3]; title="w (spanwise)",    axis_kw...)
    pd1 = contour!(ad1, 0..Lx, 0..Lz, -1.0..Float64(ymax), u_dns; levels=levels, colormap=colormap, colorrange=u_lim)
    pd2 = contour!(ad2, 0..Lx, 0..Lz, -1.0..Float64(ymax), v_dns; levels=levels, colormap=colormap, colorrange=v_lim)
    pd3 = contour!(ad3, 0..Lx, 0..Lz, -1.0..Float64(ymax), w_dns; levels=levels, colormap=colormap, colorrange=w_lim)
    Colorbar(fig[2,1], pd1; vertical=false, label="u"); tightlimits!(ad1)
    Colorbar(fig[2,2], pd2; vertical=false, label="v"); tightlimits!(ad2)
    Colorbar(fig[2,3], pd3; vertical=false, label="w"); tightlimits!(ad3)

    Label(fig[3, 0], "ODE"; rotation=π/2, fontsize=16, tellheight=false)
    ao1 = Axis3(fig[3,1]; title="u (streamwise)", axis_kw...)
    ao2 = Axis3(fig[3,2]; title="v (wall-normal)", axis_kw...)
    ao3 = Axis3(fig[3,3]; title="w (spanwise)",    axis_kw...)
    po1 = contour!(ao1, 0..Lx, 0..Lz, -1.0..Float64(ymax), u_ode; levels=levels, colormap=colormap, colorrange=u_lim)
    po2 = contour!(ao2, 0..Lx, 0..Lz, -1.0..Float64(ymax), v_ode; levels=levels, colormap=colormap, colorrange=v_lim)
    po3 = contour!(ao3, 0..Lx, 0..Lz, -1.0..Float64(ymax), w_ode; levels=levels, colormap=colormap, colorrange=w_lim)
    Colorbar(fig[4,1], po1; vertical=false, label="u"); tightlimits!(ao1)
    Colorbar(fig[4,2], po2; vertical=false, label="v"); tightlimits!(ao2)
    Colorbar(fig[4,3], po3; vertical=false, label="w"); tightlimits!(ao3)

    return fig
end

"""
    flowfield3d_u_comparison(model, xi, dns_file;
        baseflow=true, Nx=24, Nz=33, Ny=24,
        levels=8, colormap=:balance, azimuth=1.2π, ymax=1,
        title="", subtitle="", dns_label="", ode_label="", footer="",
        size=(1800, 980))

Static side-by-side 3D contour comparison of the streamwise velocity `u` only.
This is intended for publication and poster figures where the `u` structure is
the only field of interest.
"""
function CloudAtlas.flowfield3d_u_comparison(model::CloudAtlas.ODEModel, xi::Vector, dns_file::AbstractString;
                                             baseflow::Bool = true,
                                             Nx::Int = 24, Nz::Int = 33, Ny::Int = 24,
                                             levels::Int = 8,
                                             colormap = :balance,
                                             azimuth::Real = 1.2π,
                                             ymax::Real = 1,
                                             title::String = "",
                                             subtitle::String = "",
                                             dns_label::String = "DNS",
                                             ode_label::String = "ODE",
                                             footer::String = "",
                                             size = (2400, 1350),
                                             font_scale::Real = 1.0)
    fs(size) = round(Int, Float64(font_scale) * size)
    Lx = 2π / model.α
    Lz = 2π / model.γ
    xg = range(0.0, Lx * (Nx - 1) / Nx, Nx)
    zg = range(0.0, Lz * (Nz - 1) / Nz, Nz)
    yu = range(-1.0, Float64(ymax), Ny)

    println("Precomputing ODE basis on grid ($Nx×$Nz×$Ny)...")
    Bu, _, _ = _build_basis_matrices(model.Ψ, xg, yu, zg)
    println("Done.")

    u_ode = reshape(Bu' * xi, Nx, Nz, Ny)
    if baseflow
        u_ode .+= reshape(collect(yu), 1, 1, Ny)
    end
    u_dns, _, _ = _load_dns_field(dns_file, Nx, Nz, Ny; ymax = ymax, baseflow = baseflow)

    u_abs = max(maximum(abs, u_ode), maximum(abs, u_dns))
    u_lim = (-u_abs, u_abs)

    axis_kw = (; aspect = :data, azimuth = Float64(azimuth),
        xlabel = "x", ylabel = "z", zlabel = "y",
        zticks = [-1, 0, Int(ymax)],
        xlabelsize = fs(34), ylabelsize = fs(34), zlabelsize = fs(34),
        xticklabelsize = fs(30), yticklabelsize = fs(30), zticklabelsize = fs(30))

    fig = Figure(size = size, fontsize = fs(22))
    row = 0
    if !isempty(title)
        row += 1
        Label(fig[row, 1:3], title; fontsize = fs(60), font = :bold, tellwidth = false)
    end
    if !isempty(subtitle)
        row += 1
        Label(fig[row, 1:3], subtitle; fontsize = fs(48), tellwidth = false)
    end
    spacer_row1 = row + 1
    spacer_row2 = row + 2
    Label(fig[spacer_row1, 1:3], " "; fontsize = fs(18), tellwidth = false)
    Label(fig[spacer_row2, 1:3], " "; fontsize = fs(28), tellwidth = false)
    top_row = row + 3

    ax_dns = Axis3(fig[top_row, 1]; title = dns_label, titlesize = fs(42), axis_kw...)
    ax_ode = Axis3(fig[top_row, 2]; title = ode_label, titlesize = fs(42), axis_kw...)
    p_dns = contour!(ax_dns, 0..Lx, 0..Lz, -1.0..Float64(ymax), u_dns;
        levels = levels, colormap = colormap, colorrange = u_lim)
    p_ode = contour!(ax_ode, 0..Lx, 0..Lz, -1.0..Float64(ymax), u_ode;
        levels = levels, colormap = colormap, colorrange = u_lim)
    tightlimits!(ax_dns)
    tightlimits!(ax_ode)

    Colorbar(fig[top_row, 3], p_dns;
        label = "streamwise velocity u",
        height = Relative(0.75),
        labelsize = fs(56),
        ticklabelsize = fs(52),
    )

    footer_row = top_row + 1
    if !isempty(footer)
        Label(fig[footer_row, 1:3], footer; fontsize = fs(16), tellwidth = false)
    end

    return fig
end

# ── animate_flow_3d ───────────────────────────────────────────────────────────

"""
    animate_flow_3d(model, sol, filename; baseflow=true, Nx=24, Nz=33, Ny=24,
                    levels=6, colormap=:jet, azimuth=1.2π, ymax=1,
                    framerate=15, label="")

Animate the velocity field along an ODE solution trajectory, writing an MP4 to
`filename`.  Shows u, v, w in three side-by-side 3D contour panels.

Basis matrices are precomputed once so each frame is a fast matrix-vector
product rather than a nested loop over grid points.

Color limits are fixed across all frames by pre-scanning the full trajectory.
Symmetric limits `(-a, a)` are used so that the zero level is always centred.
"""
function CloudAtlas.animate_flow_3d(model::CloudAtlas.ODEModel, sol, filename::String;
                                    baseflow::Bool = true,
                                    Nx::Int = 24, Nz::Int = 33, Ny::Int = 24,
                                    levels::Int = 6,
                                    colormap = :jet,
                                    azimuth::Real = 1.2π,
                                    ymax::Real = 1,
                                    framerate::Int = 15,
                                    label::String = "")
    Lx = 2π / model.α
    Lz = 2π / model.γ
    xg = range(0.0, Lx * (Nx-1)/Nx, Nx)
    zg = range(0.0, Lz * (Nz-1)/Nz, Nz)
    yu = range(-1.0, Float64(ymax), Ny)

    println("Precomputing basis on grid ($Nx×$Nz×$Ny)...")
    Bu, Bv, Bw = _build_basis_matrices(model.Ψ, xg, yu, zg)

    println("Scanning $(length(sol.t)) frames for global color limits...")
    u_abs = v_abs = w_abs = 0.0
    for i in 1:length(sol.t)
        u, v, w = _eval_uvw(sol.u[i], Bu, Bv, Bw, yu, Nx, Nz, Ny; baseflow=baseflow)
        u_abs = max(u_abs, maximum(abs, u))
        v_abs = max(v_abs, maximum(abs, v))
        w_abs = max(w_abs, maximum(abs, w))
    end
    u_lim = (-u_abs, u_abs)
    v_lim = (-v_abs, v_abs)
    w_lim = (-w_abs, w_abs)
    println("Color limits — u: $u_lim  v: $v_lim  w: $w_lim")
    println("Rendering $(length(sol.t)) frames → $filename")

    # Fixed isosurface values: evenly spaced within each component's range,
    # excluding the endpoints. Passing a vector rather than an integer prevents
    # Makie from recomputing level positions from the per-frame data range.
    u_levels = collect(range(u_lim[1], u_lim[2]; length = levels + 2))[2:end-1]
    v_levels = collect(range(v_lim[1], v_lim[2]; length = levels + 2))[2:end-1]
    w_levels = collect(range(w_lim[1], w_lim[2]; length = levels + 2))[2:end-1]

    u0, v0, w0 = _eval_uvw(sol.u[1], Bu, Bv, Bw, yu, Nx, Nz, Ny; baseflow=baseflow)
    uu_obs    = Observable(u0)
    vu_obs    = Observable(v0)
    wu_obs    = Observable(w0)
    title_obs = Observable(_frame_title(label, sol.t[1]))

    axis_kw = (; aspect=:data, azimuth=Float64(azimuth),
                 xlabel="x", ylabel="z", zlabel="y",
                 zticks=[-1, 0, Int(ymax)])

    fig = Figure(size=(1920, 1080))
    Label(fig[0, 1:3], title_obs; fontsize=24, tellwidth=false)

    a1 = Axis3(fig[1,1]; title="u (streamwise)", axis_kw...)
    a2 = Axis3(fig[1,2]; title="v (wall-normal)", axis_kw...)
    a3 = Axis3(fig[1,3]; title="w (spanwise)",    axis_kw...)

    pu = contour!(a1, 0..Lx, 0..Lz, -1.0..Float64(ymax), uu_obs;
                  levels=u_levels, colormap=colormap, colorrange=u_lim)
    pv = contour!(a2, 0..Lx, 0..Lz, -1.0..Float64(ymax), vu_obs;
                  levels=v_levels, colormap=colormap, colorrange=v_lim)
    pw = contour!(a3, 0..Lx, 0..Lz, -1.0..Float64(ymax), wu_obs;
                  levels=w_levels, colormap=colormap, colorrange=w_lim)

    Colorbar(fig[2,1], pu; vertical=false, label="u")
    Colorbar(fig[2,2], pv; vertical=false, label="v")
    Colorbar(fig[2,3], pw; vertical=false, label="w")

    tightlimits!(a1); tightlimits!(a2); tightlimits!(a3)

    record(fig, filename, 1:length(sol.t); framerate=framerate) do i
        u, v, w     = _eval_uvw(sol.u[i], Bu, Bv, Bw, yu, Nx, Nz, Ny; baseflow=baseflow)
        uu_obs[]    = u
        vu_obs[]    = v
        wu_obs[]    = w
        title_obs[] = _frame_title(label, sol.t[i])
    end

    println("Done: $filename")
end

_frame_title(label, t) = isempty(label) ? "t = $(round(t, digits=2))" :
                                          "$label   t = $(round(t, digits=2))"

# ── DNS field loading ─────────────────────────────────────────────────────────

"""
    _load_dns_field(filename, Nx, Nz, Ny; ymax=1)

Load a Channelflow NetCDF snapshot and interpolate from the Fourier-Chebyshev
grid onto a uniform `(Nx, Nz, Ny)` grid with y ∈ [-1, ymax].
Returns `(u, v, w)` each of size `(Nx, Nz, Ny)`, matching the ODE layout.
"""
function _load_dns_field(filename::AbstractString, Nx::Int, Nz::Int, Ny::Int;
                         ymax::Real=1, baseflow::Bool=true)
    ds = NCDataset(filename)
    u_nc = ds["Velocity_X"][:,:,:]   # (Nx_dns, Ny_dns, Nz_dns)
    v_nc = ds["Velocity_Y"][:,:,:]
    w_nc = ds["Velocity_Z"][:,:,:]
    Nx_dns = size(u_nc, 1)
    Ny_dns = size(u_nc, 2)
    Nz_dns = size(u_nc, 3)
    close(ds)

    yu = range(-1.0, Float64(ymax), Ny)

    # First resample each DNS (x,z) pencil from Chebyshev y nodes to the
    # uniform y grid used for plotting.
    u_y = zeros(Nx_dns, Nz_dns, Ny)
    v_y = zeros(Nx_dns, Nz_dns, Ny)
    w_y = zeros(Nx_dns, Nz_dns, Ny)
    for idx in 1:Nx_dns, idz in 1:Nz_dns
        pu = chebinterp(u_nc[idx, :, idz], -1.0, 1.0)
        pv = chebinterp(v_nc[idx, :, idz], -1.0, 1.0)
        pw = chebinterp(w_nc[idx, :, idz], -1.0, 1.0)
        for ny in 1:Ny
            y = yu[ny]
            u_y[idx, idz, ny] = pu(y)
            v_y[idx, idz, ny] = pv(y)
            w_y[idx, idz, ny] = pw(y)
        end
    end

    # Then interpolate periodically in the Fourier directions. The previous
    # rounded-index sampling duplicated planes whenever Nx or Nz exceeded the
    # DNS resolution, which showed up as a jagged surface in poster figures.
    xlo, xhi, xw = _periodic_linear_map(Nx_dns, Nx)
    zlo, zhi, zw = _periodic_linear_map(Nz_dns, Nz)

    u = zeros(Nx, Nz, Ny)
    v = zeros(Nx, Nz, Ny)
    w = zeros(Nx, Nz, Ny)
    @views for nx in 1:Nx, nz in 1:Nz
        i0, i1 = xlo[nx], xhi[nx]
        k0, k1 = zlo[nz], zhi[nz]
        wx = xw[nx]
        wz = zw[nz]
        c00 = (1.0 - wx) * (1.0 - wz)
        c10 = wx * (1.0 - wz)
        c01 = (1.0 - wx) * wz
        c11 = wx * wz
        u[nx, nz, :] .= c00 .* u_y[i0, k0, :] .+ c10 .* u_y[i1, k0, :] .+
                         c01 .* u_y[i0, k1, :] .+ c11 .* u_y[i1, k1, :]
        v[nx, nz, :] .= c00 .* v_y[i0, k0, :] .+ c10 .* v_y[i1, k0, :] .+
                         c01 .* v_y[i0, k1, :] .+ c11 .* v_y[i1, k1, :]
        w[nx, nz, :] .= c00 .* w_y[i0, k0, :] .+ c10 .* w_y[i1, k0, :] .+
                         c01 .* w_y[i0, k1, :] .+ c11 .* w_y[i1, k1, :]
    end

    if baseflow
        u .+= reshape(collect(yu), 1, 1, Ny)
    end
    return u, v, w
end

# ── animate_flow_3d_comparison ────────────────────────────────────────────────

"""
    animate_flow_3d_comparison(model, sol, dns_dir, filename;
        baseflow=true, Nx=24, Nz=33, Ny=24,
        levels=6, colormap=:jet, azimuth=1.2π, ymax=1,
        framerate=15, label="")

Side-by-side 3D animation comparing DNS (top row) and ODE model (bottom row).

DNS snapshots are loaded from `dns_dir/u{t}.nc` at each time in `sol.t`,
matching Channelflow's `simulateflow` naming: `u0.000.nc`, `u0.500.nc`, etc.

Colorbars are fixed across all frames: a pre-scan pass over the full trajectory
determines the global min/max for each component, shared between DNS and ODE rows.
"""
function CloudAtlas.animate_flow_3d_comparison(
        model::CloudAtlas.ODEModel, sol, dns_dir::AbstractString, filename::String;
        baseflow::Bool     = true,
        Nx::Int            = 24,
        Nz::Int            = 33,
        Ny::Int            = 24,
        levels::Int        = 6,
        colormap           = :jet,
        azimuth::Real      = 1.2π,
        ymax::Real         = 1,
        framerate::Int     = 15,
        label::String      = "")

    Lx = 2π / model.α
    Lz = 2π / model.γ
    xg = range(0.0, Lx * (Nx-1)/Nx, Nx)
    zg = range(0.0, Lz * (Nz-1)/Nz, Nz)
    yu = range(-1.0, Float64(ymax), Ny)

    println("Precomputing ODE basis on grid ($Nx×$Nz×$Ny)...")
    Bu, Bv, Bw = _build_basis_matrices(model.Ψ, xg, yu, zg)

    # ── Pre-scan: find global color limits across all frames and both solvers ──
    # Only animate frames where a DNS snapshot actually exists on disk.
    # simulateflow saves t = T0, T0+dT, …, T-dT (endpoint excluded).
    frames = filter(i -> isfile(joinpath(dns_dir, @sprintf("u%.3f.nc", sol.t[i]))),
                    1:length(sol.t))
    isempty(frames) && error("No DNS snapshots found in $dns_dir — check the path and dT.")
    println("Found $(length(frames)) matching DNS snapshots (of $(length(sol.t)) ODE frames).")

    println("Scanning all frames for global color limits...")
    u_lo = u_hi = v_lo = v_hi = w_lo = w_hi = 0.0
    for i in frames
        u, v, w = _eval_uvw(sol.u[i], Bu, Bv, Bw, yu, Nx, Nz, Ny; baseflow=baseflow)
        u_lo = min(u_lo, minimum(u));  u_hi = max(u_hi, maximum(u))
        v_lo = min(v_lo, minimum(v));  v_hi = max(v_hi, maximum(v))
        w_lo = min(w_lo, minimum(w));  w_hi = max(w_hi, maximum(w))

        dns_file = joinpath(dns_dir, @sprintf("u%.3f.nc", sol.t[i]))
        ud, vd, wd = _load_dns_field(dns_file, Nx, Nz, Ny; ymax=ymax, baseflow=baseflow)
        u_lo = min(u_lo, minimum(ud)); u_hi = max(u_hi, maximum(ud))
        v_lo = min(v_lo, minimum(vd)); v_hi = max(v_hi, maximum(vd))
        w_lo = min(w_lo, minimum(wd)); w_hi = max(w_hi, maximum(wd))
    end
    # Symmetric limits look better for diverging colormaps
    u_lim = (-max(abs(u_lo), abs(u_hi)), max(abs(u_lo), abs(u_hi)))
    v_lim = (-max(abs(v_lo), abs(v_hi)), max(abs(v_lo), abs(v_hi)))
    w_lim = (-max(abs(w_lo), abs(w_hi)), max(abs(w_lo), abs(w_hi)))
    println("Color limits — u: $u_lim  v: $v_lim  w: $w_lim")

    println("Rendering $(length(frames)) frames → $filename")

    # initial fields (use first matched frame)
    i0 = frames[1]
    u_ode0, v_ode0, w_ode0 = _eval_uvw(sol.u[i0], Bu, Bv, Bw, yu, Nx, Nz, Ny; baseflow=baseflow)
    dns_file0 = joinpath(dns_dir, @sprintf("u%.3f.nc", sol.t[i0]))
    u_dns0, v_dns0, w_dns0 = _load_dns_field(dns_file0, Nx, Nz, Ny; ymax=ymax, baseflow=baseflow)

    uu_dns = Observable(u_dns0);  vu_dns = Observable(v_dns0);  wu_dns = Observable(w_dns0)
    uu_ode = Observable(u_ode0);  vu_ode = Observable(v_ode0);  wu_ode = Observable(w_ode0)
    title_obs = Observable(_frame_title(label, sol.t[i0]))

    axis_kw = (; aspect=:data, azimuth=Float64(azimuth),
                 xlabel="x", ylabel="z", zlabel="y",
                 zticks=[-1, 0, Int(ymax)])

    fig = Figure(size=(1920, 1080))
    Label(fig[0, 1:3], title_obs; fontsize=22, tellwidth=false)

    # DNS row
    Label(fig[1, 0], "DNS";  rotation=π/2, fontsize=16, tellheight=false)
    ad1 = Axis3(fig[1,1]; title="u (streamwise)", axis_kw...)
    ad2 = Axis3(fig[1,2]; title="v (wall-normal)", axis_kw...)
    ad3 = Axis3(fig[1,3]; title="w (spanwise)",    axis_kw...)
    pd1 = contour!(ad1, 0..Lx, 0..Lz, -1.0..Float64(ymax), uu_dns; levels=levels, colormap=colormap, colorrange=u_lim)
    pd2 = contour!(ad2, 0..Lx, 0..Lz, -1.0..Float64(ymax), vu_dns; levels=levels, colormap=colormap, colorrange=v_lim)
    pd3 = contour!(ad3, 0..Lx, 0..Lz, -1.0..Float64(ymax), wu_dns; levels=levels, colormap=colormap, colorrange=w_lim)
    Colorbar(fig[2,1], pd1; vertical=false, label="u"); tightlimits!(ad1)
    Colorbar(fig[2,2], pd2; vertical=false, label="v"); tightlimits!(ad2)
    Colorbar(fig[2,3], pd3; vertical=false, label="w"); tightlimits!(ad3)

    # ODE row
    Label(fig[3, 0], "ODE"; rotation=π/2, fontsize=16, tellheight=false)
    ao1 = Axis3(fig[3,1]; title="u (streamwise)", axis_kw...)
    ao2 = Axis3(fig[3,2]; title="v (wall-normal)", axis_kw...)
    ao3 = Axis3(fig[3,3]; title="w (spanwise)",    axis_kw...)
    po1 = contour!(ao1, 0..Lx, 0..Lz, -1.0..Float64(ymax), uu_ode; levels=levels, colormap=colormap, colorrange=u_lim)
    po2 = contour!(ao2, 0..Lx, 0..Lz, -1.0..Float64(ymax), vu_ode; levels=levels, colormap=colormap, colorrange=v_lim)
    po3 = contour!(ao3, 0..Lx, 0..Lz, -1.0..Float64(ymax), wu_ode; levels=levels, colormap=colormap, colorrange=w_lim)
    Colorbar(fig[4,1], po1; vertical=false, label="u"); tightlimits!(ao1)
    Colorbar(fig[4,2], po2; vertical=false, label="v"); tightlimits!(ao2)
    Colorbar(fig[4,3], po3; vertical=false, label="w"); tightlimits!(ao3)

    record(fig, filename, frames; framerate=framerate) do i
        t = sol.t[i]

        u, v, w  = _eval_uvw(sol.u[i], Bu, Bv, Bw, yu, Nx, Nz, Ny; baseflow=baseflow)
        uu_ode[] = u;  vu_ode[] = v;  wu_ode[] = w

        dns_file    = joinpath(dns_dir, @sprintf("u%.3f.nc", t))
        ud, vd, wd  = _load_dns_field(dns_file, Nx, Nz, Ny; ymax=ymax, baseflow=baseflow)
        uu_dns[]    = ud; vu_dns[] = vd; wu_dns[] = wd

        title_obs[] = _frame_title(label, t)
    end

    println("Done: $filename")
end

end # module

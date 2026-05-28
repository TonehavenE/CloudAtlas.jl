using Makie, GLMakie, FastChebInterp
using NCDatasets



function flowfield3d(filename::String; baseflow=true, component=1, levels=4, stride=4, ymax=1, colormap=:jet,
                     title="", size=(750,450), azimuth=1.2pi, xarrows=0.0, arrowcolor=:none, lengthscale=6, 
                     markerscale=2)

    # size = (750,450) good for 10 x 10 box
    # size = (500,350) good for 2pi x 1pi box
    ds = NCDataset(filename)
    x = ds["X"][:]
    y = ds["Y"][:]
    z = ds["Z"][:]
    Lx = ds.attrib["Lx"]
    Lz = ds.attrib["Lz"]

    # velocity field components in x,y,z order, as stored in NetCDF files
    u = ds["Velocity_X"][:,:,:]
    v = ds["Velocity_Y"][:,:,:]
    w = ds["Velocity_Z"][:,:,:]

    Nx, Ny, Nz = length(x), length(y), length(z)

    # Fourier-Chebyshev grid values for x,y,z, and a uniform grid for y
    xg = collect(range(0, 2pi, Nx))
    yg = collect(cos.(range(0, pi, Ny)))
    zg = collect(range(0, pi, Nz))
    yu = collect(range(-1, ymax, Ny))

    # velocity field components, in x,z,y order, for plotting in Makie
    uu = fill(0.0, Nx,Nz,Ny)
    vu = fill(0.0, Nx,Nz,Ny)
    wu = fill(0.0, Nx,Nz,Ny)

    for i in 1:Nx, j in 1:Nz
        poly = chebinterp(u[i,:,j], -1, 1)
        uu[i,j,:] = baseflow ? poly.(yu) + yu : poly.(yu)
    end

    for i in 1:Nx, j in 1:Nz
        poly = chebinterp(v[i,:,j], -1, 1)
        vu[i,j,:] = poly.(yu)
    end
    for i in 1:Nx, j in 1:Nz
        poly = chebinterp(w[i,:,j], -1, 1)
        wu[i,j,:] = poly.(yu)
    end

    # strided grid points
    xg2 = xg[1:stride:end]
    yu2 = yu[1:stride:end]
    zg2 = zg[1:stride:end]
    
    Nx2 = length(xg2)
    Ny2 = length(yu2)
    Nz2 = length(zg2)

    # reduce 3d arrays by striding in x,y,z (should combine this with generation of uu, vu, wu above)
    #         x         z        y
    uu2 = uu[1:stride:end, 1:stride:end, 1:stride:end]
    vu2 = vu[1:stride:end, 1:stride:end, 1:stride:end]
    wu2 = wu[1:stride:end, 1:stride:end, 1:stride:end]

    zticks = ymax>0.0 ? [-1;0;ymax] : [-1;ymax]
    f = Figure(size = size)
    
    a1 = Axis3(f[1, 1], aspect = :data, azimuth=azimuth, zticks=zticks,
               bbox=BBox(50, 400, 50, 300), xlabel="x", ylabel="z", zlabel="y")

    # plot arrows in x=0 y,z plane
    if arrowcolor != :none
        #uus = reshape(uu2[1,:,:], (1,Nz2,Ny2))
        #wus = reshape(wu2[1,:,:], (1,Nz2,Ny2))
        #vus = reshape(vu2[1,:,:], (1,Nz2,Ny2))

        pos = [Point3f(xarrows, zg2[i], yu2[j]) for i in 1:Nz2, j in 1:Ny2]
        dirs = [Vec3f(0.0, wu2[1,i,j], vu2[1,i,j])  for i in 1:Nz2, j in 1:Ny2]

        arrows3d!(pos, dirs, align=:tail, color=arrowcolor, shaftlength=0.8, shaftradius=0.1, tipradius=0.2,
            lengthscale=lengthscale, markerscale=markerscale)
    end
    
    contour!(a1, 0..Lx, 0..Lz, -1..ymax, uu, levels=levels, colormap=colormap)
    Label(f[1, 1, Top()], title, padding = (0, 0, 0, 0), fontsize=24)
    tightlimits!(a1)
    f
end

function flowfield3d(xi::Vector, Ψ, Lx::Real, Lz::Real, Nx::Int, Ny::Int, Nz::Int; component=1, stride=4,
                     baseflow=true, levels=4, ymax=1, colormap=:jet, title="", size=(750,450),
                     azimuth=1.2pi, xarrows=0.0, arrowcolor=:none, lengthscale=6, markerscale=2)

    
    # Fourier-Chebyshev grid values for x,y,z, and a uniform grid for y
    xg = range(0, Lx*(Nx-1)/Nx, Nx)
    yu = collect(range(-1, ymax, Ny))
    zg = range(0, Lz*(Nz-1)/Nz, Nz)

    Nmodes = length(xi)
    length(Ψ) == Nmodes || error("length(xi) == $(length(xi)) ≠ $(length(Ψ)) == length(Ψ)")

    # 3d arrays for u,v,w velocity components, uniform grid in y
    u = zeros(Nx, Nz, Ny)
    v = zeros(Nx, Nz, Ny)
    w = zeros(Nx, Nz, Ny)
    
    for i = 1:Nmodes
        for ny=1:Ny, nz = 1:Nz, nx = 1:Nx
            Ψuvw = Ψ[i](xg[nx], yu[ny], zg[nz])
            u[nx, nz, ny] += xi[i]*Ψuvw[1] 
            v[nx, nz, ny] += xi[i]*Ψuvw[2]
            w[nx, nz, ny] += xi[i]*Ψuvw[3]
        end
    end
    
    if baseflow
        for ny=1:Ny, nz = 1:Nz, nx = 1:Nx
            u[nx, nz, ny] += yu[ny]
        end
    end

    zticks = ymax>0.0 ? [-1;0;ymax] : [-1;ymax]
    f = Figure(size = size)
    
    a1 = Axis3(f[1, 1], aspect = :data, azimuth=azimuth, zticks=zticks,
               bbox=BBox(50, 400, 50, 300), xlabel="x", ylabel="z", zlabel="y")

    # plot arrows in x=0, y,z plane
    if arrowcolor != :none
        pos = [Point3f(xarrows, zg[i], yu[j]) for i in 1:stride:Nz, j in 1:stride:Ny]
        dirs = [Vec3f(0.0, w[1,i,j], v[1,i,j])  for i in 1:stride:Nz, j in 1:stride:Ny]

        arrows3d!(pos, dirs, align=:tail, color=arrowcolor, shaftlength=0.8, shaftradius=0.1, tipradius=0.2,
            lengthscale=lengthscale, markerscale=markerscale)
    end

    # the 3d velocity field has 3 components [u,v,w], the velocities in x,y,z directions
    # set which to view according to `component` function argument
    # default view is 1, the u component 

    uview = u
    if component == 2
       uview = v
    elseif component == 3
       uview = w
    end
             
    contour!(a1, 0..Lx, 0..Lz, -1..ymax, uview, levels=levels, colormap=colormap)

    Label(f[1, 1, Top()], title, padding = (0, 0, 0, 0), fontsize=24)
    tightlimits!(a1)
    f
end

# -*- coding: utf-8 -*-
# Generate DNS snapshots for the Gibson Re=200 periodic-orbit archive.
#
# This is intentionally separate from `reproduce_gibson_orbits_ode.jl`:
# DNS snapshot generation is a one-time preprocessing step, while the ODE
# reproduction/refinement script can be rerun many times against the saved series.
#
# Example:
#   CLOUDATLAS_SKIP_ACTIVATE=true \
#   GIBSON_ORBIT_IDS=1 \
#   GIBSON_DNS_SNAPSHOTS=31 \
#   GIBSON_ODE_OUT_DIR=notebooks/periodic_orbits/gibson/ode_reproduction_attempt \
#   julia --startup-file=no --project=. notebooks/periodic_orbits/gibson/generate_gibson_dns_timeseries.jl

if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "..", "..", ".."))
end

using ChannelflowWrapper
using Printf

function parse_bool_env(name::AbstractString, default::Bool)
    raw = lowercase(strip(get(ENV, name, default ? "true" : "false")))
    raw in ("1", "true", "t", "yes", "y") && return true
    raw in ("0", "false", "f", "no", "n") && return false
    error("Invalid boolean ENV[$name]='$raw'")
end

function parse_float_env(name::AbstractString, default::Float64)
    parse(Float64, strip(get(ENV, name, string(default))))
end

function parse_int_env(name::AbstractString, default::Int)
    parse(Int, strip(get(ENV, name, string(default))))
end

function parse_orbit_ids_env(name::AbstractString, default::Vector{Int})
    raw = strip(get(ENV, name, ""))
    isempty(raw) && return default
    ids = [parse(Int, strip(x)) for x in split(raw, ",") if !isempty(strip(x))]
    all(id -> 1 <= id <= 4, ids) || error("$name must contain ids in 1:4")
    return unique(ids)
end

const HERE = @__DIR__
archive = joinpath(HERE, "orbits-1-4-Re200-2pi1pi.tgz")
isfile(archive) || error("Missing Gibson orbit archive: $archive")

outdir = abspath(get(ENV, "GIBSON_ODE_OUT_DIR", joinpath(HERE, "ode_reproduction_attempt")))
extract_dir = joinpath(outdir, "dns_orbits")
mkpath(extract_dir)

orbit_ids = parse_orbit_ids_env("GIBSON_ORBIT_IDS", [1, 2, 3, 4])
Re = parse_float_env("GIBSON_RE", 200.0)
dns_snapshots = parse_int_env("GIBSON_DNS_SNAPSHOTS", 31)
dns_dt = parse_float_env("GIBSON_DNS_DT", 0.03125)
dns_label = strip(get(ENV, "GIBSON_DNS_LABEL", "u"))
dns_np0 = parse_int_env("GIBSON_DNS_NP0", 4)
dns_np1 = parse_int_env("GIBSON_DNS_NP1", 1)
force = parse_bool_env("GIBSON_FORCE_DNS_SERIES", false)
dns_symms = strip(get(ENV, "GIBSON_DNS_SYMMS", ""))

function ensure_orbit_archive_extracted(archive::AbstractString, extract_dir::AbstractString)
    needed = [joinpath(extract_dir, "orbit$(id)-Re200-2pi1pi", "ubest.nc") for id in 1:4]
    all(isfile, needed) && return
    mkpath(extract_dir)
    run(`tar -xzf $archive -C $extract_dir`)
end

orbit_dir(id::Int) = joinpath(extract_dir, "orbit$(id)-Re200-2pi1pi")
orbit_ubest(id::Int) = joinpath(orbit_dir(id), "ubest.nc")
orbit_period(id::Int) = parse(Float64, strip(read(joinpath(orbit_dir(id), "Tbest.asc"), String)))
series_dir(id::Int) = joinpath(outdir, "orbit$(id)", "dns_series")

function default_symm_file(outdir::AbstractString)
    path = joinpath(outdir, "symm_E_sxyz_sztxz.asc")
    isfile(path) && return path
    open(path, "w") do io
        println(io, "% 2")
        println(io, "1 -1 -1 -1 0.0 0.0")
        println(io, "1 1 1 -1 0.5 0.5")
    end
    return path
end

function existing_snapshots(dir::AbstractString, label::AbstractString)
    isdir(dir) || return String[]
    filter(path -> isfile(path) && startswith(basename(path), label) && endswith(path, ".nc"),
           joinpath.(Ref(dir), readdir(dir)))
end

ensure_orbit_archive_extracted(archive, extract_dir)
symms = isempty(dns_symms) ? default_symm_file(outdir) : abspath(dns_symms)
isfile(symms) || error("DNS symmetry file not found: $symms")

@printf("Output root: %s\n", outdir)
@printf("Symmetry file: %s\n", symms)

for id in orbit_ids
    T = orbit_period(id)
    dir = series_dir(id)
    mkpath(dir)
    existing = existing_snapshots(dir, dns_label)
    if !force && length(existing) >= max(2, dns_snapshots - 1)
        @printf("Orbit %d: reusing %d existing snapshots in %s\n", id, length(existing), dir)
        continue
    end

    dT = T / max(dns_snapshots - 1, 1)
    @printf("Orbit %d: generating %d snapshots, T=%.12f, dT=%.12f\n",
            id, dns_snapshots, T, dT)
    ChannelflowWrapper.simulateflow(
        orbit_ubest(id);
        np0 = dns_np0,
        np1 = dns_np1,
        R = Re,
        symms = symms,
        T = T,
        dT = dT,
        dt = dns_dt,
        o = dir,
        l = dns_label,
    )
end

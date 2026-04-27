if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "..", ".."))
end

using CloudAtlas
using CSV
using DataFrames
using DelimitedFiles
using Dates
using Printf

const DEFAULT_CATALOG_DIR = joinpath(@__DIR__, "eqb_catalog")
const DEFAULT_SOLUTIONS_DIR = joinpath(DEFAULT_CATALOG_DIR, "solutions")
const DEFAULT_PHYSICAL_PATH = joinpath(DEFAULT_CATALOG_DIR, "physical_solutions.csv")
const ASC_FILE_RE = r"^(on|ls)_([A-G])_J(\d+)K(\d+)L(\d+)\.asc$"

function parse_args(args)
    out = Dict{String,String}()
    i = 1
    while i <= length(args)
        if startswith(args[i], "--")
            key = args[i][3:end]
            if i == length(args) || startswith(args[i + 1], "--")
                out[key] = "true"
                i += 1
            else
                out[key] = args[i + 1]
                i += 2
            end
        else
            i += 1
        end
    end
    return out
end

safeparse(::Type{Float64}, s) = try parse(Float64, strip(string(s))) catch; NaN end
safeparse(::Type{Int}, s) = try parse(Int, strip(string(s))) catch; 0 end

function parse_local_asc_filename(name::AbstractString)
    m = match(ASC_FILE_RE, name)
    m === nothing && return nothing
    return (
        source = m.captures[1],
        group  = m.captures[2],
        J      = safeparse(Int, m.captures[3]),
        K      = safeparse(Int, m.captures[4]),
        L      = safeparse(Int, m.captures[5]),
        jkl    = (
            safeparse(Int, m.captures[3]),
            safeparse(Int, m.captures[4]),
            safeparse(Int, m.captures[5]),
        ),
    )
end

function find_best_local_asc(sol_dir::AbstractString)
    isdir(sol_dir) || return nothing
    best = nothing
    for name in readdir(sol_dir)
        endswith(name, ".asc") || continue
        parsed = parse_local_asc_filename(name)
        parsed === nothing && continue
        cand = merge(parsed, (asc_path = joinpath(sol_dir, name),))
        better = if best === nothing
            true
        elseif cand.jkl > best.jkl
            true
        elseif cand.jkl == best.jkl && cand.source == "on" && best.source == "ls"
            true
        else
            false
        end
        best = better ? cand : best
    end
    return best
end

function load_asc_vector(path::AbstractString)
    for cc in ('#', '%')
        X = readdlm(path; comments=true, comment_char=cc)
        vals = vec(X)
        isempty(vals) && continue
        return Float64.(vals)
    end
    error("Could not read coefficient vector from $path")
end

function symmetry_groups()
    sx, sy, sz, tx, tz = halfbox_symmetries()
    return Dict(
        "A" => [sx * sy * sz, tx * tz],
        "B" => [sx * sy, sz],
        "C" => [sx * sy * tz, sz],
        "D" => [sx * sy, sz * tx],
        "E" => [sx * sy * sz, sz * tx * tz],
        "F" => [sx * sy, sz, tx * tz],
        "G" => [sx * sy * sz],
    )
end

function model_key(case::AbstractString, group::AbstractString, J::Int, K::Int, L::Int)
    return (String(case), String(group), J, K, L)
end

function get_model!(cache, case, α, γ, group, H, J, K, L)
    key = model_key(case, group, J, K, L)
    if !haskey(cache, key)
        println("  [model] building $(case) group=$(group) J$(J)K$(K)L$(L)")
        cache[key] = ODEModel(α, γ, J, K, L, H; normalize=false, tw=false)
    end
    return cache[key]
end

function ensure_glmakie_loaded()
    if !isdefined(Main, :GLMakie)
        Core.eval(Main, :(using GLMakie))
    end
    return Base.invokelatest(() -> getfield(Main, :GLMakie))
end

function split_list(s::AbstractString)
    return [strip(x) for x in split(s, ',') if !isempty(strip(x))]
end

function select_rows(df::DataFrame, args)
    rows = df
    if haskey(args, "case")
        cases = Set(split_list(args["case"]))
        rows = filter(r -> String(r.case) in cases, rows)
    end
    if haskey(args, "physical-id")
        ids = Set(split_list(args["physical-id"]))
        rows = filter(r -> String(r.physical_id) in ids, rows)
    elseif get(args, "all", "false") != "true"
        limit = haskey(args, "limit") ? parse(Int, args["limit"]) : 4
        rows = first(rows, min(limit, nrow(rows)))
    end
    return rows
end

function render_flowfield(row, solutions_dir::AbstractString, out_dir::AbstractString, model_cache; args=Dict{String,String}())
    glmakie = ensure_glmakie_loaded()
    pid = String(row.physical_id)
    sol_dir = joinpath(solutions_dir, pid)
    best = find_best_local_asc(sol_dir)
    best === nothing && error("No local .asc seed for $pid in $sol_dir")

    Re = Float64(row.Re)
    Lx = Float64(row.Lx)
    Lz = Float64(row.Lz)
    α = 2π / Lx
    γ = 2π / Lz
    H = symmetry_groups()[best.group]

    model = get_model!(model_cache, String(row.case), α, γ, best.group, H, best.J, best.K, best.L)
    x = load_asc_vector(best.asc_path)
    length(x) == length(model) || error("Loaded $(length(x)) coefficients from $(best.asc_path), expected $(length(model))")

    Nx = haskey(args, "Nx") ? parse(Int, args["Nx"]) : 28
    Nz = haskey(args, "Nz") ? parse(Int, args["Nz"]) : 36
    Ny = haskey(args, "Ny") ? parse(Int, args["Ny"]) : 24
    levels = haskey(args, "levels") ? parse(Int, args["levels"]) : 7
    ymax = haskey(args, "ymax") ? parse(Float64, args["ymax"]) : 1.0
    baseflow = !haskey(args, "baseflow") || lowercase(args["baseflow"]) != "false"
    simple_title = get(args, "title", "simple") == "simple"

    title = if simple_title
        @sprintf(
            "%s   Re=%d   Lx=%.2f   Lz=%.2f   %s-group   J%dK%dL%d",
            pid, round(Int, Re), Lx, Lz, best.group, best.J, best.K, best.L
        )
    else
        @sprintf(
            "%s   Re=%d   Lx=%.2f   Lz=%.2f   %s-group   J%dK%dL%d   shear=%.3f   ||x||=%.3f",
            pid, round(Int, Re), Lx, Lz, best.group, best.J, best.K, best.L, shear(x, model), norm(x)
        )
    end

    fig = Base.invokelatest(
        CloudAtlas.flowfield3d,
        model,
        x;
        baseflow=baseflow,
        Nx=Nx,
        Nz=Nz,
        Ny=Ny,
        levels=levels,
        ymax=ymax,
        title=title,
        size=(1920, 1080),
        azimuth=1.2π,
    )

    mkpath(out_dir)
    out_png = joinpath(out_dir, "$(pid).png")
    Base.invokelatest(glmakie.save, out_png, fig)
    println("Saved $out_png   (seed $(best.source)_$(best.group)_J$(best.J)K$(best.K)L$(best.L))")
    return (
        physical_id = pid,
        case = String(row.case),
        Re = Re,
        Lx = Lx,
        Lz = Lz,
        group = best.group,
        source = best.source,
        J = best.J,
        K = best.K,
        L = best.L,
        asc_path = best.asc_path,
        out_png = out_png,
    )
end

function write_manifest(path::AbstractString, rows)
    open(path, "w") do io
        println(io, "physical_id,case,Re,Lx,Lz,group,source,J,K,L,asc_path,out_png")
        for r in rows
            println(io,
                string(r.physical_id, ",", r.case, ",", r.Re, ",", r.Lx, ",", r.Lz, ",",
                       r.group, ",", r.source, ",", r.J, ",", r.K, ",", r.L, ",",
                       r.asc_path, ",", r.out_png))
        end
    end
end

function main(args=ARGS)
    parsed = parse_args(args)
    physical_path = get(parsed, "physical", DEFAULT_PHYSICAL_PATH)
    solutions_dir = get(parsed, "solutions-dir", DEFAULT_SOLUTIONS_DIR)
    out_root = get(parsed, "out-dir", joinpath(DEFAULT_CATALOG_DIR, "flowfields_" * Dates.format(now(), "yyyymmdd_HHMMSS")))

    phys = CSV.read(physical_path, DataFrame)
    if get(parsed, "include-trivial", "false") != "true" && "is_trivial" in names(phys)
        phys = filter(r -> !Bool(r.is_trivial), phys)
    end
    phys = sort(phys, [:case, :physical_id])
    selected = select_rows(phys, parsed)
    isempty(selected) && error("No matching catalog entries found in $physical_path")

    dry_run = get(parsed, "dry-run", "false") == "true"
    println("Selected $(nrow(selected)) catalog entries")
    println("Output dir: $out_root")
    if dry_run
        for row in eachrow(selected)
            pid = String(row.physical_id)
            best = find_best_local_asc(joinpath(solutions_dir, pid))
            if best === nothing
                println("  $pid   MISSING_ASC")
            else
                println("  $pid   $(row.case)   $(best.source)_$(best.group)_J$(best.J)K$(best.K)L$(best.L)")
            end
        end
        return
    end

    ensure_glmakie_loaded()

    model_cache = Dict()
    manifest_rows = NamedTuple[]
    for row in eachrow(selected)
        push!(manifest_rows, render_flowfield(row, solutions_dir, out_root, model_cache; args=parsed))
    end

    manifest_path = joinpath(out_root, "manifest.csv")
    write_manifest(manifest_path, manifest_rows)
    println("Wrote manifest: $manifest_path")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end

if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "..", ".."))
end

using CSV
using Channelflow_jll
using DataFrames
using Dates
using Printf

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

parse_float(args, key, default) = parse(Float64, get(args, key, string(default)))

function changegrid(infield::AbstractString, outfield::AbstractString; Lx, Lz, Nx, Ny, Nz)
    mkpath(dirname(outfield))
    cmd = `$(Channelflow_jll.changegrid()) -Lx $(string(Lx)) -Lz $(string(Lz)) -Nx $(string(Nx)) -Ny $(string(Ny)) -Nz $(string(Nz)) $(abspath(infield)) $(abspath(outfield))`
    run(cmd)
    return outfield
end

function l2op(field1::AbstractString, field2::AbstractString, flags::Vector{String})
    cmd = `$(Channelflow_jll.L2op()) $flags $(abspath(field1)) $(abspath(field2))`
    return parse(Float64, strip(read(cmd, String)))
end

l2norm(field::AbstractString) = sqrt(l2op(field, field, ["-ip"]))

function distance_variants(field1::AbstractString, field2::AbstractString)
    variants = [
        ("none", String[]),
        ("sx", ["-sx"]),
        ("sz", ["-sz"]),
        ("sx_sz", ["-sx", "-sz"]),
    ]
    rows = NamedTuple[]
    for (label, extra) in variants
        flags = vcat(["-dist", "-n"], extra)
        d = l2op(field1, field2, flags)
        push!(rows, (shift = label, distance = d))
    end
    sort!(rows; by = r -> r.distance)
    return rows
end

function main(args=ARGS)
    parsed = parse_args(args)
    catalog_root = abspath(get(parsed, "catalog-root", "catalog/dns_geometry_to_ghc/rebuilt_catalog"))
    success_path = abspath(get(parsed, "success-manifest", joinpath(catalog_root, "dns_geometry_success_manifest.csv")))
    out_dir = abspath(get(parsed, "out-dir", joinpath(catalog_root, "comparisons")))
    threshold = parse_float(parsed, "threshold", 1e-3)
    Nx = parse(Int, get(parsed, "Nx", "48"))
    Ny = parse(Int, get(parsed, "Ny", "49"))
    Nz = parse(Int, get(parsed, "Nz", "48"))

    isfile(success_path) || error("Success manifest not found: $success_path")
    successes = CSV.read(success_path, DataFrame; stringtype=String)
    nrow(successes) >= 2 || error("Need at least two target fields to compare")
    target_Lx = parse_float(parsed, "target-Lx", successes.target_Lx[1])
    target_Lz = parse_float(parsed, "target-Lz", successes.target_Lz[1])
    mkpath(out_dir)

    resampled_dir = joinpath(out_dir, "resampled")
    fields = Dict{String,String}()
    diagnostics = NamedTuple[]
    for row in eachrow(successes)
        src = joinpath(catalog_root, row.rebuilt_dns)
        isfile(src) || error("Missing rebuilt field: $src")
        dst = joinpath(resampled_dir, row.physical_id * ".nc")
        changegrid(src, dst; Lx=target_Lx, Lz=target_Lz, Nx=Nx, Ny=Ny, Nz=Nz)
        norm = l2norm(dst)
        fields[row.physical_id] = dst
        push!(diagnostics, (
            physical_id = row.physical_id,
            source_case = row.source_case,
            group = row.group,
            target_Lx = target_Lx,
            target_Lz = target_Lz,
            Nx = Nx,
            Ny = Ny,
            Nz = Nz,
            resampled_ubest = dst,
            l2norm = norm,
            near_trivial = norm <= 1e-8,
        ))
    end
    diagnostics_path = joinpath(out_dir, "target_field_diagnostics.csv")
    CSV.write(diagnostics_path, DataFrame(diagnostics))

    rows = NamedTuple[]
    for i in 1:(nrow(successes) - 1)
        a = successes[i, :]
        field_a = fields[a.physical_id]
        for j in (i + 1):nrow(successes)
            b = successes[j, :]
            field_b = fields[b.physical_id]
            variants = distance_variants(field_a, field_b)
            best = first(variants)
            unshifted = only(filter(r -> r.shift == "none", variants))
            push!(rows, (
                source_id = a.physical_id,
                target_id = b.physical_id,
                source_case = a.source_case,
                target_case = b.source_case,
                source_group = a.group,
                target_group = b.group,
                target_Lx = a.target_Lx,
                target_Lz = a.target_Lz,
                best_shift = best.shift,
                best_distance = best.distance,
                unshifted_distance = unshifted.distance,
                is_candidate = best.distance <= threshold,
            ))
        end
    end

    df = DataFrame(rows)
    sort!(df, [:best_distance, :source_id, :target_id])
    pairwise_path = joinpath(out_dir, "target_pairwise_distances.csv")
    candidates_path = joinpath(out_dir, "target_duplicate_candidates.csv")
    CSV.write(pairwise_path, df)
    CSV.write(candidates_path, filter(r -> r.is_candidate, df))

    readme_path = joinpath(out_dir, "README.md")
    open(readme_path, "w") do io
        println(io, "# DNS Geometry-to-GHC Target Comparisons")
        println(io)
        println(io, "Generated: $(now())")
        println(io)
        println(io, "- Fields compared: $(nrow(successes))")
        println(io, "- Pairwise comparisons: $(nrow(df))")
        println(io, "- Candidate threshold: normalized L2 distance <= $(threshold)")
        println(io, "- Distance is the minimum over no half-shift, `sx`, `sz`, and `sx+sz`.")
        println(io)
        if any(df.is_candidate)
            println(io, "## Candidates")
            println(io)
            for r in eachrow(filter(r -> r.is_candidate, df))
                @printf(io, "- `%s` <-> `%s`: %.6g (%s)\n", r.source_id, r.target_id, r.best_distance, r.best_shift)
            end
        else
            println(io, "No candidate duplicates passed the threshold.")
        end
    end

    println("[wrote] $pairwise_path ($(nrow(df)) pairs)")
    println("[wrote] $candidates_path ($(nrow(filter(r -> r.is_candidate, df))) candidates)")
    println("[wrote] $diagnostics_path")
    println("[wrote] $readme_path")
    !isempty(df.best_distance) && @printf("[nearest] %s <-> %s distance %.6g shift=%s\n", df.source_id[1], df.target_id[1], df.best_distance[1], df.best_shift[1])
end

main()

if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "..", ".."))
end

using CSV
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

parse_bool(args, key; default=false) =
    lowercase(strip(get(args, key, string(default)))) in ("1", "true", "yes", "y")

safe_float(x) = try parse(Float64, string(x)) catch; NaN end

function relpath_from(path::AbstractString, root::AbstractString)
    return relpath(abspath(path), abspath(root))
end

function csv_string(x)
    if ismissing(x)
        return ""
    elseif x isa AbstractVector
        return join(string.(x), ",")
    else
        return string(x)
    end
end

function json_escape(s::AbstractString)
    out = IOBuffer()
    for c in s
        if c == '"'
            write(out, "\\\"")
        elseif c == '\\'
            write(out, "\\\\")
        elseif c == '\n'
            write(out, "\\n")
        elseif c == '\r'
            write(out, "\\r")
        elseif c == '\t'
            write(out, "\\t")
        else
            write(out, c)
        end
    end
    return String(take!(out))
end

function final_plan_rows(plan::DataFrame)
    by_id = Dict{String,DataFrameRow}()
    for row in eachrow(plan)
        id = string(row.physical_id)
        if !haskey(by_id, id) || Int(row.segment_index) > Int(by_id[id].segment_index)
            by_id[id] = row
        end
    end
    return by_id
end

function target_ubest_for(row; include_already_target=false, tol=1e-8)
    cont = string(row.cont)
    if cont == "already_target"
        include_already_target || return nothing
        seed = string(row.seed)
        return isfile(seed) ? (ubest = seed, kind = "already_target") : nothing
    end

    out_dir = string(row.out_dir)
    target_dir = joinpath(out_dir, "Target")
    ubest = joinpath(target_dir, "ubest.nc")
    isfile(ubest) || return nothing

    mu_path = joinpath(target_dir, "mu.asc")
    if isfile(mu_path)
        mu = safe_float(strip(read(mu_path, String)))
        target_mu = safe_float(row.target_mu)
        if !isnan(mu) && !isnan(target_mu) && abs(mu - target_mu) > tol
            return nothing
        end
    end

    return (ubest = ubest, kind = "continued_to_target")
end

function write_index(path, row, target_Lx, target_Lz, source_ubest)
    open(path, "w") do io
        println(io, "---")
        println(io, "physical_id: \"$(row.physical_id)\"")
        println(io, "case: \"$(row.case)\"")
        println(io, "catalog_source: \"dns_geometry_to_ghc\"")
        println(io, "Re: $(row.Re)")
        println(io, "Lx: $(target_Lx)")
        println(io, "Lz: $(target_Lz)")
        println(io, "source_dns: \"$(source_ubest)\"")
        println(io, "---")
        println(io)
        println(io, "# $(row.physical_id)")
        println(io)
        println(io, "Rebuilt from DNS geometry continuation to the GHC target box.")
        println(io)
        println(io, "| Quantity | Value |")
        println(io, "|---|---:|")
        println(io, "| Source case | `$(row.case)` |")
        println(io, "| Re | $(row.Re) |")
        println(io, "| Lx | $(target_Lx) |")
        println(io, "| Lz | $(target_Lz) |")
        println(io)
        println(io, "## Representative Files")
        println(io)
        println(io, "- ODE coefficients: [representative.asc](representative.asc)")
        println(io, "- DNS flowfield: [ubest.nc](ubest.nc)")
    end
end

function write_metadata(dst_meta, row, target_Lx, target_Lz, rel_dns, rel_ode, source_ubest)
    open(dst_meta, "w") do io
        println(io, "{")
        println(io, "  \"physical_id\": \"$(json_escape(string(row.physical_id)))\",")
        println(io, "  \"case\": \"$(json_escape(string(row.case)))\",")
        println(io, "  \"catalog_source\": \"dns_geometry_to_ghc\",")
        println(io, "  \"Re\": $(safe_float(row.Re)),")
        println(io, "  \"Lx\": $(target_Lx),")
        println(io, "  \"Lz\": $(target_Lz),")
        println(io, "  \"shear\": $(safe_float(row.shear)),")
        println(io, "  \"L2\": $(safe_float(row.L2)),")
        println(io, "  \"groups\": \"$(json_escape(csv_string(row.groups)))\",")
        println(io, "  \"representative_group\": \"$(json_escape(string(row.representative_group)))\",")
        println(io, "  \"source_dns_geometry_ubest\": \"$(json_escape(source_ubest))\",")
        println(io, "  \"assets\": {")
        println(io, "    \"dns\": \"$(json_escape(rel_dns))\",")
        println(io, "    \"ode\": \"$(json_escape(rel_ode))\"")
        println(io, "  }")
        println(io, "}")
    end
end

function main(args=ARGS)
    parsed = parse_args(args)
    catalog_root = abspath(get(parsed, "catalog-root", "catalog"))
    geometry_root = abspath(get(parsed, "geometry-root", joinpath(catalog_root, "dns_geometry_to_ghc")))
    out_dir = abspath(get(parsed, "out-dir", joinpath(geometry_root, "rebuilt_catalog")))
    include_already_target = parse_bool(parsed, "include-already-target"; default=false)

    manifest_path = abspath(get(parsed, "manifest", joinpath(catalog_root, "catalog_manifest.csv")))
    plan_path = abspath(get(parsed, "plan", joinpath(geometry_root, "plan.csv")))
    isfile(manifest_path) || error("Catalog manifest not found: $manifest_path")
    isfile(plan_path) || error("Geometry plan not found: $plan_path")

    manifest = CSV.read(manifest_path, DataFrame; stringtype=String)
    plan = CSV.read(plan_path, DataFrame; stringtype=String)
    finals = final_plan_rows(plan)

    successes = NamedTuple[]
    rebuilt_rows = DataFrame()
    target_pairs = Set{Tuple{Float64,Float64}}()

    mkpath(out_dir)
    eqb_dir = joinpath(out_dir, "equilibria")
    mkpath(eqb_dir)

    for row in eachrow(manifest)
        id = string(row.physical_id)
        haskey(finals, id) || continue
        final = finals[id]
        result = target_ubest_for(final; include_already_target=include_already_target)
        result === nothing && continue
        target_Lx = safe_float(final.target_Lx)
        target_Lz = safe_float(final.target_Lz)
        push!(target_pairs, (target_Lx, target_Lz))

        dst_sol = joinpath(eqb_dir, id)
        mkpath(dst_sol)

        src_sol = joinpath(catalog_root, "equilibria", id)
        src_ode = joinpath(src_sol, "representative.asc")
        dst_ode = joinpath(dst_sol, "representative.asc")
        isfile(src_ode) && cp(src_ode, dst_ode; force=true)
        dst_ubest = joinpath(dst_sol, "ubest.nc")
        cp(result.ubest, dst_ubest; force=true)

        rel_sol = relpath_from(dst_sol, out_dir)
        rel_dns = joinpath(rel_sol, "ubest.nc")
        rel_ode = joinpath(rel_sol, "representative.asc")

        newrow = copy(DataFrame(row))
        newrow[!, :Lx] .= target_Lx
        newrow[!, :Lz] .= target_Lz
        newrow[!, :catalog_source] .= "dns_geometry_to_ghc"
        hasproperty(newrow, :dns) && (newrow[!, :dns] .= rel_dns)
        hasproperty(newrow, :ode) && (newrow[!, :ode] .= rel_ode)
        append!(rebuilt_rows, newrow; cols=:union)

        write_metadata(
            joinpath(dst_sol, "metadata.json"),
            row,
            target_Lx,
            target_Lz,
            rel_dns,
            rel_ode,
            result.ubest,
        )
        write_index(joinpath(dst_sol, "index.md"), row, target_Lx, target_Lz, result.ubest)

        push!(successes, (
            physical_id = id,
            source_case = string(row.case),
            Re = safe_float(row.Re),
            group = string(row.representative_group),
            source_kind = result.kind,
            target_Lx = target_Lx,
            target_Lz = target_Lz,
            source_ubest = result.ubest,
            rebuilt_dns = rel_dns,
        ))
    end

    sort!(successes; by = r -> r.physical_id)
    sort!(rebuilt_rows, :physical_id)

    success_path = joinpath(out_dir, "dns_geometry_success_manifest.csv")
    CSV.write(success_path, DataFrame(successes))

    manifest_out = joinpath(out_dir, "catalog_manifest.csv")
    CSV.write(manifest_out, rebuilt_rows)

    readme = joinpath(out_dir, "README.md")
    open(readme, "w") do io
        println(io, "# Rebuilt DNS Geometry-to-GHC Catalog")
        println(io)
        println(io, "Generated: $(now())")
        println(io)
        println(io, "- Source manifest: `$(relpath_from(manifest_path, out_dir))`")
        println(io, "- Source plan: `$(relpath_from(plan_path, out_dir))`")
        if length(target_pairs) == 1
            target_Lx, target_Lz = only(target_pairs)
            println(io, "- Target `Lx = $(target_Lx)`, `Lz = $(target_Lz)`")
        else
            println(io, "- Target geometries: $(length(target_pairs))")
        end
        println(io, "- Successful target entries: $(length(successes))")
        println(io, "- Include already-target seeds: $(include_already_target)")
        println(io)
        println(io, "A continued run is counted only when its final planned segment contains `Target/ubest.nc`.")
    end

    println("[wrote] $success_path ($(length(successes)) successes)")
    println("[wrote] $manifest_out ($(nrow(rebuilt_rows)) catalog rows)")
    println("[wrote] $eqb_dir")
end

main()

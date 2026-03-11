import Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))

using CairoMakie
using DelimitedFiles
using Dates
using Printf
using Statistics

const SYMM_ORDER = ["A", "B", "C", "D", "E", "F", "G"]

function parse_args(args)
    out = Dict{String, String}()
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

function parse_csv(path::AbstractString)
    isfile(path) || return String[], Vector{Dict{String, String}}()
    lines = readlines(path)
    isempty(lines) && return String[], Vector{Dict{String, String}}()
    header = split(chomp(lines[1]), ',')
    rows = Vector{Dict{String, String}}()
    for ln in lines[2:end]
        s = chomp(ln)
        isempty(strip(s)) && continue
        vals = split(s, ',')
        length(vals) < length(header) && append!(vals, fill("", length(header) - length(vals)))
        row = Dict{String, String}()
        for i in eachindex(header)
            row[header[i]] = i <= length(vals) ? vals[i] : ""
        end
        push!(rows, row)
    end
    return header, rows
end

safeparse(::Type{Int}, s::AbstractString) = try parse(Int, strip(s)) catch; 0 end
safeparse(::Type{Float64}, s::AbstractString) = try parse(Float64, strip(s)) catch; NaN end

function read_case_queue(path::AbstractString)
    _, rows = parse_csv(path)
    out = Dict{String, NamedTuple}()
    for r in rows
        case = get(r, "case_label", "")
        isempty(case) && continue
        out[case] = (
            case_label=case,
            Re=safeparse(Float64, get(r, "Re", "NaN")),
            Lx=safeparse(Float64, get(r, "Lx", "NaN")),
            Lz=safeparse(Float64, get(r, "Lz", "NaN")),
            out_dir=get(r, "out_dir", ""),
        )
    end
    return out
end

function parse_jkl_dir(name::AbstractString)
    m = match(r"^jkl_(\d+)_(\d+)_(\d+)$", name)
    m === nothing && return nothing
    return (safeparse(Int, m.captures[1]), safeparse(Int, m.captures[2]), safeparse(Int, m.captures[3]))
end

function read_solution_statistics(path::AbstractString)
    _, rows = parse_csv(path)
    out = NamedTuple[]
    for r in rows
        push!(out, (
            level_idx=safeparse(Int, get(r, "level_idx", "0")),
            J=safeparse(Int, get(r, "J", "0")),
            K=safeparse(Int, get(r, "K", "0")),
            L=safeparse(Int, get(r, "L", "0")),
            source=get(r, "source", ""),
            attempted_seeds=safeparse(Int, get(r, "attempted_seeds", "0")),
            hookstep_converged=safeparse(Int, get(r, "hookstep_converged", "0")),
            accepted_postfilter=safeparse(Int, get(r, "accepted_postfilter", "0")),
            unique_solutions=safeparse(Int, get(r, "unique_solutions", "0")),
            promotions_reconverged=safeparse(Int, get(r, "promotions_reconverged", "0")),
        ))
    end
    sort!(out; by=x -> x.level_idx)
    return out
end

function read_shears_from_summary(path::AbstractString)
    _, rows = parse_csv(path)
    shears = Float64[]
    for r in rows
        s = safeparse(Float64, get(r, "shear", "NaN"))
        isfinite(s) && push!(shears, s)
    end
    return shears
end

function collect_overview(runs_root::AbstractString)
    queue_path = joinpath(runs_root, "run_queue_summary.csv")
    case_meta = read_case_queue(queue_path)
    case_dirs = filter(x -> isdir(joinpath(runs_root, x)), readdir(runs_root))
    sort!(case_dirs)

    rows = NamedTuple[]
    for case in case_dirs
        meta = get(
            case_meta,
            case,
            (case_label=case, Re=NaN, Lx=NaN, Lz=NaN, out_dir=joinpath(runs_root, case)),
        )
        case_dir = joinpath(runs_root, case)
        for sym in SYMM_ORDER
            sym_dir = joinpath(case_dir, sym)
            isdir(sym_dir) || continue
            stats_path = joinpath(sym_dir, "solution_statistics.csv")
            stats = read_solution_statistics(stats_path)
            isempty(stats) && continue
            final = stats[end]
            max_level = maximum(r.level_idx for r in stats)
            final_jkl = (final.J, final.K, final.L)
            final_summary = joinpath(sym_dir, @sprintf("jkl_%d_%d_%d", final_jkl...), "solutions_summary.csv")
            shears = read_shears_from_summary(final_summary)
            push!(rows, (
                case_label=case,
                Re=meta.Re,
                Lx=meta.Lx,
                Lz=meta.Lz,
                symmetry=sym,
                max_level=max_level,
                final_J=final.J,
                final_K=final.K,
                final_L=final.L,
                final_unique=final.unique_solutions,
                final_hookstep=final.hookstep_converged,
                total_hookstep=sum(r.hookstep_converged for r in stats),
                total_unique_sum=sum(r.unique_solutions for r in stats),
                n_final_shear=length(shears),
                mean_final_shear=isempty(shears) ? NaN : mean(shears),
                median_final_shear=isempty(shears) ? NaN : median(shears),
                shears=shears,
            ))
        end
    end
    return rows
end

function write_overview_csv(path::AbstractString, rows)
    open(path, "w") do io
        println(
            io,
            "case_label,Re,Lx,Lz,symmetry,max_level,final_J,final_K,final_L,final_unique,final_hookstep,total_hookstep,total_unique_sum,n_final_shear,mean_final_shear,median_final_shear",
        )
        for r in rows
            println(
                io,
                "$(r.case_label),$(r.Re),$(r.Lx),$(r.Lz),$(r.symmetry),$(r.max_level),$(r.final_J),$(r.final_K),$(r.final_L),$(r.final_unique),$(r.final_hookstep),$(r.total_hookstep),$(r.total_unique_sum),$(r.n_final_shear),$(r.mean_final_shear),$(r.median_final_shear)",
            )
        end
    end
end

function unique_cases(rows)
    cases = unique(r.case_label for r in rows)
    sort!(collect(cases))
end

function plot_heatmap_metric(rows, cases, metric_sym::Symbol, title::String, out_path::AbstractString; cblabel::String=String(metric_sym))
    case_idx = Dict(c => i for (i, c) in enumerate(cases))
    sym_idx = Dict(s => i for (i, s) in enumerate(SYMM_ORDER))
    mat = fill(NaN, length(SYMM_ORDER), length(cases))
    for r in rows
        i = get(sym_idx, r.symmetry, 0)
        j = get(case_idx, r.case_label, 0)
        (i == 0 || j == 0) && continue
        mat[i, j] = Float64(getproperty(r, metric_sym))
    end

    fig = Figure(size=(280 + 140 * max(1, length(cases)), 480))
    ax = Axis(fig[1, 1], title=title, xlabel="Case", ylabel="Symmetry")
    hm = heatmap!(ax, 1:length(cases), 1:length(SYMM_ORDER), mat; colormap=:viridis, nan_color=:lightgray)
    ax.xticks = (1:length(cases), cases)
    ax.yticks = (1:length(SYMM_ORDER), SYMM_ORDER)
    Colorbar(fig[1, 2], hm, label=cblabel)
    save(out_path, fig)
    return out_path
end

function plot_case_stats(rows, case::String, out_path::AbstractString)
    case_rows = filter(r -> r.case_label == case, rows)
    isempty(case_rows) && return nothing
    sort!(case_rows; by=r -> findfirst(==(r.symmetry), SYMM_ORDER))

    labels = [r.symmetry for r in case_rows]
    uniqs = [r.final_unique for r in case_rows]

    fig = Figure(size=(1200, 480))
    ax1 = Axis(fig[1, 1], title="Final # Solutions by Symmetry", xlabel="Symmetry", ylabel="# solutions")
    barplot!(ax1, 1:length(labels), uniqs, color=:steelblue)
    ax1.xticks = (1:length(labels), labels)

    ax2 = Axis(fig[1, 2], title="Final-Level Shear Distribution", xlabel="Symmetry", ylabel="shear")
    for (i, r) in enumerate(case_rows)
        shears = r.shears
        isempty(shears) && continue
        jitter = (rand(length(shears)) .- 0.5) .* 0.25
        scatter!(ax2, fill(i, length(shears)) .+ jitter, shears; markersize=8, color=(:tomato, 0.6))
        med = median(shears)
        lines!(ax2, [i - 0.25, i + 0.25], [med, med], color=:black, linewidth=2)
    end
    ax2.xticks = (1:length(labels), labels)
    save(out_path, fig)
    return out_path
end

function main()
    args = parse_args(ARGS)
    runs_root = get(args, "runs-root", joinpath(@__DIR__, "overnight_runs_updated"))
    out_dir = get(args, "out", joinpath(runs_root, "analysis"))
    mkpath(out_dir)

    rows = collect_overview(runs_root)
    isempty(rows) && error("No run data found under $runs_root")
    cases = unique_cases(rows)

    overview_csv = joinpath(out_dir, "overview_stats.csv")
    write_overview_csv(overview_csv, rows)

    p1 = plot_heatmap_metric(
        rows,
        cases,
        :final_unique,
        "Final Unique Solutions (by symmetry, case)",
        joinpath(out_dir, "heatmap_final_unique.png");
        cblabel="# solutions",
    )
    p2 = plot_heatmap_metric(
        rows,
        cases,
        :max_level,
        "Max Ladder Level Reached",
        joinpath(out_dir, "heatmap_max_level.png");
        cblabel="level_idx",
    )
    p3 = plot_heatmap_metric(
        rows,
        cases,
        :mean_final_shear,
        "Mean Shear at Final Level",
        joinpath(out_dir, "heatmap_mean_final_shear.png");
        cblabel="mean shear",
    )

    case_plots = String[]
    for case in cases
        outp = joinpath(out_dir, "case_$(case)_stats.png")
        p = plot_case_stats(rows, case, outp)
        p === nothing || push!(case_plots, p)
    end

    summary_md = joinpath(out_dir, "analysis_summary.md")
    open(summary_md, "w") do io
        println(io, "# EQB Discovery Analysis")
        println(io)
        println(io, "Generated: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")
        println(io)
        println(io, "- runs_root: `$(runs_root)`")
        println(io, "- overview_csv: `$(overview_csv)`")
        println(io, "- plots:")
        println(io, "  - `$(p1)`")
        println(io, "  - `$(p2)`")
        println(io, "  - `$(p3)`")
        for p in case_plots
            println(io, "  - `$(p)`")
        end
    end

    println("[done] wrote:")
    println("  $(overview_csv)")
    println("  $(p1)")
    println("  $(p2)")
    println("  $(p3)")
    for p in case_plots
        println("  $(p)")
    end
    println("  $(summary_md)")
end

main()

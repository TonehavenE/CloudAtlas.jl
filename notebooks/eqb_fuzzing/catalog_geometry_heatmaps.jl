if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "..", ".."))
end

using Dates
using Printf

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

function parse_bool(args::Dict{String, String}, key::String; default::Bool = false)
    haskey(args, key) || return default
    val = lowercase(strip(args[key]))
    val in ("1", "true", "yes", "y", "on") && return true
    val in ("0", "false", "no", "n", "off") && return false
    error("Invalid bool for --$key: $(args[key])")
end

safeparse(::Type{Float64}, s) = try
    parse(Float64, strip(string(s)))
catch
    NaN
end

safeparse(::Type{Int}, s) = try
    parse(Int, strip(string(s)))
catch
    0
end

function read_csv(path)
    isfile(path) || return String[], Dict{String, String}[]
    lines = readlines(path)
    isempty(lines) && return String[], Dict{String, String}[]
    header = split(chomp(lines[1]), ',')
    rows = Dict{String, String}[]
    for ln in lines[2:end]
        s = chomp(ln)
        isempty(strip(s)) && continue
        vals = String[]
        in_quote = false
        buf = IOBuffer()
        for ch in s
            if ch == '"'
                in_quote = !in_quote
            elseif ch == ',' && !in_quote
                push!(vals, String(take!(buf)))
            else
                write(buf, ch)
            end
        end
        push!(vals, String(take!(buf)))
        row = Dict{String, String}()
        for i in eachindex(header)
            row[header[i]] = i <= length(vals) ? vals[i] : ""
        end
        push!(rows, row)
    end
    return header, rows
end

function csv_escape(x)
    s = string(x)
    if occursin(',', s) || occursin('"', s) || occursin('\n', s)
        return "\"" * replace(s, "\"" => "\"\"") * "\""
    end
    return s
end

function parse_member_entry(s)
    m = match(r"^(on|ls):sol(\d+)@J(\d+)K(\d+)L(\d+)$", strip(s))
    m === nothing && return nothing
    return (
        source = m.captures[1],
        sol_id = safeparse(Int, m.captures[2]),
        J = safeparse(Int, m.captures[3]),
        K = safeparse(Int, m.captures[4]),
        L = safeparse(Int, m.captures[5]),
    )
end

function find_best_asc(group_rows, on_root, ls_root)
    best = nothing
    for r in group_rows
        case = r["case"]
        group = r["group"]
        for entry_str in split(r["all_members"], ';')
            m = parse_member_entry(entry_str)
            m === nothing && continue
            run_root = m.source == "on" ? on_root : ls_root
            asc_path = joinpath(
                run_root,
                case,
                group,
                "jkl_$(m.J)_$(m.K)_$(m.L)",
                "sol$(m.sol_id).asc",
            )
            isfile(asc_path) || continue
            jkl = (m.J, m.K, m.L)
            is_better = if best === nothing
                true
            elseif jkl > best.jkl
                true
            elseif jkl == best.jkl && m.source == "on" && best.source == "ls"
                true
            else
                false
            end
            if is_better
                best = (
                    source = m.source,
                    case = case,
                    group = group,
                    J = m.J,
                    K = m.K,
                    L = m.L,
                    sol_id = m.sol_id,
                    jkl = jkl,
                    asc_path = asc_path,
                )
            end
        end
    end
    return best
end

function maybe_filtered_rows(rows, args)
    out = rows
    if haskey(args, "case")
        wanted = Set(strip.(split(args["case"], ',')))
        out = [r for r in out if r["case"] in wanted]
    end
    if haskey(args, "physical-id")
        wanted = Set(strip.(split(args["physical-id"], ',')))
        out = [r for r in out if r["physical_id"] in wanted]
    end
    parse_bool(args, "include-trivial"; default = false) || (out = [r for r in out if lowercase(r["is_trivial"]) != "true"])
    if haskey(args, "groups")
        wanted = Set(strip.(split(args["groups"], ',')))
        out = [r for r in out if !isempty(intersect(Set(strip.(split(replace(r["groups"], "\"" => ""), ','))), wanted))]
    end
    if haskey(args, "limit")
        lim = parse(Int, args["limit"])
        out = out[1:min(lim, length(out))]
    end
    return out
end

function local_grid_bounds(center::Float64, halfspan::Float64, n::Int; lower::Float64 = 0.25)
    lo = max(lower, center - halfspan)
    hi = max(lo + 1e-6, center + halfspan)
    return lo, hi, n
end

function physical_numeric_id(physical_id::String)
    m = match(r"_(\d+)$", physical_id)
    m === nothing && return 1
    return parse(Int, m.captures[1])
end

function shell_command_string(parts::Vector{String})
    return join([occursin(' ', p) ? "'$(p)'" : p for p in parts], ' ')
end

function select_groups_for_pid(group_rows, best, group_mode::String)
    if group_mode == "seed"
        return [best.group]
    elseif group_mode == "all-catalog"
        return sort(unique(r["group"] for r in group_rows))
    end
    error("Unknown --group-mode: $group_mode (expected seed or all-catalog)")
end

function build_job(row, group, chosen, args, out_root)
    physical_id = row["physical_id"]
    center_Lx = safeparse(Float64, row["Lx"])
    center_Lz = safeparse(Float64, row["Lz"])
    Re = haskey(args, "Re") ? parse(Float64, args["Re"]) : safeparse(Float64, row["Re"])
    J = haskey(args, "J") ? parse(Int, args["J"]) : chosen.J
    K = haskey(args, "K") ? parse(Int, args["K"]) : chosen.K
    L = haskey(args, "L") ? parse(Int, args["L"]) : chosen.L

    Lx_halfspan = parse(Float64, get(args, "Lx-halfspan", "2.0"))
    Lz_halfspan = parse(Float64, get(args, "Lz-halfspan", "1.5"))
    Lx_n = parse(Int, get(args, "Lx-n", "25"))
    Lz_n = parse(Int, get(args, "Lz-n", "25"))
    Lx_min, Lx_max, _ = local_grid_bounds(center_Lx, Lx_halfspan, Lx_n)
    Lz_min, Lz_max, _ = local_grid_bounds(center_Lz, Lz_halfspan, Lz_n)

    physical_dir = joinpath(out_root, physical_id, group)
    run_parts = String[
        "julia",
        "--startup-file=no",
        "--project=.",
        "notebooks/alpha_gamma_grid/continue_minre_branch.jl",
        "--groups",
        group,
        "--out",
        physical_dir,
        "--seed-eqb",
        chosen.asc_path,
        "--seed-Lx",
        string(center_Lx),
        "--seed-Lz",
        string(center_Lz),
        "--seed-id",
        string(physical_numeric_id(physical_id)),
        "--grid",
        "manual",
        "--Lx-min",
        string(Lx_min),
        "--Lx-max",
        string(Lx_max),
        "--Lx-n",
        string(Lx_n),
        "--Lz-min",
        string(Lz_min),
        "--Lz-max",
        string(Lz_max),
        "--Lz-n",
        string(Lz_n),
        "--J",
        string(J),
        "--K",
        string(K),
        "--L",
        string(L),
        "--Re",
        string(Re),
    ]

    if haskey(args, "noise")
        append!(run_parts, ["--noise", args["noise"]])
    end
    if haskey(args, "trials")
        append!(run_parts, ["--trials", args["trials"]])
    end
    if haskey(args, "max-attempts")
        append!(run_parts, ["--max-attempts", args["max-attempts"]])
    end

    return (
        physical_id = physical_id,
        case = row["case"],
        Re = Re,
        center_Lx = center_Lx,
        center_Lz = center_Lz,
        group = group,
        seed_source = chosen.source,
        seed_J = chosen.J,
        seed_K = chosen.K,
        seed_L = chosen.L,
        eval_J = J,
        eval_K = K,
        eval_L = L,
        seed_sol_id = chosen.sol_id,
        seed_asc = chosen.asc_path,
        out_dir = physical_dir,
        Lx_min = Lx_min,
        Lx_max = Lx_max,
        Lx_n = Lx_n,
        Lz_min = Lz_min,
        Lz_max = Lz_max,
        Lz_n = Lz_n,
        cmd_parts = run_parts,
        cmd_string = shell_command_string(run_parts),
    )
end

function write_manifest(path, jobs)
    open(path, "w") do io
        println(io, "physical_id,case,Re,Lx_center,Lz_center,group,seed_source,seed_J,seed_K,seed_L,eval_J,eval_K,eval_L,seed_sol_id,Lx_min,Lx_max,Lx_n,Lz_min,Lz_max,Lz_n,seed_asc,out_dir,cmd")
        for job in jobs
            row = [
                job.physical_id,
                job.case,
                job.Re,
                job.center_Lx,
                job.center_Lz,
                job.group,
                job.seed_source,
                job.seed_J,
                job.seed_K,
                job.seed_L,
                job.eval_J,
                job.eval_K,
                job.eval_L,
                job.seed_sol_id,
                job.Lx_min,
                job.Lx_max,
                job.Lx_n,
                job.Lz_min,
                job.Lz_max,
                job.Lz_n,
                job.seed_asc,
                job.out_dir,
                job.cmd_string,
            ]
            println(io, join(csv_escape.(row), ','))
        end
    end
end

function write_job_files(jobs, args, out_root)
    for job in jobs
        mkpath(job.out_dir)
        open(joinpath(job.out_dir, "run_command.txt"), "w") do io
            println(io, job.cmd_string)
        end
        open(joinpath(job.out_dir, "job_info.md"), "w") do io
            println(io, "# $(job.physical_id) / $(job.group)")
            println(io)
            println(io, "- case: `$(job.case)`")
            println(io, "- center geometry: `Lx=$(job.center_Lx)`, `Lz=$(job.center_Lz)`")
            println(io, "- Re: `$(job.Re)`")
            println(io, "- seed source: `$(job.seed_source)` on `J$(job.seed_J)K$(job.seed_K)L$(job.seed_L)`")
            println(io, "- eval target: `J$(job.eval_J)K$(job.eval_K)L$(job.eval_L)`")
            println(io, "- local grid: `Lx ∈ [$(job.Lx_min), $(job.Lx_max)]` with `$(job.Lx_n)` points, `Lz ∈ [$(job.Lz_min), $(job.Lz_max)]` with `$(job.Lz_n)` points")
            println(io, "- seed asc: `$(job.seed_asc)`")
            println(io)
            println(io, "```bash")
            println(io, job.cmd_string)
            println(io, "```")
        end
    end

    open(joinpath(out_root, "README.md"), "w") do io
        println(io, "# Catalog Geometry Heatmaps")
        println(io)
        println(io, "Generated: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")
        println(io)
        println(io, "This directory contains per-solution heatmap jobs built from `eqb_catalog` representatives.")
        println(io)
        println(io, "- default mode: one representative group per `physical_id` (`--group-mode seed`)")
        println(io, "- alternate mode: one job per catalog group carrying the solution (`--group-mode all-catalog`)")
        println(io, "- manifest: `jobs.csv`")
        println(io, "- each job dir contains `run_command.txt` and `job_info.md`")
        println(io)
        println(io, "Recommended first check:")
        println(io)
        println(io, "```bash")
        println(io, "CLOUDATLAS_SKIP_ACTIVATE=true julia --startup-file=no --project=. notebooks/eqb_fuzzing/catalog_geometry_heatmaps.jl --dry-run --limit 5")
        println(io, "```")
        println(io)
        println(io, "Then run a selected command from `run_command.txt`.")
        if parse_bool(args, "run"; default = false)
            println(io)
            println(io, "This manifest was generated with `--run true`; some jobs may already have outputs under their group subdirectories.")
        end
    end
end

function main()
    args = parse_args(ARGS)
    base = @__DIR__
    on_root = abspath(get(args, "overnight-root", joinpath(base, "overnight_runs_updated")))
    ls_root = abspath(get(args, "low-shear-root", joinpath(base, "low_shear")))
    cat_dir = abspath(get(args, "catalog-dir", joinpath(base, "eqb_catalog")))
    out_root = abspath(get(args, "out-dir", joinpath(cat_dir, "geometry_heatmaps")))
    group_mode = get(args, "group-mode", "seed")
    dry_run = parse_bool(args, "dry-run"; default = false)

    _, phys_rows = read_csv(joinpath(cat_dir, "physical_solutions.csv"))
    _, catalog_rows = read_csv(joinpath(cat_dir, "catalog.csv"))

    phys_rows = maybe_filtered_rows(phys_rows, args)
    sort!(phys_rows; by = r -> r["physical_id"])

    catalog_by_pid = Dict{String, Vector{Dict{String, String}}}()
    for r in catalog_rows
        push!(get!(catalog_by_pid, r["physical_id"], Dict{String, String}[]), r)
    end

    jobs = NamedTuple[]
    skipped = String[]
    for row in phys_rows
        pid = row["physical_id"]
        group_rows = get(catalog_by_pid, pid, Dict{String, String}[])
        isempty(group_rows) && (push!(skipped, "$pid: missing catalog rows"); continue)
        best = find_best_asc(group_rows, on_root, ls_root)
        best === nothing && (push!(skipped, "$pid: no local asc found"); continue)
        for group in select_groups_for_pid(group_rows, best, group_mode)
            group_best = if group == best.group
                best
            else
                find_best_asc([r for r in group_rows if r["group"] == group], on_root, ls_root)
            end
            group_best === nothing && (push!(skipped, "$pid/$group: no local asc found"); continue)
            push!(jobs, build_job(row, group, group_best, args, out_root))
        end
    end

    mkpath(out_root)
    write_manifest(joinpath(out_root, "jobs.csv"), jobs)
    write_job_files(jobs, args, out_root)

    println("Prepared $(length(jobs)) geometry-heatmap jobs in $out_root")
    if !isempty(skipped)
        println("Skipped $(length(skipped)) entries")
        for msg in skipped[1:min(end, 10)]
            println("  [skip] $msg")
        end
    end

    show_n = min(length(jobs), parse(Int, get(args, "show", "8")))
    for job in jobs[1:show_n]
        println("  $(job.physical_id) [$(job.group)] -> $(job.out_dir)")
        println("    $(job.cmd_string)")
    end

    if dry_run
        return
    end

    if parse_bool(args, "run"; default = false)
        julia_bin = Base.julia_cmd()
        target_root = abspath(joinpath(base, "..", ".."))
        for (idx, job) in enumerate(jobs)
            println("")
            println("[run $(idx)/$(length(jobs))] $(job.physical_id) / $(job.group)")
            cmd = Cmd(vcat(collect(julia_bin.exec), job.cmd_parts[2:end]); dir = target_root)
            run(cmd)
        end
    end
end

main()

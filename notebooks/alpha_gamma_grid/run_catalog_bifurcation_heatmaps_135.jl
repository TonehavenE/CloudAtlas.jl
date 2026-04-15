import Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))

using Base.Threads
using Dates

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

function parse_bool(args, key; default::Bool = false)
    haskey(args, key) || return default
    v = lowercase(strip(args[key]))
    v in ("1", "true", "yes", "y", "on") && return true
    v in ("0", "false", "no", "n", "off") && return false
    error("Invalid bool for --$key: $(args[key])")
end

function parse_list_arg(args, key)
    haskey(args, key) || return String[]
    return [strip(s) for s in split(args[key], ',') if !isempty(strip(s))]
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

function safeparse_float(s; default = NaN)
    try
        return parse(Float64, strip(string(s)))
    catch
        return default
    end
end

function re_from_physical_id(pid::AbstractString)
    m = match(r"^re([0-9]+(?:p[0-9]+)?)_", pid)
    m === nothing && return NaN
    return parse(Float64, replace(m.captures[1], 'p' => '.'))
end

function csv_safe(s::AbstractString)
    return replace(replace(s, '\n' => ' '), ',' => ';')
end

function append_summary_row(path::String, row::AbstractVector{<:AbstractString}; io_lock::ReentrantLock)
    lock(io_lock) do
        newfile = !isfile(path)
        open(path, "a") do io
            if newfile
                println(io, "timestamp,physical_id,case,group,Re,status,error,job_dir,heatmap_png,min_re_csv")
            end
            println(io, join(string.(row), ","))
            flush(io)
        end
    end
end

function run_cmd(cmd::Cmd)
    out = IOBuffer()
    err = IOBuffer()
    proc = run(pipeline(ignorestatus(cmd), stdout = out, stderr = err))
    return (
        ok = success(proc),
        stdout = String(take!(out)),
        stderr = String(take!(err)),
    )
end

function completed_grid_jobs(out_root::String)
    jobs = NamedTuple[]
    for (root, _, files) in walkdir(out_root)
        basename(root) == "geometry_grid" || continue
        completed = filter(f -> startswith(f, "completed_grid_") && endswith(f, ".csv"), files)
        isempty(completed) && continue
        job_dir = dirname(root)
        group_dir = dirname(job_dir)
        group = basename(group_dir)
        physical_id = basename(job_dir)
        push!(
            jobs,
            (
                group = group,
                physical_id = physical_id,
                job_dir = job_dir,
                completed_csv = joinpath(root, first(sort(completed))),
            ),
        )
    end
    sort!(jobs; by = j -> (j.group, j.physical_id))
    return jobs
end

function main()
    args = parse_args(ARGS)
    base = @__DIR__

    catalog_dir = abspath(get(args, "catalog-dir", joinpath(base, "..", "eqb_fuzzing", "eqb_catalog")))
    out_root = abspath(get(args, "out-root", joinpath(catalog_dir, "ode_minre_heatmaps_J1K3L5")))

    groups_filter = Set(parse_list_arg(args, "groups"))
    pid_filter = Set(parse_list_arg(args, "physical-ids"))
    case_filter = Set(parse_list_arg(args, "cases"))
    limit = haskey(args, "limit") ? parse(Int, args["limit"]) : typemax(Int)

    target_j = parse(Int, get(args, "target-J", "1"))
    target_k = parse(Int, get(args, "target-K", "3"))
    target_l = parse(Int, get(args, "target-L", "5"))
    jobs_parallel = parse(Int, get(args, "jobs", string(max(1, Threads.nthreads()))))
    job_threads = parse(Int, get(args, "job-threads", "1"))
    resume = parse_bool(args, "resume"; default = true)
    skip_complete = parse_bool(args, "skip-complete"; default = false)
    dry_run = parse_bool(args, "dry-run"; default = false)

    catalog_path = joinpath(catalog_dir, "catalog.csv")
    _, rows = read_csv(catalog_path)
    metadata = Dict{Tuple{String, String}, NamedTuple}()
    for row in rows
        pid = get(row, "physical_id", "")
        group = get(row, "group", "")
        isempty(pid) && continue
        isempty(group) && continue
        metadata[(pid, group)] = (
            case = get(row, "case", ""),
            Re = safeparse_float(get(row, "Re", "NaN"); default = re_from_physical_id(pid)),
        )
    end

    jobs = NamedTuple[]
    for job in completed_grid_jobs(out_root)
        !isempty(groups_filter) && !(job.group in groups_filter) && continue
        !isempty(pid_filter) && !(job.physical_id in pid_filter) && continue

        meta = get(metadata, (job.physical_id, job.group), (case = "", Re = re_from_physical_id(job.physical_id)))
        !isempty(case_filter) && !(meta.case in case_filter) && continue

        heatmap_png = joinpath(job.job_dir, "heatmap_min_re.png")
        min_re_csv = joinpath(job.job_dir, "bifurcations", "min_re_$(job.group).csv")
        if skip_complete && isfile(heatmap_png) && isfile(min_re_csv)
            continue
        end

        push!(
            jobs,
            merge(job, (
                case = meta.case,
                Re = meta.Re,
                heatmap_png = heatmap_png,
                min_re_csv = min_re_csv,
            )),
        )
        length(jobs) >= limit && break
    end

    println("== Catalog bifurcation curves + min-Re heatmaps @ JKL=($(target_j),$(target_k),$(target_l)) ==")
    println("catalog_dir=$(catalog_dir)")
    println("out_root=$(out_root)")
    println("jobs=$(length(jobs)) jobs_parallel=$(jobs_parallel) job_threads=$(job_threads)")
    println("resume=$(resume) skip_complete=$(skip_complete) dry_run=$(dry_run)")

    summary_csv = joinpath(out_root, "catalog_bifurcation_heatmap_summary.csv")
    mkpath(out_root)
    if !resume
        open(summary_csv, "w") do io
            println(io, "timestamp,physical_id,case,group,Re,status,error,job_dir,heatmap_png,min_re_csv")
        end
    end

    if dry_run
        for job in jobs
            println("[dry] $(job.group)/$(job.physical_id) Re=$(job.Re) completed=$(job.completed_csv)")
        end
        println("summary=$(summary_csv)")
        return
    end

    sem = Base.Semaphore(max(1, jobs_parallel))
    summary_lock = ReentrantLock()
    @sync for job in jobs
        Threads.@spawn begin
            Base.acquire(sem)
            try
                cmd = addenv(
                    `$(Base.julia_cmd()) --project=$(joinpath(base, "..", "..")) $(joinpath(base, "postprocess_minre_continuation.jl")) --root $(out_root) --groups $(job.group) --group-subdir $(job.physical_id) --J $(target_j) --K $(target_k) --L $(target_l) --Re $(job.Re) --bif true --heatmaps true --data-subdir geometry_grid`,
                    "JULIA_NUM_THREADS" => string(job_threads),
                    "GKSwstype" => "100",
                )
                res = run_cmd(cmd)
                errtxt = res.ok ? "" : csv_safe(res.stderr)
                append_summary_row(
                    summary_csv,
                    [
                        Dates.format(now(), "yyyy-mm-ddTHH:MM:SS"),
                        job.physical_id,
                        job.case,
                        job.group,
                        string(job.Re),
                        res.ok ? "ok" : "fail",
                        errtxt,
                        job.job_dir,
                        job.heatmap_png,
                        job.min_re_csv,
                    ];
                    io_lock = summary_lock,
                )
                println("[done] $(job.group)/$(job.physical_id) status=$(res.ok ? "ok" : "fail")")
            finally
                Base.release(sem)
            end
        end
    end

    println("summary=$(summary_csv)")
end

main()

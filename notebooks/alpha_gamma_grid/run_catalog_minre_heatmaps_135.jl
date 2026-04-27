import Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))

using Dates
using Printf
using Base.Threads

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

function safeparse(::Type{Float64}, s)
    try
        return parse(Float64, strip(string(s)))
    catch
        return NaN
    end
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

function parse_member_entry(s)
    m = match(r"^(on|ls):sol(\d+)@J(\d+)K(\d+)L(\d+)$", strip(s))
    m === nothing && return nothing
    return (
        source = m.captures[1],
        sol_id = parse(Int, m.captures[2]),
        J = parse(Int, m.captures[3]),
        K = parse(Int, m.captures[4]),
        L = parse(Int, m.captures[5]),
    )
end

function find_best_asc(row, on_root::String, ls_root::String)
    best = nothing
    case = row["case"]
    group = row["group"]
    for entry_str in split(get(row, "all_members", ""), ';')
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
                sol_id = m.sol_id,
                J = m.J,
                K = m.K,
                L = m.L,
                jkl = jkl,
                asc_path = asc_path,
            )
        end
    end
    return best
end

function physical_id_seed_id(pid::AbstractString)
    m = match(r"_([0-9]+)$", pid)
    m === nothing && error("Could not parse numeric suffix from physical_id: $pid")
    return parse(Int, m.captures[1])
end

function csv_safe(s::AbstractString)
    return replace(replace(s, '\n' => ' '), ',' => ';')
end

function append_summary_row(path::String, row::AbstractVector{<:AbstractString}; io_lock::ReentrantLock)
    lock(io_lock) do
        newfile = !isfile(path)
        open(path, "a") do io
            if newfile
                println(
                    io,
                    "timestamp,physical_id,case,group,Re,Lx,Lz,seed_J,seed_K,seed_L,seed_source,status,error,job_dir,heatmap_png,min_re_csv",
                )
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

function main()
    args = parse_args(ARGS)
    base = @__DIR__

    catalog_dir = abspath(get(args, "catalog-dir", joinpath(base, "..", "eqb_fuzzing", "eqb_catalog")))
    overnight_root = abspath(get(args, "overnight-root", joinpath(base, "..", "eqb_fuzzing", "overnight_runs_updated")))
    low_shear_root = abspath(get(args, "low-shear-root", joinpath(base, "..", "eqb_fuzzing", "low_shear")))
    source_root = abspath(get(args, "source-root", joinpath(base, "eqb_alpha_gamma_grid")))
    out_root = abspath(get(args, "out-root", joinpath(catalog_dir, "ode_minre_heatmaps_J1K3L5")))

    groups_filter = Set(parse_list_arg(args, "groups"))
    pid_filter = Set(parse_list_arg(args, "physical-ids"))
    case_filter = Set(parse_list_arg(args, "cases"))
    limit = haskey(args, "limit") ? parse(Int, args["limit"]) : typemax(Int)

    target_j = parse(Int, get(args, "target-J", "1"))
    target_k = parse(Int, get(args, "target-K", "3"))
    target_l = parse(Int, get(args, "target-L", "5"))
    geom_parallel = parse(Int, get(args, "geom-parallel", "1"))
    jobs_parallel = parse(Int, get(args, "jobs", string(max(1, Threads.nthreads() ÷ max(geom_parallel, 1)))))
    job_threads = parse(Int, get(args, "job-threads", "1"))
    resume = parse_bool(args, "resume"; default = true)
    dry_run = parse_bool(args, "dry-run"; default = false)
    postprocess = parse_bool(args, "postprocess"; default = true)

    promote_trials = get(args, "promote-trials", "1000")
    promote_noise = get(args, "promote-noise", "0.01")
    geom_trials = get(args, "geom-trials", "1000")
    geom_noise = get(args, "geom-noise", "0.01")
    max_attempts = get(args, "max-attempts", "4")
    grid_mode = get(args, "grid", "summary")

    catalog_path = joinpath(catalog_dir, "catalog.csv")
    _, rows = read_csv(catalog_path)
    isempty(rows) && error("No rows found in $catalog_path")

    jobs = NamedTuple[]
    seen = Set{Tuple{String, String}}()
    for row in rows
        pid = row["physical_id"]
        group = row["group"]
        case = row["case"]

        row["is_trivial"] == "true" && continue
        !isempty(groups_filter) && !(group in groups_filter) && continue
        !isempty(pid_filter) && !(pid in pid_filter) && continue
        !isempty(case_filter) && !(case in case_filter) && continue
        key = (pid, group)
        key in seen && continue

        rep = find_best_asc(row, overnight_root, low_shear_root)
        rep === nothing && continue

        push!(seen, key)
        push!(jobs, (
            physical_id = pid,
            case = case,
            group = group,
            Re = safeparse(Float64, row["Re"]),
            Lx = safeparse(Float64, row["Lx"]),
            Lz = safeparse(Float64, row["Lz"]),
            seed_id = physical_id_seed_id(pid),
            rep = rep,
            job_dir = joinpath(out_root, group, pid),
        ))
        length(jobs) >= limit && break
    end

    println("== Catalog ODE min-Re heatmaps @ JKL=($(target_j),$(target_k),$(target_l)) ==")
    println("catalog_dir=$(catalog_dir)")
    println("source_root=$(source_root)")
    println("out_root=$(out_root)")
    println("jobs=$(length(jobs)) jobs_parallel=$(jobs_parallel) geom_parallel=$(geom_parallel) job_threads=$(job_threads)")
    println("resume=$(resume) dry_run=$(dry_run) postprocess=$(postprocess)")

    summary_csv = joinpath(out_root, "catalog_minre_heatmap_summary.csv")
    mkpath(out_root)
    if !resume
        open(summary_csv, "w") do io
            println(
                io,
                "timestamp,physical_id,case,group,Re,Lx,Lz,seed_J,seed_K,seed_L,seed_source,status,error,job_dir,heatmap_png,min_re_csv",
            )
        end
    end

    if dry_run
        for job in jobs
            println(
                "[dry] $(job.physical_id) group=$(job.group) case=$(job.case) seed=J$(job.rep.J)K$(job.rep.K)L$(job.rep.L) $(job.rep.asc_path)",
            )
        end
        return
    end

    sem = Base.Semaphore(max(1, jobs_parallel))
    summary_lock = ReentrantLock()
    @sync for job in jobs
        Threads.@spawn begin
            Base.acquire(sem)
            try
                mkpath(job.job_dir)

                promote_cmd = addenv(
                    `$(Base.julia_cmd()) --project=$(joinpath(base, "..", "..")) $(joinpath(base, "promote_continue_ode_grid.jl")) --group $(job.group) --source-root $(source_root) --out-root $(job.job_dir) --target-J $(target_j) --target-K $(target_k) --target-L $(target_l) --Re $(job.Re) --seed-path $(job.rep.asc_path) --seed-Lx $(job.Lx) --seed-Lz $(job.Lz) --seed-id $(job.seed_id) --seed-J $(job.rep.J) --seed-K $(job.rep.K) --seed-L $(job.rep.L) --seed-min-Re NaN --promote-trials $(promote_trials) --promote-noise $(promote_noise) --geom-trials $(geom_trials) --geom-noise $(geom_noise) --max-attempts $(max_attempts) --parallel $(geom_parallel) --grid $(grid_mode) --resume $(resume)`,
                    "JULIA_NUM_THREADS" => string(job_threads),
                )
                post_cmd = addenv(
                    `$(Base.julia_cmd()) --project=$(joinpath(base, "..", "..")) $(joinpath(base, "postprocess_minre_continuation.jl")) --root $(out_root) --groups $(job.group) --group-subdir $(job.physical_id) --J $(target_j) --K $(target_k) --L $(target_l) --Re $(job.Re) --bif true --heatmaps true --data-subdir geometry_grid`,
                    "JULIA_NUM_THREADS" => string(job_threads),
                    "GKSwstype" => "100",
                )

                promote_res = run_cmd(promote_cmd)
                post_res = (promote_res.ok && postprocess) ? run_cmd(post_cmd) : (ok = true, stdout = "", stderr = "")

                ok = promote_res.ok && post_res.ok
                errtxt = ok ? "" : join(
                    filter(!isempty, [
                        promote_res.ok ? "" : ("promote: " * csv_safe(promote_res.stderr)),
                        post_res.ok ? "" : ("post: " * csv_safe(post_res.stderr)),
                    ]),
                    " | ",
                )
                append_summary_row(
                    summary_csv,
                    [
                        Dates.format(now(), "yyyy-mm-ddTHH:MM:SS"),
                        job.physical_id,
                        job.case,
                        job.group,
                        string(job.Re),
                        string(job.Lx),
                        string(job.Lz),
                        string(job.rep.J),
                        string(job.rep.K),
                        string(job.rep.L),
                        job.rep.source,
                        ok ? "ok" : "fail",
                        errtxt,
                        job.job_dir,
                        joinpath(job.job_dir, "heatmap_min_re.png"),
                        joinpath(job.job_dir, "bifurcations", "min_re_$(job.group).csv"),
                    ];
                    io_lock = summary_lock,
                )

                status = ok ? "ok" : "fail"
                println("[done] $(job.physical_id) group=$(job.group) seed=J$(job.rep.J)K$(job.rep.K)L$(job.rep.L) status=$(status)")
            finally
                Base.release(sem)
            end
        end
    end

    println("summary=$(summary_csv)")
end

main()

if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "..", ".."))
end

using CloudAtlas
using ChannelflowWrapper
using CSV
using DataFrames
using DelimitedFiles
using Printf
using Dates
using Base.Threads

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

function parse_bool(args::Dict{String,String}, key::String; default::Bool=false)
    if !haskey(args, key)
        return default
    end
    v = lowercase(strip(args[key]))
    v in ("1", "true", "yes", "y", "on") && return true
    v in ("0", "false", "no", "n", "off") && return false
    error("Invalid bool for --$key: $(args[key])")
end

function parse_csv(path::AbstractString)
    isfile(path) || return String[], Vector{Dict{String,String}}()
    lines = readlines(path)
    isempty(lines) && return String[], Vector{Dict{String,String}}()
    header = split(chomp(lines[1]), ',')
    rows = Vector{Dict{String,String}}()
    for ln in lines[2:end]
        s = chomp(ln)
        isempty(strip(s)) && continue
        vals = split(s, ',')
        length(vals) < length(header) && append!(vals, fill("", length(header) - length(vals)))
        row = Dict{String,String}()
        for i in eachindex(header)
            row[header[i]] = i <= length(vals) ? vals[i] : ""
        end
        push!(rows, row)
    end
    return header, rows
end

safeparse(::Type{Float64}, s::AbstractString) = try parse(Float64, strip(s)) catch; NaN end
safeparse(::Type{Int}, s::AbstractString) = try parse(Int, strip(s)) catch; 0 end

function parse_case_list(s::AbstractString)
    t = strip(s)
    isempty(t) && return String[]
    [String(strip(x)) for x in split(t, ",") if !isempty(strip(x))]
end

function parse_group_list(s::AbstractString)
    g = parse_case_list(s)
    isempty(g) && return SYMM_ORDER
    for x in g
        x in SYMM_ORDER || error("Unknown group '$x'")
    end
    return g
end

function read_run_queue(runs_root::AbstractString)
    queue_path = joinpath(runs_root, "run_queue_summary.csv")
    _, rows = parse_csv(queue_path)
    out = Dict{String, NamedTuple}()
    for r in rows
        case = get(r, "case_label", "")
        isempty(case) && continue
        out[case] = (
            case_label=case,
            Re=safeparse(Float64, get(r, "Re", "NaN")),
            Lx=safeparse(Float64, get(r, "Lx", "NaN")),
            Lz=safeparse(Float64, get(r, "Lz", "NaN")),
            out_dir=get(r, "out_dir", joinpath(runs_root, case)),
        )
    end
    return out
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

function symm_lines(group::String)
    sxyz = "1 -1 -1 -1 0.0 0.0"
    sxy = "1 -1 -1 1 0.0 0.0"
    sz = "1 1 1 -1 0.0 0.0"
    txz = "1 1 1 1 0.5 0.5"
    sxytz = "1 -1 -1 1 0.0 0.5"
    sztx = "1 1 1 -1 0.5 0.0"
    sztxz = "1 1 1 -1 0.5 0.5"
    if group == "A"
        return [sxyz, txz]
    elseif group == "B"
        return [sxy, sz]
    elseif group == "C"
        return [sxytz, sz]
    elseif group == "D"
        return [sxy, sztx]
    elseif group == "E"
        return [sxyz, sztxz]
    elseif group == "F"
        return [sxy, sz, txz]
    elseif group == "G"
        return [sxyz]
    end
    error("Unknown group: $group")
end

function write_symm_file(path::AbstractString, lines::Vector{String})
    open(path, "w") do io
        println(io, "% $(length(lines))")
        for line in lines
            println(io, line)
        end
    end
end

function myreaddlm(filename; cc='#')
    X = readdlm(filename; comments=true, comment_char=cc)
    if ndims(X) == 1
        return vec(X)
    end
    if size(X, 2) == 1
        return vec(X[:, 1])
    end
    return vec(X)
end

function parse_jkl(dirname::AbstractString)
    m = match(r"^jkl_(\d+)_(\d+)_(\d+)$", dirname)
    m === nothing && return nothing
    return (safeparse(Int, m.captures[1]), safeparse(Int, m.captures[2]), safeparse(Int, m.captures[3]))
end

function parse_sol_id(fname::AbstractString)
    m = match(r"^sol(\d+)\.asc$", fname)
    m === nothing && return 0
    return safeparse(Int, m.captures[1])
end

function read_solution_summary(level_dir::AbstractString, sol_id::Int)
    path = joinpath(level_dir, "solutions_summary.csv")
    isfile(path) || return (found=false, norm=NaN, shear=NaN)
    _, rows = parse_csv(path)
    for row in rows
        safeparse(Int, get(row, "id", "0")) == sol_id || continue
        return (
            found=true,
            norm=safeparse(Float64, get(row, "norm", "NaN")),
            shear=safeparse(Float64, get(row, "shear", "NaN")),
        )
    end
    return (found=false, norm=NaN, shear=NaN)
end

function load_catalog_fingerprints(path::AbstractString; Re::Float64, Lx::Float64, Lz::Float64, parameter_tol::Float64=1e-8)
    isfile(path) || return NamedTuple[]
    df = CSV.read(path, DataFrame; stringtype=String)
    required = [:physical_id, :Re, :Lx, :Lz, :L2, :shear]
    all(c -> c in propertynames(df), required) || return NamedTuple[]
    out = NamedTuple[]
    for row in eachrow(df)
        rowRe = try Float64(row.Re) catch; NaN end
        rowLx = try Float64(row.Lx) catch; NaN end
        rowLz = try Float64(row.Lz) catch; NaN end
        if abs(rowRe - Re) <= parameter_tol && abs(rowLx - Lx) <= parameter_tol && abs(rowLz - Lz) <= parameter_tol
            l2 = try Float64(row.L2) catch; NaN end
            shear = try Float64(row.shear) catch; NaN end
            if isfinite(l2) && isfinite(shear)
                push!(out, (physical_id=String(row.physical_id), L2=l2, shear=shear))
            end
        end
    end
    return out
end

function is_catalog_known(summary, known; l2_tol::Float64, shear_tol::Float64)
    summary.found || return (known=false, physical_id="", l2_gap=NaN, shear_gap=NaN)
    best = (physical_id="", l2_gap=Inf, shear_gap=Inf)
    for row in known
        l2_gap = abs(summary.norm - row.L2)
        shear_gap = abs(summary.shear - row.shear)
        if l2_gap <= l2_tol && shear_gap <= shear_tol && l2_gap + shear_gap < best.l2_gap + best.shear_gap
            best = (physical_id=row.physical_id, l2_gap=l2_gap, shear_gap=shear_gap)
        end
    end
    return (
        known = !isempty(best.physical_id),
        physical_id = best.physical_id,
        l2_gap = best.l2_gap,
        shear_gap = best.shear_gap,
    )
end

function read_last_residual(convergence_path::AbstractString)
    isfile(convergence_path) || return Inf
    try
        X = readdlm(convergence_path; comments=true, comment_char='%')
        if isempty(X)
            return Inf
        elseif ndims(X) == 1
            return float(X[1])
        else
            return float(X[end, 1])
        end
    catch
        return Inf
    end
end

function is_converged_job(job_dir::AbstractString; tol::Float64=1e-10)
    convergence = joinpath(job_dir, "convergence.asc")
    ubest = joinpath(job_dir, "ubest.nc")
    res = read_last_residual(convergence)
    return isfinite(res) && res <= tol && isfile(ubest)
end

function ensure_reference_field!(cache::Dict{Tuple{Float64,Float64},String}, lk::ReentrantLock, refs_dir::String, reference_base::String, alpha::Float64, gamma::Float64)
    key = (alpha, gamma)
    if haskey(cache, key)
        return cache[key]
    end
    Base.lock(lk) do
        if haskey(cache, key)
            return cache[key]
        end
        mkpath(refs_dir)
        out = joinpath(refs_dir, @sprintf("reference_alpha%.10f_gamma%.10f.nc", alpha, gamma))
        if !isfile(out)
            changegrid(reference_base, out; al=alpha, ga=gamma)
        end
        cache[key] = out
        return out
    end
end

function ensure_symm_file!(cache::Dict{String,String}, lk::ReentrantLock, refs_dir::String, group::AbstractString)
    group_s = String(group)
    if haskey(cache, group_s)
        return cache[group_s]
    end
    Base.lock(lk) do
        if haskey(cache, group_s)
            return cache[group_s]
        end
        mkpath(refs_dir)
        out = joinpath(refs_dir, "symm_$(group_s).asc")
        if !isfile(out)
            write_symm_file(out, symm_lines(group_s))
        end
        cache[group_s] = out
        return out
    end
end

function gather_jobs(
    runs_root::String,
    queue_meta,
    cases,
    groups;
    resume::Bool=true,
    conv_tol::Float64=1e-10,
    stop_on_first::Bool=true,
    skip_catalog_known::Bool=false,
    catalog_manifest::String="",
    catalog_l2_tol::Float64=2e-3,
    catalog_shear_tol::Float64=5e-3,
)
    symm_map = symmetry_groups()
    jobs = NamedTuple[]
    solved_keys = Set{Tuple{String,String,Int}}()
    skipped_known = NamedTuple[]
    for case in cases
        meta = get(
            queue_meta,
            case,
            (case_label=case, Re=NaN, Lx=NaN, Lz=NaN, out_dir=joinpath(runs_root, case)),
        )
        case_dir = abspath(meta.out_dir)
        isdir(case_dir) || continue
        alpha = 2pi / meta.Lx
        gamma = 2pi / meta.Lz
        refs_dir = joinpath(case_dir, "channelflow_refs")
        known = if skip_catalog_known && !isempty(catalog_manifest)
            load_catalog_fingerprints(catalog_manifest; Re=meta.Re, Lx=meta.Lx, Lz=meta.Lz)
        else
            NamedTuple[]
        end
        for g in groups
            H = get(symm_map, g, nothing)
            H === nothing && continue
            group_dir = joinpath(case_dir, g)
            isdir(group_dir) || continue
            for d in readdir(group_dir)
                jkl = parse_jkl(d)
                jkl === nothing && continue
                J, K, L = jkl
                level_dir = joinpath(group_dir, d)
                dns_root = joinpath(level_dir, "dns_findsoln")
                for f in readdir(level_dir)
                    endswith(f, ".asc") || continue
                    startswith(f, "sol") || continue
                    sid = parse_sol_id(f)
                    sid == 0 && continue
                    traj_key = (case, String(g), sid)
                    sol_path = joinpath(level_dir, f)
                    job_dir = joinpath(dns_root, @sprintf("sol%03d", sid))
                    if resume && is_converged_job(job_dir; tol=conv_tol)
                        if stop_on_first
                            push!(solved_keys, traj_key)
                        end
                        continue
                    end
                    if skip_catalog_known && !isempty(known)
                        summary = read_solution_summary(level_dir, sid)
                        match = is_catalog_known(summary, known; l2_tol=catalog_l2_tol, shear_tol=catalog_shear_tol)
                        if match.known
                            push!(skipped_known, (
                                case_label=case,
                                group=g,
                                J=J,
                                K=K,
                                L=L,
                                sol_id=sid,
                                matched_physical_id=match.physical_id,
                                l2_gap=match.l2_gap,
                                shear_gap=match.shear_gap,
                                job_dir=job_dir,
                            ))
                            if stop_on_first
                                push!(solved_keys, traj_key)
                            end
                            continue
                        end
                    end
                    push!(jobs, (
                        case_label=case,
                        case_dir=case_dir,
                        refs_dir=refs_dir,
                        group=g,
                        H=H,
                        J=J,
                        K=K,
                        L=L,
                        alpha=alpha,
                        gamma=gamma,
                        Re=meta.Re,
                        sol_id=sid,
                        sol_path=sol_path,
                        job_dir=job_dir,
                        traj_key=traj_key,
                    ))
                end
            end
        end
    end
    if stop_on_first && !isempty(solved_keys)
        jobs = [j for j in jobs if !(j.traj_key in solved_keys)]
    end
    sort!(jobs; by=j -> (j.case_label, String(j.group), j.sol_id, -j.J, -j.K, -j.L))
    return jobs, solved_keys, skipped_known
end

function main()
    args = parse_args(ARGS)
    runs_root = get(args, "runs-root", joinpath(@__DIR__, "overnight_runs_updated"))
    queue_meta = read_run_queue(runs_root)
    all_cases = sort(collect(keys(queue_meta)))
    if isempty(all_cases)
        all_cases = sort(filter(x -> isdir(joinpath(runs_root, x)), readdir(runs_root)))
    end
    req_cases = parse_case_list(get(args, "cases", ""))
    cases = isempty(req_cases) ? all_cases : filter(x -> x in req_cases, all_cases)
    isempty(cases) && error("No matching cases under $runs_root")

    groups = parse_group_list(get(args, "groups", join(SYMM_ORDER, ",")))
    resume = parse_bool(args, "resume"; default=true)
    dry_run = parse_bool(args, "dry-run"; default=false)
    stop_on_first = parse_bool(args, "stop-on-first"; default=true)
    skip_catalog_known = parse_bool(args, "skip-catalog-known"; default=false)
    conv_tol = parse(Float64, get(args, "conv-tol", "1e-10"))
    parallel = parse(Int, get(args, "parallel", string(Threads.nthreads())))
    workers = max(1, min(parallel, Threads.nthreads()))
    Tfind = parse(Float64, get(args, "T", "10.0"))
    catalog_manifest = get(args, "catalog-manifest", joinpath(@__DIR__, "..", "..", "catalog", "catalog_manifest.csv"))
    catalog_l2_tol = parse(Float64, get(args, "catalog-l2-tol", "2e-3"))
    catalog_shear_tol = parse(Float64, get(args, "catalog-shear-tol", "5e-3"))
    reference_base = get(
        args,
        "reference",
        joinpath(@__DIR__, "..", "tw_discovery", "TW1-2pi1piRe200-40x49x40.nc"),
    )
    isfile(reference_base) || error("Reference field not found: $reference_base")

    jobs, pre_solved_keys, skipped_known = gather_jobs(
        runs_root,
        queue_meta,
        cases,
        groups;
        resume=resume,
        conv_tol=conv_tol,
        stop_on_first=stop_on_first,
        skip_catalog_known=skip_catalog_known,
        catalog_manifest=catalog_manifest,
        catalog_l2_tol=catalog_l2_tol,
        catalog_shear_tol=catalog_shear_tol,
    )
    buckets = Dict{Tuple{String,String,Int}, Vector{NamedTuple}}()
    for j in jobs
        push!(get!(buckets, j.traj_key, NamedTuple[]), j)
    end
    bucket_keys = collect(keys(buckets))
    sort!(bucket_keys; by=k -> (k[1], k[2], k[3]))
    for k in bucket_keys
        sort!(buckets[k]; by=j -> (-j.J, -j.K, -j.L))
    end

    println("== EQB Discovery -> findsoln ==")
    println("runs_root=$(runs_root)")
    println("cases=$(join(cases, ","))")
    println("groups=$(join(groups, ","))")
    println("jobs=$(length(jobs)) trajectories=$(length(bucket_keys)) pre_solved_trajectories=$(length(pre_solved_keys)) skipped_catalog_known=$(length(skipped_known)) resume=$(resume) dry_run=$(dry_run) workers=$(workers)")
    println("stop_on_first=$(stop_on_first) conv_tol=$(conv_tol)")
    println("skip_catalog_known=$(skip_catalog_known) catalog_manifest=$(catalog_manifest) catalog_l2_tol=$(catalog_l2_tol) catalog_shear_tol=$(catalog_shear_tol)")
    println("reference=$(reference_base)")

    summary_path = joinpath(runs_root, "findsoln_jobs_summary.csv")
    if !resume || !isfile(summary_path)
        open(summary_path, "w") do io
            println(io, "timestamp,case,group,J,K,L,sol_id,status,error,job_dir")
        end
    elseif filesize(summary_path) == 0
        open(summary_path, "a") do io
            println(io, "timestamp,case,group,J,K,L,sol_id,status,error,job_dir")
        end
    end

    if !isempty(skipped_known)
        skipped_path = joinpath(runs_root, "findsoln_catalog_known_skips.csv")
        new_file = !isfile(skipped_path) || filesize(skipped_path) == 0
        open(skipped_path, "a") do io
            if new_file
                println(io, "timestamp,case,group,J,K,L,sol_id,matched_physical_id,l2_gap,shear_gap,job_dir")
            end
            for row in skipped_known
                println(
                    io,
                    "$(Dates.format(now(), "yyyy-mm-ddTHH:MM:SS")),$(row.case_label),$(row.group),$(row.J),$(row.K),$(row.L),$(row.sol_id),$(row.matched_physical_id),$(row.l2_gap),$(row.shear_gap),$(row.job_dir)",
                )
            end
        end
        open(summary_path, "a") do io
            for row in skipped_known
                println(
                    io,
                    "$(Dates.format(now(), "yyyy-mm-ddTHH:MM:SS")),$(row.case_label),$(row.group),$(row.J),$(row.K),$(row.L),$(row.sol_id),skip_catalog_known:$(row.matched_physical_id),,$(row.job_dir)",
                )
            end
        end
        println("catalog_known_skips=$(skipped_path)")
    end

    if dry_run
        for j in jobs
            open(summary_path, "a") do io
                println(io, "$(Dates.format(now(), "yyyy-mm-ddTHH:MM:SS")),$(j.case_label),$(j.group),$(j.J),$(j.K),$(j.L),$(j.sol_id),dry,,$(j.job_dir)")
            end
        end
        println("[dry-run] wrote $summary_path")
        return
    end

    ref_cache = Dict{Tuple{Float64,Float64},String}()
    symm_cache = Dict{String,String}()
    cache_lock = ReentrantLock()
    io_lock = ReentrantLock()
    attempted = Threads.Atomic{Int}(0)
    done_buckets = Threads.Atomic{Int}(0)
    ok_count = Threads.Atomic{Int}(0)
    fail_count = Threads.Atomic{Int}(0)
    nconv_count = Threads.Atomic{Int}(0)
    skip_count = Threads.Atomic{Int}(0)

    keych = Channel{Tuple{String,String,Int}}(length(bucket_keys))
    for key in bucket_keys
        put!(keych, key)
    end
    close(keych)

    @sync for _ in 1:workers
        Threads.@spawn begin
            for key in keych
                bucket_jobs = buckets[key]
                bucket_solved = false
                for (n, j) in enumerate(bucket_jobs)
                    if resume && is_converged_job(j.job_dir; tol=conv_tol)
                        bucket_solved = true
                        Threads.atomic_add!(ok_count, 1)
                        lock(io_lock) do
                            open(summary_path, "a") do io
                                println(
                                    io,
                                    "$(Dates.format(now(), "yyyy-mm-ddTHH:MM:SS")),$(j.case_label),$(j.group),$(j.J),$(j.K),$(j.L),$(j.sol_id),already_converged_higher_or_existing,,$(j.job_dir)",
                                )
                            end
                        end
                        if stop_on_first
                            if n < length(bucket_jobs)
                                for jskip in bucket_jobs[(n + 1):end]
                                    Threads.atomic_add!(skip_count, 1)
                                    lock(io_lock) do
                                        open(summary_path, "a") do io
                                            println(
                                                io,
                                                "$(Dates.format(now(), "yyyy-mm-ddTHH:MM:SS")),$(jskip.case_label),$(jskip.group),$(jskip.J),$(jskip.K),$(jskip.L),$(jskip.sol_id),skip_after_converged,,$(jskip.job_dir)",
                                            )
                                        end
                                    end
                                end
                            end
                            break
                        end
                    end
                    status = "ok"
                    err = ""
                    try
                        mkpath(j.job_dir)
                        model = ODEModel(j.alpha, j.gamma, j.J, j.K, j.L, j.H; normalize=false, tw=false)
                        x = myreaddlm(j.sol_path)
                        if length(x) != size(model.ijkl, 1)
                            error("Vector length $(length(x)) != model size $(size(model.ijkl,1))")
                        end

                        ref_field = ensure_reference_field!(ref_cache, cache_lock, j.refs_dir, reference_base, j.alpha, j.gamma)
                        symm_file = ensure_symm_file!(symm_cache, cache_lock, j.refs_dir, j.group)
                        guess_path = joinpath(j.job_dir, "u_guess.nc")
                        coeff2field(x, model.ijkl, ref_field, guess_path; workdir=j.job_dir)
                        findsoln(
                            guess_path;
                            workdir=j.job_dir,
                            R=j.Re,
                            eqb=true,
                            symms=abspath(symm_file),
                            od=j.job_dir,
                            T=Tfind,
                        )
                        if is_converged_job(j.job_dir; tol=conv_tol)
                            bucket_solved = true
                        else
                            status = "not_converged"
                        end
                    catch e
                        status = "fail"
                        err = replace(sprint(showerror, e), ',' => ';', '\n' => ' ')
                    end
                    Threads.atomic_add!(attempted, 1)
                    if status == "fail"
                        Threads.atomic_add!(fail_count, 1)
                    elseif status == "not_converged"
                        Threads.atomic_add!(nconv_count, 1)
                    else
                        Threads.atomic_add!(ok_count, 1)
                    end
                    lock(io_lock) do
                        open(summary_path, "a") do io
                            println(
                                io,
                                "$(Dates.format(now(), "yyyy-mm-ddTHH:MM:SS")),$(j.case_label),$(j.group),$(j.J),$(j.K),$(j.L),$(j.sol_id),$(status),$(err),$(j.job_dir)",
                            )
                        end
                    end
                    if bucket_solved && stop_on_first
                        if n < length(bucket_jobs)
                            for jskip in bucket_jobs[(n + 1):end]
                                Threads.atomic_add!(skip_count, 1)
                                lock(io_lock) do
                                    open(summary_path, "a") do io
                                        println(
                                            io,
                                            "$(Dates.format(now(), "yyyy-mm-ddTHH:MM:SS")),$(jskip.case_label),$(jskip.group),$(jskip.J),$(jskip.K),$(jskip.L),$(jskip.sol_id),skip_after_converged,,$(jskip.job_dir)",
                                        )
                                    end
                                end
                            end
                        end
                        break
                    end
                end
                done = Threads.atomic_add!(done_buckets, 1) + 1
                if done % max(1, length(bucket_keys) ÷ 100) == 0 || done == length(bucket_keys)
                    println("trajectory progress $(done)/$(length(bucket_keys)) attempted=$(attempted[])")
                end
            end
        end
    end

    println("[done] attempted=$(attempted[]) ok=$(ok_count[]) not_converged=$(nconv_count[]) fail=$(fail_count[]) skipped_after_converged=$(skip_count[])")
    println("summary=$summary_path")
end

main()

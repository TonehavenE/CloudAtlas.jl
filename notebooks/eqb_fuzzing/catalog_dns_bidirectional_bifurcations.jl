#!/usr/bin/env julia

# Run DNS continuation curves for catalog equilibria using Channelflow
# `continuesoln`, with one decreasing-Re run and one increasing-Re run per seed.
#
# Typical use:
#
#   julia --startup-file=no --project=/path/to/CloudAtlas.jl \
#     /path/to/jfm_followup/scripts/catalog_dns_bidirectional_bifurcations.jl \
#     --cloudatlas-root /path/to/CloudAtlas.jl \
#     --catalog-dir /path/to/CloudAtlas.jl/notebooks/eqb_fuzzing/eqb_catalog \
#     --run true
#
# The script intentionally treats DNS as the source of truth. It only uses the
# catalog to select DNS-verified seed fields and symmetry files.

using Pkg

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

const ARGS_DICT = parse_args(ARGS)
const CLOUDATLAS_ROOT = abspath(get(ARGS_DICT, "cloudatlas-root", get(ENV, "CLOUDATLAS_ROOT", pwd())))

if lowercase(get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false")) ∉ ("1", "true", "yes", "on")
    Pkg.activate(CLOUDATLAS_ROOT)
end

using CloudAtlas
using ChannelflowWrapper
using Dates
using Printf
using Base.Threads

safeparse(::Type{Float64}, s; default=NaN) = try parse(Float64, strip(string(s))) catch; default end
safeparse(::Type{Int}, s; default=0) = try parse(Int, strip(string(s))) catch; default end

function parse_bool(args, key; default=false)
    haskey(args, key) || return default
    v = lowercase(strip(args[key]))
    v in ("1", "true", "yes", "y", "on") && return true
    v in ("0", "false", "no", "n", "off") && return false
    error("Invalid bool for --$key: $(args[key])")
end

function parse_list(s)
    t = strip(string(s))
    isempty(t) && return String[]
    return [strip(x) for x in split(t, ",") if !isempty(strip(x))]
end

function csv_escape(x)
    s = string(x)
    if occursin(',', s) || occursin('"', s) || occursin('\n', s)
        return "\"" * replace(s, "\"" => "\"\"") * "\""
    end
    return s
end

function append_csv_row(path, values)
    open(path, "a") do io
        println(io, join(csv_escape.(values), ","))
    end
end

function read_csv(path::AbstractString)
    isfile(path) || return String[], Dict{String,String}[]
    lines = readlines(path)
    isempty(lines) && return String[], Dict{String,String}[]
    header = split(chomp(lines[1]), ',')
    rows = Dict{String,String}[]
    for ln in lines[2:end]
        s = chomp(ln)
        isempty(strip(s)) && continue
        vals = String[]
        in_quote = false
        buf = IOBuffer()
        i = firstindex(s)
        while i <= lastindex(s)
            ch = s[i]
            if ch == '"'
                if in_quote && i < lastindex(s) && s[nextind(s, i)] == '"'
                    write(buf, ch)
                    i = nextind(s, i)
                else
                    in_quote = !in_quote
                end
            elseif ch == ',' && !in_quote
                push!(vals, String(take!(buf)))
            else
                write(buf, ch)
            end
            i = nextind(s, i)
        end
        push!(vals, String(take!(buf)))
        row = Dict{String,String}()
        for i in eachindex(header)
            row[header[i]] = i <= length(vals) ? vals[i] : ""
        end
        push!(rows, row)
    end
    return header, rows
end

function symm_lines(group::String)
    sxyz  = "1 -1 -1 -1 0.0 0.0"
    sxy   = "1 -1 -1 1 0.0 0.0"
    sz    = "1 1 1 -1 0.0 0.0"
    txz   = "1 1 1 1 0.5 0.5"
    sxytz = "1 -1 -1 1 0.0 0.5"
    sztx  = "1 1 1 -1 0.5 0.0"
    sztxz = "1 1 1 -1 0.5 0.5"

    if group == "A"; return [sxyz, txz]
    elseif group == "B"; return [sxy, sz]
    elseif group == "C"; return [sxytz, sz]
    elseif group == "D"; return [sxy, sztx]
    elseif group == "E"; return [sxyz, sztxz]
    elseif group == "F"; return [sxy, sz, txz]
    elseif group == "G"; return [sxyz]
    end
    error("Unknown symmetry group: $group")
end

function ensure_symm_file(group::String, symm_dir::String)
    mkpath(symm_dir)
    path = joinpath(symm_dir, "symm_$(group).asc")
    if !isfile(path)
        lines = symm_lines(group)
        open(path, "w") do io
            println(io, "% $(length(lines))")
            for line in lines
                println(io, line)
            end
        end
    end
    return abspath(path)
end

function parse_member_entry(s)
    m = match(r"^(on|ls):sol(\d+)@J(\d+)K(\d+)L(\d+)$", strip(s))
    m === nothing && return nothing
    return (
        source = String(m.captures[1]),
        sol_id = safeparse(Int, m.captures[2]),
        J = safeparse(Int, m.captures[3]),
        K = safeparse(Int, m.captures[4]),
        L = safeparse(Int, m.captures[5]),
    )
end

function source_root(source::String, overnight_root::String, low_shear_root::String)
    source == "on" && return overnight_root
    source == "ls" && return low_shear_root
    error("Unknown catalog source: $source")
end

function member_dns_path(m, case::String, group::String, overnight_root::String, low_shear_root::String)
    root = source_root(m.source, overnight_root, low_shear_root)
    return joinpath(root, case, group, "jkl_$(m.J)_$(m.K)_$(m.L)", "dns_findsoln", "sol$(m.sol_id)", "ubest.nc")
end

function candidate_seed_paths(pid, group, m, case, catalog_dir, overnight_root, low_shear_root)
    local_dir = joinpath(catalog_dir, "solutions", pid)
    return [
        joinpath(local_dir, "$(group)_J$(m.J)K$(m.K)L$(m.L)_ubest.nc"),
        member_dns_path(m, case, group, overnight_root, low_shear_root),
    ]
end

function find_seed_for_physical_id(pid, group_rows, catalog_dir, overnight_root, low_shear_root)
    candidates = NamedTuple[]
    for row in group_rows
        case = row["case"]
        group = row["group"]
        for entry in split(get(row, "all_members", ""), ';')
            m = parse_member_entry(entry)
            m === nothing && continue
            seed_path = nothing
            for path in candidate_seed_paths(pid, group, m, case, catalog_dir, overnight_root, low_shear_root)
                if isfile(path)
                    seed_path = abspath(path)
                    break
                end
            end
            seed_path === nothing && continue
            push!(
                candidates,
                (
                    group = group,
                    source = m.source,
                    J = m.J,
                    K = m.K,
                    L = m.L,
                    sol_id = m.sol_id,
                    jkl = (m.J, m.K, m.L),
                    seed = seed_path,
                ),
            )
        end
    end
    isempty(candidates) && return nothing
    sort!(
        candidates;
        by = c -> (c.jkl, c.source == "on" ? 1 : 0, c.group),
        rev = true,
    )
    return candidates[1]
end

function read_mud_points(path::String)
    rows = NamedTuple[]
    isfile(path) || return rows
    first = true
    for line in eachline(path)
        s = strip(line)
        isempty(s) && continue
        if first
            first = false
            continue
        end
        parts = split(s)
        length(parts) >= 2 || continue
        Re = tryparse(Float64, parts[1])
        input = tryparse(Float64, parts[2])
        Re === nothing && continue
        input === nothing && continue
        push!(rows, (Re = Re, input = input))
    end
    return rows
end

function summarize_re_range(out_dir::String)
    points = read_mud_points(joinpath(out_dir, "MuD.asc"))
    isempty(points) && return (n = 0, min_Re = NaN, max_Re = NaN, min_input = NaN, max_input = NaN)
    return (
        n = length(points),
        min_Re = minimum(p.Re for p in points),
        max_Re = maximum(p.Re for p in points),
        min_input = minimum(p.input for p in points),
        max_input = maximum(p.input for p in points),
    )
end

function cont_has_output(out_dir::String)
    isdir(out_dir) || return false
    isfile(joinpath(out_dir, "processinfo")) || return false
    isfile(joinpath(out_dir, "MuD.asc")) && length(read_mud_points(joinpath(out_dir, "MuD.asc"))) > 0 && return true
    for name in readdir(out_dir)
        (startswith(name, "initial-") || startswith(name, "search-")) || continue
        isfile(joinpath(out_dir, name, "ubest.nc")) && return true
    end
    return false
end

function write_combined_curve(path::String, pid::String, case::String, group::String, minus_dir::String, plus_dir::String)
    open(path, "w") do io
        println(io, "physical_id,case,group,direction,step,Re,input")
        for (direction, out_dir) in (("minus", minus_dir), ("plus", plus_dir))
            points = read_mud_points(joinpath(out_dir, "MuD.asc"))
            for (i, p) in enumerate(points)
                println(io, join(csv_escape.((pid, case, group, direction, i, p.Re, p.input)), ","))
            end
        end
    end
end

function add_optional_kwargs!(kwargs::Dict{Symbol,Any}, args)
    np0 = safeparse(Int, get(args, "np0", "0"))
    np1 = safeparse(Int, get(args, "np1", "0"))
    symmpi = safeparse(Int, get(args, "symmpi", "0"))
    np0 > 0 && (kwargs[:np0] = np0)
    np1 > 0 && (kwargs[:np1] = np1)
    symmpi > 0 && (kwargs[:symmpi] = symmpi)
end

function direct_command(seed, out_dir, symm_path, Re, T, dmu, ns, target; np0=0, np1=0, symmpi=0, executable="continuesoln", mpi_prefix="")
    flags = String[
        "-cont Re", "-eqb", "-R $(Re)", "-T $(T)", "-symms $(symm_path)",
        "-od $(out_dir)", "-dmu $(dmu)", "-ns $(ns)", "-targ", "-targMu $(target)",
    ]
    np0 > 0 && push!(flags, "-np0 $(np0)")
    np1 > 0 && push!(flags, "-np1 $(np1)")
    symmpi > 0 && push!(flags, "-symmpi $(symmpi)")
    prefix = isempty(strip(mpi_prefix)) ? "" : strip(mpi_prefix) * " "
    return prefix * executable * " " * join(flags, " ") * " " * seed
end

function write_run_scripts(path, jobs; executable, mpi_prefix, np0, np1, symmpi, shell_parallel)
    out_dir = dirname(path)
    commands_path = joinpath(out_dir, "run_continuesoln_commands.txt")
    parallel_path = joinpath(out_dir, "run_continuesoln_parallel.sh")

    commands = String[]
    mkdirs = String[]
    for j in jobs
        push!(mkdirs, "mkdir -p $(j.minus_dir) $(j.plus_dir)")
        push!(commands, direct_command(j.seed, j.minus_dir, j.symm_path, j.Re, j.T, -abs(j.dmu), j.ns, j.Re_min; np0=np0, np1=np1, symmpi=symmpi, executable=executable, mpi_prefix=mpi_prefix))
        push!(commands, direct_command(j.seed, j.plus_dir, j.symm_path, j.Re, j.T, abs(j.dmu), j.ns, j.Re_max; np0=np0, np1=np1, symmpi=symmpi, executable=executable, mpi_prefix=mpi_prefix))
    end

    open(path, "w") do io
        println(io, "#!/usr/bin/env bash")
        println(io, "set -euo pipefail")
        for mk in mkdirs
            println(io, mk)
        end
        for cmd in commands
            println(io, cmd)
        end
    end
    chmod(path, 0o755)

    open(commands_path, "w") do io
        for cmd in commands
            println(io, cmd)
        end
    end

    open(parallel_path, "w") do io
        println(io, "#!/usr/bin/env bash")
        println(io, "set -euo pipefail")
        for mk in mkdirs
            println(io, mk)
        end
        println(io, "xargs -P $(shell_parallel) -I{} bash -lc '{}' < $(commands_path)")
    end
    chmod(parallel_path, 0o755)
    return (sequential = path, commands = commands_path, parallel = parallel_path)
end

function build_jobs(args)
    catalog_dir = abspath(get(args, "catalog-dir", joinpath(CLOUDATLAS_ROOT, "notebooks", "eqb_fuzzing", "eqb_catalog")))
    eqb_root = dirname(catalog_dir)
    overnight_root = abspath(get(args, "overnight-root", joinpath(eqb_root, "overnight_runs_updated")))
    low_shear_root = abspath(get(args, "low-shear-root", joinpath(eqb_root, "low_shear")))
    out_dir = abspath(get(args, "out-dir", joinpath(catalog_dir, "dns_bidirectional_bifurcations")))
    symm_dir = joinpath(out_dir, "symm_files")

    _, phys_rows = read_csv(joinpath(catalog_dir, "physical_solutions.csv"))
    _, catalog_rows = read_csv(joinpath(catalog_dir, "catalog.csv"))
    catalog_by_pid = Dict{String, Vector{Dict{String,String}}}()
    for r in catalog_rows
        push!(get!(catalog_by_pid, r["physical_id"], Dict{String,String}[]), r)
    end

    selected_cases = Set(parse_list(get(args, "case", "")))
    selected_pids = Set(parse_list(get(args, "physical-id", "")))
    selected_groups = Set(parse_list(get(args, "group", "")))
    limit = safeparse(Int, get(args, "limit", "0"))
    Re_min = safeparse(Float64, get(args, "Re-min", "100.0"))
    Re_max = safeparse(Float64, get(args, "Re-max", "500.0"))
    T = safeparse(Float64, get(args, "T", "10.0"))
    dmu = abs(safeparse(Float64, get(args, "dmu", "0.02")))
    ns = safeparse(Int, get(args, "ns", "50"))

    jobs = NamedTuple[]
    skipped = Dict("trivial" => 0, "filtered" => 0, "no_seed" => 0)
    for pr in phys_rows
        pid = pr["physical_id"]
        if get(pr, "is_trivial", "false") == "true"
            skipped["trivial"] += 1
            continue
        end
        if !isempty(selected_cases) && !(pr["case"] in selected_cases)
            skipped["filtered"] += 1
            continue
        end
        if !isempty(selected_pids) && !(pid in selected_pids)
            skipped["filtered"] += 1
            continue
        end
        group_rows = get(catalog_by_pid, pid, Dict{String,String}[])
        if !isempty(selected_groups)
            group_rows = [r for r in group_rows if r["group"] in selected_groups]
        end
        seed = find_seed_for_physical_id(pid, group_rows, catalog_dir, overnight_root, low_shear_root)
        if seed === nothing
            skipped["no_seed"] += 1
            continue
        end
        job_dir = joinpath(out_dir, pid)
        minus_dir = joinpath(job_dir, "minus")
        plus_dir = joinpath(job_dir, "plus")
        symm_path = ensure_symm_file(seed.group, symm_dir)
        push!(jobs, (
            physical_id = pid,
            case = pr["case"],
            Re = safeparse(Float64, pr["Re"]),
            Re_min = Re_min,
            Re_max = Re_max,
            T = T,
            dmu = dmu,
            ns = ns,
            group = seed.group,
            source = seed.source,
            J = seed.J,
            K = seed.K,
            L = seed.L,
            sol_id = seed.sol_id,
            seed = seed.seed,
            symm_path = symm_path,
            job_dir = job_dir,
            minus_dir = minus_dir,
            plus_dir = plus_dir,
            combined_csv = joinpath(job_dir, "combined_curve.csv"),
        ))
        if limit > 0 && length(jobs) >= limit
            break
        end
    end
    return catalog_dir, out_dir, jobs, skipped
end

function run_one_direction(job, direction::String, args)
    out = direction == "minus" ? job.minus_dir : job.plus_dir
    dmu = direction == "minus" ? -job.dmu : job.dmu
    target = direction == "minus" ? job.Re_min : job.Re_max
    mkpath(out)
    kwargs = Dict{Symbol,Any}(
        :cont => "Re",
        :eqb => true,
        :R => job.Re,
        :T => job.T,
        :symms => job.symm_path,
        :od => out,
        :dmu => dmu,
        :ns => job.ns,
        :targ => true,
        :targMu => target,
    )
    add_optional_kwargs!(kwargs, args)
    continuesoln(job.seed; workdir=out, kwargs...)
    return summarize_re_range(out)
end

function main()
    args = ARGS_DICT
    catalog_dir, out_dir, jobs, skipped = build_jobs(args)
    run_jobs = parse_bool(args, "run"; default=false)
    resume = parse_bool(args, "resume"; default=true)
    dry_run = parse_bool(args, "dry-run"; default=!run_jobs)
    workers = max(1, safeparse(Int, get(args, "parallel", string(Threads.nthreads()))))
    workers = min(workers, Threads.nthreads())
    write_commands = parse_bool(args, "write-commands"; default=true)

    mkpath(out_dir)
    summary_path = joinpath(out_dir, "dns_bidirectional_summary.csv")
    open(summary_path, "w") do io
        println(io, "timestamp,physical_id,case,group,J,K,L,source,sol_id,direction,status,n_points,min_Re,max_Re,min_input,max_input,error,out_dir,seed")
    end

    np0 = safeparse(Int, get(args, "np0", "0"))
    np1 = safeparse(Int, get(args, "np1", "0"))
    symmpi = safeparse(Int, get(args, "symmpi", "0"))
    executable = get(args, "continuesoln", "continuesoln")
    mpi_prefix = get(args, "mpi-prefix", "")
    shell_parallel = max(1, safeparse(Int, get(args, "shell-parallel", "4")))
    if write_commands
        scripts = write_run_scripts(joinpath(out_dir, "run_continuesoln_all.sh"), jobs; executable=executable, mpi_prefix=mpi_prefix, np0=np0, np1=np1, symmpi=symmpi, shell_parallel=shell_parallel)
        println("sequential command script: $(scripts.sequential)")
        println("parallel command script  : $(scripts.parallel)")
        println("command list             : $(scripts.commands)")
    end

    println("== Catalog DNS Bidirectional Continuation ==")
    println("catalog dir : $catalog_dir")
    println("output dir  : $out_dir")
    println("jobs        : $(length(jobs))  skipped=$(skipped)")
    println("run         : $run_jobs  dry_run=$dry_run  resume=$resume workers=$workers")
    println()

    if dry_run
        for j in jobs
            println("[dry] $(j.physical_id) group=$(j.group) Re=$(j.Re) seed=$(j.seed)")
            for direction in ("minus", "plus")
                out = direction == "minus" ? j.minus_dir : j.plus_dir
                append_csv_row(summary_path, (Dates.format(now(), "yyyy-mm-ddTHH:MM:SS"), j.physical_id, j.case, j.group, j.J, j.K, j.L, j.source, j.sol_id, direction, "dry", "", "", "", "", "", "", out, j.seed))
            end
        end
        return
    end

    progress = Threads.Atomic{Int}(0)
    io_lock = ReentrantLock()
    idxch = Channel{Int}(length(jobs))
    for i in eachindex(jobs)
        put!(idxch, i)
    end
    close(idxch)

    @sync for _ in 1:workers
        Threads.@spawn begin
            for idx in idxch
                j = jobs[idx]
                for direction in ("minus", "plus")
                    out = direction == "minus" ? j.minus_dir : j.plus_dir
                    status = "ok"
                    err = ""
                    summary = (n = 0, min_Re = NaN, max_Re = NaN, min_input = NaN, max_input = NaN)
                    try
                        if resume && cont_has_output(out)
                            status = "resume"
                            summary = summarize_re_range(out)
                        else
                            summary = run_one_direction(j, direction, args)
                        end
                    catch e
                        status = "fail"
                        err = replace(sprint(showerror, e), ',' => ';', '\n' => ' ')
                    end
                    lock(io_lock) do
                        append_csv_row(summary_path, (Dates.format(now(), "yyyy-mm-ddTHH:MM:SS"), j.physical_id, j.case, j.group, j.J, j.K, j.L, j.source, j.sol_id, direction, status, summary.n, summary.min_Re, summary.max_Re, summary.min_input, summary.max_input, err, out, j.seed))
                    end
                end
                try
                    write_combined_curve(j.combined_csv, j.physical_id, j.case, j.group, j.minus_dir, j.plus_dir)
                catch e
                    @warn "failed to write combined curve" physical_id=j.physical_id error=sprint(showerror, e)
                end
                done = Threads.atomic_add!(progress, 1) + 1
                println("[$done/$(length(jobs))] $(j.physical_id) complete")
            end
        end
    end

    println()
    println("summary: $summary_path")
end

main()

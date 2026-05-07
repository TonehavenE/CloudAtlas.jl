using Channelflow_jll
using Dates
using Printf

const DEFAULT_TARGET_LX = 2 * pi / 1.14
const DEFAULT_TARGET_LZ = 2 * pi / 2.5
const DEFAULT_TARGET_CASE = "ghc_re400_alpha1p14_gamma2p5_low_shear"

function parse_args(argv)
    args = Dict{String,String}()
    i = 1
    while i <= length(argv)
        token = argv[i]
        if startswith(token, "--")
            key = token[3:end]
            if i == length(argv) || startswith(argv[i + 1], "--")
                args[key] = "true"
                i += 1
            else
                args[key] = argv[i + 1]
                i += 2
            end
        else
            i += 1
        end
    end
    return args
end

parse_bool(args, key; default=false) = lowercase(strip(get(args, key, string(default)))) in ("1", "true", "yes", "y")
parse_float(args, key, default) = parse(Float64, get(args, key, string(default)))
parse_int(args, key, default) = parse(Int, get(args, key, string(default)))

function csv_escape(x)
    s = string(x)
    if occursin(',', s) || occursin('"', s) || occursin('\n', s)
        return "\"" * replace(s, "\"" => "\"\"") * "\""
    end
    return s
end

function split_csv_line(line::AbstractString)
    vals = String[]
    buf = IOBuffer()
    in_quote = false
    i = firstindex(line)
    while i <= lastindex(line)
        ch = line[i]
        if in_quote && ch == '"'
            ni = nextind(line, i)
            if ni <= lastindex(line) && line[ni] == '"'
                write(buf, ch)
                i = ni
            else
                in_quote = false
            end
        elseif ch == '"'
            in_quote = true
        elseif ch == ',' && !in_quote
            push!(vals, String(take!(buf)))
        else
            write(buf, ch)
        end
        i = nextind(line, i)
    end
    push!(vals, String(take!(buf)))
    return vals
end

function read_csv_dicts(path::AbstractString)
    rows = Dict{String,String}[]
    lines = readlines(path)
    isempty(lines) && return String[], rows
    header = split_csv_line(lines[1])
    for line in lines[2:end]
        isempty(strip(line)) && continue
        vals = split_csv_line(line)
        row = Dict{String,String}()
        for (i, key) in pairs(header)
            row[key] = i <= length(vals) ? vals[i] : ""
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

nearly_equal(a, b; atol=1e-8) = abs(a - b) <= atol

function signed_step(from, to, base_step)
    delta = to - from
    nearly_equal(delta, 0.0) && return 0.0
    return sign(delta) * abs(base_step)
end

function make_segment(
    row,
    catalog_root,
    out_root,
    symm_dir,
    target_label,
    segment_index,
    cont,
    from_Lx,
    from_Lz,
    to_Lx,
    to_Lz,
    target_mu,
    dmu,
    ns,
    T,
)
    id = row["physical_id"]
    Re = parse(Float64, row["Re"])
    group = row["representative_group"]
    seed_rel = get(row, "dns", "")
    seed = isempty(seed_rel) ? "" : abspath(joinpath(catalog_root, seed_rel))
    symm = ensure_symm_file(group, symm_dir)
    tag = @sprintf("%02d_%s", segment_index, lowercase(cont))
    out_dir = abspath(joinpath(out_root, id, "to_$(target_label)", tag))
    return (
        physical_id = id,
        segment_index = segment_index,
        Re = Re,
        group = group,
        from_Lx = from_Lx,
        from_Lz = from_Lz,
        to_Lx = to_Lx,
        to_Lz = to_Lz,
        cont = cont,
        dmu = dmu,
        target_mu = target_mu,
        ns = ns,
        T = T,
        seed = seed,
        symm = symm,
        out_dir = out_dir,
        seed_exists = !isempty(seed) && isfile(seed),
    )
end

function axis_segment(row, catalog_root, out_root, symm_dir, target_label, idx, axis, from_Lx, from_Lz, to_Lx, to_Lz, base_dmu, ns, T)
    if axis == "Lx"
        target_mu = to_Lx
        dmu = signed_step(from_Lx, to_Lx, base_dmu)
    elseif axis == "Lz"
        target_mu = to_Lz
        dmu = signed_step(from_Lz, to_Lz, base_dmu)
    else
        error("Unknown axis continuation: $axis")
    end
    return make_segment(row, catalog_root, out_root, symm_dir, target_label, idx, axis, from_Lx, from_Lz, to_Lx, to_Lz, target_mu, dmu, ns, T)
end

function make_noop_segment(row, catalog_root, out_root, symm_dir, target_Lx, target_Lz, target_label, ns, T, reason)
    Lx = parse(Float64, row["Lx"])
    Lz = parse(Float64, row["Lz"])
    return make_segment(row, catalog_root, out_root, symm_dir, target_label, 0, reason, Lx, Lz, target_Lx, target_Lz, NaN, 0.0, ns, T)
end

function geometry_segments(row, catalog_root, out_root, symm_dir, target_Lx, target_Lz, dmu, ns, T, target_label)
    Lx = parse(Float64, row["Lx"])
    Lz = parse(Float64, row["Lz"])
    seed_rel = get(row, "dns", "")
    seed = isempty(seed_rel) ? "" : abspath(joinpath(catalog_root, seed_rel))
    if isempty(seed) || !isfile(seed)
        return [make_noop_segment(row, catalog_root, out_root, symm_dir, target_Lx, target_Lz, target_label, ns, T, "missing_seed")]
    end
    if nearly_equal(Lx, target_Lx) && nearly_equal(Lz, target_Lz)
        return [make_noop_segment(row, catalog_root, out_root, symm_dir, target_Lx, target_Lz, target_label, ns, T, "already_target")]
    end

    segments = NamedTuple[]
    idx = 1
    cur_Lx = Lx
    cur_Lz = Lz
    dx = target_Lx - Lx
    dz = target_Lz - Lz

    if !nearly_equal(dx, 0.0) && !nearly_equal(dz, 0.0) && sign(dx) == sign(dz)
        scale_x = target_Lx / Lx
        scale_z = target_Lz / Lz
        scale = dx < 0 ? max(scale_x, scale_z) : min(scale_x, scale_z)
        diag_Lx = Lx * scale
        diag_Lz = Lz * scale
        if !nearly_equal(diag_Lx, Lx) || !nearly_equal(diag_Lz, Lz)
            push!(
                segments,
                make_segment(
                    row,
                    catalog_root,
                    out_root,
                    symm_dir,
                    target_label,
                    idx,
                    "Diag",
                    cur_Lx,
                    cur_Lz,
                    diag_Lx,
                    diag_Lz,
                    hypot(diag_Lx, diag_Lz),
                    signed_step(hypot(cur_Lx, cur_Lz), hypot(diag_Lx, diag_Lz), dmu),
                    ns,
                    T,
                ),
            )
            idx += 1
            cur_Lx = diag_Lx
            cur_Lz = diag_Lz
        end
    end

    if !nearly_equal(cur_Lx, target_Lx)
        push!(segments, axis_segment(row, catalog_root, out_root, symm_dir, target_label, idx, "Lx", cur_Lx, cur_Lz, target_Lx, cur_Lz, dmu, ns, T))
        idx += 1
        cur_Lx = target_Lx
    end
    if !nearly_equal(cur_Lz, target_Lz)
        push!(segments, axis_segment(row, catalog_root, out_root, symm_dir, target_label, idx, "Lz", cur_Lx, cur_Lz, cur_Lx, target_Lz, dmu, ns, T))
    end
    return segments
end

function infer_target_geometry(rows, args)
    if haskey(args, "target-Lx") || haskey(args, "target-Lz")
        return (
            parse_float(args, "target-Lx", DEFAULT_TARGET_LX),
            parse_float(args, "target-Lz", DEFAULT_TARGET_LZ),
            get(args, "target-label", "custom"),
        )
    end
    target_case = get(args, "target-case", DEFAULT_TARGET_CASE)
    for row in rows
        get(row, "case", "") == target_case || continue
        return (
            parse(Float64, row["Lx"]),
            parse(Float64, row["Lz"]),
            get(args, "target-label", "ghc"),
        )
    end
    return (
        DEFAULT_TARGET_LX,
        DEFAULT_TARGET_LZ,
        get(args, "target-label", "ghc"),
    )
end

continuesoln_path() = Channelflow_jll.continuesoln().exec[1]

function command_parts(job; executable=continuesoln_path())
    parts = String[
        executable,
        "-cont", job.cont,
        "-eqb",
        "-R", string(job.Re),
        "-T", string(job.T),
        "-symms", job.symm,
        "-od", job.out_dir,
        "-dmu", string(job.dmu),
        "-ns", string(job.ns),
        "-targ",
        "-targMu", string(job.target_mu),
        job.seed,
    ]
    return parts
end

function shell_quote(s::AbstractString)
    return "'" * replace(s, "'" => "'\"'\"'") * "'"
end

function command_string(job; executable=continuesoln_path())
    return join(shell_quote.(command_parts(job; executable=executable)), " ")
end

function write_plan(path, jobs)
    open(path, "w") do io
        header = [
            "physical_id", "segment_index", "Re", "group", "from_Lx", "from_Lz", "target_Lx", "target_Lz",
            "cont", "dmu", "target_mu", "ns", "T", "seed", "symm", "out_dir",
            "seed_exists",
        ]
        println(io, join(header, ","))
        for j in jobs
            vals = [
                j.physical_id, j.segment_index, j.Re, j.group, j.from_Lx, j.from_Lz, j.to_Lx, j.to_Lz,
                j.cont, j.dmu, j.target_mu, j.ns, j.T, j.seed, j.symm, j.out_dir,
                j.seed_exists,
            ]
            println(io, join(csv_escape.(vals), ","))
        end
    end
    return path
end

function write_run_script(path, jobs; julia_cmd="julia")
    open(path, "w") do io
        println(io, "#!/usr/bin/env bash")
        println(io, "set -euo pipefail")
        println(io, "export LD_LIBRARY_PATH=\"/run/opengl-driver/lib:\${LD_LIBRARY_PATH:-}\"")
        println(io, "export CLOUDATLAS_SKIP_ACTIVATE=\"\${CLOUDATLAS_SKIP_ACTIVATE:-true}\"")
        println(io)
        println(io, "$(julia_cmd) --startup-file=no --project=. notebooks/eqb_fuzzing/catalog_dns_geometry_to_ghc.jl --run true")
        println(io)
        println(io, "# Direct continuesoln commands for inspection/recovery:")
        for j in jobs
            (!(j.cont in ("Diag", "Lx", "Lz")) || !j.seed_exists) && continue
            j.segment_index == 1 || continue
            println(io, "# mkdir -p $(shell_quote(j.out_dir))")
            println(io, "# " * command_string(j))
        end
    end
    chmod(path, 0o755)
    return path
end

function run_job(job; resume=true)
    mkpath(job.out_dir)
    if resume && isfile(joinpath(job.out_dir, "processinfo"))
        return (status = "skipped", message = "processinfo exists")
    end
    args = command_parts(job)[2:end]
    cmd = Cmd(`$(Channelflow_jll.continuesoln()) $args`; dir=job.out_dir)
    run(cmd)
    return (status = "ok", message = "")
end

function latest_ubest(out_dir::AbstractString)
    candidates = String[]
    for (root, _, files) in walkdir(out_dir)
        "ubest.nc" in files || continue
        push!(candidates, joinpath(root, "ubest.nc"))
    end
    isempty(candidates) && return nothing
    sort!(candidates; by = p -> stat(p).mtime, rev = true)
    return candidates[1]
end

function format_duration(seconds)
    seconds = max(0, round(Int, seconds))
    h = seconds ÷ 3600
    m = (seconds % 3600) ÷ 60
    s = seconds % 60
    h > 0 && return @sprintf("%dh%02dm%02ds", h, m, s)
    m > 0 && return @sprintf("%dm%02ds", m, s)
    return @sprintf("%ds", s)
end

function append_status(path, row)
    new_file = !isfile(path)
    open(path, "a") do io
        if new_file
            println(io, "timestamp,physical_id,status,message,elapsed_seconds,out_dir")
        end
        vals = [now(), row.physical_id, row.status, row.message, row.elapsed_seconds, row.out_dir]
        println(io, join(csv_escape.(vals), ","))
    end
end

function main(argv=ARGS)
    args = parse_args(argv)
    catalog_root = abspath(get(args, "catalog-root", "catalog"))
    manifest = abspath(get(args, "manifest", joinpath(catalog_root, "catalog_manifest.csv")))
    out_root = abspath(get(args, "out-dir", joinpath(catalog_root, "dns_geometry_to_ghc")))
    symm_dir = joinpath(out_root, "symm_files")
    dmu = parse_float(args, "dmu", 0.01)
    ns = parse_int(args, "ns", 80)
    T = parse_float(args, "T", 10.0)
    run_dns = parse_bool(args, "run"; default=false)
    resume = parse_bool(args, "resume"; default=true)
    only_id = get(args, "only-id", "")
    max_solutions = parse_int(args, "max-solutions", parse_int(args, "max-jobs", typemax(Int)))

    isfile(manifest) || error("Catalog manifest not found: $manifest")
    _, rows = read_csv_dicts(manifest)
    target_Lx, target_Lz, target_label = infer_target_geometry(rows, args)
    rows = [row for row in rows if isempty(only_id) || row["physical_id"] == only_id]
    rows = rows[1:min(length(rows), max_solutions)]
    jobs = isempty(rows) ? NamedTuple[] : reduce(vcat, map(rows) do row
        geometry_segments(row, catalog_root, out_root, symm_dir, target_Lx, target_Lz, dmu, ns, T, target_label)
    end)

    mkpath(out_root)
    plan_path = write_plan(joinpath(out_root, "plan.csv"), jobs)
    script_path = write_run_script(joinpath(out_root, "run_all.sh"), jobs)

    runnable = [j for j in jobs if j.cont in ("Diag", "Lx", "Lz") && j.seed_exists]
    skipped_target = count(j -> j.cont == "already_target", jobs)
    missing_seed = count(j -> !j.seed_exists, jobs)
    solution_count = length(unique(j.physical_id for j in jobs))

    println("[plan] manifest=$(manifest)")
    println("[plan] target $(target_label): Lx=$(target_Lx) Lz=$(target_Lz)")
    println("[plan] solutions=$(solution_count) segments=$(length(jobs)) runnable_segments=$(length(runnable)) already_target=$(skipped_target) missing_seed=$(missing_seed)")
    println("[plan] wrote $(plan_path)")
    println("[plan] wrote $(script_path)")

    if !run_dns
        println("[dry] DNS geometry continuation not launched. Re-run with --run true to execute.")
        return
    end

    status_path = joinpath(out_root, "status.csv")
    start = time()
    solution_ids = unique(j.physical_id for j in runnable)
    completed_segments = 0
    total_segments = length(runnable)
    for (solution_idx, id) in enumerate(solution_ids)
        solution_segments = [j for j in runnable if j.physical_id == id]
        sort!(solution_segments; by = j -> j.segment_index)
        current_seed = solution_segments[1].seed
        for job0 in solution_segments
            completed_segments += 1
            job = merge(job0, (seed = current_seed,))
            elapsed = time() - start
            rate = completed_segments == 1 ? NaN : elapsed / (completed_segments - 1)
            eta = isnan(rate) ? "unknown" : format_duration(rate * (total_segments - completed_segments + 1))
            println(
                "[job $(completed_segments)/$(total_segments)] solution=$(solution_idx)/$(length(solution_ids)) id=$(job.physical_id) seg=$(job.segment_index):$(job.cont) Re=$(job.Re) " *
                @sprintf("Lx %.6g -> %.6g Lz %.6g -> %.6g", job.from_Lx, job.to_Lx, job.from_Lz, job.to_Lz) *
                " eta=$(eta)"
            )
            t0 = time()
            status = "ok"
            message = ""
            try
                result = run_job(job; resume=resume)
                status = result.status
                message = result.message
            catch err
                status = "failed"
                message = sprint(showerror, err)
                @warn "DNS geometry continuation failed" id=job.physical_id segment=job.segment_index error=message
            end
            elapsed_job = time() - t0
            append_status(status_path, (
                physical_id = job.physical_id,
                status = "$(status):$(job.cont)",
                message = message,
                elapsed_seconds = @sprintf("%.3f", elapsed_job),
                out_dir = job.out_dir,
            ))
            println("[job $(completed_segments)/$(total_segments)] status=$(status) elapsed=$(format_duration(elapsed_job))")
            status == "failed" && break
            latest = latest_ubest(job.out_dir)
            if latest === nothing
                @warn "No ubest.nc found after segment" id=job.physical_id segment=job.segment_index out_dir=job.out_dir
                break
            end
            current_seed = latest
        end
    end
    println("[done] wrote $(status_path)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

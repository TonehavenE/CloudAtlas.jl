import Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))

using CloudAtlas
using ChannelflowWrapper
using DelimitedFiles
using Printf
using Dates
using Base.Threads

# ─────────────────────────────────────────────────────────────────────────────
# Default continuation parameters
# ─────────────────────────────────────────────────────────────────────────────

const CONT_T       = 10.0
const CONT_DMU     = -0.02   # step direction: negative = decreasing Re
const CONT_NS      = 50      # number of arclength steps
const CONT_RE_TARG = 100.0   # stop when Re reaches this value

# ─────────────────────────────────────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────────────────────────────────────

function parse_args(args)
    out = Dict{String,String}()
    i = 1
    while i <= length(args)
        if startswith(args[i], "--")
            key = args[i][3:end]
            if i == length(args) || startswith(args[i+1], "--")
                out[key] = "true"; i += 1
            else
                out[key] = args[i+1]; i += 2
            end
        else
            i += 1
        end
    end
    return out
end

safeparse(::Type{Float64}, s) = try parse(Float64, strip(string(s))) catch; NaN end

function parse_bool(args, key; default=false)
    haskey(args, key) || return default
    v = lowercase(strip(args[key]))
    v in ("1","true","yes","y","on") && return true
    v in ("0","false","no","n","off") && return false
    error("Invalid bool for --$key: $(args[key])")
end

# ─────────────────────────────────────────────────────────────────────────────
# CSV reader (same minimal parser as run_catalog_bifurcations.jl)
# ─────────────────────────────────────────────────────────────────────────────

function read_csv(path)
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
        row = Dict{String,String}()
        for i in eachindex(header)
            row[header[i]] = i <= length(vals) ? vals[i] : ""
        end
        push!(rows, row)
    end
    return header, rows
end

# ─────────────────────────────────────────────────────────────────────────────
# Symmetry group helpers (matches eqb_discovery.jl and dns_continuesoln_map.jl)
# ─────────────────────────────────────────────────────────────────────────────

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
            for l in lines; println(io, l); end
        end
    end
    return abspath(path)
end

# ─────────────────────────────────────────────────────────────────────────────
# Parse group letter from a ubest.nc path.
#
# Expected path structure (from create_combined_catalog.jl):
#   {run_root}/{case}/{group}/jkl_{J}_{K}_{L}/dns_findsoln/sol{N}/ubest.nc
#
# We scan path components for a single uppercase letter A–G.
# ─────────────────────────────────────────────────────────────────────────────

function parse_group_from_ubest_path(ubest_path::String, case::String)
    parts = splitpath(ubest_path)
    # Find the index of the case component, then take the next part
    for i in eachindex(parts)
        if parts[i] == case && i < length(parts)
            candidate = parts[i+1]
            if length(candidate) == 1 && candidate[1] in 'A':'G'
                return candidate
            end
        end
    end
    # Fallback: scan all parts for a lone group letter
    for p in parts
        if length(p) == 1 && p[1] in 'A':'G'
            return p
        end
    end
    return nothing
end

# ─────────────────────────────────────────────────────────────────────────────
# Read the minimum Re from a completed continuesoln output directory.
# Reads both MuD.asc (first column = Re at each step) and initial-*/mu.asc.
# ─────────────────────────────────────────────────────────────────────────────

function read_mud_min(path::String)
    isfile(path) || return nothing
    vals = Float64[]
    skip_header = true
    open(path) do io
        for line in eachline(io)
            s = strip(line)
            isempty(s) && continue
            if skip_header; skip_header = false; continue; end
            f = split(s)
            isempty(f) && continue
            v = tryparse(Float64, f[1])
            v === nothing && continue
            push!(vals, v)
        end
    end
    isempty(vals) && return nothing
    return minimum(vals)
end

function read_initial_mu_min(out_dir::String)
    vals = Float64[]
    isdir(out_dir) || return nothing
    for name in readdir(out_dir)
        startswith(name, "initial-") || continue
        mu_path = joinpath(out_dir, name, "mu.asc")
        isfile(mu_path) || continue
        v = tryparse(Float64, strip(read(mu_path, String)))
        v === nothing && continue
        push!(vals, v)
    end
    isempty(vals) && return nothing
    return minimum(vals)
end

function summarize_re_min(out_dir::String)
    m1 = read_mud_min(joinpath(out_dir, "MuD.asc"))
    m2 = read_initial_mu_min(out_dir)
    m1 === nothing && return m2
    m2 === nothing && return m1
    return min(m1, m2)
end

# Check whether a continuation run already has useful output
function cont_has_output(out_dir::String)
    isdir(out_dir) || return false
    # processinfo is written at the start, so its presence means the run started
    isfile(joinpath(out_dir, "processinfo")) || return false
    # Require at least one converged initial- or search- solution
    for name in readdir(out_dir)
        (startswith(name, "initial-") || startswith(name, "search-")) || continue
        isfile(joinpath(out_dir, name, "ubest.nc")) && return true
    end
    return false
end

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

function main()
    args = parse_args(ARGS)
    base      = @__DIR__
    cat_dir   = abspath(get(args, "catalog-dir",  joinpath(base, "eqb_catalog")))
    out_dir   = abspath(get(args, "out-dir",       joinpath(cat_dir, "dns_bifurcations")))
    resume    = parse_bool(args, "resume"; default=true)
    dry_run   = parse_bool(args, "dry-run"; default=false)
    workers   = max(1, parse(Int, get(args, "parallel", string(Threads.nthreads()))))

    # Continuation parameters (overridable)
    cont_T      = parse(Float64, get(args, "T",       string(CONT_T)))
    cont_dmu    = parse(Float64, get(args, "dmu",     string(CONT_DMU)))
    cont_ns     = parse(Int,     get(args, "ns",      string(CONT_NS)))
    cont_target = parse(Float64, get(args, "targMu",  string(CONT_RE_TARG)))

    phys_path = joinpath(cat_dir, "physical_solutions.csv")
    _, phys_rows = read_csv(phys_path)

    symm_dir = joinpath(out_dir, "symm_files")

    # Build job list
    jobs = NamedTuple[]
    skipped_trivial = 0
    skipped_no_ubest = 0
    skipped_resume   = 0
    skipped_no_group = 0

    for pr in phys_rows
        pid = pr["physical_id"]

        if pr["is_trivial"] == "true"
            skipped_trivial += 1
            continue
        end

        ubest = pr["representative_ubest"]
        if !isfile(ubest)
            @warn "ubest.nc not found for $pid: $ubest"
            skipped_no_ubest += 1
            continue
        end

        case  = pr["case"]
        Re    = safeparse(Float64, pr["Re"])
        group = parse_group_from_ubest_path(ubest, case)

        if group === nothing
            @warn "Cannot parse group from path for $pid: $ubest"
            skipped_no_group += 1
            continue
        end

        job_out_dir = joinpath(out_dir, pid)

        if resume && cont_has_output(job_out_dir)
            skipped_resume += 1
            continue
        end

        push!(jobs, (
            physical_id = pid,
            case        = case,
            group       = group,
            Re          = Re,
            ubest       = ubest,
            out_dir     = job_out_dir,
        ))
    end

    mkpath(out_dir)
    println("== Catalog DNS Bifurcation Sweep ==")
    println("catalog dir : $cat_dir")
    println("output dir  : $out_dir")
    @printf("jobs: %d  |  skipped trivial: %d  no_ubest: %d  no_group: %d  resume: %d\n",
            length(jobs), skipped_trivial, skipped_no_ubest, skipped_no_group, skipped_resume)
    println("workers: $workers  dry_run: $dry_run  resume: $resume")
    println("cont params: T=$cont_T  dmu=$cont_dmu  ns=$cont_ns  targMu=$cont_target")
    println()

    summary_path = joinpath(out_dir, "dns_bifurcation_summary.csv")
    open(summary_path, "w") do io
        println(io, "timestamp,physical_id,case,group,Re,status,min_Re,error,out_dir")
    end

    if dry_run
        for j in jobs
            println("  [dry] $(j.physical_id)  group=$(j.group)  Re=$(j.Re)  $(j.ubest)")
            open(summary_path, "a") do io
                println(io, "$(Dates.format(now(),"yyyy-mm-ddTHH:MM:SS")),$(j.physical_id),$(j.case),$(j.group),$(j.Re),dry,,,$(j.out_dir)")
            end
        end
        println("[dry-run done]")
        return
    end

    progress = Threads.Atomic{Int}(0)
    io_lock  = ReentrantLock()
    results  = Vector{NamedTuple}(undef, length(jobs))
    idxch    = Channel{Int}(length(jobs))
    for i in eachindex(jobs); put!(idxch, i); end
    close(idxch)

    @sync for _ in 1:workers
        Threads.@spawn begin
            for idx in idxch
                j       = jobs[idx]
                status  = "ok"
                min_re  = NaN
                err     = ""
                try
                    mkpath(j.out_dir)
                    symm_path = ensure_symm_file(j.group, symm_dir)
                    continuesoln(
                        j.ubest;
                        workdir = j.out_dir,
                        cont    = "Re",
                        eqb     = true,
                        R       = j.Re,
                        T       = cont_T,
                        symms   = symm_path,
                        od      = j.out_dir,
                        dmu     = cont_dmu,
                        ns      = cont_ns,
                        targ    = true,
                        targMu  = cont_target,
                    )
                    re_min_val = summarize_re_min(j.out_dir)
                    min_re = re_min_val === nothing ? NaN : re_min_val
                catch e
                    status = "fail"
                    err = replace(sprint(showerror, e), ',' => ';', '\n' => ' ')
                end
                results[idx] = (job=j, status=status, min_Re=min_re, error=err)
                done = Threads.atomic_add!(progress, 1) + 1
                lock(io_lock) do
                    open(summary_path, "a") do io
                        println(io, "$(Dates.format(now(),"yyyy-mm-ddTHH:MM:SS")),$(j.physical_id),$(j.case),$(j.group),$(j.Re),$(status),$(min_re),$(err),$(j.out_dir)")
                    end
                    println("[$done/$(length(jobs))] $(j.physical_id)  group=$(j.group)  status=$status  min_Re=$(isnan(min_re) ? "N/A" : @sprintf("%.1f", min_re))")
                end
            end
        end
    end

    nok   = count(r -> r.status == "ok",   results)
    nfail = count(r -> r.status == "fail",  results)
    println()
    println("=== Done ===")
    println("ok=$(nok)  fail=$(nfail)")
    println("summary: $summary_path")
end

main()

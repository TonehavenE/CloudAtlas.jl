import Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))

using CloudAtlas
import BifurcationKit as BK
using DelimitedFiles
using Printf
using Dates
using Base.Threads

# ─────────────────────────────────────────────────────────────────────────────
# Continuation parameters  (same as compute_eqb_discovery_bifurcations.jl)
# ─────────────────────────────────────────────────────────────────────────────

const CONT_RE_MIN   = 100.0
const CONT_RE_MAX   = 500.0
const CONT_MAX_STEPS = 2000
const CONT_DSMIN    = 1e-7
const CONT_DSMAX    = 1.0
const HOOKPARAMS    = SearchParams(; ftol=1e-8, xtol=1e-10, Nnewton=25, Nhook=6, verbosity=0)

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
safeparse(::Type{Int},     s) = try parse(Int,     strip(string(s))) catch; 0   end

function parse_bool(args, key; default=false)
    haskey(args, key) || return default
    v = lowercase(strip(args[key]))
    v in ("1","true","yes","y","on") && return true
    v in ("0","false","no","n","off") && return false
    error("Invalid bool for --$key: $(args[key])")
end

# ─────────────────────────────────────────────────────────────────────────────
# CSV helpers
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
        # Handle quoted fields (e.g. "A,B,C")
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
# Symmetry group map  (matches eqb_discovery.jl)
# ─────────────────────────────────────────────────────────────────────────────

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

# ─────────────────────────────────────────────────────────────────────────────
# Parse member string:  "on:sol001@J3K5L11"  →  (source, sol_id, J, K, L)
# ─────────────────────────────────────────────────────────────────────────────

function parse_member_entry(s)
    m = match(r"^(on|ls):sol(\d+)@J(\d+)K(\d+)L(\d+)$", strip(s))
    m === nothing && return nothing
    return (
        source = m.captures[1],
        sol_id = safeparse(Int, m.captures[2]),
        J      = safeparse(Int, m.captures[3]),
        K      = safeparse(Int, m.captures[4]),
        L      = safeparse(Int, m.captures[5]),
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# Find the best .asc file for a physical solution.
#
# "Best" = highest (J,K,L); tiebreak overnight > low_shear.
# Scans all group-level catalog rows for this physical_id.
# Returns a NamedTuple or nothing.
# ─────────────────────────────────────────────────────────────────────────────

function find_best_asc(group_rows, on_root, ls_root)
    best = nothing
    for r in group_rows
        case  = r["case"]
        group = r["group"]
        for entry_str in split(r["all_members"], ';')
            m = parse_member_entry(entry_str)
            m === nothing && continue
            run_root = m.source == "on" ? on_root : ls_root
            asc_path = joinpath(
                run_root, case, group,
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
                    source   = m.source,
                    case     = case,
                    group    = group,
                    J        = m.J,
                    K        = m.K,
                    L        = m.L,
                    sol_id   = m.sol_id,
                    jkl      = jkl,
                    asc_path = asc_path,
                )
            end
        end
    end
    return best
end

# ─────────────────────────────────────────────────────────────────────────────
# Continuation helpers
# ─────────────────────────────────────────────────────────────────────────────

function continue_eqb(model, x0, Re0)
    fp(x, p) = model.f(x, p[1])
    prob = BK.BifurcationProblem(
        fp, x0, [Float64(Re0)], 1;
        record_from_solution=(x, p; k...) -> shear(x, model),
        plot_solution=(x, p; k...) -> shear(x, model),
    )
    newton_opts = BK.NewtonPar(
        1e-10, 25, false, BK.DefaultLS(), BK.DefaultEig(), false, 1.0, 0.01
    )
    cont_opts = BK.ContinuationPar(;
        p_min        = CONT_RE_MIN,
        p_max        = CONT_RE_MAX,
        n_inversion  = 20,
        dsmin        = CONT_DSMIN,
        dsmax        = CONT_DSMAX,
        max_steps    = CONT_MAX_STEPS,
        newton_options = newton_opts,
    )
    return BK.continuation(prob, BK.PALC(), cont_opts; bothside=true)
end

function repolish(model, Re, x0)
    f  = x -> model.f(x, Re)
    Df = x -> model.Df(x, Re)
    return hookstepsolve(f, Df, x0, HOOKPARAMS)
end

function extract_re_shear(br, model)
    Re_vals = hasproperty(br, :branch) ? collect(br.branch.param) : collect(br.param)
    sols = if hasproperty(br, :branch) && hasproperty(br.branch, :sol)
        br.branch.sol
    elseif hasproperty(br, :sol)
        br.sol
    else
        error("No continuation solutions available")
    end
    shear_vals = similar(Re_vals)
    for i in eachindex(Re_vals)
        x = sols[i] isa AbstractVector ? sols[i] :
            haskey(sols[i], :x) ? sols[i].x : sols[i].u
        shear_vals[i] = shear(x, model)
    end
    return Re_vals, shear_vals
end

function write_bif_csv(path, Re_vals, shear_vals)
    open(path, "w") do io
        println(io, "Re,shear")
        for i in eachindex(Re_vals)
            println(io, "$(Re_vals[i]),$(shear_vals[i])")
        end
    end
end

csv_has_data(path) = isfile(path) && length(readlines(path)) >= 2

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

function main()
    args = parse_args(ARGS)
    base      = @__DIR__
    on_root   = abspath(get(args, "overnight-root", joinpath(base, "overnight_runs_updated")))
    ls_root   = abspath(get(args, "low-shear-root", joinpath(base, "low_shear")))
    cat_dir   = abspath(get(args, "catalog-dir",   joinpath(base, "eqb_catalog")))
    out_dir   = abspath(get(args, "out-dir",        joinpath(cat_dir, "bifurcations")))
    resume    = parse_bool(args, "resume"; default=true)
    dry_run   = parse_bool(args, "dry-run"; default=false)
    parallel  = parse(Int, get(args, "parallel", string(Threads.nthreads())))
    workers   = max(1, min(parallel, Threads.nthreads()))

    phys_path    = joinpath(cat_dir, "physical_solutions.csv")
    catalog_path = joinpath(cat_dir, "catalog.csv")

    _, phys_rows    = read_csv(phys_path)
    _, catalog_rows = read_csv(catalog_path)

    # Index catalog rows by physical_id
    catalog_by_pid = Dict{String, Vector{Dict{String,String}}}()
    for r in catalog_rows
        pid = r["physical_id"]
        push!(get!(catalog_by_pid, pid, Dict{String,String}[]), r)
    end

    symm_map = symmetry_groups()

    # Build job list
    struct_jobs = NamedTuple[]
    skipped_trivial = 0
    skipped_no_asc  = 0
    skipped_resume  = 0

    for pr in phys_rows
        pid = pr["physical_id"]

        # Skip trivial solutions (u ≈ 0)
        if pr["is_trivial"] == "true"
            skipped_trivial += 1
            continue
        end

        case = pr["case"]
        Re   = safeparse(Float64, pr["Re"])
        Lx   = safeparse(Float64, pr["Lx"])
        Lz   = safeparse(Float64, pr["Lz"])
        alpha = 2π / Lx
        gamma = 2π / Lz

        group_rows = get(catalog_by_pid, pid, Dict{String,String}[])
        rep = find_best_asc(group_rows, on_root, ls_root)

        if rep === nothing
            @warn "No .asc file found for $pid — skipping"
            skipped_no_asc += 1
            continue
        end

        H = get(symm_map, rep.group, nothing)
        H === nothing && error("Unknown symmetry group: $(rep.group)")

        bif_dir  = joinpath(out_dir, pid)
        csv_path = joinpath(bif_dir, "bif.csv")

        if resume && csv_has_data(csv_path)
            skipped_resume += 1
            continue
        end

        push!(struct_jobs, (
            physical_id = pid,
            case        = case,
            group       = rep.group,
            J           = rep.J,
            K           = rep.K,
            L           = rep.L,
            sol_id      = rep.sol_id,
            source      = rep.source,
            asc_path    = rep.asc_path,
            Re          = Re,
            alpha       = alpha,
            gamma       = gamma,
            H           = H,
            bif_dir     = bif_dir,
            csv_path    = csv_path,
        ))
    end

    println("== Catalog Bifurcation Sweep ==")
    println("catalog dir    : $cat_dir")
    println("overnight root : $on_root")
    println("low_shear root : $ls_root")
    println("output dir     : $out_dir")
    @printf("jobs: %d  |  skipped trivial: %d  no_asc: %d  resume: %d\n",
            length(struct_jobs), skipped_trivial, skipped_no_asc, skipped_resume)
    println("workers: $workers  dry_run: $dry_run  resume: $resume")
    println()

    summary_path = joinpath(out_dir, "bifurcation_summary.csv")
    mkpath(out_dir)

    open(summary_path, "w") do io
        println(io, "timestamp,physical_id,case,group,J,K,L,sol_id,source,status,min_Re,error,csv_path")
    end

    if dry_run
        for j in struct_jobs
            println("  [dry] $(j.physical_id)  $(j.group) J$(j.J)K$(j.K)L$(j.L) sol$(j.sol_id) ($(j.source))")
            open(summary_path, "a") do io
                println(io, "$(Dates.format(now(),"yyyy-mm-ddTHH:MM:SS")),$(j.physical_id),$(j.case),$(j.group),$(j.J),$(j.K),$(j.L),$(j.sol_id),$(j.source),dry,,,$(j.csv_path)")
            end
        end
        println("[dry-run done]")
        return
    end

    progress  = Threads.Atomic{Int}(0)
    io_lock   = ReentrantLock()
    results   = Vector{NamedTuple}(undef, length(struct_jobs))
    idxch     = Channel{Int}(length(struct_jobs))
    for i in eachindex(struct_jobs); put!(idxch, i); end
    close(idxch)

    @sync for _ in 1:workers
        Threads.@spawn begin
            for idx in idxch
                j = struct_jobs[idx]
                status = "ok"
                min_Re = NaN
                err    = ""
                try
                    mkpath(j.bif_dir)
                    model = ODEModel(j.alpha, j.gamma, j.J, j.K, j.L, j.H; normalize=false, tw=false)
                    x0    = vec(readdlm(j.asc_path; comments=true, comment_char='#'))
                    x0p, conv = repolish(model, j.Re, x0)
                    if !conv
                        status = "repolish_fail"
                    else
                        br = continue_eqb(model, x0p, j.Re)
                        Re_vals, shear_vals = extract_re_shear(br, model)
                        write_bif_csv(j.csv_path, Re_vals, shear_vals)
                        min_Re = minimum(Re_vals)
                    end
                catch e
                    status = "fail"
                    err = replace(sprint(showerror, e), ',' => ';', '\n' => ' ')
                end
                results[idx] = (job=j, status=status, min_Re=min_Re, error=err)
                done = Threads.atomic_add!(progress, 1) + 1
                lock(io_lock) do
                    open(summary_path, "a") do io
                        println(io, "$(Dates.format(now(),"yyyy-mm-ddTHH:MM:SS")),$(j.physical_id),$(j.case),$(j.group),$(j.J),$(j.K),$(j.L),$(j.sol_id),$(j.source),$(status),$(min_Re),$(err),$(j.csv_path)")
                    end
                    println("[$done/$(length(struct_jobs))] $(j.physical_id)  status=$status  min_Re=$(isnan(min_Re) ? "N/A" : @sprintf("%.1f",min_Re))")
                end
            end
        end
    end

    nok   = count(r -> r.status == "ok",             results)
    nfail = count(r -> r.status == "fail",            results)
    nrep  = count(r -> r.status == "repolish_fail",   results)
    println()
    println("=== Done ===")
    println("ok=$(nok)  repolish_fail=$(nrep)  fail=$(nfail)")
    println("summary: $summary_path")
end

main()

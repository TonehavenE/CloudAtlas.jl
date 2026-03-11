import Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))

using CloudAtlas
import BifurcationKit as BK
using DelimitedFiles
using Printf
using Dates
using Base.Threads

const SYMM_ORDER = ["A", "B", "C", "D", "E", "F", "G"]

const cont_Re_min = 100.0
const cont_Re_max = 500.0
const cont_max_steps = 2000
const cont_dsmin = 1e-7
const cont_dsmax = 1.0
const hookparams = SearchParams(; ftol=1e-8, xtol=1e-10, Nnewton=25, Nhook=6, verbosity=0)

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
    return [strip(x) for x in split(t, ",") if !isempty(strip(x))]
end

function parse_group_list(s::AbstractString)
    g = parse_case_list(s)
    isempty(g) && return SYMM_ORDER
    for x in g
        x in SYMM_ORDER || error("Unknown group '$x'")
    end
    return g
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

function csv_has_data(path::AbstractString)
    isfile(path) || return false
    lines = readlines(path)
    return length(lines) >= 2
end

function continue_eqb(model, x0, Re0; Re_min=cont_Re_min, Re_max=cont_Re_max, max_steps=cont_max_steps, dsmin=cont_dsmin, dsmax=cont_dsmax)
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
        p_min=Re_min,
        p_max=Re_max,
        n_inversion=20,
        dsmin=dsmin,
        dsmax=dsmax,
        max_steps=max_steps,
        newton_options=newton_opts,
    )
    return BK.continuation(prob, BK.PALC(), cont_opts; bothside=true)
end

function solve_eqb(model, Re, xguess, hp=hookparams)
    f = x -> model.f(x, Re)
    Df = x -> model.Df(x, Re)
    return hookstepsolve(f, Df, xguess, hp)
end

function get_state_vector(sol)
    if sol isa AbstractVector
        return sol
    elseif sol isa NamedTuple
        if haskey(sol, :x)
            return sol.x
        elseif haskey(sol, :u)
            return sol.u
        end
    end
    error("Unsupported continuation state type: $(typeof(sol))")
end

function extract_re_shear(br, model)
    Re_vals = hasproperty(br, :branch) ? collect(br.branch.param) : collect(br.param)
    sols = nothing
    if hasproperty(br, :branch) && hasproperty(br.branch, :sol)
        sols = br.branch.sol
    elseif hasproperty(br, :sol)
        sols = br.sol
    end
    sols === nothing && error("No continuation solutions available")
    shear_vals = similar(Re_vals)
    for i in eachindex(Re_vals)
        x = get_state_vector(sols[i])
        shear_vals[i] = shear(x, model)
    end
    return Re_vals, shear_vals
end

function gather_jobs(runs_root::String, queue_meta, cases, groups; resume::Bool=true)
    symm_map = symmetry_groups()
    jobs = NamedTuple[]
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
                bif_dir = joinpath(level_dir, "bifurcations")
                mkpath(bif_dir)
                for f in readdir(level_dir)
                    endswith(f, ".asc") || continue
                    startswith(f, "sol") || continue
                    sid = parse_sol_id(f)
                    sid == 0 && continue
                    sol_path = joinpath(level_dir, f)
                    csv_path = joinpath(bif_dir, @sprintf("bif_%s_sol%03d.csv", g, sid))
                    if resume && csv_has_data(csv_path)
                        continue
                    end
                    push!(jobs, (
                        case_label=case,
                        case_dir=case_dir,
                        group=g,
                        H=H,
                        J=J,
                        K=K,
                        L=L,
                        alpha=alpha,
                        gamma=gamma,
                        Re=meta.Re,
                        level_dir=level_dir,
                        bif_dir=bif_dir,
                        sol_id=sid,
                        sol_path=sol_path,
                        csv_path=csv_path,
                    ))
                end
            end
        end
    end
    return jobs
end

function write_bif_csv(path::AbstractString, Re_vals, shear_vals)
    open(path, "w") do io
        println(io, "Re,shear")
        for i in eachindex(Re_vals)
            println(io, "$(Re_vals[i]),$(shear_vals[i])")
        end
    end
end

function build_min_re_tables!(jobs)
    by_bif_dir = Dict{String, Vector{Tuple{Int, String}}}()
    for j in jobs
        push!(get!(by_bif_dir, j.bif_dir, Tuple{Int, String}[]), (j.sol_id, j.csv_path))
    end
    for (bif_dir, entries) in by_bif_dir
        min_path = joinpath(bif_dir, "min_re.csv")
        open(min_path, "w") do io
            println(io, "sol_id,min_Re")
            for (sid, csv_path) in sort(entries; by=x -> x[1])
                if !csv_has_data(csv_path)
                    continue
                end
                X = readdlm(csv_path, ',', Float64; skipstart=1)
                isempty(X) && continue
                if ndims(X) == 1
                    X = reshape(X, 1, length(X))
                end
                size(X, 2) < 1 && continue
                min_Re = minimum(X[:, 1])
                println(io, "$(sid),$(min_Re)")
            end
        end
    end
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
    parallel = parse(Int, get(args, "parallel", string(Threads.nthreads())))
    workers = max(1, min(parallel, Threads.nthreads()))

    jobs = gather_jobs(runs_root, queue_meta, cases, groups; resume=resume)
    println("== EQB Discovery Bifurcation Sweep ==")
    println("runs_root=$(runs_root)")
    println("cases=$(join(cases, ","))")
    println("groups=$(join(groups, ","))")
    println("jobs=$(length(jobs)) resume=$(resume) dry_run=$(dry_run) workers=$(workers)")

    summary_path = joinpath(runs_root, "bifurcation_jobs_summary.csv")
    open(summary_path, "w") do io
        println(io, "timestamp,case,group,J,K,L,sol_id,status,min_Re,error,csv_path")
    end

    if dry_run
        for j in jobs
            open(summary_path, "a") do io
                println(io, "$(Dates.format(now(), "yyyy-mm-ddTHH:MM:SS")),$(j.case_label),$(j.group),$(j.J),$(j.K),$(j.L),$(j.sol_id),dry,,,$(j.csv_path)")
            end
        end
        println("[dry-run] wrote $summary_path")
        return
    end

    progress = Threads.Atomic{Int}(0)
    io_lock = ReentrantLock()
    results = Vector{NamedTuple}(undef, length(jobs))
    idxch = Channel{Int}(length(jobs))
    for i in eachindex(jobs)
        put!(idxch, i)
    end
    close(idxch)

    @sync for _ in 1:workers
        Threads.@spawn begin
            for idx in idxch
                j = jobs[idx]
                status = "ok"
                min_Re = NaN
                err = ""
                try
                    model = ODEModel(j.alpha, j.gamma, j.J, j.K, j.L, j.H; normalize=false, tw=false)
                    x0 = myreaddlm(j.sol_path)
                    x0p, conv = solve_eqb(model, j.Re, x0)
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
                lock(io_lock) do
                    open(summary_path, "a") do io
                        println(
                            io,
                            "$(Dates.format(now(), "yyyy-mm-ddTHH:MM:SS")),$(j.case_label),$(j.group),$(j.J),$(j.K),$(j.L),$(j.sol_id),$(status),$(min_Re),$(err),$(j.csv_path)",
                        )
                    end
                end
                done = Threads.atomic_add!(progress, 1) + 1
                if done % max(1, length(jobs) ÷ 100) == 0 || done == length(jobs)
                    println("progress $(done)/$(length(jobs))")
                end
            end
        end
    end

    build_min_re_tables!(jobs)
    nok = count(r -> r.status == "ok", results)
    nfail = length(results) - nok
    println("[done] ok=$(nok) fail=$(nfail)")
    println("summary=$summary_path")
end

main()

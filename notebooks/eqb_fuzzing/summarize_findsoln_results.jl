import Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))

using DelimitedFiles
using Printf
using Dates

const GROUP_ORDER = ["A", "B", "C", "D", "E", "F", "G"]
const GROUP_SYMMS = Dict(
    "A" => "sxyz, txz",
    "B" => "sxy, sz",
    "C" => "sxytz, sz",
    "D" => "sxy, sztx",
    "E" => "sxyz, sztxz",
    "F" => "sxy, sz, txz",
    "G" => "sxyz",
)

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

safeparse(::Type{Float64}, s::AbstractString) = try parse(Float64, strip(s)) catch; NaN end
safeparse(::Type{Int}, s::AbstractString) = try parse(Int, strip(s)) catch; 0 end

function parse_case_list(s::AbstractString)
    t = strip(s)
    isempty(t) && return String[]
    [String(strip(x)) for x in split(t, ",") if !isempty(strip(x))]
end

function parse_jkl(dirname::AbstractString)
    m = match(r"^jkl_(\d+)_(\d+)_(\d+)$", dirname)
    m === nothing && return nothing
    return (safeparse(Int, m.captures[1]), safeparse(Int, m.captures[2]), safeparse(Int, m.captures[3]))
end

function parse_sol_dirname(dirname::AbstractString)
    m = match(r"^sol(\d+)$", dirname)
    m === nothing && return 0
    return safeparse(Int, m.captures[1])
end

function read_run_queue(runs_root::AbstractString)
    queue_path = joinpath(runs_root, "run_queue_summary.csv")
    isfile(queue_path) || return Dict{String,NamedTuple}()
    lines = readlines(queue_path)
    isempty(lines) && return Dict{String,NamedTuple}()
    header = split(chomp(lines[1]), ',')
    idx = Dict{String,Int}(h => i for (i, h) in enumerate(header))
    out = Dict{String,NamedTuple}()
    for ln in lines[2:end]
        s = chomp(ln)
        isempty(strip(s)) && continue
        vals = split(s, ',')
        case = get(vals, get(idx, "case_label", 0), "")
        isempty(case) && continue
        out[case] = (
            case_label=case,
            Re=safeparse(Float64, get(vals, get(idx, "Re", 0), "NaN")),
            Lx=safeparse(Float64, get(vals, get(idx, "Lx", 0), "NaN")),
            Lz=safeparse(Float64, get(vals, get(idx, "Lz", 0), "NaN")),
            out_dir=get(vals, get(idx, "out_dir", 0), joinpath(runs_root, case)),
        )
    end
    return out
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

function read_fieldconverge_stats(path::AbstractString)
    isfile(path) || return Dict{String,Float64}()
    lines = readlines(path)
    isempty(lines) && return Dict{String,Float64}()
    header = split(strip(lines[1]))
    data_lines = [strip(ln) for ln in lines[2:end] if !isempty(strip(ln))]
    isempty(data_lines) && return Dict{String,Float64}()
    vals = split(last(data_lines))
    n = min(length(header), length(vals))
    stats = Dict{String,Float64}()
    for i in 1:n
        v = safeparse(Float64, vals[i])
        if isfinite(v)
            stats[header[i]] = v
        end
    end
    return stats
end

function fmtfloat(x; digits=6)
    if !isfinite(x)
        return "NaN"
    end
    return @sprintf("%.*g", digits, x)
end

function getmetric(stats::Dict{String,Float64}, key::String)
    get(stats, key, NaN)
end

function collect_case_records(case_dir::AbstractString; conv_tol::Float64=1e-10)
    records = NamedTuple[]
    for group in GROUP_ORDER
        group_dir = joinpath(case_dir, group)
        isdir(group_dir) || continue
        for d in readdir(group_dir)
            jkl = parse_jkl(d)
            jkl === nothing && continue
            J, K, L = jkl
            dns_root = joinpath(group_dir, d, "dns_findsoln")
            isdir(dns_root) || continue
            for sol_dir in readdir(dns_root)
                sid = parse_sol_dirname(sol_dir)
                sid == 0 && continue
                job_dir = joinpath(dns_root, sol_dir)
                isdir(job_dir) || continue
                convergence = joinpath(job_dir, "convergence.asc")
                fieldconv = joinpath(job_dir, "fieldconverge.asc")
                ubest = joinpath(job_dir, "ubest.nc")
                res = read_last_residual(convergence)
                converged = isfinite(res) && (res <= conv_tol) && isfile(ubest)
                stats = read_fieldconverge_stats(fieldconv)
                push!(records, (
                    group=group,
                    sol_id=sid,
                    J=J,
                    K=K,
                    L=L,
                    job_dir=job_dir,
                    converged=converged,
                    residual=res,
                    stats=stats,
                ))
            end
        end
    end
    return records
end

function best_record(records_for_sol)
    # Prefer converged records. Within each class, prefer highest resolution (J,K,L).
    converged = [r for r in records_for_sol if r.converged]
    pool = isempty(converged) ? records_for_sol : converged
    sort!(pool; by=r -> (r.J, r.K, r.L), rev=true)
    return first(pool)
end

function write_case_summary(out_path::AbstractString, case_label::String, Re, Lx, Lz, records)
    grouped = Dict{String, Dict{Int, Vector{NamedTuple}}}()
    for g in GROUP_ORDER
        grouped[g] = Dict{Int, Vector{NamedTuple}}()
    end
    for r in records
        d = grouped[r.group]
        push!(get!(d, r.sol_id, NamedTuple[]), r)
    end

    mkpath(dirname(out_path))
    open(out_path, "w") do io
        println(io, "# $(fmtfloat(Lx; digits=8)) x $(fmtfloat(Lz; digits=8)) at Re=$(fmtfloat(Re; digits=8)) findsoln results")
        println(io)
        println(io, "Generated: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")
        println(io)

        for g in GROUP_ORDER
            sols = grouped[g]
            isempty(sols) && continue
            symm = get(GROUP_SYMMS, g, "unknown")
            println(io, "## Group $g ($symm)")
            println(io)
            for sid in sort(collect(keys(sols)))
                candidates = sols[sid]
                b = best_record(candidates)
                shear = getmetric(b.stats, "wallshear")
                shear_a = getmetric(b.stats, "wallshear_a")
                shear_b = getmetric(b.stats, "wallshear_b")
                diss = getmetric(b.stats, "dissipation")
                l2 = getmetric(b.stats, "L2")
                u2 = getmetric(b.stats, "u2")
                v2 = getmetric(b.stats, "v2")
                w2 = getmetric(b.stats, "w2")
                e3d = getmetric(b.stats, "e3d")
                ecf = getmetric(b.stats, "ecf")
                ub = getmetric(b.stats, "ubulk")
                wb = getmetric(b.stats, "wbulk")

                nconv = count(x -> x.converged, candidates)
                println(io, "sol$(lpad(string(sid), 3, '0')):")
                println(io, "- representative JKL: ($(b.J), $(b.K), $(b.L))")
                println(io, "- status: $(b.converged ? "converged" : "not_converged")")
                println(io, "- converged variants: $nconv / $(length(candidates))")
                println(io, "- final residual: $(fmtfloat(b.residual; digits=8))")
                println(io, "- shear: $(fmtfloat(shear; digits=8))")
                println(io, "- dissipation: $(fmtfloat(diss; digits=8))")
                println(io, "- L2Norm: $(fmtfloat(l2; digits=8))")
                println(io, "- components (u2,v2,w2): ($(fmtfloat(u2; digits=8)), $(fmtfloat(v2; digits=8)), $(fmtfloat(w2; digits=8)))")
                println(io, "- energies (e3d,ecf): ($(fmtfloat(e3d; digits=8)), $(fmtfloat(ecf; digits=8)))")
                println(io, "- bulks (ubulk,wbulk): ($(fmtfloat(ub; digits=8)), $(fmtfloat(wb; digits=8)))")
                println(io, "- wall shear split (a,b): ($(fmtfloat(shear_a; digits=8)), $(fmtfloat(shear_b; digits=8)))")
                println(io, "- source dir: $(b.job_dir)")
                println(io)
            end
        end
    end
end

function main()
    args = parse_args(ARGS)
    runs_root = get(args, "runs-root", joinpath(@__DIR__, "overnight_runs_updated"))
    out_dir = get(args, "out-dir", joinpath(runs_root, "analysis", "findsoln_summaries"))
    conv_tol = parse(Float64, get(args, "conv-tol", "1e-10"))
    req_cases = parse_case_list(get(args, "cases", ""))

    queue = read_run_queue(runs_root)
    all_cases = sort(collect(keys(queue)))
    if isempty(all_cases)
        all_cases = sort(filter(x -> isdir(joinpath(runs_root, x)), readdir(runs_root)))
    end
    cases = isempty(req_cases) ? all_cases : filter(x -> x in req_cases, all_cases)
    isempty(cases) && error("No matching cases under $runs_root")

    println("== findsoln summary writer ==")
    println("runs_root=$(runs_root)")
    println("out_dir=$(out_dir)")
    println("cases=$(join(cases, ',')) conv_tol=$(conv_tol)")

    wrote = 0
    for case in cases
        meta = get(queue, case, (case_label=case, Re=NaN, Lx=NaN, Lz=NaN, out_dir=joinpath(runs_root, case)))
        case_dir = abspath(meta.out_dir)
        isdir(case_dir) || continue
        records = collect_case_records(case_dir; conv_tol=conv_tol)
        out_path = joinpath(out_dir, "findsoln_summary_$(case).txt")
        write_case_summary(out_path, case, meta.Re, meta.Lx, meta.Lz, records)
        wrote += 1
        println("[wrote] $out_path (records=$(length(records)))")
    end
    println("[done] summaries_written=$wrote")
end

main()


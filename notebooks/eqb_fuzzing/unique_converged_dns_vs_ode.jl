import Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))

using DelimitedFiles
using Printf
using Dates

const GROUP_ORDER = ["A", "B", "C", "D", "E", "F", "G"]

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

function fmtfloat(x; digits=7)
    if !isfinite(x)
        return "NaN"
    end
    return @sprintf("%.*g", digits, x)
end

getmetric(stats::Dict{String,Float64}, key::String) = get(stats, key, NaN)

function collect_dns_records(case_dir::AbstractString; conv_tol::Float64=1e-10)
    recs = NamedTuple[]
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
                res = read_last_residual(joinpath(job_dir, "convergence.asc"))
                ubest_ok = isfile(joinpath(job_dir, "ubest.nc"))
                converged = isfinite(res) && res <= conv_tol && ubest_ok
                stats = read_fieldconverge_stats(joinpath(job_dir, "fieldconverge.asc"))
                push!(recs, (
                    group=group,
                    sol_id=sid,
                    J=J,
                    K=K,
                    L=L,
                    job_dir=job_dir,
                    converged=converged,
                    residual=res,
                    shear=getmetric(stats, "wallshear"),
                    L2=getmetric(stats, "L2"),
                ))
            end
        end
    end
    return recs
end

function pick_best_converged_by_solid(dns_records)
    out = Dict{Tuple{String,Int},NamedTuple}()
    for r in dns_records
        r.converged || continue
        key = (r.group, r.sol_id)
        if !haskey(out, key)
            out[key] = r
        else
            b = out[key]
            if (r.J, r.K, r.L) > (b.J, b.K, b.L)
                out[key] = r
            end
        end
    end
    return out
end

function dedupe_group_records(records::Vector{NamedTuple}; shear_tol::Float64=1e-6, l2_tol::Float64=1e-6)
    # records are best-per-sol_id, already converged
    sort!(records; by=r -> (r.shear, r.L2, r.sol_id))
    uniques = Vector{NamedTuple}()
    for r in records
        placed = false
        for i in eachindex(uniques)
            u = uniques[i]
            if abs(r.shear - u.shear) <= shear_tol && abs(r.L2 - u.L2) <= l2_tol
                members = copy(u.members)
                push!(members, (sol_id=r.sol_id, J=r.J, K=r.K, L=r.L, job_dir=r.job_dir))
                uniques[i] = (shear=u.shear, L2=u.L2, members=members)
                placed = true
                break
            end
        end
        if !placed
            push!(uniques, (shear=r.shear, L2=r.L2, members=[(sol_id=r.sol_id, J=r.J, K=r.K, L=r.L, job_dir=r.job_dir)]))
        end
    end
    sort!(uniques; by=u -> u.shear)
    return uniques
end

function read_ode_solutions_summary(path::AbstractString)
    out = Dict{Int,Tuple{Float64,Float64}}() # id => (norm, shear)
    isfile(path) || return out
    lines = readlines(path)
    length(lines) <= 1 && return out
    for ln in lines[2:end]
        s = strip(ln)
        isempty(s) && continue
        vals = split(s, ',')
        length(vals) < 3 && continue
        sid = safeparse(Int, vals[1])
        sid == 0 && continue
        out[sid] = (safeparse(Float64, vals[2]), safeparse(Float64, vals[3]))
    end
    return out
end

function lookup_ode_for_sol(case_dir::AbstractString, group::String, sol_id::Int, J::Int, K::Int, L::Int)
    # First try exact JKL, then highest JKL available for that sol_id.
    exact_path = joinpath(case_dir, group, "jkl_$(J)_$(K)_$(L)", "solutions_summary.csv")
    exact = read_ode_solutions_summary(exact_path)
    if haskey(exact, sol_id)
        norm, shear = exact[sol_id]
        return (found=true, exact=true, J=J, K=K, L=L, norm=norm, shear=shear, source=exact_path)
    end

    group_dir = joinpath(case_dir, group)
    isdir(group_dir) || return (found=false, exact=false, J=0, K=0, L=0, norm=NaN, shear=NaN, source="")

    best = nothing
    for d in readdir(group_dir)
        jkl = parse_jkl(d)
        jkl === nothing && continue
        j2, k2, l2 = jkl
        path = joinpath(group_dir, d, "solutions_summary.csv")
        tbl = read_ode_solutions_summary(path)
        haskey(tbl, sol_id) || continue
        norm, shear = tbl[sol_id]
        rec = (J=j2, K=k2, L=l2, norm=norm, shear=shear, source=path)
        if best === nothing || (rec.J, rec.K, rec.L) > (best.J, best.K, best.L)
            best = rec
        end
    end
    if best === nothing
        return (found=false, exact=false, J=0, K=0, L=0, norm=NaN, shear=NaN, source="")
    end
    return (found=true, exact=false, J=best.J, K=best.K, L=best.L, norm=best.norm, shear=best.shear, source=best.source)
end

function write_unique_summary_txt(out_path::AbstractString, case_label::String, Re, Lx, Lz, best_by_sol, shear_tol, l2_tol)
    by_group = Dict(g => NamedTuple[] for g in GROUP_ORDER)
    for ((g, _), r) in best_by_sol
        push!(by_group[g], r)
    end
    mkpath(dirname(out_path))
    open(out_path, "w") do io
        println(io, "# Unique converged DNS solutions for $(case_label)")
        println(io, "# Box: Lx=$(fmtfloat(Lx; digits=8)), Lz=$(fmtfloat(Lz; digits=8)), Re=$(fmtfloat(Re; digits=8))")
        println(io, "# dedupe tolerances: shear_tol=$(shear_tol), l2_tol=$(l2_tol)")
        println(io, "# generated: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")
        println(io)
        for g in GROUP_ORDER
            recs = by_group[g]
            isempty(recs) && continue
            uniq = dedupe_group_records(recs; shear_tol=shear_tol, l2_tol=l2_tol)
            println(io, "## Group $g")
            for (i, u) in enumerate(uniq)
                println(io, "u$(lpad(string(i), 3, '0')): shear=$(fmtfloat(u.shear; digits=9)), L2=$(fmtfloat(u.L2; digits=9)), multiplicity=$(length(u.members))")
                member_str = join(["sol$(lpad(string(m.sol_id),3,'0'))@J$(m.J)K$(m.K)L$(m.L)" for m in sort(u.members; by=x -> x.sol_id)], ", ")
                println(io, "  members: $member_str")
            end
            println(io)
        end
    end
end

function write_unique_summary_csv(out_path::AbstractString, case_label::String, Re, Lx, Lz, best_by_sol, shear_tol, l2_tol)
    by_group = Dict(g => NamedTuple[] for g in GROUP_ORDER)
    for ((g, _), r) in best_by_sol
        push!(by_group[g], r)
    end
    mkpath(dirname(out_path))
    open(out_path, "w") do io
        println(io, "case,Re,Lx,Lz,group,unique_id,shear,L2,multiplicity,members")
        for g in GROUP_ORDER
            recs = by_group[g]
            isempty(recs) && continue
            uniq = dedupe_group_records(recs; shear_tol=shear_tol, l2_tol=l2_tol)
            for (i, u) in enumerate(uniq)
                member_str = join(["sol$(lpad(string(m.sol_id),3,'0'))@J$(m.J)K$(m.K)L$(m.L)" for m in sort(u.members; by=x -> x.sol_id)], ";")
                println(io, "$(case_label),$(Re),$(Lx),$(Lz),$(g),u$(lpad(string(i),3,'0')),$(u.shear),$(u.L2),$(length(u.members)),$(member_str)")
            end
        end
    end
end

function write_ode_dns_compare_csv(out_path::AbstractString, case_label::String, case_dir::String, Re, Lx, Lz, best_by_sol)
    rows = NamedTuple[]
    for ((g, sid), dns) in sort(collect(best_by_sol); by=x -> (x[1][1], x[1][2]))
        ode = lookup_ode_for_sol(case_dir, g, sid, dns.J, dns.K, dns.L)
        delta_shear = ode.found ? dns.shear - ode.shear : NaN
        delta_l2 = ode.found ? dns.L2 - ode.norm : NaN
        push!(rows, (
            case=case_label,
            Re=Re,
            Lx=Lx,
            Lz=Lz,
            group=g,
            sol_id=sid,
            dns_shear=dns.shear,
            dns_L2=dns.L2,
            dns_residual=dns.residual,
            ode_found=ode.found,
            ode_exact_jkl=ode.exact,
            ode_J=ode.J,
            ode_K=ode.K,
            ode_L=ode.L,
            ode_shear=ode.shear,
            ode_norm=ode.norm,
            delta_shear=delta_shear,
            delta_L2norm=delta_l2,
            ode_source=ode.source,
            dns_source=dns.job_dir,
        ))
    end

    mkpath(dirname(out_path))
    open(out_path, "w") do io
        println(io, "case,Re,Lx,Lz,group,sol_id,dns_shear,dns_L2,dns_residual,ode_found,ode_exact_jkl,ode_J,ode_K,ode_L,ode_shear,ode_norm,delta_shear,delta_L2norm,ode_source,dns_source")
        for r in rows
            println(
                io,
                "$(r.case),$(r.Re),$(r.Lx),$(r.Lz),$(r.group),$(r.sol_id),$(r.dns_shear),$(r.dns_L2),$(r.dns_residual),$(r.ode_found),$(r.ode_exact_jkl),$(r.ode_J),$(r.ode_K),$(r.ode_L),$(r.ode_shear),$(r.ode_norm),$(r.delta_shear),$(r.delta_L2norm),$(r.ode_source),$(r.dns_source)",
            )
        end
    end
end

function write_ode_dns_compare_txt(out_path::AbstractString, case_label::String, Re, Lx, Lz, compare_csv_path::String)
    isfile(compare_csv_path) || return
    lines = readlines(compare_csv_path)
    length(lines) <= 1 && return
    mkpath(dirname(out_path))
    open(out_path, "w") do io
        println(io, "# ODE vs DNS comparison for $(case_label)")
        println(io, "# Box: Lx=$(fmtfloat(Lx; digits=8)), Lz=$(fmtfloat(Lz; digits=8)), Re=$(fmtfloat(Re; digits=8))")
        println(io, "# generated: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")
        println(io)
        println(io, "group, sol_id, dns_shear, dns_L2, ode(JKL), ode_shear, ode_norm, delta_shear, delta_L2")
        for ln in lines[2:end]
            vals = split(ln, ',')
            length(vals) < 20 && continue
            g = vals[5]
            sid = vals[6]
            dnss = vals[7]
            dnsl2 = vals[8]
            odej = "($(vals[12]),$(vals[13]),$(vals[14]))"
            odes = vals[15]
            oden = vals[16]
            ds = vals[17]
            dl2 = vals[18]
            println(io, "$g, $sid, $dnss, $dnsl2, $odej, $odes, $oden, $ds, $dl2")
        end
    end
end

function main()
    args = parse_args(ARGS)
    runs_root = get(args, "runs-root", joinpath(@__DIR__, "overnight_runs_updated"))
    out_dir = get(args, "out-dir", joinpath(runs_root, "analysis", "findsoln_unique"))
    conv_tol = parse(Float64, get(args, "conv-tol", "1e-10"))
    shear_tol = parse(Float64, get(args, "shear-tol", "1e-6"))
    l2_tol = parse(Float64, get(args, "l2-tol", "1e-6"))
    req_cases = parse_case_list(get(args, "cases", ""))

    queue = read_run_queue(runs_root)
    all_cases = sort(collect(keys(queue)))
    if isempty(all_cases)
        all_cases = sort(filter(x -> isdir(joinpath(runs_root, x)), readdir(runs_root)))
    end
    cases = isempty(req_cases) ? all_cases : filter(x -> x in req_cases, all_cases)
    isempty(cases) && error("No matching cases under $runs_root")

    println("== Unique converged DNS + ODE comparison ==")
    println("runs_root=$(runs_root)")
    println("out_dir=$(out_dir)")
    println("cases=$(join(cases, ',')) conv_tol=$(conv_tol) shear_tol=$(shear_tol) l2_tol=$(l2_tol)")

    for case in cases
        meta = get(queue, case, (case_label=case, Re=NaN, Lx=NaN, Lz=NaN, out_dir=joinpath(runs_root, case)))
        case_dir = abspath(meta.out_dir)
        isdir(case_dir) || continue

        dns = collect_dns_records(case_dir; conv_tol=conv_tol)
        best_by_sol = pick_best_converged_by_solid(dns)

        txt_out = joinpath(out_dir, "unique_converged_dns_$(case).txt")
        csv_out = joinpath(out_dir, "unique_converged_dns_$(case).csv")
        cmp_csv_out = joinpath(out_dir, "ode_dns_compare_$(case).csv")
        cmp_txt_out = joinpath(out_dir, "ode_dns_compare_$(case).txt")

        write_unique_summary_txt(txt_out, case, meta.Re, meta.Lx, meta.Lz, best_by_sol, shear_tol, l2_tol)
        write_unique_summary_csv(csv_out, case, meta.Re, meta.Lx, meta.Lz, best_by_sol, shear_tol, l2_tol)
        write_ode_dns_compare_csv(cmp_csv_out, case, case_dir, meta.Re, meta.Lx, meta.Lz, best_by_sol)
        write_ode_dns_compare_txt(cmp_txt_out, case, meta.Re, meta.Lx, meta.Lz, cmp_csv_out)

        println("[wrote] $(txt_out)")
        println("[wrote] $(csv_out)")
        println("[wrote] $(cmp_csv_out)")
        println("[wrote] $(cmp_txt_out)")
    end
    println("[done]")
end

main()

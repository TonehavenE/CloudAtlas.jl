#!/usr/bin/env julia

# Build Re-input continuation curves for the equilibrium catalog and infer
# branch-family connections from overlaps in a common full-basis state space.
#
# Run from the CloudAtlas checkout, or pass --cloudatlas-root explicitly:
#
#   julia --startup-file=no --project=/path/to/CloudAtlas.jl \
#     /path/to/jfm_followup/scripts/catalog_branch_graph.jl \
#     --cloudatlas-root /path/to/CloudAtlas.jl \
#     --catalog-dir /path/to/CloudAtlas.jl/notebooks/eqb_fuzzing/eqb_catalog \
#     --mode all

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
import BifurcationKit as BK
using DelimitedFiles
using Dates
using LinearAlgebra
using Printf

const DEFAULT_HOOKPARAMS = SearchParams(; ftol=1e-8, xtol=1e-10, Nnewton=25, Nhook=6, verbosity=0)
const GROUP_ORDER = ["A", "B", "C", "D", "E", "F", "G"]

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

function append_csv_row(path, values)
    open(path, "a") do io
        println(io, join(csv_escape.(values), ","))
    end
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

function read_vector(path::AbstractString)
    x = readdlm(path; comments=true, comment_char='#')
    return vec(x)
end

function write_vector(path::AbstractString, x::AbstractVector)
    mkpath(dirname(path))
    open(path, "w") do io
        for v in x
            println(io, @sprintf("%.17g", Float64(v)))
        end
    end
end

function parse_member_entry(s)
    m = match(r"^(on|ls):sol(\d+)@J(\d+)K(\d+)L(\d+)$", strip(s))
    m === nothing && return nothing
    return (
        source = m.captures[1],
        sol_id = safeparse(Int, m.captures[2]),
        J = safeparse(Int, m.captures[3]),
        K = safeparse(Int, m.captures[4]),
        L = safeparse(Int, m.captures[5]),
    )
end

function find_best_asc(group_rows, overnight_root, low_shear_root)
    best = nothing
    for r in group_rows
        case = r["case"]
        group = r["group"]
        for entry in split(get(r, "all_members", ""), ';')
            m = parse_member_entry(entry)
            m === nothing && continue
            root = m.source == "on" ? overnight_root : low_shear_root
            asc = joinpath(root, case, group, "jkl_$(m.J)_$(m.K)_$(m.L)", "sol$(m.sol_id).asc")
            isfile(asc) || continue
            jkl = (m.J, m.K, m.L)
            if best === nothing || jkl > best.jkl || (jkl == best.jkl && m.source == "on" && best.source == "ls")
                best = (
                    source = m.source,
                    case = case,
                    group = group,
                    J = m.J,
                    K = m.K,
                    L = m.L,
                    sol_id = m.sol_id,
                    jkl = jkl,
                    asc_path = asc,
                )
            end
        end
    end
    return best
end

function get_state_vector(sol)
    if sol isa AbstractVector
        return collect(sol)
    elseif sol isa NamedTuple
        if haskey(sol, :x)
            return collect(sol.x)
        elseif haskey(sol, :u)
            return collect(sol.u)
        end
    end
    if hasproperty(sol, :x)
        return collect(getproperty(sol, :x))
    elseif hasproperty(sol, :u)
        return collect(getproperty(sol, :u))
    end
    error("Unsupported continuation state type: $(typeof(sol))")
end

function continue_eqb(model, x0, Re0; Re_min, Re_max, max_steps, dsmin, dsmax)
    fp(x, p) = model.f(x, p[1])
    prob = BK.BifurcationProblem(
        fp, x0, [Float64(Re0)], 1;
        record_from_solution = (x, p; k...) -> shear(x, model),
        plot_solution = (x, p; k...) -> shear(x, model),
    )
    newton_opts = BK.NewtonPar(
        1e-10, 25, false, BK.DefaultLS(), BK.DefaultEig(), false, 1.0, 0.01
    )
    cont_opts = BK.ContinuationPar(;
        p_min = Re_min,
        p_max = Re_max,
        n_inversion = 20,
        dsmin = dsmin,
        dsmax = dsmax,
        max_steps = max_steps,
        newton_options = newton_opts,
    )
    return BK.continuation(prob, BK.PALC(), cont_opts; bothside=true)
end

function repolish(model, Re, x0)
    f = x -> model.f(x, Re)
    Df = x -> model.Df(x, Re)
    return hookstepsolve(f, Df, collect(x0), DEFAULT_HOOKPARAMS)
end

function branch_arrays(br)
    Re_vals = hasproperty(br, :branch) ? collect(br.branch.param) : collect(br.param)
    sols = if hasproperty(br, :branch) && hasproperty(br.branch, :sol)
        br.branch.sol
    elseif hasproperty(br, :sol)
        br.sol
    else
        error("No continuation solutions available")
    end
    states = [get_state_vector(sols[i]) for i in eachindex(Re_vals)]
    return Float64.(Re_vals), states
end

function branch_sample_indices(n::Int, stride::Int, max_points::Int)
    stride = max(1, stride)
    idx = collect(1:stride:n)
    if idx[end] != n
        push!(idx, n)
    end
    if max_points > 0 && length(idx) > max_points
        keep = unique(round.(Int, range(1, length(idx), length=max_points)))
        idx = idx[keep]
    end
    return idx
end

function build_jobs(args)
    catalog_dir = abspath(get(args, "catalog-dir", joinpath(CLOUDATLAS_ROOT, "notebooks", "eqb_fuzzing", "eqb_catalog")))
    eqb_root = dirname(catalog_dir)
    overnight_root = abspath(get(args, "overnight-root", joinpath(eqb_root, "overnight_runs_updated")))
    low_shear_root = abspath(get(args, "low-shear-root", joinpath(eqb_root, "low_shear")))
    _, phys_rows = read_csv(joinpath(catalog_dir, "physical_solutions.csv"))
    _, catalog_rows = read_csv(joinpath(catalog_dir, "catalog.csv"))

    selected_cases = Set(parse_list(get(args, "case", "")))
    selected_pids = Set(parse_list(get(args, "physical-id", "")))
    selected_groups = Set(parse_list(get(args, "group", "")))
    limit = safeparse(Int, get(args, "limit", "0"))

    catalog_by_pid = Dict{String, Vector{Dict{String,String}}}()
    for r in catalog_rows
        push!(get!(catalog_by_pid, r["physical_id"], Dict{String,String}[]), r)
    end

    symm_map = symmetry_groups()
    jobs = NamedTuple[]
    skipped = Dict("trivial" => 0, "filtered" => 0, "no_asc" => 0, "bad_group" => 0)
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

        rows = get(catalog_by_pid, pid, Dict{String,String}[])
        if !isempty(selected_groups)
            rows = [r for r in rows if r["group"] in selected_groups]
        end
        rep = find_best_asc(rows, overnight_root, low_shear_root)
        if rep === nothing
            skipped["no_asc"] += 1
            continue
        end
        H = get(symm_map, rep.group, nothing)
        if H === nothing
            skipped["bad_group"] += 1
            continue
        end
        push!(jobs, (
            physical_id = pid,
            case = pr["case"],
            Re = safeparse(Float64, pr["Re"]),
            Lx = safeparse(Float64, pr["Lx"]),
            Lz = safeparse(Float64, pr["Lz"]),
            seed_shear = safeparse(Float64, pr["shear"]),
            seed_L2 = safeparse(Float64, pr["L2"]),
            group = rep.group,
            H = H,
            source = rep.source,
            J = rep.J,
            K = rep.K,
            L = rep.L,
            sol_id = rep.sol_id,
            asc_path = rep.asc_path,
        ))
        if limit > 0 && length(jobs) >= limit
            break
        end
    end
    return catalog_dir, jobs, skipped
end

function run_continue(args)
    catalog_dir, jobs, skipped = build_jobs(args)
    out_dir = abspath(get(args, "out-dir", joinpath(catalog_dir, "branch_graph")))
    curves_dir = joinpath(out_dir, "curves")
    mkpath(curves_dir)

    Re_min = safeparse(Float64, get(args, "Re-min", "100.0"))
    Re_max = safeparse(Float64, get(args, "Re-max", "500.0"))
    max_steps = safeparse(Int, get(args, "max-steps", "2000"))
    dsmin = safeparse(Float64, get(args, "dsmin", "1e-7"))
    dsmax = safeparse(Float64, get(args, "dsmax", "1.0"))
    sample_stride = safeparse(Int, get(args, "sample-stride", "1"))
    max_points = safeparse(Int, get(args, "max-points", "0"))
    resume = parse_bool(args, "resume"; default=true)
    dry_run = parse_bool(args, "dry-run"; default=false)

    summary_path = joinpath(out_dir, "continuation_summary.csv")
    mkpath(out_dir)
    if !resume || !isfile(summary_path)
        open(summary_path, "w") do io
            println(io, "timestamp,physical_id,case,group,J,K,L,source,sol_id,status,n_points,min_Re,max_Re,error,points_csv")
        end
    end

    @info "catalog branch continuation" catalog_dir out_dir n_jobs=length(jobs) skipped
    for (job_i, job) in enumerate(jobs)
        branch_dir = joinpath(curves_dir, job.physical_id)
        points_csv = joinpath(branch_dir, "points.csv")
        if resume && isfile(points_csv) && length(readlines(points_csv)) > 1
            @info "skip existing" physical_id=job.physical_id points_csv
            continue
        end
        if dry_run
            println("[dry] $(job.physical_id) $(job.case) group=$(job.group) J$(job.J)K$(job.K)L$(job.L) $(job.asc_path)")
            append_csv_row(summary_path, (Dates.format(now(), "yyyy-mm-ddTHH:MM:SS"), job.physical_id, job.case, job.group, job.J, job.K, job.L, job.source, job.sol_id, "dry", "", "", "", "", points_csv))
            continue
        end

        status = "ok"
        err = ""
        n_points = 0
        min_Re = NaN
        max_Re = NaN
        try
            mkpath(branch_dir)
            alpha = 2π / job.Lx
            gamma = 2π / job.Lz
            model = ODEModel(alpha, gamma, job.J, job.K, job.L, job.H; normalize=false, tw=false)
            x0 = read_vector(job.asc_path)
            x0p, conv = repolish(model, job.Re, x0)
            if !conv
                status = "repolish_fail"
            else
                br = continue_eqb(
                    model, x0p, job.Re;
                    Re_min = Re_min,
                    Re_max = Re_max,
                    max_steps = max_steps,
                    dsmin = dsmin,
                    dsmax = dsmax,
                )
                Re_vals, states = branch_arrays(br)
                idx = branch_sample_indices(length(Re_vals), sample_stride, max_points)
                open(points_csv, "w") do io
                    println(io, "point_id,physical_id,case,group,J,K,L,source,sol_id,seed_Re,Lx,Lz,step,Re,shear,norm,state_path")
                end
                for (local_step, k) in enumerate(idx)
                    x = states[k]
                    state_path = joinpath(branch_dir, "states", @sprintf("point_%05d.asc", local_step))
                    write_vector(state_path, x)
                    append_csv_row(
                        points_csv,
                        (
                            @sprintf("%s_p%05d", job.physical_id, local_step),
                            job.physical_id, job.case, job.group, job.J, job.K, job.L,
                            job.source, job.sol_id, job.Re, job.Lx, job.Lz, k,
                            Re_vals[k], shear(x, model), norm(x), state_path,
                        ),
                    )
                end
                n_points = length(idx)
                min_Re = minimum(Re_vals)
                max_Re = maximum(Re_vals)
            end
        catch e
            status = "fail"
            err = replace(sprint(showerror, e), ',' => ';', '\n' => ' ')
        end
        append_csv_row(summary_path, (Dates.format(now(), "yyyy-mm-ddTHH:MM:SS"), job.physical_id, job.case, job.group, job.J, job.K, job.L, job.source, job.sol_id, status, n_points, min_Re, max_Re, err, points_csv))
        println("[$job_i/$(length(jobs))] $(job.physical_id) status=$status points=$n_points min_Re=$(isnan(min_Re) ? "NA" : @sprintf("%.3f", min_Re))")
    end
end

struct BranchPoint
    point_id::String
    physical_id::String
    case::String
    group::String
    J::Int
    K::Int
    L::Int
    Re::Float64
    shear::Float64
    state_path::String
    x_common::Vector{Float64}
end

function load_branch_points(args)
    catalog_dir = abspath(get(args, "catalog-dir", joinpath(CLOUDATLAS_ROOT, "notebooks", "eqb_fuzzing", "eqb_catalog")))
    out_dir = abspath(get(args, "out-dir", joinpath(catalog_dir, "branch_graph")))
    curves_dir = joinpath(out_dir, "curves")
    isdir(curves_dir) || error("No curves directory found: $curves_dir")

    selected_cases = Set(parse_list(get(args, "case", "")))
    selected_pids = Set(parse_list(get(args, "physical-id", "")))
    compare_J = safeparse(Int, get(args, "compare-J", "3"))
    compare_K = safeparse(Int, get(args, "compare-K", "5"))
    compare_L = safeparse(Int, get(args, "compare-L", "11"))

    models = Dict{Tuple{String,String,Int,Int,Int}, ODEModel}()
    target_models = Dict{String, ODEModel}()
    by_case = Dict{String, Vector{BranchPoint}}()

    for pid_dir in sort(readdir(curves_dir; join=true))
        isdir(pid_dir) || continue
        points_csv = joinpath(pid_dir, "points.csv")
        isfile(points_csv) || continue
        _, rows = read_csv(points_csv)
        for r in rows
            case = r["case"]
            pid = r["physical_id"]
            if !isempty(selected_cases) && !(case in selected_cases)
                continue
            end
            if !isempty(selected_pids) && !(pid in selected_pids)
                continue
            end
            group = r["group"]
            J = safeparse(Int, r["J"])
            K = safeparse(Int, r["K"])
            L = safeparse(Int, r["L"])
            Lx = safeparse(Float64, r["Lx"])
            Lz = safeparse(Float64, r["Lz"])
            alpha = 2π / Lx
            gamma = 2π / Lz
            symm_map = symmetry_groups()
            src_key = (case, group, J, K, L)
            src_model = get!(models, src_key) do
                ODEModel(alpha, gamma, J, K, L, symm_map[group]; normalize=false, tw=false)
            end
            target_model = get!(target_models, case) do
                ODEModel(alpha, gamma, compare_J, compare_K, compare_L, Symmetry[]; normalize=false, tw=false)
            end
            x = read_vector(r["state_path"])
            x_common = changebasis(x, src_model.ijkl, target_model.ijkl)
            push!(
                get!(by_case, case, BranchPoint[]),
                BranchPoint(
                    r["point_id"], pid, case, group, J, K, L,
                    safeparse(Float64, r["Re"]), safeparse(Float64, r["shear"]),
                    r["state_path"], Float64.(x_common),
                ),
            )
        end
    end
    return out_dir, by_case, target_models
end

function bnorm(model, x)
    v = dot(x, model.B * x)
    return sqrt(max(v, 0.0))
end

function state_distance(model, x, y; shift_grid::Int=0)
    nx = max(bnorm(model, x), eps())
    best = bnorm(model, x - y) / nx
    if shift_grid > 0
        vals = range(0.0, 1.0; length=shift_grid + 1)[1:end-1]
        for ax in vals, az in vals
            ys = apply_continuous_shift(y, model, ax, az)
            best = min(best, bnorm(model, x - ys) / nx)
        end
    end
    return best
end

function branch_pair_score(points_a, points_b, model; re_tol, shear_tol, shift_grid)
    n_matches = 0
    best_dist = Inf
    best_re_gap = Inf
    best_shear_gap = Inf
    for pa in points_a
        local_best = Inf
        local_re_gap = Inf
        local_shear_gap = Inf
        for pb in points_b
            re_gap = abs(pa.Re - pb.Re)
            re_gap <= re_tol || continue
            shear_gap = abs(pa.shear - pb.shear)
            shear_gap <= shear_tol || continue
            d = state_distance(model, pa.x_common, pb.x_common; shift_grid=shift_grid)
            if d < local_best
                local_best = d
                local_re_gap = re_gap
                local_shear_gap = shear_gap
            end
        end
        if isfinite(local_best)
            n_matches += 1
            if local_best < best_dist
                best_dist = local_best
                best_re_gap = local_re_gap
                best_shear_gap = local_shear_gap
            end
        end
    end
    return n_matches, best_dist, best_re_gap, best_shear_gap
end

mutable struct UnionFind
    parent::Dict{String,String}
end

function findroot!(uf::UnionFind, x::String)
    if !haskey(uf.parent, x)
        uf.parent[x] = x
        return x
    end
    p = uf.parent[x]
    if p != x
        uf.parent[x] = findroot!(uf, p)
    end
    return uf.parent[x]
end

function union!(uf::UnionFind, a::String, b::String)
    ra = findroot!(uf, a)
    rb = findroot!(uf, b)
    if ra != rb
        keep, drop = ra < rb ? (ra, rb) : (rb, ra)
        uf.parent[drop] = keep
    end
end

function run_analyze(args)
    out_dir, by_case, target_models = load_branch_points(args)
    graph_dir = joinpath(out_dir, "graph")
    mkpath(graph_dir)

    re_tol = safeparse(Float64, get(args, "match-Re-tol", "0.5"))
    shear_tol = safeparse(Float64, get(args, "match-shear-tol", "0.02"))
    state_tol = safeparse(Float64, get(args, "match-state-tol", "1e-3"))
    min_matches = safeparse(Int, get(args, "min-matches", "2"))
    shift_grid = safeparse(Int, get(args, "shift-grid", "0"))

    edges_csv = joinpath(graph_dir, "branch_edges.csv")
    families_csv = joinpath(graph_dir, "branch_families.csv")
    members_csv = joinpath(graph_dir, "branch_family_members.csv")
    open(edges_csv, "w") do io
        println(io, "case,physical_id_a,physical_id_b,linked,n_matches,best_state_dist,best_Re_gap,best_shear_gap,group_a,group_b")
    end

    uf = UnionFind(Dict{String,String}())
    branch_meta = Dict{String, NamedTuple}()

    for case in sort(collect(keys(by_case)))
        points = by_case[case]
        model = target_models[case]
        by_pid = Dict{String, Vector{BranchPoint}}()
        for p in points
            push!(get!(by_pid, p.physical_id, BranchPoint[]), p)
        end
        pids = sort(collect(keys(by_pid)))
        for pid in pids
            ps = by_pid[pid]
            findroot!(uf, "$case/$pid")
            branch_meta["$case/$pid"] = (
                case = case,
                physical_id = pid,
                group = ps[1].group,
                n_points = length(ps),
                min_Re = minimum(p.Re for p in ps),
                max_Re = maximum(p.Re for p in ps),
                min_shear = minimum(p.shear for p in ps),
                max_shear = maximum(p.shear for p in ps),
            )
        end
        for i in 1:max(length(pids) - 1, 0)
            for j in (i + 1):length(pids)
                a, b = pids[i], pids[j]
                pa, pb = by_pid[a], by_pid[b]
                # Skip if Re intervals do not overlap within tolerance.
                if maximum(p.Re for p in pa) + re_tol < minimum(p.Re for p in pb) ||
                   maximum(p.Re for p in pb) + re_tol < minimum(p.Re for p in pa)
                    continue
                end
                n1, d1, rg1, sg1 = branch_pair_score(pa, pb, model; re_tol=re_tol, shear_tol=shear_tol, shift_grid=shift_grid)
                n2, d2, rg2, sg2 = branch_pair_score(pb, pa, model; re_tol=re_tol, shear_tol=shear_tol, shift_grid=shift_grid)
                n_matches = max(n1, n2)
                if d1 <= d2
                    best_dist, best_re_gap, best_shear_gap = d1, rg1, sg1
                else
                    best_dist, best_re_gap, best_shear_gap = d2, rg2, sg2
                end
                linked = n_matches >= min_matches && best_dist <= state_tol
                if linked
                    union!(uf, "$case/$a", "$case/$b")
                end
                append_csv_row(edges_csv, (case, a, b, linked, n_matches, best_dist, best_re_gap, best_shear_gap, pa[1].group, pb[1].group))
            end
        end
    end

    families = Dict{String, Vector{String}}()
    for key in keys(branch_meta)
        push!(get!(families, findroot!(uf, key), String[]), key)
    end

    open(families_csv, "w") do io
        println(io, "family_id,case,n_members,members,min_Re,max_Re,min_shear,max_shear,groups")
    end
    open(members_csv, "w") do io
        println(io, "family_id,case,physical_id,group,n_points,min_Re,max_Re,min_shear,max_shear")
    end

    for (family_i, root) in enumerate(sort(collect(keys(families))))
        keys_in_family = sort(families[root])
        metas = [branch_meta[k] for k in keys_in_family]
        case = metas[1].case
        family_id = @sprintf("family_%03d", family_i)
        members = [m.physical_id for m in metas]
        groups = sort(unique(m.group for m in metas))
        append_csv_row(
            families_csv,
            (
                family_id, case, length(metas), join(members, ";"),
                minimum(m.min_Re for m in metas), maximum(m.max_Re for m in metas),
                minimum(m.min_shear for m in metas), maximum(m.max_shear for m in metas),
                join(groups, ";"),
            ),
        )
        for m in metas
            append_csv_row(members_csv, (family_id, m.case, m.physical_id, m.group, m.n_points, m.min_Re, m.max_Re, m.min_shear, m.max_shear))
        end
    end

    println("Wrote:")
    println("  $edges_csv")
    println("  $families_csv")
    println("  $members_csv")
end

function main()
    args = ARGS_DICT
    mode = lowercase(get(args, "mode", "all"))
    mode in ("continue", "analyze", "all") || error("--mode must be continue, analyze, or all")
    if mode in ("continue", "all")
        run_continue(args)
    end
    if mode in ("analyze", "all")
        run_analyze(args)
    end
end

main()

import Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))

using Printf
using Dates

# ─────────────────────────────────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────────────────────────────────

const GROUP_ORDER = ["A", "B", "C", "D", "E", "F", "G"]

const GROUP_SYMMS = Dict(
    "A" => "<sxyz, txz>",
    "B" => "<sxy, sz>",
    "C" => "<sxytz, sz>",
    "D" => "<sxy, sztx>",
    "E" => "<sxyz, sztxz>",
    "F" => "<sxy, sz, txz>",
    "G" => "<sxyz>",
)

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
                out[key] = "true"
                i += 1
            else
                out[key] = args[i+1]
                i += 2
            end
        else
            i += 1
        end
    end
    return out
end

safeparse(::Type{Float64}, s) = try parse(Float64, strip(string(s))) catch; NaN end
safeparse(::Type{Int}, s)     = try parse(Int,     strip(string(s))) catch; 0   end

# ─────────────────────────────────────────────────────────────────────────────
# CSV helpers
# ─────────────────────────────────────────────────────────────────────────────

function read_csv(path)
    isfile(path) || return String[], Vector{Dict{String,String}}()
    lines = readlines(path)
    isempty(lines) && return String[], Vector{Dict{String,String}}()
    header = split(chomp(lines[1]), ',')
    rows = Dict{String,String}[]
    for ln in lines[2:end]
        s = chomp(ln)
        isempty(strip(s)) && continue
        vals = split(s, ',')
        row = Dict{String,String}()
        for i in eachindex(header)
            row[header[i]] = i <= length(vals) ? vals[i] : ""
        end
        push!(rows, row)
    end
    return header, rows
end

# ─────────────────────────────────────────────────────────────────────────────
# Member string parsing: "sol001@J3K5L11" → (sol_id=1, J=3, K=5, L=11)
# ─────────────────────────────────────────────────────────────────────────────

function parse_member(s)
    m = match(r"^sol(\d+)@J(\d+)K(\d+)L(\d+)$", strip(s))
    m === nothing && return nothing
    return (
        sol_id = safeparse(Int, m.captures[1]),
        J      = safeparse(Int, m.captures[2]),
        K      = safeparse(Int, m.captures[3]),
        L      = safeparse(Int, m.captures[4]),
    )
end

function parse_members(members_str)
    parts = split(strip(members_str), ';')
    out = NamedTuple[]
    for p in parts
        m = parse_member(p)
        m !== nothing && push!(out, m)
    end
    return out
end

# ─────────────────────────────────────────────────────────────────────────────
# Reconstruct ubest.nc path from run root + case + group + member
# ─────────────────────────────────────────────────────────────────────────────

function ubest_path(runs_root, case, group, m)
    joinpath(
        runs_root, case, group,
        "jkl_$(m.J)_$(m.K)_$(m.L)",
        "dns_findsoln",
        "sol$(lpad(string(m.sol_id), 3, '0'))",
        "ubest.nc",
    )
end

# Return the member with the highest (J,K,L) that has a real ubest.nc file.
function best_ubest(runs_root, case, group, members)
    sorted = sort(members; by = m -> (m.J, m.K, m.L), rev = true)
    for m in sorted
        p = ubest_path(runs_root, case, group, m)
        isfile(p) && return p
    end
    # Fallback: highest JKL even if file missing
    isempty(sorted) && return ""
    m = first(sorted)
    return ubest_path(runs_root, case, group, m)
end

# ─────────────────────────────────────────────────────────────────────────────
# Read unique solution CSV for one case from one run's analysis dir
# Returns: Vector of (group, shear, L2, members_str)
# ─────────────────────────────────────────────────────────────────────────────

function read_unique_csv(analysis_dir, case)
    path = joinpath(analysis_dir, "unique_converged_dns_$(case).csv")
    _, rows = read_csv(path)
    out = NamedTuple[]
    for r in rows
        g = get(r, "group", "")
        g in GROUP_ORDER || continue
        shear = safeparse(Float64, get(r, "shear", "NaN"))
        L2    = safeparse(Float64, get(r, "L2", "NaN"))
        (isnan(shear) || isnan(L2)) && continue
        members_str = get(r, "members", "")
        push!(out, (group=g, shear=shear, L2=L2, members_str=members_str))
    end
    return out
end

# ─────────────────────────────────────────────────────────────────────────────
# Cross-run merge for a single (case, group)
#
# For each unique entry in overnight and low_shear, match by (shear, L2)
# within `tol`. Produce merged entries with source tagging.
# ─────────────────────────────────────────────────────────────────────────────

function merge_run_entries(on_entries, ls_entries; tol=1e-4)
    # on_entries / ls_entries: vectors of (shear, L2, members_str) for one group
    on_matched = falses(length(on_entries))
    ls_matched = falses(length(ls_entries))

    merged = NamedTuple[]

    for (i, a) in enumerate(on_entries)
        # find matching low_shear entry
        match_j = 0
        for j in eachindex(ls_entries)
            ls_matched[j] && continue
            b = ls_entries[j]
            if abs(a.shear - b.shear) <= tol && abs(a.L2 - b.L2) <= tol
                match_j = j
                break
            end
        end
        if match_j > 0
            b = ls_entries[match_j]
            ls_matched[match_j] = true
            on_matched[i] = true
            push!(merged, (
                shear            = a.shear,
                L2               = a.L2,
                source           = "both",
                overnight_members = a.members_str,
                low_shear_members = b.members_str,
            ))
        end
    end

    # overnight-only
    for (i, a) in enumerate(on_entries)
        on_matched[i] && continue
        push!(merged, (
            shear            = a.shear,
            L2               = a.L2,
            source           = "overnight",
            overnight_members = a.members_str,
            low_shear_members = "",
        ))
    end

    # low_shear-only
    for (j, b) in enumerate(ls_entries)
        ls_matched[j] && continue
        push!(merged, (
            shear            = b.shear,
            L2               = b.L2,
            source           = "low_shear",
            overnight_members = "",
            low_shear_members = b.members_str,
        ))
    end

    sort!(merged; by = e -> e.shear)
    return merged
end

# ─────────────────────────────────────────────────────────────────────────────
# Cross-group clustering within a case
#
# Assigns a physical_id to each (group, shear, L2) entry. Entries with the
# same (shear, L2) across different groups represent the same equilibrium.
# Returns a Dict: (group, entry_index) => physical_id (Int)
# ─────────────────────────────────────────────────────────────────────────────

function assign_cross_group_ids(per_group_merged; tol=1e-4)
    # Collect all (group, idx, shear, L2) tuples
    all_entries = NamedTuple[]
    for g in GROUP_ORDER
        haskey(per_group_merged, g) || continue
        for (i, e) in enumerate(per_group_merged[g])
            push!(all_entries, (group=g, idx=i, shear=e.shear, L2=e.L2))
        end
    end

    n = length(all_entries)
    cluster_id = zeros(Int, n)
    next_id = 1

    for i in 1:n
        cluster_id[i] != 0 && continue
        cluster_id[i] = next_id
        a = all_entries[i]
        for j in (i+1):n
            cluster_id[j] != 0 && continue
            b = all_entries[j]
            if abs(a.shear - b.shear) <= tol && abs(a.L2 - b.L2) <= tol
                cluster_id[j] = next_id
            end
        end
        next_id += 1
    end

    # Build lookup: (group, idx) => physical_id
    lookup = Dict{Tuple{String,Int},Int}()
    for (i, e) in enumerate(all_entries)
        lookup[(e.group, e.idx)] = cluster_id[i]
    end

    # Physical clusters: physical_id => list of (group, shear, L2)
    clusters = Dict{Int,Vector{NamedTuple}}()
    for (i, e) in enumerate(all_entries)
        pid = cluster_id[i]
        push!(get!(clusters, pid, NamedTuple[]), (group=e.group, shear=e.shear, L2=e.L2))
    end

    return lookup, clusters
end

# ─────────────────────────────────────────────────────────────────────────────
# Format members string for output
# ─────────────────────────────────────────────────────────────────────────────

fmt_members(s, prefix) = isempty(s) ? "" : join(["$(prefix):$m" for m in split(s, ';')], ";")

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

function main()
    args = parse_args(ARGS)
    base        = @__DIR__
    on_root     = abspath(get(args, "overnight-root", joinpath(base, "overnight_runs_updated")))
    ls_root     = abspath(get(args, "low-shear-root", joinpath(base, "low_shear")))
    out_dir     = abspath(get(args, "out-dir",        joinpath(base, "eqb_catalog")))
    cross_tol   = safeparse(Float64, get(args, "cross-tol", "1e-4"))
    trivial_tol = safeparse(Float64, get(args, "trivial-tol", "1e-8"))

    on_analysis = joinpath(on_root, "analysis", "findsoln_unique")
    ls_analysis = joinpath(ls_root, "analysis", "findsoln_unique")

    # Discover cases from run_queue_summary.csv files
    function read_cases(root)
        queue = joinpath(root, "run_queue_summary.csv")
        _, rows = read_csv(queue)
        cases = Dict{String,NamedTuple}()
        for r in rows
            c = get(r, "case_label", "")
            isempty(c) && continue
            cases[c] = (
                case  = c,
                Re    = safeparse(Float64, get(r, "Re",  "NaN")),
                Lx    = safeparse(Float64, get(r, "Lx",  "NaN")),
                Lz    = safeparse(Float64, get(r, "Lz",  "NaN")),
            )
        end
        return cases
    end

    on_cases = read_cases(on_root)
    ls_cases = read_cases(ls_root)
    all_cases = sort(collect(union(keys(on_cases), keys(ls_cases))))

    mkpath(out_dir)

    catalog_rows  = NamedTuple[]   # per (case, group, merged_entry)
    physical_rows = NamedTuple[]   # per (case, physical_id)

    println("== Building combined EQB catalog ==")
    println("overnight root : $on_root")
    println("low_shear root : $ls_root")
    println("output dir     : $out_dir")
    println("cross_tol      : $cross_tol")
    println()

    for case in all_cases
        meta = get(on_cases, case, get(ls_cases, case, (case=case, Re=NaN, Lx=NaN, Lz=NaN)))
        Re, Lx, Lz = meta.Re, meta.Lx, meta.Lz

        on_entries = read_unique_csv(on_analysis, case)  # all groups
        ls_entries = read_unique_csv(ls_analysis, case)

        # Split by group
        on_by_group = Dict(g => filter(e -> e.group == g, on_entries) for g in GROUP_ORDER)
        ls_by_group = Dict(g => filter(e -> e.group == g, ls_entries) for g in GROUP_ORDER)

        per_group_merged = Dict{String,Vector{NamedTuple}}()
        for g in GROUP_ORDER
            on_g = on_by_group[g]
            ls_g = ls_by_group[g]
            merged = merge_run_entries(on_g, ls_g; tol=cross_tol)
            per_group_merged[g] = merged
        end

        # Cross-group physical ID assignment
        gid_lookup, _ = assign_cross_group_ids(per_group_merged; tol=cross_tol)

        # Number physical clusters in shear order
        # Collect representative (shear, L2) per cluster
        cluster_rep = Dict{Int, Float64}()  # cluster_id => representative shear
        for g in GROUP_ORDER
            haskey(per_group_merged, g) || continue
            for (i, e) in enumerate(per_group_merged[g])
                pid = get(gid_lookup, (g, i), 0)
                pid == 0 && continue
                if !haskey(cluster_rep, pid)
                    cluster_rep[pid] = e.shear
                end
            end
        end
        sorted_pids = sort(collect(keys(cluster_rep)); by = pid -> cluster_rep[pid])
        pid_rank = Dict(pid => rank for (rank, pid) in enumerate(sorted_pids))

        n_on = count(e -> e.group in GROUP_ORDER, on_entries)
        n_ls = count(e -> e.group in GROUP_ORDER, ls_entries)
        total_merged = sum(length(v) for v in values(per_group_merged))
        n_phys = length(sorted_pids)
        println("Case: $case (Re=$Re, Lx=$(round(Lx,digits=3)), Lz=$(round(Lz,digits=3)))")
        println("  overnight unique: $n_on  |  low_shear unique: $n_ls  |  combined: $total_merged  |  physical solutions: $n_phys")

        # Build catalog rows and physical rows
        for g in GROUP_ORDER
            haskey(per_group_merged, g) || continue
            for (i, e) in enumerate(per_group_merged[g])
                pid = get(gid_lookup, (g, i), 0)
                rank = get(pid_rank, pid, 0)
                physical_id = @sprintf("%s_%03d", case, rank)
                is_trivial = abs(e.shear) <= trivial_tol && abs(e.L2) <= trivial_tol

                # Parse members to find best ubest.nc
                on_mems = parse_members(e.overnight_members)
                ls_mems = parse_members(e.low_shear_members)

                on_ubest = isempty(on_mems) ? "" : best_ubest(on_root, case, g, on_mems)
                ls_ubest = isempty(ls_mems) ? "" : best_ubest(ls_root, case, g, ls_mems)

                # Prefer overnight (higher resolution) if file exists
                rep_ubest = if !isempty(on_ubest) && isfile(on_ubest)
                    on_ubest
                elseif !isempty(ls_ubest) && isfile(ls_ubest)
                    ls_ubest
                else
                    on_ubest  # fallback even if missing
                end

                # Annotated member strings for output
                all_members = join(filter(!isempty, [
                    isempty(e.overnight_members) ? "" : join(["on:$m" for m in split(e.overnight_members, ';')], ";"),
                    isempty(e.low_shear_members)  ? "" : join(["ls:$m" for m in split(e.low_shear_members,  ';')], ";"),
                ]), ";")

                push!(catalog_rows, (
                    physical_id      = physical_id,
                    case             = case,
                    Re               = Re,
                    Lx               = Lx,
                    Lz               = Lz,
                    group            = g,
                    symmetry         = GROUP_SYMMS[g],
                    shear            = e.shear,
                    L2               = e.L2,
                    is_trivial       = is_trivial,
                    source           = e.source,
                    representative_ubest = rep_ubest,
                    all_members      = all_members,
                ))
            end
        end

        # Physical solutions summary per case
        added_pids = Set{Int}()
        for g in GROUP_ORDER
            haskey(per_group_merged, g) || continue
            for (i, e) in enumerate(per_group_merged[g])
                pid = get(gid_lookup, (g, i), 0)
                pid in added_pids && continue
                push!(added_pids, pid)
                rank = get(pid_rank, pid, 0)
                physical_id = @sprintf("%s_%03d", case, rank)
                is_trivial = abs(e.shear) <= trivial_tol && abs(e.L2) <= trivial_tol

                # All groups this solution appears in (in shear-sorted order)
                groups_for_pid = sort(unique([
                    g2
                    for g2 in GROUP_ORDER
                    for (i2, e2) in enumerate(get(per_group_merged, g2, NamedTuple[]))
                    if get(gid_lookup, (g2, i2), -1) == pid
                ]))

                # Determine source across all groups
                sources = Set{String}()
                for g2 in groups_for_pid
                    for (i2, e2) in enumerate(get(per_group_merged, g2, NamedTuple[]))
                        get(gid_lookup, (g2, i2), -1) == pid || continue
                        push!(sources, e2.source)
                    end
                end
                combined_source = if "both" in sources || ("overnight" in sources && "low_shear" in sources)
                    "both"
                elseif "overnight" in sources
                    "overnight"
                else
                    "low_shear"
                end

                # Best ubest.nc: scan all groups, prefer highest JKL from overnight
                best_path = ""
                best_jkl  = (-1, -1, -1)
                for g2 in groups_for_pid
                    for (i2, e2) in enumerate(get(per_group_merged, g2, NamedTuple[]))
                        get(gid_lookup, (g2, i2), -1) == pid || continue
                        for (run_root, mems_str) in [(on_root, e2.overnight_members), (ls_root, e2.low_shear_members)]
                            isempty(mems_str) && continue
                            for m in parse_members(mems_str)
                                p = ubest_path(run_root, case, g2, m)
                                isfile(p) || continue
                                if (m.J, m.K, m.L) > best_jkl
                                    best_jkl  = (m.J, m.K, m.L)
                                    best_path = p
                                end
                            end
                        end
                    end
                end

                push!(physical_rows, (
                    physical_id      = physical_id,
                    case             = case,
                    Re               = Re,
                    Lx               = Lx,
                    Lz               = Lz,
                    shear            = e.shear,
                    L2               = e.L2,
                    is_trivial       = is_trivial,
                    source           = combined_source,
                    groups           = join(groups_for_pid, ","),
                    n_groups         = length(groups_for_pid),
                    representative_ubest = best_path,
                ))
            end
        end

        println()
    end

    # ──────────────────────────────────────────────────────────────────────────
    # Write catalog.csv  (per case+group entry)
    # ──────────────────────────────────────────────────────────────────────────
    catalog_path = joinpath(out_dir, "catalog.csv")
    open(catalog_path, "w") do io
        println(io, "physical_id,case,Re,Lx,Lz,group,symmetry,shear,L2,is_trivial,source,representative_ubest,all_members")
        for r in catalog_rows
            println(io, join([
                r.physical_id, r.case, r.Re, r.Lx, r.Lz,
                r.group, "\"$(r.symmetry)\"",
                r.shear, r.L2, r.is_trivial,
                r.source, r.representative_ubest,
                "\"$(r.all_members)\"",
            ], ","))
        end
    end
    println("[wrote] $catalog_path ($(length(catalog_rows)) group-level entries)")

    # ──────────────────────────────────────────────────────────────────────────
    # Write physical_solutions.csv  (one row per physical solution)
    # ──────────────────────────────────────────────────────────────────────────
    phys_path = joinpath(out_dir, "physical_solutions.csv")
    open(phys_path, "w") do io
        println(io, "physical_id,case,Re,Lx,Lz,shear,L2,is_trivial,source,groups,n_groups,representative_ubest")
        for r in physical_rows
            println(io, join([
                r.physical_id, r.case, r.Re, r.Lx, r.Lz,
                r.shear, r.L2, r.is_trivial,
                r.source, "\"$(r.groups)\"", r.n_groups,
                r.representative_ubest,
            ], ","))
        end
    end
    println("[wrote] $phys_path ($(length(physical_rows)) physical solutions)")

    # ──────────────────────────────────────────────────────────────────────────
    # Print summary
    # ──────────────────────────────────────────────────────────────────────────
    println()
    println("=== Summary ===")
    println("Total group-level entries : $(length(catalog_rows))")
    println("Total physical solutions  : $(length(physical_rows))")
    println()

    # Per-source breakdown of physical solutions
    n_on   = count(r -> r.source == "overnight",  physical_rows)
    n_ls   = count(r -> r.source == "low_shear",  physical_rows)
    n_both = count(r -> r.source == "both",        physical_rows)
    n_triv = count(r -> r.is_trivial,              physical_rows)
    println("  overnight only : $n_on")
    println("  low_shear only : $n_ls")
    println("  both runs      : $n_both")
    println("  trivial (u≈0)  : $n_triv")
    println()

    # Per-case breakdown
    println("Per case:")
    for case in all_cases
        phys = filter(r -> r.case == case, physical_rows)
        n_total = length(phys)
        n_multi = count(r -> r.n_groups > 1, phys)
        n_t = count(r -> r.is_trivial, phys)
        println("  $case : $n_total physical solutions ($n_multi appear in >1 group, $n_t trivial)")
    end

    println()
    println("[done]")
end

main()

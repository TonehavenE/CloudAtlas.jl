import Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))

using DelimitedFiles
using Dates
using LinearAlgebra
using Printf
using Random
using Statistics
using Base.Threads

include(joinpath(@__DIR__, "promote_continue_ode_grid.jl"))

"""
DNS-matched ODE continuation workflow.

1. Pick an existing ODE seed (default: lowest min-Re in group E at 1-3-5)
2. Promote along the ladder to a target discretization (default: 2-4-7)
3. Continue at exact DNS geometry points from re_min_grid_map.csv (target_* or point_*)
4. Save every successful ODE solution immediately and keep progress CSVs for resume
"""

function parse_csv_rows(path::AbstractString)
    isfile(path) || error("Missing CSV: $path")
    lines = readlines(path)
    isempty(lines) && return String[], Vector{Dict{String,String}}()
    header = split(chomp(lines[1]), ',')
    rows = Vector{Dict{String,String}}()
    for line in lines[2:end]
        s = chomp(line)
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

function parse_status_set(args::Dict{String,String})
    raw = get(args, "dns-status", "ok")
    Set(strip.(split(raw, ",")))
end

function load_dns_targets(args::Dict{String,String})
    csv_path = get(
        args,
        "dns-csv",
        joinpath(
            @__DIR__,
            "eqb_alpha_gamma_grid",
            "dns_space_map",
            "grid_map",
            "E",
            "re_min_grid_map.csv",
        ),
    )
    geom_source = lowercase(get(args, "geom-source", "target")) # target | point
    geom_source in ("target", "point") || error("--geom-source must be target or point")
    statuses = parse_status_set(args)

    _, rows = parse_csv_rows(csv_path)
    targets = NamedTuple[]
    seen = Set{Tuple{Float64,Float64}}()
    for row in rows
        group = get(row, "group", "")
        group == "E" || continue
        status = get(row, "status", "")
        status in statuses || continue

        Lx = NaN
        Lz = NaN
        if geom_source == "point"
            Lx = safeparse(Float64, get(row, "point_Lx", ""))
            Lz = safeparse(Float64, get(row, "point_Lz", ""))
            if !isfinite(Lx) || !isfinite(Lz)
                # fall back if point geometry is missing
                Lx = safeparse(Float64, get(row, "target_Lx", ""))
                Lz = safeparse(Float64, get(row, "target_Lz", ""))
            end
        else
            Lx = safeparse(Float64, get(row, "target_Lx", ""))
            Lz = safeparse(Float64, get(row, "target_Lz", ""))
        end
        isfinite(Lx) && isfinite(Lz) || continue
        Lxk = round_key(Lx)
        Lzk = round_key(Lz)
        key = (Lxk, Lzk)
        key in seen && continue
        push!(seen, key)
        push!(
            targets,
            (
                Lx=Lx,
                Lz=Lz,
                Lxk=Lxk,
                Lzk=Lzk,
                dns_status=status,
                dns_min_Re=safeparse(Float64, get(row, "min_Re", "")),
                ix=safeparse(Int, get(row, "ix", "")),
                iz=safeparse(Int, get(row, "iz", "")),
                re_out_dir=get(row, "re_out_dir", ""),
            ),
        )
    end
    sort!(targets; by=t -> (t.Lx, t.Lz))
    return (csv_path=csv_path, geom_source=geom_source, statuses=statuses, targets=targets)
end

function nearest_neighbor_distance(points)
    n = length(points)
    n < 2 && return Inf
    dmins = Float64[]
    for i in 1:n
        pi = points[i]
        dmin = Inf
        for j in 1:n
            i == j && continue
            pj = points[j]
            d = hypot(pi.Lx - pj.Lx, pi.Lz - pj.Lz)
            dmin = min(dmin, d)
        end
        isfinite(dmin) && push!(dmins, dmin)
    end
    isempty(dmins) && return Inf
    return median(dmins)
end

function threaded_map(candidates::Vector, nworkers::Int, fn)
    isempty(candidates) && return Any[]
    out = Vector{Any}(undef, length(candidates))
    ch = Channel{Int}(length(candidates))
    for i in eachindex(candidates)
        put!(ch, i)
    end
    close(ch)
    @sync for _ in 1:min(nworkers, length(candidates))
        Threads.@spawn begin
            for i in ch
                out[i] = fn(candidates[i], i)
            end
        end
    end
    return out
end

threaded_map(fn, candidates::Vector, nworkers::Int) = threaded_map(candidates, nworkers, fn)

function bootstrap_existing_dnsmatched(out_dir::String, targets::Vector, group_prefix::String)
    solved_state = Dict{Tuple{Float64,Float64}, Vector{Float64}}()
    solved_targets = Set{Tuple{Float64,Float64}}()
    target_keys = Set((t.Lxk, t.Lzk) for t in targets)
    isdir(out_dir) || return solved_state, solved_targets
    for fname in readdir(out_dir)
        startswith(fname, "eqb_") || continue
        endswith(fname, ".asc") || continue
        info = parse_eqb_filename(fname)
        info === nothing && continue
        key = (round_key(info.Lx), round_key(info.Lz))
        key in target_keys || continue
        fpath = joinpath(out_dir, fname)
        solved_state[key] = load_eqb_vector(fpath)
        push!(solved_targets, key)
    end
    return solved_state, solved_targets
end

function write_dnsmatched_tables!(
    out_dir::String,
    group_name::String,
    group_prefix::String,
    id::Int,
    targets::Vector,
    solved_targets::Set{Tuple{Float64,Float64}},
)
    summary_path = joinpath(out_dir, "summary_$(group_name).csv")
    completed_path = joinpath(out_dir, "completed_grid_$(group_name).csv")
    unsolved_path = joinpath(out_dir, "unsolved_grid_$(group_name).csv")

    open(summary_path, "w") do io
        println(io, "Lx,Lz,alpha,gamma,id,residual")
        for t in targets
            key = (t.Lxk, t.Lzk)
            key in solved_targets || continue
            alpha = 2pi / t.Lx
            gamma = 2pi / t.Lz
            println(io, "$(t.Lx),$(t.Lz),$(alpha),$(gamma),$(id),NaN")
        end
    end
    open(completed_path, "w") do io
        println(io, "Lx,Lz")
        for t in targets
            key = (t.Lxk, t.Lzk)
            key in solved_targets || continue
            println(io, "$(t.Lx),$(t.Lz)")
        end
    end
    open(unsolved_path, "w") do io
        println(io, "Lx,Lz")
        for t in targets
            key = (t.Lxk, t.Lzk)
            key in solved_targets && continue
            println(io, "$(t.Lx),$(t.Lz)")
        end
    end
end

function append_dnsmatched_progress(path::String, row::Vector{String}; io_lock::ReentrantLock)
    lock(io_lock) do
        newfile = !isfile(path)
        open(path, "a") do io
            if newfile
                println(
                    io,
                    "timestamp,status,Lx,Lz,ix,iz,dns_status,dns_min_Re,source_Lx,source_Lz,distance,trial,residual,file",
                )
            end
            println(io, join(row, ","))
            flush(io)
        end
    end
end

function pick_nearest_source(
    target,
    solved_state::Dict{Tuple{Float64,Float64},Vector{Float64}},
)
    best_key = nothing
    best_dist = Inf
    for (key, _) in solved_state
        d = hypot(target.Lx - key[1], target.Lz - key[2])
        if d < best_dist
            best_dist = d
            best_key = key
        end
    end
    return best_key, best_dist
end

function continue_dnsmatched_geometry!(
    group_name::String,
    H,
    seed,
    promoted,
    out_root::String,
    targets::Vector,
    target_jkl::NTuple{3,Int};
    geom_trials::Int,
    geom_noise::Float64,
    max_attempts::Int,
    parallel::Int,
    resume::Bool,
    dry_run::Bool,
    max_step::Float64,
)
    group_prefix = group_name in legacy_groups ? "" : group_name
    out_dir = joinpath(out_root, "dns_matched_geometry")
    mkpath(out_dir)

    solved_state, solved_targets = resume ? bootstrap_existing_dnsmatched(out_dir, targets, group_prefix) :
                                           (Dict{Tuple{Float64,Float64},Vector{Float64}}(), Set{Tuple{Float64,Float64}}())

    # Always keep promoted seed as an available source, even if it is not one of the DNS target points.
    seed_key = (round_key(seed.Lx), round_key(seed.Lz))
    if !haskey(solved_state, seed_key)
        solved_state[seed_key] = promoted.x
    end

    # If the promoted seed lies exactly on a target point, save it immediately.
    if seed_key in Set((t.Lxk, t.Lzk) for t in targets) && !(seed_key in solved_targets)
        t = only(filter(tt -> (tt.Lxk, tt.Lzk) == seed_key, targets))
        fname = eqb_filename(group_prefix, t.Lx, t.Lz, seed.id)
        !dry_run && save(promoted.x, joinpath(out_dir, fname))
        push!(solved_targets, seed_key)
    end

    progress_path = joinpath(out_dir, "progress_dns_matched.csv")
    io_lock = ReentrantLock()
    attempts = Dict{Tuple{Float64,Float64},Int}()
    nworkers = max(1, min(parallel, Threads.nthreads()))
    iter = 0

    if dry_run
        write_dnsmatched_tables!(out_dir, group_name, group_prefix, seed.id, targets, solved_targets)
        return (solved_targets=solved_targets, solved_state=solved_state, iterations=0)
    end

    while true
        iter += 1
        candidates = NamedTuple[]
        for t in targets
            tkey = (t.Lxk, t.Lzk)
            tkey in solved_targets && continue
            ntry = get(attempts, tkey, 0)
            ntry >= max_attempts && continue
            src_key, dist = pick_nearest_source(t, solved_state)
            src_key === nothing && continue
            dist <= max_step || continue
            push!(candidates, (target=t, tkey=tkey, src_key=src_key, dist=dist, attempt=ntry + 1))
        end

        if isempty(candidates)
            println("[dns-matched] no eligible candidates (iter=$iter); stopping")
            break
        end

        sort!(candidates; by=c -> (c.dist, c.target.Lx, c.target.Lz))
        println(
            "[dns-matched iter $(iter)] solved_targets=$(length(solved_targets))/$(length(targets)) candidates=$(length(candidates)) max_step=$(round(max_step,digits=4))",
        )

        results = threaded_map(candidates, nworkers) do c, jobidx
            t = c.target
            src_key = c.src_key
            x_base = begin
                lock(io_lock) do
                    copy(solved_state[src_key])
                end
            end

            alpha = 2pi / t.Lx
            gamma = 2pi / t.Lz
            model = ODEModel(alpha, gamma, target_jkl[1], target_jkl[2], target_jkl[3], H)

            rng = MersenneTwister(
                0xD15EA5E + hash((group_name, t.Lxk, t.Lzk, src_key[1], src_key[2], c.attempt, jobidx, target_jkl)),
            )
            ok, x_star, trial = try_hookstep_trials!(
                model,
                x_base;
                trials=geom_trials,
                noise_amp=geom_noise,
                rng=rng,
                Re=RE,
            )
            res = ok ? norm(model.f(x_star, RE)) / max(norm(x_star), eps(Float64)) : NaN
            return (candidate=c, ok=ok, x=x_star, trial=trial, residual=res)
        end

        n_new = 0
        for r in results
            r === nothing && continue
            c = r.candidate
            t = c.target
            tkey = c.tkey
            attempts[tkey] = get(attempts, tkey, 0) + 1

            if r.ok && !(tkey in solved_targets)
                solved_state[tkey] = r.x
                push!(solved_targets, tkey)
                n_new += 1
                fname = eqb_filename(group_prefix, t.Lx, t.Lz, seed.id)
                fpath = joinpath(out_dir, fname)
                save(r.x, fpath)
                append_dnsmatched_progress(
                    progress_path,
                    [
                        Dates.format(now(), "yyyy-mm-ddTHH:MM:SS"),
                        "ok",
                        string(t.Lx),
                        string(t.Lz),
                        string(t.ix),
                        string(t.iz),
                        t.dns_status,
                        string(t.dns_min_Re),
                        string(c.src_key[1]),
                        string(c.src_key[2]),
                        string(c.dist),
                        string(r.trial),
                        string(r.residual),
                        joinpath("dns_matched_geometry", fname),
                    ];
                    io_lock=io_lock,
                )
                println(
                    @sprintf(
                        "[ok] Lx=%.4f Lz=%.4f from (%.4f,%.4f) dist=%.4f trial=%d res=%.3e",
                        t.Lx,
                        t.Lz,
                        c.src_key[1],
                        c.src_key[2],
                        c.dist,
                        r.trial,
                        r.residual,
                    ),
                )
            elseif !r.ok
                append_dnsmatched_progress(
                    progress_path,
                    [
                        Dates.format(now(), "yyyy-mm-ddTHH:MM:SS"),
                        "fail",
                        string(t.Lx),
                        string(t.Lz),
                        string(t.ix),
                        string(t.iz),
                        t.dns_status,
                        string(t.dns_min_Re),
                        string(c.src_key[1]),
                        string(c.src_key[2]),
                        string(c.dist),
                        string(r.trial),
                        "",
                        "",
                    ];
                    io_lock=io_lock,
                )
            end
        end

        write_dnsmatched_tables!(out_dir, group_name, group_prefix, seed.id, targets, solved_targets)
        n_new == 0 && break
    end

    write_dnsmatched_tables!(out_dir, group_name, group_prefix, seed.id, targets, solved_targets)
    return (solved_targets=solved_targets, solved_state=solved_state, iterations=iter)
end

function main_dnsmatched()
    args = parse_args(ARGS)
    group_name = get(args, "group", "E")
    group_name == "E" || error("This workflow is currently configured for group E only (got $group_name)")

    groups = symmetry_groups()
    haskey(groups, group_name) || error("Unknown group '$group_name'")
    group = groups[group_name]

    target_jkl = (
        parse(Int, get(args, "target-J", "2")),
        parse(Int, get(args, "target-K", "4")),
        parse(Int, get(args, "target-L", "7")),
    )
    source_root = get(args, "source-root", joinpath(@__DIR__, "eqb_alpha_gamma_grid"))
    source_group_dir = joinpath(source_root, group_name)

    tag = get(args, "tag", "dnsmatched")
    out_root = get(
        args,
        "out-root",
        joinpath(
            source_root,
            "multires_ode_continuation",
            group_name,
            @sprintf("J%dK%dL%d_%s", target_jkl[1], target_jkl[2], target_jkl[3], tag),
        ),
    )
    mkpath(out_root)

    promote_trials = parse(Int, get(args, "promote-trials", string(DEFAULT_PROMOTE_TRIALS)))
    promote_noise = parse(Float64, get(args, "promote-noise", string(DEFAULT_PROMOTE_NOISE)))
    geom_trials = parse(Int, get(args, "geom-trials", string(DEFAULT_GEOM_TRIALS)))
    geom_noise = parse(Float64, get(args, "geom-noise", string(DEFAULT_GEOM_NOISE)))
    max_attempts = parse(Int, get(args, "max-attempts", string(DEFAULT_MAX_ATTEMPTS)))
    parallel = parse(Int, get(args, "parallel", string(Threads.nthreads())))
    resume = parse_bool(args, "resume", true)
    dry_run = parse_bool(args, "dry-run", false)

    dns = load_dns_targets(args)
    isempty(dns.targets) && error("No DNS targets found after filtering statuses=$(collect(dns.statuses))")

    auto_step = nearest_neighbor_distance(dns.targets)
    max_step = parse(Float64, get(args, "max-step", isfinite(auto_step) ? string(1.6 * auto_step) : "1.0"))

    seed = choose_seed(source_group_dir, group_name, args)

    println("== Promote + Continue ODE on DNS-Matched Geometries ==")
    println("group=$(group_name) $(group.desc)")
    println("dns_csv=$(dns.csv_path)")
    println("geom_source=$(dns.geom_source) statuses=", join(sort!(collect(dns.statuses)), ","))
    println("dns_targets=$(length(dns.targets))")
    println("out=$(out_root)")
    println("target_jkl=$(target_jkl)")
    println("seed rank=$(seed.rank) Lx=$(seed.Lx) Lz=$(seed.Lz) id=$(seed.id) min_Re=$(seed.min_Re)")
    println(
        "promote trials=$(promote_trials) noise=$(promote_noise) | geom trials=$(geom_trials) noise=$(geom_noise)",
    )
    println("parallel=$(parallel) threads=$(Threads.nthreads()) max_attempts=$(max_attempts) max_step=$(max_step)")
    println("resume=$(resume) dry_run=$(dry_run)")

    promoted = promote_seed_to_target!(
        group_name,
        group.H,
        seed,
        out_root;
        target_jkl=target_jkl,
        promote_trials=promote_trials,
        promote_noise=promote_noise,
        resume=resume,
        dry_run=dry_run,
    )
    println("[promotion] target rung ready at $(promoted.rung_dir)")

    geom = continue_dnsmatched_geometry!(
        group_name,
        group.H,
        seed,
        promoted,
        out_root,
        dns.targets,
        target_jkl;
        geom_trials=geom_trials,
        geom_noise=geom_noise,
        max_attempts=max_attempts,
        parallel=parallel,
        resume=resume,
        dry_run=dry_run,
        max_step=max_step,
    )
    println("[done] solved_targets=$(length(geom.solved_targets))/$(length(dns.targets)) iterations=$(geom.iterations)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main_dnsmatched()
end

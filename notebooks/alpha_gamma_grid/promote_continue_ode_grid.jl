import Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))

using CloudAtlas
using Base.Threads
using DelimitedFiles
using Dates
using LinearAlgebra
using Printf
using Random

const DEFAULT_SEED_J = 1
const DEFAULT_SEED_K = 3
const DEFAULT_SEED_L = 5
const DEFAULT_RE = 300.0

const DEFAULT_LADDER = [
    (2, 3, 5),
    (2, 4, 5),
    (2, 4, 7),
    (2, 5, 7),
    (3, 5, 9),
]

const DEFAULT_PROMOTE_TRIALS = 1000
const DEFAULT_PROMOTE_NOISE = 0.01
const DEFAULT_GEOM_TRIALS = 1000
const DEFAULT_GEOM_NOISE = 0.01
const DEFAULT_MAX_ATTEMPTS = 4

const HOOKPARAMS = SearchParams(; ftol=1e-8, xtol=1e-10, Nnewton=25, Nhook=6, verbosity=0)

const legacy_groups = Set(["D"])

function symmetry_groups()
    sx, sy, sz, tx, tz = halfbox_symmetries()
    return Dict(
        "A" => (desc="<sxyz, txz>", H=[sx * sy * sz, tx * tz]),
        "B" => (desc="<sxy, sz>", H=[sx * sy, sz]),
        "C" => (desc="<sxytz, sz>", H=[sx * sy * tz, sz]),
        "D" => (desc="<sxy, sztx>", H=[sx * sy, sz * tx]),
        "E" => (desc="<sxyz, sztxz>", H=[sx * sy * sz, sz * tx * tz]),
        "F" => (desc="<sxy, sz, txz>", H=[sx * sy, sz, tx * tz]),
        "G" => (desc="<sxyz>", H=[sx * sy * sz]),
    )
end

function eqb_filename(group_prefix, Lx, Lz, id)
    if isempty(group_prefix)
        return @sprintf("eqb_Lx%.4f_Lz%.4f_id%03d.asc", Lx, Lz, id)
    end
    return @sprintf("eqb_%s_Lx%.4f_Lz%.4f_id%03d.asc", group_prefix, Lx, Lz, id)
end

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

function parse_bool(args, key, default::Bool)
    if !haskey(args, key)
        return default
    end
    v = lowercase(strip(args[key]))
    v in ("1", "true", "yes", "y", "on") && return true
    v in ("0", "false", "no", "n", "off") && return false
    error("Invalid bool for --$key: $(args[key])")
end

function round_key(value::Real; ndigits::Int=4)
    return round(Float64(value); digits=ndigits)
end

function parse_eqb_filename(fname)
    m = match(r"eqb_(?:[A-Za-z]+_)?Lx([0-9.]+)_Lz([0-9.]+)_id([0-9]+)\.asc", fname)
    m === nothing && return nothing
    return (
        Lx=parse(Float64, m.captures[1]),
        Lz=parse(Float64, m.captures[2]),
        id=parse(Int, m.captures[3]),
    )
end

function load_eqb_vector(path)
    X = readdlm(path; comments=true, comment_char='#')
    if ndims(X) == 1
        return vec(X)
    end
    return vec(X[:, 1])
end

function read_min_re_table(path)
    X = readdlm(path, ',', Float64; skipstart=1)
    isempty(X) && return Matrix{Float64}(undef, 0, 4)
    if ndims(X) == 1
        X = reshape(X, 1, length(X))
    end
    size(X, 2) < 4 && error("Expected at least 4 columns in $path")
    return X
end

function choose_seed(source_group_dir::String, group_name::String, args::Dict{String,String})
    group_prefix = group_name in legacy_groups ? "" : group_name
    if haskey(args, "seed-path")
        eqb_path = abspath(args["seed-path"])
        isfile(eqb_path) || error("Seed eqb not found: $eqb_path")
        haskey(args, "seed-Lx") || error("--seed-Lx is required with --seed-path")
        haskey(args, "seed-Lz") || error("--seed-Lz is required with --seed-path")
        haskey(args, "seed-id") || error("--seed-id is required with --seed-path")
        return (
            Lx = parse(Float64, args["seed-Lx"]),
            Lz = parse(Float64, args["seed-Lz"]),
            id = parse(Int, args["seed-id"]),
            min_Re = haskey(args, "seed-min-Re") ? parse(Float64, args["seed-min-Re"]) : NaN,
            eqb_path = eqb_path,
            rank = 0,
        )
    end

    min_re_path = get(
        args,
        "min-re-csv",
        joinpath(source_group_dir, "bifurcations", "min_re_$(group_name).csv"),
    )
    isfile(min_re_path) || error("Missing min-Re CSV: $min_re_path")

    if haskey(args, "seed-Lx") && haskey(args, "seed-Lz") && haskey(args, "seed-id")
        Lx = parse(Float64, args["seed-Lx"])
        Lz = parse(Float64, args["seed-Lz"])
        id = parse(Int, args["seed-id"])
        eqb_path = joinpath(source_group_dir, eqb_filename(group_prefix, Lx, Lz, id))
        isfile(eqb_path) || error("Seed eqb not found: $eqb_path")
        return (Lx=Lx, Lz=Lz, id=id, min_Re=NaN, eqb_path=eqb_path, rank=0)
    end

    X = read_min_re_table(min_re_path)
    isempty(X) && error("Empty min-Re CSV: $min_re_path")
    rows = [(Lx=X[i, 1], Lz=X[i, 2], id=Int(round(X[i, 3])), min_Re=X[i, 4]) for i in 1:size(X, 1)]
    sort!(rows; by=r -> (r.min_Re, r.Lx, r.Lz, r.id))
    rank = parse(Int, get(args, "seed-rank", "1"))
    1 <= rank <= length(rows) || error("--seed-rank out of range: $rank (n=$(length(rows)))")

    # Walk down sorted list until we find the corresponding eqb file.
    start_idx = rank
    for idx in start_idx:length(rows)
        r = rows[idx]
        eqb_path = joinpath(source_group_dir, eqb_filename(group_prefix, r.Lx, r.Lz, r.id))
        if isfile(eqb_path)
            return merge(r, (eqb_path=eqb_path, rank=idx))
        end
    end
    error("No EQB file found for any candidate at/after rank $rank in $source_group_dir")
end

function load_grid_from_summary(summary_path)
    isfile(summary_path) || return nothing
    X = readdlm(summary_path, ',', Float64; skipstart=1)
    isempty(X) && return nothing
    if ndims(X) == 1
        X = reshape(X, 1, length(X))
    end
    Lx_vals = sort(unique(X[:, 1]))
    Lz_vals = sort(unique(X[:, 2]))
    isempty(Lx_vals) && return nothing
    isempty(Lz_vals) && return nothing
    return Lx_vals, Lz_vals
end

function find_index(vals::Vector{Float64}, target::Float64; atol=1e-6)
    for (i, v) in pairs(vals)
        if isapprox(v, target; atol=atol, rtol=0.0)
            return i
        end
    end
    _, idx = findmin(abs.(vals .- target))
    return idx
end

function bootstrap_existing(out_dir, Lx_vals, Lz_vals)
    solved = Dict{Tuple{Int,Int}, Vector{Float64}}()
    if !isdir(out_dir)
        return solved
    end
    for fname in readdir(out_dir)
        startswith(fname, "eqb_") || continue
        endswith(fname, ".asc") || continue
        info = parse_eqb_filename(fname)
        info === nothing && continue
        i = find_index(Lx_vals, info.Lx)
        j = find_index(Lz_vals, info.Lz)
        solved[(i, j)] = load_eqb_vector(joinpath(out_dir, fname))
    end
    return solved
end

function neighbor_indices(idx::Tuple{Int,Int}, nLx, nLz)
    i, j = idx
    out = Tuple{Int,Int}[]
    i > 1 && push!(out, (i - 1, j))
    i < nLx && push!(out, (i + 1, j))
    j > 1 && push!(out, (i, j - 1))
    j < nLz && push!(out, (i, j + 1))
    return out
end

function ladder_to_target(target_jkl::NTuple{3,Int}; ladder=DEFAULT_LADDER)
    out = NTuple{3,Int}[]
    for jkl in ladder
        push!(out, jkl)
        if jkl == target_jkl
            return out
        end
    end
    error("Target rung $target_jkl is not in default ladder. Pass --ladder override (not yet implemented) or add it.")
end

function solve_eqb(model, xguess; Re=DEFAULT_RE, hookparams=HOOKPARAMS)
    f = x -> model.f(x, Re)
    Df = x -> model.Df(x, Re)
    return hookstepsolve(f, Df, xguess, hookparams)
end

function try_hookstep_trials!(
    model,
    x_base;
    trials::Int,
    noise_amp::Float64,
    rng::AbstractRNG,
    hookparams=HOOKPARAMS,
    Re=DEFAULT_RE,
)
    if length(x_base) != size(model.ijkl, 1)
        return (false, x_base, 0)
    end
    x_star = x_base
    for trial in 1:trials
        if trial == 1 || noise_amp == 0.0
            x_guess = x_base
        else
            noise = randn(rng, length(x_base))
            nrm = norm(noise)
            if nrm > 0
                noise .*= (noise_amp / nrm)
            end
            x_guess = x_base .+ noise
        end
        x_star, solved = solve_eqb(model, x_guess; Re=Re, hookparams=hookparams)
        solved && return (true, x_star, trial)
    end
    return (false, x_star, trials)
end

function append_progress_row(path::String, row::Vector{String}; io_lock::ReentrantLock)
    lock(io_lock) do
        newfile = !isfile(path)
        open(path, "a") do io
            if newfile
                println(
                    io,
                    "timestamp,status,Lx,Lz,i,j,id,source_i,source_j,trial,J,K,L,residual,norm,file",
                )
            end
            println(io, join(row, ","))
            flush(io)
        end
    end
end

function update_completed_files!(
    out_dir::String,
    group_prefix::String,
    Lx_vals::Vector{Float64},
    Lz_vals::Vector{Float64},
    solved::Dict{Tuple{Int,Int}, Vector{Float64}},
    id::Int,
)
    summary_suffix = isempty(group_prefix) ? "" : "_$(group_prefix)"
    completed_path = joinpath(out_dir, "completed_grid$(summary_suffix).csv")
    unsolved_path = joinpath(out_dir, "unsolved_grid$(summary_suffix).csv")
    solved_keys = sort!(collect(keys(solved)))

    open(completed_path, "w") do io
        println(io, "Lx,Lz")
        for (i, j) in solved_keys
            println(io, "$(Lx_vals[i]),$(Lz_vals[j])")
        end
    end

    open(unsolved_path, "w") do io
        println(io, "Lx,Lz")
        for i in eachindex(Lx_vals), j in eachindex(Lz_vals)
            haskey(solved, (i, j)) || println(io, "$(Lx_vals[i]),$(Lz_vals[j])")
        end
    end

    # Lightweight summary (residual only) to avoid expensive postprocessing during long runs.
    summary_path = joinpath(out_dir, "summary$(summary_suffix).csv")
    open(summary_path, "w") do io
        println(io, "Lx,Lz,alpha,gamma,id,residual")
        for (i, j) in solved_keys
            Lx = Lx_vals[i]
            Lz = Lz_vals[j]
            alpha = 2pi / Lx
            gamma = 2pi / Lz
            println(io, "$(Lx),$(Lz),$(alpha),$(gamma),$(id),NaN")
        end
    end
end

function promote_seed_to_target!(
    group_name::String,
    H,
    seed,
    run_root::String;
    seed_jkl::NTuple{3,Int},
    target_jkl::NTuple{3,Int},
    Re::Float64,
    promote_trials::Int,
    promote_noise::Float64,
    resume::Bool,
    dry_run::Bool,
)
    Lx = seed.Lx
    Lz = seed.Lz
    id = seed.id
    alpha = 2pi / Lx
    gamma = 2pi / Lz

    rung_root = joinpath(run_root, "promotion")
    mkpath(rung_root)
    meta_path = joinpath(rung_root, "seed_info.txt")
    if !isfile(meta_path)
        open(meta_path, "w") do io
            println(io, "group=$group_name")
            println(io, @sprintf("Lx=%.10f", Lx))
            println(io, @sprintf("Lz=%.10f", Lz))
            println(io, "id=$id")
            if hasproperty(seed, :min_Re)
                println(io, "min_Re=$(seed.min_Re)")
            end
            if hasproperty(seed, :rank)
                println(io, "rank=$(seed.rank)")
            end
            println(io, "source_eqb=$(seed.eqb_path)")
        end
    end

    seed_j, seed_k, seed_l = seed_jkl

    x0 = load_eqb_vector(seed.eqb_path)
    model0 = ODEModel(alpha, gamma, seed_j, seed_k, seed_l, H)
    length(x0) == size(model0.ijkl, 1) ||
        error("Seed vector length $(length(x0)) != model size $(size(model0.ijkl, 1)) for seed JKL=($(seed_j),$(seed_k),$(seed_l))")

    base_dir = joinpath(rung_root, @sprintf("J%dK%dL%d", seed_j, seed_k, seed_l))
    mkpath(base_dir)
    base_state_path = joinpath(base_dir, "x_star.asc")
    if !isfile(base_state_path)
        save(x0, base_state_path)
    end

    dry_run && return (model=model0, x=x0, rung_dir=base_dir)

    prev_model = model0
    prev_x = x0
    ladder = if target_jkl == seed_jkl
        NTuple{3,Int}[]
    elseif seed_jkl == (DEFAULT_SEED_J, DEFAULT_SEED_K, DEFAULT_SEED_L)
        ladder_to_target(target_jkl)
    else
        # For arbitrary catalog seeds, project directly to the requested target rung.
        [target_jkl]
    end
    rng = MersenneTwister(0x51EED + hash((group_name, round_key(Lx), round_key(Lz), id, target_jkl)))

    for (Jt, Kt, Lt) in ladder
        target_dir = joinpath(rung_root, @sprintf("J%dK%dL%d", Jt, Kt, Lt))
        mkpath(target_dir)
        solved_path = joinpath(target_dir, "x_star.asc")
        if resume && isfile(solved_path)
            model_to = ODEModel(alpha, gamma, Jt, Kt, Lt, H)
            prev_model = model_to
            prev_x = load_eqb_vector(solved_path)
            continue
        end

        model_to = ODEModel(alpha, gamma, Jt, Kt, Lt, H)
        x_proj = changebasis(prev_x, prev_model.ijkl, model_to.ijkl)
        save(x_proj, joinpath(target_dir, "x_proj.asc"))

        ok, x_star, trial = try_hookstep_trials!(
            model_to,
            x_proj;
            trials=promote_trials,
            noise_amp=promote_noise,
            rng=rng,
            Re=Re,
        )
        open(joinpath(target_dir, "attempt_info.txt"), "w") do io
            println(io, "promote_trials=$promote_trials")
            println(io, "promote_noise=$promote_noise")
            println(io, "used_trial=$trial")
            println(io, "converged=$ok")
        end
        if !ok
            error(
                "Failed to promote seed to rung JKL=($Jt,$Kt,$Lt) after $(promote_trials) perturbation trials (noise=$(promote_noise)).",
            )
        end
        save(x_star, solved_path)
        prev_model = model_to
        prev_x = x_star
    end

    rung_dir = joinpath(rung_root, @sprintf("J%dK%dL%d", target_jkl...))
    return (model=prev_model, x=prev_x, rung_dir=rung_dir)
end

function load_grid(args, source_group_dir, group_name)
    grid_mode = get(args, "grid", "summary")
    if grid_mode == "summary" || grid_mode == "auto"
        summary_suffix = group_name in legacy_groups ? "" : "_$(group_name)"
        summary_guess = joinpath(source_group_dir, "summary$(summary_suffix).csv")
        grid = load_grid_from_summary(summary_guess)
        if grid !== nothing
            return grid
        end
        grid_mode == "summary" &&
            error("Could not load grid from summary CSV: $summary_guess")
    end
    Lx_vals = collect(
        range(
            parse(Float64, get(args, "Lx-min", "5.0")),
            parse(Float64, get(args, "Lx-max", "15.0"));
            length=parse(Int, get(args, "Lx-n", "15")),
        ),
    )
    Lz_vals = collect(
        range(
            parse(Float64, get(args, "Lz-min", "2.0")),
            parse(Float64, get(args, "Lz-max", "10.0"));
            length=parse(Int, get(args, "Lz-n", "15")),
        ),
    )
    return Lx_vals, Lz_vals
end

function build_candidate_map(solved::Dict{Tuple{Int,Int},Vector{Float64}}, attempts::Dict{Tuple{Int,Int},Int}, nLx, nLz, max_attempts)
    candidates = Dict{Tuple{Int,Int}, Tuple{Int,Int}}()
    for src in keys(solved)
        for nbr in neighbor_indices(src, nLx, nLz)
            haskey(solved, nbr) && continue
            get(attempts, nbr, 0) >= max_attempts && continue
            if !haskey(candidates, nbr)
                candidates[nbr] = src
            end
        end
    end
    return candidates
end

function threaded_attempts(candidates::Vector, nworkers::Int, fn)
    isempty(candidates) && return NamedTuple[]
    results = Vector{Any}(undef, length(candidates))
    idxch = Channel{Int}(length(candidates))
    for i in eachindex(candidates)
        put!(idxch, i)
    end
    close(idxch)
    @sync for _ in 1:min(nworkers, length(candidates))
        Threads.@spawn begin
            for idx in idxch
                results[idx] = fn(candidates[idx], idx)
            end
        end
    end
    return results
end

# Julia `do` blocks pass the function as the first argument.
threaded_attempts(fn, candidates::Vector, nworkers::Int) = threaded_attempts(candidates, nworkers, fn)

function continue_geometry_grid!(
    group_name::String,
    H,
    seed,
    promoted,
    run_root::String,
    Lx_vals::Vector{Float64},
    Lz_vals::Vector{Float64},
    target_jkl::NTuple{3,Int};
    Re::Float64,
    geom_trials::Int,
    geom_noise::Float64,
    max_attempts::Int,
    parallel::Int,
    resume::Bool,
    dry_run::Bool,
)
    group_prefix = group_name in legacy_groups ? "" : group_name
    out_dir = joinpath(run_root, "geometry_grid")
    mkpath(out_dir)

    i0 = find_index(Lx_vals, seed.Lx)
    j0 = find_index(Lz_vals, seed.Lz)

    solved = resume ? bootstrap_existing(out_dir, Lx_vals, Lz_vals) : Dict{Tuple{Int,Int},Vector{Float64}}()
    seed_idx = (i0, j0)
    if !haskey(solved, seed_idx)
        save_path = joinpath(out_dir, eqb_filename(group_prefix, Lx_vals[i0], Lz_vals[j0], seed.id))
        if !dry_run
            save(promoted.x, save_path)
        end
        solved[seed_idx] = promoted.x
    end

    state_path = joinpath(out_dir, "progress_geometry.csv")
    io_lock = ReentrantLock()
    if !dry_run
        append_progress_row(
            state_path,
            [
                Dates.format(now(), "yyyy-mm-ddTHH:MM:SS"),
                "seed",
                string(Lx_vals[i0]),
                string(Lz_vals[j0]),
                string(i0),
                string(j0),
                string(seed.id),
                "",
                "",
                "",
                string(target_jkl[1]),
                string(target_jkl[2]),
                string(target_jkl[3]),
                "",
                "",
                joinpath("geometry_grid", eqb_filename(group_prefix, Lx_vals[i0], Lz_vals[j0], seed.id)),
            ];
            io_lock=io_lock,
        )
    end

    attempts = Dict{Tuple{Int,Int},Int}()
    progress_iter = 0
    nworkers = max(1, min(parallel, Threads.nthreads()))
    dry_run && return (solved=solved, attempts=attempts, iterations=0)

    while true
        progress_iter += 1
        cand_map = build_candidate_map(solved, attempts, length(Lx_vals), length(Lz_vals), max_attempts)
        isempty(cand_map) && break
        candidates = [
            (dst=dst, src=src, attempt_num=get(attempts, dst, 0) + 1) for (dst, src) in cand_map
        ]
        sort!(candidates; by=c -> (c.dst[1], c.dst[2]))

        println(
            "[iter $(progress_iter)] solved=$(length(solved)) candidates=$(length(candidates)) workers=$(nworkers)",
        )

        batch_results = threaded_attempts(candidates, nworkers) do c, idx
            dst = c.dst
            src = c.src
            i, j = dst
            si, sj = src
            Lx = Lx_vals[i]
            Lz = Lz_vals[j]
            alpha = 2pi / Lx
            gamma = 2pi / Lz
            model = ODEModel(alpha, gamma, target_jkl[1], target_jkl[2], target_jkl[3], H)

            x_base = begin
                lock(io_lock) do
                    copy(solved[src])
                end
            end
            rng = MersenneTwister(
                0x600D + hash((group_name, i, j, si, sj, c.attempt_num, idx, target_jkl)),
            )
            ok, x_star, trial = try_hookstep_trials!(
                model,
                x_base;
                trials=geom_trials,
                noise_amp=geom_noise,
                rng=rng,
                Re=Re,
            )
            residual = ok ? norm(model.f(x_star, Re)) / max(norm(x_star), eps(Float64)) : NaN
            return (c=c, ok=ok, x=x_star, trial=trial, residual=residual)
        end

        n_new = 0
        for r in batch_results
            r === nothing && continue
            dst = r.c.dst
            src = r.c.src
            attempts[dst] = get(attempts, dst, 0) + 1
            i, j = dst
            si, sj = src
            if r.ok && !haskey(solved, dst)
                solved[dst] = r.x
                n_new += 1
                fname = eqb_filename(group_prefix, Lx_vals[i], Lz_vals[j], seed.id)
                fpath = joinpath(out_dir, fname)
                save(r.x, fpath)
                append_progress_row(
                    state_path,
                    [
                        Dates.format(now(), "yyyy-mm-ddTHH:MM:SS"),
                        "ok",
                        string(Lx_vals[i]),
                        string(Lz_vals[j]),
                        string(i),
                        string(j),
                        string(seed.id),
                        string(si),
                        string(sj),
                        string(r.trial),
                        string(target_jkl[1]),
                        string(target_jkl[2]),
                        string(target_jkl[3]),
                        string(r.residual),
                        string(norm(r.x)),
                        joinpath("geometry_grid", fname),
                    ];
                    io_lock=io_lock,
                )
                println(
                    @sprintf(
                        "[ok] (%d,%d) Lx=%.4f Lz=%.4f from (%d,%d) trial=%d res=%.3e",
                        i,
                        j,
                        Lx_vals[i],
                        Lz_vals[j],
                        si,
                        sj,
                        r.trial,
                        r.residual,
                    ),
                )
            elseif !r.ok
                append_progress_row(
                    state_path,
                    [
                        Dates.format(now(), "yyyy-mm-ddTHH:MM:SS"),
                        "fail",
                        string(Lx_vals[i]),
                        string(Lz_vals[j]),
                        string(i),
                        string(j),
                        string(seed.id),
                        string(si),
                        string(sj),
                        string(r.trial),
                        string(target_jkl[1]),
                        string(target_jkl[2]),
                        string(target_jkl[3]),
                        "",
                        "",
                        "",
                    ];
                    io_lock=io_lock,
                )
            end
        end

        update_completed_files!(out_dir, group_prefix, Lx_vals, Lz_vals, solved, seed.id)
        n_new == 0 && break
    end

    update_completed_files!(out_dir, group_prefix, Lx_vals, Lz_vals, solved, seed.id)
    return (solved=solved, attempts=attempts, iterations=progress_iter)
end

function main()
    args = parse_args(ARGS)
    base_dir = @__DIR__

    group_name = get(args, "group", "E")
    groups = symmetry_groups()
    haskey(groups, group_name) || error("Unknown group '$group_name'")
    group = groups[group_name]

    source_root = get(args, "source-root", joinpath(base_dir, "eqb_alpha_gamma_grid"))
    source_group_dir = joinpath(source_root, group_name)
    isdir(source_group_dir) || error("Missing source group dir: $source_group_dir")

    target_j = parse(Int, get(args, "target-J", "2"))
    target_k = parse(Int, get(args, "target-K", "4"))
    target_l = parse(Int, get(args, "target-L", "7"))
    target_jkl = (target_j, target_k, target_l)
    Re = parse(Float64, get(args, "Re", string(DEFAULT_RE)))

    run_tag = get(args, "tag", "")
    tag_suffix = isempty(run_tag) ? "" : "_$(run_tag)"
    out_root = get(
        args,
        "out-root",
        joinpath(source_root, "multires_ode_continuation", group_name, @sprintf("J%dK%dL%d%s", target_j, target_k, target_l, tag_suffix)),
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

    seed = choose_seed(source_group_dir, group_name, args)
    Lx_vals, Lz_vals = load_grid(args, source_group_dir, group_name)

    println("== Promote + Continue ODE Grid ==")
    println("group=$(group_name) $(group.desc)")
    println("source=$(source_group_dir)")
    println("out=$(out_root)")
    println("target_jkl=$(target_jkl)")
    println("Re=$(Re)")
    println("seed rank=$(seed.rank) Lx=$(seed.Lx) Lz=$(seed.Lz) id=$(seed.id) min_Re=$(seed.min_Re)")
    println("grid size=$(length(Lx_vals))x$(length(Lz_vals))")
    println(
        "promote trials=$(promote_trials) noise=$(promote_noise) | geom trials=$(geom_trials) noise=$(geom_noise)",
    )
    println("parallel=$(parallel) (Julia threads=$(Threads.nthreads())) resume=$(resume) dry_run=$(dry_run)")

    promoted = promote_seed_to_target!(
        group_name,
        group.H,
        seed,
        out_root;
        seed_jkl=(
            parse(Int, get(args, "seed-J", string(DEFAULT_SEED_J))),
            parse(Int, get(args, "seed-K", string(DEFAULT_SEED_K))),
            parse(Int, get(args, "seed-L", string(DEFAULT_SEED_L))),
        ),
        target_jkl=target_jkl,
        Re=Re,
        promote_trials=promote_trials,
        promote_noise=promote_noise,
        resume=resume,
        dry_run=dry_run,
    )
    println("[promotion] target rung ready at $(promoted.rung_dir)")

    geom = continue_geometry_grid!(
        group_name,
        group.H,
        seed,
        promoted,
        out_root,
        Lx_vals,
        Lz_vals,
        target_jkl;
        Re=Re,
        geom_trials=geom_trials,
        geom_noise=geom_noise,
        max_attempts=max_attempts,
        parallel=parallel,
        resume=resume,
        dry_run=dry_run,
    )
    println("[done] solved=$(length(geom.solved)) iterations=$(geom.iterations)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

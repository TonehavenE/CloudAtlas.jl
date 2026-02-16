import Pkg
Pkg.activate("../../.")

using CloudAtlas
using ChannelflowWrapper
using DelimitedFiles
using Printf
using Dates
using Random
using Base.Threads

const DEFAULT_GROUPS = ["E", "F"]
const LEGACY_GROUPS = Set(["D"])

const DEFAULT_PROMOTION_LADDER = [
    (1, 3, 5),
    (2, 3, 5),
    (2, 4, 5),
    (2, 4, 7),
    (2, 5, 7),
    (3, 5, 9),
]
const DEFAULT_TARGET_RUNG = DEFAULT_PROMOTION_LADDER[end]

const DEFAULT_RE = 300.0
const DEFAULT_FINDSOLN_T = 10.0
const DEFAULT_FINDSOLN_TRIALS = 10
const DEFAULT_FINDSOLN_NOISE = 0.01
const DEFAULT_HOOKPARAMS = SearchParams(; ftol = 1e-8, xtol = 1e-10, Nnewton = 25, Nhook = 6, verbosity = 0)

const DEFAULT_GEOM_CONTS = ["Lx", "Lz"]
const DEFAULT_GEOM_DMU = 0.01
const DEFAULT_GEOM_NS = 20

const DEFAULT_RE_DMU = -0.02
const DEFAULT_RE_NS = 50
const DEFAULT_RE_TARGET = 100.0

const DEFAULT_MAX_PARALLEL = 4
const DEFAULT_RES_TOL = 1e-8

const DEFAULT_GRID_NX = 32
const DEFAULT_GRID_NY = 49
const DEFAULT_GRID_NZ = 32

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

function parse_bool(args::Dict{String, String}, key::String; default::Bool = false)
    if !haskey(args, key)
        return default
    end
    v = lowercase(strip(args[key]))
    return v in ("1", "true", "yes", "y")
end

function parse_list(args::Dict{String, String}, key::String, default::Vector{String})
    if !haskey(args, key)
        return copy(default)
    end
    vals = [String(strip(s)) for s in split(args[key], ",") if !isempty(strip(s))]
    return isempty(vals) ? copy(default) : vals
end

function parse_groups(args::Dict{String, String})
    if get(args, "all", "false") == "true"
        return ["A", "B", "C", "D", "E", "F", "G"]
    end
    return parse_list(args, "groups", DEFAULT_GROUPS)
end

function round_key(v::Real; ndigits::Int = 4)
    return round(Float64(v); digits = ndigits)
end

function parse_eqb_filename(fname::AbstractString)
    m = match(r"^eqb_(?:([A-Za-z]+)_)?Lx([0-9.]+)_Lz([0-9.]+)_id([0-9]+)\.asc$", fname)
    m === nothing && return nothing
    group = m.captures[1]
    return (
        group = group === nothing ? "" : group,
        Lx = parse(Float64, m.captures[2]),
        Lz = parse(Float64, m.captures[3]),
        id = parse(Int, m.captures[4]),
    )
end

function parse_case_token(path::AbstractString)
    for part in splitpath(path)
        m = match(r"^([A-Za-z]+)_Lx([0-9.]+)_Lz([0-9.]+)_id([0-9]+)", part)
        m === nothing && continue
        return (
            group = m.captures[1],
            Lx = parse(Float64, m.captures[2]),
            Lz = parse(Float64, m.captures[3]),
            id = parse(Int, m.captures[4]),
        )
    end
    return nothing
end

function read_last_residual(path::AbstractString)
    if !isfile(path)
        return Inf
    end
    first_line = true
    last = Inf
    open(path, "r") do io
        for line in eachline(io)
            s = strip(line)
            isempty(s) && continue
            if first_line
                first_line = false
                continue
            end
            vals = split(s)
            isempty(vals) && continue
            v = tryparse(Float64, vals[1])
            v === nothing && continue
            last = v
        end
    end
    return last
end

function read_single_float(path::AbstractString)
    if !isfile(path)
        return nothing
    end
    txt = strip(read(path, String))
    isempty(txt) && return nothing
    return tryparse(Float64, txt)
end

function read_processinfo_symm(path::AbstractString)
    if !isfile(path)
        return nothing
    end
    text = read(path, String)
    m = match(r"-symms\s+(\S+)", text)
    m === nothing && return nothing
    return m.captures[1]
end

function read_processinfo_R(path::AbstractString)
    if !isfile(path)
        return nothing
    end
    text = read(path, String)
    m = match(r"-R\s+([0-9eE+.\-]+)", text)
    m === nothing && return nothing
    return tryparse(Float64, m.captures[1])
end

function write_symm_file(path::AbstractString, lines::Vector{String})
    open(path, "w") do io
        println(io, "% $(length(lines))")
        for line in lines
            println(io, line)
        end
    end
end

function symm_lines(group::String)
    sxyz = "1 -1 -1 -1 0.0 0.0"
    sxy = "1 -1 -1 1 0.0 0.0"
    sz = "1 1 1 -1 0.0 0.0"
    txz = "1 1 1 1 0.5 0.5"
    sxytz = "1 -1 -1 1 0.0 0.5"
    sztx = "1 1 1 -1 0.5 0.0"
    sztxz = "1 1 1 -1 0.5 0.5"

    if group == "A"
        return [sxyz, txz]
    elseif group == "B"
        return [sxy, sz]
    elseif group == "C"
        return [sxytz, sz]
    elseif group == "D"
        return [sxy, sztx]
    elseif group == "E"
        return [sxyz, sztxz]
    elseif group == "F"
        return [sxy, sz, txz]
    elseif group == "G"
        return [sxyz]
    end
    error("Unknown group: $group")
end

function ensure_symm_file(group::String, out_root::AbstractString)
    symm_dir = joinpath(out_root, "symm_files")
    mkpath(symm_dir)
    symm_path = joinpath(symm_dir, "symm_$(group).asc")
    if !isfile(symm_path)
        write_symm_file(symm_path, symm_lines(group))
    end
    return abspath(symm_path)
end

function model_for_rung(alpha::Real, gamma::Real, rung::NTuple{3, Int}, H)
    J, K, L = rung
    return ODEModel(alpha, gamma, J, K, L, H)
end

function find_matching_rung(alpha::Real, gamma::Real, H, ncoeff::Int, ladder::Vector{NTuple{3, Int}})
    for rung in ladder
        model = model_for_rung(alpha, gamma, rung, H)
        if size(model.ijkl, 1) == ncoeff
            return rung, model
        end
    end
    return nothing
end

function rung_label(r::NTuple{3, Int})
    return @sprintf("J%dK%dL%d", r[1], r[2], r[3])
end

function run_with_limiter(run_job, jobs, max_parallel::Int)
    if isempty(jobs)
        return Any[]
    end
    sem = Base.Semaphore(max_parallel)
    tasks = Task[]
    results = Vector{Any}(undef, length(jobs))

    for (idx, job) in enumerate(jobs)
        t = @async begin
            Base.acquire(sem)
            try
                results[idx] = run_job(job)
            catch err
                results[idx] = (ok = false, error = sprint(showerror, err), job = job)
            finally
                Base.release(sem)
            end
        end
        push!(tasks, t)
    end
    wait.(tasks)
    return results
end

function parse_summary_map(summary_path::AbstractString)
    out = Dict{Tuple{Float64, Float64, Int}, Float64}()
    if !isfile(summary_path)
        return out
    end
    X = try
        readdlm(summary_path, ',', Float64; skipstart = 1)
    catch
        return out
    end
    isempty(X) && return out
    if ndims(X) == 1
        X = reshape(X, 1, length(X))
    end
    size(X, 2) < 9 && return out
    for i in 1:size(X, 1)
        key = (round_key(X[i, 1]), round_key(X[i, 2]), Int(round(X[i, 5])))
        out[key] = X[i, 9]
    end
    return out
end

function group_prefix(group::String)
    return group in LEGACY_GROUPS ? "" : group
end

function collect_eqb_candidates(group::String, roots::Vector{String}; max_per_group::Int = 40)
    entries = NamedTuple[]
    seen = Set{Tuple{Float64, Float64, Int}}()
    prefix = group_prefix(group)
    for root in roots
        group_dir = joinpath(root, group)
        isdir(group_dir) || continue
        summary_path = joinpath(group_dir, "summary_$(group).csv")
        summary_map = parse_summary_map(summary_path)
        for fname in readdir(group_dir)
            startswith(fname, "eqb_") || continue
            endswith(fname, ".asc") || continue
            info = parse_eqb_filename(fname)
            info === nothing && continue
            if !isempty(prefix) && info.group != prefix
                continue
            end
            key = (round_key(info.Lx), round_key(info.Lz), info.id)
            key in seen && continue
            push!(seen, key)
            res = get(summary_map, key, Inf)
            push!(entries, (
                group = group,
                Lx = info.Lx,
                Lz = info.Lz,
                id = info.id,
                residual = res,
                path = joinpath(group_dir, fname),
                source_root = root,
            ))
        end
    end
    sort!(entries; by = e -> (e.residual, e.path))
    if max_per_group > 0 && length(entries) > max_per_group
        entries = entries[1:max_per_group]
    end
    return entries
end

function collect_existing_dns_seeds(
    dns_root::String,
    groups::AbstractVector{<:AbstractString},
    seed_Re::Float64,
    tol::Float64;
    max_per_group::Int = 6,
)
    group_set = Set(String.(groups))
    seeds = NamedTuple[]
    for (dir, _, files) in walkdir(dns_root)
        base = basename(dir)
        if !startswith(base, "trial_")
            continue
        end
        "ubest.nc" in files || continue
        case = parse_case_token(dir)
        case === nothing && continue
        case.group in group_set || continue
        residual = read_last_residual(joinpath(dir, "convergence.asc"))
        residual <= tol || continue

        proc_path = joinpath(dir, "processinfo")
        Rproc = read_processinfo_R(proc_path)
        if Rproc !== nothing && !isapprox(Rproc, seed_Re; atol = 5e-3, rtol = 0.0)
            continue
        end

        symm = read_processinfo_symm(proc_path)
        if symm === nothing
            fallback = joinpath(dns_root, "symm_$(case.group).asc")
            symm = isfile(fallback) ? abspath(fallback) : nothing
        end
        symm !== nothing || continue

        push!(seeds, (
            group = case.group,
            Lx = case.Lx,
            Lz = case.Lz,
            id = case.id,
            seed_path = joinpath(dir, "ubest.nc"),
            symm_path = abspath(symm),
            residual = residual,
            source = "existing_dns",
            label = basename(dirname(dirname(dir))),
        ))
    end

    sort!(seeds; by = s -> (s.group, s.residual, s.seed_path))
    if max_per_group > 0
        limited = NamedTuple[]
        counts = Dict{String, Int}()
        for s in seeds
            c = get(counts, s.group, 0)
            if c >= max_per_group
                continue
            end
            counts[s.group] = c + 1
            push!(limited, s)
        end
        return limited
    end
    return seeds
end

function regrid_seed(seed, out_root::String, nx::Int, ny::Int, nz::Int; dry_run::Bool = false, resume::Bool = true)
    grid_dir = joinpath(out_root, "seed_grid", seed.group, seed.label)
    target_name = @sprintf("ubest_%dx%dx%d.nc", nx, ny, nz)
    target_path = joinpath(grid_dir, target_name)
    if dry_run
        return (; seed..., seed_path = abspath(target_path), source = seed.source * "_grid")
    end

    if resume && isfile(target_path)
        return (; seed..., seed_path = abspath(target_path), source = seed.source * "_grid")
    end

    mkpath(grid_dir)
    alpha = 2pi / seed.Lx
    gamma = 2pi / seed.Lz
    changegrid(seed.seed_path, target_path; Nx = nx, Ny = ny, Nz = nz, al = alpha, ga = gamma)
    return (; seed..., seed_path = abspath(target_path), source = seed.source * "_grid")
end

function promote_eqb_to_dns(
    entry,
    out_root::String,
    reference_path::String,
    ladder::Vector{NTuple{3, Int}},
    target_rung::NTuple{3, Int},
    findsoln_trials::Int,
    noise_amp::Float64,
    hookparams,
    seed_Re::Float64,
    findsoln_T::Float64,
    grid_nx::Int,
    grid_ny::Int,
    grid_nz::Int,
    res_tol::Float64;
    dry_run::Bool = false,
)
    group = entry.group
    H = begin
        sx, sy, sz, tx, tz = halfbox_symmetries()
        if group == "A"
            [sx * sy * sz, tx * tz]
        elseif group == "B"
            [sx * sy, sz]
        elseif group == "C"
            [sx * sy * tz, sz]
        elseif group == "D"
            [sx * sy, sz * tx]
        elseif group == "E"
            [sx * sy * sz, sz * tx * tz]
        elseif group == "F"
            [sx * sy, sz, tx * tz]
        elseif group == "G"
            [sx * sy * sz]
        else
            error("Unknown group: $group")
        end
    end

    x0 = begin
        X = readdlm(entry.path; comments = true, comment_char = '#')
        ndims(X) == 1 ? vec(X) : vec(X[:, 1])
    end

    alpha = 2pi / entry.Lx
    gamma = 2pi / entry.Lz
    matched = find_matching_rung(alpha, gamma, H, length(x0), ladder)
    matched === nothing && return (ok = false, reason = "no_matching_rung", entry = entry)
    start_rung, start_model = matched

    start_idx = findfirst(==(start_rung), ladder)
    start_idx === nothing && return (ok = false, reason = "start_rung_not_in_ladder", entry = entry)
    target_idx = findfirst(==(target_rung), ladder)
    target_idx === nothing && return (ok = false, reason = "target_rung_not_in_ladder", entry = entry)

    case_name = @sprintf(
        "%s_Lx%.4f_Lz%.4f_id%03d_promote_%s",
        group,
        entry.Lx,
        entry.Lz,
        entry.id,
        Dates.format(now(), "yyyymmdd_HHMMSS"),
    )
    case_dir = joinpath(out_root, "promoted_dns_seeds", group, case_name)
    mkpath(case_dir)

    symm_path = ensure_symm_file(group, out_root)
    ref_converted = joinpath(out_root, @sprintf("reference_field_%.10f_%.10f.nc", alpha, gamma))
    if !dry_run && !isfile(ref_converted)
        changegrid(
            reference_path,
            ref_converted;
            al = alpha,
            ga = gamma,
            Nx = grid_nx,
            Ny = grid_ny,
            Nz = grid_nz,
        )
    end

    prev_x = x0
    prev_model = start_model
    last_success_rung = start_rung
    last_success_dir = joinpath(case_dir, rung_label(start_rung))
    mkpath(last_success_dir)
    if !dry_run
        save(prev_x, joinpath(last_success_dir, "x_base.asc"))
    end

    rng = MersenneTwister(0xFACE + hash((group, entry.Lx, entry.Lz, entry.id)))

    for idx in (start_idx + 1):target_idx
        rung = ladder[idx]
        model_to = model_for_rung(alpha, gamma, rung, H)
        x_proj = changebasis(prev_x, prev_model.ijkl, model_to.ijkl)
        rung_dir = joinpath(case_dir, rung_label(rung))
        mkpath(rung_dir)
        if !dry_run
            save(x_proj, joinpath(rung_dir, "x_proj.asc"))
        end

        converged = false
        x_star = x_proj
        for trial in 1:findsoln_trials
            if trial == 1 || noise_amp == 0.0
                x_guess = x_proj
            else
                noise = (rand(rng, length(x_proj)) .- 0.5) .* (2 * noise_amp)
                x_guess = x_proj .+ noise
            end
            if dry_run
                converged = true
                x_star = x_guess
                break
            end
            f = x -> model_to.f(x, seed_Re)
            Df = x -> model_to.Df(x, seed_Re)
            x_star, converged = hookstepsolve(f, Df, x_guess, hookparams)
            if converged
                save(x_star, joinpath(rung_dir, @sprintf("x_star_trial_%04d.asc", trial)))
                break
            end
        end

        if !converged
            break
        end
        prev_x = x_star
        prev_model = model_to
        last_success_rung = rung
        last_success_dir = rung_dir
    end

    trial_dir = joinpath(last_success_dir, "trial_promoted")
    mkpath(trial_dir)
    guess_path = joinpath(trial_dir, "u_guess.nc")
    if dry_run
        return (
            ok = true,
            dry_run = true,
            group = group,
            Lx = entry.Lx,
            Lz = entry.Lz,
            id = entry.id,
            seed_path = guess_path,
            symm_path = symm_path,
            rung = last_success_rung,
            residual = Inf,
            source = "promoted_eqb",
            label = case_name,
        )
    end

    coeff2field(prev_x, prev_model.ijkl, ref_converted, guess_path; workdir = trial_dir)
    findsoln(
        guess_path;
        workdir = trial_dir,
        R = seed_Re,
        eqb = true,
        symms = symm_path,
        od = trial_dir,
        T = findsoln_T,
    )

    residual = read_last_residual(joinpath(trial_dir, "convergence.asc"))
    return (
        ok = residual <= res_tol,
        group = group,
        Lx = entry.Lx,
        Lz = entry.Lz,
        id = entry.id,
        seed_path = joinpath(trial_dir, "ubest.nc"),
        symm_path = symm_path,
        rung = last_success_rung,
        residual = residual,
        source = "promoted_eqb",
        label = case_name,
    )
end

function run_continuesoln_job(seed_path::String, out_dir::String; dry_run::Bool = false, resume::Bool = true, kwargs...)
    mkpath(out_dir)
    if resume && isfile(joinpath(out_dir, "processinfo"))
        return (ok = true, skipped = true, out_dir = out_dir)
    end
    if dry_run
        return (ok = true, dry_run = true, out_dir = out_dir)
    end
    continuesoln(seed_path; workdir = out_dir, kwargs...)
    return (ok = true, out_dir = out_dir)
end

function collect_geometry_points(
    cont_out_dir::String,
    cont_param::String,
    base_Lx::Float64,
    base_Lz::Float64,
    seed_path::String,
)
    points = NamedTuple[]
    push!(points, (ubest = seed_path, mu = NaN, Lx = base_Lx, Lz = base_Lz, tag = "seed"))
    for name in sort(readdir(cont_out_dir))
        startswith(name, "initial-") || continue
        d = joinpath(cont_out_dir, name)
        isdir(d) || continue
        ubest = joinpath(d, "ubest.nc")
        isfile(ubest) || continue
        mu = read_single_float(joinpath(d, "mu.asc"))
        mu === nothing && continue
        Lx = base_Lx
        Lz = base_Lz
        if cont_param == "Lx"
            Lx = mu
        elseif cont_param == "Lz"
            Lz = mu
        elseif cont_param == "Aspect"
            Lx = NaN
            Lz = NaN
        end
        push!(points, (ubest = ubest, mu = mu, Lx = Lx, Lz = Lz, tag = name))
    end
    return points
end

function read_mud_min(path::AbstractString)
    if !isfile(path)
        return nothing
    end
    vals = Float64[]
    first_line = true
    open(path, "r") do io
        for line in eachline(io)
            s = strip(line)
            isempty(s) && continue
            if first_line
                first_line = false
                continue
            end
            f = split(s)
            isempty(f) && continue
            v = tryparse(Float64, f[1])
            v === nothing && continue
            push!(vals, v)
        end
    end
    return isempty(vals) ? nothing : minimum(vals)
end

function read_initial_mu_min(cont_out_dir::AbstractString)
    vals = Float64[]
    if !isdir(cont_out_dir)
        return nothing
    end
    for name in readdir(cont_out_dir)
        startswith(name, "initial-") || continue
        v = read_single_float(joinpath(cont_out_dir, name, "mu.asc"))
        v === nothing && continue
        push!(vals, v)
    end
    return isempty(vals) ? nothing : minimum(vals)
end

function summarize_re_continuation(cont_out_dir::AbstractString)
    m1 = read_mud_min(joinpath(cont_out_dir, "MuD.asc"))
    m2 = read_initial_mu_min(cont_out_dir)
    if m1 === nothing
        return m2
    elseif m2 === nothing
        return m1
    end
    return min(m1, m2)
end

function write_csv(path::AbstractString, header::Vector{String}, rows::Vector{Vector{String}})
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, join(header, ","))
        for row in rows
            println(io, join(row, ","))
        end
    end
end

function main()
    args = parse_args(ARGS)
    base_dir = @__DIR__

    groups = parse_groups(args)
    dry_run = parse_bool(args, "dry-run"; default = false)
    resume = parse_bool(args, "resume"; default = true)
    run_promotion = parse_bool(args, "promote"; default = true)

    seed_Re = parse(Float64, get(args, "R", string(DEFAULT_RE)))
    findsoln_T = parse(Float64, get(args, "T", string(DEFAULT_FINDSOLN_T)))
    res_tol = parse(Float64, get(args, "res-tol", string(DEFAULT_RES_TOL)))

    max_parallel = parse(Int, get(args, "parallel", string(DEFAULT_MAX_PARALLEL)))
    max_dns_seeds = parse(Int, get(args, "max-dns-seeds", "4"))
    max_eqb_per_group = parse(Int, get(args, "max-eqb", "12"))
    max_promoted_seeds = parse(Int, get(args, "max-promoted", "4"))

    findsoln_trials = parse(Int, get(args, "findsoln-trials", string(DEFAULT_FINDSOLN_TRIALS)))
    noise_amp = parse(Float64, get(args, "noise", string(DEFAULT_FINDSOLN_NOISE)))

    geom_conts = parse_list(args, "geom-conts", DEFAULT_GEOM_CONTS)
    geom_dmu = parse(Float64, get(args, "geom-dmu", string(DEFAULT_GEOM_DMU)))
    geom_ns = parse(Int, get(args, "geom-ns", string(DEFAULT_GEOM_NS)))

    re_dmu = parse(Float64, get(args, "re-dmu", string(DEFAULT_RE_DMU)))
    re_ns = parse(Int, get(args, "re-ns", string(DEFAULT_RE_NS)))
    re_target = parse(Float64, get(args, "re-target", string(DEFAULT_RE_TARGET)))
    grid_nx = parse(Int, get(args, "grid-nx", string(DEFAULT_GRID_NX)))
    grid_ny = parse(Int, get(args, "grid-ny", string(DEFAULT_GRID_NY)))
    grid_nz = parse(Int, get(args, "grid-nz", string(DEFAULT_GRID_NZ)))

    ladder = copy(DEFAULT_PROMOTION_LADDER)
    target_rung = DEFAULT_TARGET_RUNG

    out_root = abspath(get(args, "out", joinpath(base_dir, "eqb_alpha_gamma_grid", "dns_space_map")))
    dns_root = abspath(get(args, "dns-root", joinpath(base_dir, "eqb_alpha_gamma_grid", "minre_continuation", "dns_minre")))
    eqb_roots = [
        abspath(joinpath(base_dir, "eqb_alpha_gamma_grid", "3-5-9")),
        abspath(joinpath(base_dir, "eqb_alpha_gamma_grid", "minre_continuation")),
        abspath(joinpath(base_dir, "eqb_alpha_gamma_grid")),
    ]
    reference_path = abspath(get(args, "reference", joinpath(base_dir, "..", "tw_discovery", "TW1-2pi1piRe200-40x49x40.nc")))

    println("== DNS Space Map ==")
    println("groups=$(join(groups, ",")) dry_run=$(dry_run) resume=$(resume)")
    println("seed_Re=$(seed_Re) tol=$(res_tol) parallel=$(max_parallel)")
    println("grid=$(grid_nx)x$(grid_ny)x$(grid_nz)")
    println("dns_root=$(dns_root)")
    println("out_root=$(out_root)")
    mkpath(out_root)

    seeds = collect_existing_dns_seeds(dns_root, groups, seed_Re, res_tol; max_per_group = max_dns_seeds)
    println("[seeds] existing DNS converged seeds: $(length(seeds))")

    promoted = NamedTuple[]
    if run_promotion
        missing = Dict(g => max(0, max_promoted_seeds - count(s -> s.group == g, seeds)) for g in groups)
        promotion_jobs = NamedTuple[]
        for g in groups
            need = missing[g]
            need <= 0 && continue
            candidates = collect_eqb_candidates(g, eqb_roots; max_per_group = max_eqb_per_group)
            if isempty(candidates)
                println("[seeds] no EQB candidates for group $(g)")
                continue
            end
            for c in candidates[1:min(need, length(candidates))]
                push!(promotion_jobs, c)
            end
        end

        if !isempty(promotion_jobs)
            println("[promote] queued EQB->DNS promotions: $(length(promotion_jobs))")
            promotion_results = run_with_limiter(promotion_jobs, max_parallel) do job
                promote_eqb_to_dns(
                    job,
                    out_root,
                    reference_path,
                    ladder,
                    target_rung,
                    findsoln_trials,
                    noise_amp,
                    DEFAULT_HOOKPARAMS,
                    seed_Re,
                    findsoln_T,
                    grid_nx,
                    grid_ny,
                    grid_nz,
                    res_tol;
                    dry_run = dry_run,
                )
            end
            for r in promotion_results
                if r isa NamedTuple && get(r, :ok, false)
                    push!(promoted, r)
                    println(
                        @sprintf(
                            "[promote] ok group=%s Lx=%.4f Lz=%.4f residual=%g",
                            r.group,
                            r.Lx,
                            r.Lz,
                            r.residual,
                        ),
                    )
                elseif r isa NamedTuple
                    println("[promote] failed reason=$(get(r, :reason, "error"))")
                end
            end
        end
    end

    for r in promoted
        push!(seeds, (
            group = r.group,
            Lx = r.Lx,
            Lz = r.Lz,
            id = r.id,
            seed_path = r.seed_path,
            symm_path = r.symm_path,
            residual = r.residual,
            source = r.source,
            label = r.label,
        ))
    end

    if isempty(seeds)
        println("[stop] no DNS seeds available")
        return
    end

    # Deduplicate by exact seed path.
    seen_seed_path = Set{String}()
    seeds_unique = NamedTuple[]
    for s in seeds
        p = abspath(s.seed_path)
        p in seen_seed_path && continue
        push!(seen_seed_path, p)
        push!(seeds_unique, s)
    end
    seeds = seeds_unique
    println("[seeds] total seeds for continuation: $(length(seeds))")

    # Force all continuation seeds onto a common DNS grid.
    seeds = [
        regrid_seed(s, out_root, grid_nx, grid_ny, grid_nz; dry_run = dry_run, resume = resume) for
        s in seeds
    ]
    println("[seeds] grid-prepared seeds: $(length(seeds))")

    geom_jobs = NamedTuple[]
    for s in seeds
        for cont in geom_conts
            for sign in (-1, 1)
                dir_tag = sign < 0 ? "minus" : "plus"
                out_dir = joinpath(
                    out_root,
                    "continuation",
                    s.group,
                    s.label,
                    @sprintf("cont_%s_%s", cont, dir_tag),
                )
                push!(geom_jobs, (
                    seed = s,
                    cont = cont,
                    dmu = sign * geom_dmu,
                    ns = geom_ns,
                    out_dir = out_dir,
                ))
            end
        end
    end

    println("[geom] jobs: $(length(geom_jobs))")
    geom_results = run_with_limiter(geom_jobs, max_parallel) do job
        run_continuesoln_job(
            job.seed.seed_path,
            job.out_dir;
            cont = job.cont,
            eqb = true,
            R = seed_Re,
            T = findsoln_T,
            symms = job.seed.symm_path,
            od = job.out_dir,
            dmu = job.dmu,
            ns = job.ns,
            dry_run = dry_run,
            resume = resume,
        )
    end

    re_jobs = NamedTuple[]
    for (idx, gr) in enumerate(geom_results)
        gj = geom_jobs[idx]
        if !(gr isa NamedTuple) || !get(gr, :ok, false)
            continue
        end
        if dry_run
            # Add a synthetic point per geometry job in dry-run mode.
            push!(re_jobs, (
                seed = gj.seed,
                src_tag = "dryrun",
                ubest = gj.seed.seed_path,
                Lx = gj.seed.Lx,
                Lz = gj.seed.Lz,
                mu = NaN,
                out_dir = joinpath(gj.out_dir, "cont_Re_from_seed"),
            ))
            continue
        end
        points = collect_geometry_points(gj.out_dir, gj.cont, gj.seed.Lx, gj.seed.Lz, gj.seed.seed_path)
        for p in points
            re_dir = joinpath(gj.out_dir, "cont_Re_from_" * p.tag)
            push!(re_jobs, (
                seed = gj.seed,
                src_tag = "$(gj.cont):$(p.tag)",
                ubest = p.ubest,
                Lx = p.Lx,
                Lz = p.Lz,
                mu = p.mu,
                out_dir = re_dir,
            ))
        end
    end

    # Deduplicate Re jobs by output directory.
    seen_re = Set{String}()
    re_jobs_unique = NamedTuple[]
    for j in re_jobs
        key = abspath(j.out_dir)
        key in seen_re && continue
        push!(seen_re, key)
        push!(re_jobs_unique, j)
    end
    re_jobs = re_jobs_unique

    println("[re] jobs: $(length(re_jobs))")
    re_results = run_with_limiter(re_jobs, max_parallel) do job
        run_continuesoln_job(
            job.ubest,
            job.out_dir;
            cont = "Re",
            eqb = true,
            R = seed_Re,
            T = findsoln_T,
            symms = job.seed.symm_path,
            od = job.out_dir,
            dmu = re_dmu,
            ns = re_ns,
            targ = true,
            targMu = re_target,
            dry_run = dry_run,
            resume = resume,
        )
    end

    rows = Vector{Vector{String}}()
    for (idx, rr) in enumerate(re_results)
        job = re_jobs[idx]
        ok = rr isa NamedTuple && get(rr, :ok, false)
        re_min = dry_run ? NaN : something(summarize_re_continuation(job.out_dir), NaN)
        push!(rows, [
            job.seed.group,
            job.seed.source,
            job.seed.label,
            @sprintf("%.4f", job.seed.Lx),
            @sprintf("%.4f", job.seed.Lz),
            job.src_tag,
            isnan(job.mu) ? "" : @sprintf("%.8f", job.mu),
            isnan(job.Lx) ? "" : @sprintf("%.8f", job.Lx),
            isnan(job.Lz) ? "" : @sprintf("%.8f", job.Lz),
            isnan(re_min) ? "" : @sprintf("%.8f", re_min),
            ok ? "ok" : "failed",
            abspath(job.out_dir),
        ])
    end

    results_csv = joinpath(out_root, "re_min_map.csv")
    write_csv(
        results_csv,
        ["group", "seed_source", "seed_label", "seed_Lx", "seed_Lz", "point_tag", "mu", "point_Lx", "point_Lz", "min_Re", "status", "out_dir"],
        rows,
    )

    println("[done] wrote $(length(rows)) rows to $(results_csv)")
end

main()

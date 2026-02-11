import Pkg
Pkg.activate("../../.")

using CloudAtlas
using LinearAlgebra
using DelimitedFiles
using Printf
using Random

const J = 1
const K = 3
const L = 5
const Re = 300.0

const DEFAULT_LX_MIN = 8.0
const DEFAULT_LX_MAX = 12.0
const DEFAULT_LX_N = 30
const DEFAULT_LZ_MIN = 5.0
const DEFAULT_LZ_MAX = 8.0
const DEFAULT_LZ_N = 30

const N_TRIALS = 3
const NOISE_AMPLITUDE = 0.0
const HOOKPARAMS = SearchParams(; ftol = 1e-8, xtol = 1e-10, Nnewton = 25, Nhook = 6, verbosity = 0)

const legacy_groups = Set(["D"])
const default_groups = ["A", "B", "C", "E", "F", "G"]

function symmetry_groups()
    sx, sy, sz, tx, tz = halfbox_symmetries()
    return [
        (name = "A", desc = "<sxyz, txz>", H = [sx * sy * sz, tx * tz]),
        (name = "B", desc = "<sxy, sz>", H = [sx * sy, sz]),
        (name = "C", desc = "<sxytz, sz>", H = [sx * sy * tz, sz]),
        (name = "D", desc = "<sxy, sztx>", H = [sx * sy, sz * tx]),
        (name = "E", desc = "<sxyz, sztxz>", H = [sx * sy * sz, sz * tx * tz]),
        (name = "F", desc = "<sxy, sz, txz>", H = [sx * sy, sz, tx * tz]),
        (name = "G", desc = "<sxyz>", H = [sx * sy * sz]),
    ]
end

function eqb_filename(group_prefix, Lx, Lz, id)
    if isempty(group_prefix)
        return @sprintf("eqb_Lx%.4f_Lz%.4f_id%03d.asc", Lx, Lz, id)
    end
    return @sprintf("eqb_%s_Lx%.4f_Lz%.4f_id%03d.asc", group_prefix, Lx, Lz, id)
end

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

function parse_group_args(args::Dict{String, String}, groups)
    names = [g.name for g in groups]
    if get(args, "all", "false") == "true"
        return names
    end
    if haskey(args, "groups")
        req = [strip(s) for s in split(args["groups"], ",") if !isempty(strip(s))]
        for g in req
            g in names || error("Unknown group '$g'. Available: $(join(names, ", "))")
        end
        return req
    end
    return default_groups
end

function read_min_re(min_re_path)
    X = readdlm(min_re_path, ',', Float64; skipstart = 1)
    if isempty(X)
        return nothing
    end
    if ndims(X) == 1
        X = reshape(X, 1, length(X))
    end
    # columns: Lx, Lz, id, min_Re
    min_idx = argmin(X[:, 4])
    return (Lx = X[min_idx, 1], Lz = X[min_idx, 2], id = Int(round(X[min_idx, 3])), min_Re = X[min_idx, 4])
end

function round_key(value::Real; ndigits::Int = 4)
    return round(Float64(value); digits = ndigits)
end

function load_eqb_vector(path)
    X = readdlm(path, comments = true, comment_char = '#')
    if ndims(X) == 1
        return vec(X)
    end
    return vec(X[:, 1])
end

function solve_eqb(model, Re, xguess, hookparams)
    f = x -> model.f(x, Re)
    Df = x -> model.Df(x, Re)
    return hookstepsolve(f, Df, xguess, hookparams)
end

function summarize_solution(model, Dmat, x, Re)
    res = norm(model.f(x, Re)) / max(norm(x), eps(eltype(x)))
    I = power_input(model, x)
    D = dissipation_rate(Dmat, x)
    return (norm = norm(x), shear = I, dissipation = D, res = res)
end

function find_index(vals::Vector{Float64}, target::Float64; atol = 1e-6)
    for (i, v) in pairs(vals)
        if isapprox(v, target; atol = atol, rtol = 0.0)
            return i
        end
    end
    _, idx = findmin(abs.(vals .- target))
    return idx
end

function load_grid_from_summary(summary_path)
    if !isfile(summary_path)
        return nothing
    end
    X = readdlm(summary_path, ',', Float64; skipstart = 1)
    if isempty(X)
        return nothing
    end
    if ndims(X) == 1
        X = reshape(X, 1, length(X))
    end
    Lx_vals = sort(unique(X[:, 1]))
    Lz_vals = sort(unique(X[:, 2]))
    if isempty(Lx_vals) || isempty(Lz_vals)
        return nothing
    end
    return Lx_vals, Lz_vals
end

function parse_eqb_filename(fname)
    m = match(r"eqb_(?:[A-Za-z]+_)?Lx([0-9.]+)_Lz([0-9.]+)_id([0-9]+)\.asc", fname)
    if m === nothing
        return nothing
    end
    return (Lx = parse(Float64, m.captures[1]), Lz = parse(Float64, m.captures[2]), id = parse(Int, m.captures[3]))
end

function bootstrap_existing(out_dir, Lx_vals, Lz_vals)
    solved = Dict{Tuple{Int, Int}, Vector{Float64}}()
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

function neighbor_indices(idx::Tuple{Int, Int}, nLx, nLz)
    i, j = idx
    out = Tuple{Int, Int}[]
    i > 1 && push!(out, (i - 1, j))
    i < nLx && push!(out, (i + 1, j))
    j > 1 && push!(out, (i, j - 1))
    j < nLz && push!(out, (i, j + 1))
    return out
end

function run_group(group, group_root, out_root, args)
    group_name = group.name
    group_prefix = group_name in legacy_groups ? "" : group_name
    group_dir = joinpath(group_root, group_name)
    if !isdir(group_dir)
        println("[skip] missing group dir: $group_dir")
        return
    end

    min_re_candidates = [
        joinpath(group_dir, "bifurcations", "min_re_$(group_name).csv"),
        joinpath(group_dir, "bifurcations", "min_re.csv"),
    ]
    min_re_path = nothing
    for path in min_re_candidates
        if isfile(path)
            min_re_path = path
            break
        end
    end
    if min_re_path === nothing
        println("[skip] missing min Re file for group $(group_name)")
        return
    end

    min_row = read_min_re(min_re_path)
    min_row === nothing && return

    Lx0 = round_key(min_row.Lx)
    Lz0 = round_key(min_row.Lz)
    id = min_row.id

    eqb_path = joinpath(group_dir, eqb_filename(group_prefix, Lx0, Lz0, id))
    if !isfile(eqb_path)
        println("[skip] missing eqb file: $eqb_path")
        return
    end

    summary_suffix = isempty(group_prefix) ? "" : "_$(group_prefix)"
    summary_guess = joinpath(group_dir, "summary$(summary_suffix).csv")
    grid_mode = get(args, "grid", "auto")
    grid = nothing
    if grid_mode == "summary" || (grid_mode == "auto" && isfile(summary_guess))
        grid = load_grid_from_summary(summary_guess)
        if grid === nothing && grid_mode == "summary"
            error("Summary grid missing/empty for group $(group_name): $(summary_guess)")
        end
    end
    if grid === nothing
        Lx_vals = collect(range(
            parse(Float64, get(args, "Lx-min", string(DEFAULT_LX_MIN))),
            parse(Float64, get(args, "Lx-max", string(DEFAULT_LX_MAX)));
            length = parse(Int, get(args, "Lx-n", string(DEFAULT_LX_N))),
        ))
        Lz_vals = collect(range(
            parse(Float64, get(args, "Lz-min", string(DEFAULT_LZ_MIN))),
            parse(Float64, get(args, "Lz-max", string(DEFAULT_LZ_MAX)));
            length = parse(Int, get(args, "Lz-n", string(DEFAULT_LZ_N))),
        ))
    else
        Lx_vals, Lz_vals = grid
    end

    out_dir = joinpath(out_root, group_name)
    mkpath(out_dir)

    i0 = find_index(Lx_vals, Lx0)
    j0 = find_index(Lz_vals, Lz0)
    println("[seed] group=$(group_name) Lx=$(Lx_vals[i0]) Lz=$(Lz_vals[j0]) id=$(id)")

    trials = parse(Int, get(args, "trials", string(N_TRIALS)))
    noise_amp = parse(Float64, get(args, "noise", string(NOISE_AMPLITUDE)))

    solved = bootstrap_existing(out_dir, Lx_vals, Lz_vals)
    seed_x = load_eqb_vector(eqb_path)
    solved[(i0, j0)] = seed_x

    queue = collect(keys(solved))
    attempts = Dict{Tuple{Int, Int}, Int}()
    max_attempts = parse(Int, get(args, "max-attempts", "4"))
    rng = MersenneTwister(0xC0FFEE + hash(group_name))

    front = 1
    while front <= length(queue)
        idx = queue[front]
        front += 1
        x_base = solved[idx]
        for nbr in neighbor_indices(idx, length(Lx_vals), length(Lz_vals))
            haskey(solved, nbr) && continue
            attempts[nbr] = get(attempts, nbr, 0) + 1
            attempts[nbr] > max_attempts && continue

            i, j = nbr
            Lx = Lx_vals[i]
            Lz = Lz_vals[j]
            alpha = 2pi / Lx
            gamma = 2pi / Lz
            model = ODEModel(alpha, gamma, J, K, L, group.H)
            if length(x_base) != size(model.ijkl, 1)
                error("State length $(length(x_base)) does not match model size $(size(model.ijkl, 1))")
            end

            converged = false
            x_star = x_base
            for trial in 1:trials
                if trial == 1 || noise_amp == 0.0
                    x_guess = x_base
                else
                    noise = (rand(rng, length(x_base)) .- 0.5) .* (2 * noise_amp)
                    x_guess = x_base .+ noise
                end
                x_star, converged = solve_eqb(model, Re, x_guess, HOOKPARAMS)
                converged && break
            end

            if converged
                solved[nbr] = x_star
                push!(queue, nbr)
                fname = eqb_filename(group_prefix, Lx, Lz, id)
                save(x_star, joinpath(out_dir, fname))
                println("[ok] group=$(group_name) Lx=$(Lx) Lz=$(Lz) from idx=$(idx)")
            elseif attempts[nbr] == max_attempts
                println("[fail] group=$(group_name) Lx=$(Lx) Lz=$(Lz) after $(max_attempts) attempts")
            end
        end
    end

    summary_path = joinpath(out_dir, "summary$(summary_suffix).csv")
    completed_path = joinpath(out_dir, "completed_grid$(summary_suffix).csv")
    unsolved_path = joinpath(out_dir, "unsolved_grid$(summary_suffix).csv")

    solved_keys = sort(collect(keys(solved)))
    open(summary_path, "w") do io
        println(io, "Lx,Lz,alpha,gamma,id,norm,shear,dissipation,residual")
        for (i, j) in solved_keys
            Lx = Lx_vals[i]
            Lz = Lz_vals[j]
            alpha = 2pi / Lx
            gamma = 2pi / Lz
            model = ODEModel(alpha, gamma, J, K, L, group.H)
            Dmat = build_dissipation_matrix(model)
            summ = summarize_solution(model, Dmat, solved[(i, j)], Re)
            println(
                io,
                "$(Lx),$(Lz),$(alpha),$(gamma),$(id),$(summ.norm),$(summ.shear),$(summ.dissipation),$(summ.res)",
            )
        end
    end

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
end

function main()
    args = parse_args(ARGS)
    base_dir = @__DIR__
    group_root = get(args, "root", joinpath(base_dir, "eqb_alpha_gamma_grid"))
    out_root = get(args, "out", joinpath(group_root, "minre_continuation"))
    mkpath(out_root)

    groups = symmetry_groups()
    requested = parse_group_args(args, groups)
    names = Set(requested)
    for g in groups
        if g.name in names
            println("\n=============================")
            println("Continuing group $(g.name) $(g.desc)")
            println("Input dir: $(joinpath(group_root, g.name))")
            println("Output dir: $(joinpath(out_root, g.name))")
            println("=============================")
            run_group(g, group_root, out_root, args)
        end
    end
end

main()

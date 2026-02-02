# import Pkg
# Pkg.activate("../../.")

using CloudAtlas
using LinearAlgebra
using Random
using Statistics
using DelimitedFiles
using Printf
using Base.Threads
using CairoMakie
import BifurcationKit as BK
using Plots

# -------------------------
# Configuration
# -------------------------
# Discretization
const J = 1
const K = 3
const L = 5

# Reynolds number
const Re = 300.0

# Grid in physical box sizes
const Lx_vals = range(5, 15; length = 25)
const Lz_vals = range(2, 10; length = 25)

# Number of guesses per grid point
const N = 1000

# Guess strategy
const guess_strategy = :shear_band
const shear_min = 1.0
const shear_max = 3.0
const rest_scale = 0.1
const frac = 0.9        # fraction of |shear| mass for dominant modes
const top_k = nothing   # alternatively choose a fixed number of dominant modes

# Accept/reject threshold for equilibria
const norm_threshold = 1e-3
# Dedup tolerances
const fp_tol = (cx = 1e-3, cz = 1e-3, nm = 2e-2, shear = 2e-2)

# Solver parameters
const hookparams = SearchParams(ftol = 1e-8, xtol = 1e-10, Nnewton = 25, Nhook = 6, verbosity = 0)

# Continuation settings (edit as needed)
const cont_Re_min = 100.0
const cont_Re_max = 500.0
const cont_max_steps = 2000
const cont_dsmin = 1e-7
const cont_dsmax = 1.0

# Resume + threading
const resume_enabled = true
const use_threads_grid = true
const use_threads_bifurcation = false

# Which stages to run
const run_bifurcations = true
const write_heatmaps = true

# Default group list (override with --groups=A,B or --all)
const default_groups = ["A", "B", "C", "E", "F", "G"]
# Groups that use legacy naming (no group prefix in filenames)
const legacy_groups = Set(["D"])

# Output root
const group_root = joinpath(@__DIR__, "eqb_alpha_gamma_grid")

# -------------------------
# Symmetry groups
# -------------------------
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

function parse_group_args(all_groups)
    names = [g.name for g in all_groups]
    for arg in ARGS
        if arg == "--all"
            return names
        elseif startswith(arg, "--groups=")
            grp_str = split(arg, "=", limit = 2)[2]
            req = [strip(s) for s in split(grp_str, ",") if !isempty(strip(s))]
            for g in req
                g in names || error("Unknown group '$g'. Available: $(join(names, ", "))")
            end
            return req
        end
    end
    return default_groups
end

# -------------------------
# Utility / progress
# -------------------------
mutable struct ProgressState
    counter::Threads.Atomic{Int}
    total::Int
    start_time::Float64
    last_print::Float64
    min_interval::Float64
    lock::ReentrantLock
    label::String
    initial_done::Int
end

function make_progress(label, total; initial_done = 0, min_interval = 5.0)
    state = ProgressState(Threads.Atomic{Int}(initial_done), total, time(), 0.0, min_interval, ReentrantLock(), label, initial_done)
    return state
end

function format_hhmmss(seconds::Float64)
    if !isfinite(seconds) || seconds < 0
        return "--:--:--"
    end
    secs = max(0, round(Int, seconds))
    h = div(secs, 3600)
    m = div(mod(secs, 3600), 60)
    s = mod(secs, 60)
    return @sprintf("%02d:%02d:%02d", h, m, s)
end

function progress_print(state::ProgressState; force = false)
    done = state.counter[]
    processed = done - state.initial_done
    now = time()
    elapsed = now - state.start_time
    if processed > 0
        rate = elapsed / processed
        eta = rate * (state.total - done)
    else
        eta = NaN
    end
    pct = 100 * done / state.total
    if force || done == state.total || (now - state.last_print) >= state.min_interval
        state.last_print = now
        @printf("[%s] %d/%d (%.1f%%), elapsed %s, ETA %s\n",
            state.label, done, state.total, pct, format_hhmmss(elapsed), format_hhmmss(eta))
    end
end

function progress_update!(state::ProgressState)
    Threads.atomic_add!(state.counter, 1)
    lock(state.lock) do
        progress_print(state)
    end
end

function find_index(vals::Vector{Float64}, target::Float64; atol = 1e-6)
    for (i, v) in pairs(vals)
        if isapprox(v, target; atol = atol, rtol = 0.0)
            return i
        end
    end
    return nothing
end

function centers_to_edges(vals::Vector{Float64})
    n = length(vals)
    if n == 1
        delta = 1.0
        return [vals[1] - delta / 2, vals[1] + delta / 2]
    end
    mids = (vals[1:end-1] .+ vals[2:end]) ./ 2
    left = vals[1] - (mids[1] - vals[1])
    right = vals[end] + (vals[end] - mids[end])
    return vcat(left, mids, right)
end

# -------------------------
# File naming / IO
# -------------------------
function eqb_filename(group_prefix, Lx, Lz, id)
    if isempty(group_prefix)
        return @sprintf("eqb_Lx%.4f_Lz%.4f_id%03d.asc", Lx, Lz, id)
    end
    return @sprintf("eqb_%s_Lx%.4f_Lz%.4f_id%03d.asc", group_prefix, Lx, Lz, id)
end

function bif_filename(group_prefix, Lx, Lz, id)
    if isempty(group_prefix)
        return @sprintf("bif_Lx%.4f_Lz%.4f_id%03d.csv", Lx, Lz, id)
    end
    return @sprintf("bif_%s_Lx%.4f_Lz%.4f_id%03d.csv", group_prefix, Lx, Lz, id)
end

function plot_filename(group_prefix, Lx, Lz, id)
    if isempty(group_prefix)
        return @sprintf("bif_Lx%.4f_Lz%.4f_id%03d.png", Lx, Lz, id)
    end
    return @sprintf("bif_%s_Lx%.4f_Lz%.4f_id%03d.png", group_prefix, Lx, Lz, id)
end

function parse_eqb_filename(fname, group_prefix)
    if isempty(group_prefix)
        pat = r"^eqb_Lx([0-9\.]+)_Lz([0-9\.]+)_id(\d+)\.asc$"
        m = match(pat, fname)
        m === nothing && return nothing
        Lx = parse(Float64, m.captures[1])
        Lz = parse(Float64, m.captures[2])
        id = parse(Int, m.captures[3])
        return (Lx, Lz, id)
    end
    pat = Regex("^eqb_" * group_prefix * "_Lx([0-9\\.]+)_Lz([0-9\\.]+)_id(\\d+)\\.asc\\z")
    m = match(pat, fname)
    m === nothing && return nothing
    Lx = parse(Float64, m.captures[1])
    Lz = parse(Float64, m.captures[2])
    id = parse(Int, m.captures[3])
    return (Lx, Lz, id)
end

function load_existing_results(summary_path)
    results = NamedTuple[]
    if !isfile(summary_path)
        return results
    end
    open(summary_path, "r") do io
        first = true
        for line in eachline(io)
            if first
                first = false
                continue
            end
            isempty(strip(line)) && continue
            vals = split(line, ',')
            length(vals) < 9 && continue
            Lx = parse(Float64, vals[1])
            Lz = parse(Float64, vals[2])
            alpha = parse(Float64, vals[3])
            gamma = parse(Float64, vals[4])
            id = parse(Int, vals[5])
            normv = parse(Float64, vals[6])
            shearv = parse(Float64, vals[7])
            diss = parse(Float64, vals[8])
            res = parse(Float64, vals[9])
            push!(results, (Lx = Lx, Lz = Lz, alpha = alpha, gamma = gamma, id = id,
                norm = normv, shear = shearv, dissipation = diss, res = res))
        end
    end
    return results
end

function load_completed_grid(completed_path)
    done = Set{Tuple{Float64, Float64}}()
    if !isfile(completed_path)
        return done
    end
    open(completed_path, "r") do io
        first = true
        for line in eachline(io)
            if first
                first = false
                continue
            end
            isempty(strip(line)) && continue
            vals = split(line, ',')
            length(vals) < 2 && continue
            Lx = parse(Float64, vals[1])
            Lz = parse(Float64, vals[2])
            push!(done, (Lx, Lz))
        end
    end
    return done
end

function bootstrap_completed_from_filenames(out_dir, group_prefix)
    done = Set{Tuple{Float64, Float64}}()
    if !isdir(out_dir)
        return done
    end
    for f in readdir(out_dir)
        info = parse_eqb_filename(f, group_prefix)
        info === nothing && continue
        Lx, Lz, _ = info
        push!(done, (Lx, Lz))
    end
    return done
end

function is_completed(Lx, Lz, done_grid; atol = 1e-3)
    for (Lx_d, Lz_d) in done_grid
        if isapprox(Lx, Lx_d; atol = atol) && isapprox(Lz, Lz_d; atol = atol)
            return true
        end
    end
    return false
end

# -------------------------
# Equisolution search
# -------------------------
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

# -------------------------
# Heatmaps
# -------------------------
function write_eqb_count_heatmap(out_dir, group_title, results)
    count_mat = fill(0, length(Lz_vals), length(Lx_vals))
    seen = Set{Tuple{Float64, Float64, Int}}()
    for r in results
        key = (r.Lx, r.Lz, r.id)
        key in seen && continue
        push!(seen, key)
        i = find_index(collect(Lz_vals), r.Lz)
        j = find_index(collect(Lx_vals), r.Lx)
        (i === nothing || j === nothing) && continue
        count_mat[i, j] += 1
    end

    fig = Figure(size = (900, 700))
    ax = Axis(fig[1, 1]; xlabel = "Lz", ylabel = "Lx",
        title = "$(group_title) - # equilibria")
    Lz_edges = centers_to_edges(collect(Lz_vals))
    Lx_edges = centers_to_edges(collect(Lx_vals))
    hm = CairoMakie.heatmap!(ax, Lz_edges, Lx_edges, count_mat; colormap = :viridis)
    Colorbar(fig[1, 2], hm; label = "count")
    CairoMakie.save(joinpath(out_dir, "heatmap_eqb_count.png"), fig)
end

function write_min_re_heatmap(out_dir, group_title, min_re_path)
    if !isfile(min_re_path)
        return
    end
    min_re_map = Dict{Tuple{Float64, Float64}, Float64}()
    open(min_re_path, "r") do io
        first = true
        for line in eachline(io)
            if first
                first = false
                continue
            end
            isempty(strip(line)) && continue
            vals = split(line, ',')
            length(vals) < 4 && continue
            Lx = parse(Float64, vals[1])
            Lz = parse(Float64, vals[2])
            min_Re = parse(Float64, vals[4])
            key = (Lx, Lz)
            min_re_map[key] = min(get(min_re_map, key, Inf), min_Re)
        end
    end

    min_re_mat = fill(NaN, length(Lz_vals), length(Lx_vals))
    for (Lx, Lz) in keys(min_re_map)
        i = find_index(collect(Lz_vals), Lz)
        j = find_index(collect(Lx_vals), Lx)
        (i === nothing || j === nothing) && continue
        min_re_mat[i, j] = min_re_map[(Lx, Lz)]
    end

    fig = Figure(size = (900, 700))
    ax = Axis(fig[1, 1]; xlabel = "Lz", ylabel = "Lx",
        title = "$(group_title) - min Re")
    Lz_edges = centers_to_edges(collect(Lz_vals))
    Lx_edges = centers_to_edges(collect(Lx_vals))
    hm = CairoMakie.heatmap!(ax, Lz_edges, Lx_edges, min_re_mat; colormap = :viridis)
    Colorbar(fig[1, 2], hm; label = "min Re")
    CairoMakie.save(joinpath(out_dir, "heatmap_min_re.png"), fig)
end

# -------------------------
# Bifurcation continuation
# -------------------------
function myreaddlm(filename; cc = '#')
    X = readdlm(filename, comments = true, comment_char = cc)
    if size(X, 2) == 1
        X = X[:, 1]
    end
    return X
end

function continue_eqb(model, x0, Re0;
    Re_min = cont_Re_min,
    Re_max = cont_Re_max,
    max_steps = cont_max_steps,
    dsmin = cont_dsmin,
    dsmax = cont_dsmax)

    fp(x, p) = model.f(x, p[1])

    prob = BK.BifurcationProblem(
        fp,
        x0,
        [Float64(Re0)],
        1;
        record_from_solution = (x, p; k...) -> shear(x, model),
        plot_solution = (x, p; k...) -> shear(x, model),
    )

    newton_opts = BK.NewtonPar(1e-10, 25, false, BK.DefaultLS(), BK.DefaultEig(), false, 1.0, 0.01)
    cont_opts = BK.ContinuationPar(
        p_min = Re_min,
        p_max = Re_max,
        n_inversion = 20,
        dsmin = dsmin,
        dsmax = dsmax,
        max_steps = max_steps,
        newton_options = newton_opts
    )

    return BK.continuation(prob, BK.PALC(), cont_opts, bothside = true)
end

function get_state_vector(sol)
    if sol isa AbstractVector
        return sol
    elseif sol isa NamedTuple
        if haskey(sol, :x)
            return sol.x
        elseif haskey(sol, :u)
            return sol.u
        else
            error("NamedTuple solution does not contain :x or :u; keys=$(keys(sol))")
        end
    else
        error("Unsupported solution type: $(typeof(sol))")
    end
end

function extract_re_shear(br, model)
    Re_vals = hasproperty(br, :branch) ? collect(br.branch.param) : collect(br.param)

    sols = nothing
    if hasproperty(br, :branch) && hasproperty(br.branch, :sol)
        sols = br.branch.sol
    elseif hasproperty(br, :sol)
        sols = br.sol
    end
    sols === nothing && error("No solutions found in ContResult")

    shear_vals = similar(Re_vals)
    for i in eachindex(Re_vals)
        x = get_state_vector(sols[i])
        shear_vals[i] = shear(x, model)
    end
    return Re_vals, shear_vals
end

# -------------------------
# Main workflow
# -------------------------
function run_group(group)
    group_name = group.name
    group_title = "Group $(group_name) $(group.desc)"
    group_prefix = group_name in legacy_groups ? "" : group_name
    summary_suffix = isempty(group_prefix) ? "" : "_$(group_prefix)"
    out_dir = joinpath(group_root, group_name)
    mkpath(out_dir)
    summary_path = joinpath(out_dir, "summary$(summary_suffix).csv")
    completed_path = joinpath(out_dir, "completed_grid$(summary_suffix).csv")

    # Load existing results for resume
    results = load_existing_results(summary_path)
    done_grid = resume_enabled ? load_completed_grid(completed_path) : Set{Tuple{Float64, Float64}}()

    # Bootstrap completed grid from filenames if needed
    if resume_enabled && !isfile(completed_path)
        boot_done = bootstrap_completed_from_filenames(out_dir, group_prefix)
        open(completed_path, "w") do io
            println(io, "Lx,Lz")
            for (Lx, Lz) in sort!(collect(boot_done))
                println(io, "$(Lx),$(Lz)")
            end
        end
        done_grid = boot_done
    end

    # Ensure headers exist
    if !isfile(summary_path)
        open(summary_path, "w") do io
            println(io, "Lx,Lz,alpha,gamma,id,norm,shear,dissipation,residual")
        end
    end
    if !isfile(completed_path)
        open(completed_path, "w") do io
            println(io, "Lx,Lz")
        end
    end

    results_lock = ReentrantLock()
    file_lock = ReentrantLock()
    print_lock = ReentrantLock()

    pairs = [(Lx, Lz) for Lx in Lx_vals for Lz in Lz_vals]
    progress = make_progress("$(group_name) grid", length(pairs); initial_done = length(done_grid), min_interval = 5.0)
    progress_print(progress; force = true)

    function process_grid_point(Lx, Lz)
        if resume_enabled && is_completed(Lx, Lz, done_grid; atol = 1e-2)
            return
        end
        alpha = 2 * pi / Lx
        gamma = 2 * pi / Lz
        lock(print_lock) do
            @printf("\n=== Group %s :: Lx=%.16g, Lz=%.16g (alpha=%.16f, gamma=%.16f) ===\n",
                group_name, Lx, Lz, alpha, gamma)
        end

        model = ODEModel(alpha, gamma, J, K, L, group.H)
        Dmat = build_dissipation_matrix(model)

        sols = Vector{Vector{Float64}}()
        fps = Vector{SolutionFingerprint}()

        rng = MersenneTwister(0xC0FFEE + threadid() + Int(round(Lx * 1000)) + Int(round(Lz * 1000)))

        for attempt in 1:N
            xi_guess = build_guess(
                model, rng;
                strategy = guess_strategy,
                shear_min = shear_min,
                shear_max = shear_max,
                rest_scale = rest_scale,
                frac = frac,
                top_k = top_k,
            )
            x_guess, _, _ = extract_components(xi_guess, model)

            x_sol, converged = solve_eqb(model, Re, x_guess, hookparams)
            if converged
                if norm(x_sol) <= norm_threshold
                    continue
                end
                fp = fingerprint(model, x_sol)
                if is_distinct(fp, fps; tol = fp_tol)
                    push!(fps, fp)
                    push!(sols, x_sol)
                    lock(print_lock) do
                        println("  + unique eqb: ||x||=$(round(norm(x_sol), digits = 4)), shear=$(round(fp.shear, digits = 4))")
                    end
                end
            end
        end

        # Save solutions and summary rows
        for (i, x_sol) in enumerate(sols)
            fname = eqb_filename(group_prefix, Lx, Lz, i)
            CloudAtlas.save(x_sol, joinpath(out_dir, fname))

            summ = summarize_solution(model, Dmat, x_sol, Re)
            row = (
                Lx = Lx, Lz = Lz, alpha = alpha, gamma = gamma, id = i,
                norm = summ.norm, shear = summ.shear, dissipation = summ.dissipation, res = summ.res
            )
            lock(results_lock) do
                push!(results, row)
            end
            lock(file_lock) do
                open(summary_path, "a") do io
                    println(io, "$(row.Lx),$(row.Lz),$(row.alpha),$(row.gamma),$(row.id),$(row.norm),$(row.shear),$(row.dissipation),$(row.res)")
                end
            end
        end

        lock(print_lock) do
            println("Found $(length(sols)) unique equilibria.")
        end

        # Mark grid point completed (even if no solutions)
        lock(file_lock) do
            open(completed_path, "a") do io
                println(io, "$(Lx),$(Lz)")
            end
        end

        progress_update!(progress)
    end

    if use_threads_grid
        Threads.@threads for idx in eachindex(pairs)
            Lx, Lz = pairs[idx]
            process_grid_point(Lx, Lz)
        end
    else
        for (Lx, Lz) in pairs
            process_grid_point(Lx, Lz)
        end
    end

    # Rewrite summary.csv from in-memory results (dedup by Lx,Lz,id)
    seen = Set{Tuple{Float64, Float64, Int}}()
    open(summary_path, "w") do io
        println(io, "Lx,Lz,alpha,gamma,id,norm,shear,dissipation,residual")
        for r in results
            key = (r.Lx, r.Lz, r.id)
            key in seen && continue
            push!(seen, key)
            println(io, "$(r.Lx),$(r.Lz),$(r.alpha),$(r.gamma),$(r.id),$(r.norm),$(r.shear),$(r.dissipation),$(r.res)")
        end
    end

    if write_heatmaps
        write_eqb_count_heatmap(out_dir, group_title, results)
    end

    if !run_bifurcations
        return
    end

    # Bifurcations
    bif_dir = joinpath(out_dir, "bifurcations")
    mkpath(bif_dir)
    min_re_path = joinpath(bif_dir, "min_re$(summary_suffix).csv")
    if !isfile(min_re_path)
        open(min_re_path, "w") do io
            println(io, "Lx,Lz,id,min_Re")
        end
    end

    bif_progress = make_progress("$(group_name) bif", length(results); initial_done = 0, min_interval = 10.0)

    function process_bifurcation(r)
        alpha = r.alpha
        gamma = r.gamma
        Lx = r.Lx
        Lz = r.Lz

        model = ODEModel(alpha, gamma, J, K, L, group.H)

        eqb_file = eqb_filename(group_prefix, Lx, Lz, r.id)
        x0 = myreaddlm(joinpath(out_dir, eqb_file))

        br = continue_eqb(model, x0, Re)

        # Extract Re/shear and save CSV
        Re_vals, shear_vals = extract_re_shear(br, model)
        csv_path = joinpath(bif_dir, bif_filename(group_prefix, Lx, Lz, r.id))
        open(csv_path, "w") do io
            println(io, "Re,shear")
            for i in eachindex(Re_vals)
                println(io, "$(Re_vals[i]),$(shear_vals[i])")
            end
        end

        # Plot and save PNG
        plt = Plots.plot(Re_vals, shear_vals;
            title = "$(group_title): Lx=$(Lx), Lz=$(Lz), id=$(r.id)",
            xlabel = "Re",
            ylabel = "I (shear)"
        )
        out_png = joinpath(bif_dir, plot_filename(group_prefix, Lx, Lz, r.id))
        Plots.savefig(plt, out_png)

        # Save min Re
        min_Re = minimum(Re_vals)
        open(min_re_path, "a") do io
            println(io, "$(Lx),$(Lz),$(r.id),$(min_Re)")
        end

        progress_update!(bif_progress)
    end

    if use_threads_bifurcation
        Threads.@threads for idx in eachindex(results)
            process_bifurcation(results[idx])
        end
    else
        for r in results
            process_bifurcation(r)
        end
    end

    if write_heatmaps
        write_min_re_heatmap(out_dir, group_title, min_re_path)
    end
end

function main()
    groups = symmetry_groups()
    requested = parse_group_args(groups)
    names = Set(requested)
    for g in groups
        if g.name in names
            println("\n=============================")
            println("Running group $(g.name) $(g.desc)")
            println("Output dir: $(joinpath(group_root, g.name))")
            println("=============================")
            run_group(g)
        end
    end
end

main()

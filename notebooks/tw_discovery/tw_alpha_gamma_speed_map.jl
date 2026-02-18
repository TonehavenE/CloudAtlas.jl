import Pkg
Pkg.activate("../../.")

using CloudAtlas
using LinearAlgebra
using Random
using Serialization
using Printf
using Dates
using CairoMakie

function parse_args(args)
    out = Dict{String, String}()
    i = 1
    while i <= length(args)
        arg = args[i]
        if startswith(arg, "--")
            key = arg[3:end]
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

function parse_int(args::Dict{String, String}, key::String; default::Int)
    if !haskey(args, key)
        return default
    end
    v = tryparse(Int, args[key])
    v === nothing && error("Invalid integer for --$(key): $(args[key])")
    return v
end

function parse_float(args::Dict{String, String}, key::String; default::Float64)
    if !haskey(args, key)
        return default
    end
    v = tryparse(Float64, args[key])
    v === nothing && error("Invalid float for --$(key): $(args[key])")
    return v
end

function centers_to_edges(vals::Vector{Float64})
    n = length(vals)
    if n == 1
        return [vals[1] - 0.5, vals[1] + 0.5]
    end
    mids = (vals[1:(end - 1)] .+ vals[2:end]) ./ 2
    left = vals[1] - (mids[1] - vals[1])
    right = vals[end] + (vals[end] - mids[end])
    return vcat(left, mids, right)
end

function nearest_index(vals::Vector{Float64}, x::Float64)
    idx = 1
    dist = abs(vals[1] - x)
    for i in 2:length(vals)
        d = abs(vals[i] - x)
        if d < dist
            dist = d
            idx = i
        end
    end
    return idx
end

function manhattan_visit_order(na::Int, ng::Int, i0::Int, j0::Int)
    coords = [(i, j) for i in 1:na for j in 1:ng]
    sort!(
        coords,
        by = ij -> (
            abs(ij[1] - i0) + abs(ij[2] - j0),
            (ij[1] - i0)^2 + (ij[2] - j0)^2,
            ij[1],
            ij[2],
        ),
    )
    return coords
end

function neighbor_coords(i::Int, j::Int, na::Int, ng::Int)
    out = Tuple{Int, Int}[]
    i > 1 && push!(out, (i - 1, j))
    i < na && push!(out, (i + 1, j))
    j > 1 && push!(out, (i, j - 1))
    j < ng && push!(out, (i, j + 1))
    return out
end

function nearest_solved_guess(
    solved::Dict{Tuple{Int, Int}, Vector{Float64}},
    i::Int,
    j::Int,
)
    best = nothing
    best_d2 = typemax(Int)
    for (ij, xi) in solved
        di = ij[1] - i
        dj = ij[2] - j
        d2 = di * di + dj * dj
        if d2 < best_d2
            best_d2 = d2
            best = xi
        end
    end
    return best
end

function symmetry_generators(name::String)
    sx, sy, sz, tx, tz = CloudAtlas.halfbox_symmetries()
    if name == "sxytxz"
        return [(sx * sy) * (tx * tz)]
    elseif name == "sztx"
        return [sz * tx]
    elseif name == "tx"
        return [tx]
    elseif name == "tz"
        return [tz]
    elseif name == "txtz"
        return [tx * tz]
    elseif name == "sxtx"
        return [sx * tx]
    elseif name == "sxtz"
        return [sx * tz]
    elseif name == "sztz"
        return [sz * tz]
    end
    error("Unknown symmetry group: $(name)")
end

function load_seed_xi(
    seed_archive::String,
    seed_id::Int,
    seed_model::ODEModel,
    target_model::ODEModel,
)
    isfile(seed_archive) || error("Seed archive not found: $(seed_archive)")
    sols = open(seed_archive, "r") do io
        deserialize(io)
    end
    1 <= seed_id <= length(sols) || error("seed_id=$(seed_id) out of range 1:$(length(sols))")

    xi_seed = sols[seed_id]
    x_seed, cx_seed, cz_seed = extract_components(xi_seed, seed_model)

    x_target = if length(seed_model) == length(target_model)
        copy(x_seed)
    else
        changebasis(x_seed, seed_model.ijkl, target_model.ijkl)
    end

    cx_target = target_model.keep_cx ? cx_seed : 0.0
    cz_target = target_model.keep_cz ? cz_seed : 0.0
    return state_to_xi(target_model, ODEState(x_target, cx_target, cz_target))
end

function run_sweep!(
    alpha_vals::Vector{Float64},
    gamma_vals::Vector{Float64},
    seed_i::Int,
    seed_j::Int,
    seed_xi::Vector{Float64},
    Re::Float64,
    J::Int,
    K::Int,
    L::Int,
    H::Vector{Symmetry},
    hookparams::SearchParams;
    fallback_tries::Int = 2,
    fallback_noise::Float64 = 1e-3,
    rng_seed::Int = 12345,
)
    na = length(alpha_vals)
    ng = length(gamma_vals)

    cx_mat = fill(NaN, na, ng)
    cz_mat = fill(NaN, na, ng)
    norm_mat = fill(NaN, na, ng)
    shear_mat = fill(NaN, na, ng)
    residual_mat = fill(NaN, na, ng)
    converged_mat = falses(na, ng)
    source_mat = fill("none", na, ng)
    solved = Dict{Tuple{Int, Int}, Vector{Float64}}()

    order = manhattan_visit_order(na, ng, seed_i, seed_j)
    rng = MersenneTwister(rng_seed)

    total = length(order)
    progress_every = max(1, total ÷ 25)

    for (k, (i, j)) in enumerate(order)
        alpha = alpha_vals[i]
        gamma = gamma_vals[j]
        model = ODEModel(alpha, gamma, J, K, L, H; normalize = false, tw = true)

        guess_pool = Vector{Tuple{String, Vector{Float64}}}()
        if i == seed_i && j == seed_j
            push!(guess_pool, ("seed", copy(seed_xi)))
        end
        for ij in neighbor_coords(i, j, na, ng)
            if haskey(solved, ij)
                push!(guess_pool, ("neighbor_$(ij[1])_$(ij[2])", copy(solved[ij])))
            end
        end
        if isempty(guess_pool)
            nearest = nearest_solved_guess(solved, i, j)
            nearest !== nothing && push!(guess_pool, ("nearest", copy(nearest)))
        end
        if isempty(guess_pool)
            push!(guess_pool, ("seed_fallback", copy(seed_xi)))
        end

        best = nothing
        for (src, xi_guess) in guess_pool
            xref, _, _ = extract_components(xi_guess, model)
            xi_star, ok = CloudAtlas.hookstepsolve(model, Re, xi_guess, hookparams; xref = xref)
            ok || continue

            x, cx, cz = extract_components(xi_star, model)
            res = norm(CloudAtlas.residual(model, x, cx, cz, Re))
            trial = (
                xi = copy(xi_star),
                source = src,
                cx = Float64(cx),
                cz = Float64(cz),
                xnorm = Float64(norm(x)),
                shear = Float64(CloudAtlas.shear(x, model)),
                residual = Float64(res),
            )
            if best === nothing || trial.residual < best.residual
                best = trial
            end
        end

        if best === nothing && fallback_tries > 0
            base = guess_pool[1][2]
            x0, cx0, cz0 = extract_components(base, model)
            for t in 1:fallback_tries
                x_try = x0 .+ fallback_noise .* randn(rng, length(x0))
                xi_try = state_to_xi(model, ODEState(x_try, cx0, cz0))
                xi_star, ok = CloudAtlas.hookstepsolve(model, Re, xi_try, hookparams; xref = x_try)
                ok || continue
                x, cx, cz = extract_components(xi_star, model)
                res = norm(CloudAtlas.residual(model, x, cx, cz, Re))
                trial = (
                    xi = copy(xi_star),
                    source = "noise_$(t)",
                    cx = Float64(cx),
                    cz = Float64(cz),
                    xnorm = Float64(norm(x)),
                    shear = Float64(CloudAtlas.shear(x, model)),
                    residual = Float64(res),
                )
                if best === nothing || trial.residual < best.residual
                    best = trial
                end
            end
        end

        if best !== nothing
            converged_mat[i, j] = true
            cx_mat[i, j] = best.cx
            cz_mat[i, j] = best.cz
            norm_mat[i, j] = best.xnorm
            shear_mat[i, j] = best.shear
            residual_mat[i, j] = best.residual
            source_mat[i, j] = best.source
            solved[(i, j)] = best.xi
        end

        if k % progress_every == 0 || k == total
            nconv = count(converged_mat)
            @printf(
                "[%s] progress %d/%d (%.1f%%), converged=%d\n",
                Dates.format(now(), "HH:MM:SS"),
                k,
                total,
                100 * k / total,
                nconv,
            )
        end
    end

    return (
        converged = converged_mat,
        cx = cx_mat,
        cz = cz_mat,
        xnorm = norm_mat,
        shear = shear_mat,
        residual = residual_mat,
        source = source_mat,
        solved = solved,
    )
end

function write_results_csv(
    out_csv::String,
    alpha_vals::Vector{Float64},
    gamma_vals::Vector{Float64},
    sweep,
)
    open(out_csv, "w") do io
        println(io, "alpha,gamma,Lx,Lz,converged,cx,cz,residual,norm,shear,source")
        for i in eachindex(alpha_vals)
            for j in eachindex(gamma_vals)
                alpha = alpha_vals[i]
                gamma = gamma_vals[j]
                Lx = 2pi / alpha
                Lz = 2pi / gamma
                conv = sweep.converged[i, j]
                if conv
                    println(
                        io,
                        @sprintf(
                            "%.12g,%.12g,%.12g,%.12g,%d,%.12g,%.12g,%.12g,%.12g,%.12g,%s",
                            alpha,
                            gamma,
                            Lx,
                            Lz,
                            1,
                            sweep.cx[i, j],
                            sweep.cz[i, j],
                            sweep.residual[i, j],
                            sweep.xnorm[i, j],
                            sweep.shear[i, j],
                            sweep.source[i, j],
                        ),
                    )
                else
                    println(
                        io,
                        @sprintf(
                            "%.12g,%.12g,%.12g,%.12g,%d,NaN,NaN,NaN,NaN,NaN,%s",
                            alpha,
                            gamma,
                            Lx,
                            Lz,
                            0,
                            sweep.source[i, j],
                        ),
                    )
                end
            end
        end
    end
end

function save_heatmap(
    out_png::String,
    data::Matrix{Float64},
    conv::BitMatrix,
    alpha_vals::Vector{Float64},
    gamma_vals::Vector{Float64},
    seed_i::Int,
    seed_j::Int;
    title::String,
    color_label::String,
    colormap = :viridis,
)
    plot_data = copy(data)
    plot_data[.!conv] .= NaN

    alpha_edges = centers_to_edges(alpha_vals)
    gamma_edges = centers_to_edges(gamma_vals)
    fig = Figure(size = (900, 700))
    ax = Axis(fig[1, 1], xlabel = "gamma", ylabel = "alpha", title = title)
    hm = heatmap!(ax, gamma_edges, alpha_edges, plot_data; colormap = colormap)
    Colorbar(fig[1, 2], hm, label = color_label)

    failed_alpha = Float64[]
    failed_gamma = Float64[]
    for i in eachindex(alpha_vals)
        for j in eachindex(gamma_vals)
            if !conv[i, j]
                push!(failed_alpha, alpha_vals[i])
                push!(failed_gamma, gamma_vals[j])
            end
        end
    end
    if !isempty(failed_alpha)
        scatter!(ax, failed_gamma, failed_alpha; marker = :x, color = :black, markersize = 8)
    end
    scatter!(
        ax,
        [gamma_vals[seed_j]],
        [alpha_vals[seed_i]];
        marker = :star5,
        color = :red,
        markersize = 16,
    )

    save(out_png, fig)
end

function save_convergence_mask(
    out_png::String,
    conv::BitMatrix,
    alpha_vals::Vector{Float64},
    gamma_vals::Vector{Float64},
    seed_i::Int,
    seed_j::Int,
)
    data = Float64.(conv)
    alpha_edges = centers_to_edges(alpha_vals)
    gamma_edges = centers_to_edges(gamma_vals)

    fig = Figure(size = (900, 700))
    ax = Axis(fig[1, 1], xlabel = "gamma", ylabel = "alpha", title = "Convergence Mask")
    hm = heatmap!(ax, gamma_edges, alpha_edges, data; colormap = :grays, colorrange = (0, 1))
    Colorbar(fig[1, 2], hm, label = "converged")
    scatter!(
        ax,
        [gamma_vals[seed_j]],
        [alpha_vals[seed_i]];
        marker = :star5,
        color = :red,
        markersize = 16,
    )
    save(out_png, fig)
end

function main()
    args = parse_args(ARGS)

    seed_group = get(args, "seed-group", "sztx")
    seed_J = parse_int(args, "seed-j"; default = 1)
    seed_K = parse_int(args, "seed-k"; default = 4)
    seed_L = parse_int(args, "seed-l"; default = 5)
    seed_id = parse_int(args, "seed-id"; default = 7)

    sweep_J = parse_int(args, "j"; default = seed_J)
    sweep_K = parse_int(args, "k"; default = seed_K)
    sweep_L = parse_int(args, "l"; default = seed_L)

    Re = parse_float(args, "re"; default = 300.0)
    base_Lx = parse_float(args, "base-lx"; default = 6.0)
    base_Lz = parse_float(args, "base-lz"; default = 4.0)
    alpha0 = 2pi / base_Lx
    gamma0 = 2pi / base_Lz

    alpha_min = parse_float(args, "alpha-min"; default = 0.85 * alpha0)
    alpha_max = parse_float(args, "alpha-max"; default = 1.15 * alpha0)
    gamma_min = parse_float(args, "gamma-min"; default = 0.85 * gamma0)
    gamma_max = parse_float(args, "gamma-max"; default = 1.15 * gamma0)
    n_alpha = parse_int(args, "n-alpha"; default = 25)
    n_gamma = parse_int(args, "n-gamma"; default = 25)

    fallback_tries = parse_int(args, "fallback-tries"; default = 2)
    fallback_noise = parse_float(args, "fallback-noise"; default = 1e-3)
    rng_seed = parse_int(args, "rng-seed"; default = 12345)

    hookparams = SearchParams(
        ftol = parse_float(args, "ftol"; default = 1e-8),
        xtol = parse_float(args, "xtol"; default = 1e-10),
        Nnewton = parse_int(args, "nnewton"; default = 20),
        Nhook = parse_int(args, "nhook"; default = 4),
        Nmusearch = parse_int(args, "nmusearch"; default = 6),
        verbosity = parse_int(args, "verbosity"; default = 0),
    )

    H = symmetry_generators(seed_group)
    archive_default = joinpath(
        @__DIR__,
        "tw_discovery_re300",
        seed_group,
        @sprintf("jkl_%d_%d_%d", seed_J, seed_K, seed_L),
        "solutions.bin",
    )
    seed_archive = abspath(get(args, "seed-archive", archive_default))

    out_default = joinpath(
        @__DIR__,
        "tw_alpha_gamma_speed_map",
        @sprintf(
            "%s_seed%d_re%.0f_jkl_%d_%d_%d",
            seed_group,
            seed_id,
            Re,
            sweep_J,
            sweep_K,
            sweep_L,
        ),
    )
    out_dir = abspath(get(args, "out", out_default))
    mkpath(out_dir)

    alpha_vals = collect(range(alpha_min, alpha_max; length = n_alpha))
    gamma_vals = collect(range(gamma_min, gamma_max; length = n_gamma))
    seed_i = nearest_index(alpha_vals, alpha0)
    seed_j = nearest_index(gamma_vals, gamma0)

    seed_model = ODEModel(alpha0, gamma0, seed_J, seed_K, seed_L, H; normalize = false, tw = true)
    sweep_model0 = ODEModel(alpha0, gamma0, sweep_J, sweep_K, sweep_L, H; normalize = false, tw = true)
    seed_xi = load_seed_xi(seed_archive, seed_id, seed_model, sweep_model0)

    println("Starting alpha-gamma TW speed sweep")
    @printf("seed archive: %s\n", seed_archive)
    @printf("seed group: %s  seed id: %d\n", seed_group, seed_id)
    @printf("sweep J,K,L: %d,%d,%d\n", sweep_J, sweep_K, sweep_L)
    @printf("grid: n_alpha=%d in [%.6f, %.6f], n_gamma=%d in [%.6f, %.6f]\n", n_alpha, alpha_min, alpha_max, n_gamma, gamma_min, gamma_max)
    @printf("seed snapped to grid index (i,j)=(%d,%d) -> alpha=%.6f, gamma=%.6f\n", seed_i, seed_j, alpha_vals[seed_i], gamma_vals[seed_j])

    sweep = run_sweep!(
        alpha_vals,
        gamma_vals,
        seed_i,
        seed_j,
        seed_xi,
        Re,
        sweep_J,
        sweep_K,
        sweep_L,
        H,
        hookparams;
        fallback_tries = fallback_tries,
        fallback_noise = fallback_noise,
        rng_seed = rng_seed,
    )

    out_csv = joinpath(out_dir, "sweep_results.csv")
    write_results_csv(out_csv, alpha_vals, gamma_vals, sweep)

    cx_png = joinpath(out_dir, "heatmap_cx.png")
    save_heatmap(
        cx_png,
        sweep.cx,
        sweep.converged,
        alpha_vals,
        gamma_vals,
        seed_i,
        seed_j;
        title = "TW wavespeed c_x over (alpha, gamma)",
        color_label = "c_x",
        colormap = :balance,
    )

    logres = fill(NaN, size(sweep.residual)...)
    for i in axes(logres, 1), j in axes(logres, 2)
        if sweep.converged[i, j] && isfinite(sweep.residual[i, j]) && sweep.residual[i, j] > 0
            logres[i, j] = log10(sweep.residual[i, j])
        end
    end
    res_png = joinpath(out_dir, "heatmap_log10_residual.png")
    save_heatmap(
        res_png,
        logres,
        sweep.converged,
        alpha_vals,
        gamma_vals,
        seed_i,
        seed_j;
        title = "log10 residual over (alpha, gamma)",
        color_label = "log10(||g||)",
        colormap = :viridis,
    )

    mask_png = joinpath(out_dir, "heatmap_converged.png")
    save_convergence_mask(mask_png, sweep.converged, alpha_vals, gamma_vals, seed_i, seed_j)

    state_path = joinpath(out_dir, "sweep_state.bin")
    open(state_path, "w") do io
        serialize(
            io,
            Dict(
                "alpha_vals" => alpha_vals,
                "gamma_vals" => gamma_vals,
                "seed_i" => seed_i,
                "seed_j" => seed_j,
                "Re" => Re,
                "J" => sweep_J,
                "K" => sweep_K,
                "L" => sweep_L,
                "cx" => sweep.cx,
                "cz" => sweep.cz,
                "xnorm" => sweep.xnorm,
                "shear" => sweep.shear,
                "residual" => sweep.residual,
                "converged" => sweep.converged,
                "source" => sweep.source,
                "solved" => sweep.solved,
            ),
        )
    end

    meta_path = joinpath(out_dir, "run_info.txt")
    open(meta_path, "w") do io
        println(io, "timestamp=$(Dates.now())")
        println(io, "seed_archive=$(seed_archive)")
        println(io, "seed_group=$(seed_group)")
        println(io, "seed_id=$(seed_id)")
        println(io, "seed_jkl=$(seed_J),$(seed_K),$(seed_L)")
        println(io, "sweep_jkl=$(sweep_J),$(sweep_K),$(sweep_L)")
        println(io, "Re=$(Re)")
        println(io, "base_Lx=$(base_Lx)")
        println(io, "base_Lz=$(base_Lz)")
        println(io, "alpha_range=$(alpha_min),$(alpha_max),n=$(n_alpha)")
        println(io, "gamma_range=$(gamma_min),$(gamma_max),n=$(n_gamma)")
        println(io, "fallback_tries=$(fallback_tries)")
        println(io, "fallback_noise=$(fallback_noise)")
        println(io, "rng_seed=$(rng_seed)")
        println(io, "ftol=$(hookparams.ftol)")
        println(io, "xtol=$(hookparams.xtol)")
        println(io, "Nnewton=$(hookparams.Nnewton)")
        println(io, "Nhook=$(hookparams.Nhook)")
        println(io, "Nmusearch=$(hookparams.Nmusearch)")
        println(io, "verbosity=$(hookparams.verbosity)")
    end

    nconv = count(sweep.converged)
    ntot = length(sweep.converged)
    @printf("Done. Converged %d / %d (%.1f%%)\n", nconv, ntot, 100 * nconv / ntot)
    println("Outputs:")
    println("  $(out_csv)")
    println("  $(cx_png)")
    println("  $(res_png)")
    println("  $(mask_png)")
    println("  $(state_path)")
    println("  $(meta_path)")
end

main()

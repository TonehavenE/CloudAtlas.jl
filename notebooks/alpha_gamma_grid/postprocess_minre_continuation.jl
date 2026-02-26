if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "..", ".."))
end

using CloudAtlas
using LinearAlgebra
using DelimitedFiles
using Printf
using CairoMakie
import BifurcationKit as BK
using Plots

const DEFAULT_J = 1
const DEFAULT_K = 3
const DEFAULT_L = 5
const DEFAULT_RE = 300.0

const cont_Re_min = 100.0
const cont_Re_max = 500.0
const cont_max_steps = 2000
const cont_dsmin = 1e-7
const cont_dsmax = 1.0

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
        (name = "sztx", desc = "<sztx>", H = [sz * tx]),
    ]
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

function parse_bool(args::Dict{String, String}, key::String; default::Bool = true)
    if !haskey(args, key)
        return default
    end
    val = lowercase(strip(args[key]))
    return val in ("1", "true", "yes", "y")
end

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
    mids = (vals[1:(end - 1)] .+ vals[2:end]) ./ 2
    left = vals[1] - (mids[1] - vals[1])
    right = vals[end] + (vals[end] - mids[end])
    return vcat(left, mids, right)
end

function read_csv_float_matrix(path::AbstractString; skipstart::Int = 0)
    if !isfile(path)
        return Array{Float64}(undef, 0, 0)
    end
    X = try
        readdlm(path, ',', Float64; skipstart = skipstart)
    catch err
        msg = sprint(showerror, err)
        if err isa ArgumentError && occursin("number of rows in dims must be > 0", msg)
            return Array{Float64}(undef, 0, 0)
        end
        rethrow()
    end
    if isempty(X)
        return Array{Float64}(undef, 0, 0)
    end
    if ndims(X) == 1
        return reshape(X, 1, length(X))
    end
    return X
end

function read_grid_points(path::AbstractString)
    X = read_csv_float_matrix(path; skipstart = 1)
    if isempty(X) || size(X, 2) < 2
        return Float64[], Float64[]
    end
    return vec(X[:, 1]), vec(X[:, 2])
end

function load_grid_values(group_dir, summary_suffix, summary_path)
    completed_path = joinpath(group_dir, "completed_grid$(summary_suffix).csv")
    unsolved_path = joinpath(group_dir, "unsolved_grid$(summary_suffix).csv")
    Lx_vals = Float64[]
    Lz_vals = Float64[]
    for path in (completed_path, unsolved_path, summary_path)
        Lx, Lz = read_grid_points(path)
        append!(Lx_vals, Lx)
        append!(Lz_vals, Lz)
    end
    if isempty(Lx_vals) || isempty(Lz_vals)
        return nothing
    end
    return sort(unique(Lx_vals)), sort(unique(Lz_vals))
end

function load_summary(summary_path)
    X = read_csv_float_matrix(summary_path; skipstart = 1)
    if isempty(X)
        return NamedTuple[]
    end
    results = NamedTuple[]
    for i in 1:size(X, 1)
        row = X[i, :]
        length(row) < 9 && continue
        push!(
            results,
            (
                Lx = row[1],
                Lz = row[2],
                alpha = row[3],
                gamma = row[4],
                id = Int(round(row[5])),
                norm = row[6],
                shear = row[7],
                dissipation = row[8],
                res = row[9],
            ),
        )
    end
    return results
end

function read_bif_min_re(path::AbstractString)
    X = read_csv_float_matrix(path; skipstart = 1)
    if isempty(X) || size(X, 2) < 1
        return nothing
    end
    return minimum(vec(X[:, 1]))
end

function load_min_re_entries(min_re_path::AbstractString)
    out = Dict{Tuple{Float64, Float64, Int}, Float64}()
    if !isfile(min_re_path)
        return out
    end
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
            id = parse(Int, vals[3])
            min_Re = parse(Float64, vals[4])
            key = (Lx, Lz, id)
            out[key] = min(get(out, key, Inf), min_Re)
        end
    end
    return out
end

function write_eqb_count_heatmap(out_dir, group_title, results, Lx_vals, Lz_vals)
    count_mat = fill(0, length(Lz_vals), length(Lx_vals))
    seen = Set{Tuple{Float64, Float64, Int}}()
    for r in results
        key = (r.Lx, r.Lz, r.id)
        key in seen && continue
        push!(seen, key)
        i = find_index(Lz_vals, r.Lz)
        j = find_index(Lx_vals, r.Lx)
        (i === nothing || j === nothing) && continue
        count_mat[i, j] += 1
    end

    fig = Figure(; size = (900, 700))
    ax = Axis(fig[1, 1]; xlabel = "Lz", ylabel = "Lx", title = "$(group_title) - # equilibria")
    Lz_edges = centers_to_edges(Lz_vals)
    Lx_edges = centers_to_edges(Lx_vals)
    hm = CairoMakie.heatmap!(ax, Lz_edges, Lx_edges, count_mat; colormap = :balance)
    Colorbar(fig[1, 2], hm; label = "count")
    return CairoMakie.save(joinpath(out_dir, "heatmap_eqb_count.png"), fig)
end

function write_min_re_heatmap(out_dir, group_title, bif_dir, group_prefix, min_re_path, Lx_vals, Lz_vals, results)
    if !isfile(min_re_path)
        return nothing
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

    # Backfill missing min-Re points from existing bifurcation traces.
    for r in results
        key = (r.Lx, r.Lz)
        if haskey(min_re_map, key)
            continue
        end
        bif_path = joinpath(bif_dir, bif_filename(group_prefix, r.Lx, r.Lz, r.id))
        min_Re = read_bif_min_re(bif_path)
        min_Re === nothing && continue
        min_re_map[key] = min(get(min_re_map, key, Inf), min_Re)
    end

    min_re_mat = fill(NaN, length(Lz_vals), length(Lx_vals))
    for (Lx, Lz) in keys(min_re_map)
        i = find_index(Lz_vals, Lz)
        j = find_index(Lx_vals, Lx)
        (i === nothing || j === nothing) && continue
        min_re_mat[i, j] = min_re_map[(Lx, Lz)]
    end
    valid = filter(!isnan, vec(min_re_mat))
    isempty(valid) && return nothing

    fig = Figure(; size = (900, 700))
    ax = Axis(fig[1, 1]; xlabel = "Lz", ylabel = "Lx", title = "$(group_title) - min Re")
    Lz_edges = centers_to_edges(Lz_vals)
    Lx_edges = centers_to_edges(Lx_vals)
    hm = CairoMakie.heatmap!(
        ax,
        Lz_edges,
        Lx_edges,
        min_re_mat;
        colormap = :balance,
        colorrange = (minimum(valid), maximum(valid)),
        nan_color = :lightgray,
    )
    Colorbar(fig[1, 2], hm; label = "min Re")
    return CairoMakie.save(joinpath(out_dir, "heatmap_min_re.png"), fig)
end

function myreaddlm(filename; cc = '#')
    X = readdlm(filename; comments = true, comment_char = cc)
    if size(X, 2) == 1
        X = X[:, 1]
    end
    return X
end

function continue_eqb(
    model,
    x0,
    Re0;
    Re_min = cont_Re_min,
    Re_max = cont_Re_max,
    max_steps = cont_max_steps,
    dsmin = cont_dsmin,
    dsmax = cont_dsmax,
)
    fp(x, p) = model.f(x, p[1])

    prob = BK.BifurcationProblem(
        fp,
        x0,
        [Float64(Re0)],
        1;
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

    return BK.continuation(prob, BK.PALC(), cont_opts; bothside = true)
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

function run_group(group, group_root, args)
    group_name = group.name
    group_title = "Group $(group_name) $(group.desc)"
    group_prefix = group_name in legacy_groups ? "" : group_name
    J = parse(Int, get(args, "J", string(DEFAULT_J)))
    K = parse(Int, get(args, "K", string(DEFAULT_K)))
    L = parse(Int, get(args, "L", string(DEFAULT_L)))
    Re = parse(Float64, get(args, "Re", string(DEFAULT_RE)))
    summary_suffix = isempty(group_prefix) ? "" : "_$(group_prefix)"

    group_dir = joinpath(group_root, group_name)
    if !isdir(group_dir)
        println("[skip] missing group dir: $group_dir")
        return
    end

    summary_path = joinpath(group_dir, "summary$(summary_suffix).csv")
    results = load_summary(summary_path)
    if isempty(results)
        println("[skip] empty summary: $summary_path")
        return
    end

    grid = load_grid_values(group_dir, summary_suffix, summary_path)
    if grid === nothing
        println("[skip] missing grid values for group $(group_name)")
        return
    end
    Lx_vals, Lz_vals = grid

    run_bifurcations = parse_bool(args, "bif"; default = true)
    write_heatmaps = parse_bool(args, "heatmaps"; default = true)
    bif_dir = joinpath(group_dir, "bifurcations")
    min_re_path = joinpath(bif_dir, "min_re$(summary_suffix).csv")
    source_group_dir = joinpath(dirname(group_root), group_name)

    if write_heatmaps
        write_eqb_count_heatmap(group_dir, group_title, results, Lx_vals, Lz_vals)
        if isfile(min_re_path)
            write_min_re_heatmap(
                group_dir,
                group_title,
                bif_dir,
                group_prefix,
                min_re_path,
                Lx_vals,
                Lz_vals,
                results,
            )
        end
    end

    if !run_bifurcations
        return
    end

    mkpath(bif_dir)
    if !isfile(min_re_path)
        open(min_re_path, "w") do io
            println(io, "Lx,Lz,id,min_Re")
        end
    end
    min_re_entries = load_min_re_entries(min_re_path)

    for r in results
        Lx = r.Lx
        Lz = r.Lz
        alpha = r.alpha
        gamma = r.gamma
        entry_key = (Lx, Lz, r.id)
        haskey(min_re_entries, entry_key) && continue

        csv_path = joinpath(bif_dir, bif_filename(group_prefix, Lx, Lz, r.id))
        if isfile(csv_path)
            min_Re = read_bif_min_re(csv_path)
            if min_Re !== nothing
                open(min_re_path, "a") do io
                    println(io, "$(Lx),$(Lz),$(r.id),$(min_Re)")
                end
                min_re_entries[entry_key] = min_Re
                continue
            end
        end

        eqb_file = eqb_filename(group_prefix, Lx, Lz, r.id)
        eqb_candidates = [
            joinpath(group_dir, eqb_file),
            joinpath(source_group_dir, eqb_file),
        ]
        eqb_path = findfirst(isfile, eqb_candidates)
        if eqb_path === nothing
            println("[skip] missing eqb file: $(eqb_candidates[1]) (and source fallback)")
            continue
        end
        eqb_path = eqb_candidates[eqb_path]

        model = ODEModel(alpha, gamma, J, K, L, group.H)
        x0 = myreaddlm(eqb_path)
        br = continue_eqb(model, x0, Re)

        Re_vals, shear_vals = extract_re_shear(br, model)
        open(csv_path, "w") do io
            println(io, "Re,shear")
            for i in eachindex(Re_vals)
                println(io, "$(Re_vals[i]),$(shear_vals[i])")
            end
        end

        plt = Plots.plot(
            Re_vals,
            shear_vals;
            title = "$(group_title): Lx=$(Lx), Lz=$(Lz), id=$(r.id)",
            xlabel = "Re",
            ylabel = "I (shear)",
        )
        out_png = joinpath(bif_dir, plot_filename(group_prefix, Lx, Lz, r.id))
        Plots.savefig(plt, out_png)

        min_Re = minimum(Re_vals)
        open(min_re_path, "a") do io
            println(io, "$(Lx),$(Lz),$(r.id),$(min_Re)")
        end
        min_re_entries[entry_key] = min_Re
    end

    if write_heatmaps
        write_min_re_heatmap(group_dir, group_title, bif_dir, group_prefix, min_re_path, Lx_vals, Lz_vals, results)
    end
end

function main()
    args = parse_args(ARGS)
    base_dir = @__DIR__
    group_root = get(args, "root", joinpath(base_dir, "eqb_alpha_gamma_grid", "minre_continuation"))

    groups = symmetry_groups()
    requested = parse_group_args(args, groups)
    names = Set(requested)
    for g in groups
        if g.name in names
            println("\n=============================")
            println("Postprocessing group $(g.name) $(g.desc)")
            println("Input/output dir: $(joinpath(group_root, g.name))")
            println("=============================")
            run_group(g, group_root, args)
        end
    end
end

main()

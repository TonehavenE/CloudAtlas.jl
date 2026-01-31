using DelimitedFiles
using CairoMakie
using Makie
using Printf

const TAU = 2pi
const BIF_PATTERN = r"^bif_Lx([0-9.]+)_Lz([0-9.]+)_id(\d+)\.csv$"

struct Branch
    Lx::Float64
    Lz::Float64
    id::Int
    Re::Vector{Float64}
    shear::Vector{Float64}
    min_Re::Float64
end

function read_bifurcation_csv(path::AbstractString)
    data = readdlm(path, ',', Float64; skipstart=1)
    if isempty(data)
        return Float64[], Float64[]
    elseif ndims(data) == 1
        return [data[1]], [data[2]]
    else
        return data[:, 1], data[:, 2]
    end
end

function load_branches(bif_dir::AbstractString)
    branches = Branch[]
    for f in readdir(bif_dir)
        m = match(BIF_PATTERN, f)
        m === nothing && continue
        Lx = parse(Float64, m.captures[1])
        Lz = parse(Float64, m.captures[2])
        id = parse(Int, m.captures[3])
        Re, shear = read_bifurcation_csv(joinpath(bif_dir, f))
        isempty(Re) && continue
        push!(branches, Branch(Lx, Lz, id, Re, shear, minimum(Re)))
    end
    return branches
end

function summarize_grid(branches::Vector{Branch})
    min_Re_map = Dict{Tuple{Float64, Float64}, Float64}()
    count_map = Dict{Tuple{Float64, Float64}, Int}()
    for b in branches
        key = (b.Lx, b.Lz)
        min_Re_map[key] = min(get(min_Re_map, key, Inf), b.min_Re)
        count_map[key] = get(count_map, key, 0) + 1
    end
    return min_Re_map, count_map
end

function find_index(vals::Vector{Float64}, target::Float64; atol=1e-6)
    for (i, v) in pairs(vals)
        if isapprox(v, target; atol=atol, rtol=0.0)
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

function save_min_re_heatmap(out_dir::AbstractString, branches::Vector{Branch})
    min_Re_map, count_map = summarize_grid(branches)
    Lx_vals = sort(unique(b.Lx for b in branches))
    Lz_vals = sort(unique(b.Lz for b in branches))

    min_Re_mat = fill(NaN, length(Lz_vals), length(Lx_vals))
    count_mat = fill(0, length(Lz_vals), length(Lx_vals))

    for (Lx, Lz) in keys(min_Re_map)
        i = find_index(Lz_vals, Lz)
        j = find_index(Lx_vals, Lx)
        (i === nothing || j === nothing) && continue
        min_Re_mat[i, j] = min_Re_map[(Lx, Lz)]
        count_mat[i, j] = count_map[(Lx, Lz)]
    end

    fig = Figure(size = (900, 700))
    ax = Axis(fig[1, 1];
        xlabel = "Lz",
        ylabel = "Lx",
        title = "Minimum Reynolds number by (Lx, Lz)")

    Lz_edges = centers_to_edges(Lz_vals)
    Lx_edges = centers_to_edges(Lx_vals)
    # CairoMakie heatmap expects x/y to match matrix dimensions as (x, y) -> (rows, cols).
    hm = heatmap!(ax, Lz_edges, Lx_edges, min_Re_mat; colormap = :viridis)
    Colorbar(fig[1, 2], hm; label = "min Re")

    save(joinpath(out_dir, "min_re_heatmap.png"), fig)

    # Also save a simple CSV summary
    open(joinpath(out_dir, "min_re_grid.csv"), "w") do io
        println(io, "Lx,Lz,alpha,gamma,min_Re,count")
        for (Lx, Lz) in keys(min_Re_map)
            alpha = TAU / Lx
            gamma = TAU / Lz
            println(io, @sprintf("%.4f,%.4f,%.8f,%.8f,%.8f,%d", Lx, Lz, alpha, gamma, min_Re_map[(Lx, Lz)], count_map[(Lx, Lz)]))
        end
    end
end

function save_animation_for_Lx(out_dir::AbstractString, branches::Vector{Branch}; Lx_target::Float64, fps::Int=8, format::Symbol=:mp4)
    Lx_vals = sort(unique(b.Lx for b in branches))
    _, idx = findmin(abs.(Lx_vals .- Lx_target))
    Lx_sel = Lx_vals[idx]

    id_vals = sort(unique(b.id for b in branches if isapprox(b.Lx, Lx_sel; atol=1e-6)))
    groups = Dict{Float64, Dict{Int, Branch}}()
    for b in branches
        isapprox(b.Lx, Lx_sel; atol=1e-6) || continue
        id_map = get!(groups, b.Lz, Dict{Int, Branch}())
        id_map[b.id] = b
    end

    Lz_vals = sort(collect(keys(groups)))
    isempty(Lz_vals) && error("No branches found for Lx=$(Lx_sel)")

    colors = Makie.wong_colors()

    # Precompute limits to keep axes stable across frames.
    Re_all = reduce(vcat, (b.Re for b in branches if isapprox(b.Lx, Lx_sel; atol=1e-6)))
    shear_all = reduce(vcat, (b.shear for b in branches if isapprox(b.Lx, Lx_sel; atol=1e-6)))
    Re_pad = 0.02 * (maximum(Re_all) - minimum(Re_all))
    shear_pad = 0.02 * (maximum(shear_all) - minimum(shear_all))

    fig = Figure(size = (900, 650))
    ax = Axis(fig[1, 1]; xlabel = "Re", ylabel = "shear")
    limits!(ax, minimum(Re_all) - Re_pad, maximum(Re_all) + Re_pad,
                minimum(shear_all) - shear_pad, maximum(shear_all) + shear_pad)

    re_obs = [Observable(Float64[]) for _ in 1:length(id_vals)]
    shear_obs = [Observable(Float64[]) for _ in 1:length(id_vals)]
    for i in 1:length(id_vals)
        c = colors[mod1(i, length(colors))]
        lines!(ax, re_obs[i], shear_obs[i]; color = c, linewidth = 2)
    end

    out_path = joinpath(out_dir, @sprintf("bifurcation_Lx%.4f.%s", Lx_sel, string(format)))
    record(fig, out_path, Lz_vals; framerate = fps) do Lz
        id_map = get(groups, Lz, Dict{Int, Branch}())
        for (i, id) in enumerate(id_vals)
            b = get(id_map, id, nothing)
            if b === nothing
                re_obs[i][] = Float64[]
                shear_obs[i][] = Float64[]
            else
                re_obs[i][] = b.Re
                shear_obs[i][] = b.shear
            end
        end
        ax.title = @sprintf("Bifurcation slices at Lx=%.4f, Lz=%.4f", Lx_sel, Lz)
    end

    return out_path
end

function build_branch_index(branches::Vector{Branch})
    id_vals = sort(unique(b.id for b in branches))
    by_Lx_Lz = Dict{Tuple{Float64, Float64}, Dict{Int, Branch}}()
    for b in branches
        key = (b.Lx, b.Lz)
        id_map = get!(by_Lx_Lz, key, Dict{Int, Branch}())
        id_map[b.id] = b
    end
    return id_vals, by_Lx_Lz
end

function launch_interactive_viewer(bif_dir::AbstractString; Lx_init::Union{Nothing, Float64}=nothing, Lz_init::Union{Nothing, Float64}=nothing)
    # NOTE: For true interactivity, start Julia with GLMakie or WGLMakie before calling this.
    branches = load_branches(bif_dir)
    isempty(branches) && error("No bifurcation CSVs found in $bif_dir")

    Lx_vals = sort(unique(b.Lx for b in branches))
    Lz_vals = sort(unique(b.Lz for b in branches))
    id_vals, by_Lx_Lz = build_branch_index(branches)

    Lx0 = isnothing(Lx_init) ? Lx_vals[1] : Lx_init
    Lz0 = isnothing(Lz_init) ? Lz_vals[1] : Lz_init

    fig = Figure(size = (1000, 700))
    ax = Axis(fig[1, 1]; xlabel = "Re", ylabel = "shear")

    # Global limits for a stable view across all slider selections.
    Re_all = reduce(vcat, (b.Re for b in branches))
    shear_all = reduce(vcat, (b.shear for b in branches))
    Re_pad = 0.02 * (maximum(Re_all) - minimum(Re_all))
    shear_pad = 0.02 * (maximum(shear_all) - minimum(shear_all))
    limits!(ax,
        minimum(Re_all) - Re_pad, maximum(Re_all) + Re_pad,
        minimum(shear_all) - shear_pad, maximum(shear_all) + shear_pad)

    Lx_slider = Slider(fig[2, 1]; range = Lx_vals, startvalue = Lx0, width = Relative(1))
    Lz_slider = Slider(fig[3, 1]; range = Lz_vals, startvalue = Lz0, width = Relative(1))

    label_obs = Observable("")
    label = Label(fig[0, 1], label_obs; tellwidth = false)

    re_obs = [Observable(Float64[]) for _ in 1:length(id_vals)]
    shear_obs = [Observable(Float64[]) for _ in 1:length(id_vals)]
    colors = Makie.wong_colors()
    for i in 1:length(id_vals)
        c = colors[mod1(i, length(colors))]
        lines!(ax, re_obs[i], shear_obs[i]; color = c, linewidth = 2)
    end

    function update_plot(Lx, Lz)
        key = (Lx, Lz)
        id_map = get(by_Lx_Lz, key, Dict{Int, Branch}())
        for (i, id) in enumerate(id_vals)
            b = get(id_map, id, nothing)
            if b === nothing
                re_obs[i][] = Float64[]
                shear_obs[i][] = Float64[]
            else
                re_obs[i][] = b.Re
                shear_obs[i][] = b.shear
            end
        end
        label_obs[] = @sprintf("Lx=%.4f, Lz=%.4f (showing %d branches)", Lx, Lz, length(id_map))
    end

    onany(Lx_slider.value, Lz_slider.value) do Lx, Lz
        update_plot(Lx, Lz)
    end

    update_plot(Lx0, Lz0)
    return fig
end

function main()
    base_dir = @__DIR__
    bif_dir = joinpath(base_dir, "eqb_alpha_gamma_grid", "bifurcations")
    out_dir = joinpath(base_dir, "eqb_alpha_gamma_grid", "viz")
    mkpath(out_dir)

    branches = load_branches(bif_dir)
    isempty(branches) && error("No bifurcation CSVs found in $bif_dir")

    save_min_re_heatmap(out_dir, branches)

    # Example: generate a Makie animation at a chosen Lx.
    anim_path = save_animation_for_Lx(out_dir, branches; Lx_target = 15.0, fps = 8, format = :mp4)
    @info "Saved animation to" anim_path

    # Interactive viewer (requires an interactive Makie backend).
    # fig = launch_interactive_viewer(bif_dir; Lx_init = 15.0, Lz_init = 2.0)
    # display(fig)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

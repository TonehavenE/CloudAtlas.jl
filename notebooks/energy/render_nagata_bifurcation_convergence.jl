if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "..", ".."))
end

using CairoMakie
using Printf

const DEFAULT_ANALYSIS_DIR = joinpath(@__DIR__, "nagata_comprehensive_analysis")
const DEFAULT_REFERENCE_CURVE = joinpath(@__DIR__, "..", "data", "eq1ReD-DNS.asc")

const FIG_FONTSIZE = 60
const AXIS_LABELSIZE = 64
const AXIS_TITLESIZE = 76
const TICK_LABELSIZE = 58
const LEGEND_LABELSIZE = 56
const LEGEND_TITLESIZE = 58
const EXPORT_PX_PER_UNIT = 2.5

const MODEL_COLORS = [
    :midnightblue,
    :dodgerblue3,
    :deepskyblue3,
    :darkorange1,
    :orangered1,
    :red,
]

function parse_args(args::Vector{String})
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

function myreaddlm(filename; cc = '#')
    rows = Vector{NTuple{2, Float64}}()
    is_csv = endswith(lowercase(filename), ".csv")
    for raw in eachline(filename)
        line = strip(raw)
        isempty(line) && continue
        if !is_csv
            pos = findfirst(==(cc), line)
            if !isnothing(pos)
                line = strip(line[begin:prevind(line, pos)])
            end
        end
        isempty(line) && continue
        parts = is_csv ? split(line, ',') : split(line)
        length(parts) < 2 && continue
        x = parse(Float64, strip(parts[1]))
        y = parse(Float64, strip(parts[2]))
        push!(rows, (x, y))
    end
    mat = Matrix{Float64}(undef, length(rows), 2)
    for (i, (x, y)) in enumerate(rows)
        mat[i, 1] = x
        mat[i, 2] = y
    end
    return mat
end

function model_dirs(base_dir::AbstractString)
    dirs = String[]
    for name in readdir(base_dir)
        startswith(name, "m_") || continue
        path = joinpath(base_dir, name)
        isdir(path) || continue
        isfile(joinpath(path, "bifurcation_curve.csv")) || continue
        push!(dirs, path)
    end
    sort!(dirs; by = d -> parse(Int, split(basename(d), "_")[2]))
    return dirs
end

function model_color(i::Int, n::Int)
    if n <= length(MODEL_COLORS)
        return MODEL_COLORS[i]
    end
    grad = cgrad(
        [:midnightblue, :dodgerblue3, :deepskyblue3, :darkorange1, :orangered1, :red],
        n,
        categorical = true,
    )
    return grad[i]
end

function load_curves(base_dir::AbstractString)
    curves = NamedTuple[]
    dirs = model_dirs(base_dir)
    for d in dirs
        m = parse(Int, split(basename(d), "_")[2])
        curve = myreaddlm(joinpath(d, "bifurcation_curve.csv"), cc = '%')
        push!(curves, (m = m, Re = curve[:, 1], shear = curve[:, 2]))
    end
    return curves
end

function nice_limits(curves, ref; xmax_clip = 400.0)
    xs = Float64[]
    ys = Float64[]
    for i in axes(ref, 1)
        ref[i, 1] <= xmax_clip || continue
        push!(xs, ref[i, 1])
        push!(ys, ref[i, 2])
    end
    for c in curves
        for i in eachindex(c.Re)
            c.Re[i] <= xmax_clip || continue
            push!(xs, c.Re[i])
            push!(ys, c.shear[i])
        end
    end
    xmin, xmax = minimum(xs), maximum(xs)
    ymin, ymax = minimum(ys), maximum(ys)
    xpad = 0.04 * (xmax - xmin)
    ypad = 0.08 * (ymax - ymin)
    return (xmin - xpad, xmax + xpad), (ymin - ypad, ymax + ypad)
end

function render_plot(curves, ref; title::String, xmax_clip::Float64 = 400.0)
    fig = Figure(size = (2200, 1450), fontsize = FIG_FONTSIZE)
    ax = Axis(
        fig[1, 1],
        xlabel = "Reynolds number Re",
        ylabel = "Shear",
        title = title,
        xlabelsize = AXIS_LABELSIZE,
        ylabelsize = AXIS_LABELSIZE,
        titlesize = AXIS_TITLESIZE,
        xticklabelsize = TICK_LABELSIZE,
        yticklabelsize = TICK_LABELSIZE,
        xgridcolor = (:black, 0.10),
        ygridcolor = (:black, 0.10),
        xgridwidth = 1.0,
        ygridwidth = 1.0,
    )

    xlim, ylim = nice_limits(curves, ref; xmax_clip = xmax_clip)
    xlims!(ax, xlim...)
    ylims!(ax, ylim...)

    ref_mask = ref[:, 1] .<= xmax_clip
    lines!(ax, ref[ref_mask, 1], ref[ref_mask, 2], color = :black, linewidth = 4.0, label = "Reference")

    for (i, c) in enumerate(curves)
        mask = c.Re .<= xmax_clip
        lines!(
            ax,
            c.Re[mask],
            c.shear[mask],
            color = model_color(i, length(curves)),
            linewidth = 3.4,
            label = @sprintf("m = %d", c.m),
        )
    end

    axislegend(
        ax;
        position = :lt,
        framevisible = true,
        labelsize = LEGEND_LABELSIZE,
        titlesize = LEGEND_TITLESIZE,
        patchsize = (34, 18),
        padding = (12, 12, 12, 12),
        rowgap = 8,
        margin = (10, 10, 10, 10),
        title = "ODE Dimension",
    )

    return fig
end

function main(args = ARGS)
    parsed = parse_args(args)
    base_dir = abspath(get(parsed, "in", DEFAULT_ANALYSIS_DIR))
    ref_path = abspath(get(parsed, "reference", DEFAULT_REFERENCE_CURVE))
    out_png = abspath(get(parsed, "out", joinpath(base_dir, "combined_bifurcation_curves_publication.png")))
    out_pdf = replace(out_png, r"\.png$" => ".pdf")
    xmax_clip = parse(Float64, get(parsed, "xmax", "400"))

    isdir(base_dir) || error("analysis directory not found: $base_dir")
    isfile(ref_path) || error("reference curve not found: $ref_path")

    curves = load_curves(base_dir)
    isempty(curves) && error("no bifurcation curves found in $base_dir")
    ref = myreaddlm(ref_path, cc = '#')

    fig = render_plot(curves, ref; title = "Nagata Bifurcation Branch Convergence", xmax_clip = xmax_clip)
    save(out_png, fig, px_per_unit = EXPORT_PX_PER_UNIT)
    save(out_pdf, fig)
    println("Wrote $out_png")
    println("Wrote $out_pdf")
end

main()

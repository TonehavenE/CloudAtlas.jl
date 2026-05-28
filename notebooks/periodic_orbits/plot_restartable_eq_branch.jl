# -*- coding: utf-8 -*-
# Plot restartable fixed-Re equilibrium scan outputs.

if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "../.."))
end

using CairoMakie
using CSV
using DataFrames
using Printf

function parse_jkl_env(name::AbstractString, default::NTuple{3, Int})
    raw = strip(get(ENV, name, ""))
    isempty(raw) && return default
    parts = split(lowercase(raw), "x")
    length(parts) == 3 || error("Invalid $name='$raw'. Expected JxKxL.")
    return (parse(Int, parts[1]), parse(Int, parts[2]), parse(Int, parts[3]))
end

function branch_dir()
    J, K, L = parse_jkl_env("HOPF_JKL", (2, 4, 7))
    default = joinpath(@__DIR__, "eqb_hopf_outputs_$(J)_$(K)_$(L)", "restartable_eq_branch")
    return abspath(get(ENV, "HOPF_RESTART_EQ_OUT_DIR", default))
end

function clean_rows(df::DataFrame)
    rows = df[df.converged .== true, :]
    sort!(rows, :Re)
    return rows
end

function plot_bifurcation(rows::DataFrame, outdir::AbstractString)
    fig = Figure(size = (1100, 850))

    ax1 = Axis(fig[1, 1], xlabel = "Re", ylabel = "power input", title = "Equilibrium branch")
    lines!(ax1, rows.Re, rows.power; color = :navy, linewidth = 2)
    scatter!(ax1, rows.Re, rows.power; color = :navy, markersize = 7)

    if "unstable_count" in names(rows)
        for u in sort(unique(skipmissing(rows.unstable_count)))
            group = rows[rows.unstable_count .== u, :]
            scatter!(ax1, group.Re, group.power; markersize = 10, label = "$(u) unstable")
        end
        axislegend(ax1, position = :rt)
    end

    ax2 = Axis(fig[2, 1], xlabel = "Re", ylabel = "state norm")
    lines!(ax2, rows.Re, rows.norm; color = :darkgreen, linewidth = 2)
    scatter!(ax2, rows.Re, rows.norm; color = :darkgreen, markersize = 7)

    ax3 = Axis(fig[3, 1], xlabel = "Re", ylabel = "max Re(lambda) complex")
    lines!(ax3, rows.Re, rows.max_complex_real; color = :black, linewidth = 2)
    scatter!(ax3, rows.Re, rows.max_complex_real; color = :black, markersize = 7)
    hlines!(ax3, [0.0]; color = :red, linestyle = :dash)

    CairoMakie.save(joinpath(outdir, "eq_branch_bifurcation.png"), fig)
end

dir = branch_dir()
metadata_path = joinpath(dir, "eq_branch_metadata.csv")
isfile(metadata_path) || error("Missing metadata CSV: $metadata_path")
rows = clean_rows(CSV.read(metadata_path, DataFrame))
isempty(rows) && error("No converged rows in $metadata_path")
plot_bifurcation(rows, dir)
@printf("Wrote %s\n", joinpath(dir, "eq_branch_bifurcation.png"))

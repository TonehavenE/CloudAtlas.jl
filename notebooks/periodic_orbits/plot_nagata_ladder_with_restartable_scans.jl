# -*- coding: utf-8 -*-
# Overlay the original Nagata ODE ladder curves, DNS data, and selected
# restartable fixed-Re scan branches on the same Re/shear axes.

if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "../.."))
end

using CairoMakie
using CSV
using DataFrames
using DelimitedFiles
using Printf

const ROOT = abspath(joinpath(@__DIR__, "..", ".."))

function read_dns_curve(path::AbstractString)
    raw = readdlm(path, comments = true, comment_char = '#')
    return Float64.(raw[:, 1]), Float64.(raw[:, 2])
end

function read_two_column_curve(path::AbstractString)
    raw = readdlm(path, ',', Float64)
    return raw[:, 1], raw[:, 2]
end

function read_restartable_curve(path::AbstractString)
    df = CSV.read(path, DataFrame)
    rows = df[df.converged .== true, :]
    return Float64.(rows.Re), Float64.(rows.shear)
end

function add_curve!(ax, x, y; label, color, linewidth = 2, linestyle = nothing, marker = false)
    # Preserve continuation/file order. Sorting by Re breaks folded branches.
    lines!(ax, x, y; label = label, color = color, linewidth = linewidth, linestyle = linestyle)
    marker && scatter!(ax, x, y; color = color, markersize = 6)
end

function main()
    outdir = abspath(get(ENV, "NAGATA_OVERLAY_OUT_DIR", joinpath(@__DIR__, "eqb_hopf_outputs_2_4_7", "restartable_overlay")))
    mkpath(outdir)
    outpath = joinpath(outdir, "nagata_ladder_restartable_overlay.png")

    dns_path = joinpath(ROOT, "notebooks", "data", "eq1ReD-DNS.asc")
    comprehensive = joinpath(ROOT, "notebooks", "energy", "nagata_comprehensive_analysis")
    ladder_specs = [
        ("m=27", joinpath(comprehensive, "m_27", "bifurcation_curve.csv")),
        ("m=59", joinpath(comprehensive, "m_59", "bifurcation_curve.csv")),
        ("m=97", joinpath(comprehensive, "m_97", "bifurcation_curve.csv")),
        ("m=169", joinpath(comprehensive, "m_169", "bifurcation_curve.csv")),
        ("m=214", joinpath(comprehensive, "m_214", "bifurcation_curve.csv")),
        ("m=367", joinpath(comprehensive, "m_367", "bifurcation_curve.csv")),
    ]
    scan_specs = [
        ("J2,K4,L7 up", joinpath(@__DIR__, "eqb_hopf_outputs_2_4_7", "restartable_eq_branch_Re300_450_dRe1", "eq_branch_metadata.csv")),
        ("J2,K4,L7 down", joinpath(@__DIR__, "eqb_hopf_outputs_2_4_7", "restartable_eq_branch_Re300_120_dRe1", "eq_branch_metadata.csv")),
    ]

    fig = Figure(size = (1200, 800))
    ax = Axis(fig[1, 1],
        xlabel = "Re",
        ylabel = "Shear",
        title = "Nagata equilibrium branches: DNS, ODE ladder, restartable scans",
        limits = ((120, 460), (1.2, 3.0)),
    )

    if isfile(dns_path)
        xdns, ydns = read_dns_curve(dns_path)
        keep = 120 .<= xdns .<= 460
        add_curve!(ax, xdns[keep], ydns[keep]; label = "DNS", color = :black, linewidth = 4)
    else
        @warn "DNS data not found" dns_path
    end

    palette = [:dodgerblue3, :seagreen4, :darkorange3, :firebrick3, :purple4, :gray35]
    for (i, (label, path)) in enumerate(ladder_specs)
        if isfile(path)
            x, y = read_two_column_curve(path)
            keep = 120 .<= x .<= 460
            add_curve!(ax, x[keep], y[keep]; label = label, color = palette[1 + mod(i - 1, length(palette))], linewidth = 2)
        else
            @warn "ODE ladder curve not found" path
        end
    end

    scan_colors = [:red, :deepskyblue4]
    for (i, (label, path)) in enumerate(scan_specs)
        if isfile(path)
            x, y = read_restartable_curve(path)
            add_curve!(ax, x, y; label = label, color = scan_colors[i], linewidth = 3, linestyle = :dash, marker = true)
        else
            @warn "Restartable scan not found" path
        end
    end

    axislegend(ax, position = :rt, nbanks = 2)
    CairoMakie.save(outpath, fig)
    @printf("Wrote %s\n", outpath)
end

main()

# -*- coding: utf-8 -*-
# Track complex eigenvalue branches from restartable EQ scan outputs.

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
    J, K, L = parse_jkl_env("HOPF_JKL", (2, 3, 7))
    default = joinpath(@__DIR__, "eqb_hopf_outputs_$(J)_$(K)_$(L)", "restartable_eq_branch")
    return abspath(get(ENV, "HOPF_RESTART_EQ_OUT_DIR", default))
end

function complex_positive_rows(eigs::DataFrame; imag_tol::Real = 1e-7)
    rows = eigs[eigs.eig_imag .> imag_tol, :]
    sort!(rows, [:step, :eig_real])
    return rows
end

function track_branches(eigs::DataFrame; imag_tol::Real = 1e-7)
    rows = complex_positive_rows(eigs; imag_tol = imag_tol)
    isempty(rows) && return DataFrame()
    steps = sort(unique(rows.step))
    branches = Dict{Int, Vector{NamedTuple}}()
    active = Dict{Int, ComplexF64}()
    next_id = 1

    first_step = first(steps)
    first_rows = rows[rows.step .== first_step, :]
    sort!(first_rows, :eig_imag)
    for r in eachrow(first_rows)
        z = complex(r.eig_real, r.eig_imag)
        branches[next_id] = [(branch_id = next_id, step = r.step, Re = r.Re,
                              eig_real = r.eig_real, eig_imag = r.eig_imag,
                              period_estimate = 2π / abs(r.eig_imag))]
        active[next_id] = z
        next_id += 1
    end

    for step in steps[2:end]
        current = rows[rows.step .== step, :]
        sort!(current, :eig_imag)
        unused = collect(1:nrow(current))
        new_active = Dict{Int, ComplexF64}()
        for bid in sort(collect(keys(active)))
            isempty(unused) && break
            zprev = active[bid]
            distances = [abs(complex(current[i, :eig_real], current[i, :eig_imag]) - zprev) for i in unused]
            best_pos = argmin(distances)
            idx = unused[best_pos]
            deleteat!(unused, best_pos)
            r = current[idx, :]
            z = complex(r.eig_real, r.eig_imag)
            push!(branches[bid], (branch_id = bid, step = r.step, Re = r.Re,
                                  eig_real = r.eig_real, eig_imag = r.eig_imag,
                                  period_estimate = 2π / abs(r.eig_imag)))
            new_active[bid] = z
        end
        for idx in unused
            r = current[idx, :]
            z = complex(r.eig_real, r.eig_imag)
            branches[next_id] = [(branch_id = next_id, step = r.step, Re = r.Re,
                                  eig_real = r.eig_real, eig_imag = r.eig_imag,
                                  period_estimate = 2π / abs(r.eig_imag))]
            new_active[next_id] = z
            next_id += 1
        end
        active = new_active
    end

    out = NamedTuple[]
    for bid in sort(collect(keys(branches)))
        append!(out, branches[bid])
    end
    return DataFrame(out)
end

function crossing_summary(tracked::DataFrame)
    rows = NamedTuple[]
    isempty(tracked) && return DataFrame(rows)
    for bid in sort(unique(tracked.branch_id))
        b = tracked[tracked.branch_id .== bid, :]
        sort!(b, :Re)
        for i in 1:nrow(b)-1
            r1 = b[i, :]
            r2 = b[i+1, :]
            if r1.eig_real == 0 || sign(r1.eig_real) != sign(r2.eig_real)
                denom = r2.eig_real - r1.eig_real
                θ = abs(denom) > eps(Float64) ? -r1.eig_real / denom : 0.5
                θ = clamp(θ, 0.0, 1.0)
                Re_cross = r1.Re + θ * (r2.Re - r1.Re)
                imag_cross = r1.eig_imag + θ * (r2.eig_imag - r1.eig_imag)
                push!(rows, (
                    branch_id = bid,
                    Re_left = r1.Re,
                    Re_right = r2.Re,
                    real_left = r1.eig_real,
                    real_right = r2.eig_real,
                    Re_cross_linear = Re_cross,
                    imag_cross_linear = imag_cross,
                    period_cross_linear = 2π / abs(imag_cross),
                ))
            end
        end
    end
    return DataFrame(rows)
end

function plot_tracking(tracked::DataFrame, crossings::DataFrame, outdir::AbstractString)
    isempty(tracked) && return
    fig = Figure(size = (1000, 700))
    ax = Axis(fig[1, 1], xlabel = "Re", ylabel = "Re(lambda)", title = "Tracked complex eigenvalue branches")
    for bid in sort(unique(tracked.branch_id))
        b = tracked[tracked.branch_id .== bid, :]
        lines!(ax, b.Re, b.eig_real; label = "branch $bid")
    end
    hlines!(ax, [0.0]; color = :red, linestyle = :dash)
    axislegend(ax, nbanks = 2)
    CairoMakie.save(joinpath(outdir, "tracked_complex_real_vs_Re.png"), fig)

    fig2 = Figure(size = (1000, 700))
    ax2 = Axis(fig2[1, 1], xlabel = "Re", ylabel = "2pi / |Im(lambda)|",
               title = "Tracked complex eigenvalue branch periods")
    for bid in sort(unique(tracked.branch_id))
        b = tracked[tracked.branch_id .== bid, :]
        lines!(ax2, b.Re, b.period_estimate; label = "branch $bid")
    end
    axislegend(ax2, nbanks = 2)
    CairoMakie.save(joinpath(outdir, "tracked_complex_period_vs_Re.png"), fig2)

    if !isempty(crossings)
        CSV.write(joinpath(outdir, "tracked_complex_crossings.csv"), crossings)
    end
end

dir = branch_dir()
eig_path = joinpath(dir, "eq_branch_leading_eigenvalues.csv")
isfile(eig_path) || error("Missing eigenvalue CSV: $eig_path")
eigs = CSV.read(eig_path, DataFrame)
tracked = track_branches(eigs)
out_path = joinpath(dir, "tracked_complex_eigenbranches.csv")
CSV.write(out_path, tracked)
crossings = crossing_summary(tracked)
cross_path = joinpath(dir, "tracked_complex_crossings.csv")
CSV.write(cross_path, crossings)
plot_tracking(tracked, crossings, dir)

@printf("Wrote %s\n", out_path)
@printf("Wrote %s\n", cross_path)
if isempty(crossings)
    println("No tracked complex branch sign crossings found in logged eigenvalues.")
else
    println(crossings)
end

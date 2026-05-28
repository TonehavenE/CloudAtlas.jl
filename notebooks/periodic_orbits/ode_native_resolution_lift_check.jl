# -*- coding: utf-8 -*-
# Lift a solved ODE periodic orbit from one Galerkin resolution to another via
# coeff2field/field2coeff, then test recurrence in the target ODE model.

if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "..", ".."))
end

using CSV
using CloudAtlas
using ChannelflowWrapper
using DataFrames
using DifferentialEquations
using LinearAlgebra
using Printf

parse_float_env(name, default) = parse(Float64, strip(get(ENV, name, string(default))))
parse_int_env(name, default) = parse(Int, strip(get(ENV, name, string(default))))

function parse_jkl_env(name::AbstractString, default::NTuple{3, Int})
    raw = strip(get(ENV, name, ""))
    isempty(raw) && return default
    parts = split(lowercase(raw), "x")
    length(parts) == 3 || error("Invalid $name='$raw'. Expected JxKxL.")
    return (parse(Int, parts[1]), parse(Int, parts[2]), parse(Int, parts[3]))
end

function load_coeff_vector(path::AbstractString)
    isfile(path) || error("Missing coefficient file: $path")
    vals = Float64[]
    for line in readlines(path)
        s = strip(line)
        isempty(s) && continue
        startswith(s, "#") && continue
        startswith(s, "%") && continue
        for tok in split(s)
            value = tryparse(Float64, tok)
            value === nothing && continue
            push!(vals, value)
        end
    end
    isempty(vals) && error("No numeric coefficients in $path")
    return vals
end

function save_coeff_vector(path::AbstractString, x::AbstractVector)
    mkpath(dirname(path))
    open(path, "w") do io
        for value in x
            @printf(io, "%.17e\n", Float64(value))
        end
    end
end

flatten_coeffs(raw) = vec(Float64.(raw))

energy(model::ODEModel, x::AbstractVector) = 0.5 * dot(x, model.B * x)

function ode_problem(model::ODEModel, x0::AbstractVector; Re::Real, tspan)
    function rhs!(du, u, p, t)
        du .= model.f(u, p[1])
        return nothing
    end
    return ODEProblem(rhs!, collect(x0), tspan, [Float64(Re)])
end

function span_class(I_span::Real, D_span::Real)
    s = min(I_span, D_span)
    s < 0.05 && return "tiny"
    s < 0.10 && return "small"
    s < 0.25 && return "medium"
    return "large"
end

function endpoint_closure_scan(model::ODEModel, x0::AbstractVector, Re::Real, T0::Real;
                               scan_min_factor::Real, scan_max_factor::Real,
                               nscan::Int, abstol::Real, reltol::Real)
    times = collect(range(scan_min_factor * Float64(T0), scan_max_factor * Float64(T0); length = nscan))
    prob = ode_problem(model, x0; Re = Re, tspan = (0.0, maximum(times)))
    sol = solve(prob, Vern9(); abstol = abstol, reltol = reltol, saveat = times, dense = false)
    sol.retcode == ReturnCode.Success || error("Target ODE period scan failed: $(sol.retcode)")
    rows = NamedTuple[]
    for (t, u) in zip(sol.t, sol.u)
        closure = norm(collect(u) .- x0)
        push!(rows, (
            T = Float64(t),
            closure = closure,
            relative_closure = closure / max(norm(x0), eps(Float64)),
        ))
    end
    best = rows[argmin([r.closure for r in rows])]
    return rows, best
end

function orbit_diagnostics(model::ODEModel, Dmat, x0::AbstractVector, Re::Real, T::Real;
                           nsamples::Int, abstol::Real, reltol::Real)
    times = collect(range(0.0, Float64(T); length = nsamples))
    prob = ode_problem(model, x0; Re = Re, tspan = (0.0, Float64(T)))
    sol = solve(prob, Vern9(); abstol = abstol, reltol = reltol, saveat = times, dense = false)
    sol.retcode == ReturnCode.Success || error("Target ODE diagnostic integration failed: $(sol.retcode)")
    xs = [collect(Float64, u) for u in sol.u]
    Ivals = [power_input(model, x) for x in xs]
    Dvals = [dissipation_rate(Dmat, x) for x in xs]
    Evals = [energy(model, x) for x in xs]
    closure = norm(xs[end] .- x0)
    return (
        closure = closure,
        relative_closure = closure / max(norm(x0), eps(Float64)),
        I_min = minimum(Ivals),
        I_max = maximum(Ivals),
        I_span = maximum(Ivals) - minimum(Ivals),
        I_mean = sum(Ivals) / length(Ivals),
        D_min = minimum(Dvals),
        D_max = maximum(Dvals),
        D_span = maximum(Dvals) - minimum(Dvals),
        D_mean = sum(Dvals) / length(Dvals),
        E_min = minimum(Evals),
        E_max = maximum(Evals),
        E_span = maximum(Evals) - minimum(Evals),
        E_mean = sum(Evals) / length(Evals),
    )
end

const HERE = @__DIR__
default_base = joinpath(HERE, "eqb_hopf_outputs_2_3_7", "clean_po_pipeline_j2_target270_long")
default_refine = joinpath(default_base, "ode_refinement")
default_x0 = joinpath(default_refine, "x0_refined.asc")
default_template = joinpath(HERE, "EQ1Re300-32x49x40.nc")

source_jkl = parse_jkl_env("RES_LIFT_SOURCE_JKL", (2, 3, 7))
target_jkl = parse_jkl_env("RES_LIFT_TARGET_JKL", (3, 5, 9))
alpha = parse_float_env("RES_LIFT_ALPHA", 1.0)
gamma = parse_float_env("RES_LIFT_GAMMA", 2.0)
Re = parse_float_env("RES_LIFT_RE", 285.91486006421275)
T0 = parse_float_env("RES_LIFT_T", 86.72275925408482)
x0_path = abspath(get(ENV, "RES_LIFT_X0", default_x0))
template_field = abspath(get(ENV, "RES_LIFT_TEMPLATE", default_template))
outdir = abspath(get(ENV, "RES_LIFT_OUT_DIR",
                     joinpath(default_base, "resolution_lift_$(source_jkl[1])_$(source_jkl[2])_$(source_jkl[3])_to_$(target_jkl[1])_$(target_jkl[2])_$(target_jkl[3])")))
scan_min = parse_float_env("RES_LIFT_SCAN_MIN", 0.7)
scan_max = parse_float_env("RES_LIFT_SCAN_MAX", 1.3)
nscan = parse_int_env("RES_LIFT_NSCAN", 61)
nsamples = parse_int_env("RES_LIFT_NSAMPLES", 401)
abstol = parse_float_env("RES_LIFT_ABSTOL", 1e-10)
reltol = parse_float_env("RES_LIFT_RELTOL", 1e-10)
mkpath(outdir)

sx, sy, sz, tx, tz = halfbox_symmetries()
H = [sx * sy * sz, sz * tx * tz]

@printf("Building source model J,K,L=(%d,%d,%d)\n", source_jkl...)
source_model = ODEModel(alpha, gamma, source_jkl..., H, normalize = true)
x_source = load_coeff_vector(x0_path)
length(x_source) == length(source_model) || error("source x length $(length(x_source)) != source dim $(length(source_model))")

source_field = joinpath(outdir, "u_source_lifted.nc")
@printf("Source coeffs -> flowfield: %s\n", source_field)
ChannelflowWrapper.coeff2field(x_source, source_model.ijkl, template_field, source_field; workdir = outdir)

@printf("Building target model J,K,L=(%d,%d,%d)\n", target_jkl...)
target_model = ODEModel(alpha, gamma, target_jkl..., H, normalize = true)
target_x_path = joinpath(outdir, "x0_target_projected.asc")
raw_target = ChannelflowWrapper.field2coeff(target_model.ijkl, source_field, target_x_path; workdir = outdir)
x_target = flatten_coeffs(raw_target)
length(x_target) == length(target_model) || error("target x length $(length(x_target)) != target dim $(length(target_model))")
save_coeff_vector(target_x_path, x_target)

@printf("Target projected norm %.12e; source norm %.12e\n", norm(x_target), norm(x_source))
@printf("Scanning target ODE periods in [%.6f, %.6f]\n", scan_min * T0, scan_max * T0)
scan_rows, best = endpoint_closure_scan(target_model, x_target, Re, T0;
                                        scan_min_factor = scan_min,
                                        scan_max_factor = scan_max,
                                        nscan = nscan,
                                        abstol = abstol,
                                        reltol = reltol)
scan_path = joinpath(outdir, "target_period_scan.csv")
CSV.write(scan_path, DataFrame(scan_rows))

@printf("Building target dissipation matrix...\n")
Dmat = build_dissipation_matrix(target_model)
diag_T0 = orbit_diagnostics(target_model, Dmat, x_target, Re, T0;
                            nsamples = nsamples, abstol = abstol, reltol = reltol)
diag_best = orbit_diagnostics(target_model, Dmat, x_target, Re, best.T;
                              nsamples = nsamples, abstol = abstol, reltol = reltol)

summary = DataFrame([
    (
        case = "target_at_source_period",
        source_J = source_jkl[1],
        source_K = source_jkl[2],
        source_L = source_jkl[3],
        target_J = target_jkl[1],
        target_K = target_jkl[2],
        target_L = target_jkl[3],
        Re = Re,
        T = T0,
        closure = diag_T0.closure,
        relative_closure = diag_T0.relative_closure,
        I_min = diag_T0.I_min,
        I_max = diag_T0.I_max,
        I_span = diag_T0.I_span,
        I_mean = diag_T0.I_mean,
        D_min = diag_T0.D_min,
        D_max = diag_T0.D_max,
        D_span = diag_T0.D_span,
        D_mean = diag_T0.D_mean,
        E_min = diag_T0.E_min,
        E_max = diag_T0.E_max,
        E_span = diag_T0.E_span,
        E_mean = diag_T0.E_mean,
        span_class = span_class(diag_T0.I_span, diag_T0.D_span),
        x0_source_path = x0_path,
        source_field_path = source_field,
        x0_target_path = target_x_path,
    ),
    (
        case = "target_best_period_scan",
        source_J = source_jkl[1],
        source_K = source_jkl[2],
        source_L = source_jkl[3],
        target_J = target_jkl[1],
        target_K = target_jkl[2],
        target_L = target_jkl[3],
        Re = Re,
        T = best.T,
        closure = diag_best.closure,
        relative_closure = diag_best.relative_closure,
        I_min = diag_best.I_min,
        I_max = diag_best.I_max,
        I_span = diag_best.I_span,
        I_mean = diag_best.I_mean,
        D_min = diag_best.D_min,
        D_max = diag_best.D_max,
        D_span = diag_best.D_span,
        D_mean = diag_best.D_mean,
        E_min = diag_best.E_min,
        E_max = diag_best.E_max,
        E_span = diag_best.E_span,
        E_mean = diag_best.E_mean,
        span_class = span_class(diag_best.I_span, diag_best.D_span),
        x0_source_path = x0_path,
        source_field_path = source_field,
        x0_target_path = target_x_path,
    ),
])
summary_path = joinpath(outdir, "resolution_lift_summary.csv")
CSV.write(summary_path, summary)

@printf("At source period: T=%.12f closure=%.6e rel=%.6e I_span=%.6e D_span=%.6e class=%s\n",
        T0, diag_T0.closure, diag_T0.relative_closure, diag_T0.I_span, diag_T0.D_span,
        span_class(diag_T0.I_span, diag_T0.D_span))
@printf("Best target scan: T=%.12f closure=%.6e rel=%.6e I_span=%.6e D_span=%.6e class=%s\n",
        best.T, diag_best.closure, diag_best.relative_closure, diag_best.I_span, diag_best.D_span,
        span_class(diag_best.I_span, diag_best.D_span))
@printf("Wrote %s\n", summary_path)

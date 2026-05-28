# -*- coding: utf-8 -*-
# Verify and optionally refine a saved ODE-native periodic orbit by exact-tangent
# fixed-Re single shooting.

if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "..", ".."))
end

using CSV
using CloudAtlas
using DataFrames
using DifferentialEquations
using LinearAlgebra
using Printf

parse_int_env(name, default) = parse(Int, strip(get(ENV, name, string(default))))
parse_float_env(name, default) = parse(Float64, strip(get(ENV, name, string(default))))

function parse_bool_env(name::AbstractString, default::Bool)
    raw = lowercase(strip(get(ENV, name, default ? "true" : "false")))
    raw in ("1", "true", "t", "yes", "y") && return true
    raw in ("0", "false", "f", "no", "n") && return false
    error("Invalid boolean ENV[$name]='$raw'")
end

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

energy(model::ODEModel, x::AbstractVector) = 0.5 * dot(x, model.B * x)

function ode_problem(model::ODEModel, x0::AbstractVector; Re::Real, tspan)
    function rhs!(du, u, p, t)
        du .= model.f(u, p[1])
        return nothing
    end
    return ODEProblem(rhs!, collect(x0), tspan, [Float64(Re)])
end

function orbit_diagnostics(model::ODEModel, Dmat, x0::AbstractVector, Re::Real, T::Real;
                           abstol::Real, reltol::Real, nsamples::Int, alg = Vern9())
    times = collect(range(0.0, Float64(T); length = nsamples))
    sol = solve(
        ode_problem(model, x0; Re = Re, tspan = (0.0, Float64(T))),
        alg;
        abstol = abstol,
        reltol = reltol,
        saveat = times,
        dense = false,
    )
    sol.retcode == ReturnCode.Success || return nothing
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

function integrate_endpoint_tangent(model::ODEModel, x0::AbstractVector, T::Real;
                                    Re::Real, abstol::Real, reltol::Real)
    m = length(model)
    y0 = zeros(Float64, m + m * m)
    y0[1:m] .= x0
    y0[m+1:end] .= vec(Matrix{Float64}(I, m, m))

    function rhs!(dy, y, p, t)
        x = @view y[1:m]
        M = reshape(@view(y[m+1:end]), m, m)
        dx = @view dy[1:m]
        dM = reshape(@view(dy[m+1:end]), m, m)
        dx .= model.f(x, p[1])
        dM .= model.Df(x, p[1]) * M
        return nothing
    end

    prob = ODEProblem(rhs!, y0, (0.0, Float64(T)), [Float64(Re)])
    sol = solve(prob, Vern9(); abstol = abstol, reltol = reltol, saveat = [Float64(T)], dense = false)
    sol.retcode == ReturnCode.Success || return nothing
    yT = sol.u[end]
    xT = collect(Float64, @view yT[1:m])
    MT = Matrix{Float64}(reshape(@view(yT[m+1:end]), m, m))
    return xT, MT
end

function shooting_residual_jacobian(model::ODEModel, ξ::AbstractVector, xref::AbstractVector, fref::AbstractVector;
                                    Re::Real, abstol::Real, reltol::Real)
    m = length(model)
    x0 = collect(Float64, ξ[1:m])
    T = Float64(ξ[m+1])
    if !(isfinite(T) && T > 0)
        return fill(1e6, m + 1), zeros(Float64, m + 1, m + 1)
    end
    out = integrate_endpoint_tangent(model, x0, T; Re = Re, abstol = abstol, reltol = reltol)
    out === nothing && return fill(1e6, m + 1), zeros(Float64, m + 1, m + 1)
    xT, MT = out

    r = zeros(Float64, m + 1)
    r[1:m] .= xT .- x0
    r[m+1] = dot(fref, x0 .- xref)

    J = zeros(Float64, m + 1, m + 1)
    J[1:m, 1:m] .= MT
    for i in 1:m
        J[i, i] -= 1.0
    end
    J[1:m, m+1] .= model.f(xT, Re)
    J[m+1, 1:m] .= fref
    return r, J
end

function shooting_residual(model::ODEModel, ξ::AbstractVector, xref::AbstractVector, fref::AbstractVector;
                           Re::Real, abstol::Real, reltol::Real)
    m = length(model)
    x0 = collect(Float64, ξ[1:m])
    T = Float64(ξ[m+1])
    if !(isfinite(T) && T > 0)
        return fill(1e6, m + 1)
    end
    sol = solve(
        ode_problem(model, x0; Re = Re, tspan = (0.0, T)),
        Vern9();
        abstol = abstol,
        reltol = reltol,
        saveat = [T],
        dense = false,
    )
    sol.retcode == ReturnCode.Success || return fill(1e6, m + 1)
    xT = collect(Float64, sol.u[end])
    r = zeros(Float64, m + 1)
    r[1:m] .= xT .- x0
    r[m+1] = dot(fref, x0 .- xref)
    return r
end

function span_class(I_span::Real, D_span::Real)
    s = min(I_span, D_span)
    s < 0.05 && return "tiny"
    s < 0.10 && return "small"
    s < 0.25 && return "medium"
    return "large"
end

function refine_shooting(model::ODEModel, Dmat, x_start::AbstractVector, T_start::Real;
                         Re::Real, abstol::Real, reltol::Real, max_iters::Int,
                         trust_radius::Real, min_span::Real)
    m = length(model)
    xref = collect(Float64, x_start)
    fref = model.f(xref, Re)
    ξ = [xref; Float64(T_start)]
    rows = NamedTuple[]

    for iter in 0:max_iters
        diag = orbit_diagnostics(model, Dmat, ξ[1:m], Re, ξ[end];
                                 abstol = abstol, reltol = reltol, nsamples = 401)
        diag === nothing && error("Failed diagnostic integration at iteration $iter")
        r, J = shooting_residual_jacobian(model, ξ, xref, fref; Re = Re, abstol = abstol, reltol = reltol)
        closure = norm(@view r[1:m])
        resnorm = norm(r)
        cls = span_class(diag.I_span, diag.D_span)
        @printf("iter=%02d T=%.12f closure=%.6e residual=%.6e I_span=%.6e D_span=%.6e class=%s\n",
                iter, ξ[end], closure, resnorm, diag.I_span, diag.D_span, cls)
        push!(rows, (
            iteration = iter,
            T = ξ[end],
            closure = closure,
            residual = resnorm,
            relative_closure = closure / max(norm(ξ[1:m]), eps(Float64)),
            I_span = diag.I_span,
            D_span = diag.D_span,
            E_span = diag.E_span,
            span_class = cls,
            step_norm = 0.0,
            accepted = iter == 0,
            stopped = "",
        ))
        if resnorm < 1e-10
            rows[end] = merge(rows[end], (stopped = "converged",))
            break
        end
        if min(diag.I_span, diag.D_span) < min_span
            rows[end] = merge(rows[end], (stopped = "span_guard",))
            break
        end
        iter == max_iters && break

        Δ = -(J \ r)
        if norm(Δ) > trust_radius
            Δ .*= trust_radius / norm(Δ)
        end

        accepted = false
        best_ξ = ξ
        best_norm = resnorm
        best_step = 0.0
        for scale in (1.0, 0.5, 0.25, 0.125, 0.0625, 0.03125)
            trial = copy(ξ)
            trial .+= scale .* Δ
            trial[end] = max(trial[end], 1e-6)
            rt = shooting_residual(model, trial, xref, fref; Re = Re, abstol = abstol, reltol = reltol)
            nt = norm(rt)
            trial_diag = orbit_diagnostics(model, Dmat, trial[1:m], Re, trial[end];
                                           abstol = abstol, reltol = reltol, nsamples = 101)
            span_ok = trial_diag !== nothing && min(trial_diag.I_span, trial_diag.D_span) >= min_span
            if span_ok && nt < best_norm
                accepted = true
                best_ξ = trial
                best_norm = nt
                best_step = scale * norm(Δ)
                break
            end
        end
        rows[end] = merge(rows[end], (step_norm = best_step, accepted = accepted,
                                      stopped = accepted ? "" : "line_search_failed"))
        accepted || break
        ξ = best_ξ
    end
    return ξ, rows
end

const HERE = @__DIR__
default_base = joinpath(HERE, "eqb_hopf_outputs_2_3_7", "clean_po_pipeline_j2_target270_long")
default_x0 = joinpath(default_base, "states", "x0_natural_step019_Re285.914860_T86.722635.asc")

x0_path = abspath(get(ENV, "PO_X0_PATH", default_x0))
Re = parse_float_env("PO_RE", 285.91486006421275)
T0 = parse_float_env("PO_T", 86.7226346466274)
alpha = parse_float_env("PO_ALPHA", 1.0)
gamma = parse_float_env("PO_GAMMA", 2.0)
J, K, L = parse_jkl_env("PO_JKL", (2, 3, 7))
abstol = parse_float_env("PO_ABSTOL", 1e-11)
reltol = parse_float_env("PO_RELTOL", 1e-11)
max_iters = parse_int_env("PO_REFINE_MAX_ITERS", 4)
trust_radius = parse_float_env("PO_TRUST_RADIUS", 0.1)
min_span = parse_float_env("PO_MIN_SPAN", 0.10)
run_refine = parse_bool_env("PO_RUN_REFINE", true)
outdir = abspath(get(ENV, "PO_REFINE_OUT_DIR", joinpath(default_base, "ode_refinement")))
mkpath(outdir)

sx, sy, sz, tx, tz = halfbox_symmetries()
H = [sx * sy * sz, sz * tx * tz]
@printf("Building model J,K,L=(%d,%d,%d) Re=%.12f\n", J, K, L, Re)
model = ODEModel(alpha, gamma, J, K, L, H, normalize = true)
Dmat = build_dissipation_matrix(model)
x0 = load_coeff_vector(x0_path)
length(x0) == length(model) || error("x0 length $(length(x0)) != model dimension $(length(model))")

initial = orbit_diagnostics(model, Dmat, x0, Re, T0; abstol = abstol, reltol = reltol, nsamples = 801)
initial === nothing && error("Initial verification integration failed")
initial_row = DataFrame([(
    label = "initial",
    Re = Re,
    T = T0,
    closure = initial.closure,
    relative_closure = initial.relative_closure,
    I_span = initial.I_span,
    D_span = initial.D_span,
    E_span = initial.E_span,
    I_mean = initial.I_mean,
    D_mean = initial.D_mean,
    E_mean = initial.E_mean,
    span_class = span_class(initial.I_span, initial.D_span),
)])
CSV.write(joinpath(outdir, "tight_verification_initial.csv"), initial_row)
@printf("Initial tight verification: closure=%.6e rel=%.6e I_span=%.6e D_span=%.6e class=%s\n",
        initial.closure, initial.relative_closure, initial.I_span, initial.D_span,
        span_class(initial.I_span, initial.D_span))

if run_refine
    ξ, rows = refine_shooting(model, Dmat, x0, T0; Re = Re, abstol = abstol, reltol = reltol,
                              max_iters = max_iters, trust_radius = trust_radius, min_span = min_span)
    CSV.write(joinpath(outdir, "shooting_refinement_iterations.csv"), DataFrame(rows))
    save_coeff_vector(joinpath(outdir, "x0_refined.asc"), ξ[1:length(model)])
    open(joinpath(outdir, "period_refined.txt"), "w") do io
        @printf(io, "%.17e\n", ξ[end])
    end
    final = orbit_diagnostics(model, Dmat, ξ[1:length(model)], Re, ξ[end];
                              abstol = abstol, reltol = reltol, nsamples = 801)
    final === nothing || CSV.write(joinpath(outdir, "tight_verification_refined.csv"), DataFrame([(
        label = "refined",
        Re = Re,
        T = ξ[end],
        closure = final.closure,
        relative_closure = final.relative_closure,
        I_span = final.I_span,
        D_span = final.D_span,
        E_span = final.E_span,
        I_mean = final.I_mean,
        D_mean = final.D_mean,
        E_mean = final.E_mean,
        span_class = span_class(final.I_span, final.D_span),
    )]))
    final === nothing || @printf("Final tight verification: T=%.12f closure=%.6e rel=%.6e I_span=%.6e D_span=%.6e class=%s\n",
                                 ξ[end], final.closure, final.relative_closure, final.I_span, final.D_span,
                                 span_class(final.I_span, final.D_span))
end

println("Wrote refinement outputs to $outdir")

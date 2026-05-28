# -*- coding: utf-8 -*-
# Continue a solved low-resolution ODE periodic orbit into a larger ODE model
# through a vector-field homotopy:
#
#   F_eps(x) = (1 - eps) * embedded_source_dynamics(x) + eps * target_dynamics(x)
#
# At eps=0 the source periodic orbit is exactly embedded in the target space and
# all newly added coordinates are damped. At eps=1 the full target ODE is active.

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

parse_float_env(name, default) = parse(Float64, strip(get(ENV, name, string(default))))
parse_int_env(name, default) = parse(Int, strip(get(ENV, name, string(default))))

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

function span_class(I_span::Real, D_span::Real)
    s = min(I_span, D_span)
    s < 0.05 && return "tiny"
    s < 0.10 && return "small"
    s < 0.25 && return "medium"
    return "large"
end

function mode_map(source::ODEModel, target::ODEModel)
    target_lookup = Dict{NTuple{4, Int}, Int}()
    for n in axes(target.ijkl, 1)
        target_lookup[(target.ijkl[n, 1], target.ijkl[n, 2], target.ijkl[n, 3], target.ijkl[n, 4])] = n
    end

    source_to_target = Vector{Int}(undef, length(source))
    for n in axes(source.ijkl, 1)
        key = (source.ijkl[n, 1], source.ijkl[n, 2], source.ijkl[n, 3], source.ijkl[n, 4])
        haskey(target_lookup, key) || error("Target basis is missing source mode $key")
        source_to_target[n] = target_lookup[key]
    end

    old_mask = falses(length(target))
    old_mask[source_to_target] .= true
    new_indices = findall(!, old_mask)
    return source_to_target, new_indices
end

function embed_source_state(source::ODEModel, target::ODEModel, x_source::AbstractVector)
    source_to_target, _ = mode_map(source, target)
    x = zeros(Float64, length(target))
    x[source_to_target] .= x_source
    return x
end

function embedded_source_rhs(source::ODEModel, target::ODEModel, source_to_target::Vector{Int},
                             new_indices::Vector{Int}, x::AbstractVector, Re::Real,
                             new_damping::Real)
    xs = collect(Float64, @view x[source_to_target])
    y = zeros(Float64, length(target))
    y[source_to_target] .= source.f(xs, Re)
    y[new_indices] .= -new_damping .* x[new_indices]
    return y
end

function embedded_source_jacobian(source::ODEModel, target::ODEModel, source_to_target::Vector{Int},
                                  new_indices::Vector{Int}, x::AbstractVector, Re::Real,
                                  new_damping::Real)
    xs = collect(Float64, @view x[source_to_target])
    J = zeros(Float64, length(target), length(target))
    J[source_to_target, source_to_target] .= source.Df(xs, Re)
    for n in new_indices
        J[n, n] = -new_damping
    end
    return J
end

function homotopy_rhs(source::ODEModel, target::ODEModel, source_to_target::Vector{Int},
                      new_indices::Vector{Int}, x::AbstractVector, Re::Real, eps_h::Real,
                      new_damping::Real)
    ys = embedded_source_rhs(source, target, source_to_target, new_indices, x, Re, new_damping)
    yt = target.f(x, Re)
    return (1 - eps_h) .* ys .+ eps_h .* yt
end

function homotopy_jacobian(source::ODEModel, target::ODEModel, source_to_target::Vector{Int},
                           new_indices::Vector{Int}, x::AbstractVector, Re::Real, eps_h::Real,
                           new_damping::Real)
    Js = embedded_source_jacobian(source, target, source_to_target, new_indices, x, Re, new_damping)
    Jt = target.Df(x, Re)
    return (1 - eps_h) .* Js .+ eps_h .* Jt
end

function ode_problem(source::ODEModel, target::ODEModel, source_to_target::Vector{Int},
                     new_indices::Vector{Int}, x0::AbstractVector; Re::Real, eps_h::Real,
                     new_damping::Real, tspan)
    function rhs!(du, u, p, t)
        du .= homotopy_rhs(source, target, source_to_target, new_indices, u, p[1], p[2], new_damping)
        return nothing
    end
    return ODEProblem(rhs!, collect(x0), tspan, [Float64(Re), Float64(eps_h)])
end

function orbit_diagnostics(source::ODEModel, target::ODEModel, source_to_target::Vector{Int},
                           new_indices::Vector{Int}, Dmat, x0::AbstractVector, Re::Real,
                           T::Real, eps_h::Real; abstol::Real, reltol::Real,
                           nsamples::Int, new_damping::Real)
    times = collect(range(0.0, Float64(T); length = nsamples))
    sol = solve(
        ode_problem(source, target, source_to_target, new_indices, x0;
                    Re = Re, eps_h = eps_h, new_damping = new_damping, tspan = (0.0, Float64(T))),
        Vern9();
        abstol = abstol,
        reltol = reltol,
        saveat = times,
        dense = false,
    )
    sol.retcode == ReturnCode.Success || return nothing
    xs = [collect(Float64, u) for u in sol.u]
    Ivals = [power_input(target, x) for x in xs]
    Dvals = [dissipation_rate(Dmat, x) for x in xs]
    Evals = [energy(target, x) for x in xs]
    closure = norm(xs[end] .- x0)
    return (
        closure = closure,
        relative_closure = closure / max(norm(x0), eps(Float64)),
        I_span = maximum(Ivals) - minimum(Ivals),
        D_span = maximum(Dvals) - minimum(Dvals),
        E_span = maximum(Evals) - minimum(Evals),
        I_mean = sum(Ivals) / length(Ivals),
        D_mean = sum(Dvals) / length(Dvals),
        E_mean = sum(Evals) / length(Evals),
        new_norm = norm(@view x0[new_indices]),
    )
end

function integrate_endpoint_tangent(source::ODEModel, target::ODEModel, source_to_target::Vector{Int},
                                    new_indices::Vector{Int}, x0::AbstractVector, T::Real;
                                    Re::Real, eps_h::Real, abstol::Real, reltol::Real,
                                    new_damping::Real)
    m = length(target)
    y0 = zeros(Float64, m + m * m)
    y0[1:m] .= x0
    y0[m+1:end] .= vec(Matrix{Float64}(I, m, m))

    function rhs!(dy, y, p, t)
        x = @view y[1:m]
        M = reshape(@view(y[m+1:end]), m, m)
        dx = @view dy[1:m]
        dM = reshape(@view(dy[m+1:end]), m, m)
        dx .= homotopy_rhs(source, target, source_to_target, new_indices, x, p[1], p[2], new_damping)
        dM .= homotopy_jacobian(source, target, source_to_target, new_indices, x, p[1], p[2], new_damping) * M
        return nothing
    end

    prob = ODEProblem(rhs!, y0, (0.0, Float64(T)), [Float64(Re), Float64(eps_h)])
    sol = solve(prob, Vern9(); abstol = abstol, reltol = reltol, saveat = [Float64(T)], dense = false)
    sol.retcode == ReturnCode.Success || return nothing
    yT = sol.u[end]
    xT = collect(Float64, @view yT[1:m])
    MT = Matrix{Float64}(reshape(@view(yT[m+1:end]), m, m))
    return xT, MT
end

function shooting_residual_jacobian(source::ODEModel, target::ODEModel, source_to_target::Vector{Int},
                                    new_indices::Vector{Int}, xi::AbstractVector, xref::AbstractVector,
                                    fref::AbstractVector; Re::Real, eps_h::Real, abstol::Real,
                                    reltol::Real, new_damping::Real)
    m = length(target)
    x0 = collect(Float64, xi[1:m])
    T = Float64(xi[m+1])
    if !(isfinite(T) && T > 0)
        return fill(1e6, m + 1), zeros(Float64, m + 1, m + 1)
    end
    out = integrate_endpoint_tangent(source, target, source_to_target, new_indices, x0, T;
                                     Re = Re, eps_h = eps_h, abstol = abstol, reltol = reltol,
                                     new_damping = new_damping)
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
    J[1:m, m+1] .= homotopy_rhs(source, target, source_to_target, new_indices, xT, Re, eps_h, new_damping)
    J[m+1, 1:m] .= fref
    return r, J
end

function shooting_residual(source::ODEModel, target::ODEModel, source_to_target::Vector{Int},
                           new_indices::Vector{Int}, xi::AbstractVector, xref::AbstractVector,
                           fref::AbstractVector; Re::Real, eps_h::Real, abstol::Real,
                           reltol::Real, new_damping::Real)
    m = length(target)
    x0 = collect(Float64, xi[1:m])
    T = Float64(xi[m+1])
    if !(isfinite(T) && T > 0)
        return fill(1e6, m + 1)
    end
    sol = solve(
        ode_problem(source, target, source_to_target, new_indices, x0;
                    Re = Re, eps_h = eps_h, new_damping = new_damping, tspan = (0.0, T)),
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

function refine_at_epsilon(source::ODEModel, target::ODEModel, source_to_target::Vector{Int},
                           new_indices::Vector{Int}, Dmat, x_start::AbstractVector, T_start::Real;
                           Re::Real, eps_h::Real, abstol::Real, reltol::Real, max_iters::Int,
                           trust_radius::Real, min_span::Real, new_damping::Real, nsamples::Int)
    m = length(target)
    xref = collect(Float64, x_start)
    fref = homotopy_rhs(source, target, source_to_target, new_indices, xref, Re, eps_h, new_damping)
    xi = [xref; Float64(T_start)]
    rows = NamedTuple[]

    for iter in 0:max_iters
        diag = orbit_diagnostics(source, target, source_to_target, new_indices, Dmat, xi[1:m],
                                 Re, xi[end], eps_h; abstol = abstol, reltol = reltol,
                                 nsamples = nsamples, new_damping = new_damping)
        diag === nothing && error("Diagnostic integration failed at eps=$eps_h iter=$iter")
        r, J = shooting_residual_jacobian(source, target, source_to_target, new_indices,
                                          xi, xref, fref; Re = Re, eps_h = eps_h,
                                          abstol = abstol, reltol = reltol,
                                          new_damping = new_damping)
        closure = norm(@view r[1:m])
        resnorm = norm(r)
        cls = span_class(diag.I_span, diag.D_span)
        @printf("eps=%.6f iter=%02d T=%.12f closure=%.6e residual=%.6e I_span=%.6e D_span=%.6e new_norm=%.6e class=%s\n",
                eps_h, iter, xi[end], closure, resnorm, diag.I_span, diag.D_span, diag.new_norm, cls)
        push!(rows, (
            eps = eps_h,
            iteration = iter,
            T = xi[end],
            closure = closure,
            residual = resnorm,
            relative_closure = closure / max(norm(xi[1:m]), eps(Float64)),
            I_span = diag.I_span,
            D_span = diag.D_span,
            E_span = diag.E_span,
            new_norm = diag.new_norm,
            span_class = cls,
            step_norm = 0.0,
            accepted = iter == 0,
            stopped = "",
        ))
        if resnorm < 1e-9
            rows[end] = merge(rows[end], (stopped = "converged",))
            return xi, rows, true
        end
        if min(diag.I_span, diag.D_span) < min_span
            rows[end] = merge(rows[end], (stopped = "span_guard",))
            return xi, rows, false
        end
        iter == max_iters && return xi, rows, false

        delta = -(J \ r)
        if norm(delta) > trust_radius
            delta .*= trust_radius / norm(delta)
        end

        accepted = false
        best_xi = xi
        best_norm = resnorm
        best_step = 0.0
        for scale in (1.0, 0.5, 0.25, 0.125, 0.0625, 0.03125)
            trial = copy(xi)
            trial .+= scale .* delta
            trial[end] = max(trial[end], 1e-6)
            rt = shooting_residual(source, target, source_to_target, new_indices,
                                   trial, xref, fref; Re = Re, eps_h = eps_h,
                                   abstol = abstol, reltol = reltol,
                                   new_damping = new_damping)
            nt = norm(rt)
            trial_diag = orbit_diagnostics(source, target, source_to_target, new_indices,
                                           Dmat, trial[1:m], Re, trial[end], eps_h;
                                           abstol = abstol, reltol = reltol,
                                           nsamples = max(51, div(nsamples, 4)),
                                           new_damping = new_damping)
            span_ok = trial_diag !== nothing && min(trial_diag.I_span, trial_diag.D_span) >= min_span
            if span_ok && nt < best_norm
                accepted = true
                best_xi = trial
                best_norm = nt
                best_step = scale * norm(delta)
                break
            end
        end
        rows[end] = merge(rows[end], (step_norm = best_step, accepted = accepted,
                                      stopped = accepted ? "" : "line_search_failed"))
        accepted || return xi, rows, false
        xi = best_xi
    end

    return xi, rows, false
end

const HERE = @__DIR__
default_base = joinpath(HERE, "eqb_hopf_outputs_2_3_7", "clean_po_pipeline_j2_target270_long")
default_x0 = joinpath(default_base, "ode_refinement", "x0_refined.asc")

source_jkl = parse_jkl_env("HOM_SOURCE_JKL", (2, 3, 7))
target_jkl = parse_jkl_env("HOM_TARGET_JKL", (2, 4, 7))
alpha = parse_float_env("HOM_ALPHA", 1.0)
gamma = parse_float_env("HOM_GAMMA", 2.0)
Re = parse_float_env("HOM_RE", 285.91486006421275)
T0 = parse_float_env("HOM_T", 86.72275925408482)
x0_path = abspath(get(ENV, "HOM_X0", default_x0))
outdir = abspath(get(ENV, "HOM_OUT_DIR",
                     joinpath(default_base, "mode_homotopy_$(source_jkl[1])_$(source_jkl[2])_$(source_jkl[3])_to_$(target_jkl[1])_$(target_jkl[2])_$(target_jkl[3])")))
eps_target = parse_float_env("HOM_EPS_TARGET", 1.0)
eps_step_initial = parse_float_env("HOM_EPS_STEP_INITIAL", 0.05)
eps_step_min = parse_float_env("HOM_EPS_STEP_MIN", 1e-4)
eps_step_max = parse_float_env("HOM_EPS_STEP_MAX", 0.10)
max_iters = parse_int_env("HOM_MAX_ITERS", 5)
trust_radius = parse_float_env("HOM_TRUST_RADIUS", 0.10)
min_span = parse_float_env("HOM_MIN_SPAN", 0.10)
new_damping = parse_float_env("HOM_NEW_DAMPING", 1.0)
abstol = parse_float_env("HOM_ABSTOL", 1e-10)
reltol = parse_float_env("HOM_RELTOL", 1e-10)
nsamples = parse_int_env("HOM_NSAMPLES", 201)
resume = parse_bool_env("HOM_RESUME", false)
mkpath(joinpath(outdir, "states"))

sx, sy, sz, tx, tz = halfbox_symmetries()
H = [sx * sy * sz, sz * tx * tz]

@printf("Building source model J,K,L=(%d,%d,%d)\n", source_jkl...)
source = ODEModel(alpha, gamma, source_jkl..., H, normalize = true)
@printf("Building target model J,K,L=(%d,%d,%d)\n", target_jkl...)
target = ODEModel(alpha, gamma, target_jkl..., H, normalize = true)
Dmat = build_dissipation_matrix(target)

source_to_target, new_indices = mode_map(source, target)
eps_current = 0.0
if resume && isfile(joinpath(outdir, "latest_state.txt"))
    latest_lines = readlines(joinpath(outdir, "latest_state.txt"))
    state_path = strip(latest_lines[1])
    eps_current = parse(Float64, split(strip(latest_lines[2]))[2])
    T_current = parse(Float64, split(strip(latest_lines[3]))[2])
    x_current = load_coeff_vector(state_path)
    length(x_current) == length(target) || error("resume x length $(length(x_current)) != target dimension $(length(target))")
    @printf("Resuming from eps=%.8f T=%.12f state=%s\n", eps_current, T_current, state_path)
else
    x_source = load_coeff_vector(x0_path)
    length(x_source) == length(source) || error("source x length $(length(x_source)) != source dimension $(length(source))")
    x_current = embed_source_state(source, target, x_source)
    T_current = T0
end

open(joinpath(outdir, "run_config.txt"), "w") do io
    println(io, "source_jkl=$(source_jkl)")
    println(io, "target_jkl=$(target_jkl)")
    println(io, "Re=$(Re)")
    println(io, "T0=$(T0)")
    println(io, "x0_path=$(x0_path)")
    println(io, "eps_target=$(eps_target)")
    println(io, "eps_step_initial=$(eps_step_initial)")
    println(io, "eps_step_min=$(eps_step_min)")
    println(io, "eps_step_max=$(eps_step_max)")
    println(io, "max_iters=$(max_iters)")
    println(io, "trust_radius=$(trust_radius)")
    println(io, "min_span=$(min_span)")
    println(io, "new_damping=$(new_damping)")
    println(io, "abstol=$(abstol)")
    println(io, "reltol=$(reltol)")
    println(io, "nsamples=$(nsamples)")
    println(io, "resume=$(resume)")
    println(io, "source_dim=$(length(source))")
    println(io, "target_dim=$(length(target))")
    println(io, "new_dim=$(length(new_indices))")
end

all_rows = NamedTuple[]
eps_step = eps_step_initial
if eps_current == 0.0
    save_coeff_vector(joinpath(outdir, "states", "x_eps000000.asc"), x_current)
end

while eps_current < eps_target - 10eps(Float64)
    global eps_current, eps_step, x_current, T_current, all_rows
    eps_next = min(eps_target, eps_current + eps_step)
    @printf("\nAttempting homotopy step eps %.8f -> %.8f (step %.3e)\n", eps_current, eps_next, eps_step)
    xi, rows, ok = refine_at_epsilon(source, target, source_to_target, new_indices, Dmat,
                                     x_current, T_current; Re = Re, eps_h = eps_next,
                                     abstol = abstol, reltol = reltol, max_iters = max_iters,
                                     trust_radius = trust_radius, min_span = min_span,
                                     new_damping = new_damping, nsamples = nsamples)
    append!(all_rows, rows)
    CSV.write(joinpath(outdir, "homotopy_iterations.csv"), DataFrame(all_rows))

    if ok
        eps_current = eps_next
        x_current = collect(Float64, xi[1:length(target)])
        T_current = Float64(xi[end])
        state_path = joinpath(outdir, "states", @sprintf("x_eps%06d.asc", round(Int, eps_current * 1_000_000)))
        save_coeff_vector(state_path, x_current)
        open(joinpath(outdir, "latest_state.txt"), "w") do io
            println(io, state_path)
            @printf(io, "eps %.17e\n", eps_current)
            @printf(io, "T %.17e\n", T_current)
        end
        eps_step = min(eps_step_max, 1.25 * eps_step)
        @printf("Accepted eps=%.8f T=%.12f; next step %.3e\n", eps_current, T_current, eps_step)
    else
        eps_step *= 0.5
        @printf("Rejected eps=%.8f; reducing step to %.3e\n", eps_next, eps_step)
        if eps_step < eps_step_min
            @printf("Stopping: eps step %.3e below minimum %.3e\n", eps_step, eps_step_min)
            break
        end
    end
end

final_diag = orbit_diagnostics(source, target, source_to_target, new_indices, Dmat, x_current,
                               Re, T_current, eps_current; abstol = abstol, reltol = reltol,
                               nsamples = max(nsamples, 401), new_damping = new_damping)
if final_diag !== nothing
    CSV.write(joinpath(outdir, "homotopy_final_summary.csv"), DataFrame([(
        source_J = source_jkl[1],
        source_K = source_jkl[2],
        source_L = source_jkl[3],
        target_J = target_jkl[1],
        target_K = target_jkl[2],
        target_L = target_jkl[3],
        Re = Re,
        eps = eps_current,
        T = T_current,
        closure = final_diag.closure,
        relative_closure = final_diag.relative_closure,
        I_span = final_diag.I_span,
        D_span = final_diag.D_span,
        E_span = final_diag.E_span,
        new_norm = final_diag.new_norm,
        span_class = span_class(final_diag.I_span, final_diag.D_span),
        reached_target = eps_current >= eps_target - 10eps(Float64),
    )]))
end

@printf("\nHomotopy finished at eps=%.8f / %.8f, T=%.12f\n", eps_current, eps_target, T_current)
println("Wrote homotopy outputs to $outdir")

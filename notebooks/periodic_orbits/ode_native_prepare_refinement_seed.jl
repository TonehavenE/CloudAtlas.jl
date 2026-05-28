# -*- coding: utf-8 -*-
# Reconstruct a saved ODE-native recurrence seed from the recurrence scan CSV.

if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "..", ".."))
end

using CSV
using CloudAtlas
using DataFrames
using DifferentialEquations
using Printf
using Random

parse_float_env(name, default) = parse(Float64, strip(get(ENV, name, string(default))))

function parse_jkl_env(name::AbstractString, default::NTuple{3, Int})
    raw = strip(get(ENV, name, ""))
    isempty(raw) && return default
    parts = split(lowercase(raw), "x")
    length(parts) == 3 || error("Invalid $name='$raw'. Expected JxKxL.")
    return (parse(Int, parts[1]), parse(Int, parts[2]), parse(Int, parts[3]))
end

function parse_bool_env(name::AbstractString, default::Bool)
    raw = lowercase(strip(get(ENV, name, default ? "true" : "false")))
    raw in ("1", "true", "t", "yes", "y") && return true
    raw in ("0", "false", "f", "no", "n") && return false
    error("Invalid boolean ENV[$name]='$raw'")
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

function ode_problem(model::ODEModel, x0::AbstractVector; Re::Real, tspan)
    function rhs!(du, u, p, t)
        du .= model.f(u, p[1])
        return nothing
    end
    return ODEProblem(rhs!, collect(x0), tspan, [Float64(Re)])
end

function integrate_endpoint(model::ODEModel, x0::AbstractVector, T::Real; Re::Real, abstol::Real, reltol::Real)
    T == 0 && return collect(Float64, x0)
    sol = solve(
        ode_problem(model, x0; Re = Re, tspan = (0.0, T)),
        Tsit5();
        abstol = abstol,
        reltol = reltol,
        saveat = [T],
        dense = false,
    )
    sol.retcode == ReturnCode.Success || error("seed integration failed: $(sol.retcode)")
    return collect(Float64, sol.u[end])
end

const HERE = @__DIR__
Re = parse_float_env("ODE_NATIVE_RE", 200.0)
alpha = parse_float_env("ODE_NATIVE_ALPHA", 1.0)
gamma = parse_float_env("ODE_NATIVE_GAMMA", 2.0)
J, K, L = parse_jkl_env("ODE_NATIVE_JKL", (2, 4, 7))
normalize_basis = parse_bool_env("ODE_NATIVE_NORMALIZE", true)
abstol = parse_float_env("ODE_NATIVE_SOLVER_ABSTOL", 1e-8)
reltol = parse_float_env("ODE_NATIVE_SOLVER_RELTOL", 1e-8)
random_amp = parse_float_env("ODE_NATIVE_RANDOM_AMP", 0.05)

csv_path = abspath(get(ENV, "ODE_NATIVE_CANDIDATE_CSV", joinpath(HERE, "ode_native_recurrence", "ode_native_recurrence_candidates_J$(J)_K$(K)_L$(L).csv")))
span_class = strip(get(ENV, "ODE_NATIVE_REFINE_SPAN_CLASS", "medium"))
seed_label_env = strip(get(ENV, "ODE_NATIVE_REFINE_SEED_LABEL", ""))
out_path = abspath(get(ENV, "ODE_NATIVE_REFINE_SEED_OUT", joinpath(HERE, "ode_native_recurrence", "refinement_seeds", "x0_best_$(span_class)_J$(J)_K$(K)_L$(L).asc")))

sx, sy, sz, tx, tz = halfbox_symmetries()
H = [sx * sy * sz, sz * tx * tz]
model = ODEModel(alpha, gamma, J, K, L, H; normalize = normalize_basis, tw = false)

df = CSV.read(csv_path, DataFrame)
sub = df[df.span_class .== span_class, :]
isempty(seed_label_env) || (sub = sub[sub.seed_label .== seed_label_env, :])
isempty(sub) && error("No candidate found for span_class=$span_class seed_label=$seed_label_env in $csv_path")
sort!(sub, :closure)
row = sub[1, :]

gibson_out = joinpath(HERE, "gibson", "ode_recurrence_attempt")
seed_paths = Dict(
    "projected_gibson_orbit1" => joinpath(gibson_out, "orbit1", "x0_projected_J$(J)_K$(K)_L$(L).asc"),
    "guarded_large_loop" => joinpath(gibson_out, "orbit1", "x_guarded_direct_w1p0_J$(J)_K$(K)_L$(L).asc"),
    "ms_large_loop_T57" => joinpath(gibson_out, "multiple_shooting_continuation", "x_ms_guarded_w1p0_N8_T57p581175_J$(J)_K$(K)_L$(L).asc"),
    "near_equilibrium_direct" => joinpath(gibson_out, "orbit1", "x_hookstep_po_direct_J$(J)_K$(K)_L$(L).asc"),
)

if haskey(seed_paths, row.seed_label)
    xbase = load_coeff_vector(seed_paths[row.seed_label])
else
    m = match(r"^random_symmetry_(\d+)$", row.seed_label)
    m === nothing && error("Cannot reconstruct seed label $(row.seed_label)")
    target_n = parse(Int, m.captures[1])
    Random.seed!(20260514)
    xbase = [random_amp .* randn(length(model)) for _ in 1:target_n][end]
end

x0 = integrate_endpoint(model, xbase, row.phase_time; Re = Re, abstol = abstol, reltol = reltol)
save_coeff_vector(out_path, x0)
@printf("Saved %s\n", out_path)
@printf("seed_label=%s span_class=%s phase_time=%.12f best_T=%.12f closure=%.6e I_span=%.6e D_span=%.6e\n",
        row.seed_label, row.span_class, row.phase_time, row.best_T, row.closure, row.I_span, row.D_span)

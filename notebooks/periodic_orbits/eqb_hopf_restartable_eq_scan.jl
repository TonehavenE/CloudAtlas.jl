# -*- coding: utf-8 -*-
# Restartable fixed-Re EQ/eigenvalue scan for the EQ1 Hopf region.
#
# This intentionally avoids a long non-checkpointed PALC sweep. Each converged
# equilibrium and its eigenvalues are written immediately before moving on.

if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "../.."))
end

using CSV
using CloudAtlas
using ChannelflowWrapper
using DataFrames
using Dates
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

function git_revision()
    try
        return strip(read(`git rev-parse --short HEAD`, String))
    catch
        return "unknown"
    end
end

function write_run_config(path::AbstractString, pairs)
    open(path, "w") do io
        for (k, v) in pairs
            println(io, "$k = $v")
        end
    end
end

function re_sequence(Re0::Real, scan_start::Real, scan_stop::Real, dRe::Real)
    d = abs(Float64(dRe))
    warm = Float64[]
    if abs(scan_start - Re0) > 1e-12
        sgn = sign(scan_start - Re0)
        r = Float64(Re0)
        while abs(scan_start - r) > d / 2
            r += sgn * d
            push!(warm, r)
            abs(scan_start - r) <= d / 2 && break
        end
        warm[end] = Float64(scan_start)
    else
        push!(warm, Float64(scan_start))
    end

    scan = Float64[]
    sgn = sign(scan_stop - scan_start)
    r = Float64(scan_start)
    push!(scan, r)
    while sgn * (scan_stop - r) > d / 2
        r += sgn * d
        push!(scan, r)
    end
    scan[end] = Float64(scan_stop)

    vals = vcat(warm, scan[2:end])
    unique_vals = Float64[]
    for r in vals
        isempty(unique_vals) || abs(r - unique_vals[end]) > 1e-10 || continue
        push!(unique_vals, r)
    end
    return unique_vals
end

function eig_summary(evals; real_tol::Real, imag_tol::Real)
    unstable = count(real.(evals) .> real_tol)
    complex_idxs = findall(abs.(imag.(evals)) .> imag_tol)
    if isempty(complex_idxs)
        return (
            unstable_count = unstable,
            max_real = maximum(real.(evals)),
            max_complex_real = NaN,
            max_complex_imag = NaN,
            hopf_period_estimate = NaN,
        )
    end
    vals = evals[complex_idxs]
    λ = vals[argmax(real.(vals))]
    omega = abs(imag(λ))
    return (
        unstable_count = unstable,
        max_real = maximum(real.(evals)),
        max_complex_real = real(λ),
        max_complex_imag = imag(λ),
        hopf_period_estimate = omega > 0 ? 2π / omega : NaN,
    )
end

function append_csv(path::AbstractString, row::NamedTuple)
    df = DataFrame([row])
    CSV.write(path, df; append = isfile(path), writeheader = !isfile(path))
end

function append_eigs(path::AbstractString, step::Int, Re::Real, evals; top::Int)
    order = sortperm(evals; by = λ -> (-real(λ), -abs(imag(λ))))
    rows = NamedTuple[]
    for (rank, idx) in enumerate(order[1:min(top, length(order))])
        λ = evals[idx]
        push!(rows, (step = step, Re = Float64(Re), rank = rank, eig_real = real(λ), eig_imag = imag(λ)))
    end
    CSV.write(path, DataFrame(rows); append = isfile(path), writeheader = !isfile(path))
end

function main()
HERE = @__DIR__
alpha = parse_float_env("HOPF_ALPHA", 1.0)
gamma = parse_float_env("HOPF_GAMMA", 2.0)
J, K, L = parse_jkl_env("HOPF_JKL", (3, 5, 9))
Re0 = parse_float_env("HOPF_RE0", 300.0)
scan_start = parse_float_env("HOPF_SCAN_RE_START", 330.0)
scan_stop = parse_float_env("HOPF_SCAN_RE_STOP", 370.0)
dRe = parse_float_env("HOPF_SCAN_DRE", 1.0)
eig_top = parse_int_env("HOPF_EIG_TOP", 24)
real_tol = parse_float_env("HOPF_EIG_REAL_TOL", 1e-7)
imag_tol = parse_float_env("HOPF_EIG_IMAG_TOL", 1e-7)
resume = parse_bool_env("HOPF_RESUME", true)
start_state_path = strip(get(ENV, "HOPF_START_STATE", ""))
start_state_Re = parse_float_env("HOPF_START_RE", Re0)

base_out = joinpath(HERE, "eqb_hopf_outputs_$(J)_$(K)_$(L)")
outdir = abspath(get(ENV, "HOPF_RESTART_EQ_OUT_DIR", joinpath(base_out, "restartable_eq_branch")))
state_dir = joinpath(outdir, "states")
mkpath(state_dir)

metadata_path = joinpath(outdir, "eq_branch_metadata.csv")
eig_path = joinpath(outdir, "eq_branch_leading_eigenvalues.csv")
config_path = joinpath(outdir, "run_config.txt")

sx, sy, sz, tx, tz = halfbox_symmetries()
H = [sx * sy * sz, sz * tx * tz]
@printf("Building model J,K,L=(%d,%d,%d)\n", J, K, L)
model = ODEModel(alpha, gamma, J, K, L, H; normalize = true)
m = length(model)
@printf("Model dimension m=%d\n", m)

write_run_config(config_path, [
    "timestamp" => Dates.format(now(), dateformat"yyyy-mm-ddTHH:MM:SS"),
    "git_revision" => git_revision(),
    "script" => abspath(@__FILE__),
    "alpha" => alpha,
    "gamma" => gamma,
    "J" => J,
    "K" => K,
    "L" => L,
    "m" => m,
    "symmetry_group" => "<sxyz, sztxz>",
    "Re0" => Re0,
    "scan_start" => scan_start,
    "scan_stop" => scan_stop,
    "dRe" => dRe,
    "eig_top" => eig_top,
    "real_tol" => real_tol,
    "imag_tol" => imag_tol,
])

proj_asc = joinpath(base_out, "xeq1_dns_projection_$(J)_$(K)_$(L).asc")
if isfile(proj_asc)
    xguess = load_coeff_vector(proj_asc)
else
    dns_file = joinpath(HERE, "EQ1Re300-32x49x40.nc")
    isfile(dns_file) || error("Missing DNS projection source $dns_file")
    x_proj = ChannelflowWrapper.field2coeff(model.ijkl, dns_file, proj_asc; workdir = base_out)
    xguess = size(x_proj, 2) == 1 ? vec(Float64.(x_proj[:, 1])) : vec(Float64.(x_proj))
end
length(xguess) == m || error("Projection length $(length(xguess)) != model dimension $m")

done = DataFrame()
if resume && isfile(metadata_path)
    done = CSV.read(metadata_path, DataFrame)
end
done_Re = isempty(done) ? Float64[] : Float64.(done.Re)

hookparams = SearchParams(ftol = 1e-10, xtol = 1e-12, δ = 0.05, Nnewton = 40, Nhook = 8, Nmusearch = 6, verbosity = 0)

if !isempty(done)
    last_row = done[end, :]
    xprev = load_coeff_vector(String(last_row.state_path))
    @printf("Resuming from step %d Re=%.8f\n", Int(last_row.step), Float64(last_row.Re))
elseif !isempty(start_state_path)
    xprev = load_coeff_vector(abspath(start_state_path))
    length(xprev) == m || error("Start-state length $(length(xprev)) != model dimension $m")
    Re0 = start_state_Re
    @printf("Starting from saved EQ state %s at Re=%.8f\n", abspath(start_state_path), Re0)
else
    @printf("Converging EQ seed at Re0=%.8f\n", Re0)
    xprev, ok = hookstepsolve(x -> model.f(x, Re0), x -> model.Df(x, Re0), xguess, hookparams)
    ok || error("Initial EQ solve failed at Re0=$Re0")
end

values = re_sequence(Re0, scan_start, scan_stop, dRe)
step0 = isempty(done) ? 0 : maximum(Int.(done.step))

for Re in values
    any(abs.(done_Re .- Re) .< 1e-10) && continue
    step = step0 + 1
    @printf("Step %04d Re=%.8f ... ", step, Re)
    xsol, ok = hookstepsolve(x -> model.f(x, Re), x -> model.Df(x, Re), xprev, hookparams)
    if !ok
        @printf("failed\n")
        append_csv(metadata_path, (
            step = step,
            Re = Re,
            converged = false,
            residual_norm = NaN,
            norm = NaN,
            shear = NaN,
            power = NaN,
            unstable_count = missing,
            max_real = NaN,
            max_complex_real = NaN,
            max_complex_imag = NaN,
            hopf_period_estimate = NaN,
            state_path = "",
        ))
        break
    end

    state_path = joinpath(state_dir, @sprintf("xeq_step%04d_Re%.8f.asc", step, Re))
    save_coeff_vector(state_path, xsol)
    Jmat = model.Df(xsol, Re)
    evals = eigvals(Jmat)
    es = eig_summary(evals; real_tol = real_tol, imag_tol = imag_tol)
    append_eigs(eig_path, step, Re, evals; top = eig_top)
    resnorm = norm(model.f(xsol, Re))
    append_csv(metadata_path, (
        step = step,
        Re = Re,
        converged = true,
        residual_norm = resnorm,
        norm = norm(xsol),
        shear = shear(xsol, model),
        power = power_input(model, xsol),
        unstable_count = es.unstable_count,
        max_real = es.max_real,
        max_complex_real = es.max_complex_real,
        max_complex_imag = es.max_complex_imag,
        hopf_period_estimate = es.hopf_period_estimate,
        state_path = state_path,
    ))
    @printf("|f|=%.3e unstable=%d max_complex=%+.4e%+.4ei Tlin=%.6f\n",
            resnorm, es.unstable_count, es.max_complex_real, es.max_complex_imag, es.hopf_period_estimate)
    xprev = xsol
    push!(done_Re, Re)
    step0 = step
end

println("Wrote $metadata_path")
println("Wrote $eig_path")
end

main()

# -*- coding: utf-8 -*-
# Project a DNS trajectory, rank recurrent windows, and test ODE shadowing.

if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "..", ".."))
end

using CSV
using CloudAtlas
using ChannelflowWrapper
using DataFrames
using Dates
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

function flatten_coeffs(raw)
    raw isa AbstractMatrix && return vec(Float64.(raw[:, 1]))
    return vec(Float64.(raw))
end

function save_coeff_vector(path::AbstractString, x::AbstractVector)
    mkpath(dirname(path))
    open(path, "w") do io
        for value in x
            @printf(io, "%.17e\n", Float64(value))
        end
    end
end

function load_coeff_vector(path::AbstractString)
    vals = Float64[]
    for line in readlines(path)
        s = strip(line)
        isempty(s) && continue
        startswith(s, "#") && continue
        startswith(s, "%") && continue
        for tok in split(s)
            value = tryparse(Float64, tok)
            value === nothing || push!(vals, value)
        end
    end
    isempty(vals) && error("No numeric coefficients in $path")
    return vals
end

function snapshot_time(path::AbstractString, label::AbstractString)
    base = basename(path)
    m = match(Regex("^" * escape_string(label) * raw"([0-9eE+\-.]+)\.nc$"), base)
    m === nothing && return nothing
    return tryparse(Float64, m.captures[1])
end

function collect_snapshots(dir::AbstractString, label::AbstractString; tmin::Real, tmax::Real)
    isdir(dir) || error("Missing DNS series directory: $dir")
    snaps = NamedTuple[]
    for name in readdir(dir)
        endswith(name, ".nc") || continue
        path = joinpath(dir, name)
        t = snapshot_time(path, label)
        t === nothing && continue
        tmin <= t <= tmax || continue
        push!(snaps, (t = t, path = path, name = name))
    end
    sort!(snaps; by = s -> s.t)
    return snaps
end

function ode_endpoint(model::ODEModel, x0::AbstractVector, T::Real; Re::Real, abstol::Real, reltol::Real)
    function rhs!(du, u, p, t)
        du .= model.f(u, p[1])
        return nothing
    end
    prob = ODEProblem(rhs!, collect(x0), (0.0, Float64(T)), [Float64(Re)])
    sol = solve(prob, Tsit5(); abstol = abstol, reltol = reltol, saveat = [Float64(T)], dense = false)
    sol.retcode == ReturnCode.Success || return nothing
    return collect(Float64, sol.u[end])
end

function write_run_config(path::AbstractString, pairs)
    open(path, "w") do io
        for (k, v) in pairs
            println(io, "$k = $v")
        end
    end
end

const HERE = @__DIR__
series_dir = abspath(get(ENV, "DNS_REC_SERIES_DIR", joinpath(HERE, "dns_recurrence_eq1", "dns_series")))
label = strip(get(ENV, "DNS_REC_LABEL", "u_dns"))
outdir = abspath(get(ENV, "DNS_REC_OUT_DIR", joinpath(dirname(series_dir), "projected_recurrence")))
Re = parse_float_env("DNS_REC_RE", 300.0)
alpha = parse_float_env("DNS_REC_ALPHA", 1.0)
gamma = parse_float_env("DNS_REC_GAMMA", 2.0)
J, K, L = parse_jkl_env("DNS_REC_JKL", (3, 5, 9))
tmin = parse_float_env("DNS_REC_TMIN", 0.0)
tmax = parse_float_env("DNS_REC_TMAX", Inf)
period_min = parse_float_env("DNS_REC_PERIOD_MIN", 20.0)
period_max = parse_float_env("DNS_REC_PERIOD_MAX", 200.0)
top_k = parse_int_env("DNS_REC_TOP_K", 25)
shadow_k = parse_int_env("DNS_REC_SHADOW_K", min(100, 5 * top_k))
dns_l2_k = parse_int_env("DNS_REC_DNS_L2_K", min(10, top_k))
project_normalized = parse_bool_env("DNS_REC_PROJECT_NRM", true)
abstol = parse_float_env("DNS_REC_SOLVER_ABSTOL", 1e-8)
reltol = parse_float_env("DNS_REC_SOLVER_RELTOL", 1e-8)

mkpath(outdir)
write_run_config(joinpath(outdir, "run_config.txt"), [
    "timestamp" => Dates.format(now(), dateformat"yyyy-mm-ddTHH:MM:SS"),
    "script" => abspath(@__FILE__),
    "series_dir" => series_dir,
    "label" => label,
    "outdir" => outdir,
    "Re" => Re,
    "J" => J,
    "K" => K,
    "L" => L,
    "period_min" => period_min,
    "period_max" => period_max,
    "top_k" => top_k,
    "shadow_k" => shadow_k,
    "dns_l2_k" => dns_l2_k,
])

sx, sy, sz, tx, tz = halfbox_symmetries()
H = [sx * sy * sz, sz * tx * tz]
model = ODEModel(alpha, gamma, J, K, L, H; normalize = true)
snaps = collect_snapshots(series_dir, label; tmin = tmin, tmax = tmax)
length(snaps) >= 2 || error("Need at least two snapshots in $series_dir with label $label")
@printf("Projecting %d DNS snapshots to J,K,L=(%d,%d,%d)\n", length(snaps), J, K, L)

coeff_dir = joinpath(outdir, "projected_J$(J)_K$(K)_L$(L)")
mkpath(coeff_dir)
xs = Vector{Vector{Float64}}(undef, length(snaps))
coeff_paths = Vector{String}(undef, length(snaps))
for (idx, snap) in enumerate(snaps)
    coeff_path = joinpath(coeff_dir, replace(snap.name, ".nc" => ".asc"))
    coeff_paths[idx] = coeff_path
    if isfile(coeff_path)
        xs[idx] = load_coeff_vector(coeff_path)
    else
        kwargs = project_normalized ? (nrm = true,) : NamedTuple()
        raw = ChannelflowWrapper.field2coeff(model.ijkl, snap.path, coeff_path; workdir = coeff_dir, kwargs...)
        xs[idx] = flatten_coeffs(raw)
    end
    length(xs[idx]) == length(model) || error("Projection length mismatch for $(snap.path)")
end

coarse = NamedTuple[]
for i in 1:length(snaps)-1
    xi = xs[i]
    denom = max(norm(xi), eps(Float64))
    for j in i+1:length(snaps)
        T = snaps[j].t - snaps[i].t
        period_min <= T <= period_max || continue
        dist = norm(xs[j] .- xi)
        push!(coarse, (
            i = i,
            j = j,
            t0 = snaps[i].t,
            t1 = snaps[j].t,
            T = T,
            coeff_closure = dist,
            coeff_relative = dist / denom,
        ))
    end
end
sort!(coarse; by = c -> c.coeff_relative)
isempty(coarse) && error("No candidate pairs found in period window")

rows = NamedTuple[]
for (rank, c) in enumerate(coarse[1:min(length(coarse), shadow_k)])
    x0 = xs[c.i]
    x1 = xs[c.j]
    xT = ode_endpoint(model, x0, c.T; Re = Re, abstol = abstol, reltol = reltol)
    xT === nothing && continue
    denom0 = max(norm(x0), eps(Float64))
    denom1 = max(norm(x1), eps(Float64))
    dns_l2 = NaN
    dns_l2_rel = NaN
    if rank <= dns_l2_k
        n0 = ChannelflowWrapper.L2norm(snaps[c.i].path)
        dns_l2 = ChannelflowWrapper.L2op(snaps[c.i].path, snaps[c.j].path; dist = true)
        dns_l2_rel = dns_l2 / max(n0, eps(Float64))
    end
    push!(rows, (
        rank = rank,
        i = c.i,
        j = c.j,
        t0 = c.t0,
        t1 = c.t1,
        T = c.T,
        coeff_closure = c.coeff_closure,
        coeff_relative = c.coeff_relative,
        ode_to_dns_projected_closure = norm(xT .- x1),
        ode_to_dns_projected_relative = norm(xT .- x1) / denom1,
        ode_periodic_closure = norm(xT .- x0),
        ode_periodic_relative = norm(xT .- x0) / denom0,
        dns_l2_closure = dns_l2,
        dns_l2_relative = dns_l2_rel,
        field0 = snaps[c.i].path,
        field1 = snaps[c.j].path,
        x0_path = coeff_paths[c.i],
        x1_path = coeff_paths[c.j],
    ))
end

df = DataFrame(rows)
sort!(df, [:ode_to_dns_projected_relative, :coeff_relative])
df.rank .= 1:nrow(df)
out_csv = joinpath(outdir, "dns_recurrence_projected_shadow_J$(J)_K$(K)_L$(L).csv")
CSV.write(out_csv, df)

seed_dir = joinpath(outdir, "refinement_seeds")
mkpath(seed_dir)
for row in eachrow(df[1:min(nrow(df), top_k), :])
    seed_path = joinpath(seed_dir, @sprintf("x0_rank%03d_t%.6f_T%.6f.asc", row.rank, row.t0, row.T))
    save_coeff_vector(seed_path, xs[Int(row.i)])
end

@printf("Wrote %s\n", out_csv)
@printf("Best candidate: rank=%d t0=%.6f T=%.6f coeff_rel=%.6e ode_shadow_rel=%.6e ode_periodic_rel=%.6e dns_l2_rel=%s\n",
        Int(df[1, :rank]), df[1, :t0], df[1, :T], df[1, :coeff_relative],
        df[1, :ode_to_dns_projected_relative], df[1, :ode_periodic_relative],
        isfinite(df[1, :dns_l2_relative]) ? @sprintf("%.6e", df[1, :dns_l2_relative]) : "not_checked")

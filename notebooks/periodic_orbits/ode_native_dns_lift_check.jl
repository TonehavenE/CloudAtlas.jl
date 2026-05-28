# -*- coding: utf-8 -*-
# Lift a refined ODE-native periodic orbit to Channelflow DNS, run pure time
# integration for one period, and measure DNS/ODE-projected closure.

if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "..", ".."))
end

using CSV
using CloudAtlas
using ChannelflowWrapper
using DataFrames
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

function write_symm_E(path::AbstractString)
    mkpath(dirname(path))
    open(path, "w") do io
        # <sxyz, sztxz> in Channelflow's six-number symmetry format.
        println(io, "% 2")
        println(io, "1 -1 -1 -1 0.0 0.0")
        println(io, "1 1 1 -1 0.5 0.5")
    end
end

function flowfield_sort_key(path::AbstractString, label::AbstractString)
    base = basename(path)
    m = match(Regex("^" * escape_string(label) * raw"(?:_?)(\d+).*\.nc$"), base)
    m === nothing && return (typemax(Int), base)
    return (parse(Int, m.captures[1]), base)
end

function find_saved_fields(dir::AbstractString, label::AbstractString)
    isdir(dir) || return String[]
    files = filter(path -> isfile(path) && endswith(path, ".nc") && startswith(basename(path), label),
                   joinpath.(Ref(dir), readdir(dir)))
    return sort(files; by = path -> flowfield_sort_key(path, label))
end

function flatten_coeffs(raw)
    v = vec(Float64.(raw))
    return v
end

const HERE = @__DIR__
default_base = joinpath(HERE, "eqb_hopf_outputs_2_3_7", "clean_po_pipeline_j2_target270_long")
default_refine = joinpath(default_base, "ode_refinement")
default_x0 = joinpath(default_refine, "x0_refined.asc")
default_template = joinpath(HERE, "EQ1Re300-32x49x40.nc")

x0_path = abspath(get(ENV, "DNS_LIFT_X0", default_x0))
template_field = abspath(get(ENV, "DNS_LIFT_TEMPLATE", default_template))
Re = parse_float_env("DNS_LIFT_RE", 285.91486006421275)
T = parse_float_env("DNS_LIFT_T", 86.72275925408482)
alpha = parse_float_env("DNS_LIFT_ALPHA", 1.0)
gamma = parse_float_env("DNS_LIFT_GAMMA", 2.0)
J, K, L = parse_jkl_env("DNS_LIFT_JKL", (2, 3, 7))
dt = parse_float_env("DNS_LIFT_DT", 0.03125)
dT = parse_float_env("DNS_LIFT_SAVE_DT", T)
run_dns = parse_bool_env("DNS_LIFT_RUN", true)
use_symms = parse_bool_env("DNS_LIFT_USE_SYMMS", true)
label = strip(get(ENV, "DNS_LIFT_LABEL", "u_dns_lift_po"))
outdir = abspath(get(ENV, "DNS_LIFT_OUT_DIR", joinpath(default_base, "dns_lift_check")))
mkpath(outdir)

sx, sy, sz, tx, tz = halfbox_symmetries()
H = [sx * sy * sz, sz * tx * tz]
@printf("Building model J,K,L=(%d,%d,%d), Re=%.12f\n", J, K, L, Re)
model = ODEModel(alpha, gamma, J, K, L, H, normalize = true)
x0 = load_coeff_vector(x0_path)
length(x0) == length(model) || error("x0 length $(length(x0)) != model dimension $(length(model))")

u0_path = joinpath(outdir, "u0_lifted_refined_po.nc")
@printf("Lifting coefficients -> %s\n", u0_path)
ChannelflowWrapper.coeff2field(x0, model.ijkl, template_field, u0_path; workdir = outdir)

symm_path = joinpath(outdir, "symm_E_sxyz_sztxz.asc")
use_symms && write_symm_E(symm_path)

run_dir = joinpath(outdir, "simulate_T")
mkpath(run_dir)
if run_dns
    sim_kwargs = Dict{Symbol, Any}(
        :R => Re,
        :T => T,
        :dT => dT,
        :dt => dt,
        :o => run_dir,
        :l => label,
        :l2 => true,
        :D => true,
        :I => true,
        :dv => true,
    )
    use_symms && (sim_kwargs[:symms] = symm_path)
    @printf("Running simulateflow T=%.12f dT=%.12f dt=%.8f out=%s label=%s\n", T, dT, dt, run_dir, label)
    ChannelflowWrapper.simulateflow(u0_path; sim_kwargs...)
else
    @printf("Skipping simulateflow because DNS_LIFT_RUN=false\n")
end

fields = find_saved_fields(run_dir, label)
@printf("Found %d saved fields with label %s\n", length(fields), label)
isempty(fields) && error("No saved DNS fields found in $run_dir with label $label")
final_field = fields[end]
@printf("Final field: %s\n", final_field)

l2_u0 = ChannelflowWrapper.L2norm(u0_path)
l2_final = ChannelflowWrapper.L2norm(final_field)
l2_dist = ChannelflowWrapper.L2op(u0_path, final_field; dist = true)
l2_rel = l2_dist / max(l2_u0, eps(Float64))

xT_path = joinpath(outdir, "xT_dns_projected.asc")
raw = ChannelflowWrapper.field2coeff(model.ijkl, final_field, xT_path; workdir = outdir)
xT = flatten_coeffs(raw)
coeff_closure = norm(xT .- x0)
coeff_rel = coeff_closure / max(norm(x0), eps(Float64))

summary = DataFrame([(
    Re = Re,
    T = T,
    dt = dt,
    dT = dT,
    u0_path = u0_path,
    final_field = final_field,
    n_saved_fields = length(fields),
    l2_u0 = l2_u0,
    l2_final = l2_final,
    l2_dist = l2_dist,
    l2_relative = l2_rel,
    coeff_closure_projected = coeff_closure,
    coeff_relative_projected = coeff_rel,
    xT_projected_path = xT_path,
)])
summary_path = joinpath(outdir, "dns_lift_closure_summary.csv")
CSV.write(summary_path, summary)
@printf("DNS L2 closure: dist=%.6e relative=%.6e\n", l2_dist, l2_rel)
@printf("Projected coefficient closure: %.6e relative=%.6e\n", coeff_closure, coeff_rel)
@printf("Wrote %s\n", summary_path)

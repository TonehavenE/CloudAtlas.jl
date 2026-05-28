# -*- coding: utf-8 -*-
# Generate a checkpointed DNS trajectory for recurrence hunting.

if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "..", ".."))
end

using ChannelflowWrapper
using Dates
using Printf

parse_float_env(name, default) = parse(Float64, strip(get(ENV, name, string(default))))
parse_int_env(name, default) = parse(Int, strip(get(ENV, name, string(default))))

function parse_bool_env(name::AbstractString, default::Bool)
    raw = lowercase(strip(get(ENV, name, default ? "true" : "false")))
    raw in ("1", "true", "t", "yes", "y") && return true
    raw in ("0", "false", "f", "no", "n") && return false
    error("Invalid boolean ENV[$name]='$raw'")
end

function write_symm_E(path::AbstractString)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, "% 2")
        println(io, "1 -1 -1 -1 0.0 0.0")
        println(io, "1 1 1 -1 0.5 0.5")
    end
end

function write_run_config(path::AbstractString, pairs)
    open(path, "w") do io
        for (k, v) in pairs
            println(io, "$k = $v")
        end
    end
end

const HERE = @__DIR__
source = abspath(get(ENV, "DNS_REC_SOURCE", joinpath(HERE, "EQ1Re300-32x49x40.nc")))
outdir = abspath(get(ENV, "DNS_REC_OUT_DIR", joinpath(HERE, "dns_recurrence_eq1")))
run_dir = joinpath(outdir, "dns_series")
label = strip(get(ENV, "DNS_REC_LABEL", "u_dns"))
Re = parse_float_env("DNS_REC_RE", 300.0)
T = parse_float_env("DNS_REC_T", 500.0)
dt = parse_float_env("DNS_REC_DT", 0.03125)
dT = parse_float_env("DNS_REC_SAVE_DT", 1.0)
perturb = parse_bool_env("DNS_REC_PERTURB", true)
perturb_mag = parse_float_env("DNS_REC_PERTURB_MAG", 0.02)
perturb_seed = parse_int_env("DNS_REC_PERTURB_SEED", 1)
use_symms = parse_bool_env("DNS_REC_USE_SYMMS", true)

isfile(source) || error("Missing DNS_REC_SOURCE: $source")
mkpath(run_dir)

symm_path = joinpath(outdir, "symm_E_sxyz_sztxz.asc")
use_symms && write_symm_E(symm_path)

u0 = source
if perturb
    u0 = joinpath(outdir, "u0_perturbed.nc")
    if !isfile(u0)
        @printf("Perturbing %s -> %s\n", source, u0)
        ChannelflowWrapper.perturbfield(source, u0; m = perturb_mag, sd = perturb_seed)
    else
        @printf("Using existing perturbed field %s\n", u0)
    end
end

write_run_config(joinpath(outdir, "run_config.txt"), [
    "timestamp" => Dates.format(now(), dateformat"yyyy-mm-ddTHH:MM:SS"),
    "script" => abspath(@__FILE__),
    "source" => source,
    "u0" => u0,
    "outdir" => outdir,
    "run_dir" => run_dir,
    "label" => label,
    "Re" => Re,
    "T" => T,
    "dt" => dt,
    "save_dt" => dT,
    "perturb" => perturb,
    "perturb_mag" => perturb_mag,
    "perturb_seed" => perturb_seed,
    "use_symms" => use_symms,
])

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

@printf("Running DNS series: Re=%.6f T=%.6f dT=%.6f dt=%.6f out=%s label=%s\n",
        Re, T, dT, dt, run_dir, label)
ChannelflowWrapper.simulateflow(u0; sim_kwargs...)
@printf("DNS recurrence series complete: %s\n", run_dir)

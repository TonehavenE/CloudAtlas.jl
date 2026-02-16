import Pkg
Pkg.activate("../../.")

using CloudAtlas
using ChannelflowWrapper
using Printf

function parse_args(args)
    out = Dict{String, String}()
    i = 1
    while i <= length(args)
        if startswith(args[i], "--")
            key = args[i][3:end]
            if i == length(args) || startswith(args[i + 1], "--")
                out[key] = "true"
                i += 1
            else
                out[key] = args[i + 1]
                i += 2
            end
        else
            i += 1
        end
    end
    return out
end

function parse_bool(args::Dict{String, String}, key::String; default::Bool = false)
    if !haskey(args, key)
        return default
    end
    v = lowercase(strip(args[key]))
    return v in ("1", "true", "yes", "y")
end

function parse_groups_arg(args::Dict{String, String})
    if !haskey(args, "groups")
        return nothing
    end
    groups = Set{String}()
    for s in split(args["groups"], ",")
        g = strip(s)
        isempty(g) && continue
        push!(groups, g)
    end
    return isempty(groups) ? nothing : groups
end

function extract_group(path::AbstractString)
    for comp in splitpath(path)
        m = match(r"^([A-Za-z]+)_Lx", comp)
        m === nothing && continue
        return m.captures[1]
    end
    return nothing
end

function parse_findsoln_args(path::AbstractString)
    if !isfile(path)
        return nothing
    end
    lines = readlines(path)
    isempty(lines) && return nothing
    line = strip(lines[end])
    isempty(line) && return nothing

    fields = split(line, '\t')
    cmdline = strip(fields[end])
    tokens = split(cmdline)
    isempty(tokens) && return nothing

    function token_after(flag::String)
        idx = findfirst(==(flag), tokens)
        if idx === nothing || idx == length(tokens)
            return nothing
        end
        return tokens[idx + 1]
    end

    Rval = let s = token_after("-R")
        s === nothing ? nothing : tryparse(Float64, s)
    end
    Tval = let s = token_after("-T")
        s === nothing ? nothing : tryparse(Float64, s)
    end
    symms = token_after("-symms")
    if symms !== nothing && !isabspath(symms)
        symms = abspath(joinpath(dirname(path), symms))
    end

    return (
        R = Rval,
        T = Tval,
        symms = symms,
        eqb = in("-eqb", tokens),
        orb = in("-orb", tokens),
        xrel = in("-xrel", tokens),
        zrel = in("-zrel", tokens),
    )
end

function read_last_residual(convergence_path::AbstractString)
    if !isfile(convergence_path)
        return Inf
    end
    last = Inf
    first_line = true
    open(convergence_path, "r") do io
        for line in eachline(io)
            s = strip(line)
            isempty(s) && continue
            if first_line
                first_line = false
                continue
            end
            fields = split(s)
            isempty(fields) && continue
            val = tryparse(Float64, fields[1])
            val === nothing && continue
            last = val
        end
    end
    return last
end

function next_restart_dir(trial_dir::AbstractString, prefix::String)
    max_id = 0
    for name in readdir(trial_dir)
        startswith(name, prefix * "_") || continue
        tail = name[(length(prefix) + 2):end]
        id = tryparse(Int, tail)
        id === nothing && continue
        max_id = max(max_id, id)
    end
    return joinpath(trial_dir, @sprintf("%s_%04d", prefix, max_id + 1))
end

function collect_trial_dirs(root::AbstractString, restart_prefix::String; groups = nothing)
    out = String[]
    for (dir, dirs, files) in walkdir(root)
        filter!(d -> !startswith(d, restart_prefix * "_"), dirs)
        startswith(basename(dir), "trial_") || continue
        "ubest.nc" in files || continue
        if groups !== nothing
            group = extract_group(dir)
            if group === nothing || !(group in groups)
                continue
            end
        end
        push!(out, dir)
    end
    sort!(out)
    return out
end

function restart_config(trial_dir, dns_root, default_R, default_T)
    group = extract_group(trial_dir)
    parsed = parse_findsoln_args(joinpath(trial_dir, "findsoln.args"))

    R = default_R
    T = default_T
    symms = nothing
    eqb = true
    orb = false
    xrel = false
    zrel = false

    if parsed !== nothing
        parsed.R !== nothing && (R = parsed.R)
        parsed.T !== nothing && (T = parsed.T)
        parsed.symms !== nothing && (symms = parsed.symms)
        eqb = parsed.eqb
        orb = parsed.orb
        xrel = parsed.xrel
        zrel = parsed.zrel
    end

    if (symms === nothing || !isfile(symms)) && group !== nothing
        fallback = joinpath(dns_root, "symm_$(group).asc")
        if isfile(fallback)
            symms = abspath(fallback)
        end
    end

    return (R = R, T = T, symms = symms, eqb = eqb, orb = orb, xrel = xrel, zrel = zrel)
end

function run_restart(trial_dir, restart_dir, cfg; dry_run = false)
    seed_path = joinpath(trial_dir, "ubest.nc")
    isfile(seed_path) || error("Missing restart seed: $seed_path")
    mkpath(restart_dir)

    kwargs = Pair{Symbol, Any}[]
    push!(kwargs, :R => cfg.R)
    push!(kwargs, :T => cfg.T)
    push!(kwargs, :od => restart_dir)
    cfg.symms !== nothing && push!(kwargs, :symms => cfg.symms)
    cfg.eqb && push!(kwargs, :eqb => true)
    cfg.orb && push!(kwargs, :orb => true)
    cfg.xrel && push!(kwargs, :xrel => true)
    cfg.zrel && push!(kwargs, :zrel => true)

    if dry_run
        println("[dry-run] seed=$(seed_path)")
        println("          out=$(restart_dir)")
        println("          flags=$(join(string.(kwargs), ", "))")
        return Inf
    end

    findsoln(seed_path; workdir = restart_dir, kwargs...)
    return read_last_residual(joinpath(restart_dir, "convergence.asc"))
end

function main()
    args = parse_args(ARGS)

    base_dir = @__DIR__
    dns_root = abspath(get(args, "root", joinpath(base_dir, "eqb_alpha_gamma_grid", "minre_continuation", "dns_minre")))
    residual_tol = parse(Float64, get(args, "res-tol", "1e-8"))
    restart_prefix = get(args, "restart-prefix", "restart")
    max_restarts = parse(Int, get(args, "max", "0"))
    dry_run = parse_bool(args, "dry-run"; default = false)
    rerun_all = parse_bool(args, "all"; default = false)
    default_R = parse(Float64, get(args, "R", "300.0"))
    default_T = parse(Float64, get(args, "T", "10.0"))
    groups = parse_groups_arg(args)

    if !isdir(dns_root)
        error("DNS root does not exist: $dns_root")
    end

    trials = collect_trial_dirs(dns_root, restart_prefix; groups = groups)
    println("[scan] root=$dns_root")
    println("[scan] found $(length(trials)) trial directories with ubest.nc")
    println("[scan] residual tolerance = $(residual_tol)")

    selected = String[]
    skipped_converged = 0
    for trial_dir in trials
        residual = read_last_residual(joinpath(trial_dir, "convergence.asc"))
        converged = isfinite(residual) && residual <= residual_tol
        if converged && !rerun_all
            skipped_converged += 1
            continue
        end
        push!(selected, trial_dir)
    end

    if max_restarts > 0 && length(selected) > max_restarts
        selected = selected[1:max_restarts]
    end

    println("[scan] skipped converged = $(skipped_converged)")
    println("[scan] selected for restart = $(length(selected))")
    dry_run && println("[mode] dry-run enabled (no findsoln executed)")

    n_success = 0
    n_failed = 0
    n_skipped = 0

    for trial_dir in selected
        prev_residual = read_last_residual(joinpath(trial_dir, "convergence.asc"))
        cfg = restart_config(trial_dir, dns_root, default_R, default_T)

        if cfg.symms === nothing || !isfile(cfg.symms)
            println("[skip] $(trial_dir)")
            println("       missing symm file (use --root or --groups to target folders with symm_*.asc)")
            n_skipped += 1
            continue
        end

        restart_dir = next_restart_dir(trial_dir, restart_prefix)
        println("\n[restart] trial=$(trial_dir)")
        println("          prev_residual=$(prev_residual)")
        println("          out=$(restart_dir)")

        new_residual = run_restart(trial_dir, restart_dir, cfg; dry_run = dry_run)
        if dry_run
            continue
        end

        converged = isfinite(new_residual) && new_residual <= residual_tol
        if converged
            n_success += 1
            println("          status=CONVERGED residual=$(new_residual)")
        else
            n_failed += 1
            println("          status=NOT_CONVERGED residual=$(new_residual)")
        end
    end

    println("\n[summary]")
    println("selected=$(length(selected)) skipped_missing_symm=$(n_skipped)")
    if !dry_run
        println("restarts_converged=$(n_success) restarts_not_converged=$(n_failed)")
    end
end

main()

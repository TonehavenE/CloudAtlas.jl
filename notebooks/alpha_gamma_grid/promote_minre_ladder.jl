import Pkg
Pkg.activate("../../.")

using CloudAtlas
using ChannelflowWrapper
using DelimitedFiles
using Printf
using Dates
using Random

const J = 1
const K = 3
const L = 5
const Re = 300.0

const LADDER_DISCRETIZATIONS = [
    (2, 3, 5),
    (2, 4, 5),
    (2, 4, 7),
    (2, 5, 7),
    (3, 5, 9),
]
const FIND_SOLN_DISCRETIZATION = (3, 5, 9)
const N_TRIALS = 200
const NOISE_AMPLITUDE = 0.01
const HOOKPARAMS = SearchParams(; ftol=1e-8, xtol=1e-10, Nnewton=25, Nhook=6, verbosity=0)

const legacy_groups = Set(["D"])
const default_groups = ["A", "B", "C", "E", "F", "G"]

function symmetry_groups()
    sx, sy, sz, tx, tz = halfbox_symmetries()
    return [
        (name="A", desc="<sxyz, txz>", H=[sx * sy * sz, tx * tz]),
        (name="B", desc="<sxy, sz>", H=[sx * sy, sz]),
        (name="C", desc="<sxytz, sz>", H=[sx * sy * tz, sz]),
        (name="D", desc="<sxy, sztx>", H=[sx * sy, sz * tx]),
        (name="E", desc="<sxyz, sztxz>", H=[sx * sy * sz, sz * tx * tz]),
        (name="F", desc="<sxy, sz, txz>", H=[sx * sy, sz, tx * tz]),
        (name="G", desc="<sxyz>", H=[sx * sy * sz]),
    ]
end

function eqb_filename(group_prefix, Lx, Lz, id)
    if isempty(group_prefix)
        return @sprintf("eqb_Lx%.4f_Lz%.4f_id%03d.asc", Lx, Lz, id)
    end
    return @sprintf("eqb_%s_Lx%.4f_Lz%.4f_id%03d.asc", group_prefix, Lx, Lz, id)
end

function parse_args(args)
    out = Dict{String,String}()
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

function parse_group_args(args::Dict{String,String}, groups)
    names = [g.name for g in groups]
    if get(args, "all", "false") == "true"
        return names
    end
    if haskey(args, "groups")
        req = [strip(s) for s in split(args["groups"], ",") if !isempty(strip(s))]
        for g in req
            g in names || error("Unknown group '$g'. Available: $(join(names, ", "))")
        end
        return req
    end
    return default_groups
end

function load_eqb_vector(path)
    X = readdlm(path; comments=true, comment_char='#')
    if ndims(X) == 1
        return vec(X)
    end
    return vec(X[:, 1])
end

function write_symm_file(path::AbstractString, lines::Vector{String})
    open(path, "w") do io
        println(io, "% $(length(lines))")
        for line in lines
            println(io, line)
        end
    end
end

function symm_lines(group::String)
    sxyz = "1 -1 -1 -1 0.0 0.0"
    sxy = "1 -1 -1 1 0.0 0.0"
    sz = "1 1 1 -1 0.0 0.0"
    txz = "1 1 1 1 0.5 0.5"
    sxytz = "1 -1 -1 1 0.0 0.5"
    sztx = "1 1 1 -1 0.5 0.0"
    sztxz = "1 1 1 -1 0.5 0.5"

    if group == "A"
        return [sxyz, txz]
    elseif group == "B"
        return [sxy, sz]
    elseif group == "C"
        return [sxytz, sz]
    elseif group == "D"
        return [sxy, sztx]
    elseif group == "E"
        return [sxyz, sztxz]
    elseif group == "F"
        return [sxy, sz, txz]
    elseif group == "G"
        return [sxyz]
    else
        error("Unknown group: $group")
    end
end

function parse_eqb_filename(fname)
    m = match(r"eqb_(?:[A-Za-z]+_)?Lx([0-9.]+)_Lz([0-9.]+)_id([0-9]+)\.asc", fname)
    if m === nothing
        return nothing
    end
    return (
        Lx=parse(Float64, m.captures[1]),
        Lz=parse(Float64, m.captures[2]),
        id=parse(Int, m.captures[3]),
    )
end

function round_key(value::Real; ndigits::Int=4)
    return round(Float64(value); digits=ndigits)
end

function load_min_re_map(search_dirs, group_name)
    out = Dict{Tuple{Float64,Float64,Int},Float64}()
    for dir in search_dirs
        min_re_path = joinpath(dir, "bifurcations", "min_re_$(group_name).csv")
        isfile(min_re_path) || continue

        X = try
            readdlm(min_re_path, ',', Float64; skipstart=1)
        catch err
            msg = sprint(showerror, err)
            if err isa ArgumentError && occursin("number of rows in dims must be > 0", msg)
                continue
            end
            rethrow()
        end

        isempty(X) && continue
        if ndims(X) == 1
            X = reshape(X, 1, length(X))
        end
        size(X, 2) < 4 && continue

        for i in 1:size(X, 1)
            key = (round_key(X[i, 1]), round_key(X[i, 2]), Int(round(X[i, 3])))
            min_Re = X[i, 4]
            out[key] = min(get(out, key, Inf), min_Re)
        end
    end
    return out
end

function promote_eqb(
    group_name, H, eqb_path, Lx, Lz, id, out_root, reference_path, trials, noise_amp
)
    alpha = 2pi / Lx
    gamma = 2pi / Lz
    model_from = ODEModel(alpha, gamma, J, K, L, H)

    x = load_eqb_vector(eqb_path)
    if length(x) != size(model_from.ijkl, 1)
        error(
            "EQB vector length $(length(x)) does not match model size $(size(model_from.ijkl, 1)) for JKL=($J,$K,$L)",
        )
    end

    symm_path = joinpath(out_root, "symm_$(group_name).asc")
    if !isfile(symm_path)
        write_symm_file(symm_path, symm_lines(group_name))
    end

    stamp = Dates.format(now(), "yyyy-mm-dd_HHMMSS")
    sol_root = joinpath(
        out_root,
        "$(group_name)_Lx$(round(Lx, digits=4))_Lz$(round(Lz, digits=4))_id$(lpad(id, 3, '0'))_$(stamp)",
    )
    mkpath(sol_root)

    ref_converted = joinpath(
        out_root, @sprintf("reference_field_%.10f_%.10f.nc", alpha, gamma)
    )
    if !isfile(ref_converted)
        changegrid(reference_path, ref_converted; al=alpha, ga=gamma)
    end

    base_dir = joinpath(sol_root, @sprintf("J%dK%dL%d", J, K, L))
    mkpath(base_dir)
    save(x, joinpath(base_dir, "x_base.asc"))

    prev_model = model_from
    prev_x = x
    last_success_dir = base_dir
    last_success_jkl = (J, K, L)
    reached_top_rung = false

    rng = MersenneTwister(0xD00D + hash((group_name, Lx, Lz, id)))

    for (Jt, Kt, Lt) in LADDER_DISCRETIZATIONS
        model_to = ODEModel(alpha, gamma, Jt, Kt, Lt, H)
        x_proj = changebasis(prev_x, prev_model.ijkl, model_to.ijkl)
        target_dir = joinpath(sol_root, @sprintf("J%dK%dL%d", Jt, Kt, Lt))
        mkpath(target_dir)
        save(x_proj, joinpath(target_dir, "x_proj.asc"))

        println("[run] group=$(group_name) Lx=$(Lx) Lz=$(Lz) id=$(id) -> JKL=($Jt,$Kt,$Lt)")

        f = x -> model_to.f(x, Re)
        Df = x -> model_to.Df(x, Re)
        converged = false
        for trial in 1:trials
            if trial == 1 || noise_amp == 0.0
                x_guess = x_proj
            else
                noise = (rand(rng, length(x_proj)) .- 0.5) .* (2 * noise_amp)
                x_guess = x_proj .+ noise
            end

            x_star, solved = hookstepsolve(f, Df, x_guess, HOOKPARAMS)
            if solved
                save(x_star, joinpath(target_dir, @sprintf("x_star_trial_%04d.asc", trial)))

                if (Jt, Kt, Lt) == FIND_SOLN_DISCRETIZATION
                    trial_dir = joinpath(target_dir, @sprintf("trial_%04d", trial))
                    mkpath(trial_dir)
                    guess_path = joinpath(trial_dir, "u_guess.nc")
                    coeff2field(
                        x_star, model_to.ijkl, ref_converted, guess_path; workdir=trial_dir
                    )
                    findsoln(
                        guess_path;
                        workdir=trial_dir,
                        R=Re,
                        eqb=true,
                        symms=abspath(symm_path),
                        od=trial_dir,
                        T=10.0,
                    )
                    reached_top_rung = true
                end

                prev_model = model_to
                prev_x = x_star
                last_success_dir = target_dir
                last_success_jkl = (Jt, Kt, Lt)
                converged = true
                break
            end
        end
        if !converged
            println(
                "[warn] no hookstep convergence after $(trials) trials for JKL=($Jt,$Kt,$Lt); stopping ladder",
            )
            break
        end
    end

    if !reached_top_rung
        Jr, Kr, Lr = last_success_jkl
        println(
            "[fallback] top rung $(FIND_SOLN_DISCRETIZATION) not reached; running findsoln from last successful rung JKL=($Jr,$Kr,$Lr)",
        )
        trial_dir = joinpath(last_success_dir, "trial_last_success")
        mkpath(trial_dir)
        guess_path = joinpath(trial_dir, "u_guess.nc")
        coeff2field(prev_x, prev_model.ijkl, ref_converted, guess_path; workdir=trial_dir)
        findsoln(
            guess_path;
            workdir=trial_dir,
            R=Re,
            eqb=true,
            symms=abspath(symm_path),
            od=trial_dir,
            T=10.0,
        )
    end
end

function run_group(group, root_dir, out_root, reference_path, args, trials, noise_amp)
    group_name = group.name
    group_prefix = group_name in legacy_groups ? "" : group_name
    group_dir = joinpath(root_dir, group_name)
    source_group_dir = joinpath(dirname(root_dir), group_name)
    search_dirs = filter(isdir, [group_dir, source_group_dir])
    if isempty(search_dirs)
        println("[skip] missing group dirs: $group_dir and $source_group_dir")
        return nothing
    end

    Lx_filter = haskey(args, "Lx") ? parse(Float64, args["Lx"]) : nothing
    Lz_filter = haskey(args, "Lz") ? parse(Float64, args["Lz"]) : nothing
    max_count = parse(Int, get(args, "max", "0"))
    min_re_map = load_min_re_map(search_dirs, group_name)

    eqb_entries = NamedTuple[]
    seen = Set{String}()
    for dir in search_dirs
        for fname in readdir(dir)
            startswith(fname, "eqb_") || continue
            endswith(fname, ".asc") || continue
            info = parse_eqb_filename(fname)
            info === nothing && continue
            if !isempty(group_prefix) && !startswith(fname, "eqb_$(group_prefix)_")
                continue
            end
            if Lx_filter !== nothing && !isapprox(info.Lx, Lx_filter; atol=5e-4, rtol=0.0)
                continue
            end
            if Lz_filter !== nothing && !isapprox(info.Lz, Lz_filter; atol=5e-4, rtol=0.0)
                continue
            end
            if fname in seen
                continue
            end
            push!(seen, fname)
            key = (round_key(info.Lx), round_key(info.Lz), info.id)
            min_Re = get(min_re_map, key, Inf)
            push!(eqb_entries, (path=joinpath(dir, fname), info=info, min_Re=min_Re))
        end
    end
    sort!(eqb_entries; by=e -> (e.min_Re, e.path))

    if isempty(eqb_entries)
        println("[skip] no eqb files found for group $(group_name)")
        return nothing
    end

    if max_count > 0
        eqb_entries = eqb_entries[1:min(max_count, length(eqb_entries))]
    end

    for entry in eqb_entries
        eqb_path = entry.path
        info = entry.info
        if isfinite(entry.min_Re)
            println(
                @sprintf(
                    "[pick] group=%s Lx=%.4f Lz=%.4f id=%03d min_Re=%.6f",
                    group_name,
                    info.Lx,
                    info.Lz,
                    info.id,
                    entry.min_Re,
                ),
            )
        else
            println(
                @sprintf(
                    "[pick] group=%s Lx=%.4f Lz=%.4f id=%03d min_Re=missing",
                    group_name,
                    info.Lx,
                    info.Lz,
                    info.id,
                ),
            )
        end
        promote_eqb(
            group_name,
            group.H,
            eqb_path,
            info.Lx,
            info.Lz,
            info.id,
            out_root,
            reference_path,
            trials,
            noise_amp,
        )
    end
end

function main()
    args = parse_args(ARGS)
    base_dir = @__DIR__
    root_dir = get(
        args, "root", joinpath(base_dir, "eqb_alpha_gamma_grid", "minre_continuation")
    )
    out_root = get(args, "out", joinpath(root_dir, "dns_minre"))
    reference_path = get(
        args,
        "reference",
        joinpath(base_dir, "..", "tw_discovery", "TW1-2pi1piRe200-40x49x40.nc"),
    )

    trials = parse(Int, get(args, "trials", string(N_TRIALS)))
    noise_amp = parse(Float64, get(args, "noise", string(NOISE_AMPLITUDE)))

    mkpath(out_root)

    groups = symmetry_groups()
    requested = parse_group_args(args, groups)
    names = Set(requested)
    for g in groups
        if g.name in names
            println("\n=============================")
            println("Promoting group $(g.name) $(g.desc)")
            println("Input dir: $(joinpath(root_dir, g.name))")
            println("Output dir: $(out_root)")
            println("=============================")
            run_group(g, root_dir, out_root, reference_path, args, trials, noise_amp)
        end
    end
end

main()

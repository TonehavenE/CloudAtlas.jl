import Pkg
Pkg.activate("../../.")

using CloudAtlas
using ChannelflowWrapper
using DelimitedFiles
using Printf
using Dates

const J = 1
const K = 3
const L = 5
const Re = 300.0

const legacy_groups = Set(["D"])
const DELTA_LX = 0.25
const DELTA_LZ = 0.25

function symmetry_groups()
    sx, sy, sz, tx, tz = halfbox_symmetries()
    return [
        (name = "A", H = [sx * sy * sz, tx * tz]),
        (name = "B", H = [sx * sy, sz]),
        (name = "C", H = [sx * sy * tz, sz]),
        (name = "D", H = [sx * sy, sz * tx]),
        (name = "E", H = [sx * sy * sz, sz * tx * tz]),
        (name = "F", H = [sx * sy, sz, tx * tz]),
        (name = "G", H = [sx * sy * sz]),
    ]
end

function eqb_filename(group_prefix, Lx, Lz, id)
    if isempty(group_prefix)
        return @sprintf("eqb_Lx%.4f_Lz%.4f_id%03d.asc", Lx, Lz, id)
    end
    return @sprintf("eqb_%s_Lx%.4f_Lz%.4f_id%03d.asc", group_prefix, Lx, Lz, id)
end

function parse_args(args)
    out = Dict{String, String}()
    i = 1
    while i <= length(args)
        if startswith(args[i], "--")
            key = args[i][3:end]
            if i == length(args)
                error("Missing value for --$key")
            end
            out[key] = args[i + 1]
            i += 2
        else
            i += 1
        end
    end
    return out
end

function read_min_re(min_re_path)
    X = readdlm(min_re_path, ',', Float64; skipstart = 1)
    if isempty(X)
        return nothing
    end
    if ndims(X) == 1
        X = reshape(X, 1, length(X))
    end
    # columns: Lx, Lz, id, min_Re
    min_idx = argmin(X[:, 4])
    return (Lx = X[min_idx, 1], Lz = X[min_idx, 2], id = Int(round(X[min_idx, 3])), min_Re = X[min_idx, 4])
end

function round_key(value::Real; ndigits::Int = 4)
    return round(Float64(value); digits = ndigits)
end

function load_eqb_vector(path)
    X = readdlm(path, comments = true, comment_char = '#')
    if ndims(X) == 1
        return vec(X)
    end
    return vec(X[:, 1])
end

function load_completed_grid(path)
    if !isfile(path)
        return Set{Tuple{Float64, Float64}}()
    end
    X = readdlm(path, ',', Float64; skipstart = 1)
    if isempty(X)
        return Set{Tuple{Float64, Float64}}()
    end
    if ndims(X) == 1
        X = reshape(X, 1, length(X))
    end
    done = Set{Tuple{Float64, Float64}}()
    for i in 1:size(X, 1)
        push!(done, (round_key(X[i, 1]), round_key(X[i, 2])))
    end
    return done
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
    # NOTE: sxytz and sztxz are inferred from sxy/sz plus tz/txz shifts.
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

function run_group(group, group_dir, out_root, reference_path)
    min_re_path = joinpath(group_dir, "bifurcations", "min_re_$(group).csv")
    if !isfile(min_re_path)
        println("[skip] missing min Re file: $min_re_path")
        return
    end
    completed_path = joinpath(group_dir, "completed_grid_$(group).csv")
    completed = load_completed_grid(completed_path)

    min_row = read_min_re(min_re_path)
    min_row === nothing && return

    Lx0 = round_key(min_row.Lx)
    Lz0 = round_key(min_row.Lz)
    id = min_row.id

    symm_path = joinpath(out_root, "symm_$(group).asc")
    write_symm_file(symm_path, symm_lines(group))

    H = first(filter(g -> g.name == group, symmetry_groups())).H

    stamp = Dates.format(now(), "yyyy-mm-dd_HHMMSS")
    offsets = [-DELTA_LX, 0.0, DELTA_LX]
    for dLx in offsets
        for dLz in [-DELTA_LZ, 0.0, DELTA_LZ]
            Lx = round_key(Lx0 + dLx)
            Lz = round_key(Lz0 + dLz)
            if !isempty(completed) && !((Lx, Lz) in completed)
                println("[skip] not in completed grid: Lx=$(Lx) Lz=$(Lz)")
                continue
            end

            group_prefix = group in legacy_groups ? "" : group
            eqb_path = joinpath(group_dir, eqb_filename(group_prefix, Lx, Lz, id))
            if !isfile(eqb_path)
                println("[skip] missing eqb file: $eqb_path")
                continue
            end

            alpha = 2pi / Lx
            gamma = 2pi / Lz
            model = ODEModel(alpha, gamma, J, K, L, H)

            sol_dir = joinpath(out_root, "$(group)_Lx$(round(Lx, digits=4))_Lz$(round(Lz, digits=4))_id$(lpad(id,3,'0'))_$(stamp)")
            mkpath(sol_dir)

            ref_converted = joinpath(out_root, @sprintf("reference_field_%.10f_%.10f.nc", alpha, gamma))
            if !isfile(ref_converted)
                changegrid(reference_path, ref_converted; al = alpha, ga = gamma)
            end

            x = load_eqb_vector(eqb_path)
            guess_path = joinpath(sol_dir, "u_guess.nc")
            coeff2field(x, model.ijkl, ref_converted, guess_path; workdir = sol_dir)

            println("[run] group=$group Lx=$(Lx) Lz=$(Lz) id=$(id)")
            findsoln(guess_path;
                workdir = sol_dir,
                R = Re,
                eqb = true,
                symms = abspath(symm_path),
                od = sol_dir,
                T = 10.0,
            )
        end
    end
end

function main()
    args = parse_args(ARGS)
    base_dir = @__DIR__
    group_root = get(args, "root", joinpath(base_dir, "eqb_alpha_gamma_grid"))
    out_root = get(args, "out", joinpath(group_root, "dns_minre"))
    reference_path = get(args, "reference", joinpath(base_dir, "..", "tw_discovery", "TW1-2pi1piRe200-40x49x40.nc"))

    mkpath(out_root)

    for g in symmetry_groups()
        group_dir = joinpath(group_root, g.name)
        if !isdir(group_dir)
            println("[skip] missing group dir: $group_dir")
            continue
        end
        run_group(g.name, group_dir, out_root, reference_path)
    end
end

main()

using CloudAtlas
using DelimitedFiles
using Printf

const J = 1
const K = 3
const L = 5

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

function load_eqb_vector(path)
    X = readdlm(path, comments = true, comment_char = '#')
    if ndims(X) == 1
        return vec(X)
    end
    return vec(X[:, 1])
end

function main()
    args = parse_args(ARGS)
    haskey(args, "group") || error("--group required")
    haskey(args, "Lx") || error("--Lx required")
    haskey(args, "Lz") || error("--Lz required")
    haskey(args, "dir") || error("--dir required")

    group = args["group"]
    Lx = parse(Float64, args["Lx"])
    Lz = parse(Float64, args["Lz"])
    dir = args["dir"]

    groups = symmetry_groups()
    g = findfirst(x -> x.name == group, groups)
    g === nothing && error("Unknown group: $group")
    H = groups[g].H

    alpha = 2pi / Lx
    gamma = 2pi / Lz
    model = ODEModel(alpha, gamma, J, K, L, H)

    pat = r"^eqb_(?:[A-G]_)?Lx([0-9\.]+)_Lz([0-9\.]+)_id(\d+)\.asc$"
    rows = Vector{Tuple{Int, Float64}}()
    for f in readdir(dir)
        m = match(pat, f)
        m === nothing && continue
        Lx_f = parse(Float64, m.captures[1])
        Lz_f = parse(Float64, m.captures[2])
        isapprox(Lx_f, Lx; atol = 1e-6, rtol = 0.0) || continue
        isapprox(Lz_f, Lz; atol = 1e-6, rtol = 0.0) || continue
        id = parse(Int, m.captures[3])
        x = load_eqb_vector(joinpath(dir, f))
        sh = shear(x, model)
        push!(rows, (id, sh))
    end

    println("id,shear")
    for (id, sh) in sort(rows; by = x -> x[1])
        @printf("%d,%.10f\n", id, sh)
    end
end

main()

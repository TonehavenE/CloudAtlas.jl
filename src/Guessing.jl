using Random

"""
    SolutionFingerprint

Lightweight signature for deduplicating solutions.
"""
struct SolutionFingerprint
    cx::Float64
    cz::Float64
    nm::Float64
    shear::Float64
end

"""
    fingerprint(model, ξ; include_shear=true)

Compute a SolutionFingerprint from a concatenated state vector.
"""
function fingerprint(model::ODEModel, ξ::AbstractVector; include_shear::Bool=true)
    x, cx, cz = extract_components(ξ, model)
    sh = include_shear ? shear(x, model) : NaN
    return SolutionFingerprint(Float64(cx), Float64(cz), Float64(norm(x)), Float64(sh))
end

get_fingerprint(args...; kwargs...) = fingerprint(args...; kwargs...)

"""
    is_distinct(new_fp, archive; tol, compare_shear=:auto)

Return true if new_fp is distinct from all fingerprints in archive.
"""
function is_distinct(
    new_fp::SolutionFingerprint,
    archive::Vector{SolutionFingerprint};
    tol = (cx = 1e-3, cz = 1e-3, nm = 2e-2, shear = 2e-2),
    compare_shear::Union{Bool, Symbol} = :auto
)
    for fp in archive
        if isapprox(new_fp.cx, fp.cx, atol = tol.cx) &&
           isapprox(new_fp.cz, fp.cz, atol = tol.cz) &&
           isapprox(new_fp.nm, fp.nm, atol = tol.nm)
            if compare_shear == false
                return false
            elseif compare_shear == true
                if isapprox(new_fp.shear, fp.shear, atol = tol.shear)
                    return false
                end
            else
                if isnan(new_fp.shear) || isnan(fp.shear) || isapprox(new_fp.shear, fp.shear, atol = tol.shear)
                    return false
                end
            end
        end
    end
    return true
end

"""
    random_guess(model, rng; xnorm=0.4, speed_scale=0.1)

Return a random initial guess for TW solving.
"""
function random_guess(
    model::ODEModel,
    rng::AbstractRNG = Random.default_rng();
    xnorm::Union{Real, Nothing} = 0.4,
    speed_scale::Real = 0.1
)
    m = length(model)
    x = randn(rng, m)
    T = eltype(x)
    if xnorm !== nothing
        x = xnorm / norm(x) * x
    end
    cx = model.keep_cx ? T(randn(rng) * speed_scale) : T(0)
    cz = model.keep_cz ? T(randn(rng) * speed_scale) : T(0)
    return state_to_xi(model, ODEState(x, cx, cz))
end

get_random_guess(args...; kwargs...) = random_guess(args...; kwargs...)

"""
    shear_target_guess(model, rng; target=1.2, tol=0.05, max_tries=100)

Randomly sample guesses until shear(x) is within tol of target.
"""
function shear_target_guess(
    model::ODEModel,
    rng::AbstractRNG = Random.default_rng();
    xnorm::Union{Real, Nothing} = 0.4,
    target::Real = 1.2,
    tol::Real = 0.05,
    max_tries::Int = 100,
    speed_scale::Real = 0.1
)
    for _ in 1:max_tries
        ξ = random_guess(model, rng; xnorm = xnorm, speed_scale = speed_scale)
        x, _, _ = extract_components(ξ, model)
        if abs(shear(x, model) - target) <= tol
            return ξ
        end
    end
    return random_guess(model, rng; xnorm = xnorm, speed_scale = speed_scale)
end

"""
    shear_dominant_indices(model; top_k=nothing, frac=0.9, min_abs=0.0)

Return indices of basis modes that dominate wall-shear contribution.
"""
function shear_dominant_indices(
    model::ODEModel;
    top_k::Union{Int, Nothing} = nothing,
    frac::Union{Real, Nothing} = 0.9,
    min_abs::Real = 0.0
)
    s = model.Ψshear
    idx = [i for i in eachindex(s) if abs(s[i]) > min_abs]
    isempty(idx) && return Int[]
    idx = sort(idx, by = i -> abs(s[i]), rev = true)

    if top_k !== nothing
        return idx[1:min(top_k, length(idx))]
    elseif frac !== nothing
        total = sum(abs.(s[idx]))
        total == 0 && return Int[]
        cum = 0.0
        selected = Int[]
        for i in idx
            push!(selected, i)
            cum += abs(s[i])
            if cum >= frac * total
                break
            end
        end
        return selected
    else
        return idx
    end
end

"""
    shear_band_guess(model, rng; shear_min=1.0, shear_max=3.0, rest_scale=0.1)

Generate a guess by sampling dominant + remaining modes until shear is in [shear_min, shear_max],
without rescaling to a fixed target. `shear_target` is ignored (kept for API compatibility).
"""
function shear_band_guess(
    model::ODEModel,
    rng::AbstractRNG = Random.default_rng();
    shear_min::Real = 1.0,
    shear_max::Real = 3.0,
    dom_idx::Union{Symbol, AbstractVector{Int}} = :auto,
    top_k::Union{Int, Nothing} = nothing,
    frac::Union{Real, Nothing} = 0.9,
    min_abs::Real = 0.0,
    dominant_scale::Real = 1.0,
    rest_scale::Real = 0.1,
    max_tries::Int = 200,
    shear_target::Union{Real, Nothing} = nothing,
    speed_scale::Real = 0.1
)
    m = length(model)
    s = model.Ψshear
    T = eltype(s)
    dom_idx = dom_idx === :auto ? shear_dominant_indices(model; top_k = top_k, frac = frac, min_abs = min_abs) : collect(dom_idx)
    rest_idx = setdiff(1:m, dom_idx)

    x = zeros(eltype(s), m)
    success = false

    for _ in 1:max_tries
        x .= 0
        if !isempty(dom_idx)
            x[dom_idx] = (rand(rng, length(dom_idx)) .* 2 .- 1) .* dominant_scale
        end
        if !isempty(rest_idx)
            x[rest_idx] = (rand(rng, length(rest_idx)) .* 2 .- 1) .* rest_scale
        end

        shear_val = 1 + dot(s, x)
        if shear_min <= shear_val <= shear_max
            success = true
            break
        end
    end

    # If we couldn't hit the band (e.g., no dominant modes), keep the last sample.

    cx = model.keep_cx ? T(randn(rng) * speed_scale) : T(0)
    cz = model.keep_cz ? T(randn(rng) * speed_scale) : T(0)
    return state_to_xi(model, ODEState(x, cx, cz))
end

"""
    build_guess(model, rng; strategy=:random)

Dispatch helper for guess strategies.
"""
function build_guess(
    model::ODEModel,
    rng::AbstractRNG = Random.default_rng();
    strategy::Symbol = :random,
    xnorm::Union{Real, Nothing} = 0.4,
    target::Real = 1.2,
    tol::Real = 0.05,
    shear_min::Real = 1.0,
    shear_max::Real = 3.0,
    speed_scale::Real = 0.1,
    kwargs...
)
    if strategy == :random
        return random_guess(model, rng; xnorm = xnorm, speed_scale = speed_scale)
    elseif strategy == :shear_target
        return shear_target_guess(model, rng; xnorm = xnorm, target = target, tol = tol, speed_scale = speed_scale)
    elseif strategy == :shear_band || strategy == :shear_modes
        return shear_band_guess(model, rng; shear_min = shear_min, shear_max = shear_max, speed_scale = speed_scale, kwargs...)
    else
        error("Unknown strategy: $(strategy)")
    end
end

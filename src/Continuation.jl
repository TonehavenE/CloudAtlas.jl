"""
Geometry continuation helpers for equilibria.
"""

"""
    GeometryContinuationPoint

One point on a natural continuation curve in `alpha` or `gamma`.

Fields include the solved coefficient vector `x`, absolute and relative
equilibrium residuals, wall power input, and dissipation. If dissipation was not
requested, `dissipation` is `NaN`.
"""
Base.@kwdef struct GeometryContinuationPoint{T<:Real}
    parameter::Symbol
    value::T
    alpha::T
    gamma::T
    Re::T
    x::Vector{T}
    residual::T
    relative_residual::T
    power_input::T
    dissipation::T
    converged::Bool
end

"""
    model_resolution(model)

Return the `(J, K, L)` truncation implied by an `ODEModel`'s `ijkl` table.
"""
function model_resolution(model::ODEModel)
    ijkl = model.ijkl
    isempty(ijkl) && return (J = 0, K = 0, L = 0)
    return (
        J = maximum(abs, ijkl[:, 2]),
        K = maximum(abs, ijkl[:, 3]),
        L = maximum(ijkl[:, 4]),
    )
end

function _basis_is_normalized(model::ODEModel; rtol = 1e-8, atol = 1e-10)
    return all(isapprox(model.B[i, i], one(eltype(model.B)); rtol = rtol, atol = atol) for i in axes(model.B, 1))
end

"""
    remake_model(model; alpha=model.α, gamma=model.γ, normalize=nothing, tw=is_tw(model))

Rebuild an `ODEModel` with the same symmetry subgroup and inferred `(J,K,L)`
truncation, but with new Fourier wavenumbers. `normalize=nothing` attempts to
preserve whether the current model's basis is normalized.
"""
function remake_model(
    model::ODEModel;
    alpha::Real = model.α,
    gamma::Real = model.γ,
    normalize = nothing,
    tw::Bool = is_tw(model),
)
    J, K, L = model_resolution(model)
    normalized = normalize === nothing ? _basis_is_normalized(model) : normalize
    T = promote_type(typeof(model.α), typeof(float(alpha)), typeof(float(gamma)))
    return ODEModel(T(alpha), T(gamma), J, K, L, model.H; normalize = normalized, tw = tw)
end

_geometry_parameter(parameter::Symbol) =
    parameter in (:alpha, Symbol("α")) ? :alpha :
    parameter in (:gamma, Symbol("γ")) ? :gamma :
    error("parameter must be :alpha or :gamma")

function _equilibrium_residual(model::ODEModel, x::AbstractVector, Re::Real)
    return model.f(x, Re)
end

function _solve_equilibrium(model::ODEModel, xguess::AbstractVector, Re::Real, params::SearchParams)
    f = x -> model.f(x, Re)
    Df = x -> model.Df(x, Re)
    return hookstepsolve(f, Df, collect(xguess), params)
end

function _predicted_guess(successes, fallback::AbstractVector, value::Real, predictor::Symbol)
    if predictor == :constant || length(successes) < 2
        return copy(fallback)
    elseif predictor != :secant
        error("predictor must be :secant or :constant")
    end

    v0, x0 = successes[end - 1]
    v1, x1 = successes[end]
    denom = v1 - v0
    iszero(denom) && return copy(x1)
    return x1 .+ ((value - v1) / denom) .* (x1 .- x0)
end

function _summarize_geometry_point(
    parameter::Symbol,
    value::Real,
    model::ODEModel,
    x::Vector,
    Re::Real,
    converged::Bool,
    compute_dissipation::Bool,
)
    residual_vec = _equilibrium_residual(model, x, Re)
    residual = norm(residual_vec)
    relative_residual = residual / max(norm(x), eps(eltype(x)))
    D = if compute_dissipation
        Dmat = build_dissipation_matrix(model)
        dissipation_rate(Dmat, x)
    else
        NaN
    end

    T = eltype(x)
    return GeometryContinuationPoint{T}(;
        parameter = parameter,
        value = T(value),
        alpha = T(model.α),
        gamma = T(model.γ),
        Re = T(Re),
        x = copy(x),
        residual = T(residual),
        relative_residual = T(relative_residual),
        power_input = T(power_input(model, x)),
        dissipation = T(D),
        converged = converged,
    )
end

"""
    continue_equilibrium_geometry(model, x0, Re, parameter, values; kwargs...)

Natural continuation of an equilibrium in the geometry parameter `:alpha` or
`:gamma` at fixed `Re`. For each requested value, CloudAtlas rebuilds the same
truncated/symmetric ODE model, solves `model.f(x, Re) = 0` with hookstep Newton,
and records power input and, by default, dissipation.

Keyword arguments:

- `params=SearchParams()` controls the hookstep solver.
- `predictor=:secant` uses a secant predictor after two successful points.
  Use `:constant` to seed each solve from the previous successful solution.
- `compute_dissipation=true` builds the curl inner-product matrix for each
  geometry and records `D = 1 + ||curl(u)||^2 / Volume`.
- `normalize=nothing` attempts to preserve basis normalization from `model`.
- `stop_on_failure=true` stops at the first failed Newton solve.

This is fast, practical natural continuation. It will not pass folds in the
continued geometry parameter; use smaller steps or pseudo-arclength continuation
for that case.
"""
function continue_equilibrium_geometry(
    model::ODEModel,
    x0::AbstractVector,
    Re::Real,
    parameter::Symbol,
    values;
    params::SearchParams = SearchParams(),
    predictor::Symbol = :secant,
    compute_dissipation::Bool = true,
    normalize = nothing,
    stop_on_failure::Bool = true,
)
    p = _geometry_parameter(parameter)
    points = GeometryContinuationPoint[]
    successes = Tuple{Float64, Vector{eltype(x0)}}[]
    fallback = collect(x0)

    for value in values
        alpha = p == :alpha ? value : model.α
        gamma = p == :gamma ? value : model.γ
        local_model = remake_model(model; alpha = alpha, gamma = gamma, normalize = normalize, tw = false)

        xguess = _predicted_guess(successes, fallback, value, predictor)
        xsol, converged = _solve_equilibrium(local_model, xguess, Re, params)
        point = _summarize_geometry_point(p, value, local_model, xsol, Re, converged, compute_dissipation)
        push!(points, point)

        if converged
            fallback = copy(xsol)
            push!(successes, (Float64(value), copy(xsol)))
        elseif stop_on_failure
            break
        end
    end

    return points
end

"""
    continue_gamma(model, x0, Re, gammas; kwargs...)

Convenience wrapper for `continue_equilibrium_geometry(model, x0, Re, :gamma, gammas; kwargs...)`.
"""
continue_gamma(model::ODEModel, x0::AbstractVector, Re::Real, gammas; kwargs...) =
    continue_equilibrium_geometry(model, x0, Re, :gamma, gammas; kwargs...)

"""
    continue_alpha(model, x0, Re, alphas; kwargs...)

Convenience wrapper for `continue_equilibrium_geometry(model, x0, Re, :alpha, alphas; kwargs...)`.
"""
continue_alpha(model::ODEModel, x0::AbstractVector, Re::Real, alphas; kwargs...) =
    continue_equilibrium_geometry(model, x0, Re, :alpha, alphas; kwargs...)

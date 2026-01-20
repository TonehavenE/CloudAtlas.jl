"""
Traveling wave helpers built on top of ODEModel.
"""

const TWModel = ODEModel

"""
    TWModel(α, γ, J, K, L, H; normalize=false, tol_phase=1e-12)

Convenience constructor for an ODEModel with traveling-wave fields enabled.
"""
function TWModel(α, γ, J::Int, K::Int, L::Int, H::Vector{Symmetry}; normalize=false, tol_phase=1e-12)
    ODEModel(α, γ, J, K, L, H; normalize=normalize, tw=true, tol_phase=tol_phase)
end

"""
    TWState(x, cx, cz)

Container for traveling-wave solutions.
"""
struct TWState{T<:Real}
    x::Vector{T}
    cx::T
    cz::T
end

TWState(x::Vector{T}, cx::Real, cz::Real) where {T<:Real} = TWState{T}(x, T(cx), T(cz))

"""
    extract_components(state::TWState)

Return (x, cx, cz).
"""
function extract_components(state::TWState)
    return state.x, state.cx, state.cz
end

"""
    extract_components(xi, model)

Backward-compatible helper to extract (x, cx, cz) from a concatenated vector.
Prefer TWState for new code.
"""
function extract_components(xi::AbstractVector, model::ODEModel)
    m = length(model.Ψ)
    if length(xi) == m + 2
        return xi[1:m], xi[m+1], xi[m+2]
    elseif length(xi) == m + 1
        if model.keep_cx && !model.keep_cz
            return xi[1:m], xi[m+1], 0.0
        elseif !model.keep_cx && model.keep_cz
            return xi[1:m], 0.0, xi[m+1]
        else
            error("ambiguous xi length for phase constraints")
        end
    elseif length(xi) == m
        return xi, 0.0, 0.0
    else
        error("xi has invalid length")
    end
end

"""
    residual(model, x, cx, cz, R)

Compute the residual of the traveling wave equation without phase constraints.
Returns just the m-dimensional residual vector.
"""
function residual(model::ODEModel, x::AbstractVector, cx::Real, cz::Real, R::Real)
    model.Cx === nothing && error("model has no TW operators (Cx)")
    model.Cz === nothing && error("model has no TW operators (Cz)")
    return (cx*model.Cx + cz*model.Cz)*x - model.A1*x - (1/R)*model.A2*x - model.N(x)
end

"""
    jacobian(model, x, cx, cz, R)

Compute the Jacobian of the residual with respect to x only.
"""
function jacobian(model::ODEModel, x::AbstractVector, cx::Real, cz::Real, R::Real)
    model.Cx === nothing && error("model has no TW operators (Cx)")
    model.Cz === nothing && error("model has no TW operators (Cz)")
    return cx*model.Cx + cz*model.Cz - model.A1 - (1/R)*model.A2 - derivative(model.N, x)
end

"""
    save_sigma(model, cx, cz, T, filename)

Save symmetry file in Channelflow format.
"""
function save_sigma(::ODEModel, cx::Real, cz::Real, T::Real, filename::String)
    open(filename, "w") do file
        az = cz ≈ 0 ? 0 : round(-cz * T, sigdigits=6)
        ax = cx ≈ 0 ? 0 : round(-cx * T, sigdigits=6)
        write(file, "% 1\n1 1 1 1 $(ax) $(az)")
    end
end

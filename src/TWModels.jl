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
    ODEState(x, cx, cz)

Container for ODE states. For equilibria, cx and cz can be `nothing`.
"""
struct ODEState{T<:Real}
    x::Vector{T}
    cx::Union{T, Nothing}
    cz::Union{T, Nothing}
end

ODEState(x::Vector{T}) where {T<:Real} = ODEState{T}(x, nothing, nothing)
ODEState(x::Vector{T}, cx::Real, cz::Real) where {T<:Real} = ODEState{T}(x, T(cx), T(cz))

"""
    extract_components(state::ODEState)

Return (x, cx, cz) with missing speeds as 0.0.
"""
function extract_components(state::ODEState)
    cx = state.cx === nothing ? 0.0 : state.cx
    cz = state.cz === nothing ? 0.0 : state.cz
    return state.x, cx, cz
end

"""
    extract_components(xi, model)

Backward-compatible helper to extract (x, cx, cz) from a concatenated vector.
Prefer ODEState for new code.
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
    state_to_xi(model, state)

Pack an ODEState into a concatenated vector compatible with TW solvers.
"""
function state_to_xi(model::ODEModel, state::ODEState)
    x = state.x
    if model.keep_cx && model.keep_cz
        return [x; state.cx === nothing ? 0.0 : state.cx; state.cz === nothing ? 0.0 : state.cz]
    elseif model.keep_cx && !model.keep_cz
        return [x; state.cx === nothing ? 0.0 : state.cx]
    elseif !model.keep_cx && model.keep_cz
        return [x; state.cz === nothing ? 0.0 : state.cz]
    else
        return x
    end
end

"""
    xi_to_state(model, xi)

Convert a concatenated vector into an ODEState using model phase flags.
"""
function xi_to_state(model::ODEModel, xi::AbstractVector)
    x, cx, cz = extract_components(xi, model)
    if model.keep_cx || model.keep_cz
        return ODEState(x, cx, cz)
    else
        return ODEState(x)
    end
end

"""
    save_state(state, filename; header=true)

Save an ODEState to a text file. First line is a comment with cx/cz if present.
"""
function save_state(state::ODEState, filename::String; header::Bool=true)
    open(filename, "w") do io
        if header
            cx = state.cx === nothing ? "none" : string(state.cx)
            cz = state.cz === nothing ? "none" : string(state.cz)
            println(io, "% cx=$(cx) cz=$(cz)")
        end
        for v in state.x
            println(io, v)
        end
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
function save_sigma(::Type{ODEModel}, cx::Real, cz::Real, T::Real, filename::String)
    open(filename, "w") do file
        az = cz ≈ 0 ? 0 : round(-cz * T, sigdigits=6)
        ax = cx ≈ 0 ? 0 : round(-cx * T, sigdigits=6)
        write(file, "% 1\n1 1 1 1 $(ax) $(az)")
    end
end

function save_sigma(model::ODEModel, cx::Real, cz::Real, T::Real, filename::String)
    # If a phase is not being constrained, treat its drift speed as zero for DNS promotion.
    cx_eff = model.keep_cx ? cx : zero(cx)
    cz_eff = model.keep_cz ? cz : zero(cz)
    save_sigma(ODEModel, cx_eff, cz_eff, T, filename)
end

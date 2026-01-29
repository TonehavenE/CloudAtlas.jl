"""
Minimal dissipation utilities.

Requires these functions/types to be defined in the host code:
  - BasisFunction
  - innerproduct(::BasisComponent, ::BasisComponent)
  - xderivative, yderivative, zderivative
"""

"""
    dissipation_term(f, g)

Compute D_ij = < curl(f), curl(g) > for two basis functions.
Expands the curl components to avoid constructing summed BasisComponents.
"""
function dissipation_term(f::BasisFunction{T}, g::BasisFunction{T}) where {T<:Real}
    # f.u[1] = u, f.u[2] = v, f.u[3] = w
    f_dy_u = yderivative(f.u[1])
    f_dz_u = zderivative(f.u[1])
    f_dx_v = xderivative(f.u[2])
    f_dz_v = zderivative(f.u[2])
    f_dx_w = xderivative(f.u[3])
    f_dy_w = yderivative(f.u[3])

    g_dy_u = yderivative(g.u[1])
    g_dz_u = zderivative(g.u[1])
    g_dx_v = xderivative(g.u[2])
    g_dz_v = zderivative(g.u[2])
    g_dx_w = xderivative(g.u[3])
    g_dy_w = yderivative(g.u[3])

    # X-component: <dy w - dz v, dy w - dz v>
    val_x = innerproduct(f_dy_w, g_dy_w) -
            innerproduct(f_dy_w, g_dz_v) -
            innerproduct(f_dz_v, g_dy_w) +
            innerproduct(f_dz_v, g_dz_v)

    # Y-component: <dz u - dx w, dz u - dx w>
    val_y = innerproduct(f_dz_u, g_dz_u) -
            innerproduct(f_dz_u, g_dx_w) -
            innerproduct(f_dx_w, g_dz_u) +
            innerproduct(f_dx_w, g_dx_w)

    # Z-component: <dx v - dy u, dx v - dy u>
    val_z = innerproduct(f_dx_v, g_dx_v) -
            innerproduct(f_dx_v, g_dy_u) -
            innerproduct(f_dy_u, g_dx_v) +
            innerproduct(f_dy_u, g_dy_u)

    return val_x + val_y + val_z
end

"""
    build_dissipation_matrix(Ψ)

Construct D where D_ij = < curl(Ψi), curl(Ψj) > for a basis set Ψ.
"""
function build_dissipation_matrix(Ψ::AbstractVector{BasisFunction{T}}) where {T<:Real}
    m = length(Ψ)
    D = zeros(T, m, m)
    for j in 1:m
        for i in 1:j
            val = dissipation_term(Ψ[i], Ψ[j])
            D[i, j] = val
            D[j, i] = val
        end
    end
    return D
end

"""
    dissipation_rate(D, x)

Compute total dissipation: 1 + x' * D * x.
"""
dissipation_rate(D::AbstractMatrix, x::AbstractVector) = 1.0 + dot(x, D * x)

import Base.length

"""
ODEModel
"""
struct ODEModel{T<:Real, TB, TF, TDF}
    α::T                         # streamwise wavenumber α = 2pi/Lx
    γ::T                         # spanwise wavenumber γ = 2pi/Lz
    H::Vector{Symmetry}          # symmetry subgroup
    ijkl::Matrix{Int}            # set of allowed i,j,k,l indices 
    Ψ::Vector{BasisFunction{T}}  # basis set built from allowed i,j,k,l
    Ψshear::Vector{T}            # value of dΨudy at walls, used to calculate shear rate
    B::AbstractMatrix{T}         # inner product matrix 
    A1::AbstractMatrix{T}        # linear term arising from base flow
    A2::AbstractMatrix{T}        # linear term arising from Laplacian
    N::SparseBilinear{T}         # nonlinear term from u dot grad u
    Bfact::TB                    # LU factorization of inner product matrix
    f::TF                        # RHS function for ODE dx/dt = f(x,R) 
    Df::TDF                      # Df(x,R), the derivative of f, [Df]_ij = df_i/dx_j

    # Optional TW fields
    Cx::Union{AbstractMatrix{T}, Nothing}  # x-translation operator (cx*∂/∂x)
    Cz::Union{AbstractMatrix{T}, Nothing}  # z-translation operator (cz*∂/∂z)
    keep_cx::Bool                # whether to enforce x-phase constraint
    keep_cz::Bool                # whether to enforce z-phase constraint
    f_tw::Union{Function, Nothing}         # RHS dx/dt = f(x, cx, cz, R)
    Df_tw::Union{Function, Nothing}        # Jacobian of f_tw w.r.t. x
    g::Union{Function, Nothing}            # TW residual factory g(xref)(xi, R) = 0
    Dg::Union{Function, Nothing}           # TW bordered Jacobian factory
end

function ODEModel(α::T, γ::T, J::Int, K::Int, L::Int, H::Vector{Symmetry}; 
                  normalize=false, tw=false, tol_phase=1e-12) where T<:Real
    ijkl = basisIndices(J,K,L,H)    # Compute set of allowed ijkl for H-symmetric Ψijkl 
    m = size(ijkl,1)                # State space dimension
    println("J,K,L,m == $J,$K,$L,$m")
    println("(2J+1)(2K+1)(2L+1) + 1 == $((2J+1)*(2K+1)*(2L+1) + 1)")
        
    Ψ = basisSet(α, γ, ijkl, normalize=normalize)  # Construct basis set 
    Ψshear = zeros(T, m)
    for i=1:m
        if Ψ[i].u[1].ejx.waveindex == 0 && Ψ[i].u[1].ekz.waveindex == 0
            dΨudy = yderivative(Ψ[i].u[1])
            Ψshear[i] = Ψ[i].u[1].coeff*(dΨudy.p(1.0)  + dΨudy.p(-1.0))/2
        end
    end

    println("Making matrices B,A1,A2,S3...")
    y = Polynomial{T, :y}([zero(T), one(T)])
    B   = [innerproduct(Ψ[i], Ψ[j]) for i in 1:m, j in 1:m]
    A1a = [-innerproduct(Ψ[i], y*xderivative(Ψ[j])) for i in 1:m, j in 1:m]
    A1b = [-innerproduct(Ψ[i], vex(Ψ[j])) for i in 1:m, j in 1:m]
    A2  = [innerproduct(Ψ[i], laplacian(Ψ[j])) for i in 1:m, j in 1:m]
    A1 = A1a + A1b

    println("Making quadratic operator N...")
    Ndense = zeros(T, m, m, m)
    for j in 1:m
        print("$j ")
        for k in 1:m
            Ψj_dotgrad_Ψk = dotgrad(Ψ[j], Ψ[k])
            for i in 1:m
                val = -innerproduct(Ψ[i], Ψj_dotgrad_Ψk)
                Ndense[i,j,k] = abs(val) > 1e-15 ? val : zero(T) 
            end
        end
    end
    println()
    N  = SparseBilinear(Ndense)

    # precompute LU decomp of Bf to speed repeated calls to Bf x = b solves
    Bfact = lu(B)
    
    # construct Re-parameterized f and Df functions 
    f(x,R)  = Bfact\(A1*x + (1/R)*(A2*x) + N(x))
    Df(x,R) = Bfact\(A1 + (1/R)*(A2) + derivative(N,x))

    Cx = nothing
    Cz = nothing
    keep_cx = false
    keep_cz = false
    f_tw = nothing
    Df_tw = nothing
    g = nothing
    Dg = nothing

    if tw
        println("Making matrices Cx,Cz...")
        Cx = [innerproduct(Ψ[i], xderivative(Ψ[j])) for i in 1:m, j in 1:m]
        Cz = [innerproduct(Ψ[i], zderivative(Ψ[j])) for i in 1:m, j in 1:m]

        keep_cx = !all(iszero, Cx)
        keep_cz = !all(iszero, Cz)

        println("Phase constraints: keep_cx = $keep_cx, keep_cz = $keep_cz")

        # ODE form for traveling wave: dx/dt = f_tw(x, cx, cz, R)
        function f_tw_inner(x::AbstractVector, cx::Real, cz::Real, R::Real)
            return Bfact \ (A1*x + (1/R)*(A2*x) + cx*Cx*x + cz*Cz*x + N(x))
        end

        # Jacobian of f_tw with respect to x only
        function Df_tw_inner(x::AbstractVector, cx::Real, cz::Real, R::Real)
            return Bfact \ (A1 + (1/R)*A2 + cx*Cx + cz*Cz + derivative(N, x))
        end

        f_tw = f_tw_inner
        Df_tw = Df_tw_inner
    end

    build_model(g_fn, Dg_fn) = ODEModel(α, γ, H, ijkl, Ψ, Ψshear, B, A1, A2, N, Bfact, f, Df,
                                        Cx, Cz, keep_cx, keep_cz, f_tw, Df_tw, g_fn, Dg_fn)

    model = build_model(g, Dg)
    if tw
        g_factory = xref -> g_tw_with_ref(model, xref)
        Dg_factory = xref -> Dg_tw_with_ref(model, xref)
        model = build_model(g_factory, Dg_factory)
    end

    return model
end

length(model::ODEModel{T}) where T<:Real = length(model.Ψ)
shear(x::Vector{T}, model::ODEModel{T}) where T<:Real = one(T) + dot(x, model.Ψshear)

is_tw(model::ODEModel) = model.Cx !== nothing && model.Cz !== nothing

"""
    g_tw_with_ref(model, xref)

Return a closure (xi, R) -> g(xi, R) that enforces ChannelFlow-style phase constraints
using the fixed reference state xref.
"""
function g_tw_with_ref(model::ODEModel, xref::AbstractVector)
    model.Cx === nothing && error("model has no TW operators (Cx)")
    model.Cz === nothing && error("model has no TW operators (Cz)")

    m = length(model.Ψ)
    length(xref) == m || error("xref must have length $m")

    ex = model.keep_cx ? (model.Cx * xref) : nothing
    ez = model.keep_cz ? (model.Cz * xref) : nothing

    return function (xi::AbstractVector, R::Real)
        x, cx, cz = extract_components(xi, model)

        residual = (cx*model.Cx + cz*model.Cz)*x - model.A1*x - (1/R)*model.A2*x - model.N(x)

        dim = m + (model.keep_cx ? 1 : 0) + (model.keep_cz ? 1 : 0)
        g_full = zeros(eltype(residual), dim)
        g_full[1:m] = residual

        idx = m
        # Phase conditions are enforced using a fixed reference state xref equal to the initial guess for the Newton solve (ChannelFlow-style). Constraints are dot(Cx*xref, x-xref)=0 and dot(Cz*xref, x-xref)=0.
        if model.keep_cx
            idx += 1
            g_full[idx] = dot(ex, x - xref)
        end
        if model.keep_cz
            idx += 1
            g_full[idx] = dot(ez, x - xref)
        end

        return g_full
    end
end

"""
    Dg_tw_with_ref(model, xref)

Return a closure (xi, R) -> Dg(xi, R) that enforces ChannelFlow-style phase constraints
using the fixed reference state xref.
"""
function Dg_tw_with_ref(model::ODEModel, xref::AbstractVector)
    model.Cx === nothing && error("model has no TW operators (Cx)")
    model.Cz === nothing && error("model has no TW operators (Cz)")

    m = length(model.Ψ)
    length(xref) == m || error("xref must have length $m")

    ex = model.keep_cx ? (model.Cx * xref) : nothing
    ez = model.keep_cz ? (model.Cz * xref) : nothing

    return function (xi::AbstractVector, R::Real)
        x, cx, cz = extract_components(xi, model)

        Jx = cx*model.Cx + cz*model.Cz - model.A1 - (1/R)*model.A2 - derivative(model.N, x)

        m_rows = m + (model.keep_cx ? 1 : 0) + (model.keep_cz ? 1 : 0)
        m_cols = length(xi)

        Dg_matrix = zeros(eltype(Jx), m_rows, m_cols)
        Dg_matrix[1:m, 1:m] = Jx

        if m_cols == m + 2
            Dg_matrix[1:m, m+1] = model.Cx * x
            Dg_matrix[1:m, m+2] = model.Cz * x
        elseif m_cols == m + 1
            if model.keep_cx && !model.keep_cz
                Dg_matrix[1:m, m+1] = model.Cx * x
            elseif !model.keep_cx && model.keep_cz
                Dg_matrix[1:m, m+1] = model.Cz * x
            else
                error("ambiguous xi length for phase constraints")
            end
        elseif m_cols != m
            error("xi has invalid length")
        end

        row = m
        if model.keep_cx
            row += 1
            Dg_matrix[row, 1:m] = ex'
        end
        if model.keep_cz
            row += 1
            Dg_matrix[row, 1:m] = ez'
        end

        return Dg_matrix
    end
end

"""
    build_dissipation_matrix(model)
Constructs the matrix D where D_ij = < curl(Ψi), curl(Ψj) >
"""
function build_dissipation_matrix(model)
    m = length(model)
    D_mat = zeros(m, m)
    println("Building dissipation matrix...")
    Threads.@threads for j in 1:m
        for i in 1:m
            # Symmetric matrix
            if i <= j
                val = dissipation_term(model.Ψ[i], model.Ψ[j])
                D_mat[i, j] = val
                D_mat[j, i] = val
            end
        end
    end
    return D_mat
end

"""
    power_input(model, x)
Calculates Power Input I = 1 + < d(u_pert)/dy >_wall.
This is equivalent to the wall shear rate.
"""
power_input(model, x) = shear(x, model)

"""
    dissipation_rate(D_matrix, x)
Calculates Total Dissipation D = 1 + || curl(u) ||^2 / Volume.
Assumes D_matrix is the precomputed inner product of curls.
"""
dissipation_rate(D_matrix::AbstractMatrix, x::Vector) = 1.0 + dot(x, D_matrix * x)

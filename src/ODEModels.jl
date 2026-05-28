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
    apply_symmetry(σ::Symmetry, model::ODEModel, x::AbstractVector)

Apply symmetry σ to coefficient vector x. All supported symmetries act diagonally:
each basis element maps to ±itself, so the result is a sign-flipping of some coefficients.
"""
function apply_symmetry(σ::Symmetry, model::ODEModel, x::AbstractVector)
    return [symmetry_sign(model.ijkl[n, :], σ) * x[n] for n in eachindex(x)]
end

"""
    apply_continuous_shift(x, model, ax, az)

Apply a continuous phase shift τ_{ax,az} to coefficient vector x, translating
the flow field by (ax*Lx, az*Lz) in the streamwise and spanwise directions.

Under an x-translation by ax, mode pairs (n, n') with ijkl indices j_n = -j_{n'} ≠ 0
rotate with angle φ = 2π|j|ax:
- i=3 (Ψw ∝ Ejx[j]): R(+φ)  i.e. y_n =  cos(φ)*x_n - sin(φ)*x_{n'}
- i=4,5,6 (Ψu ∝ Ejx[-j]): R(-φ) i.e. y_n =  cos(φ)*x_n + sin(φ)*x_{n'}

Under a z-translation by az, mode pairs with k_n = -k_{n'} ≠ 0 rotate with ψ = 2π|k|az:
- i=1 (Ψu ∝ Ekz[k]): R(+ψ)
- i=2,5,6 (Ψu or Ψw ∝ Ekz[k] with cos-leading partner): R(-ψ)
"""
function apply_continuous_shift(x::AbstractVector, model::ODEModel, ax::Real, az::Real)
    ijkl = model.ijkl
    m = size(ijkl, 1)

    # Build a lookup: (i,j,k,l) => row index
    idx_dict = Dict{NTuple{4,Int}, Int}()
    for n in 1:m
        idx_dict[(ijkl[n,1], ijkl[n,2], ijkl[n,3], ijkl[n,4])] = n
    end

    y = copy(x)

    # --- X-shift: rotate pairs sharing (i, |j|, k, l) ---
    processed = fill(false, m)
    for n in 1:m
        processed[n] && continue
        i, j, k, l = ijkl[n,1], ijkl[n,2], ijkl[n,3], ijkl[n,4]
        j == 0 && continue
        key = (i, -j, k, l)
        haskey(idx_dict, key) || continue
        np = idx_dict[key]

        φ = 2π * abs(j) * ax
        cφ, sφ = cos(φ), sin(φ)
        # n_pos = index of the j>0 mode (uses Ejx[j]=sin in basisSet for i=3,
        #         or Ejx[-j]=cos for i=4,5,6)
        n_pos = j > 0 ? n : np
        n_neg = j > 0 ? np : n

        if i == 3  # R(+φ): sin-leading (Ejx[j] for j>0)
            y[n_pos] =  cφ * x[n_pos] - sφ * x[n_neg]
            y[n_neg] =  sφ * x[n_pos] + cφ * x[n_neg]
        else       # i=4,5,6 — R(-φ): cos-leading (Ejx[-j] for j>0)
            y[n_pos] =  cφ * x[n_pos] + sφ * x[n_neg]
            y[n_neg] = -sφ * x[n_pos] + cφ * x[n_neg]
        end
        processed[n]  = true
        processed[np] = true
    end

    # --- Z-shift: rotate pairs sharing (i, j, |k|, l), applied to y ---
    x_mid = y
    z = copy(x_mid)
    fill!(processed, false)
    for n in 1:m
        processed[n] && continue
        i, j, k, l = ijkl[n,1], ijkl[n,2], ijkl[n,3], ijkl[n,4]
        k == 0 && continue
        key = (i, j, -k, l)
        haskey(idx_dict, key) || continue
        np = idx_dict[key]

        ψ = 2π * abs(k) * az
        cψ, sψ = cos(ψ), sin(ψ)
        n_pos = k > 0 ? n : np
        n_neg = k > 0 ? np : n

        if i == 1  # R(+ψ): sin-leading (Ekz[k] for k>0)
            z[n_pos] =  cψ * x_mid[n_pos] - sψ * x_mid[n_neg]
            z[n_neg] =  sψ * x_mid[n_pos] + cψ * x_mid[n_neg]
        else       # i=2,5,6 — R(-ψ): cos-leading
            z[n_pos] =  cψ * x_mid[n_pos] + sψ * x_mid[n_neg]
            z[n_neg] = -sψ * x_mid[n_pos] + cψ * x_mid[n_neg]
        end
        processed[n]  = true
        processed[np] = true
    end

    return z
end

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
    gql_model(model::ODEModel, Λ::Int)

Return a new ODEModel identical to `model` but with the N tensor replaced by its
GQL(Λ) approximation via `gql_mask_N`: N_ijk is zeroed when both input modes j and k
have streamwise wavenumber |j| > Λ.

- Λ=0: standard quasilinear (QL) approximation — L = j=0 (rolls+streaks), S = j≠0 (waves)
- Λ=J: full nonlinear system (identity operation)
"""
function gql_model(model::ODEModel{T}, Λ::Int) where T
    N_gql = gql_mask_N(model.N, model.ijkl, Λ)

    f_gql(x, R)  = model.Bfact \ (model.A1*x + (1/R)*(model.A2*x) + N_gql(x))
    Df_gql(x, R) = model.Bfact \ (model.A1 + (1/R)*model.A2 + derivative(N_gql, x))

    return ODEModel(model.α, model.γ, model.H, model.ijkl, model.Ψ, model.Ψshear,
                    model.B, model.A1, model.A2, N_gql, model.Bfact,
                    f_gql, Df_gql,
                    model.Cx, model.Cz, model.keep_cx, model.keep_cz,
                    model.f_tw, model.Df_tw, model.g, model.Dg)
end

"""
    epsilon_ql(model::ODEModel, x::AbstractVector)

Compute the QL residual fraction for solution x:

    ε_QL = ||N_SS(x)|| / ||N(x)||

where N_SS contains only the S-S interactions (entries where BOTH input modes have
streamwise wavenumber |j| > 0, i.e. both are waves rather than rolls/streaks).

Returns a value in [0,1]: 0 means fully QL-organized (pure mean×wave force balance),
1 means the nonlinear term is entirely wave×wave interactions.

This quantifies "how Waleffe-like" a solution is: Waleffe's SSP corresponds to ε_QL ≈ 0.
"""
function epsilon_ql(model::ODEModel{T}, x::AbstractVector{T}) where T
    N_full_val = model.N(x)
    N_ql = gql_mask_N(model.N, model.ijkl, 0)
    N_ss_val = N_full_val - N_ql(x)
    norm_full = norm(N_full_val)
    norm_full < eps(T) && return zero(T)
    return norm(N_ss_val) / norm_full
end


"""
    g_rpo_with_ref(model, R, σ, xref)

Return `(g, Dg)` for the relative periodic orbit (RPO) shooting problem.

The unknown vector xi = [x0; (ax); (az); T], where ax and az are the continuous
streamwise/spanwise phase shifts accumulated over one period (present only when
`model.keep_cx` / `model.keep_cz` are true). The residual is:

    g[1:m]   = τ_{ax,az}(σ(φ_R(x0, T))) - x0   # orbit closing with drift
    g[m+1]   = ⟨f(x0), x0 - xref⟩               # Lust time-phase condition
    g[m+2]   = ⟨Cx·xref, x0 - xref⟩             # x-phase condition (if keep_cx)
    g[m+3]   = ⟨Cz·xref, x0 - xref⟩             # z-phase condition (if keep_cz)

τ_{ax,az} is the continuous phase shift applied via `apply_continuous_shift`.
`xref` is fixed to the initial guess and not updated during the Newton solve.

Requires `integrate_flow` from `CloudAtlasDiffEqExt` (load DifferentialEquations.jl first).
"""
function g_rpo_with_ref(model::ODEModel, R::Real, σ::Symmetry, xref::AbstractVector)
    m = length(model)
    length(xref) == m || error("xref must have length $m")

    ex = model.keep_cx ? (model.Cx * xref) : nothing
    ez = model.keep_cz ? (model.Cz * xref) : nothing
    n_phase = (model.keep_cx ? 1 : 0) + (model.keep_cz ? 1 : 0)
    n_rows  = m + 1 + n_phase

    function g(xi::AbstractVector)
        x0  = xi[1:m]
        idx = m
        ax  = model.keep_cx ? (idx += 1; xi[idx]) : zero(eltype(xi))
        az  = model.keep_cz ? (idx += 1; xi[idx]) : zero(eltype(xi))
        T   = xi[idx + 1]

        sol   = integrate_flow(model, x0, (0.0, T); R=R, saveat=T)
        x_end = sol.u[end]
        x_ret = apply_continuous_shift(apply_symmetry(σ, model, x_end), model, ax, az)

        g_full      = zeros(eltype(xi), n_rows)
        g_full[1:m] = x_ret .- x0

        row = m
        g_full[row += 1] = dot(model.f(x0, R), x0 .- xref)
        if model.keep_cx
            g_full[row += 1] = dot(ex, x0 .- xref)
        end
        if model.keep_cz
            g_full[row += 1] = dot(ez, x0 .- xref)
        end
        return g_full
    end

    Dg(xi) = Df_finitediff(g, xi)
    return g, Dg
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

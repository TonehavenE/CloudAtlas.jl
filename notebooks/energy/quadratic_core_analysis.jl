using CloudAtlas
using LinearAlgebra
using DelimitedFiles
using Printf

function build_restricted_model(model, S)
    m = length(model)
    n = length(S)
    
    # Sub-matrices
    B_r = model.B[S, S]
    A1_r = model.A1[S, S]
    A2_r = model.A2[S, S]
    
    # Quadratic tensor N restricted to S
    ijk = model.N.ijk
    val = model.N.val
    
    S_set = Set(S)
    map_S = Dict(v => i for (i, v) in enumerate(S))
    
    I_new, J_new, K_new, V_new = Int64[], Int64[], Int64[], Float64[]
    for r in 1:length(val)
        i, j, k = ijk[r,1], ijk[r,2], ijk[r,3]
        if i in S_set && j in S_set && k in S_set
            push!(I_new, map_S[i])
            push!(J_new, map_S[j])
            push!(K_new, map_S[k])
            push!(V_new, val[r])
        end
    end
    N_r = SparseBilinear(I_new, J_new, K_new, V_new, n)
    Bfact_r = lu(B_r)
    
    f(x, R) = Bfact_r \ (A1_r*x + (1/R)*A2_r*x + N_r(x))
    Df(x, R) = Bfact_r \ (A1_r + (1/R)*A2_r + derivative(N_r, x))
    
    return (; f, Df, n, S)
end

function find_all_equilibria(r_model, R; n_attempts=100)
    solutions = []
    for _ in 1:n_attempts
        x0 = randn(r_model.n) * 0.5
        x_star, converged = hookstepsolve(x -> r_model.f(x, R), x -> r_model.Df(x, R), x0, SearchParams(verbosity=0))
        if converged && norm(x_star) > 1e-6
            # Check for uniqueness
            is_new = true
            for s in solutions
                if norm(s - x_star) < 1e-4
                    is_new = false
                    break
                end
            end
            if is_new
                push!(solutions, x_star)
            end
        end
    end
    return solutions
end

function run_3mode_analysis()
    α, γ = 1.0, 2.0
    sx, sy, sz, tx, tz = halfbox_symmetries()
    H = [sx*sy*sz, sz*tx*tz]
    model = ODEModel(α, γ, 1, 2, 3, H, normalize=false)
    
    # Core modes - expanding to 12
    core_modes_ijkl = [
        [1, 0, 0, 1], [1, 0, 0, 3], [1, 0, 1, 0], [1, 0, 1, 2], [2, 0, 1, 1], [2, 0, 1, 3],
        [1, 0, -2, 1], [1, 0, -2, 3], [2, 0, -2, 2], [3, -1, 0, 1], [3, -1, 0, 3], [5, -1, -1, 0]
    ]
    S = []
    for ijkl in core_modes_ijkl
        for i in 1:length(model)
            if collect(model.ijkl[i, :]) == ijkl
                push!(S, i)
            end
        end
    end
    
    println("Restricting model to modes: $S")
    r_model = build_restricted_model(model, S)
    
    Re = 200.0
    eqs = find_all_equilibria(r_model, Re)
    
    println("\nFound $(length(eqs)) non-trivial equilibria in 3-mode model (Re=$Re):")
    for (i, eq) in enumerate(eqs)
        println("  Sol $i: $eq  (norm=$(norm(eq)))")
    end
    
    # Compare to full equilibrium
    guess_file = "notebooks/data/xeq1projection-Re200-1-2-3-27d.asc"
    x_star_full = vec(readdlm(guess_file, comments=true, comment_char='%'))
    x_proj = x_star_full[S]
    
    println("\nProjection of full 27-mode equilibrium onto 3-mode core:")
    println("  x_proj: $x_proj")
    println("  Residual in 3-mode model: $(norm(r_model.f(x_proj, Re)))")
    
    println("\nSearching from projected full equilibrium:")
    x_star_proj, converged_proj = hookstepsolve(x -> r_model.f(x, Re), x -> r_model.Df(x, Re), x_proj, SearchParams(verbosity=0))
    if converged_proj
        println("  Converged to: $x_star_proj")
        println("  Norm: $(norm(x_star_proj))")
        println("  Distance to proj: $(norm(x_star_proj - x_proj))")
    else
        println("  Failed to converge from projected state.")
    end
    
    # Check if any 3-mode solution is close to x_proj
    for (i, eq) in enumerate(eqs)
        dist = norm(eq - x_proj)
        println("  Dist between Sol $i and Projected: $dist")
    end
end

run_3mode_analysis()

using Test
using Polynomials
using LinearAlgebra
using Random

using CloudAtlas

sx = Symmetry(-1, 1, 1)
sy = Symmetry(1, -1, 1)
sz = Symmetry(1, 1, -1)
tx = Symmetry(1, 1, 1, 1//2, 0//1)
tz = Symmetry(1, 1, 1, 0//1, 1//2)

@testset "CloudAtlas Tests" begin
    @time @testset "Polynomials" begin
        @test polyparity(Polynomial([1])) == 1
    end

    @time @testset "Fourier Modes" begin
        f = FourierMode()
        @test compatible(f, f)
    end

    @time @testset "Basis Components" begin
        f = FourierMode(1, 1, 1)
        b = BasisComponent(1, f, f, Polynomial([1, 0, -1], :y), 0)
        @test compatible(b, b)
    end

    @time @testset "Hookstep search on simple 2d function " begin
        f(x) = [x[1]^2 + x[2]^2 - 1; x[1] - x[2]]
        Df(x) = [2x[1] 2x[2] ; 1 -1]
        
        xguess = [2; 0]
        xsolution = [1/sqrt(2); 1/sqrt(2)]
        xsolve, success = hookstepsolve(f, Df, xguess)

        @test norm(xsolve-xsolution) < 1e-10
    end

    @time @testset "Shift symmetry detection" begin
        H_no_shift = [sx*sy*sz]
        H_shift_x = [tx]
        H_shift_z = [tz]
        H_shift_both = [tx*tz]

        @test !has_shift_symmetry(H_no_shift, :x)
        @test !has_shift_symmetry(H_no_shift, :z)
        @test has_shift_symmetry(H_shift_x, :x)
        @test has_shift_symmetry(H_shift_z, :z)
        @test has_shift_symmetry(H_shift_both, :x)
        @test has_shift_symmetry(H_shift_both, :z)

        Random.seed!(1234)
        α, γ = 1.0, 2.0
        tol = 1e-12

        model_no = ODEModel(α, γ, 1, 1, 1, H_no_shift; tw=true)
        cxx = model_no.Cx * randn(length(model_no.Ψ))
        keep_cx_rand = norm(cxx) > tol
        @test keep_cx_rand == !has_shift_symmetry(H_no_shift, :x)

        model_shift_x = ODEModel(α, γ, 0, 1, 1, H_shift_x; tw=true)
        cxx = model_shift_x.Cx * randn(length(model_shift_x.Ψ))
        keep_cx_rand = norm(cxx) > tol
        @test keep_cx_rand == !has_shift_symmetry(H_shift_x, :x)

        model_shift_z = ODEModel(α, γ, 1, 0, 1, H_shift_z; tw=true)
        czx = model_shift_z.Cz * randn(length(model_shift_z.Ψ))
        keep_cz_rand = norm(czx) > tol
        @test keep_cz_rand == !has_shift_symmetry(H_shift_z, :z)
    end

    @time @testset "Phase constraint sanity" begin
        Random.seed!(1234)
        α, γ = 1.0, 2.0
        H = [sx*sy*sz]

        model = ODEModel(α, γ, 1, 1, 1, H; tw=true)
        m = length(model.Ψ)

        xref = randn(m)
        xref ./= norm(xref)
        xs = [randn(m) for _ in 1:10]

        if model.keep_cx
            old_vals = [dot(model.Cx * x, x) for x in xs]
            @test maximum(abs.(old_vals)) < 1e-8

            new_vals = [dot(model.Cx * xref, x - xref) for x in xs]
            @test maximum(abs.(new_vals)) > 1e-10
        end

        if model.keep_cz
            old_vals = [dot(model.Cz * x, x) for x in xs]
            @test maximum(abs.(old_vals)) < 1e-8

            new_vals = [dot(model.Cz * xref, x - xref) for x in xs]
            @test maximum(abs.(new_vals)) > 1e-10
        end
    end

    @time @testset "ODEModel evaluation on known equilibrium" begin

        # set up ODE model for some tests
        α, γ = 1.0, 2.0             # Fourier wavenumbers α, γ = 2π/Lx, 2π/Lz
        H = [sx*sy*sz, sz*tx*tz]    # Generators of the symmetric subspace of the Nagata eqb
        J,K,L = 1,1,3               # Bounds on Fourier modes (J,K) and wall-normal polynomials (L)
        R = 200.0
        
        # ODE eqb version of Nagata lower branch, computed for PRL
        xeqb = [0.16764501289529937, -0.018552429231415948, 0.48640800040772025, -0.09759477649001111,
                -0.03411986464200022, -0.010665050862032609, -0.01731713276665348, 0.020113317487885345,
                -0.03572908824700301, -0.008809478655993888, -0.018431734698126298, -0.04736482532692928,
                -0.04609045287990289, -0.03157916691896989, 0.0010374375712356061, 0.01601957685174594,
                 0.07702704667134751]
        
        model = ODEModel(α, γ, J, K, L, H)  # Form ODE model via Galerkin projection

        @test norm(model.f(xeqb, R))/norm(xeqb) < 1e-10
        @test model_resolution(model) == (J = J, K = K, L = L)

        model_copy = remake_model(model; alpha = α, gamma = γ)
        @test length(model_copy) == length(model)
        @test model_copy.α == model.α
        @test model_copy.γ == model.γ

        branch = continue_gamma(
            model,
            xeqb,
            R,
            [γ];
            params = SearchParams(; ftol = 1e-8, verbosity = 0),
            compute_dissipation = false,
        )
        @test length(branch) == 1
        @test branch[1].converged
        @test branch[1].parameter == :gamma
        @test branch[1].gamma == γ
        @test branch[1].relative_residual < 1e-10
        @test isnan(branch[1].dissipation)
        
    end

    @time @testset "Hookstep Solve for equilibrium of ODEModel" begin
        α, γ = 1.0, 2.0             # Fourier wavenumbers α, γ = 2π/Lx, 2π/Lz
        H = [sx*sy*sz, sz*tx*tz]    # Generators of the symmetric subspace of the Nagata eqb
        J,K,L = 1,1,3               # Bounds on Fourier modes (J,K) and wall-normal polynomials (L)
        R = 200.0                   # Reynolds number

        model = ODEModel(α, γ, J, K, L, H)  # Form ODE model via Galerkin projection

        # Projection of Nagata eqb used as initial guess for ODE eqb. Computed for PRL
        xguess = [0.105, -0.0539, 0.388, -0.0172, -0.0133, 0.0113, -0.00706, 0.0240, -0.0344, -0.00868,
                  -0.01264, -0.0234, -0.0320, -0.0180, -0.00464, 0.0106, 0.0235]
        xeqb = [0.16764501289529937, -0.018552429231415948, 0.48640800040772025, -0.09759477649001111,
                -0.03411986464200022, -0.010665050862032609, -0.01731713276665348, 0.020113317487885345,
                -0.03572908824700301, -0.008809478655993888, -0.018431734698126298, -0.04736482532692928,
                -0.04609045287990289, -0.03157916691896989, 0.0010374375712356061, 0.01601957685174594,
                 0.07702704667134751]

        f = x -> model.f(x,R)
        Df = x -> model.Df(x,R)
        xsoln, success = hookstepsolve(f, Df, xguess)
        @test norm(xsoln - xeqb)/norm(xeqb) < 1e-08
    end

    @time @testset "Hookstep Solve for equilibrium of ODEModel, normalized" begin
        α, γ = 1.0, 2.0             # Fourier wavenumbers α, γ = 2π/Lx, 2π/Lz
        H = [sx*sy*sz, sz*tx*tz]    # Generators of the symmetric subspace of the Nagata eqb
        J,K,L = 1,1,3               # Bounds on Fourier modes (J,K) and wall-normal polynomials (L)
        R = 200.0                   # Reynolds number
        
        model = ODEModel(α, γ, J, K, L, H, normalize=true)  # Form ODE model via Galerkin projection
        params = SearchParams(; δ=0.01)
        
        # Projection of Nagata eqb used as initial guess for ODE eqb. Computed for PRL
        xguess = [0.117, -0.0402, 0.201, -0.00779, -0.0158, 0.00719, -0.00551, 0.0126, -0.0281,
                  -0.00619, -0.0102, -0.0121, -0.0144, -0.0222, -0.00386, 0.01876, 0.0229]

        xeqb = [0.18509767944776034, -0.013810193934778796, 0.2511800112873277, -0.04399074169151473,
                 -0.04069031295467911, -0.0068103678652483395, -0.013519832908378151, 0.01058687307496652,
                 -0.02917267839495075, -0.006278485885577374, -0.014925151720599003, -0.024459090632393224,
                 -0.020775222591909327, -0.038982169958350785, 0.0008634078112314248, 0.02842834644157768,
                  0.07523725576071376]

        f = x -> model.f(x,R)
        Df = x -> model.Df(x,R)
        xsoln, success = hookstepsolve(f, Df, xguess, params)
        @test norm(xsoln - xeqb)/norm(xeqb) < 1e-08
    end
end

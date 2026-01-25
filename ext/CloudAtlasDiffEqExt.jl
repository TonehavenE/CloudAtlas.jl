module CloudAtlasDiffEqExt
using CloudAtlas
using DifferentialEquations

export integrate_flow

"""
    integrate_flow(model, x0, tspan; R=400.0, saveat=0.5)

Integrates the ODE model and returns the solution object.
"""
function CloudAtlas.integrate_flow(model::ODEModel, x0, tspan; R=400.0, saveat=0.5)
    # Define the RHS for DifferentialEquations
    # dx/dt = f(x, R)
    function ode_rhs!(dx, x, p, t)
        dx .= model.f(x, p)
    end

    prob = ODEProblem(ode_rhs!, x0, tspan, R)
    return solve(prob, Tsit5(), saveat=saveat)
end


"""
    integrate_flow(model, state::ODEState, tspan; R=400.0, saveat=0.5, lab_frame=false)

Integrates the TW model and returns the solution object.
"""
function CloudAtlas.integrate_flow(model::ODEModel, state::ODEState, tspan; R=400.0, saveat=0.5, lab_frame=false)
    model.f_tw === nothing && error("model has no TW dynamics; use an EQB model instead")
    x0 = state.x
    # If lab_frame is true, force speeds to 0 to see the drift
    cx0 = lab_frame ? 0.0 : (state.cx === nothing ? 0.0 : state.cx)
    cz0 = lab_frame ? 0.0 : (state.cz === nothing ? 0.0 : state.cz)
    
    function ode_rhs!(dx, x, p, t)
        cx, cz, Re = p
        dx .= model.f_tw(x, cx, cz, Re)
    end

    prob = ODEProblem(ode_rhs!, x0, tspan, (cx0, cz0, R))
    return solve(prob, Tsit5(), saveat=saveat)
end

end

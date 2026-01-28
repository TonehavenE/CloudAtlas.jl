module CloudAtlas

using Polynomials
using StaticArrays
using OffsetArrays
using LinearAlgebra
using SparseArrays
using StringBuilders
import Base: *, -, zero, intersect
import LinearAlgebra: norm
import Polynomials: derivative
import SparseArrays: sparse

include("Symmetries.jl")

export Symmetry, symmetric, halfbox_symmetries, has_shift_symmetry

include("SparseBilinear.jl")

export SparseBilinear, sparse 

include("BasisFunctions.jl")

export FourierMode, BasisComponent, BasisFunction, compatible, isorthogonal, innerproduct, derivative, xderivative, yderivative, zderivative, *, zero, regularize, laplacian, dotgrad, fourierIndices, basisIndices, basisSet, estr, Estr, ustr, psistr, legendrePolynomials, xreflection, yreflection, zreflection, xtranslationLx2, ztranslationLz2, vex, norm, norm2, loworder, ijkl2file, save, polyparity, basis_index_dict, changebasis, curl, dissipation_term

include("ODEModels.jl")

export ODEModel, shear, length, is_tw
export build_dissipation_matrix, power_input, dissipation_rate

include("Hookstep.jl")

export hookstepsolve, hookstepsolve_tw, SearchParams

include("TWModels.jl")

export TWModel, ODEState, save_sigma, extract_components, state_to_xi, xi_to_state, save_state

# ====================================================================================
# VISUALIZATION API
# These types and function names are defined here so they can be exported.
# The implementation of the plotting functions is loaded conditionally 
# in ext/CloudAtlasVisualizationExt.jl when CairoMakie is loaded.

"""
    PlotSettings
Configuration for velocity field plots.
"""
Base.@kwdef struct PlotSettings
    num_points::Int = 30
    arrow_scale::Float64 = 0.5
    arrow_lengthscale::Float64 = 0.8
    arrow_tiplength::Float64 = 14.0   # Values in pixels 
    arrow_tipwidth::Float64 = 14.0    # Values in pixels
    arrow_shaftwidth::Float64 = 2.0   # Value in pixels
    colormap = :RdBu
    # colormap::Vector{Symbol} = [:navyblue, :aqua, :lime, :orange, :red4]
    fig_size::Tuple{Int,Int} = (900, 1200)
end

"""
    VelocityField

Callable struct that evaluates velocity components.
"""
struct VelocityField{T<:Real, M}
    Ψ::Vector{BasisFunction{T}}
    x::Vector{T} # The coefficient vector
    model::M
    add_baseflow::Bool
    # Fields for Traveling Wave shifting
    cx::T
    cz::T
    t::T
    
    function VelocityField(model::ODEModel{T}, x::Vector{T}; 
                           add_baseflow::Bool=false, cx::Real=0.0, cz::Real=0.0, t::Real=0.0) where T<:Real
        new{T, typeof(model)}(model.Ψ, x, model, add_baseflow, T(cx), T(cz), T(t))
    end
end

# Evaluate velocity component at a point
function (vf::VelocityField)(component::Symbol, x::Real, y::Real, z::Real)
    # Apply Galilean transformation (shift to moving frame)
    x_shifted = x - vf.cx * vf.t
    z_shifted = z - vf.cz * vf.t

    # Evaluate perturbation at shifted coordinates
    idx = component == :u ? 1 : (component == :v ? 2 : 3)
    
    perturbation = sum(vf.Ψ[i].u[idx](x_shifted, y, z_shifted) * vf.x[i] for i in eachindex(vf.x))
    
    if vf.add_baseflow && component == :u
        return perturbation + y
    else
        return perturbation
    end
end

# Define function stubs for the plotting commands.
# The extension will add methods to these specific functions.
function plot_xz_plane! end
function plot_xy_plane! end
function plot_yz_plane! end
function velocity_fields end
function velocity_fields_dns end
function velocity_fields_comparison end
function animate_flow end 
function plot_id_series end
function animate_tw_fluctuations end
function plot_coefficient_evolution end
function plot_stability_spectrum end

# EXPORTS
export PlotSettings, VelocityField
export plot_xz_plane!, plot_xy_plane!, plot_yz_plane!
export velocity_fields, velocity_fields_dns, velocity_fields_comparison, animate_flow, plot_id_series, animate_tw_fluctuations, plot_coefficient_evolution, plot_stability_spectrum

# ====================================================================================
# Diff Eqs API

function integrate_flow end
export integrate_flow

end # module CloudAtlas

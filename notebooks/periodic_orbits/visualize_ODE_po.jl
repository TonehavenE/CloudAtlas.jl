# Visualize the J2,K3,L7 ODE-native periodic orbit.
#
# Produces:
#   1. po_timeseries.png  — power input (I) and dissipation rate (D) vs t over
#                           two full periods
#   2. po_orbit_u_v_w.mp4 — 3D contour animation of (u, v, w) over two periods
#
# Usage (from repo root):
#   LD_LIBRARY_PATH=/run/opengl-driver/lib/ julia --project \
#       notebooks/periodic_orbits/visualize_ODE_po.jl
#
# Optional environment overrides:
#   PO_X0_PATH      — path to the refined x0 .asc file
#   PO_PERIOD       — period T (float)
#   PO_RE           — Reynolds number
#   PO_JKL          — resolution string, e.g. "2x3x7"
#   PO_ALPHA        — streamwise wavenumber (default 1.0)
#   PO_GAMMA        — spanwise  wavenumber  (default 2.0)
#   PO_NPERIODS     — number of periods to integrate (default 2)
#   PO_NFRAMES      — total animation frames (default 120)
#   PO_NTIMESERIES  — number of time points for timeseries (default 400)
#   PO_OUTDIR       — output directory (default: same directory as this script)
#   PO_ANIM         — set to "false" to skip animation (default true)
#   PO_TIMESERIES   — set to "false" to skip timeseries plot (default true)

if get(ENV, "CLOUDATLAS_SKIP_ACTIVATE", "false") != "true"
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "../.."))
end

using CloudAtlas
using DifferentialEquations
using GLMakie
using LinearAlgebra
using Printf

# ── helpers ───────────────────────────────────────────────────────────────────

parse_float_env(name, default) = parse(Float64, strip(get(ENV, name, string(default))))
parse_int_env(name, default)   = parse(Int,     strip(get(ENV, name, string(default))))

function parse_bool_env(name, default)
    raw = lowercase(strip(get(ENV, name, default ? "true" : "false")))
    return raw in ("1", "true", "t", "yes", "y")
end

function parse_jkl_env(name, default)
    raw = strip(get(ENV, name, ""))
    isempty(raw) && return default
    parts = split(lowercase(raw), "x")
    length(parts) == 3 || error("Invalid $name='$raw'. Expected JxKxL.")
    return (parse(Int, parts[1]), parse(Int, parts[2]), parse(Int, parts[3]))
end

function load_coeff_vector(path)
    isfile(path) || error("Missing coefficient file: $path")
    vals = Float64[]
    for line in readlines(path)
        s = strip(line)
        (isempty(s) || startswith(s, "#") || startswith(s, "%")) && continue
        for tok in split(s)
            v = tryparse(Float64, tok)
            v === nothing || push!(vals, v)
        end
    end
    isempty(vals) && error("No numeric coefficients in $path")
    return vals
end

# Minimal solution-like struct for animate_flow_3d; holds a frame subset.
struct SubSol
    t::Vector{Float64}
    u::Vector{Vector{Float64}}
end

# ── configuration ─────────────────────────────────────────────────────────────

const HERE = @__DIR__
const DEFAULT_BASE = joinpath(HERE, "eqb_hopf_outputs_2_3_7",
                                    "clean_po_pipeline_j2_target270_long",
                                    "ode_refinement")

x0_path  = abspath(get(ENV, "PO_X0_PATH", joinpath(DEFAULT_BASE, "x0_refined.asc")))
Re       = parse_float_env("PO_RE",     285.91486006421275)
T_orbit  = parse_float_env("PO_PERIOD", 86.7227592540848207)
alpha    = parse_float_env("PO_ALPHA",  1.0)
gamma    = parse_float_env("PO_GAMMA",  2.0)
J, K, L  = parse_jkl_env("PO_JKL",    (2, 3, 7))
nperiods = parse_int_env("PO_NPERIODS", 2)
nframes  = parse_int_env("PO_NFRAMES",  300)
nts      = parse_int_env("PO_NTIMESERIES", 400)
outdir   = abspath(get(ENV, "PO_OUTDIR", HERE))
do_anim  = parse_bool_env("PO_ANIM",        true)
do_ts    = parse_bool_env("PO_TIMESERIES",  true)

mkpath(outdir)

T_total = nperiods * T_orbit
@printf("J,K,L = %d,%d,%d    Re = %.6f    T = %.6f    integration = %.2f (%d periods)\n",
        J, K, L, Re, T_orbit, T_total, nperiods)

# ── build model ───────────────────────────────────────────────────────────────

sx, sy, sz, tx, tz = halfbox_symmetries()
H = [sx * sy * sz, sz * tx * tz]
model = ODEModel(alpha, gamma, J, K, L, H; normalize = true)
Dmat  = build_dissipation_matrix(model)

x0 = load_coeff_vector(x0_path)
length(x0) == length(model) ||
    error("x0 length $(length(x0)) ≠ model dimension $(length(model))")

@printf("x0 loaded: |x0| = %.6f    shear = %.6f\n", norm(x0), shear(x0, model))

# ── integrate ─────────────────────────────────────────────────────────────────

# Use the union of timeseries and animation sample points so we only integrate once.
n_save  = max(nts, nframes + 1)
ts_save = collect(range(0.0, T_total; length = n_save))

println("Integrating $(nperiods) full period(s) ($(n_save) save points) …")

function rhs!(du, u, p, t)
    du .= model.f(u, p[1])
end

prob = ODEProblem(rhs!, copy(x0), (0.0, T_total), [Re])
sol  = solve(prob, Vern9();
             abstol  = 1e-11,
             reltol  = 1e-11,
             saveat  = ts_save,
             dense   = false)

sol.retcode == ReturnCode.Success ||
    @warn "Integrator returned $(sol.retcode) — output may be incomplete"

closure = norm(sol.u[end] .- x0)
@printf("Integration done. %d time points.  End-to-end closure = %.3e\n",
        length(sol.t), closure)

# ── timeseries plot ───────────────────────────────────────────────────────────

if do_ts
    println("Generating timeseries plot …")

    I_vals = [power_input(model, u) for u in sol.u]
    D_vals = [dissipation_rate(Dmat, u) for u in sol.u]
    ts     = sol.t

    period_times = [k * T_orbit for k in 0:nperiods]
    tick_labels  = [@sprintf("%.1f\n(%dT)", period_times[i+1], i) for i in 0:nperiods]

    fig = Figure(size = (900, 480))
    ax  = Axis(fig[1, 1];
               xlabel     = "t",
               ylabel     = "energy rate",
               title      = @sprintf("J%d,K%d,L%d   Re = %.4f   T = %.4f",
                                     J, K, L, Re, T_orbit),
               xticks     = (period_times, tick_labels),
    )

    lines!(ax, ts, I_vals; color = :royalblue, linewidth = 2, label = "I  (power input)")
    lines!(ax, ts, D_vals; color = :crimson,   linewidth = 2, label = "D  (dissipation rate)")

    for pt in period_times[2:end-1]
        vlines!(ax, [pt]; color = :gray, linewidth = 1, linestyle = :dot)
    end

    axislegend(ax; position = :rt)

    ts_path = joinpath(outdir, "po_timeseries.png")
    Makie.save(ts_path, fig)
    println("Saved: $ts_path")
end

# ── I vs D phase portrait ─────────────────────────────────────────────────────

if do_ts
    println("Generating I vs D phase portrait …")

    lo = min(minimum(I_vals), minimum(D_vals)) * 0.98
    hi = max(maximum(I_vals), maximum(D_vals)) * 1.02

    fig2 = Figure(size = (540, 500))
    ax2  = Axis(fig2[1, 1];
                xlabel = "I  (power input)",
                ylabel = "D  (dissipation rate)",
                title  = @sprintf("J%d,K%d,L%d   Re = %.4f   T = %.4f",
                                  J, K, L, Re, T_orbit),
    )

    # diagonal I = D
    l_diag  = lines!(ax2, [lo, hi], [lo, hi]; color = :black, linewidth = 1,
                     linestyle = :dash)

    # full trajectory — both periods overlay since the orbit is closed
    l_orbit = lines!(ax2, I_vals, D_vals; color = :royalblue, linewidth = 2)

    limits!(ax2, lo, hi, lo, hi)

    Legend(fig2[1, 2], [l_diag, l_orbit], ["I = D", "orbit"])

    id_path = joinpath(outdir, "po_I_vs_D.png")
    Makie.save(id_path, fig2)
    println("Saved: $id_path")
end

# ── animation ─────────────────────────────────────────────────────────────────

if do_anim
    println("Generating 3D contour animation …")

    # Subsample to nframes evenly-spaced frames
    frame_idx = unique(round.(Int, range(1, length(sol.t); length = nframes)))
    frame_idx = clamp.(frame_idx, 1, length(sol.t))
    sub = SubSol(sol.t[frame_idx], sol.u[frame_idx])

    anim_path = joinpath(outdir, "po_orbit_u_v_w.mp4")
    CloudAtlas.animate_flow_3d(
        model, sub, anim_path;
        baseflow  = true,
        Nx        = 32, Nz = 40, Ny = 32,
        levels    = 8,
        colormap  = :balance,
        azimuth   = 1.2π,
        ymax      = 1,
        framerate = 20,
        label     = @sprintf("J%d,K%d,L%d  Re=%.2f  T=%.3f", J, K, L, Re, T_orbit),
    )
    println("Saved: $anim_path")
end

println("All outputs written to $outdir")

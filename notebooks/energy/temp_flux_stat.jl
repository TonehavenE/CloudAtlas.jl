using CloudAtlas
using DelimitedFiles
using Statistics
sx, sy, sz, tx, tz = halfbox_symmetries()
H = [sx*sy*sz, sz*tx*tz]
model = ODEModel(1.0, 2.0, 1, 2, 3, H, normalize=false)
x = vec(readdlm("notebooks/data/xeq1projection-Re200-1-2-3-27d.asc", comments=true, comment_char='%'))
fluxes = [abs(x[model.N.ijk[r,1]] * model.N.val[r] * x[model.N.ijk[r,2]] * x[model.N.ijk[r,3]]) for r in 1:length(model.N.val)]
println("Max Flux: ", maximum(fluxes))
println("Mean Flux (non-zero): ", mean(fluxes[fluxes .> 0]))
# count fluxes > threshold
for thr in [1e-4, 1e-5, 1e-6, 1e-7]
    println("Count > $thr: ", count(fluxes .> thr))
end

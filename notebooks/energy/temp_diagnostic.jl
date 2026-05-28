using CloudAtlas
using LinearAlgebra
using DelimitedFiles
using Printf
include("quadratic_core_analysis.jl")

sx, sy, sz, tx, tz = halfbox_symmetries()
H = [sx*sy*sz, sz*tx*tz]
model = ODEModel(1.0, 2.0, 1, 2, 3, H, normalize=false)
m = length(model)

guess_file = "notebooks/data/xeq1projection-Re200-1-2-3-27d.asc"
x_star = vec(readdlm(guess_file, comments=true, comment_char='%'))

E = 0.5 .* x_star .* (model.B * x_star)
E_norm = abs.(E) / sum(abs.(E))

ijk = model.N.ijk
rec_counts = zeros(Int, m)
don_counts = zeros(Int, m)
for r in 1:size(ijk,1)
    rec_counts[ijk[r,1]] += 1
    don_counts[ijk[r,2]] += 1
    don_counts[ijk[r,3]] += 1
end

println("Mode\tRec_Count\tDon_Count\tRel_Energy")
for i in 1:m
    @printf("%d\t%d\t%d\t%.4e\n", i, rec_counts[i], don_counts[i], E_norm[i])
end

ipr = 1.0 / sum(E_norm .^ 2)
println("\nEffective Dimension (IPR): ", ipr)

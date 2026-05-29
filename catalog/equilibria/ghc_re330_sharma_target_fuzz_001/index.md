---
physical_id: "ghc_re330_sharma_target_fuzz_001"
case: "ghc_re330_sharma_target_fuzz"
catalog_source: "literature_target_runs:ghc_re330_sharma_target_fuzz"
Re: 330.0
Lx: 5.511566576198634
Lz: 2.5132741228718345
shear: 0.343269
L2: 0.114479
groups: ["SigmaGHC", "Theta6", "ThetaGHC"]
representative_group: "ThetaGHC"
representative_J: 1
representative_K: 4
representative_L: 5
has_dns_bifurcation: false
E3D: 0.0554779
dissipation: 0.343269
D_total: 1.343269
wall_shear: 0.343269
I_total: 1.343269
has_eigen_analysis: true
leading_lambda_re: 0.06844194655896506
leading_lambda_im: 0.0
n_unstable: 2
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# ghc_re330_sharma_target_fuzz_001

## Summary

| Quantity | Value |
|---|---:|
| Case | `ghc_re330_sharma_target_fuzz` |
| Catalog source | `literature_target_runs:ghc_re330_sharma_target_fuzz` |
| Re | 330.0 |
| Lx | 5.511566576198634 |
| Lz | 2.5132741228718345 |
| Shear | 0.343269 |
| L2 | 0.114479 |
| Groups | `SigmaGHC, Theta6, ThetaGHC` |

## Literature

No literature mapping recorded yet.

## Representative Files

- ODE coefficients: [representative.asc](representative.asc)
- DNS flowfield: [ubest.nc](ubest.nc)

## DNS Diagnostics

| Quantity | Value |
|---|---:|
| L2 | 0.114479 |
| u2 | 0.155666 |
| v2 | 0.0205085 |
| w2 | 0.039477 |
| e3d | 0.0554779 |
| ecf | 0.00197903 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.343269 |
| wallshear_a | 0.171634 |
| wallshear_b | -0.171634 |
| dissipation | 0.343269 |
| I_total | 1.343269 |
| D_total | 1.343269 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 2 |
| Leading lambda | 0.06844194655896506 + 0.0i |
| Leading multiplier | 1.40805558198008 + 0.0i |
| Leading residual | 2.8260335138179675e-07 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| SigmaGHC | `<sztx, sxy*txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re330_sharma/ghc_re330_sharma_target_fuzz/SigmaGHC/jkl_1_3_5/dns_findsoln/sol002/ubest.nc` | `SigmaGHC:sol002@J1K3L5` |
| SigmaGHC | `<sztx, sxy*txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re330_sharma/ghc_re330_sharma_target_fuzz/SigmaGHC/jkl_1_4_5/dns_findsoln/sol002/ubest.nc` | `SigmaGHC:sol002@J1K4L5` |
| SigmaGHC | `<sztx, sxy*txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re330_sharma/ghc_re330_sharma_target_fuzz/SigmaGHC/jkl_1_4_5/dns_findsoln/sol003/ubest.nc` | `SigmaGHC:sol003@J1K4L5` |
| Theta6 | `<sxyz*tz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re330_sharma/ghc_re330_sharma_target_fuzz/Theta6/jkl_1_3_5/dns_findsoln/sol002/ubest.nc` | `Theta6:sol002@J1K3L5` |
| Theta6 | `<sxyz*tz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re330_sharma/ghc_re330_sharma_target_fuzz/Theta6/jkl_1_3_5/dns_findsoln/sol003/ubest.nc` | `Theta6:sol003@J1K3L5` |
| Theta6 | `<sxyz*tz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re330_sharma/ghc_re330_sharma_target_fuzz/Theta6/jkl_1_3_5/dns_findsoln/sol004/ubest.nc` | `Theta6:sol004@J1K3L5` |
| Theta6 | `<sxyz*tz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re330_sharma/ghc_re330_sharma_target_fuzz/Theta6/jkl_1_4_5/dns_findsoln/sol002/ubest.nc` | `Theta6:sol002@J1K4L5` |
| Theta6 | `<sxyz*tz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re330_sharma/ghc_re330_sharma_target_fuzz/Theta6/jkl_1_4_5/dns_findsoln/sol004/ubest.nc` | `Theta6:sol004@J1K4L5` |
| ThetaGHC | `<sxy, sztx, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re330_sharma/ghc_re330_sharma_target_fuzz/ThetaGHC/jkl_1_3_5/dns_findsoln/sol001/ubest.nc` | `ThetaGHC:sol001@J1K3L5` |
| ThetaGHC | `<sxy, sztx, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re330_sharma/ghc_re330_sharma_target_fuzz/ThetaGHC/jkl_1_3_5/dns_findsoln/sol002/ubest.nc` | `ThetaGHC:sol002@J1K3L5` |
| ThetaGHC | `<sxy, sztx, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re330_sharma/ghc_re330_sharma_target_fuzz/ThetaGHC/jkl_1_4_5/dns_findsoln/sol001/ubest.nc` | `ThetaGHC:sol001@J1K4L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

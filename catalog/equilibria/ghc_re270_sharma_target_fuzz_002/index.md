---
physical_id: "ghc_re270_sharma_target_fuzz_002"
case: "ghc_re270_sharma_target_fuzz"
catalog_source: "literature_target_runs:ghc_re270_sharma_target_fuzz"
Re: 270.0
Lx: 5.511566576198634
Lz: 2.5132741228718345
shear: 0.552964
L2: 0.154547
groups: ["SigmaGHC", "Theta6", "ThetaGHC"]
representative_group: "ThetaGHC"
representative_J: 1
representative_K: 4
representative_L: 5
has_dns_bifurcation: false
E3D: 0.080352
dissipation: 0.552964
D_total: 1.552964
wall_shear: 0.552964
I_total: 1.552964
has_eigen_analysis: true
leading_lambda_re: 0.05900162693511948
leading_lambda_im: 0.0
n_unstable: 5
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# ghc_re270_sharma_target_fuzz_002

## Summary

| Quantity | Value |
|---|---:|
| Case | `ghc_re270_sharma_target_fuzz` |
| Catalog source | `literature_target_runs:ghc_re270_sharma_target_fuzz` |
| Re | 270.0 |
| Lx | 5.511566576198634 |
| Lz | 2.5132741228718345 |
| Shear | 0.552964 |
| L2 | 0.154547 |
| Groups | `SigmaGHC, Theta6, ThetaGHC` |

## Literature

No literature mapping recorded yet.

## Representative Files

- ODE coefficients: [representative.asc](representative.asc)
- DNS flowfield: [ubest.nc](ubest.nc)

## DNS Diagnostics

| Quantity | Value |
|---|---:|
| L2 | 0.154547 |
| u2 | 0.207365 |
| v2 | 0.034138 |
| w2 | 0.0600332 |
| e3d | 0.080352 |
| ecf | 0.00476939 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.552964 |
| wallshear_a | 0.276482 |
| wallshear_b | -0.276482 |
| dissipation | 0.552964 |
| I_total | 1.552964 |
| D_total | 1.552964 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 5 |
| Leading lambda | 0.05900162693511948 + 0.0i |
| Leading multiplier | 1.3431372846279304 + 0.0i |
| Leading residual | 5.379471900650625e-06 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| SigmaGHC | `<sztx, sxy*txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re270_sharma/ghc_re270_sharma_target_fuzz/SigmaGHC/jkl_1_3_5/dns_findsoln/sol001/ubest.nc` | `SigmaGHC:sol001@J1K3L5` |
| SigmaGHC | `<sztx, sxy*txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re270_sharma/ghc_re270_sharma_target_fuzz/SigmaGHC/jkl_1_3_5/dns_findsoln/sol002/ubest.nc` | `SigmaGHC:sol002@J1K3L5` |
| SigmaGHC | `<sztx, sxy*txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re270_sharma/ghc_re270_sharma_target_fuzz/SigmaGHC/jkl_1_3_5/dns_findsoln/sol004/ubest.nc` | `SigmaGHC:sol004@J1K3L5` |
| SigmaGHC | `<sztx, sxy*txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re270_sharma/ghc_re270_sharma_target_fuzz/SigmaGHC/jkl_1_4_5/dns_findsoln/sol002/ubest.nc` | `SigmaGHC:sol002@J1K4L5` |
| SigmaGHC | `<sztx, sxy*txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re270_sharma/ghc_re270_sharma_target_fuzz/SigmaGHC/jkl_1_4_5/dns_findsoln/sol005/ubest.nc` | `SigmaGHC:sol005@J1K4L5` |
| Theta6 | `<sxyz*tz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re270_sharma/ghc_re270_sharma_target_fuzz/Theta6/jkl_1_3_5/dns_findsoln/sol003/ubest.nc` | `Theta6:sol003@J1K3L5` |
| Theta6 | `<sxyz*tz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re270_sharma/ghc_re270_sharma_target_fuzz/Theta6/jkl_1_3_5/dns_findsoln/sol004/ubest.nc` | `Theta6:sol004@J1K3L5` |
| Theta6 | `<sxyz*tz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re270_sharma/ghc_re270_sharma_target_fuzz/Theta6/jkl_1_3_5/dns_findsoln/sol005/ubest.nc` | `Theta6:sol005@J1K3L5` |
| Theta6 | `<sxyz*tz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re270_sharma/ghc_re270_sharma_target_fuzz/Theta6/jkl_1_3_5/dns_findsoln/sol007/ubest.nc` | `Theta6:sol007@J1K3L5` |
| Theta6 | `<sxyz*tz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re270_sharma/ghc_re270_sharma_target_fuzz/Theta6/jkl_1_4_5/dns_findsoln/sol001/ubest.nc` | `Theta6:sol001@J1K4L5` |
| Theta6 | `<sxyz*tz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re270_sharma/ghc_re270_sharma_target_fuzz/Theta6/jkl_1_4_5/dns_findsoln/sol004/ubest.nc` | `Theta6:sol004@J1K4L5` |
| ThetaGHC | `<sxy, sztx, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re270_sharma/ghc_re270_sharma_target_fuzz/ThetaGHC/jkl_1_3_5/dns_findsoln/sol001/ubest.nc` | `ThetaGHC:sol001@J1K3L5` |
| ThetaGHC | `<sxy, sztx, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re270_sharma/ghc_re270_sharma_target_fuzz/ThetaGHC/jkl_1_3_5/dns_findsoln/sol002/ubest.nc` | `ThetaGHC:sol002@J1K3L5` |
| ThetaGHC | `<sxy, sztx, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re270_sharma/ghc_re270_sharma_target_fuzz/ThetaGHC/jkl_1_4_5/dns_findsoln/sol001/ubest.nc` | `ThetaGHC:sol001@J1K4L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

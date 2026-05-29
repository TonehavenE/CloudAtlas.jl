---
physical_id: "ghc_re330_sharma_target_fuzz_004"
case: "ghc_re330_sharma_target_fuzz"
catalog_source: "literature_target_runs:ghc_re330_sharma_target_fuzz"
Re: 330.0
Lx: 5.511566576198634
Lz: 2.5132741228718345
shear: 1.84258
L2: 0.371329
groups: ["SigmaGHC"]
representative_group: "SigmaGHC"
representative_J: 3
representative_K: 5
representative_L: 11
has_dns_bifurcation: false
E3D: 0.0912573
dissipation: 1.84258
D_total: 2.84258
wall_shear: 1.84258
I_total: 2.84258
has_eigen_analysis: true
leading_lambda_re: 0.06349869375116025
leading_lambda_im: 0.0
n_unstable: 8
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# ghc_re330_sharma_target_fuzz_004

## Summary

| Quantity | Value |
|---|---:|
| Case | `ghc_re330_sharma_target_fuzz` |
| Catalog source | `literature_target_runs:ghc_re330_sharma_target_fuzz` |
| Re | 330.0 |
| Lx | 5.511566576198634 |
| Lz | 2.5132741228718345 |
| Shear | 1.84258 |
| L2 | 0.371329 |
| Groups | `SigmaGHC` |

## Literature

No literature mapping recorded yet.

## Representative Files

- ODE coefficients: [representative.asc](representative.asc)
- DNS flowfield: [ubest.nc](ubest.nc)

## DNS Diagnostics

| Quantity | Value |
|---|---:|
| L2 | 0.371329 |
| u2 | 0.511459 |
| v2 | 0.071377 |
| w2 | 0.0953176 |
| e3d | 0.0912573 |
| ecf | 0.0141801 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 1.84258 |
| wallshear_a | 0.921288 |
| wallshear_b | -0.921288 |
| dissipation | 1.84258 |
| I_total | 2.84258 |
| D_total | 2.84258 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 8 |
| Leading lambda | 0.06349869375116025 + 0.0i |
| Leading multiplier | 1.3736802729947382 + 0.0i |
| Leading residual | 1.6943280453927253e-05 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| SigmaGHC | `<sztx, sxy*txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re330_sharma/ghc_re330_sharma_target_fuzz/SigmaGHC/jkl_1_3_5/dns_findsoln/sol005/ubest.nc` | `SigmaGHC:sol005@J1K3L5` |
| SigmaGHC | `<sztx, sxy*txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re330_sharma/ghc_re330_sharma_target_fuzz/SigmaGHC/jkl_1_4_5/dns_findsoln/sol001/ubest.nc` | `SigmaGHC:sol001@J1K4L5` |
| SigmaGHC | `<sztx, sxy*txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re330_sharma/ghc_re330_sharma_target_fuzz/SigmaGHC/jkl_2_4_5/dns_findsoln/sol002/ubest.nc` | `SigmaGHC:sol002@J2K4L5` |
| SigmaGHC | `<sztx, sxy*txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re330_sharma/ghc_re330_sharma_target_fuzz/SigmaGHC/jkl_2_4_6/dns_findsoln/sol001/ubest.nc` | `SigmaGHC:sol001@J2K4L6` |
| SigmaGHC | `<sztx, sxy*txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re330_sharma/ghc_re330_sharma_target_fuzz/SigmaGHC/jkl_2_4_7/dns_findsoln/sol001/ubest.nc` | `SigmaGHC:sol001@J2K4L7` |
| SigmaGHC | `<sztx, sxy*txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re330_sharma/ghc_re330_sharma_target_fuzz/SigmaGHC/jkl_2_4_8/dns_findsoln/sol001/ubest.nc` | `SigmaGHC:sol001@J2K4L8` |
| SigmaGHC | `<sztx, sxy*txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re330_sharma/ghc_re330_sharma_target_fuzz/SigmaGHC/jkl_2_4_9/dns_findsoln/sol002/ubest.nc` | `SigmaGHC:sol002@J2K4L9` |
| SigmaGHC | `<sztx, sxy*txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re330_sharma/ghc_re330_sharma_target_fuzz/SigmaGHC/jkl_3_4_9/dns_findsoln/sol001/ubest.nc` | `SigmaGHC:sol001@J3K4L9` |
| SigmaGHC | `<sztx, sxy*txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re330_sharma/ghc_re330_sharma_target_fuzz/SigmaGHC/jkl_3_5_9/dns_findsoln/sol001/ubest.nc` | `SigmaGHC:sol001@J3K5L9` |
| SigmaGHC | `<sztx, sxy*txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re330_sharma/ghc_re330_sharma_target_fuzz/SigmaGHC/jkl_3_5_10/dns_findsoln/sol002/ubest.nc` | `SigmaGHC:sol002@J3K5L10` |
| SigmaGHC | `<sztx, sxy*txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re330_sharma/ghc_re330_sharma_target_fuzz/SigmaGHC/jkl_3_5_11/dns_findsoln/sol002/ubest.nc` | `SigmaGHC:sol002@J3K5L11` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

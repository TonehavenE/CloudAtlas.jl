---
physical_id: "ghc_re330_sharma_target_fuzz_003"
case: "ghc_re330_sharma_target_fuzz"
catalog_source: "literature_target_runs:ghc_re330_sharma_target_fuzz"
Re: 330.0
Lx: 5.511566576198634
Lz: 2.5132741228718345
shear: 1.30573
L2: 0.239724
groups: ["SigmaGHC"]
representative_group: "SigmaGHC"
representative_J: 1
representative_K: 4
representative_L: 5
has_dns_bifurcation: false
E3D: 0.11178
dissipation: 1.30573
D_total: 2.30573
wall_shear: 1.30573
I_total: 2.30573
has_eigen_analysis: true
leading_lambda_re: 0.07689028959933202
leading_lambda_im: 0.0
n_unstable: 11
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# ghc_re330_sharma_target_fuzz_003

## Summary

| Quantity | Value |
|---|---:|
| Case | `ghc_re330_sharma_target_fuzz` |
| Catalog source | `literature_target_runs:ghc_re330_sharma_target_fuzz` |
| Re | 330.0 |
| Lx | 5.511566576198634 |
| Lz | 2.5132741228718345 |
| Shear | 1.30573 |
| L2 | 0.239724 |
| Groups | `SigmaGHC` |

## Literature

No literature mapping recorded yet.

## Representative Files

- ODE coefficients: [representative.asc](representative.asc)
- DNS flowfield: [ubest.nc](ubest.nc)

## DNS Diagnostics

| Quantity | Value |
|---|---:|
| L2 | 0.239724 |
| u2 | 0.32016 |
| v2 | 0.0636468 |
| w2 | 0.0915531 |
| e3d | 0.11178 |
| ecf | 0.0124329 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 1.30573 |
| wallshear_a | 0.652864 |
| wallshear_b | -0.652864 |
| dissipation | 1.30573 |
| I_total | 2.30573 |
| D_total | 2.30573 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 11 |
| Leading lambda | 0.07689028959933202 + 0.0i |
| Leading multiplier | 1.4688083826308647 + 0.0i |
| Leading residual | 0.0003262110810113227 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| SigmaGHC | `<sztx, sxy*txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re330_sharma/ghc_re330_sharma_target_fuzz/SigmaGHC/jkl_1_3_5/dns_findsoln/sol004/ubest.nc` | `SigmaGHC:sol004@J1K3L5` |
| SigmaGHC | `<sztx, sxy*txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re330_sharma/ghc_re330_sharma_target_fuzz/SigmaGHC/jkl_1_4_5/dns_findsoln/sol005/ubest.nc` | `SigmaGHC:sol005@J1K4L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

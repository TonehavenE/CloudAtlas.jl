---
physical_id: "ghc_re400_literature_fuzz_005"
case: "ghc_re400_literature_fuzz"
catalog_source: "literature_target_runs:ghc_re400_literature_fuzz"
Re: 400.0
Lx: 5.511566576198634
Lz: 2.5132741228718345
shear: 1.59813
L2: 0.272377
groups: ["B", "G"]
representative_group: "G"
representative_J: 1
representative_K: 4
representative_L: 5
has_dns_bifurcation: false
E3D: 0.100573
dissipation: 1.59813
D_total: 2.5981300000000003
wall_shear: 1.59813
I_total: 2.5981300000000003
has_eigen_analysis: true
leading_lambda_re: 0.17691213139945364
leading_lambda_im: 0.0
n_unstable: 13
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# ghc_re400_literature_fuzz_005

## Summary

| Quantity | Value |
|---|---:|
| Case | `ghc_re400_literature_fuzz` |
| Catalog source | `literature_target_runs:ghc_re400_literature_fuzz` |
| Re | 400.0 |
| Lx | 5.511566576198634 |
| Lz | 2.5132741228718345 |
| Shear | 1.59813 |
| L2 | 0.272377 |
| Groups | `B, G` |

## Literature

No literature mapping recorded yet.

## Representative Files

- ODE coefficients: [representative.asc](representative.asc)
- DNS flowfield: [ubest.nc](ubest.nc)

## DNS Diagnostics

| Quantity | Value |
|---|---:|
| L2 | 0.272377 |
| u2 | 0.373044 |
| v2 | 0.0599054 |
| w2 | 0.075014 |
| e3d | 0.100573 |
| ecf | 0.00921576 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 1.59813 |
| wallshear_a | 0.799064 |
| wallshear_b | -0.799064 |
| dissipation | 1.59813 |
| I_total | 2.5981300000000003 |
| D_total | 2.5981300000000003 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 13 |
| Leading lambda | 0.17691213139945364 + 0.0i |
| Leading multiplier | 2.4219201040581586 + 0.0i |
| Leading residual | 2.0029569857485843e-10 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| B | `<sxy, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re400/ghc_re400_literature_fuzz/B/jkl_1_4_5/dns_findsoln/sol002/ubest.nc` | `fuzz:sol002@J1K4L5` |
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re400/ghc_re400_literature_fuzz/G/jkl_1_4_5/dns_findsoln/sol004/ubest.nc` | `fuzz:sol004@J1K4L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

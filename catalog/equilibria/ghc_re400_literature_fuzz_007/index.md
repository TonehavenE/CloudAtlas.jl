---
physical_id: "ghc_re400_literature_fuzz_007"
case: "ghc_re400_literature_fuzz"
catalog_source: "literature_target_runs:ghc_re400_literature_fuzz"
Re: 400.0
Lx: 5.511566576198634
Lz: 2.5132741228718345
shear: 2.04368
L2: 0.385806
groups: ["E"]
representative_group: "E"
representative_J: 2
representative_K: 4
representative_L: 6
has_dns_bifurcation: false
E3D: 0.0851956
dissipation: 2.04368
D_total: 3.04368
wall_shear: 2.04368
I_total: 3.04368
has_eigen_analysis: true
leading_lambda_re: 0.055589983720085126
leading_lambda_im: 0.0
n_unstable: 8
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# ghc_re400_literature_fuzz_007

## Summary

| Quantity | Value |
|---|---:|
| Case | `ghc_re400_literature_fuzz` |
| Catalog source | `literature_target_runs:ghc_re400_literature_fuzz` |
| Re | 400.0 |
| Lx | 5.511566576198634 |
| Lz | 2.5132741228718345 |
| Shear | 2.04368 |
| L2 | 0.385806 |
| Groups | `E` |

## Literature

No literature mapping recorded yet.

## Representative Files

- ODE coefficients: [representative.asc](representative.asc)
- DNS flowfield: [ubest.nc](ubest.nc)

## DNS Diagnostics

| Quantity | Value |
|---|---:|
| L2 | 0.385806 |
| u2 | 0.534477 |
| v2 | 0.0677193 |
| w2 | 0.0862577 |
| e3d | 0.0851956 |
| ecf | 0.0120263 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 2.04368 |
| wallshear_a | 1.02184 |
| wallshear_b | -1.02184 |
| dissipation | 2.04368 |
| I_total | 3.04368 |
| D_total | 3.04368 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 8 |
| Leading lambda | 0.055589983720085126 + 0.0i |
| Leading multiplier | 1.3204200670681794 + 0.0i |
| Leading residual | 0.0005801679914531012 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re400/ghc_re400_literature_fuzz/E/jkl_1_4_5/dns_findsoln/sol005/ubest.nc` | `fuzz:sol005@J1K4L5` |
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re400/ghc_re400_literature_fuzz/E/jkl_2_4_6/dns_findsoln/sol002/ubest.nc` | `fuzz:sol002@J2K4L6` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

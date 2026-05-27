---
physical_id: "ghc_re400_literature_fuzz_010"
case: "ghc_re400_literature_fuzz"
catalog_source: "literature_target_runs:ghc_re400_literature_fuzz"
Re: 400.0
Lx: 5.511566576198634
Lz: 2.5132741228718345
shear: 2.50069
L2: 0.333628
groups: ["B"]
representative_group: "B"
representative_J: 1
representative_K: 4
representative_L: 5
has_dns_bifurcation: false
E3D: 0.129477
dissipation: 2.50069
D_total: 3.50069
wall_shear: 2.50069
I_total: 3.50069
has_eigen_analysis: true
leading_lambda_re: 0.09027919141949373
leading_lambda_im: -0.44441001939188357
n_unstable: 20
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# ghc_re400_literature_fuzz_010

## Summary

| Quantity | Value |
|---|---:|
| Case | `ghc_re400_literature_fuzz` |
| Catalog source | `literature_target_runs:ghc_re400_literature_fuzz` |
| Re | 400.0 |
| Lx | 5.511566576198634 |
| Lz | 2.5132741228718345 |
| Shear | 2.50069 |
| L2 | 0.333628 |
| Groups | `B` |

## Literature

No literature mapping recorded yet.

## Representative Files

- ODE coefficients: [representative.asc](representative.asc)
- DNS flowfield: [ubest.nc](ubest.nc)

## DNS Diagnostics

| Quantity | Value |
|---|---:|
| L2 | 0.333628 |
| u2 | 0.451017 |
| v2 | 0.091353 |
| w2 | 0.10418 |
| e3d | 0.129477 |
| ecf | 0.0191988 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 2.50069 |
| wallshear_a | 1.25035 |
| wallshear_b | -1.25035 |
| dissipation | 2.50069 |
| I_total | 3.50069 |
| D_total | 3.50069 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 20 |
| Leading lambda | 0.09027919141949373 + -0.44441001939188357i |
| Leading multiplier | -0.9520138535351994 + -1.2490593779480157i |
| Leading residual | 5.584482423281946e-05 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| B | `<sxy, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re400/ghc_re400_literature_fuzz/B/jkl_1_4_5/dns_findsoln/sol003/ubest.nc` | `fuzz:sol003@J1K4L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

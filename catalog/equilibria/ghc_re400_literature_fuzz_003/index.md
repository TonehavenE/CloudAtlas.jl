---
physical_id: "ghc_re400_literature_fuzz_003"
case: "ghc_re400_literature_fuzz"
catalog_source: "literature_target_runs:ghc_re400_literature_fuzz"
Re: 400.0
Lx: 5.511566576198634
Lz: 2.5132741228718345
shear: 0.429258
L2: 0.209125
groups: ["E"]
representative_group: "E"
representative_J: 2
representative_K: 4
representative_L: 7
has_dns_bifurcation: false
E3D: 0.0274429
dissipation: 0.429258
D_total: 1.429258
wall_shear: 0.429258
I_total: 1.429258
has_eigen_analysis: true
leading_lambda_re: 0.05012059377963958
leading_lambda_im: 0.0
n_unstable: 2
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# ghc_re400_literature_fuzz_003

## Summary

| Quantity | Value |
|---|---:|
| Case | `ghc_re400_literature_fuzz` |
| Catalog source | `literature_target_runs:ghc_re400_literature_fuzz` |
| Re | 400.0 |
| Lx | 5.511566576198634 |
| Lz | 2.5132741228718345 |
| Shear | 0.429258 |
| L2 | 0.209125 |
| Groups | `E` |

## Literature

No literature mapping recorded yet.

## Representative Files

- ODE coefficients: [representative.asc](representative.asc)
- DNS flowfield: [ubest.nc](ubest.nc)

## DNS Diagnostics

| Quantity | Value |
|---|---:|
| L2 | 0.209125 |
| u2 | 0.294671 |
| v2 | 0.0121805 |
| w2 | 0.0220762 |
| e3d | 0.0274429 |
| ecf | 0.000635723 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.429258 |
| wallshear_a | 0.214629 |
| wallshear_b | -0.214629 |
| dissipation | 0.429258 |
| I_total | 1.429258 |
| D_total | 1.429258 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 2 |
| Leading lambda | 0.05012059377963958 + 0.0i |
| Leading multiplier | 1.2847998775429397 + 0.0i |
| Leading residual | 6.27293589724488e-08 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re400/ghc_re400_literature_fuzz/E/jkl_2_4_7/dns_findsoln/sol001/ubest.nc` | `fuzz:sol001@J2K4L7` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

---
physical_id: "ghc_re400_literature_fuzz_002"
case: "ghc_re400_literature_fuzz"
catalog_source: "literature_target_runs:ghc_re400_literature_fuzz"
Re: 400.0
Lx: 5.511566576198634
Lz: 2.5132741228718345
shear: 0.317713
L2: 0.12589
groups: ["E"]
representative_group: "E"
representative_J: 2
representative_K: 4
representative_L: 5
has_dns_bifurcation: false
E3D: 0.0450151
dissipation: 0.317713
D_total: 1.317713
wall_shear: 0.317713
I_total: 1.317713
has_eigen_analysis: true
leading_lambda_re: 0.033973405046489824
leading_lambda_im: -0.017977558422515597
n_unstable: 4
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# ghc_re400_literature_fuzz_002

## Summary

| Quantity | Value |
|---|---:|
| Case | `ghc_re400_literature_fuzz` |
| Catalog source | `literature_target_runs:ghc_re400_literature_fuzz` |
| Re | 400.0 |
| Lx | 5.511566576198634 |
| Lz | 2.5132741228718345 |
| Shear | 0.317713 |
| L2 | 0.12589 |
| Groups | `E` |

## Literature

No literature mapping recorded yet.

## Representative Files

- ODE coefficients: [representative.asc](representative.asc)
- DNS flowfield: [ubest.nc](ubest.nc)

## DNS Diagnostics

| Quantity | Value |
|---|---:|
| L2 | 0.12589 |
| u2 | 0.173565 |
| v2 | 0.0151295 |
| w2 | 0.036646 |
| e3d | 0.0450151 |
| ecf | 0.00157183 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.317713 |
| wallshear_a | 0.158856 |
| wallshear_b | -0.158856 |
| dissipation | 0.317713 |
| I_total | 1.317713 |
| D_total | 1.317713 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 4 |
| Leading lambda | 0.033973405046489824 + -0.017977558422515597i |
| Leading multiplier | 1.180362583713574 + -0.10638686974918822i |
| Leading residual | 0.0002359443046920206 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re400/ghc_re400_literature_fuzz/E/jkl_2_4_5/dns_findsoln/sol003/ubest.nc` | `fuzz:sol003@J2K4L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

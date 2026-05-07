---
physical_id: "re400_lx10_lz6_019"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 0.895123
L2: 0.219999
groups: ["G"]
representative_group: "G"
representative_J: 1
representative_K: 4
representative_L: 5
has_dns_bifurcation: false
E3D: 0.0985376
dissipation: 0.894966
D_total: 1.8949660000000002
wall_shear: 0.895123
I_total: 1.895123
has_eigen_analysis: true
leading_lambda_re: 0.16732888824352288
leading_lambda_im: 0.0843151116276339
n_unstable: 13
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_019

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.895123 |
| L2 | 0.219999 |
| Groups | `G` |

## Literature

No literature mapping recorded yet.

## Possible Same Branch

No cross-parameter ODE deduplication candidate recorded yet.

## Representative Files

- ODE coefficients: [representative.asc](representative.asc)
- DNS flowfield: [ubest.nc](ubest.nc)

## DNS/ODE Comparison

![DNS/ODE comparison](images/dns_ode_comparison.png)

## DNS Diagnostics

| Quantity | Value |
|---|---:|
| L2 | 0.219999 |
| u2 | 0.304255 |
| v2 | 0.0342363 |
| w2 | 0.0552836 |
| e3d | 0.0985376 |
| ecf | 0.0042284 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.895123 |
| wallshear_a | 0.447561 |
| wallshear_b | -0.447561 |
| dissipation | 0.894966 |
| I_total | 1.895123 |
| D_total | 1.8949660000000002 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 13 |
| Leading lambda | 0.16732888824352288 + 0.0843151116276339i |
| Leading multiplier | 2.106478009683447 + 0.944678807306667i |
| Leading residual | 0.00019285276887267213 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/G/jkl_1_4_5/dns_findsoln/sol004/ubest.nc` | `on:sol004@J1K4L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

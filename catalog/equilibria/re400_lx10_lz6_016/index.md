---
physical_id: "re400_lx10_lz6_016"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 0.697371
L2: 0.200136
groups: ["D"]
representative_group: "D"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: false
E3D: 0.0889379
dissipation: 0.697371
D_total: 1.697371
wall_shear: 0.697371
I_total: 1.697371
has_eigen_analysis: true
leading_lambda_re: 0.1691021746549474
leading_lambda_im: 0.0
n_unstable: 9
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_016

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.697371 |
| L2 | 0.200136 |
| Groups | `D` |

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
| L2 | 0.200136 |
| u2 | 0.276978 |
| v2 | 0.0342276 |
| w2 | 0.0471222 |
| e3d | 0.0889379 |
| ecf | 0.00339203 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.697371 |
| wallshear_a | 0.348685 |
| wallshear_b | -0.348685 |
| dissipation | 0.697371 |
| I_total | 1.697371 |
| D_total | 1.697371 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 9 |
| Leading lambda | 0.1691021746549474 + 0.0i |
| Leading multiplier | 2.329167420062833 + 0.0i |
| Leading residual | 3.65543975155504e-05 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| D | `<sxy, sztx>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/D/jkl_1_3_5/dns_findsoln/sol004/ubest.nc` | `on:sol004@J1K3L5;on:sol009@J1K3L5;ls:sol008@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

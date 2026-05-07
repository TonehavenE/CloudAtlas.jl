---
physical_id: "re400_lx10_lz6_005"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 0.173827
L2: 0.0845575
groups: ["D"]
representative_group: "D"
representative_J: 1
representative_K: 4
representative_L: 5
has_dns_bifurcation: false
E3D: 0.0520768
dissipation: 0.173827
D_total: 1.173827
wall_shear: 0.173827
I_total: 1.173827
has_eigen_analysis: true
leading_lambda_re: 0.017551320889050606
leading_lambda_im: 0.0
n_unstable: 5
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_005

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.173827 |
| L2 | 0.0845575 |
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
| L2 | 0.0845575 |
| u2 | 0.116356 |
| v2 | 0.0132307 |
| w2 | 0.0242117 |
| e3d | 0.0520768 |
| ecf | 0.000761255 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.173827 |
| wallshear_a | 0.0869133 |
| wallshear_b | -0.0869133 |
| dissipation | 0.173827 |
| I_total | 1.173827 |
| D_total | 1.173827 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 5 |
| Leading lambda | 0.017551320889050606 + 0.0i |
| Leading multiplier | 1.0917223693162856 + 0.0i |
| Leading residual | 0.024676762745820303 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| D | `<sxy, sztx>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/D/jkl_1_4_5/dns_findsoln/sol005/ubest.nc` | `on:sol005@J1K4L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

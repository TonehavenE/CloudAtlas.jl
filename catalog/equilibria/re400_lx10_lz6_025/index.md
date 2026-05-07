---
physical_id: "re400_lx10_lz6_025"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 1.17228
L2: 0.233655
groups: ["E"]
representative_group: "E"
representative_J: 2
representative_K: 4
representative_L: 6
has_dns_bifurcation: false
E3D: 0.104811
dissipation: 1.17228
D_total: 2.1722799999999998
wall_shear: 1.17228
I_total: 2.1722799999999998
has_eigen_analysis: true
leading_lambda_re: 0.1804991931708248
leading_lambda_im: 0.0
n_unstable: 19
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_025

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 1.17228 |
| L2 | 0.233655 |
| Groups | `E` |

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
| L2 | 0.233655 |
| u2 | 0.316823 |
| v2 | 0.0514667 |
| w2 | 0.0785066 |
| e3d | 0.104811 |
| ecf | 0.00881211 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 1.17228 |
| wallshear_a | 0.58614 |
| wallshear_b | -0.58614 |
| dissipation | 1.17228 |
| I_total | 2.1722799999999998 |
| D_total | 2.1722799999999998 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 19 |
| Leading lambda | 0.1804991931708248 + 0.0i |
| Leading multiplier | 2.465749864389075 + 0.0i |
| Leading residual | 0.0002117111124373153 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/E/jkl_2_4_6/dns_findsoln/sol010/ubest.nc` | `on:sol010@J2K4L6` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

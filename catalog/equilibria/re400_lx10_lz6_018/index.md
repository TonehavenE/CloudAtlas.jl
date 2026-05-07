---
physical_id: "re400_lx10_lz6_018"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 0.830027
L2: 0.212146
groups: ["C"]
representative_group: "C"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: false
E3D: 0.091239
dissipation: 0.830027
D_total: 1.8300269999999998
wall_shear: 0.830027
I_total: 1.8300269999999998
has_eigen_analysis: true
leading_lambda_re: 0.08514208150919629
leading_lambda_im: 0.0
n_unstable: 8
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_018

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.830027 |
| L2 | 0.212146 |
| Groups | `C` |

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
| L2 | 0.212146 |
| u2 | 0.293114 |
| v2 | 0.0331757 |
| w2 | 0.0547317 |
| e3d | 0.091239 |
| ecf | 0.00409619 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.830027 |
| wallshear_a | 0.415014 |
| wallshear_b | -0.415014 |
| dissipation | 0.830027 |
| I_total | 1.8300269999999998 |
| D_total | 1.8300269999999998 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 8 |
| Leading lambda | 0.08514208150919629 + 0.0i |
| Leading multiplier | 1.5306774383071757 + 0.0i |
| Leading residual | 0.0015512013678127868 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| C | `<sxytz, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/C/jkl_1_3_5/dns_findsoln/sol008/ubest.nc` | `on:sol008@J1K3L5;ls:sol005@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

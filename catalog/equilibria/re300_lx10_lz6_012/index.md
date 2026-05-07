---
physical_id: "re300_lx10_lz6_012"
case: "re300_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 10.0
Lz: 6.0
shear: 0.562706
L2: 0.180224
groups: ["D"]
representative_group: "D"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: true
E3D: 0.0932412
dissipation: 0.562706
D_total: 1.562706
wall_shear: 0.562706
I_total: 1.562706
has_eigen_analysis: true
leading_lambda_re: 0.024139210297667232
leading_lambda_im: 0.0
n_unstable: 4
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx10_lz6_012

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.562706 |
| L2 | 0.180224 |
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
| L2 | 0.180224 |
| u2 | 0.248347 |
| v2 | 0.0310509 |
| w2 | 0.0481787 |
| e3d | 0.0932412 |
| ecf | 0.00328534 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.562706 |
| wallshear_a | 0.281353 |
| wallshear_b | -0.281353 |
| dissipation | 0.562706 |
| I_total | 1.562706 |
| D_total | 1.562706 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 4 |
| Leading lambda | 0.024139210297667232 + 0.0i |
| Leading multiplier | 1.1282819206335573 + 0.0i |
| Leading residual | 0.04381920272644917 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| D | `<sxy, sztx>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx10_lz6/D/jkl_1_3_5/dns_findsoln/sol003/ubest.nc` | `on:sol003@J1K3L5;ls:sol003@J1K3L5` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 63
- Re range: 290.42707 to 655.581
- Input range: 1.3886151 to 2.3381621

---
physical_id: "re300_lx10_lz6_004"
case: "re300_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 10.0
Lz: 6.0
shear: 0.260169
L2: 0.118291
groups: ["G"]
representative_group: "G"
representative_J: 1
representative_K: 4
representative_L: 5
has_dns_bifurcation: true
E3D: 0.0621388
dissipation: 0.260168
D_total: 1.260168
wall_shear: 0.260169
I_total: 1.2601689999999999
has_eigen_analysis: true
leading_lambda_re: 0.0474826897459241
leading_lambda_im: 0.0
n_unstable: 3
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx10_lz6_004

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.260169 |
| L2 | 0.118291 |
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
| L2 | 0.118291 |
| u2 | 0.163084 |
| v2 | 0.015356 |
| w2 | 0.0339634 |
| e3d | 0.0621388 |
| ecf | 0.00138932 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.260169 |
| wallshear_a | 0.130084 |
| wallshear_b | -0.130084 |
| dissipation | 0.260168 |
| I_total | 1.2601689999999999 |
| D_total | 1.260168 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 3 |
| Leading lambda | 0.0474826897459241 + 0.0i |
| Leading multiplier | 1.267965248038326 + 0.0i |
| Leading residual | 0.0010930844419294943 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx10_lz6/G/jkl_1_4_5/dns_findsoln/sol008/ubest.nc` | `on:sol008@J1K4L5;ls:sol003@J1K4L5` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 68
- Re range: 274.69691 to 498.68337
- Input range: 1.2335972 to 1.3536166

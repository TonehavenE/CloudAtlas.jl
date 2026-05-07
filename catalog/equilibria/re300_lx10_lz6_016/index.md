---
physical_id: "re300_lx10_lz6_016"
case: "re300_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 10.0
Lz: 6.0
shear: 0.69859
L2: 0.23608
groups: ["E"]
representative_group: "E"
representative_J: 2
representative_K: 4
representative_L: 5
has_dns_bifurcation: true
E3D: 0.077608
dissipation: 0.69859
D_total: 1.69859
wall_shear: 0.69859
I_total: 1.69859
has_eigen_analysis: true
leading_lambda_re: 0.08450938627109389
leading_lambda_im: 0.0
n_unstable: 12
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx10_lz6_016

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.69859 |
| L2 | 0.23608 |
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
| L2 | 0.23608 |
| u2 | 0.327358 |
| v2 | 0.0319141 |
| w2 | 0.057325 |
| e3d | 0.077608 |
| ecf | 0.00430466 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.69859 |
| wallshear_a | 0.349295 |
| wallshear_b | -0.349295 |
| dissipation | 0.69859 |
| I_total | 1.69859 |
| D_total | 1.69859 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 12 |
| Leading lambda | 0.08450938627109389 + 0.0i |
| Leading multiplier | 1.5258428277952554 + 0.0i |
| Leading residual | 0.0046468201434603 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx10_lz6/E/jkl_2_4_5/dns_findsoln/sol004/ubest.nc` | `on:sol004@J2K4L5` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 98
- Re range: 239.69311 to 409.95298
- Input range: 1.4721289 to 2.974818

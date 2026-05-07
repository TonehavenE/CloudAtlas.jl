---
physical_id: "re300_lx2pi_lzpi_005"
case: "re300_lx2pi_lzpi"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 6.283185307179586
Lz: 3.141592653589793
shear: 0.869302
L2: 0.197445
groups: ["G"]
representative_group: "G"
representative_J: 2
representative_K: 4
representative_L: 5
has_dns_bifurcation: true
E3D: 0.0838262
dissipation: 0.869302
D_total: 1.869302
wall_shear: 0.869302
I_total: 1.869302
has_eigen_analysis: true
leading_lambda_re: 0.1529996316391552
leading_lambda_im: 0.0
n_unstable: 9
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx2pi_lzpi_005

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx2pi_lzpi` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 6.283185307179586 |
| Lz | 3.141592653589793 |
| Shear | 0.869302 |
| L2 | 0.197445 |
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
| L2 | 0.197445 |
| u2 | 0.270607 |
| v2 | 0.0394145 |
| w2 | 0.0564582 |
| e3d | 0.0838262 |
| ecf | 0.00474103 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.869302 |
| wallshear_a | 0.434651 |
| wallshear_b | -0.434651 |
| dissipation | 0.869302 |
| I_total | 1.869302 |
| D_total | 1.869302 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 9 |
| Leading lambda | 0.1529996316391552 + 0.0i |
| Leading multiplier | 2.1489904166319485 + 0.0i |
| Leading residual | 1.8440855138355621e-06 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx2pi_lzpi/G/jkl_2_4_5/dns_findsoln/sol001/ubest.nc` | `on:sol001@J2K4L5` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 61
- Re range: 245.07433 to 502.11592
- Input range: 1.6592917 to 4.8299798

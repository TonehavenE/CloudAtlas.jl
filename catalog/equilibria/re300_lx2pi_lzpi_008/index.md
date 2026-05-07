---
physical_id: "re300_lx2pi_lzpi_008"
case: "re300_lx2pi_lzpi"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 6.283185307179586
Lz: 3.141592653589793
shear: 1.2109
L2: 0.250827
groups: ["B"]
representative_group: "B"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: true
E3D: 0.10725
dissipation: 1.2109
D_total: 2.2109
wall_shear: 1.2109
I_total: 2.2109
has_eigen_analysis: true
leading_lambda_re: 0.0829405353424805
leading_lambda_im: 0.0
n_unstable: 7
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx2pi_lzpi_008

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx2pi_lzpi` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 6.283185307179586 |
| Lz | 3.141592653589793 |
| Shear | 1.2109 |
| L2 | 0.250827 |
| Groups | `B` |

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
| L2 | 0.250827 |
| u2 | 0.340869 |
| v2 | 0.0583745 |
| w2 | 0.0789215 |
| e3d | 0.10725 |
| ecf | 0.00963619 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 1.2109 |
| wallshear_a | 0.60545 |
| wallshear_b | -0.60545 |
| dissipation | 1.2109 |
| I_total | 2.2109 |
| D_total | 2.2109 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 7 |
| Leading lambda | 0.0829405353424805 + 0.0i |
| Leading multiplier | 1.5139205499341988 + 0.0i |
| Leading residual | 3.139785881332654e-06 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| B | `<sxy, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx2pi_lzpi/B/jkl_1_3_5/dns_findsoln/sol002/ubest.nc` | `on:sol002@J1K3L5;ls:sol003@J1K3L5` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 104
- Re range: 178.66657 to 478.01304
- Input range: 2.0176319 to 5.1631451

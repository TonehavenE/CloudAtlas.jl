---
physical_id: "re300_lx2pi_lzpi_003"
case: "re300_lx2pi_lzpi"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 6.283185307179586
Lz: 3.141592653589793
shear: 0.451944
L2: 0.238198
groups: ["E"]
representative_group: "E"
representative_J: 3
representative_K: 5
representative_L: 11
has_dns_bifurcation: true
E3D: 0.0329181
dissipation: 0.451944
D_total: 1.4519440000000001
wall_shear: 0.451944
I_total: 1.4519440000000001
has_eigen_analysis: true
leading_lambda_re: 0.05142253926723844
leading_lambda_im: 0.0
n_unstable: 1
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx2pi_lzpi_003

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx2pi_lzpi` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 6.283185307179586 |
| Lz | 3.141592653589793 |
| Shear | 0.451944 |
| L2 | 0.238198 |
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
| L2 | 0.238198 |
| u2 | 0.33534 |
| v2 | 0.0138389 |
| w2 | 0.0288492 |
| e3d | 0.0329181 |
| ecf | 0.00102379 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.451944 |
| wallshear_a | 0.225972 |
| wallshear_b | -0.225972 |
| dissipation | 0.451944 |
| I_total | 1.4519440000000001 |
| D_total | 1.4519440000000001 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 1 |
| Leading lambda | 0.05142253926723844 + 0.0i |
| Leading multiplier | 1.2931908564191157 + 0.0i |
| Leading residual | 1.8902552734948028e-07 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx2pi_lzpi/E/jkl_3_5_11/dns_findsoln/sol002/ubest.nc` | `on:sol002@J3K5L11;ls:sol002@J3K5L11` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 64
- Re range: 163.69327 to 580.39679
- Input range: 1.3906591 to 3.3485485

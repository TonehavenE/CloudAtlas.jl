---
physical_id: "re300_lx2pi_lzpi_012"
case: "re300_lx2pi_lzpi"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 6.283185307179586
Lz: 3.141592653589793
shear: 3.7039
L2: 0.419643
groups: ["A", "B", "C", "D", "E", "F"]
representative_group: "A"
representative_J: 3
representative_K: 5
representative_L: 11
has_dns_bifurcation: true
E3D: 0.208481
dissipation: 3.7039
D_total: 4.7039
wall_shear: 3.7039
I_total: 4.7039
has_eigen_analysis: true
leading_lambda_re: 0.08098708812345766
leading_lambda_im: 0.0
n_unstable: 21
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx2pi_lzpi_012

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx2pi_lzpi` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 6.283185307179586 |
| Lz | 3.141592653589793 |
| Shear | 3.7039 |
| L2 | 0.419643 |
| Groups | `A, B, C, D, E, F` |

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
| L2 | 0.419643 |
| u2 | 0.5387 |
| v2 | 0.153759 |
| w2 | 0.195859 |
| e3d | 0.208481 |
| ecf | 0.0620027 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 3.7039 |
| wallshear_a | 1.85195 |
| wallshear_b | -1.85195 |
| dissipation | 3.7039 |
| I_total | 4.7039 |
| D_total | 4.7039 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 21 |
| Leading lambda | 0.08098708812345766 + 0.0i |
| Leading multiplier | 1.4992057091372797 + 0.0i |
| Leading residual | 0.0071663336549676725 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| A | `<sxyz, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx2pi_lzpi/A/jkl_3_5_11/dns_findsoln/sol001/ubest.nc` | `on:sol001@J3K5L11;on:sol003@J1K3L5;ls:sol001@J3K5L11;ls:sol004@J1K3L5` |
| B | `<sxy, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx2pi_lzpi/B/jkl_1_3_5/dns_findsoln/sol003/ubest.nc` | `on:sol003@J1K3L5;ls:sol002@J1K3L5` |
| C | `<sxytz, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx2pi_lzpi/C/jkl_1_3_5/dns_findsoln/sol003/ubest.nc` | `on:sol003@J1K3L5;ls:sol003@J1K3L5` |
| D | `<sxy, sztx>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re300_lx2pi_lzpi/D/jkl_1_3_5/dns_findsoln/sol003/ubest.nc` | `ls:sol003@J1K3L5` |
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx2pi_lzpi/E/jkl_1_3_5/dns_findsoln/sol007/ubest.nc` | `on:sol007@J1K3L5;ls:sol008@J1K3L5;ls:sol009@J1K3L5` |
| F | `<sxy, sz, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx2pi_lzpi/F/jkl_1_3_5/dns_findsoln/sol002/ubest.nc` | `on:sol002@J1K3L5;ls:sol001@J3K5L11` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 71
- Re range: 173.98832 to 508.07227
- Input range: 1.2261403 to 5.4245666

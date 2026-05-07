---
physical_id: "re400_lx10_lz6_003"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 0.131507
L2: 0.0807176
groups: ["B", "C", "D", "E", "F", "G"]
representative_group: "B"
representative_J: 3
representative_K: 5
representative_L: 11
has_dns_bifurcation: true
E3D: 0.0369585
dissipation: 0.131507
D_total: 1.131507
wall_shear: 0.131507
I_total: 1.131507
has_eigen_analysis: true
leading_lambda_re: 0.0464087359093081
leading_lambda_im: 0.0
n_unstable: 3
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_003

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.131507 |
| L2 | 0.0807176 |
| Groups | `B, C, D, E, F, G` |

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
| L2 | 0.0807176 |
| u2 | 0.112508 |
| v2 | 0.00757403 |
| w2 | 0.0177561 |
| e3d | 0.0369585 |
| ecf | 0.000372645 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.131507 |
| wallshear_a | 0.0657533 |
| wallshear_b | -0.0657533 |
| dissipation | 0.131507 |
| I_total | 1.131507 |
| D_total | 1.131507 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 3 |
| Leading lambda | 0.0464087359093081 + 0.0i |
| Leading multiplier | 1.2611748151692823 + 0.0i |
| Leading residual | 8.31355272517984e-05 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| B | `<sxy, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/B/jkl_3_5_11/dns_findsoln/sol001/ubest.nc` | `on:sol001@J3K5L11;on:sol004@J1K4L5` |
| C | `<sxytz, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/C/jkl_3_5_11/dns_findsoln/sol001/ubest.nc` | `on:sol001@J3K5L11;on:sol003@J2K4L9;ls:sol004@J1K4L5` |
| D | `<sxy, sztx>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/D/jkl_1_4_5/dns_findsoln/sol003/ubest.nc` | `on:sol003@J1K4L5;ls:sol004@J1K4L5` |
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/E/jkl_1_4_5/dns_findsoln/sol012/ubest.nc` | `on:sol012@J1K4L5` |
| F | `<sxy, sz, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/F/jkl_1_4_5/dns_findsoln/sol002/ubest.nc` | `on:sol002@J1K4L5;ls:sol001@J1K4L5` |
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re400_lx10_lz6/G/jkl_1_4_5/dns_findsoln/sol007/ubest.nc` | `ls:sol007@J1K4L5` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 58
- Re range: 270.27081 to 519.79523
- Input range: 1.0976479 to 2.8170807

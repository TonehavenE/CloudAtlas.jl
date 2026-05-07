---
physical_id: "re300_lx10_lz6_002"
case: "re300_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 10.0
Lz: 6.0
shear: 0.191403
L2: 0.093204
groups: ["D", "G"]
representative_group: "G"
representative_J: 2
representative_K: 4
representative_L: 5
has_dns_bifurcation: true
E3D: 0.0605405
dissipation: 0.191403
D_total: 1.191403
wall_shear: 0.191403
I_total: 1.191403
has_eigen_analysis: true
leading_lambda_re: 0.03793383508390278
leading_lambda_im: 0.0
n_unstable: 6
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx10_lz6_002

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.191403 |
| L2 | 0.093204 |
| Groups | `D, G` |

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
| L2 | 0.093204 |
| u2 | 0.126776 |
| v2 | 0.0174944 |
| w2 | 0.0315549 |
| e3d | 0.0605405 |
| ecf | 0.00130177 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.191403 |
| wallshear_a | 0.0957014 |
| wallshear_b | -0.0957014 |
| dissipation | 0.191403 |
| I_total | 1.191403 |
| D_total | 1.191403 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 6 |
| Leading lambda | 0.03793383508390278 + 0.0i |
| Leading multiplier | 1.2088496143322094 + 0.0i |
| Leading residual | 0.008658983629292313 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| D | `<sxy, sztx>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx10_lz6/D/jkl_1_3_5/dns_findsoln/sol004/ubest.nc` | `on:sol004@J1K3L5` |
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx10_lz6/G/jkl_1_3_5/dns_findsoln/sol002/ubest.nc` | `on:sol002@J1K3L5;on:sol011@J1K3L5;ls:sol006@J2K4L5;ls:sol010@J1K3L5` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 71
- Re range: 273.64614 to 495.36254
- Input range: 1.1387864 to 1.307116

---
physical_id: "re300_lx10_lz6_013"
case: "re300_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 10.0
Lz: 6.0
shear: 0.5755
L2: 0.33369
groups: ["E"]
representative_group: "E"
representative_J: 3
representative_K: 5
representative_L: 11
has_dns_bifurcation: true
E3D: 0.0391387
dissipation: 0.5755
D_total: 1.5755
wall_shear: 0.5755
I_total: 1.5755
has_eigen_analysis: true
leading_lambda_re: 0.025981395226157833
leading_lambda_im: 0.0
n_unstable: 2
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx10_lz6_013

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.5755 |
| L2 | 0.33369 |
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
| L2 | 0.33369 |
| u2 | 0.470184 |
| v2 | 0.0122831 |
| w2 | 0.0383952 |
| e3d | 0.0391387 |
| ecf | 0.00162507 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.5755 |
| wallshear_a | 0.28775 |
| wallshear_b | -0.28775 |
| dissipation | 0.5755 |
| I_total | 1.5755 |
| D_total | 1.5755 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 2 |
| Leading lambda | 0.025981395226157833 + 0.0i |
| Leading multiplier | 1.1387224500292767 + 0.0i |
| Leading residual | 0.0003080975002275895 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx10_lz6/E/jkl_3_5_11/dns_findsoln/sol001/ubest.nc` | `on:sol001@J3K5L11;on:sol002@J2K4L9;on:sol005@J1K3L5;ls:sol001@J3K5L11;ls:sol003@J2K4L9` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 62
- Re range: 155.93832 to 509.62296
- Input range: 1.4886664 to 3.0257298

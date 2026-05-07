---
physical_id: "re300_lx10_lz6_003"
case: "re300_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 10.0
Lz: 6.0
shear: 0.211102
L2: 0.102108
groups: ["G"]
representative_group: "G"
representative_J: 2
representative_K: 4
representative_L: 5
has_dns_bifurcation: true
E3D: 0.0549206
dissipation: 0.211102
D_total: 1.211102
wall_shear: 0.211102
I_total: 1.211102
has_eigen_analysis: true
leading_lambda_re: 0.048718531303890665
leading_lambda_im: 0.0
n_unstable: 3
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx10_lz6_003

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.211102 |
| L2 | 0.102108 |
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
| L2 | 0.102108 |
| u2 | 0.140586 |
| v2 | 0.0128491 |
| w2 | 0.0303741 |
| e3d | 0.0549206 |
| ecf | 0.00108769 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.211102 |
| wallshear_a | 0.105551 |
| wallshear_b | -0.105551 |
| dissipation | 0.211102 |
| I_total | 1.211102 |
| D_total | 1.211102 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 3 |
| Leading lambda | 0.048718531303890665 + 0.0i |
| Leading multiplier | 1.2758245258242054 + 0.0i |
| Leading residual | 0.0007956638479949292 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx10_lz6/G/jkl_2_4_5/dns_findsoln/sol001/ubest.nc` | `on:sol001@J2K4L5;on:sol006@J1K3L5` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 66
- Re range: 240.46881 to 520.24917
- Input range: 1.1249168 to 2.8237243

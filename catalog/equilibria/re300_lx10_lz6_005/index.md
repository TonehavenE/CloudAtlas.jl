---
physical_id: "re300_lx10_lz6_005"
case: "re300_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 10.0
Lz: 6.0
shear: 0.269275
L2: 0.11686
groups: ["G"]
representative_group: "G"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: true
E3D: 0.0639457
dissipation: 0.269275
D_total: 1.269275
wall_shear: 0.269275
I_total: 1.269275
has_eigen_analysis: true
leading_lambda_re: 0.050888000556255975
leading_lambda_im: 0.0
n_unstable: 5
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx10_lz6_005

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.269275 |
| L2 | 0.11686 |
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
| L2 | 0.11686 |
| u2 | 0.160983 |
| v2 | 0.0155192 |
| w2 | 0.0340016 |
| e3d | 0.0639457 |
| ecf | 0.00139696 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.269275 |
| wallshear_a | 0.134637 |
| wallshear_b | -0.134637 |
| dissipation | 0.269275 |
| I_total | 1.269275 |
| D_total | 1.269275 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 5 |
| Leading lambda | 0.050888000556255975 + 0.0i |
| Leading multiplier | 1.2897391682589432 + 0.0i |
| Leading residual | 0.0016328051789578956 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx10_lz6/G/jkl_1_3_5/dns_findsoln/sol007/ubest.nc` | `on:sol007@J1K3L5` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 60
- Re range: 240.62965 to 500.21551
- Input range: 1.2290615 to 1.6050829

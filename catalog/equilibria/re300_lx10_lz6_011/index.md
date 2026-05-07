---
physical_id: "re300_lx10_lz6_011"
case: "re300_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 10.0
Lz: 6.0
shear: 0.504836
L2: 0.155965
groups: ["C"]
representative_group: "C"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: true
E3D: 0.0952538
dissipation: 0.504836
D_total: 1.504836
wall_shear: 0.504836
I_total: 1.504836
has_eigen_analysis: true
leading_lambda_re: 0.0665381753264706
leading_lambda_im: 0.0
n_unstable: 8
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx10_lz6_011

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.504836 |
| L2 | 0.155965 |
| Groups | `C` |

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
| L2 | 0.155965 |
| u2 | 0.213341 |
| v2 | 0.0260315 |
| w2 | 0.0495803 |
| e3d | 0.0952538 |
| ecf | 0.00313585 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.504836 |
| wallshear_a | 0.252418 |
| wallshear_b | -0.252418 |
| dissipation | 0.504836 |
| I_total | 1.504836 |
| D_total | 1.504836 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 8 |
| Leading lambda | 0.0665381753264706 + 0.0i |
| Leading multiplier | 1.3947160924898931 + 0.0i |
| Leading residual | 0.0024928498530617897 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| C | `<sxytz, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx10_lz6/C/jkl_1_3_5/dns_findsoln/sol006/ubest.nc` | `on:sol006@J1K3L5` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 65
- Re range: 254.36991 to 753.72978
- Input range: 1.3042408 to 1.7903211

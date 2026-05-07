---
physical_id: "re300_lx10_lz6_024"
case: "re300_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 10.0
Lz: 6.0
shear: 1.12265
L2: 0.249595
groups: ["D"]
representative_group: "D"
representative_J: 2
representative_K: 4
representative_L: 8
has_dns_bifurcation: true
E3D: 0.126493
dissipation: 1.12265
D_total: 2.12265
wall_shear: 1.12265
I_total: 2.12265
has_eigen_analysis: true
leading_lambda_re: 0.05752487370356121
leading_lambda_im: 0.0
n_unstable: 12
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx10_lz6_024

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 1.12265 |
| L2 | 0.249595 |
| Groups | `D` |

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
| L2 | 0.249595 |
| u2 | 0.336635 |
| v2 | 0.0649177 |
| w2 | 0.0840113 |
| e3d | 0.126493 |
| ecf | 0.0112722 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 1.12265 |
| wallshear_a | 0.561327 |
| wallshear_b | -0.561327 |
| dissipation | 1.12265 |
| I_total | 2.12265 |
| D_total | 2.12265 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 12 |
| Leading lambda | 0.05752487370356121 + 0.0i |
| Leading multiplier | 1.3332563969744868 + 0.0i |
| Leading residual | 0.05618710288115331 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| D | `<sxy, sztx>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx10_lz6/D/jkl_2_4_8/dns_findsoln/sol001/ubest.nc` | `on:sol001@J2K4L8` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 72
- Re range: 251.5061 to 439.40799
- Input range: 1.7378308 to 2.8789045

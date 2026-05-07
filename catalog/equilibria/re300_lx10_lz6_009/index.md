---
physical_id: "re300_lx10_lz6_009"
case: "re300_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 10.0
Lz: 6.0
shear: 0.385216
L2: 0.208333
groups: ["G"]
representative_group: "G"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: true
E3D: 0.0605405
dissipation: 0.191403
D_total: 1.191403
wall_shear: 0.191403
I_total: 1.191403
has_eigen_analysis: true
leading_lambda_re: 0.03807426708238502
leading_lambda_im: 0.0
n_unstable: 2
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx10_lz6_009

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.385216 |
| L2 | 0.208333 |
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
| Unstable count | 2 |
| Leading lambda | 0.03807426708238502 + 0.0i |
| Leading multiplier | 1.2096987182367447 + 0.0i |
| Leading residual | 3.778062434765746e-05 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re300_lx10_lz6/G/jkl_1_3_5/dns_findsoln/sol011/ubest.nc` | `ls:sol011@J1K3L5` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 66
- Re range: 224.21094 to 780.77291
- Input range: 1.2817676 to 4.0409315

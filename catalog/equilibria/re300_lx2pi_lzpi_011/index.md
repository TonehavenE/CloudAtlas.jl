---
physical_id: "re300_lx2pi_lzpi_011"
case: "re300_lx2pi_lzpi"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 6.283185307179586
Lz: 3.141592653589793
shear: 3.06133
L2: 0.391865
groups: ["F"]
representative_group: "F"
representative_J: 1
representative_K: 4
representative_L: 5
has_dns_bifurcation: true
E3D: 0.196406
dissipation: 4.06133
D_total: 5.06133
wall_shear: 4.06133
I_total: 5.06133
has_eigen_analysis: true
leading_lambda_re: 0.10799558135501958
leading_lambda_im: 0.0
n_unstable: 19
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx2pi_lzpi_011

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx2pi_lzpi` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 6.283185307179586 |
| Lz | 3.141592653589793 |
| Shear | 3.06133 |
| L2 | 0.391865 |
| Groups | `F` |

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
| L2 | 0.388195 |
| u2 | 0.502927 |
| v2 | 0.134928 |
| w2 | 0.173923 |
| e3d | 0.196406 |
| ecf | 0.0484546 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 4.06133 |
| wallshear_a | 2.03067 |
| wallshear_b | -2.03067 |
| dissipation | 4.06133 |
| I_total | 5.06133 |
| D_total | 5.06133 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 19 |
| Leading lambda | 0.10799558135501958 + 0.0i |
| Leading multiplier | 1.7159689504781162 + 0.0i |
| Leading residual | 2.238739984191434e-05 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| F | `<sxy, sz, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re300_lx2pi_lzpi/F/jkl_1_4_5/dns_findsoln/sol002/ubest.nc` | `ls:sol002@J1K4L5` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 87
- Re range: 244.89025 to 459.06693
- Input range: 1.6802107 to 4.8300609

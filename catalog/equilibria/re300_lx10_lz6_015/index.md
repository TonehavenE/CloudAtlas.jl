---
physical_id: "re300_lx10_lz6_015"
case: "re300_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 10.0
Lz: 6.0
shear: 0.692635
L2: 0.281618
groups: ["G"]
representative_group: "G"
representative_J: 2
representative_K: 4
representative_L: 6
has_dns_bifurcation: true
E3D: 0.09796
dissipation: 0.658194
D_total: 1.658194
wall_shear: 0.657376
I_total: 1.657376
has_eigen_analysis: true
leading_lambda_re: 0.0464456063839445
leading_lambda_im: 0.0
n_unstable: 4
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx10_lz6_015

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.692635 |
| L2 | 0.281618 |
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
| L2 | 0.191057 |
| u2 | 0.262357 |
| v2 | 0.0345904 |
| w2 | 0.054571 |
| e3d | 0.09796 |
| ecf | 0.00417449 |
| ubulk | 1.35823e-12 |
| wbulk | -1.89864e-14 |
| wallshear | 0.657376 |
| wallshear_a | 0.328688 |
| wallshear_b | -0.328688 |
| dissipation | 0.658194 |
| I_total | 1.657376 |
| D_total | 1.658194 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 4 |
| Leading lambda | 0.0464456063839445 + 0.0i |
| Leading multiplier | 1.261407337171789 + 0.0i |
| Leading residual | 0.07409636645183389 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re300_lx10_lz6/G/jkl_2_4_6/dns_findsoln/sol001/ubest.nc` | `ls:sol001@J2K4L6;ls:sol002@J2K4L5` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 86
- Re range: 180.2272 to 574.49095
- Input range: 1.6793912 to 3.0140401

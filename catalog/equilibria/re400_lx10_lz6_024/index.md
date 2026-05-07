---
physical_id: "re400_lx10_lz6_024"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 1.10926
L2: 0.223795
groups: ["A"]
representative_group: "A"
representative_J: 2
representative_K: 4
representative_L: 7
has_dns_bifurcation: false
E3D: 0.113607
dissipation: 2.10919
D_total: 3.10919
wall_shear: 2.10923
I_total: 3.10923
has_eigen_analysis: true
leading_lambda_re: 0.16728138040143758
leading_lambda_im: 0.0
n_unstable: 18
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_024

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 1.10926 |
| L2 | 0.223795 |
| Groups | `A` |

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
| L2 | 0.47048 |
| u2 | 0.659744 |
| v2 | 0.0438345 |
| w2 | 0.0742923 |
| e3d | 0.113607 |
| ecf | 0.00744081 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 2.10923 |
| wallshear_a | 1.05462 |
| wallshear_b | -1.05462 |
| dissipation | 2.10919 |
| I_total | 3.10923 |
| D_total | 3.10919 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 18 |
| Leading lambda | 0.16728138040143758 + 0.0i |
| Leading multiplier | 2.3080589779114993 + 0.0i |
| Leading residual | 0.017377708827053563 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| A | `<sxyz, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re400_lx10_lz6/A/jkl_2_4_7/dns_findsoln/sol003/ubest.nc` | `ls:sol003@J2K4L7` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

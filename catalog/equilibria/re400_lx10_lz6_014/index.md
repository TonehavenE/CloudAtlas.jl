---
physical_id: "re400_lx10_lz6_014"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 0.603132
L2: 0.26902
groups: ["A"]
representative_group: "A"
representative_J: 2
representative_K: 4
representative_L: 7
has_dns_bifurcation: true
E3D: 0.0224275
dissipation: 0.603132
D_total: 1.603132
wall_shear: 0.603132
I_total: 1.603132
has_eigen_analysis: true
leading_lambda_re: 0.047508697997450756
leading_lambda_im: 0.0
n_unstable: 2
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_014

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.603132 |
| L2 | 0.26902 |
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
| L2 | 0.26902 |
| u2 | 0.379529 |
| v2 | 0.0129464 |
| w2 | 0.0230921 |
| e3d | 0.0224275 |
| ecf | 0.000700853 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.603132 |
| wallshear_a | 0.301566 |
| wallshear_b | -0.301566 |
| dissipation | 0.603132 |
| I_total | 1.603132 |
| D_total | 1.603132 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 2 |
| Leading lambda | 0.047508697997450756 + 0.0i |
| Leading multiplier | 1.2681301465553891 + 0.0i |
| Leading residual | 0.0005318351381442448 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| A | `<sxyz, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/A/jkl_2_4_6/dns_findsoln/sol002/ubest.nc` | `on:sol002@J2K4L6;ls:sol001@J2K4L7;ls:sol004@J2K4L6` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 57
- Re range: 180.32022 to 574.92056
- Input range: 1.5598946 to 2.9722988

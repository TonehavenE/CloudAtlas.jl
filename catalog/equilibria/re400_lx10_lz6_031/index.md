---
physical_id: "re400_lx10_lz6_031"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 1.41046
L2: 0.309908
groups: ["C"]
representative_group: "C"
representative_J: 2
representative_K: 4
representative_L: 6
has_dns_bifurcation: false
E3D: 0.0949669
dissipation: 1.41046
D_total: 2.41046
wall_shear: 1.41046
I_total: 2.41046
has_eigen_analysis: true
leading_lambda_re: 0.11008249989338786
leading_lambda_im: 0.0
n_unstable: 19
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_031

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 1.41046 |
| L2 | 0.309908 |
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
| L2 | 0.309908 |
| u2 | 0.432451 |
| v2 | 0.0483841 |
| w2 | 0.0522654 |
| e3d | 0.0949669 |
| ecf | 0.0050727 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 1.41046 |
| wallshear_a | 0.70523 |
| wallshear_b | -0.70523 |
| dissipation | 1.41046 |
| I_total | 2.41046 |
| D_total | 2.41046 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 19 |
| Leading lambda | 0.11008249989338786 + 0.0i |
| Leading multiplier | 1.7339681312951503 + 0.0i |
| Leading residual | 0.000330467561540875 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| C | `<sxytz, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/C/jkl_2_4_6/dns_findsoln/sol006/ubest.nc` | `on:sol006@J2K4L6` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

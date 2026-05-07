---
physical_id: "re400_lx10_lz6_007"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 0.219208
L2: 0.0956772
groups: ["G"]
representative_group: "G"
representative_J: 1
representative_K: 4
representative_L: 5
has_dns_bifurcation: false
E3D: 0.0539565
dissipation: 0.219208
D_total: 1.219208
wall_shear: 0.219208
I_total: 1.219208
has_eigen_analysis: true
leading_lambda_re: 0.04669373954410978
leading_lambda_im: 0.0
n_unstable: 4
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_007

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.219208 |
| L2 | 0.0956772 |
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
| L2 | 0.0956772 |
| u2 | 0.132334 |
| v2 | 0.0113187 |
| w2 | 0.0258435 |
| e3d | 0.0539565 |
| ecf | 0.000796001 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.219208 |
| wallshear_a | 0.109604 |
| wallshear_b | -0.109604 |
| dissipation | 0.219208 |
| I_total | 1.219208 |
| D_total | 1.219208 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 4 |
| Leading lambda | 0.04669373954410978 + 0.0i |
| Leading multiplier | 1.262973293329188 + 0.0i |
| Leading residual | 0.057483913687384904 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/G/jkl_1_4_5/dns_findsoln/sol005/ubest.nc` | `on:sol005@J1K4L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

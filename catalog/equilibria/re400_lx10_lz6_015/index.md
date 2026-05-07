---
physical_id: "re400_lx10_lz6_015"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 0.638896
L2: 0.164839
groups: ["G"]
representative_group: "G"
representative_J: 2
representative_K: 4
representative_L: 5
has_dns_bifurcation: false
E3D: 0.105948
dissipation: 1.63002
D_total: 2.63002
wall_shear: 1.63347
I_total: 2.63347
has_eigen_analysis: true
leading_lambda_re: 0.08119311005981131
leading_lambda_im: 0.0
n_unstable: 14
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_015

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.638896 |
| L2 | 0.164839 |
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
| L2 | 0.503422 |
| u2 | 0.702564 |
| v2 | 0.0405142 |
| w2 | 0.107839 |
| e3d | 0.105948 |
| ecf | 0.0132706 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 1.63347 |
| wallshear_a | 0.816734 |
| wallshear_b | -0.816734 |
| dissipation | 1.63002 |
| I_total | 2.63347 |
| D_total | 2.63002 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 14 |
| Leading lambda | 0.08119311005981131 + 0.0i |
| Leading multiplier | 1.500750851149465 + 0.0i |
| Leading residual | 0.0010264335478464032 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re400_lx10_lz6/G/jkl_2_4_5/dns_findsoln/sol010/ubest.nc` | `ls:sol010@J2K4L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

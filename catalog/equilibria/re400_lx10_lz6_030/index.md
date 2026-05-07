---
physical_id: "re400_lx10_lz6_030"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 1.36828
L2: 0.279099
groups: ["E"]
representative_group: "E"
representative_J: 2
representative_K: 4
representative_L: 9
has_dns_bifurcation: false
E3D: 0.120134
dissipation: 2.36828
D_total: 3.36828
wall_shear: 2.36828
I_total: 3.36828
has_eigen_analysis: true
leading_lambda_re: 0.07410210623173184
leading_lambda_im: 0.0
n_unstable: 18
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_030

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 1.36828 |
| L2 | 0.279099 |
| Groups | `E` |

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
| L2 | 0.433736 |
| u2 | 0.604095 |
| v2 | 0.0663584 |
| w2 | 0.0831778 |
| e3d | 0.120134 |
| ecf | 0.011322 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 2.36828 |
| wallshear_a | 1.18414 |
| wallshear_b | -1.18414 |
| dissipation | 2.36828 |
| I_total | 3.36828 |
| D_total | 3.36828 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 18 |
| Leading lambda | 0.07410210623173184 + 0.0i |
| Leading multiplier | 1.44847391699596 + 0.0i |
| Leading residual | 0.07563972645659581 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re400_lx10_lz6/E/jkl_2_4_9/dns_findsoln/sol001/ubest.nc` | `ls:sol001@J2K4L9` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

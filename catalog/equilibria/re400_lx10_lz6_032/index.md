---
physical_id: "re400_lx10_lz6_032"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 1.90712
L2: 0.339282
groups: ["B"]
representative_group: "B"
representative_J: 2
representative_K: 4
representative_L: 5
has_dns_bifurcation: false
E3D: 0.0424292
dissipation: 0.283843
D_total: 1.283843
wall_shear: 0.283843
I_total: 1.283843
has_eigen_analysis: true
leading_lambda_re: 0.1401903081256621
leading_lambda_im: 0.0
n_unstable: 24
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_032

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 1.90712 |
| L2 | 0.339282 |
| Groups | `B` |

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
| L2 | 0.119763 |
| u2 | 0.166651 |
| v2 | 0.0118417 |
| w2 | 0.0278119 |
| e3d | 0.0424292 |
| ecf | 0.000913728 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.283843 |
| wallshear_a | 0.141922 |
| wallshear_b | -0.141922 |
| dissipation | 0.283843 |
| I_total | 1.283843 |
| D_total | 1.283843 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 24 |
| Leading lambda | 0.1401903081256621 + 0.0i |
| Leading multiplier | 2.0156697869318543 + 0.0i |
| Leading residual | 0.0001612254259266538 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| B | `<sxy, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re400_lx10_lz6/B/jkl_2_4_5/dns_findsoln/sol003/ubest.nc` | `ls:sol003@J2K4L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

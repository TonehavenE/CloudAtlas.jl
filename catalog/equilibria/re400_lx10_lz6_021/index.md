---
physical_id: "re400_lx10_lz6_021"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 1.01334
L2: 0.244266
groups: ["E"]
representative_group: "E"
representative_J: 2
representative_K: 4
representative_L: 8
has_dns_bifurcation: false
E3D: 0.0374886
dissipation: 0.909759
D_total: 1.909759
wall_shear: 0.843119
I_total: 1.843119
has_eigen_analysis: true
leading_lambda_re: 0.11429659034755618
leading_lambda_im: 0.008705254926753246
n_unstable: 9
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_021

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 1.01334 |
| L2 | 0.244266 |
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
| L2 | 0.275061 |
| u2 | 0.387105 |
| v2 | 0.0244332 |
| w2 | 0.0294878 |
| e3d | 0.0374886 |
| ecf | 0.00146651 |
| ubulk | 9.13276e-11 |
| wbulk | 1.05029e-13 |
| wallshear | 0.843119 |
| wallshear_a | 0.42156 |
| wallshear_b | -0.42156 |
| dissipation | 0.909759 |
| I_total | 1.843119 |
| D_total | 1.909759 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 9 |
| Leading lambda | 0.11429659034755618 + 0.008705254926753246i |
| Leading multiplier | 1.769214007125107 + 0.07705596268733997i |
| Leading residual | 0.023156882816480307 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re400_lx10_lz6/E/jkl_2_4_8/dns_findsoln/sol006/ubest.nc` | `ls:sol003@J1K4L5;ls:sol006@J2K4L8` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

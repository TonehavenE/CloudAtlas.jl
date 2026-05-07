---
physical_id: "re400_lx10_lz6_020"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 1.00971
L2: 0.237853
groups: ["C"]
representative_group: "C"
representative_J: 1
representative_K: 4
representative_L: 5
has_dns_bifurcation: false
E3D: 0.101245
dissipation: 2.00971
D_total: 3.00971
wall_shear: 2.00971
I_total: 3.00971
has_eigen_analysis: true
leading_lambda_re: 0.3514317674056567
leading_lambda_im: 0.03444056241134131
n_unstable: 20
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_020

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 1.00971 |
| L2 | 0.237853 |
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
| L2 | 0.487814 |
| u2 | 0.686385 |
| v2 | 0.0342867 |
| w2 | 0.0602176 |
| e3d | 0.101245 |
| ecf | 0.00480174 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 2.00971 |
| wallshear_a | 1.00486 |
| wallshear_b | -1.00486 |
| dissipation | 2.00971 |
| I_total | 3.00971 |
| D_total | 3.00971 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 20 |
| Leading lambda | 0.3514317674056567 + 0.03444056241134131i |
| Leading multiplier | 5.710222953336138 + 0.993152833587627i |
| Leading residual | 0.0015348683148500054 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| C | `<sxytz, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re400_lx10_lz6/C/jkl_1_4_5/dns_findsoln/sol003/ubest.nc` | `ls:sol003@J1K4L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

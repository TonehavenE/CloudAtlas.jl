---
physical_id: "re400_lx10_lz6_029"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 1.33606
L2: 0.294634
groups: ["C"]
representative_group: "C"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: false
E3D: 0.107342
dissipation: 1.33606
D_total: 2.33606
wall_shear: 1.33606
I_total: 2.33606
has_eigen_analysis: true
leading_lambda_re: 0.30349945597487354
leading_lambda_im: -0.006099985998178508
n_unstable: 19
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_029

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 1.33606 |
| L2 | 0.294634 |
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
| L2 | 0.294634 |
| u2 | 0.407999 |
| v2 | 0.0464736 |
| w2 | 0.0706811 |
| e3d | 0.107342 |
| ecf | 0.00715561 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 1.33606 |
| wallshear_a | 0.66803 |
| wallshear_b | -0.66803 |
| dissipation | 1.33606 |
| I_total | 2.33606 |
| D_total | 2.33606 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 19 |
| Leading lambda | 0.30349945597487354 + -0.006099985998178508i |
| Leading multiplier | 4.558675336209099 + -0.13908240821916218i |
| Leading residual | 0.002619768383447455 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| C | `<sxytz, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/C/jkl_1_3_5/dns_findsoln/sol009/ubest.nc` | `on:sol009@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

---
physical_id: "re400_lx10_lz6_012"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 0.419658
L2: 0.157738
groups: ["A", "B", "C", "E"]
representative_group: "A"
representative_J: 2
representative_K: 4
representative_L: 6
has_dns_bifurcation: false
E3D: 0.0418617
dissipation: 0.419658
D_total: 1.419658
wall_shear: 0.419658
I_total: 1.419658
has_eigen_analysis: true
leading_lambda_re: 0.16228823580410037
leading_lambda_im: 0.0
n_unstable: 11
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_012

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.419658 |
| L2 | 0.157738 |
| Groups | `A, B, C, E` |

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
| L2 | 0.157738 |
| u2 | 0.220261 |
| v2 | 0.0124314 |
| w2 | 0.033064 |
| e3d | 0.0418617 |
| ecf | 0.00124777 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.419658 |
| wallshear_a | 0.209829 |
| wallshear_b | -0.209829 |
| dissipation | 0.419658 |
| I_total | 1.419658 |
| D_total | 1.419658 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 11 |
| Leading lambda | 0.16228823580410037 + 0.0i |
| Leading multiplier | 2.251149960077783 + 0.0i |
| Leading residual | 6.174604638713583e-05 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| A | `<sxyz, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/A/jkl_2_4_6/dns_findsoln/sol001/ubest.nc` | `on:sol001@J2K4L6` |
| B | `<sxy, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re400_lx10_lz6/B/jkl_2_4_6/dns_findsoln/sol001/ubest.nc` | `ls:sol001@J2K4L6` |
| C | `<sxytz, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re400_lx10_lz6/C/jkl_2_4_6/dns_findsoln/sol001/ubest.nc` | `ls:sol001@J2K4L6` |
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/E/jkl_2_4_6/dns_findsoln/sol006/ubest.nc` | `on:sol006@J2K4L6` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

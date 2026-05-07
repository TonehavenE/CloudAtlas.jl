---
physical_id: "re400_lx10_lz6_004"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 0.151885
L2: 0.0843729
groups: ["G"]
representative_group: "G"
representative_J: 2
representative_K: 4
representative_L: 5
has_dns_bifurcation: false
E3D: 0.0369959
dissipation: 0.151884
D_total: 1.151884
wall_shear: 0.151885
I_total: 1.151885
has_eigen_analysis: true
leading_lambda_re: 0.05016983027920962
leading_lambda_im: 0.0
n_unstable: 3
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_004

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.151885 |
| L2 | 0.0843729 |
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
| L2 | 0.0843729 |
| u2 | 0.117439 |
| v2 | 0.00791307 |
| w2 | 0.019569 |
| e3d | 0.0369959 |
| ecf | 0.000445563 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.151885 |
| wallshear_a | 0.0759425 |
| wallshear_b | -0.0759425 |
| dissipation | 0.151884 |
| I_total | 1.151885 |
| D_total | 1.151884 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 3 |
| Leading lambda | 0.05016983027920962 + 0.0i |
| Leading multiplier | 1.2851162117224024 + 0.0i |
| Leading residual | 0.00010792860121686447 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/G/jkl_2_4_5/dns_findsoln/sol003/ubest.nc` | `on:sol003@J2K4L5;ls:sol001@J2K4L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

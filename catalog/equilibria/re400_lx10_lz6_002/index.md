---
physical_id: "re400_lx10_lz6_002"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 0.111429
L2: 0.0674867
groups: ["G"]
representative_group: "G"
representative_J: 2
representative_K: 4
representative_L: 5
has_dns_bifurcation: false
E3D: 0.0400788
dissipation: 0.111429
D_total: 1.111429
wall_shear: 0.111429
I_total: 1.111429
has_eigen_analysis: true
leading_lambda_re: 0.033811929183874344
leading_lambda_im: 0.0
n_unstable: 4
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_002

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.111429 |
| L2 | 0.0674867 |
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
| L2 | 0.0674867 |
| u2 | 0.0932006 |
| v2 | 0.00877493 |
| w2 | 0.018589 |
| e3d | 0.0400788 |
| ecf | 0.00042255 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.111429 |
| wallshear_a | 0.0557145 |
| wallshear_b | -0.0557145 |
| dissipation | 0.111429 |
| I_total | 1.111429 |
| D_total | 1.111429 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 4 |
| Leading lambda | 0.033811929183874344 + 0.0i |
| Leading multiplier | 1.184190768964678 + 0.0i |
| Leading residual | 0.0005842484842474539 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/G/jkl_2_4_5/dns_findsoln/sol002/ubest.nc` | `on:sol002@J2K4L5;on:sol009@J1K4L5;ls:sol006@J1K4L5;ls:sol012@J2K4L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

---
physical_id: "re400_lx10_lz6_027"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 1.30284
L2: 0.251724
groups: ["F"]
representative_group: "F"
representative_J: 2
representative_K: 4
representative_L: 8
has_dns_bifurcation: false
E3D: 0.093364
dissipation: 1.30284
D_total: 2.3028399999999998
wall_shear: 1.30284
I_total: 2.3028399999999998
has_eigen_analysis: true
leading_lambda_re: 0.22271793604240353
leading_lambda_im: 0.0
n_unstable: 26
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_027

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 1.30284 |
| L2 | 0.251724 |
| Groups | `F` |

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
| L2 | 0.251724 |
| u2 | 0.344944 |
| v2 | 0.0396947 |
| w2 | 0.0785366 |
| e3d | 0.093364 |
| ecf | 0.00774367 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 1.30284 |
| wallshear_a | 0.651421 |
| wallshear_b | -0.651421 |
| dissipation | 1.30284 |
| I_total | 2.3028399999999998 |
| D_total | 2.3028399999999998 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 26 |
| Leading lambda | 0.22271793604240353 + 0.0i |
| Leading multiplier | 3.045270344208002 + 0.0i |
| Leading residual | 0.061614186624712367 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| F | `<sxy, sz, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/F/jkl_2_4_8/dns_findsoln/sol001/ubest.nc` | `on:sol001@J2K4L8` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

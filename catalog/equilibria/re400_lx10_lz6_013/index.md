---
physical_id: "re400_lx10_lz6_013"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 0.507104
L2: 0.320622
groups: ["E", "G"]
representative_group: "E"
representative_J: 2
representative_K: 4
representative_L: 8
has_dns_bifurcation: false
E3D: 0.029342
dissipation: 0.507104
D_total: 1.507104
wall_shear: 0.507104
I_total: 1.507104
has_eigen_analysis: true
leading_lambda_re: 0.026388325279835607
leading_lambda_im: 0.0
n_unstable: 2
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_013

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.507104 |
| L2 | 0.320622 |
| Groups | `E, G` |

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
| L2 | 0.320622 |
| u2 | 0.452532 |
| v2 | 0.00879002 |
| w2 | 0.0270882 |
| e3d | 0.029342 |
| ecf | 0.000811036 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.507104 |
| wallshear_a | 0.253552 |
| wallshear_b | -0.253552 |
| dissipation | 0.507104 |
| I_total | 1.507104 |
| D_total | 1.507104 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 2 |
| Leading lambda | 0.026388325279835607 + 0.0i |
| Leading multiplier | 1.141041710609824 + 0.0i |
| Leading residual | 0.003357258766345256 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/E/jkl_2_4_8/dns_findsoln/sol003/ubest.nc` | `on:sol003@J2K4L8;on:sol008@J2K4L6;ls:sol005@J2K4L8` |
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/G/jkl_1_3_5/dns_findsoln/sol008/ubest.nc` | `on:sol008@J1K3L5;ls:sol013@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

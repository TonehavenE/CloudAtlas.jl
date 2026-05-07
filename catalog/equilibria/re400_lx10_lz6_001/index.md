---
physical_id: "re400_lx10_lz6_001"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 1.10851e-13
L2: 3.4691e-14
groups: ["A", "C", "E", "G"]
representative_group: "E"
representative_J: 2
representative_K: 4
representative_L: 9
has_dns_bifurcation: false
E3D: 9.11918e-16
dissipation: 7.36417e-27
D_total: 1.0
wall_shear: 7.34014e-14
I_total: 1.0000000000000735
has_eigen_analysis: true
leading_lambda_re: -0.008964793679996813
leading_lambda_im: 0.0
n_unstable: 0
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_001

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 1.10851e-13 |
| L2 | 3.4691e-14 |
| Groups | `A, C, E, G` |

## Literature

No literature mapping recorded yet.

## Possible Same Branch

No cross-parameter ODE deduplication candidate recorded yet.

## Representative Files

- ODE coefficients: [representative.asc](representative.asc)
- DNS flowfield: [ubest.nc](ubest.nc)

## DNS Diagnostics

| Quantity | Value |
|---|---:|
| L2 | 2.69968e-14 |
| u2 | 3.8163e-14 |
| v2 | 5.92777e-16 |
| w2 | 9.4114e-16 |
| e3d | 9.11918e-16 |
| ecf | 1.23713e-30 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 7.34014e-14 |
| wallshear_a | 3.74411e-14 |
| wallshear_b | -3.59603e-14 |
| dissipation | 7.36417e-27 |
| I_total | 1.0000000000000735 |
| D_total | 1.0 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 0 |
| Leading lambda | -0.008964793679996813 + 0.0i |
| Leading multiplier | 0.9561657824121137 + 0.0i |
| Leading residual | 0.0010502334973732244 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| A | `<sxyz, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re400_lx10_lz6/A/jkl_2_4_5/dns_findsoln/sol002/ubest.nc` | `ls:sol002@J2K4L5` |
| C | `<sxytz, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re400_lx10_lz6/C/jkl_2_4_6/dns_findsoln/sol002/ubest.nc` | `ls:sol002@J2K4L6` |
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/E/jkl_2_4_9/dns_findsoln/sol004/ubest.nc` | `on:sol004@J2K4L9;on:sol007@J2K4L6;ls:sol002@J2K4L9;ls:sol004@J2K4L8` |
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/G/jkl_2_4_5/dns_findsoln/sol001/ubest.nc` | `on:sol001@J2K4L5;ls:sol002@J2K4L5;ls:sol005@J2K4L5;ls:sol016@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

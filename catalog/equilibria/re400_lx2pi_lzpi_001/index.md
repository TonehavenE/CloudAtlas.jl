---
physical_id: "re400_lx2pi_lzpi_001"
case: "re400_lx2pi_lzpi"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 6.283185307179586
Lz: 3.141592653589793
shear: 8.26677e-13
L2: 4.53974e-13
groups: ["A", "B", "C", "G"]
representative_group: "A"
representative_J: 2
representative_K: 4
representative_L: 6
has_dns_bifurcation: false
E3D: 5.91799e-14
dissipation: 1.4944e-24
D_total: 1.0
wall_shear: 8.4137e-13
I_total: 1.0000000000008413
has_eigen_analysis: true
leading_lambda_re: -0.006168519090076506
leading_lambda_im: 0.0
n_unstable: 0
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx2pi_lzpi_001

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx2pi_lzpi` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 6.283185307179586 |
| Lz | 3.141592653589793 |
| Shear | 8.26677e-13 |
| L2 | 4.53974e-13 |
| Groups | `A, B, C, G` |

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
| L2 | 2.23707e-13 |
| u2 | 3.13831e-13 |
| v2 | 6.22037e-15 |
| w2 | 3.95023e-14 |
| e3d | 5.91799e-14 |
| ecf | 1.59912e-27 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 8.4137e-13 |
| wallshear_a | 4.14039e-13 |
| wallshear_b | -4.27331e-13 |
| dissipation | 1.4944e-24 |
| I_total | 1.0000000000008413 |
| D_total | 1.0 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 0 |
| Leading lambda | -0.006168519090076506 + 0.0i |
| Leading multiplier | 0.9696281849525579 + 0.0i |
| Leading residual | 5.182528200782377e-05 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| A | `<sxyz, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx2pi_lzpi/A/jkl_2_4_6/dns_findsoln/sol001/ubest.nc` | `on:sol001@J2K4L6;on:sol002@J2K4L5;ls:sol001@J2K4L6;ls:sol003@J2K4L5` |
| B | `<sxy, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx2pi_lzpi/B/jkl_2_4_5/dns_findsoln/sol002/ubest.nc` | `on:sol002@J2K4L5` |
| C | `<sxytz, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx2pi_lzpi/C/jkl_2_4_5/dns_findsoln/sol002/ubest.nc` | `on:sol002@J2K4L5;on:sol003@J2K4L5;ls:sol002@J2K4L5` |
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx2pi_lzpi/G/jkl_1_4_5/dns_findsoln/sol004/ubest.nc` | `on:sol004@J1K4L5;on:sol005@J1K3L5;on:sol006@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

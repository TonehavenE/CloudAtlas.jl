---
physical_id: "hkw_re400_alpha1p14_gamma1p67_low_shear_008"
case: "hkw_re400_alpha1p14_gamma1p67_low_shear"
catalog_source: "stress:minimal_low_shear"
Re: 400.0
Lx: 5.511566576198634
Lz: 3.762386411812926
shear: 1.42478
L2: 0.290936
groups: ["E"]
representative_group: "E"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: false
E3D: 0.0920756
dissipation: 1.42478
D_total: 2.42478
wall_shear: 1.42478
I_total: 2.42478
has_eigen_analysis: true
leading_lambda_re: 0.05501352332423955
leading_lambda_im: -0.2476181783868807
n_unstable: 16
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# hkw_re400_alpha1p14_gamma1p67_low_shear_008

## Summary

| Quantity | Value |
|---|---:|
| Case | `hkw_re400_alpha1p14_gamma1p67_low_shear` |
| Catalog source | `stress:minimal_low_shear` |
| Re | 400.0 |
| Lx | 5.511566576198634 |
| Lz | 3.762386411812926 |
| Shear | 1.42478 |
| L2 | 0.290936 |
| Groups | `E` |

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
| L2 | 0.290936 |
| u2 | 0.398504 |
| v2 | 0.0597982 |
| w2 | 0.0831053 |
| e3d | 0.0920756 |
| ecf | 0.0104823 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 1.42478 |
| wallshear_a | 0.712392 |
| wallshear_b | -0.712392 |
| dissipation | 1.42478 |
| I_total | 2.42478 |
| D_total | 2.42478 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 16 |
| Leading lambda | 0.05501352332423955 + -0.2476181783868807i |
| Leading multiplier | 0.43000969855010407 + -1.244419176280785i |
| Leading residual | 0.01662326836296301 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/hkw_re400_alpha1p14_gamma1p67_low_shear/E/jkl_1_3_5/dns_findsoln/sol002/ubest.nc` | `ls:sol002@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

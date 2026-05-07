---
physical_id: "hkw_re400_alpha1p14_gamma1p67_low_shear_004"
case: "hkw_re400_alpha1p14_gamma1p67_low_shear"
catalog_source: "stress:minimal_low_shear"
Re: 400.0
Lx: 5.511566576198634
Lz: 3.762386411812926
shear: 0.36718
L2: 0.126947
groups: ["G"]
representative_group: "G"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: false
E3D: 0.0406223
dissipation: 0.36718
D_total: 1.36718
wall_shear: 0.36718
I_total: 1.36718
has_eigen_analysis: true
leading_lambda_re: 0.06273747712305446
leading_lambda_im: 0.0
n_unstable: 3
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# hkw_re400_alpha1p14_gamma1p67_low_shear_004

## Summary

| Quantity | Value |
|---|---:|
| Case | `hkw_re400_alpha1p14_gamma1p67_low_shear` |
| Catalog source | `stress:minimal_low_shear` |
| Re | 400.0 |
| Lx | 5.511566576198634 |
| Lz | 3.762386411812926 |
| Shear | 0.36718 |
| L2 | 0.126947 |
| Groups | `G` |

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
| L2 | 0.126947 |
| u2 | 0.176991 |
| v2 | 0.0150157 |
| w2 | 0.0260725 |
| e3d | 0.0406223 |
| ecf | 0.000905245 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.36718 |
| wallshear_a | 0.18359 |
| wallshear_b | -0.18359 |
| dissipation | 0.36718 |
| I_total | 1.36718 |
| D_total | 1.36718 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 3 |
| Leading lambda | 0.06273747712305446 + 0.0i |
| Leading multiplier | 1.3684618688069146 + 0.0i |
| Leading residual | 2.306778233395075e-06 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/hkw_re400_alpha1p14_gamma1p67_low_shear/G/jkl_1_3_5/dns_findsoln/sol005/ubest.nc` | `ls:sol005@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

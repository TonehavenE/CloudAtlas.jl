---
physical_id: "hkw_re400_alpha1p14_gamma1p67_low_shear_011"
case: "hkw_re400_alpha1p14_gamma1p67_low_shear"
catalog_source: "stress:minimal_low_shear"
Re: 400.0
Lx: 5.511566576198634
Lz: 3.762386411812926
shear: 3.23941
L2: 0.399869
groups: ["B", "F"]
representative_group: "B"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: false
E3D: 0.131473
dissipation: 3.23941
D_total: 4.2394099999999995
wall_shear: 3.23941
I_total: 4.2394099999999995
has_eigen_analysis: true
leading_lambda_re: 0.16833172792879933
leading_lambda_im: -0.348025552300014
n_unstable: 24
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# hkw_re400_alpha1p14_gamma1p67_low_shear_011

## Summary

| Quantity | Value |
|---|---:|
| Case | `hkw_re400_alpha1p14_gamma1p67_low_shear` |
| Catalog source | `stress:minimal_low_shear` |
| Re | 400.0 |
| Lx | 5.511566576198634 |
| Lz | 3.762386411812926 |
| Shear | 3.23941 |
| L2 | 0.399869 |
| Groups | `B, F` |

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
| L2 | 0.399869 |
| u2 | 0.540294 |
| v2 | 0.108201 |
| w2 | 0.127145 |
| e3d | 0.131473 |
| ecf | 0.0278733 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 3.23941 |
| wallshear_a | 1.6197 |
| wallshear_b | -1.6197 |
| dissipation | 3.23941 |
| I_total | 4.2394099999999995 |
| D_total | 4.2394099999999995 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 24 |
| Leading lambda | 0.16833172792879933 + -0.348025552300014i |
| Leading multiplier | -0.39101000758261384 + -2.2870277102959364i |
| Leading residual | 2.561395000539748e-07 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| B | `<sxy, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/hkw_re400_alpha1p14_gamma1p67_low_shear/B/jkl_1_3_5/dns_findsoln/sol008/ubest.nc` | `ls:sol008@J1K3L5` |
| F | `<sxy, sz, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/hkw_re400_alpha1p14_gamma1p67_low_shear/F/jkl_1_3_5/dns_findsoln/sol002/ubest.nc` | `ls:sol002@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

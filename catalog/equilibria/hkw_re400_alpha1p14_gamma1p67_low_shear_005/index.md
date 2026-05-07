---
physical_id: "hkw_re400_alpha1p14_gamma1p67_low_shear_005"
case: "hkw_re400_alpha1p14_gamma1p67_low_shear"
catalog_source: "stress:minimal_low_shear"
Re: 400.0
Lx: 5.511566576198634
Lz: 3.762386411812926
shear: 0.482404
L2: 0.150856
groups: ["B"]
representative_group: "B"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: false
E3D: 0.0597876
dissipation: 0.482403
D_total: 1.4824030000000001
wall_shear: 0.482404
I_total: 1.482404
has_eigen_analysis: true
leading_lambda_re: 0.07222909705412318
leading_lambda_im: 0.0
n_unstable: 7
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# hkw_re400_alpha1p14_gamma1p67_low_shear_005

## Summary

| Quantity | Value |
|---|---:|
| Case | `hkw_re400_alpha1p14_gamma1p67_low_shear` |
| Catalog source | `stress:minimal_low_shear` |
| Re | 400.0 |
| Lx | 5.511566576198634 |
| Lz | 3.762386411812926 |
| Shear | 0.482404 |
| L2 | 0.150856 |
| Groups | `B` |

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
| L2 | 0.150856 |
| u2 | 0.208375 |
| v2 | 0.0236574 |
| w2 | 0.0391811 |
| e3d | 0.0597876 |
| ecf | 0.00209483 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.482404 |
| wallshear_a | 0.241202 |
| wallshear_b | -0.241202 |
| dissipation | 0.482403 |
| I_total | 1.482404 |
| D_total | 1.4824030000000001 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 7 |
| Leading lambda | 0.07222909705412318 + 0.0i |
| Leading multiplier | 1.434972213013744 + 0.0i |
| Leading residual | 1.225042953472024e-05 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| B | `<sxy, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/hkw_re400_alpha1p14_gamma1p67_low_shear/B/jkl_1_3_5/dns_findsoln/sol003/ubest.nc` | `ls:sol003@J1K3L5;ls:sol005@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

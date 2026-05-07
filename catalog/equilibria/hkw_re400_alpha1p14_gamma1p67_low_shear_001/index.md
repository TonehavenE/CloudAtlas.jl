---
physical_id: "hkw_re400_alpha1p14_gamma1p67_low_shear_001"
case: "hkw_re400_alpha1p14_gamma1p67_low_shear"
catalog_source: "stress:minimal_low_shear"
Re: 400.0
Lx: 5.511566576198634
Lz: 3.762386411812926
shear: 6.77947e-13
L2: 1.42951e-13
groups: ["A", "E", "G"]
representative_group: "A"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: false
E3D: 1.39085e-14
dissipation: 3.02519e-25
D_total: 1.0
wall_shear: 6.77947e-13
I_total: 1.000000000000678
has_eigen_analysis: true
leading_lambda_re: -0.006168512017457498
leading_lambda_im: 0.0
n_unstable: 0
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# hkw_re400_alpha1p14_gamma1p67_low_shear_001

## Summary

| Quantity | Value |
|---|---:|
| Case | `hkw_re400_alpha1p14_gamma1p67_low_shear` |
| Catalog source | `stress:minimal_low_shear` |
| Re | 400.0 |
| Lx | 5.511566576198634 |
| Lz | 3.762386411812926 |
| Shear | 6.77947e-13 |
| L2 | 1.42951e-13 |
| Groups | `A, E, G` |

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
| L2 | 1.42951e-13 |
| u2 | 2.01637e-13 |
| v2 | 8.74133e-15 |
| w2 | 1.16604e-14 |
| e3d | 1.39085e-14 |
| ecf | 2.12376e-28 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 6.77947e-13 |
| wallshear_a | 3.48189e-13 |
| wallshear_b | -3.29758e-13 |
| dissipation | 3.02519e-25 |
| I_total | 1.000000000000678 |
| D_total | 1.0 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 0 |
| Leading lambda | -0.006168512017457498 + 0.0i |
| Leading multiplier | 0.9696282192416121 + 0.0i |
| Leading residual | 8.438308596330795e-05 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| A | `<sxyz, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/hkw_re400_alpha1p14_gamma1p67_low_shear/A/jkl_1_3_5/dns_findsoln/sol001/ubest.nc` | `ls:sol001@J1K3L5` |
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/hkw_re400_alpha1p14_gamma1p67_low_shear/E/jkl_1_3_5/dns_findsoln/sol003/ubest.nc` | `ls:sol003@J1K3L5` |
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/hkw_re400_alpha1p14_gamma1p67_low_shear/G/jkl_1_3_5/dns_findsoln/sol002/ubest.nc` | `ls:sol002@J1K3L5;ls:sol007@J1K3L5;ls:sol008@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

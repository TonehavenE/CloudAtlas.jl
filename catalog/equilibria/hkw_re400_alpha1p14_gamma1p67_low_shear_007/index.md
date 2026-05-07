---
physical_id: "hkw_re400_alpha1p14_gamma1p67_low_shear_007"
case: "hkw_re400_alpha1p14_gamma1p67_low_shear"
catalog_source: "stress:minimal_low_shear"
Re: 400.0
Lx: 5.511566576198634
Lz: 3.762386411812926
shear: 1.12484
L2: 0.237463
groups: ["A", "B", "C", "D", "F"]
representative_group: "A"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: false
E3D: 0.0729475
dissipation: 1.12484
D_total: 2.12484
wall_shear: 1.12484
I_total: 2.12484
has_eigen_analysis: true
leading_lambda_re: 0.07532178794046676
leading_lambda_im: 0.0
n_unstable: 11
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# hkw_re400_alpha1p14_gamma1p67_low_shear_007

## Summary

| Quantity | Value |
|---|---:|
| Case | `hkw_re400_alpha1p14_gamma1p67_low_shear` |
| Catalog source | `stress:minimal_low_shear` |
| Re | 400.0 |
| Lx | 5.511566576198634 |
| Lz | 3.762386411812926 |
| Shear | 1.12484 |
| L2 | 0.237463 |
| Groups | `A, B, C, D, F` |

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
| L2 | 0.237463 |
| u2 | 0.329601 |
| v2 | 0.0393802 |
| w2 | 0.0508916 |
| e3d | 0.0729475 |
| ecf | 0.00414076 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 1.12484 |
| wallshear_a | 0.562421 |
| wallshear_b | -0.562421 |
| dissipation | 1.12484 |
| I_total | 2.12484 |
| D_total | 2.12484 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 11 |
| Leading lambda | 0.07532178794046676 + 0.0i |
| Leading multiplier | 1.4573342923408135 + 0.0i |
| Leading residual | 0.003933024551780344 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| A | `<sxyz, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/hkw_re400_alpha1p14_gamma1p67_low_shear/A/jkl_1_3_5/dns_findsoln/sol006/ubest.nc` | `ls:sol006@J1K3L5` |
| B | `<sxy, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/hkw_re400_alpha1p14_gamma1p67_low_shear/B/jkl_1_3_5/dns_findsoln/sol006/ubest.nc` | `ls:sol006@J1K3L5` |
| C | `<sxytz, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/hkw_re400_alpha1p14_gamma1p67_low_shear/C/jkl_1_3_5/dns_findsoln/sol002/ubest.nc` | `ls:sol002@J1K3L5` |
| D | `<sxy, sztx>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/hkw_re400_alpha1p14_gamma1p67_low_shear/D/jkl_1_3_5/dns_findsoln/sol004/ubest.nc` | `ls:sol004@J1K3L5` |
| F | `<sxy, sz, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/hkw_re400_alpha1p14_gamma1p67_low_shear/F/jkl_1_3_5/dns_findsoln/sol001/ubest.nc` | `ls:sol001@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

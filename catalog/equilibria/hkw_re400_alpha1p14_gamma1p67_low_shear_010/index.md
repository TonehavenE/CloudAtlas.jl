---
physical_id: "hkw_re400_alpha1p14_gamma1p67_low_shear_010"
case: "hkw_re400_alpha1p14_gamma1p67_low_shear"
catalog_source: "stress:minimal_low_shear"
Re: 400.0
Lx: 5.511566576198634
Lz: 3.762386411812926
shear: 1.66994
L2: 0.311244
groups: ["A"]
representative_group: "A"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: false
E3D: 0.113237
dissipation: 1.66958
D_total: 2.66958
wall_shear: 1.66994
I_total: 2.66994
has_eigen_analysis: true
leading_lambda_re: 0.08708645285409371
leading_lambda_im: 0.30524348377998056
n_unstable: 22
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# hkw_re400_alpha1p14_gamma1p67_low_shear_010

## Summary

| Quantity | Value |
|---|---:|
| Case | `hkw_re400_alpha1p14_gamma1p67_low_shear` |
| Catalog source | `stress:minimal_low_shear` |
| Re | 400.0 |
| Lx | 5.511566576198634 |
| Lz | 3.762386411812926 |
| Shear | 1.66994 |
| L2 | 0.311244 |
| Groups | `A` |

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
| L2 | 0.311244 |
| u2 | 0.419869 |
| v2 | 0.0731417 |
| w2 | 0.110029 |
| e3d | 0.113237 |
| ecf | 0.0174561 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 1.66994 |
| wallshear_a | 0.834971 |
| wallshear_b | -0.834971 |
| dissipation | 1.66958 |
| I_total | 2.66994 |
| D_total | 2.66958 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 22 |
| Leading lambda | 0.08708645285409371 + 0.30524348377998056i |
| Leading multiplier | 0.06887972441505372 + 1.5440954898915664i |
| Leading residual | 0.000331652707185082 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| A | `<sxyz, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/hkw_re400_alpha1p14_gamma1p67_low_shear/A/jkl_1_3_5/dns_findsoln/sol005/ubest.nc` | `ls:sol005@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

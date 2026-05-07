---
physical_id: "hkw_re400_alpha1p14_gamma1p67_low_shear_006"
case: "hkw_re400_alpha1p14_gamma1p67_low_shear"
catalog_source: "stress:minimal_low_shear"
Re: 400.0
Lx: 5.511566576198634
Lz: 3.762386411812926
shear: 0.735398
L2: 0.190023
groups: ["B"]
representative_group: "B"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: false
E3D: 0.0696988
dissipation: 0.735397
D_total: 1.7353969999999999
wall_shear: 0.735398
I_total: 1.735398
has_eigen_analysis: true
leading_lambda_re: 0.11854833800266934
leading_lambda_im: 0.0
n_unstable: 11
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# hkw_re400_alpha1p14_gamma1p67_low_shear_006

## Summary

| Quantity | Value |
|---|---:|
| Case | `hkw_re400_alpha1p14_gamma1p67_low_shear` |
| Catalog source | `stress:minimal_low_shear` |
| Re | 400.0 |
| Lx | 5.511566576198634 |
| Lz | 3.762386411812926 |
| Shear | 0.735398 |
| L2 | 0.190023 |
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
| L2 | 0.190023 |
| u2 | 0.261864 |
| v2 | 0.0344128 |
| w2 | 0.0496047 |
| e3d | 0.0696988 |
| ecf | 0.00364486 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.735398 |
| wallshear_a | 0.367699 |
| wallshear_b | -0.367699 |
| dissipation | 0.735397 |
| I_total | 1.735398 |
| D_total | 1.7353969999999999 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 11 |
| Leading lambda | 0.11854833800266934 + 0.0i |
| Leading multiplier | 1.8089411787890735 + 0.0i |
| Leading residual | 0.00026439802807827186 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| B | `<sxy, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/hkw_re400_alpha1p14_gamma1p67_low_shear/B/jkl_1_3_5/dns_findsoln/sol004/ubest.nc` | `ls:sol004@J1K3L5;ls:sol007@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

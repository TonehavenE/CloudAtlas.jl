---
physical_id: "hkw_re400_alpha1p14_gamma1p67_low_shear_009"
case: "hkw_re400_alpha1p14_gamma1p67_low_shear"
catalog_source: "stress:minimal_low_shear"
Re: 400.0
Lx: 5.511566576198634
Lz: 3.762386411812926
shear: 1.47553
L2: 0.288577
groups: ["A"]
representative_group: "A"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: false
E3D: 0.0957699
dissipation: 1.47548
D_total: 2.47548
wall_shear: 1.47553
I_total: 2.47553
has_eigen_analysis: true
leading_lambda_re: 0.09647880976278128
leading_lambda_im: -0.298342994211364
n_unstable: 18
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# hkw_re400_alpha1p14_gamma1p67_low_shear_009

## Summary

| Quantity | Value |
|---|---:|
| Case | `hkw_re400_alpha1p14_gamma1p67_low_shear` |
| Catalog source | `stress:minimal_low_shear` |
| Re | 400.0 |
| Lx | 5.511566576198634 |
| Lz | 3.762386411812926 |
| Shear | 1.47553 |
| L2 | 0.288577 |
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
| L2 | 0.288577 |
| u2 | 0.394782 |
| v2 | 0.0591806 |
| w2 | 0.08484 |
| e3d | 0.0957699 |
| ecf | 0.0107002 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 1.47553 |
| wallshear_a | 0.737764 |
| wallshear_b | -0.737764 |
| dissipation | 1.47548 |
| I_total | 2.47553 |
| D_total | 2.47548 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 18 |
| Leading lambda | 0.09647880976278128 + -0.298342994211364i |
| Leading multiplier | 0.12797419772728344 + -1.6148851728174023i |
| Leading residual | 4.1217690721876026e-05 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| A | `<sxyz, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/hkw_re400_alpha1p14_gamma1p67_low_shear/A/jkl_1_3_5/dns_findsoln/sol004/ubest.nc` | `ls:sol004@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

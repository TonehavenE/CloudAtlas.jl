---
physical_id: "ghc_re400_alpha1p14_gamma2p5_low_shear_001"
case: "ghc_re400_alpha1p14_gamma2p5_low_shear"
catalog_source: "stress:minimal_low_shear"
Re: 400.0
Lx: 5.511566576198634
Lz: 2.5132741228718345
shear: 6.96834e-13
L2: 7.22402e-13
groups: ["C", "G"]
representative_group: "C"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: false
E3D: 3.72055e-15
dissipation: 4.59416e-24
D_total: 1.0
wall_shear: 6.96834e-13
I_total: 1.0000000000006968
has_eigen_analysis: true
leading_lambda_re: -0.00616850051102296
leading_lambda_im: 0.0
n_unstable: 0
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# ghc_re400_alpha1p14_gamma2p5_low_shear_001

## Summary

| Quantity | Value |
|---|---:|
| Case | `ghc_re400_alpha1p14_gamma2p5_low_shear` |
| Catalog source | `stress:minimal_low_shear` |
| Re | 400.0 |
| Lx | 5.511566576198634 |
| Lz | 2.5132741228718345 |
| Shear | 6.96834e-13 |
| L2 | 7.22402e-13 |
| Groups | `C, G` |

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
| L2 | 7.22402e-13 |
| u2 | 1.02114e-12 |
| v2 | 2.59363e-14 |
| w2 | 1.81549e-14 |
| e3d | 3.72055e-15 |
| ecf | 1.00229e-27 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 6.96834e-13 |
| wallshear_a | 3.47963e-13 |
| wallshear_b | -3.48872e-13 |
| dissipation | 4.59416e-24 |
| I_total | 1.0000000000006968 |
| D_total | 1.0 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 0 |
| Leading lambda | -0.00616850051102296 + 0.0i |
| Leading multiplier | 0.9696282750264319 + 0.0i |
| Leading residual | 4.2900960785209365e-06 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| C | `<sxytz, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/ghc_re400_alpha1p14_gamma2p5_low_shear/C/jkl_1_3_5/dns_findsoln/sol002/ubest.nc` | `ls:sol002@J1K3L5` |
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/ghc_re400_alpha1p14_gamma2p5_low_shear/G/jkl_1_3_5/dns_findsoln/sol001/ubest.nc` | `ls:sol001@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

---
physical_id: "ghc_re400_alpha1p14_gamma2p5_low_shear_006"
case: "ghc_re400_alpha1p14_gamma2p5_low_shear"
catalog_source: "stress:minimal_low_shear"
Re: 400.0
Lx: 5.511566576198634
Lz: 2.5132741228718345
shear: 1.01997
L2: 0.218634
groups: ["E"]
representative_group: "E"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: false
E3D: 0.0928209
dissipation: 1.01997
D_total: 2.01997
wall_shear: 1.01997
I_total: 2.01997
has_eigen_analysis: true
leading_lambda_re: 0.07194190593383656
leading_lambda_im: 0.04080060218078903
n_unstable: 9
has_literature_mapping: true
literature: "GHC, 2008, EQ5"
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# ghc_re400_alpha1p14_gamma2p5_low_shear_006

## Summary

| Quantity | Value |
|---|---:|
| Case | `ghc_re400_alpha1p14_gamma2p5_low_shear` |
| Catalog source | `stress:minimal_low_shear` |
| Re | 400.0 |
| Lx | 5.511566576198634 |
| Lz | 2.5132741228718345 |
| Shear | 1.01997 |
| L2 | 0.218634 |
| Groups | `E` |

## Literature

| Appearance | Paper | Notes |
|---|---|---|
| `GHC, 2008, EQ5` | Gibson; Halcrow; Cvitanovic (2008), Equilibrium and travelling-wave solutions of plane Couette flow |  |

## Possible Same Branch

No cross-parameter ODE deduplication candidate recorded yet.

## Representative Files

- ODE coefficients: [representative.asc](representative.asc)
- DNS flowfield: [ubest.nc](ubest.nc)

## DNS Diagnostics

| Quantity | Value |
|---|---:|
| L2 | 0.218634 |
| u2 | 0.295682 |
| v2 | 0.0502638 |
| w2 | 0.0751502 |
| e3d | 0.0928209 |
| ecf | 0.008174 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 1.01997 |
| wallshear_a | 0.509983 |
| wallshear_b | -0.509983 |
| dissipation | 1.01997 |
| I_total | 2.01997 |
| D_total | 2.01997 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 9 |
| Leading lambda | 0.07194190593383656 + 0.04080060218078903i |
| Leading multiplier | 1.4031994635385199 + 0.2902952272958338i |
| Leading residual | 0.0004295656640301145 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/ghc_re400_alpha1p14_gamma2p5_low_shear/E/jkl_1_3_5/dns_findsoln/sol003/ubest.nc` | `ls:sol003@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

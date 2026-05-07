---
physical_id: "ghc_re400_alpha1p14_gamma2p5_low_shear_002"
case: "ghc_re400_alpha1p14_gamma2p5_low_shear"
catalog_source: "stress:minimal_low_shear"
Re: 400.0
Lx: 5.511566576198634
Lz: 2.5132741228718345
shear: 0.252105
L2: 0.0935552
groups: ["A", "B", "C", "D", "E", "F", "G"]
representative_group: "A"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: false
E3D: 0.0412589
dissipation: 0.252105
D_total: 1.252105
wall_shear: 0.252105
I_total: 1.252105
has_eigen_analysis: true
leading_lambda_re: 0.07070794167578316
leading_lambda_im: 0.0
n_unstable: 2
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# ghc_re400_alpha1p14_gamma2p5_low_shear_002

## Summary

| Quantity | Value |
|---|---:|
| Case | `ghc_re400_alpha1p14_gamma2p5_low_shear` |
| Catalog source | `stress:minimal_low_shear` |
| Re | 400.0 |
| Lx | 5.511566576198634 |
| Lz | 2.5132741228718345 |
| Shear | 0.252105 |
| L2 | 0.0935552 |
| Groups | `A, B, C, D, E, F, G` |

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
| L2 | 0.0935552 |
| u2 | 0.128468 |
| v2 | 0.0140675 |
| w2 | 0.0283421 |
| e3d | 0.0412589 |
| ecf | 0.00100117 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.252105 |
| wallshear_a | 0.126053 |
| wallshear_b | -0.126053 |
| dissipation | 0.252105 |
| I_total | 1.252105 |
| D_total | 1.252105 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 2 |
| Leading lambda | 0.07070794167578316 + 0.0i |
| Leading multiplier | 1.4240995345125849 + 0.0i |
| Leading residual | 5.652277477706268e-08 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| A | `<sxyz, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/ghc_re400_alpha1p14_gamma2p5_low_shear/A/jkl_1_3_5/dns_findsoln/sol001/ubest.nc` | `ls:sol001@J1K3L5` |
| B | `<sxy, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/ghc_re400_alpha1p14_gamma2p5_low_shear/B/jkl_1_3_5/dns_findsoln/sol001/ubest.nc` | `ls:sol001@J1K3L5;ls:sol002@J1K3L5` |
| C | `<sxytz, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/ghc_re400_alpha1p14_gamma2p5_low_shear/C/jkl_1_3_5/dns_findsoln/sol001/ubest.nc` | `ls:sol001@J1K3L5` |
| D | `<sxy, sztx>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/ghc_re400_alpha1p14_gamma2p5_low_shear/D/jkl_1_3_5/dns_findsoln/sol001/ubest.nc` | `ls:sol001@J1K3L5` |
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/ghc_re400_alpha1p14_gamma2p5_low_shear/E/jkl_1_3_5/dns_findsoln/sol001/ubest.nc` | `ls:sol001@J1K3L5` |
| F | `<sxy, sz, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/ghc_re400_alpha1p14_gamma2p5_low_shear/F/jkl_1_3_5/dns_findsoln/sol001/ubest.nc` | `ls:sol001@J1K3L5` |
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/ghc_re400_alpha1p14_gamma2p5_low_shear/G/jkl_1_3_5/dns_findsoln/sol003/ubest.nc` | `ls:sol003@J1K3L5;ls:sol007@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

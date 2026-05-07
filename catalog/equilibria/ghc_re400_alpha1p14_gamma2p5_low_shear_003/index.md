---
physical_id: "ghc_re400_alpha1p14_gamma2p5_low_shear_003"
case: "ghc_re400_alpha1p14_gamma2p5_low_shear"
catalog_source: "stress:minimal_low_shear"
Re: 400.0
Lx: 5.511566576198634
Lz: 2.5132741228718345
shear: 0.317713
L2: 0.12589
groups: ["E", "G"]
representative_group: "E"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: false
E3D: 0.0450151
dissipation: 0.317713
D_total: 1.317713
wall_shear: 0.317713
I_total: 1.317713
has_eigen_analysis: true
leading_lambda_re: 0.033973389308748006
leading_lambda_im: -0.017977579816902293
n_unstable: 4
has_literature_mapping: true
literature: "GHC, 2008, EQ3"
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# ghc_re400_alpha1p14_gamma2p5_low_shear_003

## Summary

| Quantity | Value |
|---|---:|
| Case | `ghc_re400_alpha1p14_gamma2p5_low_shear` |
| Catalog source | `stress:minimal_low_shear` |
| Re | 400.0 |
| Lx | 5.511566576198634 |
| Lz | 2.5132741228718345 |
| Shear | 0.317713 |
| L2 | 0.12589 |
| Groups | `E, G` |

## Literature

| Appearance | Paper | Notes |
|---|---|---|
| `GHC, 2008, EQ3` | Gibson; Halcrow; Cvitanovic (2008), Equilibrium and travelling-wave solutions of plane Couette flow |  |

## Possible Same Branch

No cross-parameter ODE deduplication candidate recorded yet.

## Representative Files

- ODE coefficients: [representative.asc](representative.asc)
- DNS flowfield: [ubest.nc](ubest.nc)

## DNS Diagnostics

| Quantity | Value |
|---|---:|
| L2 | 0.12589 |
| u2 | 0.173565 |
| v2 | 0.0151295 |
| w2 | 0.036646 |
| e3d | 0.0450151 |
| ecf | 0.00157183 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.317713 |
| wallshear_a | 0.158856 |
| wallshear_b | -0.158856 |
| dissipation | 0.317713 |
| I_total | 1.317713 |
| D_total | 1.317713 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 4 |
| Leading lambda | 0.033973389308748006 + -0.017977579816902293i |
| Leading multiplier | 1.1803624794519547 + -0.10638698764340035i |
| Leading residual | 0.00023594497353872964 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/ghc_re400_alpha1p14_gamma2p5_low_shear/E/jkl_1_3_5/dns_findsoln/sol002/ubest.nc` | `ls:sol002@J1K3L5` |
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/ghc_re400_alpha1p14_gamma2p5_low_shear/G/jkl_1_3_5/dns_findsoln/sol005/ubest.nc` | `ls:sol005@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

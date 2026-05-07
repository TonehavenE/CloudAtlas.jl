---
physical_id: "ghc_re400_alpha1p14_gamma2p5_low_shear_004"
case: "ghc_re400_alpha1p14_gamma2p5_low_shear"
catalog_source: "stress:minimal_low_shear"
Re: 400.0
Lx: 5.511566576198634
Lz: 2.5132741228718345
shear: 0.429258
L2: 0.209125
groups: ["E", "G"]
representative_group: "E"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: false
E3D: 0.0274429
dissipation: 0.429258
D_total: 1.429258
wall_shear: 0.429258
I_total: 1.429258
has_eigen_analysis: true
leading_lambda_re: 0.05007910588990642
leading_lambda_im: 0.0
n_unstable: 1
has_literature_mapping: true
literature: "GHC, 2008, EQ1"
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# ghc_re400_alpha1p14_gamma2p5_low_shear_004

## Summary

| Quantity | Value |
|---|---:|
| Case | `ghc_re400_alpha1p14_gamma2p5_low_shear` |
| Catalog source | `stress:minimal_low_shear` |
| Re | 400.0 |
| Lx | 5.511566576198634 |
| Lz | 2.5132741228718345 |
| Shear | 0.429258 |
| L2 | 0.209125 |
| Groups | `E, G` |

## Literature

| Appearance | Paper | Notes |
|---|---|---|
| `GHC, 2008, EQ1` | Gibson; Halcrow; Cvitanovic (2008), Equilibrium and travelling-wave solutions of plane Couette flow |  |

## Possible Same Branch

No cross-parameter ODE deduplication candidate recorded yet.

## Representative Files

- ODE coefficients: [representative.asc](representative.asc)
- DNS flowfield: [ubest.nc](ubest.nc)

## DNS Diagnostics

| Quantity | Value |
|---|---:|
| L2 | 0.209125 |
| u2 | 0.294671 |
| v2 | 0.0121805 |
| w2 | 0.0220762 |
| e3d | 0.0274429 |
| ecf | 0.000635723 |
| ubulk | -2.15751e-14 |
| wbulk | 0.0 |
| wallshear | 0.429258 |
| wallshear_a | 0.214629 |
| wallshear_b | -0.214629 |
| dissipation | 0.429258 |
| I_total | 1.429258 |
| D_total | 1.429258 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 1 |
| Leading lambda | 0.05007910588990642 + 0.0i |
| Leading multiplier | 1.284533387005977 + 0.0i |
| Leading residual | 6.116189940070195e-08 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/ghc_re400_alpha1p14_gamma2p5_low_shear/E/jkl_1_3_5/dns_findsoln/sol004/ubest.nc` | `ls:sol004@J1K3L5` |
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/ghc_re400_alpha1p14_gamma2p5_low_shear/G/jkl_1_3_5/dns_findsoln/sol006/ubest.nc` | `ls:sol006@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

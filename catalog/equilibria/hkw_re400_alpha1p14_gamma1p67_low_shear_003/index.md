---
physical_id: "hkw_re400_alpha1p14_gamma1p67_low_shear_003"
case: "hkw_re400_alpha1p14_gamma1p67_low_shear"
catalog_source: "stress:minimal_low_shear"
Re: 400.0
Lx: 5.511566576198634
Lz: 3.762386411812926
shear: 0.351998
L2: 0.123974
groups: ["G"]
representative_group: "G"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: false
E3D: 0.0395973
dissipation: 0.351998
D_total: 1.351998
wall_shear: 0.351998
I_total: 1.351998
has_eigen_analysis: true
leading_lambda_re: 0.0641314415796214
leading_lambda_im: 0.0
n_unstable: 5
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# hkw_re400_alpha1p14_gamma1p67_low_shear_003

## Summary

| Quantity | Value |
|---|---:|
| Case | `hkw_re400_alpha1p14_gamma1p67_low_shear` |
| Catalog source | `stress:minimal_low_shear` |
| Re | 400.0 |
| Lx | 5.511566576198634 |
| Lz | 3.762386411812926 |
| Shear | 0.351998 |
| L2 | 0.123974 |
| Groups | `G` |

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
| L2 | 0.123974 |
| u2 | 0.172829 |
| v2 | 0.0145924 |
| w2 | 0.02562 |
| e3d | 0.0395973 |
| ecf | 0.000869323 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.351998 |
| wallshear_a | 0.175999 |
| wallshear_b | -0.175999 |
| dissipation | 0.351998 |
| I_total | 1.351998 |
| D_total | 1.351998 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 5 |
| Leading lambda | 0.0641314415796214 + 0.0i |
| Leading multiplier | 1.3780331210505858 + 0.0i |
| Leading residual | 5.0875985460703374e-06 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/hkw_re400_alpha1p14_gamma1p67_low_shear/G/jkl_1_3_5/dns_findsoln/sol004/ubest.nc` | `ls:sol004@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

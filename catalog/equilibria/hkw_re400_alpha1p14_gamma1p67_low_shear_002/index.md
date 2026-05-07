---
physical_id: "hkw_re400_alpha1p14_gamma1p67_low_shear_002"
case: "hkw_re400_alpha1p14_gamma1p67_low_shear"
catalog_source: "stress:minimal_low_shear"
Re: 400.0
Lx: 5.511566576198634
Lz: 3.762386411812926
shear: 0.344935
L2: 0.111936
groups: ["G"]
representative_group: "G"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: false
E3D: 0.0480621
dissipation: 0.344931
D_total: 1.3449309999999999
wall_shear: 0.344935
I_total: 1.344935
has_eigen_analysis: true
leading_lambda_re: 0.07418366513047484
leading_lambda_im: 0.0
n_unstable: 7
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# hkw_re400_alpha1p14_gamma1p67_low_shear_002

## Summary

| Quantity | Value |
|---|---:|
| Case | `hkw_re400_alpha1p14_gamma1p67_low_shear` |
| Catalog source | `stress:minimal_low_shear` |
| Re | 400.0 |
| Lx | 5.511566576198634 |
| Lz | 3.762386411812926 |
| Shear | 0.344935 |
| L2 | 0.111936 |
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
| L2 | 0.111936 |
| u2 | 0.153837 |
| v2 | 0.017581 |
| w2 | 0.0329329 |
| e3d | 0.0480621 |
| ecf | 0.00139367 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.344935 |
| wallshear_a | 0.172467 |
| wallshear_b | -0.172467 |
| dissipation | 0.344931 |
| I_total | 1.344935 |
| D_total | 1.3449309999999999 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 7 |
| Leading lambda | 0.07418366513047484 + 0.0i |
| Leading multiplier | 1.4490647171379358 + 0.0i |
| Leading residual | 2.880779380144852e-06 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/stress_tests/minimal_low_shear/hkw_re400_alpha1p14_gamma1p67_low_shear/G/jkl_1_3_5/dns_findsoln/sol001/ubest.nc` | `ls:sol001@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

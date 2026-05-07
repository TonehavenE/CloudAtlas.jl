---
physical_id: "re400_lx10_lz6_009"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 0.276007
L2: 0.105251
groups: ["D"]
representative_group: "D"
representative_J: 2
representative_K: 4
representative_L: 8
has_dns_bifurcation: false
E3D: 0.0397582
dissipation: 1.27601
D_total: 2.2760100000000003
wall_shear: 1.27601
I_total: 2.2760100000000003
has_eigen_analysis: true
leading_lambda_re: 0.09793020099565863
leading_lambda_im: 0.0
n_unstable: 9
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_009

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.276007 |
| L2 | 0.105251 |
| Groups | `D` |

## Literature

No literature mapping recorded yet.

## Possible Same Branch

No cross-parameter ODE deduplication candidate recorded yet.

## Representative Files

- ODE coefficients: [representative.asc](representative.asc)
- DNS flowfield: [ubest.nc](ubest.nc)

## DNS/ODE Comparison

![DNS/ODE comparison](images/dns_ode_comparison.png)

## DNS Diagnostics

| Quantity | Value |
|---|---:|
| L2 | 0.539968 |
| u2 | 0.763007 |
| v2 | 0.0154793 |
| w2 | 0.0266652 |
| e3d | 0.0397582 |
| ecf | 0.00095064 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 1.27601 |
| wallshear_a | 0.638004 |
| wallshear_b | -0.638004 |
| dissipation | 1.27601 |
| I_total | 2.2760100000000003 |
| D_total | 2.2760100000000003 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 9 |
| Leading lambda | 0.09793020099565863 + 0.0i |
| Leading multiplier | 1.6317466491152381 + 0.0i |
| Leading residual | 0.0002530633527606819 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| D | `<sxy, sztx>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re400_lx10_lz6/D/jkl_2_4_8/dns_findsoln/sol002/ubest.nc` | `ls:sol002@J2K4L8` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

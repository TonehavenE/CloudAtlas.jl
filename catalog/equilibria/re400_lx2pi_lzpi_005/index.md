---
physical_id: "re400_lx2pi_lzpi_005"
case: "re400_lx2pi_lzpi"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 6.283185307179586
Lz: 3.141592653589793
shear: 0.874244
L2: 0.196106
groups: ["E"]
representative_group: "E"
representative_J: 2
representative_K: 4
representative_L: 5
has_dns_bifurcation: false
E3D: 0.0696657
dissipation: 1.87424
D_total: 2.87424
wall_shear: 1.87424
I_total: 2.87424
has_eigen_analysis: true
leading_lambda_re: 0.15043713973772316
leading_lambda_im: 0.0
n_unstable: 18
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx2pi_lzpi_005

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx2pi_lzpi` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 6.283185307179586 |
| Lz | 3.141592653589793 |
| Shear | 0.874244 |
| L2 | 0.196106 |
| Groups | `E` |

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
| L2 | 0.490143 |
| u2 | 0.691131 |
| v2 | 0.0284239 |
| w2 | 0.0448432 |
| e3d | 0.0696657 |
| ecf | 0.00281883 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 1.87424 |
| wallshear_a | 0.937122 |
| wallshear_b | -0.937122 |
| dissipation | 1.87424 |
| I_total | 2.87424 |
| D_total | 2.87424 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 18 |
| Leading lambda | 0.15043713973772316 + 0.0i |
| Leading multiplier | 2.12163220120858 + 0.0i |
| Leading residual | 0.003101062662645109 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re400_lx2pi_lzpi/E/jkl_2_4_5/dns_findsoln/sol002/ubest.nc` | `ls:sol002@J2K4L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

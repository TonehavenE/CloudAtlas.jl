---
physical_id: "re400_lx2pi_lzpi_008"
case: "re400_lx2pi_lzpi"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 6.283185307179586
Lz: 3.141592653589793
shear: 2.96315
L2: 0.379829
groups: ["D"]
representative_group: "D"
representative_J: 2
representative_K: 4
representative_L: 5
has_dns_bifurcation: false
E3D: 0.1663
dissipation: 3.96315
D_total: 4.963150000000001
wall_shear: 3.96315
I_total: 4.963150000000001
has_eigen_analysis: true
leading_lambda_re: 0.11219856086107534
leading_lambda_im: 0.0
n_unstable: 24
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx2pi_lzpi_008

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx2pi_lzpi` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 6.283185307179586 |
| Lz | 3.141592653589793 |
| Shear | 2.96315 |
| L2 | 0.379829 |
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
| L2 | 0.383368 |
| u2 | 0.506675 |
| v2 | 0.11626 |
| w2 | 0.153968 |
| e3d | 0.1663 |
| ecf | 0.0372226 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 3.96315 |
| wallshear_a | 1.98158 |
| wallshear_b | -1.98158 |
| dissipation | 3.96315 |
| I_total | 4.963150000000001 |
| D_total | 4.963150000000001 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 24 |
| Leading lambda | 0.11219856086107534 + 0.0i |
| Leading multiplier | 1.7524114385615646 + 0.0i |
| Leading residual | 0.002583231021995087 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| D | `<sxy, sztx>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re400_lx2pi_lzpi/D/jkl_2_4_5/dns_findsoln/sol002/ubest.nc` | `ls:sol002@J2K4L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

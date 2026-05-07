---
physical_id: "re300_lx2pi_lzpi_010"
case: "re300_lx2pi_lzpi"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 6.283185307179586
Lz: 3.141592653589793
shear: 3.03859
L2: 0.386379
groups: ["D"]
representative_group: "D"
representative_J: 2
representative_K: 4
representative_L: 6
has_dns_bifurcation: true
E3D: 0.193702
dissipation: 3.03859
D_total: 4.03859
wall_shear: 3.03859
I_total: 4.03859
has_eigen_analysis: true
leading_lambda_re: 0.10324436931820125
leading_lambda_im: 0.0
n_unstable: 19
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx2pi_lzpi_010

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx2pi_lzpi` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 6.283185307179586 |
| Lz | 3.141592653589793 |
| Shear | 3.03859 |
| L2 | 0.386379 |
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
| L2 | 0.386379 |
| u2 | 0.498773 |
| v2 | 0.134323 |
| w2 | 0.178213 |
| e3d | 0.193702 |
| ecf | 0.0498026 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 3.03859 |
| wallshear_a | 1.51929 |
| wallshear_b | -1.51929 |
| dissipation | 3.03859 |
| I_total | 4.03859 |
| D_total | 4.03859 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 19 |
| Leading lambda | 0.10324436931820125 + 0.0i |
| Leading multiplier | 1.6756846810995667 + 0.0i |
| Leading residual | 0.00027324800751963045 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| D | `<sxy, sztx>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx2pi_lzpi/D/jkl_2_4_6/dns_findsoln/sol001/ubest.nc` | `on:sol001@J2K4L6` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 78
- Re range: 173.98429 to 501.92812
- Input range: 1.3883712 to 4.2334235

---
physical_id: "re400_lx2pi_lzpi_007"
case: "re400_lx2pi_lzpi"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 6.283185307179586
Lz: 3.141592653589793
shear: 1.23126
L2: 0.239933
groups: ["D"]
representative_group: "D"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: false
E3D: 0.108707
dissipation: 1.23126
D_total: 2.23126
wall_shear: 1.23126
I_total: 2.23126
has_eigen_analysis: true
leading_lambda_re: 0.1573562862103215
leading_lambda_im: 0.0
n_unstable: 14
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx2pi_lzpi_007

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx2pi_lzpi` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 6.283185307179586 |
| Lz | 3.141592653589793 |
| Shear | 1.23126 |
| L2 | 0.239933 |
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
| L2 | 0.239933 |
| u2 | 0.324509 |
| v2 | 0.059044 |
| w2 | 0.0796435 |
| e3d | 0.108707 |
| ecf | 0.00982929 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 1.23126 |
| wallshear_a | 0.61563 |
| wallshear_b | -0.61563 |
| dissipation | 1.23126 |
| I_total | 2.23126 |
| D_total | 2.23126 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 14 |
| Leading lambda | 0.1573562862103215 + 0.0i |
| Leading multiplier | 2.196316043399841 + 0.0i |
| Leading residual | 1.6613936566851042e-05 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| D | `<sxy, sztx>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx2pi_lzpi/D/jkl_1_3_5/dns_findsoln/sol003/ubest.nc` | `on:sol003@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

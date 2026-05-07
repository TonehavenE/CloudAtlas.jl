---
physical_id: "re400_lx2pi_lzpi_003"
case: "re400_lx2pi_lzpi"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 6.283185307179586
Lz: 3.141592653589793
shear: 0.413657
L2: 0.231055
groups: ["E"]
representative_group: "E"
representative_J: 3
representative_K: 5
representative_L: 9
has_dns_bifurcation: false
E3D: 0.0233922
dissipation: 0.413657
D_total: 1.413657
wall_shear: 0.413657
I_total: 1.413657
has_eigen_analysis: true
leading_lambda_re: 0.04739484930630479
leading_lambda_im: 0.0
n_unstable: 1
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx2pi_lzpi_003

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx2pi_lzpi` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 6.283185307179586 |
| Lz | 3.141592653589793 |
| Shear | 0.413657 |
| L2 | 0.231055 |
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
| L2 | 0.231055 |
| u2 | 0.326007 |
| v2 | 0.00964 |
| w2 | 0.0199875 |
| e3d | 0.0233922 |
| ecf | 0.00049243 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.413657 |
| wallshear_a | 0.206828 |
| wallshear_b | -0.206828 |
| dissipation | 0.413657 |
| I_total | 1.413657 |
| D_total | 1.413657 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 1 |
| Leading lambda | 0.04739484930630479 + 0.0i |
| Leading multiplier | 1.2674084771907177 + 0.0i |
| Leading residual | 1.9317795251950823e-07 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx2pi_lzpi/E/jkl_3_5_9/dns_findsoln/sol001/ubest.nc` | `on:sol001@J3K5L9;on:sol003@J1K3L5;on:sol007@J1K3L5;ls:sol001@J3K5L9` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

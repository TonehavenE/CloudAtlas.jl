---
physical_id: "re400_lx2pi_lzpi_002"
case: "re400_lx2pi_lzpi"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 6.283185307179586
Lz: 3.141592653589793
shear: 0.192372
L2: 0.0859584
groups: ["A", "B", "C", "D", "F", "G"]
representative_group: "C"
representative_J: 3
representative_K: 5
representative_L: 9
has_dns_bifurcation: false
E3D: 0.032456
dissipation: 0.192372
D_total: 1.192372
wall_shear: 0.192372
I_total: 1.192372
has_eigen_analysis: true
leading_lambda_re: 0.0696416129795016
leading_lambda_im: 0.0
n_unstable: 2
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx2pi_lzpi_002

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx2pi_lzpi` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 6.283185307179586 |
| Lz | 3.141592653589793 |
| Shear | 0.192372 |
| L2 | 0.0859584 |
| Groups | `A, B, C, D, F, G` |

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
| L2 | 0.0859584 |
| u2 | 0.119077 |
| v2 | 0.0102908 |
| w2 | 0.0221932 |
| e3d | 0.032456 |
| ecf | 0.000598437 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.192372 |
| wallshear_a | 0.096186 |
| wallshear_b | -0.096186 |
| dissipation | 0.192372 |
| I_total | 1.192372 |
| D_total | 1.192372 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 2 |
| Leading lambda | 0.0696416129795016 + 0.0i |
| Leading multiplier | 1.4165269486150955 + 0.0i |
| Leading residual | 1.1171361223341024e-07 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| A | `<sxyz, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx2pi_lzpi/A/jkl_1_3_5/dns_findsoln/sol003/ubest.nc` | `on:sol003@J1K3L5;ls:sol002@J1K3L5` |
| B | `<sxy, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx2pi_lzpi/B/jkl_1_4_5/dns_findsoln/sol001/ubest.nc` | `on:sol001@J1K4L5;ls:sol001@J1K4L5` |
| C | `<sxytz, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx2pi_lzpi/C/jkl_1_4_5/dns_findsoln/sol004/ubest.nc` | `on:sol004@J1K4L5;ls:sol001@J3K5L9;ls:sol003@J1K4L5;ls:sol004@J1K4L5` |
| D | `<sxy, sztx>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx2pi_lzpi/D/jkl_1_4_5/dns_findsoln/sol001/ubest.nc` | `on:sol001@J1K4L5;ls:sol001@J1K4L5` |
| F | `<sxy, sz, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx2pi_lzpi/F/jkl_1_4_5/dns_findsoln/sol001/ubest.nc` | `on:sol001@J1K4L5` |
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx2pi_lzpi/G/jkl_1_4_5/dns_findsoln/sol001/ubest.nc` | `on:sol001@J1K4L5;on:sol002@J1K4L5;on:sol003@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

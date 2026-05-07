---
physical_id: "re400_lx10_lz6_023"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 1.1023
L2: 0.407408
groups: ["E"]
representative_group: "E"
representative_J: 3
representative_K: 4
representative_L: 9
has_dns_bifurcation: false
E3D: 0.0392368
dissipation: 1.1023
D_total: 2.1023
wall_shear: 1.1023
I_total: 2.1023
has_eigen_analysis: true
leading_lambda_re: 0.036411796638857054
leading_lambda_im: -0.025813497318980333
n_unstable: 4
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_023

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 1.1023 |
| L2 | 0.407408 |
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
| L2 | 0.407408 |
| u2 | 0.57445 |
| v2 | 0.0146263 |
| w2 | 0.0418921 |
| e3d | 0.0392368 |
| ecf | 0.00196888 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 1.1023 |
| wallshear_a | 0.55115 |
| wallshear_b | -0.55115 |
| dissipation | 1.1023 |
| I_total | 2.1023 |
| D_total | 2.1023 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 4 |
| Leading lambda | 0.036411796638857054 + -0.025813497318980333i |
| Leading multiplier | 1.1897063912760937 + -0.15441078044071754i |
| Leading residual | 0.001648068232216665 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/E/jkl_3_4_9/dns_findsoln/sol001/ubest.nc` | `on:sol001@J3K4L9;on:sol002@J2K4L6;on:sol016@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

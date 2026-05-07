---
physical_id: "re400_lx2pi_lzpi_004"
case: "re400_lx2pi_lzpi"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 6.283185307179586
Lz: 3.141592653589793
shear: 0.76576
L2: 0.198195
groups: ["B"]
representative_group: "B"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: false
E3D: 0.0720641
dissipation: 0.76576
D_total: 1.76576
wall_shear: 0.76576
I_total: 1.76576
has_eigen_analysis: true
leading_lambda_re: 0.13912172769185807
leading_lambda_im: 0.0
n_unstable: 8
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx2pi_lzpi_004

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx2pi_lzpi` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 6.283185307179586 |
| Lz | 3.141592653589793 |
| Shear | 0.76576 |
| L2 | 0.198195 |
| Groups | `B` |

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
| L2 | 0.198195 |
| u2 | 0.275183 |
| v2 | 0.0302548 |
| w2 | 0.0438322 |
| e3d | 0.0720641 |
| ecf | 0.00283662 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.76576 |
| wallshear_a | 0.38288 |
| wallshear_b | -0.38288 |
| dissipation | 0.76576 |
| I_total | 1.76576 |
| D_total | 1.76576 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 8 |
| Leading lambda | 0.13912172769185807 + 0.0i |
| Leading multiplier | 2.0049289795478806 + 0.0i |
| Leading residual | 2.4087085558655956e-09 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| B | `<sxy, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx2pi_lzpi/B/jkl_1_3_5/dns_findsoln/sol003/ubest.nc` | `on:sol003@J1K3L5;ls:sol002@J1K3L5;ls:sol003@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

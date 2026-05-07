---
physical_id: "re300_lx2pi_lzpi_002"
case: "re300_lx2pi_lzpi"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 6.283185307179586
Lz: 3.141592653589793
shear: 0.305736
L2: 0.11435
groups: ["D"]
representative_group: "D"
representative_J: 1
representative_K: 4
representative_L: 5
has_dns_bifurcation: true
E3D: 0.0575535
dissipation: 0.305736
D_total: 1.305736
wall_shear: 0.305736
I_total: 1.305736
has_eigen_analysis: true
leading_lambda_re: 0.0576213516388339
leading_lambda_im: 0.0
n_unstable: 4
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx2pi_lzpi_002

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx2pi_lzpi` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 6.283185307179586 |
| Lz | 3.141592653589793 |
| Shear | 0.305736 |
| L2 | 0.11435 |
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
| L2 | 0.11435 |
| u2 | 0.154921 |
| v2 | 0.0207753 |
| w2 | 0.0414713 |
| e3d | 0.0575535 |
| ecf | 0.00215148 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.305736 |
| wallshear_a | 0.152868 |
| wallshear_b | -0.152868 |
| dissipation | 0.305736 |
| I_total | 1.305736 |
| D_total | 1.305736 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 4 |
| Leading lambda | 0.0576213516388339 + 0.0i |
| Leading multiplier | 1.3338997012455276 + 0.0i |
| Leading residual | 5.083915533193887e-06 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| D | `<sxy, sztx>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx2pi_lzpi/D/jkl_1_4_5/dns_findsoln/sol002/ubest.nc` | `on:sol002@J1K4L5` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 66
- Re range: 174.08519 to 518.77022
- Input range: 1.2112112 to 5.1620126

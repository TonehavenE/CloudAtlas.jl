---
physical_id: "re300_lx2pi_lzpi_006"
case: "re300_lx2pi_lzpi"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 6.283185307179586
Lz: 3.141592653589793
shear: 0.953817
L2: 0.226596
groups: ["D"]
representative_group: "D"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: true
E3D: 0.100584
dissipation: 0.953816
D_total: 1.953816
wall_shear: 0.953817
I_total: 1.953817
has_eigen_analysis: true
leading_lambda_re: 0.08727573307350023
leading_lambda_im: 0.0
n_unstable: 7
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx2pi_lzpi_006

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx2pi_lzpi` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 6.283185307179586 |
| Lz | 3.141592653589793 |
| Shear | 0.953817 |
| L2 | 0.226596 |
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
| L2 | 0.226596 |
| u2 | 0.303545 |
| v2 | 0.0586694 |
| w2 | 0.0843179 |
| e3d | 0.100584 |
| ecf | 0.0105516 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.953817 |
| wallshear_a | 0.476908 |
| wallshear_b | -0.476908 |
| dissipation | 0.953816 |
| I_total | 1.953817 |
| D_total | 1.953816 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 7 |
| Leading lambda | 0.08727573307350023 + 0.0i |
| Leading multiplier | 1.5470945149594655 + 0.0i |
| Leading residual | 0.04957331916644073 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| D | `<sxy, sztx>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx2pi_lzpi/D/jkl_1_3_5/dns_findsoln/sol003/ubest.nc` | `on:sol003@J1K3L5` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 68
- Re range: 296.07785 to 515.8569
- Input range: 1.9464673 to 4.2757212

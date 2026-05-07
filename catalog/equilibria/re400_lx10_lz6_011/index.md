---
physical_id: "re400_lx10_lz6_011"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 0.405024
L2: 0.144998
groups: ["A", "D", "E", "G"]
representative_group: "A"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: true
E3D: 0.0721096
dissipation: 0.405024
D_total: 1.405024
wall_shear: 0.405024
I_total: 1.405024
has_eigen_analysis: true
leading_lambda_re: 0.02813136171813386
leading_lambda_im: -0.0057645340285781615
n_unstable: 6
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_011

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.405024 |
| L2 | 0.144998 |
| Groups | `A, D, E, G` |

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
| L2 | 0.144998 |
| u2 | 0.201629 |
| v2 | 0.0187425 |
| w2 | 0.0323001 |
| e3d | 0.0721096 |
| ecf | 0.00139458 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.405024 |
| wallshear_a | 0.202512 |
| wallshear_b | -0.202512 |
| dissipation | 0.405024 |
| I_total | 1.405024 |
| D_total | 1.405024 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 6 |
| Leading lambda | 0.02813136171813386 + -0.0057645340285781615i |
| Leading multiplier | 1.150551483053896 + -0.03317115199132811i |
| Leading residual | 0.0895358043598071 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| A | `<sxyz, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/A/jkl_1_3_5/dns_findsoln/sol007/ubest.nc` | `on:sol007@J1K3L5` |
| D | `<sxy, sztx>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/D/jkl_1_3_5/dns_findsoln/sol001/ubest.nc` | `on:sol001@J1K3L5` |
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/E/jkl_1_3_5/dns_findsoln/sol009/ubest.nc` | `on:sol009@J1K3L5` |
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re400_lx10_lz6/G/jkl_1_3_5/dns_findsoln/sol014/ubest.nc` | `ls:sol014@J1K3L5` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 52
- Re range: 290.68909 to 655.59851
- Input range: 1.3883039 to 2.2524852

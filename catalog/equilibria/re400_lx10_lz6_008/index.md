---
physical_id: "re400_lx10_lz6_008"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 0.261529
L2: 0.0987623
groups: ["A", "B", "C"]
representative_group: "C"
representative_J: 2
representative_K: 4
representative_L: 7
has_dns_bifurcation: true
E3D: 0.0324224
dissipation: 0.261529
D_total: 1.261529
wall_shear: 0.261529
I_total: 1.261529
has_eigen_analysis: true
leading_lambda_re: 0.07572412512286884
leading_lambda_im: 0.0
n_unstable: 7
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_008

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.261529 |
| L2 | 0.0987623 |
| Groups | `A, B, C` |

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
| L2 | 0.0987623 |
| u2 | 0.136865 |
| v2 | 0.0129819 |
| w2 | 0.0246443 |
| e3d | 0.0324224 |
| ecf | 0.000775874 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.261529 |
| wallshear_a | 0.130765 |
| wallshear_b | -0.130765 |
| dissipation | 0.261529 |
| I_total | 1.261529 |
| D_total | 1.261529 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 7 |
| Leading lambda | 0.07572412512286884 + 0.0i |
| Leading multiplier | 1.4602689420128248 + 0.0i |
| Leading residual | 0.005807361546375092 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| A | `<sxyz, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/A/jkl_2_4_5/dns_findsoln/sol004/ubest.nc` | `on:sol004@J2K4L5` |
| B | `<sxy, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re400_lx10_lz6/B/jkl_2_4_7/dns_findsoln/sol002/ubest.nc` | `ls:sol002@J2K4L7` |
| C | `<sxytz, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/C/jkl_2_4_7/dns_findsoln/sol005/ubest.nc` | `on:sol005@J2K4L7` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 60
- Re range: 185.24261 to 523.23117
- Input range: 1.2283249 to 5.3154926

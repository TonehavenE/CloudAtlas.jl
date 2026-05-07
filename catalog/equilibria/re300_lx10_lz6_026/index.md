---
physical_id: "re300_lx10_lz6_026"
case: "re300_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 10.0
Lz: 6.0
shear: 1.75755
L2: 0.337678
groups: ["A"]
representative_group: "A"
representative_J: 2
representative_K: 4
representative_L: 5
has_dns_bifurcation: true
E3D: 0.186197
dissipation: 1.73884
D_total: 2.7388399999999997
wall_shear: 1.75755
I_total: 2.75755
has_eigen_analysis: true
leading_lambda_re: 0.16657198874602028
leading_lambda_im: 0.0
n_unstable: 22
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx10_lz6_026

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 1.75755 |
| L2 | 0.337678 |
| Groups | `A` |

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
| L2 | 0.337678 |
| u2 | 0.421936 |
| v2 | 0.0948282 |
| w2 | 0.20256 |
| e3d | 0.186197 |
| ecf | 0.0500228 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 1.75755 |
| wallshear_a | 0.878774 |
| wallshear_b | -0.878774 |
| dissipation | 1.73884 |
| I_total | 2.75755 |
| D_total | 2.7388399999999997 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 22 |
| Leading lambda | 0.16657198874602028 + 0.0i |
| Leading multiplier | 2.2998868906098315 + 0.0i |
| Leading residual | 4.65097673285744e-06 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| A | `<sxyz, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx10_lz6/A/jkl_2_4_5/dns_findsoln/sol002/ubest.nc` | `on:sol002@J2K4L5` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 78
- Re range: 242.12025 to 380.19503
- Input range: 2.3834743 to 2.9303093

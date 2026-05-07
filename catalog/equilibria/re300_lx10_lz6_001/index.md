---
physical_id: "re300_lx10_lz6_001"
case: "re300_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 10.0
Lz: 6.0
shear: 0.130007
L2: 0.0787033
groups: ["G"]
representative_group: "G"
representative_J: 2
representative_K: 4
representative_L: 5
has_dns_bifurcation: true
E3D: 0.0461695
dissipation: 0.130007
D_total: 1.130007
wall_shear: 0.130007
I_total: 1.130007
has_eigen_analysis: true
leading_lambda_re: 0.04977443646429325
leading_lambda_im: 0.0
n_unstable: 3
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx10_lz6_001

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.130007 |
| L2 | 0.0787033 |
| Groups | `G` |

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
| L2 | 0.0787033 |
| u2 | 0.107964 |
| v2 | 0.0103106 |
| w2 | 0.025019 |
| e3d | 0.0461695 |
| ecf | 0.000732259 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.130007 |
| wallshear_a | 0.0650036 |
| wallshear_b | -0.0650036 |
| dissipation | 0.130007 |
| I_total | 1.130007 |
| D_total | 1.130007 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 3 |
| Leading lambda | 0.04977443646429325 + 0.0i |
| Leading multiplier | 1.2825780864388487 + 0.0i |
| Leading residual | 5.825338621424076e-06 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx10_lz6/G/jkl_2_4_5/dns_findsoln/sol004/ubest.nc` | `on:sol004@J2K4L5` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 67
- Re range: 213.9188 to 517.41042
- Input range: 1.1183289 to 2.0431422

---
physical_id: "re300_lx10_lz6_007"
case: "re300_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 10.0
Lz: 6.0
shear: 0.332424
L2: 0.114986
groups: ["C"]
representative_group: "C"
representative_J: 3
representative_K: 4
representative_L: 9
has_dns_bifurcation: true
E3D: 0.0461862
dissipation: 0.332424
D_total: 1.332424
wall_shear: 0.332424
I_total: 1.332424
has_eigen_analysis: true
leading_lambda_re: 0.08034875646353971
leading_lambda_im: 0.0
n_unstable: 8
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx10_lz6_007

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.332424 |
| L2 | 0.114986 |
| Groups | `C` |

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
| L2 | 0.114986 |
| u2 | 0.156931 |
| v2 | 0.0200376 |
| w2 | 0.0376093 |
| e3d | 0.0461862 |
| ecf | 0.00181596 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.332424 |
| wallshear_a | 0.166212 |
| wallshear_b | -0.166212 |
| dissipation | 0.332424 |
| I_total | 1.332424 |
| D_total | 1.332424 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 8 |
| Leading lambda | 0.08034875646353971 + 0.0i |
| Leading multiplier | 1.4944283846420303 + 0.0i |
| Leading residual | 0.00016907204970777182 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| C | `<sxytz, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx10_lz6/C/jkl_2_4_8/dns_findsoln/sol004/ubest.nc` | `on:sol004@J2K4L8;ls:sol001@J3K4L9;ls:sol003@J2K4L9` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 66
- Re range: 185.2225 to 516.544
- Input range: 1.2295185 to 5.3385881

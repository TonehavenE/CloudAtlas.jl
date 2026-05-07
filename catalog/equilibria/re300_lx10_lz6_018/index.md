---
physical_id: "re300_lx10_lz6_018"
case: "re300_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 10.0
Lz: 6.0
shear: 0.783748
L2: 0.218337
groups: ["E"]
representative_group: "E"
representative_J: 2
representative_K: 4
representative_L: 9
has_dns_bifurcation: true
E3D: 0.10551
dissipation: 1.78375
D_total: 2.78375
wall_shear: 1.78375
I_total: 2.78375
has_eigen_analysis: true
leading_lambda_re: 0.030402567148203857
leading_lambda_im: 0.0
n_unstable: 5
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx10_lz6_018

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.783748 |
| L2 | 0.218337 |
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
| L2 | 0.474545 |
| u2 | 0.667121 |
| v2 | 0.0430831 |
| w2 | 0.0589916 |
| e3d | 0.10551 |
| ecf | 0.00533616 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 1.78375 |
| wallshear_a | 0.891874 |
| wallshear_b | -0.891874 |
| dissipation | 1.78375 |
| I_total | 2.78375 |
| D_total | 2.78375 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 5 |
| Leading lambda | 0.030402567148203857 + 0.0i |
| Leading multiplier | 1.1641751793873139 + 0.0i |
| Leading residual | 0.045127103287697735 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re300_lx10_lz6/E/jkl_2_4_9/dns_findsoln/sol004/ubest.nc` | `ls:sol004@J2K4L9` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 61
- Re range: 290.40897 to 701.49315
- Input range: 1.3882973 to 2.0322203

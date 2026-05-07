---
physical_id: "re300_lx10_lz6_017"
case: "re300_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 10.0
Lz: 6.0
shear: 0.726279
L2: 0.203045
groups: ["G"]
representative_group: "G"
representative_J: 1
representative_K: 4
representative_L: 5
has_dns_bifurcation: true
E3D: 0.0738664
dissipation: 0.579842
D_total: 1.579842
wall_shear: 0.545337
I_total: 1.545337
has_eigen_analysis: true
leading_lambda_re: 0.10152028313912775
leading_lambda_im: 0.0
n_unstable: 7
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx10_lz6_017

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.726279 |
| L2 | 0.203045 |
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
| L2 | 0.245764 |
| u2 | 0.342431 |
| v2 | 0.0259767 |
| w2 | 0.0535343 |
| e3d | 0.0738664 |
| ecf | 0.00354072 |
| ubulk | -1.84192e-11 |
| wbulk | -2.94519e-13 |
| wallshear | 0.545337 |
| wallshear_a | 0.272668 |
| wallshear_b | -0.272668 |
| dissipation | 0.579842 |
| I_total | 1.545337 |
| D_total | 1.579842 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 7 |
| Leading lambda | 0.10152028313912775 + 0.0i |
| Leading multiplier | 1.6613016401779497 + 0.0i |
| Leading residual | 0.0002517374107795123 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re300_lx10_lz6/G/jkl_1_4_5/dns_findsoln/sol007/ubest.nc` | `ls:sol007@J1K4L5` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 89
- Re range: 284.87002 to 456.55099
- Input range: 1.3692196 to 1.741511

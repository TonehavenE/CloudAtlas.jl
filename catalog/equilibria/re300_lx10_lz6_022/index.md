---
physical_id: "re300_lx10_lz6_022"
case: "re300_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 10.0
Lz: 6.0
shear: 1.09973
L2: 0.404339
groups: ["E"]
representative_group: "E"
representative_J: 3
representative_K: 5
representative_L: 11
has_dns_bifurcation: true
E3D: 0.102379
dissipation: 1.12972
D_total: 2.12972
wall_shear: 1.1127
I_total: 2.1127000000000002
has_eigen_analysis: true
leading_lambda_re: 0.03101155942572789
leading_lambda_im: -0.02497694457360819
n_unstable: 2
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx10_lz6_022

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 1.09973 |
| L2 | 0.404339 |
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
| L2 | 0.270783 |
| u2 | 0.371679 |
| v2 | 0.0550885 |
| w2 | 0.0739366 |
| e3d | 0.102379 |
| ecf | 0.00850137 |
| ubulk | 9.7517e-12 |
| wbulk | 1.3502e-13 |
| wallshear | 1.1127 |
| wallshear_a | 0.556351 |
| wallshear_b | -0.556351 |
| dissipation | 1.12972 |
| I_total | 2.1127000000000002 |
| D_total | 2.12972 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 2 |
| Leading lambda | 0.03101155942572789 + -0.02497694457360819i |
| Leading multiplier | 1.1586312428065104 + -0.1454522964674623i |
| Leading residual | 0.0018535839218206736 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re300_lx10_lz6/E/jkl_3_5_11/dns_findsoln/sol002/ubest.nc` | `ls:sol002@J3K5L11;ls:sol006@J1K3L5` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 52
- Re range: 255.9 to 515.35438
- Input range: 2.0974219 to 3.0944515

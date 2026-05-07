---
physical_id: "re300_lx10_lz6_008"
case: "re300_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 10.0
Lz: 6.0
shear: 0.368928
L2: 0.132685
groups: ["B", "C"]
representative_group: "B"
representative_J: 2
representative_K: 4
representative_L: 9
has_dns_bifurcation: true
E3D: 0.0839137
dissipation: 0.368928
D_total: 1.368928
wall_shear: 0.368928
I_total: 1.368928
has_eigen_analysis: true
leading_lambda_re: 0.04437660097622442
leading_lambda_im: 0.0
n_unstable: 3
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx10_lz6_008

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.368928 |
| L2 | 0.132685 |
| Groups | `B, C` |

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
| L2 | 0.132685 |
| u2 | 0.181495 |
| v2 | 0.020465 |
| w2 | 0.0430246 |
| e3d | 0.0839137 |
| ecf | 0.00226994 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.368928 |
| wallshear_a | 0.184464 |
| wallshear_b | -0.184464 |
| dissipation | 0.368928 |
| I_total | 1.368928 |
| D_total | 1.368928 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 3 |
| Leading lambda | 0.04437660097622442 + 0.0i |
| Leading multiplier | 1.2484253096523033 + 0.0i |
| Leading residual | 0.0011028945891621929 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| B | `<sxy, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx10_lz6/B/jkl_2_4_9/dns_findsoln/sol001/ubest.nc` | `on:sol001@J2K4L9` |
| C | `<sxytz, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx10_lz6/C/jkl_1_4_5/dns_findsoln/sol005/ubest.nc` | `on:sol005@J1K4L5` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 60
- Re range: 254.34243 to 736.7627
- Input range: 1.1528324 to 1.7887115

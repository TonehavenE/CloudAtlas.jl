---
physical_id: "re300_lx2pi_lzpi_004"
case: "re300_lx2pi_lzpi"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 6.283185307179586
Lz: 3.141592653589793
shear: 0.78023
L2: 0.192927
groups: ["G"]
representative_group: "G"
representative_J: 2
representative_K: 4
representative_L: 5
has_dns_bifurcation: true
E3D: 0.0852362
dissipation: 0.78023
D_total: 1.78023
wall_shear: 0.78023
I_total: 1.78023
has_eigen_analysis: true
leading_lambda_re: 0.06082913479269936
leading_lambda_im: -0.08202998199759082
n_unstable: 9
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx2pi_lzpi_004

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx2pi_lzpi` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 6.283185307179586 |
| Lz | 3.141592653589793 |
| Shear | 0.78023 |
| L2 | 0.192927 |
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
| L2 | 0.192927 |
| u2 | 0.260802 |
| v2 | 0.0358255 |
| w2 | 0.0716942 |
| e3d | 0.0852362 |
| ecf | 0.00642353 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.78023 |
| wallshear_a | 0.390115 |
| wallshear_b | -0.390115 |
| dissipation | 0.78023 |
| I_total | 1.78023 |
| D_total | 1.78023 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 9 |
| Leading lambda | 0.06082913479269936 + -0.08202998199759082i |
| Leading multiplier | 1.2430455392680795 + -0.5404879408418094i |
| Leading residual | 0.0003927587027465955 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx2pi_lzpi/G/jkl_2_4_5/dns_findsoln/sol002/ubest.nc` | `on:sol002@J2K4L5;on:sol003@J1K4L5;ls:sol003@J1K4L5;ls:sol005@J1K3L5` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 93
- Re range: 174.10006 to 509.28658
- Input range: 1.3854658 to 2.970579

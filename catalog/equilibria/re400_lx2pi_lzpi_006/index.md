---
physical_id: "re400_lx2pi_lzpi_006"
case: "re400_lx2pi_lzpi"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 6.283185307179586
Lz: 3.141592653589793
shear: 0.965829
L2: 0.205098
groups: ["E"]
representative_group: "E"
representative_J: 2
representative_K: 4
representative_L: 6
has_dns_bifurcation: false
E3D: 0.0714645
dissipation: 0.965829
D_total: 1.965829
wall_shear: 0.965829
I_total: 1.965829
has_eigen_analysis: true
leading_lambda_re: 0.19563149096005347
leading_lambda_im: 0.0
n_unstable: 17
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx2pi_lzpi_006

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx2pi_lzpi` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 6.283185307179586 |
| Lz | 3.141592653589793 |
| Shear | 0.965829 |
| L2 | 0.205098 |
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
| L2 | 0.205098 |
| u2 | 0.284179 |
| v2 | 0.030692 |
| w2 | 0.0492996 |
| e3d | 0.0714645 |
| ecf | 0.00337245 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.965829 |
| wallshear_a | 0.482915 |
| wallshear_b | -0.482915 |
| dissipation | 0.965829 |
| I_total | 1.965829 |
| D_total | 1.965829 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 17 |
| Leading lambda | 0.19563149096005347 + 0.0i |
| Leading multiplier | 2.6595513809726135 + 0.0i |
| Leading residual | 3.7329646252791786e-07 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx2pi_lzpi/E/jkl_2_4_6/dns_findsoln/sol002/ubest.nc` | `on:sol002@J2K4L6` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

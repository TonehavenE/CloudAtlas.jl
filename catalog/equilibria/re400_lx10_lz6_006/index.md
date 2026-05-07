---
physical_id: "re400_lx10_lz6_006"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 0.207388
L2: 0.0928868
groups: ["C", "D"]
representative_group: "D"
representative_J: 2
representative_K: 4
representative_L: 9
has_dns_bifurcation: false
E3D: 0.0518974
dissipation: 0.207388
D_total: 1.207388
wall_shear: 0.207388
I_total: 1.207388
has_eigen_analysis: true
leading_lambda_re: 0.04950091118409056
leading_lambda_im: 0.0
n_unstable: 2
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_006

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 0.207388 |
| L2 | 0.0928868 |
| Groups | `C, D` |

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
| L2 | 0.0928868 |
| u2 | 0.128519 |
| v2 | 0.0106928 |
| w2 | 0.0249887 |
| e3d | 0.0518974 |
| ecf | 0.000738772 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.207388 |
| wallshear_a | 0.103694 |
| wallshear_b | -0.103694 |
| dissipation | 0.207388 |
| I_total | 1.207388 |
| D_total | 1.207388 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 2 |
| Leading lambda | 0.04950091118409056 + 0.0i |
| Leading multiplier | 1.280825197708144 + 0.0i |
| Leading residual | 0.00023457747980674027 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| C | `<sxytz, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re400_lx10_lz6/C/jkl_1_3_5/dns_findsoln/sol002/ubest.nc` | `on:sol002@J1K3L5` |
| D | `<sxy, sztx>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re400_lx10_lz6/D/jkl_2_4_9/dns_findsoln/sol001/ubest.nc` | `ls:sol001@J2K4L9;ls:sol005@J1K4L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

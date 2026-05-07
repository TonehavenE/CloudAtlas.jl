---
physical_id: "re400_lx10_lz6_028"
case: "re400_lx10_lz6"
catalog_source: "eqb_catalog"
Re: 400.0
Lx: 10.0
Lz: 6.0
shear: 1.33369
L2: 0.275127
groups: ["E"]
representative_group: "E"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: false
E3D: 0.0721096
dissipation: 0.405024
D_total: 1.405024
wall_shear: 0.405024
I_total: 1.405024
has_eigen_analysis: true
leading_lambda_re: 0.07150106556641277
leading_lambda_im: -0.08929645277433972
n_unstable: 12
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re400_lx10_lz6_028

## Summary

| Quantity | Value |
|---|---:|
| Case | `re400_lx10_lz6` |
| Catalog source | `eqb_catalog` |
| Re | 400.0 |
| Lx | 10.0 |
| Lz | 6.0 |
| Shear | 1.33369 |
| L2 | 0.275127 |
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
| L2 | 0.144998 |
| u2 | 0.201629 |
| v2 | 0.0187425 |
| w2 | 0.0323001 |
| e3d | 0.0721096 |
| ecf | 0.00139458 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.405024 |
| wallshear_a | 0.202512 |
| wallshear_b | -0.202512 |
| dissipation | 0.405024 |
| I_total | 1.405024 |
| D_total | 1.405024 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 12 |
| Leading lambda | 0.07150106556641277 + -0.08929645277433972i |
| Leading multiplier | 1.289601308092445 + -0.6173628841350636i |
| Leading residual | 0.032683153667648256 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re400_lx10_lz6/E/jkl_1_3_5/dns_findsoln/sol009/ubest.nc` | `ls:sol009@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

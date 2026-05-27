---
physical_id: "ghc_re400_literature_fuzz_004"
case: "ghc_re400_literature_fuzz"
catalog_source: "literature_target_runs:ghc_re400_literature_fuzz"
Re: 400.0
Lx: 5.511566576198634
Lz: 2.5132741228718345
shear: 0.453688
L2: 0.168118
groups: ["E"]
representative_group: "E"
representative_J: 1
representative_K: 3
representative_L: 5
has_dns_bifurcation: false
E3D: 0.0605875
dissipation: 0.453688
D_total: 1.453688
wall_shear: 0.453688
I_total: 1.453688
has_eigen_analysis: true
leading_lambda_re: 0.02931995715725033
leading_lambda_im: 0.0
n_unstable: 5
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# ghc_re400_literature_fuzz_004

## Summary

| Quantity | Value |
|---|---:|
| Case | `ghc_re400_literature_fuzz` |
| Catalog source | `literature_target_runs:ghc_re400_literature_fuzz` |
| Re | 400.0 |
| Lx | 5.511566576198634 |
| Lz | 2.5132741228718345 |
| Shear | 0.453688 |
| L2 | 0.168118 |
| Groups | `E` |

## Literature

No literature mapping recorded yet.

## Representative Files

- ODE coefficients: [representative.asc](representative.asc)
- DNS flowfield: [ubest.nc](ubest.nc)

## DNS Diagnostics

| Quantity | Value |
|---|---:|
| L2 | 0.168118 |
| u2 | 0.229188 |
| v2 | 0.0250745 |
| w2 | 0.0580634 |
| e3d | 0.0605875 |
| ecf | 0.00400008 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.453688 |
| wallshear_a | 0.226844 |
| wallshear_b | -0.226844 |
| dissipation | 0.453688 |
| I_total | 1.453688 |
| D_total | 1.453688 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 5 |
| Leading lambda | 0.02931995715725033 + 0.0i |
| Leading multiplier | 1.1578904660645224 + 0.0i |
| Leading residual | 0.014388504013513404 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re400/ghc_re400_literature_fuzz/E/jkl_1_3_5/dns_findsoln/sol006/ubest.nc` | `fuzz:sol006@J1K3L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

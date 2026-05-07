---
physical_id: "re300_lx2pi_lzpi_001"
case: "re300_lx2pi_lzpi"
catalog_source: "eqb_catalog"
Re: 300.0
Lx: 6.283185307179586
Lz: 3.141592653589793
shear: 0.25004
L2: 0.10128
groups: ["B", "C", "D", "F", "G"]
representative_group: "C"
representative_J: 3
representative_K: 5
representative_L: 11
has_dns_bifurcation: true
E3D: 0.046899
dissipation: 0.25004
D_total: 1.25004
wall_shear: 0.25004
I_total: 1.25004
has_eigen_analysis: true
leading_lambda_re: 0.07147587150947786
leading_lambda_im: 0.0
n_unstable: 2
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# re300_lx2pi_lzpi_001

## Summary

| Quantity | Value |
|---|---:|
| Case | `re300_lx2pi_lzpi` |
| Catalog source | `eqb_catalog` |
| Re | 300.0 |
| Lx | 6.283185307179586 |
| Lz | 3.141592653589793 |
| Shear | 0.25004 |
| L2 | 0.10128 |
| Groups | `B, C, D, F, G` |

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
| L2 | 0.10128 |
| u2 | 0.138272 |
| v2 | 0.0159542 |
| w2 | 0.0337862 |
| e3d | 0.046899 |
| ecf | 0.00139604 |
| ubulk | 0.0 |
| wbulk | 0.0 |
| wallshear | 0.25004 |
| wallshear_a | 0.12502 |
| wallshear_b | -0.12502 |
| dissipation | 0.25004 |
| I_total | 1.25004 |
| D_total | 1.25004 |

## Eigenvalue Analysis

| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | 32 |
| Unstable count | 2 |
| Leading lambda | 0.07147587150947786 + 0.0i |
| Leading multiplier | 1.4295780882374114 + 0.0i |
| Leading residual | 2.493114006328914e-08 |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| B | `<sxy, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx2pi_lzpi/B/jkl_1_4_5/dns_findsoln/sol001/ubest.nc` | `on:sol001@J1K4L5;ls:sol001@J1K4L5` |
| C | `<sxytz, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx2pi_lzpi/C/jkl_3_5_11/dns_findsoln/sol001/ubest.nc` | `on:sol001@J3K5L11;on:sol002@J1K4L5;ls:sol001@J3K5L11;ls:sol002@J1K4L5` |
| D | `<sxy, sztx>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re300_lx2pi_lzpi/D/jkl_3_5_11/dns_findsoln/sol001/ubest.nc` | `ls:sol001@J3K5L11;ls:sol002@J2K4L6` |
| F | `<sxy, sz, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/overnight_runs_updated/re300_lx2pi_lzpi/F/jkl_1_4_5/dns_findsoln/sol001/ubest.nc` | `on:sol001@J1K4L5` |
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/low_shear/re300_lx2pi_lzpi/G/jkl_1_4_5/dns_findsoln/sol001/ubest.nc` | `ls:sol001@J1K4L5;ls:sol002@J1K4L5` |

## DNS Bifurcation

- CSV: [dns_combined_curve.csv](bifurcations/dns_combined_curve.csv)
- Points: 65
- Re range: 174.10532 to 502.90277
- Input range: 1.1664352 to 5.3748088

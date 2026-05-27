---
physical_id: "ghc_re400_literature_fuzz_001"
case: "ghc_re400_literature_fuzz"
catalog_source: "literature_target_runs:ghc_re400_literature_fuzz"
Re: 400.0
Lx: 5.511566576198634
Lz: 2.5132741228718345
shear: 0.022269335687486125
L2: 0.07677082401832236
groups: ["C", "E"]
representative_group: "E"
representative_J: 2
representative_K: 4
representative_L: 5
has_dns_bifurcation: false
has_eigen_analysis: false
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# ghc_re400_literature_fuzz_001

## Summary

| Quantity | Value |
|---|---:|
| Case | `ghc_re400_literature_fuzz` |
| Catalog source | `literature_target_runs:ghc_re400_literature_fuzz` |
| Re | 400.0 |
| Lx | 5.511566576198634 |
| Lz | 2.5132741228718345 |
| Shear | 0.022269335687486125 |
| L2 | 0.07677082401832236 |
| Groups | `C, E` |

## Representative Files

- ODE coefficients: [representative.asc](representative.asc)
- DNS flowfield: [ubest.nc](ubest.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| C | `<sxytz, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re400/ghc_re400_literature_fuzz/C/jkl_2_4_5/dns_findsoln/sol001/ubest.nc` | `fuzz:sol001@J2K4L5` |
| E | `<sxyz, sztxz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re400/ghc_re400_literature_fuzz/E/jkl_2_4_5/dns_findsoln/sol004/ubest.nc` | `fuzz:sol004@J2K4L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

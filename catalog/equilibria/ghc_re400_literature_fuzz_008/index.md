---
physical_id: "ghc_re400_literature_fuzz_008"
case: "ghc_re400_literature_fuzz"
catalog_source: "literature_target_runs:ghc_re400_literature_fuzz"
Re: 400.0
Lx: 5.511566576198634
Lz: 2.5132741228718345
shear: 0.6842234876075812
L2: 0.21175076716774255
groups: ["B", "G"]
representative_group: "G"
representative_J: 1
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

# ghc_re400_literature_fuzz_008

## Summary

| Quantity | Value |
|---|---:|
| Case | `ghc_re400_literature_fuzz` |
| Catalog source | `literature_target_runs:ghc_re400_literature_fuzz` |
| Re | 400.0 |
| Lx | 5.511566576198634 |
| Lz | 2.5132741228718345 |
| Shear | 0.6842234876075812 |
| L2 | 0.21175076716774255 |
| Groups | `B, G` |

## Representative Files

- ODE coefficients: [representative.asc](representative.asc)
- DNS flowfield: [ubest.nc](ubest.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| B | `<sxy, sz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re400/ghc_re400_literature_fuzz/B/jkl_1_4_5/dns_findsoln/sol002/ubest.nc` | `fuzz:sol002@J1K4L5` |
| G | `<sxyz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re400/ghc_re400_literature_fuzz/G/jkl_1_4_5/dns_findsoln/sol004/ubest.nc` | `fuzz:sol004@J1K4L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

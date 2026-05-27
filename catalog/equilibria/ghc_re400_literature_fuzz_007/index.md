---
physical_id: "ghc_re400_literature_fuzz_007"
case: "ghc_re400_literature_fuzz"
catalog_source: "literature_target_runs:ghc_re400_literature_fuzz"
Re: 400.0
Lx: 5.511566576198634
Lz: 2.5132741228718345
shear: 0.22583074021884197
L2: 0.1324018072132757
groups: ["A"]
representative_group: "A"
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

# ghc_re400_literature_fuzz_007

## Summary

| Quantity | Value |
|---|---:|
| Case | `ghc_re400_literature_fuzz` |
| Catalog source | `literature_target_runs:ghc_re400_literature_fuzz` |
| Re | 400.0 |
| Lx | 5.511566576198634 |
| Lz | 2.5132741228718345 |
| Shear | 0.22583074021884197 |
| L2 | 0.1324018072132757 |
| Groups | `A` |

## Representative Files

- ODE coefficients: [representative.asc](representative.asc)
- DNS flowfield: [ubest.nc](ubest.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
| A | `<sxyz, txz>` | `/home/ebenq/dev/MyCloudAtlas.jl/notebooks/eqb_fuzzing/literature_target_runs/ghc_re400/ghc_re400_literature_fuzz/A/jkl_2_4_5/dns_findsoln/sol001/ubest.nc` | `fuzz:sol001@J2K4L5` |

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.

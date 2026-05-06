# Minimal Low-Shear GHC/HKW Fuzzing and DNS Promotion Findings

Generated: 2026-04-15 10:23:41

DNS promotion convergence tolerance: `1e-10`. Cross-group physical-solution tolerance: `(shear, L2) <= 1e-4` from `create_combined_catalog.jl`.

## Summary

| Box | Re | Lx | Lz | alpha | gamma | fuzz seeds | ODE unique | DNS converged seeds | DNS group-unique | DNS physical unique | nontrivial physical |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| GHC | 400 | 5.51157 | 2.51327 | 1.14 | 2.5 | 700000 | 21 | 18/21 | 16 | 7 | 6 |
| HKW | 400 | 5.51157 | 3.76239 | 1.14 | 1.67 | 700000 | 43 | 22/43 | 18 | 11 | 10 |

## Fuzzing by Symmetry Group

| Box | Group | attempted | hookstep conv. | postfilter accepted | ODE unique | ODE shear range | ODE norm range | DNS conv. seeds | DNS group-unique |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| GHC | A | 100000 | 1404 | 503 | 1 | 1.15819-1.15819 | 0.0890641-0.0890641 | 1/1 | 1 |
| GHC | B | 100000 | 8203 | 846 | 3 | 1.15819-2.43895 | 0.0890641-0.319657 | 3/3 | 2 |
| GHC | C | 100000 | 7752 | 4522 | 2 | 1.02878-1.15819 | 0.0882476-0.0890641 | 2/2 | 2 |
| GHC | D | 100000 | 13113 | 2177 | 1 | 1.15819-1.15819 | 0.0890641-0.0890641 | 1/1 | 1 |
| GHC | E | 100000 | 7448 | 1697 | 5 | 1.15819-2.61497 | 0.0890641-0.317942 | 5/5 | 5 |
| GHC | F | 100000 | 13523 | 3448 | 2 | 1.15819-4.62889 | 0.0890641-0.4534 | 1/2 | 1 |
| GHC | G | 100000 | 373 | 277 | 7 | 1.02878-1.91326 | 0.0882477-0.317942 | 5/7 | 4 |
| HKW | A | 100000 | 5417 | 258 | 6 | 1.21063-3.13623 | 0.17556-0.421166 | 4/6 | 4 |
| HKW | B | 100000 | 23955 | 203 | 8 | 1.87006-3.48881 | 0.261076-0.418435 | 6/8 | 4 |
| HKW | C | 100000 | 11993 | 932 | 5 | 1.131-2.44342 | 0.13215-0.404762 | 1/5 | 1 |
| HKW | D | 100000 | 27941 | 332 | 8 | 1.54344-4.02419 | 0.239568-0.500974 | 1/8 | 1 |
| HKW | E | 100000 | 14813 | 277 | 5 | 1.27666-3.44354 | 0.320275-0.438815 | 2/5 | 2 |
| HKW | F | 100000 | 36849 | 117 | 2 | 2.44342-3.17258 | 0.346782-0.386222 | 2/2 | 2 |
| HKW | G | 100000 | 932 | 273 | 9 | 1.03906-1.80619 | 0.0705057-0.257167 | 6/9 | 4 |

## DNS Physical Solutions

The table is deduplicated across symmetry groups. `E3D` and `ECF` are the energy diagnostics reported by the existing findsoln summary script. Leading eigenvalues were not available in these promotion outputs; no `MuE.asc` or eigenvalue artifact was found under `dns_findsoln`.

| Box | physical id | groups | trivial | shear | dissipation | L2 | final residual | E3D | ECF | leading eigs |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| GHC | ghc_re400_alpha1p14_gamma2p5_low_shear_001 | C,G | true | 6.96834e-13 | 4.59416e-24 | 7.22402e-13 | 8.82782e-16 | 3.72055e-15 | 1.00229e-27 | not computed |
| GHC | ghc_re400_alpha1p14_gamma2p5_low_shear_002 | A,B,C,D,E,F,G | false | 0.252105 | 0.252105 | 0.0935552 | 4.19289e-15 | 0.0412589 | 0.00100117 | not computed |
| GHC | ghc_re400_alpha1p14_gamma2p5_low_shear_003 | E,G | false | 0.317713 | 0.317713 | 0.12589 | 2.21364e-15 | 0.0450151 | 0.00157183 | not computed |
| GHC | ghc_re400_alpha1p14_gamma2p5_low_shear_004 | E,G | false | 0.429258 | 0.429258 | 0.209125 | 3.46875e-11 | 0.0274429 | 0.000635723 | not computed |
| GHC | ghc_re400_alpha1p14_gamma2p5_low_shear_005 | E | false | 0.453688 | 0.453688 | 0.168118 | 3.51017e-14 | 0.0605875 | 0.00400008 | not computed |
| GHC | ghc_re400_alpha1p14_gamma2p5_low_shear_006 | E | false | 1.01997 | 1.01997 | 0.218634 | 2.87795e-14 | 0.0928209 | 0.008174 | not computed |
| GHC | ghc_re400_alpha1p14_gamma2p5_low_shear_007 | B | false | 2.50069 | 2.50069 | 0.333628 | 4.49674e-16 | 0.129477 | 0.0191988 | not computed |
| HKW | hkw_re400_alpha1p14_gamma1p67_low_shear_001 | A,E,G | true | 6.77947e-13 | 3.02519e-25 | 1.42951e-13 | 1.68971e-15 | 1.39085e-14 | 2.12376e-28 | not computed |
| HKW | hkw_re400_alpha1p14_gamma1p67_low_shear_002 | G | false | 0.344935 | 0.344931 | 0.111936 | 4.77165e-16 | 0.0480621 | 0.00139367 | not computed |
| HKW | hkw_re400_alpha1p14_gamma1p67_low_shear_003 | G | false | 0.351998 | 0.351998 | 0.123974 | 3.11069e-15 | 0.0395973 | 0.000869323 | not computed |
| HKW | hkw_re400_alpha1p14_gamma1p67_low_shear_004 | G | false | 0.36718 | 0.36718 | 0.126947 | 9.42768e-15 | 0.0406223 | 0.000905245 | not computed |
| HKW | hkw_re400_alpha1p14_gamma1p67_low_shear_005 | B | false | 0.482404 | 0.482403 | 0.150856 | 4.37343e-16 | 0.0597876 | 0.00209483 | not computed |
| HKW | hkw_re400_alpha1p14_gamma1p67_low_shear_006 | B | false | 0.735398 | 0.735397 | 0.190023 | 5.42886e-16 | 0.0696988 | 0.00364486 | not computed |
| HKW | hkw_re400_alpha1p14_gamma1p67_low_shear_007 | A,B,C,D,F | false | 1.12484 | 1.12484 | 0.237463 | 3.72411e-15 | 0.0729475 | 0.00414076 | not computed |
| HKW | hkw_re400_alpha1p14_gamma1p67_low_shear_008 | E | false | 1.42478 | 1.42478 | 0.290936 | 2.82185e-15 | 0.0920756 | 0.0104823 | not computed |
| HKW | hkw_re400_alpha1p14_gamma1p67_low_shear_009 | A | false | 1.47553 | 1.47548 | 0.288577 | 7.07703e-16 | 0.0957699 | 0.0107002 | not computed |
| HKW | hkw_re400_alpha1p14_gamma1p67_low_shear_010 | A | false | 1.66994 | 1.66958 | 0.311244 | 3.10734e-12 | 0.113237 | 0.0174561 | not computed |
| HKW | hkw_re400_alpha1p14_gamma1p67_low_shear_011 | B,F | false | 3.23941 | 3.23941 | 0.399869 | 7.51293e-16 | 0.131473 | 0.0278733 | not computed |

Full per-solution table: `stress_dns_physical_solutions_table.csv`.

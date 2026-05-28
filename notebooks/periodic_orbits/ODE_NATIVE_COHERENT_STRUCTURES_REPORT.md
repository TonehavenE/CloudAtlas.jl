# ODE-Native Coherent Structures Report

Date: 2026-05-14

## 1. Gibson Orbit 1 Shadowing Benchmark

The Gibson orbit 1 experiment is now a shadowing benchmark, not a solved periodic-orbit result. Do not call the medium-loop or tiny-loop closures "the Gibson orbit".

| case | J,K,L | closure | I_span | D_span | interpretation |
|---|---:|---:|---:|---:|---|
| best large-span J2 Pareto recurrence | 2,4,7 | ~4.365366e-2 | ~0.304704 | ~0.335835 | Gibson-scale shadow |
| best medium/small J2 recurrence | 2,4,7 | ~1.060743e-2 | ~0.092166 | ~0.123814 | lower closure, reduced span |
| best large-span J3 diagnostic | 3,5,9 | ~3.107000e-2 | ~0.370290 | ~0.326065 | modest high-resolution improvement |

Conclusion: the ODE shadows Gibson-scale motion, but exact Gibson-scale periodic-orbit reproduction has not been achieved. Lower closure residuals currently come with reduced diagnostic span, so the result should be presented as a closure-versus-span Pareto tradeoff.

## 2. ODE-Native Recurrence Search

Script:

- `notebooks/periodic_orbits/ode_native_recurrence_scan.jl`

Outputs:

- `notebooks/periodic_orbits/ode_native_recurrence/ode_native_recurrence_candidates_J2_K4_L7.csv`
- `notebooks/periodic_orbits/ode_native_recurrence/ode_native_recurrence_pareto_J2_K4_L7.csv`
- `notebooks/periodic_orbits/ode_native_recurrence/closure_vs_minspan.png`
- `notebooks/periodic_orbits/ode_native_recurrence/id_span_classes.png`

Run settings:

- `J,K,L = 2,4,7`, `m = 169`
- `Re = 200`, `alpha = 1`, `gamma = 2`
- symmetry subgroup `<sxyz, sztxz>`
- 6 seeds: projected Gibson state, guarded large-loop state, previous N=8 large-loop state, near-equilibrium state, and 2 random symmetry-subspace states
- `T_final = 220`, `save_dt = 1`, recurrence window `[15, 100]`

Candidate summary:

| span class | count | best closure | max I_span | max D_span |
|---|---:|---:|---:|---:|
| tiny | 8 | 1.489529e-7 | 1.395112e-5 | 9.661003e-6 |
| small | 26 | 9.852750e-4 | 0.107438 | 0.095741 |
| medium | 14 | 3.402873e-2 | 0.215653 | 0.208217 |

Best representatives:

| class | seed | phase time | T | closure | I_span | D_span | note |
|---|---|---:|---:|---:|---:|---:|---|
| tiny | near_equilibrium_direct | 149 | 51.763932 | 1.489529e-7 | 1.341885e-5 | 9.484544e-6 | near-equilibrium loop |
| small | projected_gibson_orbit1 | 163 | 52.055728 | 9.852750e-4 | 0.065954 | 0.054721 | low closure but small span |
| medium | random_symmetry_2 | 26 | 14.111456 | 3.402873e-2 | 0.126169 | 0.111048 | best nontrivial native recurrence |
| medium, larger span | random_symmetry_1 | 55 | 18.111456 | 4.837877e-2 | 0.215653 | 0.201222 | larger span, higher closure |

No large-span ODE-native recurrence was found in this first J2 scan. The best nontrivial candidates are medium loops from random symmetry-subspace initial conditions, with closures around `3e-2` to `5e-2`.

## 3. J2 Refinement Attempt

Seed preparation script:

- `notebooks/periodic_orbits/ode_native_prepare_refinement_seed.jl`

Prepared seed:

- `notebooks/periodic_orbits/ode_native_recurrence/refinement_seeds/x0_best_medium_J2_K4_L7.asc`
- source: `random_symmetry_2`, phase time `26`, `T = 14.111456180002`

Exact-tangent multiple shooting:

- N = 8
- total period free: no total-period anchor, no per-segment time anchor
- guard homotopy: `1.0, 0.3, 0.1, 0.03, 0.0`
- 2 accepted iterations per guard weight
- diagnostic spans were sampled along each segment, not only at shooting nodes

Summary:

| iter | guard | total T | residual | continuity | closure | phase | I_span | D_span | defect |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | 1.0 | 14.111456 | 3.402961e-2 | 3.402873e-2 | 3.402873e-2 | 2.445e-4 | 0.126169 | 0.111044 | localized |
| 1 | 1.0 | 14.100327 | 3.399502e-2 | 3.399415e-2 | 3.399415e-2 | 2.439e-4 | 0.126052 | 0.110900 | localized |
| 2 | 0.3 | 14.089200 | 3.396043e-2 | 3.395956e-2 | 3.395956e-2 | 2.432e-4 | 0.125935 | 0.110756 | localized |
| 3 | 0.3 | 14.077991 | 3.392579e-2 | 3.392492e-2 | 3.392492e-2 | 2.426e-4 | 0.125817 | 0.110613 | localized |
| 4 | 0.1 | 14.066782 | 3.389113e-2 | 3.389027e-2 | 3.389027e-2 | 2.420e-4 | 0.125700 | 0.110469 | localized |
| 5 | 0.1 | 14.055380 | 3.385638e-2 | 3.385552e-2 | 3.385551e-2 | 2.414e-4 | 0.125583 | 0.110326 | localized |
| 6 | 0.03 | 14.043977 | 3.382161e-2 | 3.382076e-2 | 3.382076e-2 | 2.408e-4 | 0.125465 | 0.110183 | localized |
| 7 | 0.03 | 14.032151 | 3.378672e-2 | 3.378586e-2 | 3.378586e-2 | 2.403e-4 | 0.125347 | 0.110040 | localized |
| 8 | 0.0 | 14.020323 | 3.375182e-2 | 3.375097e-2 | 3.375097e-2 | 2.397e-4 | 0.125228 | 0.109898 | localized |
| 9 | 0.0 | 14.014324 | 3.281218e-2 | 3.281135e-2 | 3.281133e-2 | 2.327e-4 | 0.121739 | 0.104354 | localized |

Final saved state:

- `notebooks/periodic_orbits/gibson/ode_recurrence_attempt/multiple_shooting_continuation/x_ms_ode_native_medium_random2_resampledspan_N8_T14p111456_J2_K4_L7.asc`

Final per-segment mismatches:

| segment | mismatch norm |
|---:|---:|
| 1 | 1.76887e-5 |
| 2 | 1.51849e-5 |
| 3 | 1.36231e-5 |
| 4 | 1.21431e-5 |
| 5 | 1.13325e-5 |
| 6 | 1.05479e-5 |
| 7 | 9.83259e-6 |
| 8 | 3.28113e-2 |

Classification: medium-loop candidate / stalled large closing defect. It is not a solved periodic orbit. The span stayed above the `0.1` floor, but the closure decrease was modest and almost entirely localized in the final closing segment.

## 4. Hopf Branch Status

Existing Hopf/PO branch artifacts:

- `notebooks/periodic_orbits/eqb_hopf_detection.jl`
- `notebooks/periodic_orbits/eqb_hopf_outputs/po_branch_summary.csv`
- `notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/po_branch_summary.csv`
- `notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/eq1_branch_with_hopf.png`
- `notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/eigenvalue_landscape.png`
- `notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/hopf_frequency.png`
- `notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/po_branch_period.png`

The existing J3 Hopf-born PO branch summary has 22 continuation rows, with `Re` around `351.5` to `361.5` and period around `16.1` to `16.6`. This is promising, but it is not yet the requested `Re=200` ODE-native periodic-orbit result. It should be treated as the cleanest next route: equilibrium continuation -> Hopf point -> PO branch -> diagnostics -> DNS validation.

## 5. Recommendation

The best immediate path is not further Gibson forcing. The J2 recurrence search found native small and medium recurrences, but the first medium-loop exact-tangent refinement stalled at closure `3.281133e-2` with a localized final defect.

Recommended next step:

1. Extend the ODE-native recurrence scan with more random symmetry-subspace seeds and longer integrations.
2. Keep ranking by Pareto frontier, not closure alone.
3. Try N=16 multiple shooting only for medium candidates whose defect is not dominated by one closing segment.
4. Prioritize the Hopf workflow, because it provides a cleaner source of true ODE-native periodic orbit branches.
5. Defer DNS validation until an ODE PO is genuinely solved with zero guard and nontrivial span.

Current answer to the main question: yes, the CloudAtlas ODE model shows ODE-native recurrent coherent structures, especially small and medium loops, but this run did not yet produce a solved nontrivial ODE periodic orbit suitable for DNS validation.

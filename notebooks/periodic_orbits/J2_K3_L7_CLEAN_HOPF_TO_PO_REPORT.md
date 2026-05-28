# J2,K3,L7 Clean Hopf-to-PO Pipeline Report

Date: 2026-05-15

## Summary

The clean Hopf-to-periodic-orbit workflow was repeated at `J,K,L = 2,3,7`.

Main result:

```text
clean EQ branch -> clean Hopf -> saved PO states -> verified ODE closure
```

The best branch found is born from the down-leg Hopf near:

```text
Re_Hopf ≈ 270.091764
T_Hopf ≈ 71.836692
```

It continues to a verified medium-span ODE periodic orbit:

```text
Re ≈ 285.914860
T ≈ 86.722635
closure ≈ 4.31e-7
I_span ≈ 0.183765
D_span ≈ 0.195721
class = medium
```

This is the first saved, reconstructable, direct-closure-verified ODE-native PO in this workflow with nontrivial diagnostic span.

## Clean EQ Scans

Separate fixed-Re scans were run from the `Re=300` EQ seed.

Down leg:

```text
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/restartable_eq_branch_down/
```

Up leg:

```text
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/restartable_eq_branch_up/
```

Each accepted equilibrium solve saved state vectors, scalar metadata, eigenvalues, and run configuration.

## Clean Hopf Candidates

Tracked complex-pair crossings:

| leg | Re bracket | Re crossing | T estimate | unstable count change | status |
|---|---:|---:|---:|---:|---|
| down | 270-271 | 270.091764 | 71.836692 | 1 -> 3 | clean |
| up | 341-342 | 341.426970 | 19.793974 | 3 -> 5 | clean |
| up | 348-349 | 348.762424 | 179.512743 | 5 -> 3 | clean, loss of pair |
| up | 357-358 | 357.061903 | 6.156912 | 3 -> 5 | clean |

The down-leg `Re≈270.09` Hopf became the best target because its PO branch grew diagnostic span fastest.

Approximate equilibrium metadata near the main Hopf:

| Re | norm | power | unstable count | state |
|---:|---:|---:|---:|---|
| 270 | 0.273329 | 1.723737 | 1 | `restartable_eq_branch_down/states/xeq_step0031_Re270.00000000.asc` |
| 271 | 0.273849 | 1.726724 | 3 | `restartable_eq_branch_down/states/xeq_step0030_Re271.00000000.asc` |

## PO Branch Attempts

### Hopf near Re≈341.43

Output:

```text
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/clean_po_pipeline_j2_target341_long/
```

The branch continued to `Re=370` with verified direct closure, but remained tiny:

| Re | T | closure | I_span | D_span | class |
|---:|---:|---:|---:|---:|---|
| 370.0 | 20.335540 | 6.20e-8 | 0.025054 | 0.012138 | tiny |

The nominal opposite direction landed on essentially the same increasing-Re side.

### Hopf near Re≈357.06

Output:

```text
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/clean_po_pipeline_j2_target357_short/
```

This branch also verified cleanly, but stayed tiny over the short continuation:

| Re | T | closure | I_span | D_span | class |
|---:|---:|---:|---:|---:|---|
| 360.486723 | 6.148906 | 8.18e-9 | 0.006464 | 0.001968 | tiny |

### Hopf near Re≈270.09

Output:

```text
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/clean_po_pipeline_j2_target270_long/
```

This is the useful branch. It grew from tiny to medium span before continuation stalled near a difficult patch around `Re≈288.8`.

Representative medium PO:

| Re | T | closure | relative closure | I_span | D_span | E_span | class |
|---:|---:|---:|---:|---:|---:|---:|---|
| 285.914860 | 86.722635 | 4.31e-7 | 1.75e-6 | 0.183765 | 0.195721 | 0.011708 | medium |

Saved representative states:

```text
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/clean_po_pipeline_j2_target270_long/states/x0_natural_step019_Re285.914860_T86.722635.asc
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/clean_po_pipeline_j2_target270_long/restartable_po_branch/states/raw_natural_contstep0018_Re285.91486006_T86.72263465.asc
```

The next accepted row after the hard patch is a tiny near-equilibrium object at `Re≈288.76`, `T≈10.29`; it is not the representative PO and should not be treated as the same nontrivial branch segment.

## Plots and Diagnostics

For each PO attempt the script wrote:

```text
po_branch_diagnostics_J2_K3_L7.csv
po_period_vs_Re.png
po_spans_vs_Re.png
po_amplitude_vs_hopf_distance.png
representative_id_loops.png
restartable_po_branch/po_branch_summary_checkpointed.csv
restartable_po_branch/states/
```

The most important diagnostics are in:

```text
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/clean_po_pipeline_j2_target270_long/po_branch_diagnostics_J2_K3_L7.csv
```

## DNS Readiness

This branch is now DNS-diagnostic ready, but not DNS-Newton ready by default.

Recommended next DNS-side step:

1. Reconstruct/lift the representative ODE PO at `Re≈285.914860`.
2. Compute DNS one-period closure at `T≈86.722635`.
3. Only attempt DNS Newton/hookstep if the lifted DNS state is a credible near recurrence.

Reasons to be cautious:

- The absolute ODE closure is good (`4.31e-7`), but relative closure is slightly above `1e-6`.
- The period is long.
- The continuation encountered a hard patch shortly after the representative point.
- This is still a low-dimensional `J2,K3,L7` ODE object.

## Recommendation

Use the `Re≈285.914860`, `T≈86.722635` medium-span PO as the first ODE-native DNS-lift diagnostic candidate.

Before DNS Newton, do one cheap ODE-side cleanup/refinement:

```text
restart from the saved representative state,
verify closure with tighter tolerances / more samples,
optionally run a direct PO correction at fixed Re or nearby arclength.
```

If that remains stable, proceed to DNS lift/closure measurement.

## ODE-Space Refinement Update

Script:

```text
notebooks/periodic_orbits/ode_native_refine_saved_po.jl
```

The representative medium PO was refined at fixed `Re=285.91486006421275` using exact-tangent, phase-fixed single shooting.

Initial tight re-verification with `Vern9`, `abstol=reltol=1e-12`:

| T | closure | relative closure | I_span | D_span | class |
|---:|---:|---:|---:|---:|---|
| 86.722634646627 | 4.309e-7 | 1.745e-6 | 0.183812 | 0.195753 | medium |

One conservative exact-tangent Newton step gave:

| T | closure | relative closure | I_span | D_span | class |
|---:|---:|---:|---:|---:|---|
| 86.722759254085 | 1.300e-11 | 5.265e-11 | 0.183812 | 0.195753 | medium |

Independent tight re-verification of the saved refined state with `abstol=reltol=1e-12`:

| T | closure | relative closure | I_span | D_span | class |
|---:|---:|---:|---:|---:|---|
| 86.722759254085 | 1.300e-11 | 5.265e-11 | 0.183812 | 0.195753 | medium |

Refined outputs:

```text
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/clean_po_pipeline_j2_target270_long/ode_refinement/x0_refined.asc
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/clean_po_pipeline_j2_target270_long/ode_refinement/period_refined.txt
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/clean_po_pipeline_j2_target270_long/ode_refinement/shooting_refinement_iterations.csv
```

This confirms the object is a genuine solved ODE periodic orbit, not just a near recurrence.

## DNS Lift Time-Integration Check

Script:

```text
notebooks/periodic_orbits/ode_native_dns_lift_check.jl
```

The refined ODE PO was lifted to a Channelflow flowfield with `coeff2field` using
`EQ1Re300-32x49x40.nc` as the template, then integrated in DNS for one ODE
period at the same Reynolds number. This is a pure time-integration check, not a
DNS Newton solve.

Lifted state:

```text
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/clean_po_pipeline_j2_target270_long/dns_lift_check/u0_lifted_refined_po.nc
```

DNS parameters:

| Re | T | initial dt | final saved field |
|---:|---:|---:|---|
| 285.914860064213 | 86.722759254085 | 0.03125 | `u_dns_lift_po86.723.nc` |

Closure results:

| run | full-field L2 closure | relative L2 closure | projected coeff closure | projected coeff relative |
|---|---:|---:|---:|---:|
| symmetry-constrained DNS | 1.395360e-1 | 6.937686e-1 | 1.143925e-1 | 4.633578e-1 |
| unconstrained DNS repeat | 1.395360e-1 | 6.937686e-1 | 1.143925e-1 | 4.633578e-1 |

DNS energy-file endpoints from the symmetry-constrained run:

| t | L2 | ecf | dissipation |
|---:|---:|---:|---:|
| 0 | 0.201128 | 2.63383e-3 | 0.462493 |
| 86.7228 | 0.109573 | 2.60564e-6 | 0.0820033 |

Interpretation:

The ODE object is a verified medium-span ODE periodic orbit, but this lift is not
a DNS near recurrence. DNS time integration rapidly decays toward a much lower
perturbation-energy state over one ODE period. The unconstrained repeat matches
the symmetry-constrained result, so the nonclosure is not an artifact of applying
the symmetry file.

DNS output summaries:

```text
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/clean_po_pipeline_j2_target270_long/dns_lift_check/dns_lift_closure_summary.csv
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/clean_po_pipeline_j2_target270_long/dns_lift_check_nosymms/dns_lift_closure_summary.csv
```

## ODE Resolution-Lift Check

Script:

```text
notebooks/periodic_orbits/ode_native_resolution_lift_check.jl
```

The refined J2,K3,L7 representative PO was lifted into a J3,K5,L9 ODE model by:

```text
J2 coefficients -> coeff2field -> Channelflow flowfield -> field2coeff -> J3 coefficients
```

Projection mechanics were clean: the reconstructed J2 flowfield projected into
J3 with field-space reconstruction error `~1.27e-15`, and the J3 coefficient
norm matched the J2 norm to displayed precision.

Target model:

| source J,K,L | target J,K,L | Re | source T |
|---|---|---:|---:|
| 2,3,7 | 3,5,9 | 285.914860064213 | 86.722759254085 |

J3 ODE recurrence test:

| target test | T | closure | relative closure | I_span | D_span | class |
|---|---:|---:|---:|---:|---:|---|
| source period | 86.722759254085 | 1.482202e-1 | 6.003800e-1 | 8.138229e-1 | 1.337172e0 | large |
| best scan in `[0.7T,1.3T]` | 65.042069440564 | 1.142810e-1 | 4.629060e-1 | 8.138564e-1 | 1.337284e0 | large |

Interpretation:

The J2 PO embeds cleanly into the J3 coefficient space, but the J3 dynamics do
not preserve it as a near periodic orbit. The target trajectory has large
diagnostic span, but closure remains far from Newton-ready. This suggests that
the J2 PO is a genuine low-resolution ODE-native object rather than a direct
approximation to a higher-resolution/DNS periodic orbit.

Resolution-lift outputs:

```text
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/clean_po_pipeline_j2_target270_long/resolution_lift_2_3_7_to_3_5_9/resolution_lift_summary.csv
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/clean_po_pipeline_j2_target270_long/resolution_lift_2_3_7_to_3_5_9/target_period_scan.csv
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/clean_po_pipeline_j2_target270_long/resolution_lift_2_3_7_to_3_5_9/x0_target_projected.asc
```

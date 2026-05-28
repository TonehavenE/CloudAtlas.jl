# Hopf-Born ODE Periodic-Orbit Branch Status

Date: 2026-05-14

## 1. Why Recurrence Refinement Is Deprioritized

The ODE-native recurrence search produced useful closure-versus-span diagnostics, but the best nontrivial medium recurrence remained a near recurrence with a localized final closing defect. The N=8 exact-tangent multiple-shooting run reduced closure only from `3.402873e-2` to `3.281133e-2` while preserving `I_span=0.121739`, `D_span=0.104354`; nearly all residual remained in the final segment.

Per the current rule, recurrence refinement should stay paused unless a new candidate has either:

- closure `< 1e-3` with nontrivial span, or
- a non-localized multiple-shooting defect.

The cleaner route is now equilibrium continuation -> Hopf bifurcation -> ODE-native periodic-orbit branch.

## 2. Existing J3 Hopf Branch Artifacts

Loaded artifact:

- `notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/po_branch_summary.csv`

Associated available files:

- `notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/eq1_branch_with_hopf.png`
- `notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/eigenvalue_landscape.png`
- `notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/hopf_frequency.png`
- `notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/po_branch_period.png`
- `notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/xeq1_dns_projection_3_5_9.asc`
- `notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/xeq1_dns_projection_2_3_7.asc`

Important limitation: no periodic-orbit state vectors or collocation states are saved in the existing J3 Hopf output directory. The CSV stores only scalar branch summaries: `step, Re, period, norm, shear, power`.

Because of that, the existing artifact is sufficient for period/norm/power branch plots, but not sufficient to compute:

- one-period ODE closure,
- `I_min`, `I_max`, `I_span`,
- `D_min`, `D_max`, `D_span`,
- energy span,
- I-D loops,
- representative ODE PO state,
- DNS lift/closure readiness.

## 3. Existing Branch Summary

The existing J3 Hopf-born branch summary has 22 rows.

| quantity | value |
|---|---:|
| J,K,L | 3,5,9 |
| m | 367 |
| Re range | 351.508377 to 361.480580 |
| period range | 16.103514 to 16.693512 |
| norm range | 0.391095 to 0.423983 |
| power range | 1.444867 to 1.554328 |

Representative rows:

| step | Re | period | norm | shear | power |
|---:|---:|---:|---:|---:|---:|
| 1 | 351.508377 | 16.103514 | 0.391095 | 1.444867 | 1.444867 |
| 11 | 352.763667 | 16.290510 | 0.393900 | 1.458703 | 1.458703 |
| 22 | 361.480580 | 16.641057 | 0.423983 | 1.554328 | 1.554328 |

Generated scalar plots from the existing summary:

- `notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/diagnostics/existing_period_vs_Re.png`
- `notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/diagnostics/existing_norm_power_vs_Re.png`

These plots are scalar summaries only. They are not substitutes for I-D loop diagnostics.

## 4. Diagnostic Script Added

Added:

- `notebooks/periodic_orbits/eqb_hopf_branch_diagnostics.jl`

Purpose:

1. Rebuild the J3,K5,L9 ODE model.
2. Load the existing EQ1 projection.
3. Recompute the EQ1 continuation and Hopf point.
4. Continue the Hopf-born PO branch in the natural direction.
5. Attempt the opposite/lower-Re direction.
6. Extract each collocation branch state from `br_po.sol[i].x`.
7. Save branch-point initial states.
8. Integrate each branch point over one period and compute:
   - ODE closure,
   - `I_min`, `I_max`, `I_span`, `I_mean`,
   - `D_min`, `D_max`, `D_span`, `D_mean`,
   - energy min/max/span/mean,
   - span class,
   - representative I-D loops.

Expected outputs when the continuation completes:

- `notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/diagnostics/po_branch_diagnostics_J3_K5_L9.csv`
- `notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/diagnostics/po_period_vs_Re.png`
- `notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/diagnostics/po_spans_vs_Re.png`
- `notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/diagnostics/po_amplitude_vs_hopf_distance.png`
- `notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/diagnostics/representative_id_loops.png`
- saved branch-point states under `diagnostics/states/`

## 5. Attempted Recompute

Two recompute attempts were made:

1. Full range:
   - `HOPF_RE_MIN=100`, `HOPF_RE_MAX=700`, `HOPF_EQ_MAX_STEPS=800`
   - Stopped after the equilibrium continuation stage proved too slow for this turn.

2. Targeted range:
   - `HOPF_RE_MIN=280`, `HOPF_RE_MAX=390`, `HOPF_EQ_MAX_STEPS=260`
   - Completed the equilibrium continuation call but did not detect a Hopf point in that restricted run.

This means the existing March branch artifacts remain valid as scalar evidence that a J3 Hopf-born PO branch was computed, but the branch states need to be regenerated with a continuation configuration that reproduces the same Hopf detection and saves `br_po.sol`.

## 6. Best Representative ODE-Native PO

No representative ODE PO is selected yet.

Reason: the existing summary lacks saved periodic-orbit states, so closure and diagnostic spans cannot be verified. Selecting a representative from `po_branch_summary.csv` alone would risk reporting a scalar continuation point without proving:

- zero guard,
- one-period closure,
- nontrivial I/D span,
- meaningful I-D loop,
- DNS validation readiness.

The likely representative should come from the upper part of the existing branch, near steps 17-22, because those have the largest recorded norm/power and are less close to the Hopf onset. That remains a hypothesis until the states are regenerated.

## 7. DNS Validation Readiness

DNS validation is not ready.

Required before DNS lift:

1. Regenerate and save at least one collocation branch state.
2. Verify ODE closure by direct one-period integration.
3. Compute I-D and energy spans.
4. Select a nontrivial solved ODE PO.
5. Reconstruct/lift the ODE coefficients into Channelflow.
6. Compute DNS one-period closure.

No DNS Newton/hookstep should be attempted until the ODE PO state is verified.

## 8. Recommended Next Step

Modify or rerun the original Hopf notebook workflow so that it saves `br_po.sol[i].x` for every PO branch point at the moment the branch is successfully computed. The old run reached the desired branch but discarded the states, which are the critical data product.

Practical next run:

```text
CLOUDATLAS_SKIP_ACTIVATE=true \
HOPF_JKL=3x5x9 \
HOPF_RE_MIN=100 \
HOPF_RE_MAX=700 \
HOPF_EQ_MAX_STEPS=800 \
HOPF_PO_MAX_STEPS=40 \
HOPF_RUN_LOWER=true \
julia --startup-file=no --project=. notebooks/periodic_orbits/eqb_hopf_branch_diagnostics.jl
```

If that is too slow, the next improvement should not be another recurrence refinement. It should be a restartable Hopf workflow that serializes the equilibrium branch/Hopf point and the PO branch states as soon as they are produced.

Current answer to the central question: the existing artifacts show that CloudAtlas can produce a J3 Hopf-born ODE periodic-orbit branch, but the saved data are not sufficient yet to validate those orbits as closed nontrivial ODE POs or lift them to DNS.

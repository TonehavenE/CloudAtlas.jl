# Clean Hopf-to-PO Pipeline Status

Date: 2026-05-15

## Summary

The old `eqb_hopf_outputs_3_5_9/po_branch_summary.csv` is treated as an unreliable historical artifact. The current work instead builds a clean, restartable Hopf-to-periodic-orbit pipeline at `J,K,L = 1,2,5`.

The important outcome is mixed:

- The state-saving PO continuation workflow now works.
- A genuine BifurcationKit Hopf-born PO branch was continued and saved.
- The branch is a true solved ODE PO branch, but it remains small-span through `Re = 370`.
- The previously attractive tracked `T approx 16` crossing near `Re approx 347.44` is not a clean branch-switchable Hopf in this workflow.

## Workflow Changes

Updated script:

```text
notebooks/periodic_orbits/eqb_hopf_branch_diagnostics.jl
```

Added:

- `HOPF_TARGET_RE` to select the detected Hopf special point nearest a target Reynolds number.
- `HOPF_EQ_NEV` to increase the number of eigenvalues used in equilibrium continuation.
- `HOPF_RUN_NATURAL` / `HOPF_RUN_LOWER` to run one PO direction at a time.
- Immediate PO checkpointing through `finalise_solution`.

Every accepted PO continuation step now writes:

```text
restartable_po_branch/states/raw_*.asc
restartable_po_branch/states/x0_*.asc
restartable_po_branch/po_branch_summary_checkpointed.csv
```

This avoids the old scalar-only failure mode.

## Clean J1 Equilibrium Scans

### Downward Leg

Directory:

```text
notebooks/periodic_orbits/eqb_hopf_outputs_1_2_5/restartable_eq_branch_down/
```

Tracked crossing:

| branch | Re bracket | Re crossing | T estimate |
|---:|---:|---:|---:|
| 10 | 298-299 | 298.584 | 13.175 |

This is not the target `T approx 16` crossing.

### Upward Leg

Directory:

```text
notebooks/periodic_orbits/eqb_hopf_outputs_1_2_5/restartable_eq_branch_up/
```

Tracked crossings:

| branch | Re bracket | Re crossing | T estimate |
|---:|---:|---:|---:|
| 4 | 347-348 | 347.389 | 186.766 |
| 5 | 349-350 | 349.777 | 39.349 |
| 9 | 347-348 | 347.650 | 15.986 |
| 10 | 347-348 | 347.081 | 13.194 |

Refinement near `Re = 347.4..347.5` found:

| branch | Re bracket | Re crossing | T estimate |
|---:|---:|---:|---:|
| 1 | 347.43-347.44 | 347.436676 | 440.253 |
| 9 | 347.43-347.44 | 347.436516 | 15.9669 |
| 10 | 347.43-347.44 | 347.430819 | 13.1944 |

However, the `T approx 16` crossing is not a clean Hopf special point for branch switching. BifurcationKit does not detect it as the usable Hopf even with `HOPF_EQ_NEV=12`; the unstable count stays constant across the refined bracket while another complex branch crosses in the opposite direction nearby.

## Clean Branch-Switchable Hopf

The reproducible BifurcationKit Hopf point selected from the J1 branch is:

| J,K,L | Re_Hopf | PO period near Hopf | power near Hopf |
|---|---:|---:|---:|
| 1,2,5 | 349.776505522889 | 39.31 | about 1.714 |

This is not the old scalar artifact and should not be interpreted as a recovery of that branch. It is a clean ODE-native Hopf-born PO branch.

## PO Continuation

Main output directory:

```text
notebooks/periodic_orbits/eqb_hopf_outputs_1_2_5/clean_po_pipeline_j1_T39_long/
```

Files:

```text
po_branch_diagnostics_J1_K2_L5.csv
restartable_po_branch/po_branch_summary_checkpointed.csv
restartable_po_branch/states/
po_period_vs_Re.png
po_spans_vs_Re.png
po_amplitude_vs_hopf_distance.png
representative_id_loops.png
```

The natural-direction continuation saved 20 branch rows and 19 checkpointed continuation states. It reached `Re = 370`.

Representative endpoint:

| Re | T | closure | I_span | D_span | E_span | class |
|---:|---:|---:|---:|---:|---:|---|
| 370.0 | 36.801404 | 3.287e-8 | 0.062658 | 0.161106 | 0.002670 | small |

The one-period ODE closure is good. The diagnostic span is not tiny by the endpoint, but it is still only `small` because `min(I_span,D_span) < 0.10`.

## Lower-Re Attempt

Output directory:

```text
notebooks/periodic_orbits/eqb_hopf_outputs_1_2_5/clean_po_pipeline_j1_T39_lower/
```

Using `δp = -0.5` did not produce a lower-Re branch in practice. It converged onto the same increasing-Re side and also reached `Re = 370`, with essentially identical diagnostics:

| Re | T | closure | I_span | D_span | class |
|---:|---:|---:|---:|---:|---|
| 370.0 | 36.801404 | 3.289e-8 | 0.062658 | 0.161106 | small |

So this clean J1 Hopf branch currently does not provide a route toward `Re = 200`.

## DNS Readiness

Do not attempt DNS validation yet.

The branch now has saved and reconstructable ODE PO states with verified closure, but the representative orbit is only small-span at `Re=370`. It is useful as a pipeline proof and as a low-resolution ODE-native coherent structure, not yet as a strong DNS lifting candidate.

## Recommendation

The pipeline objective is achieved for `J1,K2,L5`: clean EQ branch, clean Hopf, saved PO states, verified ODE closure, and diagnostic plots.

Next step:

1. Repeat the same state-saving workflow at `J2,K3,L7`.
2. Only launch from a Hopf bracketed on a single continuous equilibrium branch.
3. Treat crossings with no unstable-count change, such as the J1 `T approx 16` crossing, as eigen-branch interactions rather than branch-switchable Hopf points until proven otherwise.
4. Continue DNS validation only if a saved PO branch produces at least medium diagnostic span with small ODE closure.

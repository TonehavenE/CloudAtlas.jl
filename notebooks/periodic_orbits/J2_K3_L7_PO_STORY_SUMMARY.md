# J2,K3,L7 ODE-Native Periodic Orbit: Discovery and Follow-Up Summary

## What We Found

The `J,K,L = 2,3,7` CloudAtlas ODE model has a genuine, solved, ODE-native
periodic orbit with nontrivial diagnostic span.

The representative refined orbit is:

| quantity | value |
|---|---:|
| Re | 285.914860064213 |
| period T | 86.722759254085 |
| ODE closure | 1.300e-11 |
| relative ODE closure | 5.265e-11 |
| I_span | 0.183811 |
| D_span | 0.195749 |
| span class | medium |

This is the first compelling result because it is not a recurrence-search
near miss and not a scalar-only continuation artifact. It has:

- a reproducible equilibrium branch,
- a clean Hopf crossing,
- saved periodic-orbit states,
- direct one-period ODE closure verification,
- exact-tangent ODE-space refinement,
- nontrivial `I,D` span.

## Why We Changed Strategy

Before this result, the main effort was to reproduce Gibson DNS periodic orbit 1
inside the ODE truncation. That produced useful shadowing diagnostics but not a
solved Gibson-scale ODE periodic orbit:

- Gibson-scale J2 recurrences retained large `I,D` span but stalled at closure
  around `4e-2`.
- Lower-closure recurrences existed, but their diagnostic span shrank and they
  were not Gibson-scale objects.
- J3 cheap diagnostics improved large-span closure only modestly.

The conclusion was that Gibson orbit 1 should be treated as a shadowing
benchmark for this ODE model, not as the immediate target object.

The workflow then pivoted to ODE-native coherent structures:

```text
ODE equilibrium branch -> Hopf bifurcation -> ODE periodic orbit -> diagnostics -> DNS lift test
```

## Provenance Correction Before the J2 Result

An old directory named like a J3 Hopf-born PO branch had scalar rows but no saved
collocation/state vectors. Reproducibility checks showed that the old J3-labeled
branch was not provenance-clean:

- the restartable `J3,K5,L9` scan did not reproduce the claimed Hopf crossing,
- the eigenperiods did not match the old scalar PO periods,
- nearby lower resolutions gave partial but inconsistent matches.

So that old branch was demoted to historical/noisy evidence. The new criterion
became: find a clean Hopf crossing on a reproducible branch and save all states.

## Pipeline Proof at J1,K2,L5

The first successful test of the new workflow was at `J,K,L = 1,2,5`.

That run established the checkpointed Hopf-to-PO machinery:

```text
clean EQ branch -> clean Hopf -> saved PO states -> direct ODE closure
```

The J1 branch produced verified periodic orbits, but they remained small-span.
It was therefore a pipeline proof, not the main scientific object.

## How the J2,K3,L7 PO Was Found

We repeated the clean pipeline at `J,K,L = 2,3,7`.

### 1. Clean Equilibrium Scans

Separate upward and downward equilibrium continuation scans were run from a
known `Re=300` equilibrium seed. The legs were saved separately:

```text
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/restartable_eq_branch_down/
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/restartable_eq_branch_up/
```

Each accepted equilibrium step saved:

- equilibrium state vector,
- Reynolds number,
- norm and power/shear,
- leading eigenvalues,
- unstable count,
- run configuration.

### 2. Clean Hopf Crossings

Several clean complex-pair crossings were found:

| leg | Re crossing | Hopf period estimate | unstable count change | status |
|---|---:|---:|---:|---|
| down | 270.091764 | 71.836692 | 1 -> 3 | clean |
| up | 341.426970 | 19.793974 | 3 -> 5 | clean |
| up | 348.762424 | 179.512743 | 5 -> 3 | clean loss of pair |
| up | 357.061903 | 6.156912 | 3 -> 5 | clean |

The down-leg Hopf near `Re = 270.091764` became the main target because its PO
branch grew diagnostic amplitude fastest.

### 3. State-Saving PO Continuation

Periodic-orbit continuation was launched from the clean `Re≈270.09` Hopf. The
run saved both raw continuation states and reconstructed initial conditions at
each accepted step:

```text
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/clean_po_pipeline_j2_target270_long/
```

The useful branch grew from tiny Hopf-born oscillations to a medium-span orbit.
The representative saved point before a hard continuation patch was:

| Re | T | direct closure | relative closure | I_span | D_span | class |
|---:|---:|---:|---:|---:|---:|---|
| 285.914860 | 86.722635 | 4.31e-7 | 1.75e-6 | 0.183765 | 0.195721 | medium |

Saved representative state:

```text
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/clean_po_pipeline_j2_target270_long/restartable_po_branch/states/x0_natural_contstep0018_Re285.91486006_T86.72263465.asc
```

The next accepted row jumped to a tiny near-equilibrium object near
`Re≈288.76`, `T≈10.29`; that is not treated as the same useful medium-span
object.

### 4. ODE-Space Refinement

The representative medium-span point was then refined at fixed
`Re=285.914860064213` using exact-tangent, phase-fixed single shooting:

```text
notebooks/periodic_orbits/ode_native_refine_saved_po.jl
```

One conservative Newton step improved the closure from `4.309e-7` to
`1.300e-11` without shrinking the loop:

| stage | T | closure | relative closure | I_span | D_span | class |
|---|---:|---:|---:|---:|---:|---|
| saved PO state | 86.722634646627 | 4.309e-7 | 1.745e-6 | 0.183811 | 0.195749 | medium |
| refined PO state | 86.722759254085 | 1.300e-11 | 5.265e-11 | 0.183811 | 0.195749 | medium |

Refined outputs:

```text
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/clean_po_pipeline_j2_target270_long/ode_refinement/x0_refined.asc
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/clean_po_pipeline_j2_target270_long/ode_refinement/period_refined.txt
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/clean_po_pipeline_j2_target270_long/ode_refinement/shooting_refinement_iterations.csv
```

This is why the object is a solved ODE periodic orbit, not merely a near
recurrence.

## What We Tried Next

### DNS Lift and Pure DNS Time Integration

The refined J2 PO was lifted to a Channelflow flowfield via `coeff2field`, then
integrated in DNS for one ODE period:

```text
notebooks/periodic_orbits/ode_native_dns_lift_check.jl
```

The DNS test was run both with the symmetry file and without symmetry
constraints. The results matched.

| run | full-field L2 closure | relative L2 closure | projected coefficient closure | projected coefficient relative |
|---|---:|---:|---:|---:|
| symmetry-constrained DNS | 1.395360e-1 | 6.937686e-1 | 1.143925e-1 | 4.633578e-1 |
| unconstrained DNS repeat | 1.395360e-1 | 6.937686e-1 | 1.143925e-1 | 4.633578e-1 |

The DNS perturbation energy decayed strongly:

| t | L2 | ecf | dissipation |
|---:|---:|---:|---:|
| 0 | 0.201128 | 2.63383e-3 | 0.462493 |
| 86.7228 | 0.109573 | 2.60564e-6 | 0.0820033 |

Conclusion:

The J2 object is not a DNS near recurrence. It decays substantially under DNS
over one ODE period, so DNS Newton/hookstep is not justified from this lift.

### Resolution Lift from J2,K3,L7 to J3,K5,L9

We also tested whether the J2 PO was closer to a richer ODE truncation before
going all the way to DNS:

```text
J2 coefficients -> coeff2field -> flowfield -> field2coeff -> J3 coefficients
```

Script:

```text
notebooks/periodic_orbits/ode_native_resolution_lift_check.jl
```

The projection mechanics were clean: the J2 reconstructed flowfield projected
into J3 with field-space reconstruction error around `1.27e-15`, and the
coefficient norm matched.

But the J3 dynamics did not preserve the orbit:

| target test | T | closure | relative closure | I_span | D_span | class |
|---|---:|---:|---:|---:|---:|---|
| J3 at J2 period | 86.722759254085 | 1.482202e-1 | 6.003800e-1 | 0.813823 | 1.337172 | large |
| best J3 scan in `[0.7T,1.3T]` | 65.042069440564 | 1.142810e-1 | 4.629060e-1 | 0.813856 | 1.337284 | large |

Conclusion:

The J2 PO embeds cleanly in the higher-dimensional basis, but it is not a near
periodic orbit of the J3 dynamics. The diagnostic span grows in J3, but closure
is far too large for refinement.

## Interpretation

The result is compelling, but with a specific scope:

```text
The CloudAtlas J2,K3,L7 ODE model contains a genuine ODE-native,
medium-span Hopf-born periodic orbit.
```

It does not yet imply:

```text
This orbit is a DNS periodic orbit, or even a strong DNS near recurrence.
```

The follow-up failures are scientifically useful:

- direct DNS lift fails by large relative closure and energy decay,
- J3 resolution lift fails by large J3 ODE closure,
- therefore the object appears to be native to the low-resolution ODE truncation.

## Why This Is Still the First Strong Result

Unlike the Gibson recurrence attempts, this object is solved to numerical
periodic-orbit tolerance in the ODE. Unlike the old J3-labeled scalar branch, it
has saved states and verified direct closure. Unlike the J1 pipeline proof, it
has medium diagnostic span.

The clean statement is:

```text
We have demonstrated a reproducible Hopf-to-periodic-orbit pipeline in
CloudAtlas and found a nontrivial ODE-native PO at J2,K3,L7.
The first DNS and higher-resolution ODE lift tests show that this particular
PO does not survive as a near recurrence outside the low-resolution model.
```

## Recommended Next Step

Use this as the benchmark for the pipeline, not as the DNS target.

The next scientifically useful step is to search for similarly clean Hopf-born
periodic-orbit branches at richer truncations, starting from reproducible Hopf
crossings and saving states from the beginning. A higher-resolution PO should be
DNS-lifted only after it has:

- verified ODE closure,
- nontrivial `I,D` span,
- and decent closure under one-resolution-up ODE dynamics.

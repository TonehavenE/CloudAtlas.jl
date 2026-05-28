# Resolution Persistence of ODE-Native Periodic Orbits

Date: 2026-05-18

## Summary

The `J2,K3,L7` CloudAtlas ODE model contains a genuine, saved,
reconstructable, medium-span ODE-native periodic orbit. It is the first
compelling periodic-orbit result in this workflow because it was produced by a
clean Hopf-to-PO pipeline and verified by direct ODE time integration.

The same object does not currently pass the next scientific filter:
resolution persistence. It does not lift to a DNS near recurrence, and it does
not remain a near recurrence when lifted into the `J3,K5,L9` ODE model.

The current safe claim is:

```text
The J2,K3,L7 PO is a genuine low-resolution ODE-native periodic orbit,
but not yet a DNS-relevant coherent state.
```

## Quick DNS Findsoln Check

Although the DNS time-integration closure was poor, a bounded DNS `findsoln`
orbit correction was attempted on the lifted J2 PO projection as a sanity check.
This was intentionally limited to one Newton attempt with a very small GMRES
budget.

Input:

```text
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/clean_po_pipeline_j2_target270_long/dns_lift_check/u0_lifted_refined_po.nc
```

Output directory:

```text
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/clean_po_pipeline_j2_target270_long/dns_findsoln_quick/
```

Parameters:

| setting | value |
|---|---:|
| Re | 285.914860064213 |
| T | 86.722759254085 |
| dt | 0.03125 |
| symmetry group | `<sxyz, sztxz>` |
| Newton steps | 1 |
| GMRES budget | 3 |
| hookstep budget | 3 |

Result:

| quantity | value |
|---|---:|
| initial `L2Norm(G(x))` | 0.125854 |
| initial objective `1/2 ||G(x)||^2` | 0.00791956 |
| Newton-step norm | 0.192641 |
| initial trust radius | 0.01 |
| status | hookstep failed; returned best answer so far |

Interpretation:

The DNS Newton check did not converge and did not find an acceptable first
hookstep. This is consistent with the earlier pure DNS time-integration result:
the lifted J2 PO is not in an obvious DNS Newton basin.

## Archived J2,K3,L7 Periodic Orbit

Hopf source:

| quantity | value |
|---|---:|
| J,K,L | 2,3,7 |
| Hopf Re | 270.091764 |
| Hopf period estimate | 71.836692 |
| unstable count change | 1 -> 3 |

Representative refined PO:

| quantity | value |
|---|---:|
| Re | 285.914860064213 |
| period T | 86.722759254085 |
| ODE closure | 1.300e-11 |
| relative ODE closure | 5.265e-11 |
| I_span | 0.183812 |
| D_span | 0.195753 |
| class | medium |

Saved files:

```text
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/clean_po_pipeline_j2_target270_long/ode_refinement/x0_refined.asc
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/clean_po_pipeline_j2_target270_long/ode_refinement/period_refined.txt
notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/clean_po_pipeline_j2_target270_long/ode_refinement/shooting_refinement_iterations.csv
```

This object was obtained by:

```text
clean EQ branch -> clean Hopf -> saved PO branch -> direct ODE verification -> exact-tangent refinement
```

It should be archived as a successful low-resolution ODE result.

## DNS Lift Result

The refined J2 PO was lifted to a Channelflow flowfield with `coeff2field`, then
integrated in DNS for one ODE period.

| run | full-field L2 closure | relative L2 closure | projected coefficient closure | projected coefficient relative |
|---|---:|---:|---:|---:|
| symmetry-constrained DNS | 1.395360e-1 | 6.937686e-1 | 1.143925e-1 | 4.633578e-1 |
| unconstrained DNS repeat | 1.395360e-1 | 6.937686e-1 | 1.143925e-1 | 4.633578e-1 |

DNS endpoint drift:

| t | L2 | ecf | dissipation |
|---:|---:|---:|---:|
| 0 | 0.201128 | 2.63383e-3 | 0.462493 |
| 86.7228 | 0.109573 | 2.60564e-6 | 0.0820033 |

Conclusion:

```text
Verified ODE PO, not a DNS near recurrence.
```

## Resolution-Lift Diagnostic

For a future ODE PO candidate at source resolution `J,K,L`, the standardized
next-resolution lift test is:

1. Convert source coefficients to a velocity field with `coeff2field`.
2. Project that field into the target ODE basis with `field2coeff`.
3. Integrate the target ODE over the source period.
4. Scan target periods in `[0.7T, 1.3T]`.
5. Report source closure/spans and target closure/spans.

Required fields:

```text
source J,K,L
target J,K,L
Re
source T
source closure
source I_span, D_span
target closure at source T
target relative closure at source T
best target T
best target closure
best target relative closure
target I_span, D_span
classification
```

Classification:

| class | next-resolution relative closure |
|---|---:|
| excellent persistence | < 1e-3 |
| promising | < 1e-2 |
| weak | < 1e-1 |
| poor | >= 1e-1 |

Reusable script:

```text
notebooks/periodic_orbits/ode_native_resolution_lift_check.jl
```

## J2 -> J3 Resolution Persistence Table

The refined J2 PO was lifted into `J3,K5,L9`:

```text
J2 coefficients -> coeff2field -> flowfield -> field2coeff -> J3 coefficients
```

Projection mechanics were clean. The reconstructed J2 flowfield projected into
J3 with field-space reconstruction error `~1.27e-15`, so the failure below is
dynamical, not a projection-format issue.

| source | target | Re | test | T | relative closure | I_span | D_span | persistence |
|---|---|---:|---|---:|---:|---:|---:|---|
| J2,K3,L7 | J3,K5,L9 | 285.914860 | source period | 86.722759 | 6.003800e-1 | 0.813823 | 1.337172 | poor |
| J2,K3,L7 | J3,K5,L9 | 285.914860 | best scan | 65.042069 | 4.629060e-1 | 0.813856 | 1.337284 | poor |

Conclusion:

The J2 PO embeds into the richer basis, but it is not a near periodic orbit of
the J3 dynamics.

## J3,K5,L9 Clean Hopf Scan Status

Fresh coarse restartable scans were run in separate directories:

```text
notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/restartable_eq_branch_down_clean/
notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/restartable_eq_branch_up_clean/
```

These scans used the explicit `J3,K5,L9` model with:

```text
alpha = 1
gamma = 2
symmetry group = <sxyz, sztxz>
```

### Upward Clean Scan

Range:

```text
Re = 300, 305, ..., 370
```

Result:

| Re range | unstable count | leading complex real part | period estimate |
|---|---:|---:|---:|
| 300 -> 370 | 1 throughout | -3.6129e-2 -> -2.6438e-2 | 65.217644 -> 70.845290 |

No unstable-count change and no complex-pair crossing were found.

### Downward Clean Scan

Range:

```text
Re = 300, 295, ..., 250
```

Result:

| Re range | unstable count | leading complex real part | period estimate |
|---|---:|---:|---:|
| 300 -> 250 | 1 throughout | -3.6129e-2 -> -4.4856e-2 | 65.217644 -> 59.247730 |

No unstable-count change and no complex-pair crossing were found.

### J3 Hopf Candidates

No clean J3 Hopf candidate was found on this equilibrium branch over
`250 <= Re <= 370` in the coarse clean scans.

Therefore no J3 PO continuation was launched from these scans.

## DNS Readiness Assessment

The current J2 PO is not DNS-Newton-ready:

- DNS relative closure is `~0.694`,
- projected DNS endpoint closure is `~0.463`,
- DNS perturbation energy decays strongly over one period,
- quick DNS `findsoln` did not find an acceptable first hookstep,
- next-resolution J3 relative closure is `~0.46` to `0.60`.

A future candidate should only proceed to DNS Newton if:

```text
native ODE closure << 1e-6
min(I_span, D_span) >= 0.10
next-resolution relative closure is at least weak/promising
DNS relative closure < 0.1
no rapid energy decay over one DNS period
```

## Current Answer to the Central Question

Central question:

```text
Which ODE-native periodic orbits persist under resolution increase,
and are any of them credible DNS near recurrences?
```

Current answer:

```text
The verified J2,K3,L7 PO does not persist to J3,K5,L9 and is not a DNS near
recurrence. No clean J3,K5,L9 Hopf-born PO branch has yet been found on the
tested EQ branch segment 250 <= Re <= 370.
```

## Recommended Next Step

Continue the J3-native search, but broaden it rather than forcing the J2 object:

1. Refine/extend clean J3 equilibrium scans beyond `250 <= Re <= 370`.
2. Track additional complex eigenbranches, not only the leading complex pair.
3. If no Hopf appears on this branch, search other reproducible J3 equilibrium
   branches.
4. Launch PO continuation only from clean J3 Hopf crossings with a clear
   unstable-count change.
5. Apply the resolution-lift diagnostic before any DNS Newton attempt.

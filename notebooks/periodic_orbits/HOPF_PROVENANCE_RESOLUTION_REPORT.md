# Hopf Branch Provenance Resolution Report

Date: 2026-05-15

## 1. Old Artifact Inspection

Inspected:

```text
notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/
```

File chronology:

| timestamp | file |
|---|---|
| 2026-03-28 12:44 | `xeq1_dns_projection_3_5_9.asc` |
| 2026-03-28 13:04 | `projectfield.args` |
| 2026-03-28 13:04 | `xeq1_dns_projection_2_3_7.asc` |
| 2026-03-28 13:06 | `eq1_branch_with_hopf.png`, `eigenvalue_landscape.png`, `hopf_frequency.png` |
| 2026-03-29 12:06 | `po_branch_period.png`, `po_branch_summary.csv` |

State-vector dimensions:

| file | numeric count | matches |
|---|---:|---|
| `xeq1_dns_projection_3_5_9.asc` | 367 | J3,K5,L9 |
| `xeq1_dns_projection_2_3_7.asc` | 132 | J2,K3,L7 |

`po_branch_summary.csv` has no hidden metadata or comments. It contains only:

```text
step,Re,period,norm,shear,power
```

The old scalar PO branch summary is:

| quantity | value |
|---|---:|
| Re range | 351.508377 to 361.480580 |
| period range | 16.103514 to 16.693512 |
| norm range | 0.391095 to 0.423983 |
| power range | 1.444867 to 1.554328 |

Conclusion: the old `eqb_hopf_outputs_3_5_9` directory is not provenance-clean. It contains valid J3 and J2 projection files, but the PO summary itself has no resolution metadata and no saved states.

## 2. Restartable Scans Run

Added eigen-branch tracker:

- `notebooks/periodic_orbits/eqb_hopf_track_eigenpairs.jl`

The tracker reads saved leading eigenvalues, greedily matches complex pairs across Re, writes tracked branches, and reports sign crossings.

Restartable scan outputs now include:

- `eq_branch_metadata.csv`
- `eq_branch_leading_eigenvalues.csv`
- saved equilibrium states under `states/`
- `tracked_complex_eigenbranches.csv`
- `tracked_complex_crossings.csv`
- tracking plots:
  - `tracked_complex_real_vs_Re.png`
  - `tracked_complex_period_vs_Re.png`

## 3. Candidate Configuration Comparison

Old scalar branch target:

```text
Re ~351.5--361.5
period ~16.1--16.7
power ~1.44--1.55
```

Restartable scan comparison:

| J,K,L | crossing found? | Re_cross | T_cross | nearest power | nearest norm | match assessment |
|---|---:|---:|---:|---:|---:|---|
| 1,2,5 | yes | 347.301227 | 15.974517 | 1.708175 | 0.255123 | best period match, power too high |
| 2,3,7 upward scan | yes | 341.452559 | 19.794707 | 2.212370 | 0.334570 | period close-ish, power too high |
| 2,3,7 lower scan branch-jump point | yes | 299.591633 | 17.399851 | 1.493683 | 0.231766 | period/power close, Re wrong and branch jump contaminated |
| 2,4,7 | no | - | - | - | - | no crossing in logged eigenvalues |
| 3,5,9 | no | - | - | - | - | no crossing in logged eigenvalues |

## 4. J3,K5,L9 Result

The explicit restartable J3,K5,L9 scan over Re 301--370 found:

- unstable count = 1 throughout,
- leading complex pair stable throughout,
- period estimate ~65--71,
- no tracked complex sign crossing in logged eigenvalues.

This does not support treating the old scalar branch as a verified J3,K5,L9 Hopf-born PO branch.

## 5. J2,K3,L7 Result

The prior J2,K3,L7 upward scan found a tracked crossing:

```text
Re_cross ~341.452559
T_cross  ~19.794707
power    ~2.212370
```

The lower-Re scan found:

```text
Re_cross ~270.092
T_cross  ~71.837
```

and also a crossing estimate near:

```text
Re_cross ~299.592
T_cross  ~17.400
power    ~1.494
```

However, that latter point occurs across a discontinuity introduced by the scan path jumping from Re 250 back to Re 300, so it should be treated as a branch-switch warning rather than a clean Hopf bracket.

## 6. J1,K2,L5 Result

The J1,K2,L5 scan found the closest period match:

```text
Re_cross ~347.301227
T_cross  ~15.974517
power    ~1.708175
```

This is close to the old PO period but still does not match the old scalar branch power range `1.44--1.55`.

## 7. Current Provenance Conclusion

The old scalar PO branch is still not provenance-clean.

Most likely interpretations:

1. The old branch was not the current explicit J3,K5,L9 fixed-Re EQ branch.
2. It may have been computed from another equilibrium branch or an interactive configuration state.
3. It may involve a lower resolution, but neither J1,K2,L5 nor J2,K3,L7 perfectly reproduces all old scalar features.

The safest statement is:

```text
The old J3-labeled PO branch should not be cited as a verified J3 Hopf-born branch.
```

## 8. Next Step

Do not launch PO continuation yet.

The next useful run is a clean two-leg scan that avoids hidden branch jumps:

1. Downward leg from Re 300 to lower Re, saved in its own directory.
2. Upward leg from Re 300 to higher Re, saved in its own directory.

For the main suspect configurations:

```text
J,K,L = 1,2,5
J,K,L = 2,3,7
```

Then refine any crossing whose estimated period is in the `16--20` range using a clean bracket on a single continuous branch. Only after that should a state-saving PO continuation be launched.

DNS validation remains blocked until a saved PO state has verified ODE closure and nontrivial I-D diagnostics.

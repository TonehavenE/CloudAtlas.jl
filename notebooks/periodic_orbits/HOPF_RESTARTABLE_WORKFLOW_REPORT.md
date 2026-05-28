# Restartable Hopf Workflow Report

Date: 2026-05-14

## 1. Old Workflow Audit

Target artifact:

- `notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/po_branch_summary.csv`

Existing scalar branch summary:

| quantity | value |
|---|---:|
| rows | 22 |
| Re range | 351.508377 to 361.480580 |
| period range | 16.103514 to 16.693512 |
| norm range | 0.391095 to 0.423983 |
| power range | 1.444867 to 1.554328 |

Available files in the old output directory:

- `eq1_branch_with_hopf.png`
- `eigenvalue_landscape.png`
- `hopf_frequency.png`
- `po_branch_period.png`
- `po_branch_summary.csv`
- `xeq1_dns_projection_3_5_9.asc`
- `xeq1_dns_projection_2_3_7.asc`
- `projectfield.args`

Audit result:

- The tracked script `notebooks/periodic_orbits/eqb_hopf_detection.jl` currently defaults to `J,K,L = 1,2,5`, not `3,5,9`.
- The checkpoint copy `notebooks/periodic_orbits/.ipynb_checkpoints/eqb_hopf_detection-checkpoint.jl` also defaults to `J,K,L = 1,2,5`.
- There is no committed history for `eqb_hopf_detection.jl`, so the exact interactive edit that produced the J3-labeled output is not recoverable from git.
- The old J3 output directory contains both `xeq1_dns_projection_3_5_9.asc` and `xeq1_dns_projection_2_3_7.asc`; the `2_3_7` projection was written on March 28, 2026 at 13:04, minutes before the old branch/eigenvalue plots.
- The old PO summary was written on March 29, 2026 at 12:06, but no PO states or collocation vectors were saved.

Working interpretation:

```text
The old scalar PO branch is real evidence that a Hopf-born branch was computed,
but the output directory is not sufficient to prove that the branch was J3,K5,L9.
The presence of a 2,3,7 projection in the same J3-labeled output directory is a
configuration-contamination warning.
```

## 2. Restartable EQ Branch Workflow

Added:

- `notebooks/periodic_orbits/eqb_hopf_restartable_eq_scan.jl`

This script avoids a long non-checkpointed PALC run. It performs fixed-Re EQ solves using the previous equilibrium as the next initial guess, and after every accepted solve it immediately saves:

- equilibrium state `.asc`,
- metadata row,
- leading eigenvalues,
- run configuration,
- git revision (`cff9083f` for this run).

Output layout:

```text
notebooks/periodic_orbits/eqb_hopf_outputs_<J>_<K>_<L>/restartable_eq_branch/
  run_config.txt
  eq_branch_metadata.csv
  eq_branch_leading_eigenvalues.csv
  states/
    xeq_stepXXXX_ReYYYY.asc
```

## 3. J3,K5,L9 Restartable Scan

Run:

```text
CLOUDATLAS_SKIP_ACTIVATE=true
HOPF_JKL=3x5x9
HOPF_SCAN_RE_START=330
HOPF_SCAN_RE_STOP=370
HOPF_SCAN_DRE=1
HOPF_RESUME=true
julia --startup-file=no --project=. notebooks/periodic_orbits/eqb_hopf_restartable_eq_scan.jl
```

Outputs:

- `notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/restartable_eq_branch/eq_branch_metadata.csv`
- `notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/restartable_eq_branch/eq_branch_leading_eigenvalues.csv`
- `notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/restartable_eq_branch/states/`
- `notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/restartable_eq_branch/max_complex_real_vs_Re.png`
- `notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/restartable_eq_branch/hopf_period_estimate_vs_Re.png`
- `notebooks/periodic_orbits/eqb_hopf_outputs_3_5_9/restartable_eq_branch/unstable_count_vs_Re.png`

Summary:

| quantity | value |
|---|---:|
| rows | 70 |
| Re range | 301 to 370 |
| unstable count | 1 throughout |
| max complex real range | -3.594831e-2 to -2.643848e-2 |
| linear period estimate range | 65.321565 to 70.845290 |

Near the old PO branch region:

| Re | norm | power | unstable | max complex Re(lambda) | Im(lambda) | 2pi/omega |
|---:|---:|---:|---:|---:|---:|---:|
| 342 | 0.232888 | 1.46911 | 1 | -2.94771e-2 | -9.11142e-2 | 68.9595 |
| 350 | 0.233009 | 1.46853 | 1 | -2.84861e-2 | -9.03538e-2 | 69.5398 |
| 352 | 0.233040 | 1.46839 | 1 | -2.82536e-2 | -9.01730e-2 | 69.6792 |
| 361 | 0.233181 | 1.46785 | 1 | -2.72838e-2 | -8.94007e-2 | 70.2812 |
| 370 | 0.233324 | 1.46737 | 1 | -2.64385e-2 | -8.86886e-2 | 70.8453 |

Conclusion for J3 fixed-Re branch:

- This scan did not reproduce a Hopf crossing near Re 351-361.
- The leading complex pair is stable in this region.
- Its period estimate is about 70, not the old PO period 16-17.
- This is likely not the branch/configuration that produced the old scalar PO summary.

## 4. J2,K3,L7 Probe Because Of Audit Warning

Because the J3-labeled output directory contains `xeq1_dns_projection_2_3_7.asc`, I ran the same restartable scan at `J,K,L = 2,3,7`.

Run:

```text
CLOUDATLAS_SKIP_ACTIVATE=true
HOPF_JKL=2x3x7
HOPF_SCAN_RE_START=330
HOPF_SCAN_RE_STOP=370
HOPF_SCAN_DRE=2
HOPF_RESUME=false
julia --startup-file=no --project=. notebooks/periodic_orbits/eqb_hopf_restartable_eq_scan.jl
```

Outputs:

- `notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/restartable_eq_branch/eq_branch_metadata.csv`
- `notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/restartable_eq_branch/eq_branch_leading_eigenvalues.csv`
- `notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/restartable_eq_branch/states/`
- `notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/restartable_eq_branch/max_complex_real_vs_Re.png`
- `notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/restartable_eq_branch/hopf_period_estimate_vs_Re.png`
- `notebooks/periodic_orbits/eqb_hopf_outputs_2_3_7/restartable_eq_branch/unstable_count_vs_Re.png`

Summary:

| quantity | value |
|---|---:|
| rows | 35 |
| Re range | 302 to 370 |
| unstable count | 3 or 5 |
| max complex real range | 4.317122e-3 to 4.496327e-2 |
| linear period estimate range | 19.808929 to 263.644640 |

Near the old PO branch region:

| Re | norm | power | unstable | max complex Re(lambda) | Im(lambda) | 2pi/omega |
|---:|---:|---:|---:|---:|---:|---:|
| 344 | 0.336109 | 2.22878 | 5 | 4.31712e-3 | -3.17190e-1 | 19.8089 |
| 346 | 0.337520 | 2.24429 | 5 | 7.20593e-3 | -3.16899e-1 | 19.8271 |
| 350 | 0.340164 | 2.27471 | 3 | 1.22330e-2 | -3.16104e-1 | 19.8770 |
| 352 | 0.341480 | 2.29053 | 3 | 1.44818e-2 | -3.15589e-1 | 19.9094 |
| 360 | 0.347029 | 2.36201 | 5 | 2.13499e-2 | -3.12061e-1 | 20.1345 |

Conclusion for J2,K3,L7 probe:

- This branch shows eigenvalue-instability changes in the old Re region.
- It has a complex pair with linear period near 20, much closer to the old PO period 16-17 than the J3 fixed-Re scan.
- It still does not exactly match the old scalar branch power/norm values.
- This supports the configuration-mismatch hypothesis, but does not prove the old PO branch was J2,K3,L7.

## 5. Hopf Detection Status

No verified Hopf point suitable for PO continuation was selected in this turn.

Current status:

- J3,K5,L9 fixed-Re checkpoint scan: no crossing in Re 301-370.
- J2,K3,L7 checkpoint probe: unstable-count changes and positive complex pair in Re 342-370, but not yet a clean bracketing of a Hopf crossing from negative to positive because the scan started after that pair was already unstable.

The next focused scan should bracket the J2,K3,L7 crossing at lower Re, e.g. `Re=250..345`, and should increase eigenvalue logging if needed.

## 6. Restartable PO Branch Status

No PO branch continuation was launched from the new checkpointed scans.

Reason: launching a PO branch before resolving the branch/configuration mismatch would recreate the same failure mode as the old workflow: a potentially expensive computation whose interpretation is ambiguous.

The existing `eqb_hopf_branch_diagnostics.jl` can save `br_po.sol[i].x` after a successful BK PO branch run, but the more robust next step is to start that PO branch only after the restartable EQ/eigen scan has identified the actual Hopf point and resolution.

## 7. DNS Readiness

DNS validation is still not ready.

Required before DNS lifting:

1. Confirm the actual resolution/configuration of the Hopf point.
2. Save the PO branch state/collocation vectors.
3. Verify one-period ODE closure by direct integration.
4. Compute nontrivial I-D and energy spans.
5. Select a representative solved ODE PO.

No DNS Newton/hookstep should be attempted from scalar branch summaries.

## 8. Recommended Next Step

Do not run a full blind J3 `Re=100..700` sweep.

Run a restartable lower-Re scan for the suspicious `J2,K3,L7` branch to bracket the instability crossing:

```text
CLOUDATLAS_SKIP_ACTIVATE=true \
HOPF_JKL=2x3x7 \
HOPF_SCAN_RE_START=250 \
HOPF_SCAN_RE_STOP=345 \
HOPF_SCAN_DRE=1 \
HOPF_RESUME=false \
julia --startup-file=no --project=. notebooks/periodic_orbits/eqb_hopf_restartable_eq_scan.jl
```

In parallel, preserve the J3 checkpoint data and do not discard it: it is useful evidence that the current explicit J3,K5,L9 fixed-Re branch does not match the old PO summary.

Once a crossing is bracketed, start a state-saving PO continuation from that exact Hopf point and save `br_po.sol[i].x` immediately.

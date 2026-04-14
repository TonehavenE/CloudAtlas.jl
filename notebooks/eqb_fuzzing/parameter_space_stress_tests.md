# EQB Parameter-Space Stress Tests

Goal: test how well the ODE equilibrium discovery model explores beyond the current catalog, especially large boxes and high Reynolds number.

## Main Diagnosis

The existing `Lx=10, Lz=120` hugebox runs are not just "finding nothing"; they are converging to states rejected by the norm filter:

| Run | JKL | Attempts | Hookstep converged | Accepted postfilter | Unique |
|---|---:|---:|---:|---:|---:|
| `eqb_discovery_re400_lx10_lz120_scan50` | `1x3x5` | 350 | 310 | 0 | 0 |
| `eqb_discovery_re400_lx10_lz120_quickE` | `1x3x5` | 200 | 189 | 0 | 0 |
| `eqb_discovery_re400_lx10_lz120_playground` | `1x10x5` | 5000 | 1926 | 0 | 0 |

For the successful `Lz=6` baseline, `K=3` reaches physical spanwise wavenumber `K * 2pi/Lz = pi`. In `Lz=120`, the equivalent cutoff is `K=60`. A periodic copy of any `Lz=6` solution into `Lz=120` maps `k -> 20k`, so even the first nonzero spanwise harmonic needs `K >= 20`. The current `K=10` hugebox test cannot represent those copied states.

Dimension preflight, by symmetry:

| JKL | F m | F dense-N est. | E m | E dense-N est. | G m | G dense-N est. |
|---|---:|---:|---:|---:|---:|---:|
| `1x3x5` | 30 | 0.000 GB | 59 | 0.002 GB | 116 | 0.012 GB |
| `1x10x5` | 83 | 0.005 GB | 174 | 0.042 GB | 347 | 0.334 GB |
| `1x20x5` | 163 | 0.035 GB | 339 | 0.312 GB | 677 | 2.482 GB |
| `1x40x5` | 323 | 0.270 GB | 669 | 2.396 GB | 1337 | 19.129 GB |
| `1x60x5` | 483 | 0.902 GB | 999 | 7.976 GB | 1997 | 63.713 GB |
| `2x20x7` | 381 | 0.442 GB | 769 | 3.637 GB | 1538 | 29.104 GB |
| `2x40x7` | 751 | 3.390 GB | 1519 | 28.041 GB | 3038 | 224.362 GB |

This is why the runnable harness starts hugebox tests with symmetry `F`. With the current constructor, `N` is first allocated as a dense `m x m x m` tensor before it becomes sparse; `E` at `1x60x5` is already about 8 GB for that tensor alone.

## Runnable Harness

Use the driver:

```bash
SUITE=huge_probe DRY_RUN=true bash notebooks/eqb_fuzzing/run_parameter_space_stress_tests.sh
```

Actually run the conservative hugebox probe:

```bash
SUITE=huge_probe DRY_RUN=false bash notebooks/eqb_fuzzing/run_parameter_space_stress_tests.sh
```

Run one case:

```bash
SUITE=huge_probe ONLY_CASE=huge_re400_lx10_lz120_k60_F DRY_RUN=false bash notebooks/eqb_fuzzing/run_parameter_space_stress_tests.sh
```

The driver writes outputs under ignored `notebooks/eqb_fuzzing/stress_tests/{SUITE}/` and skips cases whose estimated dense `N` allocation exceeds `MAX_N_GB` unless `ALLOW_LARGE_N=true`.

Override symmetries and attempts with:

```bash
SYMMETRIES=E,F ATTEMPTS=10000 SUITE=huge_probe DRY_RUN=false bash notebooks/eqb_fuzzing/run_parameter_space_stress_tests.sh
```

Minimal-cell low-shear fuzzing, `JKL=1x3x5`, all groups, `100000` attempts, band `[1,3]`:

```bash
SUITE=minimal_low_shear DRY_RUN=true bash notebooks/eqb_fuzzing/run_parameter_space_stress_tests.sh
SUITE=minimal_low_shear DRY_RUN=false bash notebooks/eqb_fuzzing/run_parameter_space_stress_tests.sh
python3 notebooks/eqb_fuzzing/summarize_stress_test_stats.py notebooks/eqb_fuzzing/stress_tests/minimal_low_shear
```

## Test 0: Control Reproducibility

Purpose: verify the runner still finds known-domain solutions before spending time on new regimes.

Run small samples at existing catalog geometries:

| Case | Re | Lx | Lz | Ladder | Symmetries | Attempts | Expected |
|---|---:|---:|---:|---|---|---:|---|
| `ctrl_re400_lx10_lz6` | 400 | 10 | 6 | `1x3x5` | `A,B,C,D,E,F,G` | 5000 | nonzero accepted and unique in several groups |
| `ctrl_re400_lx2pi_lzpi` | 400 | `2pi` | `pi` | `1x3x5` | `A,B,C,D,E,F,G` | 5000 | nonzero accepted and unique, lower hit rate than `10x6` |

If these fail, stop and debug the runner or current code changes before testing new physics.

## Test 1: Hugebox Representability Scan

Purpose: determine whether the `Lz=120` failure is mostly because `K` was too small.

Fixed parameters: `Lx=10`, `Lz=120`, `Re=400`, shear band `[3,7]`, ladder is a single level.

| Test | Ladder | Symmetries | Attempts | Reason |
|---|---|---|---:|---|
| `huge_re400_lx10_lz120_k10_F` | `1x10x5` | `F` | 5000 | reproduces the current failure mode with the smallest group |
| `huge_re400_lx10_lz120_k20_F` | `1x20x5` | `F` | 5000 | can represent copied `k=1` content from `Lz=6` |
| `huge_re400_lx10_lz120_k40_F` | `1x40x5` | `F` | 5000 | can represent copied `k<=2` content |
| `huge_re400_lx10_lz120_k60_F` | `1x60x5` | `F` | 5000 | matches the `Lz=6, K=3` physical spanwise cutoff |

Acceptance criteria:
- If `K=20/40/60` still has `accepted_postfilter=0`, the problem is not only spanwise representability; inspect the rejected converged norms and shears.
- If accepted states appear only at `K>=20`, retire the `K=10` hugebox wrapper default.
- If unique states appear at `K=60`, promote only those groups to `2x20x7` or `2x40x7` rather than immediately building all groups at high dimension.

Example command:

```bash
EQB_RE=400 \
EQB_LX=10.0 \
EQB_LZ=120.0 \
EQB_SYMMETRIES=E,F,G \
EQB_LADDER=1x20x5 \
EQB_ATTEMPTS=5000 \
EQB_RESUME=false \
EQB_OUT_DIR=notebooks/eqb_fuzzing/stress_tests/huge_k20_copy_fundamental \
julia --startup-file=no --project=. notebooks/eqb_fuzzing/eqb_discovery.jl
```

## Test 2: Large-Box Scaling Curve

Purpose: test whether discovery degrades smoothly as `Lz` grows when `K` preserves the same physical spanwise cutoff.

Use `K = ceil(Lz / 2)` to match the baseline cutoff `K * 2pi/Lz ~= pi`.

| Test | Re | Lx | Lz | Ladder | Symmetries | Attempts |
|---|---:|---:|---:|---|---|---:|
| `lz12_k6` | 400 | 10 | 12 | `1x6x5` | `E,F,G` | 10000 |
| `lz24_k12` | 400 | 10 | 24 | `1x12x5` | `E,F,G` | 10000 |
| `lz48_k24` | 400 | 10 | 48 | `1x24x5` | `E,F,G` | 10000 |
| `lz120_k60` | 400 | 10 | 120 | `1x60x5` | `E,F,G` | 10000 |

Record for each run:
- `hookstep_converged / attempted_seeds`
- `accepted_postfilter / hookstep_converged`
- `unique_solutions / accepted_postfilter`
- max and median shear among accepted solutions
- which symmetry groups find states first

This should reveal whether the model loses search power with aspect ratio, or whether the earlier hugebox test was underresolved.

## Test 3: High-Re Scan at Known Boxes

Purpose: isolate Reynolds-number stress without changing geometry.

Use existing successful geometries and the normal first-level ladder:

| Domain | Re values | Ladder | Symmetries | Attempts |
|---|---|---|---|---:|
| `10x6` | `500, 700, 1000, 1500, 2000` | `1x3x5` | `A,B,C,D,E,F,G` | 25000 |
| `2pi x pi` | `500, 700, 1000, 1500, 2000` | `1x3x5` | `A,B,C,D,E,F,G` | 25000 |

Promote only cases that produce unique solutions at level 1:

```bash
EQB_LADDER=1x3x5,1x4x5,2x4x5,2x4x6,2x4x7,2x4x8,2x4x9,3x4x9,3x5x9 \
EQB_APPEND_ATTEMPTS=0 \
EQB_RESUME=true \
...
```

Acceptance criteria:
- If high Re yields many Hookstep convergences but few accepted states, add a rejected-convergence diagnostic before increasing attempts.
- If unique count grows with Re at low resolution but promotion fails, treat this as a resolution/ladder problem rather than a search problem.

## Test 4: Shear-Band Coverage

Purpose: avoid testing only the high-shear band that built the current `overnight_runs_updated` catalog.

For representative cases `Re=1000, Lx=10, Lz=6` and `Re=400, Lx=10, Lz=120, K=60`, run:

| Band | Env |
|---|---|
| low | `EQB_SHEAR_MIN=0.05 EQB_SHEAR_MAX=1.0` |
| medium | `EQB_SHEAR_MIN=1.0 EQB_SHEAR_MAX=3.0` |
| current | `EQB_SHEAR_MIN=3.0 EQB_SHEAR_MAX=7.0` |
| very high | `EQB_SHEAR_MIN=7.0 EQB_SHEAR_MAX=15.0` |

Use `E,F,G` first, `10000` attempts per band. Expand to all groups only for bands that yield accepted nontrivial states.

Acceptance criteria:
- If low/medium bands dominate at high Re, the current high-shear fuzzing is biased.
- If very-high band converges only to laminar, avoid simply raising the shear band for large boxes.

## Test 5: Seeded Large-Box Challenge

Purpose: separate "model can represent the state" from "random fuzz can discover the state."

Take existing `Lz=6` catalog representatives and embed them into `Lz=120` by mapping `k -> 20k` at fixed `J,L`. Then solve at `Lz=120` with `K=20,40,60`.

Acceptance criteria:
- If embedded seeds reconverge but random fuzz fails, the ODE model can hold the solution but the random guess distribution is weak.
- If embedded seeds fail even at `K=60`, inspect basis normalization, symmetry compatibility, and domain-rescaling assumptions before doing more random fuzzing.

This probably needs a small seed-conversion helper; it should work at the coefficient-index level using `model.ijkl` lookups.

## Test 6: Re Continuation Challenge

Purpose: test exploration by continuation rather than random initial guesses.

For every nontrivial `physical_id` in `eqb_catalog/physical_solutions.csv`:
- choose the best ODE coefficient representative from `catalog.csv`
- continue in `Re` upward from 300/400 to `1000`, `1500`, `2000`
- rerun Hookstep at target Re from interpolated continuation points

Acceptance criteria:
- If continuation reaches high Re where fuzz finds nothing, high-Re exploration should use continuation-seeded fuzzing.
- If continuation branches turn or terminate early, target random fuzz near those turning points rather than uniform Re grids.

## Immediate Fixes Before Long Runs

1. Rename or parameterize the hugebox wrapper output directory; it currently defaults to `eqb_discovery_re400_lx10_lz120_playground` while `DEFAULT_RE = 300.0`.
2. Change the hugebox default ladder from `1x10x5` to a test matrix entry, not a single hard-coded value.
3. Add an optional rejected-convergence log for `norm(x) <= EQB_NORM_THRESHOLD`, at least aggregate min/median/max norm and shear. The current `accepted_postfilter=0` hugebox rows do not say whether everything is exactly laminar or just barely below threshold.
4. Run dimension preflight before any `K >= 40` test. Matrix construction is much more expensive than counting `basisIndices`.

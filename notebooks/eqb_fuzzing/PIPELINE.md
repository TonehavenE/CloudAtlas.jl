# Equilibrium Fuzzing Pipeline

This directory contains the full pipeline for discovering, cataloging, and
characterizing equilibrium solutions in plane Couette flow across a range of
domain geometries and Reynolds numbers.

## Overview

The pipeline consists of five stages:

```
Stage 1  eqb_discovery.jl         — ODE-level fuzz search + promotion
Stage 2  promote_eqb_discovery_to_findsoln.jl  — ODE solutions → DNS (findsoln)
Stage 3  unique_converged_dns_vs_ode.jl        — deduplicate converged DNS solutions
Stage 4  create_combined_catalog.jl            — merge runs into a unified catalog
Stage 5a run_catalog_bifurcations.jl           — ODE continuation (BifurcationKit)
Stage 5b run_catalog_dns_bifurcations.jl       — DNS continuation (continuesoln)
```

---

## Stage 1 — ODE Fuzz Search (`eqb_discovery.jl`)

**Purpose:** Find candidate equilibria by randomly initializing ODE-level
Newton solves across all symmetry groups A–G at low resolution JKL=(1,3,5),
then promoting converged solutions up the JKL resolution ladder.

**Symmetry groups:**

| Group | Generators           | Julia symmetry expression              |
|-------|----------------------|----------------------------------------|
| A     | sxyz, txz            | `[sx*sy*sz, tx*tz]`                    |
| B     | sxy, sz              | `[sx*sy, sz]`                          |
| C     | sxytz, sz            | `[sx*sy*tz, sz]`                       |
| D     | sxy, sztx            | `[sx*sy, sz*tx]`                       |
| E     | sxyz, sztxz          | `[sx*sy*sz, sz*tx*tz]`                 |
| F     | sxy, sz, txz         | `[sx*sy, sz, tx*tz]`                   |
| G     | sxyz                 | `[sx*sy*sz]`                           |

**JKL promotion ladder:** (1,3,5) → (1,4,5) → (2,4,5) → (2,4,6) → ... → (3,5,11)

Each level uses `ODEModel(alpha, gamma, J, K, L, H; normalize=false, tw=false)` and
`hookstepsolve(f, Df, x0, params)`.

**Key output directories:**

- `overnight_runs_updated/` — target shear band [3, 7], Re = 300 and 400, two geometries
- `low_shear/` — target shear band [1, 3], Re = 300 and 400, same geometries

Each run directory has the structure:
```
{run_root}/{case}/{group}/jkl_{J}_{K}_{L}/
    sol{N:03d}.asc        — ODE coefficient vector
    dns_findsoln/         — (after Stage 2)
        sol{N:03d}/
            ubest.nc      — DNS field (converged)
            convergence.asc
            fieldconverge.asc  — (shear, L2) per iteration
```

**Cases run:**

| case              | Re  | Lx             | Lz            |
|-------------------|-----|----------------|---------------|
| re300_lx10_lz6    | 300 | 10.0           | 6.0           |
| re400_lx10_lz6    | 400 | 10.0           | 6.0           |
| re300_lx2pi_lzpi  | 300 | 2π ≈ 6.2832    | π ≈ 3.1416    |
| re400_lx2pi_lzpi  | 400 | 2π ≈ 6.2832    | π ≈ 3.1416    |

**Common pitfalls:**
- A solution found in group F (which has generators sxy, sz, txz) also satisfies
  subgroups B and C. Always check `create_combined_catalog.jl` for cross-group
  deduplication rather than assuming group-level uniqueness.
- The `normalize=false` flag is required — normalization changes the ODE vector
  field and breaks continuation.

---

## Stage 2 — Promote to DNS (`promote_eqb_discovery_to_findsoln.jl`)

**Purpose:** Take the highest-JKL ODE solution for each unique group-level
equilibrium, convert it to a DNS field via `coeff2field`, and reconverge with
`findsoln` (Channelflow Newton solver) to obtain a verified DNS equilibrium.

**Key function called:** `findsoln(u_guess.nc; eqb=true, R=Re, T=10, symms=symm.asc, od=out_dir)`

**Output:** `dns_findsoln/sol{N:03d}/ubest.nc` per converged solution.

**Symmetry file format** (written by `ensure_symm_file` in dns_continuesoln_map.jl
and replicated in run_catalog_dns_bifurcations.jl):
```
% 2
1 -1 -1 -1 0.0 0.0    ← sxyz
1 1 1 -1 0.5 0.5      ← sztxz  (for group E)
```
Each line: `sign_ux sign_uy sign_uz sign_p shift_x shift_z`

---

## Stage 3 — Deduplicate DNS Solutions (`unique_converged_dns_vs_ode.jl`)

**Purpose:** Collect all converged `dns_findsoln` solutions within a run, pick
the highest-JKL representative per sol_id, then deduplicate across sol_ids using
tolerance on `(shear, L2)`.

**Deduplication tolerance (within a run):** `shear_tol=1e-6`, `l2_tol=1e-6`

**Output:** `{run_root}/analysis/findsoln_unique/unique_converged_dns_{case}.csv`

Columns: `group, case, sol_id, J, K, L, shear, L2, source, asc_path, ubest_path`

**Pitfall:** The `fieldconverge.asc` file records (shear, L2) at each Newton
iteration; the script uses the *last* entry (most converged) for deduplication.

---

## Stage 4 — Build Unified Catalog (`create_combined_catalog.jl`)

**Purpose:** Merge unique solutions from all runs (overnight + low_shear) into
a single catalog, deduplicating across runs and across symmetry groups.

**Cross-run deduplication tolerance:** `1e-4` on `(shear, L2)`

**Cross-group deduplication:** Within each case, solutions found in different
groups A–G are clustered by the same `1e-4` tolerance. A solution in group F
that also appears in B and C gets a single `physical_id`.

**Output files:**

`eqb_catalog/catalog.csv` — one row per (physical_id, group) pair
Columns: `physical_id, case, Re, Lx, Lz, group, symmetry, shear, L2, is_trivial, source, representative_ubest, all_members`

- `all_members` format: `on:sol001@J3K5L11;ls:sol003@J2K4L9`
  - prefix `on:` = overnight_runs_updated, `ls:` = low_shear

`eqb_catalog/physical_solutions.csv` — one row per unique physical equilibrium (79 total)
Columns: `physical_id, case, Re, Lx, Lz, shear, L2, is_trivial, source, groups, n_groups, representative_ubest`

- `physical_id` format: `{case}_{N:03d}`, sorted by shear within each case (001 = lowest shear)
- `representative_ubest` = best available `ubest.nc`: highest JKL, overnight preferred over low_shear at equal JKL
- 2 trivial solutions (`is_trivial=true`): `re400_lx10_lz6_001` and `re400_lx2pi_lzpi_001`

**Notable multi-group solutions:**
- `re300_lx2pi_lzpi_012` (shear≈3.704, 6 groups: A,B,C,D,E,F)
- `re400_lx10_lz6_003` (shear≈0.132, 6 groups: B,C,D,E,F,G)

---

## Stage 5a — ODE Continuation (`run_catalog_bifurcations.jl`)

**Purpose:** Sweep Re ∈ [100, 500] for each physical solution using
BifurcationKit pseudo-arclength continuation on the ODE model. Produces
Re vs shear bifurcation curves.

**Input:** Best `.asc` ODE coefficient file (highest JKL, overnight > low_shear)

The `.asc` path is reconstructed from `catalog.csv`'s `all_members` field:
`{run_root}/{case}/{group}/jkl_{J}_{K}_{L}/sol{sol_id:03d}.asc`

**Continuation parameters:**
- `p_min=100`, `p_max=500`, `max_steps=2000`
- `dsmin=1e-7`, `dsmax=1.0`
- `bothside=true` (sweeps both directions from seed Re)
- Hookstep repolish before starting: `hookstepsolve(f, Df, x0, params)`

**Output:** `eqb_catalog/bifurcations/{physical_id}/bif.csv`
Columns: `Re,shear`

**Summary:** `eqb_catalog/bifurcations/bifurcation_summary.csv`

**Run command:**
```bash
JULIA_NUM_THREADS=auto julia --project=. notebooks/eqb_fuzzing/run_catalog_bifurcations.jl --parallel 12 2>&1 | tee eqb_catalog/bifurcations/run.log
```

**Supports:** `--resume`, `--dry-run`, `--parallel N`, `--catalog-dir`, `--out-dir`,
`--overnight-root`, `--low-shear-root`

---

## Stage 5b — DNS Continuation (`run_catalog_dns_bifurcations.jl`)

**Purpose:** Run Channelflow's `continuesoln` on each `ubest.nc` DNS field to
trace the equilibrium branch in Re using full DNS, producing Re vs observable
(shear-like) data.

**Input:** `representative_ubest` from `physical_solutions.csv`

The symmetry group is parsed from the ubest path:
`{run_root}/{case}/{GROUP}/jkl_{J}_{K}_{L}/dns_findsoln/sol{N}/ubest.nc`

**Continuation parameters:**
- `cont="Re"`, `eqb=true`
- `R = seed_Re` (from catalog, e.g. 300 or 400)
- `T = 10.0` (integration time for Newton convergence check)
- `dmu = -0.02` (step toward lower Re)
- `ns = 50` (max arclength steps)
- `targ = true`, `targMu = 100.0` (stop at Re=100)

Equivalent CLI command:
```
continuesoln -eqb -cont Re -R 300 -T 10 -symms symm_E.asc -dmu -0.02 -ns 50 -targ -targMu 100 ubest.nc
```

**Output directory structure:**
```
eqb_catalog/dns_bifurcations/
    symm_files/
        symm_A.asc  symm_B.asc  ...  symm_G.asc
    {physical_id}/
        processinfo         — records the exact command run
        MuD.asc             — Re, obs, s, guesserr, error, directory per step
        MuE.asc             — eigenvalue data (if computed)
        initial-{N}/
            ubest.nc        — converged DNS field at this Re
            mu.asc          — single float: Re value at this step
            convergence.asc
        search-{N}/         — arclength predictor-corrector steps
    dns_bifurcation_summary.csv
```

**Reading results:** `MuD.asc` columns are `%Re, obs, s, guesserr, error, directory`.
The `obs` column is the continuation observable (typically related to shear/drag).
To get Re vs shear for plotting, compute shear from `initial-*/ubest.nc` fields
or use `obs` as a proxy.

**Run command:**
```bash
JULIA_NUM_THREADS=auto julia --project=. notebooks/eqb_fuzzing/run_catalog_dns_bifurcations.jl --parallel 12 2>&1 | tee eqb_catalog/dns_bifurcations/run.log
```

**Supports:** `--resume`, `--dry-run`, `--parallel N`, `--catalog-dir`, `--out-dir`,
`--T`, `--dmu`, `--ns`, `--targMu`

**Pitfall:** DNS continuation is much slower than ODE continuation — each Newton
step runs a full DNS integration for time T. With 77 solutions and ~50 steps each,
expect significant wall time. Use `--parallel` to maximize throughput, but
be aware that each Channelflow process is itself multi-threaded.

---

## Analysis Scripts

`analyze_eqb_discovery_runs.jl` — summary statistics and plots for a single discovery run

`summarize_findsoln_results.jl` — reads `findsoln_jobs_summary.csv` and reports
convergence rates per group/case

`eqb_fuzzing_unique_dash_app.py` — interactive Plotly Dash dashboard for
browsing catalog solutions, bifurcation curves (ODE and DNS), and geometry

---

## Key Data Locations

| Data                          | Path |
|-------------------------------|------|
| Overnight runs                | `overnight_runs_updated/` |
| Low-shear runs                | `low_shear/` |
| Per-run unique solution CSVs  | `{run_root}/analysis/findsoln_unique/unique_converged_dns_{case}.csv` |
| Unified catalog               | `eqb_catalog/catalog.csv` |
| Physical solutions            | `eqb_catalog/physical_solutions.csv` |
| ODE bifurcation curves        | `eqb_catalog/bifurcations/{physical_id}/bif.csv` |
| DNS bifurcation outputs       | `eqb_catalog/dns_bifurcations/{physical_id}/` |

---

## Common Pitfalls

1. **Cross-group duplicates:** A solution invariant under group F is also
   invariant under B and C (subgroups). Always use `physical_id` from
   `physical_solutions.csv`, not group-level sol_ids.

2. **ODE vs DNS continuation:** ODE continuation (`run_catalog_bifurcations.jl`)
   is fast but approximate. DNS continuation (`run_catalog_dns_bifurcations.jl`)
   is authoritative but slow. Use ODE results for exploration, DNS for publication.

3. **Trivial solutions:** Two `is_trivial=true` entries exist (shear≈0, L2≈0).
   Both scripts skip them automatically.

4. **JKL resolution matters:** The ODE model size grows with JKL. The highest
   JKL available is preferred as it is the best-resolved. `all_members` in
   `catalog.csv` encodes the JKL for each available representative.

5. **Symmetry file format:** The `.asc` symmetry files expected by `continuesoln`
   must start with `% N` (number of generators), then one generator per line in
   the format `sign_ux sign_uy sign_uz sign_p shift_x shift_z`.

6. **MuD.asc observable:** The `obs` column in `MuD.asc` is `wallStress` (input
   power / dissipation proxy) as defined by Channelflow's default observable for
   plane Couette flow. It is not exactly the same as the ODE shear computed by
   `CloudAtlas.shear()`.

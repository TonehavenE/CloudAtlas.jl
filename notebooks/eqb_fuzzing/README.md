# Equilibrium Discovery Fuzzing

This folder contains a parallel equilibrium-discovery workflow modeled on the TW discovery notebook, but configured for equilibrium solving (`tw=false`).

## Main script

- `eqb_discovery.jl`

## What it does

- Uses `Lx = 10.0`, `Lz = 6.0` by default.
- Uses `Re = 400.0` by default (override with `EQB_RE`).
- Fuzzes 10,000 initial guesses at `(J,K,L) = (1,3,5)` by default.
- Promotes unique solutions up this default ladder:
  - `(1,3,5)`, `(1,4,5)`, `(2,4,5)`, `(2,4,6)`, `(2,4,7)`, `(2,4,8)`, `(2,4,9)`, `(3,4,9)`, `(3,5,9)`, `(3,5,9)`, `(3,5,10)`, `(3,5,11)`
- Targets high-shear guesses with a default band `3 <= shear <= 7`.
- Runs Hookstep stages in parallel via Julia threads.

## Symmetry groups

The script includes groups A-G:

- A: `<sxyz, txz>`
- B: `<sxy, sz>`
- C: `<sxytz, sz>`
- D: `<sxy, sztx>`
- E: `<sxyz, sztxz>`
- F: `<sxy, sz, txz>`
- G: `<sxyz>`

## Output layout

By default outputs are under:

- `notebooks/eqb_fuzzing/eqb_discovery_re400/`

Per symmetry group (example `E/`):

- `E/solution_statistics.csv`
- `E/jkl_1_3_5/solutions_summary.csv`
- `E/jkl_1_3_5/solutions.bin`
- `E/jkl_1_3_5/sol1.asc`, `sol2.asc`, ...
- ... repeated for each ladder level

The run root also contains:

- `run_summary.md` (auto-updated markdown summary during execution)

## Results log

Use `run_summary.md` for ongoing run status and per-level counts:

- Hookstep converged count
- Unique solution count
- Promotion reconverged count

`solution_statistics.csv` in each symmetry directory is the machine-readable source of truth.

## Minimal run command

```bash
JULIA_NUM_THREADS=auto julia --project=. notebooks/eqb_fuzzing/eqb_discovery.jl
```

## Useful overrides

- `EQB_RE` (default `400.0`)
- `EQB_OUT_DIR`
- `EQB_ATTEMPTS` (default `10000`)
- `EQB_SYMMETRIES` (comma-separated subset, e.g. `A,C,E`)
- `EQB_SHEAR_MIN` / `EQB_SHEAR_MAX` (defaults `3.0`, `7.0`)
- `EQB_LADDER` (comma-separated `JxKxL` tokens)


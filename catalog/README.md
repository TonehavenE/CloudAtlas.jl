# Equilibrium Catalog

This generated catalog contains 105 unique equilibrium solutions.

- `equilibria/<physical_id>/` contains per-solution markdown, representative ODE/DNS assets, DNS/ODE comparison plots, diagnostics, and optional bifurcation data.
- `equilibria/<physical_id>/eigen/` contains optional `findeigenvals` output when eigenanalysis is requested.
- `index.json` is the machine-readable catalog index.
- `site/index.html` is a dependency-free static browser. It can be opened directly from disk.
- DNS diagnostics include raw `fieldprops` values plus derived GHC-style `I_total = wallshear + 1` and `D_total = dissipation + 1`.

Regenerate with:

```bash
python3 notebooks/eqb_fuzzing/build_equilibrium_catalog.py
```

Compute cached leading-eigenvalue data with:

```bash
python3 notebooks/eqb_fuzzing/build_equilibrium_catalog.py --compute-eigen --eigen-workers 2
```

Compute missing DNS/ODE comparison plots with:

```bash
python3 notebooks/eqb_fuzzing/build_equilibrium_catalog.py --compute-fieldprops --compute-comparisons
```

Compute cross-parameter ODE deduplication candidates with:

```bash
CLOUDATLAS_SKIP_ACTIVATE=true julia --startup-file=no --project=. notebooks/eqb_fuzzing/catalog_cross_parameter_dedup.jl
python3 notebooks/eqb_fuzzing/build_equilibrium_catalog.py --compute-fieldprops
```

# Catalog Geometry Heatmaps

This is the catalog-wide wrapper for the old `alpha_gamma_grid` continuation workflow.

## Why `A/B/C/E/F` can look duplicated

The old geometry heatmaps were seeded **per symmetry group**, not from one shared cross-group seed file. So the scripts do not literally force `A/B/C/E/F` to start from the same `.asc`.

That said, the overlap concern is still real:

- the catalog already contains physical solutions that live in several groups at once
- so several groups can independently continue the same underlying branch
- identical or near-identical `min_Re(Lx,Lz)` landscapes across `A/B/C/E/F` are therefore plausible even if the bookkeeping was correct

Examples already in `eqb_catalog/physical_solutions.csv`:

- `re300_lx2pi_lzpi_012` appears in `A,B,C,D,E,F`
- `re400_lx10_lz6_012` appears in `A,B,C,E`
- `re400_lx10_lz6_003` appears in `B,C,D,E,F,G`

So the right interpretation is usually not "the script duplicated one seed by mistake", but "the same physical branch exists in several invariant subspaces".

## New script

Use [catalog_geometry_heatmaps.jl](/home/ebenq/Dev/julia/CloudAtlas.jl/notebooks/eqb_fuzzing/catalog_geometry_heatmaps.jl).

What it does:

- reads `eqb_catalog/physical_solutions.csv` and `catalog.csv`
- finds the best local ODE `.asc` representative for each `physical_id`
- writes a manifest of per-solution geometry jobs
- writes a one-line `run_command.txt` for each job
- optionally explodes one physical solution into all catalog groups that carry it

By default this is **local around each solution's own geometry**, not one global `10×6` grid:

- `Lx ∈ [Lx0 - 2.0, Lx0 + 2.0]`
- `Lz ∈ [Lz0 - 1.5, Lz0 + 1.5]`
- `25 × 25` grid

That is a better default for catalog-wide exploration.

## Recommended usage

Dry-run and generate a small manifest:

```bash
CLOUDATLAS_SKIP_ACTIVATE=true julia --startup-file=no --project=. notebooks/eqb_fuzzing/catalog_geometry_heatmaps.jl --dry-run --limit 5
```

Generate the full manifest, one representative group per physical solution:

```bash
CLOUDATLAS_SKIP_ACTIVATE=true julia --startup-file=no --project=. notebooks/eqb_fuzzing/catalog_geometry_heatmaps.jl
```

Generate jobs for every catalog group carrying each solution:

```bash
CLOUDATLAS_SKIP_ACTIVATE=true julia --startup-file=no --project=. notebooks/eqb_fuzzing/catalog_geometry_heatmaps.jl --group-mode all-catalog
```

Restrict to one case:

```bash
CLOUDATLAS_SKIP_ACTIVATE=true julia --startup-file=no --project=. notebooks/eqb_fuzzing/catalog_geometry_heatmaps.jl --case re300_lx10_lz6
```

Restrict to one physical solution:

```bash
CLOUDATLAS_SKIP_ACTIVATE=true julia --startup-file=no --project=. notebooks/eqb_fuzzing/catalog_geometry_heatmaps.jl --physical-id re300_lx2pi_lzpi_003
```

Then go into the generated job directory and run the stored one-line command:

```bash
cat notebooks/eqb_fuzzing/eqb_catalog/geometry_heatmaps/re300_lx2pi_lzpi_003/E/run_command.txt
```

## Current limitation

This script is intentionally a wrapper around the existing geometry continuation code. It does **not** yet deduplicate heatmap outputs across groups or compare cross-group solutions automatically. It gets the catalog-wide machinery in place first.

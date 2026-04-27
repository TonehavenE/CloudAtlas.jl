# Catalog Branch Graph Workflow

This workflow turns the equilibrium catalog into branch-family data.

It has two phases:

1. `continue`: for each nontrivial `physical_id`, choose the best local ODE
   `.asc` representative, run pseudo-arclength continuation in `Re`, and save
   sampled states along the branch.
2. `analyze`: project sampled states into a common full basis and link two
   catalog entries when their continuation curves overlap in `Re`, wall input,
   and state-space distance.

## Typical Run

From any machine with a CloudAtlas checkout:

```bash
julia --startup-file=no --project=/path/to/CloudAtlas.jl \
  /path/to/jfm_followup/scripts/catalog_branch_graph.jl \
  --cloudatlas-root /path/to/CloudAtlas.jl \
  --catalog-dir /path/to/CloudAtlas.jl/notebooks/eqb_fuzzing/eqb_catalog \
  --mode all
```

Outputs are written by default to:

```text
notebooks/eqb_fuzzing/eqb_catalog/branch_graph/
```

Main output files:

- `continuation_summary.csv`: one row per attempted catalog branch.
- `curves/<physical_id>/points.csv`: sampled continuation points.
- `curves/<physical_id>/states/point_*.asc`: ODE state vectors at sampled points.
- `graph/branch_edges.csv`: pairwise branch-overlap tests.
- `graph/branch_families.csv`: connected components inferred from linked edges.
- `graph/branch_family_members.csv`: one row per catalog solution in each family.

## Safer First Runs

Dry-run selection only:

```bash
julia --startup-file=no --project=/path/to/CloudAtlas.jl \
  scripts/catalog_branch_graph.jl \
  --cloudatlas-root /path/to/CloudAtlas.jl \
  --catalog-dir /path/to/CloudAtlas.jl/notebooks/eqb_fuzzing/eqb_catalog \
  --mode continue --dry-run --limit 5
```

One case:

```bash
julia --startup-file=no --project=/path/to/CloudAtlas.jl \
  scripts/catalog_branch_graph.jl \
  --cloudatlas-root /path/to/CloudAtlas.jl \
  --catalog-dir /path/to/CloudAtlas.jl/notebooks/eqb_fuzzing/eqb_catalog \
  --mode all --case re300_lx10_lz6
```

One solution:

```bash
julia --startup-file=no --project=/path/to/CloudAtlas.jl \
  scripts/catalog_branch_graph.jl \
  --cloudatlas-root /path/to/CloudAtlas.jl \
  --catalog-dir /path/to/CloudAtlas.jl/notebooks/eqb_fuzzing/eqb_catalog \
  --mode all --physical-id re300_lx10_lz6_013
```

Analyze already-computed curves without rerunning continuation:

```bash
julia --startup-file=no --project=/path/to/CloudAtlas.jl \
  scripts/catalog_branch_graph.jl \
  --cloudatlas-root /path/to/CloudAtlas.jl \
  --catalog-dir /path/to/CloudAtlas.jl/notebooks/eqb_fuzzing/eqb_catalog \
  --mode analyze
```

## Important Parameters

- `--Re-min 100 --Re-max 500`: continuation range.
- `--max-steps 2000`: pseudo-arclength step cap.
- `--sample-stride 1`: save every continuation point. Increase to reduce disk.
- `--max-points 0`: no cap. Set e.g. `--max-points 300` for cheaper analysis.
- `--compare-J 3 --compare-K 5 --compare-L 11`: common full-basis resolution for state matching.
- `--match-Re-tol 0.5`: maximum `Re` gap for candidate overlap points.
- `--match-shear-tol 0.02`: maximum wall-input gap for candidate overlap points.
- `--match-state-tol 1e-3`: normalized common-basis state-distance threshold.
- `--min-matches 2`: minimum overlapping sampled points before linking branches.
- `--shift-grid 0`: no continuous-shift quotient. Set `4` or `8` to test a coarse translation grid.

## Interpretation

An edge in `branch_edges.csv` means two catalog solutions appear to lie on the
same numerically continued ODE branch under the chosen tolerances. This is
evidence for branch identity or fold connectivity. It is not, by itself,
evidence of a secondary bifurcation; that still needs stability/eigenvalue
information near the suspected connection.

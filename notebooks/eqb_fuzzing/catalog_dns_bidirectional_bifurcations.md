# Catalog DNS Bidirectional Bifurcations

This script builds DNS bifurcation curves from the equilibrium catalog using
Channelflow `continuesoln`.

For each selected nontrivial `physical_id`, it launches two continuation runs:

- `minus`: `-dmu < 0`, targeting lower Reynolds number.
- `plus`: `-dmu > 0`, targeting higher Reynolds number.

It prefers portable catalog seeds under:

```text
eqb_catalog/solutions/<physical_id>/*_ubest.nc
```

and falls back to reconstructed `overnight_runs_updated` / `low_shear` paths if
needed.

## Dry Run

Use this first to verify seed selection and generated commands:

```bash
julia --startup-file=no --project=/path/to/CloudAtlas.jl \
  /path/to/jfm_followup/scripts/catalog_dns_bidirectional_bifurcations.jl \
  --cloudatlas-root /path/to/CloudAtlas.jl \
  --catalog-dir /path/to/CloudAtlas.jl/notebooks/eqb_fuzzing/eqb_catalog \
  --dry-run true --limit 5
```

This writes:

```text
eqb_catalog/dns_bidirectional_bifurcations/run_continuesoln_all.sh
eqb_catalog/dns_bidirectional_bifurcations/dns_bidirectional_summary.csv
```

## Run From Julia

```bash
julia --startup-file=no --project=/path/to/CloudAtlas.jl \
  /path/to/jfm_followup/scripts/catalog_dns_bidirectional_bifurcations.jl \
  --cloudatlas-root /path/to/CloudAtlas.jl \
  --catalog-dir /path/to/CloudAtlas.jl/notebooks/eqb_fuzzing/eqb_catalog \
  --run true
```

## Run Direct Channelflow Commands

The dry-run also writes a shell script containing direct `continuesoln` commands:

```bash
bash /path/to/CloudAtlas.jl/notebooks/eqb_fuzzing/eqb_catalog/dns_bidirectional_bifurcations/run_continuesoln_all.sh
```

If the target machine needs MPI:

```bash
julia --startup-file=no --project=/path/to/CloudAtlas.jl \
  scripts/catalog_dns_bidirectional_bifurcations.jl \
  --cloudatlas-root /path/to/CloudAtlas.jl \
  --catalog-dir /path/to/CloudAtlas.jl/notebooks/eqb_fuzzing/eqb_catalog \
  --dry-run true \
  --np0 4 --np1 4 --symmpi 100 \
  --mpi-prefix "mpiexec -n 16"
```

## Useful Filters

One case:

```bash
--case re300_lx10_lz6
```

One solution:

```bash
--physical-id re300_lx10_lz6_013
```

One symmetry group:

```bash
--group E
```

Limit for test runs:

```bash
--limit 3
```

## Continuation Parameters

- `--Re-min 100`: lower target for the minus run.
- `--Re-max 500`: upper target for the plus run.
- `--dmu 0.02`: magnitude of the initial continuation parameter step.
- `--ns 50`: Channelflow continuation step count.
- `--T 10`: integration time used by Channelflow residual evaluations.
- `--parallel N`: number of Julia worker tasks when launching from Julia.

## Outputs

For each solution:

```text
dns_bidirectional_bifurcations/<physical_id>/minus/
dns_bidirectional_bifurcations/<physical_id>/plus/
dns_bidirectional_bifurcations/<physical_id>/combined_curve.csv
```

Top-level summary:

```text
dns_bidirectional_bifurcations/dns_bidirectional_summary.csv
```

`combined_curve.csv` contains:

```text
physical_id,case,group,direction,step,Re,input
```

where `input` is the wall-input/shear observable read from `MuD.asc`.

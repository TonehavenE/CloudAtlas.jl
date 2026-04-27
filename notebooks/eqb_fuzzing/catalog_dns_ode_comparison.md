# Catalog DNS + ODE Comparison

This workflow uses the existing `.nc` files already stored in
`notebooks/eqb_fuzzing/eqb_catalog/solutions/<physical_id>/` and pairs them with
the best local ODE `.asc` representative for the same `physical_id`.

Script:

```text
notebooks/eqb_fuzzing/catalog_dns_ode_comparison.jl
```

The renderer is GLMakie-based and uses the DNS NetCDF reader already present in
`ext/CloudAtlasGLMakieExt.jl`.

## Commands

Full catalog:

```bash
LD_LIBRARY_PATH=/run/opengl-driver/lib/ CLOUDATLAS_SKIP_ACTIVATE=true julia --startup-file=no --project=. notebooks/eqb_fuzzing/catalog_dns_ode_comparison.jl --all true
```

One case:

```bash
LD_LIBRARY_PATH=/run/opengl-driver/lib/ CLOUDATLAS_SKIP_ACTIVATE=true julia --startup-file=no --project=. notebooks/eqb_fuzzing/catalog_dns_ode_comparison.jl --case re400_lx10_lz6 --all true
```

Selected solutions:

```bash
LD_LIBRARY_PATH=/run/opengl-driver/lib/ CLOUDATLAS_SKIP_ACTIVATE=true julia --startup-file=no --project=. notebooks/eqb_fuzzing/catalog_dns_ode_comparison.jl --physical-id re400_lx10_lz6_023,re300_lx10_lz6_022
```

Dry-run selection check:

```bash
CLOUDATLAS_SKIP_ACTIVATE=true julia --startup-file=no --project=. notebooks/eqb_fuzzing/catalog_dns_ode_comparison.jl --dry-run --limit 5
```

## Selection Rule

- one comparison figure per `physical_id`
- ODE side: choose the best local `.asc`
- DNS side: prefer the matching local `*_ubest.nc` for that ODE representative;
  otherwise fall back to the best local `.nc`, then to `representative_ubest`

## Output

- one `1920x1080` PNG per `physical_id`
- DNS row on top, ODE row on bottom
- shared color limits per component
- `manifest.csv` recording the selected ODE and DNS files

## Related

If by "compute the DNS for the catalog" you mean launching the DNS continuation
jobs from the representative catalog snapshots, the existing script is:

```text
notebooks/eqb_fuzzing/run_catalog_dns_bifurcations.jl
```

Typical command:

```bash
CLOUDATLAS_SKIP_ACTIVATE=true julia --startup-file=no --project=. notebooks/eqb_fuzzing/run_catalog_dns_bifurcations.jl
```

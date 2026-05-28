# Repository Guidelines

## Project Structure & Module Organization

CloudAtlas.jl is a Julia package for reduced-order coherent-structure and Channelflow workflows. Core package code lives in `src/`; optional package extensions live in `ext/`. Tests are under `test/`, with `test/runtests.jl` as the main entry point. Exploratory and production research scripts live in `notebooks/`, organized by topic such as `notebooks/periodic_orbits`, `notebooks/energy`, and `notebooks/alpha_gamma_grid`. Catalog data and generated solution metadata are under `catalog/`. External Channelflow helper programs and flags are kept in `chflow-programs/` and root `*.args` or `*flags.txt` files.

## Build, Test, and Development Commands

Run commands from the repository root.

```bash
julia --startup-file=no --project=. test/runtests.jl
```

Runs the package test suite in the checked-out environment.

```bash
julia --startup-file=no --project=. notebooks/periodic_orbits/eqb_hopf_track_eigenpairs.jl
```

Runs a research script against the active project. Most notebook scripts are configured with environment variables, for example `HOPF_JKL=3x5x9`.

```bash
julia --project=.
```

Starts a REPL with the local package environment loaded.

## Coding Style & Naming Conventions

Use idiomatic Julia with 4-space indentation. Prefer explicit, descriptive function names such as `build_dissipation_matrix`, `hookstepsolve_rpo`, and `ode_native_*` script names. Keep reusable logic in `src/`; keep experiment-specific orchestration in `notebooks/<topic>/`. Use keyword arguments and environment variables for script configuration rather than hard-coded paths.

## Testing Guidelines

Add or update tests in `test/runtests.jl` when changing package behavior in `src/` or `ext/`. For research scripts, include checkpointed CSV output and concise run configuration files where possible. Before committing package changes, run `julia --startup-file=no --project=. test/runtests.jl`.

## Commit & Pull Request Guidelines

Recent commits use short imperative summaries, often with prefixes such as `feat:` or `Fix`, for example `feat: hopf stuff` and `Fix GHC Re400 literature fuzz catalog entries`. Keep commits scoped: separate source changes from large generated datasets when practical. Pull requests should describe the workflow changed, list key commands run, note any large generated files, and include plots or CSV paths when results are relevant.

## Agent-Specific Instructions

Do not overwrite user-generated outputs or broad dirty worktree changes. Use `rg` for search, keep generated artifacts scoped to their experiment directory, and document long-running command parameters in an output `run_config.txt` or the PR description.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

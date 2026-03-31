#!/usr/bin/env python3
"""
Collect all ODE (.asc) and DNS (ubest.nc) solution files referenced in the
catalog into a single organized directory tree:

  eqb_catalog/solutions/{physical_id}/
      ubest.nc                        — best DNS field (representative_ubest)
      on_{group}_J{J}K{K}L{L}.asc    — ODE coefficients from overnight run
      ls_{group}_J{J}K{K}L{L}.asc    — ODE coefficients from low_shear run

Run from the repo root:
    python notebooks/eqb_fuzzing/collect_catalog_solutions.py
"""

from __future__ import annotations

import argparse
import csv
import re
import shutil
from pathlib import Path

MEMBER_RE = re.compile(r"(on|ls):sol(\d+)@J(\d+)K(\d+)L(\d+)")
UBEST_JKL_RE = re.compile(r"jkl_(\d+)_(\d+)_(\d+)")


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as f:
        return list(csv.DictReader(f))


def parse_ubest_group_jkl(ubest_path: str, case: str) -> tuple[str, str] | tuple[None, None]:
    """Extract group letter and JKL string from a ubest.nc path."""
    parts = Path(ubest_path).parts
    for i, p in enumerate(parts):
        if p == case and i + 2 < len(parts):
            group = parts[i + 1]
            jkl_part = parts[i + 2]
            m = UBEST_JKL_RE.match(jkl_part)
            if m and len(group) == 1 and group in "ABCDEFG":
                J, K, L = m.groups()
                return group, f"J{J}K{K}L{L}"
    return None, None


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--catalog-dir", default=None)
    ap.add_argument("--overnight-root", default=None)
    ap.add_argument("--low-shear-root", default=None)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    script_dir = Path(__file__).resolve().parent
    cat_dir    = Path(args.catalog_dir)    if args.catalog_dir    else script_dir / "eqb_catalog"
    on_root    = Path(args.overnight_root) if args.overnight_root else script_dir / "overnight_runs_updated"
    ls_root    = Path(args.low_shear_root) if args.low_shear_root else script_dir / "low_shear"
    out_dir    = cat_dir / "solutions"

    phys_rows = read_csv(cat_dir / "physical_solutions.csv")
    cat_rows  = read_csv(cat_dir / "catalog.csv")

    # Index catalog rows by physical_id
    by_pid: dict[str, list[dict]] = {}
    for r in cat_rows:
        by_pid.setdefault(r["physical_id"], []).append(r)

    copied = skipped = errors = 0

    for pr in phys_rows:
        pid      = pr["physical_id"]
        case     = pr["case"]
        ubest    = pr["representative_ubest"]
        shear    = pr["shear"]
        L2       = pr["L2"]
        groups   = pr["groups"]
        Re       = pr["Re"]
        Lx, Lz   = pr["Lx"], pr["Lz"]

        sol_dir = out_dir / pid
        if not args.dry_run:
            sol_dir.mkdir(parents=True, exist_ok=True)

        # ── DNS field ──────────────────────────────────────────────────────
        ubest_src = Path(ubest)
        if ubest_src.is_file():
            dns_group, dns_jkl = parse_ubest_group_jkl(ubest, case)
            if dns_group and dns_jkl:
                dns_dest = sol_dir / f"{dns_group}_{dns_jkl}_ubest.nc"
            else:
                dns_dest = sol_dir / "ubest.nc"

            if not args.dry_run and not dns_dest.exists():
                shutil.copy2(ubest_src, dns_dest)
                copied += 1
            elif args.dry_run:
                print(f"  [dns] {pid}/{dns_dest.name}")
                copied += 1
            else:
                skipped += 1
        else:
            print(f"  [WARN] missing ubest.nc for {pid}: {ubest_src}")
            errors += 1

        # ── ODE coefficient files ──────────────────────────────────────────
        cat_group_rows = by_pid.get(pid, [])
        for row in cat_group_rows:
            group = row["group"]
            for m in MEMBER_RE.finditer(row["all_members"]):
                src, sol, J, K, L = m.groups()
                run_root = on_root if src == "on" else ls_root
                asc_src  = run_root / case / group / f"jkl_{J}_{K}_{L}" / f"sol{int(sol)}.asc"
                prefix   = "on" if src == "on" else "ls"
                asc_dest = sol_dir / f"{prefix}_{group}_J{J}K{K}L{L}.asc"

                if not asc_src.is_file():
                    print(f"  [WARN] missing .asc: {asc_src}")
                    errors += 1
                    continue

                if not args.dry_run and not asc_dest.exists():
                    shutil.copy2(asc_src, asc_dest)
                    copied += 1
                elif args.dry_run:
                    print(f"  [ode] {pid}/{asc_dest.name}")
                    copied += 1
                else:
                    skipped += 1

    print(f"\nDone: copied={copied}  skipped(exist)={skipped}  errors={errors}")
    if not args.dry_run:
        print(f"Output: {out_dir}")


if __name__ == "__main__":
    main()

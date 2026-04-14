#!/usr/bin/env python3
"""Summarize eqb_discovery stress-test solution_statistics.csv files."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


GROUP_ORDER = ["A", "B", "C", "D", "E", "F", "G"]


def parse_float(value: str) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return float("nan")


def read_stats(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as fh:
        return list(csv.DictReader(fh))


def format_float(value: str) -> str:
    x = parse_float(value)
    if x != x:
        return ""
    return f"{x:.6g}"


def summarize_run(run_dir: Path) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for group in GROUP_ORDER:
        stats_path = run_dir / group / "solution_statistics.csv"
        if not stats_path.exists():
            continue
        stats = read_stats(stats_path)
        if not stats:
            continue
        row = stats[0]
        rows.append(
            {
                "case": run_dir.name,
                "group": group,
                "J": row.get("J", ""),
                "K": row.get("K", ""),
                "L": row.get("L", ""),
                "attempted": row.get("attempted_seeds", "0"),
                "hookstep": row.get("hookstep_converged", "0"),
                "accepted": row.get("accepted_postfilter", "0"),
                "rejected": row.get("rejected_postfilter", "0"),
                "unique": row.get("unique_solutions", "0"),
                "rej_norm_med": format_float(row.get("rejected_norm_median", "")),
                "rej_shear_med": format_float(row.get("rejected_shear_median", "")),
            }
        )
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run_root", type=Path, help="Stress-test suite directory, e.g. notebooks/eqb_fuzzing/stress_tests/minimal_low_shear")
    args = parser.parse_args()

    run_dirs = sorted(p for p in args.run_root.iterdir() if p.is_dir())
    rows: list[dict[str, str]] = []
    for run_dir in run_dirs:
        rows.extend(summarize_run(run_dir))

    fieldnames = [
        "case",
        "group",
        "J",
        "K",
        "L",
        "attempted",
        "hookstep",
        "accepted",
        "rejected",
        "unique",
        "rej_norm_med",
        "rej_shear_med",
    ]
    writer = csv.DictWriter(__import__("sys").stdout, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

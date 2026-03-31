#!/usr/bin/env python3
"""
Plot DNS bifurcation curves (Re vs shear) from run_catalog_dns_bifurcations.jl output.

Produces:
  1. Per-case overlaid figures  — all solutions in one case, coloured by symmetry group
  2. Per-case faceted figures   — one subplot per group, curves per solution
  3. All-cases summary figure   — one subplot per case (overlaid)

Shear is computed as  shear = obs - 1  where obs is the first numeric column of
MuD.asc (total wall shear rate, laminar contributes 1).

Usage:
    python plot_dns_bifurcations.py [--catalog-dir PATH] [--out-dir PATH] [--show]
"""

from __future__ import annotations

import argparse
import csv
import math
from pathlib import Path

import matplotlib
matplotlib.use("Agg")          # non-interactive; change to "TkAgg" if --show wanted
import matplotlib.pyplot as plt
import matplotlib.cm as cm
import numpy as np


# ── colour palette: one per group A–G ────────────────────────────────────────
GROUPS = ["A", "B", "C", "D", "E", "F", "G"]
GROUP_COLORS = {
    "A": "#e41a1c",   # red
    "B": "#377eb8",   # blue
    "C": "#4daf4a",   # green
    "D": "#984ea3",   # purple
    "E": "#ff7f00",   # orange
    "F": "#a65628",   # brown
    "G": "#f781bf",   # pink
}
GROUP_MARKERS = {g: m for g, m in zip(GROUPS, ["o", "s", "^", "D", "v", "P", "*"])}

CASE_LABELS = {
    "re300_lx10_lz6":   r"$Re=300,\ L_x=10,\ L_z=6$",
    "re400_lx10_lz6":   r"$Re=400,\ L_x=10,\ L_z=6$",
    "re300_lx2pi_lzpi": r"$Re=300,\ L_x=2\pi,\ L_z=\pi$",
    "re400_lx2pi_lzpi": r"$Re=400,\ L_x=2\pi,\ L_z=\pi$",
}


# ── data loading ──────────────────────────────────────────────────────────────

def read_summary(summary_csv: Path) -> list[dict]:
    if not summary_csv.is_file():
        return []
    with summary_csv.open(newline="") as f:
        return [r for r in csv.DictReader(f) if r["status"] == "ok"]


def read_mud_asc(path: Path) -> tuple[list[float], list[float]]:
    """Return (Re_list, shear_list) from a MuD.asc file.
    shear = obs  (total wall shear rate; laminar value = 1).
    """
    re_vals, shear_vals = [], []
    if not path.is_file():
        return re_vals, shear_vals
    with path.open() as f:
        header_skipped = False
        for line in f:
            s = line.strip()
            if not s:
                continue
            if not header_skipped:
                header_skipped = True
                continue
            parts = s.split()
            if len(parts) < 2:
                continue
            try:
                re_vals.append(float(parts[0]))
                shear_vals.append(float(parts[1]))
            except ValueError:
                continue
    return re_vals, shear_vals


def load_all_curves(summary_csv: Path) -> dict[str, list[dict]]:
    """Return  {case: [{physical_id, group, Re_seed, re_vals, shear_vals}]}."""
    rows = read_summary(summary_csv)
    by_case: dict[str, list[dict]] = {}
    for r in rows:
        case = r["case"]
        pid  = r["physical_id"]
        grp  = r["group"]
        re_seed = float(r["Re"]) if r["Re"] else 300.0
        out_dir = Path(r["out_dir"])
        re_vals, shear_vals = read_mud_asc(out_dir / "MuD.asc")
        if not re_vals:
            continue
        by_case.setdefault(case, []).append(dict(
            physical_id=pid,
            group=grp,
            re_seed=re_seed,
            re_vals=re_vals,
            shear_vals=shear_vals,
        ))
    return by_case


# ── individual plots ──────────────────────────────────────────────────────────

def plot_case_overlaid(case: str, curves: list[dict], out_dir: Path, show: bool) -> None:
    """One figure: all solutions in this case, coloured by group."""
    fig, ax = plt.subplots(figsize=(8, 5))
    seen_groups: set[str] = set()

    # Sort by group then physical_id for deterministic legend order
    for c in sorted(curves, key=lambda x: (x["group"], x["physical_id"])):
        g = c["group"]
        label = g if g not in seen_groups else None
        seen_groups.add(g)
        ax.plot(
            c["re_vals"], c["shear_vals"],
            color=GROUP_COLORS.get(g, "gray"),
            lw=1.4,
            alpha=0.85,
            label=label,
        )

    ax.set_xlabel("Re", fontsize=12)
    ax.set_ylabel("Wall shear", fontsize=12)
    ax.set_title(f"DNS bifurcation curves — {CASE_LABELS.get(case, case)}", fontsize=12)
    ax.legend(title="Group", fontsize=9, title_fontsize=9)
    ax.grid(True, lw=0.4, alpha=0.4)
    fig.tight_layout()

    out_path = out_dir / f"bif_overlaid_{case}.pdf"
    fig.savefig(out_path, dpi=150)
    fig.savefig(out_dir / f"bif_overlaid_{case}.png", dpi=150)
    print(f"  saved {out_path.name}")
    if show:
        plt.show()
    plt.close(fig)


def plot_case_faceted(case: str, curves: list[dict], out_dir: Path, show: bool) -> None:
    """One figure per case: grid of subplots, one per group present."""
    groups_present = sorted(set(c["group"] for c in curves))
    n = len(groups_present)
    ncols = min(n, 4)
    nrows = math.ceil(n / ncols)

    fig, axes = plt.subplots(nrows, ncols, figsize=(4.5 * ncols, 3.5 * nrows), squeeze=False)
    fig.suptitle(f"DNS bifurcation curves — {CASE_LABELS.get(case, case)}", fontsize=11)

    for idx, g in enumerate(groups_present):
        ax = axes[idx // ncols][idx % ncols]
        group_curves = [c for c in curves if c["group"] == g]
        for i, c in enumerate(sorted(group_curves, key=lambda x: x["physical_id"])):
            ax.plot(c["re_vals"], c["shear_vals"], lw=1.3, alpha=0.85,
                    color=GROUP_COLORS.get(g, "gray"),
                    label=c["physical_id"].split("_")[-1])
        ax.set_title(f"Group {g}", fontsize=10, color=GROUP_COLORS.get(g, "gray"), fontweight="bold")
        ax.set_xlabel("Re", fontsize=9)
        ax.set_ylabel("shear", fontsize=9)
        ax.grid(True, lw=0.3, alpha=0.4)
        if len(group_curves) <= 12:
            ax.legend(fontsize=7, ncol=2)

    # Hide unused axes
    for idx in range(n, nrows * ncols):
        axes[idx // ncols][idx % ncols].set_visible(False)

    fig.tight_layout()
    out_path = out_dir / f"bif_faceted_{case}.pdf"
    fig.savefig(out_path, dpi=150)
    fig.savefig(out_dir / f"bif_faceted_{case}.png", dpi=150)
    print(f"  saved {out_path.name}")
    if show:
        plt.show()
    plt.close(fig)


def plot_all_cases_summary(by_case: dict[str, list[dict]], out_dir: Path, show: bool) -> None:
    """One summary figure: one subplot per case, all solutions overlaid."""
    cases = sorted(by_case.keys())
    n = len(cases)
    ncols = min(n, 2)
    nrows = math.ceil(n / ncols)

    fig, axes = plt.subplots(nrows, ncols, figsize=(7 * ncols, 4.5 * nrows), squeeze=False)
    fig.suptitle("DNS bifurcation curves — all cases", fontsize=12)

    seen_groups_global: set[str] = set()
    dummy_handles = {}

    for idx, case in enumerate(cases):
        ax = axes[idx // ncols][idx % ncols]
        curves = by_case[case]
        seen_groups: set[str] = set()

        for c in sorted(curves, key=lambda x: (x["group"], x["physical_id"])):
            g = c["group"]
            label = g if g not in seen_groups else None
            seen_groups.add(g)
            line, = ax.plot(
                c["re_vals"], c["shear_vals"],
                color=GROUP_COLORS.get(g, "gray"),
                lw=1.3, alpha=0.8,
                label=label,
            )
            if g not in seen_groups_global:
                dummy_handles[g] = line
                seen_groups_global.add(g)

        ax.set_title(CASE_LABELS.get(case, case), fontsize=10)
        ax.set_xlabel("Re", fontsize=9)
        ax.set_ylabel("Wall shear", fontsize=9)
        ax.grid(True, lw=0.3, alpha=0.4)
        ax.legend(title="Group", fontsize=8, title_fontsize=8)

    # Hide unused subplots
    for idx in range(n, nrows * ncols):
        axes[idx // ncols][idx % ncols].set_visible(False)

    fig.tight_layout()
    out_path = out_dir / "bif_all_cases_summary.pdf"
    fig.savefig(out_path, dpi=150)
    fig.savefig(out_dir / "bif_all_cases_summary.png", dpi=150)
    print(f"  saved {out_path.name}")
    if show:
        plt.show()
    plt.close(fig)


# ── individual-solution plots ─────────────────────────────────────────────────

def plot_individual_solutions(by_case: dict[str, list[dict]], out_dir: Path) -> None:
    """One small figure per physical solution — useful for spot-checking."""
    ind_dir = out_dir / "individual"
    ind_dir.mkdir(exist_ok=True)
    for case, curves in by_case.items():
        for c in curves:
            fig, ax = plt.subplots(figsize=(5, 3.5))
            g = c["group"]
            ax.plot(c["re_vals"], c["shear_vals"],
                    color=GROUP_COLORS.get(g, "gray"), lw=1.5)
            ax.set_xlabel("Re")
            ax.set_ylabel("Wall shear (perturbation)")
            ax.set_title(f"{c['physical_id']}  (Group {g})", fontsize=10)
            ax.grid(True, lw=0.3, alpha=0.4)
            fig.tight_layout()
            fig.savefig(ind_dir / f"{c['physical_id']}.png", dpi=120)
            plt.close(fig)
    print(f"  saved individual plots to {ind_dir}")


# ── main ──────────────────────────────────────────────────────────────────────

def parse_args():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--catalog-dir", default=None,
                   help="Path to eqb_catalog directory (default: auto-detect from script location)")
    p.add_argument("--out-dir", default=None,
                   help="Where to save plots (default: eqb_catalog/dns_bifurcations/plots)")
    p.add_argument("--show", action="store_true",
                   help="Display figures interactively (requires display)")
    p.add_argument("--no-individual", action="store_true",
                   help="Skip per-solution individual plots")
    return p.parse_args()


def main():
    args = parse_args()

    script_dir = Path(__file__).resolve().parent
    catalog_dir = Path(args.catalog_dir) if args.catalog_dir else script_dir / "eqb_catalog"
    dns_bif_dir = catalog_dir / "dns_bifurcations"
    out_dir = Path(args.out_dir) if args.out_dir else dns_bif_dir / "plots"
    out_dir.mkdir(parents=True, exist_ok=True)

    summary_csv = dns_bif_dir / "dns_bifurcation_summary.csv"
    print(f"Reading summary: {summary_csv}")
    by_case = load_all_curves(summary_csv)

    if not by_case:
        print("No completed runs found in summary CSV.")
        return

    total = sum(len(v) for v in by_case.values())
    print(f"Loaded {total} curves across {len(by_case)} cases: {sorted(by_case.keys())}")
    print(f"Output directory: {out_dir}")
    print()

    for case, curves in sorted(by_case.items()):
        print(f"[{case}] {len(curves)} curves")
        plot_case_overlaid(case, curves, out_dir, args.show)
        plot_case_faceted(case, curves, out_dir, args.show)

    print("\n[summary]")
    plot_all_cases_summary(by_case, out_dir, args.show)

    if not args.no_individual:
        print("\n[individual]")
        plot_individual_solutions(by_case, out_dir)

    print(f"\nDone. All plots saved to {out_dir}")


if __name__ == "__main__":
    main()

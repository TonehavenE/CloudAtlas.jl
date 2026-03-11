#!/usr/bin/env python3
"""Create ODE bifurcation overlay plots per unique converged DNS solution.

For each case/group/unique_id row in findsoln_unique CSV, build an overlay of
all available ODE bifurcation curves (Re vs shear) for the member sol_ids
across discretizations, with legend labels:
  solXXX JxKyLz (m=<num_modes>)
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import argparse
import csv
import re
from typing import Iterable

import matplotlib.pyplot as plt


MEMBER_RE = re.compile(r"^sol(?P<sid>\d+)@J(?P<J>\d+)K(?P<K>\d+)L(?P<L>\d+)$")
JKL_DIR_RE = re.compile(r"^jkl_(\d+)_(\d+)_(\d+)$")
GROUPS = ["A", "B", "C", "D", "E", "F", "G"]


@dataclass(frozen=True)
class Curve:
    sol_id: int
    J: int
    K: int
    L: int
    path: Path
    Re: list[float]
    shear: list[float]

    @property
    def modes(self) -> int:
        return (2 * self.J + 1) * (2 * self.K + 1) * (2 * self.L + 1)

    @property
    def label(self) -> str:
        return f"sol{self.sol_id:03d} J{self.J}K{self.K}L{self.L} (m={self.modes})"


def parse_member_tokens(members: str) -> list[int]:
    out: list[int] = []
    for token in str(members).split(";"):
        t = token.strip()
        if not t:
            continue
        m = MEMBER_RE.match(t)
        if m:
            out.append(int(m.group("sid")))
    return sorted(set(out))


def parse_jkl_dirname(name: str) -> tuple[int, int, int] | None:
    m = JKL_DIR_RE.match(name)
    if not m:
        return None
    return int(m.group(1)), int(m.group(2)), int(m.group(3))


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", newline="") as f:
        return list(csv.DictReader(f))


def find_curves_for_solution(case_dir: Path, group: str, sol_id: int) -> list[Curve]:
    out: list[Curve] = []
    group_dir = case_dir / group
    if not group_dir.is_dir():
        return out

    for d in sorted(group_dir.iterdir()):
        if not d.is_dir():
            continue
        jkl = parse_jkl_dirname(d.name)
        if jkl is None:
            continue
        J, K, L = jkl
        bif = d / "bifurcations" / f"bif_{group}_sol{sol_id:03d}.csv"
        if not bif.is_file():
            continue
        try:
            rows = read_csv_rows(bif)
        except Exception:
            continue
        if not rows:
            continue
        if "Re" not in rows[0] or "shear" not in rows[0]:
            continue
        try:
            re_vals = [float(r["Re"]) for r in rows]
            sh_vals = [float(r["shear"]) for r in rows]
        except Exception:
            continue
        out.append(Curve(sol_id=sol_id, J=J, K=K, L=L, path=bif, Re=re_vals, shear=sh_vals))
    out.sort(key=lambda c: (c.J, c.K, c.L, c.sol_id))
    return out


def save_overlay_plot(case: str, group: str, unique_id: str, curves: Iterable[Curve], out_png: Path) -> None:
    curves = list(curves)
    plt.figure(figsize=(10, 6))
    if not curves:
        plt.text(0.5, 0.5, "No bifurcation curves found for selected members.", ha="center", va="center", transform=plt.gca().transAxes)
    else:
        cmap = plt.get_cmap("tab20")
        for i, c in enumerate(curves):
            plt.plot(c.Re, c.shear, linewidth=1.8, color=cmap(i % 20), label=c.label)
    plt.title(f"{case} | Group {group} | {unique_id} : ODE bifurcation overlays")
    plt.xlabel("Re")
    plt.ylabel("shear")
    plt.grid(True, alpha=0.25)
    if curves:
        plt.legend(loc="center left", bbox_to_anchor=(1.02, 0.5), fontsize=8)
    plt.tight_layout()
    out_png.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(out_png, dpi=180)
    plt.close()


def case_list_from_unique_dir(unique_dir: Path, requested: list[str]) -> list[str]:
    if requested:
        return requested
    out: list[str] = []
    for p in sorted(unique_dir.glob("unique_converged_dns_*.csv")):
        case = p.stem.replace("unique_converged_dns_", "")
        out.append(case)
    return out


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--runs-root", default=str(Path(__file__).resolve().parent / "overnight_runs_updated"))
    parser.add_argument("--out-dir", default="")
    parser.add_argument("--cases", default="")
    args = parser.parse_args()

    runs_root = Path(args.runs_root).resolve()
    unique_dir = runs_root / "analysis" / "findsoln_unique"
    out_root = Path(args.out_dir).resolve() if args.out_dir else unique_dir / "bif_overlays"
    out_root.mkdir(parents=True, exist_ok=True)

    cases = [c.strip() for c in args.cases.split(",") if c.strip()]
    cases = case_list_from_unique_dir(unique_dir, cases)
    if not cases:
        raise SystemExit(f"No cases found in {unique_dir}")

    summary_rows: list[dict] = []

    for case in cases:
        unique_csv = unique_dir / f"unique_converged_dns_{case}.csv"
        if not unique_csv.is_file():
            continue
        dfu = read_csv_rows(unique_csv)
        case_dir = runs_root / case
        if not case_dir.is_dir():
            continue

        for row in dfu:
            group = str(row.get("group", ""))
            if group not in GROUPS:
                continue
            unique_id = str(row.get("unique_id", ""))
            members = str(row.get("members", ""))
            sol_ids = parse_member_tokens(members)
            all_curves: list[Curve] = []
            for sid in sol_ids:
                all_curves.extend(find_curves_for_solution(case_dir, group, sid))
            all_curves.sort(key=lambda c: (c.sol_id, c.J, c.K, c.L))

            out_dir = out_root / case / group
            out_dir.mkdir(parents=True, exist_ok=True)
            png_path = out_dir / f"{unique_id}.png"
            save_overlay_plot(case, group, unique_id, all_curves, png_path)

            summary_rows.append(
                {
                    "case": case,
                    "group": group,
                    "unique_id": unique_id,
                    "members": members,
                    "n_sol_ids": len(sol_ids),
                    "n_curves": len(all_curves),
                    "plot_path": str(png_path),
                }
            )

    summary_csv = out_root / "overlay_index.csv"
    with summary_csv.open("w", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["case", "group", "unique_id", "members", "n_sol_ids", "n_curves", "plot_path"],
        )
        writer.writeheader()
        writer.writerows(summary_rows)
    print(f"[done] wrote {summary_csv}")


if __name__ == "__main__":
    main()

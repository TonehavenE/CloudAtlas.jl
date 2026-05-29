#!/usr/bin/env python3
"""Import DNS-converged non-trivial GHC Sharma target fuzz outputs."""

from __future__ import annotations

import csv
import json
import re
import shutil
from dataclasses import dataclass
from pathlib import Path

import import_ghc_literature_fuzz_catalog as base


ROOT = Path(__file__).resolve().parents[2]
CATALOG_ROOT = ROOT / "catalog"
LX = 5.511566576198634
LZ = 2.5132741228718345
CLUSTER_TOL = 1e-3
TRIVIAL_TOL = 1e-8
GENERATED_AT = "2026-05-29T00:00:00-04:00"

GROUP_SYMMS = {
    "SigmaGHC": "<sztx, sxy*txz>",
    "Theta6": "<sxyz*tz>",
    "ThetaGHC": "<sxy, sztx, txz>",
}


@dataclass(frozen=True)
class Run:
    case: str
    re: float
    root: Path
    jobs_summary: Path
    source_label: str


RUNS = [
    Run(
        case="ghc_re330_sharma_target_fuzz",
        re=330.0,
        root=ROOT
        / "notebooks/eqb_fuzzing/literature_target_runs/ghc_re330_sharma/"
        / "ghc_re330_sharma_target_fuzz",
        jobs_summary=ROOT
        / "notebooks/eqb_fuzzing/literature_target_runs/ghc_re330_sharma/"
        / "findsoln_jobs_summary.csv",
        source_label="literature_target_runs:ghc_re330_sharma_target_fuzz",
    ),
    Run(
        case="ghc_re270_sharma_target_fuzz",
        re=270.0,
        root=ROOT
        / "notebooks/eqb_fuzzing/literature_target_runs/ghc_re270_sharma/"
        / "ghc_re270_sharma_target_fuzz",
        jobs_summary=ROOT
        / "notebooks/eqb_fuzzing/literature_target_runs/ghc_re270_sharma/"
        / "findsoln_jobs_summary.csv",
        source_label="literature_target_runs:ghc_re270_sharma_target_fuzz",
    ),
]


def read_ok_candidates(run: Run) -> list[base.Candidate]:
    candidates: list[base.Candidate] = []
    with run.jobs_summary.open(newline="") as f:
        for row in csv.DictReader(f):
            if row["status"] != "ok":
                continue
            group = row["group"]
            j, k, l = int(row["J"]), int(row["K"]), int(row["L"])
            sol_id = int(row["sol_id"])
            sol_root = run.root / group / f"jkl_{j}_{k}_{l}"
            sol_dir = Path(row["job_dir"])
            asc = sol_root / f"sol{sol_id}.asc"
            ubest = sol_dir / "ubest.nc"
            fieldconverge = sol_dir / "fieldconverge.asc"
            if not asc.is_file() or not ubest.is_file() or not fieldconverge.is_file():
                continue
            diagnostics = base.read_fieldconverge(fieldconverge)
            if diagnostics["L2"] <= TRIVIAL_TOL and abs(diagnostics["wallshear"]) <= TRIVIAL_TOL:
                continue
            candidates.append(
                base.Candidate(
                    group=group,
                    J=j,
                    K=k,
                    L=l,
                    sol_id=sol_id,
                    asc=asc,
                    ubest=ubest,
                    fieldconverge=fieldconverge,
                    diagnostics=diagnostics,
                    catalog_source=run.source_label,
                    member_prefix=group,
                )
            )
    return candidates


def cluster_candidates(candidates: list[base.Candidate]) -> list[base.Cluster]:
    clusters: list[base.Cluster] = []
    for cand in sorted(candidates, key=lambda c: (c.shear, c.L2, c.group, c.jkl, c.sol_id)):
        for cluster in clusters:
            rep = cluster.rep
            if abs(cand.shear - rep.shear) <= CLUSTER_TOL and abs(cand.L2 - rep.L2) <= CLUSTER_TOL:
                cluster.candidates.append(cand)
                break
        else:
            clusters.append(base.Cluster([cand]))
    return sorted(clusters, key=lambda c: (c.rep.shear, c.rep.L2))


def configure_base(run: Run) -> None:
    base.CASE = run.case
    base.RE = run.re
    base.LX = LX
    base.LZ = LZ
    base.CATALOG_SOURCE = run.source_label
    base.SOURCE_PATHS = {run.source_label: run.root}
    base.GROUP_SYMMS = GROUP_SYMMS
    base.GENERATED_AT = GENERATED_AT


def import_case(run: Run) -> tuple[int, int, int]:
    configure_base(run)
    candidates = read_ok_candidates(run)
    clusters = cluster_candidates(candidates)
    catalog_clusters = [
        (idx, cluster)
        for idx, cluster in enumerate(clusters, start=1)
        if base.has_completed_eigen(f"{run.case}_{idx:03d}")
    ]
    valid_ids = {f"{run.case}_{idx:03d}" for idx, _ in catalog_clusters}
    base.cleanup_obsolete_dirs(valid_ids)

    manifest_path = CATALOG_ROOT / "catalog_manifest.csv"
    fieldnames, rows = base.read_csv_rows(manifest_path)
    rows = [r for r in rows if r.get("case") != run.case]

    new_meta: list[dict[str, object]] = []
    for idx, cluster in catalog_clusters:
        pid = f"{run.case}_{idx:03d}"
        out_dir = CATALOG_ROOT / "equilibria" / pid
        out_dir.mkdir(parents=True, exist_ok=True)
        rep = cluster.rep
        shutil.copy2(rep.asc, out_dir / "representative.asc")
        shutil.copy2(rep.ubest, out_dir / "ubest.nc")
        cat_path = base.rel(out_dir)
        meta = base.metadata_for(pid, cluster, cat_path, out_dir)
        new_meta.append(meta)
        out_dir.joinpath("metadata.json").write_text(
            json.dumps(meta, indent=2, sort_keys=True) + "\n"
        )
        out_dir.joinpath("index.md").write_text(base.index_markdown(pid, meta))
        d = rep.diagnostics
        eigen = meta["eigen_analysis"]
        leading = eigen.get("leading") or {}
        rows.append(
            {
                "physical_id": pid,
                "case": run.case,
                "catalog_source": rep.catalog_source,
                "Re": run.re,
                "Lx": LX,
                "Lz": LZ,
                "shear": d["wallshear"],
                "L2": d["L2"],
                "groups": ",".join(cluster.groups),
                "representative_group": rep.group,
                "representative_J": rep.J,
                "representative_K": rep.K,
                "representative_L": rep.L,
                "ode": f"equilibria/{pid}/representative.asc",
                "dns": f"equilibria/{pid}/ubest.nc",
                "dns_ode_comparison": "",
                "dns_bifurcation": "",
                "dns_bifurcation_points": 0,
                "E3D": d["e3d"],
                "dissipation": d["dissipation"],
                "D_total": d["dissipation"] + 1.0,
                "wall_shear": d["wallshear"],
                "I_total": d["wallshear"] + 1.0,
                "leading_lambda_re": leading.get("lambda_re", ""),
                "leading_lambda_im": leading.get("lambda_im", ""),
                "n_unstable": eigen.get("n_unstable", ""),
                "eigen_lambda": f"equilibria/{pid}/eigen/lambda.asc" if eigen["available"] else "",
                "leading_eigenvector": f"equilibria/{pid}/eigen/ef1.nc" if eigen["available"] else "",
                "literature": "",
                "dedup_component_id": "",
                "dedup_component_size": 1,
                "dedup_status": "single",
                "dedup_members": pid,
                "dedup_edge_count": 0,
            }
        )

    base.write_csv_rows(manifest_path, fieldnames, rows)
    base.sync_indexes(new_meta)
    return len(candidates), len(clusters), len(catalog_clusters)


def main() -> None:
    totals = []
    for run in RUNS:
        totals.append((run, *import_case(run)))
    readme = CATALOG_ROOT / "README.md"
    total = len(json.loads((CATALOG_ROOT / "index.json").read_text())["solutions"])
    readme.write_text(re.sub(r"\b\d+ unique", f"{total} unique", readme.read_text(), count=1))
    for run, candidates, clusters, added in totals:
        print(
            f"{run.case}: {candidates} non-trivial ok DNS candidates, "
            f"{clusters} clusters, {added} catalog entries"
        )


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Import the GHC Re=400 literature fuzz run into the generated catalog."""

from __future__ import annotations

import csv
import json
import shutil
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RUN_ROOT = (
    ROOT
    / "notebooks/eqb_fuzzing/literature_target_runs/ghc_re400/"
    / "ghc_re400_literature_fuzz"
)
CATALOG_ROOT = ROOT / "catalog"

CASE = "ghc_re400_literature_fuzz"
CATALOG_SOURCE = "literature_target_runs:ghc_re400_literature_fuzz"
RE = 400.0
LX = 5.511566576198634
LZ = 2.5132741228718345
CLUSTER_TOL = 1e-4

GROUP_SYMMS = {
    "A": "<sxyz, txz>",
    "B": "<sxy, sz>",
    "C": "<sxytz, sz>",
    "D": "<sxy, sztx>",
    "E": "<sxyz, sztxz>",
    "F": "<sxy, sz, txz>",
    "G": "<sxyz>",
}


@dataclass
class Candidate:
    group: str
    J: int
    K: int
    L: int
    sol_id: int
    L2: float
    shear_total: float
    asc: Path
    ubest: Path

    @property
    def shear(self) -> float:
        return self.shear_total - 1.0

    @property
    def jkl(self) -> tuple[int, int, int]:
        return (self.J, self.K, self.L)

    @property
    def member(self) -> str:
        return f"fuzz:sol{self.sol_id:03d}@J{self.J}K{self.K}L{self.L}"


@dataclass
class Cluster:
    candidates: list[Candidate] = field(default_factory=list)

    @property
    def rep(self) -> Candidate:
        return max(
            self.candidates,
            key=lambda c: (c.jkl, -abs(c.shear), c.group, -c.sol_id),
        )

    @property
    def shear(self) -> float:
        return self.rep.shear

    @property
    def L2(self) -> float:
        return self.rep.L2

    @property
    def groups(self) -> list[str]:
        return sorted({c.group for c in self.candidates})

    def matches(self, cand: Candidate) -> bool:
        ref = self.rep
        return (
            abs(cand.shear - ref.shear) <= CLUSTER_TOL
            and abs(cand.L2 - ref.L2) <= CLUSTER_TOL
        )


def read_candidates() -> list[Candidate]:
    out: list[Candidate] = []
    for summary in sorted(RUN_ROOT.glob("[A-G]/jkl_*/solutions_summary.csv")):
        group = summary.parts[-3]
        jkl = summary.parts[-2]
        _, J, K, L = jkl.split("_")
        J, K, L = int(J), int(K), int(L)
        with summary.open(newline="") as f:
            for row in csv.DictReader(f):
                sol_id = int(row["id"])
                sol_dir = summary.parent / "dns_findsoln" / f"sol{sol_id:03d}"
                ubest = sol_dir / "ubest.nc"
                asc = summary.parent / f"sol{sol_id}.asc"
                if not ubest.is_file() or not asc.is_file():
                    continue
                out.append(
                    Candidate(
                        group=group,
                        J=J,
                        K=K,
                        L=L,
                        sol_id=sol_id,
                        L2=float(row["norm"]),
                        shear_total=float(row["shear"]),
                        asc=asc,
                        ubest=ubest,
                    )
                )
    return out


def cluster_candidates(candidates: list[Candidate]) -> list[Cluster]:
    clusters: list[Cluster] = []
    for cand in sorted(candidates, key=lambda c: (c.shear, c.L2, c.group, c.jkl)):
        for cluster in clusters:
            if cluster.matches(cand):
                cluster.candidates.append(cand)
                break
        else:
            clusters.append(Cluster([cand]))
    return sorted(clusters, key=lambda c: (c.shear, c.L2))


def read_csv_rows(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open(newline="") as f:
        reader = csv.DictReader(f)
        return list(reader.fieldnames or []), list(reader)


def write_csv_rows(path: Path, fieldnames: list[str], rows: list[dict[str, object]]) -> None:
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({k: row.get(k, "") for k in fieldnames})


def rel(path: Path) -> str:
    return path.relative_to(CATALOG_ROOT).as_posix()


def metadata_for(pid: str, cluster: Cluster, cat_path: str) -> dict[str, object]:
    rep = cluster.rep
    group_rows = []
    for cand in sorted(cluster.candidates, key=lambda c: (c.group, c.jkl, c.sol_id)):
        group_rows.append(
            {
                "group": cand.group,
                "symmetry": GROUP_SYMMS[cand.group],
                "representative": str(cand.ubest),
                "members": cand.member,
                "J": cand.J,
                "K": cand.K,
                "L": cand.L,
            }
        )
    return {
        "physical_id": pid,
        "case": CASE,
        "catalog_source": CATALOG_SOURCE,
        "catalog_path": cat_path,
        "Re": RE,
        "Lx": LX,
        "Lz": LZ,
        "shear": rep.shear,
        "L2": rep.L2,
        "groups": cluster.groups,
        "representative_group": rep.group,
        "representative_J": rep.J,
        "representative_K": rep.K,
        "representative_L": rep.L,
        "assets": {
            "ode": f"{cat_path}/representative.asc",
            "dns": f"{cat_path}/ubest.nc",
            "dns_ode_comparison": None,
        },
        "bifurcation": {
            "available": False,
            "csv": None,
            "curve": [],
            "max_Re": None,
            "max_input": None,
            "min_Re": None,
            "min_input": None,
            "n_points": 0,
        },
        "dns_diagnostics": None,
        "eigen_analysis": {
            "available": False,
            "method": None,
            "n_eigenvalues": 0,
            "n_unstable": None,
            "leading": None,
            "spectrum": [],
            "files": {},
            "eigenvectors": [],
            "error": None,
        },
        "literature": "",
        "deduplication": {
            "component_id": "",
            "component_size": 1,
            "status": "single",
            "members": [pid],
            "edges": [],
            "strong_edges": 0,
            "weak_edges": 0,
        },
        "group_representatives": group_rows,
    }


def index_markdown(pid: str, meta: dict[str, object]) -> str:
    groups = ", ".join(meta["groups"])
    return f"""---
physical_id: "{pid}"
case: "{CASE}"
catalog_source: "{CATALOG_SOURCE}"
Re: {RE}
Lx: {LX}
Lz: {LZ}
shear: {meta["shear"]}
L2: {meta["L2"]}
groups: {json.dumps(meta["groups"])}
representative_group: "{meta["representative_group"]}"
representative_J: {meta["representative_J"]}
representative_K: {meta["representative_K"]}
representative_L: {meta["representative_L"]}
has_dns_bifurcation: false
has_eigen_analysis: false
has_literature_mapping: false
literature: ""
dedup_component_id: ""
dedup_component_size: 1
dedup_status: "single"
---

# {pid}

## Summary

| Quantity | Value |
|---|---:|
| Case | `{CASE}` |
| Catalog source | `{CATALOG_SOURCE}` |
| Re | {RE} |
| Lx | {LX} |
| Lz | {LZ} |
| Shear | {meta["shear"]} |
| L2 | {meta["L2"]} |
| Groups | `{groups}` |

## Representative Files

- ODE coefficients: [representative.asc](representative.asc)
- DNS flowfield: [ubest.nc](ubest.nc)

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
{chr(10).join(f'| {r["group"]} | `{r["symmetry"]}` | `{r["representative"]}` | `{r["members"]}` |' for r in meta["group_representatives"])}

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.
"""


def sync_json_indexes(new_meta: list[dict[str, object]]) -> None:
    index_path = CATALOG_ROOT / "index.json"
    data = json.loads(index_path.read_text())
    old_solutions = [s for s in data["solutions"] if s.get("case") != CASE]
    data["solutions"] = old_solutions + new_meta
    data["cases"] = sorted({s["case"] for s in data["solutions"]})
    sources = {s["label"]: s for s in data.get("catalog_sources", [])}
    sources[CATALOG_SOURCE] = {
        "label": CATALOG_SOURCE,
        "path": str(RUN_ROOT),
        "solutions": len(new_meta),
    }
    data["catalog_sources"] = sorted(sources.values(), key=lambda s: s["label"])
    data["counts"]["solutions"] = len(data["solutions"])
    data["counts"]["with_dns"] = sum(1 for s in data["solutions"] if s["assets"]["dns"])
    data["counts"]["with_ode"] = sum(1 for s in data["solutions"] if s["assets"]["ode"])
    data["counts"]["with_eigen_analysis"] = sum(
        1 for s in data["solutions"] if s.get("eigen_analysis", {}).get("available")
    )
    data["counts"]["with_dns_bifurcation"] = sum(
        1 for s in data["solutions"] if s.get("bifurcation", {}).get("available")
    )
    data["counts"]["with_dns_diagnostics"] = sum(
        1 for s in data["solutions"] if s.get("dns_diagnostics")
    )
    data["counts"]["with_dns_ode_comparison"] = sum(
        1 for s in data["solutions"] if s["assets"].get("dns_ode_comparison")
    )
    data["counts"]["with_literature_mapping"] = sum(
        1 for s in data["solutions"] if s.get("literature")
    )
    data["generated_at"] = datetime.now(timezone.utc).isoformat()
    index_path.write_text(json.dumps(data, indent=2) + "\n")
    (CATALOG_ROOT / "site/catalog-data.js").write_text(
        "window.CATALOG_DATA = "
        + json.dumps(data, indent=2)
        + ";\n"
    )


def main() -> None:
    candidates = read_candidates()
    clusters = cluster_candidates(candidates)
    if not clusters:
        raise SystemExit(f"No DNS-reconverged candidates found under {RUN_ROOT}")

    manifest_path = CATALOG_ROOT / "catalog_manifest.csv"
    fieldnames, rows = read_csv_rows(manifest_path)
    rows = [r for r in rows if r.get("case") != CASE]

    new_meta: list[dict[str, object]] = []
    for idx, cluster in enumerate(clusters, start=1):
        pid = f"{CASE}_{idx:03d}"
        out_dir = CATALOG_ROOT / "equilibria" / pid
        out_dir.mkdir(parents=True, exist_ok=True)
        rep = cluster.rep
        shutil.copy2(rep.asc, out_dir / "representative.asc")
        shutil.copy2(rep.ubest, out_dir / "ubest.nc")
        meta = metadata_for(pid, cluster, rel(out_dir))
        new_meta.append(meta)
        (out_dir / "metadata.json").write_text(
            json.dumps(meta, indent=2, sort_keys=True) + "\n"
        )
        (out_dir / "index.md").write_text(index_markdown(pid, meta))

        rows.append(
            {
                "physical_id": pid,
                "case": CASE,
                "catalog_source": CATALOG_SOURCE,
                "Re": RE,
                "Lx": LX,
                "Lz": LZ,
                "shear": rep.shear,
                "L2": rep.L2,
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
                "E3D": "",
                "dissipation": "",
                "D_total": "",
                "wall_shear": "",
                "I_total": "",
                "leading_lambda_re": "",
                "leading_lambda_im": "",
                "n_unstable": "",
                "eigen_lambda": "",
                "leading_eigenvector": "",
                "literature": "",
                "dedup_component_id": "",
                "dedup_component_size": 1,
                "dedup_status": "single",
                "dedup_members": pid,
                "dedup_edge_count": 0,
            }
        )

    write_csv_rows(manifest_path, fieldnames, rows)
    sync_json_indexes(new_meta)

    print(f"Imported {len(candidates)} DNS-reconverged candidates")
    print(f"Added {len(clusters)} catalog solutions for {CASE}")


if __name__ == "__main__":
    main()

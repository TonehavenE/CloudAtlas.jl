#!/usr/bin/env python3
"""Import DNS-converged non-trivial GHC Re=400 literature fuzz outputs."""

from __future__ import annotations

import csv
import json
import math
import re
import shutil
from dataclasses import dataclass, field
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RUN_ROOT = (
    ROOT
    / "notebooks/eqb_fuzzing/literature_target_runs/ghc_re400/"
    / "ghc_re400_literature_fuzz"
)
RUN_ROOT_V2 = (
    ROOT
    / "notebooks/eqb_fuzzing/literature_target_runs_v2/ghc_re400/"
    / "ghc_re400_literature_fuzz"
)
CATALOG_ROOT = ROOT / "catalog"

CASE = "ghc_re400_literature_fuzz"
CATALOG_SOURCE = "literature_target_runs:ghc_re400_literature_fuzz"
CATALOG_SOURCE_V2 = "literature_target_runs_v2:ghc_re400_literature_fuzz"
SOURCE_PATHS = {
    CATALOG_SOURCE: RUN_ROOT,
    CATALOG_SOURCE_V2: RUN_ROOT_V2,
}
RE = 400.0
LX = 5.511566576198634
LZ = 2.5132741228718345
CLUSTER_TOL = 1e-3
TRIVIAL_TOL = 1e-8
GENERATED_AT = "2026-05-27T01:36:26+00:00"

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
    asc: Path
    ubest: Path
    fieldconverge: Path
    diagnostics: dict[str, float]
    catalog_source: str = CATALOG_SOURCE
    member_prefix: str = "fuzz"

    @property
    def L2(self) -> float:
        return self.diagnostics["L2"]

    @property
    def shear(self) -> float:
        return self.diagnostics["wallshear"]

    @property
    def jkl(self) -> tuple[int, int, int]:
        return (self.J, self.K, self.L)

    @property
    def member(self) -> str:
        return f"{self.member_prefix}:sol{self.sol_id:03d}@J{self.J}K{self.K}L{self.L}"


@dataclass
class Cluster:
    candidates: list[Candidate] = field(default_factory=list)

    @property
    def rep(self) -> Candidate:
        return max(
            self.candidates,
            key=lambda c: (c.jkl, c.group, -c.sol_id),
        )

    @property
    def groups(self) -> list[str]:
        return sorted({c.group for c in self.candidates})

    def matches(self, cand: Candidate) -> bool:
        ref = self.rep
        return (
            abs(cand.shear - ref.shear) <= CLUSTER_TOL
            and abs(cand.L2 - ref.L2) <= CLUSTER_TOL
        )


def read_fieldconverge(path: Path) -> dict[str, float]:
    rows = [ln.split() for ln in path.read_text().splitlines() if ln.strip()]
    if len(rows) < 2:
        raise ValueError(f"Empty fieldconverge file: {path}")
    return dict(zip(rows[0], map(float, rows[-1])))


def read_candidates() -> list[Candidate]:
    out: list[Candidate] = []
    for fc in sorted(RUN_ROOT.glob("[A-G]/jkl_*/dns_findsoln/sol*/fieldconverge.asc")):
        rel = fc.relative_to(RUN_ROOT).parts
        group = rel[0]
        _, J, K, L = rel[1].split("_")
        J, K, L = int(J), int(K), int(L)
        sol_id = int(rel[3][3:])
        sol_dir = fc.parent
        asc = sol_dir.parents[1] / f"sol{sol_id}.asc"
        ubest = sol_dir / "ubest.nc"
        diagnostics = read_fieldconverge(fc)
        if not asc.is_file() or not ubest.is_file():
            continue
        if diagnostics["L2"] <= TRIVIAL_TOL and abs(diagnostics["wallshear"]) <= TRIVIAL_TOL:
            continue
        out.append(
            Candidate(
                group=group,
                J=J,
                K=K,
                L=L,
                sol_id=sol_id,
                asc=asc,
                ubest=ubest,
                fieldconverge=fc,
                diagnostics=diagnostics,
            )
        )
    return out


def read_candidate(
    root: Path,
    group: str,
    J: int,
    K: int,
    L: int,
    sol_id: int,
    *,
    catalog_source: str,
    member_prefix: str,
) -> Candidate:
    sol_root = root / group / f"jkl_{J}_{K}_{L}"
    sol_dir = sol_root / "dns_findsoln" / f"sol{sol_id:03d}"
    asc = sol_root / f"sol{sol_id}.asc"
    ubest = sol_dir / "ubest.nc"
    fc = sol_dir / "fieldconverge.asc"
    if not asc.is_file():
        raise FileNotFoundError(asc)
    if not ubest.is_file():
        raise FileNotFoundError(ubest)
    diagnostics = read_fieldconverge(fc)
    if diagnostics["L2"] <= TRIVIAL_TOL and abs(diagnostics["wallshear"]) <= TRIVIAL_TOL:
        raise ValueError(f"Trivial DNS convergence is not catalogable: {fc}")
    return Candidate(
        group=group,
        J=J,
        K=K,
        L=L,
        sol_id=sol_id,
        asc=asc,
        ubest=ubest,
        fieldconverge=fc,
        diagnostics=diagnostics,
        catalog_source=catalog_source,
        member_prefix=member_prefix,
    )


def read_extra_catalog_clusters() -> list[tuple[int, Cluster]]:
    return [
        (
            15,
            Cluster(
                [
                    read_candidate(
                        RUN_ROOT_V2,
                        "E",
                        1,
                        4,
                        5,
                        5,
                        catalog_source=CATALOG_SOURCE_V2,
                        member_prefix="fuzz_v2",
                    )
                ]
            ),
        )
    ]


def cluster_candidates(candidates: list[Candidate]) -> list[Cluster]:
    clusters: list[Cluster] = []
    for cand in sorted(candidates, key=lambda c: (c.shear, c.L2, c.group, c.jkl, c.sol_id)):
        for cluster in clusters:
            if cluster.matches(cand):
                cluster.candidates.append(cand)
                break
        else:
            clusters.append(Cluster([cand]))
    return sorted(clusters, key=lambda c: (c.rep.shear, c.rep.L2))


def rel(path: Path) -> str:
    return path.relative_to(CATALOG_ROOT).as_posix()


def read_csv_rows(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open(newline="") as f:
        reader = csv.DictReader(f)
        return list(reader.fieldnames or []), list(reader)


def write_csv_rows(path: Path, fieldnames: list[str], rows: list[dict[str, object]]) -> None:
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow({k: row.get(k, "") for k in fieldnames})


def load_pairs(path: Path) -> list[tuple[float, float]]:
    vals: list[tuple[float, float]] = []
    if not path.is_file():
        return vals
    for line in path.read_text().splitlines():
        s = line.strip()
        if not s or s.startswith("%") or s.startswith("#"):
            continue
        parts = s.split()
        if len(parts) == 1:
            vals.append((float(parts[0]), 0.0))
        else:
            vals.append((float(parts[0]), float(parts[1])))
    return vals


def load_residuals(path: Path) -> list[float]:
    vals: list[float] = []
    if not path.is_file():
        return vals
    for line in path.read_text().splitlines():
        s = line.strip()
        if not s or s.startswith("%") or s.startswith("#"):
            continue
        vals.append(float(s.split()[0]))
    return vals


def parse_eigen(cat_path: str, out_dir: Path) -> dict[str, object]:
    eigen_dir = out_dir / "eigen"
    lambdas = load_pairs(eigen_dir / "lambda.asc")
    multipliers = load_pairs(eigen_dir / "Lambda.asc")
    residuals = load_residuals(eigen_dir / "Residu.asc")
    if not lambdas:
        return {
            "available": False,
            "method": None,
            "n_eigenvalues": 0,
            "n_unstable": None,
            "leading": None,
            "spectrum": [],
            "files": {},
            "eigenvectors": [],
            "error": None,
        }

    spectrum = []
    for i, lam in enumerate(lambdas, start=1):
        mult = multipliers[i - 1] if i <= len(multipliers) else (None, None)
        ef = eigen_dir / f"ef{i}.nc"
        spectrum.append(
            {
                "index": i,
                "lambda_re": lam[0],
                "lambda_im": lam[1],
                "multiplier_re": mult[0],
                "multiplier_im": mult[1],
                "residual": residuals[i - 1] if i <= len(residuals) else None,
                "unstable": lam[0] > 0,
                "eigenvector": f"{cat_path}/eigen/ef{i}.nc" if ef.is_file() else None,
            }
        )
    leading = max(spectrum, key=lambda r: r["lambda_re"])
    eigenvectors = [r["eigenvector"] for r in spectrum if r["eigenvector"]]
    return {
        "available": True,
        "method": "findeigenvals",
        "n_eigenvalues": len(spectrum),
        "n_unstable": sum(1 for r in spectrum if r["unstable"]),
        "leading": leading,
        "spectrum": spectrum,
        "files": {
            "args": f"{cat_path}/eigen/findeigenvals.args",
            "lambda": f"{cat_path}/eigen/lambda.asc",
            "multipliers": f"{cat_path}/eigen/Lambda.asc",
            "residuals": f"{cat_path}/eigen/Residu.asc",
        },
        "eigenvectors": eigenvectors,
        "error": None,
        "parameters": {
            "R": RE,
            "T": 5.0,
            "N": 32,
            "Ns": 6,
            "dt": None,
            "variabledt": False,
        },
    }


def metadata_for(pid: str, cluster: Cluster, cat_path: str, out_dir: Path) -> dict[str, object]:
    rep = cluster.rep
    d = rep.diagnostics
    group_rows = [
        {
            "group": c.group,
            "symmetry": GROUP_SYMMS[c.group],
            "representative": str(c.ubest),
            "members": c.member,
            "J": c.J,
            "K": c.K,
            "L": c.L,
        }
        for c in sorted(cluster.candidates, key=lambda c: (c.group, c.jkl, c.sol_id))
    ]
    return {
        "physical_id": pid,
        "case": CASE,
        "catalog_source": rep.catalog_source,
        "catalog_path": cat_path,
        "Re": RE,
        "Lx": LX,
        "Lz": LZ,
        "shear": d["wallshear"],
        "L2": d["L2"],
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
        "dns_diagnostics": {
            "method": "fieldconverge",
            "source": str(rep.fieldconverge),
            "values": d,
            "derived": {
                "D_total": d["dissipation"] + 1.0,
                "I_total": d["wallshear"] + 1.0,
            },
        },
        "eigen_analysis": parse_eigen(cat_path, out_dir),
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
    d = meta["dns_diagnostics"]["values"]
    derived = meta["dns_diagnostics"]["derived"]
    eigen = meta["eigen_analysis"]
    leading = eigen.get("leading") or {}
    groups = ", ".join(meta["groups"])
    eigen_section = "No eigenvalue analysis is available yet."
    if eigen["available"]:
        eigen_section = f"""| Quantity | Value |
|---|---:|
| Method | `findeigenvals` |
| Eigenvalues | {eigen["n_eigenvalues"]} |
| Unstable count | {eigen["n_unstable"]} |
| Leading lambda | {leading["lambda_re"]} + {leading["lambda_im"]}i |
| Leading multiplier | {leading["multiplier_re"]} + {leading["multiplier_im"]}i |
| Leading residual | {leading["residual"]} |

- Spectrum: [lambda.asc](eigen/lambda.asc)
- Multipliers: [Lambda.asc](eigen/Lambda.asc)
- Residuals: [Residu.asc](eigen/Residu.asc)
- Leading eigenvector: [ef1.nc](eigen/ef1.nc)"""

    return f"""---
physical_id: "{pid}"
case: "{CASE}"
catalog_source: "{meta["catalog_source"]}"
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
E3D: {d["e3d"]}
dissipation: {d["dissipation"]}
D_total: {derived["D_total"]}
wall_shear: {d["wallshear"]}
I_total: {derived["I_total"]}
has_eigen_analysis: {str(eigen["available"]).lower()}
leading_lambda_re: {leading.get("lambda_re", "")}
leading_lambda_im: {leading.get("lambda_im", "")}
n_unstable: {eigen.get("n_unstable", "")}
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
| Catalog source | `{meta["catalog_source"]}` |
| Re | {RE} |
| Lx | {LX} |
| Lz | {LZ} |
| Shear | {meta["shear"]} |
| L2 | {meta["L2"]} |
| Groups | `{groups}` |

## Literature

No literature mapping recorded yet.

## Representative Files

- ODE coefficients: [representative.asc](representative.asc)
- DNS flowfield: [ubest.nc](ubest.nc)

## DNS Diagnostics

| Quantity | Value |
|---|---:|
| L2 | {d["L2"]} |
| u2 | {d["u2"]} |
| v2 | {d["v2"]} |
| w2 | {d["w2"]} |
| e3d | {d["e3d"]} |
| ecf | {d["ecf"]} |
| ubulk | {d["ubulk"]} |
| wbulk | {d["wbulk"]} |
| wallshear | {d["wallshear"]} |
| wallshear_a | {d["wallshear_a"]} |
| wallshear_b | {d["wallshear_b"]} |
| dissipation | {d["dissipation"]} |
| I_total | {derived["I_total"]} |
| D_total | {derived["D_total"]} |

## Eigenvalue Analysis

{eigen_section}

## Group Representatives

| Group | Symmetry | Representative | Members |
|---|---|---|---|
{chr(10).join(f'| {r["group"]} | `{r["symmetry"]}` | `{r["representative"]}` | `{r["members"]}` |' for r in meta["group_representatives"])}

## DNS Bifurcation

No DNS bidirectional bifurcation curve is available for this solution.
"""


def sync_indexes(new_meta: list[dict[str, object]]) -> None:
    index_path = CATALOG_ROOT / "index.json"
    data = json.loads(index_path.read_text())
    data["solutions"] = [s for s in data["solutions"] if s.get("case") != CASE] + new_meta
    data["cases"] = sorted({s["case"] for s in data["solutions"]})
    sources = {s["label"]: s for s in data.get("catalog_sources", [])}
    for label in SOURCE_PATHS:
        count = sum(1 for s in new_meta if s["catalog_source"] == label)
        if count:
            sources[label] = {
                "label": label,
                "path": str(SOURCE_PATHS[label]),
                "solutions": count,
            }
        else:
            sources.pop(label, None)
    data["catalog_sources"] = sorted(sources.values(), key=lambda s: s["label"])
    c = data["counts"]
    c["solutions"] = len(data["solutions"])
    c["with_dns"] = sum(1 for s in data["solutions"] if s["assets"].get("dns"))
    c["with_ode"] = sum(1 for s in data["solutions"] if s["assets"].get("ode"))
    c["with_eigen_analysis"] = sum(
        1 for s in data["solutions"] if s.get("eigen_analysis", {}).get("available")
    )
    c["with_dns_bifurcation"] = sum(
        1 for s in data["solutions"] if s.get("bifurcation", {}).get("available")
    )
    c["with_dns_diagnostics"] = sum(1 for s in data["solutions"] if s.get("dns_diagnostics"))
    c["with_dns_ode_comparison"] = sum(
        1 for s in data["solutions"] if s["assets"].get("dns_ode_comparison")
    )
    c["with_literature_mapping"] = sum(1 for s in data["solutions"] if s.get("literature"))
    data["generated_at"] = GENERATED_AT
    index_path.write_text(json.dumps(data, indent=2) + "\n")

    site_original = CATALOG_ROOT.joinpath("site/catalog-data.js").read_text()
    prefix = "window.CATALOG_DATA = "
    if not site_original.startswith(prefix):
        raise ValueError("Unexpected catalog-data.js prefix")
    CATALOG_ROOT.joinpath("site/catalog-data.js").write_text(
        prefix + json.dumps(data, indent=2) + ";\n"
    )


def cleanup_obsolete_dirs(valid_ids: set[str]) -> None:
    for path in CATALOG_ROOT.glob(f"equilibria/{CASE}_*"):
        if path.name not in valid_ids:
            shutil.rmtree(path)


def has_completed_eigen(pid: str) -> bool:
    eigen_dir = CATALOG_ROOT / "equilibria" / pid / "eigen"
    return (eigen_dir / "lambda.asc").is_file()


def main() -> None:
    candidates = read_candidates()
    clusters = cluster_candidates(candidates)
    catalog_clusters = [
        (idx, cluster)
        for idx, cluster in enumerate(clusters, start=1)
        if has_completed_eigen(f"{CASE}_{idx:03d}")
    ]
    extra_clusters = [
        (idx, cluster)
        for idx, cluster in read_extra_catalog_clusters()
        if has_completed_eigen(f"{CASE}_{idx:03d}")
    ]
    catalog_clusters.extend(extra_clusters)
    valid_ids = {f"{CASE}_{idx:03d}" for idx, _ in catalog_clusters}
    cleanup_obsolete_dirs(valid_ids)

    manifest_path = CATALOG_ROOT / "catalog_manifest.csv"
    fieldnames, rows = read_csv_rows(manifest_path)
    rows = [r for r in rows if r.get("case") != CASE]

    new_meta: list[dict[str, object]] = []
    for idx, cluster in catalog_clusters:
        pid = f"{CASE}_{idx:03d}"
        out_dir = CATALOG_ROOT / "equilibria" / pid
        out_dir.mkdir(parents=True, exist_ok=True)
        rep = cluster.rep
        shutil.copy2(rep.asc, out_dir / "representative.asc")
        shutil.copy2(rep.ubest, out_dir / "ubest.nc")
        cat_path = rel(out_dir)
        meta = metadata_for(pid, cluster, cat_path, out_dir)
        new_meta.append(meta)
        out_dir.joinpath("metadata.json").write_text(json.dumps(meta, indent=2, sort_keys=True) + "\n")
        out_dir.joinpath("index.md").write_text(index_markdown(pid, meta))
        d = rep.diagnostics
        eigen = meta["eigen_analysis"]
        leading = eigen.get("leading") or {}
        rows.append(
            {
                "physical_id": pid,
                "case": CASE,
                "catalog_source": rep.catalog_source,
                "Re": RE,
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

    write_csv_rows(manifest_path, fieldnames, rows)
    sync_indexes(new_meta)
    readme = CATALOG_ROOT / "README.md"
    total = len(json.loads((CATALOG_ROOT / "index.json").read_text())["solutions"])
    readme.write_text(re.sub(r"\b\d+ unique", f"{total} unique", readme.read_text(), count=1))

    print(f"Imported {len(candidates) + sum(len(c.candidates) for _, c in extra_clusters)} non-trivial DNS-converged candidates")
    print(f"Found {len(clusters) + len(extra_clusters)} distinct DNS-converged clusters")
    print(f"Added {len(catalog_clusters)} catalog solutions with completed eigen diagnostics for {CASE}")
    print(f"Eigen analyses present: {sum(1 for m in new_meta if m['eigen_analysis']['available'])}")


if __name__ == "__main__":
    main()

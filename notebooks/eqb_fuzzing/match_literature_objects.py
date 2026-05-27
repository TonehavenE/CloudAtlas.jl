#!/usr/bin/env python3
"""Cheap invariant matching between CloudAtlas catalog rows and literature rows.

This is a triage tool, not a proof of branch identity. It compares rows by
Re, reported fluctuation norm, and total dissipation/input D. The output is
intended to identify targets for curation or more expensive continuation.
"""

from __future__ import annotations

import argparse
import csv
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CATALOG = ROOT / "catalog" / "catalog_manifest.csv"
DEFAULT_LITERATURE = (
    ROOT / "notebooks" / "eqb_fuzzing" / "eqb_catalog" / "literature_objects.csv"
)
DEFAULT_OUT = ROOT / "catalog" / "literature_candidate_matches.csv"
DEFAULT_DIRECT_OUT = ROOT / "catalog" / "literature_direct_review.csv"
DEFAULT_LEADS_OUT = ROOT / "catalog" / "literature_scalar_leads.csv"


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as f:
        return list(csv.DictReader(f))


def write_csv(path: Path, rows: list[dict[str, object]], fields: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def parse_float(value: str) -> float:
    value = (value or "").strip()
    if value == "":
        return math.nan
    return float(value)


def rel_gap(a: float, b: float) -> float:
    if math.isnan(a) or math.isnan(b):
        return math.inf
    scale = max(abs(a), abs(b), 1.0)
    return abs(a - b) / scale


def lit_label(row: dict[str, str]) -> str:
    root = row.get("root_label", "")
    prefix = f"{root} " if root else ""
    return f"{row['citation_key']} {prefix}{row['object_id']} Re{row['Re']}"


def geometry_evidence(cat: dict[str, str], lit: dict[str, str]) -> str:
    lit_geometry = (lit.get("geometry_label") or "").strip()
    case = cat.get("case", "")
    if lit_geometry == "GHC":
        if case.startswith("ghc_re400_alpha1p14_gamma2p5_low_shear"):
            return "same_ghc_box"
        return "cross_geometry"
    if lit_geometry:
        return f"literature_geometry_{lit_geometry}"
    return "unknown_literature_geometry"


def confidence_label(
    cat: dict[str, str],
    lit: dict[str, str],
    norm_gap: float,
    d_gap: float,
    unstable_gap: float,
) -> tuple[str, str]:
    cat_l2 = parse_float(cat.get("L2", ""))
    lit_norm = parse_float(lit.get("norm", ""))
    if lit.get("object_id") == "EQ0" or max(abs(cat_l2), abs(lit_norm)) < 1e-8:
        return "laminar", "Laminar/trivial rows are useful sanity checks but not branch evidence."

    if cat.get("literature"):
        return "curated", "Already present in literature_mappings.csv."

    geom = geometry_evidence(cat, lit)
    if geom == "cross_geometry":
        return "weak_cross_geometry", "Only scalar fingerprints match; geometry differs."
    if unstable_gap >= 3:
        return "weak_stability_mismatch", "Scalar fingerprints match but unstable dimension differs strongly."
    if norm_gap <= 1e-3 and d_gap <= 1e-3 and unstable_gap <= 1:
        return "review", "Strong scalar match at compatible geometry; needs manual curation."
    return "ambiguous", "Cheap scalar match only; needs field/branch evidence."


def score_match(
    cat: dict[str, str],
    lit: dict[str, str],
    norm_weight: float,
    d_weight: float,
    unstable_weight: float,
) -> tuple[float, float, float, float]:
    norm_gap = abs(parse_float(cat.get("L2", "")) - parse_float(lit.get("norm", "")))
    d_gap = abs(parse_float(cat.get("D_total", "")) - parse_float(lit.get("D", "")))
    cat_unstable = parse_float(cat.get("n_unstable", ""))
    lit_unstable = parse_float(lit.get("unstable_dim", ""))
    unstable_gap = (
        0.0
        if math.isnan(cat_unstable) or math.isnan(lit_unstable)
        else abs(cat_unstable - lit_unstable)
    )
    score = norm_weight * norm_gap + d_weight * d_gap + unstable_weight * unstable_gap
    return score, norm_gap, d_gap, unstable_gap


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--literature", type=Path, default=DEFAULT_LITERATURE)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--direct-out", type=Path, default=DEFAULT_DIRECT_OUT)
    parser.add_argument("--leads-out", type=Path, default=DEFAULT_LEADS_OUT)
    parser.add_argument("--max-norm-gap", type=float, default=0.01)
    parser.add_argument("--max-d-gap", type=float, default=0.03)
    parser.add_argument("--top", type=int, default=10)
    args = parser.parse_args()

    catalog = read_csv(args.catalog)
    literature = [
        row
        for row in read_csv(args.literature)
        if row.get("object_type") == "EQ" and row.get("Re", "")
    ]

    matches: list[dict[str, object]] = []
    for lit in literature:
        lit_re = parse_float(lit["Re"])
        candidates = []
        for cat in catalog:
            if parse_float(cat.get("Re", "")) != lit_re:
                continue
            score, norm_gap, d_gap, unstable_gap = score_match(
                cat, lit, norm_weight=1.0, d_weight=1.0, unstable_weight=0.002
            )
            if norm_gap <= args.max_norm_gap and d_gap <= args.max_d_gap:
                candidates.append((score, norm_gap, d_gap, unstable_gap, cat))
        for rank, (score, norm_gap, d_gap, unstable_gap, cat) in enumerate(
            sorted(candidates, key=lambda x: x[0])[: args.top], start=1
        ):
            confidence, reason = confidence_label(cat, lit, norm_gap, d_gap, unstable_gap)
            matches.append(
                {
                    "literature_label": lit_label(lit),
                    "citation_key": lit["citation_key"],
                    "literature_object_id": lit["object_id"],
                    "literature_root_label": lit.get("root_label", ""),
                    "literature_Re": lit["Re"],
                    "literature_norm": lit["norm"],
                    "literature_D": lit["D"],
                    "literature_H": lit["H"],
                    "literature_unstable_dim": lit["unstable_dim"],
                    "rank": rank,
                    "geometry_evidence": geometry_evidence(cat, lit),
                    "confidence": confidence,
                    "confidence_reason": reason,
                    "physical_id": cat["physical_id"],
                    "case": cat["case"],
                    "catalog_source": cat["catalog_source"],
                    "groups": cat["groups"],
                    "catalog_L2": cat["L2"],
                    "catalog_D_total": cat["D_total"],
                    "catalog_n_unstable": cat["n_unstable"],
                    "norm_gap": f"{norm_gap:.8g}",
                    "D_gap": f"{d_gap:.8g}",
                    "unstable_gap": f"{unstable_gap:.8g}",
                    "score": f"{score:.8g}",
                    "existing_literature": cat.get("literature", ""),
                }
            )

    fields = [
        "literature_label",
        "citation_key",
        "literature_object_id",
        "literature_root_label",
        "literature_Re",
        "literature_norm",
        "literature_D",
        "literature_H",
        "literature_unstable_dim",
        "rank",
        "geometry_evidence",
        "confidence",
        "confidence_reason",
        "physical_id",
        "case",
        "catalog_source",
        "groups",
        "catalog_L2",
        "catalog_D_total",
        "catalog_n_unstable",
        "norm_gap",
        "D_gap",
        "unstable_gap",
        "score",
        "existing_literature",
    ]

    direct_rows = [
        row
        for row in matches
        if row["geometry_evidence"] == "same_ghc_box" and row["confidence"] != "laminar"
    ]
    lead_rows = [
        row
        for row in matches
        if not (
            row["geometry_evidence"] == "same_ghc_box"
            and row["confidence"] != "laminar"
        )
    ]

    write_csv(args.out, matches, fields)
    write_csv(args.direct_out, direct_rows, fields)
    write_csv(args.leads_out, lead_rows, fields)

    print(f"wrote {len(matches)} candidate matches to {args.out}")
    print(f"wrote {len(direct_rows)} direct review rows to {args.direct_out}")
    print(f"wrote {len(lead_rows)} scalar lead rows to {args.leads_out}")


if __name__ == "__main__":
    main()

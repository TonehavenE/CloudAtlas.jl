#!/usr/bin/env python3
"""Summarize literature-object coverage by curated catalog mappings."""

from __future__ import annotations

import csv
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LITERATURE = ROOT / "notebooks" / "eqb_fuzzing" / "eqb_catalog" / "literature_objects.csv"
MAPPINGS = ROOT / "notebooks" / "eqb_fuzzing" / "eqb_catalog" / "literature_mappings.csv"
CATALOG = ROOT / "catalog" / "catalog_manifest.csv"
OUT = ROOT / "catalog" / "literature_coverage.csv"


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as f:
        return list(csv.DictReader(f))


def object_key(row: dict[str, str]) -> tuple[str, str, str]:
    return (row.get("citation_key", ""), row.get("object_type", ""), row.get("object_id", ""))


def canonical_key(row: dict[str, str]) -> tuple[str, str, str]:
    """Group obvious repeated literature appearances.

    GHC rows and Sharma rows with the same Re and EQ id are the same known object
    for direct coverage purposes.
    """

    return (row.get("Re", ""), row.get("object_type", ""), row.get("object_id", ""))


def mapping_matches_literature(mapping: dict[str, str], lit: dict[str, str]) -> bool:
    if mapping["citation_key"] != lit["citation_key"]:
        return False
    if mapping["object_type"] != lit["object_type"]:
        return False
    if mapping["object_id"] != lit["object_id"]:
        return False

    root = (lit.get("root_label") or "").strip()
    if lit["citation_key"] == "Sharma2020" and root:
        haystack = f"{mapping.get('literature_label', '')} {mapping.get('notes', '')}"
        return root in haystack
    return True


def main() -> None:
    literature = read_csv(LITERATURE)
    mappings = read_csv(MAPPINGS)
    catalog = {row["physical_id"]: row for row in read_csv(CATALOG)}

    mapped_by_canonical: dict[tuple[str, str, str], list[dict[str, str]]] = defaultdict(list)
    for mapping in mappings:
        for lit in literature:
            if mapping_matches_literature(mapping, lit):
                mapped_by_canonical[canonical_key(lit)].append(mapping)

    duplicate_counts = defaultdict(int)
    for lit in literature:
        duplicate_counts[canonical_key(lit)] += 1

    rows: list[dict[str, str]] = []
    for lit in literature:
        if lit["object_type"] != "EQ":
            continue

        ckey = canonical_key(lit)
        mapped = mapped_by_canonical.get(ckey, [])
        mapped_ids = sorted({m["physical_id"] for m in mapped})
        mapped_labels = sorted({m["literature_label"] for m in mapped})

        if lit["object_id"] == "EQ0":
            status = "laminar"
            reason = "Laminar/trivial equilibrium; not counted as nonlinear-solution coverage."
        elif mapped_ids:
            status = "mapped"
            reason = "Curated direct mapping exists."
        elif duplicate_counts[ckey] > 1 and any(
            mapped_by_canonical.get(k)
            for k in mapped_by_canonical
            if k == ckey
        ):
            status = "duplicate_literature"
            reason = "Repeated literature appearance of an already mapped object."
        else:
            status = "missing_direct"
            reason = "No curated same-parameter mapping in the current catalog."

        mapped_cases = sorted(
            {
                catalog[pid]["case"]
                for pid in mapped_ids
                if pid in catalog
            }
        )
        rows.append(
            {
                "status": status,
                "reason": reason,
                "citation_key": lit["citation_key"],
                "source_table": lit["source_table"],
                "root_label": lit["root_label"],
                "object_id": lit["object_id"],
                "Re": lit["Re"],
                "geometry_label": lit["geometry_label"],
                "norm": lit["norm"],
                "E": lit["E"],
                "D": lit["D"],
                "H": lit["H"],
                "unstable_dim": lit["unstable_dim"],
                "unstable_dim_H": lit["unstable_dim_H"],
                "mapped_physical_ids": ";".join(mapped_ids),
                "mapped_literature_labels": ";".join(mapped_labels),
                "mapped_cases": ";".join(mapped_cases),
            }
        )

    fields = [
        "status",
        "reason",
        "citation_key",
        "source_table",
        "root_label",
        "object_id",
        "Re",
        "geometry_label",
        "norm",
        "E",
        "D",
        "H",
        "unstable_dim",
        "unstable_dim_H",
        "mapped_physical_ids",
        "mapped_literature_labels",
        "mapped_cases",
    ]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)

    canonical_rows: list[dict[str, str]] = []
    for ckey in sorted({canonical_key(row) for row in literature if row["object_type"] == "EQ"}):
        members = [row for row in rows if (row["Re"], "EQ", row["object_id"]) == ckey]
        if not members:
            continue
        statuses = {row["status"] for row in members}
        if "mapped" in statuses:
            status = "mapped"
        elif statuses == {"laminar"}:
            status = "laminar"
        else:
            status = "missing_direct"
        canonical_rows.append(
            {
                "status": status,
                "Re": ckey[0],
                "object_id": ckey[2],
                "geometry_label": ";".join(sorted({row["geometry_label"] for row in members})),
                "literature_rows": ";".join(
                    f"{row['citation_key']}:{row['root_label'] or row['object_id']}"
                    for row in members
                ),
                "D_values": ";".join(row["D"] for row in members),
                "H_values": ";".join(row["H"] for row in members),
                "mapped_physical_ids": ";".join(
                    sorted(
                        {
                            pid
                            for row in members
                            for pid in row["mapped_physical_ids"].split(";")
                            if pid
                        }
                    )
                ),
                "mapped_literature_labels": ";".join(
                    sorted(
                        {
                            label
                            for row in members
                            for label in row["mapped_literature_labels"].split(";")
                            if label
                        }
                    )
                ),
            }
        )

    canonical_out = OUT.with_name("literature_coverage_canonical.csv")
    canonical_fields = [
        "status",
        "Re",
        "object_id",
        "geometry_label",
        "literature_rows",
        "D_values",
        "H_values",
        "mapped_physical_ids",
        "mapped_literature_labels",
    ]
    with canonical_out.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=canonical_fields)
        writer.writeheader()
        writer.writerows(canonical_rows)

    counts = defaultdict(int)
    for row in rows:
        counts[row["status"]] += 1
    canonical_counts = defaultdict(int)
    for row in canonical_rows:
        canonical_counts[row["status"]] += 1
    print(f"wrote {len(rows)} rows to {OUT}")
    for key in sorted(counts):
        print(f"{key}: {counts[key]}")
    print(f"wrote {len(canonical_rows)} rows to {canonical_out}")
    for key in sorted(canonical_counts):
        print(f"canonical {key}: {canonical_counts[key]}")


if __name__ == "__main__":
    main()

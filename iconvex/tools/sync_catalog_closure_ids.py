#!/usr/bin/env python3
"""Synchronize closure-audit catalog IDs from stable exact names."""

from __future__ import annotations

import argparse
import csv
import io
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "research/known_encodings.csv"
AUDIT = ROOT / "research/CATALOG_CLOSURE_AUDIT.tsv"


def generated_contents() -> str:
    with CATALOG.open(newline="") as stream:
        catalog_rows = list(csv.DictReader(stream))

    unresolved_by_name: dict[str, tuple[str, str]] = {}
    for row in catalog_rows:
        disposition = row["implementation_disposition"]
        if disposition not in {"codec_gap", "research_candidate"}:
            continue
        name = row["name"]
        if name in unresolved_by_name:
            raise RuntimeError(f"duplicate unresolved exact catalog name: {name!r}")
        unresolved_by_name[name] = (row["catalog_id"], disposition)

    with AUDIT.open(newline="") as stream:
        reader = csv.DictReader(stream, delimiter="\t")
        fields = reader.fieldnames
        rows = list(reader)

    if fields is None or fields[0] != "catalog_id" or "name" not in fields:
        raise RuntimeError("unexpected closure-audit schema")

    for row in rows:
        name = row["name"]
        if name not in unresolved_by_name:
            raise RuntimeError(f"closure name absent from catalog: {name!r}")
        catalog_id, disposition = unresolved_by_name[name]
        if row["current_disposition"] != disposition:
            raise RuntimeError(
                f"closure disposition differs for {name!r}: "
                f"{row['current_disposition']} != {disposition}"
            )
        row["catalog_id"] = catalog_id

    rows.sort(key=lambda row: int(row["catalog_id"].split("-", 1)[1]))
    output = io.StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=fields, delimiter="\t", lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    return output.getvalue()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    options = parser.parse_args()
    contents = generated_contents()

    if options.check:
        if AUDIT.read_text() != contents:
            raise SystemExit(f"{AUDIT.relative_to(ROOT)} is out of date")
        print(f"{AUDIT.relative_to(ROOT)} is current")
    else:
        AUDIT.write_text(contents)
        print(f"synchronized {len(contents.splitlines()) - 1} closure-audit IDs")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Generate the Wikipedia-versus-GNU research report from the merged catalog.

Only records carrying the direct ``wikipedia`` source tag are in scope.  The
broader ``wikipedia_historical`` inventory is a different source and is not
silently folded into this comparison.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import sys
from collections import Counter
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CATALOG = ROOT / "research/known_encodings.csv"
DEFAULT_OUTPUT_DIR = ROOT / "research"
CSV_NAME = "WIKIPEDIA_MISSING_FROM_GNU.csv"
MARKDOWN_NAME = "WIKIPEDIA_MISSING_FROM_GNU.md"

COLUMNS = [
    "catalog_id",
    "name",
    "aliases",
    "kinds",
    "confidence",
    "gnu_libiconv_1_19",
    "iconvex",
    "coverage_status",
    "implementation_disposition",
    "wikipedia_source_ids",
    "wikipedia_urls",
    "all_source_ids",
    "all_source_urls",
    "statuses",
]

DISPOSITION_LABELS = {
    "codec_gap": "Codec gaps",
    "research_candidate": "Research candidates",
    "encoding_family": "Encoding families",
    "repertoire_abstraction": "Repertoire abstraction",
    "repertoire_profile": "Repertoire profile",
    "withdrawn_unassigned_part": "Withdrawn/unassigned part",
}


def pipe_values(value: str) -> list[str]:
    return value.split(" | ") if value else []


def wikipedia_records(catalog_path: Path) -> tuple[list[dict[str, str]], bytes]:
    catalog_bytes = catalog_path.read_bytes()

    with io.StringIO(catalog_bytes.decode("utf-8"), newline="") as stream:
        source_rows = list(csv.DictReader(stream))

    rows: list[dict[str, str]] = []

    for source in source_rows:
        sources = pipe_values(source["sources"])

        if source["gnu_libiconv_1_19"] != "no" or "wikipedia" not in sources:
            continue

        wikipedia_ids = [
            value
            for value in pipe_values(source["source_ids"])
            if value.startswith("wikipedia:")
        ]
        wikipedia_urls = [
            value
            for value in pipe_values(source["source_urls"])
            if value.startswith("https://en.wikipedia.org/wiki/")
            and not value.endswith("/List_of_information_system_character_sets")
        ]

        if not wikipedia_ids or len(wikipedia_ids) != len(wikipedia_urls):
            raise ValueError(
                f"{source['catalog_id']} has unpaired direct Wikipedia identities and URLs"
            )

        iconvex = source["iconvex"]
        if iconvex not in {"yes", "no"}:
            raise ValueError(f"{source['catalog_id']} has invalid Iconvex status {iconvex!r}")

        rows.append(
            {
                "catalog_id": source["catalog_id"],
                "name": source["name"],
                "aliases": source["aliases"],
                "kinds": source["kinds"],
                "confidence": source["confidence"],
                "gnu_libiconv_1_19": source["gnu_libiconv_1_19"],
                "iconvex": iconvex,
                "coverage_status": "implemented" if iconvex == "yes" else "remaining",
                "implementation_disposition": source["implementation_disposition"],
                "wikipedia_source_ids": " | ".join(wikipedia_ids),
                "wikipedia_urls": " | ".join(wikipedia_urls),
                "all_source_ids": source["source_ids"],
                "all_source_urls": source["source_urls"],
                "statuses": source["statuses"],
            }
        )

    rows.sort(key=lambda row: row["catalog_id"])

    ids = [row["catalog_id"] for row in rows]
    if len(ids) != len(set(ids)):
        raise ValueError("Wikipedia report contains duplicate catalog IDs")

    return rows, catalog_bytes


def render_csv(rows: Iterable[dict[str, str]]) -> str:
    stream = io.StringIO(newline="")
    writer = csv.DictWriter(stream, fieldnames=COLUMNS, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    return stream.getvalue()


def markdown_cell(value: str) -> str:
    return value.replace("\\", "\\\\").replace("|", "\\|").replace("\n", " ")


def wikipedia_links(row: dict[str, str]) -> str:
    ids = pipe_values(row["wikipedia_source_ids"])
    urls = pipe_values(row["wikipedia_urls"])
    return " ".join(f"[{markdown_cell(identity)}]({url})" for identity, url in zip(ids, urls))


def evidence_links(row: dict[str, str]) -> str:
    wikipedia = set(pipe_values(row["wikipedia_urls"]))
    urls = [url for url in pipe_values(row["all_source_urls"]) if url not in wikipedia]
    return " ".join(f"[source {index}]({url})" for index, url in enumerate(urls, 1)) or "—"


def report_table(rows: Iterable[dict[str, str]]) -> list[str]:
    lines = [
        "| Catalog ID | Identity | Confidence | Iconvex | Disposition | Wikipedia source | Other specification/evidence |",
        "|---|---|:---:|:---:|---|---|---|",
    ]

    for row in rows:
        lines.append(
            f"| {row['catalog_id']} | {markdown_cell(row['name'])} | {row['confidence']} | "
            f"{row['iconvex']} | `{row['implementation_disposition']}` | "
            f"{wikipedia_links(row)} | {evidence_links(row)} |"
        )

    return lines


def render_markdown(rows: list[dict[str, str]], catalog_bytes: bytes) -> str:
    implemented = [row for row in rows if row["coverage_status"] == "implemented"]
    remaining = [row for row in rows if row["coverage_status"] == "remaining"]
    dispositions = Counter(row["implementation_disposition"] for row in remaining)
    catalog_sha256 = hashlib.sha256(catalog_bytes).hexdigest()

    lines = [
        "# Wikipedia character-set clusters missing from GNU libiconv 1.19",
        "",
        "This is a deterministic projection of `known_encodings.csv`. A cluster is included",
        "only when its merged source set contains the direct `wikipedia` source and GNU",
        "libiconv 1.19 support is `no`. The separate `wikipedia_historical` source is not",
        "implicitly treated as direct Wikipedia category membership.",
        "",
        f"Source catalog SHA-256: `{catalog_sha256}`.",
        "",
        "## Summary",
        "",
        f"- Wikipedia-sourced clusters absent from GNU libiconv 1.19: **{len(rows)}**.",
        f"- Implemented by Iconvex: **{len(implemented)}**.",
        f"- Remaining: **{len(remaining)}**.",
    ]

    for disposition in DISPOSITION_LABELS:
        lines.append(f"- {DISPOSITION_LABELS[disposition]}: **{dispositions[disposition]}**.")

    lines.extend(
        [
            "",
            "`codec_gap` is an actionable codec target. `research_candidate` requires an",
            "exact mapping/specification before implementation. Family, repertoire, profile,",
            "and withdrawn-part rows are catalogued identities but are not standalone codecs.",
            "The CSV preserves aliases, kinds, all source identities, all source URLs, and the",
            "audited disposition for every row.",
            "",
            f"## Remaining clusters ({len(remaining)})",
            "",
            *report_table(remaining),
            "",
            f"## Implemented by Iconvex ({len(implemented)})",
            "",
            *report_table(implemented),
            "",
        ]
    )

    return "\n".join(lines)


def generated_artifacts(catalog_path: Path) -> dict[str, str]:
    rows, catalog_bytes = wikipedia_records(catalog_path)
    return {
        CSV_NAME: render_csv(rows),
        MARKDOWN_NAME: render_markdown(rows, catalog_bytes),
    }


def write_artifacts(catalog_path: Path, output_dir: Path, check: bool) -> int:
    expected = generated_artifacts(catalog_path)
    stale: list[str] = []

    for name, contents in expected.items():
        path = output_dir / name

        if check:
            if not path.exists() or path.read_text(encoding="utf-8") != contents:
                stale.append(str(path))
        else:
            output_dir.mkdir(parents=True, exist_ok=True)
            if not path.exists() or path.read_text(encoding="utf-8") != contents:
                path.write_text(contents, encoding="utf-8")

    if stale:
        print("stale Wikipedia/GNU report artifact(s):", file=sys.stderr)
        for path in stale:
            print(f"  {path}", file=sys.stderr)
        print(f"regenerate with: {Path(__file__).name}", file=sys.stderr)
        return 1

    rows, _catalog_bytes = wikipedia_records(catalog_path)
    implemented = sum(row["coverage_status"] == "implemented" for row in rows)
    print(
        f"Wikipedia/GNU report: {len(rows)} clusters, {implemented} implemented, "
        f"{len(rows) - implemented} remaining"
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    return write_artifacts(args.catalog, args.output_dir, args.check)


if __name__ == "__main__":
    raise SystemExit(main())

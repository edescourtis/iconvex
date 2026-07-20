#!/usr/bin/env python3
"""Deterministically regenerate the Unicode 17 telegraph property-token tables.

The default output is a repository-local scratch directory, never the packaged
source directory. Pass --output-dir explicitly for another destination. Writing
the packaged tables additionally requires --allow-package-overwrite.
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from collections import defaultdict
from functools import lru_cache
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_FIXTURES = ROOT / "test/fixtures/unihan-17.0.0-telegraph"
DEFAULT_OUTPUT = ROOT / "tmp/generated-unihan-17.0.0-telegraph"
PACKAGED_OUTPUT = ROOT / "priv/sources/unihan-17.0.0-telegraph"

SOURCE_HASHES = {
    "Unihan_OtherMappings-17.0.0.txt":
        "4fabda168d04a5ac360809a8bfa377fe54e04fbc069ba67cacad4df03d691fa0",
    "UnicodeData-17.0.0.txt":
        "2e1efc1dcb59c575eedf5ccae60f95229f706ee6d031835247d843c11d96470c",
}
OUTPUT_HASHES = {
    "mainland_tokens.csv":
        "685b057cc0690c19718966aa02121887071398227c6b48605cf9347db70e16f0",
    "taiwan_tokens.csv":
        "15dc21eacf695ce038500e68fa40c125d0762b5e265c9683f82f17d2eac878a6",
    "taiwan_policy.csv":
        "79890c693597f1f25b4e68abe5627883c8299d7d382ed8865c42a3d361971696",
}
PROPERTIES = ("kMainlandTelegraph", "kTaiwanTelegraph")
PROPERTY_LINE = re.compile(
    r"^(U\+[0-9A-F]{4,6})\t(kMainlandTelegraph|kTaiwanTelegraph)\t"
    r"([0-9]{4}(?: [0-9]{4})*)$"
)
LOSSLESS_VPUA = {
    "0066": 0xF8B00,
    "2210": 0xF8B01,
    "7775": 0xF8B02,
    "9795": 0xF8B03,
}
EXPECTED_DUPLICATES = {
    0x5875: ["1057", "7775"],
    0x843C: ["5501", "9795"],
}
EXPECTED_NORMALIZATION_HAZARDS = {"0066", "2210"}


class GenerationError(Exception):
    """A pinned source or derived-table invariant failed."""


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_pinned(path: Path, expected: str) -> bytes:
    try:
        data = path.read_bytes()
    except OSError as error:
        raise GenerationError(f"cannot read source fixture {path}: {error}") from error
    actual = sha256_bytes(data)
    if actual != expected:
        raise GenerationError(
            f"source fixture SHA-256 mismatch for {path.name}: "
            f"expected {expected}, got {actual}"
        )
    return data


def scalar(text: str, context: str) -> int:
    value = int(text[2:], 16)
    if not (0 <= value <= 0x10FFFF) or 0xD800 <= value <= 0xDFFF:
        raise GenerationError(f"invalid Unicode scalar {text!r} in {context}")
    return value


def parse_unihan(data: bytes) -> dict[str, list[tuple[str, int]]]:
    tables: dict[str, list[tuple[str, int]]] = {name: [] for name in PROPERTIES}
    text = data.decode("utf-8", errors="strict")
    for line_number, line in enumerate(text.splitlines(), 1):
        if "\tkMainlandTelegraph\t" not in line and "\tkTaiwanTelegraph\t" not in line:
            continue
        match = PROPERTY_LINE.fullmatch(line)
        if match is None:
            raise GenerationError(
                f"unexpected telegraph property syntax at Unihan line {line_number}: {line!r}"
            )
        scalar_text, property_name, token_field = match.groups()
        codepoint = scalar(scalar_text, f"Unihan line {line_number}")
        tables[property_name].extend((token, codepoint) for token in token_field.split(" "))

    for property_name, rows in tables.items():
        rows.sort(key=lambda row: (int(row[0]), row[1]))
        tokens = [token for token, _codepoint in rows]
        if len(tokens) != len(set(tokens)):
            raise GenerationError(f"{property_name} assigns one token more than once")
    return tables


def parse_decompositions(data: bytes) -> dict[int, tuple[bool, tuple[int, ...]]]:
    mappings: dict[int, tuple[bool, tuple[int, ...]]] = {}
    for line_number, line in enumerate(data.decode("utf-8", errors="strict").splitlines(), 1):
        fields = line.split(";")
        if len(fields) != 15:
            raise GenerationError(f"UnicodeData line {line_number} does not have 15 fields")
        raw = fields[5]
        if not raw:
            continue
        parts = raw.split()
        compatibility = parts[0].startswith("<")
        if compatibility:
            parts = parts[1:]
        mappings[int(fields[0], 16)] = (
            compatibility,
            tuple(int(part, 16) for part in parts),
        )
    return mappings


def decomposer(mappings: dict[int, tuple[bool, tuple[int, ...]]]):
    @lru_cache(maxsize=None)
    def decompose(codepoint: int, compatibility: bool) -> tuple[int, ...]:
        entry = mappings.get(codepoint)
        if entry is None or (entry[0] and not compatibility):
            return (codepoint,)
        output: list[int] = []
        for child in entry[1]:
            output.extend(decompose(child, compatibility))
        return tuple(output)

    return decompose


def reverse_groups(rows: list[tuple[str, int]]) -> dict[int, list[str]]:
    groups: dict[int, list[str]] = defaultdict(list)
    for token, codepoint in rows:
        groups[codepoint].append(token)
    for tokens in groups.values():
        tokens.sort(key=int)
    return dict(groups)


def validate_frozen_facts(
    tables: dict[str, list[tuple[str, int]]],
    decompose,
) -> tuple[dict[int, list[str]], set[str]]:
    mainland = tables["kMainlandTelegraph"]
    taiwan = tables["kTaiwanTelegraph"]
    if len(mainland) != 7_078 or len({cp for _token, cp in mainland}) != 7_078:
        raise GenerationError("Mainland assignment/scalar counts drifted from 7,078")
    if len(taiwan) != 9_026 or len({cp for _token, cp in taiwan}) != 9_024:
        raise GenerationError("Taiwan assignment/scalar counts drifted from 9,026/9,024")

    duplicates = {
        codepoint: tokens
        for codepoint, tokens in reverse_groups(taiwan).items()
        if len(tokens) > 1
    }
    if duplicates != EXPECTED_DUPLICATES:
        raise GenerationError(f"Taiwan duplicate reverse groups drifted: {duplicates!r}")

    hazards: set[str] = set()
    normalized_groups: dict[tuple[int, ...], list[tuple[str, int]]] = defaultdict(list)
    for token, codepoint in taiwan:
        normalized = decompose(codepoint, False)
        if len(normalized) != 1:
            raise GenerationError(f"multi-scalar canonical decomposition at token {token}")
        normalized_groups[normalized].append((token, codepoint))
        if normalized != (codepoint,):
            hazards.add(token)
    if hazards != EXPECTED_NORMALIZATION_HAZARDS:
        raise GenerationError(f"Taiwan normalization hazards drifted: {sorted(hazards)!r}")
    for token in hazards:
        codepoint = dict(taiwan)[token]
        normalized = decompose(codepoint, False)
        if len({source for _token, source in normalized_groups[normalized]}) < 2:
            raise GenerationError(f"normalization rewrite at {token} is not an assigned collision")

    duplicate_aliases = {
        token
        for tokens in duplicates.values()
        for token in tokens[1:]
    }
    if set(LOSSLESS_VPUA) != hazards | duplicate_aliases:
        raise GenerationError("lossless VPUA policy no longer exactly covers all four hazards")
    return reverse_groups(taiwan), hazards


def mapping_bytes(rows: list[tuple[str, int]]) -> bytes:
    lines = ["decimal_token,unicode_scalar"]
    lines.extend(f"{token},U+{codepoint:04X}" for token, codepoint in rows)
    return ("\n".join(lines) + "\n").encode("ascii")


def policy_bytes(
    taiwan: list[tuple[str, int]],
    reverse: dict[int, list[str]],
    normalization_hazards: set[str],
) -> bytes:
    lines = [
        "decimal_token,source_unicode_scalar,readable_reverse_role,"
        "lossless_output_scalar,lossless_reason"
    ]
    for token, codepoint in taiwan:
        role = "canonical-minimum" if token == reverse[codepoint][0] else "decode-alias"
        output = LOSSLESS_VPUA.get(token, codepoint)
        if token in normalization_hazards:
            reason = "canonical-normalization-collision"
        elif role == "decode-alias":
            reason = "duplicate-readable-reverse"
        else:
            reason = "source-scalar"
        lines.append(
            f"{token},U+{codepoint:04X},{role},U+{output:04X},{reason}"
        )
    return ("\n".join(lines) + "\n").encode("ascii")


def generated_files(fixtures_dir: Path) -> dict[str, bytes]:
    sources = {
        name: read_pinned(fixtures_dir / name, expected)
        for name, expected in SOURCE_HASHES.items()
    }
    tables = parse_unihan(sources["Unihan_OtherMappings-17.0.0.txt"])
    decompose = decomposer(parse_decompositions(sources["UnicodeData-17.0.0.txt"]))
    reverse, hazards = validate_frozen_facts(tables, decompose)
    result = {
        "mainland_tokens.csv": mapping_bytes(tables["kMainlandTelegraph"]),
        "taiwan_tokens.csv": mapping_bytes(tables["kTaiwanTelegraph"]),
        "taiwan_policy.csv": policy_bytes(tables["kTaiwanTelegraph"], reverse, hazards),
    }
    for name, data in result.items():
        actual = sha256_bytes(data)
        if actual != OUTPUT_HASHES[name]:
            raise GenerationError(
                f"generated {name} SHA-256 mismatch: expected {OUTPUT_HASHES[name]}, got {actual}"
            )
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--fixtures-dir",
        type=Path,
        default=DEFAULT_FIXTURES,
        help="directory containing the two exact Unicode 17 source fixtures",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"output directory (default: {DEFAULT_OUTPUT})",
    )
    parser.add_argument(
        "--allow-package-overwrite",
        action="store_true",
        help="required when --output-dir is the packaged priv/sources directory",
    )
    args = parser.parse_args()
    fixtures_dir = args.fixtures_dir.expanduser().resolve()
    output_dir = args.output_dir.expanduser().resolve()
    if output_dir == PACKAGED_OUTPUT.resolve() and not args.allow_package_overwrite:
        raise GenerationError(
            "refusing to overwrite packaged tables without --allow-package-overwrite"
        )

    files = generated_files(fixtures_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    for name, data in files.items():
        (output_dir / name).write_bytes(data)
        print(f"{sha256_bytes(data)}  {name}")
    print(f"generated {len(files)} files in {output_dir}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (GenerationError, UnicodeError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)

#!/usr/bin/env python3
"""Independently verify the Unicode 17 telegraph property-token tables.

This verifier intentionally does not import the generator. It reparses the two
authoritative Unicode fixtures, checks every decimal token, derives reverse and
normalization policy independently, and exact-compares the packaged CSV files.
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
DEFAULT_PACKAGE = ROOT / "priv/sources/unihan-17.0.0-telegraph"

SOURCE_HASHES = {
    "Unihan_OtherMappings-17.0.0.txt":
        "4fabda168d04a5ac360809a8bfa377fe54e04fbc069ba67cacad4df03d691fa0",
    "UnicodeData-17.0.0.txt":
        "2e1efc1dcb59c575eedf5ccae60f95229f706ee6d031835247d843c11d96470c",
}
FILTERED_SOURCE_HASHES = {
    "kMainlandTelegraph":
        "51bf7c96b23c71abf276727f38c32b3c62918cacd05b98ca072dbf8b4ee0ac23",
    "kTaiwanTelegraph":
        "9f18a54524a55c6125080211983a9004b96e659ba0331b825c72b1475b4dc180",
}
TABLE_HASHES = {
    "mainland_tokens.csv":
        "685b057cc0690c19718966aa02121887071398227c6b48605cf9347db70e16f0",
    "taiwan_tokens.csv":
        "15dc21eacf695ce038500e68fa40c125d0762b5e265c9683f82f17d2eac878a6",
    "taiwan_policy.csv":
        "79890c693597f1f25b4e68abe5627883c8299d7d382ed8865c42a3d361971696",
}
PROPERTY_NAMES = ("kMainlandTelegraph", "kTaiwanTelegraph")
PROPERTY_TO_FILE = {
    "kMainlandTelegraph": "mainland_tokens.csv",
    "kTaiwanTelegraph": "taiwan_tokens.csv",
}
VPUA_REWRITES = {
    "0066": 0xF8B00,
    "2210": 0xF8B01,
    "7775": 0xF8B02,
    "9795": 0xF8B03,
}
EXPECTED_DUPLICATES = {
    0x5875: ["1057", "7775"],
    0x843C: ["5501", "9795"],
}
EXPECTED_COLLISIONS = {
    0x51B5: [("0066", 0x2F81B), ("0400", 0x51B5)],
    0x62FC: [("2178", 0x62FC), ("2210", 0x2F8BA)],
}
MAPPING_ROW = re.compile(r"^([0-9]{4}),(U\+[0-9A-F]{4,6})$")
POLICY_ROW = re.compile(
    r"^([0-9]{4}),(U\+[0-9A-F]{4,6}),"
    r"(canonical-minimum|decode-alias),(U\+[0-9A-F]{4,6}),"
    r"(source-scalar|canonical-normalization-collision|duplicate-readable-reverse)$"
)


class VerificationError(Exception):
    """The authoritative fixtures or a derived contract do not match."""


def check(condition: bool, message: str) -> None:
    if not condition:
        raise VerificationError(message)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def pinned_bytes(path: Path, expected_hash: str, kind: str) -> bytes:
    try:
        data = path.read_bytes()
    except OSError as error:
        raise VerificationError(f"cannot read {kind} {path}: {error}") from error
    actual = sha256(data)
    check(
        actual == expected_hash,
        f"{kind} SHA-256 mismatch for {path.name}: expected {expected_hash}, got {actual}",
    )
    return data


def parse_scalar(text: str, context: str) -> int:
    check(re.fullmatch(r"U\+[0-9A-F]{4,6}", text) is not None, f"bad scalar {text!r} in {context}")
    value = int(text[2:], 16)
    check(
        0 <= value <= 0x10FFFF and not 0xD800 <= value <= 0xDFFF,
        f"non-scalar {text!r} in {context}",
    )
    return value


def authoritative_tables(source: bytes) -> dict[str, dict[str, int]]:
    tables: dict[str, dict[str, int]] = {name: {} for name in PROPERTY_NAMES}
    text = source.decode("utf-8", errors="strict")
    for line_number, line in enumerate(text.splitlines(), 1):
        if not any(f"\t{name}\t" in line for name in PROPERTY_NAMES):
            continue
        fields = line.split("\t")
        check(len(fields) == 3, f"target Unihan line {line_number} does not have three fields")
        scalar_text, property_name, token_field = fields
        check(property_name in tables, f"unexpected property at Unihan line {line_number}")
        codepoint = parse_scalar(scalar_text, f"Unihan line {line_number}")
        check(
            re.fullmatch(r"[0-9]{4}(?: [0-9]{4})*", token_field) is not None,
            f"bad token field at Unihan line {line_number}: {token_field!r}",
        )
        for token in token_field.split(" "):
            check(token not in tables[property_name], f"duplicate source token {token} in {property_name}")
            tables[property_name][token] = codepoint

    check(len(tables["kMainlandTelegraph"]) == 7_078, "authoritative Mainland count is not 7,078")
    check(len(tables["kTaiwanTelegraph"]) == 9_026, "authoritative Taiwan count is not 9,026")
    return tables


def verify_filtered_source_hashes(source: bytes) -> None:
    for property_name, expected in FILTERED_SOURCE_HASHES.items():
        marker = b"\t" + property_name.encode("ascii") + b"\t"
        rows = [line for line in source.splitlines(keepends=True) if marker in line]
        check(rows and all(line.endswith(b"\n") for line in rows), f"bad raw rows for {property_name}")
        actual = sha256(b"".join(rows))
        check(actual == expected, f"filtered source row hash mismatch for {property_name}")


def strict_lines(data: bytes, file_name: str) -> list[str]:
    check(b"\r" not in data, f"{file_name} must use LF line endings")
    check(data.endswith(b"\n") and not data.endswith(b"\n\n"), f"{file_name} must end with one LF")
    try:
        lines = data[:-1].decode("ascii", errors="strict").split("\n")
    except UnicodeDecodeError as error:
        raise VerificationError(f"{file_name} is not ASCII: {error}") from error
    check(all(lines), f"{file_name} contains a blank row")
    return lines


def packaged_mapping(data: bytes, file_name: str) -> dict[str, int]:
    lines = strict_lines(data, file_name)
    check(lines[0] == "decimal_token,unicode_scalar", f"bad mapping header in {file_name}")
    result: dict[str, int] = {}
    previous = -1
    for line_number, line in enumerate(lines[1:], 2):
        match = MAPPING_ROW.fullmatch(line)
        check(match is not None, f"bad mapping row at {file_name}:{line_number}")
        token, scalar_text = match.groups()
        value = int(token)
        check(value > previous, f"mapping tokens are not strictly increasing at {file_name}:{line_number}")
        previous = value
        result[token] = parse_scalar(scalar_text, f"{file_name}:{line_number}")
    return result


def verify_all_tokens(
    property_name: str,
    authoritative: dict[str, int],
    packaged: dict[str, int],
) -> None:
    for value in range(10_000):
        token = f"{value:04d}"
        expected = authoritative.get(token)
        actual = packaged.get(token)
        check(
            actual == expected,
            f"{property_name} differs from Unicode 17 at token {token}: "
            f"expected {expected!r}, got {actual!r}",
        )


def reverse_groups(table: dict[str, int]) -> dict[int, list[str]]:
    groups: dict[int, list[str]] = defaultdict(list)
    for token, codepoint in table.items():
        groups[codepoint].append(token)
    for tokens in groups.values():
        tokens.sort(key=int)
    return dict(groups)


def unicode_decompositions(data: bytes) -> dict[int, tuple[bool, tuple[int, ...]]]:
    mappings: dict[int, tuple[bool, tuple[int, ...]]] = {}
    for line_number, line in enumerate(data.decode("utf-8", errors="strict").splitlines(), 1):
        fields = line.split(";")
        check(len(fields) == 15, f"UnicodeData line {line_number} does not have 15 fields")
        raw = fields[5]
        if not raw:
            continue
        pieces = raw.split()
        compatibility = pieces[0].startswith("<")
        if compatibility:
            pieces = pieces[1:]
        mappings[int(fields[0], 16)] = (
            compatibility,
            tuple(int(piece, 16) for piece in pieces),
        )
    return mappings


def make_decomposer(mappings: dict[int, tuple[bool, tuple[int, ...]]]):
    @lru_cache(maxsize=None)
    def decompose(codepoint: int, compatibility: bool) -> tuple[int, ...]:
        mapping = mappings.get(codepoint)
        if mapping is None or (mapping[0] and not compatibility):
            return (codepoint,)
        flattened: list[int] = []
        for child in mapping[1]:
            flattened.extend(decompose(child, compatibility))
        return tuple(flattened)

    return decompose


def normalization_collisions(
    taiwan: dict[str, int],
    decompose,
    compatibility: bool,
    form: str,
) -> tuple[dict[int, list[tuple[str, int]]], set[str]]:
    normalized: dict[int, list[tuple[str, int]]] = defaultdict(list)
    changed: set[str] = set()
    for token, codepoint in taiwan.items():
        result = decompose(codepoint, compatibility)
        # Every decomposition in this repertoire resolves to one scalar.
        # Canonical composition only combines multi-scalar sequences, so the
        # NFC/NFKC result is necessarily identical to the NFD/NFKD result here.
        check(
            len(result) == 1,
            f"{form} requires unsupported multi-scalar recomposition at token {token}",
        )
        normalized[result[0]].append((token, codepoint))
        if result != (codepoint,):
            changed.add(token)

    collisions = {
        codepoint: sorted(entries, key=lambda entry: int(entry[0]))
        for codepoint, entries in normalized.items()
        if len({source for _token, source in entries}) > 1
    }
    check(collisions == EXPECTED_COLLISIONS, f"{form} collision groups drifted: {collisions!r}")
    check(changed == {"0066", "2210"}, f"{form} changed-token set drifted: {sorted(changed)!r}")
    return collisions, changed


def packaged_policy(data: bytes) -> dict[str, dict[str, object]]:
    lines = strict_lines(data, "taiwan_policy.csv")
    check(
        lines[0] ==
        "decimal_token,source_unicode_scalar,readable_reverse_role,"
        "lossless_output_scalar,lossless_reason",
        "bad Taiwan policy header",
    )
    rows: dict[str, dict[str, object]] = {}
    previous = -1
    for line_number, line in enumerate(lines[1:], 2):
        match = POLICY_ROW.fullmatch(line)
        check(match is not None, f"bad policy row at taiwan_policy.csv:{line_number}")
        token, source, role, output, reason = match.groups()
        value = int(token)
        check(value > previous, f"policy tokens are not strictly increasing at line {line_number}")
        previous = value
        rows[token] = {
            "source": parse_scalar(source, f"taiwan_policy.csv:{line_number}"),
            "role": role,
            "output": parse_scalar(output, f"taiwan_policy.csv:{line_number}"),
            "reason": reason,
        }
    return rows


def verify_reverse_and_policy(
    mainland: dict[str, int],
    taiwan: dict[str, int],
    policy: dict[str, dict[str, object]],
    decompose,
) -> None:
    check(len(set(mainland.values())) == 7_078, "Mainland reverse is not unique")
    taiwan_reverse = reverse_groups(taiwan)
    duplicates = {
        codepoint: tokens
        for codepoint, tokens in taiwan_reverse.items()
        if len(tokens) > 1
    }
    check(len(taiwan_reverse) == 9_024, "Taiwan reverse scalar count is not 9,024")
    check(duplicates == EXPECTED_DUPLICATES, f"Taiwan duplicate groups drifted: {duplicates!r}")

    changed_by_form = {}
    for form, compatibility in (
        ("NFD", False),
        ("NFC", False),
        ("NFKD", True),
        ("NFKC", True),
    ):
        _collisions, changed_by_form[form] = normalization_collisions(
            taiwan, decompose, compatibility, form
        )
    check(len(policy) == 9_026, "Taiwan policy row count is not 9,026")

    duplicate_aliases = {
        token
        for tokens in duplicates.values()
        for token in tokens[1:]
    }
    expected_rewrites = changed_by_form["NFD"] | duplicate_aliases
    check(expected_rewrites == set(VPUA_REWRITES), "VPUA rewrite domain is not the four exact hazards")
    outputs: list[int] = []
    for value in range(10_000):
        token = f"{value:04d}"
        row = policy.get(token)
        if token not in taiwan:
            check(row is None, f"policy unexpectedly assigns absent token {token}")
            continue
        check(row is not None, f"policy omits assigned token {token}")
        source = int(row["source"])
        check(taiwan[token] == source, f"policy source mismatch at token {token}")
        expected_role = (
            "canonical-minimum" if token == min(taiwan_reverse[source], key=int) else "decode-alias"
        )
        check(row["role"] == expected_role, f"readable minimum-token role mismatch at {token}")
        expected_output = VPUA_REWRITES.get(token, source)
        check(row["output"] == expected_output, f"lossless output mismatch at token {token}")
        if token in changed_by_form["NFD"]:
            expected_reason = "canonical-normalization-collision"
        elif token in duplicate_aliases:
            expected_reason = "duplicate-readable-reverse"
        else:
            expected_reason = "source-scalar"
        check(row["reason"] == expected_reason, f"lossless reason mismatch at token {token}")
        outputs.append(expected_output)

    check(len(outputs) == len(set(outputs)) == 9_026, "lossless policy is not bijective")
    for codepoint in outputs:
        for form, compatibility in (
            ("NFD", False),
            ("NFC", False),
            ("NFKD", True),
            ("NFKC", True),
        ):
            check(
                decompose(codepoint, compatibility) == (codepoint,),
                f"lossless output U+{codepoint:04X} is not stable under {form}",
            )


def verify(fixtures_dir: Path, package_dir: Path) -> None:
    fixtures = {
        name: pinned_bytes(fixtures_dir / name, expected, "source fixture")
        for name, expected in SOURCE_HASHES.items()
    }
    unihan_source = fixtures["Unihan_OtherMappings-17.0.0.txt"]
    verify_filtered_source_hashes(unihan_source)
    authoritative = authoritative_tables(unihan_source)

    packaged_data = {
        name: pinned_bytes(package_dir / name, expected, "packaged table")
        for name, expected in TABLE_HASHES.items()
    }
    packaged = {
        property_name: packaged_mapping(packaged_data[file_name], file_name)
        for property_name, file_name in PROPERTY_TO_FILE.items()
    }
    for property_name in PROPERTY_NAMES:
        verify_all_tokens(property_name, authoritative[property_name], packaged[property_name])

    decompose = make_decomposer(
        unicode_decompositions(fixtures["UnicodeData-17.0.0.txt"])
    )
    verify_reverse_and_policy(
        packaged["kMainlandTelegraph"],
        packaged["kTaiwanTelegraph"],
        packaged_policy(packaged_data["taiwan_policy.csv"]),
        decompose,
    )

    mainland = packaged["kMainlandTelegraph"]
    taiwan = packaged["kTaiwanTelegraph"]
    shared = set(mainland) & set(taiwan)
    check(len(shared) == 6_770, "regional shared-token count is not 6,770")
    check(sum(mainland[token] == taiwan[token] for token in shared) == 4_154, "regional same count drifted")
    check(sum(mainland[token] != taiwan[token] for token in shared) == 2_616, "regional difference count drifted")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--fixtures-dir",
        type=Path,
        default=DEFAULT_FIXTURES,
        help="directory containing the exact Unicode 17 source fixtures",
    )
    parser.add_argument(
        "--package-dir",
        type=Path,
        default=DEFAULT_PACKAGE,
        help="directory containing mainland_tokens.csv, taiwan_tokens.csv, and taiwan_policy.csv",
    )
    args = parser.parse_args()
    verify(args.fixtures_dir.expanduser().resolve(), args.package_dir.expanduser().resolve())
    print("PASS: Unicode 17 telegraph fixtures and all 30,000 token outcomes are source-exact")
    print("PASS: Mainland 7,078/7,078; Taiwan readable 9,026/9,024; lossless 9,026/9,026")
    print("PASS: duplicate minimum reverses and all four NFC/NFD/NFKC/NFKD policies are exact")
    for name in SOURCE_HASHES:
        print(f"{SOURCE_HASHES[name]}  {name}")
    for name in TABLE_HASHES:
        print(f"{TABLE_HASHES[name]}  {name}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (VerificationError, UnicodeError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)

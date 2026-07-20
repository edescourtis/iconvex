# Changelog

## Unreleased

- Regenerated the exhaustive algorithmic-codec evidence after the final
  recovery changes. All 1,112,064 Unicode scalar values pass for 10/10
  algorithmic codecs with zero mismatches, and the checked report is bound to
  the exact shipped runtime sources and runner by SHA-256. Regenerated the
  exact 1,841-codec inventory and the 2,093-codec workspace aggregate against
  the same final source and 198/198 GNU differential evidence.
- Preserved codec-owned state during invalid-byte recovery for UTF-8-SIG and
  all three `ICONVEX-` Unicode signature profiles. Callback recovery no longer
  treats a suffix as a new message, so embedded U+FEFF values remain data and
  the initial UTF-16 signature continues to select the suffix endian. IMAP
  UTF-7 and SCSU now consume strict multi-byte error sequences atomically.
  One-shot and every-split streaming discard, replacement, and byte
  substitution are pinned for all six codecs.
- Fixed Unicode substitution for BOCU-1, SCSU, WTF-8, CESU-8, UTF-8-MAC,
  UTF-EBCDIC, Java modified UTF-8, IMAP UTF-7, UTF-8-SIG, UTF-1, and all six
  ICU Unicode variants. Replacements now pass through one complete target
  encode, preserving compression state and emitting target signatures once.
- Made generated glibc-charmap, ICU archive, and ICU multibyte wrappers recover
  terminal incomplete table units atomically. Callback replacement now emits
  one replacement/event for the same unit native discard removes, without
  leaking or reinterpreting a trailing source byte; all 41 observed wrappers
  are pinned by an executable regression matrix.
- Fixed BOCU-1 invalid-byte callback and byte-substitution recovery to consume
  the complete malformed lead/trail sequence, matching native discard reset
  semantics instead of leaking the rejected trail as U+0000.
- Replaced three undisclosed vendor-attributed BOM runtimes with neutral,
  newly authored `ICONVEX-` signature profiles composed from the existing
  LGPL Core UTF engines. Removed the old vendor spellings, module/file names,
  codec IDs, and source URL; added packaged specification/provenance metadata
  that distinguishes the custom framing policy from standard Unicode schemes.
- Hardened the Hex licensing boundary: the unlicensed raw VietUnicode VNI HTML
  snapshots remain repository-only validation evidence while the package ships
  only the normalized mapping and provenance metadata. Added complete verbatim
  LPPL 1.0 and LPPL 1.3c terms for the packaged CTAN TeX'n'ANSI and cmap
  artifacts, and declared both upstream `-or-later` license grants.
- Quarantined all seven GPL-derived OpenJDK source-informed codecs from the
  LGPL runtime and Hex artifact: `x-eucJP-Open`, `x-MS950-HKSCS-XP`,
  `x-windows-50220`,
  `x-windows-50221`, `x-windows-iso2022jp`, `x-ISO-2022-CN-GB`, and
  `x-ISO-2022-CN-CNS`. Their modules, importers, generated tables, public
  registrations, and packaged support matrices were removed. Exact upstream
  snapshots remain repository-only provenance. Specs now registers 1,841
  codecs and the four-package registry has 2,093 unique canonical names.
- Added the exact source-qualified
  `CTAN-LY1-TEXNANSI-1.1-AGL-4036A9CA`,
  `ADOBE-POSTSCRIPT-3-ISOLATIN1-AGL-4036A9CA`,
  `TAMILVU-TACE16-APPENDIX-D-2010-16BE`,
  `TAMILVU-TACE16-APPENDIX-D-2010-16LE`,
  `WANG-1983-WISCII-PDF-F4043449-WIKIPEDIA-REV1352856854`,
  `WIKIPEDIA-REV1354794598-PARATYPE-WINDOWS-POLYTONIC-GREEK`, and
  `WIKIPEDIA-REV1340817319-EKI-SAMI-WIN-CP1270` codecs, with source assets,
  exhaustive scalar/byte/word/stream tests, and independent performance gates.
- Declare the runtime `:crypto` application used by shipped source-integrity
  validators, so clean production releases include OTP Crypto and can execute
  provenance checks without relying on an ambient development application.
- Aligned WTF-8 source conversion with Core's GNU target fallback. Isolated
  surrogate units still round-trip byte-for-byte through WTF-8, while UTF-8
  now emits U+FFFD by default, discards under `//IGNORE`, and exposes the raw
  surrogate to Unicode substitution, matching GNU's explicit UCS-4 behavior.

### Breaking compatibility: GNU spellings and RFC 1345 identities

The complete four-package registry now resolves all 758/758 spellings parsed
from GNU libiconv 1.19 to the corresponding GNU codec semantics. Twenty-five
names previously resolved to different RFC 1345 tables because a Specs
canonical claim outranked an Extras alias:

`IBM037`, `IBM1026`, `IBM273`, `IBM277`, `IBM278`, `IBM280`, `IBM284`,
`IBM285`, `IBM297`, `IBM424`, `IBM437`, `IBM500`, `IBM852`, `IBM855`,
`IBM857`, `IBM860`, `IBM861`, `IBM863`, `IBM864`, `IBM865`, `IBM869`,
`IBM870`, `IBM871`, `IBM880`, and `IBM905`.

Those unqualified names now retain GNU semantics. The displaced RFC tables and
all of their RFC aliases remain available through explicit source-qualified
registry names. For example, use `RFC1345:IBM037` instead of `IBM037`, and
`RFC1345:cp037` instead of `cp037`, when the RFC 1345 mapping is intended.
This is a breaking registry-name migration for callers that relied on the old
unqualified Specs identities.

The direct source API is unchanged: `Iconvex.Specs.RFC1345.decode/2` and
`Iconvex.Specs.RFC1345.encode/2` still accept the original RFC names and
aliases. After the OpenJDK ISO-2022 quarantine, the Specs codec count is
1,841 and the full-stack canonical count is 2,093. The full-stack verifier
exhaustively compares all 256 input
bytes for each of the 25 reclaimed GNU aliases and verifies that every
qualified RFC identity and alias remains registered.

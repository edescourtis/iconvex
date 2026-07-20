# Iconvex Unicode signature profiles

Iconvex ships three explicitly project-defined framing profiles:

| Encoding | Nonempty output prefix | Input rule |
|---|---|---|
| `ICONVEX-UTF-16-SIGNATURE-LE-DEFAULT` | `FF FE` | consume either UTF-16 signature; otherwise little endian |
| `ICONVEX-UTF-32BE-SIGNATURE` | `00 00 FE FF` | consume only that signature; otherwise big endian |
| `ICONVEX-UTF-32LE-SIGNATURE` | `FF FE 00 00` | consume only that signature; otherwise little endian |

They use Unicode Standard 16.0.0 scalar, UTF-16, and UTF-32 serialization
rules, but each is an Iconvex-defined signature policy and is not a Unicode-standard encoding scheme. In particular, Unicode's standard
fixed-endian UTF-16BE/LE and UTF-32BE/LE schemes treat an initial U+FEFF as
content rather than consuming it as a BOM. The `ICONVEX-` prefix prevents the
custom behavior from being mistaken for those standard schemes or for a
vendor codec.

The implementation composes the existing `Iconvex.UnicodeCodec` UTF engines
with the framing rules above. That wrapper is original library code under
`LGPL-2.1-or-later`; it imports no vendor source or mapping table. Normative
URLs, the exact behavior boundary, and the factual release disposition are in
`priv/sources/iconvex-unicode-signature-profiles/SOURCE_METADATA.md`. This is a
provenance statement, not legal advice.

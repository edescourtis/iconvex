# Kermit versioned single-byte source metadata

These four runtime profiles preserve names found in C-Kermit while choosing an
independently versioned mapping whenever the Kermit table is ambiguous or
defective. The implementation embeds only scalar mapping data and is native
Elixir; the files below remain reproducible test oracles.

## Greek ISO / ELOT 928

- Artifact: `../icu-data-archive/iso-8859_7-1987.ucm`
- Title: *ISO 8859-7:1987 to Unicode*, table version 1.0, 1999-07-27
- SHA-256: `dbbc16acd5773a6635ce2acb9c6901db4c1749e0d5ab107512fc93e8d92ff413`
- Historical identity stated by the source: ISO-IR-126, ELOT 928, and ECMA-118
- Cross-check: Kermit `u_8859_7`, which is byte-exact with this UCM

This is deliberately distinct from modern ISO-8859-7 and from the four-cell
different RFC 1345 table named `ISO_8859-7:1987`.

## Hebrew ISO

- Primary table: Kermit `u_8859_8` in
  `../dec-terminal-character-sets/kermit/ckcuni.c`
- Kermit revision: `8e977425d2f7f618d14aa466d516e9b79787ffc6`
- SHA-256: `af93d5a1c779aa73fa3221ab5ec0125de20267110cf23395971ce35cc88527ca`
- Independent cross-check: `../rfc1345.txt`, charset `ISO_8859-8:1988`

The Kermit and RFC tables are byte-exact. This historical profile retains
U+203E at byte AF and leaves FD/FE undefined; modern ISO-8859-8 instead uses
U+00AF, U+200E, and U+200F at those positions.

## Latin-6 / current ISO-8859-10

- Artifact: `ISO-8859-10.TXT`
- Source distribution: GNU libiconv 1.19 test data
- Upstream distribution: <https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.19.tar.gz>
- SHA-256: `03605555e750ac5a2a34c9d9943e3fb823e1f8c46bc0316ff556dce0dbbdfe27`
- Cross-check: GNU libiconv 1.19 `ISO-8859-10`

The current standard table differs from Kermit's `u_8859_10` at 16 positions.
Kermit's table also differs from RFC 1345's earlier `latin6` table at five
positions. `LATIN6-ISO` intentionally follows the current GNU mapping.

## Macintosh Latin

- Artifact: `../icu-data-archive/windows-10079-2000.ucm`
- Description in the source: Icelandic (Mac), `x-mac-icelandic`
- SHA-256: `2c57ea0726702163983481661b8f8ffe532e9f1060c57f4cdb9f196294d0ef04`
- Cross-check: Kermit `u_maclatin`, byte-exact across all 256 octets

The table includes Apple's U+F8FF private-use logo at byte F0, matching Kermit
and the archived Windows-10079 mapping rather than converters that reject that
position.

## Licensing

GNU libiconv's LGPL-2.1-or-later terms are carried in this package's `LICENSE`.
The ICU/Unicode mapping artifacts retain their embedded notices. Kermit's
BSD-style license is pinned at
`../dec-terminal-character-sets/kermit/COPYING`; it applies to the audit source,
not to the native Elixir implementation.

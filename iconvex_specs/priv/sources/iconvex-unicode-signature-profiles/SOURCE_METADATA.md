# Iconvex Unicode signature profiles — source and disposition

## Normative facts

The scalar encoding and byte-serialization rules come from the Unicode Standard 16.0.0:

- Chapter 3, section 3.9 defines Unicode scalar values and the UTF-16 and
  UTF-32 encoding forms.
- Chapter 3, section 3.10 defines UTF-16BE, UTF-16LE, UTF-32BE, and UTF-32LE
  byte serialization and BOM handling:
  <https://www.unicode.org/versions/Unicode16.0.0/core-spec/chapter-3/>.
- Chapter 23, section 23.8.1 describes U+FEFF as a byte order mark/signature:
  <https://www.unicode.org/versions/Unicode16.0.0/core-spec/chapter-23/>.

No Unicode text, table, or executable source is copied into the runtime. The
links above identify the public specification facts. The repository's exact
Unicode License V3 text is shipped as `LICENSE.UNICODE`.

## Project policy

Each runtime is an Iconvex-defined composition of an existing LGPL
Iconvex Core UTF codec and a small signature policy. It is deliberately named
with an `ICONVEX-` prefix because it is not a Unicode-standard encoding scheme:

- `ICONVEX-UTF-16-SIGNATURE-LE-DEFAULT` writes a little-endian U+FEFF before
  nonempty output, consumes either UTF-16 signature, and defaults unsigned
  input to little endian.
- `ICONVEX-UTF-32BE-SIGNATURE` writes and consumes a matching big-endian
  U+FEFF signature and otherwise uses fixed big endian.
- `ICONVEX-UTF-32LE-SIGNATURE` writes and consumes a matching little-endian
  U+FEFF signature and otherwise uses fixed little endian.

The standard fixed-endian UTF-16BE/LE and UTF-32BE/LE schemes do not consume an
initial U+FEFF as a BOM. These project profiles intentionally do, so they are
not presented under standard or vendor runtime identities.

## Runtime ownership and release disposition

`lib/iconvex/specs/iconvex_unicode_signature_profiles.ex` was newly authored
for Iconvex and is distributed under `LGPL-2.1-or-later`, like the rest of the
original library code. It delegates Unicode scalar validation and UTF byte
serialization to the existing `Iconvex.UnicodeCodec` dependency, also
distributed under `LGPL-2.1-or-later`. It contains no imported mapping table,
vendor source translation, generated vendor asset, or vendor implementation
source.

This record describes repository provenance and packaging; it is not legal
advice.

# Kamenicky / KEYBCS2 normalized source metadata

This directory contains an independently normalized factual mapping, not a
copy of any upstream program or mapping file. The CSV and the Iconvex
implementation are distributed under `LGPL-2.1-or-later`.

Retrieved and reviewed: 2026-07-17.

## Original KEYBCS2 profile

The primary historical description is Lukas Petrlik's public-domain *The Czech
and Slovak Character Encoding Mess Explained*, version 1.10 (1996-06-19):

- URL: https://ftp.fi.muni.cz/pub/localization/charsets/cs-encodings-faq
- SHA-256: `ac570cbd8f97bd22b65a19fe456f263508946417e46a83de232c583b62511a49`
- license: Public Domain, stated in the source

It says that Kamenicky, alias `KEYBCS2`, is defined by the behavior of the
public-domain utility written by the Kamenicky brothers. Its complete RFC 1345
mnemonic table has C0, ASCII, and DEL text/control identities and maps byte
`AD` to the section sign U+00A7 (`SE`). It also explains that `cp895` was an
unofficial vendor number, not an IBM or Microsoft assignment.

Three independently maintained or executable tables exactly corroborate all
256 original-profile mappings:

- Free Pascal `rtl/ucmaps/cp895.txt`, pinned to commit
  `fd6d7d680d3ec43c61c19c2c1a841b3fa90bca03` (2015-02-07):
  https://gitlab.com/freepascal.org/fpc/source/-/raw/fd6d7d680d3ec43c61c19c2c1a841b3fa90bca03/rtl/ucmaps/cp895.txt
  SHA-256: `adfa9b04937649657bc462c5a63a95eba53c0a895396194d3d03236fcdb8573a`.
  The file header credits Tomas Hajny and says it is based on a public-domain
  description. The containing FPC RTL uses modified LGPL 2.1; pinned
  `rtl/COPYING.txt` SHA-256:
  `d17b69e76f3c0163448c71ac7bb65eb46a25dd533641942c6ffeac35d6074dae`.
- The 2004 DOSEMU extra-charset implementation:
  https://linux.fjfi.cvut.cz/~zub/cp895/cp895.c
  SHA-256: `faa315c81e90f45d65ac0e4b31abe17d369e6683a437d4781b67ef3321dc7d21`.
  It names `cp895`, `keybcs2`, and `kamenicky` and maps `AD` to U+00A7. It is
  not vendored.
- The corresponding Linux-console translation table:
  https://linux.fjfi.cvut.cz/~zub/cp895/kam_to_uni.trans
  SHA-256: `0b7e4f98862e97cc7c5b80fbfbcac21073579429edcf9a2c3994a29b573aa37a`.
  It is not vendored.

The normalized original profile therefore has 256 defined bytes and 256
unique Unicode scalar outputs. Encoding is the exact inverse; no undefined or
duplicate-output policy is needed.

## MySQL KEYBCS2 variant

Current MySQL deliberately supplies a text charset named `keybcs2`, but its
Unicode table preserves CP437's inverted exclamation mark U+00A1 at byte `AD`
instead of original KEYBCS2's section sign U+00A7. All other 255 bytes agree.
Iconvex exposes this source-qualified variant as `MYSQL-KEYBCS2` rather than
silently merging it with the historical profile.

- Oracle MySQL `share/charsets/keybcs2.xml`, commit
  `d229bb760c49b65e19ec28342236961ad961d7fe` (2026-07-14):
  https://raw.githubusercontent.com/mysql/mysql-server/d229bb760c49b65e19ec28342236961ad961d7fe/share/charsets/keybcs2.xml
- SHA-256: `86852fa5aede60cdaaf7ce46281a60f707c8bc69067f26202127905e6b2aabe9`
- license: GPL-2.0 with the additional permission stated in the file; the
  upstream XML is not vendored

This variant also has 256 defined bytes and 256 unique Unicode scalar outputs,
so its encoder is its exact inverse.

## Naming and collision policy

The unambiguous historical names `KEYBCS2` and `KAMENICKY` identify the
original profile. Numeric names are intentionally not aliases. Bare `CP895`,
`DOS-895`, and `895` conflict with Japanese IBM code page 895; `CP867` and
`NEC-867` conflict with IBM's Hebrew code page 867; `3844` is a printer model
code-page number rather than a globally registered charset identity.

GNU libiconv 1.19 does not expose `KEYBCS2`, `KAMENICKY`, `CP895`, or `CP867`,
including with extra encodings enabled, so GNU is not a differential oracle:

- release: https://ftp.gnu.org/gnu/libiconv/libiconv-1.19.tar.gz
- tarball SHA-256:
  `88dd96a8c0464eca144fc791ae60cd31cd8ee78321e67397e25fc095c4a19aa6`
- `lib/encodings.def` SHA-256:
  `156cc484a53109241e3c4d23e0ac1d75c0e199eac48f3de8e9d9e87ecc1ce5f1`

PC-BASIC's `kamenicky.ucp` is a CP437-compatible display-glyph profile, not a
canonical text decoder. It substitutes CP437 glyphs for C0 and DEL, maps `AD`
to U+00BF, and maps `FF` to U+0000. It differs from original text KEYBCS2 at 34
slots and is therefore documented but not conflated with either text profile:

- URL: https://raw.githubusercontent.com/robhagemans/pcbasic/6a3a035b0a1c1029d48bc9284e642b6b4bd64fb5/pcbasic/data/codepages/kamenicky.ucp
- SHA-256: `205f0e8b73e95d1f918ec035a610c877325bca432cb7760cec6ee8d6598c539d`
- license: GPL-3.0-or-later; upstream license SHA-256:
  `66975a08038ba7cd3a6aabf840941afb67aad897eccc2678b6f31c91aa93e1bf`

For both implemented text profiles, bytes `00` through `1F` decode to Unicode
controls U+0000 through U+001F and byte `7F` decodes to U+007F. CP437 smiley,
card-suit, and house glyphs are presentation semantics and are not accepted by
the inverse text encoders.

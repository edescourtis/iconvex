# VietUnicode VNI profile evidence

This directory pins the four profile columns published as “VNI Character
Sets” by the Vietnamese Unicode project. The page says that it was excerpted
from VNI Software Company's `vnichar.htm`; this is attribution, not a claim of
VNI authorship, affiliation, approval, or endorsement by Iconvex.

## Primary snapshot

- URL: `https://vietunicode.sourceforge.net/charset/vni.html`
- Retrieved: `2026-07-18`
- HTTP `Last-Modified`: `Wed, 20 Mar 2002 01:55:54 GMT`
- HTTP `ETag`: `W/"27cf-39c952753de80"`
- Wire size: `10191` bytes (CRLF)
- Wire SHA-256: `104cfaf796d37c64cff0f35dfb3dd557cd6ca0e54b01cc517d29966fe83e10b7`
- LF/POSIX-newline-normalized size: `10037` bytes
- LF/POSIX-newline-normalized SHA-256: `676bc2b9220c74b1f4019fc0b096614cbf903eeedd64cadc0a8144db85004549`

`vni.html.base64` losslessly preserves the wire bytes. `vni.html` is the
line-ending-normalized, reviewable copy with one final POSIX newline. Tests
require the decoded wire digest, the normalized digest, and byte-for-byte
equality after CRLF-to-LF plus final-newline normalization.

Those two raw snapshots are repository-only source-validation evidence. The
upstream page states no redistribution grant, so they are not redistributed in
the Hex package. The release selects only `vni_profiles.csv` and this
`SOURCE_METADATA.md`; repository tests continue to validate both raw snapshots
against the pinned digests above.

## Normalized mapping

`vni_profiles.csv` SHA-256:
`86389a581bf7fc71277fcf94cb7e793f5b072b2758fc3d8404ac02dc195695aa`

The source contains 134 Vietnamese scalar rows and four distinct serialized
profiles. The normalized table adds the 128 ASCII identity tokens, then applies
the source rows by token. A source glyph replaces an ASCII identity token in
the DOS font profile when the two occupy the same byte. Unicode scalars are
derived independently from the source's base-letter and mark descriptions by
canonical composition; `D bar` and `d bar` are U+0110 and U+0111.

The resulting exact profile shapes are:

- VNI ASCII/DOS: 255 one-byte tokens. This is a font-glyph profile; one octet
  is undefined and several ASCII graphic slots are replaced.
- VNI ANSI Win/Unix: 144 one-byte tokens and 118 two-byte tokens.
- VNI Mac: 144 one-byte tokens and 118 two-byte tokens.
- VNI Internet Mail: 128 one-byte, 74 two-byte, and 60 three-byte tokens.
  Longest-token decoding is required. Its ASCII punctuation tokens make
  serialization non-injective across some adjacent scalar boundaries: all
  individual source mappings are reversible, while 134 of the 262² adjacent
  canonical scalar pairs merge into a longer token.

No unqualified `VNI` name is exposed. The public names carry the source date
and the exact profile. The Internet Mail and DOS variants are identified as
font/token profiles rather than represented as generic byte code pages.

## Independent operational reference

Encode::VN 0.06 (released 2013-09-15) states that its VNI maps were generated
from the VNI Software Company `vnichar.htm` table and publishes the same four
profiles. Release archive:
`https://cpan.metacpan.org/authors/id/J/JW/JWANG/Encode-VN-0.06.tar.gz`.

- Archive SHA-256: `23b7ae19c5c4ac21d1fc95e29b9516fb7092177723add7f0adac69504b00eddb`
- `x-viet-vni-ascii.ucm`: `0bf92c64f0b87f327748afa6ef6a32b9edb259ca18b2b3d8c6cd66a44fffb283`
- `x-viet-vni.ucm`: `6f2ba519256f1c57e1d5ce3bd58db3a829b5fb34147e51990e0e630bdeedef81`
- `x-viet-vni-mac.ucm`: `c82af8503a330c48b4018f7b36bcf6d4bd8725b317e2d2332c8f75042cf93ef7`
- `x-viet-vni-email.ucm`: `c690f88ed400a6b1e9d802b05883695c6c50664f2132d90b93a26f3566ba42ab`

The UCM rows confirm the ASCII baseline, token repertoire, and canonical
Unicode inverse used here. The runtime does not invoke Perl, XS, ICU, iconv,
or any external converter.

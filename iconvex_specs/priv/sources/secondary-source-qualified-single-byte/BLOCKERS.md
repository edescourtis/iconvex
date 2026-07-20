# Exact-evidence blockers for the remaining secondary rows

These are evidence blocks, not deferred guesses. A codec can be added later
when the stated evidence gap is closed without weakening the byte-exact and
`LGPL-2.1-or-later` requirements.

## ENC-0067 - Bitstream International Character Set

Disposition: `blocked_exact_evidence`.

The cited BICS artifact is not a single-byte encoding. It defines two-byte
codes prefixed by `00` or `01`. Wikipedia revision 1281909572 (wikitext
SHA-256
`d4d327400fecdaa4ce3cb2f74369c893c6921774b9255aa835aebe5e28ddb636`)
also contains several graphic cells with no Unicode mapping and explicitly
labels others "not in Unicode". Treating a second byte as a standalone octet,
or assigning replacement/private-use scalars, would invent both framing and
round-trip semantics. A future BICS codec needs a pinned primary framing
specification and an explicit, content-qualified policy for every non-Unicode
glyph.

## ENC-0985 - Iran System encoding standard

Disposition: `blocked_license_and_semantics`.

The authoritative *IRAN SYSTEM to Unicode* table version 1.0, dated 2000-01-21,
is 13439 bytes with SHA-256
`e31f8d325640aff859f2ce53c6b69e650a0084c42ba6dcbaddaeccdf82b0e1e3`.
It states "Copyright (c) 1999 Roozbeh Pournader. All Rights reserved" and maps
many bytes to two- or three-scalar joining-control sequences. The cited
Wikipedia revision instead maps those cells to Arabic presentation-form
scalars. Those are observably different Unicode streams and inverse policies.
Without redistribution permission for the authoritative mapping or an
explicitly versioned specification choosing one semantic model, an LGPL codec
would make an unsupported license and identity claim.

## ENC-1265 - Modified HP Roman-8

Disposition: `blocked_ambiguous_profiles`.

The redirect target at Wikipedia HP Roman revision 1361711799 has wikitext
SHA-256
`c4cd07bb1be71bd5267eb9f6222839451ce344637e39e8a5b4ad0d5ffe4832a0`.
It defines two different encodings: 1984 variant I for HP 110/110 Plus and
1986 variant II for HP 82240A/B and HP-28C/S. Even within those tables it gives
alternative Unicode mappings, including `U+02CB or U+0060` and
`U+00B5 or U+03BC`; variant II also gives `U+2221 or U+2220`. Selecting one
alternative would manufacture an inverse. Exact source-qualified codecs need
pinned primary charts plus a documented Unicode mapping policy for each
ambiguous glyph, and the two variants must remain separate identities.


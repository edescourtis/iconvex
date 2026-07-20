# ISO-IR-169 Blissymbolics

`ISO-IR-169` is the registered raw two-byte, 94-by-94 graphic-set form,
without an ISO-2022 designation escape. The official sheet defines
exactly 2,304 characters:

- 8 general characters, 10 ordinal digits, and 19 indicators;
- 2,267 dictionary words at rows 16 through 40;
- no mappings for any unassigned code-table position.

Seventeen general characters have exact Unicode equivalents. Unicode
still has no published Blissymbolics block, and both WG2 N1866 and the
newer N5228 propose an ideographic/decomposed model rather than assigning
the lexical ISO-IR-169 words one-for-one. The remaining 2,287 registered
characters therefore use Supplementary Private Use Area-A with this
stable reversible formula:

`U+F0000 + (first_byte - 0x21) * 94 + second_byte - 0x21`

This retains every original code position without claiming a false
semantic equivalence. The generated mapping, every 16-bit input word,
every prefix byte, the complete repertoire, and every Unicode scalar are
covered by tests.

| Property | Value |
|---|---:|
| Decoder mappings | 2304 |
| Encoder mappings | 2304 |
| Direct Unicode mappings | 17 |
| Stable PUA mappings | 2287 |

- Registration SHA-256: `4c3383874ef94677111b025ca9a56ddeee282fcad9b03d9cbf3fc3d73167a75e`
- Normalized mapping SHA-256: `5773c8c83e5f876809ff887c0cd9e7473c7d66c69341091f74f44e63cdf1da3f`
- WG2 N1866 SHA-256: `f6fe0782185d9f58ec12ab09c35ab61be5e1dd893b1e8ecbcc860a0b271390d6`
- WG2 N5228 SHA-256: `c6fc3ac979f8a52ab2c8212711936b93cc6ee4cc65ec54e784c2db9f7e114764`

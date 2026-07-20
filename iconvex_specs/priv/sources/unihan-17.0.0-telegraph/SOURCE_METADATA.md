# Unicode 17 Chinese telegraph property-token mappings

These compact tables are independently filtered from Unicode 17.0.0
`Unihan.zip`, member `Unihan_OtherMappings.txt`, whose SHA-256 digest is
`4fabda168d04a5ac360809a8bfa377fe54e04fbc069ba67cacad4df03d691fa0`.
The containing `Unihan-17.0.0.zip` digest is
`f7a48b2b545acfaa77b2d607ae28747404ce02baefee16396c5d2d7a8ef34b5e`.

Unicode Standard Annex #38 revision 39 documents the Unicode 17 properties
`kMainlandTelegraph` and `kTaiwanTelegraph` as Provisional Other Mappings. Each
property subentry has validation syntax `\d{4}`; all shipped tokens are exactly
four ASCII decimal digits. The authoritative documentation is
<https://www.unicode.org/reports/tr38/tr38-39.html> (SHA-256
`c860013dbd725652888296afe688ac5db9352d234e0741ad44e6cba6ab56852e`).

The tables provide three source-qualified one-token profiles:

- `UNIHAN-17.0.0-KMAINLANDTELEGRAPH-DECIMAL-TOKEN` — 7,078 assigned tokens;
- `UNIHAN-17.0.0-KTAIWANTELEGRAPH-DECIMAL-TOKEN-READABLE` — 9,026 tokens and
  9,024 reverse scalars, choosing the smallest numeric token for duplicates;
- `UNIHAN-17.0.0-KTAIWANTELEGRAPH-DECIMAL-TOKEN-LOSSLESS-VPUA-1` — 9,026
  bijective outputs, reserving U+F8B00..U+F8B03 for tokens `0066`, `2210`,
  `7775`, and `9795`.

The readable reverse rule and VPUA rewrites are explicit Iconvex policies, not
historical-preference claims. The Unicode property source defines individual
four-digit values but does not define concatenated message framing,
space-separated messages, BCD, shifts, incremental resynchronization, or a
generic Mainland/Taiwan choice. Accordingly these profiles are property-token
APIs, are not registered as `Iconvex.Codec` byte streams, and deliberately do
not claim aliases such as `CHINESE-TELEGRAPH`, `CHINESE-COMMERCIAL-CODE`, or
`CNS2DCI`.

Generated table SHA-256 digests:

- `mainland_tokens.csv`:
  `685b057cc0690c19718966aa02121887071398227c6b48605cf9347db70e16f0`;
- `taiwan_tokens.csv`:
  `15dc21eacf695ce038500e68fa40c125d0762b5e265c9683f82f17d2eac878a6`;
- `taiwan_policy.csv`:
  `79890c693597f1f25b4e68abe5627883c8299d7d382ed8865c42a3d361971696`.

The mappings are distributed under Unicode License v3, reproduced by the
package-level `LICENSE.UNICODE`. Iconvex implementation code remains
LGPL-2.1-or-later. No Unicode archives, research snapshots, third-party codec
sources, or historical source scans are selected for the package artifact.

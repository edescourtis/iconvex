# ELOT 927 profile decision

The ISO 2375 registration authority's registration 88 PDF is pinned by URL and
digest:

- <https://itscj.ipsj.or.jp/ir/088.pdf>
- SHA-256 `0bcae39e969ce89ad4b926cc0b0cc7c838a6720e99461f19460c9d9d2e7d815c`

The rendered registration chart assigns Greek capitals to positions 41–5A and
Greek lowercase letters to positions 61–7A, with positions 4A, 57, and 6A
unused. That is byte-exact with the existing RFC 1345 `greek7` / ISO-IR-88
codec, so standard `ELOT-927` and `ELOT927` are aliases of `greek7`.

Kermit's separately licensed `u_elot927` decoder table is not that standard
mapping: it preserves ASCII capitals, maps uppercase-only Greek at 61–78, and
maps 79–7A to SPACE. The complete tables differ at 54 printable positions.
Iconvex therefore exposes this historical terminal behavior only as
`KERMIT-ELOT927-GREEK`, with `ELOT927-GREEK` retained as its source title.

The Kermit encoder function is not used as an oracle: its lowercase-Greek
arithmetic produces high-bit values incompatible with a seven-bit code. The
native encoder is instead the deterministic inverse of the pinned decoder
table; duplicate SPACE cells 79 and 7A encode canonically as 20.

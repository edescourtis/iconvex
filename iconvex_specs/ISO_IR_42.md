# ISO-IR 42 / JIS C 6226-1978

`ISO-IR-42` exposes the registered two-byte 94×94 graphic set directly. Both
bytes are in `0x21..0x7E`; it does not add an EUC or ISO-2022 transport layer.

The executable mapping is the pinned ICU `ibm-955_P110-1997` pure-DBCS table:

- 6,879 round-trip mappings
- 12 Unicode-to-byte fallback rows, deliberately disabled because they do not
  round-trip
- official ISO-IR registration SHA-256:
  `f3ef6fd4f2c126b3477e0763a713dcff14373fc7d3ee121c397b3283380ff2d3`
- ICU UCM SHA-256:
  `06bd629e1967a5fb9bcb75b5cd964efb60036ca5b5d78bb0ce5b1301ffcfc7f7`
- independent Pike table revision:
  `4bf9adbd874894d2484de1664969de43e4206492`

The conformance test checks all 8,836 graphic positions, every single-byte
prefix, the whole repertoire in one round trip, all 12 disabled fallbacks, and
canonical encoding over every Unicode scalar.

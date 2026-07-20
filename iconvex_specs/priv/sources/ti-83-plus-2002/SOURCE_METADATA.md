# TI-83 Plus 2002 numeric source metadata

- Source: Texas Instruments, *TI-83 Plus Developer Guide*, Third Release, 28 May 2002.
- Official URL: https://education.ti.com/download/en/ed-tech/830D08FF31804AEAA2F03B8F5E89AD14/672891A1E98349CAB91C11B4928C253C/sdk83pguide.pdf
- Official guide SHA-256: `a07d2cae4d5be0529901c178acd80028d2a72c484a04c61cde104f34712cec55`.
- Large-font evidence: Appendix A, PDF physical pages 173-179, printed pages 156-162.
- Small-font evidence: Appendix B, PDF physical pages 180-187, printed pages 163-170.
- Compact mapping SHA-256: `186d80d270a6a27815df8d0b5ff993c65b158efb7f3d6ddd27533feb9cb96ccc`.

The compact asset defines six explicit profiles: `TI-83-PLUS-LARGE`,
`TI-83-PLUS-LARGE-LOSSLESS-VPUA`, `TI-83-PLUS-LARGE-RAW-VPUA`,
`TI-83-PLUS-SMALL`, `TI-83-PLUS-SMALL-LOSSLESS-VPUA`, and
`TI-83-PLUS-SMALL-RAW-VPUA`. Bare `TI-83-PLUS` names are intentionally absent
because the two source fonts do not have identical byte semantics.

Readable rows contain numeric Unicode scalar sequences and explicit reverse
policies. Lossless rows preserve ambiguous, duplicate, and invalid byte identity.
Raw profiles are arithmetic: large byte `b` maps to `U+F8400+b`; small byte `b`
maps to `U+F8600+b`. The corresponding lossless allocation blocks are
`U+F8300..U+F83FF` and `U+F8500..U+F85FF`.

This is an independently authored compact numeric transcription. The release
asset contains no official symbol-name or cell transcription, source PDF or
render, third-party implementation artifact, normalization-collision research
table, or temporary filesystem path.

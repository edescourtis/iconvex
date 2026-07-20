# UTF-6 draft source metadata

- Profile: `UTF-6`
- Revision: `draft-ietf-idn-utf6-00`, 16 November 2000
- Authors: Mark Welter and Brian W. Spolarich, WALID, Inc.
- Normative source: `https://www.ietf.org/archive/id/draft-ietf-idn-utf6-00.txt`
- Retrieved: 2026-07-17
- Source SHA-256: `80033b5e41bc9f2fd01bddf99a300827b837f06ba93ef303bc54bc53df3755ca`
- Local source: `draft-ietf-idn-utf6-00.txt`
- Upstream notice: `UPSTREAM-NOTICE.txt`

The draft states: “The distribution of this document is unlimited.” It also
states “Copyright (c) The Internet Society (2000). All Rights Reserved.” The
complete pinned draft, including its status and copyright notices, is retained
byte-for-byte. It is specification evidence, not linked runtime code. The
independently written pure-Elixir implementation is LGPL-2.1-or-later under
the package `LICENSE`.

## Exact interpretation

The forward transform operates on UTF-16 code units exactly as section 2.4.3
specifies. Unicode supplementary scalars are converted to high/low surrogate
pairs before section 2.4.2 compression; the reverse transform validates and
recombines those pairs and rejects every unpaired surrogate.

Section 2.4.1's displayed initial-character set, `[ghijklmopqrstuv]`, has a
display-set typo that omits `n`. Section 2.5.1 normatively and explicitly says
the decoder accepts the continuous range `g` through `v`; the implementation
therefore uses all sixteen consecutive ASCII letters `g..v` for nibble values
zero through fifteen. Reverse input is ASCII-case-insensitive as required.

The draft requires RFC 1035 legality after conversion. Iconvex consequently
rejects dot-created empty parts, labels longer than 63 bytes, and a literal
hyphen that would end a generated label. The empty codepoint list is treated
as a hostname with zero parts and maps to the empty binary; it does not create
or accept an empty label. Every nonempty component is emitted with canonical
lowercase `wq--`, `y`, `z`, and variable-length digits.

Malformed reverse input uses whole-string `:stop` recovery because restarting
inside a compressed component can change all subsequent code units. No GNU
libiconv comparator exists: GNU libiconv 1.19 does not expose this expired IDN
draft profile. The repository benchmark uses an independent direct draft
transcription and enforces the common 30x native/reference ceiling.

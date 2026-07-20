# High-priority codec-gap audit

`HIGH_PRIORITY_CODEC_GAPS.tsv` is the exact, test-enforced queue of
high-confidence text codecs not yet implemented. It is regenerated conceptually
from `known_encodings.csv`, but kept as a reviewed evidence ledger: every row
names the authoritative inventory, the mapping artifact searched, and the exact
byte-level evidence still missing.

The IBM audit searched every nested member of IBM's six-package 2013 CDRA
conversion-table archive. `IBM-1175.zip` was present, was implemented, and all
256 mappings were proven equal to the pinned runtime table. None of the 19 IBM
rows still in this ledger was present. A CCSID description or an associated
code-page family is insufficient to invent a byte table, especially for UDC,
Arabic shaping, and bidirectional string-type variants.

The Microsoft audit checked the code-page identifier registry, Windows SDK
conversion documentation, and the open .NET Reference Source. The registry
provides labels for 50229, 50936, 709, and 710 but no mapping tables. Reference
Source explicitly rejects 50229. These names remain gaps instead of being
silently aliased to superficially similar ISO-2022, EBCDIC, or Arabic codecs.

Nine rows record the complete OpenJDK quarantine. Seven are the exact removed
Specs canonical codecs; `CP50220` and ICU
`ISO_2022,locale=zh,version=2` are separate catalog records whose former
implemented status depended only on aliases supplied by those removed codecs.
Every prior runtime was source-informed GPL-plus-Classpath work. The two
table-only generators also inspected and reproduced distinctive Java routing,
override, duplicate-priority, and canonical-reverse choices in merged ETFs.
It may not be reintroduced into the LGPL release; each row remains a gap until
an independent, suitably licensed mapping/state source and implementation pass
provenance review. Core's separate `cp50221` registration does not prove the
exact `x-windows-50221` OpenJDK profile. Likewise, the separately shipped ICU
archive `ibm-1350_P110-1997` remains implemented under its own source-qualified
identity; that does not preserve the removed `x-eucJP-Open` registration.

Primary evidence:

- IBM i CCSID definitions: <https://www.ibm.com/docs/en/i/7.6.0?topic=information-ccsid-values-defined-i>
- IBM encoding schemes: <https://www.ibm.com/docs/en/zos/3.1.0?topic=ccsids-encoding-scheme>
- IBM CDRA conversion tables: <https://download.boulder.ibm.com/ibmdl/pub/software/dw/java/cdctables.zip>
- Microsoft code-page identifiers: <https://learn.microsoft.com/en-us/windows/win32/intl/code-page-identifiers>
- Microsoft .NET Reference Source `Encoding`: <https://github.com/microsoft/referencesource/blob/master/mscorlib/system/text/encoding.cs>

When an exact public mapping appears, TDD begins by removing that name from this
ledger and observing the catalog/audit contract fail before implementing it.

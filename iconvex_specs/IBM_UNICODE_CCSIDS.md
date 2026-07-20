# IBM Unicode CCSIDs

ICU 78.3 classifies `ibm-1200` and `ibm-13488` as byte-identical
aliases of BOM-less UTF-16BE. Iconvex exposes both IBM names through
one native Elixir codec and preserves the explicit IBM namespace.

`ibm-61952` is intentionally not registered: ICU's primary converter
registry says it is not a valid CCSID because it denotes Unicode 1.1,
while IBM i labels it an obsolete UCS CCSID and recommends 13488.

| Encoding | Aliases | Wire semantics |
|---|---|---|
| `IBM-1200` | `IBM-1201`, `IBM-13488`, `IBM-13489`, `IBM-17584`, `IBM-17585`, `IBM-21680`, `IBM-21681`, `IBM-25776`, `IBM-25777`, `IBM-29872`, `IBM-29873`, `IBM-61955`, `IBM-61956`; each also accepts `IBMnnn` and `CCSIDnnn` | BOM-less UTF-16BE |

- IBM source: https://www.ibm.com/docs/en/i/7.4.0?topic=information-ccsid-values-defined-i
- IBM source SHA-256: `d0682e71d66de77bd518cda1e82377474bdb78cd6dd87b0c17cbccdc25c67dfb`
- ICU source: pinned `priv/sources/icu-78.3-unicode-variants/convrtrs.txt`

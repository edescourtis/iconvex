# RFC 3492 / CPython Punycode source metadata

Iconvex Specs implements the Punycode instance of Bootstring defined by RFC
3492. The runtime implementation is original pure Elixir; the pinned CPython
module is an independently implemented executable test oracle and is never
loaded or called at runtime.

| Artifact | Upstream | Revision | SHA-256 | License |
|---|---|---|---|---|
| `rfc3492.txt` | <https://www.rfc-editor.org/rfc/rfc3492.txt> | RFC 3492, March 2003 | `d1848b1b4f01e20708a64f42394e5f4b840141935bed7f09ad7baeb6693b8772` | RFC Trust / notices embedded in the document |
| `cpython-3.14.6-punycode.py` | <https://github.com/python/cpython/blob/v3.14.6/Lib/encodings/punycode.py> | CPython `v3.14.6` | `1e8d57e06e9b527009c35f2a1486ab56b51540e817f5bd8f239dc71e3fc0b014` | Python Software Foundation License Version 2 |
| `CPYTHON-LICENSE.txt` | <https://github.com/python/cpython/blob/v3.14.6/LICENSE> | CPython `v3.14.6` | `b0e25a78cffb43f4d92de8b61ccfa1f1f98ecbc22330b54b5251e7b6ba010231` | Full upstream license text |

RFC 3492 sections 5 and 6 define the exact parameters and algorithms. Section
7.1 supplies nineteen normative examples, all of which are parsed directly
from the pinned RFC by the test suite. CPython supplies an independent encoder,
decoder, malformed-input classifier, and performance comparison point.

Punycode maps one complete Unicode scalar string to variable-length ASCII. It
is not the higher-level IDNA `xn--` label format: Iconvex neither prepends that
prefix nor applies IDNA mapping, normalization, or label-length policy.

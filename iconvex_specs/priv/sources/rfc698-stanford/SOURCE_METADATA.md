# RFC 698 Stanford Extended ASCII graphics metadata

This directory contains an Iconvex-authored factual Unicode normalization of
the Stanford graphic table in RFC 698. The normalized mapping and native
Elixir implementation are LGPL-2.1-or-later. The RFC itself remains governed
by its publisher's terms and is referenced rather than redistributed.

## Exact source

- Document: RFC 698, *TELNET EXTENDED ASCII OPTION*, July 1975.
- Source: https://www.rfc-editor.org/rfc/rfc698.txt
- Retrieved source size: 5,086 bytes.
- Source SHA-256:
  `a67d173ac8a5807983f9396ad1f67d0e65f082b08e74b849299c5feb2945c85f`.
- Normalized `graphics.csv` SHA-256:
  `be4ced42a51ca173da08f240a4618a51fe88584946d3aa932f5fceb9861e9490`.

Section 6 describes the SU-AI character set only for reference and says it is
"not required as part of the extended ASCII Telnet option". Iconvex therefore
registers two explicitly RFC-, site-, year-, and interpretation-qualified
seven-bit graphic profiles. It does not claim the unqualified names
`STANFORD-EXTENDED-ASCII`, `RFC698`, or `EXTEND-ASCII`.

## Two graphic interpretations

The `FORMAT-EFFECTOR` profile preserves the RFC's main meanings for null, tab,
line feed, vertical tab, form feed, carriage return, and rubout. The
`HIDDEN-GRAPHICS` profile uses the seven alternate glyphs that the RFC marks
as hidden for typesetting programs: middle dot, gamma, delta, integral,
plus-minus, circled plus, and circumflex. The profiles differ only at octal
codes `000`, `011` through `015`, and `177`.

The RFC names mathematical characters rather than Unicode scalars. The
normalization uses the direct modern scalar with the same name: for example
DEL is U+2202 PARTIAL DIFFERENTIAL, logical operators use U+2227/U+2228,
LOZENGE uses U+25CA, and the hidden vertically centered dot uses U+00B7. All
128 values in each profile are unique, so encoding is an exact inverse.

## Deliberate transport exclusion

RFC 698 separately defines CONTROL and META modifier bits and a two-octet
TELNET subnegotiation wrapper for a logical nine-bit value. Those modifier bits
are program commands, not Unicode characters, and the RFC does not prescribe
the Stanford graphics for that option. Consequently the
9-bit modifier transport is not implemented as a text codec. It would belong in a TELNET
protocol adapter with an application-defined modifier model, not in either
graphic character mapping.

GNU libiconv 1.19 does not expose either source-qualified Stanford profile, so
no GNU differential result is claimed for them.

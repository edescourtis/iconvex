# Short KOI sources

`SHORT-KOI` is the stateless KOI-7 N2 profile standardized by GOST 13052
(initially GOST 13052-67 and subsequently revised). It retains controls,
punctuation, digits, and uppercase ASCII in their seven-bit positions and
replaces positions 60–7E hexadecimal with 31 uppercase Cyrillic letters.

The executable mapping is ported from the pinned, BSD-licensed C-Kermit
`u_koi7` decoder table in
`../dec-terminal-character-sets/kermit/ckcuni.c`. Kermit's matching published
table is <https://www.columbia.edu/kermit/koi7.html>. The source file and its
`COPYING` file are pinned by SHA-256 in `test/short_koi_test.exs`.

Kermit's `SHORT-KOI` is not `KOI7-switched`: the latter uses SI/SO state to
select ISO 646 or KOI-7 N1, while this codec places KOI-7 N2 Cyrillic directly
in the 60–7E range. Octets 80–FF are outside the seven-bit code and invalid.

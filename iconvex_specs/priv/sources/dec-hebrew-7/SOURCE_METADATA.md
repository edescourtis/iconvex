# DEC Hebrew source metadata

## Digital Guide to Developing International Software

- Artifact: `Kennelly_Digital_Guide_To_Developing_International_Software_1991.pdf`
- Publisher: Digital Press / Digital Equipment Corporation, 1991
- Source URL: <https://www.bitsavers.org/pdf/dec/_Books/_Digital_Press/Kennelly_Digital_Guide_To_Developing_International_Software_1991.pdf>
- SHA-256: `a28083a4057e8bffcc928bda4f56bb316b939b6c6b5f498a3a180322bd1cb80b`
- PDF page: 40 (zero-based page index 39); printed page: 19
- Scope: defines DEC Hebrew 7-bit as ASCII with positions 96-122 replaced
  by the Hebrew alphabet and explicitly equates it to Israeli Standards Institute Standard 960. The same page defines DEC Hebrew 8-bit as DEC MCS
  with positions 192-223 and 251-255 removed and Hebrew placed at 224-250.

The scan says `251-256`; an octet has positions 0-255, so position 256 is
outside the code space. This implementation applies the stated removal through
the final octet, 255.

## VT510 Video Terminal Programmer Information

- Artifact: `vt510rmb.pdf`
- Publisher: Digital Equipment Corporation
- Source URL: <https://vt100.net/mirror/mds-199909/cd3/term/vt510rmb.pdf>
- SHA-256: `440bbee110eb75027a06b5b375683fbc87cb739edac32899005ad46981c7d514`
- PDF page: 181 (zero-based page index 180); printed page: 5-57
- Scope: DECHEBM independently identifies received hexadecimal positions
  `60` through `7A` as DEC 7-bit Hebrew.

## Kermit cross-check

- Artifact: `../dec-terminal-character-sets/kermit/ckcuni.c`
- Pinned revision: `8e977425d2f7f618d14aa466d516e9b79787ffc6`
- SHA-256: `af93d5a1c779aa73fa3221ab5ec0125de20267110cf23395971ce35cc88527ca`
- License artifact: `../dec-terminal-character-sets/kermit/COPYING`
- License SHA-256: `067b8c8fc98d9359dfbd211820e1d57bed1e173144a184a21e8ead802b6502be`
- Scope: `u_hebrew7` and `tx_hebrew7` independently enumerate the same
  27-letter mapping in positions 96-122.

The mapping facts are implemented under Iconvex's LGPL-2.1-or-later license.
The retained Kermit source remains under its own BSD-style terms in `COPYING`.

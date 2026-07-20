# Historical ISO-IR graphic sets

These codecs expose the registered graphic positions directly. ISO-IR 31
maps composite Greek diacritics to Unicode combining sequences and preposed
breathing signs to their Greek Extended spacing characters. ISO-IR 38 is
the 77-character DIN 31624 bibliographic set, checked against Pike's pinned
independent 94-position table and updated to current Unicode combining
characters. ISO-IR 39 uses
the final Unicode L2/00-223 mapping for ISO 6438, including its corrected
U+01DD case pairing, with the dedicated Latin chi characters added in
Unicode 7 and 8 replacing the old Greek-chi fallbacks. ISO-IR 53 is
the revised 76-character ISO 5426 bibliographic extension with the literal
UCS mappings recorded on its registration sheet. ISO-IR 59 is the complete
94-position Arabic CODAR-U set, including vocalization presentation forms
and its compound tatweel-plus-hamza graphic. ISO-IR 198 is the exact
60-character Latin/Hebrew supplementary repertoire.

| Encoding | Decode mappings | Encode mappings | Registration SHA-256 | Mapping/cross-check SHA-256 |
|---|---:|---:|---|---|
| `ISO-IR-31` | 83 | 83 | `2006784a60655960304cc9ceeb05599355242d83352e0ebbe2aff4fb8eef14f2` | — |
| `ISO-IR-38` | 76 | 76 | `42ff603c9fbaf7518ea3253568a2e88f7accf8ef00635486e031c0603a2665cd` | `28f856d12347859c9cb7f10361c813c4a4f3f7c9d33911544b50c7897748d860` |
| `ISO-IR-39` | 60 | 60 | `15510e5c252717ffbff519a7beb8a07cb26295be9111ad527016cddfd61826c9` | `d4872f2e9b75cc011b63c60e75e22a36358228e85f56dc35817624fd4250b498` |
| `ISO-IR-53` | 77 | 75 | `cc37311a58fee1c31868b1486fbde279a7f00ee9a6a496642a2dfa2731ead18f` | — |
| `ISO-IR-59` | 94 | 93 | `fcbf4dfa7d522a9332ef6cd1cb73c7ab2531fdccbbd1b330dca2bd7e47d23862` | `28f856d12347859c9cb7f10361c813c4a4f3f7c9d33911544b50c7897748d860` |
| `ISO-IR-198` | 60 | 60 | `acbf5b215a37a343e90f849106b118f532ab9c35340e27a1768382930c8f3aba` | — |


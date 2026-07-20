# Formal SignWriting oracle exceptions

Iconvex follows the declared v1.0.0 FSW/SWU domain, not broader implementation
regexes or later software behavior.

- The final ordinary FSW symbol is `S38b07`, mapped to U+4F428. Values
  `S38b08` through `S38b5f` (U+4F429 through U+4F480) accepted by a broader
  upstream library path are outside the v1.0.0 declared 62,504-symbol domain and
  are rejected.
- `S00000` maps only to the null U+40000. Other `S0....` spellings are not
  ordinary symbols.
- Hexadecimal letters in FSW symbols are lowercase only. Uppercase spellings
  are not silently normalized.
- A number scalar has no standalone FSW lexical token. Exactly two consecutive
  number scalars encode one `nnnxnnn` coordinate; policy recovery never pairs
  numbers across a discarded or replaced scalar.
- SWU is an experimental character design and is not the Unicode Standard's
  SignWriting encoding. `SWU`, `SGNW`, and bare `SIGNWRITING` are therefore not
  aliases of this FSW source codec.
- `draft-slevinski-formal-signwriting-11` (SHA-256
  `db8830a22a80791e9eb9c2374a585c9422dd7f6ad50ab0f2160f332f9c0c06bb`)
  was reviewed as contextual material but is not the selected v1.0.0 oracle.

The exception record is project-authored and LGPL-2.1-or-later. No upstream
CC BY artifact is redistributed here.

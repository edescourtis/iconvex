# ICU 78.3 LMBCS profiles

Native Elixir port pinned to Unicode ICU revision `21d1eb0f306e1141c10931e914dfc038c06121da`.
The annotated ICU algorithm and all thirteen loaded mapping tables are committed and hashed.
ICU instantiates optimization groups `1`, `2`, `3`, `4`, `5`, `6`, `8`, `11`, `16`, `17`, `18`, and `19`; Iconvex Specs exposes exactly those twelve canonical profiles.
The eleven non-default names are working but intentionally unadvertised in ICU's alias list, so they have no invented aliases.

| Group | Decode mappings | Encode mappings |
|---:|---:|---:|
| `0x00` | 286 | 277 |
| `0x01` | 256 | 256 |
| `0x02` | 255 | 255 |
| `0x03` | 245 | 245 |
| `0x04` | 256 | 256 |
| `0x05` | 256 | 256 |
| `0x06` | 255 | 255 |
| `0x08` | 256 | 256 |
| `0x0B` | 256 | 256 |
| `0x10` | 9795 | 9398 |
| `0x11` | 17366 | 17366 |
| `0x12` | 19850 | 19840 |
| `0x13` | 24070 | 24070 |

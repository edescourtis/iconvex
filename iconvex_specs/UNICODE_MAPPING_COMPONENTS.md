# Unicode mapping-table component codecs

These are exact, separately named component representations from pinned Unicode mapping tables.
The Hangul columns are not advertised as full EUC-KR, UHC, or JOHAB transports; they contain
only the Hangul syllable mappings explicitly present in `HANGUL.TXT`. `IBMGRAPH` exposes the
memory-mapped PC video glyph positions and its distinct CP864 column.

| Encoding | Aliases | Decode mappings | Encode mappings | Source SHA-256 |
|---|---|---:|---:|---|
| `HANGUL-WANSUNG-COMPONENT` | `UNICODE-HANGUL-WANSUNG` | 2350 | 2350 | `c855b0b66c979fa296b7e996ef08e7a3c5bc530f9f68c865b669e77bc29749bb` |
| `HANGUL-UHANGUL` | `HANGUL`, `UHANGUL`, `UNICODE-HANGUL-UNIFIED` | 11172 | 11172 | `c855b0b66c979fa296b7e996ef08e7a3c5bc530f9f68c865b669e77bc29749bb` |
| `HANGUL-JOHAB-COMPONENT` | `UNICODE-HANGUL-JOHAB` | 11172 | 11172 | `c855b0b66c979fa296b7e996ef08e7a3c5bc530f9f68c865b669e77bc29749bb` |
| `IBMGRAPH` | `IBM-PC-VIDEO-GRAPHICS` | 43 | 43 | `5c8052b5a9c3852b1cb4b6a1b5d1591e8d26604e7ed457cbdc6f1cbe09463cf2` |
| `IBMGRAPH-CP864` | `IBM-PC-VIDEO-GRAPHICS-CP864` | 32 | 32 | `5c8052b5a9c3852b1cb4b6a1b5d1591e8d26604e7ed457cbdc6f1cbe09463cf2` |

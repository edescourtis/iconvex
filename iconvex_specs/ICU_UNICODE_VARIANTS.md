# ICU Unicode converter variants

Generated from ICU 78.3 commit `21d1eb0f306e1141c10931e914dfc038c06121da`. The platform/opposite
names are resolved from ICU's compile-time endianness routing. UTF-16
versions 1 and 2 reproduce ICU's BOM-required Java `Unicode` behavior
and its always-big-endian Java compatibility variant, respectively.

| Encoding | Variant |
|---|---|
| `UTF16_PlatformEndian` | `utf16_platform` |
| `UTF16_OppositeEndian` | `utf16_opposite` |
| `UTF32_PlatformEndian` | `utf32_platform` |
| `UTF32_OppositeEndian` | `utf32_opposite` |
| `UTF-16,version=1` | `utf16_v1` |
| `UTF-16,version=2` | `utf16_v2` |

Source-set SHA-256: `ff926070b332b264d5bc7312c842e5b30298dc68f292ea5f17ea14ffaf35463a`.

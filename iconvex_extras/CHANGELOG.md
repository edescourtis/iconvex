# Changelog

## Unreleased

- Rebind the final Core-plus-Extras runtime to a fresh GNU libiconv 1.19
  differential over every code point from U+0000 through U+10FFFF. All 198
  codecs remain byte-exact in both directions and both cross-decodes, with
  zero breaches of the independent 30x directional ceiling.
- Make DEC-HANYU, EUC-JISX0213, and ISO-2022-JP-3 policy recovery consume a
  reported terminal incomplete sequence as one codec-native unit. Invalid-byte
  callbacks now fire once, discard cannot reinterpret a malformed suffix,
  replacement occurs once, and byte substitution still renders every consumed
  source byte.
- Replace biased GNU CLI wall-clock denominators with an offline C11 helper
  linked to the exact GNU libiconv 1.19 installation selected by `--iconv`.
  Correctness still comes from byte-comparing pinned CLI output; engine timing
  excludes process startup, file I/O, and stdout, uses fractional microseconds
  for calibrated sub-millisecond batches, and remains independently gated in
  both directions without a millisecond clamp.
- Add bounded dense decode caches for CP943 and EUC-JISX0213 plus a range-aware
  EUC-JISX0213 encoder. Their complete all-codepoint hotspot smoke now passes
  the fair 30x engine gate in both directions with zero mismatches.
- Extend the combined GNU libiconv 1.19 differential to every Unicode code
  point U+0000..U+10FFFF. The UCS-4BE corpus includes all 2,048 non-scalar
  surrogate code points in forward, reverse, and both cross-decode comparisons
  while retaining the independent 30x directional performance gates.
- Make the directional performance gate repeatable by recording the fastest of
  three isolated samples while retaining every sample in total wall time.
- Gate the exhaustive GNU performance ceiling independently for forward and
  reverse conversion, and report both directional ratios alongside their
  worst-case value so a fast direction cannot mask a breach in the other.
- Register all 86 codecs as one atomic managed set. Extras now coexists with
  Telecom and all 1,841 runtime Specs codecs in every start order; its 227 overlaps
  with Specs use deterministic canonical-first/package-priority selection and
  expose the Specs fallback atomically when Extras stops.
- Preserve all package registrations and ownership tokens across a supervised
  Iconvex registry-worker restart.
- Add true incremental source and target streaming for ISO-2022-JP-3, including
  designation state and two-codepoint mapping lookahead across chunk boundaries.
- Bind every full Core-plus-Extras GNU libiconv 1.19 differential to the exact
  runtime, runner, helper source, compiled helper, and linked library artifacts.

## 0.1.0

- Add the exact 86-codec complement of Iconvex's GNU-default 112 codecs.
- Auto-register 85 packed-table codecs and ISO-2022-JP-3 through the public
  external codec API.
- Port all applicable GNU mapping, inverse, stateful, EBCDIC, and discard tests.
- Add every-Unicode-scalar GNU differential verification and paired core/extras
  performance benchmarks.

# Changelog

## Unreleased

- Recover malformed multi-octet Morse signals as complete serialized tokens.
  Public callback discard/replacement now emits one event and cannot reinterpret
  a suffix of the rejected signal; byte substitution still represents every
  consumed source octet.
- Enforce the ETSI TS 102 221 section 8.2 255-octet complete-record limit for
  SIM/USIM alpha identifiers. Source and target Stream state is now bounded;
  strict overflow reports the exact first excess byte or code point, recovery
  is split-invariant, and earlier in-record errors retain first-error priority.
- Commit malformed default-alphabet recovery to GSM mode after consuming the
  first invalid octet, so later `0x80`/`0x81`/`0x82` data cannot be
  reinterpreted as a new UCS2 framing header. One-shot and every Stream split
  retain exact policy events through the 255/256-byte record boundary.
- Preserve SIM alpha-identifier framing during malformed UCS-2 recovery.
  Native discard, substitutions, callbacks, and every Stream split now retain
  `0x80`/`0x81`/`0x82` mode and compressed payload boundaries.
- Report the first malformed `0x80` UCS-2 unit before a later odd tail, and
  report short `0x81`/`0x82` payloads at physical EOF in both one-shot and
  streaming conversion. Plain discard retains a valid compressed prefix when
  the missing declared unit has no physical byte. Present compressed payload
  errors likewise precede a later declared EOF, and a trailing GSM escape is
  reported at its physical byte in every chunking.
- Register all 54 codecs as one atomic managed set. Telecom now starts in any
  order beside Extras and Specs and participates in the deterministic
  2,093-codec full-stack registry without weakening public conflict checks.
- Add distinct, source-qualified IBM Six-Bit Transcode profiles from
  GA27-3005-3 and GA27-3004-2, with complete octet transports, historical
  low-order-first packing, explicit MSB packing, normalized source evidence,
  exhaustive tests, and reproducible performance gates.
- Resolve all canonical and alias `-PACKED-MSB`/`-PACKED-LSB` transport names,
  reject named-order conflicts and mistagged LSB containers, and compare every
  IBM Transcode codec/transport path against an output-equal independent
  reference under the 30× and linear-scaling gates.
- Preserve all package registrations and ownership tokens across a supervised
  Iconvex registry-worker restart.
- Add ITU-T ITA2 / CCITT No. 2 with letters/figures state, unpacked octets,
  strict malformed-input handling, and exact consecutive five-bit packing.
- Add ITU-R CCIR 476 / SITOR / NAVTEX with all traffic and service signals,
  seven-unit packing, and collective-FEC polarity inversion.
- Add ITU-R M.1371-6 AIS six-bit Table 45 with exact field packing and a
  separate IEC 61162 AIVDM/AIVDO armoring and fill-bit API.
- Add ITU-T S.2 case-preserving ITA2 with both modes, single-capital state,
  capital-lock optimization, and normative initialization.

## 0.1.0

- Add unpacked GSM 03.38 for SMPP.
- Add every Release 19 national locking and single-shift table.
- Add 39 named external Iconvex codecs and all 182 arbitrary table pairings.
- Add exhaustive table, round-trip, ICU differential, lifecycle, and error
  conformance tests.
- Add optimized direct UTF-8 paths and reproducible A/B benchmarks.

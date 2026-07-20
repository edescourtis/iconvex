# Iconvex 0.1.0 release candidate

This directory contains the exact seven Hex package tarballs consumed by
`iconvex_integration/tools/publish_hex.sh`. `manifests/SHA256SUMS` binds every
outer tar; the publisher verifies that manifest, rebuilds every frozen source
tree byte-for-byte, performs all dry-runs, and checks Hex remote state before
any live publication.

`HEX_CHECKSUMS` records each Hex envelope's embedded content checksum.
`artifact_summary.tsv` records the audited unpacked file counts and tree
digests. The release audit passed 2,255 packaged files, 2,093 codecs, 1,050 ICU
archive tables, and 1,841 Specs runtime probes.

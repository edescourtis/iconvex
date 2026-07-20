# OpenJDK MS950-HKSCS-XP quarantine record

This repository-only document records removed research. It is not selected by
the Hex package and is not a support matrix.

The removed generator parsed the MS950 and HKSCS-XP mapping files from OpenJDK
revision `6ae23a0d6574dc8139aea93ea3c562a7410fcb34`. It also inspected
distinctive branches in `MS950_HKSCS_XP.java.template` and `HKSCS.java` and
reproduced the Java HKSCS-override/MS950-fallback order, encoded-row duplicate
priority, and canonical reverse choices in a merged ETF. Repository evidence
did not independently establish those choices, so it did not support the
former LGPL-only provenance claim for the generated asset.

`x-MS950-HKSCS-XP` and former alias `MS950_HKSCS_XP` are not registered or
shipped. The runtime module, importer, generated table, manifest, tests, and
packaged matrix were quarantined and deleted. The exact 8-file
upstream/provenance snapshot remains repository-only under
`priv/sources/openjdk-ms950-hkscs-xp` and is excluded from Hex. Source-set
SHA-256: `1f6d7cd051a9aa511729b9bd289e2b371948688fdfa5ab5e36afc666fb2b3e64`.

This is a conservative factual provenance disposition, not a conclusion about
copyrightability or legal advice.

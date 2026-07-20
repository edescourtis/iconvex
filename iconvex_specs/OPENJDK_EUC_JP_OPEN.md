# OpenJDK EUC-JP-Open quarantine record

This repository-only document records removed research. It is not selected by
the Hex package and is not a support matrix.

The removed generator parsed five standard/Solaris JIS mapping files from
OpenJDK revision `6ae23a0d6574dc8139aea93ea3c562a7410fcb34`. It also inspected
distinctive `EUC_JP_Open.java.template` branches and reproduced the Java
standard-first/Solaris-second routing, `b > 0x7500` plane choice, duplicate
priority, and canonical reverse choices in a merged ETF. Repository evidence
did not independently establish those choices, so it did not support the
former LGPL-only provenance claim for the generated asset.

`x-eucJP-Open` and former aliases `EUC_JP_Solaris` and `eucJP-open` are not
registered or shipped. The runtime module, importer, generated table, manifest,
tests, and packaged matrix were quarantined and deleted. The exact 11-file
upstream/provenance snapshot remains repository-only under
`priv/sources/openjdk-euc-jp-open` and is excluded from Hex. Source-set SHA-256:
`53c246c96937564f32a97dbd77cc6592af1f2298be8c5e5cbba7530711c76d31`.

This is a conservative factual provenance disposition, not a conclusion about
copyrightability or legal advice.

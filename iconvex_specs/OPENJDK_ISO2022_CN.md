# OpenJDK ISO-2022-CN quarantine record

This repository-only record describes removed research. It is not selected by
the Hex package and is not a support matrix.

The former implementation was a source-informed translation of retained
`GPL-2.0-only WITH Classpath-exception-2.0` OpenJDK Java at revision
`6ae23a0d6574dc8139aea93ea3c562a7410fcb34`. Its generator inspected the shared
decoder and distinctive GB2312/CNS encoder branches. It therefore was not
supportable as independently authored LGPL runtime code.

The implementation, importer, generated tables, generated manifests, public
registrations, and packaged documentation are quarantined and not shipped.
The removed canonical names were `x-ISO-2022-CN-GB` and
`x-ISO-2022-CN-CNS`; their former Specs aliases were `ISO2022CN_GB`,
`ISO-2022-CN-GB`, `ISO2022CN_CNS`, and `ISO-2022-CN-CNS`.

The exact 15-file upstream snapshot remains under
`priv/sources/openjdk-iso2022-cn` solely for research and provenance. It is
excluded from Hex. Source-set SHA-256:
`9dd12938d687678bd59fd44bbfdd83a394ada94690d0219e18a7d50cf01e7768`.
This is a factual provenance disposition, not legal advice.

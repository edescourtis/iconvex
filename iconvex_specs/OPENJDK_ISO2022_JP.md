# OpenJDK Microsoft ISO-2022-JP quarantine record

This repository-only record describes removed research. It is not selected by
the Hex package and is not a support matrix.

The former implementation was a source-informed translation of retained
`GPL-2.0-only WITH Classpath-exception-2.0` OpenJDK Java at revision
`6ae23a0d6574dc8139aea93ea3c562a7410fcb34`. Its state machine was ported from
`ISO2022_JP.java`, and its generator inspected distinctive Java branches and
mapping rules. It therefore was not supportable as independently authored LGPL
runtime code.

The implementation, importer, generated tables, generated manifests, public
registrations, and packaged documentation are quarantined and not shipped.
The removed canonical names were `x-windows-50220`, `x-windows-50221`, and
`x-windows-iso2022jp`; their former Specs aliases were `ms50220`, `cp50220`,
`ms50221`, and `windows-iso2022jp`. GNU Core's separate `cp50221` claim is not
part of this quarantine.

The exact 16-file upstream snapshot remains under
`priv/sources/openjdk-iso2022-jp` solely for research and provenance. It is
excluded from Hex. Source-set SHA-256:
`69ec017e91bee35416907eb01a40f2629b6bf1ec79e9643350638252c9604434`.
This is a factual provenance disposition, not legal advice.

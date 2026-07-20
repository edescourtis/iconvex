# OpenJDK source metadata

This source set is pinned byte-for-byte to the official OpenJDK `jdk` repository at revision `6ae23a0d6574dc8139aea93ea3c562a7410fcb34`. Its ordered import aggregate is `1f6d7cd051a9aa511729b9bd289e2b371948688fdfa5ab5e36afc666fb2b3e64`.

Every retained upstream file is repository-only research/provenance evidence and is excluded from the Hex package. OpenJDK's source headers identify applicable code as `GPL-2.0-only WITH Classpath-exception-2.0`; mapping files without a per-file header remain associated with the license bundle shipped by that exact source tree.

The removed generator was source-informed and did not merely normalize independent mapping facts. It parsed the MS950 and HKSCS-XP maps, inspected distinctive fallback branches in `MS950_HKSCS_XP.java.template` and `HKSCS.java`, and reproduced their HKSCS-override/MS950-fallback order, encoded-row duplicate priority, and canonical reverse choices in the shipped merged ETF. No independent source or provenance record in this repository established those choices. The project therefore could not support its former independent-origin / LGPL-only asset claim from repository evidence. The runtime module, generator, table, manifest, registration, and packaged support matrix were quarantined and deleted. This is a conservative factual provenance disposition, not a conclusion about copyrightability or legal advice.

The exact upstream `LICENSE` (GPLv2 plus the Classpath Exception) is SHA-256 `4b9abebc4338048a7c2dc184e9f800deb349366bdf28eb23c2677a77b4c87726`. `ADDITIONAL_LICENSE_INFO` is SHA-256 `a69bce275ba7a3570af6579cb0f55682cd75fedfcd49e0e8e9022270c447c916`. Both were retrieved from the same revision:

- <https://github.com/openjdk/jdk/blob/6ae23a0d6574dc8139aea93ea3c562a7410fcb34/LICENSE>
- <https://github.com/openjdk/jdk/blob/6ae23a0d6574dc8139aea93ea3c562a7410fcb34/ADDITIONAL_LICENSE_INFO>

| Local artifact | Official upstream artifact | SHA-256 | License association |
|---|---|---|---|
| `HKSCS.java` | <https://github.com/openjdk/jdk/blob/6ae23a0d6574dc8139aea93ea3c562a7410fcb34/src/java.base/share/classes/sun/nio/cs/HKSCS.java> | `aca0554d9f784f91076b3a4f4e21e39c362473ff2b6a2b2f94ca8b2ad03ff584` | OpenJDK `LICENSE`; source headers apply the Classpath Exception where stated |
| `MS950.map` | <https://github.com/openjdk/jdk/blob/6ae23a0d6574dc8139aea93ea3c562a7410fcb34/make/data/charsetmapping/MS950.map> | `93dd7d3ecf5b21659c424978bb2acddc758703fa527a079be0cade900cee5eb4` | OpenJDK `LICENSE`; source headers apply the Classpath Exception where stated |
| `MS950_HKSCS_XP.java.template` | <https://github.com/openjdk/jdk/blob/6ae23a0d6574dc8139aea93ea3c562a7410fcb34/src/jdk.charsets/share/classes/sun/nio/cs/ext/MS950_HKSCS_XP.java.template> | `62344cf2d7d3a0cf586f0edd574280f5c96cede0c9a695f131e47c278d058079` | OpenJDK `LICENSE`; source headers apply the Classpath Exception where stated |
| `MS950_HKSCS_XP.map` | <https://github.com/openjdk/jdk/blob/6ae23a0d6574dc8139aea93ea3c562a7410fcb34/make/data/charsetmapping/MS950_HKSCS_XP.map> | `d30585627ae3ec615f21ec5121db9ca5698b699067941bc852a14df96064bc35` | OpenJDK `LICENSE`; source headers apply the Classpath Exception where stated |
| `charsets` | <https://github.com/openjdk/jdk/blob/6ae23a0d6574dc8139aea93ea3c562a7410fcb34/make/data/charsetmapping/charsets> | `f3157c318b916709417738e34e8c008e923dcaec3d49b519b743f89c23b4398f` | OpenJDK `LICENSE`; source headers apply the Classpath Exception where stated |

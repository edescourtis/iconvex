# OpenJDK source metadata

This source set is pinned byte-for-byte to the official OpenJDK `jdk` repository at revision `6ae23a0d6574dc8139aea93ea3c562a7410fcb34`. Its ordered import aggregate is `9dd12938d687678bd59fd44bbfdd83a394ada94690d0219e18a7d50cf01e7768`.

Every retained upstream file is repository-only research/provenance evidence and is excluded from the Hex package. OpenJDK's source headers identify applicable code as `GPL-2.0-only WITH Classpath-exception-2.0`; mapping files without a per-file header remain associated with the license bundle shipped by that exact source tree.

The removed runtime and importer deliberately reproduced OpenJDK-only behavior and checked distinctive decoder and encoder branches, establishing a source-informed translation rather than an independently written implementation. The project resolved that LGPL release blocker: the CN runtime module, importer, generated tables, generated manifests, public registrations, and packaged support matrix were quarantined and deleted. `x-ISO-2022-CN-GB` and `x-ISO-2022-CN-CNS` are not shipped by Specs. This upstream snapshot remains repository-only and is not runtime or generator input. This is a factual provenance disposition, not legal advice.

The exact upstream `LICENSE` (GPLv2 plus the Classpath Exception) is SHA-256 `4b9abebc4338048a7c2dc184e9f800deb349366bdf28eb23c2677a77b4c87726`. `ADDITIONAL_LICENSE_INFO` is SHA-256 `a69bce275ba7a3570af6579cb0f55682cd75fedfcd49e0e8e9022270c447c916`. Both were retrieved from the same revision:

- <https://github.com/openjdk/jdk/blob/6ae23a0d6574dc8139aea93ea3c562a7410fcb34/LICENSE>
- <https://github.com/openjdk/jdk/blob/6ae23a0d6574dc8139aea93ea3c562a7410fcb34/ADDITIONAL_LICENSE_INFO>

| Local artifact | Official upstream artifact | SHA-256 | License association |
|---|---|---|---|
| `ISO2022_CN.java` | <https://github.com/openjdk/jdk/blob/6ae23a0d6574dc8139aea93ea3c562a7410fcb34/src/jdk.charsets/share/classes/sun/nio/cs/ext/ISO2022_CN.java> | `e16c8321eb140df259c7978510a28719ffada1a0b12caaf1769a74679da5c986` | OpenJDK `LICENSE`; source headers apply the Classpath Exception where stated |
| `ISO2022_CN_GB.java` | <https://github.com/openjdk/jdk/blob/6ae23a0d6574dc8139aea93ea3c562a7410fcb34/src/jdk.charsets/share/classes/sun/nio/cs/ext/ISO2022_CN_GB.java> | `743f02a74c9b339c2df03a2682d5cc3f1bea0f18e4457af27caf6717e2b092c2` | OpenJDK `LICENSE`; source headers apply the Classpath Exception where stated |
| `ISO2022_CN_CNS.java` | <https://github.com/openjdk/jdk/blob/6ae23a0d6574dc8139aea93ea3c562a7410fcb34/src/jdk.charsets/share/classes/sun/nio/cs/ext/ISO2022_CN_CNS.java> | `b8ce0a17593349409f93cbfd11f059535605d63651759b05faee005ea1e76301` | OpenJDK `LICENSE`; source headers apply the Classpath Exception where stated |
| `ISO2022.java` | <https://github.com/openjdk/jdk/blob/6ae23a0d6574dc8139aea93ea3c562a7410fcb34/src/jdk.charsets/share/classes/sun/nio/cs/ext/ISO2022.java> | `819083b2f28a0816b68a0f16a60330402226650e45fa15ac73f1ba270dbf3598` | OpenJDK `LICENSE`; source headers apply the Classpath Exception where stated |
| `EUC_CN.map` | <https://github.com/openjdk/jdk/blob/6ae23a0d6574dc8139aea93ea3c562a7410fcb34/make/data/charsetmapping/EUC_CN.map> | `f47e4d6488adfd2e1d5ff5876872afd0720d27daf424390647c6b75a0c60f9c0` | OpenJDK `LICENSE`; source headers apply the Classpath Exception where stated |
| `EUC_TW.map` | <https://github.com/openjdk/jdk/blob/6ae23a0d6574dc8139aea93ea3c562a7410fcb34/make/data/charsetmapping/EUC_TW.map> | `1d2fa625e4dedf5c126368e4458d84b46e984220c26add29b1672361522dcb78` | OpenJDK `LICENSE`; source headers apply the Classpath Exception where stated |
| `EUC_TW.nr` | <https://github.com/openjdk/jdk/blob/6ae23a0d6574dc8139aea93ea3c562a7410fcb34/make/data/charsetmapping/EUC_TW.nr> | `3295e47d60391ce840233c14986f9dabbd186a985f145a24cd9be8c9f6b17013` | OpenJDK `LICENSE`; source headers apply the Classpath Exception where stated |
| `EUC_TW.java.template` | <https://github.com/openjdk/jdk/blob/6ae23a0d6574dc8139aea93ea3c562a7410fcb34/src/jdk.charsets/share/classes/sun/nio/cs/ext/EUC_TW.java.template> | `5ca6a0f2b864b2ae79f4191aee7145c60e8201529851aacf54af0a8d2f458eab` | OpenJDK `LICENSE`; source headers apply the Classpath Exception where stated |
| `EUC_TWGenerator.java` | <https://github.com/openjdk/jdk/blob/6ae23a0d6574dc8139aea93ea3c562a7410fcb34/make/jdk/src/classes/build/tools/charsetmapping/EUC_TW.java> | `adf9dbe65b64b796a66ae62a651402f869bf798474979dc61c146fbd69b29337` | OpenJDK `LICENSE`; source headers apply the Classpath Exception where stated |
| `DBCS.java` | <https://github.com/openjdk/jdk/blob/6ae23a0d6574dc8139aea93ea3c562a7410fcb34/make/jdk/src/classes/build/tools/charsetmapping/DBCS.java> | `6ac55281e6bc2ba131425d123acae0518bf8e6ace888e9d745b9352ba9e57982` | OpenJDK `LICENSE`; source headers apply the Classpath Exception where stated |
| `DoubleByte.java` | <https://github.com/openjdk/jdk/blob/6ae23a0d6574dc8139aea93ea3c562a7410fcb34/src/java.base/share/classes/sun/nio/cs/DoubleByte.java> | `e6286e1a9b9dabc55863dc2a5d134db6b0c82a09ea3dac573d622f8a7c91729e` | OpenJDK `LICENSE`; source headers apply the Classpath Exception where stated |
| `charsets` | <https://github.com/openjdk/jdk/blob/6ae23a0d6574dc8139aea93ea3c562a7410fcb34/make/data/charsetmapping/charsets> | `f3157c318b916709417738e34e8c008e923dcaec3d49b519b743f89c23b4398f` | OpenJDK `LICENSE`; source headers apply the Classpath Exception where stated |

`EUC_TWGenerator.java` is an unmodified local rename of upstream `make/jdk/src/classes/build/tools/charsetmapping/EUC_TW.java`; its digest above proves the identity.

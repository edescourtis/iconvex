# Iconvex integration TDD log

## Cycle 1 — provenance-quarantine release cardinalities

- RED changed the checkout and full-stack executable expectations first. The
  focused selection failed on the stale 2,100 full-stack and 1,848 Specs prose
  and audit-tool claims while the runtime registry already derived 2,093 names.
- GREEN binds the current checkout probes to 2,093/2,093 full-stack codecs and
  1,841/1,841 runtime Specs encode/decode checks. All six extension start
  orders retain the same registry snapshot; the focused integration selection
  passes 16/16 with warnings as errors.
- Exact recursively packaged file counts and package digests remain deferred to
  the final frozen-tree artifact-audit rebind; this cycle does not rewrite
  historical evidence snapshots.

## Cycle 2 — quarantined top-level release evidence

- RED expanded the exact repository-only allowlist to the four OpenJDK support
  documents created by the seven-codec LGPL quarantine. Both focused contracts
  failed against the stale two-file allowlist and 91-file evidence claim.
- GREEN names all six repository-only Specs documents explicitly and derives
  the corrected 87 byte-identical packaged release-evidence files. This changes
  no runtime selection: the four OpenJDK documents and their GPL-plus-Classpath
  source snapshots remain available only in the repository, outside Hex.

## Cycle 3 — exact Hex metadata boundary

- RED required the reusable audit to consume the same seven tarballs as the
  unpacked consumer and failed because it only checked unpacked file trees.
  A second RED required every repository-only exception to be proven present
  in the workspace and absent from its artifact.
- GREEN validates the exact four-file Hex v3 envelope and its SHA-256 inner
  checksum, delegates malformed metadata to Hex's atom-safe parser, and
  compares package name, app, version, repository, optional flag, and every
  `~> 0.1.0` requirement against a seven-package literal contract before
  applications start. Every inner tar path and byte is also bound to the
  separately supplied unpacked root, preventing a different self-consistent
  tar from borrowing its evidence. The source/artifact exception boundary is
  now executable rather than implicit.

## Cycle 4 — single-snapshot tar parsing and adversarial fixtures

- RED added behavioral package fixtures before changing the audit helper. The
  focused run failed on the absent single-read contract and absent
  tar-to-unpacked-root verifier; the valid Extras fixture expectation was then
  corrected to preserve its actual package name before implementation.
- GREEN reads each `.tar` exactly once and supplies that immutable binary to
  both the outer-envelope validator and Hex's official atom-safe parser. The
  same reusable verifier now binds every inner path and byte to the separately
  unpacked artifact root.
- The focused 19/19 test run executes valid Core and Extras envelopes, corrupt
  checksum rejection, duplicate outer and inner path rejection, unknown-atom
  rejection without atom interning in a monitored subprocess, and counterfeit
  payload/root rejection. These malformed-input guarantees are no longer
  inferred only from source markers.

## Cycle 5 — final seven-package tree rebind

- A measurement-only Hex build established the final package boundary after
  the deep-dive, coverage, benchmark, provenance, and parser-hardening cycles.
  RED changed the exact audit contract first and failed 3/19 against the stale
  aggregate count, per-package counts/digests, and README claim.
- GREEN binds the audit to 2,258 recursively packaged files: Core 127, Extras
  99, Specs 910, each archive shard 356, and Telecom 54. Every SHA-256 tree
  digest is derived from sorted relative paths, path/content byte lengths, and
  exact contents; the clean-consumer run additionally binds these trees to the
  same seven checksum-valid Hex tar snapshots.

## Cycle 6 — quarantine-clean Specs artifact rebind

- The complete Specs regression exposed four zero-byte OpenJDK runtime-source
  remnants and its existing quarantine tests failed before their deletion.
  Removing them made the prior measured artifact intentionally stale. RED then
  changed the integration expectations first and failed 3/19 on the obsolete
  Specs file count/digest and aggregate claim.
- GREEN binds the quarantine-clean Specs package at 906 files and the complete
  seven-package boundary at 2,254 files. The new Specs digest covers its final
  959/959-tested source tree and proves that none of the four forbidden runtime
  paths is present in the checksum-valid tar payload.

## Cycle 7 — directory/file-prefix ordering parity

- The first real clean-consumer audit failed before application startup because
  Hex returns its file map in global path order while the recursive artifact
  walker visits a directory before a sibling file sharing its prefix. RED made
  that exact `lib/iconvex/` versus `lib/iconvex.ex` shape executable and failed
  1/1 despite the two sets and every byte being identical.
- GREEN globally sorts the artifact path list only for tar/root set comparison;
  the separately pinned tree-digest traversal remains unchanged. The same test
  still exercises counterfeit-byte rejection after the ordering check.

## Cycle 8 — Core GPL notice release-boundary audit

- RED expanded the clean-consumer repository-only contract first. The focused
  release-evidence test failed 1/1 because the auditor named only Specs'
  quarantined documents and did not independently prove that Core's retained
  `LICENSE.GPL-3.0` test-source notice stays outside its LGPL Hex artifact.
- GREEN adds the Core notice to the executable repository-only map and updates
  the release-boundary documentation. The focused contract passes 1/1: the
  audit now requires the notice in the workspace and rejects it from the
  package without changing the 87-file packaged evidence cardinality.

## Cycle 9 — final frozen seven-artifact rebind

- A fresh build and independent unpack of all seven Hex tarballs made the prior
  release snapshot naturally RED before any expectation changed: the unchanged
  clean-consumer audit stopped at its stale 87-file evidence boundary because
  the packaged neutral Unicode-signature profile raises the executable total to
  88. Measurement also showed the intended GPL-only test-notice exclusion moves
  Core from 127 to 126 files, while the signature-profile evidence moves Specs
  from 906 to 907; the seven-package total remains 2,254.
- RED changed only the executable contract first. The focused run failed 2/2
  against the old evidence cardinality and old Core, Extras, and Specs tree
  pins. GREEN binds Core to
  `3fa5917d75a16f7cb128dbf059bba4962e0d5ca6b9260be19bbd5ea21393bb2e`,
  Extras to
  `1ce2d99ef52f6dc5c858757f44a7d941feda2ba24462e5220a9bd2f92dc28b6a`,
  and Specs to
  `0327dd077659c07ca42de6cdc54ae6586cb851cb2b356d98b2d5a5c083cf6bcd`;
  the three archive and Telecom pins remain unchanged. The focused contract
  then passes 2/2.
- The final clean consumer passes in 10.80 seconds: 7/7 exact dependency roots
  and Hex metadata/checksum/payload contracts, 88/88 byte-identical release
  evidence files, 2,254/2,254 recursively pinned package files, 2,093/2,093
  full-stack codecs, 25/25 exhaustive GNU/RFC collision migrations, 16/16
  provenance helpers, 1,050/1,050 archive tables, and 1,841/1,841 Specs runtime
  codec checks. No source package was rebuilt after this artifact freeze.

## Cycle 10 — aggregate workflow discovery (review Cycle 122)

- RED required the combined checkout's Git repository root to contain a
  GitHub-discoverable workflow, with explicit Core compatibility, package
  working-directory, warning-clean compilation, test, release, and
  documentation contracts. The focused test failed 1/1 because the only
  workflow lived under the standalone Core package. Its log SHA-256 is
  `64a4e28e4bcdc369153d7d6acb7433f7287ab30816ae19ca35a1623ba53db0b3`.
- GREEN adds the aggregate-root workflow without removing Core's independent
  workflow. Its matrix names all seven non-Core sibling roots, applies the
  checkout-only Core/archive paths, and runs each command from the package it
  validates. The focused contract passes 1/1; its log SHA-256 is
  `3bebf2b4e0bde5c7ce95a7d545bfeda735b033d7a7da1511cd6b30e6a80b059c`.

## Cycle 11 — generator reproducibility and support-document authority

- RED first required a deterministic, non-mutating support-document report
  mode and failed 1/1 because the registry generator accepted only a full
  destructive regeneration. The log SHA-256 is
  `677775d5545c5a3358d8f80d9d6a0b16613bfe6354e7eae9baed6f1b00e8723a`.
  A subsequent isolated full run exposed that the generator would also remove
  the shipped ISO-2022-JP-3 streaming callbacks. The expectation-first focused
  contract failed 1/1; its log SHA-256 is
  `9f82cb0e8e7d17e8d945bc8caf79b567183bf36dfe4d6c4d140c55e6bbdf1864`.
- GREEN gives the report mode one pure document renderer, removes the obsolete
  Core `ISO-IR-180` alias, retains equivalent generated terms/source across OTP
  serializer and map-order differences, and makes the ISO-2022-JP-3 stream
  surface part of its generation template. The final focused file passes 2/2
  from a fresh build; its log SHA-256 is
  `eadf304541925e366bbf37b31961af590fc6014f51763d13a6406baa217aafc9`.
  Two complete GNU libiconv 1.19 regenerations left the same 205 generated
  source/table/document files byte-identical to baseline. All three sorted
  manifests have SHA-256
  `dc2cff6f1072b4302ad172399acfd264414e8820e1869d3ee444da11a2c74678`,
  and the generated registry still contains no `ISO-IR-180` binding.

## Cycle 12 — warning-clean aggregate documentation

- RED added the aggregate-workflow expectation first and failed 1/1 because
  the Core documentation job still invoked plain `mix docs`.
- GREEN changes only that job's command to
  `mix docs --warnings-as-errors`. The focused aggregate-workflow contract
  passes 1/1, so documentation warnings now fail the root-discovered CI job.

## Cycle 13 — final seven-artifact evidence rebind

- A fresh seven-package Hex build made the unchanged clean-consumer audit RED
  at Core's stale 126-file boundary: the artifact now contains 127 files. The
  expectation-first checkout contract then failed 3/19 against the old tree
  pins and 2,254-file documentation.
- GREEN binds the measured trees to Core 127/
  `64b246b3a03ddad461644577ea3fd3a29594b9a6fceb0404d6499d9698732734`,
  Extras 99/
  `e036c1545b96559ed8dd7e2078c6c3265ecb6ea9ae1556ae2d544c5b86ac48d1`,
  Specs 907/
  `c151bea23a9cbf930c69eddefbcf28ef231dc209e790cf51b58b71c3e8c885f1`,
  and Telecom 54/
  `8179e16b2c910c0ab99389e65b23081838c538483e9795f7456445c3cfdf336a`;
  the measured 356-file archive shard pins remain unchanged. The focused
  checkout contract passes 19/19.
- The clean consumer compiles all seven unpacked artifacts with warnings as
  errors and passes the complete audit: 7/7 exact roots and Hex metadata,
  88/88 byte-identical release-evidence files, 2,255/2,255 recursively pinned
  files, 2,093/2,093 codecs, 1,050/1,050 archive tables, and 1,841/1,841 Specs
  runtime encode/decode probes.

## Cycle 14 — post-audit artifact rebind

- The final README and GNU-evidence-gate fixes changed only packaged Specs and
  Telecom evidence bytes. A fresh seven-tarball build kept all file counts and
  the 88-file release boundary unchanged; the old audit was RED on Specs'
  stale digest. The expectation-first checkout contract then failed exactly
  1/19 against the two old tree pins.
- GREEN binds Specs 907 files to
  `88956f9b5c1540ab4b0eabdadb9680457ad56a25d6d56d7bd05d770d5c06fd7e`
  and Telecom 54 files to
  `602214eba68250e0ead656f74abd58dc75bed3f2970e17ec1cd26848c5be25cd`;
  every other count and digest remains unchanged. The focused checkout file
  passes 19/19.
- The exact clean consumer compiles warning-free and the complete audit passes:
  7/7 roots and Hex metadata, 88/88 release-evidence files, 2,255/2,255
  recursively pinned files, 2,093/2,093 codecs, 1,050/1,050 archive tables,
  and 1,841/1,841 Specs runtime probes.

## Cycle 15 — aggregate formatting gates

- RED extended the root-workflow contract to require exactly two
  `mix format --check-formatted` steps: one for Core and one under the sibling
  package matrix. The focused test failed 1/1 because the workflow had neither;
  its log SHA-256 is
  `105821568d13db545cf98108283f8fdd3d0c35d47e473c5393ac6783b7fc630f`.
- GREEN adds both formatting gates before compilation/documentation. The
  focused aggregate-workflow contract passes 1/1; its log SHA-256 is
  `765c8b9b0f42c12514db6998f932c6e74866ccf02772b73141a0c04511d09771`.

## Cycle 16 — immutable aggregate dependency locks

- RED rejected every bare `mix deps.get` command in the root-discovered
  workflow. The extension matrix still used one, so the focused contract failed
  1/1; its log SHA-256 is
  `dc0f030aeb0d94e8e2b41c920eac180777426e09e35f45138c6b7b3bb7e27cd3`.
- GREEN changes the extension matrix to `mix deps.get --check-locked`, matching
  Core and documentation jobs. The focused workflow contract passes 1/1; its
  log SHA-256 is
  `c02bdd9065dab832c715c9043da29fafae9585efa177379aae7744b8b17ae533`.

## Cycle 17 — final shipping-artifact rebind

- RED built the exact seven 0.1.0 Hex tarballs and unpacked payloads after the
  final recovery, evidence, and coverage cycles, then changed the
  expectation-first checkout contract to their measured trees. The audit still
  contained the preceding candidate's pins, so the focused file failed exactly
  1/19; its log SHA-256 is
  `29df67af28e9e702e069e937c76be5b3faa7f51ddd315914abe05aac5999557a`.
- GREEN binds Core 127 files to
  `67b3690eb6f7be0fce51929ebdc87ad8cd141c7c1534bb38b23ae6930e2bc61a`,
  Extras 99 to
  `d3448cbba3b1732672082080dc21e21e7f2e6f62c9354feb9fb25b25bc8d35f8`,
  Specs 907 to
  `65869e41467f99172819dd0ba1343a389df9ce8ece1b98e55c67719c63f12883`,
  and Telecom 54 to
  `000c50bcbb42bd94def87e078620c834cc985a90a62466f55d622290acaa4066`;
  the three 356-file archive shard pins remain unchanged. The focused checkout
  contract passes 19/19; its log SHA-256 is
  `363505a65acb9b3d4c387f698c804df5afd013016619fb85ec834db27f01a6d4`.
- A standalone production consumer compiles every unpacked artifact with
  warnings as errors; its log SHA-256 is
  `dd1c58d345677ef320c49566201820b828df9e75f712d3a7d1fecd2ee07c6ca5`.
  The complete audit passes 7/7 roots and Hex metadata, 88/88 byte-identical
  release-evidence files, 2,255/2,255 recursively pinned files, 2,093/2,093
  codecs, 1,050/1,050 archive tables, and 1,841/1,841 Specs runtime probes; its
  log SHA-256 is
  `357e5c8778ce9d8b6563345b492e01ace5d7a5d7a42f7a150467bf395be249cb`.
- Explicit formatting and the complete checkout integration suite pass 25/25;
  the final log SHA-256 is
  `1dcc3791081b6edc89443eedda502d4cbf157b2558f232708bfe1b3cecadeb26`.

## Cycle 18 — guarded seven-package Hex publisher

- RED added the executable publisher contract before its implementation. All
  7 focused tests failed because `tools/publish_hex.sh` did not exist; the log
  SHA-256 is
  `c64b8aafc92a265facfb784d2068a82ca16905a05f6686198074a80ab7a75f25`.
- GREEN adds a strict-mode publisher whose default is mutation-free. It pins
  Elixir 1.19.5/OTP 28, verifies the authenticated Hex user is
  `eric.descourtis`, checks all source projects are exactly version 0.1.0,
  validates all seven candidate tarball hashes against the final
  `SHA256SUMS`, rebuilds byte-identical source artifacts, and completes every
  `mix hex.publish package --dry-run --yes` preflight in dependency order
  before any live operation is possible.
- Live publication requires both `--publish` and the exact typed confirmation
  (or its exact environment opt-in), then invokes only the seven source
  packages in dependency order. Integration is excluded. GitHub links, when
  present in package metadata, must resolve to `edescourtis/iconvex`. The
  contract proves wrong-user, checksum, metadata, and missing-confirmation
  failures publish nothing.
- The focused contract passes 7/7; its log SHA-256 is
  `957ac4810b2732d4a50b61c45e683222043e13e0f1a00cb1631c5eb4b69fed13`.
  `bash -n`, ShellCheck, and focused Elixir formatting also pass. No live Hex
  publication was executed. The complete Integration suite passes 32/32; its
  log SHA-256 is
  `7cfda6ebc93b2556a6f1a799ef2104fd40b050e05d360e2f9078c1ca44d102bc`.

## Cycle 19 — immutable publish source and pinned Hex transport

- RED extended the publisher contract before changing the script. The focused
  run failed 10/11, covering the missing source freeze, per-package live
  rebuild, pinned candidate-manifest digest, Hex 2.2.1 check, secured Hex API
  environment, portable Erlang-bin fixture, build-mismatch injection, and Nth
  dry-run failure injection. Its log SHA-256 is
  `6e90be11911dd291568c63b3d66b98c9029a6158888a5bad6cd2b8ac977a5daa`.
- GREEN freezes each package through `mix hex.build --unpack` into an isolated
  temporary workspace before candidate checksum verification. Metadata
  probes, candidate rebuilds, all dry-runs, and every live command use only
  those frozen trees. Symbolic links in a frozen tree fail closed, so later
  edits to the original workspace cannot alter an upload.
- The script pins Hex 2.2.1, `https://hex.pm/api`, safe HTTPS and registry
  verification settings, and the candidate `SHA256SUMS` digest. Before each
  live operation it rebuilds that package from the frozen tree and compares
  the artifact to the manifest immediately before invoking
  `mix hex.publish package --yes`.
- Failure-injection contracts prove both a frozen build mismatch and failure
  of the fourth dry-run yield zero publish invocations. The focused contract
  passed 11/11; its log SHA-256 is
  `33ab0e336d43f4b78879e645105be9a32eab5ba26f48a4d4c0232cfae0dd4ab9`.

## Cycle 20 — fail-closed authoritative repository metadata

- RED required every frozen package to expose both an exact Mix
  `source_url` and at least one exact package link to
  `https://github.com/edescourtis/iconvex`. Missing and conflicting URL cases
  produced 5 expected failures in the 14-test focused run; its log SHA-256 is
  `7e31f8adeb18cb01565b1cb10eba1fc0cf61cb8ab7cc91cbfe21d8c0398d0953`.
- GREEN makes both repository metadata checks mandatory. Missing, blank,
  alternate, slash-normalized, or `.git`-normalized values no longer pass.
  Each rejection is proved to occur before any dry-run or live publish.
- The final focused publisher contract passes 14/14; its log SHA-256 is
  `ff28fec0eeca8a28d37c6c7b0406e5ec9d5715e29bbe55e21b163b7c4248166f`.
  `bash -n`, ShellCheck, and formatting pass. The complete Integration suite
  passes 41/41; its log SHA-256 is
  `b1fd60811bc115e233e5ee1492461f24b8840b2fc9a342a3538a64b00350bac7`.
- A real default-mode run froze all seven production sources, verified the
  pinned candidate manifest, then stopped at the Hex owner gate because the
  host has no authenticated Hex user. It executed no dry-run or live publish;
  the diagnostic log SHA-256 is
  `72550e69bea3e486315d66335475fcee7fc218ba88e7222b3fc8dba11ecc5c39`.
  No live Hex publication was executed.

## Cycle 21 — all-package Hex API mutation barrier and resumable publishing

- RED added fake-API expectations before the publisher changed. The focused
  contract failed because the script had no Hex API boundary and an injected
  `iconvex_extras` ownership collision still exited successfully. New cases
  cover absent packages, ownership collision, existing-release checksum and
  publisher mismatch, an exact resumable release, a later API failure, and
  post-publish publisher readback.
- GREEN pins every read to `https://hex.pm/api`, collects both package and
  0.1.0 release responses for all seven packages before validating any of
  them, and therefore performs zero publication when even the final remote
  state is unavailable or invalid. Existing releases are skipped only when
  package owner, release publisher, and Hex API checksum all match exactly.
- The API checksum is explicitly compared with the candidate's complete outer
  tar SHA-256 from the pinned manifest; it is not confused with the different
  `CHECKSUM` member embedded inside a Hex tar. Every newly published package is
  read back through both API endpoints and verified before dependency-order
  publication continues. Default mode performs only local operations and
  authenticated/read-only HTTP GETs; no live Hex write was executed.
- The focused fake-API contract passes 20/20; its log SHA-256 is
  `a10b5e54dc95598420e7cb1bc80f146a263271d78ecbd93518e576347b3d0419`.
  `bash -n`, ShellCheck, and focused formatting pass. The complete Integration
  suite passes 48/48; its log SHA-256 is
  `95e45dd6b673a8c197ca624d0415c67d991fc8c578dfaced5461e525af076d7f`.

## Cycle 22 — authoritative GitHub source metadata

- RED introduced the repository-metadata contract before the seven package
  manifests exposed their public monorepo. The initial aggregate run failed on
  the missing exact `https://github.com/edescourtis/iconvex` source metadata;
  its recorded log SHA-256 begins `920bd343`. A second expectation required the
  same exact `GitHub` link inside every built Hex tar and made the three-test
  contract RED; that log SHA-256 begins `ead119bf`.
- GREEN binds all seven Mix projects to the exact public source URL, pins Core
  ExDoc links to `v0.1.0` under the `iconvex/` monorepo directory, and makes the
  artifact audit reject a missing or different Hex `GitHub` link. The final
  3/3 metadata contract log SHA-256 is
  `923b2497f2302810f43902530d1aab3ce7109691a7d91f30bfaac4b16090362a`.

## Cycle 23 — immutable 2026-07-20 shipping candidate

- RED changed the expectation-first checkout contract to the freshly measured
  2026-07-20 package trees while the audit still carried the preceding pins;
  its recorded log SHA-256 begins `d14f5704`.
- GREEN binds the 2,255-file artifact boundary to Core 127 files, Extras 99,
  Specs 907, Telecom 54, and 356 files in each archive shard. The focused
  checkout contract passes 19/19; its final seed-zero log SHA-256 is
  `1cb3b1f7411784225eb4701d8ecd33ea00f3ebe69b4e06b352f81df7072b2103`.
- The exact seven-tar `SHA256SUMS` digest is
  `20952bda49efd909ec11b761d66d079e2a9563b41124c5b3099d36458f6a7636`.
  A clean production consumer compiles all seven unpacked packages with
  warnings as errors; its log SHA-256 is
  `c1a9dc979af7b8719912a25a9918f81a40279917537ebddf7e7637f4f7b21997`.
  The complete artifact audit again passes 7/7 roots, 88/88 evidence files,
  2,255/2,255 packaged files, 2,093/2,093 codecs, 1,050/1,050 archive tables,
  and 1,841/1,841 Specs probes; its log SHA-256 is
  `357e5c8778ce9d8b6563345b492e01ace5d7a5d7a42f7a150467bf395be249cb`.

## Cycle 24 — publisher bound to the final candidate

- RED changed the publisher contract first to require the 2026-07-20 release
  root and exact manifest digest. The focused contract failed 1/1 against the
  preceding pin; its log SHA-256 is
  `2a28a6af61d7544d3e8d7746379f75742bd84ebfeaaefba150cb5e84eac61d54`.
- GREEN changes only the script's immutable candidate root and manifest pin.
  The focused contract passes 1/1; its log SHA-256 is
  `374bf2646037342bc629bb6ba9e38eed37dbcae549ccfabc63e1e6780c3f126a`.
  No live Hex publication was executed.

## Cycle 25 — persistent, portable release inputs

- RED replaced the ephemeral release-root expectation first. The focused
  publisher contract failed 1/1 while the script still named a `/private/tmp`
  candidate; its log SHA-256 is
  `c362cd64ac761f11fcdad23a6c6b97b91b9b5c5e09ca9484e37aa2ba8a6dae86`.
- GREEN derives `iconvex_release_0.1.0` from the script-discovered workspace,
  preserving the same exact seven-tar manifest digest. The focused contract
  passes 1/1; its log SHA-256 is
  `7c7c75bc98518e97acfc3120f1c2faf2256d0175bc46cf65becb243d16f66b7d`.
- A second RED expectation rejected host-specific `/Users/...` toolchain
  paths and required ASDF discovery through `ASDF_DATA_DIR` or `$HOME/.asdf`.
  The focused failure log SHA-256 is
  `3427dece632ffd91caaebd8930586efd73a2d5fa91e2693ef48eb8845d7b2c50`.
- GREEN keeps the exact Elixir 1.19.5/OTP 28.3 pins while making their ASDF
  installation root portable. The focused contract passes 1/1; its log
  SHA-256 is
  `fb9d74b70ea0ee3aa7f588e8c9fdd38d8745a3c1e857610a0bbe489b9028c0c6`.
  `bash -n` and ShellCheck pass. No live Hex publication was executed.

## Cycle 26 — portable publisher temporary workspace

- RED extended the publisher contract first to reject the macOS-only
  `/private/tmp` fallback and require `${TMPDIR:-/tmp}`. The focused contract
  failed 1/1; its log SHA-256 is
  `37e68caf2001b04c632f0bdd6520056a82e10ad9ba517cbc0e7d4a9eb7275b3a`.
- GREEN changes the isolated preflight fallback to POSIX `/tmp`, while still
  honoring an explicit `TMPDIR`. The focused contract passes 1/1; its log
  SHA-256 is
  `c57cd7e7c74e3ee4cad12a8ab55bcff464eaa0ad2b012af5d3d4face4bc192bd`.
  `bash -n` and ShellCheck pass. The complete final Integration suite passes
  48/48; its log SHA-256 is
  `49100dd07ae35498748938b48fb53820d0c80053267a7ff1d8438ed338328b5a`.
  A real default run then verified the persistent manifest and all seven exact
  repository metadata contracts before stopping at the host's missing Hex
  authentication; its log SHA-256 is
  `5710203237f85a13198b846a7e82cc9073c2f72cc89328c355111583a24cdd4a`.
  No dry-run or live Hex publication was executed.

## Cycle 27 — aggregate CI measurement isolation

- RED used the first public GitHub Actions run to exercise the aggregate
  workflow on clean Linux workers. Integration had no formatter inputs;
  Extras and Telecom completed all 134 and 163 behavioral tests before their
  package-wide 90% coverage thresholds rejected 61.69% and 79.25%; and OTP 26
  cover instrumentation distorted an absolute reduction measurement and made
  a global atom-count assertion order-sensitive. The first expectation-first
  workflow contract failed 2/2 with log SHA-256
  `7e5f66370db2e6b2dbea5a524de4f6bfae28097b1d64196c5bdbe9018a2d87ae`.
- A second RED required compatibility tests to run uninstrumented on every OTP
  pair and coverage to be enforced once on OTP 28. The unchanged workflow
  failed 1/2; its log SHA-256 is
  `3e6a0004faee328d9a5b63daf7223ba4ddd70ff22556bb26fea7718f79ec3e8c`.
- GREEN defines Integration formatter inputs, runs every extension and
  Integration suite with deterministic seed zero, runs the complete Core suite
  uninstrumented on the OTP compatibility matrix, and adds a dedicated OTP 28
  coverage job. The focused contract passes 2/2; its log SHA-256 is
  `ae0191ee4fc9dc0af6aec34b90909eceac98798f8840d701091112f23c77aad1`.
- Final review required the Integration formatter to include its own config.
  That expectation failed 1/2 before implementation and then passed 2/2 with
  RED/GREEN log SHA-256 values
  `72a641edca024c05fd088fb5f112f844d811a3d6281eeb5e2b2507c7bd569383`
  and `740d6c8cda10f8ded6da0fb5b9a578e6ab7de313f59bb7555732ffdee5891d48`.
- The replacement clean-Linux run then exposed that setup-beam's exact OTP
  28.0 release prints a Regex recompilation warning to generated-document
  stdout. An expectation first rejected every `28.0` pin and required all five
  OTP 28 jobs to use the publisher baseline, OTP 28.3. The focused RED/GREEN
  log SHA-256 values are
  `7e136e257fcf35ae998a208c89f7d01c633fcf6d83b3dc46de174294b64bae98`
  and `b7810fdcf3549b96db782a12258b81f95e077b6b10f0c9358d0088b83f2209a4`.
- Exact local workflow commands pass Integration 49/49, Core compatibility
  623/623, and Core coverage 623/623 at 93.30%. Their log SHA-256 values are
  `02e205d35ba18d06bfff25803365d67393626a398625ebe952e2a509b310865f`,
  `ebf5b29ad88f129c4944c0d09492f5e468c39a247e8ce5154c280c2fa473ba09`,
  and `f092e95f1a0c337d9932c493b17fec8239eb44957297ef8ce9c2fc12779f44f9`.
  Core sources, tests, saved evidence, and all seven frozen Hex artifacts remain
  byte-identical.

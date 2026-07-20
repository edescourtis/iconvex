#!/usr/bin/env elixir

Code.require_file("artifact_audit_support.exs", __DIR__)

assert! = fn condition, message ->
  unless condition, do: raise(message)
end

artifact_apps = [
  :iconvex,
  :iconvex_specs_icu_archive_a,
  :iconvex_specs_icu_archive_b,
  :iconvex_specs_icu_archive_c,
  :iconvex_specs,
  :iconvex_extras,
  :iconvex_telecom
]

artifact_versions = %{
  iconvex: "0.1.0",
  iconvex_specs_icu_archive_a: "0.1.0",
  iconvex_specs_icu_archive_b: "0.1.0",
  iconvex_specs_icu_archive_c: "0.1.0",
  iconvex_specs: "0.1.0",
  iconvex_extras: "0.1.0",
  iconvex_telecom: "0.1.0"
}

expected_github_url = "https://github.com/edescourtis/iconvex"

artifact_requirements = %{
  iconvex: [],
  iconvex_extras: [{"iconvex", "iconvex", "~> 0.1.0", false, "hexpm"}],
  iconvex_specs_icu_archive_a: [{"iconvex", "iconvex", "~> 0.1.0", false, "hexpm"}],
  iconvex_specs_icu_archive_b: [{"iconvex", "iconvex", "~> 0.1.0", false, "hexpm"}],
  iconvex_specs_icu_archive_c: [{"iconvex", "iconvex", "~> 0.1.0", false, "hexpm"}],
  iconvex_specs: [
    {"iconvex", "iconvex", "~> 0.1.0", false, "hexpm"},
    {"iconvex_specs_icu_archive_a", "iconvex_specs_icu_archive_a", "~> 0.1.0", false, "hexpm"},
    {"iconvex_specs_icu_archive_b", "iconvex_specs_icu_archive_b", "~> 0.1.0", false, "hexpm"},
    {"iconvex_specs_icu_archive_c", "iconvex_specs_icu_archive_c", "~> 0.1.0", false, "hexpm"}
  ],
  iconvex_telecom: [{"iconvex", "iconvex", "~> 0.1.0", false, "hexpm"}]
}

artifact_tree_expectations = %{
  iconvex: {127, "05a5f29bed880647d9ddc3533f03541352d3ae24021d16d0f2e607395fc51a12"},
  iconvex_extras: {99, "87f86a956d1fbe920423fd30d95bb04e66f57ff10d5a276335c812c0bf302001"},
  iconvex_specs: {907, "712624b2fcd1aa350addb151878534f3d3e87f05801340c4be0357872b053eaf"},
  iconvex_specs_icu_archive_a:
    {356, "a4d4265674625e01d242080a163a0bfef17aa77e7147fe6855c8d0f48e644ff3"},
  iconvex_specs_icu_archive_b:
    {356, "435b590156286597f2657ee78dfabd87fef7984c90eb56b5a971906fa23e300a"},
  iconvex_specs_icu_archive_c:
    {356, "e7d6671a8f4a3535e4cacb6828b95d1bf2e670c5b71e877e73b4ee622194c3c9"},
  iconvex_telecom: {54, "45a87a227fa6ef56c29e6123f3193d0ed90c0459fbcf9a4f32940a948f68bc86"}
}

repository_only_top_level = %{
  iconvex: ["LICENSE.GPL-3.0"],
  iconvex_specs: [
    "ICU_SWAP_LFNL_DIFFERENTIAL.md",
    "OPENJDK_ENCODINGS.md",
    "OPENJDK_EUC_JP_OPEN.md",
    "OPENJDK_ISO2022_CN.md",
    "OPENJDK_ISO2022_JP.md",
    "UTF8_MAC.md"
  ]
}

artifact_root = System.fetch_env!("ICONVEX_ARTIFACT_ROOT") |> Path.expand()
workspace_root = System.fetch_env!("ICONVEX_WORKSPACE_ROOT") |> Path.expand()

assert!.(
  File.lstat!(artifact_root).type == :directory,
  "artifact root is not a real directory: #{artifact_root}"
)

assert!.(
  File.lstat!(workspace_root).type == :directory,
  "workspace root is not a real directory: #{workspace_root}"
)

dependency_paths = Mix.Project.deps_paths()

assert!.(
  Map.keys(dependency_paths) |> Enum.sort() == Enum.sort(artifact_apps),
  "artifact dependency keys differ from the exact seven-package set"
)

validated_roots =
  Map.new(artifact_apps, fn app ->
    version = Map.fetch!(artifact_versions, app)
    dependency_path = dependency_paths |> Map.fetch!(app) |> Path.expand()
    expected_path = Path.join(artifact_root, "#{app}-#{version}")
    workspace_path = Path.join(workspace_root, Atom.to_string(app))

    assert!.(
      dependency_path == expected_path,
      "#{app} resolved outside its exact unpacked artifact root: #{dependency_path}"
    )

    assert!.(
      File.lstat!(dependency_path).type == :directory,
      "#{app} artifact dependency root is not a real directory: #{dependency_path}"
    )

    assert!.(
      File.lstat!(workspace_path).type == :directory,
      "#{app} workspace source root is not a real directory: #{workspace_path}"
    )

    {app, {dependency_path, workspace_path}}
  end)

tarball_root = System.fetch_env!("ICONVEX_TARBALL_ROOT") |> Path.expand()

assert!.(
  File.lstat!(tarball_root).type == :directory,
  "tarball root is not a real directory: #{tarball_root}"
)

expected_tarball_names =
  Enum.map(artifact_apps, fn app -> "#{app}-#{Map.fetch!(artifact_versions, app)}.tar" end)
  |> Enum.sort()

assert!.(
  File.ls!(tarball_root) |> Enum.sort() == expected_tarball_names,
  "Hex tarball set differs from the exact seven-package set"
)

release_evidence_file? = fn name ->
  name in ["NOTICE", "mix.exs"] or String.ends_with?(name, [".md", ".csv"])
end

release_evidence_names = fn directory ->
  directory
  |> File.ls!()
  |> Enum.filter(fn name ->
    release_evidence_file?.(name) and File.regular?(Path.join(directory, name))
  end)
  |> Enum.sort()
end

release_evidence_count =
  Enum.reduce(artifact_apps, 0, fn app, count ->
    {dependency_path, workspace_path} = Map.fetch!(validated_roots, app)

    for name <- Map.get(repository_only_top_level, app, []) do
      assert!.(
        File.regular?(Path.join(workspace_path, name)),
        "repository-only workspace evidence is absent: #{app}/#{name}"
      )

      assert!.(
        not File.exists?(Path.join(dependency_path, name)),
        "repository-only evidence leaked into artifact: #{app}/#{name}"
      )
    end

    workspace_evidence =
      workspace_path
      |> release_evidence_names.()
      |> Kernel.--(Map.get(repository_only_top_level, app, []))

    artifact_evidence = release_evidence_names.(dependency_path)

    assert!.(
      workspace_evidence == artifact_evidence,
      "workspace release evidence differs from artifact for #{app}: " <>
        "#{inspect(workspace_evidence)} != #{inspect(artifact_evidence)}"
    )

    for name <- artifact_evidence do
      workspace_file = Path.join(workspace_path, name)
      artifact_file = Path.join(dependency_path, name)

      assert!.(
        File.lstat!(artifact_file).type == :regular,
        "artifact release evidence is not a real file: #{artifact_file}"
      )

      assert!.(
        File.read!(workspace_file) == File.read!(artifact_file),
        "workspace release evidence content differs from artifact: #{app}/#{name}"
      )
    end

    count + length(artifact_evidence)
  end)

assert!.(
  release_evidence_count == 88,
  "expected exactly 88 byte-identical workspace/artifact release evidence files"
)

IconvexIntegration.ArtifactAuditSupport.ensure_crypto!()

for app <- artifact_apps do
  version = Map.fetch!(artifact_versions, app)
  tarball = Path.join(tarball_root, "#{app}-#{version}.tar")
  tar = IconvexIntegration.ArtifactAuditSupport.hex_tar!(tarball)
  metadata = tar.metadata
  {dependency_path, _workspace_path} = Map.fetch!(validated_roots, app)

  :ok =
    IconvexIntegration.ArtifactAuditSupport.verify_contents_root!(
      tar.contents,
      dependency_path,
      app
    )

  assert!.(metadata["name"] == Atom.to_string(app), "Hex metadata name differs for #{app}")
  assert!.(metadata["app"] == Atom.to_string(app), "Hex metadata app differs for #{app}")
  assert!.(metadata["version"] == version, "Hex metadata version differs for #{app}")

  links = Map.fetch!(metadata, "links")

  assert!.(
    Map.get(links, "GitHub") == expected_github_url,
    "Hex metadata GitHub link differs for #{app}"
  )

  actual_requirements =
    metadata
    |> Map.fetch!("requirements")
    |> Enum.map(fn {name, fields} ->
      {
        name,
        Map.fetch!(fields, "app"),
        Map.fetch!(fields, "requirement"),
        Map.fetch!(fields, "optional"),
        Map.fetch!(fields, "repository")
      }
    end)
    |> Enum.sort()

  assert!.(
    actual_requirements == Map.fetch!(artifact_requirements, app),
    "Hex metadata requirements differ for #{app}: " <>
      "#{inspect(actual_requirements)} != #{inspect(Map.fetch!(artifact_requirements, app))}"
  )
end

packaged_file_count =
  Enum.reduce(artifact_apps, 0, fn app, count ->
    {dependency_path, workspace_path} = Map.fetch!(validated_roots, app)
    {expected_count, expected_digest} = Map.fetch!(artifact_tree_expectations, app)
    relative_files = IconvexIntegration.ArtifactAuditSupport.regular_files!(dependency_path)

    assert!.(
      length(relative_files) == expected_count,
      "#{app} artifact tree file count differs: #{length(relative_files)} != #{expected_count}"
    )

    actual_digest =
      IconvexIntegration.ArtifactAuditSupport.tree_sha256!(dependency_path, relative_files)

    assert!.(
      actual_digest == expected_digest,
      "#{app} artifact tree digest differs: #{actual_digest} != #{expected_digest}"
    )

    for relative <- relative_files do
      artifact_file = Path.join(dependency_path, relative)
      workspace_file = Path.join(workspace_path, relative)

      assert!.(
        File.regular?(workspace_file),
        "packaged file is absent from workspace source: #{app}/#{relative}"
      )

      assert!.(
        File.read!(artifact_file) == File.read!(workspace_file),
        "packaged file differs from workspace source: #{app}/#{relative}"
      )
    end

    count + length(relative_files)
  end)

assert!.(packaged_file_count == 2_255, "expected exactly 2,255 recursively packaged files")

for app <- artifact_apps do
  case Application.ensure_all_started(app) do
    {:ok, _started} -> :ok
    {:error, reason} -> raise "could not start #{app}: #{inspect(reason)}"
  end
end

encodings = Iconvex.encodings()
normalize = &String.upcase(&1, :ascii)

expected_encodings =
  (Iconvex.Registry.builtin_canonical_names() ++
     Enum.map(Iconvex.Specs.registrations(), & &1.canonical) ++
     Iconvex.Extras.encodings() ++ Iconvex.Telecom.encodings())
  |> Enum.map(normalize)
  |> Enum.uniq()
  |> Enum.sort()

actual_encodings = encodings |> Enum.map(normalize) |> Enum.sort()

assert!.(
  length(expected_encodings) == 2_093 and actual_encodings == expected_encodings,
  "expected the derived 2,093-name ASCII-case-unique full-stack canonical set"
)

packaged_provenance_codecs = [
  Iconvex.Specs.DECGreek81994,
  Iconvex.Specs.DECTurkish81994,
  Iconvex.Specs.IBM1116850P100Composite,
  Iconvex.Specs.IBM1117437P100Composite,
  Iconvex.Specs.IBM310293P100CompositeVPUA,
  Iconvex.Specs.IBM907CDRAP100VPUAComposite,
  Iconvex.Specs.IBMTNZCP310B1EAE3C
]

{:ok, modules} = :application.get_key(:iconvex_specs, :modules)

actual_helpers =
  for module <- modules,
      {name, arity} <- module.__info__(:functions),
      text = Atom.to_string(name),
      String.contains?(text, "path") or String.ends_with?(text, "_directory"),
      do: {module, name, arity}

expected_helpers =
  [
    {Iconvex.Specs.IBMAdditionalCodePages, :source_map_path, 1},
    {Iconvex.Specs.IBMAdditionalCodePages, :source_metadata_path, 0}
  ] ++
    for module <- packaged_provenance_codecs,
        name <- [:source_map_path, :source_metadata_path],
        do: {module, name, 0}

assert!.(
  Enum.sort(actual_helpers) == Enum.sort(expected_helpers),
  "installed provenance helper surface differs from the exact 16-entry allowlist"
)

runtime_priv = :iconvex_specs |> :code.priv_dir() |> List.to_string()
telecom_runtime_priv = :iconvex_telecom |> :code.priv_dir() |> List.to_string()

for codec <- packaged_provenance_codecs,
    path <- [codec.source_map_path(), codec.source_metadata_path()] do
  assert!.(File.regular?(path), "missing installed provenance file: #{path}")

  assert!.(
    not (path |> Path.relative_to(runtime_priv) |> String.starts_with?("..")),
    "installed provenance path escaped the Specs priv directory: #{path}"
  )
end

kermit_copying =
  Path.join(runtime_priv, "sources/dec-terminal-character-sets/kermit/COPYING")

kermit_metadata =
  Path.join(runtime_priv, "sources/kermit-vendor-8bit/SOURCE_METADATA.md")

assert!.(File.regular?(kermit_copying), "Kermit COPYING is absent from the Specs artifact")

assert!.(
  File.regular?(kermit_metadata),
  "Kermit source metadata is absent from the Specs artifact"
)

kermit_copying_digest =
  kermit_copying
  |> File.read!()
  |> then(&:crypto.hash(:sha256, &1))
  |> Base.encode16(case: :lower)

assert!.(
  kermit_copying_digest ==
    "067b8c8fc98d9359dfbd211820e1d57bed1e173144a184a21e8ead802b6502be",
  "packaged Kermit COPYING digest differs from the pinned BSD-3-Clause source"
)

fieldata_tables = [
  {"sources/univac-1100-fieldata/table_6_1.csv",
   "ba38cd68725d7df26c12771e79816e77850e4c796a4c63904feadb61d03e04eb"},
  {"sources/univac-4009-fieldata/table_3_1.csv",
   "fa0f6937c4bde63821373f6af6c08d256beeb31a34a717c1a8001828ad32d3d6"}
]

for {relative, expected_digest} <- fieldata_tables do
  path = Path.join(runtime_priv, relative)
  assert!.(File.regular?(path), "packaged FIELDATA table is absent: #{relative}")

  digest = path |> File.read!() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
  assert!.(digest == expected_digest, "packaged FIELDATA table digest differs: #{relative}")
end

recent_source_assets = [
  {"sources/mac-esperanto/SOURCE_METADATA.md",
   "20a59bec95edd225467b15124a6a1634799c01322ebe3dd0ac125b42a5e93ea1"},
  {"sources/mac-esperanto/macos_esperanto_0_3.csv",
   "4ad11598020843b2728f438dc8e8e3149ee822ae03a688330ad0b80dc013aa05"},
  {"sources/vscii-2/SOURCE_METADATA.md",
   "9a0b0fa992eea3858d72a22697a19252aebeb426038029b3ae7a3a0517fea6a3"},
  {"sources/vscii-2/vscii2.csv",
   "719bd06c76a258e414f422093b49a7687da111e9cbf2fab14194ff57e2d6f127"},
  {"sources/lotus-lics/SOURCE_METADATA.md",
   "328bb0a6b703742a8b882adcb079d5413ae9a4d6cb514dcd0ae4b6b83fe6cfe2"},
  {"sources/lotus-lics/lotus_lics_hp_1991.csv",
   "2eedf12805e1aee25e37044ddf58c8fcdcb9e754f3c3776aeb8a0447674a5239"},
  {"sources/us-army-tap-code/SOURCE_METADATA.md",
   "27885c0d5edf80e27e06a732aab183369eed8c45d82380efbd680b9f06a1237e"},
  {"sources/us-army-tap-code/pairs.csv",
   "b9289530db75d795b65768b8be1add61a9d6ee20e6fb780a7b5bda853637e4cb"},
  {"sources/ibm-24-26-arrangements/SOURCE_METADATA.md",
   "eb261f34e7d19f2308608e14dc0597b4e4949252586b7a28cd5aaf962f78111c"},
  {"sources/ibm-24-26-arrangements/figure_23_arrangements.csv",
   "edb7190244bbf1bca034453bc7de16ccc78d5a3d86c5f5957ec82a2f93d25733"},
  {"sources/draft-jseng-utf5-01/SOURCE_METADATA.md",
   "797c56059bcf89b14ee6fd01dabf845fc0ce9eb9db964c64a4736ceb55e2cd9d"},
  {"sources/draft-jseng-utf5-01/draft-jseng-utf5-01.txt",
   "12ae18367c110b5dcef9cc3f06b6ae40e60c8fde489fdd161f1bb98e3e5f2375"},
  {"sources/draft-ietf-idn-utf6-00/SOURCE_METADATA.md",
   "cf1f1733c0be85d65014d49a10503cbc819b67149b982f93847f808bafdfd76a"},
  {"sources/draft-ietf-idn-utf6-00/UPSTREAM-NOTICE.txt",
   "9ae4c27dbce06d6b1fb2da4d9547aaf9bab317295a5bc0e872e30fa0905205e2"},
  {"sources/draft-ietf-idn-utf6-00/draft-ietf-idn-utf6-00.txt",
   "80033b5e41bc9f2fd01bddf99a300827b837f06ba93ef303bc54bc53df3755ca"}
]

for {relative, expected_digest} <- recent_source_assets do
  path = Path.join(runtime_priv, relative)
  assert!.(File.regular?(path), "recent source asset is absent: #{relative}")

  digest = path |> File.read!() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
  assert!.(digest == expected_digest, "recent source asset digest differs: #{relative}")
end

punched_card_assets = [
  {"sources/punched-card-codes/canonical_maps.csv",
   "541347c32f7610d3830b9259a68891b6ae2a410b1251f039f37930b83c3476c7"},
  {"sources/punched-card-codes/decode_aliases.csv",
   "da98e499e2b860bea2f35b7fbd66e14db1142047a7ac9ffe5b84174875b65323"},
  {"sources/punched-card-codes/PROFILE_DISPOSITION.md",
   "e8b8320fab1a422ef3c36bff8e87dabc828198c50f141d54f62c7c551c8d94fc"},
  {"sources/punched-card-codes/SOURCE_METADATA.md",
   "e42d5114417710ae1233942078813a3951ad2970720e150c155b511fd583d25c"}
]

for {relative, expected_digest} <- punched_card_assets do
  path = Path.join(runtime_priv, relative)
  assert!.(File.regular?(path), "packaged punched-card evidence is absent: #{relative}")

  digest = path |> File.read!() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

  assert!.(
    digest == expected_digest,
    "packaged punched-card evidence digest differs: #{relative}"
  )
end

for pattern <- [
      "sources/punched-card-codes/*.pdf",
      "sources/punched-card-codes/*.html"
    ] do
  assert!.(
    Path.wildcard(Path.join(runtime_priv, pattern)) == [],
    "copyrighted punched-card source must not ship in the Specs artifact: #{pattern}"
  )
end

transcode_profiles = [
  %{
    codec: Iconvex.Telecom.IBM2780SixBitTranscode,
    canonical: "IBM-2780-SIX-BIT-TRANSCODE-GA27-3005-3",
    alias_name: "IBM-2780-SIX-BIT-TRANSCODE-1971",
    profile_scalar: 0x2311,
    relative: "sources/ibm-six-bit-transcode/ga27-3005-3.csv",
    sha256: "cbb94188f9ac1a8b9a95dcff91d0744c84f77ad53377d62dd76eff4d6a476416"
  },
  %{
    codec: Iconvex.Telecom.IBMBscSixBitTranscode,
    canonical: "IBM-BSC-SIX-BIT-TRANSCODE-GA27-3004-2",
    alias_name: "IBM-BSC-SIX-BIT-TRANSCODE-1970",
    profile_scalar: 0x003C,
    relative: "sources/ibm-six-bit-transcode/ga27-3004-2.csv",
    sha256: "5dccf290006224a0de51dddda9ec227183f1527610f61cf2f70b606ccea7c31e"
  }
]

transcode_assets =
  Enum.map(transcode_profiles, &{&1.relative, &1.sha256}) ++
    [
      {"sources/ibm-six-bit-transcode/SOURCE_METADATA.md",
       "3b9fe66217399b16b338ffa41209d2b77237886cde306e10e63f82374506908f"}
    ]

transcode_csv_vector! = fn path ->
  ["unit_hex,unicode_hex" | rows] =
    path
    |> File.read!()
    |> String.split("\n", trim: true)

  assert!.(length(rows) == 64, "IBM Transcode CSV must contain exactly 64 rows: #{path}")

  rows
  |> Enum.with_index()
  |> Enum.map(fn {row, expected_unit} ->
    [unit_hex, unicode_hex] = String.split(row, ",", parts: 2)

    assert!.(
      String.to_integer(unit_hex, 16) == expected_unit,
      "IBM Transcode CSV unit order differs at #{expected_unit}: #{path}"
    )

    String.to_integer(unicode_hex, 16)
  end)
end

for {relative, expected_digest} <- transcode_assets do
  path = Path.join(telecom_runtime_priv, relative)
  assert!.(File.regular?(path), "packaged IBM Transcode evidence is absent: #{relative}")

  digest = path |> File.read!() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

  assert!.(
    digest == expected_digest,
    "packaged IBM Transcode evidence digest differs: #{relative}"
  )
end

for profile <- transcode_profiles do
  codec = profile.codec
  path = Path.join(telecom_runtime_priv, profile.relative)
  vector = transcode_csv_vector!.(path)
  units = 0..63 |> Enum.to_list() |> :erlang.list_to_binary()

  assert!.(
    MapSet.size(MapSet.new(vector)) == 64 and
      codec.decode(units) == {:ok, vector} and
      codec.encode(vector) == {:ok, units},
    "packaged IBM Transcode full-map contract failed: #{profile.canonical}"
  )

  for {codepoint, unit} <- Enum.with_index(vector) do
    assert!.(
      codec.decode(<<unit>>) == {:ok, [codepoint]} and
        codec.encode([codepoint]) == {:ok, <<unit>>},
      "packaged IBM Transcode cell differs at unit #{unit}: #{profile.canonical}"
    )
  end
end

assert!.(
  Path.wildcard(Path.join(telecom_runtime_priv, "sources/ibm-six-bit-transcode/*.pdf")) == [],
  "copyrighted IBM Transcode manuals must not ship in the Telecom artifact"
)

assert!.(
  Path.wildcard(Path.join(runtime_priv, "sources/ibm-24-26-arrangements/*.pdf")) == [],
  "copyrighted IBM 24/26 manual must not ship in the Specs artifact"
)

for relative <- [
      "sources/univac-1100-fieldata/SOURCE_METADATA.md",
      "sources/univac-4009-fieldata/SOURCE_METADATA.md"
    ] do
  assert!.(
    File.regular?(Path.join(runtime_priv, relative)),
    "packaged FIELDATA source metadata is absent: #{relative}"
  )
end

assert!.(
  Path.wildcard(Path.join(runtime_priv, "sources/univac-*-fieldata/*.pdf")) == [],
  "copyrighted FIELDATA source manuals must not ship in the Specs artifact"
)

ti_asset_sets = [
  {"sources/ti-89-92-plus-ams-2.0",
   %{
     "SOURCE_METADATA.md" => "8d446d83fd5cda065ac304f416f84ea2d8754cb7d567bf390a0f980924bbf491",
     "mapping.csv" => "be205ae316b916d6f2b386fd85729f51cdcd6852c9db64f014d0187a6345fb44"
   }},
  {"sources/ti-83-plus-2002",
   %{
     "SOURCE_METADATA.md" => "31a7655c59eb3da1f7c6bb123f6eedb961f64ea2cb3a7e9240dc5e004e73aa8f",
     "mapping.csv" => "186d80d270a6a27815df8d0b5ff993c65b158efb7f3d6ddd27533feb9cb96ccc"
   }}
]

for {relative_directory, expected_files} <- ti_asset_sets do
  directory = Path.join(runtime_priv, relative_directory)
  actual_filenames = File.ls!(directory) |> Enum.sort()
  expected_filenames = expected_files |> Map.keys() |> Enum.sort()

  assert!.(
    actual_filenames == expected_filenames,
    "TI artifact directory has an unexpected file set: #{relative_directory}"
  )

  for {filename, expected_digest} <- expected_files do
    path = Path.join(directory, filename)
    contents = File.read!(path)
    digest = contents |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

    assert!.(
      digest == expected_digest,
      "TI artifact digest differs: #{relative_directory}/#{filename}"
    )

    assert!.(not String.contains?(contents, "/private/"), "TI artifact leaks a private path")
  end

  mapping = File.read!(Path.join(directory, "mapping.csv"))

  assert!.(
    Enum.all?(["official_symbol_name", "source_cell", "source_evidence"], fn field ->
      not String.contains?(mapping, field)
    end),
    "TI compact mapping unexpectedly contains source transcription fields"
  )

  for pattern <- ["*.c", "*.h", "*.o", "*.so", "*.dylib", "*.beam", "*.pdf", "*.png"] do
    assert!.(
      Path.wildcard(Path.join(directory, pattern)) == [],
      "TI artifact unexpectedly packages implementation/source evidence: #{pattern}"
    )
  end
end

specs_dependency_root = Map.fetch!(Mix.Project.deps_paths(), :iconvex_specs)
vpua_allocations = File.read!(Path.join(specs_dependency_root, "VPUA_ALLOCATIONS.md"))

for allocation <- [
      "U+F0000..U+F2283",
      "U+F4000..U+F403F",
      "U+F8300..U+F83FF",
      "U+F8400..U+F84FF",
      "U+F8500..U+F85FF",
      "U+F8600..U+F86FF",
      "U+F8900..U+F89FF",
      "U+F8A00..U+F8AFF"
    ] do
  assert!.(
    String.contains?(vpua_allocations, allocation),
    "missing VPUA allocation #{allocation}"
  )
end

ti89_profiles = [
  {Iconvex.Specs.TI89AMS20, "TI-89-92-PLUS-AMS-2.0"},
  {Iconvex.Specs.TI89AMS20Visible, "TI-89-92-PLUS-AMS-2.0-VISIBLE"},
  {Iconvex.Specs.TI89AMS20LosslessVPUA, "TI-89-92-PLUS-AMS-2.0-LOSSLESS-VPUA"},
  {Iconvex.Specs.TI89AMS20RawVPUA, "TI-89-92-PLUS-AMS-2.0-RAW-VPUA"}
]

for {codec, canonical} <- ti89_profiles do
  assert!.(
    codec.canonical_name() == canonical,
    "wrong TI-89 profile canonical: #{inspect(codec)}"
  )

  assert!.(
    codec.mapping_sha256() == "be205ae316b916d6f2b386fd85729f51cdcd6852c9db64f014d0187a6345fb44",
    "wrong TI-89 mapping digest callback"
  )

  assert!.(
    codec.metadata_sha256() ==
      "8d446d83fd5cda065ac304f416f84ea2d8754cb7d567bf390a0f980924bbf491",
    "wrong TI-89 metadata digest callback"
  )

  assert!.(
    codec.source_sha256() == "6e7266917fd2de05f7374ebe0de3ef898a06533e17fd9a5c6e4a3d3f237140a9",
    "wrong TI-89 source digest callback"
  )

  assert!.(codec.source_pages() == [436, 572], "wrong TI-89 source pages")
  assert!.(codec.printed_source_pages() == [419, 555], "wrong TI-89 printed pages")

  assert!.(
    match?({:ok, %{codec: ^codec, canonical: ^canonical}}, Iconvex.Registry.resolve(canonical)),
    "TI-89 profile does not resolve to its exact module"
  )
end

ti83_profiles = [
  {Iconvex.Specs.TI83PlusLarge, "TI-83-PLUS-LARGE", Enum.to_list(173..179),
   Enum.to_list(156..162)},
  {Iconvex.Specs.TI83PlusLargeLosslessVPUA, "TI-83-PLUS-LARGE-LOSSLESS-VPUA",
   Enum.to_list(173..179), Enum.to_list(156..162)},
  {Iconvex.Specs.TI83PlusLargeRawVPUA, "TI-83-PLUS-LARGE-RAW-VPUA", Enum.to_list(173..179),
   Enum.to_list(156..162)},
  {Iconvex.Specs.TI83PlusSmall, "TI-83-PLUS-SMALL", Enum.to_list(180..187),
   Enum.to_list(163..170)},
  {Iconvex.Specs.TI83PlusSmallLosslessVPUA, "TI-83-PLUS-SMALL-LOSSLESS-VPUA",
   Enum.to_list(180..187), Enum.to_list(163..170)},
  {Iconvex.Specs.TI83PlusSmallRawVPUA, "TI-83-PLUS-SMALL-RAW-VPUA", Enum.to_list(180..187),
   Enum.to_list(163..170)}
]

for {codec, canonical, source_pages, printed_pages} <- ti83_profiles do
  assert!.(
    codec.canonical_name() == canonical and codec.aliases() == [],
    "wrong TI-83 profile identity"
  )

  assert!.(
    codec.mapping_sha256() == "186d80d270a6a27815df8d0b5ff993c65b158efb7f3d6ddd27533feb9cb96ccc",
    "wrong TI-83 mapping digest callback"
  )

  assert!.(
    codec.metadata_sha256() == "31a7655c59eb3da1f7c6bb123f6eedb961f64ea2cb3a7e9240dc5e004e73aa8f",
    "wrong TI-83 metadata digest callback"
  )

  assert!.(
    codec.source_sha256() == "a07d2cae4d5be0529901c178acd80028d2a72c484a04c61cde104f34712cec55",
    "wrong TI-83 source digest callback"
  )

  assert!.(codec.source_pages() == source_pages, "wrong TI-83 source pages")
  assert!.(codec.printed_source_pages() == printed_pages, "wrong TI-83 printed pages")

  assert!.(
    match?({:ok, %{codec: ^codec, canonical: ^canonical}}, Iconvex.Registry.resolve(canonical)),
    "TI-83 profile does not resolve to its exact module"
  )
end

for bare_name <- [
      "TI-83-PLUS",
      "TI83PLUS",
      "TI83-PLUS",
      "TI-83 PLUS",
      "TI-83-PLUS-LOSSLESS-VPUA",
      "TI-83-PLUS-RAW-VPUA"
    ] do
  assert!.(Iconvex.canonical_name(bare_name) == :error, "ambiguous TI-83 name was registered")
end

assert!.(
  Iconvex.convert(<<0x11>>, "TI-83-PLUS-LARGE", "UTF-8") == {:ok, <<0x207B::utf8, 0x00B9::utf8>>} and
    Iconvex.convert(<<0x207B::utf8, 0x00B9::utf8>>, "UTF-8", "TI-83-PLUS-LARGE") ==
      {:ok, <<0x11>>},
  "TI-83 longest-sequence conversion smoke test failed"
)

assert!.(
  Iconvex.Specs.TI83PlusLarge.decode(<<0x1D>>) == {:ok, [?1, ?0]} and
    Iconvex.Specs.TI83PlusLarge.encode([?1, ?0]) == {:ok, <<?1, ?0>>},
  "TI-83 decode-only reverse policy smoke test failed"
)

assert!.(
  Iconvex.Specs.TI83PlusLarge.decode(<<0xF2>>) == {:error, :invalid_sequence, 0, <<0xF2>>} and
    Iconvex.Specs.TI83PlusSmall.decode(<<0xED>>) == {:error, :invalid_sequence, 0, <<0xED>>},
  "TI-83 readable invalid-tail smoke test failed"
)

for codec <- [
      Iconvex.Specs.TI83PlusLargeLosslessVPUA,
      Iconvex.Specs.TI83PlusLargeRawVPUA,
      Iconvex.Specs.TI83PlusSmallLosslessVPUA,
      Iconvex.Specs.TI83PlusSmallRawVPUA
    ] do
  sample = <<0x00, 0xD6, 0xFF>>
  {:ok, codepoints} = codec.decode(sample)
  assert!.(codec.encode(codepoints) == {:ok, sample}, "TI-83 lossless/raw round trip failed")
end

assert!.(
  Path.wildcard(Path.join(runtime_priv, "tables/icu_archive_*.etf")) == [],
  "main Specs artifact unexpectedly contains an ICU archive shard table"
)

archive_shards = [
  {:iconvex_specs_icu_archive_a, 1..350},
  {:iconvex_specs_icu_archive_b, 351..700},
  {:iconvex_specs_icu_archive_c, 701..1050}
]

archive_table_count =
  Enum.reduce(
    archive_shards,
    0,
    fn {app, indexes}, count ->
      expected_table_filenames =
        indexes
        |> Enum.map(&"icu_archive_#{&1}.etf")
        |> Enum.sort()

      actual_table_filenames =
        app
        |> :code.priv_dir()
        |> List.to_string()
        |> Path.join("tables/*.etf")
        |> Path.wildcard()
        |> Enum.map(&Path.basename/1)
        |> Enum.sort()

      assert!.(
        actual_table_filenames == expected_table_filenames,
        "#{app} archive table file set differs from its exact assigned range"
      )

      Enum.reduce(indexes, count, fn index, inner_count ->
        id = String.to_atom("icu_archive_#{index}")
        provider_record = :persistent_term.get({{Iconvex.Tables, :provider}, id}, :missing)

        provider =
          case provider_record do
            {provider_app, {:owned, token}}
            when is_atom(provider_app) and is_reference(token) ->
              provider_app

            {provider_app, :unowned} when is_atom(provider_app) ->
              provider_app

            provider_app ->
              provider_app
          end

        assert!.(provider == app, "archive table #{index} has the wrong provider: #{provider}")

        table = Iconvex.Tables.fetch!(id)
        assert!.(is_map(table), "archive table #{index} did not load from #{app}")
        inner_count + 1
      end)
    end
  )

assert!.(
  archive_table_count == 1_050,
  "expected all 1,050 provider-routed archive shard tables to load"
)

registrations = Iconvex.Specs.registrations()
expected_specs_count = length(Iconvex.Specs.codecs())
assert!.(expected_specs_count == 1_841, "expected 1,841 runtime Specs codec modules")

assert!.(
  length(registrations) == expected_specs_count,
  "Specs registration count differs from its codec-module count"
)

gnu_reclaimed_rfc_identities = %{
  "IBM037" => {"IBM-037", "RFC1345:IBM037"},
  "IBM1026" => {"IBM-1026", "RFC1345:IBM1026"},
  "IBM273" => {"IBM-273", "RFC1345:IBM273"},
  "IBM277" => {"IBM-277", "RFC1345:IBM277"},
  "IBM278" => {"IBM-278", "RFC1345:IBM278"},
  "IBM280" => {"IBM-280", "RFC1345:IBM280"},
  "IBM284" => {"IBM-284", "RFC1345:IBM284"},
  "IBM285" => {"IBM-285", "RFC1345:IBM285"},
  "IBM297" => {"IBM-297", "RFC1345:IBM297"},
  "IBM424" => {"IBM-424", "RFC1345:IBM424"},
  "IBM437" => {"CP437", "RFC1345:IBM437"},
  "IBM500" => {"IBM-500", "RFC1345:IBM500"},
  "IBM852" => {"CP852", "RFC1345:IBM852"},
  "IBM855" => {"CP855", "RFC1345:IBM855"},
  "IBM857" => {"CP857", "RFC1345:IBM857"},
  "IBM860" => {"CP860", "RFC1345:IBM860"},
  "IBM861" => {"CP861", "RFC1345:IBM861"},
  "IBM863" => {"CP863", "RFC1345:IBM863"},
  "IBM864" => {"CP864", "RFC1345:IBM864"},
  "IBM865" => {"CP865", "RFC1345:IBM865"},
  "IBM869" => {"CP869", "RFC1345:IBM869"},
  "IBM870" => {"IBM-870", "RFC1345:IBM870"},
  "IBM871" => {"IBM-871", "RFC1345:IBM871"},
  "IBM880" => {"IBM-880", "RFC1345:IBM880"},
  "IBM905" => {"IBM-905", "RFC1345:IBM905"}
}

assert!.(
  map_size(gnu_reclaimed_rfc_identities) == 25,
  "expected exactly 25 source-qualified RFC/GNU collision identities"
)

decode_single_byte = fn encoding, byte ->
  case Iconvex.convert(<<byte>>, encoding, "UTF-8") do
    {:error, %Iconvex.Error{} = error} ->
      {:error, error.kind, error.offset, error.sequence, error.codepoint}

    result ->
      result
  end
end

for {source_name, {gnu_canonical, rfc_qualified}} <- gnu_reclaimed_rfc_identities do
  assert!.(
    Iconvex.canonical_name(source_name) == {:ok, gnu_canonical},
    "GNU spelling does not retain GNU semantics: #{source_name}"
  )

  assert!.(
    Iconvex.canonical_name(rfc_qualified) == {:ok, rfc_qualified},
    "qualified RFC 1345 identity is unavailable: #{rfc_qualified}"
  )

  registration =
    Enum.find(registrations, fn registration ->
      registration.source == "RFC1345" and registration.canonical == rfc_qualified
    end)

  rfc_entry = Enum.find(Iconvex.Specs.RFC1345.encodings(), &(&1.name == source_name))
  expected_rfc_aliases = Enum.map(rfc_entry.aliases, &"RFC1345:#{&1}")

  assert!.(
    registration != nil and
      Enum.sort(registration.aliases) == Enum.sort(expected_rfc_aliases),
    "RFC 1345 aliases are not all source-qualified: #{rfc_qualified}"
  )

  for byte <- 0..255 do
    gnu_alias_result = decode_single_byte.(source_name, byte)
    gnu_canonical_result = decode_single_byte.(gnu_canonical, byte)

    assert!.(
      gnu_alias_result == gnu_canonical_result,
      "GNU alias differs from its canonical target: #{source_name} byte #{byte}"
    )
  end
end

for registration <- registrations do
  case registration.codec.decode(<<>>) do
    {:ok, _codepoints} -> :ok
    other -> raise "#{registration.canonical} empty decode returned #{inspect(other)}"
  end

  case registration.codec.encode([]) do
    {:ok, _bytes} -> :ok
    other -> raise "#{registration.canonical} empty encode returned #{inspect(other)}"
  end
end

assert!.(
  Iconvex.convert(<<0xC1>>, "IBM-1047", "UTF-8") == {:ok, "A"},
  "Extras conversion smoke test failed"
)

assert!.(
  Iconvex.convert(<<0x1B, 0x65>>, "GSM0338", "UTF-8") == {:ok, "€"},
  "Telecom conversion smoke test failed"
)

assert!.(
  match?({:ok, _}, Iconvex.convert(<<0x21>>, "KERMIT-DG-LINEDRAWING", "UTF-8")),
  "Specs Kermit conversion smoke test failed"
)

assert!.(
  Iconvex.convert(<<0xB0>>, "MACOS_ESPERANTO", "UTF-8") == {:ok, <<0x0108::utf8>>},
  "Specs MacOS Esperanto conversion smoke test failed"
)

assert!.(
  Iconvex.convert(<<0xB9>>, "VSCII-2", "UTF-8") == {:ok, <<0x1EA1::utf8>>},
  "Specs VSCII-2 conversion smoke test failed"
)

assert!.(
  Iconvex.convert(<<0x80>>, "LICS", "UTF-8") == {:ok, <<0x0300::utf8>>},
  "Specs Lotus LICS conversion smoke test failed"
)

assert!.(
  Iconvex.convert(
    <<1, 3>>,
    "US-ARMY-GTA-31-70-001-TAP-CODE-PAIR-VALUES",
    "UTF-8"
  ) == {:ok, "C"} and
    Iconvex.convert(
      "K",
      "UTF-8",
      "US-ARMY-GTA-31-70-001-TAP-CODE-PAIR-VALUES"
    ) == {:ok, <<1, 3>>},
  "Specs U.S. Army Tap Code pair-value conversion smoke test failed"
)

assert!.(
  Iconvex.convert("A\u2262\u0391.", "UTF-8", "UTF-5") == {:ok, "K1I262J91IE"} and
    Iconvex.convert("K1I262J91IE", "UTF-5", "UTF-8") == {:ok, "A\u2262\u0391."},
  "Specs UTF-5 exact-draft conversion smoke test failed"
)

assert!.(
  Iconvex.Specs.UTF5.decode_chunk("K1!", false) ==
    {:error, :invalid_sequence, 2, "!"} and
    Iconvex.Specs.UTF5.decode_chunk("K1T800", false) == {:ok, [?A], "T800"},
  "Specs UTF-5 bounded streaming review fix is absent"
)

utf6_arabic = "\u0645\u0648\u0642\u0639.\u0648\u0644\u064A\u062F.\u0634\u0631\u0643\u0629"
utf6_wire = "wq--ymk5k8k2j9.wq--ymk8k4kaif.wq--ymj4j1k3i9"

assert!.(
  Iconvex.convert(utf6_arabic, "UTF-8", "UTF-6") == {:ok, utf6_wire} and
    Iconvex.convert(utf6_wire, "UTF-6", "UTF-8") == {:ok, utf6_arabic},
  "Specs UTF-6 exact-draft conversion smoke test failed"
)

assert!.(
  Iconvex.Specs.UTF6.encode_discard(~c"A.") == Iconvex.Specs.UTF6.encode(~c"A") and
    Iconvex.Specs.UTF6.encode_substitute(~c"A-", fn ?- -> ~c"X.Y" end) ==
      Iconvex.Specs.UTF6.encode(~c"AX.Y"),
  "Specs UTF-6 structural policy review fix is absent"
)

assert!.(
  Iconvex.convert(
    "A",
    "UTF-8",
    "IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-A-16BE"
  ) == {:ok, <<0x09, 0x00>>} and
    Iconvex.convert(
      <<0x09, 0x00>>,
      "IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-A-16BE",
      "UTF-8"
    ) == {:ok, "A"},
  "Specs IBM 24/26 arrangement A conversion smoke test failed"
)

assert!.(
  Iconvex.convert(<<0o06, 0o07, 0o10>>, "FIELDATA-UNIVAC-1100", "UTF-8") ==
    {:ok, "ABC"},
  "Specs FIELDATA semantic conversion smoke test failed"
)

for alias_name <- ["EXEC-8-FIELDATA", "FIELDATA-1100"] do
  assert!.(
    Iconvex.canonical_name(alias_name) == {:ok, "FIELDATA-UNIVAC-1100"},
    "Specs FIELDATA source-qualified alias failed: #{alias_name}"
  )
end

for ambiguous_name <- ["FIELDATA-UNIVAC", "UNIVAC-FIELDATA"] do
  assert!.(
    Iconvex.canonical_name(ambiguous_name) == :error,
    "Specs FIELDATA ambiguous family label was unexpectedly claimed: #{ambiguous_name}"
  )
end

assert!.(
  Iconvex.convert(<<0o57>>, "FIELDATA-UNIVAC-4009-INPUT", "UTF-8") ==
    {:ok, <<0xF402F::utf8>>},
  "Specs FIELDATA proprietary-glyph identity failed"
)

assert!.(
  Iconvex.Specs.Packed.decode_to_utf8(
    <<0o06::6, 0o06::6, 0o06::6, 0o06::6, 0o04::6>>,
    "FIELDATA-UNIVAC-4009-INPUT",
    :msb
  ) == {:error, :invalid_sequence, 24, <<0o04::6>>},
  "Specs FIELDATA packed error did not retain its physical MSB bit offset"
)

assert!.(
  Iconvex.convert(<<0o00, 0o77>>, "FIELDATA-UNIVAC-4009-RAW-VPUA", "UTF-8") ==
    {:ok, <<0xF4000::utf8, 0xF403F::utf8>>},
  "Specs FIELDATA raw-VPUA conversion smoke test failed"
)

iowa_sample = "AZ9≤"
iowa_profile = Iconvex.Specs.Packed.profile("BCD-CDC-IOWA")

assert!.(
  iowa_profile.codec == Iconvex.Specs.BCDCDCIowa and
    iowa_profile.canonical == "BCD-CDC-IOWA" and iowa_profile.unit_bits == 12,
  "Specs source-qualified Iowa packed profile did not resolve"
)

{:ok, iowa_packed} =
  Iconvex.Specs.Packed.encode_from_utf8(iowa_sample, "BCD-CDC-IOWA", :standard)

assert!.(
  Iconvex.Specs.Packed.decode_to_utf8(iowa_packed, "BCD-CDC-IOWA", :standard) ==
    {:ok, iowa_sample},
  "Specs source-qualified Iowa packed round trip failed"
)

for encoding <- ["BCD-CDC-IOWA-16BE", "BCD-CDC-IOWA-16LE"] do
  assert!.(
    Iconvex.canonical_name(encoding) == {:ok, encoding},
    "Specs source-qualified Iowa word transport did not resolve: #{encoding}"
  )

  {:ok, encoded} = Iconvex.convert(iowa_sample, "UTF-8", encoding)

  assert!.(
    Iconvex.convert(encoded, encoding, "UTF-8") == {:ok, iowa_sample},
    "Specs source-qualified Iowa word transport round trip failed: #{encoding}"
  )
end

for ambiguous_name <- ["BCD-CDC", "CDC punched-card BCD", "CDC-PUNCHED-CARD-BCD"] do
  assert!.(
    Iconvex.canonical_name(ambiguous_name) == :error and
      Iconvex.Specs.Packed.profile(ambiguous_name) == nil and
      Iconvex.convert("A", "UTF-8", ambiguous_name) == {:error, :unknown_encoding},
    "Specs ambiguous generic punched-card identity was unexpectedly claimed: #{ambiguous_name}"
  )
end

packed_profiles = Iconvex.Telecom.Packed.profiles()

packed_name_cases =
  for profile <- packed_profiles,
      base_name <- [profile.canonical | profile.codec.aliases()],
      order <- [:msb, :lsb] do
    %{profile: profile, base_name: base_name, order: order}
  end

packed_case_name = fn packed_case ->
  suffix = packed_case.order |> Atom.to_string() |> String.upcase()
  "#{packed_case.base_name}-PACKED-#{suffix}"
end

packed_representative = fn profile ->
  Enum.find_value(0..(Bitwise.bsl(1, profile.unit_bits) - 1), fn unit ->
    with {:ok, codepoints} when codepoints != [] <- profile.codec.decode(<<unit>>),
         {:ok, <<^unit>>} <- profile.codec.encode(codepoints) do
      List.to_string(codepoints)
    else
      _ -> nil
    end
  end) || raise("no representable packed unit for #{profile.canonical}")
end

packed_names = Enum.map(packed_name_cases, packed_case_name)

canonical_packed_count =
  Enum.count(packed_name_cases, &(&1.base_name == &1.profile.canonical))

alias_packed_count = length(packed_name_cases) - canonical_packed_count

assert!.(
  length(packed_name_cases) == 322 and canonical_packed_count == 102 and
    alias_packed_count == 220 and MapSet.size(MapSet.new(packed_names)) == 322,
  "Telecom packed canonical/alias name inventory failed"
)

for packed_case <- packed_name_cases do
  profile = packed_case.profile
  order = packed_case.order
  opposite_order = if order == :msb, do: :lsb, else: :msb
  name = packed_case_name.(packed_case)
  sample = packed_representative.(profile)

  assert!.(
    Iconvex.Telecom.Packed.profile(name) == profile,
    "Telecom packed name resolved to the wrong profile: #{name}"
  )

  {:ok, packed} = Iconvex.Telecom.Packed.encode_from_utf8(sample, name)

  assert!.(
    Iconvex.Telecom.Packed.decode_to_utf8(packed, name) == {:ok, sample} and
      Iconvex.Telecom.Packed.encode_from_utf8(sample, name, order) == {:ok, packed} and
      Iconvex.Telecom.Packed.decode_to_utf8(packed, name, order) == {:ok, sample} and
      Iconvex.Telecom.Packed.encode_from_utf8(sample, name, opposite_order) ==
        {:error, :bit_order_mismatch} and
      Iconvex.Telecom.Packed.decode_to_utf8(packed, name, opposite_order) ==
        {:error, :bit_order_mismatch},
    "Telecom packed named-order contract failed: #{name}"
  )

  if order == :lsb do
    %Iconvex.Packed.LSB{} = lsb = packed
    mistagged = %{lsb | bit_order: :msb}

    assert!.(
      Iconvex.Telecom.Packed.decode_to_utf8(mistagged, name) ==
        {:error, :bit_order_mismatch},
      "Telecom packed LSB transport tag was not enforced: #{name}"
    )
  end
end

for profile <- transcode_profiles do
  codec = profile.codec
  canonical = profile.canonical
  alias_name = profile.alias_name
  profile_scalar = profile.profile_scalar

  assert!.(
    Iconvex.canonical_name(canonical) == {:ok, canonical} and
      Iconvex.canonical_name(alias_name) == {:ok, canonical} and
      codec.decode(<<0x0C>>) == {:ok, [profile_scalar]} and
      codec.encode([profile_scalar]) == {:ok, <<0x0C>>},
    "Telecom source-qualified IBM Transcode profile identity failed: #{canonical}"
  )

  sample = <<0x0001::utf8, 0x0002::utf8, profile_scalar::utf8, 0x007F::utf8>>
  packed_lsb = "#{canonical}-PACKED-LSB"
  packed_msb = "#{canonical}-PACKED-MSB"

  {:ok, %Iconvex.Packed.LSB{} = lsb} =
    Iconvex.Telecom.Packed.encode_from_utf8(sample, packed_lsb)

  {:ok, msb} = Iconvex.Telecom.Packed.encode_from_utf8(sample, packed_msb)

  assert!.(
    lsb == %Iconvex.Packed.LSB{
      data: <<0x80, 0xC2, 0xFC>>,
      bit_size: 24,
      unit_bits: 6
    } and
      msb == <<0x00, 0xA3, 0x3F>> and
      Iconvex.Telecom.Packed.decode_to_utf8(lsb, packed_lsb) == {:ok, sample} and
      Iconvex.Telecom.Packed.decode_to_utf8(msb, packed_msb) == {:ok, sample} and
      Iconvex.Telecom.Packed.profile("#{alias_name}-PACKED-LSB").canonical == canonical,
    "Telecom IBM Transcode named packed vectors failed: #{canonical}"
  )

  assert!.(
    Iconvex.Telecom.Packed.encode_from_utf8(sample, packed_lsb, :msb) ==
      {:error, :bit_order_mismatch} and
      Iconvex.Telecom.Packed.decode_to_utf8(lsb, packed_lsb, :msb) ==
        {:error, :bit_order_mismatch} and
      Iconvex.Telecom.Packed.decode_to_utf8(%{lsb | bit_order: :msb}, packed_lsb) ==
        {:error, :bit_order_mismatch},
    "Telecom IBM Transcode packed order validation failed: #{canonical}"
  )
end

for generic_name <- ["TRANSCODE", "SIX-BIT-TRANSCODE", "IBM-SIX-BIT-TRANSCODE"] do
  assert!.(
    Iconvex.canonical_name(generic_name) == :error and
      Iconvex.Telecom.Packed.profile(generic_name) == nil and
      Iconvex.convert("A", "UTF-8", generic_name) == {:error, :unknown_encoding},
    "Telecom ambiguous generic Transcode identity was unexpectedly claimed: #{generic_name}"
  )
end

IO.puts(
  "clean artifact audit: 7/7 artifact dependency roots; " <>
    "7/7 Hex tar metadata requirements; " <>
    "88/88 workspace release evidence files byte-identical; " <>
    "2,255/2,255 packaged files recursively pinned and byte-identical; " <>
    "2,093/2,093 full-stack codecs; " <>
    "25/25 GNU/RFC collision migrations exhaustive; " <>
    "16/16 public provenance helpers; Kermit BSD/source evidence present; " <>
    "FIELDATA, Iowa punched-card, IBM Six-Bit Transcode, and recent source assets/review fixes present; " <>
    "1,050/1,050 archive shard tables; " <>
    "TI-89/TI-83 exact assets and ten profiles present; " <>
    "1,841/1,841 runtime Specs encode/decode checks"
)

defmodule IconvexIntegration.CheckoutDependencyContractTest do
  use ExUnit.Case, async: true

  @workspace Path.expand("../..", __DIR__)
  @artifact_support Path.join(@workspace, "iconvex_integration/tools/artifact_audit_support.exs")
  Code.require_file(@artifact_support)

  @siblings [
    :iconvex,
    :iconvex_extras,
    :iconvex_telecom,
    :iconvex_specs_icu_archive_a,
    :iconvex_specs_icu_archive_b,
    :iconvex_specs_icu_archive_c,
    :iconvex_specs
  ]
  @overrides [
    :iconvex,
    :iconvex_specs_icu_archive_a,
    :iconvex_specs_icu_archive_b,
    :iconvex_specs_icu_archive_c
  ]

  test "plain checkout mode resolves every package from its sibling directory" do
    dependencies = Mix.Project.config() |> Keyword.fetch!(:deps) |> Map.new(&dependency/1)

    assert Map.keys(dependencies) |> Enum.sort() == Enum.sort(@siblings)

    for app <- @siblings do
      options = Map.fetch!(dependencies, app)
      expected_path = Path.join(@workspace, Atom.to_string(app))

      assert Path.expand(Keyword.fetch!(options, :path), @workspace <> "/iconvex_integration") ==
               expected_path

      assert Keyword.fetch!(options, :runtime) == false
    end

    for app <- @overrides do
      assert Map.fetch!(dependencies, app) |> Keyword.fetch!(:override)
    end
  end

  test "release probes state the exact current full-stack cardinalities" do
    readme = File.read!(Path.join(@workspace, "iconvex_integration/README.md"))

    artifact_audit =
      File.read!(Path.join(@workspace, "iconvex_integration/tools/artifact_audit.exs"))

    assert readme =~ "2,093/2,093 full-stack codecs"
    assert readme =~ "1,841/1,841 runtime Specs encode/decode checks"
    assert artifact_audit =~ "length(expected_encodings) == 2_093"
    assert artifact_audit =~ "expected_specs_count == 1_841"
    assert artifact_audit =~ "2,093/2,093 full-stack codecs"
    assert artifact_audit =~ "1,841/1,841 runtime Specs encode/decode checks"
    assert artifact_audit =~ ~s|System.fetch_env!("ICONVEX_ARTIFACT_ROOT")|
    assert artifact_audit =~ ~s|System.fetch_env!("ICONVEX_TARBALL_ROOT")|
    assert artifact_audit =~ ~s|System.fetch_env!("ICONVEX_WORKSPACE_ROOT")|
    assert artifact_audit =~ "7/7 artifact dependency roots"
    assert artifact_audit =~ "1,050/1,050 archive shard tables"
    assert artifact_audit =~ "88/88 workspace release evidence files byte-identical"
    assert artifact_audit =~ "2,255/2,255 packaged files recursively pinned and byte-identical"
    assert readme =~ "ICONVEX_ARTIFACT_ROOT=/absolute/path/to/unpacked/artifacts"
    assert readme =~ "ICONVEX_TARBALL_ROOT=/absolute/path/to/tarballs"
    assert readme =~ "ICONVEX_WORKSPACE_ROOT=/absolute/path/to/source/workspace"
    assert readme =~ "all 1,050 archive-shard tables"
    assert readme =~ "88 workspace release-evidence files"
    assert readme =~ "mix run --no-start --no-compile"

    assert artifact_audit |> literal_assignment!(:artifact_apps) |> Enum.sort() ==
             Enum.sort(@siblings)

    assert literal_assignment!(artifact_audit, :archive_shards) == [
             {:iconvex_specs_icu_archive_a, 1..350},
             {:iconvex_specs_icu_archive_b, 351..700},
             {:iconvex_specs_icu_archive_c, 701..1050}
           ]
  end

  test "RED: artifact probe preserves qualified RFC tables while enforcing GNU semantics" do
    artifact_audit =
      File.read!(Path.join(@workspace, "iconvex_integration/tools/artifact_audit.exs"))

    assert artifact_audit =~ "gnu_reclaimed_rfc_identities ="
    assert artifact_audit =~ "map_size(gnu_reclaimed_rfc_identities) == 25"
    assert artifact_audit =~ "Iconvex.canonical_name(source_name) == {:ok, gnu_canonical}"
    assert artifact_audit =~ "Iconvex.canonical_name(rfc_qualified) == {:ok, rfc_qualified}"
    assert artifact_audit =~ "Enum.sort(registration.aliases) == Enum.sort(expected_rfc_aliases)"
    assert artifact_audit =~ "for byte <- 0..255"
    assert artifact_audit =~ "gnu_alias_result == gnu_canonical_result"
    assert artifact_audit =~ "25/25 GNU/RFC collision migrations exhaustive"
  end

  test "artifact probe validates the exact clean roots before starting dependency applications" do
    artifact_audit =
      File.read!(Path.join(@workspace, "iconvex_integration/tools/artifact_audit.exs"))

    artifact_support =
      File.read!(Path.join(@workspace, "iconvex_integration/tools/artifact_audit_support.exs"))

    assert literal_assignment!(artifact_audit, :artifact_versions) ==
             Map.new(@siblings, &{&1, "0.1.0"})

    assert artifact_audit =~ "Map.keys(dependency_paths)"
    assert artifact_audit =~ "File.lstat!(artifact_root).type == :directory"
    assert artifact_audit =~ "File.lstat!(workspace_root).type == :directory"
    assert artifact_audit =~ "validated_roots ="

    dependency_validation =
      source_position!(artifact_audit, "dependency_paths = Mix.Project.deps_paths()")

    release_evidence_validation =
      source_position!(artifact_audit, "release_evidence_count =")

    complete_root_validation = source_position!(artifact_audit, "validated_roots =")

    application_start =
      source_position!(
        artifact_audit,
        "for app <- artifact_apps do\n  case Application.ensure_all_started(app)"
      )

    crypto_start =
      source_position!(
        artifact_audit,
        "IconvexIntegration.ArtifactAuditSupport.ensure_crypto!()"
      )

    crypto_code_path =
      source_position!(artifact_support, ~s|[root, "lib", "crypto-*", "ebin"]|)

    crypto_module_load =
      source_position!(artifact_support, "unless Code.ensure_loaded?(:crypto) do")

    crypto_application_start =
      source_position!(artifact_support, "Application.ensure_all_started(:crypto)")

    first_crypto_use = source_position!(artifact_audit, ":crypto.hash(:sha256")

    assert dependency_validation < application_start
    assert complete_root_validation < release_evidence_validation
    assert release_evidence_validation < crypto_start
    assert crypto_module_load < crypto_code_path
    assert crypto_code_path < crypto_application_start
    assert crypto_start < first_crypto_use
  end

  test "RED: artifact probe verifies each exact Hex tar and dependency requirement" do
    artifact_audit =
      File.read!(Path.join(@workspace, "iconvex_integration/tools/artifact_audit.exs"))

    artifact_support =
      File.read!(Path.join(@workspace, "iconvex_integration/tools/artifact_audit_support.exs"))

    iconvex_requirement = {"iconvex", "iconvex", "~> 0.1.0", false, "hexpm"}

    assert literal_assignment!(artifact_audit, :artifact_requirements) == %{
             iconvex: [],
             iconvex_extras: [iconvex_requirement],
             iconvex_specs_icu_archive_a: [iconvex_requirement],
             iconvex_specs_icu_archive_b: [iconvex_requirement],
             iconvex_specs_icu_archive_c: [iconvex_requirement],
             iconvex_specs: [
               iconvex_requirement,
               {"iconvex_specs_icu_archive_a", "iconvex_specs_icu_archive_a", "~> 0.1.0", false,
                "hexpm"},
               {"iconvex_specs_icu_archive_b", "iconvex_specs_icu_archive_b", "~> 0.1.0", false,
                "hexpm"},
               {"iconvex_specs_icu_archive_c", "iconvex_specs_icu_archive_c", "~> 0.1.0", false,
                "hexpm"}
             ],
             iconvex_telecom: [iconvex_requirement]
           }

    assert artifact_audit =~ ~s|System.fetch_env!("ICONVEX_TARBALL_ROOT")|
    assert artifact_audit =~ "Hex tarball set differs from the exact seven-package set"
    assert artifact_audit =~ "hex_tar!"
    assert artifact_audit =~ "Hex metadata requirements differ"
    assert artifact_support =~ "Hex tar contents differ from unpacked artifact"
    assert artifact_support =~ "Hex tar content differs from unpacked artifact"
    assert artifact_support =~ ~s|["CHECKSUM", "VERSION", "contents.tar.gz", "metadata.config"]|
    assert artifact_support =~ "tar_binary = File.read!(path)"
    assert artifact_support =~ ":erl_tar.extract({:binary, tar_binary}"
    assert artifact_support =~ ~s|:crypto.hash(:sha256, [version, metadata_binary, contents])|
    assert artifact_support =~ "Mix.Local.append_archives()"
    refute artifact_support =~ "Mix.path_for(:archives)"
    assert artifact_support =~ "apply(:mix_hex_tarball, :unpack"
    assert artifact_support =~ "[tar_binary, :memory]"
    refute artifact_support =~ "[File.read!(path), :memory]"
    refute artifact_support =~ ":erl_scan.string"
    refute artifact_support =~ ":erl_parse.parse_term"
    assert artifact_audit =~ "verify_contents_root!"
  end

  @tag :tmp_dir
  test "Hex reader accepts exact Core and Extras package shapes", %{tmp_dir: tmp_dir} do
    core =
      create_hex_tar!(tmp_dir, "iconvex", %{
        "name" => "iconvex",
        "app" => "iconvex",
        "version" => "0.1.0",
        "requirements" => %{}
      })

    extras =
      create_hex_tar!(tmp_dir, "iconvex_extras", %{
        "name" => "iconvex_extras",
        "app" => "iconvex_extras",
        "version" => "0.1.0",
        "requirements" => %{
          "iconvex" => %{
            "app" => "iconvex",
            "requirement" => "~> 0.1.0",
            "optional" => false,
            "repository" => "hexpm"
          }
        }
      })

    assert %{metadata: %{"name" => "iconvex"}, contents: %{"mix.exs" => "core"}} =
             IconvexIntegration.ArtifactAuditSupport.hex_tar!(core)

    assert %{
             metadata: %{
               "name" => "iconvex_extras",
               "requirements" => %{
                 "iconvex" => %{
                   "requirement" => "~> 0.1.0",
                   "optional" => false,
                   "repository" => "hexpm"
                 }
               }
             },
             contents: %{"mix.exs" => "iconvex_extras"}
           } = IconvexIntegration.ArtifactAuditSupport.hex_tar!(extras)
  end

  @tag :tmp_dir
  test "Hex reader rejects a corrupt envelope checksum", %{tmp_dir: tmp_dir} do
    valid = create_hex_tar!(tmp_dir, "checksum", valid_metadata("checksum"))
    corrupt = Path.join(tmp_dir, "checksum-corrupt.tar")

    valid
    |> outer_entries!()
    |> replace_entry!("CHECKSUM", String.duplicate("0", 64))
    |> write_tar!(corrupt)

    assert_raise RuntimeError, ~r/Hex inner checksum differs/, fn ->
      IconvexIntegration.ArtifactAuditSupport.hex_tar!(corrupt)
    end
  end

  @tag :tmp_dir
  test "Hex reader rejects duplicate outer and inner paths", %{tmp_dir: tmp_dir} do
    valid = create_hex_tar!(tmp_dir, "duplicates", valid_metadata("duplicates"))
    entries = outer_entries!(valid)
    duplicate_outer = Path.join(tmp_dir, "duplicate-outer.tar")
    write_tar!(entries ++ [{"VERSION", "3"}], duplicate_outer)

    assert_raise RuntimeError, ~r/Hex outer file set differs/, fn ->
      IconvexIntegration.ArtifactAuditSupport.hex_tar!(duplicate_outer)
    end

    duplicate_inner_tar = Path.join(tmp_dir, "duplicate-inner-contents.tar")
    write_tar!([{"mix.exs", "first"}, {"mix.exs", "second"}], duplicate_inner_tar)
    duplicate_contents = duplicate_inner_tar |> File.read!() |> :zlib.gzip()

    duplicate_inner =
      entries
      |> replace_entry!("contents.tar.gz", duplicate_contents)
      |> refresh_checksum!()
      |> write_tar!(Path.join(tmp_dir, "duplicate-inner.tar"))

    assert_raise RuntimeError, ~r/(duplicate file|official Hex reader rejected)/, fn ->
      IconvexIntegration.ArtifactAuditSupport.hex_tar!(duplicate_inner)
    end
  end

  @tag :tmp_dir
  test "Hex metadata parser rejects and does not intern an unknown atom", %{tmp_dir: tmp_dir} do
    atom_name = "iconvex_forbidden_atom_#{System.unique_integer([:positive])}"
    assert_raise ArgumentError, fn -> String.to_existing_atom(atom_name) end

    valid = create_hex_tar!(tmp_dir, "illegal-atom", valid_metadata("illegal_atom"))

    illegal =
      valid
      |> outer_entries!()
      |> replace_entry!(
        "metadata.config",
        metadata_entry!(valid) <> "{<<\"forbidden\">>,#{atom_name}}.\n"
      )
      |> refresh_checksum!()
      |> write_tar!(Path.join(tmp_dir, "illegal-atom.tar"))

    parent = self()

    {pid, reference} =
      spawn_monitor(fn ->
        result =
          try do
            IconvexIntegration.ArtifactAuditSupport.hex_tar!(illegal)
            :accepted
          rescue
            error -> {:rejected, Exception.message(error)}
          end

        existing =
          try do
            String.to_existing_atom(atom_name)
            true
          rescue
            ArgumentError -> false
          end

        send(parent, {:illegal_atom_probe, result, existing})
      end)

    assert_receive {:illegal_atom_probe, {:rejected, message}, false}, 5_000
    assert message =~ "official Hex reader rejected"
    assert_receive {:DOWN, ^reference, :process, ^pid, :normal}, 5_000
    assert_raise ArgumentError, fn -> String.to_existing_atom(atom_name) end
  end

  @tag :tmp_dir
  test "tar payload is byte-bound to its separately unpacked artifact root", %{tmp_dir: tmp_dir} do
    artifact_root = Path.join(tmp_dir, "artifact")
    File.mkdir_p!(Path.join(artifact_root, "lib/iconvex"))
    File.write!(Path.join(artifact_root, "mix.exs"), "core")
    File.write!(Path.join(artifact_root, "lib/iconvex.ex"), "same")
    File.write!(Path.join(artifact_root, "lib/iconvex/application.ex"), "nested")

    contents = %{
      "mix.exs" => "core",
      "lib/iconvex.ex" => "same",
      "lib/iconvex/application.ex" => "nested"
    }

    assert :ok =
             IconvexIntegration.ArtifactAuditSupport.verify_contents_root!(
               contents,
               artifact_root,
               "iconvex"
             )

    counterfeit = Map.put(contents, "lib/iconvex.ex", "different")

    assert_raise RuntimeError, ~r/Hex tar content differs from unpacked artifact/, fn ->
      IconvexIntegration.ArtifactAuditSupport.verify_contents_root!(
        counterfeit,
        artifact_root,
        "iconvex"
      )
    end
  end

  test "artifact probe compares the complete packaged release-evidence boundary" do
    readme = File.read!(Path.join(@workspace, "iconvex_integration/README.md"))

    artifact_audit =
      File.read!(Path.join(@workspace, "iconvex_integration/tools/artifact_audit.exs"))

    assert literal_assignment!(artifact_audit, :repository_only_top_level) == %{
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

    assert readme =~ "`LICENSE.GPL-3.0`"
    assert readme =~ "`ICU_SWAP_LFNL_DIFFERENTIAL.md`"
    assert readme =~ "`OPENJDK_ENCODINGS.md`"
    assert readme =~ "`UTF8_MAC.md`"
    assert artifact_audit =~ "repository-only workspace evidence is absent"
    assert artifact_audit =~ "repository-only evidence leaked into artifact"
    assert artifact_audit =~ "workspace release evidence differs from artifact"
    assert artifact_audit =~ "workspace release evidence content differs from artifact"
    assert artifact_audit =~ "release_evidence_count == 88"
  end

  test "artifact probe pins and byte-compares every recursively packaged file" do
    artifact_audit =
      File.read!(Path.join(@workspace, "iconvex_integration/tools/artifact_audit.exs"))

    assert literal_assignment!(artifact_audit, :artifact_tree_expectations) == %{
             iconvex: {127, "05a5f29bed880647d9ddc3533f03541352d3ae24021d16d0f2e607395fc51a12"},
             iconvex_extras:
               {99, "87f86a956d1fbe920423fd30d95bb04e66f57ff10d5a276335c812c0bf302001"},
             iconvex_specs:
               {907, "712624b2fcd1aa350addb151878534f3d3e87f05801340c4be0357872b053eaf"},
             iconvex_specs_icu_archive_a:
               {356, "a4d4265674625e01d242080a163a0bfef17aa77e7147fe6855c8d0f48e644ff3"},
             iconvex_specs_icu_archive_b:
               {356, "435b590156286597f2657ee78dfabd87fef7984c90eb56b5a971906fa23e300a"},
             iconvex_specs_icu_archive_c:
               {356, "e7d6671a8f4a3535e4cacb6828b95d1bf2e670c5b71e877e73b4ee622194c3c9"},
             iconvex_telecom:
               {54, "45a87a227fa6ef56c29e6123f3193d0ed90c0459fbcf9a4f32940a948f68bc86"}
           }

    assert artifact_audit =~ "artifact tree file count differs"
    assert artifact_audit =~ "artifact tree digest differs"
    assert artifact_audit =~ "packaged file differs from workspace source"
  end

  test "artifact probe pins Iowa punched-card evidence and its qualified codec boundary" do
    readme = File.read!(Path.join(@workspace, "iconvex_integration/README.md"))

    artifact_audit =
      File.read!(Path.join(@workspace, "iconvex_integration/tools/artifact_audit.exs"))

    for {relative, digest} <- [
          {"sources/punched-card-codes/canonical_maps.csv",
           "541347c32f7610d3830b9259a68891b6ae2a410b1251f039f37930b83c3476c7"},
          {"sources/punched-card-codes/decode_aliases.csv",
           "da98e499e2b860bea2f35b7fbd66e14db1142047a7ac9ffe5b84174875b65323"},
          {"sources/punched-card-codes/PROFILE_DISPOSITION.md",
           "e8b8320fab1a422ef3c36bff8e87dabc828198c50f141d54f62c7c551c8d94fc"},
          {"sources/punched-card-codes/SOURCE_METADATA.md",
           "e42d5114417710ae1233942078813a3951ad2970720e150c155b511fd583d25c"}
        ] do
      assert artifact_audit =~ relative
      assert artifact_audit =~ digest
    end

    assert artifact_audit =~ ~s|sources/punched-card-codes/*.pdf|
    assert artifact_audit =~ ~s|sources/punched-card-codes/*.html|

    for name <- ["BCD-CDC-IOWA", "BCD-CDC-IOWA-16BE", "BCD-CDC-IOWA-16LE"] do
      assert artifact_audit =~ name
    end

    for name <- ["BCD-CDC", "CDC punched-card BCD", "CDC-PUNCHED-CARD-BCD"] do
      assert artifact_audit =~ name
    end

    assert readme =~ "2,255 recursively packaged files"
    assert readme =~ "Iowa punched-card"
  end

  test "RED: artifact probe pins both IBM six-bit Transcode profiles and rejects the generic family" do
    readme = File.read!(Path.join(@workspace, "iconvex_integration/README.md"))

    artifact_audit =
      File.read!(Path.join(@workspace, "iconvex_integration/tools/artifact_audit.exs"))

    for {relative, digest} <- [
          {"sources/ibm-six-bit-transcode/ga27-3005-3.csv",
           "cbb94188f9ac1a8b9a95dcff91d0744c84f77ad53377d62dd76eff4d6a476416"},
          {"sources/ibm-six-bit-transcode/ga27-3004-2.csv",
           "5dccf290006224a0de51dddda9ec227183f1527610f61cf2f70b606ccea7c31e"},
          {"sources/ibm-six-bit-transcode/SOURCE_METADATA.md",
           "3b9fe66217399b16b338ffa41209d2b77237886cde306e10e63f82374506908f"}
        ] do
      assert artifact_audit =~ relative
      assert artifact_audit =~ digest
    end

    assert artifact_audit =~ ~s|sources/ibm-six-bit-transcode/*.pdf|

    for name <- [
          "IBM-2780-SIX-BIT-TRANSCODE-GA27-3005-3",
          "IBM-BSC-SIX-BIT-TRANSCODE-GA27-3004-2",
          "IBM-2780-SIX-BIT-TRANSCODE-1971",
          "IBM-BSC-SIX-BIT-TRANSCODE-1970"
        ] do
      assert artifact_audit =~ name
    end

    for generic <- ["TRANSCODE", "SIX-BIT-TRANSCODE", "IBM-SIX-BIT-TRANSCODE"] do
      assert artifact_audit =~ generic
    end

    assert artifact_audit =~ "0x2311"
    assert artifact_audit =~ "0x003C"
    assert artifact_audit =~ "%Iconvex.Packed.LSB{"
    assert artifact_audit =~ ~s|packed_lsb = "\#{canonical}-PACKED-LSB"|
    assert artifact_audit =~ ~s|packed_msb = "\#{canonical}-PACKED-MSB"|
    assert artifact_audit =~ "%{lsb | bit_order: :msb}"
    assert artifact_audit =~ "{:error, :bit_order_mismatch}"
    assert readme =~ "IBM Six-Bit Transcode"
    assert readme =~ "102 canonical packed names"
    assert readme =~ "220 packed alias forms"
  end

  test "RED: artifact probe executes every canonical and alias packed suffix contract" do
    artifact_audit =
      File.read!(Path.join(@workspace, "iconvex_integration/tools/artifact_audit.exs"))

    assert artifact_audit =~ "packed_name_cases ="
    assert artifact_audit =~ "for packed_case <- packed_name_cases do"
    assert artifact_audit =~ "length(packed_name_cases) == 322"
    assert artifact_audit =~ "Iconvex.Telecom.Packed.encode_from_utf8(sample, name)"
    assert artifact_audit =~ "Iconvex.Telecom.Packed.decode_to_utf8(packed, name)"

    assert artifact_audit =~
             "Iconvex.Telecom.Packed.encode_from_utf8(sample, name, opposite_order)"

    assert artifact_audit =~ "Iconvex.Telecom.Packed.decode_to_utf8(packed, name, opposite_order)"
    assert artifact_audit =~ "Iconvex.Telecom.Packed.decode_to_utf8(mistagged, name)"
    assert artifact_audit =~ "{:error, :bit_order_mismatch}"
  end

  test "RED: artifact probe parses both packaged Transcode maps and checks all 64 cells" do
    artifact_audit =
      File.read!(Path.join(@workspace, "iconvex_integration/tools/artifact_audit.exs"))

    assert artifact_audit =~ "transcode_csv_vector! ="
    assert artifact_audit =~ ~s(["unit_hex,unicode_hex" | rows])
    assert artifact_audit =~ "length(rows) == 64"
    assert artifact_audit =~ "String.to_integer(unit_hex, 16) == expected_unit"
    assert artifact_audit =~ "for {codepoint, unit} <- Enum.with_index(vector) do"
    assert artifact_audit =~ "codec.decode(<<unit>>) == {:ok, [codepoint]}"
    assert artifact_audit =~ "codec.encode([codepoint]) == {:ok, <<unit>>}"
  end

  test "artifact probe executes its root guard and rejects sibling checkouts" do
    integration_root = Path.join(@workspace, "iconvex_integration")
    script = Path.join(integration_root, "tools/artifact_audit.exs")

    {output, status} =
      System.cmd(
        System.find_executable("mix"),
        ["run", "--no-compile", script],
        cd: integration_root,
        env: [
          {"ICONVEX_ARTIFACT_ROOT", @workspace},
          {"ICONVEX_WORKSPACE_ROOT", @workspace},
          {"MIX_ENV", "test"}
        ],
        stderr_to_stdout: true
      )

    assert status != 0
    assert output =~ "iconvex resolved outside its exact unpacked artifact root"
    refute output =~ "clean artifact audit"
  end

  test "OTP crypto fallback wildcard resolves to the installed ebin directory" do
    root = :code.root_dir() |> List.to_string()

    matches =
      [root, "lib", "crypto-*", "ebin"]
      |> Path.join()
      |> Path.wildcard()

    assert [_ | _] = matches
    assert Enum.all?(matches, &File.dir?/1)
  end

  test "OTP crypto fallback is executed under no-start and hashes successfully" do
    integration_root = Path.join(@workspace, "iconvex_integration")
    probe = Path.join(integration_root, "tools/artifact_audit_crypto_probe.exs")

    {output, status} =
      System.cmd(
        System.find_executable("mix"),
        ["run", "--no-start", "--no-compile", probe],
        cd: integration_root,
        env: [{"MIX_ENV", "test"}],
        stderr_to_stdout: true
      )

    assert status == 0, output
    refute output =~ "warning:"
    assert output =~ "artifact audit crypto probe: before=false after=true sha256_bytes=32"
  end

  defp dependency({app, options}) when is_list(options), do: {app, options}
  defp dependency({app, _requirement, options}), do: {app, options}

  defp create_hex_tar!(tmp_dir, name, metadata) do
    :ok = Mix.Local.append_archives()

    files = [{~c"mix.exs", if(name == "iconvex", do: "core", else: name)}]
    {:ok, %{tarball: tarball}} = apply(:mix_hex_tarball, :create, [metadata, files])
    path = Path.join(tmp_dir, "#{name}.tar")
    File.write!(path, tarball)
    path
  end

  defp valid_metadata(name) do
    %{
      "name" => name,
      "app" => name,
      "version" => "0.1.0",
      "requirements" => %{}
    }
  end

  defp outer_entries!(path) do
    {:ok, entries} = :erl_tar.extract(String.to_charlist(path), [:memory])
    Enum.map(entries, fn {name, contents} -> {List.to_string(name), contents} end)
  end

  defp metadata_entry!(path) do
    path
    |> outer_entries!()
    |> Map.new()
    |> Map.fetch!("metadata.config")
  end

  defp replace_entry!(entries, target, replacement) do
    assert Enum.count(entries, fn {name, _contents} -> name == target end) == 1

    Enum.map(entries, fn
      {^target, _contents} -> {target, replacement}
      entry -> entry
    end)
  end

  defp refresh_checksum!(entries) do
    files = Map.new(entries)

    checksum =
      :crypto.hash(:sha256, [
        Map.fetch!(files, "VERSION"),
        Map.fetch!(files, "metadata.config"),
        Map.fetch!(files, "contents.tar.gz")
      ])
      |> Base.encode16(case: :upper)

    replace_entry!(entries, "CHECKSUM", checksum)
  end

  defp write_tar!(entries, path) do
    :ok =
      :erl_tar.create(
        String.to_charlist(path),
        Enum.map(entries, fn {name, contents} -> {String.to_charlist(name), contents} end),
        []
      )

    path
  end

  defp literal_assignment!(source, name) do
    ast = Code.string_to_quoted!(source)

    {_ast, value} =
      Macro.prewalk(ast, nil, fn
        {:=, _metadata, [{variable, _variable_metadata, _context}, value]} = node, nil
        when variable == name ->
          {node, value}

        node, value ->
          {node, value}
      end)

    assert value != nil, "missing literal assignment for #{name}"
    {literal, []} = Code.eval_quoted(value, [], __ENV__)
    literal
  end

  defp source_position!(source, needle) do
    case :binary.match(source, needle) do
      {position, _length} -> position
      :nomatch -> flunk("missing source marker: #{inspect(needle)}")
    end
  end
end

defmodule Iconvex.Specs.UnihanTelegraphPropertyTokenTest do
  use ExUnit.Case, async: false

  @moduletag timeout: 180_000

  @source_dir Path.expand(
                "../priv/sources/unihan-17.0.0-telegraph",
                __DIR__
              )
  @mainland_path Path.join(@source_dir, "mainland_tokens.csv")
  @taiwan_path Path.join(@source_dir, "taiwan_tokens.csv")
  @policy_path Path.join(@source_dir, "taiwan_policy.csv")
  @metadata_path Path.join(@source_dir, "SOURCE_METADATA.md")
  @inventory_path Path.expand("../SUPPORTED_PROPERTY_TOKEN_MAPPING_INVENTORY.csv", __DIR__)
  @inventory_generator Path.expand(
                         "../tools/generate_property_token_mapping_inventory.exs",
                         __DIR__
                       )
  @fixture_dir Path.expand("fixtures/unihan-17.0.0-telegraph", __DIR__)
  @unihan_fixture Path.join(@fixture_dir, "Unihan_OtherMappings-17.0.0.txt")
  @unicode_data_fixture Path.join(@fixture_dir, "UnicodeData-17.0.0.txt")
  @source_extractor Path.expand("../tools/extract_unihan_telegraph.py", __DIR__)
  @source_verifier Path.expand("../tools/verify_unihan_telegraph.py", __DIR__)

  @hashes %{
    mainland: "685b057cc0690c19718966aa02121887071398227c6b48605cf9347db70e16f0",
    taiwan: "15dc21eacf695ce038500e68fa40c125d0762b5e265c9683f82f17d2eac878a6",
    policy: "79890c693597f1f25b4e68abe5627883c8299d7d382ed8865c42a3d361971696",
    metadata: "59a38784c2ec0e931d6f6edeb287ed6cff4077014dba1263f0d76f3339a07ddd"
  }

  @source_fixture_hashes %{
    unihan: "4fabda168d04a5ac360809a8bfa377fe54e04fbc069ba67cacad4df03d691fa0",
    unicode_data: "2e1efc1dcb59c575eedf5ccae60f95229f706ee6d031835247d843c11d96470c"
  }

  @mainland Iconvex.Specs.Unihan17MainlandTelegraphDecimalToken
  @taiwan_readable Iconvex.Specs.Unihan17TaiwanTelegraphDecimalTokenReadable
  @taiwan_lossless Iconvex.Specs.Unihan17TaiwanTelegraphDecimalTokenLosslessVPUA1
  @profiles [@mainland, @taiwan_readable, @taiwan_lossless]

  @mapping_names [
    "UNIHAN-17.0.0-KMAINLANDTELEGRAPH-DECIMAL-TOKEN",
    "UNIHAN-17.0.0-KTAIWANTELEGRAPH-DECIMAL-TOKEN-READABLE",
    "UNIHAN-17.0.0-KTAIWANTELEGRAPH-DECIMAL-TOKEN-LOSSLESS-VPUA-1"
  ]

  test "pins the exact Unicode-derived fixtures, counts, regional deltas, and policies" do
    assert sha256(File.read!(@mainland_path)) == @hashes.mainland
    assert sha256(File.read!(@taiwan_path)) == @hashes.taiwan
    assert sha256(File.read!(@policy_path)) == @hashes.policy
    assert sha256(File.read!(@metadata_path)) == @hashes.metadata

    mainland = token_map(@mainland_path)
    taiwan = token_map(@taiwan_path)
    policy = policy_map()

    assert map_size(mainland) == 7_078
    assert map_size(taiwan) == 9_026
    assert map_size(policy) == 9_026
    assert mainland |> Map.values() |> Enum.uniq() |> length() == 7_078
    assert taiwan |> Map.values() |> Enum.uniq() |> length() == 9_024
    assert mainland |> Map.keys() |> Enum.min() == "0001"
    assert mainland |> Map.keys() |> Enum.max() == "9694"
    assert taiwan |> Map.keys() |> Enum.min() == "0001"
    assert taiwan |> Map.keys() |> Enum.max() == "9798"
    assert 10_000 - map_size(mainland) == 2_922
    assert 10_000 - map_size(taiwan) == 974

    shared =
      Map.keys(mainland) |> MapSet.new() |> MapSet.intersection(MapSet.new(Map.keys(taiwan)))

    assert MapSet.size(shared) == 6_770
    assert Enum.count(shared, &(mainland[&1] == taiwan[&1])) == 4_154
    assert Enum.count(shared, &(mainland[&1] != taiwan[&1])) == 2_616
    assert map_size(mainland) - MapSet.size(shared) == 308
    assert map_size(taiwan) - MapSet.size(shared) == 2_256

    for {token, mainland_scalar, taiwan_scalar} <- [
          {"0001", 0x4E00, 0x4E00},
          {"0948", 0x56FD, 0x570B},
          {"1947", 0x7231, 0x611B},
          {"5618", 0x8427, 0x856D}
        ] do
      assert mainland[token] == mainland_scalar
      assert taiwan[token] == taiwan_scalar
    end

    assert reverse_groups(taiwan) |> Map.take([0x5875, 0x843C]) == %{
             0x5875 => ["1057", "7775"],
             0x843C => ["5501", "9795"]
           }

    assert policy["0066"] == %{
             source: 0x2F81B,
             role: :canonical,
             output: 0xF8B00,
             reason: :normalization
           }

    assert policy["2210"] == %{
             source: 0x2F8BA,
             role: :canonical,
             output: 0xF8B01,
             reason: :normalization
           }

    assert policy["7775"] == %{
             source: 0x5875,
             role: :decode_only,
             output: 0xF8B02,
             reason: :duplicate
           }

    assert policy["9795"] == %{
             source: 0x843C,
             role: :decode_only,
             output: 0xF8B03,
             reason: :duplicate
           }

    assert Enum.all?(policy, fn {token, row} -> row.source == taiwan[token] end)
    assert policy |> Map.values() |> Enum.map(& &1.output) |> Enum.uniq() |> length() == 9_026
  end

  test "RED: repository Unicode fixtures independently regenerate and verify every table" do
    python = System.find_executable("python3") || flunk("python3 is unavailable")

    assert sha256(File.read!(@unihan_fixture)) == @source_fixture_hashes.unihan
    assert sha256(File.read!(@unicode_data_fixture)) == @source_fixture_hashes.unicode_data
    assert File.regular?(@source_extractor)
    assert File.regular?(@source_verifier)
    refute File.read!(@source_verifier) =~ "import extract_unihan_telegraph"

    {verify_output, 0} =
      System.cmd(python, [@source_verifier],
        cd: System.tmp_dir!(),
        stderr_to_stdout: true
      )

    assert verify_output =~ "all 30,000 token outcomes are source-exact"
    assert verify_output =~ "Mainland 7,078/7,078"
    assert verify_output =~ "Taiwan readable 9,026/9,024"
    assert verify_output =~ "lossless 9,026/9,026"
    assert verify_output =~ "NFC/NFD/NFKC/NFKD policies are exact"

    temp =
      Path.join(
        System.tmp_dir!(),
        "iconvex-unihan-source-contract-#{System.unique_integer([:positive])}"
      )

    generated = Path.join(temp, "generated")
    tampered_fixtures = Path.join(temp, "tampered-fixtures")
    tampered_package = Path.join(temp, "tampered-package")
    File.mkdir_p!(temp)
    on_exit(fn -> File.rm_rf!(temp) end)

    {generate_output, 0} =
      System.cmd(python, [@source_extractor, "--output-dir", generated],
        cd: System.tmp_dir!(),
        stderr_to_stdout: true
      )

    assert generate_output =~ "generated 3 files"

    for name <- ["mainland_tokens.csv", "taiwan_tokens.csv", "taiwan_policy.csv"] do
      assert File.read!(Path.join(generated, name)) == File.read!(Path.join(@source_dir, name))
    end

    {overwrite_error, overwrite_status} =
      System.cmd(python, [@source_extractor, "--output-dir", @source_dir],
        cd: System.tmp_dir!(),
        stderr_to_stdout: true
      )

    assert overwrite_status != 0

    assert overwrite_error =~
             "refusing to overwrite packaged tables without --allow-package-overwrite"

    File.cp_r!(@fixture_dir, tampered_fixtures)

    tampered_unihan = Path.join(tampered_fixtures, "Unihan_OtherMappings-17.0.0.txt")

    File.write!(
      tampered_unihan,
      File.read!(tampered_unihan)
      |> String.replace("U+4E00\tkMainlandTelegraph\t0001", "U+4E00\tkMainlandTelegraph\t9999",
        global: false
      )
    )

    {fixture_error, fixture_status} =
      System.cmd(python, [@source_verifier, "--fixtures-dir", tampered_fixtures],
        stderr_to_stdout: true
      )

    assert fixture_status != 0
    assert fixture_error =~ "source fixture SHA-256 mismatch"

    File.mkdir_p!(tampered_package)

    for name <- ["mainland_tokens.csv", "taiwan_tokens.csv", "taiwan_policy.csv"] do
      File.cp!(Path.join(@source_dir, name), Path.join(tampered_package, name))
    end

    tampered_table = Path.join(tampered_package, "mainland_tokens.csv")
    File.write!(tampered_table, File.read!(tampered_table) <> "\n")

    {table_error, table_status} =
      System.cmd(
        python,
        [@source_verifier, "--package-dir", tampered_package],
        stderr_to_stdout: true
      )

    assert table_status != 0
    assert table_error =~ "packaged table SHA-256 mismatch"
  end

  test "RED: source asset validation rejects hash-valid semantic corruption" do
    validator = Iconvex.Specs.UnihanTelegraphToken.SourceAsset
    assets = source_assets()

    validated = apply(validator, :validate!, [assets, @hashes])
    assert length(validated.mainland_rows) == 7_078
    assert length(validated.taiwan_rows) == 9_026
    assert length(validated.policy_rows) == 9_026

    assert_raise ArgumentError, ~r/mainland SHA-256 mismatch/, fn ->
      apply(validator, :validate!, [Map.update!(assets, :mainland, &(&1 <> "\n")), @hashes])
    end

    assert_semantic_rejection(
      validator,
      assets,
      :mainland,
      fn bytes ->
        String.replace(bytes, "decimal_token,unicode_scalar", "token,unicode_scalar",
          global: false
        )
      end,
      ~r/mainland header/
    )

    assert_semantic_rejection(
      validator,
      assets,
      :mainland,
      fn bytes ->
        String.replace(bytes, "0001,U+4E00\n0002,U+4E01", "0002,U+4E01\n0001,U+4E00",
          global: false
        )
      end,
      ~r/strictly increasing/
    )

    assert_semantic_rejection(
      validator,
      assets,
      :mainland,
      fn bytes ->
        String.replace(bytes, "0001,U+4E00", "0001,U+D800", global: false)
      end,
      ~r/Unicode scalar/
    )

    assert_semantic_rejection(
      validator,
      assets,
      :policy,
      fn bytes ->
        String.replace(
          bytes,
          "0001,U+4E00,canonical-minimum,U+4E00,source-scalar",
          "0001,U+4E01,canonical-minimum,U+4E00,source-scalar",
          global: false
        )
      end,
      ~r/source.*Taiwan/i
    )

    assert_semantic_rejection(
      validator,
      assets,
      :policy,
      fn bytes ->
        String.replace(
          bytes,
          "9795,U+843C,decode-alias,U+F8B03,duplicate-readable-reverse",
          "9795,U+843C,decode-alias,U+F8B02,duplicate-readable-reverse",
          global: false
        )
      end,
      ~r/lossless output.*unique/i
    )
  end

  test "RED: exposes the three telegraph property-token mappings without codec aliases" do
    assert apply(Iconvex.Specs, :property_token_mappings, []) |> Enum.take(3) == @profiles

    for {module, mapping_name} <- Enum.zip(@profiles, @mapping_names) do
      assert apply(module, :mapping_name, []) == mapping_name

      metadata = apply(module, :metadata, [])
      assert metadata.mapping_name == mapping_name
      assert metadata.unicode_version == "17.0.0"
      assert metadata.property_status == :provisional
      assert metadata.grammar == "[0-9]{4}"
      assert metadata.transport == :single_property_token
      assert metadata.stream_transport == :undefined
      assert metadata.aliases == []

      assert module.module_info(:attributes)[:behaviour] == [
               Iconvex.Specs.PropertyTokenMapping
             ]

      assert Iconvex.canonical_name(mapping_name) == :error
      assert Iconvex.convert("0001", mapping_name, "UTF-8") == {:error, :unknown_encoding}
      assert Iconvex.stream([], mapping_name, "UTF-8") == {:error, :unknown_encoding}
    end

    for generic <- [
          "CHINESE-TELEGRAPH",
          "CHINESE-TELEGRAPH-CODE",
          "CHINESE-COMMERCIAL-CODE",
          "CHINESE-TELEGRAPHIC-CODE",
          "CNS2DCI"
        ] do
      assert Iconvex.canonical_name(generic) == :error
    end
  end

  test "RED: generated property-token inventory is an exact public metadata snapshot" do
    assert File.regular?(@inventory_generator)

    all_profiles = apply(Iconvex.Specs, :property_token_mappings, [])

    rows =
      Enum.map(all_profiles, fn module ->
        metadata = apply(module, :metadata, [])

        profile =
          case metadata.reverse_policy do
            :unique -> "exact"
            :minimum_decimal_token -> "readable-minimum-token-reverse"
            :lossless_vpua_1 -> "lossless-vpua-1"
          end

        Enum.join(
          [
            metadata.mapping_name,
            inspect(module),
            Atom.to_string(metadata.unihan_property),
            profile,
            metadata.assigned_tokens,
            metadata.reverse_scalars,
            metadata.grammar,
            Atom.to_string(metadata.transport),
            "no",
            "no"
          ],
          ","
        )
      end)

    expected =
      Enum.join(
        [
          "mapping_name,module,unicode_property,profile,assigned_tokens,reverse_scalars,grammar,transport,codec_registry,gnu_libiconv_1_19_exact_alias"
          | rows
        ],
        "\n"
      ) <> "\n"

    assert File.read!(@inventory_path) == expected

    temp =
      Path.join(
        System.tmp_dir!(),
        "iconvex-property-token-inventory-#{System.unique_integer([:positive])}"
      )

    generated = Path.join(temp, "inventory.csv")
    File.mkdir_p!(temp)
    on_exit(fn -> File.rm_rf!(temp) end)

    {generate_output, 0} = run_inventory_generator(["--output", generated])
    assert generate_output =~ "wrote 4 property-token mappings"
    assert File.read!(generated) == expected

    {check_output, 0} = run_inventory_generator(["--check", "--output", generated])
    assert check_output =~ "is current"

    File.write!(generated, expected <> "stale\n")
    {stale_output, stale_status} = run_inventory_generator(["--check", "--output", generated])
    assert stale_status != 0
    assert stale_output =~ "is out of date"
  end

  test "RED: all 10,000 token values decode exactly in all three profiles" do
    mainland = token_map(@mainland_path)
    taiwan = token_map(@taiwan_path)
    policy = policy_map()

    for value <- 0..9_999 do
      token = decimal_token(value)

      assert apply(@mainland, :decode_token, [token]) == expected_decode(mainland, token)
      assert apply(@taiwan_readable, :decode_token, [token]) == expected_decode(taiwan, token)

      assert apply(@taiwan_lossless, :decode_token, [token]) ==
               expected_policy_decode(policy, token)
    end
  end

  test "RED: every profile reverse is exhaustive and applies only its stated policy" do
    mainland = token_map(@mainland_path)
    taiwan = token_map(@taiwan_path)
    policy = policy_map()

    for {token, scalar} <- mainland do
      assert apply(@mainland, :encode_scalar, [scalar]) == {:ok, token}
    end

    readable_reverse =
      taiwan
      |> Enum.sort_by(fn {token, _scalar} -> token end)
      |> Enum.reduce(%{}, fn {token, scalar}, acc -> Map.put_new(acc, scalar, token) end)

    assert map_size(readable_reverse) == 9_024

    for {scalar, token} <- readable_reverse do
      assert apply(@taiwan_readable, :encode_scalar, [scalar]) == {:ok, token}
    end

    assert apply(@taiwan_readable, :encode_scalar, [0x5875]) == {:ok, "1057"}
    assert apply(@taiwan_readable, :encode_scalar, [0x843C]) == {:ok, "5501"}
    assert apply(@taiwan_readable, :decode_token, ["7775"]) == {:ok, 0x5875}
    assert apply(@taiwan_readable, :decode_token, ["9795"]) == {:ok, 0x843C}

    for {token, row} <- policy do
      assert apply(@taiwan_lossless, :encode_scalar, [row.output]) == {:ok, token}
    end

    for scalar <- [0x2F81B, 0x2F8BA] do
      assert apply(@taiwan_lossless, :encode_scalar, [scalar]) ==
               {:error, {:unrepresentable_scalar, scalar}}
    end
  end

  test "RED: malformed token and scalar errors are exact and deterministic" do
    for module <- @profiles do
      for length <- 0..3 do
        token = :binary.copy("0", length)

        assert apply(module, :decode_token, [token]) ==
                 {:error, {:invalid_token_length, length}}
      end

      for token <- ["00000", "+001", "-001", " 001", "001 ", "0 01", "\t001"] do
        assert apply(module, :decode_token, [token]) ==
                 if(byte_size(token) == 4,
                   do: first_invalid_digit(token),
                   else: {:error, {:invalid_token_length, byte_size(token)}}
                 )
      end

      assert apply(module, :decode_token, [<<"0", 0xC3, 0xA9, "1">>]) ==
               {:error, {:invalid_token_digit, 1, <<0xC3>>}}

      assert apply(module, :decode_token, [1234]) == {:error, {:invalid_argument, :token}}
      assert apply(module, :encode_scalar, ["一"]) == {:error, {:invalid_argument, :scalar}}

      for scalar <- [-1, 0xD800, 0xDFFF, 0x110000] do
        assert apply(module, :encode_scalar, [scalar]) ==
                 {:error, {:invalid_unicode_scalar, scalar}}
      end

      assert apply(module, :encode_scalar, [0x2603]) ==
               {:error, {:unrepresentable_scalar, 0x2603}}
    end
  end

  test "RED: UTF-8 token helpers accept exactly one scalar and preserve malformed offsets" do
    for {module, token, scalar} <- [
          {@mainland, "0001", 0x4E00},
          {@taiwan_readable, "0001", 0x4E00},
          {@taiwan_lossless, "0066", 0xF8B00}
        ] do
      utf8 = <<scalar::utf8>>
      assert apply(module, :decode_token_to_utf8, [token]) == {:ok, utf8}
      assert apply(module, :encode_utf8_to_token, [utf8]) == {:ok, token}
      assert apply(module, :encode_utf8_to_token, [<<>>]) == {:error, {:invalid_scalar_count, 0}}

      assert apply(module, :encode_utf8_to_token, [utf8 <> utf8]) ==
               {:error, {:invalid_scalar_count, 2}}

      assert apply(module, :encode_utf8_to_token, ["e\u0301"]) ==
               {:error, {:invalid_scalar_count, 2}}

      assert apply(module, :encode_utf8_to_token, ["👨‍👩‍👧‍👦"]) ==
               {:error, {:invalid_scalar_count, 7}}

      assert apply(module, :encode_utf8_to_token, [<<0xFF>>]) ==
               {:error, {:invalid_utf8, :invalid_sequence, 0, <<0xFF>>}}

      assert apply(module, :encode_utf8_to_token, [<<0xE4, 0xB8>>]) ==
               {:error, {:invalid_utf8, :incomplete_sequence, 0, <<0xE4, 0xB8>>}}

      assert apply(module, :encode_utf8_to_token, [[scalar]]) ==
               {:error, {:invalid_argument, :utf8}}
    end
  end

  test "RED: UTF-8 cardinality scanning is bounded and preserves the core error contract" do
    for malformed <- [
          <<?A, 0xFF, ?B>>,
          <<0xC0, 0x80>>,
          <<0xED, 0xA0, 0x80>>,
          <<0xF4, 0x90, 0x80, 0x80>>,
          <<?A, 0xE4, 0xB8>>,
          <<0xF0, 0x9F, 0x98>>
        ] do
      expected =
        case Iconvex.UnicodeCodec.decode(%{id: :utf8}, malformed) do
          {:error, kind, offset, sequence} ->
            {:error, {:invalid_utf8, kind, offset, sequence}}
        end

      for module <- @profiles do
        assert apply(module, :encode_utf8_to_token, [malformed]) == expected
      end
    end

    input = :binary.copy("A", 1_000_000)
    parent = self()
    reply = make_ref()

    {_pid, monitor} =
      spawn_monitor(fn ->
        Process.flag(:max_heap_size, %{size: 250_000, kill: true, error_logger: false})
        result = apply(@mainland, :encode_utf8_to_token, [input])
        send(parent, {reply, result})
      end)

    assert_receive {^reply, {:error, {:invalid_scalar_count, 1_000_000}}}, 10_000
    assert_receive {:DOWN, ^monitor, :process, _pid, :normal}, 1_000
  end

  test "RED: the successful one-scalar UTF-8 hot path has bounded relative reductions" do
    scalar_reductions =
      reduction_measure(fn -> apply(@mainland, :encode_scalar, [0x4E00]) end)

    utf8_reductions =
      reduction_measure(fn -> apply(@mainland, :encode_utf8_to_token, ["一"]) end)

    assert scalar_reductions > 0
    assert utf8_reductions / scalar_reductions <= 1.35
  end

  test "RED: lossless outputs remove every normalization collision without implicit normalization" do
    taiwan = token_map(@taiwan_path)
    policy = policy_map()

    for form <- [:nfc, :nfd, :nfkc, :nfkd] do
      collisions = normalization_collisions(taiwan, form)

      assert Map.take(collisions, [0x51B5, 0x62FC]) == %{
               0x51B5 => [{"0066", 0x2F81B}, {"0400", 0x51B5}],
               0x62FC => [{"2178", 0x62FC}, {"2210", 0x2F8BA}]
             }

      assert map_size(collisions) == 2

      for {_token, row} <- policy do
        assert normalize(row.output, form) == [row.output]
      end
    end

    assert Enum.map(["0066", "2210", "7775", "9795"], &policy[&1].output) ==
             Enum.to_list(0xF8B00..0xF8B03)
  end

  test "RED: runtime lookups perform no filesystem reads" do
    {metadata, control_calls} = traced_filesystem_calls(fn -> File.read!(@metadata_path) end)
    assert is_binary(metadata)

    assert Enum.any?(control_calls, fn
             {File, :read!, [@metadata_path]} -> true
             _other -> false
           end)

    {results, runtime_calls} =
      traced_filesystem_calls(fn ->
        for module <- @profiles do
          {
            apply(module, :mapping_name, []),
            apply(module, :metadata, []),
            apply(module, :decode_token, ["0001"]),
            apply(module, :decode_token_to_utf8, ["0001"]),
            apply(module, :encode_scalar, [0x4E00]),
            apply(module, :encode_utf8_to_token, ["一"])
          }
        end
      end)

    for {name, profile_metadata, decoded, decoded_utf8, encoded, encoded_utf8} <- results do
      assert is_binary(name)
      assert is_map(profile_metadata)
      assert decoded == {:ok, 0x4E00}
      assert decoded_utf8 == {:ok, "一"}
      assert encoded == {:ok, "0001"}
      assert encoded_utf8 == {:ok, "0001"}
    end

    assert runtime_calls == []
  end

  test "RED: release package selects only compact tables, metadata, inventory, docs, and Unicode notice" do
    assert @source_dir
           |> Path.join("*")
           |> Path.wildcard()
           |> Enum.filter(&File.regular?/1)
           |> Enum.map(&Path.basename/1)
           |> Enum.sort() == [
             "SOURCE_METADATA.md",
             "mainland_tokens.csv",
             "taiwan_policy.csv",
             "taiwan_tokens.csv"
           ]

    files = Mix.Project.config() |> Keyword.fetch!(:package) |> Keyword.fetch!(:files)

    for path <- [
          "priv/sources/unihan-17.0.0-telegraph/mainland_tokens.csv",
          "priv/sources/unihan-17.0.0-telegraph/taiwan_tokens.csv",
          "priv/sources/unihan-17.0.0-telegraph/taiwan_policy.csv",
          "priv/sources/unihan-17.0.0-telegraph/SOURCE_METADATA.md",
          "SUPPORTED_PROPERTY_TOKEN_MAPPING_INVENTORY.csv",
          "UNIHAN_TELEGRAPH_PROPERTY_TOKENS.md",
          "LICENSE.UNICODE"
        ] do
      assert path in files, "release manifest omits #{path}"
    end

    refute Enum.any?(files, fn path ->
             String.contains?(path, "unihan-17.0.0-telegraph") and
               Path.extname(path) in [".zip", ".html", ".json", ".py", ".txt"]
           end)

    refute Enum.any?(files, fn path ->
             String.starts_with?(path, "test/fixtures/unihan-17.0.0-telegraph/") or
               path in [
                 "tools/extract_unihan_telegraph.py",
                 "tools/verify_unihan_telegraph.py"
               ]
           end)

    metadata = File.read!(@metadata_path)
    refute metadata =~ "/private/"
    assert metadata =~ "does not define concatenated message framing"

    assert sha256(File.read!(Path.expand("../LICENSE.UNICODE", __DIR__))) ==
             "e7a93b009565cfce55919a381437ac4db883e9da2126fa28b91d12732bc53d96"
  end

  defp expected_decode(map, token) do
    case map do
      %{^token => scalar} -> {:ok, scalar}
      _ -> {:error, {:unassigned_token, token}}
    end
  end

  defp reduction_measure(function) do
    parent = self()
    reply = make_ref()

    {_pid, monitor} =
      spawn_monitor(fn ->
        :erlang.garbage_collect()
        {:reductions, before_count} = Process.info(self(), :reductions)

        checksum =
          Enum.reduce(1..50_000, 0, fn _, acc ->
            {:ok, token} = function.()
            acc + :binary.first(token)
          end)

        {:reductions, after_count} = Process.info(self(), :reductions)
        send(parent, {reply, checksum, after_count - before_count})
      end)

    assert_receive {^reply, 2_400_000, reductions}, 10_000
    assert_receive {:DOWN, ^monitor, :process, _pid, :normal}, 1_000
    reductions
  end

  defp run_inventory_generator(arguments) do
    root = Path.expand("..", __DIR__)
    mix = System.find_executable("mix") || flunk("mix executable is unavailable")

    System.cmd(
      mix,
      ["run", "--no-compile", @inventory_generator, "--" | arguments],
      cd: root,
      env: [
        {"MIX_ENV", Atom.to_string(Mix.env())},
        {"MIX_BUILD_PATH", Path.expand(Mix.Project.build_path(), root)},
        {"ICONVEX_PATH", Path.expand("../iconvex", root)},
        {"ICONVEX_ARCHIVE_PATH", Path.expand("..", root)}
      ],
      stderr_to_stdout: true
    )
  end

  defp traced_filesystem_calls(function) do
    parent = self()
    reply = make_ref()

    worker =
      spawn(fn ->
        receive do
          {^reply, :run} ->
            outcome =
              try do
                {:ok, function.()}
              rescue
                exception -> {:error, {:exception, exception, __STACKTRACE__}}
              catch
                kind, reason -> {:error, {kind, reason, __STACKTRACE__}}
              end

            send(parent, {reply, :result, outcome})

            receive do
              {^reply, :stop} -> :ok
            end
        end
      end)

    :erlang.trace_pattern({File, :_, :_}, true, [:local])
    :erlang.trace_pattern({:file, :_, :_}, true, [:local])
    :erlang.trace(worker, true, [:call, {:tracer, parent}])

    try do
      send(worker, {reply, :run})
      assert_receive {^reply, :result, outcome}, 5_000

      delivery = :erlang.trace_delivered(worker)
      assert_receive {:trace_delivered, ^worker, ^delivery}, 5_000

      result =
        case outcome do
          {:ok, result} -> result
          {:error, error} -> flunk("traced worker failed: #{inspect(error)}")
        end

      {result, collect_trace_calls(worker, [])}
    after
      :erlang.trace(worker, false, [:call])
      :erlang.trace_pattern({File, :_, :_}, false, [:local])
      :erlang.trace_pattern({:file, :_, :_}, false, [:local])
      send(worker, {reply, :stop})
    end
  end

  defp collect_trace_calls(worker, calls) do
    receive do
      {:trace, ^worker, :call, {module, function, arguments}} ->
        collect_trace_calls(worker, [{module, function, arguments} | calls])
    after
      0 -> Enum.reverse(calls)
    end
  end

  defp expected_policy_decode(policy, token) do
    case policy do
      %{^token => row} -> {:ok, row.output}
      _ -> {:error, {:unassigned_token, token}}
    end
  end

  defp token_map(path) do
    ["decimal_token,unicode_scalar" | rows] =
      path |> File.read!() |> String.split("\n", trim: true)

    Map.new(rows, fn row ->
      [token, scalar] = String.split(row, ",")
      {token, parse_scalar(scalar)}
    end)
  end

  defp policy_map do
    [
      "decimal_token,source_unicode_scalar,readable_reverse_role," <>
        "lossless_output_scalar,lossless_reason"
      | rows
    ] = @policy_path |> File.read!() |> String.split("\n", trim: true)

    Map.new(rows, fn row ->
      [token, source, role, output, reason] = String.split(row, ",")

      {token,
       %{
         source: parse_scalar(source),
         role: parse_role(role),
         output: parse_scalar(output),
         reason: parse_reason(reason)
       }}
    end)
  end

  defp reverse_groups(map) do
    map
    |> Enum.group_by(fn {_token, scalar} -> scalar end, fn {token, _scalar} -> token end)
    |> Map.new(fn {scalar, tokens} -> {scalar, Enum.sort(tokens)} end)
  end

  defp normalization_collisions(map, form) do
    map
    |> Enum.group_by(fn {_token, scalar} -> normalize(scalar, form) end)
    |> Enum.filter(fn {_normalized, entries} ->
      entries |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> length() > 1
    end)
    |> Map.new(fn {[normalized], entries} ->
      {normalized, Enum.sort_by(entries, &elem(&1, 0))}
    end)
  end

  defp normalize(scalar, :nfc), do: :unicode.characters_to_nfc_list([scalar])
  defp normalize(scalar, :nfd), do: :unicode.characters_to_nfd_list([scalar])
  defp normalize(scalar, :nfkc), do: :unicode.characters_to_nfkc_list([scalar])
  defp normalize(scalar, :nfkd), do: :unicode.characters_to_nfkd_list([scalar])

  defp parse_scalar("U+" <> scalar), do: String.to_integer(scalar, 16)
  defp parse_role("canonical-minimum"), do: :canonical
  defp parse_role("decode-alias"), do: :decode_only
  defp parse_reason("source-scalar"), do: :source
  defp parse_reason("canonical-normalization-collision"), do: :normalization
  defp parse_reason("duplicate-readable-reverse"), do: :duplicate

  defp decimal_token(value) do
    <<div(value, 1_000) + ?0, div(rem(value, 1_000), 100) + ?0, div(rem(value, 100), 10) + ?0,
      rem(value, 10) + ?0>>
  end

  defp first_invalid_digit(token) do
    {offset, byte} =
      token
      |> :binary.bin_to_list()
      |> Enum.with_index()
      |> Enum.find_value(fn {byte, offset} ->
        if byte not in ?0..?9, do: {offset, byte}
      end)

    {:error, {:invalid_token_digit, offset, <<byte>>}}
  end

  defp source_assets do
    %{
      mainland: File.read!(@mainland_path),
      taiwan: File.read!(@taiwan_path),
      policy: File.read!(@policy_path),
      metadata: File.read!(@metadata_path)
    }
  end

  defp assert_semantic_rejection(validator, assets, key, mutation, message) do
    mutated = Map.update!(assets, key, mutation)
    hashes = Map.put(@hashes, key, sha256(Map.fetch!(mutated, key)))

    assert_raise ArgumentError, message, fn ->
      apply(validator, :validate!, [mutated, hashes])
    end
  end

  defp sha256(binary),
    do: binary |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
end

defmodule Iconvex.Specs.LietuvybeLSTSourceQualifiedTest do
  use ExUnit.Case, async: true

  @source_dir Path.expand("../priv/sources/lietuvybe-lst-source-qualified", __DIR__)
  @metadata Path.join(@source_dir, "SOURCE_METADATA.md")

  @lst1564 """
  ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ----
  ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ----
  00A0 0104+0303 0118+0301 0118+0303 0069+0307+0303 004C+0303 004D+0303 006D+0303 0116+0301 00D1 0116+0303 0052+0303 0172+0301 00AD 016A+0303 016A+0301
  0128 0105+0303 0119+0301 0119+0303 00B4 006C+0303 00B6 006A+0307+0303 0117+0301 00F1 0117+0303 0072+0303 0173+0301 0172+0303 016B+0303 016B+0301
  0104 012E 00C0 00C1 00C4 00C3 0118 0104+0301 010C 00C9 00C8 0116 1EBC 00CC 00CD 012E+0301
  0160 012E+0303 00D2 00D3 00DD 00D5 00D6 0168 0172 00D9 00DA 016A 00DC 1EF8 017D 00DF
  0105 012F 00E0 00E1 00E4 00E3 0119 0105+0301 010D 00E9 00E8 0117 1EBD 0069+0307+0300 0069+0307+0301 012F+0307+0301
  0161 012F+0307+0303 00F2 00F3 00FD 00F5 00F6 0169 0173 00F9 00FA 016B 00FC 1EF9 017E 0173+0303
  """

  @lst1590_2 """
  00C1 00FC 00E9 00E0 00E4 1EBD 00E3 00E1 00F9 0105+0301 0116+0303 0117+0303 0069+0307+0301 00C8 00C4 00C3
  00C9 016B+0301 016A+0301 00FD 00F6 1EBC 0118+0301 00DA 00FA 00D6 00DC 0117+0301 0118+0303 0116+0301 0168 0069+0307+0303
  00C0 00CD 00F3 1EF8 1EF9 00E8 004C+0303 004D+0303 00D1 016A+0303 0172+0301 0172+0303 0173+0301 00D9 0052+0303 0072+0303
  2591 2592 2593 2502 0251 0104 010C 0118 0116 0254 2551 2557 255D 012E 0160 2510
  2514 0259 025B 0261 2500 026A 0172 016A 255A 2554 014B 03B8 0283 2550 028A 017D
  0105 010D 0119 0117 012F 0161 0173 016B 017E 2518 250C 00B4 028C 0292 02C8 02CC
  00D3 00DF 00DD 012E+0303 00F5 00D5 006C+0303 012F+0307+0303 00CC 0069+0307+0300 012E+0301 012F+0307+0301 00F2 0104+0301 00D2 0173+0303
  00AD 0105+0303 201C 016B+0303 0104+0303 006D+0303 0169 201E 0128 00E6 00F0 00F1 0119+0303 0119+0301 006A+0307+0303 00A0
  """

  @lst1590_4 """
  20AC ---- 0251 0254 201E 0259 025B 0261 026A 014B 03B8 02C8 0283 ---- ---- ----
  ---- 2018 2019 201C 201D 2022 2013 2014 028A 028C 0292 02CC 00E6 ---- ---- 00F0
  00A0 0104+0303 0118+0301 0118+0303 0069+0307+0303 004C+0303 004D+0303 006D+0303 0116+0301 00D1 0116+0303 0052+0303 0172+0301 00AD 016A+0303 016A+0301
  0128 0105+0303 0119+0301 0119+0303 00B4 006C+0303 00B6 006A+0307+0303 0117+0301 00F1 0117+0303 0072+0303 0173+0301 0172+0303 016B+0303 016B+0301
  0104 012E 00C0 00C1 00C4 00C3 0118 0104+0301 010C 00C9 00C8 0116 1EBC 00CC 00CD 012E+0301
  0160 012E+0303 00D2 00D3 00DD 00D5 00D6 0168 0172 00D9 00DA 016A 00DC 1EF8 017D 00DF
  0105 012F 00E0 00E1 00E4 00E3 0119 0105+0301 010D 00E9 00E8 0117 1EBD 0069+0307+0300 0069+0307+0301 012F+0307+0301
  0161 012F+0307+0303 00F2 00F3 00FD 00F5 00F6 0169 0173 00F9 00FA 016B 00FC 1EF9 017E 0173+0303
  """

  @profiles [
    %{
      module: Module.concat([Iconvex, Specs, Lietuvybe, LST1564Commit52A97895]),
      canonical: "LIETUVYBE-52A97895-LST-1564-2000-STRICT-BLANKS",
      generic: "LST-1564",
      file: "lst1564.csv",
      high: @lst1564,
      mapping_sha256: "fdc7ccd7e311b4530d58606ea47deb30186c143f84fbecb01062d45bd5326d04",
      mapped: 224,
      invalid: 32,
      reserved: 32
    },
    %{
      module: Module.concat([Iconvex, Specs, Lietuvybe, LST1590Part2Commit52A97895]),
      canonical: "LIETUVYBE-52A97895-LST-1590-2-2000-STRICT-BLANKS",
      generic: "LST-1590-2",
      file: "lst1590_2.csv",
      high: @lst1590_2,
      mapping_sha256: "defee7782bcba01ea7b3f6d85a0103813f6e72d2aaab728892b6bfbfa3fd4240",
      mapped: 256,
      invalid: 0,
      reserved: 0
    },
    %{
      module: Module.concat([Iconvex, Specs, Lietuvybe, LST1590Part4Commit52A97895]),
      canonical: "LIETUVYBE-52A97895-LST-1590-4-2000-STRICT-BLANKS",
      generic: "LST-1590-4",
      file: "lst1590_4.csv",
      high: @lst1590_4,
      mapping_sha256: "8d7325c6785dd6a18af90e576c827ed8386f1f6b14e1aed97618e650c3214b13",
      mapped: 249,
      invalid: 7,
      reserved: 0
    }
  ]

  test "RED: normalized tables and provenance pins are exact" do
    metadata = File.read!(@metadata)

    for pin <- [
          "52a97895aad2ba40e93a1da28a63c964ad63b9eb",
          "ac4ae79efcf577157ed00972960711966c2375285128c07a6ad2485d983f8077",
          "CC-BY-4.0",
          "5e931495ae6cf3c1f8c05c4c61eed85b25d4660b",
          "796923eb8b61c77d0bb713de8e4c7c6cb8e0dbdb77b5a149c84c3a6f6eb07be4",
          "U+025B",
          "U+025C",
          "LST_biuletenis_2022-11-30__Nr__22.pdf",
          "not an implementation claim for the official standards"
        ] do
      assert metadata =~ pin
    end

    for profile <- @profiles do
      path = Path.join(@source_dir, profile.file)
      rows = parse_mapping(path)
      expected = oracle(profile.high)

      assert sha256(File.read!(path)) == profile.mapping_sha256
      assert length(rows) == 256
      assert Enum.map(rows, & &1.byte) == Enum.to_list(0..255)
      assert Enum.map(rows, & &1.sequence) == expected
      assert Enum.count(rows, &(&1.sequence != :undefined)) == profile.mapped
      assert Enum.count(rows, &(&1.sequence == :undefined)) == profile.invalid
      assert Enum.count(rows, &(&1.status == "reserved_control")) == profile.reserved
      assert Enum.count(rows, &(&1.status == "undefined")) == profile.invalid - profile.reserved
    end
  end

  test "RED: compile-time validator rejects repinned order, scalar, and inverse mutations" do
    source = File.read!(Path.join(@source_dir, "lst1590_2.csv"))

    mutations = [
      {String.replace(source, "\n80,00C1,assigned", "\n81,00C1,assigned", global: false),
       "mapping row order mismatch"},
      {String.replace(source, "\n80,00C1,assigned", "\n80,00D800,assigned", global: false),
       "non-scalar Unicode value"},
      {String.replace(source, "\n81,00FC,assigned", "\n81,00C1,assigned", global: false),
       "duplicate complete Unicode mapping"}
    ]

    for {mutated, expected_message} <- mutations do
      assert_validator_rejects(mutated, expected_message)
    end
  end

  test "RED: all codecs are native, commit-qualified, and expose no generic aliases" do
    modules = Enum.map(@profiles, & &1.module)
    assert apply(Iconvex.Specs.Lietuvybe.Codecs, :modules, []) == modules

    for profile <- @profiles do
      codec = profile.module
      assert Code.ensure_loaded?(codec)
      assert apply(codec, :canonical_name, []) == profile.canonical
      assert apply(codec, :aliases, []) == []
      assert apply(codec, :unit_bits, []) == 8
      assert apply(codec, :provenance_qualification, []) == :lietuvybe_commit_snapshot
      assert apply(codec, :source_commit, []) == "52a97895aad2ba40e93a1da28a63c964ad63b9eb"

      assert apply(codec, :source_blob_sha256, []) ==
               "ac4ae79efcf577157ed00972960711966c2375285128c07a6ad2485d983f8077"

      assert apply(codec, :mapping_sha256, []) == profile.mapping_sha256
      assert apply(codec, :mapped_byte_count, []) == profile.mapped
      assert apply(codec, :invalid_byte_count, []) == profile.invalid
      assert apply(codec, :reserved_control_count, []) == profile.reserved
      assert apply(codec, :inverse_policy, []) == :unique_longest_match
      assert apply(codec, :blank_slot_policy, []) == :strict_undefined

      case Iconvex.Registry.resolve(profile.generic) do
        {:ok, %{codec: resolved}} -> refute resolved == codec
        :error -> :ok
      end
    end
  end

  test "RED: commit-qualified profiles are selected and registered without generic claims" do
    modules = Enum.map(@profiles, & &1.module)

    assert Enum.all?(modules, &(&1 in Iconvex.Specs.codecs()))
    assert Enum.all?(modules, &(&1 in Iconvex.Specs.catalogued_codecs()))

    registrations = Iconvex.Specs.registrations()

    for profile <- @profiles do
      assert Enum.any?(registrations, fn registration ->
               registration.codec == profile.module and
                 registration.canonical == profile.canonical and
                 registration.source == "LIETUVYBE-COMMIT" and
                 registration.aliases == []
             end)

      assert {:ok, %{codec: codec}} = Iconvex.ExternalRegistry.resolve(profile.canonical)
      assert codec == profile.module

      case Iconvex.ExternalRegistry.resolve(profile.generic) do
        {:ok, %{codec: resolved}} -> refute resolved == profile.module
        :error -> :ok
      end
    end
  end

  test "RED: every byte, UTF-8 projection, and unique inverse matches the independent oracle" do
    for profile <- @profiles do
      codec = profile.module
      expected = oracle(profile.high)

      for {sequence, byte} <- Enum.with_index(expected) do
        case sequence do
          :undefined ->
            assert apply(codec, :decode, [<<byte>>]) ==
                     {:error, :invalid_sequence, 0, <<byte>>}

            assert apply(codec, :decode_discard, [<<byte>>]) == {:ok, []}

          codepoints ->
            assert apply(codec, :decode, [<<byte>>]) == {:ok, codepoints}
            assert apply(codec, :decode_discard, [<<byte>>]) == {:ok, codepoints}
            assert apply(codec, :decode_to_utf8, [<<byte>>]) == {:ok, List.to_string(codepoints)}
            assert apply(codec, :encode, [codepoints]) == {:ok, <<byte>>}

            assert apply(codec, :encode_from_utf8, [List.to_string(codepoints)]) ==
                     {:ok, <<byte>>}
        end
      end

      valid = for {sequence, byte} <- Enum.with_index(expected), sequence != :undefined, do: byte
      decoded = Enum.flat_map(valid, &Enum.at(expected, &1))
      binary = :erlang.list_to_binary(valid)
      assert apply(codec, :decode, [binary]) == {:ok, decoded}
      assert apply(codec, :decode_to_utf8, [binary]) == {:ok, List.to_string(decoded)}
      assert apply(codec, :encode, [decoded]) == {:ok, binary}
    end
  end

  test "RED: longest-match sequences, errors, discard, and replacement are deterministic" do
    for profile <- @profiles do
      codec = profile.module
      a_ogonek_tilde = byte_for(profile.high, [0x0104, 0x0303])
      i_dot_tilde = byte_for(profile.high, [?i, 0x0307, 0x0303])
      l_tilde = byte_for(profile.high, [?L, 0x0303])

      assert apply(codec, :encode, [[0x0104, 0x0303]]) == {:ok, <<a_ogonek_tilde>>}
      assert apply(codec, :encode, [[?i, 0x0307, 0x0303]]) == {:ok, <<i_dot_tilde>>}
      assert apply(codec, :encode, [[?L, 0x0303]]) == {:ok, <<l_tilde>>}
      assert apply(codec, :encode, [[?L]]) == {:ok, "L"}

      assert apply(codec, :encode, [[?A, 0x10FFFF, ?B]]) ==
               {:error, :unrepresentable_character, 0x10FFFF}

      assert apply(codec, :encode_discard, [[?A, 0x10FFFF, ?B]]) == {:ok, "AB"}

      assert apply(codec, :encode_substitute, [
               [?A, 0x10FFFF, ?B],
               fn 0x10FFFF -> ~c"?" end
             ]) == {:ok, "A?B"}

      assert apply(codec, :encode_substitute, [
               [0x10FFFF],
               fn 0x10FFFF -> [0x10FFFE] end
             ]) == {:error, :unrepresentable_character, 0x10FFFE}

      assert apply(codec, :encode_from_utf8, ["A" <> <<0xE2, 0x82>>]) ==
               {:decode_error, :incomplete_sequence, 1, <<0xE2, 0x82>>}

      assert apply(codec, :encode_from_utf8, ["A" <> <<0xFF>>]) ==
               {:decode_error, :invalid_sequence, 1, <<0xFF>>}
    end
  end

  test "RED: chunk encoders retain only true sequence prefixes" do
    for profile <- @profiles do
      codec = profile.module
      i_dot_tilde = byte_for(profile.high, [?i, 0x0307, 0x0303])
      l_tilde = byte_for(profile.high, [?L, 0x0303])

      assert apply(codec, :decode_chunk, ["AB", false]) == {:ok, ~c"AB", <<>>}
      assert apply(codec, :encode_chunk, [[?L], false, :error]) == {:ok, <<>>, [?L]}

      assert apply(codec, :encode_chunk, [[?L, 0x0303], false, :error]) ==
               {:ok, <<l_tilde>>, []}

      assert apply(codec, :encode_chunk, [[?i, 0x0307], false, :error]) ==
               {:ok, <<>>, [?i, 0x0307]}

      assert apply(codec, :encode_chunk, [[?i, 0x0307, 0x0303], false, :error]) ==
               {:ok, <<i_dot_tilde>>, []}

      assert apply(codec, :encode_chunk, [[?L], true, :error]) == {:ok, "L", []}
      assert apply(codec, :encode_chunk, [[?L, ?X], false, :error]) == {:ok, "LX", []}

      assert apply(codec, :encode_chunk, [[?A, 0x10FFFF, ?B], true, :discard]) ==
               {:ok, "AB", []}

      assert apply(codec, :encode_chunk, [
               [?A, 0x10FFFF, ?B],
               true,
               {:replace, fn 0x10FFFF -> ~c"?" end}
             ]) == {:ok, "A?B", []}
    end

    lst1564 = hd(@profiles).module

    assert apply(lst1564, :decode_chunk, [<<0x41, 0x80, 0x42>>, false]) ==
             {:error, :invalid_sequence, 1, <<0x80>>}

    assert apply(lst1564, :decode_discard, [<<0x41, 0x80, 0x42>>]) == {:ok, ~c"AB"}
  end

  defp oracle(high) do
    Enum.map(0..0x7F, &[&1]) ++
      (high
       |> String.split()
       |> Enum.map(fn
         "----" -> :undefined
         token -> token |> String.split("+") |> Enum.map(&String.to_integer(&1, 16))
       end))
  end

  defp parse_mapping(path) do
    ["byte_hex,unicode_sequence,status" | rows] =
      path |> File.read!() |> String.split("\n", trim: true)

    Enum.map(rows, fn row ->
      [byte, sequence, status] = String.split(row, ",", parts: 3)

      parsed =
        case {sequence, status} do
          {"", status} when status in ["undefined", "reserved_control"] ->
            :undefined

          {value, "assigned"} ->
            value |> String.split("+") |> Enum.map(&String.to_integer(&1, 16))
        end

      %{byte: String.to_integer(byte, 16), sequence: parsed, status: status}
    end)
  end

  defp byte_for(high, sequence), do: high |> oracle() |> Enum.find_index(&(&1 == sequence))

  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

  defp assert_validator_rejects(csv, expected_message) do
    unique = System.unique_integer([:positive, :monotonic])
    path = Path.join(System.tmp_dir!(), "iconvex-lst-validation-#{unique}.csv")
    File.write!(path, csv)
    on_exit(fn -> File.rm(path) end)

    module = "Iconvex.Specs.Lietuvybe.ValidationProbe#{unique}"

    definition = """
    require Iconvex.Specs.SourceQualifiedSequenceSingleByte

    Iconvex.Specs.SourceQualifiedSequenceSingleByte.defcodec(
      #{module},
      canonical: "LIETUVYBE-52A97895-LST-1590-2-2000-STRICT-BLANKS",
      codec_id: :lietuvybe_validation_probe_#{unique},
      mapping_path: #{inspect(path)},
      mapping_sha256: #{inspect(sha256(csv))},
      metadata_path: #{inspect(@metadata)},
      mapped_byte_count: 256,
      invalid_byte_count: 0,
      reserved_control_count: 0,
      source_url: "https://raw.githubusercontent.com/lietuvybe-lt/lietuvybe.lt/52a97895aad2ba40e93a1da28a63c964ad63b9eb/content/standartai/ra%C5%A1men%C5%B3-koduot%C4%97s/index.md",
      source_commit: "52a97895aad2ba40e93a1da28a63c964ad63b9eb",
      source_blob_sha256: "ac4ae79efcf577157ed00972960711966c2375285128c07a6ad2485d983f8077",
      source_blob_size: 42_924
    )
    """

    assert_raise ArgumentError, ~r/#{Regex.escape(expected_message)}/, fn ->
      Code.compile_string(definition, "lietuvybe_validation_probe_#{unique}.exs")
    end
  end
end

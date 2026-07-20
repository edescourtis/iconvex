defmodule Iconvex.Specs.CorkT1Test do
  use ExUnit.Case, async: false

  @ec_codec Module.concat([Iconvex, Specs, CorkT1ECGlyph])
  @cmap_codec Module.concat([Iconvex, Specs, CorkT1CMap10J])
  @engine Module.concat([Iconvex, Specs, CorkT1])
  @source_asset Module.concat([Iconvex, Specs, CorkT1, SourceAsset])
  @codecs [@ec_codec, @cmap_codec]

  @source_dir Path.expand("../priv/sources/cork-t1", __DIR__)
  @mapping Path.join(@source_dir, "cork_t1_slots.csv")
  @metadata Path.join(@source_dir, "SOURCE_METADATA.md")
  @mapping_sha256 "5a61cedd1713ec413c686b6fdcbb9791f2f9afca8a47d356eb1add25b5f458dc"
  @metadata_sha256 "783bfda2d4c8ef0d12f1c849b929dc8a3d3ad03bc9810a34639ef8f7c8b205db"
  @reduction_heap_words 1_000_000

  @ec_matrix """
  0060 00B4 02C6 02DC 00A8 02DD 02DA 02C7 02D8 00AF 02D9 00B8 02DB 201A 2039 203A
  201C 201D 201E 00AB 00BB 2013 2014 200B ---- 0131 0237 FB00 FB01 FB02 FB03 FB04
  2423 0021 0022 0023 0024 0025 0026 2019 0028 0029 002A 002B 002C 002D 002E 002F
  0030 0031 0032 0033 0034 0035 0036 0037 0038 0039 003A 003B 003C 003D 003E 003F
  0040 0041 0042 0043 0044 0045 0046 0047 0048 0049 004A 004B 004C 004D 004E 004F
  0050 0051 0052 0053 0054 0055 0056 0057 0058 0059 005A 005B 005C 005D 005E 005F
  2018 0061 0062 0063 0064 0065 0066 0067 0068 0069 006A 006B 006C 006D 006E 006F
  0070 0071 0072 0073 0074 0075 0076 0077 0078 0079 007A 007B 007C 007D 007E 002D
  0102 0104 0106 010C 010E 011A 0118 011E 0139 013D 0141 0143 0147 014A 0150 0154
  0158 015A 0160 015E 0164 0162 0170 016E 0178 0179 017D 017B 0132 0130 0111 00A7
  0103 0105 0107 010D 010F 011B 0119 011F 013A 013E 0142 0144 0148 014B 0151 0155
  0159 015B 0161 015F 0165 0163 0171 016F 00FF 017A 017E 017C 0133 00A1 00BF 00A3
  00C0 00C1 00C2 00C3 00C4 00C5 00C6 00C7 00C8 00C9 00CA 00CB 00CC 00CD 00CE 00CF
  00D0 00D1 00D2 00D3 00D4 00D5 00D6 0152 00D8 00D9 00DA 00DB 00DC 00DD 00DE 0053+0053
  00E0 00E1 00E2 00E3 00E4 00E5 00E6 00E7 00E8 00E9 00EA 00EB 00EC 00ED 00EE 00EF
  00F0 00F1 00F2 00F3 00F4 00F5 00F6 0153 00F8 00F9 00FA 00FB 00FC 00FD 00FE 00DF
  """

  @ec_oracle @ec_matrix
             |> String.split()
             |> Enum.map(fn
               "----" -> :undefined
               token -> token |> String.split("+") |> Enum.map(&String.to_integer(&1, 16))
             end)

  @cmap_overrides %{
    0x17 => [0x200C],
    0x1B => ~c"ff",
    0x1C => ~c"fi",
    0x1D => ~c"fl",
    0x1E => ~c"ffi",
    0x1F => ~c"ffl",
    0x7F => [0x00AD],
    0x95 => [0x021A],
    0xB5 => [0x021B],
    0xDF => ~c"SS"
  }

  @cmap_oracle @ec_oracle
               |> Enum.with_index()
               |> Enum.map(fn {mapping, byte} -> Map.get(@cmap_overrides, byte, mapping) end)

  test "RED: audited profiles and normalized source assets exist" do
    assert File.regular?(@mapping)
    assert File.regular?(@metadata)
    assert sha256(@mapping) == @mapping_sha256
    assert sha256(@metadata) == @metadata_sha256

    assert Path.wildcard(Path.join(@source_dir, "*")) |> Enum.sort() ==
             Enum.sort([@mapping, @metadata])

    metadata = File.read!(@metadata)
    assert metadata =~ "LGPL-2.1-or-later"
    assert metadata =~ "Cork/T1 is a font-glyph encoding"
    assert metadata =~ "perthousandzero"
    assert metadata =~ "GNU libiconv does not expose Cork/T1"

    for codec <- @codecs do
      assert Code.ensure_loaded?(codec)
      assert call(codec, :unit_bits, []) == 8
      assert call(codec, :mapping_sha256, []) == @mapping_sha256
      assert call(codec, :metadata_sha256, []) == @metadata_sha256
    end
  end

  test "the independent CSV oracle has all 256 ordered glyph slots" do
    rows = source_rows()

    assert length(rows) == 256
    assert Enum.map(rows, & &1.byte) == Enum.to_list(0..255)
    assert Enum.map(rows, & &1.octal) == Enum.to_list(0..255)
    assert Enum.map(rows, & &1.ec) == @ec_oracle
    assert Enum.map(rows, & &1.cmap) == @cmap_oracle
    assert Enum.count(rows, &(&1.status == "undefined")) == 1
    assert Enum.at(rows, 0x18).glyph == "perthousandzero"
    assert Enum.at(rows, 0x18).ec == :undefined
    assert Enum.at(rows, 0x18).cmap == :undefined
    assert Enum.at(rows, 0xD0).status == "overloaded"

    differences =
      rows
      |> Enum.filter(&(&1.ec != &1.cmap))
      |> Enum.map(& &1.byte)

    assert differences == [0x17, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x7F, 0x95, 0xB5]
  end

  test "source validator locks digests, ordering, scalar validity, and profile invariants" do
    csv = File.read!(@mapping)
    metadata = File.read!(@metadata)

    rows =
      call(@source_asset, :validate!, [
        csv,
        metadata,
        [mapping_sha256: @mapping_sha256, metadata_sha256: @metadata_sha256]
      ])

    assert length(rows) == 256

    assert_raise ArgumentError, ~r/mapping SHA-256 mismatch/, fn ->
      call(@source_asset, :validate!, [
        csv <> "x",
        metadata,
        [mapping_sha256: @mapping_sha256, metadata_sha256: @metadata_sha256]
      ])
    end

    reordered = reorder_first_two_rows(csv)

    assert_raise ArgumentError, ~r/ordered row.*00/i, fn ->
      call(@source_asset, :validate!, [
        reordered,
        metadata,
        [mapping_sha256: sha256_bytes(reordered), metadata_sha256: @metadata_sha256]
      ])
    end
  end

  test "both profiles exhaustively decode every byte against independent tables" do
    for {codec, oracle} <- [{@ec_codec, @ec_oracle}, {@cmap_codec, @cmap_oracle}],
        byte <- 0..255 do
      case Enum.at(oracle, byte) do
        :undefined ->
          assert call(codec, :decode, [<<byte>>]) ==
                   {:error, :invalid_sequence, 0, <<byte>>}

        expected ->
          assert call(codec, :decode, [<<byte>>]) == {:ok, expected}
      end
    end

    valid_bytes = valid_bytes()

    for {codec, oracle} <- [{@ec_codec, @ec_oracle}, {@cmap_codec, @cmap_oracle}] do
      expected = Enum.flat_map(valid_bytes, &Enum.at(oracle, &1))
      binary = :binary.list_to_bin(valid_bytes)
      assert call(codec, :decode, [binary]) == {:ok, expected}
      assert call(codec, :decode_to_utf8, [binary]) == {:ok, List.to_string(expected)}
    end
  end

  test "undefined and ambiguous slots have explicit non-lossy behavior" do
    for codec <- @codecs do
      assert call(codec, :decode, [<<0x41, 0x18, 0x42>>]) ==
               {:error, :invalid_sequence, 1, <<0x18>>}

      assert call(codec, :decode_discard, [<<0x41, 0x18, 0x42>>]) == {:ok, ~c"AB"}

      assert call(codec, :decode_chunk, [<<0x18>>, false]) ==
               {:error, :invalid_sequence, 0, <<0x18>>}

      assert call(codec, :encode, [[0x2080]]) ==
               {:error, :unrepresentable_character, 0x2080}

      assert call(codec, :encode, [[0x1E9E]]) ==
               {:error, :unrepresentable_character, 0x1E9E}

      assert call(codec, :encode, [[0x0110]]) ==
               {:error, :unrepresentable_character, 0x0110}

      assert call(codec, :encode, [[0x00D0]]) == {:ok, <<0xD0>>}

      assert call(codec, :encode, [[0x20]]) ==
               {:error, :unrepresentable_character, 0x20}

      assert call(codec, :encode, [[0x2423]]) == {:ok, <<0x20>>}
    end
  end

  test "single-byte round trips use each profile's documented canonical inverse" do
    for byte <- valid_bytes() do
      {:ok, ec_codepoints} = call(@ec_codec, :decode, [<<byte>>])
      expected_ec_byte = if byte == 0x7F, do: 0x2D, else: byte
      assert call(@ec_codec, :encode, [ec_codepoints]) == {:ok, <<expected_ec_byte>>}

      {:ok, cmap_codepoints} = call(@cmap_codec, :decode, [<<byte>>])
      assert call(@cmap_codec, :encode, [cmap_codepoints]) == {:ok, <<byte>>}
    end
  end

  test "EC glyph and CMap extraction semantics differ only at the ten reviewed slots" do
    assert call(@ec_codec, :decode, [<<0x17, 0x1B, 0x1E, 0x7F, 0x95, 0xB5, 0xDF>>]) ==
             {:ok, [0x200B, 0xFB00, 0xFB03, 0x002D, 0x0162, 0x0163, ?S, ?S]}

    assert call(@cmap_codec, :decode, [<<0x17, 0x1B, 0x1E, 0x7F, 0x95, 0xB5, 0xDF>>]) ==
             {:ok, [0x200C, ?f, ?f, ?f, ?f, ?i, 0x00AD, 0x021A, 0x021B, ?S, ?S]}

    assert call(@ec_codec, :encode, [[0xFB00, 0xFB03]]) == {:ok, <<0x1B, 0x1E>>}

    assert call(@cmap_codec, :encode, [[0xFB00]]) ==
             {:error, :unrepresentable_character, 0xFB00}
  end

  test "CMap inverse uses deterministic longest match while EC retains ligature scalars" do
    source = ~c"ffiAfflAffAfiAflASS"
    expected = <<0x1E, ?A, 0x1F, ?A, 0x1B, ?A, 0x1C, ?A, 0x1D, ?A, 0xDF>>

    assert call(@cmap_codec, :encode, [source]) == {:ok, expected}
    assert call(@cmap_codec, :encode_from_utf8, [List.to_string(source)]) == {:ok, expected}

    assert call(@ec_codec, :encode, [~c"ffiASS"]) ==
             {:ok, <<?f, ?f, ?i, ?A, 0xDF>>}

    assert call(@ec_codec, :encode_from_utf8, ["ffiASS"]) ==
             {:ok, <<?f, ?f, ?i, ?A, 0xDF>>}
  end

  test "chunk encoders retain only true longest-match prefixes" do
    assert call(@cmap_codec, :encode_chunk, [[?f], false, :error]) == {:ok, <<>>, [?f]}

    assert call(@cmap_codec, :encode_chunk, [[?f, ?f], false, :error]) ==
             {:ok, <<>>, [?f, ?f]}

    assert call(@cmap_codec, :encode_chunk, [[?f, ?f, ?i], false, :error]) ==
             {:ok, <<0x1E>>, []}

    assert call(@cmap_codec, :encode_chunk, [[?f, ?f, ?A], false, :error]) ==
             {:ok, <<0x1B, ?A>>, []}

    assert call(@cmap_codec, :encode_chunk, [[?f, ?i], false, :error]) ==
             {:ok, <<0x1C>>, []}

    assert call(@cmap_codec, :encode_chunk, [[?f], true, :error]) == {:ok, <<?f>>, []}

    assert call(@cmap_codec, :encode_chunk, [[?f, ?f], true, :error]) ==
             {:ok, <<0x1B>>, []}

    for codec <- @codecs do
      assert call(codec, :encode_chunk, [[?S], false, :error]) == {:ok, <<>>, [?S]}
      assert call(codec, :encode_chunk, [[?S, ?S], false, :error]) == {:ok, <<0xDF>>, []}
      assert call(codec, :encode_chunk, [[?S], true, :error]) == {:ok, <<?S>>, []}
    end

    assert call(@ec_codec, :encode_chunk, [[?f], false, :error]) == {:ok, <<?f>>, []}
  end

  test "stream split simulation equals one-shot encoding at every codepoint boundary" do
    samples = [
      {@ec_codec, ~c"SfSSffiSAS"},
      {@cmap_codec, ~c"ffifflfffiflSSSfA"}
    ]

    for {codec, codepoints} <- samples do
      {:ok, expected} = call(codec, :encode, [codepoints])

      for split <- 0..length(codepoints) do
        {left, right} = Enum.split(codepoints, split)
        assert encode_two_chunks(codec, left, right) == {:ok, expected}
      end

      singleton_chunks = Enum.map(codepoints, &[&1])
      assert encode_chunks(codec, singleton_chunks) == {:ok, expected}
    end
  end

  test "strict, discard, substitution, and malformed UTF-8 paths preserve first errors" do
    for codec <- @codecs do
      assert call(codec, :encode, [[?A, 0x2603, ?B]]) ==
               {:error, :unrepresentable_character, 0x2603}

      assert call(codec, :encode_discard, [[?A, 0x2603, ?B]]) == {:ok, "AB"}

      assert call(codec, :encode_substitute, [
               [?A, 0x2603, ?B],
               fn 0x2603 -> ~c"?" end
             ]) == {:ok, "A?B"}

      assert call(codec, :encode_chunk, [[?A, 0x2603, ?B], true, :discard]) ==
               {:ok, "AB", []}

      assert call(codec, :encode_chunk, [
               [?A, 0x2603, ?B],
               true,
               {:replace, fn 0x2603 -> ~c"?" end}
             ]) == {:ok, "A?B", []}

      assert call(codec, :encode_from_utf8, ["A" <> <<0xE2, 0x82>>]) ==
               {:decode_error, :incomplete_sequence, 1, <<0xE2, 0x82>>}

      assert call(codec, :encode_from_utf8, ["A" <> <<0xFF>>]) ==
               {:decode_error, :invalid_sequence, 1, <<0xFF>>}

      assert call(codec, :encode_from_utf8, [<<0x2603::utf8, 0xFF>>]) ==
               {:error, :unrepresentable_character, 0x2603}
    end
  end

  test "direct UTF-8 paths stay linear across output chunk boundaries" do
    for codec <- @codecs do
      encoded = :binary.copy(<<?A>>, 8_193)
      text = :binary.copy("A", 8_193)
      assert call(codec, :decode_to_utf8, [encoded]) == {:ok, text}
      assert call(codec, :encode_from_utf8, [text]) == {:ok, encoded}

      small_decode =
        reductions(fn -> call(codec, :decode_to_utf8, [:binary.copy(<<?A>>, 65_536)]) end)

      large_decode =
        reductions(fn -> call(codec, :decode_to_utf8, [:binary.copy(<<?A>>, 131_072)]) end)

      small_encode =
        reductions(fn -> call(codec, :encode_from_utf8, [:binary.copy("A", 65_536)]) end)

      large_encode =
        reductions(fn -> call(codec, :encode_from_utf8, [:binary.copy("A", 131_072)]) end)

      assert_ratio(large_decode / small_decode)
      assert_ratio(large_encode / small_encode)
    end
  end

  test "profile identity, aliases, provenance, and counts are explicit" do
    assert call(@ec_codec, :canonical_name, []) == "TEX-T1-EC-GLYPH"
    assert call(@cmap_codec, :canonical_name, []) == "TEX-T1-CMAP-1.0J"

    assert call(@ec_codec, :aliases, []) == [
             "T1",
             "TEX-T1",
             "CORK",
             "CORK-ENCODING",
             "CORKENCODING",
             "EC",
             "EC-ENCODING",
             "ECENCODING",
             "TEX-LATIN-1",
             "TEXLATIN1",
             "TEX256",
             "TEX256.ENC",
             "8T"
           ]

    assert call(@cmap_codec, :aliases, []) == ["T1-CMAP", "TEX-T1-CMAP", "TEX-T1-0"]

    assert call(@engine, :profile_counts, [:ec_glyph]) == %{
             defined: 255,
             scalars: 254,
             sequences: 1
           }

    assert call(@engine, :profile_counts, [:cmap_1_0j]) == %{
             defined: 255,
             scalars: 249,
             sequences: 6
           }

    assert call(@engine, :profile_differences, []) ==
             [0x17, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x7F, 0x95, 0xB5]

    assert call(@engine, :ferguson_sha256, []) ==
             "ce79e1e82074f4d48abd15c9bc4f38619d1469bf96c532941e3bbd1df409a74c"

    assert call(@engine, :ec_encoding_sha256, []) ==
             "bd865bb53fe3c2f479efa8e3d92e1027db5e64a1d7c0ced7884d6c9ee65c0b48"

    assert call(@engine, :t1_cmap_sha256, []) ==
             "e43d20b203a25786d101e757d312b3660bc2505d57251db7701cd3f69e6d1f42"
  end

  defp valid_bytes, do: Enum.reject(0..255, &(&1 == 0x18))

  defp source_rows do
    [_header | rows] = @mapping |> File.read!() |> String.split("\n", trim: true)

    Enum.map(rows, fn row ->
      [hex, octal, glyph, ec, cmap, status, notes] = String.split(row, ",", parts: 7)

      %{
        byte: String.to_integer(hex, 16),
        octal: String.to_integer(octal, 8),
        glyph: glyph,
        ec: parse_mapping(ec),
        cmap: parse_mapping(cmap),
        status: status,
        notes: notes
      }
    end)
  end

  defp parse_mapping(""), do: :undefined

  defp parse_mapping(token),
    do: token |> String.split("+") |> Enum.map(&String.to_integer(&1, 16))

  defp reorder_first_two_rows(csv) do
    [header, first, second | rest] = String.split(csv, "\n", trim: true)
    Enum.join([header, second, first | rest], "\n") <> "\n"
  end

  defp encode_two_chunks(codec, left, right) do
    with {:ok, first, pending} <- call(codec, :encode_chunk, [left, false, :error]),
         {:ok, second, pending} <- call(codec, :encode_chunk, [pending ++ right, false, :error]),
         {:ok, final, []} <- call(codec, :encode_chunk, [pending, true, :error]) do
      {:ok, first <> second <> final}
    end
  end

  defp encode_chunks(codec, chunks) do
    {output, pending} =
      Enum.reduce(chunks, {[], []}, fn chunk, {output, pending} ->
        {:ok, bytes, pending} = call(codec, :encode_chunk, [pending ++ chunk, false, :error])
        {[bytes | output], pending}
      end)

    {:ok, final, []} = call(codec, :encode_chunk, [pending, true, :error])
    {:ok, output |> :lists.reverse([final]) |> IO.iodata_to_binary()}
  end

  defp reductions(function) do
    for _ <- 1..3 do
      Task.async(fn ->
        # Isolate scheduler work from arbitrary GC steps in the ExUnit process.
        Process.flag(:min_heap_size, @reduction_heap_words)
        :erlang.garbage_collect()
        {:reductions, before_count} = Process.info(self(), :reductions)
        assert {:ok, _output} = function.()
        {:reductions, after_count} = Process.info(self(), :reductions)
        after_count - before_count
      end)
      |> Task.await(30_000)
    end
    |> Enum.sort()
    |> Enum.at(1)
  end

  defp assert_ratio(ratio), do: assert(ratio > 1.6 and ratio < 2.6)
  defp call(module, function, arguments), do: apply(module, function, arguments)
  defp sha256(path), do: path |> File.read!() |> sha256_bytes()

  defp sha256_bytes(bytes),
    do: bytes |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
end

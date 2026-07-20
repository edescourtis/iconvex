defmodule Iconvex.Specs.VSCII2Test do
  use ExUnit.Case, async: false

  @codec Iconvex.Specs.VSCII2
  @source Iconvex.Specs.VSCII2.SourceAsset
  @mapping Path.expand("../priv/sources/vscii-2/vscii2.csv", __DIR__)
  @metadata Path.expand("../priv/sources/vscii-2/SOURCE_METADATA.md", __DIR__)

  # ISO-IR-180 positions 10/0 through 15/15, transcribed independently from
  # the primary chart. The test does not derive its oracle from production.
  @high_mapping [
    0x00A0,
    0x0102,
    0x00C2,
    0x00CA,
    0x00D4,
    0x01A0,
    0x01AF,
    0x0110,
    0x0103,
    0x00E2,
    0x00EA,
    0x00F4,
    0x01A1,
    0x01B0,
    0x0111,
    0x1EB0,
    0x0300,
    0x0309,
    0x0303,
    0x0301,
    0x0323,
    0x00E0,
    0x1EA3,
    0x00E3,
    0x00E1,
    0x1EA1,
    0x1EB2,
    0x1EB1,
    0x1EB3,
    0x1EB5,
    0x1EAF,
    0x1EB4,
    0x1EAE,
    0x1EA6,
    0x1EA8,
    0x1EAA,
    0x1EA4,
    0x1EC0,
    0x1EB7,
    0x1EA7,
    0x1EA9,
    0x1EAB,
    0x1EA5,
    0x1EAD,
    0x00E8,
    0x1EC2,
    0x1EBB,
    0x1EBD,
    0x00E9,
    0x1EB9,
    0x1EC1,
    0x1EC3,
    0x1EC5,
    0x1EBF,
    0x1EC7,
    0x00EC,
    0x1EC9,
    0x1EC4,
    0x1EBE,
    0x1ED2,
    0x0129,
    0x00ED,
    0x1ECB,
    0x00F2,
    0x1ED4,
    0x1ECF,
    0x00F5,
    0x00F3,
    0x1ECD,
    0x1ED3,
    0x1ED5,
    0x1ED7,
    0x1ED1,
    0x1ED9,
    0x1EDD,
    0x1EDF,
    0x1EE1,
    0x1EDB,
    0x1EE3,
    0x00F9,
    0x1ED6,
    0x1EE7,
    0x0169,
    0x00FA,
    0x1EE5,
    0x1EEB,
    0x1EED,
    0x1EEF,
    0x1EE9,
    0x1EF1,
    0x1EF3,
    0x1EF7,
    0x1EF9,
    0x00FD,
    0x1EF5,
    0x1ED0
  ]

  @oracle_list Enum.to_list(0x00..0x7F) ++ List.duplicate(nil, 32) ++ @high_mapping
  @oracle_table List.to_tuple(@oracle_list)
  @oracle_encoder @oracle_list
                  |> Enum.with_index()
                  |> Enum.reject(fn {codepoint, _byte} -> is_nil(codepoint) end)
                  |> Map.new()

  test "identity names exact VN2, while related Vietnamese encodings are excluded" do
    assert @codec.canonical_name() == "VSCII-2"

    assert @codec.aliases() == [
             "VSCII",
             "TCVN-5712-2",
             "TCVN5712-2",
             "TCVN5712-2:1993",
             "TCVN-VN2",
             "VN2",
             "ISO-IR-180"
           ]

    excluded = @source.excluded_variants()

    for name <- [
          "VISCII",
          "VSCII-1",
          "VSCII-3",
          "TCVN",
          "TCVN-5712",
          "TCVN5712-1",
          "TCVN5712-1:1993",
          "TCVN3",
          "VN1",
          "VN3",
          "x-viet-tcvn5712"
        ] do
      refute name in @codec.aliases()
      assert name in excluded
    end
  end

  test "shared registry gives ISO-IR-180 to VN2 while preserving RFC 1456 VISCII" do
    assert Iconvex.canonical_name("ISO-IR-180") == {:ok, "VSCII-2"}
    assert Iconvex.canonical_name("VSCII") == {:ok, "VSCII-2"}
    assert Iconvex.canonical_name("VISCII") == {:ok, "VISCII"}
    assert Iconvex.canonical_name("TCVN") == {:ok, "TCVN"}

    assert {:ok, %{codec: @codec, canonical: "VSCII-2"}} =
             Iconvex.Registry.resolve("ISO-IR-180")

    assert {:ok, %{canonical: "VISCII"}} = Iconvex.Registry.resolve("VISCII")
    assert {:ok, %{canonical: "TCVN"}} = Iconvex.Registry.resolve("TCVN5712-1:1993")
  end

  test "every one of 256 octets matches the independent ISO-IR-180 oracle" do
    assert tuple_size(@oracle_table) == 256
    assert Enum.count(@oracle_list, &is_integer/1) == 224
    assert Enum.count(@oracle_list, &is_nil/1) == 32

    for byte <- 0x00..0xFF do
      case elem(@oracle_table, byte) do
        nil ->
          assert @codec.decode(<<byte>>) == {:error, :invalid_sequence, 0, <<byte>>}

        codepoint ->
          assert @codec.decode(<<byte>>) == {:ok, [codepoint]}
      end
    end
  end

  test "encoder is the complete 224-scalar bijective inverse and nothing else" do
    assert map_size(@oracle_encoder) == 224

    for {codepoint, byte} <- @oracle_encoder do
      assert @codec.encode([codepoint]) == {:ok, <<byte>>}
    end

    for codepoint <- 0..0x10FFFF,
        codepoint not in 0xD800..0xDFFF,
        not Map.has_key?(@oracle_encoder, codepoint) do
      assert @codec.encode([codepoint]) ==
               {:error, :unrepresentable_character, codepoint}
    end
  end

  test "raw combining mappings round-trip without inferred normalization" do
    source = <<0x61, 0xB0, 0xB3, 0xB4>>
    raw = [?a, 0x0300, 0x0301, 0x0323]

    assert @codec.decode(source) == {:ok, raw}
    assert @codec.encode(raw) == {:ok, source}
    assert @codec.encode([0x1EA1]) == {:ok, <<0xB9>>}
    assert @codec.encode([0x1EA7]) == {:ok, <<0xC7>>}
  end

  test "direct callbacks preserve offsets, malformed UTF-8, and conversion policies" do
    assigned = assigned_pairs()
    bytes = assigned |> Enum.map(&elem(&1, 1)) |> :erlang.list_to_binary()
    utf8 = assigned |> Enum.map(fn {cp, _byte} -> <<cp::utf8>> end) |> IO.iodata_to_binary()

    assert @codec.decode_to_utf8(bytes) == {:ok, utf8}
    assert @codec.encode_from_utf8(utf8) == {:ok, bytes}

    assert @codec.decode(<<0x41, 0x80, 0x42>>) ==
             {:error, :invalid_sequence, 1, <<0x80>>}

    assert @codec.decode_to_utf8(<<0x41, 0x9F, 0x42>>) ==
             {:error, :invalid_sequence, 1, <<0x9F>>}

    assert @codec.decode_discard(<<0x41, 0x80, 0x42, 0x9F>>) == {:ok, [?A, ?B]}
    assert @codec.encode_discard([?A, 0x1F642, ?B]) == {:ok, "AB"}
    assert @codec.encode_chunk([?A, 0x1F642, ?B], false, :discard) == {:ok, "AB", []}

    assert @codec.encode_substitute([?A, 0x1F642, ?B], fn 0x1F642 -> [??] end) ==
             {:ok, "A?B"}

    assert @codec.encode_chunk([?A, 0x1F642, ?B], true, {:replace, fn _ -> [??] end}) ==
             {:ok, "A?B", []}

    assert @codec.encode_from_utf8(<<0x41, 0xFF, 0x42>>) ==
             {:decode_error, :invalid_sequence, 1, <<0xFF, 0x42>>}

    assert @codec.encode_from_utf8(<<0x41, 0xE2, 0x82>>) ==
             {:decode_error, :incomplete_sequence, 1, <<0xE2, 0x82>>}
  end

  test "every split of the complete assigned stream equals one-shot conversion" do
    assigned = assigned_pairs()
    source = assigned |> Enum.map(&elem(&1, 1)) |> :erlang.list_to_binary()
    codepoints = Enum.map(assigned, &elem(&1, 0))

    assert @codec.decode(source) == {:ok, codepoints}
    assert @codec.encode(codepoints) == {:ok, source}

    for split <- 0..byte_size(source) do
      {left, right} = :erlang.split_binary(source, split)
      {:ok, left_codepoints, <<>>} = @codec.decode_chunk(left, false)
      {:ok, right_codepoints, <<>>} = @codec.decode_chunk(right, true)
      assert left_codepoints ++ right_codepoints == codepoints
    end

    for split <- 0..length(codepoints) do
      {left, right} = Enum.split(codepoints, split)
      {:ok, left_bytes, []} = @codec.encode_chunk(left, false, :error)
      {:ok, right_bytes, []} = @codec.encode_chunk(right, true, :error)
      assert left_bytes <> right_bytes == source
    end
  end

  test "checked-in mapping is byte-exact and tamper validation is structural" do
    mapping = File.read!(@mapping)
    metadata = File.read!(@metadata)

    assert @source.mapping_sha256() == sha256(mapping)
    assert @source.metadata_sha256() == sha256(metadata)

    rows =
      @source.validate!(mapping, metadata,
        mapping_sha256: sha256(mapping),
        metadata_sha256: sha256(metadata)
      )

    assert Enum.map(rows, & &1.unicode) == @oracle_list
    assert source_high_table() == Enum.drop(@oracle_list, 0x80)

    assert_raise ArgumentError, ~r/mapping SHA-256 mismatch/, fn ->
      @source.validate!(mapping <> "x", metadata,
        mapping_sha256: sha256(mapping),
        metadata_sha256: sha256(metadata)
      )
    end

    wrong_schema = String.replace(mapping, "byte_hex,unicode_hex,status", "byte,value,state")

    assert_raise ArgumentError, ~r/unexpected VSCII-2 mapping header/, fn ->
      validate_with_current_digests(wrong_schema, metadata)
    end

    reordered = reorder_first_two_rows(mapping)

    assert_raise ArgumentError, ~r/ordered row 00/, fn ->
      validate_with_current_digests(reordered, metadata)
    end

    changed_hole = String.replace(mapping, "80,,undefined", "80,0080,mapped")

    assert_raise ArgumentError, ~r/undefined-byte range/, fn ->
      validate_with_current_digests(changed_hole, metadata)
    end

    duplicate = String.replace(mapping, "A2,00C2,mapped", "A2,0102,mapped")

    assert_raise ArgumentError, ~r/224 unique scalar mappings/, fn ->
      validate_with_current_digests(duplicate, metadata)
    end

    incomplete_metadata = String.replace(metadata, "`x-viet-tcvn5712`", "`x-viet-X`")

    assert_raise ArgumentError, ~r/metadata omits/, fn ->
      @source.validate!(mapping, incomplete_metadata,
        mapping_sha256: sha256(mapping),
        metadata_sha256: sha256(incomplete_metadata)
      )
    end
  end

  test "primary registration and independent Unicode transcription are pinned" do
    assert @source.standard_profile() == {:tcvn_5712_1993, :vn2}
    assert @source.profile_counts() == %{defined: 224, undefined: 32, non_ascii: 96}
    assert @source.unit_bits() == 8
    assert @source.control_policy() == :ascii_identity_including_c0_and_del
    assert @source.undefined_policy() == :c1_80_9f_undefined
    assert @source.reverse_policy() == :exact_bijective_inverse
    assert @source.normalization_policy() == :none_raw_graphic_mappings
    assert @source.packed_applicability() == :not_applicable_octet_codec
    assert @source.gnu_libiconv_support() == :unsupported

    assert @source.source_url(:iso_ir_180) == "https://itscj.ipsj.or.jp/ir/180.pdf"

    assert @source.source_sha256(:iso_ir_180) ==
             "a02cf84237d0344f2ef1d09f125a4fa5ea5464bdf1d90bd8e537bac04c9090a0"

    assert @source.source_size(:iso_ir_180) == 998_754
    assert @source.source_page_count(:iso_ir_180) == 6
    assert @source.source_license(:iso_ir_180) == :copyrighted_reference_only

    assert @source.source_url(:vsqi_catalog) ==
             "https://tieuchuan.vsqi.gov.vn/tieuchuan/view?sohieu=TCVN+5712%3A1993"

    assert @source.source_sha256(:vsqi_catalog) ==
             "5b5a8909bb9b7ca9e6dbe6f390466657f341d182e7c11afcf94242df4fa980b1"

    assert @source.source_url(:python_charmap) ==
             "https://bugs.python.org/file37055/TCVN5712-2.TXT"

    assert @source.source_sha256(:python_charmap) ==
             "4b2385eed17f8aa30b3299ddc924b83bff6479f43befbb7619d81a97b04b920b"

    assert @source.source_url(:unicode_data_17) ==
             "https://www.unicode.org/Public/17.0.0/ucd/UnicodeData.txt"

    assert @source.source_sha256(:unicode_data_17) ==
             "2e1efc1dcb59c575eedf5ccae60f95229f706ee6d031835247d843c11d96470c"

    assert @source.core_registry_audit() == %{
             path: "../iconvex/lib/iconvex/registry.ex",
             alias: "ISO-IR-180",
             formerly_incorrect_target: :viscii,
             current_builtin_target: :unregistered,
             required_external_target: :vscii_2,
             status: :core_misalias_removed_pending_specs_registration
           }
  end

  test "native direct callbacks scale linearly and beat the generic reduction ceiling" do
    alphabet =
      :erlang.list_to_binary(Enum.to_list(0x00..0x7F) ++ Enum.to_list(0xA0..0xFF))

    small_source = repeat_to_size(alphabet, 32_768)
    large_source = repeat_to_size(alphabet, 65_536)
    {:ok, small_text} = @codec.decode_to_utf8(small_source)
    {:ok, large_text} = @codec.decode_to_utf8(large_source)

    native_decode_small = reductions(fn -> @codec.decode_to_utf8(small_source) end)
    native_decode_large = reductions(fn -> @codec.decode_to_utf8(large_source) end)
    native_encode_small = reductions(fn -> @codec.encode_from_utf8(small_text) end)
    native_encode_large = reductions(fn -> @codec.encode_from_utf8(large_text) end)
    reference_decode = reductions(fn -> reference_decode_to_utf8(large_source) end)
    reference_encode = reductions(fn -> reference_encode_from_utf8(large_text) end)

    assert_ratio(native_decode_large / native_decode_small, 1.60, 2.60)
    assert_ratio(native_encode_large / native_encode_small, 1.60, 2.60)
    assert native_decode_large / reference_decode <= 1.25
    assert native_encode_large / reference_encode <= 1.25
  end

  defp assigned_pairs do
    @oracle_list
    |> Enum.with_index()
    |> Enum.reject(fn {codepoint, _byte} -> is_nil(codepoint) end)
  end

  defp source_high_table do
    @source.high_hex()
    |> Base.decode16!()
    |> then(fn binary ->
      for <<codepoint::unsigned-big-32 <- binary>> do
        if codepoint == 0xFFFFFFFF, do: nil, else: codepoint
      end
    end)
  end

  defp validate_with_current_digests(mapping, metadata) do
    @source.validate!(mapping, metadata,
      mapping_sha256: sha256(mapping),
      metadata_sha256: sha256(metadata)
    )
  end

  defp reorder_first_two_rows(mapping) do
    [header, first, second | rest] = String.split(mapping, "\n", trim: true)
    Enum.join([header, second, first | rest], "\n") <> "\n"
  end

  defp reference_decode_to_utf8(source) do
    text =
      source |> :binary.bin_to_list() |> Enum.map(&elem(@oracle_table, &1)) |> List.to_string()

    {:ok, text}
  end

  defp reference_encode_from_utf8(text) do
    codepoints = :unicode.characters_to_list(text, :utf8)
    encoded = codepoints |> Enum.map(&Map.fetch!(@oracle_encoder, &1)) |> :erlang.list_to_binary()
    {:ok, encoded}
  end

  defp repeat_to_size(alphabet, size) do
    copies = div(size + byte_size(alphabet) - 1, byte_size(alphabet))
    alphabet |> :binary.copy(copies) |> binary_part(0, size)
  end

  defp reductions(function) do
    :erlang.garbage_collect()
    {:reductions, before_count} = Process.info(self(), :reductions)
    assert {:ok, _output} = function.()
    {:reductions, after_count} = Process.info(self(), :reductions)
    after_count - before_count
  end

  defp assert_ratio(actual, minimum, maximum) do
    assert actual >= minimum and actual <= maximum,
           "expected reduction scaling #{actual} in #{minimum}..#{maximum}"
  end

  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end

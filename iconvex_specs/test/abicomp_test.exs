defmodule Iconvex.Specs.ABICOMPTest do
  use ExUnit.Case, async: false

  @codec Iconvex.Specs.ABICOMP
  @source Iconvex.Specs.ABICOMP.SourceAsset
  @mapping Path.expand("../priv/sources/abicomp/abicomp.csv", __DIR__)
  @metadata Path.expand("../priv/sources/abicomp/SOURCE_METADATA.md", __DIR__)
  @mapping_sha256 "2edd0ed4875ee8f62ad82c2cfde796842a05bbef82b9a3f1cd123ed3c9c03bfb"
  @metadata_sha256 "31ea0634ca8ad35b5c872419e53b7890da020b8d8ba9725471d454176b0ed9de"

  @high_mapping [
    0x00A0,
    0x00C0,
    0x00C1,
    0x00C2,
    0x00C3,
    0x00C4,
    0x00C7,
    0x00C8,
    0x00C9,
    0x00CA,
    0x00CB,
    0x00CC,
    0x00CD,
    0x00CE,
    0x00CF,
    0x00D1,
    0x00D2,
    0x00D3,
    0x00D4,
    0x00D5,
    0x00D6,
    0x0152,
    0x00D9,
    0x00DA,
    0x00DB,
    0x00DC,
    0x0178,
    0x00A8,
    0x00A3,
    0x00A6,
    0x00A7,
    0x00B0,
    0x00A1,
    0x00E0,
    0x00E1,
    0x00E2,
    0x00E3,
    0x00E4,
    0x00E7,
    0x00E8,
    0x00E9,
    0x00EA,
    0x00EB,
    0x00EC,
    0x00ED,
    0x00EE,
    0x00EF,
    0x00F1,
    0x00F2,
    0x00F3,
    0x00F4,
    0x00F5,
    0x00F6,
    0x0153,
    0x00F9,
    0x00FA,
    0x00FB,
    0x00FC,
    0x00FF,
    0x00DF,
    0x00AA,
    0x00BA,
    0x00BF,
    0x00B1
  ]

  @oracle_list Enum.to_list(0x00..0x7F) ++
                 List.duplicate(nil, 32) ++ @high_mapping ++ List.duplicate(nil, 32)
  @oracle_table List.to_tuple(@oracle_list)
  @oracle_encoder @oracle_list
                  |> Enum.with_index()
                  |> Enum.reject(fn {codepoint, _byte} -> is_nil(codepoint) end)
                  |> Map.new()

  test "the codec identity is explicit and PCL variants are not overclaimed" do
    assert @codec.canonical_name() == "ABICOMP"

    assert @codec.aliases() == [
             "BRAZIL-ABICOMP",
             "CP3848",
             "CODE-PAGE-3848",
             "FREEDOS-CP3848"
           ]

    refute "PCL-13P" in @codec.aliases()
    refute "PCL-14P" in @codec.aliases()
    refute "ABICOMP-INTERNATIONAL" in @codec.aliases()
    assert @source.excluded_variants() == ["PCL-13P", "PCL-14P", "ABICOMP-INTERNATIONAL"]
  end

  test "every byte has the exact assigned or undefined result" do
    table = oracle_table()

    assert tuple_size(table) == 256
    assert Enum.count(Tuple.to_list(table), &is_integer/1) == 192
    assert Enum.count(Tuple.to_list(table), &is_nil/1) == 64

    for byte <- 0x00..0xFF do
      case elem(table, byte) do
        nil ->
          assert @codec.decode(<<byte>>) == {:error, :invalid_sequence, 0, <<byte>>}

        codepoint ->
          assert @codec.decode(<<byte>>) == {:ok, [codepoint]}
      end
    end
  end

  test "the encoder is exactly the complete bijective inverse" do
    table = oracle_table()

    inverse =
      table
      |> Tuple.to_list()
      |> Enum.with_index()
      |> Enum.reject(fn {codepoint, _byte} -> is_nil(codepoint) end)
      |> Map.new(fn {codepoint, byte} -> {codepoint, byte} end)

    assert map_size(inverse) == 192

    for {codepoint, byte} <- inverse do
      assert @codec.encode([codepoint]) == {:ok, <<byte>>}
    end

    for codepoint <- 0..0x10FFFF,
        codepoint not in 0xD800..0xDFFF,
        not Map.has_key?(inverse, codepoint) do
      assert @codec.encode([codepoint]) ==
               {:error, :unrepresentable_character, codepoint}
    end
  end

  test "direct UTF-8 callbacks preserve tables, offsets, and policies" do
    table = oracle_table()

    assigned =
      table
      |> Tuple.to_list()
      |> Enum.with_index()
      |> Enum.reject(fn {codepoint, _byte} -> is_nil(codepoint) end)

    bytes = assigned |> Enum.map(&elem(&1, 1)) |> :erlang.list_to_binary()
    utf8 = assigned |> Enum.map(fn {cp, _byte} -> <<cp::utf8>> end) |> IO.iodata_to_binary()

    assert @codec.decode_to_utf8(bytes) == {:ok, utf8}
    assert @codec.encode_from_utf8(utf8) == {:ok, bytes}

    assert @codec.decode(<<0x41, 0x80, 0x42>>) ==
             {:error, :invalid_sequence, 1, <<0x80>>}

    assert @codec.decode_discard(<<0x41, 0x80, 0x42, 0xE0>>) == {:ok, [?A, ?B]}
    assert @codec.encode_discard([?A, 0x1F642, ?B]) == {:ok, "AB"}

    assert @codec.encode_from_utf8(<<0x41, 0xFF, 0x42>>) ==
             {:decode_error, :invalid_sequence, 1, <<0xFF, 0x42>>}

    assert @codec.encode_from_utf8(<<0x41, 0xE2, 0x82>>) ==
             {:decode_error, :incomplete_sequence, 1, <<0xE2, 0x82>>}
  end

  test "every split of the complete assigned stream equals one-shot conversion" do
    assigned =
      @oracle_list
      |> Enum.with_index()
      |> Enum.reject(fn {codepoint, _byte} -> is_nil(codepoint) end)

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

  test "source validation rejects digest, schema, ordering, and invariant tampering" do
    mapping = File.read!(@mapping)
    metadata = File.read!(@metadata)

    rows =
      @source.validate!(mapping, metadata,
        mapping_sha256: @mapping_sha256,
        metadata_sha256: @metadata_sha256
      )

    assert length(rows) == 256

    assert_raise ArgumentError, ~r/mapping SHA-256 mismatch/, fn ->
      @source.validate!(mapping <> "x", metadata,
        mapping_sha256: @mapping_sha256,
        metadata_sha256: @metadata_sha256
      )
    end

    wrong_schema = String.replace(mapping, "byte_hex,unicode_hex,status", "byte,value,state")

    assert_raise ArgumentError, ~r/unexpected ABICOMP mapping header/, fn ->
      validate_with_recomputed_mapping_digest(wrong_schema, metadata)
    end

    reordered = reorder_first_two_rows(mapping)

    assert_raise ArgumentError, ~r/ordered row 00/, fn ->
      validate_with_recomputed_mapping_digest(reordered, metadata)
    end

    changed_hole = String.replace(mapping, "80,,undefined", "80,0080,mapped")

    assert_raise ArgumentError, ~r/undefined-byte ranges/, fn ->
      validate_with_recomputed_mapping_digest(changed_hole, metadata)
    end

    duplicate = String.replace(mapping, "A2,00C1,mapped", "A2,00C0,mapped")

    assert_raise ArgumentError, ~r/192 unique scalar mappings/, fn ->
      validate_with_recomputed_mapping_digest(duplicate, metadata)
    end

    incomplete_metadata = String.replace(metadata, "`PCL-14P`", "`PCL-X`")

    assert_raise ArgumentError, ~r/metadata omits/, fn ->
      @source.validate!(mapping, incomplete_metadata,
        mapping_sha256: @mapping_sha256,
        metadata_sha256: sha256(incomplete_metadata)
      )
    end
  end

  test "native direct callbacks are linear and stay within the generic reduction ceiling" do
    alphabet = :erlang.list_to_binary(Enum.to_list(0x00..0x7F) ++ Enum.to_list(0xA0..0xDF))
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

  test "provenance pins independent primary manuals and the FreeDOS implementation" do
    assert @source.profile_counts() == %{defined: 192, undefined: 64, non_ascii: 64}
    assert @source.unit_bits() == 8
    assert @source.control_policy() == :ascii_identity_including_c0_and_del
    assert @source.reverse_policy() == :exact_bijective_inverse
    assert @source.packed_applicability() == :not_applicable_octet_codec
    assert @source.gnu_libiconv_support() == :unsupported

    assert @source.mapping_sha256() ==
             "2edd0ed4875ee8f62ad82c2cfde796842a05bbef82b9a3f1cd123ed3c9c03bfb"

    assert @source.metadata_sha256() ==
             "31ea0634ca8ad35b5c872419e53b7890da020b8d8ba9725471d454176b0ed9de"

    assert source_high_table() == oracle_table() |> Tuple.to_list() |> Enum.drop(0x80)

    assert @source.source_sha256(:star_manual) ==
             "c723b37df1b936606d960754713c23ed9ac11be1f0cb3365300fad1c9521724b"

    assert @source.source_sha256(:epson_manual) ==
             "9c957a73217d9e39cfa9ba5c3f4b40cdcfe205e8b988ee2bf69268d12d8c697d"

    assert @source.source_sha256(:freedos_archive) ==
             "5af7b1064c946810453034aa689870ecf6b2d8640f5daec9c45496808afd50bc"

    assert @source.source_sha256(:freedos_ega18_cpx) ==
             "11944b119a838656de3fc795521e90bbc610b000fe603f95f8c685ee21216b1f"

    assert @source.source_url(:star_manual) ==
             "https://archive.org/download/manuallib-id-2525457/2525457.pdf"

    assert @source.source_url(:epson_manual) ==
             "https://archive.org/download/manualzz-id-749516/749516.pdf"

    assert @source.source_page(:star_manual) == %{physical_pdf: 64, printed: 58}
    assert @source.source_page(:epson_manual) == %{physical_pdf: 119, printed: "B-5"}
    assert @source.source_size(:star_manual) == 3_261_185

    assert @source.alternate_artifact(:star_manual) == %{
             url:
               "https://minuszerodegrees.net/manuals/Star%20Micronics/dot_matrix/" <>
                 "Star%20Micronics%20-%20LC-8021%20-%20Users%20Manual.pdf",
             sha256: "b47aa8daac993cdfa128f5036aa3cef8b5a05315b15c865cea509e3c88b80157",
             size: 3_260_460,
             page_64_semantics: :render_identical
           }

    assert @source.source_license(:star_manual) == :copyrighted_reference_only
    assert @source.source_license(:freedos_ega18_cpx) == :gpl_2_0_or_later_reference_only

    assert @source.gnu_fixture_sha256(:encodings_extra_def) ==
             "0747ecd7a6311ea3fab734d666e49b17e39750a4ba5d498fee267132461e3303"
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

  defp oracle_table, do: @oracle_table

  defp validate_with_recomputed_mapping_digest(mapping, metadata) do
    @source.validate!(mapping, metadata,
      mapping_sha256: sha256(mapping),
      metadata_sha256: @metadata_sha256
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

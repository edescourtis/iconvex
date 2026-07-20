defmodule Iconvex.Specs.LotusLICSTest do
  use ExUnit.Case, async: false

  @codec Module.concat([Iconvex, Specs, LotusLICS])
  @source_asset Module.concat([Iconvex, Specs, LotusLICS, SourceAsset])
  @packed Module.concat([Iconvex, Specs, LotusLICS, Packed])
  @source_dir Path.expand("../priv/sources/lotus-lics", __DIR__)
  @mapping Path.join(@source_dir, "lotus_lics_hp_1991.csv")
  @metadata Path.join(@source_dir, "SOURCE_METADATA.md")

  # Literal fixture digests prevent the implementation from blessing changed
  # source assets at runtime.
  @mapping_sha256 "2eedf12805e1aee25e37044ddf58c8fcdcb9e754f3c3776aeb8a0447674a5239"
  @metadata_sha256 "328bb0a6b703742a8b882adcb079d5413ae9a4d6cb514dcd0ae4b6b83fe6cfe2"

  @hp_sha256 "358d8b5b06cc196034fcb54af77388cc0d75f58513f7ea4dd4cc6488e04ef621"
  @xerox_sha256 "dd588f6a90c38ce9ae612a25439310f7a374581facbdf2325f2b05dd8863e72c"
  @lotus_sha256 "3fd743be6e67450d889a1bc4164e12f7edb6dbe106b6915768eabff545e35beb"

  @undefined Enum.to_list(0x85..0x8F) ++ [0x99] ++ Enum.to_list(0x9C..0x9F) ++ [0xFF]
  @replacements %{
    0x80 => 0x0300,
    0x81 => 0x0301,
    0x82 => 0x0302,
    0x83 => 0x0308,
    0x84 => 0x0303,
    0x90 => 0x0300,
    0x91 => 0x0301,
    0x92 => 0x0302,
    0x93 => 0x0308,
    0x94 => 0x0303,
    0x95 => 0x0131,
    0x96 => 0x0331,
    0x97 => 0x25B2,
    0x98 => 0x25BC,
    0x9A => 0x00A0,
    0x9B => 0x2190,
    0xA0 => 0x0192,
    0xA1 => 0x00A1,
    0xA2 => 0x00A2,
    0xA3 => 0x00A3,
    0xA4 => 0x201C,
    0xA5 => 0x00A5,
    0xA6 => 0x20A7,
    0xA7 => 0x00A7,
    0xA8 => 0x00A4,
    0xA9 => 0x00A9,
    0xAA => 0x00AA,
    0xAB => 0x00AB,
    0xAC => 0x0394,
    0xAD => 0x03C0,
    0xAE => 0x2265,
    0xAF => 0x00F7,
    0xB0 => 0x00B0,
    0xB1 => 0x00B1,
    0xB2 => 0x00B2,
    0xB3 => 0x00B3,
    0xB4 => 0x201E,
    0xB5 => 0x00B5,
    0xB6 => 0x00B6,
    0xB7 => 0x00B7,
    0xB8 => 0x2122,
    0xB9 => 0x00B9,
    0xBA => 0x00BA,
    0xBB => 0x00BB,
    0xBC => 0x00BC,
    0xBD => 0x00BD,
    0xBE => 0x2264,
    0xBF => 0x00BF,
    0xD7 => 0x0152,
    0xDD => 0x0178,
    0xF7 => 0x0153,
    0xFD => 0x00FF,
    0xFE => 0x00FE
  }

  @table 0..255
         |> Enum.map(fn byte ->
           cond do
             byte in @undefined -> nil
             Map.has_key?(@replacements, byte) -> Map.fetch!(@replacements, byte)
             true -> byte
           end
         end)
         |> List.to_tuple()

  @inverse @table
           |> Tuple.to_list()
           |> Enum.with_index()
           |> Enum.reject(fn {codepoint, _byte} -> is_nil(codepoint) end)
           |> Enum.reduce(%{}, fn {codepoint, byte}, acc -> Map.put_new(acc, codepoint, byte) end)

  test "RED: pins the complete HP LICS profile and normalized source assets" do
    assert Code.ensure_loaded?(@codec)
    assert Code.ensure_loaded?(@source_asset)
    refute Code.ensure_loaded?(@packed)
    assert File.regular?(@mapping)
    assert File.regular?(@metadata)
    assert sha256(File.read!(@mapping)) == @mapping_sha256
    assert sha256(File.read!(@metadata)) == @metadata_sha256

    assert Path.wildcard(Path.join(@source_dir, "*")) |> Enum.sort() ==
             Enum.sort([@mapping, @metadata])

    metadata = File.read!(@metadata)
    assert metadata =~ "HP 95LX User's Guide"
    assert metadata =~ "June 1991"
    assert metadata =~ "Appendix F"
    assert metadata =~ "Xerox ViewPoint File Conversions Reference"
    assert metadata =~ "May 1988"
    assert metadata =~ "Lotus 1-2-3 Release 2"
    assert metadata =~ @hp_sha256
    assert metadata =~ @xerox_sha256
    assert metadata =~ @lotus_sha256
    assert metadata =~ "0x97, 0x98, 0x9A, and 0x9B"
    assert metadata =~ "lowest-byte canonical encoder"
    assert metadata =~ "LGPL-2.1-or-later"
    assert metadata =~ "GNU libiconv 1.19 does not expose LICS"
  end

  test "the independent CSV classifies every byte and the profile evolution exactly" do
    rows = source_rows()

    assert length(rows) == 256
    assert Enum.map(rows, & &1.byte) == Enum.to_list(0..255)
    assert Enum.map(rows, & &1.codepoint) == Tuple.to_list(@table)

    assert Enum.frequencies_by(rows, & &1.provenance) == %{
             "hp_1991_control" => 32,
             "hp_1991_ascii" => 96,
             "hp_1991_extension" => 4,
             "hp_1991_undefined" => 17,
             "xerox_1988_hp_1991" => 107
           }

    assert Enum.filter(rows, &(&1.status == "undefined")) |> Enum.map(& &1.byte) == @undefined

    assert Enum.filter(rows, &(&1.provenance == "hp_1991_extension"))
           |> Enum.map(& &1.byte) == [0x97, 0x98, 0x9A, 0x9B]

    assert Enum.at(rows, 0x7F).codepoint == 0x007F
    assert Enum.at(rows, 0x80).codepoint == 0x0300
    assert Enum.at(rows, 0x96).codepoint == 0x0331
    assert Enum.at(rows, 0xA4).codepoint == 0x201C
    assert Enum.at(rows, 0xB4).codepoint == 0x201E
    assert Enum.at(rows, 0xFD).codepoint == 0x00FF
    assert Enum.at(rows, 0xFF).codepoint == nil
  end

  test "source validation rejects digest, schema, ordering, value, status, and provenance tampering" do
    csv = File.read!(@mapping)
    metadata = File.read!(@metadata)

    assert length(validate(csv, metadata)) == 256

    assert_raise ArgumentError, ~r/mapping SHA-256 mismatch/, fn ->
      call(@source_asset, :validate!, [
        csv <> "x",
        metadata,
        [mapping_sha256: @mapping_sha256, metadata_sha256: @metadata_sha256]
      ])
    end

    assert_raise ArgumentError, ~r/metadata SHA-256 mismatch/, fn ->
      call(@source_asset, :validate!, [
        csv,
        metadata <> "x",
        [mapping_sha256: @mapping_sha256, metadata_sha256: @metadata_sha256]
      ])
    end

    wrong_header =
      String.replace(csv, "byte_hex,unicode_hex,status,provenance", "byte,value,state,source")

    assert_raise ArgumentError, ~r/unexpected LICS mapping header/, fn ->
      validate_with_digest(wrong_header, metadata)
    end

    assert_raise ArgumentError, ~r/ordered row 00/, fn ->
      validate_with_digest(reorder_first_two_rows(csv), metadata)
    end

    changed_value = String.replace(csv, "A4,201C,mapped", "A4,201D,mapped")

    assert_raise ArgumentError, ~r/differ from the HP 1991 profile/, fn ->
      validate_with_digest(changed_value, metadata)
    end

    changed_status = String.replace(csv, "85,,undefined", "85,0085,mapped")

    assert_raise ArgumentError, ~r/differ from the HP 1991 profile/, fn ->
      validate_with_digest(changed_status, metadata)
    end

    changed_provenance =
      String.replace(csv, "97,25B2,mapped,hp_1991_extension", "97,25B2,mapped,xerox_1988_hp_1991")

    assert_raise ArgumentError, ~r/provenance must distinguish/, fn ->
      validate_with_digest(changed_provenance, metadata)
    end

    incomplete_metadata = String.replace(metadata, "Appendix F", "Appendix X")

    assert_raise ArgumentError, ~r/metadata omits/, fn ->
      call(@source_asset, :validate!, [
        csv,
        incomplete_metadata,
        [mapping_sha256: @mapping_sha256, metadata_sha256: sha256(incomplete_metadata)]
      ])
    end
  end

  test "every one of the 256 byte values has the exact strict and direct result" do
    for byte <- 0..255 do
      case elem(@table, byte) do
        nil ->
          assert call(@codec, :decode, [<<byte>>]) ==
                   {:error, :invalid_sequence, 0, <<byte>>}

          assert call(@codec, :decode_to_utf8, [<<byte>>]) ==
                   {:error, :invalid_sequence, 0, <<byte>>}

        codepoint ->
          assert call(@codec, :decode, [<<byte>>]) == {:ok, [codepoint]}
          assert call(@codec, :decode_to_utf8, [<<byte>>]) == {:ok, <<codepoint::utf8>>}
      end
    end

    for {bad_byte, index} <- Enum.with_index(@undefined) do
      prefix = :binary.copy("A", index)

      assert call(@codec, :decode, [prefix <> <<bad_byte, ?Z>>]) ==
               {:error, :invalid_sequence, index, <<bad_byte>>}
    end
  end

  test "discard covers every undefined position without changing any assigned position" do
    bytes = :binary.list_to_bin(Enum.to_list(0..255))
    expected = @table |> Tuple.to_list() |> Enum.reject(&is_nil/1)

    assert call(@codec, :decode_discard, [bytes]) == {:ok, expected}

    interleaved =
      Enum.flat_map(0..255, fn byte -> [byte, 0x85] end) |> :binary.list_to_bin()

    assert call(@codec, :decode_discard, [interleaved]) == {:ok, expected}
  end

  test "the encoder is exhaustive and uses the documented canonical duplicate bytes" do
    assert map_size(@inverse) == 234

    assert call(@codec, :encode, [[0x0300, 0x0301, 0x0302, 0x0308, 0x0303]]) ==
             {:ok, <<0x80, 0x81, 0x82, 0x83, 0x84>>}

    for {codepoint, byte} <- @inverse do
      assert call(@codec, :encode, [[codepoint]]) == {:ok, <<byte>>}
      assert call(@codec, :encode_from_utf8, [<<codepoint::utf8>>]) == {:ok, <<byte>>}
    end

    Enum.each(0..0x10FFFF, fn codepoint ->
      unless codepoint in 0xD800..0xDFFF do
        expected =
          case @inverse do
            %{^codepoint => byte} -> {:ok, <<byte>>}
            _ -> {:error, :unrepresentable_character, codepoint}
          end

        actual = call(@codec, :encode, [[codepoint]])

        unless actual == expected do
          flunk(
            "inverse mismatch for U+#{Integer.to_string(codepoint, 16)}: " <>
              "expected #{inspect(expected)}, got #{inspect(actual)}"
          )
        end
      end
    end)
  end

  test "all five Unicode duplicate pairs decode, with byte roundtrip limits explicit" do
    pairs = [
      {0x80, 0x90, 0x0300},
      {0x81, 0x91, 0x0301},
      {0x82, 0x92, 0x0302},
      {0x83, 0x93, 0x0308},
      {0x84, 0x94, 0x0303}
    ]

    for {canonical, alternate, codepoint} <- pairs do
      assert call(@codec, :decode, [<<canonical>>]) == {:ok, [codepoint]}
      assert call(@codec, :decode, [<<alternate>>]) == {:ok, [codepoint]}
      assert call(@codec, :encode, [[codepoint]]) == {:ok, <<canonical>>}
    end
  end

  test "strict, discard, substitute, and malformed UTF-8 preserve first-error precedence" do
    assert call(@codec, :encode, [[?A, 0x1F642, ?B]]) ==
             {:error, :unrepresentable_character, 0x1F642}

    assert call(@codec, :encode_discard, [[?A, 0x1F642, ?B]]) == {:ok, "AB"}

    assert call(@codec, :encode_substitute, [
             [?A, 0x1F642, ?B],
             fn 0x1F642 -> ~c"?" end
           ]) == {:ok, "A?B"}

    assert call(@codec, :encode_substitute, [
             [?A, 0x1F642, ?B],
             fn 0x1F642 -> [0x1F643] end
           ]) == {:error, :unrepresentable_character, 0x1F643}

    assert call(@codec, :encode_from_utf8, ["A" <> <<0xE2, 0x82>>]) ==
             {:decode_error, :incomplete_sequence, 1, <<0xE2, 0x82>>}

    assert call(@codec, :encode_from_utf8, ["A" <> <<0xFF, ?B>>]) ==
             {:decode_error, :invalid_sequence, 1, <<0xFF, ?B>>}

    assert call(@codec, :encode_from_utf8, [<<0x1F642::utf8, 0xFF>>]) ==
             {:error, :unrepresentable_character, 0x1F642}
  end

  test "stateless streams match one-shot conversion at every valid boundary" do
    assigned =
      @table
      |> Tuple.to_list()
      |> Enum.with_index()
      |> Enum.reject(fn {codepoint, _byte} -> is_nil(codepoint) end)

    bytes = assigned |> Enum.map(&elem(&1, 1)) |> :binary.list_to_bin()
    codepoints = Enum.map(assigned, &elem(&1, 0))

    for split <- 0..byte_size(bytes) do
      <<left::binary-size(split), right::binary>> = bytes
      assert decode_chunks([left, right]) == {:ok, codepoints}
    end

    canonical = Enum.sort_by(@inverse, fn {_codepoint, byte} -> byte end)
    canonical_codepoints = Enum.map(canonical, &elem(&1, 0))
    canonical_bytes = canonical |> Enum.map(&elem(&1, 1)) |> :binary.list_to_bin()

    for split <- 0..length(canonical_codepoints) do
      {left, right} = Enum.split(canonical_codepoints, split)
      assert encode_chunks([left, right], :error) == {:ok, canonical_bytes}
    end

    assert decode_chunks(for <<byte <- bytes>>, do: <<byte>>) == {:ok, codepoints}
    assert encode_chunks(Enum.map(canonical_codepoints, &[&1]), :error) == {:ok, canonical_bytes}

    assert call(@codec, :decode_chunk, [<<0x85>>, false]) ==
             {:error, :invalid_sequence, 0, <<0x85>>}

    assert call(@codec, :encode_chunk, [[?A, 0x1F642, ?B], false, :discard]) ==
             {:ok, "AB", []}

    assert call(@codec, :encode_chunk, [
             [?A, 0x1F642, ?B],
             false,
             {:replace, fn 0x1F642 -> ~c"?" end}
           ]) == {:ok, "A?B", []}
  end

  test "native direct paths are linear around chunk edges" do
    alphabet =
      @table
      |> Tuple.to_list()
      |> Enum.with_index()
      |> Enum.reject(fn {codepoint, _byte} -> is_nil(codepoint) end)
      |> Enum.map(&elem(&1, 1))
      |> :binary.list_to_bin()

    small = repeat_to_size(alphabet, 32_768)
    large = repeat_to_size(alphabet, 65_536)
    {:ok, small_text} = call(@codec, :decode_to_utf8, [small])
    {:ok, large_text} = call(@codec, :decode_to_utf8, [large])

    assert call(@codec, :encode_from_utf8, [small_text]) ==
             {:ok, canonicalize_bytes(small)}

    assert call(@codec, :encode_from_utf8, [large_text]) ==
             {:ok, canonicalize_bytes(large)}

    assert reductions(fn -> call(@codec, :decode_to_utf8, [large]) end) /
             max(reductions(fn -> call(@codec, :decode_to_utf8, [small]) end), 1) < 2.40

    assert reductions(fn -> call(@codec, :encode_from_utf8, [large_text]) end) /
             max(reductions(fn -> call(@codec, :encode_from_utf8, [small_text]) end), 1) < 2.40
  end

  test "identity, provenance, profile distinction, GNU absence, and octet transport are explicit" do
    assert call(@codec, :canonical_name, []) == "LICS"
    assert call(@codec, :aliases, []) == ["LOTUS-INTERNATIONAL-CHARACTER-SET"]
    assert call(@codec, :codec_id, []) == :lotus_lics_hp_1991
    assert call(@codec, :unit_bits, []) == 8
    assert call(@codec, :packed_applicability, []) == :not_applicable_octet_codec
    assert call(@codec, :gnu_libiconv_support, []) == :unsupported
    refute Code.ensure_loaded?(@packed)

    assert call(@source_asset, :profile_counts, []) == %{
             defined: 239,
             undefined: 17,
             unique_scalars: 234,
             unicode_duplicates: 5
           }

    assert call(@source_asset, :reverse_policy, []) == :lowest_byte_canonical_for_duplicates

    assert call(@source_asset, :mapping_sha256, []) == @mapping_sha256
    assert call(@source_asset, :metadata_sha256, []) == @metadata_sha256

    assert call(@source_asset, :earlier_profile_differences, []) == %{
             xerox_1988_unlisted_hp_1991_assigned: [0x97, 0x98, 0x9A, 0x9B]
           }

    assert call(@source_asset, :source_sha256, [:hp_manual]) == @hp_sha256
    assert call(@source_asset, :source_sha256, [:xerox_manual]) == @xerox_sha256
    assert call(@source_asset, :source_sha256, [:lotus_release_2_files]) == @lotus_sha256
    assert call(@source_asset, :source_size, [:hp_manual]) == 7_575_631
    assert call(@source_asset, :source_size, [:xerox_manual]) == 11_527_427
    assert call(@source_asset, :source_size, [:lotus_release_2_files]) == 728_366

    assert call(@source_asset, :source_url, [:hp_manual]) ==
             "https://www.retroisle.com/others/hp95lx/OriginalDocs/" <>
               "95LX_UsersGuide_F1000-90001_826pages_Jun91.pdf"

    assert call(@source_asset, :source_url, [:xerox_manual]) ==
             "https://bitsavers.org/pdf/xerox/viewpoint/VP_2.0/" <>
               "610E12320_File_Conversion_Reference_Volume_10_May88.pdf"

    assert call(@source_asset, :source_url, [:lotus_release_2_files]) ==
             "https://archive.org/download/Lotus1-2-3Release2/files_extracted.zip"

    assert call(@source_asset, :source_license, [:hp_manual]) ==
             :copyrighted_reference_only

    assert call(@source_asset, :source_pages, [:hp_manual]) == %{
             physical_pdf: 792..798,
             printed: "F-1..F-7"
           }

    assert call(@source_asset, :source_pages, [:xerox_manual]) == %{
             physical_pdf: 166..179,
             printed: "6-19..6-32"
           }

    assert call(@source_asset, :gnu_fixture_sha256, [:encodings_def]) ==
             "156cc484a53109241e3c4d23e0ac1d75c0e199eac48f3de8e9d9e87ecc1ce5f1"

    assert call(@source_asset, :gnu_fixture_sha256, [:encodings_extra_def]) ==
             "0747ecd7a6311ea3fab734d666e49b17e39750a4ba5d498fee267132461e3303"

    assert call(@source_asset, :gnu_fixture_sha256, [:iconv_l_default]) ==
             "f747cadfad9e17ecfa455937b2f95e8bef5c747dcd989d66e52e4681e49b3da1"

    public_functions = @source_asset.__info__(:functions)
    refute {:high_hex, 0} in public_functions
    assert {:high_hex, 0} in @source_asset.__info__(:macros)

    refute Enum.any?(public_functions, fn {name, _arity} ->
             text = Atom.to_string(name)
             String.ends_with?(text, "path") or String.ends_with?(text, "dir")
           end)
  end

  defp source_rows do
    @mapping
    |> File.read!()
    |> String.split("\n", trim: true)
    |> case do
      ["byte_hex,unicode_hex,status,provenance" | rows] -> Enum.map(rows, &parse_source_row/1)
      [header | _rows] -> flunk("unexpected source header #{inspect(header)}")
    end
  end

  defp parse_source_row(row) do
    [byte, unicode, status, provenance] = String.split(row, ",", parts: 4)

    %{
      byte: String.to_integer(byte, 16),
      codepoint: if(unicode == "", do: nil, else: String.to_integer(unicode, 16)),
      status: status,
      provenance: provenance
    }
  end

  defp validate(csv, metadata) do
    call(@source_asset, :validate!, [
      csv,
      metadata,
      [mapping_sha256: @mapping_sha256, metadata_sha256: @metadata_sha256]
    ])
  end

  defp validate_with_digest(csv, metadata) do
    call(@source_asset, :validate!, [
      csv,
      metadata,
      [mapping_sha256: sha256(csv), metadata_sha256: @metadata_sha256]
    ])
  end

  defp reorder_first_two_rows(csv) do
    [header, first, second | rest] = String.split(csv, "\n", trim: true)
    Enum.join([header, second, first | rest], "\n") <> "\n"
  end

  defp decode_chunks(chunks) do
    chunks
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, [], <<>>}, fn {chunk, index}, {:ok, acc, pending} ->
      final? = index == length(chunks) - 1

      case call(@codec, :decode_chunk, [pending <> chunk, final?]) do
        {:ok, decoded, next_pending} -> {:cont, {:ok, [decoded | acc], next_pending}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, reversed, <<>>} -> {:ok, reversed |> :lists.reverse() |> List.flatten()}
      other -> other
    end
  end

  defp encode_chunks(chunks, policy) do
    chunks
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, [], []}, fn {chunk, index}, {:ok, acc, pending} ->
      final? = index == length(chunks) - 1

      case call(@codec, :encode_chunk, [pending ++ chunk, final?, policy]) do
        {:ok, encoded, next_pending} -> {:cont, {:ok, [encoded | acc], next_pending}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, reversed, []} -> {:ok, reversed |> :lists.reverse() |> IO.iodata_to_binary()}
      other -> other
    end
  end

  defp canonicalize_bytes(bytes) do
    for <<byte <- bytes>>, into: <<>> do
      codepoint = elem(@table, byte)
      <<Map.fetch!(@inverse, codepoint)>>
    end
  end

  defp repeat_to_size(alphabet, size) do
    copies = div(size + byte_size(alphabet) - 1, byte_size(alphabet))
    alphabet |> :binary.copy(copies) |> binary_part(0, size)
  end

  defp reductions(function) do
    parent = self()
    token = make_ref()

    spawn(fn ->
      :erlang.garbage_collect()
      {:reductions, before_count} = Process.info(self(), :reductions)
      result = function.()
      {:reductions, after_count} = Process.info(self(), :reductions)
      send(parent, {token, result, after_count - before_count})
    end)

    receive do
      {^token, {:ok, _output}, count} -> count
      {^token, result, _count} -> flunk("reduction path failed: #{inspect(result)}")
    after
      30_000 -> flunk("reduction worker timed out")
    end
  end

  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
  defp call(module, function, arguments), do: apply(module, function, arguments)
end

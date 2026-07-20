defmodule Iconvex.Specs.BraSCIITest do
  use ExUnit.Case, async: false

  @codec Module.concat([Iconvex, Specs, BraSCII])
  @source_asset Module.concat([Iconvex, Specs, BraSCII, SourceAsset])
  @source_dir Path.expand("../priv/sources/brascii", __DIR__)
  @mapping Path.join(@source_dir, "brascii_nbr_9611.csv")
  @metadata Path.join(@source_dir, "SOURCE_METADATA.md")

  @mapping_sha256 "d3854633818c51e23aa189a5628a8356c5cfb36a3885da7ae9239a6a833944ac"
  @metadata_sha256 "f0c87c17e1ccfa6a601bbc0e8b55d5ca97b82d43eebed8091277748a37e3063c"
  @epson_sha256 "9c957a73217d9e39cfa9ba5c3f4b40cdcfe205e8b988ee2bf69268d12d8c697d"
  @star_sha256 "c723b37df1b936606d960754713c23ed9ac11be1f0cb3365300fad1c9521724b"
  @star_mirror_sha256 "b47aa8daac993cdfa128f5036aa3cef8b5a05315b15c865cea509e3c88b80157"
  @star_page_raster_sha256 "8f9a7a87454e8a58df381137714774844bd14a35ae5127a875a4eba0c9ebaca5"
  @ecma_sha256 "dd7541b58618e2995f77e28b07434626e03b299df60039d2861e10d414600ba1"

  test "RED: pins the normalized table and independent primary-source evidence" do
    assert File.regular?(@mapping)
    assert File.regular?(@metadata)
    assert sha256_file(@mapping) == @mapping_sha256
    assert sha256_file(@metadata) == @metadata_sha256

    assert Path.wildcard(Path.join(@source_dir, "*")) |> Enum.sort() ==
             Enum.sort([@mapping, @metadata])

    metadata = File.read!(@metadata)
    assert metadata =~ "ABNT NBR 9611:1991"
    assert metadata =~ "Epson Stylus COLOR 200"
    assert metadata =~ @epson_sha256
    assert metadata =~ "Star Micronics LC-8021"
    assert metadata =~ @star_sha256
    assert metadata =~ @star_mirror_sha256
    assert metadata =~ @star_page_raster_sha256
    assert metadata =~ "ECMA-94"
    assert metadata =~ @ecma_sha256
    assert metadata =~ "C0 and C1"
    assert metadata =~ "LGPL-2.1-or-later"
    assert metadata =~ "GNU libiconv 1.19 does not expose BraSCII"
    assert metadata =~ "upstream PDFs are not redistributed"
  end

  test "the independent CSV oracle explicitly classifies all 256 byte values" do
    rows = source_rows()

    assert length(rows) == 256
    assert Enum.map(rows, & &1.byte) == Enum.to_list(0..255)
    assert Enum.map(rows, & &1.codepoint) == Enum.map(0..255, &oracle_decode/1)

    assert Enum.frequencies_by(rows, & &1.classification) == %{
             "ascii_graphic" => 95,
             "c0_control" => 32,
             "c1_control" => 32,
             "delete_control" => 1,
             "g1_graphic" => 96
           }

    assert Enum.frequencies_by(rows, & &1.status) == %{
             "control" => 65,
             "graphic" => 189,
             "space" => 2
           }

    assert Enum.at(rows, 0xD7) == %{
             byte: 0xD7,
             codepoint: 0x0152,
             classification: "g1_graphic",
             status: "graphic",
             notes: "brascii_oe_override"
           }

    assert Enum.at(rows, 0xF7) == %{
             byte: 0xF7,
             codepoint: 0x0153,
             classification: "g1_graphic",
             status: "graphic",
             notes: "brascii_oe_override"
           }
  end

  test "source validator locks digests, ordering, classification, and the two overrides" do
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

  test "every byte decodes against the independent NBR 9611 oracle" do
    for byte <- 0..255 do
      expected = oracle_decode(byte)
      assert call(@codec, :decode, [<<byte>>]) == {:ok, [expected]}
      assert call(@codec, :decode_to_utf8, [<<byte>>]) == {:ok, <<expected::utf8>>}
    end

    bytes = :binary.list_to_bin(Enum.to_list(0..255))
    expected = Enum.map(0..255, &oracle_decode/1)
    assert call(@codec, :decode, [bytes]) == {:ok, expected}
    assert call(@codec, :decode_discard, [bytes]) == {:ok, expected}
    assert call(@codec, :decode_to_utf8, [bytes]) == {:ok, List.to_string(expected)}
  end

  test "the inverse is byte-roundtrip exact and deliberately excludes multiplication and division" do
    for byte <- 0..255 do
      codepoint = oracle_decode(byte)
      assert call(@codec, :encode, [[codepoint]]) == {:ok, <<byte>>}
      assert call(@codec, :encode_from_utf8, [<<codepoint::utf8>>]) == {:ok, <<byte>>}
    end

    assert call(@codec, :encode, [[0x00D7]]) ==
             {:error, :unrepresentable_character, 0x00D7}

    assert call(@codec, :encode, [[0x00F7]]) ==
             {:error, :unrepresentable_character, 0x00F7}

    assert call(@codec, :encode, [[0x0152, 0x0153]]) == {:ok, <<0xD7, 0xF7>>}
    assert call(@codec, :encode_from_utf8, ["Œœ"]) == {:ok, <<0xD7, 0xF7>>}
  end

  @tag timeout: 120_000
  test "every Unicode scalar has exactly the independently specified inverse result" do
    Enum.each(0..0x10FFFF, fn codepoint ->
      unless codepoint in 0xD800..0xDFFF do
        expected = oracle_encode(codepoint)
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

  test "strict, discard, substitution, and malformed UTF-8 preserve first-error semantics" do
    assert call(@codec, :encode, [[?A, 0x2603, ?B]]) ==
             {:error, :unrepresentable_character, 0x2603}

    assert call(@codec, :encode_discard, [[?A, 0x2603, ?B]]) == {:ok, "AB"}

    assert call(@codec, :encode_substitute, [
             [?A, 0x2603, ?B],
             fn 0x2603 -> ~c"?" end
           ]) == {:ok, "A?B"}

    assert call(@codec, :encode_substitute, [
             [?A, 0x2603, ?B],
             fn 0x2603 -> [0x00D7] end
           ]) == {:error, :unrepresentable_character, 0x00D7}

    assert call(@codec, :encode_from_utf8, ["A" <> <<0xE2, 0x82>>]) ==
             {:decode_error, :incomplete_sequence, 1, <<0xE2, 0x82>>}

    assert call(@codec, :encode_from_utf8, ["A" <> <<0xFF>>]) ==
             {:decode_error, :invalid_sequence, 1, <<0xFF>>}

    assert call(@codec, :encode_from_utf8, [<<0x2603::utf8, 0xFF>>]) ==
             {:error, :unrepresentable_character, 0x2603}
  end

  test "stateless streaming agrees with one-shot conversion at every boundary" do
    bytes = :binary.list_to_bin(Enum.to_list(0..255))
    codepoints = Enum.map(0..255, &oracle_decode/1)
    {:ok, expected_text} = call(@codec, :decode_to_utf8, [bytes])

    for split <- 0..byte_size(bytes) do
      <<left::binary-size(split), right::binary>> = bytes
      assert decode_two_chunks(left, right) == {:ok, codepoints}
    end

    for split <- 0..length(codepoints) do
      {left, right} = Enum.split(codepoints, split)
      assert encode_two_chunks(left, right) == {:ok, bytes}
    end

    assert decode_chunks(for <<byte <- bytes>>, do: <<byte>>) == {:ok, codepoints}
    assert encode_chunks(Enum.map(codepoints, &[&1])) == {:ok, bytes}
    assert call(@codec, :decode_to_utf8, [bytes]) == {:ok, expected_text}
  end

  test "stream policies are applied in one pass with no false pending unit" do
    assert call(@codec, :decode_chunk, [<<0xD7>>, false]) == {:ok, [0x0152], <<>>}
    assert call(@codec, :encode_chunk, [[0x0152], false, :error]) == {:ok, <<0xD7>>, []}

    assert call(@codec, :encode_chunk, [[?A, 0x2603, ?B], false, :discard]) ==
             {:ok, "AB", []}

    assert call(@codec, :encode_chunk, [
             [?A, 0x2603, ?B],
             false,
             {:replace, fn 0x2603 -> ~c"?" end}
           ]) == {:ok, "A?B", []}

    assert call(@codec, :encode_chunk, [[?A, 0x2603, ?B], false, :error]) ==
             {:error, :unrepresentable_character, 0x2603}
  end

  test "large direct paths remain linear and bounded around output chunk edges" do
    small = :binary.copy(:binary.list_to_bin(Enum.to_list(0..255)), 128)
    large = small <> small
    {:ok, small_text} = call(@codec, :decode_to_utf8, [small])
    {:ok, large_text} = call(@codec, :decode_to_utf8, [large])

    assert call(@codec, :encode_from_utf8, [small_text]) == {:ok, small}
    assert call(@codec, :encode_from_utf8, [large_text]) == {:ok, large}

    assert reductions(fn -> call(@codec, :decode_to_utf8, [large]) end) /
             max(reductions(fn -> call(@codec, :decode_to_utf8, [small]) end), 1) < 2.40

    assert reductions(fn -> call(@codec, :encode_from_utf8, [large_text]) end) /
             max(reductions(fn -> call(@codec, :encode_from_utf8, [small_text]) end), 1) < 2.40
  end

  test "identity, aliases, provenance, and transport policy are explicit" do
    assert Code.ensure_loaded?(@codec)
    assert call(@codec, :canonical_name, []) == "BRASCII"

    assert call(@codec, :aliases, []) == [
             "BRA-SCII",
             "ABNT",
             "ABNT-BRASCII",
             "NBR-9611",
             "NBR-9611:1991",
             "NBR-9614",
             "NBR-9614:1986",
             "CP3847",
             "CODE-PAGE-3847",
             "BRAZIL-ABNT",
             "BRAZIL-ABNT-3847"
           ]

    assert call(@codec, :unit_bits, []) == 8
    assert call(@codec, :mapping_sha256, []) == @mapping_sha256
    assert call(@codec, :metadata_sha256, []) == @metadata_sha256
    assert call(@codec, :epson_source_sha256, []) == @epson_sha256
    assert call(@codec, :star_source_sha256, []) == @star_sha256
    assert call(@codec, :star_mirror_sha256, []) == @star_mirror_sha256
    assert call(@codec, :star_page_raster_sha256, []) == @star_page_raster_sha256
    assert call(@codec, :ecma_source_sha256, []) == @ecma_sha256
    assert call(@codec, :epson_source_page, []) == %{pdf: 119, printed: "B-5"}
    assert call(@codec, :star_source_page, []) == %{pdf: 64, printed: 58}

    assert call(@codec, :transport_policy, []) == %{
             ascii: :identity,
             c0_controls: :unicode_identity,
             c1_controls: :unicode_identity,
             g1_graphics: :nbr_9611_1991
           }
  end

  defp source_rows do
    @mapping
    |> File.read!()
    |> String.split("\n", trim: true)
    |> case do
      ["byte_hex,unicode_hex,classification,status,notes" | rows] ->
        Enum.map(rows, &parse_source_row/1)

      [header | _rows] ->
        flunk("unexpected source header #{inspect(header)}")
    end
  end

  defp parse_source_row(row) do
    [byte, codepoint, classification, status, notes] = String.split(row, ",", parts: 5)

    %{
      byte: String.to_integer(byte, 16),
      codepoint: String.to_integer(codepoint, 16),
      classification: classification,
      status: status,
      notes: notes
    }
  end

  defp oracle_decode(0xD7), do: 0x0152
  defp oracle_decode(0xF7), do: 0x0153
  defp oracle_decode(byte), do: byte

  defp oracle_encode(0x0152), do: {:ok, <<0xD7>>}
  defp oracle_encode(0x0153), do: {:ok, <<0xF7>>}

  defp oracle_encode(codepoint)
       when codepoint in 0..0xFF and codepoint not in [0xD7, 0xF7],
       do: {:ok, <<codepoint>>}

  defp oracle_encode(codepoint), do: {:error, :unrepresentable_character, codepoint}

  defp decode_two_chunks(left, right), do: decode_chunks([left, right])

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
      {:ok, _reversed, pending} -> {:error, :pending, pending}
      error -> error
    end
  end

  defp encode_two_chunks(left, right), do: encode_chunks([left, right])

  defp encode_chunks(chunks) do
    chunks
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, [], []}, fn {chunk, index}, {:ok, acc, pending} ->
      final? = index == length(chunks) - 1

      case call(@codec, :encode_chunk, [pending ++ chunk, final?, :error]) do
        {:ok, encoded, next_pending} -> {:cont, {:ok, [encoded | acc], next_pending}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, reversed, []} -> {:ok, reversed |> :lists.reverse() |> IO.iodata_to_binary()}
      {:ok, _reversed, pending} -> {:error, :pending, pending}
      error -> error
    end
  end

  defp reorder_first_two_rows(csv) do
    [header, first, second | rest] = String.split(csv, "\n", trim: true)
    Enum.join([header, second, first | rest], "\n") <> "\n"
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

  defp sha256_file(path), do: path |> File.read!() |> sha256_bytes()
  defp sha256_bytes(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
  defp call(module, function, arguments), do: apply(module, function, arguments)
end

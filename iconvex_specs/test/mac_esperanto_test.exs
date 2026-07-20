defmodule Iconvex.Specs.MacEsperantoTest do
  use ExUnit.Case, async: false

  @codec Module.concat([Iconvex, Specs, MacEsperanto])
  @source_asset Module.concat([Iconvex, Specs, MacEsperanto, SourceAsset])
  @source_dir Path.expand("../priv/sources/mac-esperanto", __DIR__)
  @mapping Path.join(@source_dir, "macos_esperanto_0_3.csv")
  @metadata Path.join(@source_dir, "SOURCE_METADATA.md")
  @mapping_sha256 "4ad11598020843b2728f438dc8e8e3149ee822ae03a688330ad0b80dc013aa05"
  @metadata_sha256 "20a59bec95edd225467b15124a6a1634799c01322ebe3dd0ac125b42a5e93ea1"
  @upstream_sha256 "d7ca70a8da95d5ec5338705d3cd0907232eed98416fe062bb731d86090a52084"

  @high_hex """
  000000C4000000C5000000C7000000C9000000D1000000D6000000DC000000E1
  000000E0000000E2000000E4000000E3000000E5000000E7000000E9000000E8
  000000EA000000EB000000ED000000EC000000EE000000EF000000F1000000F3
  000000F2000000F4000000F6000000F5000000FA000000F9000000FB000000FC
  00002020000000B0000000A2000000A3000000A700002022000000B6000000DF
  000000AE000000A900002122000000B4000000A800002260000000C6000000D8
  00000108000000B1000022640000226500000109000000B50000011C0000011D
  000001240000012500000134000001350000015C0000015D000000E6000000F8
  0000016C0000016D000000AC0000010A000001920000010B00000120000000AB
  000000BB00002026000000A0000000C0000000C3000000D50000015200000153
  00002013000020140000201C0000201D0000201800002019000000F7000025CA
  000000FF000001780000011E0000011F00000130000001310000015E0000015F
  00002021000000B70000201A0000201E00002030000000C2000000CA000000C1
  000000CB000000C8000000CD000000CE000000CF000000CC000000D3000000D4
  00000121000000D2000000DA000000DB000000D9000000A4000002C6000002DC
  00000126000002D8000002D90000017B000000B80000017C00000127000002C7
  """

  @high @high_hex
        |> String.replace(~r/\s+/, "")
        |> Base.decode16!()
        |> then(fn binary ->
          for <<codepoint::unsigned-big-32 <- binary>>, do: codepoint
        end)
  @table List.to_tuple(Enum.to_list(0x00..0x7F) ++ @high)
  @inverse @table
           |> Tuple.to_list()
           |> Enum.with_index()
           |> Map.new(fn {codepoint, byte} -> {codepoint, byte} end)

  test "RED: pins the normalized table and authoritative public source" do
    assert Code.ensure_loaded?(@codec)
    assert File.regular?(@mapping)
    assert File.regular?(@metadata)
    assert sha256_bytes(File.read!(@mapping)) == @mapping_sha256
    assert sha256_bytes(File.read!(@metadata)) == @metadata_sha256

    assert Path.wildcard(Path.join(@source_dir, "*")) |> Enum.sort() ==
             Enum.sort([@mapping, @metadata])

    metadata = File.read!(@metadata)
    assert metadata =~ "MacOS_Esperanto"
    assert metadata =~ "Table version: 0.3"
    assert metadata =~ "15 August 1997"
    assert metadata =~ "Michael Everson"
    assert metadata =~ @upstream_sha256
    assert metadata =~ "13,591"
    assert metadata =~ "Apple Computer, Inc."
    assert metadata =~ "C0 and DEL"
    assert metadata =~ "LGPL-2.1-or-later"
    assert metadata =~ "GNU libiconv 1.19 does not expose"
  end

  test "the independent CSV oracle classifies all 256 byte values exactly once" do
    rows = source_rows()

    assert length(rows) == 256
    assert Enum.map(rows, & &1.byte) == Enum.to_list(0..255)
    assert Enum.map(rows, & &1.codepoint) == Tuple.to_list(@table)

    assert Enum.frequencies_by(rows, & &1.provenance) == %{
             "source_identity" => 95,
             "source_mapping" => 128,
             "transport_identity" => 33
           }

    assert Enum.at(rows, 0xB0) == %{
             byte: 0xB0,
             codepoint: 0x0108,
             provenance: "source_mapping"
           }

    assert Enum.at(rows, 0xC0) == %{
             byte: 0xC0,
             codepoint: 0x016C,
             provenance: "source_mapping"
           }

    assert Enum.at(rows, 0xF5) == %{
             byte: 0xF5,
             codepoint: 0x00A4,
             provenance: "source_mapping"
           }
  end

  test "source validator locks digests, ordering, policy, and all table values" do
    csv = File.read!(@mapping)
    metadata = File.read!(@metadata)
    mapping_sha = call(@source_asset, :mapping_sha256, [])
    metadata_sha = call(@source_asset, :metadata_sha256, [])
    assert mapping_sha == @mapping_sha256
    assert metadata_sha == @metadata_sha256

    rows =
      call(@source_asset, :validate!, [
        csv,
        metadata,
        [mapping_sha256: mapping_sha, metadata_sha256: metadata_sha]
      ])

    assert length(rows) == 256
    assert sha256_bytes(csv) == mapping_sha
    assert sha256_bytes(metadata) == metadata_sha

    assert_raise ArgumentError, ~r/mapping SHA-256 mismatch/, fn ->
      call(@source_asset, :validate!, [
        csv <> "x",
        metadata,
        [mapping_sha256: mapping_sha, metadata_sha256: metadata_sha]
      ])
    end

    assert_raise ArgumentError, ~r/metadata SHA-256 mismatch/, fn ->
      call(@source_asset, :validate!, [
        csv,
        metadata <> "x",
        [mapping_sha256: mapping_sha, metadata_sha256: metadata_sha]
      ])
    end

    altered = String.replace(csv, "B0,0108,source_mapping", "B0,0109,source_mapping")

    assert_raise ArgumentError, ~r/80\.\.FF differ/, fn ->
      call(@source_asset, :validate!, [
        altered,
        metadata,
        [mapping_sha256: sha256_bytes(altered), metadata_sha256: metadata_sha]
      ])
    end

    reordered = reorder_first_two_rows(csv)

    assert_raise ArgumentError, ~r/ordered row.*00/i, fn ->
      call(@source_asset, :validate!, [
        reordered,
        metadata,
        [mapping_sha256: sha256_bytes(reordered), metadata_sha256: metadata_sha]
      ])
    end
  end

  test "every byte decodes against the independent MacOS Esperanto oracle" do
    for byte <- 0..255 do
      expected = elem(@table, byte)
      assert call(@codec, :decode, [<<byte>>]) == {:ok, [expected]}
      assert call(@codec, :decode_to_utf8, [<<byte>>]) == {:ok, <<expected::utf8>>}
    end

    bytes = :binary.list_to_bin(Enum.to_list(0..255))
    expected = Tuple.to_list(@table)
    assert call(@codec, :decode, [bytes]) == {:ok, expected}
    assert call(@codec, :decode_discard, [bytes]) == {:ok, expected}
    assert call(@codec, :decode_to_utf8, [bytes]) == {:ok, List.to_string(expected)}
  end

  test "the unique source mapping has an exact inverse for every byte" do
    assert map_size(@inverse) == 256

    for byte <- 0..255 do
      codepoint = elem(@table, byte)
      assert call(@codec, :encode, [[codepoint]]) == {:ok, <<byte>>}
      assert call(@codec, :encode_from_utf8, [<<codepoint::utf8>>]) == {:ok, <<byte>>}
    end

    assert call(@codec, :encode, [[0x0108, 0x0109, 0x016C, 0x016D]]) ==
             {:ok, <<0xB0, 0xB4, 0xC0, 0xC1>>}
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
             fn 0x2603 -> [0x2602] end
           ]) == {:error, :unrepresentable_character, 0x2602}

    assert call(@codec, :encode_from_utf8, ["A" <> <<0xE2, 0x82>>]) ==
             {:decode_error, :incomplete_sequence, 1, <<0xE2, 0x82>>}

    assert call(@codec, :encode_from_utf8, ["A" <> <<0xFF>>]) ==
             {:decode_error, :invalid_sequence, 1, <<0xFF>>}

    assert call(@codec, :encode_from_utf8, [<<0x2603::utf8, 0xFF>>]) ==
             {:error, :unrepresentable_character, 0x2603}
  end

  test "stateless streaming agrees with one-shot conversion at every boundary" do
    bytes = :binary.list_to_bin(Enum.to_list(0..255))
    codepoints = Tuple.to_list(@table)

    for split <- 0..byte_size(bytes) do
      <<left::binary-size(split), right::binary>> = bytes
      assert decode_chunks([left, right]) == {:ok, codepoints}
    end

    for split <- 0..length(codepoints) do
      {left, right} = Enum.split(codepoints, split)
      assert encode_chunks([left, right]) == {:ok, bytes}
    end

    assert decode_chunks(for <<byte <- bytes>>, do: <<byte>>) == {:ok, codepoints}
    assert encode_chunks(Enum.map(codepoints, &[&1])) == {:ok, bytes}
  end

  test "stream policies are one-pass and never retain a false pending unit" do
    assert call(@codec, :decode_chunk, [<<0xB0>>, false]) == {:ok, [0x0108], <<>>}
    assert call(@codec, :encode_chunk, [[0x0108], false, :error]) == {:ok, <<0xB0>>, []}

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

  test "large direct paths remain linear and bounded around chunk edges" do
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

  test "identity, exact aliases, provenance, and transport policy are explicit" do
    assert call(@codec, :canonical_name, []) == "MACOS_ESPERANTO"

    assert call(@codec, :aliases, []) == [
             "MACESPERANTO",
             "MAC-ESPERANTO",
             "MACOS-ESPERANTO"
           ]

    assert call(@codec, :codec_id, []) == :macos_esperanto_0_3
    assert call(@codec, :unit_bits, []) == 8
    assert call(@codec, :source_version, []) == "0.3"
    assert call(@codec, :source_date, []) == "1997-08-15"
    assert call(@codec, :source_author, []) == "Michael Everson"
    assert call(@codec, :upstream_sha256, []) == @upstream_sha256
    assert call(@codec, :source_size, []) == 13_591

    assert call(@codec, :gnu_fixture_sha256, [:encodings_def]) ==
             "156cc484a53109241e3c4d23e0ac1d75c0e199eac48f3de8e9d9e87ecc1ce5f1"

    assert call(@codec, :gnu_fixture_sha256, [:encodings_extra_def]) ==
             "0747ecd7a6311ea3fab734d666e49b17e39750a4ba5d498fee267132461e3303"

    assert call(@codec, :gnu_fixture_sha256, [:iconv_l_default]) ==
             "f747cadfad9e17ecfa455937b2f95e8bef5c747dcd989d66e52e4681e49b3da1"

    assert call(@codec, :source_url, []) ==
             "https://www.evertype.com/standards/eo/eo-table.html"

    assert call(@codec, :transport_policy, []) == %{
             ascii_graphics: :source_identity,
             c0_controls: :unicode_identity,
             delete: :unicode_identity,
             high_half: :source_mapping_0_3
           }

    assert call(@codec, :gnu_libiconv_support, []) == :unsupported
    assert call(@codec, :packed_applicability, []) == :not_applicable_octet_codec
  end

  defp source_rows do
    @mapping
    |> File.read!()
    |> String.split("\n", trim: true)
    |> case do
      ["byte_hex,unicode_hex,provenance" | rows] -> Enum.map(rows, &parse_source_row/1)
      [header | _rows] -> flunk("unexpected source header #{inspect(header)}")
    end
  end

  defp parse_source_row(row) do
    [byte, codepoint, provenance] = String.split(row, ",", parts: 3)

    %{
      byte: String.to_integer(byte, 16),
      codepoint: String.to_integer(codepoint, 16),
      provenance: provenance
    }
  end

  defp oracle_encode(codepoint) do
    case @inverse do
      %{^codepoint => byte} -> {:ok, <<byte>>}
      _ -> {:error, :unrepresentable_character, codepoint}
    end
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
      {:ok, _reversed, pending} -> {:error, :pending, pending}
      error -> error
    end
  end

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

  defp sha256_bytes(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
  defp call(module, function, arguments), do: apply(module, function, arguments)
end

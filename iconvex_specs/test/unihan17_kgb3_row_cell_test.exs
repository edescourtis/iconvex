defmodule Iconvex.Specs.Unihan17KGB3RowCellTest do
  use ExUnit.Case, async: false

  @moduletag timeout: 240_000

  @codec Iconvex.Specs.Unihan17KGB3RowCellGL
  @property Iconvex.Specs.Unihan17KGB3RowCellDecimalToken
  @source_asset Iconvex.Specs.UnihanGB3RowCell.SourceAsset

  @fixture_dir Path.expand("fixtures/unihan-17.0.0-telegraph", __DIR__)
  @unihan Path.join(@fixture_dir, "Unihan_OtherMappings-17.0.0.txt")
  @unicode_data Path.join(@fixture_dir, "UnicodeData-17.0.0.txt")
  @source_dir Path.expand("../priv/sources/unihan-17.0.0-kgb3", __DIR__)
  @mapping Path.join(@source_dir, "row_cells.csv")
  @metadata Path.join(@source_dir, "SOURCE_METADATA.md")
  @generator Path.expand("../tools/import_unihan17_kgb3_row_cell.exs", __DIR__)

  @unihan_sha256 "4fabda168d04a5ac360809a8bfa377fe54e04fbc069ba67cacad4df03d691fa0"
  @unicode_data_sha256 "2e1efc1dcb59c575eedf5ccae60f95229f706ee6d031835247d843c11d96470c"
  @mapping_sha256 "63dd2f9d88dc53b9c3603fe798b6f414c578fc22b68d840225a5d44b890d6baf"

  test "RED: pins and independently reproduces the complete Unicode 17 kGB3 snapshot" do
    assert sha256(File.read!(@unihan)) == @unihan_sha256
    assert sha256(File.read!(@unicode_data)) == @unicode_data_sha256
    assert sha256(File.read!(@mapping)) == @mapping_sha256
    assert File.regular?(@metadata)
    assert File.regular?(@generator)

    source = source_mappings()
    packaged = packaged_mappings()

    assert packaged == source
    assert map_size(source) == 7_236
    assert source |> Map.values() |> Enum.uniq() |> length() == 7_236
    assert source |> Map.keys() |> Enum.min() == 1601
    assert source |> Map.keys() |> Enum.max() == 9293
    refute Map.has_key?(source, 1893)
    refute Map.has_key?(source, 9294)

    assert Enum.count(source, fn {_coordinate, scalar} -> scalar in 0x3400..0x4DBF end) ==
             2_391

    assert Enum.count(source, fn {_coordinate, scalar} -> scalar in 0x4E00..0x9FFF end) ==
             4_843

    assert Enum.count(source, fn {_coordinate, scalar} -> scalar in 0x20000..0x2A6DF end) == 2

    metadata = File.read!(@metadata)
    assert metadata =~ "Unicode 17.0.0"
    assert metadata =~ "provisional `kGB3`"
    assert metadata =~ @unihan_sha256
    assert metadata =~ @mapping_sha256
    assert metadata =~ "Unicode License v3"
    assert metadata =~ "does not claim exact GB 13131-1991 conformance"
    assert metadata =~ "no ISO-2022 designation"
  end

  test "source validator rejects digest, schema, order, coordinate, and metadata tampering" do
    mapping = File.read!(@mapping)
    metadata = File.read!(@metadata)
    hashes = @source_asset.expected_hashes()

    assert length(@source_asset.validate!(mapping, metadata, hashes)) == 7_236

    assert_raise ArgumentError, ~r/mapping SHA-256 mismatch/, fn ->
      @source_asset.validate!(mapping <> "\n", metadata, hashes)
    end

    valid_hash = sha256(String.replace(mapping, "1601,U+4E0F", "1600,U+4E0F", global: false))

    assert_raise ArgumentError, ~r/row\/cell domain/, fn ->
      tampered = String.replace(mapping, "1601,U+4E0F", "1600,U+4E0F", global: false)
      @source_asset.validate!(tampered, metadata, %{hashes | mapping: valid_hash})
    end

    reordered = mapping |> String.split("\n") |> swap_rows(1, 2) |> Enum.join("\n")

    assert_raise ArgumentError, ~r/strictly increasing/, fn ->
      @source_asset.validate!(reordered, metadata, %{hashes | mapping: sha256(reordered)})
    end

    bad_header = String.replace(mapping, "row_cell_decimal", "coordinate", global: false)

    assert_raise ArgumentError, ~r/header/, fn ->
      @source_asset.validate!(bad_header, metadata, %{hashes | mapping: sha256(bad_header)})
    end

    assert_raise ArgumentError, ~r/metadata omits/, fn ->
      @source_asset.validate!(mapping, "incomplete", %{hashes | metadata: sha256("incomplete")})
    end
  end

  test "exposes one property-token mapping and one collision-safe GL codec" do
    assert @property.mapping_name() == "UNIHAN-17.0.0-KGB3-ROW-CELL-DECIMAL-TOKEN"

    assert @property.metadata() == %{
             aliases: [],
             assigned_tokens: 7_236,
             grammar: "[0-9]{4}",
             mapping_name: "UNIHAN-17.0.0-KGB3-ROW-CELL-DECIMAL-TOKEN",
             property_status: :provisional,
             reverse_policy: :unique,
             reverse_scalars: 7_236,
             stream_transport: :undefined,
             transport: :single_property_token,
             unicode_version: "17.0.0",
             unihan_property: :kGB3
           }

    assert @codec.canonical_name() == "UNIHAN-17.0.0-KGB3-ROW-CELL-GL"
    assert @codec.aliases() == []

    assert {:ok, %{canonical: "UNIHAN-17.0.0-KGB3-ROW-CELL-GL"}} =
             Iconvex.Registry.resolve(@codec.canonical_name())

    assert @property in Iconvex.Specs.property_token_mappings()
    assert @codec in Iconvex.Specs.codecs()

    for unsafe <- [
          "GB-13131",
          "GB13131",
          "GB/T-13131",
          "GB-13131-91",
          "GB/T-7589-1987",
          "KGB3",
          "EUC-GB3",
          "ISO-2022-CN-GB3"
        ] do
      assert Iconvex.Registry.resolve(unsafe) == :error
    end
  end

  test "property tokens cover all assignments and reject holes, bad syntax, and bad UTF-8" do
    for {coordinate, scalar} <- source_mappings() do
      token = coordinate |> Integer.to_string() |> String.pad_leading(4, "0")
      assert @property.decode_token(token) == {:ok, scalar}
      assert @property.decode_token_to_utf8(token) == {:ok, <<scalar::utf8>>}
      assert @property.encode_scalar(scalar) == {:ok, token}
      assert @property.encode_utf8_to_token(<<scalar::utf8>>) == {:ok, token}
    end

    assert @property.decode_token("1893") == {:error, {:unassigned_token, "1893"}}
    assert @property.decode_token("9294") == {:error, {:unassigned_token, "9294"}}
    assert @property.decode_token("123") == {:error, {:invalid_token_length, 3}}
    assert @property.decode_token("1x01") == {:error, {:invalid_token_digit, 1, "x"}}
    assert @property.encode_scalar(?A) == {:error, {:unrepresentable_scalar, ?A}}
    assert @property.encode_utf8_to_token("AB") == {:error, {:invalid_scalar_count, 2}}

    assert @property.encode_utf8_to_token(<<0xFF>>) ==
             {:error, {:invalid_utf8, :invalid_sequence, 0, <<0xFF>>}}

    for malformed <- [<<?A, 0xFF, ?B>>, <<0xED, 0xA0, 0x80>>, <<?A, 0xE4, 0xB8>>] do
      expected =
        case Iconvex.UnicodeCodec.decode(%{id: :utf8}, malformed) do
          {:error, kind, offset, sequence} ->
            {:error, {:invalid_utf8, kind, offset, sequence}}
        end

      assert @property.encode_utf8_to_token(malformed) == expected
    end
  end

  test "all 7,236 mappings decode, encode, and round-trip exactly" do
    for {coordinate, scalar} <- source_mappings() do
      encoded = gl_bytes(coordinate)
      assert @codec.decode(encoded) == {:ok, [scalar]}
      assert @codec.decode_to_utf8(encoded) == {:ok, <<scalar::utf8>>}
      assert @codec.encode([scalar]) == {:ok, encoded}
      assert @codec.encode_from_utf8(<<scalar::utf8>>) == {:ok, encoded}
    end
  end

  @tag timeout: 240_000
  test "exhausts all 65,536 two-byte words" do
    expected =
      Map.new(source_mappings(), fn {coordinate, scalar} -> {gl_bytes(coordinate), scalar} end)

    for word <- 0..0xFFFF do
      encoded = <<word::16>>

      case Map.fetch(expected, encoded) do
        {:ok, scalar} -> assert @codec.decode(encoded) == {:ok, [scalar]}
        :error -> assert match?({:error, :invalid_sequence, 0, ^encoded}, @codec.decode(encoded))
      end
    end
  end

  test "classifies every one-byte input and both Unicode 17 holes exactly" do
    for byte <- 0..255 do
      result = @codec.decode(<<byte>>)

      if byte in 0x30..0x7C,
        do: assert(result == {:error, :incomplete_sequence, 0, <<byte>>}),
        else: assert(result == {:error, :invalid_sequence, 0, <<byte>>})
    end

    assert @codec.decode(gl_bytes(1893)) ==
             {:error, :invalid_sequence, 0, gl_bytes(1893)}

    assert @codec.decode(gl_bytes(9294)) ==
             {:error, :invalid_sequence, 0, gl_bytes(9294)}

    assert source_mappings()[1665] == 0x50B1
    assert source_mappings()[1666] == 0x4EF1
    assert source_mappings()[1683] == 0x511C
    assert source_mappings()[2105] == 0x22341
    assert source_mappings()[4923] == 0x225D6
  end

  test "fixed-pair recovery consumes one pair and public policies preserve framing" do
    first = gl_bytes(1601)
    second = gl_bytes(1602)
    hole = gl_bytes(1893)
    input = first <> hole <> second
    expected = <<source_mappings()[1601]::utf8, source_mappings()[1602]::utf8>>

    assert @codec.decode_error_consumption(:invalid_sequence, hole) == 2
    assert @codec.decode_error_consumption(:incomplete_sequence, binary_part(hole, 0, 1)) == 1

    assert @codec.decode_discard(input) ==
             {:ok, [source_mappings()[1601], source_mappings()[1602]]}

    assert Iconvex.convert(input, @codec, "UTF-8", invalid: :discard) == {:ok, expected}

    assert Iconvex.convert(input, @codec, "UTF-8", byte_substitute: "<%02x>") ==
             {:ok,
              <<source_mappings()[1601]::utf8>> <>
                "<32><7d>" <> <<source_mappings()[1602]::utf8>>}

    assert @codec.encode_discard([source_mappings()[1601], ?A, source_mappings()[1602]]) ==
             {:ok, first <> second}

    assert @codec.encode_substitute([source_mappings()[1601], ?A], fn _ ->
             [source_mappings()[1602]]
           end) == {:ok, first <> second}
  end

  test "streaming buffers at most one physical byte and matches one-shot at every split" do
    mappings = Enum.sort(source_mappings())

    encoded =
      mappings
      |> Enum.map(fn {coordinate, _scalar} -> gl_bytes(coordinate) end)
      |> IO.iodata_to_binary()

    scalars = Enum.map(mappings, &elem(&1, 1))

    for split <- 0..byte_size(encoded) do
      {left, right} = :erlang.split_binary(encoded, split)
      {:ok, left_scalars, pending} = @codec.decode_chunk(left, false)
      assert byte_size(pending) in 0..1
      {:ok, right_scalars, <<>>} = @codec.decode_chunk(pending <> right, true)
      assert left_scalars ++ right_scalars == scalars
    end

    assert @codec.decode_chunk(<<0x30>>, false) == {:ok, [], <<0x30>>}
    assert @codec.decode_chunk(<<0x2F>>, false) == {:ok, [], <<0x2F>>}
    assert @codec.decode_chunk(<<0x2F>>, true) == {:error, :invalid_sequence, 0, <<0x2F>>}
    assert @codec.decode_chunk(<<0x30>>, true) == {:error, :incomplete_sequence, 0, <<0x30>>}
    assert @codec.encode_chunk(scalars, false, :error) == {:ok, encoded, []}
  end

  @tag timeout: 240_000
  test "classifies every Unicode scalar under discard policy" do
    all_scalars =
      0..0x10FFFF
      |> Stream.reject(&(&1 in 0xD800..0xDFFF))
      |> Stream.chunk_every(4_096)
      |> Enum.map(&List.to_string/1)
      |> IO.iodata_to_binary()

    expected =
      source_mappings()
      |> Enum.map(fn {coordinate, scalar} -> {scalar, gl_bytes(coordinate)} end)
      |> Enum.sort()
      |> Enum.map(&elem(&1, 1))
      |> IO.iodata_to_binary()

    assert Iconvex.convert(
             all_scalars,
             "UTF-8",
             @codec,
             unrepresentable: :discard
           ) == {:ok, expected}
  end

  test "direct UTF-8 path reports the first source or destination error exactly" do
    scalar = source_mappings()[1601]

    assert @codec.encode_from_utf8(<<scalar::utf8, ?A, 0xFF>>) ==
             {:error, :unrepresentable_character, ?A}

    assert @codec.encode_from_utf8(<<scalar::utf8, 0xFF, ?A>>) ==
             {:decode_error, :invalid_sequence, byte_size(<<scalar::utf8>>), <<0xFF, ?A>>}

    assert @codec.encode_from_utf8(<<scalar::utf8, 0xE2, 0x82>>) ==
             {:decode_error, :incomplete_sequence, byte_size(<<scalar::utf8>>), <<0xE2, 0x82>>}
  end

  defp source_mappings do
    @unihan
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.reduce(%{}, fn line, mappings ->
      case Regex.run(~r/^U\+([0-9A-F]{4,6})\tkGB3\t([0-9]{4})$/, line) do
        [_, scalar, coordinate] ->
          Map.put(mappings, String.to_integer(coordinate), String.to_integer(scalar, 16))

        _ ->
          mappings
      end
    end)
  end

  defp packaged_mappings do
    ["row_cell_decimal,unicode_scalar" | rows] =
      @mapping |> File.read!() |> String.split("\n", trim: true)

    Map.new(rows, fn row ->
      [coordinate, "U+" <> scalar] = String.split(row, ",")
      {String.to_integer(coordinate), String.to_integer(scalar, 16)}
    end)
  end

  defp gl_bytes(coordinate) do
    row = div(coordinate, 100)
    cell = rem(coordinate, 100)
    <<row + 0x20, cell + 0x20>>
  end

  defp swap_rows(rows, left, right) do
    left_row = Enum.at(rows, left)
    right_row = Enum.at(rows, right)

    rows
    |> List.replace_at(left, right_row)
    |> List.replace_at(right, left_row)
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

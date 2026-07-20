defmodule Iconvex.Specs.UNIVACFieldataTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.{
    FieldataUNIVAC1100,
    FieldataUNIVAC4009Input,
    FieldataUNIVAC4009LosslessVPUA,
    FieldataUNIVAC4009Output,
    FieldataUNIVAC4009RawVPUA,
    Packed
  }

  @generic_source_dir Path.expand("../priv/sources/univac-1100-fieldata", __DIR__)
  @generic_table Path.join(@generic_source_dir, "table_6_1.csv")
  @generic_metadata Path.join(@generic_source_dir, "SOURCE_METADATA.md")
  @generic_table_sha256 "ba38cd68725d7df26c12771e79816e77850e4c796a4c63904feadb61d03e04eb"
  @generic_pdf_sha256 "de2f25c0ebff74ee75c6fba8a4125b733800200525b8df84a9e40c667400f6ab"

  @console_source_dir Path.expand("../priv/sources/univac-4009-fieldata", __DIR__)
  @console_table Path.join(@console_source_dir, "table_3_1.csv")
  @console_metadata Path.join(@console_source_dir, "SOURCE_METADATA.md")
  @console_table_sha256 "fa0f6937c4bde63821373f6af6c08d256beeb31a34a717c1a8001828ad32d3d6"
  @console_pdf_sha256 "469bcb196f0bc76b2bdbce3821a34fcd8e697bf20bb86a088746cd57ad673140"

  @console_profiles [
    {FieldataUNIVAC4009Input, :input_unicode},
    {FieldataUNIVAC4009Output, :output_unicode},
    {FieldataUNIVAC4009LosslessVPUA, :lossless_vpua},
    {FieldataUNIVAC4009RawVPUA, :raw_vpua}
  ]

  @profiles [{FieldataUNIVAC1100, :generic} | @console_profiles]

  test "RED: pins both primary manuals and complete independent mapping vectors" do
    assert sha256(File.read!(@generic_table)) == @generic_table_sha256
    assert sha256(File.read!(@console_table)) == @console_table_sha256

    generic_metadata = File.read!(@generic_metadata)
    console_metadata = File.read!(@console_metadata)
    assert generic_metadata =~ @generic_pdf_sha256
    assert generic_metadata =~ "PDF page 113 / printed page 6-1"
    assert generic_metadata =~ "Copyright 1971, 1974 - SPERRY RAND CORPORATION"
    assert console_metadata =~ @console_pdf_sha256
    assert console_metadata =~ "PDF page 19 / printed page 3-4"
    assert console_metadata =~ "Copyright 1968, 1974 - SPERRY RAND CORPORATION"

    assert FieldataUNIVAC1100.source_sha256() == @generic_pdf_sha256
    assert FieldataUNIVAC1100.source_pages() == [113]
    assert FieldataUNIVAC1100.printed_source_pages() == ["6-1"]

    for {codec, _column} <- @console_profiles do
      assert codec.source_sha256() == @console_pdf_sha256
      assert codec.source_pages() == [19]
      assert codec.printed_source_pages() == ["3-4"]
      assert codec.unit_bits() == 6
    end
  end

  test "implements all 64 standard UNIVAC 1100 FIELDATA assignments" do
    rows = generic_rows()
    units = rows |> Enum.map(& &1.unit) |> :binary.list_to_bin()
    codepoints = Enum.flat_map(rows, & &1.mapping)

    assert length(rows) == 64
    assert Enum.map(rows, & &1.unit) == Enum.to_list(0..63)
    assert FieldataUNIVAC1100.decode(units) == {:ok, codepoints}
    assert FieldataUNIVAC1100.encode(codepoints) == {:ok, units}
    assert FieldataUNIVAC1100.decode_to_utf8(units) == {:ok, List.to_string(codepoints)}
    assert FieldataUNIVAC1100.encode_from_utf8(List.to_string(codepoints)) == {:ok, units}

    for %{unit: unit, mapping: mapping} <- rows do
      assert FieldataUNIVAC1100.decode(<<unit>>) == {:ok, mapping}
      assert FieldataUNIVAC1100.encode(mapping) == {:ok, <<unit>>}
    end

    assert FieldataUNIVAC1100.encode(~c"abc") ==
             {:error, :unrepresentable_character, ?a}
  end

  test "implements every directional, lossless, and raw 4009 cell" do
    rows = console_rows()
    assert length(rows) == 64
    assert Enum.map(rows, & &1.unit) == Enum.to_list(0..63)

    for {codec, column} <- @console_profiles do
      accepted = Enum.reject(rows, &(Map.fetch!(&1, column) == :unavailable))
      units = accepted |> Enum.map(& &1.unit) |> :binary.list_to_bin()

      expected =
        accepted
        |> Enum.flat_map(fn row ->
          case Map.fetch!(row, column) do
            :ignored -> []
            mapping -> mapping
          end
        end)

      assert codec.decode(units) == {:ok, expected}
      assert codec.decode_to_utf8(units) == {:ok, List.to_string(expected)}

      for row <- rows do
        case Map.fetch!(row, column) do
          :unavailable ->
            assert codec.decode(<<row.unit>>) ==
                     {:error, :invalid_sequence, 0, <<row.unit>>}

          :ignored ->
            assert codec.decode(<<row.unit>>) == {:ok, []}
            assert codec.decode_to_utf8(<<row.unit>>) == {:ok, ""}

          mapping ->
            text = List.to_string(mapping)
            assert codec.decode(<<row.unit>>) == {:ok, mapping}
            assert codec.encode(mapping) == {:ok, <<row.unit>>}
            assert codec.decode_to_utf8(<<row.unit>>) == {:ok, text}
            assert codec.encode_from_utf8(text) == {:ok, <<row.unit>>}
        end
      end
    end
  end

  test "the generic and 4009 semantic tables differ at exactly seven source cells" do
    generic = Map.new(generic_rows(), &{&1.unit, &1.mapping})
    lossless = Map.new(console_rows(), &{&1.unit, &1.lossless_vpua})

    differing =
      0..63
      |> Enum.filter(&(generic[&1] != lossless[&1]))
      |> Enum.map(&Integer.to_string(&1, 8))

    assert differing == ["0", "3", "4", "46", "52", "57", "77"]
    assert generic[0o76] == [0x2311]
    assert lossless[0o76] == [0x2311]
  end

  test "device actions and VPUA identities remain explicit rather than becoming NUL" do
    assert FieldataUNIVAC4009Input.decode(<<0o00, 0o03>>) == {:ok, [0xF4000, 0x0085]}

    assert FieldataUNIVAC4009Input.decode(<<0o04>>) ==
             {:error, :invalid_sequence, 0, <<0o04>>}

    assert FieldataUNIVAC4009Output.decode(<<0o00, 0o03, 0o04>>) == {:ok, [0x0085]}

    assert FieldataUNIVAC4009LosslessVPUA.decode(<<0o00, 0o03, 0o04, 0o57>>) ==
             {:ok, [0xF4000, 0x0085, 0xF4004, 0xF402F]}

    assert FieldataUNIVAC4009RawVPUA.decode(0..63 |> Enum.to_list() |> :binary.list_to_bin()) ==
             {:ok, Enum.to_list(0xF4000..0xF403F)}

    for codec <- [FieldataUNIVAC4009Input, FieldataUNIVAC4009Output] do
      assert codec.decode(<<0o57>>) == {:ok, [0xF402F]}
      assert codec.decode(<<0o76>>) == {:ok, [0x2311]}
      assert codec.decode(<<0o77>>) == {:ok, [0x2191]}
      assert codec.encode([0x000A]) == {:error, :unrepresentable_character, 0x000A}
      assert codec.encode([0x0085]) == {:ok, <<0o03>>}
    end
  end

  test "strict errors, discard, substitution, and direct UTF-8 offsets are exhaustive" do
    for {codec, _column} <- @profiles, unit <- 64..255 do
      assert codec.decode(<<0o06, unit>>) ==
               {:error, :invalid_sequence, 1, <<unit>>}
    end

    for {codec, column} <- @profiles do
      first = mapping_for(column, 0o06)
      second = mapping_for(column, 0o07)
      replacement = mapping_for(column, 0o46)
      first_text = List.to_string(first)
      second_text = List.to_string(second)

      assert codec.decode_discard(<<0o06, 0xFF, 0o07>>) == {:ok, first ++ second}
      assert codec.encode_discard(first ++ [0x2603] ++ second) == {:ok, <<0o06, 0o07>>}

      assert codec.encode_substitute(first ++ [0x2603] ++ second, fn 0x2603 -> replacement end) ==
               {:ok, <<0o06, 0o46, 0o07>>}

      assert codec.encode_from_utf8(first_text <> <<0xFF>>) ==
               {:decode_error, :invalid_sequence, byte_size(first_text), <<0xFF>>}

      assert Iconvex.convert(<<0o06, 0xFF, 0o07>>, codec.canonical_name(), "UTF-8",
               invalid: :discard
             ) == {:ok, first_text <> second_text}

      assert Iconvex.convert(first_text <> "☃" <> second_text, "UTF-8", codec.canonical_name(),
               unrepresentable: :discard
             ) == {:ok, <<0o06, 0o07>>}
    end

    assert FieldataUNIVAC4009Input.decode_discard(<<0o06, 0o04, 0o07>>) == {:ok, ~c"AB"}
  end

  test "registers only source-qualified names and never claims bare FIELDATA" do
    assert Iconvex.canonical_name("UNIVAC-1100-FIELDATA") ==
             {:ok, "FIELDATA-UNIVAC-1100"}

    assert Iconvex.canonical_name("UNISYS-FIELDATA") == {:ok, "FIELDATA-UNIVAC-1100"}

    for {codec, _column} <- @console_profiles do
      canonical = codec.canonical_name()
      assert Iconvex.canonical_name(canonical) == {:ok, canonical}
      assert Packed.profile(canonical).codec == codec
      assert Packed.profile(canonical).unit_bits == 6
    end

    assert Iconvex.canonical_name("FIELDATA") == :error
    assert Iconvex.canonical_name("UNIVAC-1108-FIELDATA-4009") == :error
  end

  test "packed MSB follows two 36-bit words and LSB is explicit library interchange" do
    text = generic_rows() |> Enum.take(12) |> Enum.flat_map(& &1.mapping) |> List.to_string()
    historical = <<0x00, 0x10, 0x83, 0x10, 0x51, 0x87, 0x20, 0x92, 0x8B>>

    assert {:ok, ^historical} =
             Packed.encode_from_utf8(text, "FIELDATA-UNIVAC-1100", :msb)

    assert Packed.decode_to_utf8(historical, "FIELDATA-UNIVAC-1100", :msb) ==
             {:ok, text}

    assert {:ok,
            %Iconvex.Packed.LSB{
              data: <<0x40, 0x20, 0x0C, 0x44, 0x61, 0x1C, 0x48, 0xA2, 0x2C>>,
              bit_size: 72,
              unit_bits: 6
            } = lsb} = Packed.encode_from_utf8(text, "FIELDATA-UNIVAC-1100", :lsb)

    assert Packed.decode_to_utf8(lsb, "FIELDATA-UNIVAC-1100", :lsb) == {:ok, text}

    for {codec, column} <- @console_profiles do
      row = Enum.find(console_rows(), &is_list(Map.fetch!(&1, column)))
      sample = row |> Map.fetch!(column) |> List.to_string()
      canonical = codec.canonical_name()

      for order <- [:msb, :lsb] do
        assert {:ok, packed} = Packed.encode_from_utf8(sample, canonical, order)
        assert Packed.decode_to_utf8(packed, canonical, order) == {:ok, sample}
      end
    end
  end

  test "direct paths cross allocation boundaries and native loops remain linear" do
    for {codec, _column} <- @profiles do
      {:ok, one} = codec.decode(<<0o06>>)
      text = one |> List.to_string() |> :binary.copy(8_193)
      units = :binary.copy(<<0o06>>, 8_193)
      assert codec.decode_to_utf8(units) == {:ok, text}
      assert codec.encode_from_utf8(text) == {:ok, units}
    end

    short = :binary.copy(<<0o06>>, 20_000)
    long = :binary.copy(<<0o06>>, 40_000)
    assert {:ok, _} = FieldataUNIVAC1100.decode_to_utf8(short)
    short_reductions = reductions(fn -> FieldataUNIVAC1100.decode_to_utf8(short) end)
    long_reductions = reductions(fn -> FieldataUNIVAC1100.decode_to_utf8(long) end)
    ratio = long_reductions / short_reductions
    assert ratio > 1.7 and ratio < 2.3
  end

  test "stateless callbacks stream every profile in both directions with native policies" do
    for {codec, column} <- @profiles do
      first = mapping_for(column, 0o06)
      second = mapping_for(column, 0o07)
      replacement = mapping_for(column, 0o46)
      codepoints = first ++ second
      text = List.to_string(codepoints)

      assert codec.decode_chunk(<<0o06, 0o07>>, false) == {:ok, codepoints, <<>>}

      assert codec.decode_chunk(<<0o06, 0xFF>>, false) ==
               {:error, :invalid_sequence, 1, <<0xFF>>}

      assert codec.encode_chunk(codepoints, false, :error) == {:ok, <<0o06, 0o07>>, []}

      assert codec.encode_chunk(first ++ [0x2603] ++ second, false, :discard) ==
               {:ok, <<0o06, 0o07>>, []}

      assert codec.encode_chunk(
               first ++ [0x2603] ++ second,
               false,
               {:replace, fn 0x2603 -> replacement end}
             ) == {:ok, <<0o06, 0o46, 0o07>>, []}

      assert {:ok, source_stream} =
               Iconvex.stream([<<0o06>>, <<0o07>>], codec.canonical_name(), "UTF-8")

      assert source_stream |> Enum.to_list() |> IO.iodata_to_binary() == text

      assert {:ok, discard_source_stream} =
               Iconvex.stream([<<0o06, 0xFF>>, <<0o07>>], codec.canonical_name(), "UTF-8",
                 invalid: :discard
               )

      assert discard_source_stream |> Enum.to_list() |> IO.iodata_to_binary() == text

      for split <- 0..byte_size(text) do
        <<left::binary-size(split), right::binary>> = text

        assert {:ok, target_stream} =
                 Iconvex.stream([left, right], "UTF-8", codec.canonical_name())

        assert target_stream |> Enum.to_list() |> IO.iodata_to_binary() == <<0o06, 0o07>>
      end

      assert {:ok, discard_target_stream} =
               Iconvex.stream([text <> "☃"], "UTF-8", codec.canonical_name(),
                 unrepresentable: :discard
               )

      assert discard_target_stream |> Enum.to_list() |> IO.iodata_to_binary() ==
               <<0o06, 0o07>>
    end
  end

  test "generated byte and packed inventories publish every FIELDATA profile" do
    byte_inventory = File.read!("SUPPORTED_CODEC_INVENTORY.csv")
    packed_inventory = File.read!("SUPPORTED_PACKED_CODEC_INVENTORY.csv")

    for {codec, _column} <- @profiles do
      canonical = codec.canonical_name()
      assert byte_inventory =~ "#{canonical},"
      assert packed_inventory =~ "#{canonical},"
      assert packed_inventory =~ "#{canonical}-PACKED-MSB|#{canonical}-PACKED-LSB"
    end
  end

  defp generic_rows do
    read_csv(@generic_table)
    |> Enum.map(fn row ->
      %{unit: String.to_integer(row["octal"], 8), mapping: parse_mapping(row["unicode"])}
    end)
  end

  defp console_rows do
    read_csv(@console_table)
    |> Enum.map(fn row ->
      %{
        unit: String.to_integer(row["octal"], 8),
        input_unicode: parse_mapping(row["input_unicode"]),
        output_unicode: parse_mapping(row["output_unicode"]),
        lossless_vpua: parse_mapping(row["lossless_vpua"]),
        raw_vpua: parse_mapping(row["raw_vpua"])
      }
    end)
  end

  defp mapping_for(:generic, unit) do
    generic_rows() |> Enum.find(&(&1.unit == unit)) |> Map.fetch!(:mapping)
  end

  defp mapping_for(column, unit) do
    console_rows() |> Enum.find(&(&1.unit == unit)) |> Map.fetch!(column)
  end

  defp read_csv(path) do
    [header | rows] = path |> File.read!() |> String.split("\n", trim: true)
    fields = String.split(header, ",")

    Enum.map(rows, fn row ->
      fields |> Enum.zip(String.split(row, ",")) |> Map.new()
    end)
  end

  defp parse_mapping("UNAVAILABLE"), do: :unavailable
  defp parse_mapping("IGNORED"), do: :ignored

  defp parse_mapping(value) do
    Regex.scan(~r/U\+([0-9A-F]+)/, value, capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&String.to_integer(&1, 16))
  end

  defp reductions(function) do
    {:reductions, before} = Process.info(self(), :reductions)
    assert {:ok, _} = function.()
    {:reductions, after_count} = Process.info(self(), :reductions)
    after_count - before
  end

  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end

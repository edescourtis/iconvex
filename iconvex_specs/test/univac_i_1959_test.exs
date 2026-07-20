defmodule Iconvex.Specs.UNIVACI1959Test do
  use ExUnit.Case, async: false

  import Bitwise

  alias Iconvex.Specs.Packed

  @semantic Module.concat([Iconvex, Specs, UNIVACIExpanded1959])
  @lossless Module.concat([Iconvex, Specs, UNIVACIExpanded1959LosslessVPUA])
  @raw Module.concat([Iconvex, Specs, UNIVACIExpanded1959RawVPUA])
  @checked Module.concat([Iconvex, Specs, UNIVACIExpanded1959OddParity7Bit])
  @tape Module.concat([Iconvex, Specs, UNIVACIExpanded1959PaperTapeRow])
  @codecs [@semantic, @lossless, @raw, @checked, @tape]

  @source_dir Path.expand("../priv/sources/univac-i-1959", __DIR__)
  @table Path.join(@source_dir, "table_8_2.csv")
  @metadata Path.join(@source_dir, "SOURCE_METADATA.md")
  @unicode_corpus Path.expand("fixtures/all-unicode-scalars.utf32be", __DIR__)
  @table_sha256 "61a1e290652c0a0dd658301cef5d96caa1ab3a6e7520752eeca4d9902fb5622a"
  @programming_sha256 "2b4c3c18112a5a0820cf886e417cb605408b635fdc6bdaf658638c7d738c3efc"
  @reference_card_sha256 "87a6858433286efffcbf4c7bcdb96460d62ad656d06d7125af924fed4542d97f"

  test "RED: source-bound profiles and transports are registered before implementation" do
    assert sha256(@table) == @table_sha256

    metadata = File.read!(@metadata)
    assert metadata =~ @programming_sha256
    assert metadata =~ @reference_card_sha256
    assert metadata =~ "129 / printed page 124"
    assert metadata =~ "LGPL-2.1-or-later"
    assert Path.wildcard(Path.join(@source_dir, "*.pdf")) == []

    for codec <- @codecs do
      assert Code.ensure_loaded?(codec)
      assert apply(codec, :source_sha256, []) == @programming_sha256
      assert apply(codec, :unit_bits, []) in [6, 7, 8]
      assert apply(codec, :canonical_name, []) in Iconvex.Specs.encodings()
    end

    assert length(Iconvex.Specs.codecs()) == 1_841
    assert length(Iconvex.Specs.encodings()) == 1_841
  end

  test "the independent oracle contains exactly 63 assignments and one unused code" do
    rows = source_rows()

    assert length(rows) == 64
    assert Enum.map(rows, & &1.unit) == Enum.to_list(0..63)
    assert Enum.count(rows, &(&1.status == :assigned)) == 63
    assert List.last(rows).status == :unused

    for row <- rows do
      assert row.unit == (row.zone <<< 4 ||| row.xs3)
      assert row.raw == 0xF4080 + row.unit
    end

    assert row!(0x00).semantic == :ignored
    assert row!(0x01).semantic == 0x20
    assert row!(0x10).semantic == 0x0D
    assert row!(0x20).semantic == 0x09
    assert row!(0x1E).semantic == 0x00A2
    assert row!(0x30).semantic == 0x03A3
    assert row!(0x31).semantic == 0x03B2
    assert row!(0x3F).semantic == :unavailable
  end

  test "semantic, lossless, and forensic tables exhaust every six-bit unit" do
    rows = source_rows()

    semantic_units = :binary.list_to_bin(Enum.to_list(0..62))
    semantic_codepoints = rows |> Enum.take(63) |> mapped(:semantic)
    assert call(@semantic, :decode, [semantic_units]) == {:ok, semantic_codepoints}

    assert call(@semantic, :encode, [semantic_codepoints]) ==
             {:ok, :binary.part(semantic_units, 1, 62)}

    lossless_codepoints = rows |> Enum.take(63) |> mapped(:lossless)
    assert call(@lossless, :decode, [semantic_units]) == {:ok, lossless_codepoints}
    assert call(@lossless, :encode, [lossless_codepoints]) == {:ok, semantic_units}

    all_units = :binary.list_to_bin(Enum.to_list(0..63))
    raw_codepoints = mapped(rows, :raw)
    assert call(@raw, :decode, [all_units]) == {:ok, raw_codepoints}
    assert call(@raw, :encode, [raw_codepoints]) == {:ok, all_units}

    for unit <- 64..255 do
      for codec <- [@semantic, @lossless, @raw] do
        assert call(codec, :decode, [<<0x14, unit>>]) ==
                 {:error, :invalid_sequence, 1, <<unit>>}
      end
    end

    for codec <- [@semantic, @lossless] do
      assert call(codec, :decode, [<<0x3F>>]) ==
               {:error, :invalid_sequence, 0, <<0x3F>>}
    end
  end

  test "all 1,112,064 Unicode scalars expose exactly the documented encoder keys" do
    rows = source_rows()

    expected = %{
      @semantic => rows |> mapped(:semantic) |> Enum.sort(),
      @lossless => rows |> mapped(:lossless) |> Enum.sort(),
      @raw => rows |> mapped(:raw) |> Enum.sort(),
      @checked => rows |> mapped(:semantic) |> Enum.sort(),
      @tape => rows |> mapped(:semantic) |> Enum.sort()
    }

    corpus = File.read!(@unicode_corpus)
    assert byte_size(corpus) == 1_112_064 * 4

    for codec <- @codecs do
      actual =
        for <<codepoint::unsigned-big-32 <- corpus>>,
            match?({:ok, _unit}, call(codec, :encode, [[codepoint]])),
            do: codepoint

      assert actual == Map.fetch!(expected, codec)
    end
  end

  test "the checked septet profile validates all 128 patterns with odd parity" do
    valid =
      for septet <- 0..127,
          odd_parity?(septet),
          (septet &&& 0x3F) != 0x3F,
          do: septet

    assert length(valid) == 63

    for septet <- 0..127 do
      basic = septet &&& 0x3F

      if septet in valid do
        expected = if basic == 0, do: [], else: [row!(basic).semantic]
        assert call(@checked, :decode, [<<septet>>]) == {:ok, expected}
      else
        assert call(@checked, :decode, [<<septet>>]) ==
                 {:error, :invalid_sequence, 0, <<septet>>}
      end
    end

    assert call(@checked, :encode, [~c"A1"]) == {:ok, <<0x54, 0x04>>}
    assert call(@checked, :decode, [<<0x54, 0x04>>]) == {:ok, ~c"A1"}

    for byte <- 128..255 do
      assert call(@checked, :decode, [<<0x54, byte>>]) ==
               {:error, :invalid_sequence, 1, <<byte>>}
    end
  end

  test "the physical tape-row profile enforces sprocket track and parity" do
    assert call(@tape, :encode, [~c"A1"]) == {:ok, <<0xAC, 0x0C>>}
    assert call(@tape, :decode, [<<0xAC, 0x0C>>]) == {:ok, ~c"A1"}

    valid =
      Enum.filter(0..255, fn row ->
        sprocket? = (row &&& 0x08) != 0
        septet = (row &&& 0xF0) >>> 1 ||| (row &&& 0x07)
        sprocket? and odd_parity?(septet) and (septet &&& 0x3F) != 0x3F
      end)

    assert length(valid) == 63

    for row <- 0..255 do
      result = call(@tape, :decode, [<<row>>])
      assert match?({:ok, _}, result) == row in valid
    end

    assert call(@tape, :decode, [<<0xA4>>]) ==
             {:error, :invalid_sequence, 0, <<0xA4>>}

    assert call(@tape, :decode, [<<0x2C>>]) ==
             {:error, :invalid_sequence, 0, <<0x2C>>}
  end

  test "all non-octet profiles publish exact MSB and LSB packed transports" do
    samples = [
      {@semantic, "UNIVAC-I-EXPANDED-1959", "A1Σβ¢"},
      {@lossless, "UNIVAC-I-EXPANDED-1959-LOSSLESS-VPUA", <<0xF4040::utf8, ?A::utf8>>},
      {@raw, "UNIVAC-I-EXPANDED-1959-RAW-VPUA", <<0xF4080::utf8, 0xF40BF::utf8>>},
      {@checked, "UNIVAC-I-EXPANDED-1959-ODD-PARITY-7BIT", "A1Σβ¢"}
    ]

    for {codec, canonical, text} <- samples do
      assert Packed.profile(codec).canonical == canonical

      for order <- [:msb, :lsb] do
        assert {:ok, packed} = Packed.encode_from_utf8(text, canonical, order)
        assert Packed.decode_to_utf8(packed, canonical, order) == {:ok, text}
      end

      assert Packed.profile("#{canonical}-PACKED-MSB").codec == codec
      assert Packed.profile("#{canonical}-PACKED-LSB").codec == codec
    end

    assert {:ok, <<0x14::6, 0x04::6>>} =
             Packed.encode_from_utf8("A1", "UNIVAC-I-EXPANDED-1959", :msb)

    assert {:ok, <<0x54::7, 0x04::7>>} =
             Packed.encode_from_utf8(
               "A1",
               "UNIVAC-I-EXPANDED-1959-ODD-PARITY-7BIT",
               :msb
             )

    assert Packed.decode_to_utf8(<<0x14::6, 0x04::6, 1::3>>, "UNIVAC-I-EXPANDED-1959", :msb) ==
             {:error, :incomplete_unit, 12, <<1::3>>}

    assert Packed.decode_to_utf8(<<0x14::6, 0x3F::6>>, "UNIVAC-I-EXPANDED-1959", :msb) ==
             {:error, :invalid_sequence, 6, <<0x3F::6>>}

    assert Packed.decode_to_utf8(
             <<0x54::7, 0x00::7>>,
             "UNIVAC-I-EXPANDED-1959-ODD-PARITY-7BIT",
             :msb
           ) == {:error, :invalid_sequence, 7, <<0x00::7>>}

    twelve = "ABCDEFGHIJKL"
    assert {:ok, basic_word} = Packed.encode_from_utf8(twelve, "UNIVAC-I-EXPANDED-1959", :msb)
    assert bit_size(basic_word) == 72
    assert byte_size(basic_word) == 9

    assert {:ok, checked_word} =
             Packed.encode_from_utf8(
               twelve,
               "UNIVAC-I-EXPANDED-1959-ODD-PARITY-7BIT",
               :msb
             )

    assert bit_size(checked_word) == 84

    assert {:ok, two_checked_words} =
             Packed.encode_from_utf8(
               twelve <> twelve,
               "UNIVAC-I-EXPANDED-1959-ODD-PARITY-7BIT",
               :msb
             )

    assert bit_size(two_checked_words) == 168
    assert byte_size(two_checked_words) == 21
  end

  test "strict, discard, substitution, UTF-8, and first-error behavior is exact" do
    for codec <- @codecs do
      sample = sample_text(codec)
      sample_codepoints = String.to_charlist(sample)
      replacement = replacement_codepoints(codec)
      valid_a = call(codec, :encode, [sample_codepoints]) |> elem(1)
      invalid = invalid_unit(codec)

      assert call(codec, :decode_discard, [valid_a <> invalid <> valid_a]) ==
               {:ok, sample_codepoints ++ sample_codepoints}

      assert call(codec, :encode_discard, [sample_codepoints ++ [0x2603] ++ sample_codepoints]) ==
               {:ok, valid_a <> valid_a}

      assert call(codec, :encode_substitute, [
               sample_codepoints ++ [0x2603] ++ sample_codepoints,
               fn 0x2603 -> replacement end
             ]) ==
               {:ok, valid_a <> (call(codec, :encode, [replacement]) |> elem(1)) <> valid_a}

      assert call(codec, :decode_to_utf8, [valid_a]) == {:ok, sample}
      assert call(codec, :encode_from_utf8, [sample]) == {:ok, valid_a}

      assert call(codec, :encode_from_utf8, [sample <> <<0xFF>>]) ==
               {:decode_error, :invalid_sequence, byte_size(sample), <<0xFF>>}

      assert call(codec, :encode_from_utf8, [<<0x2603::utf8, 0xFF>>]) ==
               {:error, :unrepresentable_character, 0x2603}
    end
  end

  test "stateless streaming is identical at every source and UTF-8 split" do
    for codec <- @codecs do
      canonical = call(codec, :canonical_name, [])
      text = stream_text(codec)
      {:ok, encoded} = call(codec, :encode_from_utf8, [text])

      for split <- 0..byte_size(encoded) do
        <<left::binary-size(split), right::binary>> = encoded
        assert {:ok, stream} = Iconvex.stream([left, right], canonical, "UTF-8")
        assert stream |> Enum.to_list() |> IO.iodata_to_binary() == text
      end

      for split <- 0..byte_size(text) do
        <<left::binary-size(split), right::binary>> = text
        assert {:ok, stream} = Iconvex.stream([left, right], "UTF-8", canonical)
        assert stream |> Enum.to_list() |> IO.iodata_to_binary() == encoded
      end
    end
  end

  test "native direct loops stay linear across allocation boundaries" do
    for codec <- @codecs do
      sample = sample_text(codec)
      {:ok, encoded} = call(codec, :encode_from_utf8, [sample])
      input = :binary.copy(encoded, 8_193)
      text = :binary.copy(sample, 8_193)
      assert call(codec, :decode_to_utf8, [input]) == {:ok, text}
      assert call(codec, :encode_from_utf8, [text]) == {:ok, input}
    end

    short = :binary.copy(<<0x14>>, 20_000)
    long = :binary.copy(<<0x14>>, 40_000)
    short_reductions = reductions(fn -> call(@semantic, :decode_to_utf8, [short]) end)
    long_reductions = reductions(fn -> call(@semantic, :decode_to_utf8, [long]) end)
    ratio = long_reductions / short_reductions
    assert ratio > 1.7 and ratio < 2.3
  end

  test "bounded UTF-8 chunks carry split scalars and retain absolute error offsets" do
    raw_scalar = <<0xF4094::utf8>>
    raw_text = :binary.copy(raw_scalar, 16_385)
    raw_units = :binary.copy(<<0x14>>, 16_385)

    assert call(@raw, :encode_from_utf8, [raw_text]) == {:ok, raw_units}

    assert call(@raw, :encode_from_utf8, [:binary.copy(raw_scalar, 16_384) <> <<0xFF>>]) ==
             {:decode_error, :invalid_sequence, 65_536, <<0xFF>>}

    ascii_prefix = :binary.copy("A", 65_536)

    assert call(@semantic, :encode_from_utf8, [ascii_prefix <> <<0x2603::utf8, 0xFF>>]) ==
             {:error, :unrepresentable_character, 0x2603}
  end

  test "catalog-facing aliases are source-qualified and ambiguous family names stay free" do
    assert Iconvex.canonical_name("UNIVAC-I-63") ==
             {:ok, "UNIVAC-I-EXPANDED-1959"}

    assert Iconvex.canonical_name("UNIVAC-I-EXPANDED-1959-CHECKED") ==
             {:ok, "UNIVAC-I-EXPANDED-1959-ODD-PARITY-7BIT"}

    assert Iconvex.canonical_name("UNIVAC-I") == :error
    assert Iconvex.canonical_name("UNIVAC-I-SIX-BIT-CODE") == :error
    assert Iconvex.canonical_name("FIELDATA") == :error
  end

  test "generated byte and packed inventories contain the complete family" do
    byte_inventory = File.read!("SUPPORTED_CODEC_INVENTORY.csv")
    packed_inventory = File.read!("SUPPORTED_PACKED_CODEC_INVENTORY.csv")

    for codec <- @codecs do
      canonical = call(codec, :canonical_name, [])
      assert byte_inventory =~ "#{canonical},"
    end

    for codec <- [@semantic, @lossless, @raw, @checked] do
      canonical = call(codec, :canonical_name, [])
      assert packed_inventory =~ "#{canonical},"
      assert packed_inventory =~ "#{canonical}-PACKED-MSB|#{canonical}-PACKED-LSB"
    end
  end

  test "the release selects only the independent transcription and metadata" do
    files = Mix.Project.config() |> Keyword.fetch!(:package) |> Keyword.fetch!(:files)

    assert "priv/sources/univac-i-1959/*.csv" in files
    assert "priv/sources/univac-i-1959/SOURCE_METADATA.md" in files
    refute Enum.any?(files, &String.contains?(&1, "univac-i-1959/*.pdf"))
  end

  defp call(module, function, arguments), do: apply(module, function, arguments)

  defp invalid_unit(@semantic), do: <<0x3F>>
  defp invalid_unit(@lossless), do: <<0x3F>>
  defp invalid_unit(@raw), do: <<0x40>>
  defp invalid_unit(@checked), do: <<0x00>>
  defp invalid_unit(@tape), do: <<0x00>>

  defp sample_text(@raw), do: <<0xF4094::utf8>>
  defp sample_text(_codec), do: "A"

  defp replacement_codepoints(@raw), do: [0xF4084]
  defp replacement_codepoints(_codec), do: ~c"1"

  defp stream_text(@raw),
    do: List.to_string([0xF4094, 0xF40B0, 0xF40B1, 0xF409E, 0xF4084])

  defp stream_text(_codec), do: "AΣβ¢1"

  defp source_rows do
    [_header | rows] = @table |> File.read!() |> String.split("\n", trim: true)

    Enum.map(rows, fn row ->
      [hex, zone, xs3, _glyph, semantic, lossless, raw, status] = String.split(row, ",")

      %{
        unit: String.to_integer(hex, 16),
        zone: String.to_integer(zone, 2),
        xs3: String.to_integer(xs3, 2),
        semantic: parse_mapping(semantic),
        lossless: parse_mapping(lossless),
        raw: parse_mapping(raw),
        status: String.to_atom(status)
      }
    end)
  end

  defp row!(unit), do: Enum.find(source_rows(), &(&1.unit == unit))

  defp mapped(rows, column) do
    Enum.flat_map(rows, fn row ->
      case Map.fetch!(row, column) do
        codepoint when is_integer(codepoint) -> [codepoint]
        _action -> []
      end
    end)
  end

  defp parse_mapping("IGNORED"), do: :ignored
  defp parse_mapping("UNAVAILABLE"), do: :unavailable
  defp parse_mapping("U+" <> hex), do: String.to_integer(hex, 16)

  defp odd_parity?(value) do
    value
    |> Integer.digits(2)
    |> Enum.sum()
    |> rem(2)
    |> Kernel.==(1)
  end

  defp reductions(function) do
    {:reductions, before} = Process.info(self(), :reductions)
    assert {:ok, _} = function.()
    {:reductions, after_count} = Process.info(self(), :reductions)
    after_count - before
  end

  defp sha256(path) do
    path
    |> File.read!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end

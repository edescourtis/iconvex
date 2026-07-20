defmodule Iconvex.Specs.TI89AMS20Test do
  use ExUnit.Case, async: false

  @mapping_path Path.expand(
                  "../priv/sources/ti-89-92-plus-ams-2.0/mapping.csv",
                  __DIR__
                )
  @metadata_path Path.expand(
                   "../priv/sources/ti-89-92-plus-ams-2.0/SOURCE_METADATA.md",
                   __DIR__
                 )

  @mapping_sha256 "be205ae316b916d6f2b386fd85729f51cdcd6852c9db64f014d0187a6345fb44"
  @metadata_sha256 "8d446d83fd5cda065ac304f416f84ea2d8754cb7d567bf390a0f980924bbf491"
  @guide_sha256 "6e7266917fd2de05f7374ebe0de3ef898a06533e17fd9a5c6e4a3d3f237140a9"
  @corroborating_sha256 "95e086e54fa68df96b5a8249883a60797108dad2c32aa54b64fb84bf9150df1f"

  @profiles [
    %{
      key: :source_glyph,
      codec: Iconvex.Specs.TI89AMS20,
      canonical: "TI-89-92-PLUS-AMS-2.0",
      aliases: [
        "TI-89-AMS-2.0",
        "TI-92-PLUS-AMS-2.0",
        "TI89-AMS-2.0",
        "TI92PLUS-AMS-2.0"
      ]
    },
    %{
      key: :visible,
      codec: Iconvex.Specs.TI89AMS20Visible,
      canonical: "TI-89-92-PLUS-AMS-2.0-VISIBLE",
      aliases: ["TI-89-AMS-2.0-VISIBLE", "TI-92-PLUS-AMS-2.0-VISIBLE"]
    },
    %{
      key: :lossless_vpua,
      codec: Iconvex.Specs.TI89AMS20LosslessVPUA,
      canonical: "TI-89-92-PLUS-AMS-2.0-LOSSLESS-VPUA",
      aliases: [
        "TI-89-AMS-2.0-LOSSLESS-VPUA",
        "TI-92-PLUS-AMS-2.0-LOSSLESS-VPUA"
      ]
    },
    %{
      key: :raw_vpua,
      codec: Iconvex.Specs.TI89AMS20RawVPUA,
      canonical: "TI-89-92-PLUS-AMS-2.0-RAW-VPUA",
      aliases: ["TI-89-AMS-2.0-RAW-VPUA", "TI-92-PLUS-AMS-2.0-RAW-VPUA"]
    }
  ]

  test "pins the independently authored 256-row source asset and official evidence" do
    assert sha256(File.read!(@mapping_path)) == @mapping_sha256
    assert sha256(File.read!(@metadata_path)) == @metadata_sha256

    rows = mappings()
    assert length(rows) == 256
    assert Enum.map(rows, & &1.byte) == Enum.to_list(0x00..0xFF)

    for key <- [:source_glyph, :visible, :lossless_vpua, :raw_vpua] do
      outputs = Enum.map(rows, &Map.fetch!(&1, key))
      assert length(Enum.uniq(outputs)) == 256, Atom.to_string(key)

      assert Enum.all?(outputs, fn sequence ->
               Enum.all?(sequence, &valid_scalar?/1)
             end)
    end

    assert sequence_bytes(rows, :source_glyph) == [0x9A, 0x9B, 0xB4]
    assert sequence_bytes(rows, :visible) == [0x9A, 0x9B, 0xB4]
    assert sequence_bytes(rows, :lossless_vpua) == [0x9A, 0x9B, 0xB4]
    assert sequence_bytes(rows, :raw_vpua) == []

    assert vpua_bytes(rows, :lossless_vpua, 0xF8900..0xF89FF) ==
             [0x00, 0x95, 0x96, 0x98, 0x99, 0xB5, 0xBC]

    assert Enum.map(rows, & &1.raw_vpua) == Enum.map(0x00..0xFF, &[0xF8A00 + &1])

    metadata = File.read!(@metadata_path)
    assert metadata =~ @guide_sha256
    assert metadata =~ @corroborating_sha256
    assert metadata =~ "PDF physical page 572, printed page 555"
    assert metadata =~ "PDF physical page 436, printed page 419"
    assert metadata =~ "PDF physical page 926, printed page 924"
    assert metadata =~ "No libticonv table was copied or transformed"
    assert metadata =~ "Byte 0 is absent from the printed table"
    assert metadata =~ "canonical `00` -> U+0000 choice"
    assert metadata =~ "explicitly libticonv-corroborated inference"
  end

  test "exposes source hashes, exact pages, and URLs without packaging the PDFs" do
    for profile <- @profiles do
      codec = profile.codec
      assert codec.mapping_sha256() == @mapping_sha256
      assert codec.metadata_sha256() == @metadata_sha256
      assert codec.source_sha256() == @guide_sha256
      assert codec.source_pages() == [436, 572]
      assert codec.printed_source_pages() == [419, 555]
      assert codec.corroborating_source_sha256() == @corroborating_sha256
      assert codec.corroborating_source_pages() == [926]
      assert codec.printed_corroborating_source_pages() == [924]
      assert String.starts_with?(codec.source_url(), "https://education.ti.com/")
      assert String.starts_with?(codec.corroborating_source_url(), "https://education.ti.com/")
    end

    refute File.exists?(Path.join(Path.dirname(@mapping_path), "8992bookeng.pdf"))
    refute File.exists?(Path.join(Path.dirname(@mapping_path), "TI-89_Guidebook_EN.pdf"))
  end

  test "RED: compile-time source asset validator rejects tampering and every invalid schema" do
    mapping = File.read!(@mapping_path)
    metadata = File.read!(@metadata_path)
    validator = Iconvex.Specs.TI89AMS20.SourceAsset

    assert_raise RuntimeError, ~r/mapping asset SHA-256 mismatch/, fn ->
      validator.validate!(mapping <> "\n", metadata,
        mapping_sha256: @mapping_sha256,
        metadata_sha256: @metadata_sha256
      )
    end

    assert_raise RuntimeError, ~r/metadata asset SHA-256 mismatch/, fn ->
      validator.validate!(mapping, metadata <> "\n",
        mapping_sha256: @mapping_sha256,
        metadata_sha256: @metadata_sha256
      )
    end

    bad_header =
      String.replace(
        mapping,
        "# BYTE;SOURCE_GLYPH;VISIBLE;LOSSLESS_VPUA;RAW_VPUA",
        "# BYTE;SOURCE_GLYPH;VISIBLE;LOSSLESS_VPUA;RAW"
      )

    assert_invalid_asset(
      validator,
      bad_header,
      metadata,
      ~r/unexpected TI AMS 2.0 mapping header/
    )

    missing_row = String.replace(mapping, "FF;00FF;00FF;00FF;F8AFF\n", "")

    assert_invalid_asset(
      validator,
      missing_row,
      metadata,
      ~r/exactly one ordered row for every byte 00\.\.FF/
    )

    duplicate_final_byte =
      String.replace(mapping, "FF;00FF;00FF;00FF;F8AFF", "FE;00FF;00FF;00FF;F8AFF")

    assert_invalid_asset(
      validator,
      duplicate_final_byte,
      metadata,
      ~r/exactly one ordered row for every byte 00\.\.FF/
    )

    lowercase_byte = String.replace(mapping, "0A;000A;240A;000A;F8A0A", "0a;000A;240A;000A;F8A0A")

    assert_invalid_asset(
      validator,
      lowercase_byte,
      metadata,
      ~r/exact two-digit uppercase hexadecimal/
    )

    malformed_fields =
      String.replace(mapping, "80;03B1;03B1;03B1;F8A80", "80;03B1;03B1;03B1")

    assert_invalid_asset(
      validator,
      malformed_fields,
      metadata,
      ~r/must contain exactly five fields/
    )

    invalid_surrogate =
      String.replace(mapping, "80;03B1;03B1;03B1;F8A80", "80;D800;03B1;03B1;F8A80")

    assert_invalid_asset(
      validator,
      invalid_surrogate,
      metadata,
      ~r/invalid Unicode scalar/
    )

    overlong_sequence =
      String.replace(mapping, "9A;0078+0305;", "9A;0078+0305+0041;")

    assert_invalid_asset(
      validator,
      overlong_sequence,
      metadata,
      ~r/must contain one or two Unicode scalars/
    )

    for {profile, duplicate_row} <- [
          {:source_glyph, "01;0002;2401;0001;F8A01"},
          {:visible, "01;0001;2402;0001;F8A01"},
          {:lossless_vpua, "01;0001;2401;0002;F8A01"},
          {:raw_vpua, "01;0001;2401;0001;F8A02"}
        ] do
      duplicate_reverse =
        String.replace(mapping, "01;0001;2401;0001;F8A01", duplicate_row)

      assert_invalid_asset(
        validator,
        duplicate_reverse,
        metadata,
        ~r/#{profile} reverse mappings must be unique/
      )
    end
  end

  test "RED: release manifest ships the independent mapping and metadata but no source PDF" do
    files = Mix.Project.config() |> Keyword.fetch!(:package) |> Keyword.fetch!(:files)

    for path <- [
          "priv/sources/ti-89-92-plus-ams-2.0/mapping.csv",
          "priv/sources/ti-89-92-plus-ams-2.0/SOURCE_METADATA.md"
        ] do
      assert path in files, "release manifest omits #{path}"
    end

    refute Enum.any?(files, &String.ends_with?(&1, ".pdf"))
  end

  test "uses the audited source glyphs and keeps the four policies distinct" do
    rows = mapping_map()
    source = rows.source_glyph
    visible = rows.visible
    lossless = rows.lossless_vpua

    assert source[0x95] == [0x1D07]
    assert source[0x96] == [0x1D452]
    assert source[0x97] == [0x1D48A]
    assert source[0x98] == [0x02B3]
    assert source[0x99] == [0x1D40]
    assert source[0xB5] == [0x00B5]
    assert source[0xBC] == [0x1D451]

    refute source[0x96] == [0x212F]
    refute source[0x99] == [0x22BA]
    refute source[0xBC] in [[0x2202], [0x2146]]

    for byte <- Enum.to_list(0x00..0x0A) ++ [0x0C, 0x0D] do
      assert visible[byte] == [0x2400 + byte]
    end

    assert visible[0x0B] == [0x2BB5]
    assert visible[0x0E] == [0x1F512]

    for byte <- [0x00, 0x95, 0x96, 0x98, 0x99, 0xB5, 0xBC] do
      assert lossless[byte] == [0xF8900 + byte]
    end
  end

  test "decodes every byte and all 256 bytes together for every profile" do
    expected = mapping_map()
    all_bytes = :binary.list_to_bin(Enum.to_list(0x00..0xFF))

    for profile <- @profiles do
      codec = profile.codec
      table = Map.fetch!(expected, profile.key)
      all_codepoints = Enum.flat_map(0x00..0xFF, &Map.fetch!(table, &1))

      for byte <- 0x00..0xFF do
        assert codec.decode(<<byte>>) == {:ok, Map.fetch!(table, byte)},
               "#{profile.canonical} byte #{hex(byte)}"
      end

      assert codec.decode(all_bytes) == {:ok, all_codepoints}
      assert codec.decode_discard(all_bytes) == {:ok, all_codepoints}
      assert codec.decode_chunk(all_bytes, true) == {:ok, all_codepoints, <<>>}
      assert codec.decode_chunk(all_bytes, false) == {:ok, all_codepoints, <<>>}
      assert codec.decode_to_utf8(all_bytes) == {:ok, List.to_string(all_codepoints)}
    end
  end

  test "encodes every source row and complete repertoire using canonical reverse mappings" do
    expected = mapping_map()

    for profile <- @profiles do
      codec = profile.codec
      table = Map.fetch!(expected, profile.key)

      for byte <- 0x00..0xFF do
        assert codec.encode(Map.fetch!(table, byte)) == {:ok, <<byte>>},
               "#{profile.canonical} byte #{hex(byte)}"
      end

      all_codepoints = Enum.flat_map(0x00..0xFF, &Map.fetch!(table, &1))
      utf8 = List.to_string(all_codepoints)
      all_bytes = :binary.list_to_bin(Enum.to_list(0x00..0xFF))
      assert codec.encode(all_codepoints) == {:ok, all_bytes}
      assert codec.encode_from_utf8(utf8) == {:ok, all_bytes}
    end
  end

  test "retains exact Greek, special, and high-byte behavior" do
    source = mapping_map().source_glyph
    codec = Iconvex.Specs.TI89AMS20

    assert source[0x80] == [0x03B1]
    assert source[0x8B] == [0x03A0]
    assert source[0x8E] == [0x03A3]
    assert source[0x9A] == [?x, 0x0305]
    assert source[0x9B] == [?y, 0x0305]
    assert source[0xAA] == [0x00AA]
    assert source[0xAD] == [0x2212]
    assert source[0xB4] == [0x207B, 0x00B9]

    for byte <- 0xC0..0xFF do
      assert source[byte] == [byte]
      assert codec.decode(<<byte>>) == {:ok, [byte]}
      assert codec.encode([byte]) == {:ok, <<byte>>}
    end
  end

  test "uses longest-match-first and never normalizes compatibility collisions" do
    source = mapping_map().source_glyph
    codec = Iconvex.Specs.TI89AMS20

    assert codec.encode([?x, 0x0305, ?x]) == {:ok, <<0x9A, ?x>>}
    assert codec.encode([?y, 0x0305, ?y]) == {:ok, <<0x9B, ?y>>}
    assert codec.encode([0x207B, 0x00B9, 0x00B9]) == {:ok, <<0xB4, 0xB9>>}

    for {plain, compatibility} <- [
          {0x2B, 0xB8},
          {0x31, 0xB9},
          {0x32, 0xB2},
          {0x33, 0xB3},
          {0x54, 0x99},
          {0x61, 0xAA},
          {0x65, 0x96},
          {0x69, 0x97},
          {0x6F, 0xBA},
          {0x72, 0x98}
        ] do
      plain_sequence = Map.fetch!(source, plain)
      compatibility_sequence = Map.fetch!(source, compatibility)
      assert nfkc(plain_sequence) == nfkc(compatibility_sequence)
      assert codec.encode(plain_sequence) == {:ok, <<plain>>}
      assert codec.encode(compatibility_sequence) == {:ok, <<compatibility>>}
    end

    assert nfkc(source[0xB4]) == nfkc(source[0xAD] ++ source[0x31])
    assert codec.encode(source[0xB4]) == {:ok, <<0xB4>>}
    assert codec.encode(source[0xAD] ++ source[0x31]) == {:ok, <<0xAD, 0x31>>}
  end

  test "strict, discard, substitute, and direct UTF-8 paths agree" do
    for profile <- @profiles do
      codec = profile.codec
      table = Map.fetch!(mapping_map(), profile.key)
      source = table[0x41] ++ [0x2603] ++ table[0x42]
      source_utf8 = List.to_string(source)
      replacement = table[0x3F]

      assert codec.encode(source) == {:error, :unrepresentable_character, 0x2603}

      assert codec.encode_from_utf8(source_utf8) ==
               {:error, :unrepresentable_character, 0x2603}

      assert codec.encode_discard(source) == {:ok, "AB"}
      assert codec.encode_substitute(source, fn 0x2603 -> replacement end) == {:ok, "A?B"}

      assert {:error,
              %Iconvex.Error{
                kind: :unrepresentable_character,
                encoding: encoding,
                codepoint: 0x2603
              }} = Iconvex.convert(source_utf8, "UTF-8", profile.canonical)

      assert encoding == profile.canonical

      assert Iconvex.convert(source_utf8, "UTF-8", profile.canonical, unrepresentable: :discard) ==
               {:ok, "AB"}

      if profile.key != :raw_vpua do
        assert Iconvex.convert(source_utf8, "UTF-8", profile.canonical,
                 unicode_substitute: "<?%04X>"
               ) == {:ok, "A<?2603>B"}
      end

      sample_bytes = <<0x00, 0x41, 0x80, 0x95, 0x9A, 0xB4, 0xFF>>
      sample_codepoints = Enum.flat_map(:binary.bin_to_list(sample_bytes), &table[&1])
      sample_utf8 = List.to_string(sample_codepoints)
      assert codec.decode_to_utf8(sample_bytes) == {:ok, sample_utf8}
      assert codec.encode_from_utf8(sample_utf8) == {:ok, sample_bytes}
    end
  end

  test "direct UTF-8 reports terminal and nonmatching sequence prefixes with codec tuples" do
    terminal_prefix = <<0x207B::utf8>>

    for codec <- [
          Iconvex.Specs.TI89AMS20,
          Iconvex.Specs.TI89AMS20Visible,
          Iconvex.Specs.TI89AMS20LosslessVPUA
        ] do
      assert codec.encode_from_utf8(terminal_prefix) ==
               {:error, :unrepresentable_character, 0x207B}

      assert codec.encode_from_utf8(terminal_prefix <> "A") ==
               {:error, :unrepresentable_character, 0x207B}

      assert {:error, %Iconvex.Error{kind: :unrepresentable_character, codepoint: 0x207B}} =
               Iconvex.convert(terminal_prefix, "UTF-8", codec.canonical_name())
    end
  end

  test "direct UTF-8 rejects incomplete and malformed suffixes at exact byte offsets" do
    for profile <- @profiles do
      codec = profile.codec
      table = Map.fetch!(mapping_map(), profile.key)
      prefix = table[0x96] |> List.to_string()
      offset = byte_size(prefix)

      assert codec.encode_from_utf8(prefix <> <<0xE2, 0x82>>) ==
               {:decode_error, :incomplete_sequence, offset, <<0xE2, 0x82>>}

      assert codec.encode_from_utf8(prefix <> <<0xFF>>) ==
               {:decode_error, :invalid_sequence, offset, <<0xFF>>}
    end
  end

  test "chunk encoders buffer terminal x, y, and superscript minus prefixes" do
    for codec <- [
          Iconvex.Specs.TI89AMS20,
          Iconvex.Specs.TI89AMS20Visible,
          Iconvex.Specs.TI89AMS20LosslessVPUA
        ] do
      assert codec.encode_chunk([?x], false, :error) == {:ok, <<>>, [?x]}
      assert codec.encode_chunk([?y], false, :error) == {:ok, <<>>, [?y]}
      assert codec.encode_chunk([0x207B], false, :error) == {:ok, <<>>, [0x207B]}
      assert codec.encode_chunk([?x], false, :discard) == {:ok, <<>>, [?x]}

      assert codec.encode_chunk([?y], false, {:replace, fn _ -> ~c"?" end}) ==
               {:ok, <<>>, [?y]}

      assert codec.encode_chunk([?x, 0x0305], false, :error) == {:ok, <<0x9A>>, []}
      assert codec.encode_chunk([?y, 0x0305], false, :error) == {:ok, <<0x9B>>, []}

      assert codec.encode_chunk([0x207B, 0x00B9], false, :error) ==
               {:ok, <<0xB4>>, []}

      assert codec.encode_chunk([?x], true, :error) == {:ok, <<?x>>, []}
      assert codec.encode_chunk([?x, ?A], false, :error) == {:ok, "xA", []}
      assert codec.encode_chunk([0x207B, ?A], false, :discard) == {:ok, "A", []}

      assert codec.encode_chunk(
               [0x207B, ?A],
               false,
               {:replace, fn 0x207B -> ~c"?" end}
             ) == {:ok, "?A", []}

      assert codec.encode_chunk([0x207B], true, :error) ==
               {:error, :unrepresentable_character, 0x207B}

      assert codec.encode_chunk([0x207B], true, :discard) == {:ok, <<>>, []}

      assert codec.encode_chunk(
               [0x207B],
               true,
               {:replace, fn 0x207B -> ~c"?" end}
             ) == {:ok, "?", []}
    end
  end

  test "public streams preserve all source and UTF-8 split boundaries" do
    all_bytes = :binary.list_to_bin(Enum.to_list(0x00..0xFF))
    expected = mapping_map()

    for profile <- @profiles do
      table = Map.fetch!(expected, profile.key)
      codepoints = Enum.flat_map(0x00..0xFF, &table[&1])
      utf8 = List.to_string(codepoints)

      source_chunks = for <<byte <- all_bytes>>, do: <<byte>>
      assert {:ok, decoded_stream} = Iconvex.stream(source_chunks, profile.canonical, "UTF-8")
      assert decoded_stream |> Enum.to_list() |> IO.iodata_to_binary() == utf8

      utf8_chunks = for <<byte <- utf8>>, do: <<byte>>
      assert {:ok, encoded_stream} = Iconvex.stream(utf8_chunks, "UTF-8", profile.canonical)
      assert encoded_stream |> Enum.to_list() |> IO.iodata_to_binary() == all_bytes
    end

    sequence_chunks = [
      "A",
      "x",
      <<0x0305::utf8>>,
      "y",
      <<0x0305::utf8>>,
      <<0x207B::utf8>>,
      <<0x00B9::utf8>>,
      "B"
    ]

    assert {:ok, stream} =
             Iconvex.stream(sequence_chunks, "UTF-8", "TI-89-92-PLUS-AMS-2.0")

    assert stream |> Enum.to_list() |> IO.iodata_to_binary() ==
             <<?A, 0x9A, 0x9B, 0xB4, ?B>>
  end

  test "registers only explicit AMS 2.0 names and aliases" do
    for profile <- @profiles do
      assert profile.codec.canonical_name() == profile.canonical

      assert {:ok, %{canonical: canonical, kind: :external}} =
               Iconvex.Registry.resolve(profile.canonical)

      assert canonical == profile.canonical

      for alias_name <- profile.aliases do
        assert {:ok, %{canonical: ^canonical}} = Iconvex.Registry.resolve(alias_name)
      end
    end

    for unversioned <- ["TI-89", "TI-92-PLUS", "TI89", "TI92", "TI-AMS"] do
      assert Iconvex.Registry.resolve(unversioned) == :error
    end
  end

  @tag timeout: 120_000
  test "large direct paths have bounded scheduler-reduction scaling" do
    small = :binary.copy("AMS2 x y 123\n", 16_384)
    large = small <> small

    for codec <- Enum.map(@profiles, & &1.codec) do
      {:ok, small_utf8} = codec.decode_to_utf8(small)
      {:ok, large_utf8} = codec.decode_to_utf8(large)
      assert large_utf8 == small_utf8 <> small_utf8
      assert codec.encode_from_utf8(large_utf8) == {:ok, large}

      decode_scaling =
        reduction_scaling(fn -> codec.decode_to_utf8(small) end, fn ->
          codec.decode_to_utf8(large)
        end)

      encode_scaling =
        reduction_scaling(fn -> codec.encode_from_utf8(small_utf8) end, fn ->
          codec.encode_from_utf8(large_utf8)
        end)

      assert decode_scaling <= 2.35,
             "#{inspect(codec)} decode reduction scaling #{decode_scaling}"

      assert encode_scaling <= 2.35,
             "#{inspect(codec)} encode reduction scaling #{encode_scaling}"
    end
  end

  defp mappings do
    @mapping_path
    |> File.stream!([], :line)
    |> Enum.reject(&String.starts_with?(&1, "#"))
    |> Enum.map(fn line ->
      [byte, source_glyph, visible, lossless_vpua, raw_vpua] =
        line |> String.trim() |> String.split(";")

      %{
        byte: String.to_integer(byte, 16),
        source_glyph: parse_sequence(source_glyph),
        visible: parse_sequence(visible),
        lossless_vpua: parse_sequence(lossless_vpua),
        raw_vpua: parse_sequence(raw_vpua)
      }
    end)
  end

  defp mapping_map do
    rows = mappings()

    Map.new([:source_glyph, :visible, :lossless_vpua, :raw_vpua], fn key ->
      {key, Map.new(rows, &{&1.byte, Map.fetch!(&1, key)})}
    end)
  end

  defp sequence_bytes(rows, key) do
    for row <- rows, length(Map.fetch!(row, key)) > 1, do: row.byte
  end

  defp vpua_bytes(rows, key, range) do
    for row <- rows,
        sequence = Map.fetch!(row, key),
        length(sequence) == 1,
        hd(sequence) in range,
        do: row.byte
  end

  defp parse_sequence(value) do
    value |> String.split("+") |> Enum.map(&String.to_integer(&1, 16))
  end

  defp valid_scalar?(codepoint),
    do: codepoint in 0x0000..0x10FFFF and codepoint not in 0xD800..0xDFFF

  defp nfkc(codepoints), do: :unicode.characters_to_nfkc_list(codepoints)

  defp reduction_scaling(small, large) do
    small.()
    large.()
    :erlang.garbage_collect()
    {:reductions, before_small} = Process.info(self(), :reductions)
    small.()
    {:reductions, after_small} = Process.info(self(), :reductions)
    :erlang.garbage_collect()
    {:reductions, before_large} = Process.info(self(), :reductions)
    large.()
    {:reductions, after_large} = Process.info(self(), :reductions)
    (after_large - before_large) / max(after_small - before_small, 1)
  end

  defp sha256(body), do: :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)

  defp assert_invalid_asset(validator, mapping, metadata, message) do
    assert_raise RuntimeError, message, fn ->
      validator.validate!(mapping, metadata,
        mapping_sha256: sha256(mapping),
        metadata_sha256: sha256(metadata)
      )
    end
  end

  defp hex(byte), do: byte |> Integer.to_string(16) |> String.pad_leading(2, "0")
end

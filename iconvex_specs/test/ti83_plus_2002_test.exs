defmodule Iconvex.Specs.TI83Plus2002Test do
  use ExUnit.Case, async: false

  @mapping_path Path.expand(
                  "../priv/sources/ti-83-plus-2002/mapping.csv",
                  __DIR__
                )
  @metadata_path Path.expand(
                   "../priv/sources/ti-83-plus-2002/SOURCE_METADATA.md",
                   __DIR__
                 )

  @mapping_sha256 "186d80d270a6a27815df8d0b5ff993c65b158efb7f3d6ddd27533feb9cb96ccc"
  @metadata_sha256 "31a7655c59eb3da1f7c6bb123f6eedb961f64ea2cb3a7e9240dc5e004e73aa8f"
  @guide_sha256 "a07d2cae4d5be0529901c178acd80028d2a72c484a04c61cde104f34712cec55"
  @source_url "https://education.ti.com/download/en/ed-tech/830D08FF31804AEAA2F03B8F5E89AD14/672891A1E98349CAB91C11B4928C253C/sdk83pguide.pdf"

  @profiles [
    %{
      key: :large_readable,
      font: :large,
      kind: :readable,
      codec: Iconvex.Specs.TI83PlusLarge,
      canonical: "TI-83-PLUS-LARGE",
      source_pages: Enum.to_list(173..179),
      printed_pages: Enum.to_list(156..162)
    },
    %{
      key: :large_lossless,
      font: :large,
      kind: :lossless,
      codec: Iconvex.Specs.TI83PlusLargeLosslessVPUA,
      canonical: "TI-83-PLUS-LARGE-LOSSLESS-VPUA",
      source_pages: Enum.to_list(173..179),
      printed_pages: Enum.to_list(156..162)
    },
    %{
      key: :large_raw,
      font: :large,
      kind: :raw,
      codec: Iconvex.Specs.TI83PlusLargeRawVPUA,
      canonical: "TI-83-PLUS-LARGE-RAW-VPUA",
      source_pages: Enum.to_list(173..179),
      printed_pages: Enum.to_list(156..162)
    },
    %{
      key: :small_readable,
      font: :small,
      kind: :readable,
      codec: Iconvex.Specs.TI83PlusSmall,
      canonical: "TI-83-PLUS-SMALL",
      source_pages: Enum.to_list(180..187),
      printed_pages: Enum.to_list(163..170)
    },
    %{
      key: :small_lossless,
      font: :small,
      kind: :lossless,
      codec: Iconvex.Specs.TI83PlusSmallLosslessVPUA,
      canonical: "TI-83-PLUS-SMALL-LOSSLESS-VPUA",
      source_pages: Enum.to_list(180..187),
      printed_pages: Enum.to_list(163..170)
    },
    %{
      key: :small_raw,
      font: :small,
      kind: :raw,
      codec: Iconvex.Specs.TI83PlusSmallRawVPUA,
      canonical: "TI-83-PLUS-SMALL-RAW-VPUA",
      source_pages: Enum.to_list(180..187),
      printed_pages: Enum.to_list(163..170)
    }
  ]

  @normalization_expectations %{
    large_readable: %{nfc: {12, 0}, nfd: {12, 0}, nfkc: {26, 16}, nfkd: {26, 16}},
    small_readable: %{nfc: {13, 0}, nfd: {13, 0}, nfkc: {27, 16}, nfkd: {27, 16}},
    large_lossless: %{nfc: {0, 0}, nfd: {0, 0}, nfkc: {12, 12}, nfkd: {12, 12}},
    small_lossless: %{nfc: {0, 0}, nfd: {0, 0}, nfkc: {12, 12}, nfkd: {12, 12}},
    large_raw: %{nfc: {0, 0}, nfd: {0, 0}, nfkc: {0, 0}, nfkd: {0, 0}},
    small_raw: %{nfc: {0, 0}, nfd: {0, 0}, nfkc: {0, 0}, nfkd: {0, 0}}
  }

  @vpua_allocations [
    {:iso_ir_169, 0xF0000, 0xF2283},
    {:univac, 0xF4000, 0xF403F},
    {:univac_i_lossless, 0xF4040, 0xF4040},
    {:univac_i_raw, 0xF4080, 0xF40BF},
    {:ti83_large_lossless, 0xF8300, 0xF83FF},
    {:ti83_large_raw, 0xF8400, 0xF84FF},
    {:ti83_small_lossless, 0xF8500, 0xF85FF},
    {:ti83_small_raw, 0xF8600, 0xF86FF},
    {:ti89_lossless, 0xF8900, 0xF89FF},
    {:ti89_raw, 0xF8A00, 0xF8AFF},
    {:chinese_telegraph_taiwan_lossless, 0xF8B00, 0xF8B03},
    {:pascii_10_lossless, 0xF8C00, 0xF8CFF},
    {:pascii_10_raw, 0xF8D00, 0xF8DFF}
  ]

  test "pins a compact numeric 256-byte table and the corrected frozen facts" do
    assert sha256(File.read!(@mapping_path)) == @mapping_sha256
    assert sha256(File.read!(@metadata_path)) == @metadata_sha256

    rows = mappings()
    assert length(rows) == 256
    assert Enum.map(rows, & &1.byte) == Enum.to_list(0x00..0xFF)

    assert invalid_bytes(rows, :large_readable) == [0x00 | Enum.to_list(0xF2..0xFF)]
    assert invalid_bytes(rows, :small_readable) == [0x00 | Enum.to_list(0xED..0xFF)]
    assert Enum.count(rows, & &1.large_readable) == 241
    assert Enum.count(rows, & &1.small_readable) == 236

    for key <- [:large_lossless, :small_lossless, :large_raw, :small_raw] do
      outputs = Enum.map(rows, &Map.fetch!(&1, key))
      assert length(Enum.uniq(outputs)) == 256, Atom.to_string(key)
      assert Enum.all?(outputs, &valid_sequence?/1), Atom.to_string(key)
    end

    for key <- [:large_readable, :small_readable] do
      assert rows
             |> Enum.map(&Map.fetch!(&1, key))
             |> Enum.reject(&is_nil/1)
             |> Enum.all?(&valid_sequence?/1)
    end

    assert sequence_bytes(rows, :large_readable) == [0x11, 0x1D, 0xCB, 0xCC, 0xD8, 0xDE]
    assert sequence_bytes(rows, :small_readable) == [0x11, 0x1D, 0xCB, 0xCC, 0xD8, 0xDE]

    for font <- [:large, :small] do
      assert mapping(rows, font, 0x01, :readable) == [0x006E]
      assert mapping(rows, font, 0x0A, :readable) == [0x25A1]
      assert mapping(rows, font, 0x0C, :readable) == [0x00B7]
      assert mapping(rows, font, 0x0C, :lossless) == [lossless_base(font) + 0x0C]
      assert mapping(rows, font, 0xD6, :readable) == [lossless_base(font) + 0xD6]
    end

    assert Enum.map(rows, & &1.large_raw) == Enum.map(0x00..0xFF, &[0xF8400 + &1])
    assert Enum.map(rows, & &1.small_raw) == Enum.map(0x00..0xFF, &[0xF8600 + &1])

    validate_asset_policies!(rows, :large)
    validate_asset_policies!(rows, :small)
  end

  test "pins the official guide hash, exact appendix pages, and packaging boundary" do
    metadata = File.read!(@metadata_path)
    assert metadata =~ @guide_sha256
    assert metadata =~ @mapping_sha256
    assert metadata =~ @source_url
    assert metadata =~ "PDF physical pages 173-179, printed pages 156-162"
    assert metadata =~ "PDF physical pages 180-187, printed pages 163-170"
    assert metadata =~ "six explicit profiles"
    assert metadata =~ "Bare `TI-83-PLUS` names are intentionally absent"
    assert metadata =~ "independently authored compact numeric transcription"
  end

  test "RED: all six codecs expose the pinned source hashes and font-specific pages" do
    for profile <- @profiles do
      codec = profile.codec
      assert codec.mapping_sha256() == @mapping_sha256
      assert codec.metadata_sha256() == @metadata_sha256
      assert codec.source_sha256() == @guide_sha256
      assert codec.source_url() == @source_url
      assert codec.source_pages() == profile.source_pages
      assert codec.printed_source_pages() == profile.printed_pages
    end
  end

  test "RED: compile-time asset validator rejects tampering before table construction" do
    mapping = File.read!(@mapping_path)
    metadata = File.read!(@metadata_path)
    validator = Iconvex.Specs.TI83Plus2002.SourceAsset

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

    duplicate_final_byte =
      String.replace(
        mapping,
        "FF;-;F83FF;invalid;-;F85FF;invalid",
        "FE;-;F83FF;invalid;-;F85FF;invalid"
      )

    assert_raise RuntimeError, ~r/exactly one ordered row for every byte 00\.\.FF/, fn ->
      validator.validate!(duplicate_final_byte, metadata,
        mapping_sha256: sha256(duplicate_final_byte),
        metadata_sha256: @metadata_sha256
      )
    end

    lowercase_byte = String.replace(mapping, "0A;25A1;", "0a;25A1;")

    assert_raise RuntimeError, ~r/exact two-digit uppercase hexadecimal/, fn ->
      validator.validate!(lowercase_byte, metadata,
        mapping_sha256: sha256(lowercase_byte),
        metadata_sha256: @metadata_sha256
      )
    end

    alias_to_alias =
      String.replace(
        mapping,
        "DA;0046;F83DA;alias:46;0046;F85DA;alias:46",
        "DA;0046;F83DA;alias:0F;0046;F85DA;alias:0F"
      )

    assert_raise RuntimeError, ~r/alias target must be a canonical reverse owner/, fn ->
      validator.validate!(alias_to_alias, metadata,
        mapping_sha256: sha256(alias_to_alias),
        metadata_sha256: @metadata_sha256
      )
    end

    surrogate = String.replace(mapping, "05;25B6;F8305;", "05;D800;F8305;")

    assert_raise RuntimeError, ~r/invalid TI-83 Plus Unicode scalar/, fn ->
      validator.validate!(surrogate, metadata,
        mapping_sha256: sha256(surrogate),
        metadata_sha256: @metadata_sha256
      )
    end

    unknown_policy =
      String.replace(
        mapping,
        "05;25B6;F8305;canonical;25B6;F8505;canonical",
        "05;25B6;F8305;unknown;25B6;F8505;canonical"
      )

    assert_raise RuntimeError, ~r/invalid TI-83 Plus reverse policy/, fn ->
      validator.validate!(unknown_policy, metadata,
        mapping_sha256: sha256(unknown_policy),
        metadata_sha256: @metadata_sha256
      )
    end

    duplicate_canonical =
      String.replace(
        mapping,
        "05;25B6;F8305;canonical;25B6;F8505;canonical",
        "05;2B07;F8305;canonical;25B6;F8505;canonical"
      )

    assert_raise RuntimeError, ~r/canonical reverse mappings must be unique/, fn ->
      validator.validate!(duplicate_canonical, metadata,
        mapping_sha256: sha256(duplicate_canonical),
        metadata_sha256: @metadata_sha256
      )
    end
  end

  test "RED: registers six explicit font profiles and no ambiguous bare aliases" do
    for profile <- @profiles do
      assert profile.codec.canonical_name() == profile.canonical

      assert {:ok, %{canonical: canonical, kind: :external}} =
               Iconvex.Registry.resolve(profile.canonical)

      assert canonical == profile.canonical

      assert {:ok, %{canonical: ^canonical}} =
               Iconvex.Registry.resolve(String.downcase(canonical))
    end

    for bare <- [
          "TI-83-PLUS",
          "TI83PLUS",
          "TI83-PLUS",
          "TI-83 PLUS",
          "TI-83-PLUS-LOSSLESS-VPUA",
          "TI-83-PLUS-RAW-VPUA"
        ] do
      assert Iconvex.Registry.resolve(bare) == :error
    end
  end

  test "RED: every byte decodes exactly and readable invalid tails retain exact offsets" do
    rows = mappings()
    tables = tables(rows)
    all_bytes = :binary.list_to_bin(Enum.to_list(0x00..0xFF))

    for profile <- @profiles do
      codec = profile.codec
      table = Map.fetch!(tables, profile.key)

      for byte <- 0x00..0xFF do
        case Map.fetch!(table, byte) do
          nil ->
            assert codec.decode(<<byte>>) == {:error, :invalid_sequence, 0, <<byte>>}
            assert codec.decode(<<0x41, byte>>) == {:error, :invalid_sequence, 1, <<byte>>}

          sequence ->
            assert codec.decode(<<byte>>) == {:ok, sequence},
                   "#{profile.canonical} byte #{hex(byte)}"
        end
      end

      expected_discarded =
        Enum.flat_map(0x00..0xFF, fn byte ->
          case Map.fetch!(table, byte) do
            nil -> []
            sequence -> sequence
          end
        end)

      assert codec.decode_discard(all_bytes) == {:ok, expected_discarded}

      defined_bytes =
        for byte <- 0x00..0xFF, Map.fetch!(table, byte) != nil, into: <<>>, do: <<byte>>

      assert codec.decode(defined_bytes) == {:ok, expected_discarded}
      assert codec.decode_chunk(defined_bytes, true) == {:ok, expected_discarded, <<>>}
      assert codec.decode_to_utf8(defined_bytes) == {:ok, List.to_string(expected_discarded)}
    end
  end

  test "RED: every canonical, alias, decode-only, lossless, and raw reverse policy is exact" do
    rows = mappings()
    tables = tables(rows)

    for profile <- @profiles do
      codec = profile.codec
      table = Map.fetch!(tables, profile.key)

      for row <- rows do
        sequence = Map.fetch!(table, row.byte)

        case expected_reverse(profile, row) do
          :invalid ->
            assert is_nil(sequence)

          expected ->
            assert codec.encode(sequence) == {:ok, expected},
                   "#{profile.canonical} byte #{hex(row.byte)}"

            assert codec.encode_from_utf8(List.to_string(sequence)) == {:ok, expected},
                   "#{profile.canonical} direct UTF-8 byte #{hex(row.byte)}"
        end
      end
    end
  end

  @tag timeout: 180_000
  test "RED: both mixed-lossless profiles round-trip all 131,072 adjacent byte pairs" do
    tables = tables(mappings())

    count =
      for profile <- @profiles,
          profile.kind == :lossless,
          left <- 0x00..0xFF,
          right <- 0x00..0xFF,
          reduce: 0 do
        count ->
          table = Map.fetch!(tables, profile.key)
          source = <<left, right>>
          codepoints = Map.fetch!(table, left) ++ Map.fetch!(table, right)

          assert profile.codec.decode(source) == {:ok, codepoints},
                 "#{profile.canonical} #{hex(left)} #{hex(right)} decode"

          assert profile.codec.encode(codepoints) == {:ok, source},
                 "#{profile.canonical} #{hex(left)} #{hex(right)} encode"

          count + 1
      end

    assert count == 131_072
  end

  test "RED: active sequences use longest match while decode-only sequences never enter the reverse trie" do
    rows = mappings()
    tables = tables(rows)

    active = %{
      0x11 => [0x207B, 0x00B9],
      0xCB => [?x, 0x0305],
      0xCC => [?y, 0x0305],
      0xD8 => [?p, 0x0302]
    }

    for profile <- @profiles, profile.kind in [:readable, :lossless] do
      codec = profile.codec

      for {byte, sequence} <- active do
        assert codec.decode(<<byte>>) == {:ok, sequence}
        assert codec.encode(sequence) == {:ok, <<byte>>}
      end

      for {prefix, ordinary_byte} <- [
            {0x207B, nil},
            {?x, ?x},
            {?y, ?y},
            {?p, ?p}
          ] do
        assert codec.encode_chunk([prefix], false, :error) == {:ok, <<>>, [prefix]}

        if ordinary_byte do
          assert codec.encode_chunk([prefix], true, :error) == {:ok, <<ordinary_byte>>, []}

          assert codec.encode_chunk([prefix, ?A], false, :error) ==
                   {:ok, <<ordinary_byte, ?A>>, []}
        else
          assert codec.encode_chunk([prefix], true, :error) ==
                   {:error, :unrepresentable_character, prefix}
        end
      end

      assert codec.encode_chunk([0x207B, 0x00B9], false, :error) == {:ok, <<0x11>>, []}
      assert codec.encode_chunk([?x, 0x0305], false, :error) == {:ok, <<0xCB>>, []}
      assert codec.encode_chunk([?y, 0x0305], false, :error) == {:ok, <<0xCC>>, []}
      assert codec.encode_chunk([?p, 0x0302], false, :error) == {:ok, <<0xD8>>, []}
    end

    for profile <- @profiles, profile.kind == :readable do
      codec = profile.codec
      assert codec.decode(<<0x1D>>) == {:ok, [?1, ?0]}
      assert codec.decode(<<0xDE>>) == {:ok, [?), ?)]}
      assert codec.encode([?1, ?0]) == {:ok, <<?1, ?0>>}
      assert codec.encode([?), ?)]) == {:ok, <<?), ?)>>}
      assert codec.encode_chunk([?1], false, :error) == {:ok, <<?1>>, []}
      assert codec.encode_chunk([?)], false, :error) == {:ok, <<?)>>, []}
      assert codec.encode_chunk([?1, ?0], false, :error) == {:ok, <<?1, ?0>>, []}
      assert codec.encode_chunk([?), ?)], false, :error) == {:ok, <<?), ?)>>, []}
    end

    for profile <- @profiles, profile.kind == :lossless do
      table = Map.fetch!(tables, profile.key)
      assert profile.codec.decode(<<0x1D>>) == {:ok, table[0x1D]}
      assert profile.codec.encode(table[0x1D]) == {:ok, <<0x1D>>}
      assert profile.codec.decode(<<0xDE>>) == {:ok, table[0xDE]}
      assert profile.codec.encode(table[0xDE]) == {:ok, <<0xDE>>}
    end
  end

  test "RED: a retained superscript-minus prefix errors when the next scalar cannot complete it" do
    nonmatching = [0x207B, ?A]
    nonmatching_utf8 = List.to_string(nonmatching)

    for profile <- @profiles, profile.kind in [:readable, :lossless] do
      codec = profile.codec

      assert codec.encode(nonmatching) ==
               {:error, :unrepresentable_character, 0x207B}

      assert codec.encode_from_utf8(nonmatching_utf8) ==
               {:error, :unrepresentable_character, 0x207B}

      assert codec.encode_chunk(nonmatching, false, :error) ==
               {:error, :unrepresentable_character, 0x207B}

      assert codec.encode_chunk(nonmatching, true, :error) ==
               {:error, :unrepresentable_character, 0x207B}
    end
  end

  test "RED: readable direct and chunk decoders preserve every invalid-tail offset and sequence" do
    for profile <- @profiles, profile.kind == :readable do
      codec = profile.codec

      for tail <- invalid_tail(profile.font) do
        source = <<0x41, tail>>
        expected = {:error, :invalid_sequence, 1, <<tail>>}

        assert codec.decode_to_utf8(source) == expected,
               "#{profile.canonical} direct tail #{hex(tail)}"

        assert codec.decode_chunk(source, true) == expected,
               "#{profile.canonical} final chunk tail #{hex(tail)}"

        assert codec.decode_chunk(source, false) == expected,
               "#{profile.canonical} non-final chunk tail #{hex(tail)}"
      end
    end
  end

  test "RED: public streams keep strict, discard, and replacement policy at an invalid-tail boundary" do
    tables = tables(mappings())

    for profile <- @profiles, profile.kind == :readable do
      tail = invalid_tail(profile.font) |> Enum.min()
      chunks = [<<0x41>>, <<tail>>]
      prefix = tables[profile.key][0x41] |> List.to_string()

      assert {:ok, strict_stream} =
               Iconvex.stream(chunks, profile.canonical, "UTF-8")

      error =
        assert_raise Iconvex.Error, fn ->
          strict_stream |> Enum.to_list() |> IO.iodata_to_binary()
        end

      assert error.kind == :invalid_sequence
      assert error.encoding == profile.canonical
      assert error.offset == 1
      assert error.sequence == <<tail>>

      assert {:ok, discard_stream} =
               Iconvex.stream(chunks, profile.canonical, "UTF-8", invalid: :discard)

      assert discard_stream |> Enum.to_list() |> IO.iodata_to_binary() == prefix

      assert {:ok, replacement_stream} =
               Iconvex.stream(chunks, profile.canonical, "UTF-8", byte_substitute: "<%02x>")

      assert replacement_stream |> Enum.to_list() |> IO.iodata_to_binary() ==
               prefix <> "<#{tail |> hex() |> String.downcase()}>"
    end
  end

  @tag timeout: 120_000
  test "RED: public streams preserve every source and UTF-8 split in representative policy data" do
    rows = mappings()
    tables = tables(rows)
    source = <<0x05, 0x11, 0x1D, 0xCB, 0xCC, 0xD8, 0xDE, 0xE0>>

    for profile <- @profiles do
      table = Map.fetch!(tables, profile.key)
      codepoints = Enum.flat_map(:binary.bin_to_list(source), &Map.fetch!(table, &1))
      utf8 = List.to_string(codepoints)

      expected_encoded =
        source
        |> :binary.bin_to_list()
        |> Enum.map(fn byte ->
          row = Enum.at(rows, byte)
          expected_reverse(profile, row)
        end)
        |> IO.iodata_to_binary()

      assert_stream_splits(source, profile.canonical, "UTF-8", utf8)
      assert_stream_splits(utf8, "UTF-8", profile.canonical, expected_encoded)
    end
  end

  test "enumerates every normalization collision without shipping a collision research table" do
    rows = mappings()
    tables = tables(rows)

    for {key, expected_forms} <- @normalization_expectations do
      table = Map.fetch!(tables, key)

      for {form, expected} <- expected_forms do
        assert normalization_stats(table, form) == expected,
               "#{key} #{form}"
      end
    end

    expected_large_lossless = %{
      [?t] => [0x0D, 0x74],
      [?0] => [0x30, 0x80],
      [?1] => [0x31, 0x81],
      [?2] => [0x12, 0x32, 0x82],
      [?3] => [0x33, 0x83, 0xD5],
      [?4] => [0x24, 0x34, 0x84],
      [?5] => [0x35, 0x85],
      [?6] => [0x36, 0x86],
      [?7] => [0x37, 0x87],
      [?8] => [0x38, 0x88],
      [?9] => [0x39, 0x89],
      [?e] => [0x65, 0xDB]
    }

    expected_small_lossless =
      Map.put(expected_large_lossless, [?4], [0x34, 0x84])

    assert collision_bytes(tables.large_lossless, :nfkc) == expected_large_lossless
    assert collision_bytes(tables.large_lossless, :nfkd) == expected_large_lossless
    assert collision_bytes(tables.small_lossless, :nfkc) == expected_small_lossless
    assert collision_bytes(tables.small_lossless, :nfkd) == expected_small_lossless
  end

  test "RED: normalization is never implicit in any introduced collision" do
    rows = mappings()
    tables = tables(rows)

    for profile <- @profiles do
      table = Map.fetch!(tables, profile.key)

      for form <- [:nfc, :nfd, :nfkc, :nfkd],
          {_normalized, entries} <- collision_groups(table, form),
          entries |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> length() > 1,
          {byte, sequence} <- entries do
        row = Enum.at(rows, byte)
        assert profile.codec.encode(sequence) == {:ok, expected_reverse(profile, row)}
      end
    end
  end

  test "VPUA allocations are exhaustive, arithmetic, and non-overlapping" do
    assert Enum.map(@vpua_allocations, &elem(&1, 0)) == [
             :iso_ir_169,
             :univac,
             :univac_i_lossless,
             :univac_i_raw,
             :ti83_large_lossless,
             :ti83_large_raw,
             :ti83_small_lossless,
             :ti83_small_raw,
             :ti89_lossless,
             :ti89_raw,
             :chinese_telegraph_taiwan_lossless,
             :pascii_10_lossless,
             :pascii_10_raw
           ]

    for {{left_name, left_first, left_last}, {right_name, right_first, right_last}} <-
          Enum.chunk_every(@vpua_allocations, 2, 1, :discard) do
      assert left_first <= left_last
      assert right_first <= right_last

      assert left_last < right_first,
             "#{left_name} overlaps #{right_name}"
    end

    rows = mappings()

    for {font, lossless_key, raw_key, lossless_range, raw_range} <- [
          {:large, :large_lossless, :large_raw, 0xF8300..0xF83FF, 0xF8400..0xF84FF},
          {:small, :small_lossless, :small_raw, 0xF8500..0xF85FF, 0xF8600..0xF86FF}
        ] do
      for row <- rows do
        assert Map.fetch!(row, raw_key) == [raw_range.first + row.byte]

        for codepoint <- Map.fetch!(row, lossless_key),
            codepoint >= 0xF0000 do
          assert codepoint in lossless_range,
                 "#{font} byte #{hex(row.byte)} escapes its lossless allocation"
        end
      end
    end
  end

  test "RED: central VPUA allocation ledger pins every current non-overlapping block" do
    path = Path.expand("../VPUA_ALLOCATIONS.md", __DIR__)
    ledger = File.read!(path)

    ledger_rows =
      Regex.scan(
        ~r/^\| `([a-z0-9_]+)` \| U\+([0-9A-F]+)\.\.U\+([0-9A-F]+) \|/m,
        ledger,
        capture: :all_but_first
      )
      |> Enum.map(fn [name, first, last] ->
        {
          String.to_existing_atom(name),
          String.to_integer(first, 16),
          String.to_integer(last, 16)
        }
      end)

    assert ledger_rows == @vpua_allocations

    assert ledger =~ @mapping_sha256
    assert ledger =~ "strictly non-overlapping"

    files = Mix.Project.config() |> Keyword.fetch!(:package) |> Keyword.fetch!(:files)
    assert "VPUA_ALLOCATIONS.md" in files
  end

  test "RED: strict, discard, substitute, conversion, and malformed UTF-8 offsets agree" do
    rows = mappings()
    tables = tables(rows)

    for profile <- @profiles do
      codec = profile.codec
      table = Map.fetch!(tables, profile.key)
      source = table[0x41] ++ [0x2603] ++ table[0x42]
      source_utf8 = List.to_string(source)
      replacement = table[0x3F]

      assert codec.encode(source) == {:error, :unrepresentable_character, 0x2603}

      assert codec.encode_from_utf8(source_utf8) ==
               {:error, :unrepresentable_character, 0x2603}

      assert codec.encode_discard(source) == {:ok, <<0x41, 0x42>>}

      assert codec.encode_substitute(source, fn 0x2603 -> replacement end) ==
               {:ok, <<0x41, 0x3F, 0x42>>}

      assert {:error,
              %Iconvex.Error{
                kind: :unrepresentable_character,
                encoding: encoding,
                codepoint: 0x2603
              }} = Iconvex.convert(source_utf8, "UTF-8", profile.canonical)

      assert encoding == profile.canonical

      assert Iconvex.convert(source_utf8, "UTF-8", profile.canonical, unrepresentable: :discard) ==
               {:ok, <<0x41, 0x42>>}

      prefix = List.to_string(table[0x41])
      offset = byte_size(prefix)

      assert codec.encode_from_utf8(prefix <> <<0xE2, 0x82>>) ==
               {:decode_error, :incomplete_sequence, offset, <<0xE2, 0x82>>}

      assert codec.encode_from_utf8(prefix <> <<0xFF>>) ==
               {:decode_error, :invalid_sequence, offset, <<0xFF>>}

      assert {:error,
              %Iconvex.Error{
                kind: :invalid_sequence,
                encoding: "UTF-8",
                offset: ^offset,
                sequence: <<0xFF>>
              }} = Iconvex.convert(prefix <> <<0xFF>>, "UTF-8", profile.canonical)

      if profile.kind == :readable do
        tail = if profile.font == :large, do: 0xF2, else: 0xED
        expected_a = table[0x41]
        assert codec.decode(<<tail>>) == {:error, :invalid_sequence, 0, <<tail>>}
        assert codec.decode(<<0x41, tail>>) == {:error, :invalid_sequence, 1, <<tail>>}
        assert codec.decode_discard(<<tail, 0x41>>) == {:ok, expected_a}

        assert {:error,
                %Iconvex.Error{
                  kind: :invalid_sequence,
                  encoding: bad_encoding,
                  offset: 1,
                  sequence: <<^tail>>
                }} = Iconvex.convert(<<0x41, tail>>, profile.canonical, "UTF-8")

        assert bad_encoding == profile.canonical
      end
    end
  end

  test "release boundary contains only compact facts and excludes restricted research artifacts" do
    source_dir = Path.dirname(@mapping_path)

    assert source_dir
           |> Path.join("**/*")
           |> Path.wildcard()
           |> Enum.filter(&File.regular?/1)
           |> Enum.map(&Path.relative_to(&1, source_dir))
           |> Enum.sort() == ["SOURCE_METADATA.md", "mapping.csv"]

    mapping = File.read!(@mapping_path)
    refute mapping =~ "official_symbol_name"
    refute mapping =~ "source_cell"
    refute mapping =~ "source_evidence"
    refute mapping =~ "/private/"

    metadata = File.read!(@metadata_path)
    refute metadata =~ "/private/"
    refute metadata =~ "libticonv"
    refute metadata =~ "GNU General Public License"

    files = Mix.Project.config() |> Keyword.fetch!(:package) |> Keyword.fetch!(:files)

    refute Enum.any?(files, fn path ->
             String.contains?(path, "ti-83-plus-2002") and
               Path.extname(path) in [".pdf", ".png", ".jpg", ".jpeg", ".svg", ".html"]
           end)

    for path <- [
          "priv/sources/ti-83-plus-2002/mapping.csv",
          "priv/sources/ti-83-plus-2002/SOURCE_METADATA.md"
        ] do
      assert path in files, "release manifest omits #{path}"
    end
  end

  defp mappings do
    [_header | rows] =
      @mapping_path
      |> File.stream!([], :line)
      |> Enum.reject(&String.starts_with?(&1, "#"))
      |> Enum.map(&String.trim/1)

    Enum.map(rows, fn line ->
      [
        byte,
        large_readable,
        large_lossless,
        large_reverse,
        small_readable,
        small_lossless,
        small_reverse
      ] = String.split(line, ";")

      byte = String.to_integer(byte, 16)

      %{
        byte: byte,
        large_readable: parse_sequence(large_readable),
        large_lossless: parse_sequence(large_lossless),
        large_raw: [0xF8400 + byte],
        large_reverse: parse_policy(large_reverse),
        small_readable: parse_sequence(small_readable),
        small_lossless: parse_sequence(small_lossless),
        small_raw: [0xF8600 + byte],
        small_reverse: parse_policy(small_reverse)
      }
    end)
  end

  defp tables(rows) do
    Map.new(
      [
        :large_readable,
        :large_lossless,
        :large_raw,
        :small_readable,
        :small_lossless,
        :small_raw
      ],
      fn key ->
        {key, Map.new(rows, &{&1.byte, Map.fetch!(&1, key)})}
      end
    )
  end

  defp validate_asset_policies!(rows, font) do
    readable_key = key(font, :readable)
    reverse_key = key(font, :reverse)
    table = Map.new(rows, &{&1.byte, Map.fetch!(&1, readable_key)})

    for row <- rows do
      sequence = Map.fetch!(row, readable_key)

      case Map.fetch!(row, reverse_key) do
        :invalid ->
          assert is_nil(sequence)

        {:alias, target} ->
          assert sequence == Map.fetch!(table, target)
          assert Map.fetch!(Enum.at(rows, target), reverse_key) in [:canonical, :longest, :vpua]

        policy when policy in [:canonical, :longest, :vpua, :decode_only] ->
          assert valid_sequence?(sequence)
      end
    end
  end

  defp expected_reverse(%{kind: kind}, row) when kind in [:lossless, :raw],
    do: <<row.byte>>

  defp expected_reverse(%{kind: :readable, font: font}, row) do
    case Map.fetch!(row, key(font, :reverse)) do
      :invalid -> :invalid
      {:alias, target} -> <<target>>
      :decode_only when row.byte == 0x1D -> <<0x31, 0x30>>
      :decode_only when row.byte == 0xDE -> <<0x29, 0x29>>
      policy when policy in [:canonical, :longest, :vpua] -> <<row.byte>>
    end
  end

  defp invalid_bytes(rows, key) do
    for row <- rows, Map.fetch!(row, key) == nil, do: row.byte
  end

  defp sequence_bytes(rows, key) do
    for row <- rows,
        sequence = Map.fetch!(row, key),
        is_list(sequence) and length(sequence) > 1,
        do: row.byte
  end

  defp mapping(rows, font, byte, kind),
    do: rows |> Enum.at(byte) |> Map.fetch!(key(font, kind))

  defp key(:large, :readable), do: :large_readable
  defp key(:large, :lossless), do: :large_lossless
  defp key(:large, :reverse), do: :large_reverse
  defp key(:small, :readable), do: :small_readable
  defp key(:small, :lossless), do: :small_lossless
  defp key(:small, :reverse), do: :small_reverse

  defp lossless_base(:large), do: 0xF8300
  defp lossless_base(:small), do: 0xF8500

  defp invalid_tail(:large), do: Enum.to_list(0xF2..0xFF)
  defp invalid_tail(:small), do: Enum.to_list(0xED..0xFF)

  defp parse_sequence("-"), do: nil

  defp parse_sequence(value),
    do: value |> String.split("+") |> Enum.map(&String.to_integer(&1, 16))

  defp parse_policy("canonical"), do: :canonical
  defp parse_policy("longest"), do: :longest
  defp parse_policy("vpua"), do: :vpua
  defp parse_policy("decode_only"), do: :decode_only
  defp parse_policy("invalid"), do: :invalid

  defp parse_policy("alias:" <> byte),
    do: {:alias, String.to_integer(byte, 16)}

  defp valid_sequence?(sequence) when is_list(sequence),
    do: Enum.all?(sequence, &valid_scalar?/1)

  defp valid_sequence?(_), do: false

  defp valid_scalar?(codepoint),
    do: codepoint in 0x0000..0x10FFFF and codepoint not in 0xD800..0xDFFF

  defp normalization_stats(table, form) do
    groups = collision_groups(table, form)

    introduced =
      Enum.count(groups, fn {_normalized, entries} ->
        entries |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> length() > 1
      end)

    {map_size(groups), introduced}
  end

  defp collision_bytes(table, form) do
    Map.new(collision_groups(table, form), fn {normalized, entries} ->
      {normalized, Enum.map(entries, &elem(&1, 0))}
    end)
  end

  defp collision_groups(table, form) do
    table
    |> Enum.reject(fn {_byte, sequence} -> is_nil(sequence) end)
    |> Enum.group_by(fn {_byte, sequence} -> normalize(sequence, form) end)
    |> Map.filter(fn {_normalized, entries} -> length(entries) > 1 end)
    |> Map.new(fn {normalized, entries} ->
      {normalized, Enum.sort_by(entries, &elem(&1, 0))}
    end)
  end

  defp normalize(sequence, :nfc), do: :unicode.characters_to_nfc_list(sequence)
  defp normalize(sequence, :nfd), do: :unicode.characters_to_nfd_list(sequence)
  defp normalize(sequence, :nfkc), do: :unicode.characters_to_nfkc_list(sequence)
  defp normalize(sequence, :nfkd), do: :unicode.characters_to_nfkd_list(sequence)

  defp assert_stream_splits(input, from, to, expected) do
    assert {:ok, stream} = Iconvex.stream([input], from, to)
    assert stream |> Enum.to_list() |> IO.iodata_to_binary() == expected

    for offset <- 1..(byte_size(input) - 1) do
      chunks = [
        binary_part(input, 0, offset),
        binary_part(input, offset, byte_size(input) - offset)
      ]

      assert {:ok, split_stream} = Iconvex.stream(chunks, from, to)
      assert split_stream |> Enum.to_list() |> IO.iodata_to_binary() == expected
    end
  end

  defp sha256(body), do: :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)
  defp hex(byte), do: byte |> Integer.to_string(16) |> String.pad_leading(2, "0")
end

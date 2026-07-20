defmodule Iconvex.Specs.PASCII10Test do
  use ExUnit.Case, async: false

  @urdu_kashmiri Module.concat([Iconvex, Specs, PASCII10UrduKashmiriBestFit])
  @sindhi Module.concat([Iconvex, Specs, PASCII10SindhiBestFit])
  @lossless Module.concat([Iconvex, Specs, PASCII10LosslessVPUA1])
  @raw Module.concat([Iconvex, Specs, PASCII10RawVPUA1])
  @source_asset Module.concat([Iconvex, Specs, PASCII10, SourceAsset])
  @codecs [@urdu_kashmiri, @sindhi, @lossless, @raw]

  @source_dir Path.expand("../priv/sources/pascii-cdac-gist-1.0-2002", __DIR__)
  @mapping Path.join(@source_dir, "mapping.csv")
  @metadata Path.join(@source_dir, "SOURCE_METADATA.md")
  @unicode_corpus Path.expand("fixtures/all-unicode-scalars.utf32be", __DIR__)

  @source_sha256 "8eb605e3a7e0dcfed1fdb58de7ddfa2171d964b7b43220a234cbd6924608ecea"
  @source_size 459_623
  @mapping_sha256 "335236d0b61cf050f3d0ab1d0fed7b66df6bb1c317da4291d109a8eb769d2cf5"
  @metadata_sha256 "7681febbdefbd5304a8f6402f7ebc34c742e0fdbaea0da690f7ca15e81d32c4e"
  @lossless_base 0xF8C00
  @raw_base 0xF8D00
  @unassigned [0x80]
  @reserved [0xFA, 0xFB, 0xFE, 0xFF]
  @invalid_source_cells @unassigned ++ @reserved

  # This independent executable oracle follows the C-DAC byte chart. Unicode
  # values are explicitly an Iconvex Unicode-17 best-fit projection; source
  # cells without an exact scalar retain their source-qualified VPUA identity.
  @urdu_high [
    nil,
    0x0640,
    0x0627,
    0x0622,
    0x0628,
    0x067B,
    0x0680,
    0x067E,
    0x06A6,
    0x062A,
    0x0629,
    0x067F,
    0x0679,
    0x067A,
    0x062B,
    0x062C,
    0x0684,
    0x0683,
    0x0686,
    0x0687,
    0x062D,
    0x062E,
    0x062F,
    0x068C,
    0x0688,
    0x068F,
    0x068D,
    0x0630,
    0x0631,
    0x0691,
    {0x0699, 0x06BE},
    0x0632,
    0x0698,
    0x0633,
    0x0634,
    0x0635,
    0x0636,
    0x0637,
    0x0638,
    0x0639,
    0x063A,
    0x0641,
    0x0642,
    0x06A9,
    0x06A9,
    0x06AF,
    0x06B3,
    0x06B1,
    0x0644,
    0x0645,
    0x0646,
    0x06BA,
    0x06BB,
    0x0648,
    0x06C4,
    0x0647,
    0x06BE,
    0x0621,
    0x06CC,
    0x0620,
    0x06D3,
    0x06D2,
    0x064E,
    0x0650,
    0x064F,
    0x0657,
    0x0654,
    0x0655,
    @lossless_base + 0xC4,
    0x065F,
    0x0651,
    0x0653,
    0x06E1,
    0x0670,
    0x0656,
    0xFBC2,
    0x2026,
    0x0614,
    0x060C,
    0x0610,
    0x0613,
    0x0612,
    0x0611,
    0x08D7,
    @lossless_base + 0xD4,
    0x06D9,
    0x06DA,
    0x06E2,
    0x0601,
    0x066A,
    0x066C,
    0x066B,
    0x06F0,
    0x06F1,
    0x06F2,
    0x06F3,
    0x06F4,
    0x06F5,
    0x06F6,
    0x06F7,
    0x06F8,
    0x06F9,
    0x0021,
    0x201C,
    0x201D,
    0x2018,
    0x2019,
    0x0028,
    0x0029,
    0x066D,
    0x002B,
    @lossless_base + 0xEF,
    0x002D,
    0x002F,
    0x061B,
    0x003A,
    0x061F,
    0x003D,
    0x06D4,
    0x06DD,
    0x25CF,
    0x066C,
    nil,
    nil,
    0x25CC,
    0x00B7,
    nil,
    nil
  ]

  @urdu_table List.to_tuple(Enum.to_list(0x00..0x7F) ++ @urdu_high)
  @sindhi_table @urdu_table
                |> put_elem(0x8C, 0x067D)
                |> put_elem(0x98, 0x068A)
                |> put_elem(0x9D, 0x0699)
                |> put_elem(0xAB, 0x06AA)
                |> put_elem(0xBA, 0x064A)

  @lossless_table 0x00..0xFF
                  |> Enum.map(fn byte ->
                    cond do
                      byte < 0x80 -> byte
                      byte in @invalid_source_cells -> nil
                      true -> @lossless_base + byte
                    end
                  end)
                  |> List.to_tuple()

  @raw_table 0x00..0xFF
             |> Enum.map(&(@raw_base + &1))
             |> List.to_tuple()

  @profiles [
    {@urdu_kashmiri, @urdu_table},
    {@sindhi, @sindhi_table},
    {@lossless, @lossless_table},
    {@raw, @raw_table}
  ]

  test "RED: exact source-qualified PASCII modules and independent assets exist" do
    for module <- @codecs ++ [@source_asset] do
      assert Code.ensure_loaded?(module), inspect(module)
    end

    assert File.regular?(@mapping)
    assert File.regular?(@metadata)

    assert Path.wildcard(Path.join(@source_dir, "*")) |> Enum.sort() ==
             Enum.sort([@mapping, @metadata])

    assert sha256(File.read!(@mapping)) == @mapping_sha256
    assert sha256(File.read!(@metadata)) == @metadata_sha256

    metadata = File.read!(@metadata)
    assert metadata =~ "PASCII (Perso-Arabic Standard for Information Interchange) Version 1.0"
    assert metadata =~ "October 2002"
    assert metadata =~ @source_sha256
    assert metadata =~ Integer.to_string(@source_size)
    assert metadata =~ "physical PDF pages 4–7"
    assert metadata =~ "printed pages 61–64"
    assert metadata =~ "copyrighted reference only"
    assert metadata =~ "non-normative Unicode 17.0.0 best-fit projection"
    assert metadata =~ "no unqualified PASCII alias"
    assert metadata =~ "LGPL-2.1-or-later"

    mapping = File.read!(@mapping)
    assert mapping =~ "80,unassigned,,,,F8D80,cdac_unassigned\n"

    assert mapping =~
             "CB,assigned,FBC2,FBC2,F8CCB,F8DCB,cdac_cell_unicode17_nearest_best_fit\n"

    assert mapping =~
             "9E,assigned,0699+06BE,0699+06BE,F8C9E,F8D9E,iconvex_logical_sequence_inference\n"

    assert metadata =~ "Byte `80` is unassigned"
    assert metadata =~ "`CB` uses the nearest Unicode 17 best-fit scalar"
    assert metadata =~ "Persian and Arabic best-fit projections are intentionally withheld"
    refute metadata =~ "`CB` maps exactly"
  end

  test "source validation rejects digest, schema, ordering, profile, and metadata tampering" do
    mapping = File.read!(@mapping)
    metadata = File.read!(@metadata)

    assert length(validate(mapping, metadata)) == 256

    assert_raise ArgumentError, ~r/mapping SHA-256 mismatch/, fn ->
      validate(mapping <> "x", metadata)
    end

    assert_raise ArgumentError, ~r/metadata SHA-256 mismatch/, fn ->
      validate(mapping, metadata <> "x")
    end

    wrong_header =
      String.replace(
        mapping,
        "byte_hex,status,urdu_kashmiri_best_fit,sindhi_best_fit,lossless_vpua_1,raw_vpua_1,provenance",
        "byte,state,urdu,sindhi,lossless,raw,source"
      )

    assert_raise ArgumentError, ~r/unexpected PASCII mapping header/, fn ->
      validate_with_actual_digests(wrong_header, metadata)
    end

    reordered =
      mapping
      |> String.split("\n", trim: false)
      |> then(fn [header, first, second | rest] ->
        Enum.join([header, second, first | rest], "\n")
      end)

    assert_raise ArgumentError, ~r/ordered row 00/, fn ->
      validate_with_actual_digests(reordered, metadata)
    end

    wrong_language = String.replace(mapping, "BA,assigned,06CC,064A", "BA,assigned,0649,0649")

    assert_raise ArgumentError, ~r/language-profile deltas/, fn ->
      validate_with_actual_digests(wrong_language, metadata)
    end

    wrong_wasla = String.replace(mapping, "CB,assigned,FBC2,FBC2", "CB,assigned,F8CCB,F8CCB")

    assert_raise ArgumentError, ~r/Unicode 17 projection invariants/, fn ->
      validate_with_actual_digests(wrong_wasla, metadata)
    end

    incomplete_metadata = String.replace(metadata, "no unqualified PASCII alias", "generic alias")

    assert_raise ArgumentError, ~r/metadata omits/, fn ->
      validate_with_actual_digests(mapping, incomplete_metadata)
    end
  end

  test "every byte has the exact strict and direct result in every profile" do
    for {codec, table} <- @profiles, byte <- 0x00..0xFF do
      case elem(table, byte) do
        nil ->
          assert call(codec, :decode, [<<byte>>]) ==
                   {:error, :invalid_sequence, 0, <<byte>>}

          assert call(codec, :decode_to_utf8, [<<byte>>]) ==
                   {:error, :invalid_sequence, 0, <<byte>>}

        mapping ->
          expected = sequence_list(mapping)
          assert call(codec, :decode, [<<byte>>]) == {:ok, expected}
          assert call(codec, :decode_to_utf8, [<<byte>>]) == {:ok, List.to_string(expected)}
      end
    end
  end

  test "language-dependent cells are split and source-only cells stay explicit" do
    for {byte, urdu, sindhi} <- [
          {0x8C, 0x0679, 0x067D},
          {0x98, 0x0688, 0x068A},
          {0x9D, 0x0691, 0x0699},
          {0xAB, 0x06A9, 0x06AA},
          {0xBA, 0x06CC, 0x064A}
        ] do
      assert call(@urdu_kashmiri, :decode, [<<byte>>]) == {:ok, [urdu]}
      assert call(@sindhi, :decode, [<<byte>>]) == {:ok, [sindhi]}
    end

    assert call(@urdu_kashmiri, :decode, [<<0x9E>>]) == {:ok, [0x0699, 0x06BE]}
    assert call(@sindhi, :decode, [<<0x9E>>]) == {:ok, [0x0699, 0x06BE]}

    assert call(@urdu_kashmiri, :decode, [<<0xCB>>]) == {:ok, [0xFBC2]}

    for byte <- [0xC4, 0xD4, 0xEF] do
      assert call(@urdu_kashmiri, :decode, [<<byte>>]) ==
               {:ok, [@lossless_base + byte]}
    end

    for byte <- @invalid_source_cells do
      assert call(@lossless, :decode, [<<byte>>]) ==
               {:error, :invalid_sequence, 0, <<byte>>}
    end
  end

  test "lossless and raw profiles are exhaustive bijections" do
    for byte <- 0x00..0xFF do
      assert call(@raw, :decode, [<<byte>>]) == {:ok, [@raw_base + byte]}
      assert call(@raw, :encode, [[@raw_base + byte]]) == {:ok, <<byte>>}

      unless byte in @invalid_source_cells do
        codepoint = if byte < 0x80, do: byte, else: @lossless_base + byte
        assert call(@lossless, :decode, [<<byte>>]) == {:ok, [codepoint]}
        assert call(@lossless, :encode, [[codepoint]]) == {:ok, <<byte>>}
      end
    end
  end

  test "best-fit reverse mappings use documented longest and lowest-byte policies" do
    assert call(@urdu_kashmiri, :encode, [[0x0699, 0x06BE]]) == {:ok, <<0x9E>>}
    assert call(@sindhi, :encode, [[0x0699, 0x06BE]]) == {:ok, <<0x9E>>}
    assert call(@sindhi, :encode, [[0x0699]]) == {:ok, <<0x9D>>}

    for {codepoint, byte} <- [
          {0x0021, 0x21},
          {0x0028, 0x28},
          {0x0029, 0x29},
          {0x002B, 0x2B},
          {0x002D, 0x2D},
          {0x002F, 0x2F},
          {0x003A, 0x3A},
          {0x003D, 0x3D},
          {0x0654, 0xC2},
          {0x066C, 0xDA},
          {0x06A9, 0xAB}
        ] do
      assert call(@urdu_kashmiri, :encode, [[codepoint]]) == {:ok, <<byte>>}
    end

    assert call(@sindhi, :encode, [[0x06A9]]) == {:ok, <<0xAC>>}
    assert call(@sindhi, :encode, [[0x06AA]]) == {:ok, <<0xAB>>}
  end

  test "the all-scalar corpus proves every encoder key and no accidental extras" do
    corpus = File.read!(@unicode_corpus)
    assert byte_size(corpus) == 1_112_064 * 4

    for {codec, table} <- @profiles do
      expected = single_encoder(table)

      actual =
        for <<codepoint::unsigned-big-32 <- corpus>>,
          reduce: %{} do
          acc ->
            case call(codec, :encode, [[codepoint]]) do
              {:ok, <<byte>>} ->
                Map.put(acc, codepoint, byte)

              {:error, :unrepresentable_character, ^codepoint} ->
                acc

              other ->
                flunk(
                  "unexpected scalar result U+#{Integer.to_string(codepoint, 16)}: #{inspect(other)}"
                )
            end
        end

      assert actual == expected, call(codec, :canonical_name, [])

      for {codepoint, byte} <- expected do
        assert call(codec, :encode_from_utf8, [<<codepoint::utf8>>]) == {:ok, <<byte>>}
      end

      for {{first, second}, byte} <- sequence_encoder(table) do
        codepoints = [first, second]
        assert call(codec, :encode, [codepoints]) == {:ok, <<byte>>}
        assert call(codec, :encode_from_utf8, [List.to_string(codepoints)]) == {:ok, <<byte>>}
      end

      for byte <- 0x00..0xFF do
        case elem(table, byte) do
          nil ->
            assert call(codec, :decode, [<<byte>>]) ==
                     {:error, :invalid_sequence, 0, <<byte>>}

          mapping ->
            decoded = sequence_list(mapping)

            canonical_byte =
              case mapping do
                codepoint when is_integer(codepoint) -> Map.fetch!(expected, codepoint)
                sequence -> Map.fetch!(sequence_encoder(table), sequence)
              end

            assert call(codec, :encode, [decoded]) == {:ok, <<canonical_byte>>}

            assert call(codec, :encode_from_utf8, [List.to_string(decoded)]) ==
                     {:ok, <<canonical_byte>>}
        end
      end
    end
  end

  test "strict, discard, substitution, malformed UTF-8, and first-error precedence are exact" do
    for codec <- @codecs do
      sample = sample(codec)
      {:ok, encoded} = call(codec, :encode_from_utf8, [sample])

      assert call(codec, :decode_discard, [invalid_byte(codec) <> encoded]) ==
               {:ok, String.to_charlist(sample)}

      assert call(codec, :encode_discard, [String.to_charlist(sample) ++ [0x1F642]]) ==
               {:ok, encoded}

      assert call(codec, :encode_substitute, [
               String.to_charlist(sample) ++ [0x1F642],
               fn 0x1F642 -> replacement(codec) end
             ]) == {:ok, encoded <> replacement_bytes(codec)}

      assert call(codec, :encode_from_utf8, [sample <> <<0xFF>>]) ==
               {:decode_error, :invalid_sequence, byte_size(sample), <<0xFF>>}

      assert call(codec, :encode_from_utf8, [<<0x1F642::utf8, 0xFF>>]) ==
               {:error, :unrepresentable_character, 0x1F642}
    end
  end

  test "public one-shot conversion normalizes strict, discard, and substitution policies" do
    for codec <- @codecs do
      canonical = call(codec, :canonical_name, [])
      text = sample(codec)
      {:ok, encoded} = call(codec, :encode_from_utf8, [text])

      assert Iconvex.convert(encoded, canonical, "UTF-8") == {:ok, text}
      assert Iconvex.convert(text, "UTF-8", canonical) == {:ok, encoded}

      assert {:error,
              %Iconvex.Error{
                kind: :unrepresentable_character,
                encoding: ^canonical,
                codepoint: 0x1F642
              }} = Iconvex.convert(text <> <<0x1F642::utf8>>, "UTF-8", canonical)

      assert Iconvex.convert(
               text <> <<0x1F642::utf8>>,
               "UTF-8",
               canonical,
               unrepresentable: :discard
             ) == {:ok, encoded}
    end

    for codec <- [@urdu_kashmiri, @sindhi, @lossless] do
      canonical = call(codec, :canonical_name, [])
      text = sample(codec)
      {:ok, encoded} = call(codec, :encode_from_utf8, [text])

      assert Iconvex.convert(
               text <> <<0x1F642::utf8>>,
               "UTF-8",
               canonical,
               unicode_substitute: "%04X"
             ) == {:ok, encoded <> "1F642"}

      assert {:error,
              %Iconvex.Error{
                kind: :invalid_sequence,
                encoding: ^canonical,
                offset: 0,
                sequence: <<0x80>>
              }} = Iconvex.convert(<<0x80>> <> encoded, canonical, "UTF-8")

      assert Iconvex.convert(<<0x80>> <> encoded, canonical, "UTF-8", invalid: :discard) ==
               {:ok, text}

      assert Iconvex.convert(
               <<0x80>> <> encoded,
               canonical,
               "UTF-8",
               byte_substitute: "<%02x>"
             ) == {:ok, "<80>" <> text}
    end
  end

  test "RHEY prefix semantics survive final, nonmatching, malformed, discard, and substitute streams" do
    urdu = call(@urdu_kashmiri, :canonical_name, [])
    sindhi = call(@sindhi, :canonical_name, [])
    rheh = <<0x0699::utf8>>

    assert call(@urdu_kashmiri, :encode_chunk, [[0x0699], false, :error]) ==
             {:ok, <<>>, [0x0699]}

    assert call(@urdu_kashmiri, :encode_chunk, [[0x0699], true, :error]) ==
             {:error, :unrepresentable_character, 0x0699}

    assert call(@sindhi, :encode_chunk, [[0x0699], true, :error]) == {:ok, <<0x9D>>, []}

    assert_stream_error([rheh], "UTF-8", urdu, :unrepresentable_character, codepoint: 0x0699)

    assert collect_stream([rheh], "UTF-8", sindhi) == <<0x9D>>

    assert_stream_error([rheh, "A"], "UTF-8", urdu, :unrepresentable_character, codepoint: 0x0699)

    assert collect_stream([rheh, "A"], "UTF-8", sindhi) == <<0x9D, ?A>>

    assert_stream_error([rheh, <<0xFF>>], "UTF-8", urdu, :unrepresentable_character,
      codepoint: 0x0699
    )

    same_chunk_malformed = rheh <> <<0xFF>>

    assert {:error,
            %Iconvex.Error{
              kind: :unrepresentable_character,
              encoding: ^urdu,
              codepoint: 0x0699
            }} = Iconvex.convert(same_chunk_malformed, "UTF-8", urdu)

    assert_stream_error([same_chunk_malformed], "UTF-8", urdu, :unrepresentable_character,
      codepoint: 0x0699
    )

    assert_stream_error([rheh, <<0xFF>>], "UTF-8", sindhi, :invalid_sequence,
      offset: byte_size(rheh),
      sequence: <<0xFF>>
    )

    assert collect_stream([rheh], "UTF-8", urdu, unrepresentable: :discard) == <<>>
    assert collect_stream([rheh, "A"], "UTF-8", urdu, unrepresentable: :discard) == "A"

    assert collect_stream([rheh], "UTF-8", urdu, unicode_substitute: "%04X") == "0699"
    assert collect_stream([rheh, "A"], "UTF-8", urdu, unicode_substitute: "%04X") == "0699A"
  end

  test "stateless streaming matches one-shot conversion at every byte and Unicode boundary" do
    for codec <- @codecs do
      canonical = call(codec, :canonical_name, [])
      text = stream_sample(codec)
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

  test "identity, registry, source, package, and transport policies are explicit" do
    expected = [
      {@urdu_kashmiri, "PASCII-CDAC-GIST-1.0-2002-URDU-KASHMIRI-UNICODE17-BEST-FIT"},
      {@sindhi, "PASCII-CDAC-GIST-1.0-2002-SINDHI-UNICODE17-BEST-FIT"},
      {@lossless, "PASCII-CDAC-GIST-1.0-2002-LOSSLESS-VPUA-1"},
      {@raw, "PASCII-CDAC-GIST-1.0-2002-RAW-VPUA-1"}
    ]

    for {codec, canonical} <- expected do
      assert call(codec, :canonical_name, []) == canonical
      refute "PASCII" in call(codec, :aliases, [])
      assert call(codec, :unit_bits, []) == 8
      assert call(codec, :packed_applicability, []) == :not_applicable_octet_codec
      assert call(codec, :gnu_libiconv_support, []) == :unsupported
      assert {:ok, %{codec: ^codec}} = Iconvex.Registry.resolve(canonical)
      assert codec in Iconvex.Specs.additional_codecs()
    end

    assert call(@urdu_kashmiri, :projection_status, []) ==
             :non_normative_unicode_17_best_fit

    assert call(@sindhi, :projection_status, []) == :non_normative_unicode_17_best_fit
    assert call(@lossless, :projection_status, []) == :exact_source_identity_vpua
    assert call(@raw, :projection_status, []) == :forensic_raw_vpua

    assert call(@source_asset, :source_sha256, []) == @source_sha256
    assert call(@source_asset, :mapping_sha256, []) == @mapping_sha256
    assert call(@source_asset, :metadata_sha256, []) == @metadata_sha256
    assert call(@source_asset, :source_size, []) == @source_size
    assert call(@source_asset, :source_pages, []) == %{physical_pdf: 4..7, printed: 61..64}
    assert call(@source_asset, :source_license, []) == :copyrighted_reference_only

    files = Mix.Project.config() |> Keyword.fetch!(:package) |> Keyword.fetch!(:files)
    assert "priv/sources/pascii-cdac-gist-1.0-2002/mapping.csv" in files
    assert "priv/sources/pascii-cdac-gist-1.0-2002/SOURCE_METADATA.md" in files
    refute Enum.any?(files, &String.ends_with?(&1, ".pdf"))
  end

  test "direct native paths remain linear across allocation boundaries" do
    for codec <- @codecs do
      unit = sample(codec)
      small_text = :binary.copy(unit, 4_096)
      large_text = :binary.copy(unit, 8_192)
      {:ok, small} = call(codec, :encode_from_utf8, [small_text])
      {:ok, large} = call(codec, :encode_from_utf8, [large_text])

      assert reductions(fn -> call(codec, :decode_to_utf8, [large]) end) /
               max(reductions(fn -> call(codec, :decode_to_utf8, [small]) end), 1) < 2.60

      assert reductions(fn -> call(codec, :encode_from_utf8, [large_text]) end) /
               max(reductions(fn -> call(codec, :encode_from_utf8, [small_text]) end), 1) < 2.60

      native_decode = reductions(fn -> call(codec, :decode_to_utf8, [large]) end)
      composed_decode = reductions(fn -> reference_decode_to_utf8(codec, large) end)
      native_encode = reductions(fn -> call(codec, :encode_from_utf8, [large_text]) end)
      composed_encode = reductions(fn -> reference_encode_from_utf8(codec, large_text) end)

      assert native_decode / max(composed_decode, 1) <= 1.25
      assert native_encode / max(composed_encode, 1) <= 1.25
    end
  end

  defp call(module, function, arguments), do: apply(module, function, arguments)

  defp sequence_list(value) when is_integer(value), do: [value]
  defp sequence_list(value) when is_tuple(value), do: Tuple.to_list(value)

  defp single_encoder(table) do
    table
    |> Tuple.to_list()
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn
      {codepoint, byte}, acc when is_integer(codepoint) -> Map.put_new(acc, codepoint, byte)
      {_nil_or_sequence, _byte}, acc -> acc
    end)
  end

  defp sequence_encoder(table) do
    table
    |> Tuple.to_list()
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn
      {{first, second}, byte}, acc -> Map.put_new(acc, {first, second}, byte)
      {_nil_or_scalar, _byte}, acc -> acc
    end)
  end

  defp sample(@urdu_kashmiri), do: "A" <> <<0x0627::utf8>>
  defp sample(@sindhi), do: "A" <> <<0x067D::utf8>>
  defp sample(@lossless), do: "A" <> <<@lossless_base + 0x81::utf8>>
  defp sample(@raw), do: <<@raw_base + 0x00::utf8, @raw_base + 0xFF::utf8>>

  defp stream_sample(@urdu_kashmiri), do: sample(@urdu_kashmiri) <> <<0x0699::utf8, 0x06BE::utf8>>
  defp stream_sample(@sindhi), do: sample(@sindhi) <> <<0x0699::utf8, 0x06BE::utf8>>
  defp stream_sample(codec), do: sample(codec)

  defp invalid_byte(@raw), do: <<>>
  defp invalid_byte(_codec), do: <<0x80>>

  defp replacement(@urdu_kashmiri), do: ~c"?"
  defp replacement(@sindhi), do: ~c"?"
  defp replacement(@lossless), do: ~c"?"
  defp replacement(@raw), do: [@raw_base + ?A]

  defp replacement_bytes(@raw), do: <<?A>>
  defp replacement_bytes(_codec), do: "?"

  defp reductions(fun) do
    parent = self()
    token = make_ref()

    {_pid, monitor} =
      spawn_monitor(fn ->
        :erlang.garbage_collect()
        {:reductions, before_count} = Process.info(self(), :reductions)
        _ = fun.()
        {:reductions, after_count} = Process.info(self(), :reductions)
        send(parent, {token, after_count - before_count})
      end)

    receive do
      {^token, count} ->
        receive do
          {:DOWN, ^monitor, :process, _pid, :normal} ->
            count

          {:DOWN, ^monitor, :process, _pid, reason} ->
            flunk("reduction worker failed: #{inspect(reason)}")
        after
          30_000 -> flunk("reduction worker did not terminate")
        end

      {:DOWN, ^monitor, :process, _pid, reason} ->
        flunk("reduction worker failed before reporting: #{inspect(reason)}")
    after
      30_000 -> flunk("reduction worker timed out")
    end
  end

  defp reference_decode_to_utf8(codec, source) do
    case call(codec, :decode, [source]) do
      {:ok, codepoints} -> {:ok, List.to_string(codepoints)}
      error -> error
    end
  end

  defp reference_encode_from_utf8(codec, text),
    do: call(codec, :encode, [String.to_charlist(text)])

  defp collect_stream(chunks, from, to, options \\ []) do
    assert {:ok, stream} = Iconvex.stream(chunks, from, to, options)
    stream |> Enum.to_list() |> IO.iodata_to_binary()
  end

  defp assert_stream_error(chunks, from, to, kind, fields) do
    assert {:ok, stream} = Iconvex.stream(chunks, from, to)

    error =
      assert_raise Iconvex.Error, fn ->
        stream |> Enum.to_list() |> IO.iodata_to_binary()
      end

    assert error.kind == kind

    for {field, expected} <- fields do
      assert Map.fetch!(error, field) == expected
    end
  end

  defp validate(mapping, metadata) do
    call(@source_asset, :validate!, [
      mapping,
      metadata,
      [mapping_sha256: @mapping_sha256, metadata_sha256: @metadata_sha256]
    ])
  end

  defp validate_with_actual_digests(mapping, metadata) do
    call(@source_asset, :validate!, [
      mapping,
      metadata,
      [mapping_sha256: sha256(mapping), metadata_sha256: sha256(metadata)]
    ])
  end

  defp sha256(bytes),
    do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end

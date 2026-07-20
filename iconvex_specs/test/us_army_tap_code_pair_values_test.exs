defmodule Iconvex.Specs.USArmyTapCodePairValuesTest do
  use ExUnit.Case, async: false

  @codec Iconvex.Specs.USArmyTapCodePairValues
  @source Iconvex.Specs.USArmyTapCodePairValues.SourceAsset
  @mapping Path.expand(
             "../priv/sources/us-army-tap-code/pairs.csv",
             __DIR__
           )
  @metadata Path.expand(
              "../priv/sources/us-army-tap-code/SOURCE_METADATA.md",
              __DIR__
            )

  @letters ~c"ABCDEFGHIJLMNOPQRSTUVWXYZ"
  @decode_table List.to_tuple(@letters)
  @encoder @letters
           |> Enum.with_index()
           |> Map.new(fn {codepoint, index} ->
             {codepoint, <<div(index, 5) + 1, rem(index, 5) + 1>>}
           end)
           |> Map.put(?K, <<1, 3>>)

  setup_all do
    {:ok, _started} = Application.ensure_all_started(:iconvex)

    case Iconvex.register_codec_if_absent(@codec) do
      {:ok, token} when is_reference(token) ->
        on_exit(fn -> Iconvex.unregister_codec(@codec, token) end)

      {:ok, :existing} ->
        :ok
    end

    :ok
  end

  test "identity is source and transport qualified without overclaiming variants" do
    assert @codec.canonical_name() == "US-ARMY-GTA-31-70-001-TAP-CODE-PAIR-VALUES"

    assert @codec.aliases() == [
             "US-ARMY-POW-TAP-CODE-PAIR-VALUES",
             "GTA-31-70-001-TAP-CODE-PAIR-VALUES",
             "POW-TAP-CODE-5X5-PAIR-VALUES"
           ]

    for excluded <- [
          "TAP-CODE",
          "KNOCK-CODE",
          "POLYBIUS-SQUARE",
          "TAP-CODE-NUMBERS",
          "TAP-CODE-HAND-LANGUAGE",
          "TAP-CODE-SCRAMBLED-MATRIX"
        ] do
      refute excluded in @codec.aliases()
      assert excluded in @source.excluded_names()
    end
  end

  test "all 65,536 possible octet pairs have exact valid or invalid classification" do
    valid =
      for row <- 0..0xFF,
          column <- 0..0xFF,
          reduce: 0 do
        count ->
          input = <<row, column>>

          if row in 1..5 and column in 1..5 do
            expected = elem(@decode_table, (row - 1) * 5 + column - 1)
            assert @codec.decode(input) == {:ok, [expected]}
            count + 1
          else
            assert @codec.decode(input) == {:error, :invalid_sequence, 0, input}
            count
          end
      end

    assert valid == 25
    assert 65_536 - valid == 65_511
  end

  test "complete matrix is row first, column second, and K encodes canonically as C" do
    source = complete_pair_stream()
    assert byte_size(source) == 50
    assert @codec.decode(source) == {:ok, @letters}
    assert @codec.encode(@letters) == {:ok, source}

    assert @codec.decode(<<1, 3>>) == {:ok, [?C]}
    assert @codec.encode([?C]) == {:ok, <<1, 3>>}
    assert @codec.encode([?K]) == {:ok, <<1, 3>>}
    assert @codec.decode(<<1, 3>>) != {:ok, [?K]}

    assert @codec.decode(<<2, 2, 1, 2, 4, 5>>) == {:ok, ~c"GBU"}
  end

  test "Unicode boundary accepts only uppercase A-Z with lossy K input alias" do
    for codepoint <- ?A..?Z do
      assert @codec.encode([codepoint]) == {:ok, Map.fetch!(@encoder, codepoint)}
    end

    for codepoint <- 0..0x10FFFF,
        codepoint not in 0xD800..0xDFFF,
        not Map.has_key?(@encoder, codepoint) do
      assert @codec.encode([codepoint]) ==
               {:error, :unrepresentable_character, codepoint}
    end

    for rejected <- [?a, ?k, ?\s, ?0, ?., 0x00C9, 0x1F642] do
      assert @codec.encode([rejected]) == {:error, :unrepresentable_character, rejected}
    end
  end

  test "one-shot errors, discard, replacement, and direct UTF-8 callbacks are exact" do
    assert @codec.decode(<<1>>) == {:error, :incomplete_sequence, 0, <<1>>}

    assert @codec.decode(<<1, 1, 0, 1>>) ==
             {:error, :invalid_sequence, 2, <<0, 1>>}

    assert @codec.decode(<<1, 1, 2>>) == {:error, :incomplete_sequence, 2, <<2>>}

    assert @codec.decode_discard(<<1, 1, 0, 0, 1, 2, 6, 1, 5>>) == {:ok, ~c"AB"}
    assert @codec.encode_discard([?A, ?\s, ?K]) == {:ok, <<1, 1, 1, 3>>}

    assert @codec.encode_substitute([?A, ?\s, ?K], fn ?\s -> [?Q] end) ==
             {:ok, <<1, 1, 4, 1, 1, 3>>}

    assert @codec.encode_chunk([?A, ?\s, ?K], false, :discard) ==
             {:ok, <<1, 1, 1, 3>>, []}

    assert @codec.encode_chunk([?A, ?\s, ?K], true, {:replace, fn _ -> [?Q] end}) ==
             {:ok, <<1, 1, 4, 1, 1, 3>>, []}

    source = complete_pair_stream()
    text = List.to_string(@letters)
    assert @codec.decode_to_utf8(source) == {:ok, text}
    assert @codec.encode_from_utf8(text) == {:ok, source}
    assert @codec.encode_from_utf8("CK") == {:ok, <<1, 3, 1, 3>>}
    assert @codec.encode_from_utf8("é") == {:error, :unrepresentable_character, 0x00E9}

    assert @codec.encode_from_utf8(<<"A", 0xC3, 0xA9, 0xFF>>) ==
             {:error, :unrepresentable_character, 0x00E9}

    assert @codec.encode_from_utf8(<<"A", 0xFF, "B">>) ==
             {:decode_error, :invalid_sequence, 1, <<0xFF, "B">>}

    assert @codec.encode_from_utf8(<<"A", 0xE2, 0x82>>) ==
             {:decode_error, :incomplete_sequence, 1, <<0xE2, 0x82>>}
  end

  test "direct decode reports a complete bad pair before any odd trailing count" do
    assert @codec.decode_to_utf8(<<1, 1, 1, 0, 2, 2>>) ==
             {:error, :invalid_sequence, 2, <<1, 0>>}

    assert @codec.decode_to_utf8(<<1, 1, 0, 1, 2>>) ==
             {:error, :invalid_sequence, 2, <<0, 1>>}

    assert @codec.decode_to_utf8(<<1, 1, 0>>) ==
             {:error, :incomplete_sequence, 2, <<0>>}

    assert @codec.decode_to_utf8(<<1, 1, 1>>) ==
             {:error, :incomplete_sequence, 2, <<1>>}
  end

  test "every byte split preserves a pending count and equals one-shot decoding" do
    source = complete_pair_stream()

    for split <- 0..byte_size(source) do
      {left, right} = :erlang.split_binary(source, split)
      {:ok, left_codepoints, pending} = @codec.decode_chunk(left, false)
      assert byte_size(pending) in 0..1
      {:ok, right_codepoints, <<>>} = @codec.decode_chunk(pending <> right, true)
      assert left_codepoints ++ right_codepoints == @letters
    end

    for split <- 0..length(@letters) do
      {left, right} = Enum.split(@letters, split)
      {:ok, left_bytes, []} = @codec.encode_chunk(left, false, :error)
      {:ok, right_bytes, []} = @codec.encode_chunk(right, true, :error)
      assert left_bytes <> right_bytes == source
    end

    assert @codec.decode_chunk(<<1>>, false) == {:ok, [], <<1>>}
    assert @codec.decode_chunk(<<1>>, true) == {:error, :incomplete_sequence, 0, <<1>>}
  end

  test "public recovery consumes one complete pair and emits one callback event" do
    input = <<1, 1, 0, 1, 1, 2>>

    assert @codec.decode(input) == {:error, :invalid_sequence, 2, <<0, 1>>}
    assert @codec.decode_error_consumption(:invalid_sequence, <<0, 1>>) == 2
    assert @codec.decode_error_consumption(:incomplete_sequence, <<1>>) == 1

    assert Iconvex.convert(input, @codec, "UTF-8", invalid: :discard) == {:ok, "AB"}

    assert Iconvex.convert(input, @codec, "UTF-8", byte_substitute: "<%02x>") ==
             {:ok, "A<00><01>B"}

    parent = self()

    handler = fn event ->
      send(parent, {:tap_code_invalid_pair, event})
      :discard
    end

    assert Iconvex.convert(input, @codec, "UTF-8", on_invalid_byte: handler) == {:ok, "AB"}

    assert_receive {:tap_code_invalid_pair,
                    %Iconvex.InvalidByte{
                      encoding: "US-ARMY-GTA-31-70-001-TAP-CODE-PAIR-VALUES",
                      kind: :invalid_sequence,
                      offset: 2,
                      byte: 0,
                      sequence: <<0, 1>>
                    }}

    refute_receive {:tap_code_invalid_pair, _event}

    for options <- [[invalid: :discard], [byte_substitute: "<%02x>"]] do
      expected = if options[:invalid] == :discard, do: "AB", else: "A<00><01>B"

      for split <- 0..byte_size(input) do
        {left, right} = :erlang.split_binary(input, split)
        {:ok, stream} = Iconvex.stream([left, right], @codec, "UTF-8", options)
        assert stream |> Enum.to_list() |> IO.iodata_to_binary() == expected
      end
    end
  end

  test "source assets are exact and reject digest, schema, order, and invariant tampering" do
    mapping = File.read!(@mapping)
    metadata = File.read!(@metadata)

    assert @source.mapping_sha256() == sha256(mapping)
    assert @source.metadata_sha256() == sha256(metadata)

    rows = validate_with_current_digests(mapping, metadata)
    assert length(rows) == 25
    assert Enum.map(rows, & &1.unicode) == @letters

    assert_raise ArgumentError, ~r/mapping SHA-256 mismatch/, fn ->
      @source.validate!(mapping <> "x", metadata,
        mapping_sha256: sha256(mapping),
        metadata_sha256: sha256(metadata)
      )
    end

    wrong_schema =
      String.replace(mapping, "row,column,unicode_hex,letter", "r,c,unicode,name")

    assert_raise ArgumentError, ~r/unexpected Army Tap Code mapping header/, fn ->
      validate_with_current_digests(wrong_schema, metadata)
    end

    reordered = reorder_first_two_rows(mapping)

    assert_raise ArgumentError, ~r/ordered pair 1,1/, fn ->
      validate_with_current_digests(reordered, metadata)
    end

    duplicate = String.replace(mapping, "1,2,0042,B", "1,2,0041,A")

    assert_raise ArgumentError, ~r/25 unique decoded letters/, fn ->
      validate_with_current_digests(duplicate, metadata)
    end

    inserted_k = String.replace(mapping, "1,3,0043,C", "1,3,004B,K")

    assert_raise ArgumentError, ~r/C at pair 1,3 and omit K/, fn ->
      validate_with_current_digests(inserted_k, metadata)
    end

    incomplete_metadata = String.replace(metadata, "scrambled matrices", "other matrices")

    assert_raise ArgumentError, ~r/metadata omits/, fn ->
      @source.validate!(mapping, incomplete_metadata,
        mapping_sha256: sha256(mapping),
        metadata_sha256: sha256(incomplete_metadata)
      )
    end
  end

  test "primary Army card and independent Naval History source are pinned" do
    assert @source.profile_counts() == %{
             decoded_letters: 25,
             encode_inputs: 26,
             valid_pairs: 25,
             invalid_octet_pairs: 65_511
           }

    assert @source.logical_unit() == {:ordered_pair, :tap_counts, 1..5}
    assert @source.storage_unit_bits() == 8
    assert @source.transport_policy() == :project_defined_numeric_count_octets
    assert @source.k_policy() == :encode_k_as_c_decode_c
    assert @source.case_policy() == :uppercase_basic_latin_only
    assert @source.word_boundary_policy() == :not_defined_not_encoded
    assert @source.number_policy() == :excluded_separate_timing_mode
    assert @source.matrix_policy() == :fixed_gta_31_70_001_january_2015
    assert @source.packed_applicability() == :not_a_fixed_width_bit_code
    assert @source.gnu_libiconv_support() == :unsupported

    assert @source.gnu_fixture_sha256(:encodings_extra_def) ==
             "0747ecd7a6311ea3fab734d666e49b17e39750a4ba5d498fee267132461e3303"

    assert @source.source_url(:army_official) ==
             "https://rdl.train.army.mil/catalog-ws/view/100.ATSC/" <>
               "B18B36F6-2596-43BA-B50A-EFC562032BA9-1300757028781/" <>
               "gta31_70_001.pdf"

    assert @source.source_url(:army_2015_artifact) ==
             "https://asktop.net/wp/download/GTA/GTAx31-70-001xv2015x.pdf"

    assert @source.source_sha256(:army_2015_artifact) ==
             "b1ba006ff9150582a6a40dc759ce3d4b21a8aa72f71b678ca80baff13bd75e3d"

    assert @source.source_size(:army_2015_artifact) == 5_069_379
    assert @source.source_page(:army_2015_artifact) == %{physical_pdf: 1, panel: :interior}
    assert @source.source_license(:army_2015_artifact) == :us_government_public_release

    assert @source.source_url(:naval_history_official) ==
             "https://www.history.navy.mil/content/dam/nhhc/research/publications/" <>
               "Publication-PDF/BattleBehindBars.pdf"

    assert @source.source_url(:naval_history_artifact) ==
             "https://md.teyit.org/file/battlebehindbars2.pdf"

    assert @source.source_sha256(:naval_history_artifact) ==
             "bfae22e1f86c310ce67eb12006b70eafea0fa89514c0c88f1212c739e5572735"

    assert @source.source_size(:naval_history_artifact) == 1_986_013

    assert @source.source_page(:naval_history_artifact) == %{
             physical_pdf: 33,
             printed: 27
           }

    assert @source.source_license(:naval_history_artifact) ==
             :us_government_publication_reference_only
  end

  test "direct native paths scale linearly and stay below generic reduction ceiling" do
    alphabet = complete_pair_stream()
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

  defp complete_pair_stream do
    for row <- 1..5, column <- 1..5, into: <<>>, do: <<row, column>>
  end

  defp validate_with_current_digests(mapping, metadata) do
    @source.validate!(mapping, metadata,
      mapping_sha256: sha256(mapping),
      metadata_sha256: sha256(metadata)
    )
  end

  defp reorder_first_two_rows(mapping) do
    [header, first, second | rest] = String.split(mapping, "\n", trim: true)
    Enum.join([header, second, first | rest], "\n") <> "\n"
  end

  defp reference_decode_to_utf8(source) do
    output =
      for <<row, column <- source>>, into: <<>> do
        <<elem(@decode_table, (row - 1) * 5 + column - 1)>>
      end

    {:ok, output}
  end

  defp reference_encode_from_utf8(text) do
    output = text |> :binary.bin_to_list() |> Enum.map(&Map.fetch!(@encoder, &1))
    {:ok, IO.iodata_to_binary(output)}
  end

  defp repeat_to_size(alphabet, size) do
    even_size = size - rem(size, 2)
    copies = div(even_size + byte_size(alphabet) - 1, byte_size(alphabet))
    alphabet |> :binary.copy(copies) |> binary_part(0, even_size)
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

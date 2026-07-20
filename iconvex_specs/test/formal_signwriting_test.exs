defmodule Iconvex.Specs.FormalSignWritingTest do
  use ExUnit.Case, async: false

  @codec Module.concat([Iconvex, Specs, FormalSignWriting])
  @source_dir Path.expand("../priv/sources/formal-signwriting-1.0.0", __DIR__)
  @contract Path.join(@source_dir, "mapping_contract.csv")
  @metadata Path.join(@source_dir, "SOURCE_METADATA.md")
  @exceptions Path.join(@source_dir, "ORACLE_EXCEPTIONS.md")
  @unicode_corpus Path.expand("fixtures/all-unicode-scalars.utf32be", __DIR__)

  @technical_notes_sha "b8a660c6e884a351bf846e8ccfa459e9fa2a3ac4fe0b18546303169a1c306870"
  @technical_paper_sha "8c75daac3229de9c9c297c457bf3fc48c231c84bc4d267a59c1d9ff9a3e4bed0"
  @grammar_notes_sha "bbc5c5b865cc50c30122611956473818116a0b1b1371a92b1d0579deeb1b8dcb"
  @grammar_paper_sha "34e2d7156db91fd3d1ab0e6075c45bf8096c634a6edf6ab98edf723ed2bac75b"
  @archive_sha "ba881a636c08a35c498ed7f9dc3262b6ba3a98918cff88818cddafbfc7079fb9"

  @marker_pairs Enum.zip(~c"ABLMR", Enum.to_list(0x1D800..0x1D804))
  @number_first 0x1D80C
  @number_last 0x1D9FF
  @null 0x40000
  @symbol_first 0x40001
  @symbol_last 0x4F428
  @symbol_count 62_504

  test "RED: the source-bound strict v1.0.0 lexical codec exists" do
    assert Enum.sort(Path.wildcard(Path.join(@source_dir, "*"))) ==
             Enum.sort([@contract, @exceptions, @metadata])

    metadata = File.read!(@metadata)
    exceptions = File.read!(@exceptions)

    for digest <- [
          @technical_notes_sha,
          @technical_paper_sha,
          @grammar_notes_sha,
          @grammar_paper_sha,
          @archive_sha
        ] do
      assert metadata =~ digest
    end

    assert metadata =~ "CC BY 4.0"
    assert metadata =~ "LGPL-2.1-or-later"
    assert metadata =~ "99e0258ed19db56d89099dc43e15fa5c82719983"
    assert metadata =~ "63,010 mappings"
    assert exceptions =~ "S38b08"
    assert exceptions =~ "4F480"
    assert exceptions =~ "not the selected v1.0.0 oracle"
    assert Path.wildcard(Path.join(@source_dir, "*.pdf")) == []
    assert Path.wildcard(Path.join(@source_dir, "*.md")) |> length() == 2

    assert Code.ensure_loaded?(@codec)
    assert call(:canonical_name) == "FSW"

    assert call(:aliases) == [
             "FORMAL-SIGNWRITING-IN-ASCII",
             "FORMAL-SIGNWRITING-ASCII",
             "FSW-ASCII",
             "FSW-2012"
           ]

    refute Enum.any?(call(:aliases), &(&1 in ["SWU", "SGNW", "SIGNWRITING"]))
    assert call(:codec_id) == :formal_signwriting_v1_0_0
    assert call(:source_sha256) == @technical_notes_sha
  end

  test "all 62,504 declared ordinary symbols are exact and bijective" do
    fsw = IO.iodata_to_binary(for id <- 1..@symbol_count, do: fsw_symbol(id))
    expected = Enum.to_list(@symbol_first..@symbol_last)
    expected_utf8 = List.to_string(expected)

    assert byte_size(fsw) == @symbol_count * 6
    assert call(:decode, [fsw]) == {:ok, expected}
    assert call(:decode_to_utf8, [fsw]) == {:ok, expected_utf8}
    assert call(:fsw_to_swu, [fsw]) == {:ok, expected_utf8}
    assert call(:encode, [expected]) == {:ok, fsw}
    assert call(:encode_from_utf8, [expected_utf8]) == {:ok, fsw}
    assert call(:swu_to_fsw, [expected_utf8]) == {:ok, fsw}

    assert fsw_symbol(1) == "S10000"
    assert fsw_symbol(@symbol_count) == "S38b07"
  end

  test "null, five markers, and every one of the 500 numbers are exhaustive" do
    marker_fsw = @marker_pairs |> Enum.map(&elem(&1, 0)) |> :binary.list_to_bin()
    marker_swu = Enum.map(@marker_pairs, &elem(&1, 1))

    assert call(:decode, [marker_fsw]) == {:ok, marker_swu}
    assert call(:encode, [marker_swu]) == {:ok, marker_fsw}
    assert call(:decode, ["S00000"]) == {:ok, [@null]}
    assert call(:encode, [[@null]]) == {:ok, "S00000"}

    fsw = IO.iodata_to_binary(for number <- 250..749, do: coord(number, number))

    expected =
      Enum.flat_map(250..749, fn number ->
        scalar = @number_first + number - 250
        [scalar, scalar]
      end)

    assert call(:decode, [fsw]) == {:ok, expected}
    assert call(:encode, [expected]) == {:ok, fsw}
    assert List.first(expected) == @number_first
    assert List.last(expected) == @number_last
    assert 5 + 500 + 1 + @symbol_count == 63_010
  end

  test "all 250,000 ordered coordinate pairs preserve their two lexical numbers" do
    fsw =
      IO.iodata_to_binary(for first <- 250..749, second <- 250..749, do: coord(first, second))

    expected =
      for first <- 250..749,
          second <- 250..749,
          scalar <- [@number_first + first - 250, @number_first + second - 250],
          do: scalar

    assert byte_size(fsw) == 250_000 * 7
    assert length(expected) == 500_000
    assert call(:decode, [fsw]) == {:ok, expected}
    assert call(:encode, [expected]) == {:ok, fsw}
  end

  test "every lower-hex shaped symbol candidate has the exact declared acceptance set" do
    for base <- 0x000..0x3FF, fill <- 0..15, rotation <- 0..15 do
      token = "S" <> hex(base, 3) <> hex(fill, 1) <> hex(rotation, 1)

      accepted? =
        token == "S00000" or
          (base in 0x100..0x38A and fill in 0..5) or
          (base == 0x38B and fill == 0 and rotation in 0..7)

      assert match?({:ok, [_scalar]}, call(:decode, [token])) == accepted?, token
    end
  end

  test "strict edges reject broader regexes, uppercase hex, and out-of-range coordinates" do
    for invalid <- [
          "S38b08",
          "S38b0f",
          "S38b10",
          "S38b5f",
          "S38c00",
          "S0ff00",
          "S1A000",
          "S10A00",
          "S1000A",
          "S100g0",
          "249x250",
          "250x249",
          "750x250",
          "250x750",
          "250X250"
        ] do
      assert match?({:error, :invalid_sequence, 0, _}, call(:decode, [invalid])), invalid
    end

    assert call(:encode, [[0x4F429]]) ==
             {:error, :unrepresentable_character, 0x4F429}

    for scalar <- [0x1D805, 0x1D80B, 0x4F480, ?A, 0x10FFFF] do
      assert call(:encode, [[scalar]]) ==
               {:error, :unrepresentable_character, scalar}
    end
  end

  test "all 256 lexical start bytes have exactly the reviewed classification" do
    markers = Map.new(@marker_pairs)

    for byte <- 0..255 do
      result = call(:decode, [<<byte>>])

      cond do
        Map.has_key?(markers, byte) ->
          assert result == {:ok, [Map.fetch!(markers, byte)]}

        byte == ?S or byte in ?2..?7 ->
          assert result == {:error, :incomplete_sequence, 0, <<byte>>}

        true ->
          assert match?({:error, :invalid_sequence, 0, _}, result)
      end
    end
  end

  test "every proper token prefix is pending while streaming and incomplete when final" do
    for token <- ["S00000", "S10000", "S38b07", "250x250", "749x749"],
        length <- 1..(byte_size(token) - 1) do
      prefix = binary_part(token, 0, length)
      assert call(:decode_chunk, [prefix, false]) == {:ok, [], prefix}

      assert call(:decode_chunk, [prefix, true]) ==
               {:error, :incomplete_sequence, 0, prefix}
    end

    for scalar <- @number_first..@number_last do
      assert call(:encode_chunk, [[scalar], false, :error]) == {:ok, <<>>, [scalar]}

      assert call(:encode_chunk, [[scalar], true, :error]) ==
               {:error, :unrepresentable_character, scalar}
    end
  end

  test "one-shot and streaming conversion agree at every byte and scalar split" do
    fsw = "AS00000S10000S38b07M250x749S20500500x500"
    {:ok, expected_codepoints} = call(:decode, [fsw])
    {:ok, expected_fsw} = call(:encode, [expected_codepoints])

    for split <- 0..byte_size(fsw) do
      <<left::binary-size(split), right::binary>> = fsw
      assert {:ok, left_out, pending} = call(:decode_chunk, [left, false])
      assert byte_size(pending) <= 6
      assert {:ok, right_out, <<>>} = call(:decode_chunk, [pending <> right, true])
      assert left_out ++ right_out == expected_codepoints
    end

    for split <- 0..length(expected_codepoints) do
      {left, right} = Enum.split(expected_codepoints, split)
      assert {:ok, left_out, pending} = call(:encode_chunk, [left, false, :error])
      assert length(pending) <= 1
      assert {:ok, right_out, []} = call(:encode_chunk, [pending ++ right, true, :error])
      assert left_out <> right_out == expected_fsw
    end
  end

  test "strict, discard, and replacement policies preserve token boundaries" do
    invalid = 0x2603
    n250 = @number_first
    n251 = @number_first + 1
    marker = 0x1D800

    assert call(:decode_discard, ["AS1000ZS10000\xFFB"]) ==
             {:ok, [0x1D800, @symbol_first, 0x1D801]}

    assert call(:encode_discard, [[n250, invalid, n251]]) == {:ok, <<>>}

    assert call(:encode_substitute, [
             [n250, invalid, n251],
             fn _ -> [marker] end
           ]) == {:ok, "AAA"}

    assert call(:encode_substitute, [
             [n250, n251, invalid],
             fn _ -> [n250, n251] end
           ]) == {:ok, "250x251250x251"}

    assert call(:encode_chunk, [[n250, invalid, n251], true, :discard]) ==
             {:ok, <<>>, []}

    assert call(:encode_chunk, [
             [n250, invalid, n251],
             true,
             {:replace, fn _ -> [marker] end}
           ]) == {:ok, "AAA", []}
  end

  test "direct UTF-8 reports the first destination or malformed-source error" do
    marker = <<0x1D800::utf8>>
    invalid_scalar = <<0x2603::utf8>>

    assert call(:encode_from_utf8, [marker <> invalid_scalar <> <<0xFF>>]) ==
             {:error, :unrepresentable_character, 0x2603}

    assert call(:encode_from_utf8, [marker <> <<0xFF, 0x80>>]) ==
             {:decode_error, :invalid_sequence, byte_size(marker), <<0xFF, 0x80>>}

    assert call(:encode_from_utf8, [marker <> <<0xF0, 0x9F>>]) ==
             {:decode_error, :incomplete_sequence, byte_size(marker), <<0xF0, 0x9F>>}

    assert call(:decode_to_utf8, ["S10000!"]) ==
             {:error, :invalid_sequence, 6, "!"}
  end

  test "all Unicode scalars expose exactly the strict single-scalar encoder keys" do
    corpus = File.read!(@unicode_corpus)
    assert byte_size(corpus) == 1_112_064 * 4

    actual =
      for <<scalar::unsigned-big-32 <- corpus>>,
          match?({:ok, _}, call(:encode, [[scalar]])),
          do: scalar

    expected =
      (Enum.map(@marker_pairs, &elem(&1, 1)) ++
         [@null] ++
         Enum.to_list(@symbol_first..@symbol_last))
      |> Enum.sort()

    assert actual == expected

    for scalar <- @number_first..@number_last do
      assert call(:encode, [[scalar]]) ==
               {:error, :unrepresentable_character, scalar}

      assert call(:encode, [[scalar, scalar]]) ==
               {:ok, coord(250 + scalar - @number_first, 250 + scalar - @number_first)}
    end
  end

  test "lexical conversion is deliberately separate from full-sign grammar validation" do
    for lexical <- ["A", "S10000", "250x250", "AB", "S00000"] do
      assert match?({:ok, _}, call(:decode, [lexical]))
      refute call(:valid_sign?, [lexical])
    end

    valid = [
      "B250x250",
      "L749x250S10000250x250",
      "AS00000B500x500",
      "AS00000S10000S38b07M500x500S20500500x500"
    ]

    for sign <- valid do
      assert call(:valid_sign?, [sign]), sign
      assert call(:validate_sign, [sign]) == :ok
    end

    for sign <- [
          "",
          "A",
          "AS00000",
          "AS00000S38b08B500x500",
          "S00000B500x500",
          "B249x250",
          "B500x500S00000500x500",
          "B500x500S10000",
          "B500x500A"
        ] do
      refute call(:valid_sign?, [sign]), sign
      assert match?({:error, :invalid_sign, _, _}, call(:validate_sign, [sign]))
    end
  end

  test "large direct paths are bounded and reduction growth remains linear" do
    unit = "AS10000S38b07M250x749S20500500x500"
    source = :binary.copy(unit, 4_000)
    assert byte_size(source) > 100_000

    assert {:ok, swu} = call(:decode_to_utf8, [source])
    assert {:ok, ^source} = call(:encode_from_utf8, [swu])

    bounded_source = :binary.copy(unit, 32_000)
    assert byte_size(bounded_source) > 1_048_576
    assert {:ok, bounded_swu} = call(:decode_to_utf8, [bounded_source])
    assert {:ok, ^bounded_source} = call(:encode_from_utf8, [bounded_swu])

    assert call(:decode_to_utf8, [bounded_source <> "!"]) ==
             {:error, :invalid_sequence, byte_size(bounded_source), "!"}

    small_decode = reductions(fn -> call(:decode_to_utf8, [:binary.copy(unit, 1_000)]) end)
    large_decode = reductions(fn -> call(:decode_to_utf8, [:binary.copy(unit, 2_000)]) end)

    small_encode =
      reductions(fn -> call(:encode_from_utf8, [binary_part(swu, 0, div(byte_size(swu), 4))]) end)

    large_encode =
      reductions(fn -> call(:encode_from_utf8, [binary_part(swu, 0, div(byte_size(swu), 2))]) end)

    decode_scaling = large_decode / small_decode
    encode_scaling = large_encode / small_encode
    assert decode_scaling >= 1.65 and decode_scaling <= 2.35
    assert encode_scaling >= 1.65 and encode_scaling <= 2.35
  end

  defp call(function, args \\ []), do: apply(@codec, function, args)

  defp coord(x, y),
    do: [Integer.to_string(x), ?x, Integer.to_string(y)] |> IO.iodata_to_binary()

  defp fsw_symbol(id) do
    q = id - 1
    base = 0x100 + div(q, 96)
    remainder = rem(q, 96)
    fill = div(remainder, 16)
    rotation = rem(remainder, 16)

    ["S", hex(base, 3), Integer.to_string(fill), hex(rotation, 1)]
    |> IO.iodata_to_binary()
  end

  defp hex(value, width) do
    value
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(width, "0")
  end

  defp reductions(function) do
    :erlang.garbage_collect()
    {:reductions, before_count} = Process.info(self(), :reductions)
    assert match?({:ok, _}, function.())
    {:reductions, after_count} = Process.info(self(), :reductions)
    after_count - before_count
  end
end

defmodule Iconvex.Specs.KermitJIS7KanjiTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.{ICUJIS7, KermitJIS7Kanji}

  @root Path.expand("..", __DIR__)
  @mapping_path Path.join(@root, "priv/sources/JIS0208.TXT")
  @source_directory Path.join(@root, "priv/sources/kermit-jis7-kanji")
  @kermit_mapping_path Path.join(
                         @root,
                         "priv/sources/dec-terminal-character-sets/kermit/ckcuni.c"
                       )

  @esc 0x1B
  @so 0x0E
  @si 0x0F

  test "publishes only Kermit's exact source-qualified identities" do
    assert KermitJIS7Kanji.canonical_name() == "JIS7-KANJI"
    assert KermitJIS7Kanji.aliases() == ["ISO2022JP-KANJI", "KERMIT-JIS7-KANJI"]
    assert KermitJIS7Kanji.codec_id() == :kermit_jis7_kanji
    assert KermitJIS7Kanji.stateful?()
    assert KermitJIS7Kanji.mapping_count() == 6_879
    assert KermitJIS7Kanji.encoder_mapping_count() == 6_841
    assert KermitJIS7Kanji.representable_count() == 7_029

    refute "ISO-2022-JP" in KermitJIS7Kanji.aliases()
    refute "JIS7" in KermitJIS7Kanji.aliases()
  end

  test "is intentionally not byte/state equivalent to ICU JIS7" do
    # Kermit starts in JIS X 0201 Roman; ICU starts in ASCII.
    assert KermitJIS7Kanji.decode(<<0x5C, 0x7E>>) == {:ok, [0x00A5, 0x203E]}
    assert ICUJIS7.decode(<<0x5C, 0x7E>>) == {:ok, [0x005C, 0x007E]}

    # Kermit preserves Kanji state across line controls; ICU resets G0 at a line.
    input = <<@esc, "$B", 0x24, 0x22, ?\n, 0x24, 0x22>>
    assert KermitJIS7Kanji.decode(input) == {:ok, [0x3042, ?\n, 0x3042]}
    assert ICUJIS7.decode(input) == {:ok, [0x3042, ?\n, 0x24, 0x22]}

    # Kermit returns to JIS Roman, never ICU's terminal ASCII designation.
    assert KermitJIS7Kanji.encode([0x3042]) ==
             {:ok, <<@esc, "$B", 0x24, 0x22, @esc, "(J">>}

    assert ICUJIS7.encode([0x3042]) ==
             {:ok, <<@esc, "$B", 0x24, 0x22, @esc, "(B">>}

    # ICU's wider version-3 profile accepts a GB designation that Kermit does not.
    assert KermitJIS7Kanji.decode(<<@esc, "$A", 0x21, 0x21>>) ==
             {:error, :invalid_sequence, 0, <<@esc, "$A">>}

    assert match?({:ok, [_]}, ICUJIS7.decode(<<@esc, "$A", 0x21, 0x21>>))
  end

  test "decodes all 6,879 mappings and encodes Kermit's exact 6,841-map subset" do
    rows = jis0208_rows()
    assert length(rows) == 6_879
    assert rows |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> length() == 6_879

    {decode_only, bidirectional} =
      Enum.split_with(rows, fn {_pair, codepoint} ->
        codepoint in 0x039D..0x0400 or codepoint in [0xFFE3, 0xFFE5]
      end)

    assert length(decode_only) == 38
    assert length(bidirectional) == 6_841

    for {pair, codepoint} <- rows do
      assert KermitJIS7Kanji.decode(<<@esc, "$B", pair::binary>>) == {:ok, [codepoint]},
             "decode mismatch for #{inspect(pair)} -> U+#{hex(codepoint)}"
    end

    for {pair, codepoint} <- bidirectional do
      assert KermitJIS7Kanji.encode([codepoint]) ==
               {:ok, <<@esc, "$B", pair::binary, @esc, "(J">>},
             "encode mismatch for U+#{hex(codepoint)} -> #{inspect(pair)}"
    end

    for {_pair, codepoint} <- decode_only do
      assert KermitJIS7Kanji.encode([codepoint]) ==
               {:error, :unrepresentable_character, codepoint}
    end
  end

  test "preserves Kermit's two executable Unicode encoder bounds, including asymmetry" do
    source = File.read!(@kermit_mapping_path)

    assert source =~ "if (un <= 0x039c)"
    assert source =~ "if (un <= 0xff9f)"

    # The backing arrays contain these JIS characters, but un_to_sj() cannot
    # reach them because of the exact source bounds above.
    for codepoint <- [0x039D, 0x03A9, 0x03B1, 0x03C9, 0xFFE3, 0xFFE5] do
      assert KermitJIS7Kanji.encode([codepoint]) ==
               {:error, :unrepresentable_character, codepoint}
    end

    assert match?({:ok, _bytes}, KermitJIS7Kanji.encode([0x039C]))
    assert match?({:ok, _bytes}, KermitJIS7Kanji.encode([0xFF9F]))
  end

  test "Kermit's executable Shift-JIS oracle is exactly the pinned JIS table" do
    source = File.read!(@kermit_mapping_path)
    first = c_array(source, "sju_8140")
    second = c_array(source, "sju_e040")

    assert length(first) == 0x9FFC - 0x8140 + 1
    assert length(second) == 0xEAA4 - 0xE040 + 1

    kermit =
      for row <- 0x21..0x7E,
          cell <- 0x21..0x7E,
          shift_jis = jis_to_shift_jis(row, cell),
          codepoint = kermit_shift_jis_to_unicode(shift_jis, first, second),
          codepoint != 0xFFFD,
          into: %{} do
        {<<row, cell>>, codepoint}
      end

    assert kermit == Map.new(jis0208_rows())
  end

  test "covers every Roman and shifted-kana character" do
    roman_input =
      0x00..0x7F
      |> Enum.reject(&(&1 in [@so, @si, @esc]))
      |> :erlang.list_to_binary()

    expected_roman =
      for byte <- :binary.bin_to_list(roman_input) do
        case byte do
          0x5C -> 0x00A5
          0x7E -> 0x203E
          _ -> byte
        end
      end

    assert KermitJIS7Kanji.decode(roman_input) == {:ok, expected_roman}

    for codepoint <- 0x00..0x7F,
        codepoint not in [@so, @si, @esc, 0x5C, 0x7E] do
      assert KermitJIS7Kanji.encode([codepoint]) == {:ok, <<codepoint>>}
    end

    assert KermitJIS7Kanji.encode([0x00A5, 0x203E]) == {:ok, <<0x5C, 0x7E>>}

    assert KermitJIS7Kanji.encode([0x005C]) ==
             {:ok, <<@esc, "$B", 0x21, 0x40, @esc, "(J">>}

    assert KermitJIS7Kanji.encode([0x007E]) ==
             {:error, :unrepresentable_character, 0x007E}

    for control <- [@so, @si, @esc] do
      assert KermitJIS7Kanji.encode([control]) ==
               {:error, :unrepresentable_character, control}
    end

    kana = Enum.to_list(0xFF61..0xFF9F)
    septets = :erlang.list_to_binary(Enum.to_list(0x21..0x5F))
    assert KermitJIS7Kanji.decode(<<@so, septets::binary, @si>>) == {:ok, kana}
    assert KermitJIS7Kanji.encode(kana) == {:ok, <<@so, septets::binary, @si>>}
  end

  test "implements all nine valid encoder state transitions and exact finalizers" do
    cases = [
      {:roman, ?A, <<?A>>, :roman},
      {:roman, 0xFF71, <<@so, 0x31>>, :kana},
      {:roman, 0x3042, <<@esc, "$B", 0x24, 0x22>>, :kanji},
      {:kana, ?A, <<@si, ?A>>, :roman},
      {:kana, 0xFF71, <<0x31>>, :kana},
      {:kana, 0x3042, <<@si, @esc, "$B", 0x24, 0x22>>, :kanji},
      {:kanji, ?A, <<@esc, "(J", ?A>>, :roman},
      {:kanji, 0xFF71, <<@esc, "(J", @so, 0x31>>, :kana},
      {:kanji, 0x3042, <<0x24, 0x22>>, :kanji}
    ]

    for {state, codepoint, output, next_state} <- cases do
      assert KermitJIS7Kanji.encode_chunk([codepoint], state, false, :error) ==
               {:ok, output, next_state, []}
    end

    assert KermitJIS7Kanji.encode_chunk([], :roman, true, :error) ==
             {:ok, <<>>, :roman, []}

    assert KermitJIS7Kanji.encode_chunk([], :kana, true, :error) ==
             {:ok, <<@si>>, :roman, []}

    assert KermitJIS7Kanji.encode_chunk([], :kanji, true, :error) ==
             {:ok, <<@esc, "(J">>, :roman, []}
  end

  test "covers every decoder designation, shift, control, line, and EOF state" do
    controls = Enum.to_list(0x00..0x20) -- [@so, @si, @esc]
    controls = controls ++ [0x7F]

    for state <- [:roman, :kana, :kanji] do
      assert KermitJIS7Kanji.decode_chunk(<<>>, state, true) == {:ok, [], state, <<>>}
      assert KermitJIS7Kanji.decode_chunk(<<@so>>, state, true) == {:ok, [], :kana, <<>>}
      assert KermitJIS7Kanji.decode_chunk(<<@si>>, state, true) == {:ok, [], :roman, <<>>}

      assert KermitJIS7Kanji.decode_chunk(<<@esc, @esc>>, state, true) ==
               {:ok, [], state, <<>>}

      for designation <- [<<@esc, "$@">>, <<@esc, "$B">>] do
        assert KermitJIS7Kanji.decode_chunk(designation, state, true) ==
                 {:ok, [], :kanji, <<>>}
      end

      for designation <- [<<@esc, "(B">>, <<@esc, "(J">>] do
        assert KermitJIS7Kanji.decode_chunk(designation, state, true) ==
                 {:ok, [], :roman, <<>>}
      end

      for control <- controls do
        assert KermitJIS7Kanji.decode_chunk(<<control>>, state, true) ==
                 {:ok, [control], state, <<>>}
      end
    end
  end

  test "accepts exactly Kermit's designations, shifts, doubled escape, and line persistence" do
    assert KermitJIS7Kanji.decode(<<@esc, "$@", 0x24, 0x22>>) == {:ok, [0x3042]}
    assert KermitJIS7Kanji.decode(<<@esc, "$B", 0x24, 0x22>>) == {:ok, [0x3042]}

    assert KermitJIS7Kanji.decode(<<@esc, "(B", 0x5C, 0x7E>>) ==
             {:ok, [0x00A5, 0x203E]}

    assert KermitJIS7Kanji.decode(<<@esc, "(J", 0x5C, 0x7E>>) ==
             {:ok, [0x00A5, 0x203E]}

    assert KermitJIS7Kanji.decode(<<@so, 0x31, @esc, @esc, 0x32, @si>>) ==
             {:ok, [0xFF71, 0xFF72]}

    assert KermitJIS7Kanji.decode(<<@esc, "$B", 0x24, 0x22, ?\r, 0x24, 0x24>>) ==
             {:ok, [0x3042, ?\r, 0x3044]}
  end

  test "reports malformed and incomplete units with exact offsets and widths" do
    cases = [
      {<<0x80>>, {:error, :invalid_sequence, 0, <<0x80>>}},
      {<<?A, @esc, ?X>>, {:error, :invalid_sequence, 1, <<@esc, ?X>>}},
      {<<@esc, ?$, ?A>>, {:error, :invalid_sequence, 0, <<@esc, ?$, ?A>>}},
      {<<@esc, ?(, ?I>>, {:error, :invalid_sequence, 0, <<@esc, ?(, ?I>>}},
      {<<@so, 0x60>>, {:error, :invalid_sequence, 1, <<0x60>>}},
      {<<@esc, "$B", 0x24, 0x20>>, {:error, :invalid_sequence, 3, <<0x24, 0x20>>}},
      {<<@esc, "$B", 0x22, 0x2F>>, {:error, :invalid_sequence, 3, <<0x22, 0x2F>>}},
      {<<@esc>>, {:error, :incomplete_sequence, 0, <<@esc>>}},
      {<<@esc, ?$>>, {:error, :incomplete_sequence, 0, <<@esc, ?$>>}},
      {<<@esc, "$B", 0x24>>, {:error, :incomplete_sequence, 3, <<0x24>>}}
    ]

    for {input, expected} <- cases do
      assert KermitJIS7Kanji.decode(input) == expected
    end

    assert KermitJIS7Kanji.decode_error_consumption(:invalid_sequence, <<0x24, 0x20>>) == 2
    assert KermitJIS7Kanji.decode_error_consumption(:invalid_sequence, <<@esc, ?$, ?A>>) == 3
  end

  test "stream decoder is equivalent at every byte split including escape and pair interiors" do
    input =
      <<?A, @so, 0x31, 0x32, @si, @esc, "$B", 0x24, 0x22, ?\n, 0x24, 0x24, @esc, @esc, @esc, "(J",
        0x5C>>

    assert {:ok, expected} = KermitJIS7Kanji.decode(input)

    for split <- 0..byte_size(input) do
      <<left::binary-size(split), right::binary>> = input
      initial = KermitJIS7Kanji.stream_decoder_init()
      assert {:ok, first, state, pending} = KermitJIS7Kanji.decode_chunk(left, initial, false)

      assert {:ok, second, _state, <<>>} =
               KermitJIS7Kanji.decode_chunk(pending <> right, state, true)

      assert first ++ second == expected, "decode split #{split} diverged"
    end
  end

  test "stream encoder is equivalent at every codepoint split and finalizes only once" do
    codepoints = [?A, 0xFF71, 0xFF72, 0x3042, ?\n, 0x3044, 0x00A5]
    assert {:ok, expected} = KermitJIS7Kanji.encode(codepoints)

    for split <- 0..length(codepoints) do
      {left, right} = Enum.split(codepoints, split)
      initial = KermitJIS7Kanji.stream_encoder_init()

      assert {:ok, first, state, []} =
               KermitJIS7Kanji.encode_chunk(left, initial, false, :error)

      assert {:ok, second, :roman, []} =
               KermitJIS7Kanji.encode_chunk(right, state, true, :error)

      assert first <> second == expected, "encode split #{split} diverged"
    end
  end

  test "discard and replacement policies retain codec state" do
    assert KermitJIS7Kanji.decode_discard(<<@esc, "$B", 0x24, 0x22, 0x22, 0x2F, 0x24, 0x24>>) ==
             {:ok, [0x3042, 0x3044]}

    assert KermitJIS7Kanji.encode_discard([0x3042, 0x10FFFF, 0x3044]) ==
             {:ok, <<@esc, "$B", 0x24, 0x22, 0x24, 0x24, @esc, "(J">>}

    assert KermitJIS7Kanji.encode_substitute(
             [0x3042, 0x10FFFF, ?A],
             fn _ -> [0xFF71] end
           ) ==
             {:ok, <<@esc, "$B", 0x24, 0x22, @esc, "(J", @so, 0x31, @si, ?A>>}

    assert KermitJIS7Kanji.encode_chunk(
             [0x3042, 0x10FFFF, 0x3044],
             :roman,
             true,
             :discard
           ) ==
             {:ok, <<@esc, "$B", 0x24, 0x22, 0x24, 0x24, @esc, "(J">>, :roman, []}

    assert KermitJIS7Kanji.decode_discard(
             <<?A, @esc, ?X, 0x80, @esc, "$B", 0x22, 0x2F, 0x24, 0x22, @esc>>
           ) == {:ok, [?A, 0x3042]}
  end

  @tag timeout: 120_000
  test "classifies every Unicode scalar and no value outside the exact repertoire" do
    representable =
      jis0208_rows()
      |> Enum.map(&elem(&1, 1))
      |> Kernel.++(Enum.to_list(0x00..0x7F))
      |> Kernel.++([0x00A5, 0x203E])
      |> Kernel.++(Enum.to_list(0xFF61..0xFF9F))
      |> MapSet.new()
      |> MapSet.difference(
        MapSet.new([@so, @si, @esc, 0x007E, 0xFFE3, 0xFFE5] ++ Enum.to_list(0x039D..0x0400))
      )

    assert MapSet.size(representable) == 7_029

    mismatch =
      [0x0000..0xD7FF, 0xE000..0x10FFFF]
      |> Enum.reduce_while(nil, fn range, _none ->
        Enum.reduce_while(range, nil, fn codepoint, _none ->
          expected? = MapSet.member?(representable, codepoint)
          actual? = match?({:ok, _bytes}, KermitJIS7Kanji.encode([codepoint]))

          if actual? == expected?,
            do: {:cont, nil},
            else: {:halt, {codepoint, expected?, KermitJIS7Kanji.encode([codepoint])}}
        end)
        |> case do
          nil -> {:cont, nil}
          mismatch -> {:halt, mismatch}
        end
      end)

    assert mismatch == nil
  end

  test "UTF-8 fast paths are strict and preserve byte offsets" do
    assert KermitJIS7Kanji.decode_to_utf8(<<0x5C, @so, 0x31, @si>>) ==
             {:ok, <<0x00A5::utf8, 0xFF71::utf8>>}

    assert KermitJIS7Kanji.encode_from_utf8(<<0x00A5::utf8, 0xFF71::utf8>>) ==
             {:ok, <<0x5C, @so, 0x31, @si>>}

    assert KermitJIS7Kanji.encode_from_utf8(<<0xE3, 0x81>>) ==
             {:decode_error, :incomplete_sequence, 0, <<0xE3, 0x81>>}

    assert KermitJIS7Kanji.encode_from_utf8(<<0xE3, 0x28, 0xA1>>) ==
             {:decode_error, :invalid_sequence, 0, <<0xE3, 0x28, 0xA1>>}
  end

  test "pins the complete Kermit state/mapping source and its separate license" do
    expected = %{
      "ckuxla.c" => "d4e73639659b948d4233431d541d4bd2938f0cae2505a0b00aa3aa52abb44dd0",
      "ckcfns.c" => "e18da89dfa6cdaafd29483722fba7370648526d176cb300037c2fff83fc1942f",
      "ckuxla.h" => "3352daca1cef3d015ad53d64032d49df1a4efac6f3013f8a75b975b4a63f97ee"
    }

    assert KermitJIS7Kanji.source_revision() ==
             "8e977425d2f7f618d14aa466d516e9b79787ffc6"

    assert KermitJIS7Kanji.source_sha256() == expected

    assert KermitJIS7Kanji.mapping_sha256() ==
             "1c571870457f19c97720631fa83ee491549a96ba1436da1296786a67d8632e87"

    assert KermitJIS7Kanji.kermit_mapping_sha256() ==
             "af93d5a1c779aa73fa3221ab5ec0125de20267110cf23395971ce35cc88527ca"

    assert KermitJIS7Kanji.source_license_sha256() ==
             "067b8c8fc98d9359dfbd211820e1d57bed1e173144a184a21e8ead802b6502be"

    for {filename, sha256} <- expected do
      assert digest(Path.join(@source_directory, filename)) == sha256
    end

    assert digest(@mapping_path) == KermitJIS7Kanji.mapping_sha256()
    assert digest(@kermit_mapping_path) == KermitJIS7Kanji.kermit_mapping_sha256()

    assert digest(Path.join(@root, "priv/sources/dec-terminal-character-sets/kermit/COPYING")) ==
             KermitJIS7Kanji.source_license_sha256()
  end

  defp jis0208_rows do
    @mapping_path
    |> File.stream!()
    |> Stream.reject(&String.starts_with?(&1, "#"))
    |> Stream.map(&String.split/1)
    |> Stream.filter(&(length(&1) >= 3))
    |> Enum.map(fn [_shift_jis, jis, unicode | _comment] ->
      <<pair::binary-size(2)>> = hex_binary(jis)
      {pair, hex_integer(unicode)}
    end)
  end

  defp c_array(source, name) do
    expression = ~r/#{Regex.escape(name)}\[\]\s*=\s*\{(.*?)\};/s
    [_, body] = Regex.run(expression, source)
    body = Regex.replace(~r{/\*.*?\*/}s, body, "")

    ~r/0x[0-9a-fA-F]{4}/
    |> Regex.scan(body)
    |> Enum.map(fn [value] -> hex_integer(value) end)
  end

  defp jis_to_shift_jis(row, cell) do
    trail = if Bitwise.band(row, 1) == 1, do: cell + 0x1F, else: cell + 0x7D
    trail = if trail >= 0x7F, do: trail + 1, else: trail
    lead = Bitwise.bsr(row - 0x21, 1) + 0x81
    lead = if lead > 0x9F, do: lead + 0x40, else: lead
    Bitwise.bsl(lead, 8) + trail
  end

  defp kermit_shift_jis_to_unicode(shift_jis, first, _second)
       when shift_jis in 0x8140..0x9FFC,
       do: Enum.at(first, shift_jis - 0x8140)

  defp kermit_shift_jis_to_unicode(shift_jis, _first, second)
       when shift_jis in 0xE040..0xEAA4,
       do: Enum.at(second, shift_jis - 0xE040)

  defp kermit_shift_jis_to_unicode(_shift_jis, _first, _second), do: 0xFFFD

  defp hex_binary(value) do
    integer = hex_integer(value)
    <<Bitwise.bsr(integer, 8), Bitwise.band(integer, 0xFF)>>
  end

  defp hex_integer("0x" <> digits), do: String.to_integer(digits, 16)
  defp hex_integer("0X" <> digits), do: String.to_integer(digits, 16)
  defp hex_integer(digits), do: String.to_integer(digits, 16)

  defp digest(path), do: :crypto.hash(:sha256, File.read!(path)) |> Base.encode16(case: :lower)
  defp hex(codepoint), do: codepoint |> Integer.to_string(16) |> String.upcase()
end

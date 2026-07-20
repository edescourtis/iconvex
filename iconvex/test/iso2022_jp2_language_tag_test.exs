defmodule Iconvex.ISO2022JP2LanguageTagTest do
  use ExUnit.Case, async: false

  alias Iconvex.ISO2022JPCodec

  @entry %{id: :iso2022_jp2}
  @language_tag 0xE0001
  @cancel_tag 0xE007F

  @jis_one <<0x1B, "$B", 0x30, 0x6C, 0x1B, "(B">>
  @ksc_one <<0x1B, "$(C", 0x6C, 0x69, 0x1B, "(B">>
  @gb_one <<0x1B, "$A", 0x52, 0x3B, 0x1B, "(B">>
  @latin1_nbsp <<0x1B, ".A", 0x1B, ?N, 0x20>>

  test "default and completed language tags select GNU's exact U+4E00 preference" do
    for {prefix, expected} <- [
          {[], @jis_one},
          {tag("ja"), @jis_one},
          {tag("JA"), @jis_one},
          {tag("ko"), @ksc_one},
          {tag("Ko"), @ksc_one},
          {tag("zh"), @gb_one},
          {tag("zH"), @gb_one}
        ] do
      assert ISO2022JPCodec.encode(@entry, prefix ++ [0x4E00]) == {:ok, expected}
      assert ISO2022JPCodec.decode(@entry, expected) == {:ok, [0x4E00]}
    end
  end

  test "language parser restarts, cancels, and distinguishes temporary from completed states" do
    assert ISO2022JPCodec.encode(
             @entry,
             tag("ko") ++ [@language_tag] ++ tag_tail("zh") ++ [0x4E00]
           ) ==
             {:ok, @gb_one}

    assert ISO2022JPCodec.encode(@entry, tag("ko") ++ [@cancel_tag, 0x4E00]) ==
             {:ok, @jis_one}

    assert ISO2022JPCodec.encode(@entry, [@language_tag, tag_char(?k), tag_char(?q), 0x4E00]) ==
             {:ok, @jis_one}

    assert ISO2022JPCodec.encode(@entry, tag("ko") ++ [tag_char(?q), 0x4E00]) ==
             {:ok, @ksc_one}

    assert ISO2022JPCodec.encode(@entry, [@language_tag, tag_char(?k), ?A, 0x4E00]) ==
             {:ok, "A" <> @jis_one}

    assert ISO2022JPCodec.encode(@entry, tag("ko") ++ [?A, 0x4E00]) ==
             {:ok, "A" <> @ksc_one}
  end

  test "all tag characters emit nothing and partial language prefixes succeed at EOF" do
    assert ISO2022JPCodec.encode(@entry, Enum.to_list(0xE0000..0xE007F)) == {:ok, <<>>}

    for partial <- [
          [@language_tag],
          [@language_tag, tag_char(?j)],
          [@language_tag, tag_char(?k)],
          [@language_tag, tag_char(?z)]
        ] do
      assert ISO2022JPCodec.encode(@entry, partial) == {:ok, <<>>}
    end
  end

  test "G2 designation is orthogonal to language cancel and newline resets G2 only" do
    assert ISO2022JPCodec.encode(@entry, [0xA0, @cancel_tag, 0xA0]) ==
             {:ok, @latin1_nbsp <> <<0x1B, ?N, 0x20>>}

    assert {:ok, newline_encoded} = ISO2022JPCodec.encode(@entry, [0xA0, ?\n, 0xA0])
    assert newline_encoded == @latin1_nbsp <> <<?\n>> <> @latin1_nbsp
    assert length(:binary.matches(newline_encoded, <<0x1B, ".A">>)) == 2

    assert ISO2022JPCodec.encode(@entry, tag("ko") ++ [0xA0, ?\r, 0x4E00]) ==
             {:ok, @latin1_nbsp <> <<?\r>> <> @ksc_one}
  end

  test "strict, discard, and substitution retain the selected language around failures" do
    input = tag("ko") ++ [0x4E00, 0x110000, 0x4E00]

    assert ISO2022JPCodec.encode(@entry, input) ==
             {:error, :unrepresentable_character, 0x110000}

    assert ISO2022JPCodec.encode_discard(@entry, input) ==
             {:ok, <<0x1B, "$(C", 0x6C, 0x69, 0x6C, 0x69, 0x1B, "(B">>}

    assert {:ok, substituted} =
             ISO2022JPCodec.encode_substitute(@entry, input, fn _ -> [?x] end)

    assert ISO2022JPCodec.decode(@entry, substituted) == {:ok, [0x4E00, ?x, 0x4E00]}
    assert length(:binary.matches(substituted, <<0x1B, "$(C">>)) == 2
  end

  test "public UCS-4BE policies preserve completed language state like GNU" do
    input =
      [@language_tag, tag_char(?k), tag_char(?o), 0x110000, 0x4E00]
      |> Enum.map(&<<&1::32-big>>)
      |> IO.iodata_to_binary()

    assert {:error,
            %Iconvex.Error{
              kind: :unrepresentable_character,
              codepoint: 0x110000
            }} = Iconvex.convert(input, "UCS-4BE", "ISO-2022-JP-2")

    for split <- 0..byte_size(input) do
      <<first::binary-size(split), second::binary>> = input

      error =
        assert_raise Iconvex.Error, fn ->
          [first, second]
          |> Iconvex.stream!("UCS-4BE", "ISO-2022-JP-2")
          |> Enum.join()
        end

      assert error.kind == :unrepresentable_character
      assert error.codepoint == 0x110000
    end

    policies = [
      {[unrepresentable: :discard], @ksc_one},
      {[unicode_substitute: "<U+%04X>"], "<U+110000>" <> @ksc_one}
    ]

    for {options, expected} <- policies do
      assert Iconvex.convert(input, "UCS-4BE", "ISO-2022-JP-2", options) ==
               {:ok, expected}

      for split <- 0..byte_size(input) do
        <<first::binary-size(split), second::binary>> = input

        assert [first, second]
               |> Iconvex.stream!("UCS-4BE", "ISO-2022-JP-2", options)
               |> Enum.join() == expected,
               "#{inspect(options)} UCS-4BE split #{split}"
      end
    end
  end

  test "stream encoder preserves language state per codepoint and across every UTF-8 split" do
    codepoints = tag("zh") ++ [?A, 0x4E00]
    expected = "A" <> @gb_one

    assert stream_codepoints(codepoints) == expected

    utf8 = List.to_string(codepoints)

    for split <- 0..byte_size(utf8) do
      <<first::binary-size(split), second::binary>> = utf8

      assert [first, second]
             |> Iconvex.stream!("UTF-8", "ISO-2022-JP-2")
             |> Enum.join() == expected,
             "UTF-8 split #{split}"
    end
  end

  defp tag(language), do: [@language_tag | tag_tail(language)]

  defp tag_tail(language) do
    language
    |> String.to_charlist()
    |> Enum.map(&tag_char/1)
  end

  defp tag_char(char), do: 0xE0000 + char

  defp stream_codepoints(codepoints) do
    {parts, state} =
      Enum.reduce(codepoints, {[], ISO2022JPCodec.stream_encode_init(@entry)}, fn codepoint,
                                                                                  {parts, state} ->
        assert {:ok, output, next_state, []} =
                 ISO2022JPCodec.encode_chunk(@entry, [codepoint], state, false, :error)

        {[output | parts], next_state}
      end)

    assert {:ok, suffix, _state, []} =
             ISO2022JPCodec.encode_chunk(@entry, [], state, true, :error)

    [Enum.reverse(parts), suffix] |> IO.iodata_to_binary()
  end
end

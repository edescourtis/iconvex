defmodule Iconvex.OptionsAndStreamingTest do
  use ExUnit.Case, async: true

  test "discard policies match GNU suffixes" do
    assert Iconvex.convert(<<"A", 0x81, "B">>, "CP1252", "UTF-8//IGNORE") == {:ok, "AB"}
    assert Iconvex.convert("A😀B", "UTF-8", "ASCII//NON_IDENTICAL_DISCARD") == {:ok, "AB"}

    assert Iconvex.convert(<<"A", 0x81, "B">>, "CP1252", "UTF-8", invalid: :discard) ==
             {:ok, "AB"}

    assert Iconvex.convert("A😀B", "UTF-8", "ASCII", unrepresentable: :discard) ==
             {:ok, "AB"}
  end

  test "GNU transliteration data is applied recursively" do
    input = "Straße € Æ œ © ™ — “x”"
    expected = "Strasse EUR AE oe (c) TM - \"x\""

    assert Iconvex.convert(input, "UTF-8", "ASCII//TRANSLIT") == {:ok, expected}
    assert Iconvex.convert("¼", "UTF-8", "ASCII//TRANSLIT") == {:ok, " 1/4 "}
  end

  test "convert! returns output or raises the typed error" do
    assert Iconvex.convert!("café", "UTF-8", "CP1252") == <<"caf", 0xE9>>

    assert_raise Iconvex.Error, fn ->
      Iconvex.convert!("😀", "UTF-8", "ASCII")
    end
  end

  test "Stream conversion is lazy and emits stable output before EOF" do
    parent = self()

    source =
      ["one", "two"]
      |> Stream.map(fn chunk ->
        send(parent, {:read, chunk})
        chunk
      end)

    stream = Iconvex.stream!(source, "UTF-8", "ASCII")
    refute_received {:read, _chunk}

    assert Enum.take(stream, 1) == ["one"]
    assert_received {:read, "one"}
    refute_received {:read, "two"}
  end

  test "Stream conversion preserves source and target sequences across chunk boundaries" do
    assert <<"caf", 0xE9>> ==
             [<<"caf", 0xC3>>, <<0xA9>>]
             |> Iconvex.stream!("UTF-8", "CP1252")
             |> Enum.join()

    assert ["Ṛ"] =
             [<<0x52>>, <<0xF2>>]
             |> Iconvex.stream!("CP1258", "UTF-8")
             |> Enum.to_list()

    assert <<0x88, 0xA5>> ==
             [<<0x00EA::utf8>>, <<0x030C::utf8>>]
             |> Iconvex.stream!("UTF-8", "BIG5-HKSCS")
             |> Enum.join()
  end

  test "invalid-byte callback can translate, discard, or keep the default policy" do
    parent = self()

    handler = fn event ->
      send(parent, {:invalid_byte, event})
      {:replace, "<#{event.byte}>"}
    end

    assert Iconvex.convert(<<"A", 0x81, "B">>, "CP1252", "UTF-8", on_invalid_byte: handler) ==
             {:ok, "A<129>B"}

    assert_received {:invalid_byte,
                     %Iconvex.InvalidByte{
                       encoding: "CP1252",
                       kind: :invalid_sequence,
                       offset: 1,
                       byte: 0x81,
                       sequence: <<0x81>>
                     }}

    assert Iconvex.convert(<<0x81>>, "CP1252", "UTF-8",
             invalid: :discard,
             on_invalid_byte: fn _event -> :default end
           ) == {:ok, ""}

    assert Iconvex.convert(<<0x81>>, "CP1252", "UTF-8",
             invalid: :discard,
             on_invalid_byte: fn _event -> :error end
           ) ==
             {:error,
              Iconvex.Error.exception(
                kind: :invalid_sequence,
                encoding: "CP1252",
                offset: 0,
                sequence: <<0x81>>
              )}
  end

  test "Stream callback offsets are absolute across chunks" do
    parent = self()

    output =
      ["AB", <<0x81>>, "C"]
      |> Iconvex.stream!("CP1252", "UTF-8",
        on_invalid_byte: fn event ->
          send(parent, {:invalid_byte, event})
          :discard
        end
      )
      |> Enum.join()

    assert output == "ABC"
    assert_received {:invalid_byte, %Iconvex.InvalidByte{offset: 2, byte: 0x81}}
  end

  test "Stream reports malformed trailing input while enumerating" do
    error =
      assert_raise Iconvex.Error, fn ->
        ["ok", <<0xC3>>]
        |> Iconvex.stream!("UTF-8", "UTF-8")
        |> Enum.to_list()
      end

    assert error.kind == :incomplete_sequence
    assert error.offset == 2
    assert error.sequence == <<0xC3>>
  end

  test "Stream carries built-in stateful decoders across every byte split" do
    cases = [
      {"ISO-2022-JP", "ASCII 日本語 ASCII"},
      {"ISO-2022-JP-2", "ASCII 日本語 £ Α ASCII"},
      {"ISO-2022-KR", "ASCII 한국어 ASCII"},
      {"ISO-2022-CN", "ASCII 中文 ASCII"},
      {"HZ", "ASCII 中文 ASCII"},
      {"UTF-7", "ASCII £ 日本 😀 ASCII"}
    ]

    for {encoding, expected} <- cases do
      encoded = Iconvex.convert!(expected, "UTF-8", encoding)

      for split <- 0..byte_size(encoded) do
        <<first::binary-size(split), second::binary>> = encoded

        assert [first, second]
               |> Iconvex.stream!(encoding, "UTF-8")
               |> Enum.join() == expected,
               "#{encoding} split #{split}"
      end
    end
  end

  test "Stream carries designated ISO-2022 single shifts across every byte split" do
    cases = [
      {"ISO-2022-JP-2", <<0x1B, ".A", 0x1B, ?N, 0x21>>, <<0x00A1::utf8>>},
      {"ISO-2022-CN", <<0x1B, "$*H", 0x1B, ?N, 0x21, 0x21>>, <<0x4E42::utf8>>},
      {"ISO-2022-CN-EXT", <<0x1B, "$+I", 0x1B, ?O, 0x21, 0x21>>, <<0x4E28::utf8>>}
    ]

    for {encoding, encoded, expected} <- cases do
      assert Iconvex.convert!(encoded, encoding, "UTF-8") == expected

      for split <- 0..byte_size(encoded) do
        <<first::binary-size(split), second::binary>> = encoded

        assert [first, second]
               |> Iconvex.stream!(encoding, "UTF-8")
               |> Enum.join() == expected,
               "#{encoding} single-shift split #{split}"
      end
    end
  end

  test "designated ISO-2022 single shifts remain strict at EOF and on malformed payloads" do
    for {encoding, incomplete, undesignated, malformed} <- [
          {"ISO-2022-JP-2", <<0x1B, ".A", 0x1B, ?N>>, <<0x1B, ?N, 0x21>>,
           <<0x1B, ".F", 0x1B, ?N, 0x7F>>},
          {"ISO-2022-CN", <<0x1B, "$*H", 0x1B, ?N, 0x21>>, <<0x1B, ?N, 0x21, 0x21>>,
           <<0x1B, "$*H", 0x1B, ?N, 0x00, 0x21>>},
          {"ISO-2022-CN-EXT", <<0x1B, "$+I", 0x1B, ?O, 0x21>>, <<0x1B, ?O, 0x21, 0x21>>,
           <<0x1B, "$+I", 0x1B, ?O, 0x00, 0x21>>}
        ] do
      assert {:error, %Iconvex.Error{kind: :incomplete_sequence}} =
               Iconvex.convert(incomplete, encoding, "UTF-8")

      assert {:error, %Iconvex.Error{kind: :invalid_sequence}} =
               Iconvex.convert(undesignated, encoding, "UTF-8")

      assert {:error, %Iconvex.Error{kind: :invalid_sequence}} =
               Iconvex.convert(malformed, encoding, "UTF-8")
    end
  end

  test "Stream carries built-in stateful encoders across every UTF-8 split" do
    cases = [
      {"ISO-2022-JP", "ASCII 日本語 ASCII"},
      {"ISO-2022-JP-2", "ASCII 日本語 £ Α ASCII"},
      {"ISO-2022-KR", "ASCII 한국어 ASCII"},
      {"ISO-2022-CN", "ASCII 中文 ASCII"},
      {"HZ", "ASCII 中文 ASCII"},
      {"UTF-7", "ASCII £ 日本 😀 ASCII"}
    ]

    for {encoding, input} <- cases do
      expected = Iconvex.convert!(input, "UTF-8", encoding)

      for split <- 0..byte_size(input) do
        <<first::binary-size(split), second::binary>> = input

        assert [first, second]
               |> Iconvex.stream!("UTF-8", encoding)
               |> Enum.join() == expected,
               "#{encoding} split #{split}"
      end
    end
  end

  test "stateful Stream emits before source EOF" do
    parent = self()

    source =
      ["日", "本"]
      |> Stream.map(fn chunk ->
        send(parent, {:read_stateful, chunk})
        chunk
      end)

    assert [_first_output] = source |> Iconvex.stream!("UTF-8", "ISO-2022-JP") |> Enum.take(1)
    assert_received {:read_stateful, "日"}
    refute_received {:read_stateful, "本"}
  end

  test "HZ preserves GNU's literal-tilde encoder quirk in one-shot and Stream conversion" do
    expected = "~{VP~}~~{ND~}"

    assert Iconvex.convert!("中~文", "UTF-8", "HZ") == expected
    assert ["中", "~", "文"] |> Iconvex.stream!("UTF-8", "HZ") |> Enum.join() == expected
  end

  test "Stream carries generic UTF byte order across every byte split" do
    cases = [
      {"UTF-16", <<0xFF, 0xFE, ?A, 0, 0xFE, 0xFF, 0, ?B>>},
      {"UTF-32", <<0xFF, 0xFE, 0, 0, ?A, 0, 0, 0, 0, 0, 0xFE, 0xFF, 0, 0, 0, ?B>>}
    ]

    for {encoding, input} <- cases, split <- 0..byte_size(input) do
      <<first::binary-size(split), second::binary>> = input

      assert [first, second]
             |> Iconvex.stream!(encoding, "UTF-8")
             |> Enum.join() == "AB",
             "#{encoding} split #{split}"
    end
  end

  test "Stream emits one generic UTF BOM across every input split" do
    for {encoding, expected} <- [
          {"UTF-16", <<0xFE, 0xFF, 0, ?A, 0, ?B>>},
          {"UTF-32", <<0, 0, 0xFE, 0xFF, 0, 0, 0, ?A, 0, 0, 0, ?B>>}
        ],
        split <- 0..2 do
      {first, second} = String.split_at("AB", split)

      assert [first, second]
             |> Iconvex.stream!("UTF-8", encoding)
             |> Enum.join() == expected,
             "#{encoding} split #{split}"
    end
  end

  test "streaming preserves incomplete multibyte input across every split" do
    input = String.duplicate("日本語 café 😀", 8)
    {:ok, expected} = Iconvex.convert(input, "UTF-8", "GB18030")

    for split <- 0..byte_size(input) do
      <<first::binary-size(split), second::binary>> = input
      {:ok, converter} = Iconvex.new("UTF-8", "GB18030")
      {:ok, out1, converter} = Iconvex.feed(converter, first)
      {:ok, out2, converter} = Iconvex.feed(converter, second)
      {:ok, out3} = Iconvex.finish(converter)
      assert IO.iodata_to_binary([out1, out2, out3]) == expected
    end
  end

  test "streaming buffers stateful source safely" do
    encoded = File.read!(Path.expand("fixtures/gnu-libiconv-1.19/ISO-2022-JP-snippet", __DIR__))

    utf8 =
      File.read!(Path.expand("fixtures/gnu-libiconv-1.19/ISO-2022-JP-snippet.UTF-8", __DIR__))

    {:ok, converter} = Iconvex.new("ISO-2022-JP", "UTF-8")

    {parts, converter} =
      Enum.reduce(:binary.bin_to_list(encoded), {[], converter}, fn byte, {parts, converter} ->
        {:ok, output, converter} = Iconvex.feed(converter, <<byte>>)
        {[output | parts], converter}
      end)

    {:ok, final} = Iconvex.finish(converter)
    assert IO.iodata_to_binary([Enum.reverse(parts), final]) == utf8
  end
end

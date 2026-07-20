defmodule Iconvex.UpstreamBehaviorTest do
  use ExUnit.Case, async: false

  alias Iconvex.UpstreamFixture

  @fixtures UpstreamFixture.root()

  test "GNU check-translit fixtures" do
    for {file, from, to} <- [
          {"Quotes", "UTF-8", "ISO-8859-1"},
          {"Quotes", "UTF-8", "ASCII"},
          {"Translit1", "ISO-8859-1", "ASCII"}
        ] do
      input = File.read!(Path.join(@fixtures, "#{file}.#{from}"))
      expected = File.read!(Path.join(@fixtures, "#{file}.#{to}"))
      assert Iconvex.convert(input, from, to <> "//TRANSLIT") == {:ok, expected}
    end
  end

  test "GNU check-translitfailure fixture" do
    input = File.read!(Path.join(@fixtures, "TranslitFail1.ISO-8859-1"))

    assert {:error, %Iconvex.Error{kind: :unrepresentable_character}} =
             Iconvex.convert(input, "ISO-8859-1", "ASCII//TRANSLIT")
  end

  test "GNU check-subst byte substitutions" do
    input = "Böse Bübchen\n"

    assert Iconvex.convert(input, "ASCII", "ASCII", byte_substitute: "<0x%02x>") ==
             {:ok, "B<0xc3><0xb6>se B<0xc3><0xbc>bchen\n"}

    assert Iconvex.convert(input, "ASCII", "UTF-8", byte_substitute: "«0x%02x»") ==
             {:ok, "B«0xc3»«0xb6»se B«0xc3»«0xbc»bchen\n"}

    assert {:ok, latin1} =
             Iconvex.convert(input, "ASCII", "ISO-8859-1", byte_substitute: "«0x%02x»")

    assert Iconvex.convert(latin1, "ISO-8859-1", "UTF-8") ==
             {:ok, "B«0xc3»«0xb6»se B«0xc3»«0xbc»bchen\n"}

    assert {:ok, long} =
             Iconvex.convert(input, "ASCII", "ASCII", byte_substitute: "<0x%010000x>")

    c3 = "<0x" <> String.duplicate("0", 9_998) <> "c3>"
    b6 = "<0x" <> String.duplicate("0", 9_998) <> "b6>"
    bc = "<0x" <> String.duplicate("0", 9_998) <> "bc>"
    assert long == "B#{c3}#{b6}se B#{c3}#{bc}bchen\n"
  end

  test "GNU check-subst Unicode substitutions" do
    assert Iconvex.convert("Böse Bübchen\n", "UTF-8", "ASCII", unicode_substitute: "<U+%04X>") ==
             {:ok, "B<U+00F6>se B<U+00FC>bchen\n"}

    assert {:ok, ascii_substituted} =
             Iconvex.convert("Russian (Русский)\n", "UTF-8", "ISO-8859-1",
               unicode_substitute: "<U+%04X>"
             )

    assert Iconvex.convert(ascii_substituted, "ISO-8859-1", "UTF-8") ==
             {:ok, "Russian (<U+0420><U+0443><U+0441><U+0441><U+043A><U+0438><U+0439>)\n"}

    assert {:ok, latin1} =
             Iconvex.convert("Russian (Русский)\n", "UTF-8", "ISO-8859-1",
               unicode_substitute: "«U+%04X»"
             )

    assert Iconvex.convert(latin1, "ISO-8859-1", "UTF-8") ==
             {:ok, "Russian («U+0420»«U+0443»«U+0441»«U+0441»«U+043A»«U+0438»«U+0439»)\n"}

    assert {:ok, long} =
             Iconvex.convert("Böse Bübchen\n", "UTF-8", "ASCII",
               unicode_substitute: "<U+%010000X>"
             )

    f6 = "<U+" <> String.duplicate("0", 9_998) <> "F6>"
    fc = "<U+" <> String.duplicate("0", 9_998) <> "FC>"
    assert long == "B#{f6}se B#{fc}bchen\n"
  end

  test "GNU test-discard suffix combinations" do
    inputs = [<<"3", 0xD4, "℃ß">>, <<"3℃", 0xD4, "ß">>]

    translit_ignore_targets = [
      "ISO-8859-1//IGNORE//TRANSLIT",
      "ISO-8859-1//TRANSLIT//IGNORE",
      "ISO-8859-1//NON_IDENTICAL_DISCARD//IGNORE//TRANSLIT",
      "ISO-8859-1//NON_IDENTICAL_DISCARD//TRANSLIT//IGNORE",
      "ISO-8859-1//IGNORE//NON_IDENTICAL_DISCARD//TRANSLIT",
      "ISO-8859-1//IGNORE//TRANSLIT//NON_IDENTICAL_DISCARD",
      "ISO-8859-1//TRANSLIT//NON_IDENTICAL_DISCARD//IGNORE",
      "ISO-8859-1//TRANSLIT//IGNORE//NON_IDENTICAL_DISCARD"
    ]

    for input <- inputs do
      assert {:error, %Iconvex.Error{}} = Iconvex.convert(input, "UTF-8", "ISO-8859-1")

      assert {:error, %Iconvex.Error{kind: :invalid_sequence}} =
               Iconvex.convert(input, "UTF-8", "ISO-8859-1//TRANSLIT")

      assert Iconvex.convert(input, "UTF-8", "ISO-8859-1//IGNORE") == {:ok, <<"3", 0xDF>>}

      assert Iconvex.convert(input, "UTF-8", "ISO-8859-1",
               invalid: :discard,
               unrepresentable: :discard
             ) == {:ok, <<"3", 0xDF>>}

      assert {:error, %Iconvex.Error{kind: :invalid_sequence}} =
               Iconvex.convert(input, "UTF-8", "ISO-8859-1//NON_IDENTICAL_DISCARD")

      assert {:error, %Iconvex.Error{kind: :invalid_sequence}} =
               Iconvex.convert(
                 input,
                 "UTF-8",
                 "ISO-8859-1//NON_IDENTICAL_DISCARD//TRANSLIT"
               )

      for target <- translit_ignore_targets do
        assert Iconvex.convert(input, "UTF-8", target) == {:ok, <<"3", 0xB0, "C", 0xDF>>}
      end

      assert Iconvex.convert(input, "UTF-8", "ISO-8859-1",
               invalid: :discard,
               transliterate: true
             ) == {:ok, <<"3", 0xB0, "C", 0xDF>>}
    end
  end

  test "GNU test-shiftseq malformed UTF-7 has stable error position" do
    assert {:error, %Iconvex.Error{kind: :invalid_sequence, offset: 1}} =
             Iconvex.convert("+2D/YQNhB", "UTF-7", "UTF-8")

    assert {:ok, converter} = Iconvex.new("UTF-7", "UTF-8")
    assert {:ok, <<>>, converter} = Iconvex.feed(converter, "+2D/Y")

    assert {:error, %Iconvex.Error{kind: :invalid_sequence, offset: 1}} =
             Iconvex.finish(%{converter | pending: "+2D/YQNhB"})
  end

  test "GNU test-to-wchar incomplete UTF-8 equivalent" do
    assert {:error, %Iconvex.Error{kind: :incomplete_sequence, offset: 0}} =
             Iconvex.convert(<<0xC2>>, "UTF-8", "UCS-4-INTERNAL")
  end

  test "GNU test-bom-state byte order survives chunk boundaries" do
    for {encoding, inputs, split} <- [
          {"UCS-2",
           [<<0xFE, 0xFF, 0x25, 0x26, 0x26, 0x29>>, <<0xFF, 0xFE, 0x26, 0x25, 0x29, 0x26>>], 4},
          {"UTF-16",
           [<<0xFE, 0xFF, 0x25, 0x26, 0x26, 0x29>>, <<0xFF, 0xFE, 0x26, 0x25, 0x29, 0x26>>], 4},
          {"UCS-4",
           [
             <<0, 0, 0xFE, 0xFF, 0, 0, 0x25, 0x26, 0, 0, 0x26, 0x29>>,
             <<0xFF, 0xFE, 0, 0, 0x26, 0x25, 0, 0, 0x29, 0x26, 0, 0>>
           ], 8},
          {"UTF-32",
           [
             <<0, 0, 0xFE, 0xFF, 0, 0, 0x25, 0x26, 0, 0, 0x26, 0x29>>,
             <<0xFF, 0xFE, 0, 0, 0x26, 0x25, 0, 0, 0x29, 0x26, 0, 0>>
           ], 8}
        ],
        input <- inputs do
      <<first::binary-size(split), second::binary>> = input
      assert {:ok, converter} = Iconvex.new(encoding, "UTF-8")
      assert {:ok, out1, converter} = Iconvex.feed(converter, first)
      assert {:ok, out2, converter} = Iconvex.feed(converter, second)
      assert {:ok, out3} = Iconvex.finish(converter)
      assert IO.iodata_to_binary([out1, out2, out3]) == "┦☩"
    end
  end
end

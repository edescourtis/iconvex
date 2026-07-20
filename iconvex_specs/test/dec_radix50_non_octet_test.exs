defmodule Iconvex.Specs.DECRadix50NonOctetTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.{
    DECRadix50PDP10,
    DECRadix50PDP10BE40,
    DECRadix50PDP10LE40,
    DECRadix50PDP9,
    DECRadix50PDP9BE24,
    DECRadix50PDP9LE24
  }

  @source_directory Path.expand("../priv/sources/dec-radix-50", __DIR__)

  @pdp10_source_path Path.join(
                       @source_directory,
                       "AA-C780C-TB_Macro_Assembler_Reference_Manual_Apr78.pdf"
                     )

  @pdp9_source_path Path.join(@source_directory, "DEC-9A-GUAB-D_UTILITIES.pdf")
  @pdp10_sha256 "4034751a6807f29fc447550139432adbb19e796e51885fb5eefbbf1a0eeb2df0"
  @pdp9_sha256 "48391ddbd4919a86c6f1d648573d2d44f6ddf1bdb81c987880383f7a8c339e28"
  @pdp10_alphabet String.to_charlist(" 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ.$%")
  @pdp9_alphabet [0x20] ++ Enum.to_list(?A..?Z) ++ [?%, ?.] ++ Enum.to_list(?0..?9) ++ [?#]

  test "RED: pins both normative non-octet DEC manuals and pages" do
    assert sha256(File.read!(@pdp10_source_path)) == @pdp10_sha256
    assert DECRadix50PDP10.source_pages() == [86, 165, 166, 167]
    assert DECRadix50PDP10.printed_source_pages() == ["3-56", "A-1", "A-2", "A-3"]
    assert DECRadix50PDP10.unit_bits() == 36

    assert sha256(File.read!(@pdp9_source_path)) == @pdp9_sha256
    assert DECRadix50PDP9.source_page() == 133
    assert DECRadix50PDP9.printed_source_page() == "A1-1"
    assert DECRadix50PDP9.unit_bits() == 18
  end

  test "covers every PDP-10 digit in all six positions and the official SYMBOL vector" do
    for {character, digit} <- Enum.with_index(@pdp10_alphabet), position <- 0..5 do
      expected = List.replace_at(~c"      ", position, character)
      digits = List.replace_at([0, 0, 0, 0, 0, 0], position, digit)
      value = Enum.reduce(digits, 0, &(&2 * 40 + &1))

      assert DECRadix50PDP10.pack_value(expected) == {:ok, value}
      assert DECRadix50PDP10.unpack_value(value) == {:ok, expected}
    end

    assert DECRadix50PDP10.pack_value(~c"SYMBOL") == {:ok, 0o26633472376}
    assert DECRadix50PDP10.pack_word(~c"SYMBOL", 2) == {:ok, 0o126633472376}
    assert DECRadix50PDP10.unpack_word(0o126633472376) == {:ok, 2, ~c"SYMBOL"}
  end

  test "PDP-10 exposes exact 36-bit words and explicit 40-bit byte transports" do
    assert DECRadix50PDP10.encode_packed(~c"SYMBOL") ==
             {:ok, <<0::4, 0o26633472376::32>>}

    assert DECRadix50PDP10.decode_packed(<<0::4, 0o26633472376::32>>) ==
             {:ok, ~c"SYMBOL"}

    assert DECRadix50PDP10BE40.encode(~c"SYMBOL") ==
             {:ok, <<0::4, 0::4, 0o26633472376::32>>}

    value = 0o26633472376
    assert DECRadix50PDP10LE40.encode(~c"SYMBOL") == {:ok, <<value::40-little>>}
    assert DECRadix50PDP10BE40.decode(<<0::4, 0::4, value::32>>) == {:ok, ~c"SYMBOL"}
    assert DECRadix50PDP10LE40.decode(<<value::40-little>>) == {:ok, ~c"SYMBOL"}
    assert DECRadix50PDP10BE40.encode(~c"A") == DECRadix50PDP10BE40.encode(~c"A     ")
  end

  test "PDP-10 strictly rejects metadata tags, overflow, padding, and partial words" do
    assert DECRadix50PDP10.decode_packed(<<1::4, 0::32>>) ==
             {:error, :invalid_sequence, 0, <<1::4, 0::32>>}

    assert DECRadix50PDP10.decode_packed(<<1::7>>) ==
             {:error, :incomplete_sequence, 0, <<1::7>>}

    assert DECRadix50PDP10BE40.decode(<<1::4, 0::36>>) ==
             {:error, :invalid_sequence, 0, <<1::4, 0::36>>}

    overflow = 4_096_000_000

    assert DECRadix50PDP10BE40.decode(<<0::8, overflow::32>>) ==
             {:error, :invalid_sequence, 0, <<0::8, overflow::32>>}

    assert DECRadix50PDP10LE40.decode(<<1, 2>>) ==
             {:error, :incomplete_sequence, 0, <<1, 2>>}

    assert DECRadix50PDP10LE40.decode(<<0, 0, 0, 0, 0x10>>) ==
             {:error, :invalid_sequence, 0, <<0, 0, 0, 0, 0x10>>}
  end

  test "covers every PDP-9 digit in all three positions and the official SYMNAM vector" do
    for {character, digit} <- Enum.with_index(@pdp9_alphabet), position <- 0..2 do
      expected = List.replace_at(~c"   ", position, character)
      digits = List.replace_at([0, 0, 0], position, digit)
      value = Enum.reduce(digits, 0, &(&2 * 40 + &1))

      assert DECRadix50PDP9.pack_value(expected) == {:ok, value}
      assert DECRadix50PDP9.unpack_value(value) == {:ok, expected}
    end

    assert DECRadix50PDP9.pack_symbol(~c"SYMNAM") ==
             {:ok, <<0o475265::18, 0o053665::18>>}

    assert DECRadix50PDP9.unpack_word(0o475265) == {:ok, 2, ~c"SYM"}
    assert DECRadix50PDP9.unpack_word(0o053665) == {:ok, 0, ~c"NAM"}
  end

  test "PDP-9 exposes exact 18-bit words and explicit 24-bit byte transports" do
    assert DECRadix50PDP9.encode_packed(~c"SYM") == {:ok, <<0::2, 0o075265::16>>}
    assert DECRadix50PDP9.decode_packed(<<0::2, 0o075265::16>>) == {:ok, ~c"SYM"}
    assert DECRadix50PDP9BE24.encode(~c"SYM") == {:ok, <<0::6, 0::2, 0o075265::16>>}
    assert DECRadix50PDP9LE24.encode(~c"SYM") == {:ok, <<0o075265::24-little>>}
    assert DECRadix50PDP9BE24.decode(<<0::8, 0o075265::16>>) == {:ok, ~c"SYM"}
    assert DECRadix50PDP9LE24.decode(<<0o075265::24-little>>) == {:ok, ~c"SYM"}
  end

  test "PDP-9 strictly rejects classification, padding, and partial words" do
    assert DECRadix50PDP9.decode_packed(<<1::2, 0::16>>) ==
             {:error, :invalid_sequence, 0, <<1::2, 0::16>>}

    assert DECRadix50PDP9.decode_packed(<<1::17>>) ==
             {:error, :incomplete_sequence, 0, <<1::17>>}

    assert DECRadix50PDP9BE24.decode(<<1::6, 0::18>>) ==
             {:error, :invalid_sequence, 0, <<1::6, 0::18>>}

    assert DECRadix50PDP9LE24.decode(<<1>>) ==
             {:error, :incomplete_sequence, 0, <<1>>}

    assert DECRadix50PDP9LE24.decode(<<0, 0, 4>>) ==
             {:error, :invalid_sequence, 0, <<0, 0, 4>>}
  end

  test "all byte transports cover discard, direct UTF-8, and registry conversion" do
    for codec <- [
          DECRadix50PDP10BE40,
          DECRadix50PDP10LE40,
          DECRadix50PDP9BE24,
          DECRadix50PDP9LE24
        ] do
      text = if codec in [DECRadix50PDP10BE40, DECRadix50PDP10LE40], do: "SYMBOL", else: "SYM"
      invalid_size = if byte_size(text) == 6, do: 5, else: 3
      invalid = :binary.copy(<<0xFF>>, invalid_size)

      assert {:ok, encoded} = codec.encode_from_utf8(text)
      assert codec.decode_to_utf8(encoded) == {:ok, text}
      assert codec.encode_discard([?S, 0x2603, ?Y, ?M]) == codec.encode(~c"SYM")
      assert codec.decode_discard(invalid <> encoded) == {:ok, String.to_charlist(text)}
      assert Iconvex.convert(text, "UTF-8", codec.canonical_name()) == {:ok, encoded}
      assert Iconvex.convert(encoded, codec.canonical_name(), "UTF-8") == {:ok, text}
      assert codec.encode_from_utf8("S") == codec.encode([?S])
      assert codec.encode_from_utf8("☃") == {:error, :unrepresentable_character, 0x2603}

      assert codec.encode_from_utf8(<<0xFF>>) ==
               {:decode_error, :invalid_sequence, 0, <<0xFF>>}
    end
  end

  test "all endian word transports preserve UTF-8 first-error ordering" do
    earlier_unrepresentable = <<0x2603::utf8, 0xFF>>

    for codec <- [
          DECRadix50PDP10BE40,
          DECRadix50PDP10LE40,
          DECRadix50PDP9BE24,
          DECRadix50PDP9LE24
        ] do
      assert codec.encode_from_utf8(earlier_unrepresentable) ==
               {:error, :unrepresentable_character, 0x2603}

      assert {:error,
              %Iconvex.Error{
                kind: :unrepresentable_character,
                encoding: encoding,
                codepoint: 0x2603
              }} = Iconvex.convert(earlier_unrepresentable, "UTF-8", codec.canonical_name())

      assert encoding == codec.canonical_name()

      assert codec.encode_from_utf8(<<?A, 0xFF>>) ==
               {:decode_error, :invalid_sequence, 1, <<0xFF>>}
    end
  end

  test "registers all four byte transports and inventories both exact packed formats" do
    assert DECRadix50PDP10.transport_codecs() == [DECRadix50PDP10BE40, DECRadix50PDP10LE40]
    assert DECRadix50PDP9.transport_codecs() == [DECRadix50PDP9BE24, DECRadix50PDP9LE24]
    assert Iconvex.canonical_name("PDP-10-RADIX-50") == {:ok, "DEC-RADIX-50-36BIT-40BE"}
    assert Iconvex.canonical_name("PDP-15-RADIX-50-LE") == {:ok, "DEC-RADIX-50-18BIT-24LE"}

    assert Iconvex.Specs.non_octet_encodings() ==
             [
               "DEC-RADIX-50-18BIT",
               "DEC-RADIX-50-36BIT",
               "UTF-18",
               "UTF-9",
               "IBM-7040-H-REPORT",
               "IBM-7040-H-PROGRAM",
               "IBM-1401-CARD",
               "CDC-167-BCD-HOLLERITH-1965",
               "CDC-6000-STANDARD-HOLLERITH-1970",
               "BCD-CDC-IOWA",
               "IBM-029-CARD-IOWA-824E61A9",
               "DEC-026-CARD-IOWA-824E61A9",
               "DEC-029-CARD-IOWA-824E61A9",
               "EBCD-CARD-IOWA-824E61A9",
               "GE-600-CARD-IOWA-824E61A9",
               "IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-A",
               "IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-B",
               "IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-C",
               "IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-D",
               "IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-E",
               "IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-F",
               "IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-G",
               "IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-H",
               "IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-J",
               "IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-K"
             ]
  end

  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end

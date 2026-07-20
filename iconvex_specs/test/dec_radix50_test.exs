defmodule Iconvex.Specs.DECRadix50Test do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.{DECRadix50, DECRadix50BE16, DECRadix50LE16}

  @source_path Path.expand(
                 "../priv/sources/dec-radix-50/DEC-11-LFLRA_FORTRAN_Language_Reference_Manual_Jun77.pdf",
                 __DIR__
               )
  @source_sha256 "4f8ad8bc9f838f051d45f3c9560f7df09c2bd49142f484c13739d7d57ee57625"
  @alphabet [0x20] ++ Enum.to_list(?A..?Z) ++ [?$, ?.] ++ Enum.to_list(?0..?9)
  @codes Enum.to_list(0..28) ++ Enum.to_list(30..39)

  test "RED: pins DEC's complete PDP-11 RADIX-50 table and formula" do
    assert sha256(File.read!(@source_path)) == @source_sha256
    assert DECRadix50.source_page() == 145
    assert DECRadix50.printed_source_page() == "A-3"
    assert DECRadix50.word_bits() == 16
    assert DECRadix50.radix() == 40
    assert DECRadix50.characters_per_word() == 3
    assert String.starts_with?(DECRadix50.source_url(), "https://www.bitsavers.org/")
  end

  test "covers every assigned digit in every word position" do
    for {character, code} <- Enum.zip(@alphabet, @codes), position <- 0..2 do
      digits = List.replace_at([0, 0, 0], position, code)
      word = DECRadix50.pack_digits(digits)
      expected = List.replace_at(~c"   ", position, character)

      assert DECRadix50.unpack_word(word) == {:ok, expected}
      assert DECRadix50.pack_codepoints(expected) == {:ok, word}
    end
  end

  test "exhausts the entire 16-bit word space" do
    for word <- 0..0xFFFF do
      first = div(word, 1_600)
      remainder = rem(word, 1_600)
      second = div(remainder, 40)
      third = rem(remainder, 40)
      valid? = word < 64_000 and 29 not in [first, second, third]

      case DECRadix50.unpack_word(word) do
        {:ok, codepoints} ->
          assert valid?
          assert DECRadix50.pack_codepoints(codepoints) == {:ok, word}
          assert DECRadix50BE16.decode(<<word::16-big>>) == {:ok, codepoints}
          assert DECRadix50LE16.decode(<<word::16-little>>) == {:ok, codepoints}

        {:error, _reason} ->
          refute valid?
      end
    end
  end

  test "matches DEC's published X2B example and pads short final words" do
    assert DECRadix50.pack_codepoints(~c"X2B") == {:ok, 0o115402}
    assert DECRadix50.unpack_word(0o115402) == {:ok, ~c"X2B"}

    assert DECRadix50LE16.encode(~c"X2B") == {:ok, <<0o115402::16-little>>}
    assert DECRadix50BE16.encode(~c"X2B") == {:ok, <<0o115402::16-big>>}
    assert DECRadix50LE16.decode(<<0o115402::16-little>>) == {:ok, ~c"X2B"}
    assert DECRadix50BE16.decode(<<0o115402::16-big>>) == {:ok, ~c"X2B"}

    assert DECRadix50LE16.encode(~c"A") == {:ok, <<1_600::16-little>>}
    assert DECRadix50BE16.encode(~c"AB") == {:ok, <<1_680::16-big>>}
    assert DECRadix50BE16.decode(<<1_680::16-big>>) == {:ok, ~c"AB "}
  end

  test "rejects the unassigned digit, out-of-range words, and partial words" do
    invalid_words = [29 * 1_600, 29 * 40, 29, 64_000]

    for word <- invalid_words do
      assert DECRadix50BE16.decode(<<word::16-big>>) ==
               {:error, :invalid_sequence, 0, <<word::16-big>>}

      assert DECRadix50LE16.decode(<<word::16-little>>) ==
               {:error, :invalid_sequence, 0, <<word::16-little>>}
    end

    assert DECRadix50BE16.decode(<<0::16-big, 1>>) ==
             {:error, :incomplete_sequence, 2, <<1>>}

    invalid_after_prefix = <<0::16-big, 64_000::16-big>>

    assert DECRadix50BE16.decode(invalid_after_prefix) ==
             {:error, :invalid_sequence, 2, <<64_000::16-big>>}

    assert DECRadix50BE16.decode_to_utf8(invalid_after_prefix) ==
             {:error, :invalid_sequence, 2, <<64_000::16-big>>}

    assert DECRadix50LE16.encode([?A, 0x2603]) ==
             {:error, :unrepresentable_character, 0x2603}

    assert DECRadix50.pack_codepoints(~c"ABCD") == {:error, :too_many_characters}
  end

  test "discard and direct UTF-8 paths preserve word framing" do
    valid_be = <<DECRadix50.pack_digits([1, 2, 3])::16-big>>
    invalid_be = <<DECRadix50.pack_digits([29, 0, 0])::16-big>>

    assert DECRadix50BE16.decode_discard(valid_be <> invalid_be <> <<1>>) == {:ok, ~c"ABC"}
    assert DECRadix50LE16.encode_discard([?A, 0x2603, ?B]) == {:ok, <<1_680::16-little>>}
    assert DECRadix50LE16.encode_discard([0x2603]) == {:ok, <<>>}
    assert DECRadix50BE16.decode_to_utf8(valid_be) == {:ok, "ABC"}
    assert DECRadix50LE16.encode_from_utf8("X2B") == {:ok, <<0o115402::16-little>>}

    assert DECRadix50BE16.encode_from_utf8("Aé") ==
             {:error, :unrepresentable_character, ?é}

    assert DECRadix50LE16.encode_from_utf8(<<?A, 0xFF>>) ==
             {:decode_error, :invalid_sequence, 1, <<0xFF>>}
  end

  test "registers explicit endian transports and makes PDP-11 little-endian unqualified" do
    assert DECRadix50.transport_codecs() == [DECRadix50BE16, DECRadix50LE16]
    assert Iconvex.canonical_name("DEC-RADIX-50") == {:ok, "DEC-RADIX-50-16LE"}
    assert Iconvex.canonical_name("DEC-RADIX-50-BE") == {:ok, "DEC-RADIX-50-16BE"}
    assert Iconvex.canonical_name("PDP-11-RAD50") == {:ok, "DEC-RADIX-50-16LE"}

    assert Iconvex.convert(<<0o115402::16-little>>, "DEC-RADIX-50", "UTF-8") ==
             {:ok, "X2B"}

    assert Iconvex.convert("X2B", "UTF-8", "DEC-RADIX-50-BE") ==
             {:ok, <<0o115402::16-big>>}
  end

  test "direct UTF-8 paths cross internal allocation chunks exactly" do
    utf8 = :binary.copy("ABC", 1_025)

    for codec <- [DECRadix50BE16, DECRadix50LE16] do
      assert {:ok, packed} = codec.encode_from_utf8(utf8)
      assert byte_size(packed) == 2_050
      assert codec.decode_to_utf8(packed) == {:ok, utf8}
    end
  end

  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end

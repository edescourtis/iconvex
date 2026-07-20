defmodule Iconvex.Specs.UTF18Test do
  use ExUnit.Case, async: false

  @vectors [
    {0x0041, 0o000101},
    {0x00C0, 0o000300},
    {0x0391, 0o001621},
    {0x611B, 0o060433},
    {0x10330, 0o201460},
    {0xE0041, 0o600101}
  ]

  test "RED: RFC 4042 vectors are exact 18-bit values" do
    for {codepoint, value} <- @vectors do
      assert Iconvex.Specs.UTF18.encode_packed([codepoint]) == {:ok, <<value::18>>}
      assert Iconvex.Specs.UTF18.decode_packed(<<value::18>>) == {:ok, [codepoint]}

      for {codec, endian} <- [
            {Iconvex.Specs.UTF18BE24, :big},
            {Iconvex.Specs.UTF18LE24, :little}
          ] do
        assert codec.encode([codepoint]) == {:ok, word(value, endian)}
        assert codec.decode(word(value, endian)) == {:ok, [codepoint]}
      end
    end
  end

  test "packed form preserves exact non-byte-aligned length" do
    assert {:ok, packed} = Iconvex.Specs.UTF18.encode_packed([?A, 0x10330, 0xE0041])
    assert bit_size(packed) == 54
    refute is_binary(packed)
    assert Iconvex.Specs.UTF18.decode_packed(packed) == {:ok, [?A, 0x10330, 0xE0041]}
  end

  test "every RFC-representable Unicode scalar round-trips through all transports" do
    [0..0x2FFFF, 0xE0000..0xEFFFF]
    |> Stream.concat()
    |> Stream.reject(&(&1 in 0xD800..0xDFFF))
    |> Stream.chunk_every(4_096)
    |> Enum.each(fn scalars ->
      assert {:ok, packed} = Iconvex.Specs.UTF18.encode_packed(scalars)
      assert Iconvex.Specs.UTF18.decode_packed(packed) == {:ok, scalars}

      assert {:ok, big} = Iconvex.Specs.UTF18BE24.encode(scalars)
      assert Iconvex.Specs.UTF18BE24.decode(big) == {:ok, scalars}

      assert {:ok, little} = Iconvex.Specs.UTF18LE24.encode(scalars)
      assert Iconvex.Specs.UTF18LE24.decode(little) == {:ok, scalars}
    end)
  end

  test "excluded planes, surrogates, partial values, and nonzero padding are strict" do
    for codepoint <- [0xD800, 0x30000, 0xDFFFF, 0xF0000, 0x10FFFF] do
      assert Iconvex.Specs.UTF18.encode_packed([codepoint]) ==
               {:error, :unrepresentable_character, codepoint}

      assert Iconvex.Specs.UTF18BE24.encode([codepoint]) ==
               {:error, :unrepresentable_character, codepoint}

      assert Iconvex.Specs.UTF18LE24.encode([codepoint]) ==
               {:error, :unrepresentable_character, codepoint}
    end

    assert Iconvex.Specs.UTF18.decode_packed(<<1::1>>) ==
             {:error, :incomplete_sequence, 0, <<1::1>>}

    assert Iconvex.Specs.UTF18.decode_packed(<<0xD800::18>>) ==
             {:error, :invalid_sequence, 0, <<0xD800::18>>}

    for {codec, endian} <- [
          {Iconvex.Specs.UTF18BE24, :big},
          {Iconvex.Specs.UTF18LE24, :little}
        ] do
      assert codec.decode(<<0>>) == {:error, :incomplete_sequence, 0, <<0>>}

      assert codec.decode(word(0x40000, endian)) ==
               {:error, :invalid_sequence, 0, word(0x40000, endian)}

      assert codec.decode(word(0xD800, endian)) ==
               {:error, :invalid_sequence, 0, word(0xD800, endian)}

      assert codec.decode_discard(word(0x40000, endian) <> word(?A, endian)) == {:ok, [?A]}
    end
  end

  test "direct UTF-8 word transports preserve first-error ordering and byte offsets" do
    earlier_unrepresentable = <<?A, 0x30000::utf8, 0xFF>>
    malformed_only = <<?A, 0xFF>>

    for codec <- [Iconvex.Specs.UTF18BE24, Iconvex.Specs.UTF18LE24] do
      assert codec.encode_from_utf8(earlier_unrepresentable) ==
               {:encode_error, :unrepresentable_character, 0x30000}

      assert {:error,
              %Iconvex.Error{
                kind: :unrepresentable_character,
                encoding: encoding,
                codepoint: 0x30000
              }} = Iconvex.convert(earlier_unrepresentable, "UTF-8", codec.canonical_name())

      assert encoding == codec.canonical_name()

      assert codec.encode_from_utf8(malformed_only) ==
               {:decode_error, :invalid_sequence, 1, <<0xFF>>}
    end
  end

  test "24-bit transports register explicitly and expose direct UTF-8 paths" do
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

    assert Iconvex.canonical_name("UTF-18") == :error

    for codec <- [Iconvex.Specs.UTF18BE24, Iconvex.Specs.UTF18LE24] do
      assert Iconvex.canonical_name(codec.canonical_name()) == {:ok, codec.canonical_name()}
      assert {:ok, encoded} = codec.encode_from_utf8("A𐌰")
      assert codec.decode_to_utf8(encoded) == {:ok, "A𐌰"}
      assert Iconvex.convert("A𐌰", "UTF-8", codec.canonical_name()) == {:ok, encoded}
      assert Iconvex.convert(encoded, codec.canonical_name(), "UTF-8") == {:ok, "A𐌰"}
    end
  end

  defp word(value, :big), do: <<value::24-big>>
  defp word(value, :little), do: <<value::24-little>>
end

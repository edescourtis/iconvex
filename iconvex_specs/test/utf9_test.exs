defmodule Iconvex.Specs.UTF9Test do
  use ExUnit.Case, async: false

  @vectors [
    {0x0041, [0o101]},
    {0x00C0, [0o300]},
    {0x0391, [0o403, 0o221]},
    {0x611B, [0o541, 0o033]},
    {0x10330, [0o401, 0o403, 0o060]},
    {0xE0041, [0o416, 0o400, 0o101]},
    {0x10FFFD, [0o420, 0o777, 0o375]}
  ]

  test "RED: RFC 4042 vectors are exact 9-bit nonets" do
    for {codepoint, nonets} <- @vectors do
      packed = pack(nonets)

      assert Iconvex.Specs.UTF9.encode_packed([codepoint]) == {:ok, packed}
      assert Iconvex.Specs.UTF9.decode_packed(packed) == {:ok, [codepoint]}
      assert Iconvex.Specs.UTF9BE16.encode([codepoint]) == {:ok, words(nonets, :big)}
      assert Iconvex.Specs.UTF9LE16.encode([codepoint]) == {:ok, words(nonets, :little)}
      assert Iconvex.Specs.UTF9BE16.decode(words(nonets, :big)) == {:ok, [codepoint]}
      assert Iconvex.Specs.UTF9LE16.decode(words(nonets, :little)) == {:ok, [codepoint]}
    end
  end

  test "packed API preserves exact non-byte-aligned length" do
    assert {:ok, packed} = Iconvex.Specs.UTF9.encode_packed([?A, 0x0391, 0x10330])
    assert bit_size(packed) == 54
    refute is_binary(packed)
    assert Iconvex.Specs.UTF9.decode_packed(packed) == {:ok, [?A, 0x0391, 0x10330]}
  end

  test "every Unicode scalar round-trips through packed, 16BE, and 16LE transports" do
    0..0x10FFFF
    |> Stream.reject(&(&1 in 0xD800..0xDFFF))
    |> Stream.chunk_every(4_096)
    |> Enum.each(fn scalars ->
      assert {:ok, packed} = Iconvex.Specs.UTF9.encode_packed(scalars)
      assert Iconvex.Specs.UTF9.decode_packed(packed) == {:ok, scalars}

      assert {:ok, big} = Iconvex.Specs.UTF9BE16.encode(scalars)
      assert Iconvex.Specs.UTF9BE16.decode(big) == {:ok, scalars}

      assert {:ok, little} = Iconvex.Specs.UTF9LE16.encode(scalars)
      assert Iconvex.Specs.UTF9LE16.decode(little) == {:ok, scalars}
    end)
  end

  test "strict decoders reject padding, overlong, truncated, surrogate, and overflow forms" do
    assert Iconvex.Specs.UTF9.decode_packed(<<1::1>>) ==
             {:error, :incomplete_sequence, 0, <<1::1>>}

    assert Iconvex.Specs.UTF9.decode_packed(pack([0x100, 0])) ==
             {:error, :invalid_sequence, 0, pack([0x100])}

    assert Iconvex.Specs.UTF9.decode_packed(pack([0x101])) ==
             {:error, :incomplete_sequence, 0, pack([0x101])}

    assert Iconvex.Specs.UTF9.decode_packed(pack([0x1D8, 0])) ==
             {:error, :invalid_sequence, 0, pack([0x1D8, 0])}

    assert Iconvex.Specs.UTF9.decode_packed(pack([0x111, 0x100, 0])) ==
             {:error, :invalid_sequence, 0, pack([0x111, 0x100, 0])}

    for {codec, endian} <- [{Iconvex.Specs.UTF9BE16, :big}, {Iconvex.Specs.UTF9LE16, :little}] do
      assert codec.decode(<<0>>) == {:error, :incomplete_sequence, 0, <<0>>}

      assert codec.decode(words([0x200], endian)) ==
               {:error, :invalid_sequence, 0, words([0x200], endian)}

      assert codec.decode(words([0x100, 0], endian)) ==
               {:error, :invalid_sequence, 0, words([0x100], endian)}

      assert codec.decode(words([0x101], endian)) ==
               {:error, :incomplete_sequence, 0, words([0x101], endian)}

      assert codec.decode(words([0x1D8, 0], endian)) ==
               {:error, :invalid_sequence, 0, words([0x1D8, 0], endian)}

      assert codec.decode(words([0x111, 0x100, 0], endian)) ==
               {:error, :invalid_sequence, 0, words([0x111, 0x100, 0], endian)}

      assert codec.decode_discard(words([0x200, ?A], endian)) == {:ok, [?A]}
    end
  end

  test "encoders reject non-scalars and discard them without corrupting neighbors" do
    for codec <- [Iconvex.Specs.UTF9, Iconvex.Specs.UTF9BE16, Iconvex.Specs.UTF9LE16] do
      encode = if codec == Iconvex.Specs.UTF9, do: :encode_packed, else: :encode

      assert apply(codec, encode, [[0xD800]]) ==
               {:error, :unrepresentable_character, 0xD800}

      assert apply(codec, encode, [[0x110000]]) ==
               {:error, :unrepresentable_character, 0x110000}
    end

    assert Iconvex.Specs.UTF9BE16.encode_discard([?A, 0xD800, ?B]) ==
             {:ok, words([?A, ?B], :big)}

    assert Iconvex.Specs.UTF9LE16.encode_discard([?A, 0xD800, ?B]) ==
             {:ok, words([?A, ?B], :little)}
  end

  test "word transports register explicitly and expose strict UTF-8 fast paths" do
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

    assert Iconvex.canonical_name("UTF-9") == :error
    assert Iconvex.canonical_name("UTF-9-16BE") == {:ok, "UTF-9-16BE"}
    assert Iconvex.canonical_name("UTF-9-16LE") == {:ok, "UTF-9-16LE"}

    for codec <- [Iconvex.Specs.UTF9BE16, Iconvex.Specs.UTF9LE16] do
      assert {:ok, encoded} = codec.encode_from_utf8("AΑ𐌰")
      assert codec.decode_to_utf8(encoded) == {:ok, "AΑ𐌰"}
      assert Iconvex.convert("AΑ𐌰", "UTF-8", codec.canonical_name()) == {:ok, encoded}
      assert Iconvex.convert(encoded, codec.canonical_name(), "UTF-8") == {:ok, "AΑ𐌰"}
    end
  end

  test "generated non-octet inventory is exact runtime metadata" do
    expected =
      "canonical,aliases,module,unit_bits,transports\n" <>
        "BCD-CDC-IOWA,BCD-CDC-IOWA-RECONSTRUCTED,Iconvex.Specs.BCDCDCIowa,12,BCD-CDC-IOWA-16BE|BCD-CDC-IOWA-16LE\n" <>
        "CDC-167-BCD-HOLLERITH-1965,CDC-166-BCD-HOLLERITH-1965,Iconvex.Specs.CDC167BCDHollerith1965,12,CDC-167-BCD-HOLLERITH-1965-16BE|CDC-167-BCD-HOLLERITH-1965-16LE\n" <>
        "CDC-6000-STANDARD-HOLLERITH-1970,CDC-6000-HOLLERITH-1970,Iconvex.Specs.CDC6000StandardHollerith1970,12,CDC-6000-STANDARD-HOLLERITH-1970-16BE|CDC-6000-STANDARD-HOLLERITH-1970-16LE\n" <>
        "DEC-026-CARD-IOWA-824E61A9,DEC-026-PUNCHED-CARD-IOWA-824E61A9,Iconvex.Specs.DEC026CardIowa824E61A9,12,DEC-026-CARD-IOWA-824E61A9-16BE|DEC-026-CARD-IOWA-824E61A9-16LE\n" <>
        "DEC-029-CARD-IOWA-824E61A9,DEC-029-PUNCHED-CARD-IOWA-824E61A9,Iconvex.Specs.DEC029CardIowa824E61A9,12,DEC-029-CARD-IOWA-824E61A9-16BE|DEC-029-CARD-IOWA-824E61A9-16LE\n" <>
        "DEC-RADIX-50-18BIT,,Iconvex.Specs.DECRadix50PDP9,18,DEC-RADIX-50-18BIT-24BE|DEC-RADIX-50-18BIT-24LE\n" <>
        "DEC-RADIX-50-36BIT,,Iconvex.Specs.DECRadix50PDP10,36,DEC-RADIX-50-36BIT-40BE|DEC-RADIX-50-36BIT-40LE\n" <>
        "EBCD-CARD-IOWA-824E61A9,EBCD-PUNCHED-CARD-IOWA-824E61A9,Iconvex.Specs.EBCDCardIowa824E61A9,12,EBCD-CARD-IOWA-824E61A9-16BE|EBCD-CARD-IOWA-824E61A9-16LE\n" <>
        "GE-600-CARD-IOWA-824E61A9,GE-600-PUNCHED-CARD-IOWA-824E61A9,Iconvex.Specs.GE600CardIowa824E61A9,12,GE-600-CARD-IOWA-824E61A9-16BE|GE-600-CARD-IOWA-824E61A9-16LE\n" <>
        "IBM-029-CARD-IOWA-824E61A9,IBM-029-PUNCHED-CARD-IOWA-824E61A9,Iconvex.Specs.IBM029CardIowa824E61A9,12,IBM-029-CARD-IOWA-824E61A9-16BE|IBM-029-CARD-IOWA-824E61A9-16LE\n" <>
        "IBM-1401-CARD,IBM1401-CARD,Iconvex.Specs.IBM1401Card,12,IBM-1401-CARD-16BE|IBM-1401-CARD-16LE\n" <>
        "IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-A,BCD-A|IBM 026 Commercial card code|IBM-026-COMMERCIAL-CARD-CODE|IBM-24-26-ARRANGEMENT-A,Iconvex.Specs.IBM2426ArrangementA,12,IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-A-16BE|IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-A-16LE\n" <>
        "IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-B,IBM-24-26-ARRANGEMENT-B,Iconvex.Specs.IBM2426ArrangementB,12,IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-B-16BE|IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-B-16LE\n" <>
        "IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-C,IBM-24-26-ARRANGEMENT-C,Iconvex.Specs.IBM2426ArrangementC,12,IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-C-16BE|IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-C-16LE\n" <>
        "IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-D,IBM-24-26-ARRANGEMENT-D,Iconvex.Specs.IBM2426ArrangementD,12,IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-D-16BE|IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-D-16LE\n" <>
        "IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-E,IBM-24-26-ARRANGEMENT-E,Iconvex.Specs.IBM2426ArrangementE,12,IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-E-16BE|IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-E-16LE\n" <>
        "IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-F,IBM-24-26-ARRANGEMENT-F,Iconvex.Specs.IBM2426ArrangementF,12,IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-F-16BE|IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-F-16LE\n" <>
        "IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-G,IBM-24-26-ARRANGEMENT-G,Iconvex.Specs.IBM2426ArrangementG,12,IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-G-16BE|IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-G-16LE\n" <>
        "IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-H,BCD-H|IBM 026 FORTRAN card code|IBM-026-FORTRAN-CARD-CODE|IBM-24-26-ARRANGEMENT-H,Iconvex.Specs.IBM2426ArrangementH,12,IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-H-16BE|IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-H-16LE\n" <>
        "IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-J,IBM-24-26-ARRANGEMENT-J,Iconvex.Specs.IBM2426ArrangementJ,12,IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-J-16BE|IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-J-16LE\n" <>
        "IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-K,IBM-24-26-ARRANGEMENT-K,Iconvex.Specs.IBM2426ArrangementK,12,IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-K-16BE|IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-K-16LE\n" <>
        "IBM-7040-H-PROGRAM,IBM-7044-H-PROGRAM,Iconvex.Specs.IBM7040HProgram,12,IBM-7040-H-PROGRAM-16BE|IBM-7040-H-PROGRAM-16LE\n" <>
        "IBM-7040-H-REPORT,IBM-7044-H-REPORT,Iconvex.Specs.IBM7040HReport,12,IBM-7040-H-REPORT-16BE|IBM-7040-H-REPORT-16LE\n" <>
        "UTF-18,,Iconvex.Specs.UTF18,18,UTF-18-24BE|UTF-18-24LE\n" <>
        "UTF-9,,Iconvex.Specs.UTF9,9,UTF-9-16BE|UTF-9-16LE\n"

    assert File.read!("SUPPORTED_NON_OCTET_CODEC_INVENTORY.csv") == expected
  end

  defp pack(nonets), do: Enum.reduce(nonets, <<>>, &<<&2::bitstring, &1::9>>)

  defp words(nonets, :big),
    do: nonets |> Enum.map(&<<&1::16-big>>) |> IO.iodata_to_binary()

  defp words(nonets, :little),
    do: nonets |> Enum.map(&<<&1::16-little>>) |> IO.iodata_to_binary()
end

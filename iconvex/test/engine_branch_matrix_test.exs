defmodule Iconvex.EngineBranchMatrixTest do
  use ExUnit.Case, async: false

  alias Iconvex.{EscapeCodec, GB18030Codec, Packed, TableCodec, Tables, UnicodeCodec}

  test "C99 escape decoder and encoder cover literals, limits, and truncation" do
    entry = %{id: :c99}

    assert {:ok, [0, ?A, 0x9F]} = EscapeCodec.decode(entry, <<0, ?A, 0x9F>>)

    assert {:ok, [0xE9, 0x1F600, ?$, ?@, ?`]} =
             EscapeCodec.decode(entry, ~S(\u00e9\U0001f600\u0024\u0040\u0060))

    assert {:error, :invalid_sequence, 2, "\\"} = EscapeCodec.decode(entry, ~S(\q\u0041))
    assert {:error, :invalid_sequence, 0, <<0xA0>>} = EscapeCodec.decode(entry, <<0xA0>>)

    for input <- ["\\", "\\u", "\\u12", "\\U000000"] do
      assert {:error, :incomplete_sequence, 0, ^input} = EscapeCodec.decode(entry, input)
    end

    assert {:ok, [0x11111110, 0x33333333]} =
             EscapeCodec.decode(entry, ~S(\UGGGGGGGG\UZZZZZZZZ))

    assert {:ok, encoded} = EscapeCodec.encode(entry, [0, 0xA0, 0x10000, 0xFFFFFFFF])
    assert {:ok, [0, 0xA0, 0x10000, 0xFFFFFFFF]} = EscapeCodec.decode(entry, encoded)

    assert {:error, :unrepresentable_character, 0x100000000} =
             EscapeCodec.encode(entry, [0x100000000])

    assert {:ok, "A"} = EscapeCodec.encode_discard(entry, [?A, 0x100000000])
  end

  test "JAVA escape decoder and encoder cover surrogate and literal branches" do
    entry = %{id: :java}

    assert {:ok, [?A, 0xFF]} = EscapeCodec.decode(entry, <<?A, 0xFF>>)
    assert {:ok, [0xE9, 0x1F600]} = EscapeCodec.decode(entry, ~S(\u00e9\ud83d\ude00))
    assert {:ok, ~c"\\q\\ud800A"} = EscapeCodec.decode(entry, ~S(\q\ud800\u0041))

    for input <- ["\\", "\\u", "\\u12", "\\ud800\\u"] do
      assert {:error, :incomplete_sequence, 0, ^input} = EscapeCodec.decode(entry, input)
    end

    assert {:ok, encoded} = EscapeCodec.encode(entry, [?A, 0x80, 0x1F600])
    assert {:ok, [?A, 0x80, 0x1F600]} = EscapeCodec.decode(entry, encoded)
    assert {:ok, ~S(\ud800)} = EscapeCodec.encode(entry, [0xD800])
    assert {:ok, ~S(A\ud800)} = EscapeCodec.encode_discard(entry, [?A, 0xD800, 0x110000])
  end

  test "GB18030 covers every input width and discard path" do
    entry = %{id: :gb18030_2005}

    assert {:ok, [?A, 0x1F600]} = GB18030Codec.decode(entry, <<?A, 0x94, 0x39, 0xFC, 0x36>>)

    for input <- [<<0x90>>, <<0x90, 0x30>>, <<0x90, 0x30, 0x81>>, <<0x81>>, <<0x81, 0x30>>] do
      assert {:error, :incomplete_sequence, 0, ^input} = GB18030Codec.decode(entry, input)
    end

    assert {:error, :invalid_sequence, 0, <<0xFF>>} = GB18030Codec.decode(entry, <<0xFF>>)

    assert {:error, :invalid_sequence, 0, <<0x81, 0x20>>} =
             GB18030Codec.decode(entry, <<0x81, 0x20>>)

    assert {:ok, encoded} = GB18030Codec.encode(entry, [?A, 0x1F600])
    assert {:ok, [?A, 0x1F600]} = GB18030Codec.decode(entry, encoded)

    assert {:error, :unrepresentable_character, 0x110000} =
             GB18030Codec.encode(entry, [0x110000])

    assert {:ok, ^encoded} = GB18030Codec.encode_discard(entry, [?A, 0x110000, 0x1F600])
  end

  test "Unicode engines cover malformed units, endian switches, and discard" do
    assert {:error, :invalid_sequence, 0, <<0xFF>>} = UnicodeCodec.decode(%{id: :utf8}, <<0xFF>>)

    assert {:error, :incomplete_sequence, 0, <<0xC3>>} =
             UnicodeCodec.decode(%{id: :utf8}, <<0xC3>>)

    assert {:error, :invalid_sequence, 0, <<0xD8, 0>>} =
             UnicodeCodec.decode(%{id: :ucs2be}, <<0xD8, 0>>)

    assert {:error, :incomplete_sequence, 0, <<0xD8, 0>>} =
             UnicodeCodec.decode(%{id: :utf16be}, <<0xD8, 0>>)

    assert {:error, :invalid_sequence, 0, <<0xD8, 0>>} =
             UnicodeCodec.decode(%{id: :utf16be}, <<0xD8, 0, 0, ?A>>)

    assert {:error, :invalid_sequence, 0, <<0xDC, 0>>} =
             UnicodeCodec.decode(%{id: :utf16be}, <<0xDC, 0>>)

    assert {:error, :incomplete_sequence, 0, <<0>>} = UnicodeCodec.decode(%{id: :ucs2be}, <<0>>)

    assert {:error, :incomplete_sequence, 0, <<0, 0, 0>>} =
             UnicodeCodec.decode(%{id: :utf32be}, <<0, 0, 0>>)

    assert {:ok, [?A]} = UnicodeCodec.decode(%{id: :utf16}, <<0xFE, 0xFF, 0, ?A>>)
    assert {:ok, [?A]} = UnicodeCodec.decode(%{id: :utf16}, <<0xFF, 0xFE, ?A, 0>>)
    assert {:ok, [?A]} = UnicodeCodec.decode(%{id: :utf32}, <<0, 0, 0xFE, 0xFF, 0, 0, 0, ?A>>)
    assert {:ok, [?A]} = UnicodeCodec.decode(%{id: :utf32}, <<0xFF, 0xFE, 0, 0, ?A, 0, 0, 0>>)

    assert {:ok, [0x110000]} = UnicodeCodec.decode(%{id: :ucs4be}, <<0, 0x11, 0, 0>>)

    for id <- [:ucs4be, :ucs4le, :ucs4internal, :ucs4swapped] do
      assert {:ok, [0xFFFFFFFF]} = UnicodeCodec.decode(%{id: id}, <<0xFFFFFFFF::32>>)
      assert {:ok, <<0xFFFFFFFF::32>>} = UnicodeCodec.encode(%{id: id}, [0xFFFFFFFF])
    end

    assert {:error, :invalid_sequence, 0, <<0xFFFFFFFF::32>>} =
             UnicodeCodec.decode(%{id: :ucs4}, <<0xFFFFFFFF::32>>)

    assert {:error, :unrepresentable_character, 0xFFFFFFFF} =
             UnicodeCodec.encode(%{id: :ucs4}, [0xFFFFFFFF])

    assert {:error, :invalid_sequence, 0, <<0, 0x11, 0, 0>>} =
             UnicodeCodec.decode(%{id: :utf32be}, <<0, 0x11, 0, 0>>)

    assert {:ok, "A"} = UnicodeCodec.encode_discard(%{id: :utf8}, [?A, 0xD800, 0x110000])
    assert {:ok, <<0, ?A>>} = UnicodeCodec.encode_discard(%{id: :ucs2be}, [?A, 0x1F600])
    assert {:ok, <<0, 0, 0, ?A>>} = UnicodeCodec.encode_discard(%{id: :utf32be}, [?A, 0xD800])

    for id <- [:ucs2le, :ucs2internal, :ucs2swapped, :utf16le] do
      assert {:ok, bytes} = UnicodeCodec.encode(%{id: id}, [?A])
      assert {:ok, [?A]} = UnicodeCodec.decode(%{id: id}, bytes)
    end

    for id <- [:ucs4le, :ucs4internal, :ucs4swapped, :utf32le] do
      assert {:ok, bytes} = UnicodeCodec.encode(%{id: id}, [?A])
      assert {:ok, [?A]} = UnicodeCodec.decode(%{id: id}, bytes)
    end
  end

  test "table engines cover native discard, multicodepoint, and UTF-8 fast errors" do
    cp1252 = %{id: :cp1252}
    hkscs = %{id: :big5hkscs2008}
    sjis = %{id: :sjis}

    assert {:ok, [?A, ?B]} = TableCodec.decode_discard(cp1252, <<?A, 0x81, ?B>>)
    assert {:ok, "AB"} = TableCodec.encode_discard(cp1252, [?A, 0x1F600, ?B])
    assert {:error, :unrepresentable_character, 0x1F600} = TableCodec.encode(cp1252, [0x1F600])

    assert {:ok, [0xEA, 0x030C]} = TableCodec.decode(hkscs, <<0x88, 0xA5>>)
    assert {:ok, <<0x88, 0xA5>>} = TableCodec.encode(hkscs, [0xEA, 0x030C])
    assert {:ok, <<0x88, 0xA5>>} = TableCodec.encode_discard(hkscs, [0x110000, 0xEA, 0x030C])
    assert :miss = TableCodec.decode_to_utf8(hkscs, <<0x88, 0xA5>>)
    assert :miss = TableCodec.encode_from_utf8(hkscs, "ê̌")

    assert {:ok, []} = TableCodec.decode_discard(sjis, <<0x82>>)

    assert {:decode_error, :incomplete_sequence, 0, <<0xC3>>} =
             TableCodec.encode_from_utf8(cp1252, <<0xC3>>)

    assert {:decode_error, :invalid_sequence, 0, <<0xFF>>} =
             TableCodec.encode_from_utf8(cp1252, <<0xFF>>)
  end

  test "packed validation and provider lifecycle cover all public error shapes" do
    assert {:error, :invalid_unit_bits} = Packed.pack(<<1>>, 0)
    assert {:error, :invalid_unit_bits} = Packed.unpack(<<1>>, 9)
    assert {:error, :invalid_unit_bits} = Packed.pack_lsb(<<1>>, :bad)
    assert {:error, :invalid_unit_bits} = Packed.unpack_lsb(<<>>, -1, 7)
    assert {:error, :unit_out_of_range, 0, 0x80} = Packed.pack_lsb(<<0x80>>, 7)
    assert {:ok, <<>>} = Packed.unpack_lsb(<<>>, 0, 7)

    id = :iconvex_test_provider
    assert :ok = Tables.register_provider(id, :iconvex)
    assert :ok = Tables.register_provider(id, :iconvex)

    assert {:error, {:table_provider_conflict, ^id, :iconvex}} =
             Tables.register_provider(id, :other_app)

    assert :ok = Tables.unregister_provider(id, :other_app)
    assert :ok = Tables.unregister_provider(id, :iconvex)
  end
end

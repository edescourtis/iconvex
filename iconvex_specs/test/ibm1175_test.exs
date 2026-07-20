defmodule Iconvex.Specs.IBM1175Test do
  use ExUnit.Case, async: false

  @table_id :icu_archive_374

  test "RED: IBM-1175 and every CCSID spelling register" do
    for name <- ["IBM-1175", "IBM1175", "CP1175", "CCSID1175"] do
      assert Iconvex.canonical_name(name) == {:ok, "IBM-1175"}
      assert Iconvex.canonical_name(String.downcase(name, :ascii)) == {:ok, "IBM-1175"}
    end
  end

  test "all 256 bytes equal the pinned IBM-authored lira-update table" do
    table = Iconvex.Tables.fetch!(@table_id)

    for byte <- 0..0xFF do
      expected =
        case elem(table.one, byte) do
          nil -> {:error, :invalid_sequence, 0, <<byte>>}
          tuple -> {:ok, Tuple.to_list(tuple)}
        end

      assert Iconvex.Specs.IBM1175.decode(<<byte>>) == expected
    end

    assert Iconvex.Specs.IBM1175.decode(<<0x9A, 0x9F>>) == {:ok, [0x20BA, 0x20AC]}
  end

  test "every canonical encoder mapping is exact and round-trips" do
    table = Iconvex.Tables.fetch!(@table_id)

    for {tuple, bytes} <- table.encode do
      codepoints = Tuple.to_list(tuple)
      assert Iconvex.Specs.IBM1175.encode(codepoints) == {:ok, bytes}
      assert Iconvex.Specs.IBM1175.decode(bytes) == {:ok, codepoints}
    end

    assert Iconvex.Specs.IBM1175.encode([0x20BA, 0x20AC]) == {:ok, <<0x9A, 0x9F>>}
    assert Iconvex.Specs.IBM1175.encode([0x00AA]) == {:error, :unrepresentable_character, 0x00AA}
  end

  test "strict, discard, UTF-8, and public conversion paths agree" do
    assert Iconvex.Specs.IBM1175.encode([?A, 0x10FFFF]) ==
             {:error, :unrepresentable_character, 0x10FFFF}

    assert Iconvex.Specs.IBM1175.encode_discard([?A, 0x10FFFF, ?B]) == {:ok, <<0xC1, 0xC2>>}
    assert {:ok, encoded} = Iconvex.Specs.IBM1175.encode_from_utf8("TRY ₺€")
    assert Iconvex.Specs.IBM1175.decode_to_utf8(encoded) == {:ok, "TRY ₺€"}
    assert Iconvex.convert("TRY ₺€", "UTF-8", "IBM-1175") == {:ok, encoded}
    assert Iconvex.convert(encoded, "IBM-1175", "UTF-8") == {:ok, "TRY ₺€"}
  end
end

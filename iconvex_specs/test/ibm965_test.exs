defmodule Iconvex.Specs.IBM965Test do
  use ExUnit.Case, async: false

  @table_id :icu_archive_729
  @designation <<0x1B, "$)G">>

  test "RED: IBM-965 and all CCSID spellings register" do
    for name <- ["IBM-965", "IBM965", "CP965", "CCSID965"] do
      assert Iconvex.canonical_name(name) == {:ok, "IBM-965"}
      assert Iconvex.canonical_name(String.downcase(name, :ascii)) == {:ok, "IBM-965"}
    end
  end

  test "ASCII and every CP960 94 by 94 graphic position decode exactly" do
    for byte <- 0..0x7F, byte not in [0x0E, 0x0F, 0x1B] do
      assert Iconvex.Specs.IBM965.decode(<<byte>>) == {:ok, [byte]}
    end

    table = Iconvex.Tables.fetch!(@table_id)

    for first <- 0x21..0x7E, second <- 0x21..0x7E do
      source = <<first + 0x80, second + 0x80>>
      input = @designation <> <<0x0E, first, second, 0x0F>>

      expected =
        case Map.get(table.many, source) do
          nil -> {:error, :invalid_sequence, 5, <<first, second>>}
          tuple -> {:ok, Tuple.to_list(tuple)}
        end

      assert Iconvex.Specs.IBM965.decode(input) == expected
    end
  end

  test "every canonical CP960 encoder mapping round-trips and framing is exact" do
    table = Iconvex.Tables.fetch!(@table_id)

    for {tuple, source} <- table.encode do
      <<first, second>> = source
      expected = @designation <> <<0x0E, first - 0x80, second - 0x80, 0x0F>>
      codepoints = Tuple.to_list(tuple)

      assert Iconvex.Specs.IBM965.encode(codepoints) == {:ok, expected}
      assert Iconvex.Specs.IBM965.decode(expected) == {:ok, codepoints}
    end

    assert Iconvex.Specs.IBM965.encode([0x4E00, ?A]) ==
             {:ok, @designation <> <<0x0E, 0x44, 0x21, 0x0F, ?A>>}
  end

  test "line boundaries reset designation and malformed state is strict" do
    assert Iconvex.Specs.IBM965.encode([0x4E00, ?\n, 0x4E00]) ==
             {:ok,
              @designation <>
                <<0x0E, 0x44, 0x21, 0x0F, ?\n>> <>
                @designation <> <<0x0E, 0x44, 0x21, 0x0F>>}

    assert Iconvex.Specs.IBM965.decode(<<0x0E>>) ==
             {:error, :invalid_sequence, 0, <<0x0E>>}

    assert Iconvex.Specs.IBM965.decode(<<0x1B, ?$>>) ==
             {:error, :incomplete_sequence, 0, <<0x1B, ?$>>}

    assert Iconvex.Specs.IBM965.decode(<<0x1B, "$)X">>) ==
             {:error, :invalid_sequence, 0, <<0x1B, "$)X">>}

    assert Iconvex.Specs.IBM965.decode(@designation <> <<0x0E, 0x21>>) ==
             {:error, :incomplete_sequence, 5, <<0x21>>}

    assert Iconvex.Specs.IBM965.decode(<<0x80>>) ==
             {:error, :invalid_sequence, 0, <<0x80>>}

    assert Iconvex.Specs.IBM965.decode_discard(<<0x80, ?A, 0x1B>>) == {:ok, [?A]}
    assert Iconvex.Specs.IBM965.encode_discard([?A, 0xD800, ?B]) == {:ok, "AB"}
  end

  test "direct UTF-8 paths and Iconvex conversion preserve results" do
    assert {:ok, encoded} = Iconvex.Specs.IBM965.encode_from_utf8("A一")
    assert Iconvex.Specs.IBM965.decode_to_utf8(encoded) == {:ok, "A一"}
    assert Iconvex.convert("A一", "UTF-8", "IBM-965") == {:ok, encoded}
    assert Iconvex.convert(encoded, "IBM-965", "UTF-8") == {:ok, "A一"}
  end
end

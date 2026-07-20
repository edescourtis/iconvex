defmodule Iconvex.Specs.IBM17354Test do
  use ExUnit.Case, async: false

  @table_id :icu_archive_735
  @designation <<0x1B, "$)C">>

  test "RED: IBM-17354 and every CCSID spelling register" do
    for name <- ["IBM-17354", "IBM17354", "CP17354", "CCSID17354"] do
      assert Iconvex.canonical_name(name) == {:ok, "IBM-17354"}
      assert Iconvex.canonical_name(String.downcase(name, :ascii)) == {:ok, "IBM-17354"}
    end
  end

  test "ASCII and all 94 by 94 CP971 graphic positions decode exactly" do
    for byte <- 0..0x7F, byte not in [0x0E, 0x0F, 0x1B] do
      assert Iconvex.Specs.IBM17354.decode(<<byte>>) == {:ok, [byte]}
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

      assert Iconvex.Specs.IBM17354.decode(input) == expected
    end
  end

  test "all 8,412 preferred CP971 encoders round-trip with exact framing" do
    table = Iconvex.Tables.fetch!(@table_id)

    for {tuple, <<first, second>>} <- table.encode do
      expected = @designation <> <<0x0E, first - 0x80, second - 0x80, 0x0F>>
      codepoints = Tuple.to_list(tuple)

      assert Iconvex.Specs.IBM17354.encode(codepoints) == {:ok, expected}
      assert Iconvex.Specs.IBM17354.decode(expected) == {:ok, codepoints}
    end

    assert Iconvex.Specs.IBM17354.encode([0xAC00, ?A]) ==
             {:ok, @designation <> <<0x0E, 0x30, 0x21, 0x0F, ?A>>}
  end

  test "line reset, malformed state, discard, UTF-8, and public paths are strict" do
    assert Iconvex.Specs.IBM17354.encode([0xAC00, ?\n, 0xAC00]) ==
             {:ok,
              @designation <>
                <<0x0E, 0x30, 0x21, 0x0F, ?\n>> <>
                @designation <> <<0x0E, 0x30, 0x21, 0x0F>>}

    assert Iconvex.Specs.IBM17354.decode(<<0x0E>>) ==
             {:error, :invalid_sequence, 0, <<0x0E>>}

    assert Iconvex.Specs.IBM17354.decode(<<0x1B, ?$>>) ==
             {:error, :incomplete_sequence, 0, <<0x1B, ?$>>}

    assert Iconvex.Specs.IBM17354.decode(@designation <> <<0x0E, 0x21>>) ==
             {:error, :incomplete_sequence, 5, <<0x21>>}

    assert Iconvex.Specs.IBM17354.decode_discard(<<0x80, ?A, 0x1B>>) == {:ok, [?A]}
    assert Iconvex.Specs.IBM17354.encode_discard([?A, 0xD800, ?B]) == {:ok, "AB"}

    assert {:ok, encoded} = Iconvex.Specs.IBM17354.encode_from_utf8("A가")
    assert Iconvex.Specs.IBM17354.decode_to_utf8(encoded) == {:ok, "A가"}
    assert Iconvex.convert("A가", "UTF-8", "IBM-17354") == {:ok, encoded}
    assert Iconvex.convert(encoded, "IBM-17354", "UTF-8") == {:ok, "A가"}
  end

  test "RED: buffered converters pin the archive provider across stop and replacement" do
    encoded = @designation <> <<0x0E, 0x30, 0x21, 0x0F>>
    provider_key = {{Iconvex.Tables, :provider}, @table_id}

    assert {:ok, decoder} = Iconvex.new("IBM-17354", "UTF-8")
    assert {:ok, <<>>, decoder} = Iconvex.feed(decoder, encoded)
    assert {:ok, encoder} = Iconvex.new("UTF-8", "IBM-17354")
    assert {:ok, <<>>, encoder} = Iconvex.feed(encoder, "가")

    on_exit(fn ->
      Iconvex.Tables.unregister_provider(@table_id, :iconvex_specs_icu_archive_b)
      Application.ensure_all_started(:iconvex_specs_icu_archive_c)
    end)

    assert :ok = Application.stop(:iconvex_specs_icu_archive_c)
    assert :persistent_term.get(provider_key, :missing) == :missing
    assert :ok = Iconvex.Tables.register_provider(@table_id, :iconvex_specs_icu_archive_b)

    assert Iconvex.finish(decoder) == {:ok, "가"}
    assert Iconvex.finish(encoder) == {:ok, encoded}

    assert :ok = Iconvex.Tables.unregister_provider(@table_id, :iconvex_specs_icu_archive_b)
    assert {:ok, _started} = Application.ensure_all_started(:iconvex_specs_icu_archive_c)
    assert Iconvex.finish(decoder) == {:ok, "가"}
    assert Iconvex.finish(encoder) == {:ok, encoded}
  end
end

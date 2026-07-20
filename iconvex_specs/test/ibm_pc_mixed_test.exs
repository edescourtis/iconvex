defmodule Iconvex.Specs.IBMPCMixedTest do
  use ExUnit.Case, async: false

  @profiles [
    {Iconvex.Specs.IBM934, :icu_archive_631, :icu_archive_669, 0xAC00, <<0x86, 0x40>>},
    {Iconvex.Specs.IBM938, :icu_archive_647, :icu_archive_670, 0x4E00, <<0x8C, 0x40>>}
  ]

  test "RED: IBM-934 and IBM-938 CCSID spellings register" do
    for {canonical, names} <- [
          {"IBM-934", ["IBM-934", "IBM934", "CP934", "CCSID934"]},
          {"IBM-938", ["IBM-938", "IBM938", "CP938", "CCSID938"]}
        ],
        name <- names do
      assert Iconvex.canonical_name(name) == {:ok, canonical}
      assert Iconvex.canonical_name(String.downcase(name, :ascii)) == {:ok, canonical}
    end
  end

  test "all 256 initial bytes and every possible lead/trail pair classify exactly" do
    for {codec, single_id, double_id, _codepoint, _source} <- @profiles do
      single = Iconvex.Tables.fetch!(single_id)
      double = Iconvex.Tables.fetch!(double_id)
      leads = double.many |> Map.keys() |> MapSet.new(fn <<lead, _trail>> -> lead end)

      for byte <- 0..0xFF do
        expected =
          case elem(single.one, byte) do
            nil ->
              if MapSet.member?(leads, byte),
                do: {:error, :incomplete_sequence, 0, <<byte>>},
                else: {:error, :invalid_sequence, 0, <<byte>>}

            tuple ->
              {:ok, Tuple.to_list(tuple)}
          end

        assert codec.decode(<<byte>>) == expected
      end

      for lead <- leads, trail <- 0..0xFF do
        source = <<lead, trail>>

        expected =
          case Map.get(double.many, source) do
            nil -> {:error, :invalid_sequence, 0, source}
            tuple -> {:ok, Tuple.to_list(tuple)}
          end

        assert codec.decode(source) == expected
      end
    end
  end

  test "every component decoder mapping and preferred encoder mapping executes" do
    for {codec, single_id, double_id, _codepoint, _source} <- @profiles do
      single = Iconvex.Tables.fetch!(single_id)
      double = Iconvex.Tables.fetch!(double_id)

      for {source, tuple} <- decoder_rows(single) ++ Map.to_list(double.many) do
        assert codec.decode(source) == {:ok, Tuple.to_list(tuple)}
      end

      expected_encode = Map.merge(double.encode, single.encode)

      for {tuple, source} <- expected_encode do
        codepoints = Tuple.to_list(tuple)
        assert codec.encode(codepoints) == {:ok, source}
        assert codec.decode(source) == {:ok, codepoints}
      end
    end
  end

  test "fixed IBM vectors, strict prefix errors, discard, and UTF-8 paths" do
    for {codec, _single_id, _double_id, codepoint, source} <- @profiles do
      utf8 = "A" <> <<codepoint::utf8>>
      encoded = "A" <> source

      assert codec.encode_from_utf8(utf8) == {:ok, encoded}
      assert codec.decode_to_utf8(encoded) == {:ok, utf8}
      assert Iconvex.convert(utf8, "UTF-8", codec.canonical_name()) == {:ok, encoded}
      assert Iconvex.convert(encoded, codec.canonical_name(), "UTF-8") == {:ok, utf8}

      <<lead, _trail>> = source
      assert codec.decode(<<lead>>) == {:error, :incomplete_sequence, 0, <<lead>>}
      assert codec.decode_discard(<<0xFF, ?A, lead>>) == {:ok, [?A]}
      assert codec.encode_discard([?A, 0xD800, ?B]) == {:ok, "AB"}
    end
  end

  defp decoder_rows(table) do
    for byte <- 0..0xFF, tuple = elem(table.one, byte), tuple != nil, do: {<<byte>>, tuple}
  end
end

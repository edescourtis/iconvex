defmodule Iconvex.Specs.IBMISO2022JPTest do
  use ExUnit.Case, async: false

  @profiles [
    {Iconvex.Specs.IBM5052, :icu_archive_632, :icu_archive_723, <<0x1B, "$B">>, true},
    {Iconvex.Specs.IBM5053, :icu_archive_632, :icu_archive_726, <<0x1B, "$@">>, false},
    {Iconvex.Specs.IBM958, :ascii, :icu_archive_723, <<0x1B, "$B">>, true},
    {Iconvex.Specs.IBM5055, :ascii, :icu_archive_726, <<0x1B, "$@">>, false}
  ]

  test "RED: all IBM names and equivalent CCSIDs are externally registered" do
    expected = %{
      "IBM-5052" => "IBM-5052",
      "IBM-956" => "IBM-5052",
      "IBM-5053" => "IBM-5053",
      "IBM-957" => "IBM-5053",
      "IBM-958" => "IBM-958",
      "IBM-5055" => "IBM-5055",
      "IBM-959" => "IBM-5055"
    }

    for {name, canonical} <- expected do
      assert Iconvex.canonical_name(name) == {:ok, canonical}
      assert Iconvex.canonical_name(String.downcase(name, :ascii)) == {:ok, canonical}
    end
  end

  test "IBM profile vectors select their declared G0 and JIS revision" do
    assert Iconvex.Specs.IBM5052.encode([?A, 0x00A5, 0x0391]) ==
             {:ok, <<?A, 0x5C, 0x1B, "$B", 0x26, 0x21, 0x1B, "(J">>}

    assert Iconvex.Specs.IBM958.encode([?A, ?\\, 0x0391]) ==
             {:ok, <<?A, ?\\, 0x1B, "$B", 0x26, 0x21, 0x1B, "(B">>}

    assert Iconvex.Specs.IBM5053.decode(<<0x1B, "$@", 0x26, 0x21, 0x1B, "(J">>) ==
             {:ok, [0x0391]}

    assert Iconvex.Specs.IBM5055.decode(<<0x1B, "$@", 0x26, 0x21, 0x1B, "(B">>) ==
             {:ok, [0x0391]}
  end

  test "every source mapping and every 94 by 94 graphic position is audited" do
    for {codec, single_id, double_id, designation, high_bit?} <- @profiles do
      assert single_mismatches(codec, single_id) == []
      assert double_mismatches(codec, double_id, designation, high_bit?) == []
      assert encode_mismatches(codec, single_id, double_id) == []
    end
  end

  test "strict decoding distinguishes malformed and truncated state sequences" do
    for {codec, _single_id, _double_id, designation, _high_bit?} <- @profiles do
      assert codec.decode(<<0x80>>) == {:error, :invalid_sequence, 0, <<0x80>>}
      assert codec.decode(<<0x1B>>) == {:error, :incomplete_sequence, 0, <<0x1B>>}
      assert codec.decode(<<0x1B, ?$>>) == {:error, :incomplete_sequence, 0, <<0x1B, ?$>>}
      assert codec.decode(<<0x1B, "!X">>) == {:error, :invalid_sequence, 0, <<0x1B, "!X">>}

      assert codec.decode(designation <> <<0x21>>) ==
               {:error, :incomplete_sequence, byte_size(designation), <<0x21>>}

      assert codec.decode_discard(<<0x80, ?A, 0x1B>>) == {:ok, [?A]}
      assert codec.encode_discard([?A, 0xD800, ?B]) == {:ok, "AB"}
    end
  end

  test "UTF-8 fast paths and Iconvex conversion preserve stateful results" do
    for {codec, _single_id, _double_id, _designation, _high_bit?} <- @profiles do
      assert {:ok, encoded} = codec.encode_from_utf8("AΑ")
      assert codec.decode_to_utf8(encoded) == {:ok, "AΑ"}
      assert Iconvex.convert("AΑ", "UTF-8", codec.canonical_name()) == {:ok, encoded}
      assert Iconvex.convert(encoded, codec.canonical_name(), "UTF-8") == {:ok, "AΑ"}
    end
  end

  defp single_mismatches(codec, :ascii) do
    for byte <- 0..0x7F,
        byte != 0x1B,
        codec.decode(<<byte>>) != {:ok, [byte]},
        do: byte
  end

  defp single_mismatches(codec, table_id) do
    table = Iconvex.Tables.fetch!(table_id)

    for byte <- 0..0x7F,
        byte != 0x1B,
        expected = elem(table.one, byte),
        codec.decode(<<byte>>) != expected_decode(expected, byte),
        do: byte
  end

  defp double_mismatches(codec, table_id, designation, high_bit?) do
    table = Iconvex.Tables.fetch!(table_id)

    return =
      if codec in [Iconvex.Specs.IBM5052, Iconvex.Specs.IBM5053],
        do: <<0x1B, "(J">>,
        else: <<0x1B, "(B">>

    for first <- 0x21..0x7E,
        second <- 0x21..0x7E,
        source = if(high_bit?, do: <<first + 0x80, second + 0x80>>, else: <<first, second>>),
        expected = Map.get(table.many, source),
        input = designation <> <<first, second>> <> return,
        codec.decode(input) != expected_decode(expected, input),
        do: {first, second}
  end

  defp encode_mismatches(codec, single_id, double_id) do
    single_codepoints =
      case single_id do
        :ascii -> Enum.map(0..0x7F, &{&1})
        id -> Iconvex.Tables.fetch!(id).encode |> Map.keys()
      end

    double_codepoints = Iconvex.Tables.fetch!(double_id).encode |> Map.keys()

    for tuple <- Enum.uniq(single_codepoints ++ double_codepoints),
        tuple != {0x1B},
        codepoints = Tuple.to_list(tuple),
        not round_trips?(codec, codepoints),
        do: tuple
  end

  defp round_trips?(codec, codepoints) do
    case codec.encode(codepoints) do
      {:ok, encoded} -> codec.decode(encoded) == {:ok, codepoints}
      _ -> false
    end
  end

  defp expected_decode(nil, input) when is_integer(input),
    do: {:error, :invalid_sequence, 0, <<input>>}

  defp expected_decode(nil, input),
    do: {:error, :invalid_sequence, 3, binary_part(input, 3, 2)}

  defp expected_decode(tuple, _input), do: {:ok, Tuple.to_list(tuple)}
end

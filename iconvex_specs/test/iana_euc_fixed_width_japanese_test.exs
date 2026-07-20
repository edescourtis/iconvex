defmodule Iconvex.Specs.IANAEUCFixedWidthJapaneseTest do
  use ExUnit.Case, async: false
  import Bitwise

  @canonical "Extended_UNIX_Code_Fixed_Width_for_Japanese"

  test "registers both IANA names" do
    for name <- [@canonical, "csEUCFixWidJapanese"] do
      assert {:ok, %{canonical: @canonical}} = Iconvex.Registry.resolve(name)
    end
  end

  test "uses the complete two-byte representation of all four Japanese EUC code sets" do
    cases = [
      {<<0x00, ?A>>, "A"},
      {<<0x00, 0xA6>>, "ｦ"},
      {<<0xC6, 0xFC>>, "日"},
      {<<0xA2, 0x2F>>, "˘"}
    ]

    for {encoded, utf8} <- cases do
      assert Iconvex.convert(encoded, @canonical, "UTF-8") == {:ok, utf8}
      assert Iconvex.convert(utf8, "UTF-8", @canonical) == {:ok, encoded}
    end
  end

  test "exhausts all 65,536 fixed-width byte pairs against GNU EUC-JP mappings" do
    table = Iconvex.Tables.fetch!(%{id: :euc_jp, table_app: :iconvex})

    for value <- 0..0xFFFF do
      pair = <<value::16-big>>
      expected = expected_pair(pair, table)
      assert normalized(Iconvex.convert(pair, @canonical, "UTF-8")) == expected
    end
  end

  @tag timeout: 120_000
  test "matches transformed GNU EUC-JP output over every Unicode scalar" do
    all_scalars =
      0..0x10FFFF
      |> Stream.reject(&(&1 in 0xD800..0xDFFF))
      |> Stream.chunk_every(4_096)
      |> Enum.map(&List.to_string/1)
      |> IO.iodata_to_binary()

    {:ok, packed} =
      Iconvex.convert(all_scalars, "UTF-8", "EUC-JP", unrepresentable: :discard)

    expected = packed_to_fixed(packed, [])

    assert Iconvex.convert(all_scalars, "UTF-8", @canonical, unrepresentable: :discard) ==
             {:ok, expected}
  end

  test "reports odd input as incomplete and rejects structurally invalid pairs" do
    assert {:error, %{kind: :incomplete_sequence, offset: 0, sequence: <<0>>}} =
             Iconvex.convert(<<0>>, @canonical, "UTF-8")

    assert {:error, %{kind: :invalid_sequence, offset: 0, sequence: <<1, 1>>}} =
             Iconvex.convert(<<1, 1>>, @canonical, "UTF-8")
  end

  defp expected_pair(<<0, second>>, table) when second <= 0x7F do
    case elem(table.one, second) do
      nil -> {:error, :invalid_sequence}
      codepoints -> {:ok, codepoints |> Tuple.to_list() |> List.to_string()}
    end
  end

  defp expected_pair(<<0, second>>, table) when second in 0xA1..0xDF,
    do: expected_many(<<0x8E, second>>, table)

  defp expected_pair(<<first, second>>, table)
       when first in 0xA1..0xFE and second in 0xA1..0xFE,
       do: expected_many(<<first, second>>, table)

  defp expected_pair(<<first, second>>, table)
       when first in 0xA1..0xFE and second in 0x21..0x7E,
       do: expected_many(<<0x8F, first, second ||| 0x80>>, table)

  defp expected_pair(_pair, _table), do: {:error, :invalid_sequence}

  defp expected_many(bytes, table) do
    case Map.fetch(table.many, bytes) do
      {:ok, codepoints} -> {:ok, codepoints |> Tuple.to_list() |> List.to_string()}
      :error -> {:error, :invalid_sequence}
    end
  end

  defp normalized({:ok, output}), do: {:ok, output}
  defp normalized({:error, %{kind: kind}}), do: {:error, kind}

  defp packed_to_fixed(<<>>, result), do: result |> :lists.reverse() |> IO.iodata_to_binary()

  defp packed_to_fixed(<<byte, rest::binary>>, result) when byte <= 0x7F,
    do: packed_to_fixed(rest, [<<0, byte>> | result])

  defp packed_to_fixed(<<0x8E, byte, rest::binary>>, result),
    do: packed_to_fixed(rest, [<<0, byte>> | result])

  defp packed_to_fixed(<<0x8F, first, second, rest::binary>>, result),
    do: packed_to_fixed(rest, [<<first, second &&& 0x7F>> | result])

  defp packed_to_fixed(<<first, second, rest::binary>>, result),
    do: packed_to_fixed(rest, [<<first, second>> | result])
end

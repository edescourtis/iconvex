defmodule Iconvex.UCS4AllCodepointFastPathTest do
  use ExUnit.Case, async: true

  alias Iconvex.UnicodeCodec

  test "explicit UCS-4 keeps consecutive non-scalar surrogates between scalar runs" do
    codepoints =
      [0, 0xD7FF] ++ Enum.to_list(0xD800..0xDFFF) ++ [0xE000, 0x10FFFF, 0x110000, 0xFFFFFFFF]

    for {id, endian} <- [
          {:ucs4be, :big},
          {:ucs4le, :little},
          {:ucs4internal, :erlang.system_info(:endian)},
          {:ucs4swapped, swapped(:erlang.system_info(:endian))}
        ] do
      source = Enum.map_join(codepoints, &word32(&1, endian))
      assert UnicodeCodec.decode(%{id: id}, source) == {:ok, codepoints}
      assert UnicodeCodec.encode(%{id: id}, codepoints) == {:ok, source}
    end
  end

  test "explicit UCS-4 retains exact incomplete-sequence diagnostics" do
    assert UnicodeCodec.decode(%{id: :ucs4be}, <<0, 0, 0xD8, 0, 0xAA>>) ==
             {:error, :incomplete_sequence, 4, <<0xAA>>}
  end

  test "UTF-7 discard retains GNU shift state across malformed surrogate units" do
    vectors = [
      {"+2AA-", []},
      {"+2ADYAQ-", [0x36]},
      {"+2ADcAA-", [0x10000]},
      {"+3ADcAQ-", [0xDC00, 0xDC01]},
      {"+1//YANgB3ADcAeAA-", [0xD7FF, 0xC036, 0x77, 0x37, 0x78]}
    ]

    for {utf7, codepoints} <- vectors do
      expected = Enum.map_join(codepoints, &word32(&1, :big))

      assert Iconvex.convert!(utf7, "UTF-7", "UCS-4BE", invalid: :discard) == expected,
             utf7
    end
  end

  defp word32(value, :big), do: <<value::unsigned-big-32>>
  defp word32(value, :little), do: <<value::unsigned-little-32>>
  defp swapped(:big), do: :little
  defp swapped(:little), do: :big
end

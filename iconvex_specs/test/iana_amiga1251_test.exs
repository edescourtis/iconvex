defmodule Iconvex.Specs.IANAAmiga1251Test do
  use ExUnit.Case, async: false

  @source Path.expand("../priv/sources/iana/Amiga-1251", __DIR__)
  @manifest Path.expand("../priv/iana_amiga1251_manifest.etf", __DIR__)

  test "registers all IANA names" do
    for name <- ["Amiga-1251", "Ami1251", "Amiga1251", "Ami-1251", "csAmiga1251"] do
      assert {:ok, %{canonical: "Amiga-1251"}} = Iconvex.Registry.resolve(name)
    end
  end

  test "decodes and reverses every byte in IANA's equivalency table" do
    mappings = parse_source(File.read!(@source))
    input = :binary.list_to_bin(Enum.to_list(0..255))
    expected = 0..255 |> Enum.map(&Map.fetch!(mappings, &1)) |> List.to_string()

    assert Iconvex.convert(input, "Amiga-1251", "UTF-8") == {:ok, expected}
    assert Iconvex.convert(expected, "UTF-8", "Amiga-1251") == {:ok, input}
  end

  test "pins the official IANA registration" do
    manifest = @manifest |> File.read!() |> :erlang.binary_to_term()
    assert manifest.source_url == "https://www.iana.org/assignments/charset-reg/Amiga-1251"

    assert manifest.source_sha256 ==
             "3ca52cd54dbbbe861bdfcbf4bd7a6a1c8521d5d8ccd3291e17f4b5d50083cd0d"
  end

  defp parse_source(source) do
    Regex.scan(~r/^0x([0-9A-Fa-f]{2})\s+0x([0-9A-Fa-f]{4,6})\b/m, source, capture: :all_but_first)
    |> Map.new(fn [byte, codepoint] ->
      {String.to_integer(byte, 16), String.to_integer(codepoint, 16)}
    end)
  end
end

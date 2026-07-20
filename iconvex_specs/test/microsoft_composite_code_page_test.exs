defmodule Iconvex.Specs.MicrosoftCompositeCodePageTest do
  use ExUnit.Case, async: false

  @aliases %{
    "CP50930" => "ibm-930_P120-1999",
    "CP50931" => "ICU-ARCHIVE-ibm-931_P120-1999",
    "CP50933" => "ibm-933_P110-1995",
    "CP50935" => "ibm-935_P110-1999",
    "CP50937" => "ibm-937_P110-1999",
    "CP50939" => "ibm-939_P120-1999"
  }

  test "registers Microsoft's composite EBCDIC page identifiers" do
    for {alias_name, canonical} <- @aliases do
      assert {:ok, %{canonical: ^canonical}} = Iconvex.Registry.resolve(alias_name)

      assert {:ok, %{canonical: ^canonical}} =
               Iconvex.Registry.resolve(String.replace(alias_name, "CP", "windows-"))
    end
  end

  test "Microsoft aliases are byte-identical to their pinned IBM CCSID mappings" do
    samples = [0x0000, 0x000A, 0x0041, 0x0061, 0x00A5, 0x203E, 0x3000, 0x3042, 0x4E00, 0xAC00]

    for {alias_name, canonical} <- @aliases do
      representable =
        Enum.filter(samples, fn codepoint ->
          match?({:ok, _}, Iconvex.convert(List.to_string([codepoint]), "UTF-8", canonical))
        end)

      utf8 = List.to_string(representable)

      assert Iconvex.convert(utf8, "UTF-8", alias_name) ==
               Iconvex.convert(utf8, "UTF-8", canonical)

      {:ok, bytes} = Iconvex.convert(utf8, "UTF-8", canonical)

      assert Iconvex.convert(bytes, alias_name, "UTF-8") ==
               Iconvex.convert(bytes, canonical, "UTF-8")
    end
  end
end

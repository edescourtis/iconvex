defmodule Iconvex.Specs.DotnetXEuropaTest do
  use ExUnit.Case, async: false

  @source Path.expand("../priv/sources/dotnet-runtime-codepages/codepages.nlp", __DIR__)
  @manifest Path.expand("../priv/dotnet_codepages_manifest.etf", __DIR__)

  test "registers the Microsoft and .NET names" do
    for name <- ["x-Europa", "CP29001", "windows-29001", "Europa"] do
      assert {:ok, %{canonical: "x-Europa"}} = Iconvex.Registry.resolve(name)
    end
  end

  test "decodes and reverses every .NET CP29001 byte" do
    input = :binary.list_to_bin(Enum.to_list(0..255))
    expected = @source |> File.read!() |> cp29001_table() |> List.to_string()

    assert Iconvex.convert(input, "x-Europa", "UTF-8") == {:ok, expected}
    assert Iconvex.convert(expected, "UTF-8", "x-Europa") == {:ok, input}
  end

  test "pins the complete .NET source set and documents the table identity" do
    manifest = @manifest |> File.read!() |> :erlang.binary_to_term()
    assert manifest.revision == "dbb2178288bb4e1e8f1fde3958be3bd75573c459"

    assert manifest.aggregate_sha256 ==
             "710a341a09f90bec6ec66e01d44620bf6485b4420b92a6075e45f5e38f860cdf"

    assert {"codepages.nlp", "0cad998c5e9776cdbbfc34e5687931d771018f8df9c3bf741b3e2e676533e9fb"} in manifest.sources
  end

  defp cp29001_table(binary) do
    <<_header::binary-size(44), indexes::binary-size(109 * 40), _::binary>> = binary

    offsets =
      for <<_name::binary-size(32), code_page::little-16, _byte_count::little-16,
            offset::little-32 <- indexes>>,
          code_page == 29_001,
          do: offset

    offset = List.first(offsets)

    <<_::binary-size(offset + 48), mappings::binary-size(512), _::binary>> = binary
    for <<codepoint::little-16 <- mappings>>, do: codepoint
  end
end

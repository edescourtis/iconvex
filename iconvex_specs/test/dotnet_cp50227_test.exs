defmodule Iconvex.Specs.DotnetCP50227Test do
  use ExUnit.Case, async: false

  @provider_source Path.expand(
                     "../priv/sources/dotnet-runtime-codepages/CodePagesEncodingProvider.cs",
                     __DIR__
                   )

  test "registers .NET's x-cp50227 names" do
    for name <- ["x-cp50227", "CP50227", "windows-50227"] do
      assert {:ok, %{canonical: "x-cp50227"}} = Iconvex.Registry.resolve(name)
    end
  end

  @tag timeout: 120_000
  test "matches .NET's documented CP936 delegation over every Unicode scalar" do
    source = File.read!(@provider_source)
    assert source =~ "case ISOSimplifiedCN:"
    assert source =~ "new DBCSCodePageEncoding(codepage, EUCCN)"

    all_scalars =
      0..0x10FFFF
      |> Stream.reject(&(&1 in 0xD800..0xDFFF))
      |> Stream.chunk_every(4_096)
      |> Enum.map(&List.to_string/1)
      |> IO.iodata_to_binary()

    assert Iconvex.convert(all_scalars, "UTF-8", "x-cp50227", unrepresentable: :discard) ==
             Iconvex.convert(all_scalars, "UTF-8", "CP936", unrepresentable: :discard)
  end

  test "is byte-identical to CP936 in both strict directions" do
    utf8 = "ASCII 中文 € 😀"

    assert normalized(Iconvex.convert(utf8, "UTF-8", "x-cp50227")) ==
             normalized(Iconvex.convert(utf8, "UTF-8", "CP936"))

    for bytes <- [<<0>>, <<?A>>, <<0xD6, 0xD0>>, <<0x81>>, <<0xFF>>] do
      assert normalized(Iconvex.convert(bytes, "x-cp50227", "UTF-8")) ==
               normalized(Iconvex.convert(bytes, "CP936", "UTF-8"))
    end
  end

  defp normalized({:ok, output}), do: {:ok, output}

  defp normalized({:error, error}),
    do: {:error, error.kind, error.offset, error.sequence, error.codepoint}
end

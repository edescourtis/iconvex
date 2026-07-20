defmodule Iconvex.Specs.GlibcIBM423Test do
  use ExUnit.Case, async: true

  alias Iconvex.Specs.GlibcIBM423

  @revision "e5145be467bed28bafde33a51df97840be37065e"
  @source_dir Path.expand("../priv/sources/glibc-#{@revision}-ibm423", __DIR__)
  @hashes %{
    "ibm423.c" => "0d1f50f21a2b7ec6375e1ad8a35258b3993d0220b7d4089fb0408e229ae67067",
    "IBM423" => "8c5890f6c82ceef0231fd61f4bd661e1fd8cadd88e1944be2b31c967a9f1e02e"
  }

  test "pins linked glibc implementation and generated-table source" do
    for {filename, digest} <- @hashes do
      source = File.read!(Path.join(@source_dir, filename))
      assert sha256(source) == digest
    end

    assert File.read!(Path.join(@source_dir, "ibm423.c")) =~ "#include <ibm423.h>"

    source_note = File.read!(Path.join(@source_dir, "SOURCE.md"))
    assert source_note =~ "all 246 defined byte positions"
    assert source_note =~ "against Iconvex Specs"
    refute source_note =~ "all 249 defined byte positions"
    refute source_note =~ "against Iconvex Extras"
  end

  test "registers collision-free glibc revision names" do
    for name <- ["GLIBC-IBM423", "IBM423-GLIBC", "GLIBC-CP423"] do
      assert {:ok, %{canonical: "GLIBC-IBM423", codec: GlibcIBM423}} =
               Iconvex.Registry.resolve(name)
    end
  end

  test "all 256 byte positions match glibc IBM423 charmap" do
    decode = glibc_decode_map()
    assert map_size(decode) == 246

    for byte <- 0..255 do
      case Map.fetch(decode, byte) do
        {:ok, codepoint} -> assert GlibcIBM423.decode(<<byte>>) == {:ok, [codepoint]}
        :error -> assert {:error, :invalid_sequence, 0, <<^byte>>} = GlibcIBM423.decode(<<byte>>)
      end
    end
  end

  test "every glibc scalar encodes to its canonical IBM423 byte" do
    for {byte, codepoint} <- glibc_decode_map() do
      assert GlibcIBM423.encode([codepoint]) == {:ok, <<byte>>}
    end
  end

  defp glibc_decode_map do
    @source_dir
    |> Path.join("IBM423")
    |> File.stream!()
    |> Enum.reduce(%{}, fn line, acc ->
      case Regex.run(~r/^<U([0-9A-F]{4,6})>\s+\/x([0-9a-f]{2})\s/, line) do
        [_, unicode, byte] ->
          Map.put(acc, String.to_integer(byte, 16), String.to_integer(unicode, 16))

        nil ->
          acc
      end
    end)
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

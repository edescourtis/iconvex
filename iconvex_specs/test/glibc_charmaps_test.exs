defmodule Iconvex.Specs.GlibcCharmapsTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.GlibcCharmaps

  test "pins the glibc TSCII 1.7 and BRF charmaps" do
    hashes = Map.new(GlibcCharmaps.sources(), &{&1.name, &1.sha256})

    assert Map.take(hashes, ["BRF", "TSCII"]) == %{
             "BRF" => "99c43b9b82fe6c030fa3ae77cf5b77affb2ae7afbc508f0a9bd7fc10b5c5aac8",
             "TSCII" => "7c6fbda96b4ec82701d330926b5d3ef710d37a53dd33daccb6f758fb76bbffbb"
           }
  end

  test "implements BRF braille cells and controls" do
    assert GlibcCharmaps.decode("BRF", <<0x41, 0x42>>) == {:ok, [0x2801, 0x2803]}
    assert GlibcCharmaps.encode("BRF", [0x2801, 0x2803]) == {:ok, <<0x41, 0x42>>}
    assert GlibcCharmaps.decode("BRF", <<0x0A>>) == {:ok, [0x0A]}
  end

  test "Braille ASCII is the registered BRF wire mapping" do
    assert Iconvex.canonical_name("BRAILLE-ASCII") == {:ok, "BRF"}

    all_bytes = :binary.list_to_bin(Enum.to_list(0..0x7F))

    assert Iconvex.convert(all_bytes, "BRAILLE-ASCII", "UTF-8") ==
             Iconvex.convert(all_bytes, "BRF", "UTF-8")
  end

  test "implements TSCII multi-codepoint glyphs and multibyte compositions" do
    assert GlibcCharmaps.decode("TSCII", <<0x82>>) ==
             {:ok, [0x0BB8, 0x0BCD, 0x0BB0, 0x0BC0]}

    assert GlibcCharmaps.decode("TSCII", <<0x83, 0xA4>>) == {:ok, [0x0B9C, 0x0BC1]}
    assert GlibcCharmaps.decode("TSCII", <<0xA6, 0xB8>>) == {:ok, [0x0B95, 0x0BC6]}

    assert GlibcCharmaps.encode("TSCII", [0x0BB8, 0x0BCD, 0x0BB0, 0x0BC0]) ==
             {:ok, <<0x82>>}
  end

  test "executes every generated decoder and encoder mapping" do
    for entry <- GlibcCharmaps.encodings() do
      table = Iconvex.Tables.fetch!(%{id: entry.id, table_app: :iconvex_specs})

      mappings =
        Map.merge(
          table.many,
          table.one
          |> Tuple.to_list()
          |> Enum.with_index()
          |> Enum.reject(fn {value, _byte} -> is_nil(value) end)
          |> Map.new(fn {value, byte} -> {<<byte>>, value} end)
        )

      assert map_size(mappings) == entry.decode_mappings

      for {bytes, codepoints} <- mappings do
        assert GlibcCharmaps.decode(entry.name, bytes) == {:ok, Tuple.to_list(codepoints)}
      end

      for {codepoints, bytes} <- table.encode do
        assert GlibcCharmaps.encode(entry.name, Tuple.to_list(codepoints)) == {:ok, bytes}
      end
    end
  end

  test "registers both codecs" do
    assert Iconvex.canonical_name("TSCII") == {:ok, "TSCII"}
    assert Iconvex.canonical_name("BRF") == {:ok, "BRF"}
  end
end

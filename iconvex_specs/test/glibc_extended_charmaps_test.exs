defmodule Iconvex.Specs.GlibcExtendedCharmapsTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.GlibcCharmaps

  @revision "cdfa80fad3d52217ae986f9acdcbdbfc94b3da3e"

  @extended ~w(
    CP770 CP771 CP772 CP773 CP774 CWI EBCDIC-IS-FRISS EUC-JP-MS
    HP-GREEK8 HP-ROMAN9 HP-THAI8 HP-TURKISH8 IBM1004 IBM256 IBM866NAV
    ISIRI-3342 ISO-8859-9E ISO-IR-197 ISO-IR-209 ISO_11548-1 ISO_6937
    KOI-8 MAC-IS MAC-SAMI MAC-UK MIK WIN-SAMI-2
  )

  test "pins every glibc charmap still absent from the co-installed Iconvex stack" do
    assert GlibcCharmaps.revision() == @revision

    names = GlibcCharmaps.encodings() |> Enum.map(& &1.name) |> MapSet.new()
    assert Enum.all?(@extended, &MapSet.member?(names, &1))
    assert length(GlibcCharmaps.encodings()) == 29
  end

  test "covers representative single-byte, multibyte, combining, and braille mappings" do
    assert GlibcCharmaps.decode("HP-ROMAN9", <<0xBA>>) == {:ok, [0x20A0]}
    assert GlibcCharmaps.decode("ISO_11548-1", <<0xFF>>) == {:ok, [0x28FF]}
    assert GlibcCharmaps.decode("ISO_6937", <<0xC1, 0x41>>) == {:ok, [0x00C0]}
    assert GlibcCharmaps.encode("ISO_6937", [0x00C0]) == {:ok, <<0xC1, 0x41>>}
    assert GlibcCharmaps.decode("EUC-JP-MS", <<0xA1, 0xA1>>) == {:ok, [0x3000]}
  end

  test "registers the full extended family and source aliases" do
    for name <- @extended do
      assert Iconvex.canonical_name(name) == {:ok, name}
    end

    assert Iconvex.canonical_name("ISO6937") == {:ok, "ISO_6937"}
    assert Iconvex.canonical_name("CP-HU") == {:ok, "CWI"}
    assert Iconvex.canonical_name("WINDOWS-SAMI2") == {:ok, "WIN-SAMI-2"}
  end

  test "executes every pinned CHARMAP row in both directions" do
    sources = Map.new(GlibcCharmaps.sources(), &{&1.file, &1})

    for entry <- GlibcCharmaps.encodings() do
      source = Map.fetch!(sources, entry.source_file)
      path = Path.join([File.cwd!(), "priv", "sources", "glibc", source.file])
      content = File.read!(path)

      assert :crypto.hash(:sha256, content) |> Base.encode16(case: :lower) == source.sha256

      rows = parse_rows(content)

      decode =
        Enum.reduce(rows, %{}, fn {bytes, codepoints}, mappings ->
          Map.put_new(mappings, bytes, codepoints)
        end)

      encode =
        Enum.reduce(rows, %{}, fn {bytes, codepoints}, mappings ->
          Map.put_new(mappings, codepoints, bytes)
        end)

      assert map_size(decode) == entry.decode_mappings
      assert map_size(encode) == entry.encode_mappings

      for {bytes, codepoints} <- decode do
        assert GlibcCharmaps.decode(entry.name, bytes) == {:ok, Tuple.to_list(codepoints)}
      end

      for {codepoints, bytes} <- encode do
        assert GlibcCharmaps.encode(entry.name, Tuple.to_list(codepoints)) == {:ok, bytes}
      end
    end
  end

  defp parse_rows(content) do
    content
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      case Regex.run(
             ~r/^(?:%IRREVERSIBLE%)?((?:<U[0-9A-Fa-f]+>)+)\s+((?:\/x[0-9A-Fa-f]{2})+)/,
             line,
             capture: :all_but_first
           ) do
        [unicode, encoded] ->
          codepoints =
            Regex.scan(~r/<U([0-9A-Fa-f]+)>/, unicode, capture: :all_but_first)
            |> List.flatten()
            |> Enum.map(&String.to_integer(&1, 16))
            |> List.to_tuple()

          bytes =
            Regex.scan(~r/\/x([0-9A-Fa-f]{2})/, encoded, capture: :all_but_first)
            |> List.flatten()
            |> Enum.map(&String.to_integer(&1, 16))
            |> :binary.list_to_bin()

          [{bytes, codepoints}]

        nil ->
          []
      end
    end)
  end
end

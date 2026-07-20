defmodule Iconvex.Specs.KermitVersionedSingleByteTest do
  use ExUnit.Case, async: false

  @kermit Path.expand(
            "../priv/sources/dec-terminal-character-sets/kermit/ckcuni.c",
            __DIR__
          )
  @greek_ucm Path.expand("../priv/sources/icu-data-archive/iso-8859_7-1987.ucm", __DIR__)
  @mac_ucm Path.expand("../priv/sources/icu-data-archive/windows-10079-2000.ucm", __DIR__)
  @latin6_gnu Path.expand(
                "../priv/sources/kermit-versioned-single-byte/ISO-8859-10.TXT",
                __DIR__
              )

  @profiles [
    {"GREEK-ISO", ["ELOT928-GREEK", "ELOT-928"], :greek},
    {"HEBREW-ISO", ["ISO-8859-8-1988-HISTORICAL"], :hebrew},
    {"LATIN6-ISO", ["ISO-8859-10-LATIN6-STANDARD"], :latin6},
    {"MACINTOSH-LATIN", ["MAC-LATIN-KERMIT", "MAC-ICELAND-10079"], :mac}
  ]

  test "RED: versioned profiles decode every octet exactly from independent sources" do
    source = File.read!(@kermit)
    greek = ucm_table(@greek_ucm)
    hebrew = kermit_table(source, "u_8859_8", 0xA0, 96)
    latin6 = mapping_txt_table(@latin6_gnu)
    mac = ucm_table(@mac_ucm)

    assert greek == kermit_table(source, "u_8859_7", 0xA0, 96)
    assert mac == kermit_table(source, "u_maclatin", 0x80, 128)

    for {encoding, table} <- [
          {"GREEK-ISO", greek},
          {"HEBREW-ISO", hebrew},
          {"LATIN6-ISO", latin6},
          {"MACINTOSH-LATIN", mac}
        ],
        byte <- 0x00..0xFF do
      case elem(table, byte) do
        nil ->
          assert {:error, %Iconvex.Error{kind: :invalid_sequence, offset: 0}} =
                   Iconvex.convert(<<byte>>, encoding, "UTF-8")

        codepoint ->
          assert Iconvex.convert(<<byte>>, encoding, "UTF-32BE") ==
                   {:ok, <<codepoint::unsigned-big-32>>}
      end
    end
  end

  test "each profile encodes its complete canonical inverse" do
    source = File.read!(@kermit)

    tables = %{
      greek: ucm_table(@greek_ucm),
      hebrew: kermit_table(source, "u_8859_8", 0xA0, 96),
      latin6: mapping_txt_table(@latin6_gnu),
      mac: ucm_table(@mac_ucm)
    }

    for {canonical, _aliases, id} <- @profiles do
      expected_inverse = canonical_inverse(Map.fetch!(tables, id))

      for {codepoint, byte} <- expected_inverse do
        assert Iconvex.convert(<<codepoint::unsigned-big-32>>, "UTF-32BE", canonical) ==
                 {:ok, <<byte>>}
      end

      assert {:error, %Iconvex.Error{kind: :unrepresentable_character}} =
               Iconvex.convert(<<0x10FFFF::unsigned-big-32>>, "UTF-32BE", canonical)
    end
  end

  test "direct UTF-8 paths cross chunk boundaries without changing any valid octet" do
    source = File.read!(@kermit)

    tables = %{
      "GREEK-ISO" => ucm_table(@greek_ucm),
      "HEBREW-ISO" => kermit_table(source, "u_8859_8", 0xA0, 96),
      "LATIN6-ISO" => mapping_txt_table(@latin6_gnu),
      "MACINTOSH-LATIN" => ucm_table(@mac_ucm)
    }

    for {encoding, table} <- tables do
      one_pass =
        table
        |> Tuple.to_list()
        |> Enum.with_index()
        |> Enum.reject(fn {codepoint, _byte} -> is_nil(codepoint) end)

      encoded =
        one_pass |> Enum.map(fn {_codepoint, byte} -> byte end) |> :erlang.list_to_binary()

      utf8 =
        one_pass
        |> Enum.map(fn {codepoint, _byte} -> <<codepoint::utf8>> end)
        |> IO.iodata_to_binary()

      encoded = :binary.copy(encoded, 32)
      utf8 = :binary.copy(utf8, 32)

      assert Iconvex.convert(encoded, encoding, "UTF-8") == {:ok, utf8}
      assert Iconvex.convert(utf8, "UTF-8", encoding) == {:ok, encoded}
    end
  end

  test "aliases, discard policy, offsets, and malformed UTF-8 use native paths" do
    for {canonical, aliases, _id} <- @profiles, alias_name <- aliases do
      assert Iconvex.canonical_name(alias_name) == {:ok, canonical}
    end

    assert {:error, %Iconvex.Error{kind: :invalid_sequence, offset: 1, encoding: "GREEK-ISO"}} =
             Iconvex.convert(<<0x41, 0xA4>>, "GREEK-ISO", "UTF-8")

    assert Iconvex.convert(<<0x41, 0xA4, 0x42>>, "GREEK-ISO", "UTF-8", invalid: :discard) ==
             {:ok, "AB"}

    assert Iconvex.convert("A🙂B", "UTF-8", "LATIN6-ISO", unrepresentable: :discard) ==
             {:ok, "AB"}

    assert {:error, %Iconvex.Error{kind: :incomplete_sequence, offset: 1}} =
             Iconvex.convert(<<0x41, 0xC2>>, "UTF-8", "MACINTOSH-LATIN")

    assert {:error, %Iconvex.Error{kind: :invalid_sequence, offset: 1}} =
             Iconvex.convert(<<0x41, 0xFF>>, "UTF-8", "HEBREW-ISO")
  end

  test "bounded UTF-8 parsing preserves split scalars and first-error ordering" do
    prefix = :binary.copy("A", 65_535)
    split_bullet = prefix <> <<0xE2, 0x88, 0x99>> <> "B"
    expected = :binary.copy(<<0x41>>, 65_535) <> <<0x95, 0x42>>

    assert Iconvex.Specs.KOI8F.encode_from_utf8(split_bullet) == {:ok, expected}

    assert Iconvex.Specs.KOI8F.encode_from_utf8(prefix <> <<0xE2, 0x88>>) ==
             {:decode_error, :incomplete_sequence, 65_535, <<0xE2, 0x88>>}

    assert Iconvex.Specs.KOI8F.encode_from_utf8(prefix <> <<0xFF>>) ==
             {:decode_error, :invalid_sequence, 65_535, <<0xFF>>}

    suffix = :binary.copy("B", 128)

    assert Iconvex.Specs.KOI8F.encode_from_utf8(prefix <> <<0xFF>> <> suffix) ==
             {:decode_error, :invalid_sequence, 65_535, <<0xFF>> <> suffix}

    assert Iconvex.Specs.KOI8F.encode_from_utf8("🙂" <> <<0xFF>>) ==
             {:error, :unrepresentable_character, 0x1F642}

    assert Iconvex.Specs.KOI8F.encode_from_utf8(<<0xFF>> <> "🙂") ==
             {:decode_error, :invalid_sequence, 0, <<0xFF, 0xF0, 0x9F, 0x99, 0x82>>}
  end

  test "historical identities and Kermit deviations are permanently guarded" do
    source = File.read!(@kermit)
    greek = ucm_table(@greek_ucm)
    hebrew = kermit_table(source, "u_8859_8", 0xA0, 96)
    latin6 = mapping_txt_table(@latin6_gnu)
    mac = ucm_table(@mac_ucm)

    assert table_difference(greek, rfc_table("ISO_8859-7:1987")) == 4
    assert table_difference(hebrew, rfc_table("ISO_8859-8:1988")) == 0
    kermit_latin6 = kermit_table(source, "u_8859_10", 0xA0, 96)
    assert table_difference(latin6, kermit_latin6) == 16
    assert table_difference(rfc_table("latin6"), kermit_latin6) == 5
    assert table_difference(mac, kermit_table(source, "u_maclatin", 0x80, 128)) == 0

    assert sha256(@kermit) == "af93d5a1c779aa73fa3221ab5ec0125de20267110cf23395971ce35cc88527ca"

    assert sha256(@greek_ucm) ==
             "dbbc16acd5773a6635ce2acb9c6901db4c1749e0d5ab107512fc93e8d92ff413"

    assert sha256(@mac_ucm) == "2c57ea0726702163983481661b8f8ffe532e9f1060c57f4cdb9f196294d0ef04"

    assert sha256(@latin6_gnu) ==
             "03605555e750ac5a2a34c9d9943e3fb823e1f8c46bc0316ff556dce0dbbdfe27"
  end

  defp ucm_table(path) do
    mappings =
      ~r/<U([0-9A-Fa-f]{4,6})>\s+\\x([0-9A-Fa-f]{2})\s+\|0/
      |> Regex.scan(File.read!(path), capture: :all_but_first)
      |> Map.new(fn [codepoint, byte] ->
        {String.to_integer(byte, 16), String.to_integer(codepoint, 16)}
      end)

    List.to_tuple(for byte <- 0x00..0xFF, do: Map.get(mappings, byte))
  end

  defp mapping_txt_table(path) do
    mappings =
      ~r/^0x([0-9A-Fa-f]{2})\s+0x([0-9A-Fa-f]{4,6})/m
      |> Regex.scan(File.read!(path), capture: :all_but_first)
      |> Map.new(fn [byte, codepoint] ->
        {String.to_integer(byte, 16), String.to_integer(codepoint, 16)}
      end)

    List.to_tuple(for byte <- 0x00..0xFF, do: Map.get(mappings, byte))
  end

  defp kermit_table(source, name, offset, size) do
    pattern = ~r/struct\s+x_to_unicode\s+#{Regex.escape(name)}\s*=\s*\{(?<body>.*?)\n\};/s
    %{"body" => body} = Regex.named_captures(pattern, source)

    high =
      ~r/0x([0-9A-Fa-f]+)/
      |> Regex.scan(body, capture: :all_but_first)
      |> Enum.take(size)
      |> Enum.map(fn
        [replacement] when replacement in ["fffd", "FFFD"] -> nil
        [hex] -> String.to_integer(hex, 16)
      end)

    List.to_tuple(for byte <- 0x00..0xFF, do: kermit_codepoint(byte, offset, high))
  end

  defp kermit_codepoint(byte, offset, _high) when byte < offset, do: byte

  defp kermit_codepoint(byte, offset, high) when byte < offset + length(high),
    do: Enum.at(high, byte - offset)

  defp kermit_codepoint(_byte, _offset, _high), do: nil

  defp rfc_table(name) do
    List.to_tuple(
      for byte <- 0x00..0xFF do
        case Iconvex.Specs.RFC1345.decode(name, <<byte>>) do
          {:ok, [codepoint]} -> codepoint
          {:error, _, _, _} -> nil
        end
      end
    )
  end

  defp canonical_inverse(table) do
    table
    |> Tuple.to_list()
    |> Enum.with_index()
    |> Enum.reject(fn {codepoint, _byte} -> is_nil(codepoint) end)
    |> Enum.reduce(%{}, fn {codepoint, byte}, acc -> Map.put_new(acc, codepoint, byte) end)
  end

  defp table_difference(left, right) do
    left
    |> Tuple.to_list()
    |> Enum.zip(Tuple.to_list(right))
    |> Enum.count(fn {a, b} -> a != b end)
  end

  defp sha256(path) do
    path |> File.read!() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
  end
end

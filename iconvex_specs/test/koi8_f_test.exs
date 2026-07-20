defmodule Iconvex.Specs.KOI8FTest do
  use ExUnit.Case, async: false

  @source Path.expand("../priv/sources/koi8-f/KOI8UNI.TXT", __DIR__)
  @source_sha256 "9b24e0aa3d0eaf1ebacfb7cbb1ef435793c7542a3cf99fc20f90923fccba15cd"
  @codec Module.concat([Iconvex, Specs, KOI8F])

  test "RED: the complete permissively licensed KOI8-F mapping is pinned" do
    assert File.regular?(@source)
    assert sha256(@source) == @source_sha256

    table = source_table()
    assert map_size(table) == 256
    assert Map.keys(table) |> Enum.sort() == Enum.to_list(0x00..0xFF)
    assert table[0x95] == 0x2219
    assert table[0x9A] == 0x00A0
    assert table[0xA0] == 0x00A0

    source = File.read!(@source)
    assert source =~ "Permission is hereby granted, free of charge"
    assert source =~ "KOI8 Unified Cyrillic to Unicode 2.1 mapping table"
    assert source =~ "Adjusted to match RFC1489 for 0x95"
  end

  test "every octet decodes exactly as the authoritative mapping" do
    for {byte, codepoint} <- source_table() do
      assert Iconvex.convert(<<byte>>, "KOI8-F", "UTF-32BE") ==
               {:ok, <<codepoint::unsigned-big-32>>}
    end
  end

  test "the encoder is the complete canonical inverse with the first duplicate preferred" do
    table = source_table()

    inverse =
      table
      |> Enum.sort()
      |> Enum.reduce(%{}, fn {byte, codepoint}, acc -> Map.put_new(acc, codepoint, byte) end)

    for {codepoint, byte} <- inverse do
      assert Iconvex.convert(<<codepoint::unsigned-big-32>>, "UTF-32BE", "KOI8-F") ==
               {:ok, <<byte>>}
    end

    assert inverse[0x00A0] == 0x9A
    assert Iconvex.convert(<<0xA0>>, "KOI8-F", "KOI8-F") == {:ok, <<0x9A>>}

    assert {:error, %Iconvex.Error{kind: :unrepresentable_character}} =
             Iconvex.convert(<<0x10FFFF::unsigned-big-32>>, "UTF-32BE", "KOI8-F")
  end

  test "registry names and source-qualified aliases are collision-safe" do
    assert "KOI8-F" in Iconvex.Specs.encodings()
    assert length(Iconvex.Specs.encodings()) == 1_841
    assert length(Iconvex.Specs.codecs()) == 1_841

    for alias_name <- [
          "KOI8-UNIFIED",
          "KOI8-F-NMSU-2008",
          "KOI8-UNIFIED-NMSU-2008",
          "CP60270-NMSU-2008"
        ] do
      assert Iconvex.canonical_name(alias_name) == {:ok, "KOI8-F"}
    end

    assert apply(@codec, :canonical_name, []) == "KOI8-F"
  end

  test "native UTF-8 callbacks preserve full tables, malformed offsets, and policies" do
    encoded = :erlang.list_to_binary(Enum.to_list(0x00..0xFF))

    utf8 =
      source_table()
      |> Enum.sort()
      |> Enum.map(fn {_byte, codepoint} -> <<codepoint::utf8>> end)
      |> IO.iodata_to_binary()

    assert apply(@codec, :decode_to_utf8, [encoded]) == {:ok, utf8}

    canonical_encoded =
      encoded
      |> :binary.bin_to_list()
      |> Enum.map(fn
        0xA0 -> 0x9A
        byte -> byte
      end)
      |> :erlang.list_to_binary()

    assert apply(@codec, :encode_from_utf8, [utf8]) == {:ok, canonical_encoded}

    assert {:error, %Iconvex.Error{kind: :invalid_sequence, offset: 1, sequence: <<0xFF, "B">>}} =
             Iconvex.convert(<<"A", 0xFF, "B">>, "UTF-8", "KOI8-F")

    assert {:error, %Iconvex.Error{kind: :incomplete_sequence, offset: 1}} =
             Iconvex.convert(<<"A", 0xE2, 0x82>>, "UTF-8", "KOI8-F")

    assert Iconvex.convert("A🙂B", "UTF-8", "KOI8-F", unrepresentable: :discard) ==
             {:ok, "AB"}
  end

  defp source_table do
    @source
    |> File.stream!([], :line)
    |> Enum.reduce(%{}, fn line, acc ->
      case Regex.run(~r/^0x([0-9A-Fa-f]{2})\s+0x([0-9A-Fa-f]{4,6})\b/, line) do
        [_, byte, codepoint] ->
          Map.put(acc, String.to_integer(byte, 16), String.to_integer(codepoint, 16))

        nil ->
          acc
      end
    end)
  end

  defp sha256(path) do
    path
    |> File.read!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end

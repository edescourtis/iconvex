defmodule Iconvex.Specs.CPythonISO2022JPExtTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.CPythonISO2022JPExt, as: Codec

  @revision "c63aec69bd59c55314c06c23f4c22c03de76fe45"
  @source_dir Path.expand("../priv/sources/cpython-3.14.6-iso2022-jp-ext", __DIR__)
  @hashes %{
    "_codecs_iso2022.c" => "1dec516ad16a9aa179770b5accdd20efa77e7265c0a2a06d8d8913e4524c4010",
    "mappings_jp.h" => "09012ff9eb963073d42a8bce375c05484219537caa0cc2aa74baa63d5f3f1658",
    "iso2022_jp_ext.py" => "f4c9ed8f3031995faa224bcb10153d2b6144944477d1f27d1a6cc4a879fac34c"
  }

  test "registers CPython's public codec name and collision-free aliases" do
    for name <- [
          "ISO-2022-JP-EXT",
          "ISO2022-JP-EXT",
          "ISO2022_JP_EXT",
          "PYTHON-ISO2022-JP-EXT"
        ] do
      assert {:ok, %{canonical: "ISO-2022-JP-EXT", codec: Codec}} =
               Iconvex.Registry.resolve(name)
    end
  end

  test "pins CPython 3.14.6 implementation, generated maps, and exact designation order" do
    assert Codec.revision() == @revision

    for {filename, digest} <- @hashes do
      assert sha256(File.read!(Path.join(@source_dir, filename))) == digest
    end

    c = File.read!(Path.join(@source_dir, "_codecs_iso2022.c"))

    assert c =~
             ~r/iso2022_jp_ext_designations\[\].*?REGISTRY_JISX0208,\s*REGISTRY_JISX0212,\s*REGISTRY_JISX0201_R,\s*REGISTRY_JISX0201_K,\s*REGISTRY_JISX0208_O,\s*REGISTRY_SENTINEL/s

    assert c =~ "CONFIGDEF(jp_ext, NO_SHIFT | USE_JISX0208_EXT)"
  end

  @tag timeout: 180_000
  test "every designated byte cell decodes exactly like CPython 3.14.6" do
    cases =
      for(byte <- 0..255, do: <<byte>>) ++
        for(
          prefix <- [<<0x1B, "(B">>, <<0x1B, "(J">>, <<0x1B, "(I">>],
          byte <- 0..255,
          do: prefix <> <<byte>>
        ) ++
        for(
          prefix <- [<<0x1B, "$B">>, <<0x1B, "$@">>, <<0x1B, "$(D">>],
          first <- 0x21..0x7E,
          second <- 0x21..0x7E,
          do: prefix <> <<first, second>>
        ) ++
        for prefix <- [<<0x1B, "$B">>, <<0x1B, "$@">>, <<0x1B, "$(D">>],
            byte <- Enum.to_list(0x00..0x1A) ++ Enum.to_list(0x1C..0x1F) ++ [0x7F],
            do: prefix <> <<byte>>

    expected = python_decode(cases)

    mismatches =
      cases
      |> Enum.zip(expected)
      |> Enum.reduce([], fn {input, oracle}, acc ->
        actual = normalize_decode(Codec.decode(input))
        if actual == oracle, do: acc, else: [{Base.encode16(input), oracle, actual} | acc]
      end)

    assert length(cases) == 27_628
    assert Enum.take(mismatches, 20) == []
  end

  @tag timeout: 180_000
  test "every Unicode scalar has exact CPython encode success, bytes, and reset state" do
    {expected, oracle_hash} = python_scalar_encodings()
    assert map_size(expected) == 13_138
    assert oracle_hash == "5a1770f9abe36f718288a94ce1d8ffa29f218db0142cbde13c80e832bc9e970b"

    mismatches =
      scalar_ranges()
      |> Enum.reduce([], fn range, acc ->
        Enum.reduce(range, acc, fn codepoint, inner ->
          expected_result =
            case Map.fetch(expected, codepoint) do
              {:ok, bytes} -> {:ok, bytes}
              :error -> :unrepresentable
            end

          actual_result = normalize_encode(Codec.encode([codepoint]))

          if expected_result == actual_result,
            do: inner,
            else: [{codepoint, expected_result, actual_result} | inner]
        end)
      end)

    assert Enum.take(mismatches, 20) == []
  end

  test "mixed state, controls, resets, and malformed corpus match CPython" do
    valid = [
      "",
      "ASCII",
      "A¥‾あｶ丂",
      "日本語\nASCII",
      "ｱｲｳ\r\n亜",
      "\t\n\r"
    ]

    for utf8 <- valid do
      codepoints = String.to_charlist(utf8)
      assert Codec.encode(codepoints) == python_encode(utf8)
    end

    malformed = [
      <<0x1B>>,
      <<0x1B, ?$>>,
      <<0x1B, "$(">>,
      <<0x1B, "(Z">>,
      <<0x1B, "$B", 0x21>>,
      <<0x1B, "$B", 0x20, 0x21>>,
      <<0x1B, "$B", 0x7F, 0x21>>,
      <<0x1B, "$(D", 0x21>>,
      <<0x1B, "(I", 0x20>>,
      <<0x80>>,
      <<0xFF>>
    ]

    assert Enum.map(malformed, &normalize_decode(Codec.decode(&1))) == python_decode(malformed)

    stateful_controls = [
      <<0x1B, "$B", 0x24, 0x22, 0x0A, 0x24, 0x24>>,
      <<0x1B, "$(D", 0x30, 0x21, 0x09, 0x30, 0x22>>,
      <<0x1B, "(I", 0x36, 0x0D, 0x37>>
    ]

    assert Enum.map(stateful_controls, &normalize_decode(Codec.decode(&1))) ==
             python_decode(stateful_controls)
  end

  test "UTF-8 fast paths use same exact codec" do
    utf8 = "A¥‾あｶ丂"
    {:ok, encoded} = python_encode(utf8)

    assert Codec.encode_from_utf8(utf8) == {:ok, encoded}
    assert Codec.decode_to_utf8(encoded) == {:ok, utf8}
    assert Iconvex.convert(utf8, "UTF-8", "ISO-2022-JP-EXT") == {:ok, encoded}
    assert Iconvex.convert(encoded, "ISO-2022-JP-EXT", "UTF-8") == {:ok, utf8}
  end

  defp python_decode(cases) do
    input = temp_path("decode")
    File.write!(input, Enum.map_join(cases, "\n", &Base.encode16(&1, case: :lower)))

    script = ~S"""
    import sys
    for line in open(sys.argv[1], encoding="ascii"):
        data = bytes.fromhex(line.strip())
        try:
            text = data.decode("iso2022_jp_ext")
            print("O\t" + ",".join(str(ord(ch)) for ch in text))
        except UnicodeDecodeError:
            print("E")
    """

    {output, 0} = System.cmd("python3", ["-c", script, input])
    File.rm!(input)

    output
    |> String.split("\n", trim: true)
    |> Enum.map(fn
      "E" -> :error
      "O\t" -> {:ok, []}
      "O\t" <> values -> {:ok, values |> String.split(",") |> Enum.map(&String.to_integer/1)}
    end)
  end

  defp python_scalar_encodings do
    script = ~S"""
    import hashlib
    rows = []
    digest = hashlib.sha256()
    for cp in range(0x110000):
        if 0xD800 <= cp <= 0xDFFF:
            continue
        try:
            encoded = chr(cp).encode("iso2022_jp_ext")
        except UnicodeEncodeError:
            continue
        rows.append((cp, encoded))
        digest.update(cp.to_bytes(4, "big"))
        digest.update(len(encoded).to_bytes(2, "big"))
        digest.update(encoded)
    print("META\t%d\t%s" % (len(rows), digest.hexdigest()))
    for cp, encoded in rows:
        print("%d\t%s" % (cp, encoded.hex()))
    """

    {output, 0} = System.cmd("python3", ["-c", script])
    [meta | rows] = String.split(output, "\n", trim: true)
    ["META", count, hash] = String.split(meta, "\t")

    encodings =
      Map.new(rows, fn row ->
        [codepoint, hex] = String.split(row, "\t")
        {String.to_integer(codepoint), Base.decode16!(hex, case: :mixed)}
      end)

    assert map_size(encodings) == String.to_integer(count)
    {encodings, hash}
  end

  defp python_encode(utf8) do
    script = "import sys; print(sys.argv[1].encode('iso2022_jp_ext').hex())"

    case System.cmd("python3", ["-c", script, utf8], stderr_to_stdout: true) do
      {hex, 0} -> {:ok, hex |> String.trim() |> Base.decode16!(case: :mixed)}
      {_error, _status} -> :unrepresentable
    end
  end

  defp normalize_decode({:ok, codepoints}), do: {:ok, codepoints}
  defp normalize_decode({:error, _kind, _offset, _sequence}), do: :error

  defp normalize_encode({:ok, bytes}), do: {:ok, bytes}
  defp normalize_encode({:error, :unrepresentable_character, _codepoint}), do: :unrepresentable

  defp scalar_ranges, do: [0..0xD7FF, 0xE000..0x10FFFF]

  defp temp_path(label) do
    Path.join(
      System.tmp_dir!(),
      "iconvex-iso2022-jp-ext-#{label}-#{System.unique_integer([:positive])}"
    )
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

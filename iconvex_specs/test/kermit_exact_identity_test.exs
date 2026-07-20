defmodule Iconvex.Specs.KermitExactIdentityTest do
  use ExUnit.Case, async: false

  @source_path Path.expand(
                 "../priv/sources/dec-terminal-character-sets/kermit/ckcuni.c",
                 __DIR__
               )
  @source_sha256 "af93d5a1c779aa73fa3221ab5ec0125de20267110cf23395971ce35cc88527ca"

  @exact_tables [
    {"u_8859_6", "ISO-8859-6", 0xA0},
    {"u_8859_5", "ISO-8859-5", 0xA0},
    {"u_8859_1", "ISO-8859-1", 0xA0},
    {"u_8859_2", "ISO-8859-2", 0xA0},
    {"u_8859_3", "ISO-8859-3", 0xA0},
    {"u_8859_4", "ISO-8859-4", 0xA0},
    {"u_8859_9", "ISO-8859-9", 0xA0},
    {"u_8859_15", "ISO-8859-15", 0xA0},
    {"u_koi8", "KOI-8", 0xA0},
    {"u_fr_canadian", "CSA_Z243.4-1985-1", 0x21},
    {"u_danish", "DS_2089", 0x21},
    {"u_norwegian", "DS_2089", 0x21},
    {"u_french", "NF_Z_62-010_(1973)", 0x21},
    {"u_german", "DIN_66003", 0x21},
    {"u_italian", "IT", 0x21},
    {"u_jis0201r", "JIS_C6220-1969-ro", 0x21},
    {"u_spanish", "ES", 0x21}
  ]

  test "all 17 catalog bridges are byte-exact against the pinned Kermit tables" do
    source = File.read!(@source_path)
    assert sha256(source) == @source_sha256

    for {table_name, codec_name, first_byte} <- @exact_tables do
      expected = source_table(source, table_name)
      actual = runtime_table(codec_name, first_byte, length(expected))

      assert actual == normalize_undefined(expected),
             "#{table_name} differs from #{codec_name}"

      for {codepoint, index} <- Enum.with_index(expected), codepoint != 0xFFFD do
        byte = first_byte + index

        assert Iconvex.convert(<<codepoint::unsigned-big-32>>, "UTF-32BE", codec_name) ==
                 {:ok, <<byte>>},
               "#{codec_name} does not encode U+#{hex(codepoint)} back to 0x#{hex(byte)}"
      end
    end
  end

  test "historically similar titles remain separate when any byte differs" do
    source = File.read!(@source_path)

    assert difference_count(source, "u_8859_7", "ISO-8859-7", 0xA0) == 3
    assert difference_count(source, "u_8859_8", "ISO-8859-8", 0xA0) == 3
    assert difference_count(source, "u_8859_10", "ISO-8859-10", 0xA0) == 16
    assert difference_count(source, "u_maclatin", "MacRoman", 0x80) == 7
  end

  defp difference_count(source, table_name, codec_name, first_byte) do
    expected = source |> source_table(table_name) |> normalize_undefined()
    actual = runtime_table(codec_name, first_byte, length(expected))

    expected
    |> Enum.zip(actual)
    |> Enum.count(fn {left, right} -> left != right end)
  end

  defp runtime_table(codec_name, first_byte, size) do
    for byte <- first_byte..(first_byte + size - 1) do
      case Iconvex.convert(<<byte>>, codec_name, "UTF-32BE") do
        {:ok, <<codepoint::unsigned-big-32>>} -> codepoint
        {:error, %Iconvex.Error{kind: :invalid_sequence}} -> :undefined
      end
    end
  end

  defp source_table(source, table_name) do
    pattern =
      ~r/struct\s+x_to_unicode\s+#{Regex.escape(table_name)}\s*=\s*\{(?<body>.*?)\n\};/s

    %{"body" => body} = Regex.named_captures(pattern, source)

    ~r/0x([0-9A-Fa-f]+)/
    |> Regex.scan(body, capture: :all_but_first)
    |> Enum.map(fn [hex] -> String.to_integer(hex, 16) end)
  end

  defp normalize_undefined(table) do
    Enum.map(table, fn
      0xFFFD -> :undefined
      codepoint -> codepoint
    end)
  end

  defp hex(integer), do: integer |> Integer.to_string(16) |> String.upcase()
  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end

defmodule Iconvex.StateMachinePolicyMatrixTest do
  use ExUnit.Case, async: false

  @encodings [
    "HZ",
    "ISO-2022-KR",
    "ISO-2022-JP",
    "ISO-2022-JP-1",
    "ISO-2022-JP-2",
    "ISO-2022-JP-MS",
    "ISO-2022-CN",
    "ISO-2022-CN-EXT",
    "UTF-7"
  ]
  @policies [[], [invalid: :discard], [byte_substitute: "<%02x>"]]

  defp representative("HZ"), do: "A中文B"
  defp representative("ISO-2022-KR"), do: "A한글B"
  defp representative("ISO-2022-CN"), do: "A中文B"
  defp representative("ISO-2022-CN-EXT"), do: "A结中文B"
  defp representative("UTF-7"), do: "A+😀éB"
  defp representative("ISO-2022-JP-MS"), do: "A日本語B"
  defp representative(_japanese), do: "A日本語¥‾B"

  defp encoded_representative(encoding) do
    assert {:ok, encoded} = Iconvex.convert(representative(encoding), "UTF-8", encoding)
    encoded
  end

  test "every byte split is exactly one-shot under every source policy" do
    for encoding <- @encodings do
      input = encoded_representative(encoding)

      for options <- @policies do
        assert {:ok, expected} = Iconvex.convert(input, encoding, "UTF-8", options)

        for split <- 0..byte_size(input) do
          <<first::binary-size(split), second::binary>> = input
          assert {:ok, converter} = Iconvex.new(encoding, "UTF-8", options)
          assert {:ok, <<>>, converter} = Iconvex.feed(converter, first)
          assert {:ok, <<>>, converter} = Iconvex.feed(converter, second)
          assert {:ok, ^expected} = Iconvex.finish(converter)
        end
      end
    end
  end

  test "invalid byte at every state-machine position stays total and split-exact" do
    for encoding <- @encodings do
      input = encoded_representative(encoding)

      for insertion <- 0..byte_size(input) do
        <<prefix::binary-size(insertion), suffix::binary>> = input
        malformed = prefix <> <<0xFF>> <> suffix

        assert {:error, %Iconvex.Error{offset: offset}} =
                 Iconvex.convert(malformed, encoding, "UTF-8")

        assert offset <= insertion

        for options <- tl(@policies) do
          assert {:ok, expected} = Iconvex.convert(malformed, encoding, "UTF-8", options)
          assert {:ok, converter} = Iconvex.new(encoding, "UTF-8", options)
          assert {:ok, <<>>, converter} = Iconvex.feed(converter, prefix <> <<0xFF>>)
          assert {:ok, <<>>, converter} = Iconvex.feed(converter, suffix)
          assert {:ok, ^expected} = Iconvex.finish(converter)
        end
      end
    end
  end

  test "malformed designation, shift, pair, and truncation branches have exact policies" do
    cases = [
      {"HZ", "~", "", "<7e>"},
      {"HZ", "~x", "x", "<7e>x"},
      {"HZ", "~{!", "", "<21>"},
      {"HZ", <<0x80>>, "", "<80>"},
      {"ISO-2022-KR", <<0x1B, "$">>, "", "<1b><24>"},
      {"ISO-2022-KR", <<0x0E, ?A>>, "A", "<0e>A"},
      {"ISO-2022-CN", <<0x1B, "$">>, "", "<1b><24>"},
      {"ISO-2022-CN", <<0x0E, ?A>>, "A", "<0e>A"},
      {"ISO-2022-JP", <<0x1B, "$">>, "", "<1b><24>"},
      {"ISO-2022-JP", <<0x1B, ?x, ?A>>, "xA", "<1b>xA"},
      {"UTF-7", "+", "", "<2b>"},
      {"UTF-7", <<0xFF, ?A>>, "A", "<ff>A"}
    ]

    for {encoding, input, discarded, substituted} <- cases do
      assert {:ok, ^discarded} =
               Iconvex.convert(input, encoding, "UTF-8", invalid: :discard)

      assert {:ok, ^substituted} =
               Iconvex.convert(input, encoding, "UTF-8", byte_substitute: "<%02x>")
    end
  end

  test "HZ preserves GNU's literal-tilde encoder quirk exactly" do
    assert {:ok, "~"} = Iconvex.convert("~", "UTF-8", "HZ")

    assert {:error, %Iconvex.Error{kind: :incomplete_sequence, offset: 0}} =
             Iconvex.convert("~", "HZ", "UTF-8")

    assert {:ok, "~"} = Iconvex.convert("~~", "HZ", "UTF-8")
  end

  test "codec-native discard encoders skip invalid scalars without losing state" do
    for id <- [
          :hz,
          :iso2022_kr,
          :iso2022_jp,
          :iso2022_jp1,
          :iso2022_jp2,
          :iso2022_jpms,
          :iso2022_cn,
          :iso2022_cn_ext,
          :utf7
        ] do
      assert {:ok, encoded} = Iconvex.StatefulCodec.encode_discard(%{id: id}, [?A, 0x110000, ?B])
      assert {:ok, [?A, ?B]} = Iconvex.StatefulCodec.decode(%{id: id}, encoded)
    end

    assert {:error, :unsupported_conversion, 0, <<>>} =
             Iconvex.StatefulCodec.decode(%{id: :unknown}, <<>>)

    assert {:error, :unsupported_conversion, 0} =
             Iconvex.StatefulCodec.encode(%{id: :unknown}, [])

    assert {:error, :unsupported_conversion, 0} =
             Iconvex.StatefulCodec.encode_discard(%{id: :unknown}, [])
  end
end

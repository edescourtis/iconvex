defmodule Iconvex.DeepDiveRegressionTest do
  use ExUnit.Case, async: false

  defmodule StableA do
    use Iconvex.Codec
    def canonical_name, do: "X-STABLE"
    def aliases, do: []
    def codec_id, do: :stable_a
    def decode(input), do: {:ok, for(<<_ <- input>>, do: ?A)}
    def decode_discard(input), do: decode(input)
    def decode_chunk(input, _final?), do: {:ok, for(<<_ <- input>>, do: ?A), <<>>}
    def encode(codepoints), do: {:ok, :binary.copy("a", length(codepoints))}
    def encode_discard(codepoints), do: encode(codepoints)
    def encode_substitute(codepoints, _replacer), do: encode(codepoints)
  end

  defmodule StableB do
    use Iconvex.Codec
    def canonical_name, do: "X-STABLE"
    def aliases, do: []
    def codec_id, do: :stable_b
    def decode(input), do: {:ok, for(<<_ <- input>>, do: ?B)}
    def decode_discard(input), do: decode(input)
    def decode_chunk(input, _final?), do: {:ok, for(<<_ <- input>>, do: ?B), <<>>}
    def encode(codepoints), do: {:ok, :binary.copy("b", length(codepoints))}
    def encode_discard(codepoints), do: encode(codepoints)
    def encode_substitute(codepoints, _replacer), do: encode(codepoints)
  end

  test "RED: malformed ISO-2022-JP discard and byte substitution retain JIS state" do
    input =
      <<0x1B, 0x24, 0x42, 0x24, 0x22, 0xFF, 0x24, 0x24, 0x1B, 0x28, 0x42>>

    assert Iconvex.convert(input, "ISO-2022-JP", "UTF-8", invalid: :discard) ==
             {:ok, "あい"}

    assert Iconvex.convert(input, "ISO-2022-JP", "UTF-8", byte_substitute: "<%02x>") ==
             {:ok, "あ<ff>い"}

    chunks = for <<byte <- input>>, do: <<byte>>

    assert chunks
           |> Iconvex.stream!("ISO-2022-JP", "UTF-8", invalid: :discard)
           |> Enum.join() == "あい"

    assert chunks
           |> Iconvex.stream!("ISO-2022-JP", "UTF-8", byte_substitute: "<%02x>")
           |> Enum.join() == "あ<ff>い"
  end

  test "streaming retains incomplete UTF-8 under every malformed-input policy" do
    for options <- [[], [invalid: :discard], [byte_substitute: "<%02x>"]] do
      assert {:ok, converter} = Iconvex.new("UTF-8", "UTF-8", options)
      assert {:ok, <<>>, converter} = Iconvex.feed(converter, <<0xC3>>)
      assert {:ok, <<>>, converter} = Iconvex.feed(converter, <<0xA9>>)
      assert {:ok, "é"} = Iconvex.finish(converter)
    end

    for options <- [[invalid: :discard], [byte_substitute: "<%02x>"]] do
      assert [<<0xC3>>, <<0xA9>>]
             |> Iconvex.stream!("UTF-8", "UTF-8", options)
             |> Enum.join() == "é"
    end
  end

  test "streaming preserves destination longest-match lookahead" do
    input = <<0x00EA::utf8, 0x030C::utf8>>
    assert Iconvex.convert(input, "UTF-8", "BIG5-HKSCS") == {:ok, <<0x88, 0xA5>>}

    assert {:ok, converter} = Iconvex.new("UTF-8", "BIG5-HKSCS")
    assert {:ok, <<>>, converter} = Iconvex.feed(converter, <<0x00EA::utf8>>)
    assert {:ok, <<>>, converter} = Iconvex.feed(converter, <<0x030C::utf8>>)
    assert {:ok, <<0x88, 0xA5>>} = Iconvex.finish(converter)
  end

  test "streaming preserves source composition across chunks" do
    for {encoding, bytes, expected} <- [
          {"CP1258", <<0x52, 0xF2>>, "Ṛ"},
          {"TCVN", <<0x68, 0xB4>>, "ḥ"}
        ] do
      assert Iconvex.convert(bytes, encoding, "UTF-8") == {:ok, expected}
      assert {:ok, converter} = Iconvex.new(encoding, "UTF-8")
      <<first, second>> = bytes
      assert {:ok, <<>>, converter} = Iconvex.feed(converter, <<first>>)
      assert {:ok, <<>>, converter} = Iconvex.feed(converter, <<second>>)
      assert {:ok, ^expected} = Iconvex.finish(converter)
    end
  end

  test "generic UTF destinations emit one BOM for the complete stream" do
    for {encoding, expected} <- [
          {"UTF-16", <<0xFE, 0xFF, 0, ?A, 0, ?B>>},
          {"UTF-32", <<0, 0, 0xFE, 0xFF, 0, 0, 0, ?A, 0, 0, 0, ?B>>}
        ] do
      assert {:ok, converter} = Iconvex.new("UTF-8", encoding)
      assert {:ok, <<>>, converter} = Iconvex.feed(converter, "A")
      assert {:ok, <<>>, converter} = Iconvex.feed(converter, "B")
      assert {:ok, ^expected} = Iconvex.finish(converter)
    end
  end

  test "resolved external codec remains stable after registry mutation" do
    assert :ok = Iconvex.register_codec(StableA)
    assert {:ok, converter} = Iconvex.new("X-STABLE", "UTF-8")
    stream = Iconvex.stream!([<<1, 2>>], "X-STABLE", "UTF-8")
    assert :ok = Iconvex.unregister_codec(StableA)
    assert :ok = Iconvex.register_codec(StableB)

    assert {:ok, <<>>, converter} = Iconvex.feed(converter, <<1, 2>>)
    assert {:ok, "AA"} = Iconvex.finish(converter)
    assert Enum.join(stream) == "AA"
  after
    Iconvex.unregister_codec(StableA)
    Iconvex.unregister_codec(StableB)
  end

  test "finish_with_state makes lifecycle and full-stream offsets observable" do
    assert {:ok, converter} = Iconvex.new("ASCII", "UTF-8")
    assert {:ok, <<>>, converter} = Iconvex.feed(converter, "AB")
    assert {:ok, <<>>, converter} = Iconvex.feed(converter, <<0xFF>>)

    assert {:error, %Iconvex.Error{kind: :invalid_sequence, offset: 2}} =
             Iconvex.finish(converter)

    assert {:ok, valid} = Iconvex.new("ASCII", "UTF-8")
    assert {:ok, <<>>, valid} = Iconvex.feed(valid, "AB")
    assert {:ok, "AB", finished} = Iconvex.finish_with_state(valid)
    assert {:error, :already_finished} = Iconvex.feed(finished, "C")
    assert {:error, :already_finished} = Iconvex.finish_with_state(finished)
  end

  test "option and suffix validation has one non-raising error contract" do
    assert Iconvex.convert("A", "UTF-8", "ASCII", typo: true) ==
             {:error, {:invalid_option, :typo, :unknown}}

    assert Iconvex.convert("A", "UTF-8", "ASCII//TYPO") ==
             {:error, {:invalid_suffix, "TYPO"}}

    assert Iconvex.convert(<<0xFF>>, "UTF-8", "ASCII", invalid: :bogus) ==
             {:error, {:invalid_option, :invalid, {:invalid_value, :bogus}}}

    assert Iconvex.convert("A", "UTF-8", "ASCII", [:x]) ==
             {:error, {:invalid_options, :expected_keyword}}

    assert Iconvex.convert("A", "UTF-8", "ASCII", invalid: :error, invalid: :discard) ==
             {:error, {:invalid_option, :invalid, :duplicate}}

    assert Iconvex.convert(<<0xFF>>, "ASCII", "UTF-8", byte_substitute: "plain") ==
             {:error, {:invalid_option, :byte_substitute, :missing_hex_field}}

    assert Iconvex.convert(<<0xFF>>, "ASCII", "UTF-8", byte_substitute: "%010000000x") ==
             {:error, {:invalid_option, :byte_substitute, :width_too_large}}

    assert_raise ArgumentError, fn ->
      Iconvex.convert!("A", "UTF-8", "ASCII//TYPO")
    end
  end

  test "Unicode malformed policies preserve BOM-selected endian state" do
    cases = [
      {"UTF-16", <<0xFF, 0xFE, ?A, 0, 0, 0xDC, ?B, 0>>, "A<00><dc>B"},
      {"UTF-32", <<0xFF, 0xFE, 0, 0, ?A, 0, 0, 0, 0, 0xD8, 0, 0, ?B, 0, 0, 0>>,
       "A<00><d8><00><00>B"}
    ]

    for {encoding, input, substituted} <- cases do
      assert {:ok, "AB"} = Iconvex.convert(input, encoding, "UTF-8", invalid: :discard)

      assert {:ok, ^substituted} =
               Iconvex.convert(input, encoding, "UTF-8", byte_substitute: "<%02x>")
    end
  end
end

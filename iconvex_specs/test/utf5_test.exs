defmodule Iconvex.Specs.UTF5Test do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.UTF5

  @draft Path.expand(
           "../priv/sources/draft-jseng-utf5-01/draft-jseng-utf5-01.txt",
           __DIR__
         )
  @metadata Path.expand("../priv/sources/draft-jseng-utf5-01/SOURCE_METADATA.md", __DIR__)
  @draft_sha256 "12ae18367c110b5dcef9cc3f06b6ae40e60c8fde489fdd161f1bb98e3e5f2375"

  test "RED: draft-jseng-utf5-01 section 3 vectors encode and decode exactly" do
    vectors = [
      {"A\u2262\u0391.", "K1I262J91IE"},
      {"Hi Mom \u263A!", "K8M9I0KDMFMDI0I63AI1"},
      {"\u65E5\u672C\u8A9E", "M5E5M72COA9E"}
    ]

    for {unicode, utf5} <- vectors do
      codepoints = String.to_charlist(unicode)
      assert UTF5.encode(codepoints) == {:ok, utf5}
      assert UTF5.decode(utf5) == {:ok, codepoints}
    end
  end

  @tag timeout: :infinity
  test "every modern Unicode scalar has the draft's canonical hexadecimal form and round-trips" do
    0..0x10FFFF
    |> Stream.reject(&(&1 in 0xD800..0xDFFF))
    |> Stream.chunk_every(4_096)
    |> Enum.each(fn codepoints ->
      expected = codepoints |> Enum.map(&oracle_encode/1) |> IO.iodata_to_binary()
      assert UTF5.encode(codepoints) == {:ok, expected}
      assert UTF5.decode(expected) == {:ok, codepoints}
    end)
  end

  test "the complete one-octet domain follows the quintet grammar" do
    for byte <- 0..0xFF do
      case UTF5.decode(<<byte>>) do
        {:ok, [codepoint]} ->
          assert byte in ?G..?V
          assert codepoint == byte - ?G

        {:error, :invalid_sequence, 0, <<^byte>>} ->
          refute byte in ?G..?V
      end
    end
  end

  test "rejects noncanonical zero, forbidden alphabet, surrogates, and values above Unicode" do
    for input <- ["G0", "0", "W", "h", "H!", "T800", "H10000"] do
      assert match?({:error, :invalid_sequence, _, _}, UTF5.decode(input)), input
    end

    assert UTF5.encode([0xD800]) == {:error, :unrepresentable_character, 0xD800}
    assert UTF5.encode([0x11_0000]) == {:error, :unrepresentable_character, 0x11_0000}
    assert UTF5.encode_discard([?A, 0xD800, ?B, 0x11_0000]) == {:ok, "K1K2"}
  end

  test "chunk callbacks retain the undecidable final sequence and preserve policies" do
    assert UTF5.decode_chunk("K1K", false) == {:ok, [?A], "K"}
    assert UTF5.decode_chunk("K2", true) == {:ok, [?B], <<>>}
    assert UTF5.decode_chunk("K1K2", true) == {:ok, [?A, ?B], <<>>}

    assert UTF5.encode_chunk([?A, ?B], false, :error) == {:ok, "K1K2", []}
    assert UTF5.encode_chunk([?A, 0xD800, ?B], false, :discard) == {:ok, "K1K2", []}

    assert UTF5.encode_chunk([?A, 0xD800, ?B], true, {:replace, fn _ -> ~c"?" end}) ==
             {:ok, "K1JFK2", []}
  end

  test "RED: non-final decoding rejects impossible suffixes at one-shot offsets" do
    cases = [
      {"K1!", {:error, :invalid_sequence, 2, "!"}},
      {"K1G0", {:error, :invalid_sequence, 2, "G0"}},
      {"K1VFFFFF", {:error, :invalid_sequence, 2, "VFFFFF"}},
      {"K1T800!", {:error, :invalid_sequence, 6, "!"}}
    ]

    for {input, expected} <- cases do
      assert UTF5.decode(input) == expected
      assert UTF5.decode_chunk(input, false) == expected
    end

    assert UTF5.decode_chunk("K1T800", false) == {:ok, [?A], "T800"}
  end

  test "RED: adversarial pending is bounded and valid stream work remains linear" do
    for suffix <- ["G", "K1", "T800", "VFFFF", "H0FFFF"] do
      assert {:ok, [?A], pending} = UTF5.decode_chunk("K1" <> suffix, false)
      assert pending == suffix
      assert byte_size(pending) <= 6
    end

    small = "K1" <> :binary.copy("0", 32_768)
    large = "K1" <> :binary.copy("0", 65_536)

    {small_result, small_reductions} =
      reductions_with_result(fn -> UTF5.decode_chunk(small, false) end)

    {large_result, large_reductions} =
      reductions_with_result(fn -> UTF5.decode_chunk(large, false) end)

    assert small_result == {:error, :invalid_sequence, 0, "K10000"}
    assert large_result == small_result

    rejection_ratio = large_reductions / max(small_reductions, 1)
    assert rejection_ratio <= 1.25

    small_valid = :binary.copy("K1", 8_192) <> "K"
    large_valid = :binary.copy("K1", 16_384) <> "K"

    {{:ok, small_output, "K"}, small_valid_reductions} =
      reductions_with_result(fn -> UTF5.decode_chunk(small_valid, false) end)

    {{:ok, large_output, "K"}, large_valid_reductions} =
      reductions_with_result(fn -> UTF5.decode_chunk(large_valid, false) end)

    assert length(small_output) == 8_192
    assert length(large_output) == 16_384

    valid_ratio = large_valid_reductions / max(small_valid_reductions, 1)
    assert valid_ratio >= 1.70 and valid_ratio <= 2.35
  end

  test "direct UTF-8 callbacks and malformed input preserve Iconvex error contracts" do
    unicode =
      "Hello \u039A\u03B1\u03BB\u03B7\u03BC\u03AD\u03C1\u03B1 \u65E5\u672C\u8A9E \u{1F600}"

    assert {:ok, encoded} = UTF5.encode_from_utf8(unicode)
    assert UTF5.decode_to_utf8(encoded) == {:ok, unicode}

    assert UTF5.encode_from_utf8(<<?A, 0xC2>>) ==
             {:decode_error, :incomplete_sequence, 1, <<0xC2>>}
  end

  test "RED: registry aliases and public conversion select the exact native codec" do
    assert UTF5 in Iconvex.Specs.codecs()
    assert Iconvex.canonical_name("utf5") == {:ok, "UTF-5"}
    assert Iconvex.canonical_name("draft-jseng-utf5-01") == {:ok, "UTF-5"}

    unicode = "A\u2262\u0391."
    assert Iconvex.convert(unicode, "UTF-8", "UTF-5") == {:ok, "K1I262J91IE"}
    assert Iconvex.convert("K1I262J91IE", "UTF-5", "UTF-8") == {:ok, unicode}
  end

  test "the authoritative draft and metadata are pinned byte-for-byte" do
    assert File.regular?(@draft)
    assert File.regular?(@metadata)
    assert sha256(@draft) == @draft_sha256

    metadata = File.read!(@metadata)
    assert metadata =~ "draft-jseng-utf5-01"
    assert metadata =~ @draft_sha256
    assert metadata =~ "Distribution of this document is unlimited"
  end

  test "encode and decode scheduler work remains linear when input doubles" do
    small = List.duplicate([0, ?A, 0x3B1, 0x65E5, 0x1F600], 4_000) |> List.flatten()
    large = small ++ small
    {:ok, small_encoded} = UTF5.encode(small)
    {:ok, large_encoded} = UTF5.encode(large)

    encode_ratio =
      reductions(fn -> UTF5.encode(large) end) / reductions(fn -> UTF5.encode(small) end)

    decode_ratio =
      reductions(fn -> UTF5.decode(large_encoded) end) /
        reductions(fn -> UTF5.decode(small_encoded) end)

    assert encode_ratio >= 1.70 and encode_ratio <= 2.35
    assert decode_ratio >= 1.70 and decode_ratio <= 2.35
  end

  defp oracle_encode(0), do: "G"

  defp oracle_encode(codepoint) do
    <<first, rest::binary>> = Integer.to_string(codepoint, 16)
    <<?G + hex_value(first), String.upcase(rest)::binary>>
  end

  defp hex_value(digit) when digit in ?1..?9, do: digit - ?0
  defp hex_value(digit) when digit in ?A..?F, do: digit - ?A + 10
  defp hex_value(digit) when digit in ?a..?f, do: digit - ?a + 10

  defp sha256(path) do
    path
    |> File.read!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp reductions(function) do
    parent = self()
    token = make_ref()

    spawn(fn ->
      :erlang.garbage_collect()
      {:reductions, before_count} = Process.info(self(), :reductions)
      result = function.()
      {:reductions, after_count} = Process.info(self(), :reductions)
      send(parent, {token, result, after_count - before_count})
    end)

    receive do
      {^token, {:ok, _result}, count} -> count
    after
      30_000 -> flunk("UTF-5 reduction measurement timed out")
    end
  end

  defp reductions_with_result(function) do
    parent = self()
    token = make_ref()

    spawn(fn ->
      :erlang.garbage_collect()
      {:reductions, before_count} = Process.info(self(), :reductions)
      result = function.()
      {:reductions, after_count} = Process.info(self(), :reductions)
      send(parent, {token, result, after_count - before_count})
    end)

    receive do
      {^token, result, count} -> {result, count}
    after
      30_000 -> flunk("UTF-5 reduction measurement timed out")
    end
  end
end

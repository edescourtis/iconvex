defmodule Iconvex.Specs.UnicodeMiscTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.UnicodeMisc

  @source_directory Path.expand("../priv/sources/unicode-misc", __DIR__)

  test "pins both APL ISO-IR-68 revisions and KPS 9566-2003" do
    assert UnicodeMisc.aggregate_sha256() ==
             "f76182817119b7cdf4a61be5aa5fa5d661654039210563c92ab9a1971892e369"

    assert Enum.map(UnicodeMisc.encodings(), & &1.name) == [
             "APL-ISO-IR-68",
             "APL-ISO-IR-68-2004",
             "KPS-9566-2003"
           ]
  end

  test "keeps the corrected APL revision separate from the 2004 table" do
    [current, old, _kps] = UnicodeMisc.codecs()
    assert current.decode(<<0x28, 0x29>>) == {:ok, [0x2228, 0x2227]}
    assert old.decode(<<0x28, 0x29>>) == {:ok, [0x2227, 0x2228]}
    assert current.decode(<<0x21, 0x08, 0x26>>) == {:ok, [0x2369]}
  end

  test "executes KPS 9566 single-byte and double-byte mappings" do
    [_current, _old, kps] = UnicodeMisc.codecs()
    assert kps.decode(<<0x41, 0xA1, 0xA1, 0xA4, 0xA1>>) == {:ok, [?A, 0x3000, 0x3131]}
    assert kps.encode([?A, 0x3000, 0x3131]) == {:ok, <<0x41, 0xA1, 0xA1, 0xA4, 0xA1>>}
  end

  test "verifies every source row, source digest, and canonical direction" do
    for {entry, codec} <- Enum.zip(UnicodeMisc.encodings(), UnicodeMisc.codecs()) do
      source = File.read!(Path.join(@source_directory, entry.source_file))
      mappings = parse_mappings(source)
      decode = Enum.reduce(mappings, %{}, fn {bytes, cp}, map -> Map.put_new(map, bytes, cp) end)
      encode = Enum.reduce(mappings, %{}, fn {bytes, cp}, map -> Map.put_new(map, cp, bytes) end)

      assert sha256(source) == entry.sha256
      assert length(mappings) == entry.mapping_rows
      assert map_size(decode) == entry.decode_mappings
      assert map_size(encode) == entry.encode_mappings

      for {bytes, codepoint} <- decode, do: assert(codec.decode(bytes) == {:ok, [codepoint]})
      for {codepoint, bytes} <- encode, do: assert(codec.encode([codepoint]) == {:ok, bytes})
    end
  end

  defp parse_mappings(source) do
    source
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      case Regex.run(~r/^0x([0-9A-Fa-f]+)\s+0x([0-9A-Fa-f]+)/, line, capture: :all_but_first) do
        [encoded, unicode] ->
          [{Base.decode16!(encoded, case: :mixed), String.to_integer(unicode, 16)}]

        nil ->
          []
      end
    end)
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

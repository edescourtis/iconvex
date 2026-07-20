defmodule Iconvex.Specs.WindowsBestFitTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.WindowsBestFit

  @source_directory Path.expand("../priv/sources/windows-best-fit", __DIR__)

  @code_pages [
    874,
    932,
    936,
    949,
    950,
    1250,
    1251,
    1252,
    1253,
    1254,
    1255,
    1256,
    1257,
    1258,
    1361
  ]

  test "catalogues every official Unicode Microsoft best-fit table" do
    assert WindowsBestFit.aggregate_sha256() ==
             "0a18f4eab7105aa7f5e54fb7dd6a2b9c1f72dd794e2d517a5e502e5c65c7e430"

    assert Enum.map(WindowsBestFit.encodings(), & &1.code_page) == @code_pages
    assert length(WindowsBestFit.codecs()) == 15
  end

  test "keeps best-fit encode mappings directional" do
    entry = Enum.find(WindowsBestFit.encodings(), &(&1.code_page == 1252))
    codec = Enum.at(WindowsBestFit.codecs(), entry.index - 1)

    # U+2212 has a documented best-fit encoding to ASCII hyphen-minus, while
    # decoding that byte remains U+002D.
    assert codec.encode([0x2212]) == {:ok, "-"}
    assert codec.decode("-") == {:ok, [0x2D]}
  end

  test "exhaustively executes every pinned MB/DBCS and WC source row" do
    for {entry, codec} <- Enum.zip(WindowsBestFit.encodings(), WindowsBestFit.codecs()) do
      source = File.read!(Path.join(@source_directory, entry.source_file))
      %{decode: decode, encode: encode} = parse(source)
      assert sha256(source) == entry.sha256
      assert map_size(decode) == entry.decode_mappings
      assert map_size(encode) == entry.encode_mappings

      for {bytes, codepoint} <- decode,
          do: assert(codec.decode(bytes) == {:ok, [codepoint]})

      for {codepoint, bytes} <- encode,
          do: assert(codec.encode([codepoint]) == {:ok, bytes})
    end
  end

  defp parse(source) do
    source
    |> String.split("\n")
    |> Enum.reduce(%{decode: %{}, encode: %{}, state: nil}, fn line, acc ->
      cond do
        String.starts_with?(line, "MBTABLE") -> %{acc | state: :mb}
        String.starts_with?(line, "DBCSRANGE") -> %{acc | state: nil}
        String.starts_with?(line, "WCTABLE") -> %{acc | state: :wc}
        String.starts_with?(line, "DBCSTABLE") -> %{acc | state: {:dbcs, lead_byte(line)}}
        true -> parse_row(line, acc)
      end
    end)
    |> Map.delete(:state)
  end

  defp parse_row(line, %{state: state} = acc) do
    case Regex.run(~r/^0x([0-9A-Fa-f]+)\s+0x([0-9A-Fa-f]+)/, line, capture: :all_but_first) do
      [left, right] ->
        left = String.to_integer(left, 16)
        right = String.to_integer(right, 16)

        case state do
          :mb -> put_new(acc, :decode, <<left>>, right)
          {:dbcs, lead} -> put_new(acc, :decode, <<lead, left>>, right)
          :wc -> put_new(acc, :encode, left, encoded_bytes(right))
          nil -> acc
        end

      nil ->
        acc
    end
  end

  defp lead_byte(line) do
    [value] = Regex.run(~r/LeadByte\s*=\s*0x([0-9A-Fa-f]+)/, line, capture: :all_but_first)
    String.to_integer(value, 16)
  end

  defp put_new(acc, direction, key, value),
    do: Map.update!(acc, direction, &Map.put_new(&1, key, value))

  defp encoded_bytes(value) when value <= 0xFF, do: <<value>>
  defp encoded_bytes(value), do: <<value::16-big>>

  defp sha256(contents), do: :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)
end

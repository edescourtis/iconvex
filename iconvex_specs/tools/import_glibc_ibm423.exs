defmodule Iconvex.Specs.Tools.ImportGlibcIBM423 do
  @moduledoc false

  @revision "e5145be467bed28bafde33a51df97840be37065e"
  @source_sha256 "8c5890f6c82ceef0231fd61f4bd661e1fd8cadd88e1944be2b31c967a9f1e02e"

  def run do
    root = Path.expand("..", __DIR__)
    source = Path.join([root, "priv", "sources", "glibc-#{@revision}-ibm423", "IBM423"])
    content = File.read!(source)
    assert_hash!(content)
    mappings = parse(content)
    table = build_table(mappings)
    output = Path.join([root, "priv", "tables", "glibc_ibm423_e5145be.etf"])
    File.write!(output, :erlang.term_to_binary(table, [:deterministic]))

    IO.puts(
      "wrote #{output}: #{length(mappings)} decode mappings, #{map_size(table.encode)} encodings"
    )
  end

  defp parse(content) do
    Regex.scan(
      ~r/^<U([0-9A-F]{4,6})>\s+\/x([0-9a-f]{2})\s/m,
      content,
      capture: :all_but_first
    )
    |> Enum.map(fn [unicode, byte] ->
      {String.to_integer(byte, 16), {String.to_integer(unicode, 16)}}
    end)
  end

  defp build_table(mappings) do
    one_map = Map.new(mappings)

    encode =
      Enum.reduce(mappings, %{}, fn {byte, codepoints}, acc ->
        Map.put_new(acc, codepoints, <<byte>>)
      end)

    %{
      encode: encode,
      many: %{},
      max_codepoints: 1,
      max_input: 1,
      one: 0..255 |> Enum.map(&Map.get(one_map, &1)) |> List.to_tuple(),
      prefixes: MapSet.new()
    }
  end

  defp assert_hash!(content) do
    actual = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
    unless actual == @source_sha256, do: raise("IBM423 SHA-256 mismatch: #{actual}")
  end
end

Iconvex.Specs.Tools.ImportGlibcIBM423.run()

defmodule Iconvex.Specs.ICUArchiveExhaustiveTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.ICUArchive

  @source_directory Path.expand("../priv/sources/icu-data-archive", __DIR__)

  @tag timeout: 600_000
  test "verifies every committed source and independently rebuilds directional counts" do
    aggregate =
      Enum.reduce(ICUArchive.encodings(), :crypto.hash_init(:sha256), fn entry, context ->
        source = File.read!(Path.join(@source_directory, entry.source_file))
        mappings = parse_mappings(source)

        assert sha256(source) == entry.sha256
        assert length(mappings) == entry.mapping_rows
        assert map_size(decode_map(mappings)) == entry.decode_mappings
        assert map_size(encode_map(mappings)) == entry.encode_mappings

        context
        |> :crypto.hash_update(entry.source_file)
        |> :crypto.hash_update(<<0>>)
        |> :crypto.hash_update(source)
      end)
      |> :crypto.hash_final()
      |> Base.encode16(case: :lower)

    assert aggregate == ICUArchive.aggregate_sha256()
  end

  @tag timeout: 600_000
  test "executes every one of the archived decoder mappings" do
    for {entry, codec} <- Enum.zip(ICUArchive.encodings(), ICUArchive.codecs()) do
      source = File.read!(Path.join(@source_directory, entry.source_file))

      for {bytes, codepoints} <- source |> parse_mappings() |> decode_map() do
        unless entry.stateful and bytes in [<<0x0E>>, <<0x0F>>] do
          input = stateful_input(entry, bytes)
          assert codec.decode(input) == {:ok, Tuple.to_list(codepoints)}
        end
      end
    end
  end

  @tag timeout: 600_000
  test "executes every one of the archived canonical encoder mappings" do
    for {entry, codec} <- Enum.zip(ICUArchive.encodings(), ICUArchive.codecs()) do
      source = File.read!(Path.join(@source_directory, entry.source_file))

      for {codepoints, bytes} <- source |> parse_mappings() |> encode_map() do
        assert codec.encode(Tuple.to_list(codepoints)) == {:ok, stateful_input(entry, bytes)}
      end
    end
  end

  defp stateful_input(%{stateful: true}, bytes)
       when byte_size(bytes) == 2,
       do: <<0x0E, bytes::binary, 0x0F>>

  defp stateful_input(_entry, bytes), do: bytes

  defp parse_mappings(source) do
    source
    |> String.split("CHARMAP", parts: 2)
    |> List.last()
    |> String.split("END CHARMAP", parts: 2)
    |> hd()
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      case Regex.run(
             ~r/^((?:<U[0-9A-Fa-f]+>\+?)+)\s+((?:\\x[0-9A-Fa-f]{2}\+?)+)(?:\s+\|(\d))?/,
             line,
             capture: :all_but_first
           ) do
        [unicode, encoded, precision] -> [mapping(unicode, encoded, precision)]
        [unicode, encoded] -> [mapping(unicode, encoded, "0")]
        nil -> []
      end
    end)
  end

  defp mapping(unicode, encoded, precision) do
    codepoints =
      Regex.scan(~r/<U([0-9A-Fa-f]+)>/, unicode, capture: :all_but_first)
      |> List.flatten()
      |> Enum.map(&String.to_integer(&1, 16))
      |> List.to_tuple()

    bytes =
      Regex.scan(~r/\\x([0-9A-Fa-f]{2})/, encoded, capture: :all_but_first)
      |> List.flatten()
      |> Enum.map(&String.to_integer(&1, 16))
      |> :binary.list_to_bin()

    {codepoints, bytes, String.to_integer(precision)}
  end

  defp decode_map(mappings) do
    mappings
    |> Enum.filter(fn {codepoints, _bytes, precision} ->
      precision in [0, 3] and not Enum.any?(Tuple.to_list(codepoints), &(&1 in [0xFFFE, 0xFFFF]))
    end)
    |> Enum.sort_by(fn {_codepoints, _bytes, precision} -> if precision == 0, do: 0, else: 1 end)
    |> Enum.reduce(%{}, fn {codepoints, bytes, _precision}, result ->
      Map.put_new(result, bytes, codepoints)
    end)
  end

  defp encode_map(mappings) do
    mappings
    |> Enum.filter(fn {codepoints, _bytes, precision} ->
      precision in [0, 4] or (precision == 1 and private_use?(codepoints))
    end)
    |> Enum.sort_by(fn {_codepoints, _bytes, precision} ->
      case precision do
        0 -> 0
        4 -> 1
        1 -> 2
      end
    end)
    |> Enum.reduce(%{}, fn {codepoints, bytes, _precision}, result ->
      Map.put_new(result, codepoints, bytes)
    end)
  end

  defp private_use?(codepoints) do
    codepoints
    |> Tuple.to_list()
    |> Enum.all?(fn codepoint ->
      codepoint in 0xE000..0xF8FF or codepoint in 0xF0000..0xFFFFD or
        codepoint in 0x100000..0x10FFFD
    end)
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

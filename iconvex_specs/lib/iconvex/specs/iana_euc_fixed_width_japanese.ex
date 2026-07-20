defmodule Iconvex.Specs.IANAEUCFixedWidthJapanese do
  @moduledoc """
  IANA `Extended_UNIX_Code_Fixed_Width_for_Japanese` (MIBenum 19).

  This is the complete two-byte form of EUC-JP: code-set 0 and code-set 2
  characters are zero-prefixed, code-set 1 bytes are unchanged, and the
  code-set 3 introducer/high bit are omitted.
  """

  use Iconvex.Codec
  import Bitwise

  @entry %{id: :euc_jp, table_app: :iconvex}

  @impl true
  def canonical_name, do: "Extended_UNIX_Code_Fixed_Width_for_Japanese"

  @impl true
  def aliases, do: ["csEUCFixWidJapanese"]

  @impl true
  def codec_id, do: :iana_euc_fixed_width_japanese

  @impl true
  def decode(input) when is_binary(input) do
    decode_pairs(input, Iconvex.Tables.fetch!(@entry), 0, [])
  end

  @impl true
  def decode_discard(input) when is_binary(input) do
    decode_discard_pairs(input, Iconvex.Tables.fetch!(@entry), [])
  end

  @impl true
  def decode_to_utf8(input) when is_binary(input) do
    case decode(input) do
      {:ok, codepoints} -> {:ok, List.to_string(codepoints)}
      error -> error
    end
  end

  @impl true
  def encode(codepoints) when is_list(codepoints) do
    @entry
    |> Iconvex.TableCodec.encode(codepoints)
    |> fixed_encode_result()
  end

  @impl true
  def encode_discard(codepoints) when is_list(codepoints) do
    @entry
    |> Iconvex.TableCodec.encode_discard(codepoints)
    |> fixed_encode_result()
  end

  @impl true
  def encode_substitute(codepoints, replacer) when is_list(codepoints) do
    @entry
    |> Iconvex.TableCodec.encode_substitute(codepoints, replacer)
    |> fixed_encode_result()
  end

  @impl true
  def encode_from_utf8(input) when is_binary(input) do
    case Iconvex.TableCodec.encode_from_utf8(@entry, input) do
      {:ok, packed} -> {:ok, packed_to_fixed(packed, [])}
      result -> result
    end
  end

  def source_url, do: "https://www.rfc-editor.org/rfc/rfc1874.html"

  defp decode_pairs(<<>>, _table, _offset, result), do: {:ok, :lists.reverse(result)}

  defp decode_pairs(<<byte>>, _table, offset, _result),
    do: {:error, :incomplete_sequence, offset, <<byte>>}

  defp decode_pairs(<<first, second, rest::binary>>, table, offset, result) do
    case lookup(first, second, table) do
      nil -> {:error, :invalid_sequence, offset, <<first, second>>}
      codepoints -> decode_pairs(rest, table, offset + 2, prepend(codepoints, result))
    end
  end

  defp decode_discard_pairs(<<>>, _table, result), do: {:ok, :lists.reverse(result)}
  defp decode_discard_pairs(<<_byte>>, _table, result), do: {:ok, :lists.reverse(result)}

  defp decode_discard_pairs(<<first, second, rest::binary>>, table, result) do
    case lookup(first, second, table) do
      nil -> decode_discard_pairs(rest, table, result)
      codepoints -> decode_discard_pairs(rest, table, prepend(codepoints, result))
    end
  end

  defp lookup(0, second, table) when second <= 0x7F, do: elem(table.one, second)

  defp lookup(0, second, table) when second in 0xA1..0xDF,
    do: Map.get(table.many, <<0x8E, second>>)

  defp lookup(first, second, table)
       when first in 0xA1..0xFE and second in 0xA1..0xFE,
       do: Map.get(table.many, <<first, second>>)

  defp lookup(first, second, table)
       when first in 0xA1..0xFE and second in 0x21..0x7E,
       do: Map.get(table.many, <<0x8F, first, second ||| 0x80>>)

  defp lookup(_first, _second, _table), do: nil

  defp fixed_encode_result({:ok, packed}), do: {:ok, packed_to_fixed(packed, [])}
  defp fixed_encode_result(error), do: error

  defp packed_to_fixed(<<>>, result), do: result |> :lists.reverse() |> IO.iodata_to_binary()

  defp packed_to_fixed(<<byte, rest::binary>>, result) when byte <= 0x7F,
    do: packed_to_fixed(rest, [<<0, byte>> | result])

  defp packed_to_fixed(<<0x8E, byte, rest::binary>>, result),
    do: packed_to_fixed(rest, [<<0, byte>> | result])

  defp packed_to_fixed(<<0x8F, first, second, rest::binary>>, result),
    do: packed_to_fixed(rest, [<<first, second &&& 0x7F>> | result])

  defp packed_to_fixed(<<first, second, rest::binary>>, result),
    do: packed_to_fixed(rest, [<<first, second>> | result])

  defp prepend(tuple, result) when tuple_size(tuple) == 1, do: [elem(tuple, 0) | result]

  defp prepend(tuple, result) when tuple_size(tuple) == 2,
    do: [elem(tuple, 1), elem(tuple, 0) | result]

  defp prepend(tuple, result), do: tuple |> Tuple.to_list() |> :lists.reverse(result)
end

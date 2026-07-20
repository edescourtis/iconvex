defmodule Iconvex.Specs.KermitELOT927Greek do
  @moduledoc """
  Kermit's uppercase-only seven-bit `ELOT927-GREEK` terminal profile.

  This legacy table is not the standard ELOT 927 / ISO-IR-88 mapping. The byte
  API carries one septet per octet; `Iconvex.Specs.Packed` provides contiguous
  MSB- and LSB-first septets.
  """

  use Iconvex.Codec

  @source_path Path.expand(
                 "../../../priv/sources/dec-terminal-character-sets/kermit/ckcuni.c",
                 __DIR__
               )
  @source_license_path Path.expand(
                         "../../../priv/sources/dec-terminal-character-sets/kermit/COPYING",
                         __DIR__
                       )
  @source_metadata_path Path.expand(
                          "../../../priv/sources/elot927/SOURCE_METADATA.md",
                          __DIR__
                        )
  @external_resource @source_path
  @external_resource @source_license_path
  @external_resource @source_metadata_path

  @chunk_units 4_096
  @compile {:inline, decode_utf8_codepoint: 6, utf8: 1}
  @greek (Enum.to_list(0x0391..0x03A1) ++ Enum.to_list(0x03A3..0x03A9))
         |> List.to_tuple()
  @encode @greek
          |> Tuple.to_list()
          |> Enum.with_index(0x61)
          |> Map.new()

  @impl true
  def canonical_name, do: "KERMIT-ELOT927-GREEK"

  @impl true
  def aliases, do: ["ELOT927-GREEK", "DEC-GREEK-7-UPPER"]

  @impl true
  def codec_id, do: :kermit_elot927_greek

  def unit_bits, do: 7
  @impl true
  def decode(input) when is_binary(input), do: decode_all(input, 0, [])

  @impl true
  def decode_discard(input) when is_binary(input), do: decode_discard_all(input, [])

  @impl true
  def encode(codepoints) when is_list(codepoints), do: encode_all(codepoints, [])

  @impl true
  def encode_discard(codepoints) when is_list(codepoints), do: encode_discard_all(codepoints, [])

  @impl true
  def encode_substitute(codepoints, replacer),
    do: Iconvex.Specs.CodecSupport.encode_substitute_each(codepoints, &encode/1, replacer)

  @impl true
  def decode_to_utf8(input) when is_binary(input),
    do: decode_utf8_all(input, 0, [], 0, [])

  @impl true
  def encode_from_utf8(input) when is_binary(input),
    do: encode_utf8_all(input, 0, [], 0, [])

  defp decode_all(<<>>, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_all(<<unit, rest::binary>>, offset, acc) when unit < 0x61,
    do: decode_all(rest, offset + 1, [unit | acc])

  defp decode_all(<<unit, rest::binary>>, offset, acc) when unit < 0x79,
    do: decode_all(rest, offset + 1, [elem(@greek, unit - 0x61) | acc])

  defp decode_all(<<unit, rest::binary>>, offset, acc) when unit < 0x7B,
    do: decode_all(rest, offset + 1, [0x20 | acc])

  defp decode_all(<<unit, rest::binary>>, offset, acc) when unit < 0x80,
    do: decode_all(rest, offset + 1, [unit | acc])

  defp decode_all(<<unit, _rest::binary>>, offset, _acc),
    do: {:error, :invalid_sequence, offset, <<unit>>}

  defp decode_discard_all(<<>>, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_all(<<unit, rest::binary>>, acc) when unit < 0x61,
    do: decode_discard_all(rest, [unit | acc])

  defp decode_discard_all(<<unit, rest::binary>>, acc) when unit < 0x79,
    do: decode_discard_all(rest, [elem(@greek, unit - 0x61) | acc])

  defp decode_discard_all(<<unit, rest::binary>>, acc) when unit < 0x7B,
    do: decode_discard_all(rest, [0x20 | acc])

  defp decode_discard_all(<<unit, rest::binary>>, acc) when unit < 0x80,
    do: decode_discard_all(rest, [unit | acc])

  defp decode_discard_all(<<_unit, rest::binary>>, acc),
    do: decode_discard_all(rest, acc)

  defp encode_all([], acc), do: {:ok, reverse_binary(acc)}

  defp encode_all([codepoint | rest], acc) when codepoint < 0x61,
    do: encode_all(rest, [codepoint | acc])

  defp encode_all([codepoint | rest], acc) when codepoint in 0x7B..0x7F,
    do: encode_all(rest, [codepoint | acc])

  defp encode_all([codepoint | rest], acc) do
    case @encode do
      %{^codepoint => unit} -> encode_all(rest, [unit | acc])
      _ -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_discard_all([], acc), do: {:ok, reverse_binary(acc)}

  defp encode_discard_all([codepoint | rest], acc) when codepoint < 0x61,
    do: encode_discard_all(rest, [codepoint | acc])

  defp encode_discard_all([codepoint | rest], acc) when codepoint in 0x7B..0x7F,
    do: encode_discard_all(rest, [codepoint | acc])

  defp encode_discard_all([codepoint | rest], acc) do
    case @encode do
      %{^codepoint => unit} -> encode_discard_all(rest, [unit | acc])
      _ -> encode_discard_all(rest, acc)
    end
  end

  defp decode_utf8_all(<<>>, _offset, acc, _count, chunks),
    do: {:ok, finish_iodata(acc, chunks)}

  defp decode_utf8_all(<<unit, rest::binary>>, offset, acc, count, chunks)
       when unit < 0x61 do
    decode_utf8_codepoint(rest, offset, unit, acc, count, chunks)
  end

  defp decode_utf8_all(<<unit, rest::binary>>, offset, acc, count, chunks)
       when unit < 0x79 do
    decode_utf8_codepoint(rest, offset, elem(@greek, unit - 0x61), acc, count, chunks)
  end

  defp decode_utf8_all(<<unit, rest::binary>>, offset, acc, count, chunks)
       when unit < 0x7B do
    decode_utf8_codepoint(rest, offset, 0x20, acc, count, chunks)
  end

  defp decode_utf8_all(<<unit, rest::binary>>, offset, acc, count, chunks)
       when unit < 0x80 do
    decode_utf8_codepoint(rest, offset, unit, acc, count, chunks)
  end

  defp decode_utf8_all(<<unit, _rest::binary>>, offset, _acc, _count, _chunks),
    do: {:error, :invalid_sequence, offset, <<unit>>}

  defp decode_utf8_codepoint(rest, offset, codepoint, acc, count, chunks) do
    next_acc = [utf8(codepoint) | acc]

    if count == @chunk_units - 1 do
      chunk = next_acc |> :lists.reverse() |> IO.iodata_to_binary()
      decode_utf8_all(rest, offset + 1, [], 0, [chunk | chunks])
    else
      decode_utf8_all(rest, offset + 1, next_acc, count + 1, chunks)
    end
  end

  defp encode_utf8_all(<<>>, _offset, acc, _count, chunks),
    do: {:ok, finish_iodata(acc, chunks)}

  defp encode_utf8_all(<<codepoint, rest::binary>>, offset, acc, count, chunks)
       when codepoint < 0x61 do
    encode_utf8_unit(rest, offset, codepoint, 1, acc, count, chunks)
  end

  defp encode_utf8_all(<<codepoint, rest::binary>>, offset, acc, count, chunks)
       when codepoint in 0x7B..0x7F do
    encode_utf8_unit(rest, offset, codepoint, 1, acc, count, chunks)
  end

  defp encode_utf8_all(input, offset, acc, count, chunks) do
    case input do
      <<codepoint::utf8, rest::binary>> ->
        case @encode do
          %{^codepoint => unit} ->
            width = byte_size(input) - byte_size(rest)
            encode_utf8_unit(rest, offset, unit, width, acc, count, chunks)

          _ ->
            {:error, :unrepresentable_character, codepoint}
        end

      _ ->
        malformed_utf8(input, offset)
    end
  end

  defp encode_utf8_unit(rest, offset, unit, width, acc, count, chunks) do
    next_acc = [unit | acc]

    if count == @chunk_units - 1 do
      chunk = next_acc |> :lists.reverse() |> :erlang.list_to_binary()
      encode_utf8_all(rest, offset + width, [], 0, [chunk | chunks])
    else
      encode_utf8_all(rest, offset + width, next_acc, count + 1, chunks)
    end
  end

  defp malformed_utf8(input, offset),
    do: Iconvex.Specs.CodecSupport.malformed_utf8(input, offset)

  defp reverse_binary(acc), do: acc |> :lists.reverse() |> :erlang.list_to_binary()
  defp utf8(codepoint) when codepoint < 0x80, do: codepoint
  defp utf8(codepoint), do: <<codepoint::utf8>>

  defp finish_iodata([], chunks), do: chunks |> :lists.reverse() |> IO.iodata_to_binary()

  defp finish_iodata(acc, chunks) do
    chunk = acc |> :lists.reverse() |> IO.iodata_to_binary()
    [chunk | chunks] |> :lists.reverse() |> IO.iodata_to_binary()
  end
end

defmodule Iconvex.Telecom.TBCDCodec do
  @moduledoc "Iconvex codec wrapper for 3GPP Telephony Binary Coded Decimal."

  use Iconvex.Telecom.SubstitutionCodec

  import Bitwise

  alias Iconvex.Telecom.TBCD

  @impl true
  def canonical_name, do: "TBCD"

  @impl true
  def aliases, do: ["TELEPHONY-BCD", "3GPP-TBCD", "GSM-TBCD"]

  @impl true
  def decode(input) when is_binary(input) do
    case TBCD.decode(input) do
      {:ok, digits} ->
        {:ok, :binary.bin_to_list(digits)}

      {:error, {:invalid_filler, offset, _nibble}} ->
        {:error, :invalid_sequence, offset, binary_part(input, offset, 1)}
    end
  end

  @impl true
  def decode_discard(input) when is_binary(input), do: decode_discard_loop(input, [])

  @impl true
  def encode(codepoints) when is_list(codepoints) do
    case first_unrepresentable(codepoints) do
      nil -> TBCD.encode(:erlang.list_to_binary(codepoints))
      codepoint -> {:error, :unrepresentable_character, codepoint}
    end
  end

  @impl true
  def encode_discard(codepoints) when is_list(codepoints) do
    codepoints
    |> Enum.filter(&representable?/1)
    |> encode()
  end

  @impl true
  def decode_to_utf8(input) when is_binary(input) do
    case TBCD.decode(input) do
      {:ok, _digits} = result ->
        result

      {:error, {:invalid_filler, offset, _nibble}} ->
        {:error, :invalid_sequence, offset, binary_part(input, offset, 1)}
    end
  end

  @impl true
  def encode_from_utf8(input) when is_binary(input) do
    with {:ok, codepoints} <- utf8_codepoints(input) do
      case encode(codepoints) do
        {:error, kind, codepoint} -> {:encode_error, kind, codepoint}
        result -> result
      end
    end
  end

  defp decode_discard_loop(<<>>, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_loop(<<octet, rest::binary>>, acc) do
    low = octet &&& 0x0F
    high = octet >>> 4

    cond do
      low == 0x0F ->
        decode_discard_loop(rest, acc)

      high == 0x0F and rest != <<>> ->
        decode_discard_loop(rest, acc)

      high == 0x0F ->
        decode_discard_loop(rest, [digit(low) | acc])

      true ->
        decode_discard_loop(rest, [digit(high), digit(low) | acc])
    end
  end

  defp first_unrepresentable(codepoints), do: Enum.find(codepoints, &(not representable?(&1)))

  defp representable?(codepoint),
    do: codepoint in ?0..?9 or codepoint in [?*, ?#, ?a, ?b, ?c]

  defp digit(nibble) when nibble in 0..9, do: ?0 + nibble
  defp digit(0x0A), do: ?*
  defp digit(0x0B), do: ?#
  defp digit(0x0C), do: ?a
  defp digit(0x0D), do: ?b
  defp digit(0x0E), do: ?c

  defp utf8_codepoints(input) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        {:ok, codepoints}

      {:incomplete, _converted, rest} ->
        {:decode_error, :incomplete_sequence, byte_size(input) - byte_size(rest), rest}

      {:error, _converted, rest} ->
        {:decode_error, :invalid_sequence, byte_size(input) - byte_size(rest), rest}
    end
  end
end

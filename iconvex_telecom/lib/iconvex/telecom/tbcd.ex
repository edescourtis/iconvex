defmodule Iconvex.Telecom.TBCD do
  @moduledoc """
  Telephony Binary Coded Decimal as used by 3GPP protocols.

  The first digit occupies the low nibble. The alphabet is `0`-`9`, `*`,
  `#`, `a`, `b`, and `c`; an odd final digit is padded by a high `0xF` nibble.
  """

  import Bitwise

  def encode(digits) when is_binary(digits), do: encode_digits(digits, 0, [])

  def decode(encoded) when is_binary(encoded), do: decode_octets(encoded, 0, [])

  defp encode_digits(<<>>, _offset, acc),
    do: {:ok, acc |> Enum.reverse() |> :erlang.list_to_binary()}

  defp encode_digits(<<low>>, offset, acc) do
    with {:ok, low} <- digit_to_nibble(low, offset) do
      encode_digits(<<>>, offset + 1, [low ||| 0xF0 | acc])
    end
  end

  defp encode_digits(<<low, high, rest::binary>>, offset, acc) do
    with {:ok, low} <- digit_to_nibble(low, offset),
         {:ok, high} <- digit_to_nibble(high, offset + 1) do
      encode_digits(rest, offset + 2, [low ||| high <<< 4 | acc])
    end
  end

  defp decode_octets(<<>>, _offset, acc),
    do: {:ok, acc |> Enum.reverse() |> :erlang.list_to_binary()}

  defp decode_octets(<<octet, rest::binary>>, offset, acc) do
    low = octet &&& 0x0F
    high = octet >>> 4

    cond do
      low == 0x0F ->
        {:error, {:invalid_filler, offset, :low}}

      high == 0x0F and rest != <<>> ->
        {:error, {:invalid_filler, offset, :high}}

      high == 0x0F ->
        decode_octets(rest, offset + 1, [nibble_to_digit(low) | acc])

      true ->
        decode_octets(rest, offset + 1, [nibble_to_digit(high), nibble_to_digit(low) | acc])
    end
  end

  defp digit_to_nibble(digit, _offset) when digit in ?0..?9, do: {:ok, digit - ?0}
  defp digit_to_nibble(?*, _offset), do: {:ok, 0x0A}
  defp digit_to_nibble(?#, _offset), do: {:ok, 0x0B}
  defp digit_to_nibble(?a, _offset), do: {:ok, 0x0C}
  defp digit_to_nibble(?b, _offset), do: {:ok, 0x0D}
  defp digit_to_nibble(?c, _offset), do: {:ok, 0x0E}
  defp digit_to_nibble(digit, offset), do: {:error, {:invalid_digit, offset, digit}}

  defp nibble_to_digit(nibble) when nibble in 0..9, do: ?0 + nibble
  defp nibble_to_digit(0x0A), do: ?*
  defp nibble_to_digit(0x0B), do: ?#
  defp nibble_to_digit(0x0C), do: ?a
  defp nibble_to_digit(0x0D), do: ?b
  defp nibble_to_digit(0x0E), do: ?c
end

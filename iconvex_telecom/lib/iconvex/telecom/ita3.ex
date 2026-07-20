defmodule Iconvex.Telecom.ITA3 do
  @moduledoc """
  International Telegraph Alphabet No. 3 (ITA3), as specified by ITU-T S.13.

  ITA3 is the seven-unit, three-of-seven constant-ratio ARQ representation of
  ITA2 traffic. One seven-bit signal is stored in each octet; bit 0 is code
  element 1, the element transmitted first. ARQ repetition, alpha, and beta
  service signals are exposed separately and are deliberately not presented as
  Unicode text characters.
  """

  use Iconvex.Telecom.SubstitutionCodec

  alias Iconvex.Telecom.ITA2

  @traffic %{
    0 => 112,
    1 => 14,
    2 => 13,
    3 => 44,
    4 => 11,
    5 => 42,
    6 => 7,
    7 => 38,
    8 => 97,
    9 => 28,
    10 => 19,
    11 => 98,
    12 => 21,
    13 => 100,
    14 => 25,
    15 => 104,
    16 => 81,
    17 => 70,
    18 => 35,
    19 => 82,
    20 => 37,
    21 => 84,
    22 => 41,
    23 => 88,
    24 => 49,
    25 => 76,
    26 => 67,
    27 => 50,
    28 => 69,
    29 => 52,
    30 => 73,
    31 => 56
  }

  @service_signals %{alpha: 74, beta: 26, repetition: 22}
  @from_ita2 0..31 |> Enum.map(&Map.fetch!(@traffic, &1)) |> List.to_tuple()
  @to_ita2 @traffic |> Map.new(fn {ita2, ita3} -> {ita3, ita2} end)
  @to_ita2_tuple 0..127 |> Enum.map(&Map.get(@to_ita2, &1)) |> List.to_tuple()

  @impl true
  def canonical_name, do: "ITA3"

  @impl true
  def aliases,
    do: [
      "ITA-3",
      "CCITT-3",
      "CCITT-NO-3",
      "ITU-T-S.13",
      "INTERNATIONAL-TELEGRAPH-ALPHABET-NO-3"
    ]

  @impl true
  def stateful?, do: true

  @doc "Returns the exact ITA2-unit to ITA3 traffic-signal table from S.13."
  def traffic_table, do: @traffic

  @doc "Returns the three non-text ARQ service signals from S.13."
  def service_signals, do: @service_signals

  @doc "Converts unpacked five-bit ITA2 units to unpacked ITA3 signals."
  def from_ita2(units) when is_binary(units), do: from_ita2_loop(units, 0, [])

  @doc "Converts unpacked ITA3 traffic signals to five-bit ITA2 units."
  def to_ita2(signals) when is_binary(signals), do: to_ita2_loop(signals, 0, [])

  @impl true
  def decode(input) when is_binary(input) do
    with {:ok, ita2} <- to_ita2(input), do: ITA2.decode(ita2)
  end

  @impl true
  def decode_discard(input) when is_binary(input) do
    input
    |> to_ita2_discard([], :binary)
    |> ITA2.decode_discard()
  end

  @impl true
  def decode_to_utf8(input) when is_binary(input) do
    with {:ok, ita2} <- to_ita2(input), do: ITA2.decode_to_utf8(ita2)
  end

  @impl true
  def encode(codepoints) when is_list(codepoints) do
    with {:ok, ita2} <- ITA2.encode(codepoints), do: from_ita2(ita2)
  end

  @impl true
  def encode_discard(codepoints) when is_list(codepoints) do
    {:ok, ita2} = ITA2.encode_discard(codepoints)
    from_ita2(ita2)
  end

  @impl true
  def encode_from_utf8(input) when is_binary(input) do
    case ITA2.encode_from_utf8(input) do
      {:ok, ita2} -> from_ita2(ita2)
      error -> error
    end
  end

  defp from_ita2_loop(<<>>, _offset, acc), do: {:ok, binary_result(acc)}

  defp from_ita2_loop(<<unit, _rest::binary>>, offset, _acc) when unit > 31,
    do: {:error, :invalid_sequence, offset, <<unit>>}

  defp from_ita2_loop(<<unit, rest::binary>>, offset, acc),
    do: from_ita2_loop(rest, offset + 1, [elem(@from_ita2, unit) | acc])

  defp to_ita2_loop(<<>>, _offset, acc), do: {:ok, binary_result(acc)}

  defp to_ita2_loop(<<signal, _rest::binary>>, offset, _acc) when signal > 127,
    do: {:error, :invalid_sequence, offset, <<signal>>}

  defp to_ita2_loop(<<signal, rest::binary>>, offset, acc) do
    case elem(@to_ita2_tuple, signal) do
      nil -> {:error, :invalid_sequence, offset, <<signal>>}
      unit -> to_ita2_loop(rest, offset + 1, [unit | acc])
    end
  end

  defp to_ita2_discard(<<>>, acc, :binary), do: binary_result(acc)

  defp to_ita2_discard(<<signal, rest::binary>>, acc, :binary) when signal <= 127 do
    case elem(@to_ita2_tuple, signal) do
      nil -> to_ita2_discard(rest, acc, :binary)
      unit -> to_ita2_discard(rest, [unit | acc], :binary)
    end
  end

  defp to_ita2_discard(<<_signal, rest::binary>>, acc, :binary),
    do: to_ita2_discard(rest, acc, :binary)

  defp binary_result(acc), do: acc |> :lists.reverse() |> :erlang.list_to_binary()
end

defmodule Iconvex.Telecom.ITA4 do
  @moduledoc """
  International Telegraph Alphabet No. 4 (ITA4), as specified by ITU-T R.44.

  ITA4 is the six-unit synchronous-multiplex representation of ITA2 traffic.
  One six-bit signal is stored in each octet; bit 0 is code element 1, the
  element transmitted first. The phasing, permanent-A, and permanent-Z
  signals are exposed separately and are not presented as Unicode text.
  """

  use Iconvex.Telecom.SubstitutionCodec

  import Bitwise

  alias Iconvex.Telecom.ITA2

  @traffic Map.new(0..31, fn
             0 -> {0, 1}
             unit -> {unit, unit <<< 1}
           end)
  @service_signals %{alpha: 0, beta: 63, phasing: 51}
  @from_ita2 0..31 |> Enum.map(&Map.fetch!(@traffic, &1)) |> List.to_tuple()
  @to_ita2 @traffic |> Map.new(fn {ita2, ita4} -> {ita4, ita2} end)
  @to_ita2_tuple 0..63 |> Enum.map(&Map.get(@to_ita2, &1)) |> List.to_tuple()

  @impl true
  def canonical_name, do: "ITA4"

  @impl true
  def aliases,
    do: [
      "ITA-4",
      "CCITT-4",
      "CCITT-NO-4",
      "ITU-T-R.44",
      "INTERNATIONAL-TELEGRAPH-ALPHABET-NO-4"
    ]

  @impl true
  def stateful?, do: true

  @doc "Returns the exact ITA2-unit to ITA4 traffic-signal table from R.44."
  def traffic_table, do: @traffic

  @doc "Returns the three non-text multiplex service signals from R.44."
  def service_signals, do: @service_signals

  @doc "Converts unpacked five-bit ITA2 units to unpacked ITA4 signals."
  def from_ita2(units) when is_binary(units), do: from_ita2_loop(units, 0, [])

  @doc "Converts unpacked ITA4 traffic signals to five-bit ITA2 units."
  def to_ita2(signals) when is_binary(signals), do: to_ita2_loop(signals, 0, [])

  @impl true
  def decode(input) when is_binary(input) do
    with {:ok, ita2} <- to_ita2(input), do: ITA2.decode(ita2)
  end

  @impl true
  def decode_discard(input) when is_binary(input) do
    input
    |> to_ita2_discard([])
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

  defp to_ita2_loop(<<signal, _rest::binary>>, offset, _acc) when signal > 63,
    do: {:error, :invalid_sequence, offset, <<signal>>}

  defp to_ita2_loop(<<signal, rest::binary>>, offset, acc) do
    case elem(@to_ita2_tuple, signal) do
      nil -> {:error, :invalid_sequence, offset, <<signal>>}
      unit -> to_ita2_loop(rest, offset + 1, [unit | acc])
    end
  end

  defp to_ita2_discard(<<>>, acc), do: binary_result(acc)

  defp to_ita2_discard(<<signal, rest::binary>>, acc) when signal <= 63 do
    case elem(@to_ita2_tuple, signal) do
      nil -> to_ita2_discard(rest, acc)
      unit -> to_ita2_discard(rest, [unit | acc])
    end
  end

  defp to_ita2_discard(<<_signal, rest::binary>>, acc), do: to_ita2_discard(rest, acc)

  defp binary_result(acc), do: acc |> :lists.reverse() |> :erlang.list_to_binary()
end

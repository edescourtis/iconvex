defmodule Iconvex.Telecom.CCIR476 do
  @moduledoc """
  CCIR 476 / ITU-R M.476-5 seven-unit error-detecting telegraph code.

  Each traffic signal is carried in one octet with its high bit zero. The
  lower seven bits contain exactly four one bits. Unicode conversion follows
  the ITA2 letters/figures state machine used at the terminal interface by the
  Recommendation. Service signals are exposed separately because several are
  context-dependent and collide numerically with traffic signals.
  """

  use Iconvex.Telecom.SubstitutionCodec

  import Bitwise

  alias Iconvex.Telecom.ITA2

  @traffic %{
    0 => 0x2B,
    1 => 0x35,
    2 => 0x1B,
    3 => 0x71,
    4 => 0x1D,
    5 => 0x69,
    6 => 0x59,
    7 => 0x39,
    8 => 0x0F,
    9 => 0x65,
    10 => 0x55,
    11 => 0x74,
    12 => 0x4D,
    13 => 0x6C,
    14 => 0x5C,
    15 => 0x3C,
    16 => 0x17,
    17 => 0x63,
    18 => 0x53,
    19 => 0x72,
    20 => 0x4B,
    21 => 0x6A,
    22 => 0x5A,
    23 => 0x3A,
    24 => 0x47,
    25 => 0x27,
    26 => 0x56,
    27 => 0x36,
    28 => 0x4E,
    29 => 0x2E,
    30 => 0x1E,
    31 => 0x2D
  }

  @service_signals %{
    alpha: 0x78,
    beta: 0x66,
    cs1: 0x53,
    cs2: 0x2B,
    cs3: 0x4D,
    repetition: 0x33
  }

  @from_ita2 0..31 |> Enum.map(&Map.fetch!(@traffic, &1)) |> List.to_tuple()
  @to_ita2 @traffic |> Map.new(fn {ita2, signal} -> {signal, ita2} end)
  @to_ita2_tuple 0..127 |> Enum.map(&Map.get(@to_ita2, &1)) |> List.to_tuple()

  @ita2_tables ITA2.tables()
  @letters_encode Keyword.fetch!(@ita2_tables, :letters)
  @figures_encode Keyword.fetch!(@ita2_tables, :figures)
  @shared_encode Map.take(@letters_encode, [0x0000, ?\n, ?\s, ?\r])
  @letters_decode @letters_encode |> Map.new(fn {codepoint, unit} -> {unit, codepoint} end)
  @figures_decode @figures_encode |> Map.new(fn {codepoint, unit} -> {unit, codepoint} end)
  @letters_decode_tuple 0..31 |> Enum.map(&Map.get(@letters_decode, &1)) |> List.to_tuple()
  @figures_decode_tuple 0..31 |> Enum.map(&Map.get(@figures_decode, &1)) |> List.to_tuple()
  @figures_shift 27
  @letters_shift 31
  @figures_shift_signal elem(@from_ita2, @figures_shift)
  @letters_shift_signal elem(@from_ita2, @letters_shift)

  @impl true
  def canonical_name, do: "CCIR476"

  @impl true
  def aliases,
    do: ["CCIR-476", "CCIR_476", "SITOR", "SITOR-B", "NAVTEX", "ITU-R-M.476-5"]

  @impl true
  def stateful?, do: true

  @doc "Returns the exact ITA2-unit to CCIR 476 traffic-signal table."
  def traffic_table, do: @traffic

  @doc "Returns the M.476-5 service signals, which are not all text symbols."
  def service_signals, do: @service_signals

  @doc "Converts unpacked five-bit ITA2 units to unpacked CCIR 476 signals."
  def from_ita2(units) when is_binary(units), do: from_ita2_loop(units, 0, [])

  @doc "Converts unpacked CCIR 476 traffic signals to five-bit ITA2 units."
  def to_ita2(signals) when is_binary(signals), do: to_ita2_loop(signals, 0, [])

  @doc "Inverts all seven signal bits for the M.476-5 collective FEC polarity."
  def invert(signals) when is_binary(signals), do: invert_loop(signals, 0, [])

  @impl true
  def decode(input) when is_binary(input), do: decode_loop(input, :letters, 0, [])

  @impl true
  def decode_discard(input) when is_binary(input),
    do: decode_discard_loop(input, :letters, [])

  @impl true
  def encode(codepoints) when is_list(codepoints),
    do: encode_loop(codepoints, :letters, [])

  @impl true
  def encode_discard(codepoints) when is_list(codepoints),
    do: encode_discard_loop(codepoints, :letters, [])

  @impl true
  def decode_to_utf8(input) do
    case decode(input) do
      {:ok, codepoints} -> {:ok, List.to_string(codepoints)}
      error -> error
    end
  end

  @impl true
  def encode_from_utf8(input) when is_binary(input) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        encode_utf8_codepoints(codepoints)

      {:incomplete, converted, rest} ->
        encode_prefix_or_utf8_error(
          converted,
          :incomplete_sequence,
          byte_size(input) - byte_size(rest),
          rest
        )

      {:error, converted, rest} ->
        encode_prefix_or_utf8_error(
          converted,
          :invalid_sequence,
          byte_size(input) - byte_size(rest),
          rest
        )
    end
  end

  defp decode_loop(<<>>, _mode, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_loop(<<signal, _rest::binary>>, _mode, offset, _acc) when signal > 127,
    do: {:error, :invalid_sequence, offset, <<signal>>}

  defp decode_loop(<<signal, rest::binary>>, mode, offset, acc) do
    case elem(@to_ita2_tuple, signal) do
      nil ->
        {:error, :invalid_sequence, offset, <<signal>>}

      @figures_shift ->
        decode_loop(rest, :figures, offset + 1, acc)

      @letters_shift ->
        decode_loop(rest, :letters, offset + 1, acc)

      unit ->
        codepoint = elem(decode_table(mode), unit)
        decode_loop(rest, mode, offset + 1, [codepoint | acc])
    end
  end

  defp decode_discard_loop(<<>>, _mode, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_loop(<<signal, rest::binary>>, mode, acc) when signal <= 127 do
    case elem(@to_ita2_tuple, signal) do
      nil ->
        decode_discard_loop(rest, mode, acc)

      @figures_shift ->
        decode_discard_loop(rest, :figures, acc)

      @letters_shift ->
        decode_discard_loop(rest, :letters, acc)

      unit ->
        decode_discard_loop(rest, mode, [elem(decode_table(mode), unit) | acc])
    end
  end

  defp decode_discard_loop(<<_signal, rest::binary>>, mode, acc),
    do: decode_discard_loop(rest, mode, acc)

  defp encode_loop([], _mode, acc), do: {:ok, binary_result(acc)}

  defp encode_loop([codepoint | rest], mode, acc) do
    case encoded(codepoint, mode) do
      nil -> {:error, :unrepresentable_character, codepoint}
      {signals, next_mode} -> encode_loop(rest, next_mode, [signals | acc])
    end
  end

  defp encode_discard_loop([], _mode, acc), do: {:ok, binary_result(acc)}

  defp encode_discard_loop([codepoint | rest], mode, acc) do
    case encoded(codepoint, mode) do
      nil -> encode_discard_loop(rest, mode, acc)
      {signals, next_mode} -> encode_discard_loop(rest, next_mode, [signals | acc])
    end
  end

  defp encoded(codepoint, mode) do
    case @shared_encode do
      %{^codepoint => unit} ->
        {elem(@from_ita2, unit), mode}

      _ ->
        case encode_table(mode) do
          %{^codepoint => unit} -> {elem(@from_ita2, unit), mode}
          _ -> encoded_in_other_mode(codepoint, mode)
        end
    end
  end

  defp encoded_in_other_mode(codepoint, :letters) do
    case @figures_encode do
      %{^codepoint => unit} ->
        {<<@figures_shift_signal, elem(@from_ita2, unit)>>, :figures}

      _ ->
        nil
    end
  end

  defp encoded_in_other_mode(codepoint, :figures) do
    case @letters_encode do
      %{^codepoint => unit} ->
        {<<@letters_shift_signal, elem(@from_ita2, unit)>>, :letters}

      _ ->
        nil
    end
  end

  defp decode_table(:letters), do: @letters_decode_tuple
  defp decode_table(:figures), do: @figures_decode_tuple
  defp encode_table(:letters), do: @letters_encode
  defp encode_table(:figures), do: @figures_encode

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

  defp invert_loop(<<>>, _offset, acc), do: {:ok, binary_result(acc)}

  defp invert_loop(<<signal, _rest::binary>>, offset, _acc) when signal > 127,
    do: {:error, :invalid_sequence, offset, <<signal>>}

  defp invert_loop(<<signal, rest::binary>>, offset, acc),
    do: invert_loop(rest, offset + 1, [bxor(signal, 0x7F) | acc])

  defp binary_result(acc), do: acc |> :lists.reverse() |> :erlang.list_to_binary()

  defp encode_utf8_codepoints(codepoints) do
    case encode(codepoints) do
      {:error, kind, codepoint} -> {:encode_error, kind, codepoint}
      result -> result
    end
  end

  defp encode_prefix_or_utf8_error(converted, kind, offset, rest) do
    case encode(converted) do
      {:error, encode_kind, codepoint} -> {:encode_error, encode_kind, codepoint}
      {:ok, _encoded_prefix} -> {:decode_error, kind, offset, rest}
    end
  end
end

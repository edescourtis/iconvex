defmodule Iconvex.Telecom.ITA2 do
  @moduledoc """
  International Telegraph Alphabet No. 2 (ITA2 / CCITT No. 2).

  The external representation is one five-bit ITA2 signal element per octet,
  with the upper three bits required to be zero. This is the unpacked form
  commonly carried by byte-oriented telecom interfaces. Use
  `Iconvex.Telecom.ITA2.Packing` for a consecutive five-bit bitstring.

  The letters/figures state machine and repertoire follow ITU-T S.1. The
  figures `WRU` and `BELL` functions are represented by Unicode control
  characters U+0005 and U+0007 respectively.
  """

  use Iconvex.Telecom.SubstitutionCodec

  @letters [
    {0, 0x0000},
    {1, ?E},
    {2, ?\n},
    {3, ?A},
    {4, ?\s},
    {5, ?S},
    {6, ?I},
    {7, ?U},
    {8, ?\r},
    {9, ?D},
    {10, ?R},
    {11, ?J},
    {12, ?N},
    {13, ?F},
    {14, ?C},
    {15, ?K},
    {16, ?T},
    {17, ?Z},
    {18, ?L},
    {19, ?W},
    {20, ?H},
    {21, ?Y},
    {22, ?P},
    {23, ?Q},
    {24, ?O},
    {25, ?B},
    {26, ?G},
    {28, ?M},
    {29, ?X},
    {30, ?V}
  ]

  @figures [
    {0, 0x0000},
    {1, ?3},
    {2, ?\n},
    {3, ?-},
    {4, ?\s},
    {5, ?'},
    {6, ?8},
    {7, ?7},
    {8, ?\r},
    {9, 0x0005},
    {10, ?4},
    {11, 0x0007},
    {12, ?,},
    {13, ?!},
    {14, ?:},
    {15, ?(},
    {16, ?5},
    {17, ?+},
    {18, ?)},
    {19, ?2},
    {20, 0x00A3},
    {21, ?6},
    {22, ?0},
    {23, ?1},
    {24, ?9},
    {25, ??},
    {26, ?&},
    {28, ?.},
    {29, ?/},
    {30, ?;}
  ]

  @letters_decode @letters |> Map.new()
  @figures_decode @figures |> Map.new()
  @letters_decode_tuple 0..31 |> Enum.map(&Map.get(@letters_decode, &1)) |> List.to_tuple()
  @figures_decode_tuple 0..31 |> Enum.map(&Map.get(@figures_decode, &1)) |> List.to_tuple()
  @letters_encode @letters |> Map.new(fn {code, codepoint} -> {codepoint, code} end)
  @figures_encode @figures |> Map.new(fn {code, codepoint} -> {codepoint, code} end)

  @shared_encode @letters_encode
                 |> Map.take([0x0000, ?\n, ?\s, ?\r])

  @letters_shift 31
  @figures_shift 27

  @impl true
  def canonical_name, do: "ITA2"

  @impl true
  def aliases,
    do: [
      "ITA-2",
      "CCITT-2",
      "CCITT2",
      "BAUDOT",
      "BAUDOT-CODE",
      "CCITT-NO-2",
      "INTERNATIONAL-TELEGRAPH-ALPHABET-NO-2"
    ]

  @impl true
  def stateful?, do: true

  @doc "Returns the two executable ITA2 alphabets as `{codepoint, code}` maps."
  def tables do
    [
      letters: @letters_encode,
      figures: @figures_encode
    ]
  end

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

  defp decode_loop(<<byte, _rest::binary>>, _mode, offset, _acc) when byte > 31,
    do: {:error, :invalid_sequence, offset, <<byte>>}

  defp decode_loop(<<@figures_shift, rest::binary>>, _mode, offset, acc),
    do: decode_loop(rest, :figures, offset + 1, acc)

  defp decode_loop(<<@letters_shift, rest::binary>>, _mode, offset, acc),
    do: decode_loop(rest, :letters, offset + 1, acc)

  defp decode_loop(<<code, rest::binary>>, mode, offset, acc) do
    decode_loop(rest, mode, offset + 1, [elem(decode_table(mode), code) | acc])
  end

  defp decode_discard_loop(<<>>, _mode, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_loop(<<byte, rest::binary>>, mode, acc) when byte > 31,
    do: decode_discard_loop(rest, mode, acc)

  defp decode_discard_loop(<<@figures_shift, rest::binary>>, _mode, acc),
    do: decode_discard_loop(rest, :figures, acc)

  defp decode_discard_loop(<<@letters_shift, rest::binary>>, _mode, acc),
    do: decode_discard_loop(rest, :letters, acc)

  defp decode_discard_loop(<<code, rest::binary>>, mode, acc),
    do: decode_discard_loop(rest, mode, [elem(decode_table(mode), code) | acc])

  defp encode_loop([], _mode, acc), do: {:ok, encode_result(acc)}

  defp encode_loop([codepoint | rest], mode, acc) do
    case encoded(codepoint, mode) do
      nil ->
        {:error, :unrepresentable_character, codepoint}

      {bytes, next_mode} ->
        encode_loop(rest, next_mode, [bytes | acc])
    end
  end

  defp encode_discard_loop([], _mode, acc), do: {:ok, encode_result(acc)}

  defp encode_discard_loop([codepoint | rest], mode, acc) do
    case encoded(codepoint, mode) do
      nil -> encode_discard_loop(rest, mode, acc)
      {bytes, next_mode} -> encode_discard_loop(rest, next_mode, [bytes | acc])
    end
  end

  defp encoded(codepoint, mode) do
    case @shared_encode do
      %{^codepoint => code} ->
        {code, mode}

      _ ->
        current = encode_table(mode)

        case current do
          %{^codepoint => code} -> {code, mode}
          _ -> encoded_in_other_mode(codepoint, mode)
        end
    end
  end

  defp encoded_in_other_mode(codepoint, :letters) do
    case @figures_encode do
      %{^codepoint => code} -> {<<@figures_shift, code>>, :figures}
      _ -> nil
    end
  end

  defp encoded_in_other_mode(codepoint, :figures) do
    case @letters_encode do
      %{^codepoint => code} -> {<<@letters_shift, code>>, :letters}
      _ -> nil
    end
  end

  defp decode_table(:letters), do: @letters_decode_tuple
  defp decode_table(:figures), do: @figures_decode_tuple
  defp encode_table(:letters), do: @letters_encode
  defp encode_table(:figures), do: @figures_encode

  defp encode_result(acc), do: acc |> :lists.reverse() |> IO.iodata_to_binary()

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

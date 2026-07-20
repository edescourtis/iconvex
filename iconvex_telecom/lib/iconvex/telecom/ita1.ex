defmodule Iconvex.Telecom.ITA1 do
  @moduledoc """
  International Telegraph Alphabet No. 1 (ITA1 / original Baudot code).

  The representation is one five-unit signal per octet, with element 1 in
  bit 0 and the upper three bits zero. The polarity/code permutation and
  repertoire are the normative table in Article 16 of the 1958 ITU Telegraph
  Regulations. `letter blank` and `figure blank` both print a space and select
  the corresponding case, exactly as specified; no invisible shift is
  invented for this historical alphabet.
  """

  use Iconvex.Telecom.SubstitutionCodec

  @rows [
    {1, 30, ?A, ?1},
    {2, 19, ?B, ?8},
    {3, 18, ?C, ?9},
    {4, 16, ?D, ?0},
    {5, 29, ?E, ?2},
    {6, 17, ?F, :national_use},
    {7, 21, ?G, ?7},
    {8, 20, ?H, ?+},
    {9, 25, ?I, :national_use},
    {10, 22, ?J, ?6},
    {11, 6, ?K, ?(},
    {12, 4, ?L, ?=},
    {13, 5, ?M, ?)},
    {14, 1, ?N, :national_use},
    {15, 24, ?O, ?5},
    {16, 0, ?P, ?%},
    {17, 2, ?Q, ?/},
    {18, 3, ?R, ?-},
    {19, 11, ?S, ?.},
    {20, 10, ?T, :national_use},
    {21, 26, ?U, ?4},
    {22, 8, ?V, ?'},
    {23, 9, ?W, ??},
    {24, 13, ?X, ?,},
    {25, 27, ?Y, ?3},
    {26, 12, ?Z, ?:},
    {27, 28, :carriage_return, :carriage_return},
    {28, 14, :line_feed, :line_feed},
    {29, 15, :letter_blank, :letter_blank},
    {30, 23, :figure_blank, :figure_blank},
    {31, 7, :error, :error},
    {32, 31, :instrument_at_rest, :instrument_at_rest}
  ]

  @signal_table Map.new(@rows, fn {signal, code, letter, figure} ->
                  {signal, %{code: code, letter: letter, figure: figure}}
                end)
  @signal_numbers @rows |> Map.new(fn {signal, code, _letter, _figure} -> {code, signal} end)

  @letters @rows
           |> Enum.filter(fn {_signal, _code, letter, _figure} -> is_integer(letter) end)
           |> Map.new(fn {_signal, code, letter, _figure} -> {letter, code} end)

  @figures @rows
           |> Enum.filter(fn {_signal, _code, _letter, figure} -> is_integer(figure) end)
           |> Map.new(fn {_signal, code, _letter, figure} -> {figure, code} end)

  @letters_decode @letters |> Map.new(fn {codepoint, code} -> {code, codepoint} end)
  @figures_decode @figures |> Map.new(fn {codepoint, code} -> {code, codepoint} end)
  @letters_tuple 0..31 |> Enum.map(&Map.get(@letters_decode, &1)) |> List.to_tuple()
  @figures_tuple 0..31 |> Enum.map(&Map.get(@figures_decode, &1)) |> List.to_tuple()

  @letter_blank 15
  @figure_blank 23
  @carriage_return 28
  @line_feed 14
  @error_signal 7
  @rest_signal 31

  @impl true
  def canonical_name, do: "ITA1"

  @impl true
  def aliases,
    do: [
      "ITA-1",
      "CCITT-1",
      "CCITT1",
      "CCITT-NO-1",
      "BAUDOT-ORIGINAL",
      "BAUDOT-CODE-ITA1",
      "INTERNATIONAL-TELEGRAPH-ALPHABET-NO-1"
    ]

  @impl true
  def codec_id, do: :ita1

  @impl true
  def stateful?, do: true

  @doc "Returns all 32 normative ITU rows, keyed by the printed signal number."
  def signal_table, do: @signal_table

  @doc "Returns the printed ITU signal number for a five-bit signal value."
  def signal_number(code) when is_integer(code) do
    case @signal_numbers do
      %{^code => signal} -> {:ok, signal}
      _ -> :error
    end
  end

  @doc "Returns table rows whose figure-case character is nationally assigned."
  def national_use_signals, do: [6, 9, 14, 20]

  @doc "Returns the executable international letter and figure maps."
  def tables, do: [letters: @letters, figures: @figures]

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
  def decode_to_utf8(input) when is_binary(input) do
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

  defp decode_loop(<<@letter_blank, rest::binary>>, _mode, offset, acc),
    do: decode_loop(rest, :letters, offset + 1, [32 | acc])

  defp decode_loop(<<@figure_blank, rest::binary>>, _mode, offset, acc),
    do: decode_loop(rest, :figures, offset + 1, [32 | acc])

  defp decode_loop(<<@carriage_return, rest::binary>>, mode, offset, acc),
    do: decode_loop(rest, mode, offset + 1, [?\r | acc])

  defp decode_loop(<<@line_feed, rest::binary>>, mode, offset, acc),
    do: decode_loop(rest, mode, offset + 1, [?\n | acc])

  defp decode_loop(<<code, _rest::binary>>, _mode, offset, _acc)
       when code in [@error_signal, @rest_signal],
       do: {:error, :invalid_sequence, offset, <<code>>}

  defp decode_loop(<<code, rest::binary>>, mode, offset, acc) do
    case elem(decode_table(mode), code) do
      nil -> {:error, :invalid_sequence, offset, <<code>>}
      codepoint -> decode_loop(rest, mode, offset + 1, [codepoint | acc])
    end
  end

  defp decode_discard_loop(<<>>, _mode, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_loop(<<byte, rest::binary>>, mode, acc) when byte > 31,
    do: decode_discard_loop(rest, mode, acc)

  defp decode_discard_loop(<<@letter_blank, rest::binary>>, _mode, acc),
    do: decode_discard_loop(rest, :letters, [32 | acc])

  defp decode_discard_loop(<<@figure_blank, rest::binary>>, _mode, acc),
    do: decode_discard_loop(rest, :figures, [32 | acc])

  defp decode_discard_loop(<<@carriage_return, rest::binary>>, mode, acc),
    do: decode_discard_loop(rest, mode, [?\r | acc])

  defp decode_discard_loop(<<@line_feed, rest::binary>>, mode, acc),
    do: decode_discard_loop(rest, mode, [?\n | acc])

  defp decode_discard_loop(<<code, rest::binary>>, mode, acc) do
    case elem(decode_table(mode), code) do
      nil -> decode_discard_loop(rest, mode, acc)
      codepoint -> decode_discard_loop(rest, mode, [codepoint | acc])
    end
  end

  defp encode_loop([], _mode, acc), do: {:ok, binary_result(acc)}

  defp encode_loop([32 | rest], mode, acc) do
    target = target_mode(rest, mode)
    blank = if target == :letters, do: @letter_blank, else: @figure_blank
    encode_loop(rest, target, [blank | acc])
  end

  defp encode_loop([codepoint | rest], mode, acc) do
    case encoded(codepoint, mode) do
      nil -> {:error, :unrepresentable_character, codepoint}
      code -> encode_loop(rest, mode, [code | acc])
    end
  end

  defp encode_discard_loop([], _mode, acc), do: {:ok, binary_result(acc)}

  defp encode_discard_loop([32 | rest], mode, acc) do
    target = target_mode(rest, mode)
    blank = if target == :letters, do: @letter_blank, else: @figure_blank
    encode_discard_loop(rest, target, [blank | acc])
  end

  defp encode_discard_loop([codepoint | rest], mode, acc) do
    case encoded(codepoint, mode) do
      nil -> encode_discard_loop(rest, mode, acc)
      code -> encode_discard_loop(rest, mode, [code | acc])
    end
  end

  defp encoded(?\r, _mode), do: @carriage_return
  defp encoded(?\n, _mode), do: @line_feed
  defp encoded(codepoint, :letters), do: Map.get(@letters, codepoint)
  defp encoded(codepoint, :figures), do: Map.get(@figures, codepoint)

  defp target_mode([], mode), do: mode
  defp target_mode([32 | rest], mode), do: target_mode(rest, mode)
  defp target_mode([codepoint | _rest], _mode) when is_map_key(@letters, codepoint), do: :letters
  defp target_mode([codepoint | _rest], _mode) when is_map_key(@figures, codepoint), do: :figures
  defp target_mode([_shared_or_unknown | rest], mode), do: target_mode(rest, mode)

  defp decode_table(:letters), do: @letters_tuple
  defp decode_table(:figures), do: @figures_tuple
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

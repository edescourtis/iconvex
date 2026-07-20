defmodule Iconvex.Telecom.ITA2S2 do
  @moduledoc """
  ITU-T S.2 case-preserving extension of International Telegraph Alphabet No. 2.

  The external form remains one five-bit ITA2 unit per octet. S.2 assigns
  additional meaning to FIGS/FS and LTRS/LS sequences so a receiver can
  distinguish lowercase, a single capital, capital-lock groups, and figures.
  `Iconvex.Telecom.ITA2.Packing` can pack these units consecutively.
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
  @letters_tuple 0..31 |> Enum.map(&Map.get(@letters_decode, &1)) |> List.to_tuple()
  @figures_tuple 0..31 |> Enum.map(&Map.get(@figures_decode, &1)) |> List.to_tuple()
  @letters_encode @letters |> Map.new(fn {code, codepoint} -> {codepoint, code} end)
  @figures_encode @figures |> Map.new(fn {code, codepoint} -> {codepoint, code} end)
  @shared_encode Map.take(@letters_encode, [0x0000, ?\n, ?\s, ?\r])

  @fs 27
  @ls 31

  @impl true
  def canonical_name, do: "ITA2-S2"

  @impl true
  def aliases,
    do: ["ITA2-S.2", "ITA-2-S2", "CCITT-S.2", "ITU-T-S.2", "CASE-PRESERVING-ITA2"]

  @impl true
  def stateful?, do: true

  @impl true
  def decode(input) when is_binary(input), do: decode_loop(input, :m1_small, 0, [])

  @impl true
  def decode_discard(input) when is_binary(input),
    do: decode_discard_loop(input, :m1_small, [])

  @impl true
  def encode(codepoints) when is_list(codepoints),
    do: encode_loop(codepoints, :m1_small, [])

  @impl true
  def encode_discard(codepoints) when is_list(codepoints),
    do: encode_discard_loop(codepoints, :m1_small, [])

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
        case encode(codepoints) do
          {:error, kind, codepoint} -> {:encode_error, kind, codepoint}
          result -> result
        end

      {:incomplete, converted, rest} ->
        utf8_error(converted, :incomplete_sequence, input, rest)

      {:error, converted, rest} ->
        utf8_error(converted, :invalid_sequence, input, rest)
    end
  end

  defp decode_loop(<<>>, _state, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_loop(<<byte, _rest::binary>>, _state, offset, _acc) when byte > 31,
    do: {:error, :invalid_sequence, offset, <<byte>>}

  defp decode_loop(<<@fs, rest::binary>>, state, offset, acc),
    do: decode_loop(rest, on_fs(state), offset + 1, acc)

  defp decode_loop(<<@ls, rest::binary>>, state, offset, acc),
    do: decode_loop(rest, on_ls(state), offset + 1, acc)

  defp decode_loop(<<code, rest::binary>>, state, offset, acc) do
    {codepoint, next_state} = decoded(code, state)
    decode_loop(rest, next_state, offset + 1, [codepoint | acc])
  end

  defp decode_discard_loop(<<>>, _state, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_loop(<<byte, rest::binary>>, state, acc) when byte > 31,
    do: decode_discard_loop(rest, state, acc)

  defp decode_discard_loop(<<@fs, rest::binary>>, state, acc),
    do: decode_discard_loop(rest, on_fs(state), acc)

  defp decode_discard_loop(<<@ls, rest::binary>>, state, acc),
    do: decode_discard_loop(rest, on_ls(state), acc)

  defp decode_discard_loop(<<code, rest::binary>>, state, acc) do
    {codepoint, next_state} = decoded(code, state)
    decode_discard_loop(rest, next_state, [codepoint | acc])
  end

  defp on_fs(:m1_small), do: :m1_figures_candidate
  defp on_fs(:m1_single), do: :m1_figures
  defp on_fs(:m1_figures_candidate), do: :m1_figures
  defp on_fs(:m1_figures), do: :m1_figures
  defp on_fs(:m2_caps), do: :m2_figures
  defp on_fs(:m2_figures), do: :m2_figures

  defp on_ls(:m1_small), do: :m1_single
  defp on_ls(:m1_single), do: :m1_single
  defp on_ls(:m1_figures_candidate), do: :m2_caps
  defp on_ls(:m1_figures), do: :m1_small
  defp on_ls(:m2_caps), do: :m1_small
  defp on_ls(:m2_figures), do: :m2_caps

  defp decoded(code, :m1_figures_candidate),
    do: {elem(@figures_tuple, code), :m1_figures}

  defp decoded(code, :m1_figures), do: {elem(@figures_tuple, code), :m1_figures}
  defp decoded(code, :m2_figures), do: {elem(@figures_tuple, code), :m2_figures}

  defp decoded(code, :m1_single) do
    codepoint = elem(@letters_tuple, code)
    {letter_case(codepoint, :upper), :m1_small}
  end

  defp decoded(code, :m1_small) do
    codepoint = elem(@letters_tuple, code)
    {letter_case(codepoint, :lower), :m1_small}
  end

  defp decoded(code, :m2_caps) do
    codepoint = elem(@letters_tuple, code)
    {letter_case(codepoint, :upper), :m2_caps}
  end

  defp letter_case(codepoint, :lower) when codepoint in ?A..?Z, do: codepoint + 32
  defp letter_case(codepoint, _case), do: codepoint

  defp encode_loop([], _state, acc), do: {:ok, encode_result(acc)}

  defp encode_loop(codepoints, state, acc) do
    case encoded(codepoints, state) do
      nil -> {:error, :unrepresentable_character, hd(codepoints)}
      {bytes, next_state} -> encode_loop(tl(codepoints), next_state, [bytes | acc])
    end
  end

  defp encode_discard_loop([], _state, acc), do: {:ok, encode_result(acc)}

  defp encode_discard_loop(codepoints, state, acc) do
    case encoded(codepoints, state) do
      nil -> encode_discard_loop(tl(codepoints), state, acc)
      {bytes, next_state} -> encode_discard_loop(tl(codepoints), next_state, [bytes | acc])
    end
  end

  defp encoded([codepoint | rest], state) do
    cond do
      Map.has_key?(@shared_encode, codepoint) ->
        {Map.fetch!(@shared_encode, codepoint), state}

      codepoint in ?a..?z ->
        encode_lower(codepoint - 32, state)

      codepoint in ?A..?Z ->
        encode_upper(codepoint, state, upper_group?([codepoint | rest]))

      Map.has_key?(@figures_encode, codepoint) ->
        encode_figure(codepoint, state)

      true ->
        nil
    end
  end

  defp encode_lower(uppercase, :m1_small), do: {@letters_encode[uppercase], :m1_small}
  defp encode_lower(uppercase, :m1_figures), do: {<<@ls, @letters_encode[uppercase]>>, :m1_small}
  defp encode_lower(uppercase, :m2_caps), do: {<<@ls, @letters_encode[uppercase]>>, :m1_small}

  defp encode_lower(uppercase, :m2_figures),
    do: {<<@ls, @ls, @letters_encode[uppercase]>>, :m1_small}

  defp encode_upper(codepoint, :m1_small, true),
    do: {<<@fs, @ls, @letters_encode[codepoint]>>, :m2_caps}

  defp encode_upper(codepoint, :m1_small, false),
    do: {<<@ls, @letters_encode[codepoint]>>, :m1_small}

  defp encode_upper(codepoint, :m1_figures, true),
    do: {<<@ls, @fs, @ls, @letters_encode[codepoint]>>, :m2_caps}

  defp encode_upper(codepoint, :m1_figures, false),
    do: {<<@ls, @ls, @letters_encode[codepoint]>>, :m1_small}

  defp encode_upper(codepoint, :m2_caps, _lock), do: {@letters_encode[codepoint], :m2_caps}

  defp encode_upper(codepoint, :m2_figures, _lock),
    do: {<<@ls, @letters_encode[codepoint]>>, :m2_caps}

  defp encode_figure(codepoint, :m1_small),
    do: {<<@fs, @figures_encode[codepoint]>>, :m1_figures}

  defp encode_figure(codepoint, :m1_figures),
    do: {@figures_encode[codepoint], :m1_figures}

  defp encode_figure(codepoint, :m2_caps),
    do: {<<@fs, @figures_encode[codepoint]>>, :m2_figures}

  defp encode_figure(codepoint, :m2_figures),
    do: {@figures_encode[codepoint], :m2_figures}

  defp upper_group?(codepoints), do: upper_letters(codepoints, 3) == 3
  defp upper_letters(_codepoints, 0), do: 3
  defp upper_letters([], _remaining), do: 0

  defp upper_letters([codepoint | rest], remaining) when codepoint in ?A..?Z,
    do: upper_letters(rest, remaining - 1)

  defp upper_letters([codepoint | _rest], _remaining) when codepoint in ?a..?z, do: 0
  defp upper_letters([_nonletter | rest], remaining), do: upper_letters(rest, remaining)

  defp encode_result(acc), do: acc |> :lists.reverse() |> IO.iodata_to_binary()

  defp utf8_error(converted, kind, input, rest) do
    case encode(converted) do
      {:error, encode_kind, codepoint} -> {:encode_error, encode_kind, codepoint}
      {:ok, _prefix} -> {:decode_error, kind, byte_size(input) - byte_size(rest), rest}
    end
  end
end

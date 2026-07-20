defmodule Iconvex.Specs.ICUJIS.Data do
  @moduledoc false

  @path Path.expand("../../../priv/icu_jis.etf", __DIR__)
  @external_resource @path

  def fetch, do: Iconvex.Specs.RuntimeAsset.fetch(__MODULE__, @path)
end

defmodule Iconvex.Specs.ICUJIS do
  @moduledoc """
  Pure Elixir implementation of ICU 78.3's JIS7 and JIS8 converters.

  The state machine is ported from ICU's pinned `ucnv2022.cpp`. Its five
  component mapping tables are generated from the exact UCM sources loaded by
  ICU: Shift-JIS/JIS X 0208, JIS X 0212, GB 2312, KS C 5601, and ISO-8859-7.
  """

  alias Iconvex.Specs.ICUJIS.Data

  @manifest_path Path.expand("../../../priv/icu_jis_manifest.etf", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()
  @entries Map.new(@manifest.encodings, &{&1.variant, &1})
  @preference [:ascii, :roman, :latin1, :jis208, :greek, :jis212, :gb, :ksc]
  @dbcs [:jis208, :jis212, :gb, :ksc]
  @forbidden_controls [0x0E, 0x0F, 0x1B]

  @type variant :: :jis7 | :jis8
  @type charset :: :ascii | :roman | :latin1 | :greek | :kana7 | :jis208 | :jis212 | :gb | :ksc
  @type state :: {charset(), charset() | nil, 0 | 1 | 2, 0 | 1 | 2}

  def aggregate_sha256, do: @manifest.aggregate_sha256
  def entries, do: @manifest.encodings
  def entry(variant), do: Map.fetch!(@entries, variant)
  def release, do: @manifest.release
  def revision, do: @manifest.revision
  def source_url, do: @manifest.source_url
  def sources, do: @manifest.sources

  def decode(variant, input) when variant in [:jis7, :jis8] and is_binary(input) do
    decode_loop(input, Data.fetch(), variant, {:ascii, nil, 0, 0}, 0, [], false)
  end

  def decode_discard(variant, input) when variant in [:jis7, :jis8] and is_binary(input) do
    decode_loop(input, Data.fetch(), variant, {:ascii, nil, 0, 0}, 0, [], true)
  end

  def encode(variant, codepoints) when variant in [:jis7, :jis8] and is_list(codepoints) do
    encode_loop(codepoints, Data.fetch(), variant, {:ascii, nil, 0, 0}, [], false)
  end

  def encode_discard(variant, codepoints)
      when variant in [:jis7, :jis8] and is_list(codepoints) do
    encode_loop(codepoints, Data.fetch(), variant, {:ascii, nil, 0, 0}, [], true)
  end

  def encode_substitute(variant, codepoints, replacer)
      when variant in [:jis7, :jis8] and is_list(codepoints) and is_function(replacer, 1) do
    encode_substitute_loop(
      codepoints,
      [],
      false,
      Data.fetch(),
      variant,
      {:ascii, nil, 0, 0},
      [],
      replacer
    )
  end

  def decode_to_utf8(variant, input) do
    with {:ok, codepoints} <- decode(variant, input), do: {:ok, List.to_string(codepoints)}
  end

  def encode_from_utf8(variant, input) when is_binary(input) do
    Iconvex.Specs.CodecSupport.encode_utf8(input, &encode(variant, &1))
  end

  defp decode_loop(<<>>, _data, _variant, _state, _offset, acc, _discard?) do
    {:ok, :lists.reverse(acc)}
  end

  defp decode_loop(<<0x1B, _::binary>> = input, data, variant, state, offset, acc, discard?) do
    case escape(input) do
      {:g0, charset, size, rest} ->
        {_g0, g2, g, prev} = state
        decode_loop(rest, data, variant, {charset, g2, g, prev}, offset + size, acc, discard?)

      {:g2, charset, size, rest} ->
        {g0, _g2, g, prev} = state
        decode_loop(rest, data, variant, {g0, charset, g, prev}, offset + size, acc, discard?)

      {:ss2, size, rest} ->
        {g0, g2, g, prev} = state

        if g2 == nil do
          invalid(input, size, data, variant, state, offset, acc, discard?)
        else
          previous = if g < 2, do: g, else: prev
          decode_loop(rest, data, variant, {g0, g2, 2, previous}, offset + size, acc, discard?)
        end

      :incomplete ->
        incomplete(input, offset, acc, discard?)

      {:invalid, size} ->
        invalid(input, size, data, variant, state, offset, acc, discard?)
    end
  end

  defp decode_loop(<<0x0F, rest::binary>>, data, :jis7, {g0, g2, _g, prev}, offset, acc, discard?) do
    decode_loop(rest, data, :jis7, {g0, g2, 0, prev}, offset + 1, acc, discard?)
  end

  defp decode_loop(<<0x0E, rest::binary>>, data, :jis7, {g0, g2, _g, prev}, offset, acc, discard?) do
    decode_loop(rest, data, :jis7, {g0, g2, 1, prev}, offset + 1, acc, discard?)
  end

  defp decode_loop(<<byte, _::binary>> = input, data, variant, state, offset, acc, discard?)
       when byte in [0x0E, 0x0F] do
    invalid(input, 1, data, variant, state, offset, acc, discard?)
  end

  defp decode_loop(<<byte, _::binary>> = input, data, variant, state, offset, acc, discard?)
       when byte in [0x0A, 0x0D] do
    {g0, _g2, _g, prev} = state
    line_g0 = if g0 in [:ascii, :roman], do: g0, else: :ascii
    decode_character(input, data, variant, {line_g0, nil, 0, prev}, offset, acc, discard?)
  end

  defp decode_loop(input, data, variant, state, offset, acc, discard?) do
    decode_character(input, data, variant, state, offset, acc, discard?)
  end

  defp decode_character(input, data, variant, state, offset, acc, discard?) do
    case decode_one(input, data, variant, state) do
      {:ok, codepoint, size, next_state} ->
        <<_::binary-size(size), rest::binary>> = input

        decode_loop(
          rest,
          data,
          variant,
          next_state,
          offset + size,
          [codepoint | acc],
          discard?
        )

      :incomplete ->
        incomplete(input, offset, acc, discard?)

      {:invalid, size} ->
        invalid(input, size, data, variant, state, offset, acc, discard?)
    end
  end

  defp decode_one(<<byte, _::binary>>, _data, :jis8, state)
       when byte in 0xA1..0xDF do
    if current_charset(state) in @dbcs do
      {:invalid, 1}
    else
      {:ok, byte + 0xFEC0, 1, restore_single_shift(state)}
    end
  end

  defp decode_one(input, data, _variant, state) do
    case current_charset(state) do
      :ascii ->
        decode_ascii(input, state)

      :roman ->
        decode_roman(input, state)

      :kana7 ->
        decode_kana(input, state)

      :latin1 ->
        decode_latin1(input, state)

      :greek ->
        decode_table_byte(input, data.greek.decode, state)

      charset when charset in @dbcs ->
        decode_table_pair(input, Map.fetch!(data, charset).decode, state)

      nil ->
        {:invalid, 1}
    end
  end

  defp decode_ascii(<<byte, _::binary>>, state) when byte <= 0x7F,
    do: {:ok, byte, 1, restore_single_shift(state)}

  defp decode_ascii(_input, _state), do: {:invalid, 1}

  defp decode_roman(<<byte, _::binary>>, state) when byte <= 0x7F do
    codepoint = if byte == 0x5C, do: 0x00A5, else: if(byte == 0x7E, do: 0x203E, else: byte)
    {:ok, codepoint, 1, restore_single_shift(state)}
  end

  defp decode_roman(_input, _state), do: {:invalid, 1}

  defp decode_kana(<<byte, _::binary>>, state) when byte in 0x21..0x5F,
    do: {:ok, byte + 0xFF40, 1, restore_single_shift(state)}

  defp decode_kana(_input, _state), do: {:invalid, 1}

  defp decode_latin1(<<byte, _::binary>>, state) when byte <= 0x7F,
    do: {:ok, byte + 0x80, 1, restore_single_shift(state)}

  defp decode_latin1(_input, _state), do: {:invalid, 1}

  defp decode_table_byte(<<byte, _::binary>>, mapping, state) when byte <= 0x7F do
    case Map.fetch(mapping, <<byte>>) do
      {:ok, codepoint} -> {:ok, codepoint, 1, restore_single_shift(state)}
      :error -> {:invalid, 1}
    end
  end

  defp decode_table_byte(_input, _mapping, _state), do: {:invalid, 1}

  defp decode_table_pair(<<>>, _mapping, _state), do: :incomplete
  defp decode_table_pair(<<_first>>, _mapping, _state), do: :incomplete

  defp decode_table_pair(<<first, second, _::binary>>, mapping, state) do
    cond do
      first not in 0x21..0x7E ->
        {:invalid, 1}

      second not in 0x21..0x7E ->
        {:invalid, if(second in @forbidden_controls, do: 1, else: 2)}

      true ->
        case Map.fetch(mapping, <<first, second>>) do
          {:ok, codepoint} -> {:ok, codepoint, 2, restore_single_shift(state)}
          :error -> {:invalid, 2}
        end
    end
  end

  defp current_charset({g0, _g2, 0, _prev}), do: g0
  defp current_charset({_g0, _g2, 1, _prev}), do: :kana7
  defp current_charset({_g0, g2, 2, _prev}), do: g2

  defp restore_single_shift({g0, g2, 2, prev}), do: {g0, g2, prev, prev}
  defp restore_single_shift(state), do: state

  defp invalid(input, size, data, variant, state, offset, acc, true) do
    size = min(max(size, 1), byte_size(input))
    <<_::binary-size(size), rest::binary>> = input
    decode_loop(rest, data, variant, state, offset + size, acc, true)
  end

  defp invalid(input, size, _data, _variant, _state, offset, _acc, false) do
    size = min(max(size, 1), byte_size(input))
    {:error, :invalid_sequence, offset, binary_part(input, 0, size)}
  end

  defp incomplete(_input, _offset, acc, true), do: {:ok, :lists.reverse(acc)}
  defp incomplete(input, offset, _acc, false), do: {:error, :incomplete_sequence, offset, input}

  defp escape(<<0x1B, ?N, rest::binary>>), do: {:ss2, 2, rest}
  defp escape(<<0x1B, ?(, ?B, rest::binary>>), do: {:g0, :ascii, 3, rest}
  defp escape(<<0x1B, ?(, ?J, rest::binary>>), do: {:g0, :roman, 3, rest}
  defp escape(<<0x1B, ?(, ?I, rest::binary>>), do: {:g0, :kana7, 3, rest}
  defp escape(<<0x1B, ?$, ?B, rest::binary>>), do: {:g0, :jis208, 3, rest}
  defp escape(<<0x1B, ?$, ?@, rest::binary>>), do: {:g0, :jis208, 3, rest}
  defp escape(<<0x1B, ?$, ?A, rest::binary>>), do: {:g0, :gb, 3, rest}
  defp escape(<<0x1B, ?$, ?(, ?D, rest::binary>>), do: {:g0, :jis212, 4, rest}
  defp escape(<<0x1B, ?$, ?(, ?C, rest::binary>>), do: {:g0, :ksc, 4, rest}
  defp escape(<<0x1B, ?., ?A, rest::binary>>), do: {:g2, :latin1, 3, rest}
  defp escape(<<0x1B, ?., ?F, rest::binary>>), do: {:g2, :greek, 3, rest}
  defp escape(<<0x1B>>), do: :incomplete
  defp escape(<<0x1B, char>>) when char in [?(, ?$, ?.], do: :incomplete
  defp escape(<<0x1B, ?$, ?(>>), do: :incomplete
  defp escape(<<0x1B, ?$, ?(, _unknown, _::binary>>), do: {:invalid, 4}
  defp escape(input), do: {:invalid, min(3, byte_size(input))}

  defp encode_loop([], _data, _variant, state, acc, _discard?) do
    suffix = terminal_reset(state)
    {:ok, acc |> :lists.reverse([suffix]) |> IO.iodata_to_binary()}
  end

  defp encode_loop([codepoint | rest], data, variant, state, acc, discard?) do
    case choose(codepoint, data, variant, state) do
      {:ok, choice} ->
        {output, next_state} = emit(choice, state)
        next_state = if codepoint in [0x0A, 0x0D], do: clear_g2(next_state), else: next_state
        encode_loop(rest, data, variant, next_state, [output | acc], discard?)

      :error when discard? ->
        encode_loop(rest, data, variant, state, acc, true)

      :error ->
        {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_substitute_loop([], resume, true, data, variant, state, acc, replacer),
    do: encode_substitute_loop(resume, [], false, data, variant, state, acc, replacer)

  defp encode_substitute_loop([], [], false, _data, _variant, state, acc, _replacer) do
    suffix = terminal_reset(state)
    {:ok, acc |> :lists.reverse([suffix]) |> IO.iodata_to_binary()}
  end

  defp encode_substitute_loop(
         [codepoint | rest],
         resume,
         replacement?,
         data,
         variant,
         state,
         acc,
         replacer
       ) do
    case choose(codepoint, data, variant, state) do
      {:ok, choice} ->
        {output, next_state} = emit(choice, state)
        next_state = if codepoint in [0x0A, 0x0D], do: clear_g2(next_state), else: next_state

        encode_substitute_loop(
          rest,
          resume,
          replacement?,
          data,
          variant,
          next_state,
          [output | acc],
          replacer
        )

      :error when replacement? ->
        {:error, :unrepresentable_character, codepoint}

      :error ->
        encode_substitute_loop(
          replacer.(codepoint),
          rest,
          true,
          data,
          variant,
          state,
          acc,
          replacer
        )
    end
  end

  defp choose(codepoint, _data, _variant, _state) when codepoint in @forbidden_controls,
    do: :error

  defp choose(codepoint, _data, :jis7, _state) when codepoint in 0xFF61..0xFF9F,
    do: {:ok, {:kana7, 1, <<codepoint - 0xFF40>>}}

  defp choose(codepoint, _data, :jis8, {g0, _g2, _g, _prev})
       when codepoint in 0xFF61..0xFF9F do
    charset = if g0 in @dbcs, do: :roman, else: g0
    {:ok, {charset, 0, <<codepoint - 0xFEC0>>}}
  end

  defp choose(codepoint, data, _variant, {g0, g2, _g, _prev}) do
    case map_character(g0, codepoint, data) do
      {:ok, _choice} = found ->
        found

      :error ->
        case g2 && map_character(g2, codepoint, data) do
          {:ok, _choice} = found -> found
          _ -> choose_preferred(@preference, codepoint, data)
        end
    end
  end

  defp choose_preferred([], _codepoint, _data), do: :error

  defp choose_preferred([charset | rest], codepoint, data) do
    case map_character(charset, codepoint, data) do
      {:ok, _choice} = found -> found
      :error -> choose_preferred(rest, codepoint, data)
    end
  end

  defp map_character(:ascii, codepoint, _data) when codepoint <= 0x7F,
    do: {:ok, {:ascii, 0, <<codepoint>>}}

  defp map_character(:roman, codepoint, _data)
       when codepoint <= 0x7F and codepoint not in [0x5C, 0x7E],
       do: {:ok, {:roman, 0, <<codepoint>>}}

  defp map_character(:roman, 0x00A5, _data), do: {:ok, {:roman, 0, <<0x5C>>}}
  defp map_character(:roman, 0x203E, _data), do: {:ok, {:roman, 0, <<0x7E>>}}

  defp map_character(:latin1, codepoint, _data) when codepoint in 0xA0..0xFF,
    do: {:ok, {:latin1, 2, <<codepoint - 0x80>>}}

  defp map_character(charset, codepoint, data)
       when charset in [:jis208, :jis212, :gb, :ksc, :greek] do
    case Map.fetch(Map.fetch!(data, charset).encode, codepoint) do
      {:ok, bytes} -> {:ok, {charset, if(charset == :greek, do: 2, else: 0), bytes}}
      :error -> :error
    end
  end

  defp map_character(_charset, _codepoint, _data), do: :error

  defp emit({charset, target_g, bytes}, state) do
    {si, state} = leave_shift_out(target_g, state)
    {designation, state} = designate(charset, target_g, state)
    {shift, state} = shift(target_g, state)
    {[si, designation, shift, bytes], state}
  end

  defp leave_shift_out(0, {g0, g2, 1, _prev}), do: {<<0x0F>>, {g0, g2, 0, 0}}
  defp leave_shift_out(_target_g, state), do: {<<>>, state}

  defp designate(charset, 0, {charset, g2, g, prev}), do: {<<>>, {charset, g2, g, prev}}

  defp designate(charset, 0, {_g0, g2, g, prev}),
    do: {designation(charset), {charset, g2, g, prev}}

  defp designate(_charset, 1, state), do: {<<>>, state}
  defp designate(charset, 2, {g0, charset, g, prev}), do: {<<>>, {g0, charset, g, prev}}

  defp designate(charset, 2, {g0, _g2, g, prev}),
    do: {designation(charset), {g0, charset, g, prev}}

  defp shift(0, state), do: {<<>>, state}
  defp shift(1, {g0, g2, 1, prev}), do: {<<>>, {g0, g2, 1, prev}}
  defp shift(1, {g0, g2, _g, _prev}), do: {<<0x0E>>, {g0, g2, 1, 0}}
  defp shift(2, state), do: {<<0x1B, ?N>>, state}

  defp designation(:ascii), do: <<0x1B, "(B">>
  defp designation(:roman), do: <<0x1B, "(J">>
  defp designation(:latin1), do: <<0x1B, ".A">>
  defp designation(:greek), do: <<0x1B, ".F">>
  defp designation(:jis208), do: <<0x1B, "$B">>
  defp designation(:jis212), do: <<0x1B, "$(D">>
  defp designation(:gb), do: <<0x1B, "$A">>
  defp designation(:ksc), do: <<0x1B, "$(C">>

  defp clear_g2({g0, _g2, g, prev}), do: {g0, nil, g, prev}

  defp terminal_reset({g0, _g2, g, _prev}) do
    [if(g == 0, do: <<>>, else: <<0x0F>>), if(g0 == :ascii, do: <<>>, else: designation(:ascii))]
  end
end

defmodule Iconvex.Specs.ICUJIS7 do
  @moduledoc "ICU 78.3 compatible JIS7 converter."
  use Iconvex.Codec
  alias Iconvex.Specs.ICUJIS, as: Engine
  def canonical_name, do: Engine.entry(:jis7).name
  def aliases, do: Engine.entry(:jis7).aliases
  def codec_id, do: Engine.entry(:jis7).id
  def decode(input), do: Engine.decode(:jis7, input)
  def decode_discard(input), do: Engine.decode_discard(:jis7, input)
  def decode_to_utf8(input), do: Engine.decode_to_utf8(:jis7, input)
  def encode(codepoints), do: Engine.encode(:jis7, codepoints)
  def encode_discard(codepoints), do: Engine.encode_discard(:jis7, codepoints)

  def encode_substitute(codepoints, replacer),
    do: Engine.encode_substitute(:jis7, codepoints, replacer)

  def encode_from_utf8(input), do: Engine.encode_from_utf8(:jis7, input)
end

defmodule Iconvex.Specs.ICUJIS8 do
  @moduledoc "ICU 78.3 compatible JIS8 converter."
  use Iconvex.Codec
  alias Iconvex.Specs.ICUJIS, as: Engine
  def canonical_name, do: Engine.entry(:jis8).name
  def aliases, do: Engine.entry(:jis8).aliases
  def codec_id, do: Engine.entry(:jis8).id
  def decode(input), do: Engine.decode(:jis8, input)
  def decode_discard(input), do: Engine.decode_discard(:jis8, input)
  def decode_to_utf8(input), do: Engine.decode_to_utf8(:jis8, input)
  def encode(codepoints), do: Engine.encode(:jis8, codepoints)
  def encode_discard(codepoints), do: Engine.encode_discard(:jis8, codepoints)

  def encode_substitute(codepoints, replacer),
    do: Engine.encode_substitute(:jis8, codepoints, replacer)

  def encode_from_utf8(input), do: Engine.encode_from_utf8(:jis8, input)
end

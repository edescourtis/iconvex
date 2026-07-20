defmodule Iconvex.Specs.SCSU do
  @moduledoc "SCSU (Standard Compression Scheme for Unicode), UTS #6."

  use Iconvex.Codec
  import Bitwise

  @static_offsets {0x0000, 0x0080, 0x0100, 0x0300, 0x2000, 0x2080, 0x2100, 0x3000}
  @initial_dynamic {0x0080, 0x00C0, 0x0400, 0x0600, 0x0900, 0x3040, 0x30A0, 0xFF00}
  @fixed_offsets [
    {0xF9, 0x00C0},
    {0xFA, 0x0250},
    {0xFB, 0x0370},
    {0xFC, 0x0530},
    {0xFD, 0x3040},
    {0xFE, 0x30A0},
    {0xFF, 0xFF60}
  ]
  @initial_lru [7, 0, 3, 2, 4, 5, 6, 1]

  @impl true
  def canonical_name, do: "SCSU"

  @impl true
  def aliases, do: ["csSCSU"]

  @impl true
  def codec_id, do: :scsu

  @impl true
  def stateful?, do: true

  @impl true
  def decode(input) when is_binary(input),
    do: decode_all(input, 0, decoder_state(), [], :strict)

  @impl true
  def decode_discard(input) when is_binary(input),
    do: decode_all(input, 0, decoder_state(), [], :discard)

  @impl true
  def encode(codepoints) when is_list(codepoints),
    do: encode_all(codepoints, encoder_state(), [])

  @impl true
  def encode_discard(codepoints) when is_list(codepoints),
    do: encode_discard_all(codepoints, encoder_state(), [])

  @impl true
  def encode_substitute(codepoints, replacer),
    do:
      Iconvex.Specs.CodecSupport.encode_substitute_transform(
        codepoints,
        &encode/1,
        replacer
      )

  @impl true
  def decode_to_utf8(input) do
    with {:ok, codepoints} <- decode(input), do: {:ok, List.to_string(codepoints)}
  end

  @impl true
  def encode_from_utf8(input) when is_binary(input) do
    if String.valid?(input) do
      encode(String.to_charlist(input))
    else
      Iconvex.Specs.CodecSupport.malformed_utf8(input)
    end
  end

  @impl true
  def decode_error_consumption(_kind, sequence), do: max(byte_size(sequence), 1)

  @impl true
  def stream_decoder_init, do: decoder_state()

  @impl true
  def decode_chunk(input, state, final?) when is_binary(input),
    do: decode_chunk_all(input, input, 0, state, [], final?, nil)

  @impl true
  def decode_recovery_state(_state, _kind, _sequence, _consumed), do: decoder_state()

  @impl true
  def stream_encoder_init, do: nil

  @impl true
  def encode_chunk(codepoints, state, false, _policy) when is_list(codepoints),
    do: {:ok, <<>>, state, codepoints}

  def encode_chunk(codepoints, state, true, policy) when is_list(codepoints) do
    case encode_with_policy(codepoints, policy) do
      {:ok, output} -> {:ok, output, state, []}
      error -> error
    end
  end

  defp decoder_state do
    %{mode: :single, dynamic: @initial_dynamic, window: 0, pending: nil}
  end

  defp encoder_state do
    %{mode: :single, dynamic: @initial_dynamic, window: 0, lru: @initial_lru}
  end

  defp decode_chunk_all(_original, <<>>, _offset, %{pending: nil} = state, acc, _final?, _rewind),
    do: {:ok, :lists.reverse(acc), state, <<>>}

  defp decode_chunk_all(
         original,
         <<>>,
         _offset,
         %{pending: _pending},
         acc,
         false,
         {pending_offset, checkpoint}
       ) do
    bytes = binary_part(original, pending_offset, byte_size(original) - pending_offset)
    {:ok, :lists.reverse(acc), checkpoint, bytes}
  end

  defp decode_chunk_all(
         _original,
         <<>>,
         _offset,
         %{pending: pending},
         _acc,
         true,
         _rewind
       ),
       do: {:error, :incomplete_sequence, pending.offset, pending.bytes}

  defp decode_chunk_all(original, input, offset, state, acc, final?, rewind) do
    case next_token(input, state) do
      {:state, sequence, rest, next_state} ->
        next_state = append_pending(next_state, sequence)

        decode_chunk_all(
          original,
          rest,
          offset + byte_size(sequence),
          next_state,
          acc,
          final?,
          rewind
        )

      {:emit, value, kind, sequence, rest, next_state} ->
        case emit_value(value, kind, sequence, offset, next_state, acc) do
          {:ok, emitted_state, next_acc} ->
            next_rewind =
              cond do
                is_nil(state.pending) and not is_nil(emitted_state.pending) -> {offset, state}
                not is_nil(state.pending) and is_nil(emitted_state.pending) -> nil
                true -> rewind
              end

            decode_chunk_all(
              original,
              rest,
              offset + byte_size(sequence),
              emitted_state,
              next_acc,
              final?,
              next_rewind
            )

          {:error, start, bad_sequence} ->
            {:error, :invalid_sequence, start, bad_sequence}
        end

      {:error, :incomplete_sequence, _token_sequence, <<>>} when not final? ->
        {pending_offset, checkpoint} =
          case {state.pending, rewind} do
            {nil, _rewind} -> {offset, state}
            {_pending, {start, prior_state}} -> {start, prior_state}
          end

        pending = binary_part(original, pending_offset, byte_size(original) - pending_offset)
        {:ok, :lists.reverse(acc), checkpoint, pending}

      {:error, kind, token_sequence, _rest} ->
        {start, sequence} = error_with_pending(state, offset, token_sequence)
        {:error, kind, start, sequence}
    end
  end

  defp decode_all(<<>>, _offset, %{pending: nil}, acc, _policy),
    do: {:ok, :lists.reverse(acc)}

  defp decode_all(<<>>, _offset, %{pending: _pending}, acc, :discard),
    do: {:ok, :lists.reverse(acc)}

  defp decode_all(<<>>, _offset, %{pending: pending}, _acc, :strict),
    do: {:error, :incomplete_sequence, pending.offset, pending.bytes}

  defp decode_all(input, offset, state, acc, policy) do
    case next_token(input, state) do
      {:state, sequence, rest, next_state} ->
        next_state = append_pending(next_state, sequence)
        decode_all(rest, offset + byte_size(sequence), next_state, acc, policy)

      {:emit, value, kind, sequence, rest, next_state} ->
        case emit_value(value, kind, sequence, offset, next_state, acc) do
          {:ok, next_state, next_acc} ->
            decode_all(
              rest,
              offset + byte_size(sequence),
              next_state,
              next_acc,
              policy
            )

          {:error, start, bad_sequence} when policy == :strict ->
            {:error, :invalid_sequence, start, bad_sequence}

          {:error, _start, _bad_sequence} ->
            decode_all(rest, offset + byte_size(sequence), decoder_state(), acc, policy)
        end

      {:error, kind, token_sequence, rest} ->
        {start, sequence} = error_with_pending(state, offset, token_sequence)

        if policy == :strict do
          {:error, kind, start, sequence}
        else
          decode_all(rest, offset + byte_size(token_sequence), decoder_state(), acc, policy)
        end
    end
  end

  defp next_token(input, %{mode: :single} = state), do: next_single(input, state)
  defp next_token(input, %{mode: :unicode} = state), do: next_unicode(input, state)

  defp next_single(<<byte, rest::binary>>, state)
       when byte in [0x00, 0x09, 0x0A, 0x0D] or byte in 0x20..0x7F,
       do: {:emit, byte, :unit, <<byte>>, rest, state}

  defp next_single(<<command, argument, rest::binary>>, state) when command in 0x01..0x08 do
    window = command - 1

    codepoint =
      if argument < 0x80 do
        elem(@static_offsets, window) + argument
      else
        elem(state.dynamic, window) + argument - 0x80
      end

    kind = if codepoint > 0xFFFF, do: :scalar, else: :unit
    {:emit, codepoint, kind, <<command, argument>>, rest, state}
  end

  defp next_single(<<command>>, _state) when command in 0x01..0x08,
    do: {:error, :incomplete_sequence, <<command>>, <<>>}

  defp next_single(<<0x0B, high, low, rest::binary>>, state) do
    {window, offset} = extended_window(high, low)
    dynamic = put_elem(state.dynamic, window, offset)
    next = %{state | dynamic: dynamic, window: window}
    {:state, <<0x0B, high, low>>, rest, next}
  end

  defp next_single(<<0x0B, rest::binary>> = input, _state) when byte_size(rest) < 2,
    do: {:error, :incomplete_sequence, input, <<>>}

  defp next_single(<<0x0C, rest::binary>>, _state),
    do: {:error, :invalid_sequence, <<0x0C>>, rest}

  defp next_single(<<0x0E, high, low, rest::binary>>, state),
    do: {:emit, high <<< 8 ||| low, :unit, <<0x0E, high, low>>, rest, state}

  defp next_single(<<0x0E, rest::binary>> = input, _state) when byte_size(rest) < 2,
    do: {:error, :incomplete_sequence, input, <<>>}

  defp next_single(<<0x0F, rest::binary>>, state),
    do: {:state, <<0x0F>>, rest, %{state | mode: :unicode}}

  defp next_single(<<command, rest::binary>>, state) when command in 0x10..0x17 do
    window = command - 0x10
    {:state, <<command>>, rest, %{state | window: window}}
  end

  defp next_single(<<command, index, rest::binary>>, state) when command in 0x18..0x1F do
    sequence = <<command, index>>

    case window_offset(index) do
      {:ok, offset} ->
        window = command - 0x18
        dynamic = put_elem(state.dynamic, window, offset)
        {:state, sequence, rest, %{state | dynamic: dynamic, window: window}}

      :error ->
        {:error, :invalid_sequence, sequence, rest}
    end
  end

  defp next_single(<<command>>, _state) when command in 0x18..0x1F,
    do: {:error, :incomplete_sequence, <<command>>, <<>>}

  defp next_single(<<byte, rest::binary>>, state) when byte >= 0x80 do
    codepoint = elem(state.dynamic, state.window) + byte - 0x80
    kind = if codepoint > 0xFFFF, do: :scalar, else: :unit
    {:emit, codepoint, kind, <<byte>>, rest, state}
  end

  defp next_unicode(<<command, rest::binary>>, state) when command in 0xE0..0xE7 do
    window = command - 0xE0
    {:state, <<command>>, rest, %{state | mode: :single, window: window}}
  end

  defp next_unicode(<<command, index, rest::binary>>, state) when command in 0xE8..0xEF do
    sequence = <<command, index>>

    case window_offset(index) do
      {:ok, offset} ->
        window = command - 0xE8
        dynamic = put_elem(state.dynamic, window, offset)

        {:state, sequence, rest, %{state | mode: :single, dynamic: dynamic, window: window}}

      :error ->
        {:error, :invalid_sequence, sequence, rest}
    end
  end

  defp next_unicode(<<command>>, _state) when command in 0xE8..0xEF,
    do: {:error, :incomplete_sequence, <<command>>, <<>>}

  defp next_unicode(<<0xF0, high, low, rest::binary>>, state),
    do: {:emit, high <<< 8 ||| low, :unit, <<0xF0, high, low>>, rest, state}

  defp next_unicode(<<0xF0, rest::binary>> = input, _state) when byte_size(rest) < 2,
    do: {:error, :incomplete_sequence, input, <<>>}

  defp next_unicode(<<0xF1, high, low, rest::binary>>, state) do
    {window, offset} = extended_window(high, low)
    dynamic = put_elem(state.dynamic, window, offset)

    {:state, <<0xF1, high, low>>, rest,
     %{state | mode: :single, dynamic: dynamic, window: window}}
  end

  defp next_unicode(<<0xF1, rest::binary>> = input, _state) when byte_size(rest) < 2,
    do: {:error, :incomplete_sequence, input, <<>>}

  defp next_unicode(<<0xF2, rest::binary>>, _state),
    do: {:error, :invalid_sequence, <<0xF2>>, rest}

  defp next_unicode(<<high, low, rest::binary>>, state),
    do: {:emit, high <<< 8 ||| low, :unit, <<high, low>>, rest, state}

  defp next_unicode(input, _state), do: {:error, :incomplete_sequence, input, <<>>}

  defp emit_value(value, :scalar, _sequence, _offset, %{pending: nil} = state, acc)
       when value in 0x10000..0x10FFFF,
       do: {:ok, state, [value | acc]}

  defp emit_value(value, :unit, sequence, offset, %{pending: nil} = state, acc)
       when value in 0xD800..0xDBFF,
       do: {:ok, %{state | pending: %{high: value, offset: offset, bytes: sequence}}, acc}

  defp emit_value(value, :unit, sequence, offset, %{pending: nil}, _acc)
       when value in 0xDC00..0xDFFF,
       do: {:error, offset, sequence}

  defp emit_value(value, :unit, _sequence, _offset, %{pending: nil} = state, acc),
    do: {:ok, state, [value | acc]}

  defp emit_value(value, :unit, _sequence, _offset, %{pending: pending} = state, acc)
       when value in 0xDC00..0xDFFF do
    codepoint = 0x10000 + ((pending.high - 0xD800) <<< 10) + value - 0xDC00
    {:ok, %{state | pending: nil}, [codepoint | acc]}
  end

  defp emit_value(_value, _kind, sequence, _offset, %{pending: pending}, _acc),
    do: {:error, pending.offset, pending.bytes <> sequence}

  defp append_pending(%{pending: nil} = state, _sequence), do: state

  defp append_pending(%{pending: pending} = state, sequence),
    do: %{state | pending: %{pending | bytes: pending.bytes <> sequence}}

  defp error_with_pending(%{pending: nil}, offset, sequence), do: {offset, sequence}

  defp error_with_pending(%{pending: pending}, _offset, sequence),
    do: {pending.offset, pending.bytes <> sequence}

  defp window_offset(index) when index in 0x01..0x67, do: {:ok, index * 0x80}
  defp window_offset(index) when index in 0x68..0xA7, do: {:ok, index * 0x80 + 0xAC00}

  defp window_offset(index) when index in 0xF9..0xFF,
    do: {:ok, elem({0x00C0, 0x0250, 0x0370, 0x0530, 0x3040, 0x30A0, 0xFF60}, index - 0xF9)}

  defp window_offset(_index), do: :error

  defp extended_window(high, low) do
    window = high >>> 5
    block = (high &&& 0x1F) <<< 8 ||| low
    {window, 0x10000 + block * 0x80}
  end

  defp encode_all([], _state, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_all([codepoint | rest], state, acc) do
    case encode_one(codepoint, state) do
      {:ok, bytes, next_state} -> encode_all(rest, next_state, [bytes | acc])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_discard_all([], _state, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_discard_all([codepoint | rest], state, acc) do
    case encode_one(codepoint, state) do
      {:ok, bytes, next_state} -> encode_discard_all(rest, next_state, [bytes | acc])
      :error -> encode_discard_all(rest, state, acc)
    end
  end

  defp encode_one(codepoint, %{mode: :single} = state)
       when codepoint in [0x00, 0x09, 0x0A, 0x0D] or codepoint in 0x20..0x7F,
       do: {:ok, <<codepoint>>, state}

  defp encode_one(codepoint, %{mode: :single} = state)
       when codepoint in 0..0x10FFFF and codepoint not in 0xD800..0xDFFF do
    cond do
      in_window?(codepoint, elem(state.dynamic, state.window)) ->
        {:ok, <<0x80 + codepoint - elem(state.dynamic, state.window)>>, state}

      window = dynamic_window(state.dynamic, codepoint) ->
        next = %{state | window: window, lru: mark_used(state.lru, window)}
        {:ok, <<0x10 + window, 0x80 + codepoint - elem(state.dynamic, window)>>, next}

      window = static_window(codepoint) ->
        {:ok, <<0x01 + window, codepoint - elem(@static_offsets, window)>>, state}

      codepoint > 0xFFFF ->
        define_extended(codepoint, state, 0x0B)

      definition = window_definition(codepoint) ->
        define_standard(codepoint, definition, state, 0x18)

      true ->
        next = %{state | mode: :unicode}
        {:ok, [<<0x0F>>, unicode_unit(codepoint)], next}
    end
  end

  defp encode_one(codepoint, %{mode: :unicode} = state)
       when codepoint in 0..0x10FFFF and codepoint not in 0xD800..0xDFFF do
    cond do
      codepoint in [0x00, 0x09, 0x0A, 0x0D] or codepoint in 0x20..0x7F ->
        next = %{state | mode: :single, lru: mark_used(state.lru, state.window)}
        {:ok, <<0xE0 + state.window, codepoint>>, next}

      window = dynamic_window(state.dynamic, codepoint) ->
        next = %{state | mode: :single, window: window, lru: mark_used(state.lru, window)}
        {:ok, <<0xE0 + window, 0x80 + codepoint - elem(state.dynamic, window)>>, next}

      codepoint > 0xFFFF ->
        define_extended(codepoint, state, 0xF1)

      definition = window_definition(codepoint) ->
        define_standard(codepoint, definition, state, 0xE8)

      true ->
        {:ok, unicode_unit(codepoint), state}
    end
  end

  defp encode_one(_codepoint, _state), do: :error

  defp encode_with_policy(codepoints, :error), do: encode(codepoints)
  defp encode_with_policy(codepoints, :discard), do: encode_discard(codepoints)

  defp encode_with_policy(codepoints, {:replace, replacer}),
    do: encode_substitute(codepoints, replacer)

  defp define_standard(codepoint, {index, offset}, state, command_base) do
    window = hd(state.lru)
    dynamic = put_elem(state.dynamic, window, offset)

    next = %{
      state
      | mode: :single,
        dynamic: dynamic,
        window: window,
        lru: mark_used(state.lru, window)
    }

    {:ok, <<command_base + window, index, 0x80 + codepoint - offset>>, next}
  end

  defp define_extended(codepoint, state, command) do
    window = hd(state.lru)
    block = div(codepoint - 0x10000, 0x80)
    offset = 0x10000 + block * 0x80
    high = window <<< 5 ||| block >>> 8
    low = block &&& 0xFF
    dynamic = put_elem(state.dynamic, window, offset)

    next = %{
      state
      | mode: :single,
        dynamic: dynamic,
        window: window,
        lru: mark_used(state.lru, window)
    }

    {:ok, <<command, high, low, 0x80 + codepoint - offset>>, next}
  end

  defp unicode_unit(codepoint) when codepoint <= 0xFFFF do
    high = codepoint >>> 8
    pair = <<codepoint::16-big>>
    if high in 0xE0..0xF2, do: [<<0xF0>>, pair], else: pair
  end

  defp dynamic_window(dynamic, codepoint),
    do: Enum.find(0..7, &in_window?(codepoint, elem(dynamic, &1)))

  defp static_window(codepoint),
    do: Enum.find(0..7, &in_window?(codepoint, elem(@static_offsets, &1)))

  defp in_window?(codepoint, offset), do: codepoint >= offset and codepoint < offset + 0x80

  defp window_definition(codepoint) do
    Enum.find_value(@fixed_offsets, fn {index, offset} ->
      if in_window?(codepoint, offset), do: {index, offset}
    end) || regular_window_definition(codepoint)
  end

  defp regular_window_definition(codepoint) when codepoint in 0x0080..0x33FF do
    index = div(codepoint, 0x80)
    {index, index * 0x80}
  end

  defp regular_window_definition(codepoint) when codepoint in 0xE000..0xFFFF do
    index = div(codepoint - 0xAC00, 0x80)
    {index, index * 0x80 + 0xAC00}
  end

  defp regular_window_definition(_codepoint), do: nil

  defp mark_used(lru, window), do: List.delete(lru, window) ++ [window]
end

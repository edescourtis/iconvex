defmodule Iconvex.UTF7Codec do
  @moduledoc false
  import Bitwise

  alias Iconvex.UnicodeCodec

  @direct MapSet.new(
            ~c"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'(),-./:? \t\n\r"
          )
  @optional MapSet.new(~c"!\"#$%&*;<=>@[\\]^_`{|}")
  @base64 MapSet.new(~c"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/-")

  def stream_init do
    %{
      mode: :direct,
      bits: 0,
      bit_count: 0,
      pending_byte: nil,
      high_surrogate: nil,
      shift_offset: nil,
      digits: 0,
      shifted_bytes: [],
      shifted_codepoints: []
    }
  end

  def decode_chunk(input, state, final?, base_offset) do
    result =
      case decode_stream(input, state, base_offset, []) do
        {:ok, codepoints, state} when final? -> finish_stream(state, codepoints)
        {:ok, codepoints, state} -> {:ok, codepoints, state, <<>>}
        error -> error
      end

    replay_continuing_shift_error(result, input, state)
  end

  def decode(%{id: :utf7}, input), do: decode_loop(input, 0, [])
  def decode_discard(%{id: :utf7}, input), do: decode_replace_loop(input, fn _byte -> [] end, [])

  def decode_substitute(%{id: :utf7}, input, replacer) when is_function(replacer, 1),
    do: decode_replace_loop(input, replacer, [])

  @doc false
  def decode_discard_gnu_ucs4(input, endian)
      when is_binary(input) and endian in [:big, :little],
      do: decode_gnu_discard_ucs4(input, 0, <<>>, endian)

  def encode(%{id: :utf7}, codepoints), do: encode_loop(codepoints, [])

  def encode_discard(%{id: :utf7}, codepoints),
    do: encode_loop(Enum.filter(codepoints, &encodable?/1), [])

  def encode_substitute(%{id: :utf7}, codepoints, replacer) when is_function(replacer, 1) do
    with {:ok, substituted} <- substitute_invalid(codepoints, replacer, []) do
      encode_loop(substituted, [])
    end
  end

  def stream_encode_init, do: %{mode: :direct, bits: 0, bit_count: 0}

  def encode_chunk(codepoints, state, final?, policy) do
    stream_encode(codepoints, [], false, state, final?, policy, [])
  end

  defp decode_stream(<<>>, state, _offset, acc),
    do: {:ok, :lists.reverse(acc), state}

  defp decode_stream(input, %{mode: :direct} = state, offset, acc) do
    case input do
      <<?+, rest::binary>> ->
        decode_stream(
          rest,
          begin_shift(state, offset),
          offset + 1,
          acc
        )

      <<byte, rest::binary>> when byte < 0x80 ->
        if xdirect?(byte),
          do: decode_stream(rest, state, offset + 1, [byte | acc]),
          else: {:error, :invalid_sequence, offset, <<byte>>}

      <<byte, _rest::binary>> ->
        {:error, :invalid_sequence, offset, <<byte>>}
    end
  end

  defp decode_stream(input, %{mode: :plus} = state, offset, acc) do
    case input do
      <<?-, rest::binary>> ->
        decode_stream(rest, reset_stream(state), offset + 1, [?+ | acc])

      <<byte, rest::binary>> ->
        if base64_digit?(byte) do
          state = append_shifted_byte(state, byte)
          state = %{state | mode: :shift, digits: 1}

          case push_base64(state, byte) do
            {:ok, emitted, state} ->
              decode_stream(rest, buffer_shifted(emitted, state), offset + 1, acc)

            {:error, _decoded_utf16} ->
              stream_shift_error(state)
          end
        else
          stream_shift_error(state)
        end
    end
  end

  defp decode_stream(input, %{mode: :shift} = state, offset, acc) do
    case input do
      <<?-, rest::binary>> ->
        case close_shift(state) do
          :ok ->
            {state, acc} = commit_shift(state, acc)
            decode_stream(rest, state, offset + 1, acc)

          {:error, _decoded_utf16} ->
            stream_shift_error(state)
        end

      <<byte, rest::binary>> ->
        if base64_digit?(byte) do
          state = append_shifted_byte(state, byte)
          state = %{state | digits: state.digits + 1}

          case push_base64(state, byte) do
            {:ok, emitted, state} ->
              decode_stream(rest, buffer_shifted(emitted, state), offset + 1, acc)

            {:error, _decoded_utf16} ->
              stream_shift_error(state)
          end
        else
          case close_shift(state) do
            :ok ->
              {state, acc} = commit_shift(state, acc)
              decode_stream(input, state, offset, acc)

            {:error, _decoded_utf16} ->
              stream_shift_error(state)
          end
        end
    end
  end

  defp finish_stream(%{mode: :direct} = state, codepoints),
    do: {:ok, codepoints, state, <<>>}

  defp finish_stream(%{mode: :plus} = state, _codepoints),
    do: stream_shift_error(state)

  defp finish_stream(%{mode: :shift} = state, codepoints) do
    case close_shift(state) do
      :ok ->
        shifted = :lists.reverse(state.shifted_codepoints)
        {:ok, codepoints ++ shifted, reset_stream(state), <<>>}

      {:error, _decoded_utf16} ->
        stream_shift_error(state)
    end
  end

  # An open shift is already decoded into `state`, so successful continuations
  # never return it as generic stream pending input. If a later chunk proves the
  # shift malformed, hand its original bytes and absolute start back to Stream;
  # Stream resets this decoder and runs that source through the existing policy
  # machinery exactly once. This keeps valid streaming linear without exposing
  # shifted codepoints before padding and surrogate validation succeed.
  defp replay_continuing_shift_error(
         {:error, _kind, _offset, _sequence},
         input,
         %{mode: mode, shift_offset: shift_offset} = state
       )
       when mode in [:plus, :shift],
       do: {:replay_utf7_source, shift_offset, shifted_source(state) <> input}

  defp replay_continuing_shift_error(result, _input, _state), do: result

  defp begin_shift(state, offset) do
    %{
      state
      | mode: :plus,
        bits: 0,
        bit_count: 0,
        pending_byte: nil,
        high_surrogate: nil,
        shift_offset: offset,
        digits: 0,
        shifted_bytes: [?+],
        shifted_codepoints: []
    }
  end

  defp append_shifted_byte(state, byte),
    do: %{state | shifted_bytes: [byte | state.shifted_bytes]}

  defp buffer_shifted([], state), do: state

  defp buffer_shifted(emitted, state),
    do: %{state | shifted_codepoints: :lists.reverse(emitted, state.shifted_codepoints)}

  defp commit_shift(state, acc),
    do: {reset_stream(state), state.shifted_codepoints ++ acc}

  defp shifted_source(%{mode: mode, shifted_bytes: bytes}) when mode in [:plus, :shift],
    do: bytes |> :lists.reverse() |> :erlang.list_to_binary()

  defp shifted_source(_state), do: <<>>

  defp push_base64(state, byte) do
    bits = state.bits <<< 6 ||| base64_value(byte)
    drain_base64(%{state | bits: bits, bit_count: state.bit_count + 6}, [])
  end

  defp drain_base64(%{bit_count: count} = state, acc) when count < 8,
    do: {:ok, :lists.reverse(acc), state}

  defp drain_base64(state, acc) do
    remaining = state.bit_count - 8
    byte = state.bits >>> remaining
    mask = if remaining == 0, do: 0, else: (1 <<< remaining) - 1
    state = %{state | bits: state.bits &&& mask, bit_count: remaining}

    case push_utf16_byte(state, byte) do
      {:ok, nil, state} -> drain_base64(state, acc)
      {:ok, codepoint, state} -> drain_base64(state, [codepoint | acc])
      {:error, sequence} -> {:error, sequence}
    end
  end

  defp push_utf16_byte(%{pending_byte: nil} = state, byte),
    do: {:ok, nil, %{state | pending_byte: byte}}

  defp push_utf16_byte(%{pending_byte: first} = state, second) do
    unit = first <<< 8 ||| second
    state = %{state | pending_byte: nil}

    case {state.high_surrogate, unit} do
      {nil, high} when high in 0xD800..0xDBFF ->
        {:ok, nil, %{state | high_surrogate: high}}

      {nil, low} when low in 0xDC00..0xDFFF ->
        {:error, <<first, second>>}

      {nil, scalar} ->
        {:ok, scalar, state}

      {high, low} when low in 0xDC00..0xDFFF ->
        scalar = 0x10000 + ((high - 0xD800) <<< 10) + low - 0xDC00
        {:ok, scalar, %{state | high_surrogate: nil}}

      {_high, _not_low} ->
        {:error, <<first, second>>}
    end
  end

  defp close_shift(state) do
    valid_padding? = state.bit_count in [0, 2, 4] and state.bits == 0

    if state.digits > 0 and valid_padding? and is_nil(state.pending_byte) and
         is_nil(state.high_surrogate),
       do: :ok,
       else: {:error, <<>>}
  end

  defp reset_stream(state) do
    %{
      state
      | mode: :direct,
        bits: 0,
        bit_count: 0,
        pending_byte: nil,
        high_surrogate: nil,
        shift_offset: nil,
        digits: 0,
        shifted_bytes: [],
        shifted_codepoints: []
    }
  end

  defp stream_shift_error(state),
    do: {:error, :invalid_sequence, state.shift_offset, shifted_source(state)}

  defp base64_value(byte) when byte in ?A..?Z, do: byte - ?A
  defp base64_value(byte) when byte in ?a..?z, do: byte - ?a + 26
  defp base64_value(byte) when byte in ?0..?9, do: byte - ?0 + 52
  defp base64_value(?+), do: 62
  defp base64_value(?/), do: 63

  defp decode_loop(<<>>, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_loop(<<"+-", rest::binary>>, offset, acc),
    do: decode_loop(rest, offset + 2, [?+ | acc])

  defp decode_loop(<<?+, rest::binary>> = input, offset, acc) do
    {encoded, tail} = take_base64(rest, [])

    if encoded == "" do
      {:error, :invalid_sequence, offset, <<?+>>}
    else
      {tail, terminator_size} =
        case tail do
          <<?-, remaining::binary>> -> {remaining, 1}
          remaining -> {remaining, 0}
        end

      with {:ok, bytes} <- decode_base64(encoded),
           true <- rem(byte_size(bytes), 2) == 0,
           {:ok, codepoints} <- UnicodeCodec.decode(%{id: :utf16be}, bytes) do
        consumed = 1 + byte_size(encoded) + terminator_size
        decode_loop(tail, offset + consumed, prepend_list(codepoints, acc))
      else
        _ ->
          {:error, :invalid_sequence, offset + 1, binary_part(input, 1, byte_size(encoded))}
      end
    end
  end

  defp decode_loop(<<byte, rest::binary>>, offset, acc) when byte < 0x80 do
    if xdirect?(byte) do
      decode_loop(rest, offset + 1, [byte | acc])
    else
      {:error, :invalid_sequence, offset, <<byte>>}
    end
  end

  defp decode_loop(<<byte, _::binary>>, offset, _acc),
    do: {:error, :invalid_sequence, offset, <<byte>>}

  defp decode_replace_loop(<<>>, _replacer, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_replace_loop(<<"+-", rest::binary>>, replacer, acc),
    do: decode_replace_loop(rest, replacer, [?+ | acc])

  defp decode_replace_loop(<<?+, rest::binary>>, replacer, acc) do
    {encoded, tail0} = take_base64(rest, [])

    {tail, terminator_size} =
      case tail0 do
        <<?-, remaining::binary>> -> {remaining, 1}
        remaining -> {remaining, 0}
      end

    result =
      with false <- encoded == "",
           {:ok, bytes} <- decode_base64(encoded),
           true <- rem(byte_size(bytes), 2) == 0,
           {:ok, codepoints} <- UnicodeCodec.decode(%{id: :utf16be}, bytes) do
        {:ok, codepoints}
      else
        _ -> :error
      end

    case result do
      {:ok, codepoints} ->
        _consumed = 1 + byte_size(encoded) + terminator_size
        decode_replace_loop(tail, replacer, :lists.reverse(codepoints, acc))

      :error ->
        decode_replace_loop(rest, replacer, replace(?+, replacer, acc))
    end
  end

  defp decode_replace_loop(<<byte, rest::binary>>, replacer, acc) when byte < 0x80 do
    if xdirect?(byte),
      do: decode_replace_loop(rest, replacer, [byte | acc]),
      else: decode_replace_loop(rest, replacer, replace(byte, replacer, acc))
  end

  defp decode_replace_loop(<<byte, rest::binary>>, replacer, acc),
    do: decode_replace_loop(rest, replacer, replace(byte, replacer, acc))

  # GNU libiconv retains the UTF-7 shift state that existed before an invalid
  # code unit, consumes the shift prefix plus one source byte, and resumes from
  # that retained state. This matters for adjacent explicit UCS-4 surrogate
  # units: the encoder can emit them, while the reverse `//IGNORE` path must
  # recover at the same base64 bit position as GNU.
  defp decode_gnu_discard_ucs4(<<>>, _state, acc, _endian), do: {:ok, acc}

  defp decode_gnu_discard_ucs4(input, state, acc, endian) do
    case gnu_utf7_next(input, state) do
      {:ok, codepoint, consumed, next_state} ->
        <<_::binary-size(consumed), rest::binary>> = input

        decode_gnu_discard_ucs4(
          rest,
          next_state,
          append_ucs4(acc, codepoint, endian),
          endian
        )

      {:skip, consumed, next_state} when consumed > 0 ->
        <<_::binary-size(consumed), rest::binary>> = input
        decode_gnu_discard_ucs4(rest, next_state, acc, endian)

      {:invalid, shifted, retained_state} ->
        consumed = shifted + 1
        <<_::binary-size(consumed), rest::binary>> = input
        decode_gnu_discard_ucs4(rest, retained_state, acc, endian)

      :incomplete ->
        :incomplete
    end
  end

  defp append_ucs4(acc, codepoint, :big), do: <<acc::binary, codepoint::unsigned-big-32>>

  defp append_ucs4(acc, codepoint, :little),
    do: <<acc::binary, codepoint::unsigned-little-32>>

  defp gnu_utf7_next(input, state) when (state &&& 3) == 0,
    do: gnu_utf7_inactive(input, state, 0)

  defp gnu_utf7_next(input, state),
    do: gnu_utf7_active(input, state, state, 0, 2, 0, 0, 0)

  defp gnu_utf7_inactive(<<>>, state, count) when count > 0,
    do: {:skip, count, state}

  defp gnu_utf7_inactive(<<>>, _state, 0), do: :incomplete

  defp gnu_utf7_inactive(<<?+, rest::binary>>, state, count) do
    case rest do
      <<>> when count > 0 ->
        {:skip, count, state}

      <<>> ->
        :incomplete

      <<?-, _tail::binary>> ->
        {:ok, ?+, count + 2, state}

      _base64_or_invalid ->
        gnu_utf7_active(rest, 1, 1, count + 1, 2, 0, 0, 0)
    end
  end

  defp gnu_utf7_inactive(<<byte, _rest::binary>>, state, count) when byte < 0x80 do
    if xdirect?(byte), do: {:ok, byte, count + 1, state}, else: {:invalid, count, state}
  end

  defp gnu_utf7_inactive(_input, state, count), do: {:invalid, count, state}

  defp gnu_utf7_active(<<>>, retained, _base64state, count, _kmax, _k, _wc, _digits)
       when count > 0,
       do: {:skip, count, retained}

  defp gnu_utf7_active(<<>>, _retained, _base64state, 0, _kmax, _k, _wc, _digits),
    do: :incomplete

  defp gnu_utf7_active(
         <<byte, rest::binary>> = input,
         retained,
         base64state,
         count,
         kmax,
         k,
         wc,
         digits
       ) do
    if base64_digit?(byte) do
      value = base64_value(byte)

      {next_base64state, next_k, next_wc} =
        case base64state &&& 3 do
          1 ->
            {value <<< 2, k, wc}

          0 ->
            {(value &&& 15) <<< 4 ||| 2, k + 1,
             wc <<< 8 ||| (base64state &&& 0xFC) ||| value >>> 4}

          2 ->
            {(value &&& 3) <<< 6 ||| 3, k + 1,
             wc <<< 8 ||| (base64state &&& 0xFC) ||| value >>> 2}

          3 ->
            {1, k + 1, wc <<< 8 ||| (base64state &&& 0xFC) ||| value}
        end

      next_digits = digits + 1

      cond do
        next_k == 2 and kmax == 2 and next_wc in 0xD800..0xDBFF ->
          gnu_utf7_active(
            rest,
            retained,
            next_base64state,
            count,
            4,
            next_k,
            next_wc,
            next_digits
          )

        next_k == kmax ->
          if kmax == 4 do
            high = next_wc >>> 16
            low = next_wc &&& 0xFFFF

            if low in 0xDC00..0xDFFF do
              scalar = 0x10000 + ((high - 0xD800) <<< 10) + low - 0xDC00
              {:ok, scalar, count + next_digits, next_base64state}
            else
              {:invalid, count, retained}
            end
          else
            {:ok, next_wc, count + next_digits, next_base64state}
          end

        true ->
          gnu_utf7_active(
            rest,
            retained,
            next_base64state,
            count,
            kmax,
            next_k,
            next_wc,
            next_digits
          )
      end
    else
      pending_data? = (base64state &&& 0xFC) != 0

      cond do
        pending_data? or digits > 0 ->
          {:invalid, count, retained}

        byte == ?- ->
          gnu_utf7_inactive(rest, 0, count + 1)

        true ->
          gnu_utf7_inactive(input, 0, count)
      end
    end
  end

  defp stream_encode([], resume, true, state, final?, policy, acc),
    do: stream_encode(resume, [], false, state, final?, policy, acc)

  defp stream_encode([], [], false, state, final?, _policy, acc) do
    {closing, state} = if final?, do: close_encode_shift(state, true), else: {<<>>, state}
    {:ok, acc |> :lists.reverse([closing]) |> IO.iodata_to_binary(), state, []}
  end

  defp stream_encode(
         [codepoint | rest],
         resume,
         replacement?,
         state,
         final?,
         policy,
         acc
       ) do
    cond do
      encodable?(codepoint) ->
        {output, state} = encode_stream_codepoint(codepoint, state)

        stream_encode(
          rest,
          resume,
          replacement?,
          state,
          final?,
          policy,
          [output | acc]
        )

      replacement? ->
        {:error, :unrepresentable_character, codepoint}

      policy == :error ->
        {:error, :unrepresentable_character, codepoint}

      policy == :discard ->
        stream_encode(rest, resume, false, state, final?, policy, acc)

      match?({:replace, _replacer}, policy) ->
        {:replace, replacer} = policy
        stream_encode(replacer.(codepoint), rest, true, state, final?, policy, acc)
    end
  end

  defp encode_stream_codepoint(?+, %{mode: :direct} = state), do: {"+-", state}

  defp encode_stream_codepoint(?+, state) do
    push_encode_bytes(encode_utf16_unit(?+), state, [])
  end

  defp encode_stream_codepoint(codepoint, state) do
    if direct?(codepoint) do
      {closing, state} = close_encode_shift(state, base64?(codepoint))
      {closing <> <<codepoint>>, state}
    else
      bytes = encode_utf16_unit(codepoint)
      opening? = state.mode == :direct
      {encoded, state} = push_encode_bytes(bytes, state, [])
      prefix = if opening?, do: "+", else: ""
      {prefix <> encoded, state}
    end
  end

  defp push_encode_bytes(<<>>, state, acc),
    do: {acc |> :lists.reverse() |> IO.iodata_to_binary(), state}

  defp push_encode_bytes(<<byte, rest::binary>>, state, acc) do
    bits = state.bits <<< 8 ||| byte
    state = %{state | bits: bits, bit_count: state.bit_count + 8, mode: :shift}
    {digits, state} = drain_encode_bits(state, [])
    push_encode_bytes(rest, state, [digits | acc])
  end

  defp drain_encode_bits(%{bit_count: count} = state, acc) when count < 6,
    do: {acc |> :lists.reverse() |> IO.iodata_to_binary(), state}

  defp drain_encode_bits(state, acc) do
    remaining = state.bit_count - 6
    value = state.bits >>> remaining
    mask = if remaining == 0, do: 0, else: (1 <<< remaining) - 1
    state = %{state | bits: state.bits &&& mask, bit_count: remaining}
    drain_encode_bits(state, [base64_character(value) | acc])
  end

  defp close_encode_shift(%{mode: :direct} = state, _terminator?), do: {<<>>, state}

  defp close_encode_shift(state, terminator?) do
    digit =
      if state.bit_count == 0,
        do: <<>>,
        else: base64_character(state.bits <<< (6 - state.bit_count))

    terminator = if terminator?, do: "-", else: ""
    {digit <> terminator, stream_encode_init()}
  end

  defp base64_character(value) when value < 26, do: <<?A + value>>
  defp base64_character(value) when value < 52, do: <<?a + value - 26>>
  defp base64_character(value) when value < 62, do: <<?0 + value - 52>>
  defp base64_character(62), do: "+"
  defp base64_character(63), do: "/"

  defp encode_loop([], acc), do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_loop([?+ | rest], acc),
    do: encode_loop(rest, ["+-" | acc])

  defp encode_loop([codepoint | rest], acc) do
    if direct?(codepoint) do
      encode_loop(rest, [<<codepoint>> | acc])
    else
      {group, tail} = Enum.split_while([codepoint | rest], &(not direct?(&1)))

      case encode_utf16_units(group, []) do
        {:ok, utf16} ->
          encoded = Base.encode64(utf16, padding: false)
          terminator = if tail == [] or base64?(hd(tail)), do: "-", else: ""
          encode_loop(tail, [["+", encoded, terminator] | acc])

        {:error, _kind, invalid} ->
          {:error, :unrepresentable_character, invalid}
      end
    end
  end

  defp substitute_invalid([], _replacer, acc), do: {:ok, :lists.reverse(acc)}

  defp substitute_invalid([codepoint | rest], replacer, acc) do
    if encodable?(codepoint) do
      substitute_invalid(rest, replacer, [codepoint | acc])
    else
      case validate_replacement(replacer.(codepoint), []) do
        {:ok, replacement} ->
          substitute_invalid(rest, replacer, :lists.reverse(replacement, acc))

        error ->
          error
      end
    end
  end

  defp validate_replacement([], acc), do: {:ok, :lists.reverse(acc)}

  defp validate_replacement([codepoint | rest], acc) do
    if encodable?(codepoint),
      do: validate_replacement(rest, [codepoint | acc]),
      else: {:error, :unrepresentable_character, codepoint}
  end

  defp take_base64(<<byte, rest::binary>>, acc) do
    if base64_digit?(byte) do
      take_base64(rest, [byte | acc])
    else
      {acc |> :lists.reverse() |> :erlang.list_to_binary(), <<byte, rest::binary>>}
    end
  end

  defp take_base64(<<>>, acc), do: {acc |> :lists.reverse() |> :erlang.list_to_binary(), <<>>}

  defp decode_base64(encoded) do
    case Base.decode64(encoded, padding: false) do
      {:ok, bytes} ->
        if Base.encode64(bytes, padding: false) == encoded, do: {:ok, bytes}, else: :error

      :error ->
        :error
    end
  end

  defp direct?(codepoint), do: MapSet.member?(@direct, codepoint)
  defp xdirect?(codepoint), do: direct?(codepoint) or MapSet.member?(@optional, codepoint)
  defp base64?(codepoint), do: MapSet.member?(@base64, codepoint)
  defp base64_digit?(codepoint), do: codepoint != ?- and base64?(codepoint)

  defp encodable?(codepoint), do: codepoint in 0..0x10FFFF

  defp encode_utf16_units([], acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_utf16_units([codepoint | rest], acc) when codepoint in 0..0x10FFFF,
    do: encode_utf16_units(rest, [encode_utf16_unit(codepoint) | acc])

  defp encode_utf16_units([codepoint | _rest], _acc),
    do: {:error, :unrepresentable_character, codepoint}

  defp encode_utf16_unit(codepoint) when codepoint <= 0xFFFF,
    do: <<codepoint::unsigned-big-16>>

  defp encode_utf16_unit(codepoint) do
    value = codepoint - 0x10000
    high = 0xD800 + (value >>> 10)
    low = 0xDC00 + (value &&& 0x3FF)
    <<high::unsigned-big-16, low::unsigned-big-16>>
  end

  defp prepend_list(list, acc), do: :lists.reverse(list, acc)
  defp replace(byte, replacer, acc), do: :lists.reverse(replacer.(byte), acc)
end

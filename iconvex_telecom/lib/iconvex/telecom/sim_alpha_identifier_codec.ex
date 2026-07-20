defmodule Iconvex.Telecom.SIMAlphaIdentifierCodec do
  @moduledoc """
  Iconvex codec wrapper for 3GPP TS 11.11/31.101 alpha identifiers.

  Stream decoder state counts consumed record octets but excludes the returned
  pending binary; their combined size never exceeds the 255-octet UICC record
  limit. Target state retains at most 255 UCS2 code points. Exact admission
  re-encodes only that bounded candidate so automatic GSM/`0x81`/`0x82`/`0x80`
  mode changes cannot make a size check stale.
  """

  use Iconvex.Telecom.SubstitutionCodec

  alias Iconvex.Telecom.{GSM0338, SIMAlphaIdentifier}

  @escape 0x1B
  @max_bytes 255
  @decoder_tag :sim_alpha_identifier

  @doc "Maximum size, in octets, of one complete SIM/UICC alpha-identifier record."
  def max_bytes, do: @max_bytes

  @impl true
  def canonical_name, do: "SIM-ALPHA-IDENTIFIER"

  @impl true
  def aliases,
    do: ["SIM-ALPHA", "USIM-ALPHA", "USIM-ALPHA-IDENTIFIER", "SIM-UCS2-80-81-82"]

  @impl true
  def stateful?, do: true

  @impl true
  def decode(input) when is_binary(input) do
    case normalized_decode(input) do
      {:ok, utf8} -> {:ok, String.to_charlist(utf8)}
      {:error, _kind, _offset, _sequence} = error -> error
    end
  end

  @impl true
  def decode_discard(input) when is_binary(input) do
    decode_discard_loop(input, stream_decoder_init(), [])
  end

  @impl true
  def decode_error_consumption(_kind, sequence) when is_binary(sequence),
    do: max(byte_size(sequence), 1)

  @impl true
  def stream_decoder_init, do: {@decoder_tag, 0, :start}

  @impl true
  def decode_chunk(input, {@decoder_tag, total, inner_state}, final?)
      when is_binary(input) and is_integer(total) and total in 0..@max_bytes and
             is_boolean(final?) do
    decode_bounded_chunk(input, total, inner_state, final?)
  end

  @impl true
  def decode_recovery_state(
        {@decoder_tag, total, inner_state},
        kind,
        sequence,
        consumed
      )
      when is_integer(total) and total in 0..@max_bytes and is_binary(consumed) do
    admitted_size = min(byte_size(consumed), @max_bytes - total)
    admitted = binary_part(consumed, 0, admitted_size)
    next_total = total + admitted_size

    next_inner_state =
      inner_state
      |> advance_recovery_state(kind, sequence, admitted)
      |> close_compressed_at_record_end(next_total)

    {@decoder_tag, next_total, next_inner_state}
  end

  @impl true
  def stream_encoder_init, do: []

  @impl true
  def encode_chunk(codepoints, state, final?, policy)
      when is_list(codepoints) and is_list(state) and is_boolean(final?) do
    case buffer_codepoints(codepoints, state, policy) do
      {:ok, buffered} ->
        if final? do
          case encode_buffered(buffered) do
            {:ok, output} -> {:ok, output, [], []}
            error -> error
          end
        else
          {:ok, <<>>, buffered, []}
        end

      error ->
        error
    end
  end

  @impl true
  def encode(codepoints) when is_list(codepoints) do
    codepoints
    |> Enum.take(@max_bytes + 1)
    |> encode_strict_window()
  end

  @impl true
  def encode_discard(codepoints) when is_list(codepoints) do
    with {:ok, buffered} <- buffer_codepoints(codepoints, [], :discard) do
      encode_buffered(buffered)
    end
  end

  defp buffer_codepoints([], state, _policy), do: {:ok, state}

  defp buffer_codepoints(_codepoints, state, :discard) when length(state) >= @max_bytes,
    do: {:ok, state}

  defp buffer_codepoints([codepoint | rest], state, :error) do
    if scalar_ucs2?(codepoint) do
      case admit_codepoint(codepoint, state) do
        {:ok, next_state} -> buffer_codepoints(rest, next_state, :error)
        :full -> {:error, :unrepresentable_character, codepoint}
        error -> error
      end
    else
      {:error, :unrepresentable_character, codepoint}
    end
  end

  defp buffer_codepoints([codepoint | rest], state, :discard) do
    if scalar_ucs2?(codepoint) do
      case admit_codepoint(codepoint, state) do
        {:ok, next_state} -> buffer_codepoints(rest, next_state, :discard)
        :full -> buffer_codepoints(rest, state, :discard)
        error -> error
      end
    else
      buffer_codepoints(rest, state, :discard)
    end
  end

  defp buffer_codepoints([codepoint | rest], state, {:replace, replacer} = policy)
       when is_function(replacer, 1) do
    if scalar_ucs2?(codepoint) do
      case admit_codepoint(codepoint, state) do
        {:ok, next_state} -> buffer_codepoints(rest, next_state, policy)
        :full -> {:error, :unrepresentable_character, codepoint}
        error -> error
      end
    else
      with {:ok, next_state} <- buffer_codepoints(replacer.(codepoint), state, :error) do
        buffer_codepoints(rest, next_state, policy)
      end
    end
  end

  defp admit_codepoint(_codepoint, state) when length(state) >= @max_bytes, do: :full

  defp admit_codepoint(codepoint, state) do
    candidate = [codepoint | state]

    case candidate |> :lists.reverse() |> List.to_string() |> SIMAlphaIdentifier.encode() do
      {:ok, _encoded} ->
        {:ok, candidate}

      {:error, {:alpha_identifier_too_long, _size}} ->
        :full

      {:error, {:not_representable_in_ucs2, failed}} ->
        {:error, :unrepresentable_character, failed}

      {:error, :unrepresentable_character, failed} ->
        {:error, :unrepresentable_character, failed}
    end
  end

  defp encode_buffered(state) do
    case state |> :lists.reverse() |> List.to_string() |> SIMAlphaIdentifier.encode() do
      {:ok, _output} = success ->
        success

      {:error, {:alpha_identifier_too_long, _size}} ->
        {:error, :unrepresentable_character, hd(state)}

      {:error, {:not_representable_in_ucs2, codepoint}} ->
        {:error, :unrepresentable_character, codepoint}

      {:error, :unrepresentable_character, codepoint} ->
        {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_strict_window(codepoints) do
    case Enum.find_index(codepoints, &(not scalar_ucs2?(&1))) do
      nil ->
        encode_valid_window(codepoints)

      invalid_index ->
        valid_prefix = Enum.take(codepoints, invalid_index)

        case raw_encode(valid_prefix) do
          {:ok, _output} ->
            {:error, :unrepresentable_character, Enum.at(codepoints, invalid_index)}

          {:error, {:alpha_identifier_too_long, _size}} ->
            capacity_error(valid_prefix)
        end
    end
  end

  defp encode_valid_window(codepoints) do
    if length(codepoints) > @max_bytes do
      bounded_prefix = Enum.take(codepoints, @max_bytes)

      case raw_encode(bounded_prefix) do
        {:ok, _output} ->
          {:error, :unrepresentable_character, Enum.at(codepoints, @max_bytes)}

        {:error, {:alpha_identifier_too_long, _size}} ->
          capacity_error(bounded_prefix)
      end
    else
      encode_bounded_window(codepoints)
    end
  end

  defp encode_bounded_window(codepoints) do
    case raw_encode(codepoints) do
      {:ok, _output} = success -> success
      {:error, {:alpha_identifier_too_long, _size}} -> capacity_error(codepoints)
    end
  end

  defp capacity_error(codepoints) do
    full_index = first_full_prefix(codepoints, 1, length(codepoints))
    {:error, :unrepresentable_character, Enum.at(codepoints, full_index - 1)}
  end

  defp first_full_prefix(_codepoints, low, high) when low == high, do: low

  defp first_full_prefix(codepoints, low, high) do
    middle = div(low + high, 2)

    case codepoints |> Enum.take(middle) |> raw_encode() do
      {:ok, _output} -> first_full_prefix(codepoints, middle + 1, high)
      {:error, {:alpha_identifier_too_long, _size}} -> first_full_prefix(codepoints, low, middle)
    end
  end

  defp raw_encode(codepoints),
    do: codepoints |> List.to_string() |> SIMAlphaIdentifier.encode()

  @impl true
  def decode_to_utf8(input) when is_binary(input), do: normalized_decode(input)

  defp normalized_decode(input) do
    case SIMAlphaIdentifier.decode(input) do
      {:ok, _utf8} = result ->
        result

      {:error, kind, offset, sequence} ->
        {:error, kind, offset, sequence}

      {:error, {:alpha_identifier_too_long, _size} = reason} ->
        normalize_decode_error(input, reason)

      {:error, reason} ->
        normalize_decode_error(bounded_record(input), reason)
    end
  end

  defp bounded_record(input) when byte_size(input) <= @max_bytes, do: input
  defp bounded_record(input), do: binary_part(input, 0, @max_bytes)

  @impl true
  def encode_from_utf8(input) when is_binary(input) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        case encode(codepoints) do
          {:error, :unrepresentable_character, codepoint} ->
            {:encode_error, :unrepresentable_character, codepoint}

          result ->
            result
        end

      {:incomplete, _converted, rest} ->
        {:decode_error, :incomplete_sequence, byte_size(input) - byte_size(rest), rest}

      {:error, _converted, rest} ->
        {:decode_error, :invalid_sequence, byte_size(input) - byte_size(rest), rest}
    end
  end

  defp scalar_ucs2?(codepoint),
    do: is_integer(codepoint) and codepoint in 0..0xFFFF and codepoint not in 0xD800..0xDFFF

  defp decode_bounded_chunk(input, total, inner_state, final?) do
    available = @max_bytes - total

    if byte_size(input) <= available do
      input
      |> decode_chunk_state(inner_state, final?)
      |> wrap_decoder_state(total, input)
    else
      <<record_input::binary-size(available), overflow::binary>> = input

      case decode_chunk_state(record_input, inner_state, true) do
        {:ok, _codepoints, _next_inner_state, _pending} ->
          {:error, :invalid_sequence, available, binary_part(overflow, 0, 1)}

        earlier_error ->
          earlier_error
      end
    end
  end

  defp wrap_decoder_state(
         {:ok, codepoints, next_inner_state, pending},
         total,
         input
       ) do
    consumed = byte_size(input) - byte_size(pending)
    {:ok, codepoints, {@decoder_tag, total + consumed, next_inner_state}, pending}
  end

  defp wrap_decoder_state(error, _total, _input), do: error

  defp advance_recovery_state(
         {:compressed, remaining, base},
         _kind,
         _sequence,
         consumed
       )
       when is_integer(remaining) and remaining > 0 do
    case max(remaining - byte_size(consumed), 0) do
      0 -> :padding
      next_remaining -> {:compressed, next_remaining, base}
    end
  end

  # Once a physical octet has been consumed as an invalid default-alphabet
  # unit, the record has selected GSM mode. Leaving the state at :start would
  # let a later 0x80/0x81/0x82 byte be reinterpreted as a framing header.
  defp advance_recovery_state(:start, :invalid_sequence, _sequence, consumed)
       when byte_size(consumed) > 0,
       do: :gsm

  defp advance_recovery_state(state, _kind, _sequence, _consumed), do: state

  defp close_compressed_at_record_end({:compressed, _remaining, _base}, @max_bytes),
    do: :padding

  defp close_compressed_at_record_end(state, _total), do: state

  defp decode_chunk_state(<<>>, :start, _final?), do: {:ok, [], :start, <<>>}

  defp decode_chunk_state(<<0x80, rest::binary>>, :start, final?),
    do: decode_ucs2_units(rest, final?, 1, [])

  defp decode_chunk_state(<<0x81, length, base, rest::binary>>, :start, final?),
    do: decode_compressed_units(rest, length, base * 128, final?, 3, [])

  defp decode_chunk_state(<<0x82, length, base::16-big, rest::binary>>, :start, final?),
    do: decode_compressed_units(rest, length, base, final?, 4, [])

  defp decode_chunk_state(<<prefix, _rest::binary>> = input, :start, final?)
       when prefix in [0x81, 0x82] do
    if final?,
      do: {:error, :incomplete_sequence, 0, input},
      else: {:ok, [], :start, input}
  end

  defp decode_chunk_state(input, :start, final?),
    do: decode_gsm_units(input, final?, 0, [])

  defp decode_chunk_state(input, :ucs2, final?),
    do: decode_ucs2_units(input, final?, 0, [])

  defp decode_chunk_state(input, :gsm, final?),
    do: decode_gsm_units(input, final?, 0, [])

  defp decode_chunk_state(input, {:compressed, remaining, base}, final?),
    do: decode_compressed_units(input, remaining, base, final?, 0, [])

  defp decode_chunk_state(_input, :padding, _final?), do: {:ok, [], :padding, <<>>}

  defp decode_ucs2_units(<<>>, _final?, _offset, acc),
    do: decoded(acc, :ucs2, <<>>)

  defp decode_ucs2_units(<<codepoint::16-big, _rest::binary>>, _final?, offset, _acc)
       when codepoint in 0xD800..0xDFFF,
       do: {:error, :invalid_sequence, offset, <<codepoint::16-big>>}

  defp decode_ucs2_units(<<codepoint::16-big, rest::binary>>, final?, offset, acc),
    do: decode_ucs2_units(rest, final?, offset + 2, [codepoint | acc])

  defp decode_ucs2_units(<<0xFF>>, true, _offset, acc),
    do: decoded(acc, :ucs2, <<>>)

  defp decode_ucs2_units(<<byte>>, true, offset, _acc),
    do: {:error, :incomplete_sequence, offset, <<byte>>}

  defp decode_ucs2_units(<<byte>>, false, _offset, acc),
    do: decoded(acc, :ucs2, <<byte>>)

  defp decode_gsm_units(<<>>, _final?, _offset, acc),
    do: decoded(acc, :gsm, <<>>)

  defp decode_gsm_units(<<@escape>>, false, _offset, acc),
    do: decoded(acc, :gsm, <<@escape>>)

  defp decode_gsm_units(<<@escape>>, true, _offset, acc),
    do: decoded([0x20 | acc], :gsm, <<>>)

  defp decode_gsm_units(<<0xFF, rest::binary>> = padding, final?, offset, acc) do
    if all_ff?(rest) do
      if final?, do: decoded(acc, :gsm, <<>>), else: decoded(acc, :gsm, padding)
    else
      {:error, :invalid_sequence, offset, <<0xFF>>}
    end
  end

  defp decode_gsm_units(<<@escape, byte, rest::binary>>, final?, offset, acc) do
    case GSM0338.decode(<<@escape, byte>>) do
      {:ok, codepoints} ->
        decode_gsm_units(rest, final?, offset + 2, prepend(codepoints, acc))

      {:error, kind, local_offset, sequence} ->
        {:error, kind, offset + local_offset, sequence}
    end
  end

  defp decode_gsm_units(<<byte, rest::binary>>, final?, offset, acc) do
    case GSM0338.decode(<<byte>>) do
      {:ok, codepoints} ->
        decode_gsm_units(rest, final?, offset + 1, prepend(codepoints, acc))

      {:error, kind, local_offset, sequence} ->
        {:error, kind, offset + local_offset, sequence}
    end
  end

  defp decode_compressed_units(_input, 0, _base, _final?, _offset, acc),
    do: decoded(acc, :padding, <<>>)

  defp decode_compressed_units(<<>>, remaining, base, false, _offset, acc),
    do: decoded(acc, {:compressed, remaining, base}, <<>>)

  defp decode_compressed_units(<<>>, _remaining, _base, true, offset, _acc),
    do: {:error, :incomplete_sequence, offset, <<>>}

  defp decode_compressed_units(
         <<@escape>>,
         remaining,
         _base,
         true,
         offset,
         _acc
       )
       when remaining > 1,
       do: {:error, :incomplete_sequence, offset, <<@escape>>}

  defp decode_compressed_units(
         <<@escape>>,
         remaining,
         base,
         false,
         _offset,
         acc
       )
       when remaining > 1,
       do: decoded(acc, {:compressed, remaining, base}, <<@escape>>)

  defp decode_compressed_units(
         <<@escape, extension, rest::binary>>,
         remaining,
         base,
         final?,
         offset,
         acc
       )
       when remaining > 1 and extension < 0x80 do
    {:ok, codepoints} = GSM0338.decode(<<@escape, extension>>)

    decode_compressed_units(
      rest,
      remaining - 2,
      base,
      final?,
      offset + 2,
      prepend(codepoints, acc)
    )
  end

  defp decode_compressed_units(<<byte, rest::binary>>, remaining, base, final?, offset, acc)
       when byte >= 0x80 do
    codepoint = base + rem(byte, 0x80)

    if scalar_ucs2?(codepoint) do
      decode_compressed_units(
        rest,
        remaining - 1,
        base,
        final?,
        offset + 1,
        [codepoint | acc]
      )
    else
      {:error, :invalid_sequence, offset, <<byte>>}
    end
  end

  defp decode_compressed_units(<<byte, rest::binary>>, remaining, base, final?, offset, acc) do
    {:ok, codepoints} = GSM0338.decode(<<byte>>)

    decode_compressed_units(
      rest,
      remaining - 1,
      base,
      final?,
      offset + 1,
      prepend(codepoints, acc)
    )
  end

  defp decode_discard_loop(input, state, acc) do
    case decode_chunk(input, state, true) do
      {:ok, codepoints, _next_state, _pending} ->
        {:ok, finish_decoded(acc, codepoints)}

      {:error, kind, offset, sequence}
      when kind in [:invalid_sequence, :incomplete_sequence] and offset >= 0 and
             offset <= byte_size(input) ->
        prefix = binary_part(input, 0, offset)
        remaining = binary_part(input, offset, byte_size(input) - offset)
        consumption = decode_error_consumption(kind, sequence)

        with {:ok, prefix_codepoints, prefix_state, <<>>} <-
               decode_recovery_prefix(prefix, state) do
          if byte_size(remaining) >= consumption do
            <<consumed::binary-size(consumption), rest::binary>> = remaining
            next_state = decode_recovery_state(prefix_state, kind, sequence, consumed)

            decode_discard_loop(rest, next_state, [prefix_codepoints | acc])
          else
            {:ok, finish_decoded(acc, prefix_codepoints)}
          end
        else
          _unstable_prefix -> {:ok, finish_decoded(acc, [])}
        end
    end
  end

  defp decode_recovery_prefix(prefix, state) do
    case decode_chunk(prefix, state, false) do
      {:ok, codepoints, next_state, <<>>} -> {:ok, codepoints, next_state, <<>>}
      _pending_or_error -> decode_chunk(prefix, state, true)
    end
  end

  defp decoded(acc, state, pending),
    do: {:ok, :lists.reverse(acc), state, pending}

  defp prepend(codepoints, acc), do: Enum.reduce(codepoints, acc, &[&1 | &2])

  defp all_ff?(<<>>), do: true
  defp all_ff?(<<0xFF, rest::binary>>), do: all_ff?(rest)
  defp all_ff?(_other), do: false

  defp finish_decoded([], codepoints), do: codepoints

  defp finish_decoded(acc, codepoints),
    do: acc |> :lists.reverse([codepoints]) |> List.flatten()

  defp decode_error_kind(reason)
       when reason in [:truncated_alpha_identifier, :truncated_ucs2],
       do: :incomplete_sequence

  defp decode_error_kind(_reason), do: :invalid_sequence

  defp normalize_decode_error(input, {:invalid_ucs2, codepoint} = reason) do
    case invalid_ucs2_location(input, codepoint) do
      {offset, sequence} -> {:error, decode_error_kind(reason), offset, sequence}
      nil -> {:error, decode_error_kind(reason), 0, input}
    end
  end

  defp normalize_decode_error(<<0x80, data::binary>> = input, :truncated_ucs2 = reason) do
    offset = max(byte_size(input) - 1, 0)
    sequence = if data == <<>>, do: input, else: binary_part(input, offset, 1)
    {:error, decode_error_kind(reason), offset, sequence}
  end

  defp normalize_decode_error(
         <<0x81, length, _base, payload::binary>> = input,
         :truncated_alpha_identifier = reason
       )
       when byte_size(payload) < length do
    truncated_compressed_error(input, payload, reason)
  end

  defp normalize_decode_error(
         <<0x82, length, _base::16-big, payload::binary>> = input,
         :truncated_alpha_identifier = reason
       )
       when byte_size(payload) < length do
    truncated_compressed_error(input, payload, reason)
  end

  defp normalize_decode_error(input, {:alpha_identifier_too_long, _size})
       when byte_size(input) > @max_bytes,
       do: {:error, :invalid_sequence, @max_bytes, binary_part(input, @max_bytes, 1)}

  defp normalize_decode_error(input, reason),
    do: {:error, decode_error_kind(reason), 0, input}

  defp invalid_ucs2_location(<<0x80, data::binary>>, codepoint),
    do: find_ucs2_codepoint(data, codepoint, 1)

  defp invalid_ucs2_location(<<0x81, length, base, rest::binary>>, codepoint),
    do: find_compressed_codepoint(rest, length, base * 128, codepoint, 3)

  defp invalid_ucs2_location(<<0x82, length, base::16-big, rest::binary>>, codepoint),
    do: find_compressed_codepoint(rest, length, base, codepoint, 4)

  defp invalid_ucs2_location(_input, _codepoint), do: nil

  defp find_ucs2_codepoint(<<codepoint::16-big, _rest::binary>>, codepoint, offset),
    do: {offset, <<codepoint::16-big>>}

  defp find_ucs2_codepoint(<<_codepoint::16, rest::binary>>, target, offset),
    do: find_ucs2_codepoint(rest, target, offset + 2)

  defp find_ucs2_codepoint(_data, _target, _offset), do: nil

  defp find_compressed_codepoint(rest, length, base, target, header_size) do
    payload_size = min(length, byte_size(rest))
    <<payload::binary-size(payload_size), _padding::binary>> = rest
    find_compressed_codepoint_byte(payload, base, target, header_size)
  end

  defp find_compressed_codepoint_byte(<<byte, rest::binary>>, base, target, offset)
       when byte >= 0x80 do
    if base + rem(byte, 0x80) == target,
      do: {offset, <<byte>>},
      else: find_compressed_codepoint_byte(rest, base, target, offset + 1)
  end

  defp find_compressed_codepoint_byte(<<_byte, rest::binary>>, base, target, offset),
    do: find_compressed_codepoint_byte(rest, base, target, offset + 1)

  defp find_compressed_codepoint_byte(<<>>, _base, _target, _offset), do: nil

  defp truncated_compressed_error(input, payload, reason) do
    if payload != <<>> and :binary.last(payload) == @escape do
      {:error, decode_error_kind(reason), byte_size(input) - 1, <<@escape>>}
    else
      {:error, decode_error_kind(reason), byte_size(input), <<>>}
    end
  end
end

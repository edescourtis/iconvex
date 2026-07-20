defmodule Iconvex.Stream do
  @moduledoc false

  alias Iconvex.{
    Converter,
    Error,
    EscapeCodec,
    ExternalCallbacks,
    StatefulCodec,
    TableCodec,
    Tables,
    TargetArbitrator,
    UnicodeCodec
  }

  defstruct [
    :from_entry,
    :to_entry,
    :options,
    :provider_snapshot,
    :source_state,
    :target_state,
    source_pending: <<>>,
    source_offset: 0,
    target_pending: [],
    target_started?: false
  ]

  @doc false
  def __decode_complete_with_callback__(%{kind: :stateful} = entry, target, input, options)
      when is_binary(input) and is_list(options),
      do: decode_complete_with_callback(entry, target, input, options)

  def __decode_complete_with_callback__(
        %{kind: :external, stateful?: true} = entry,
        target,
        input,
        options
      )
      when is_binary(input) and is_list(options),
      do: decode_complete_with_callback(entry, target, input, options)

  defp decode_complete_with_callback(entry, target, input, options)
       when is_binary(input) and is_list(options) do
    with {:ok, source_state} <- init_source(entry) do
      case decode_with_policy(
             entry,
             input,
             source_state,
             true,
             options,
             0,
             [],
             {target, TargetArbitrator.init()},
             []
           ) do
        {:ok, codepoints, _source_state, <<>>} -> {:ok, codepoints}
        error -> error
      end
    end
  end

  def build(enumerable, %Converter{} = converter) do
    with :ok <- validate_enumerable(enumerable),
         {:ok, source_state} <- init_source(converter.from_entry),
         {:ok, target_state} <- init_target(converter.to_entry) do
      state = %__MODULE__{
        from_entry: converter.from_entry,
        to_entry: converter.to_entry,
        options: converter.options,
        provider_snapshot: converter.provider_snapshot,
        source_state: source_state,
        target_state: target_state
      }

      stream =
        Elixir.Stream.transform(
          enumerable,
          fn -> state end,
          &transform_chunk/2,
          &finish_stream/1,
          fn _state -> :ok end
        )

      {:ok, stream}
    end
  end

  defp validate_enumerable(enumerable) do
    if Enumerable.impl_for(enumerable),
      do: :ok,
      else: {:error, {:invalid_argument, :enumerable}}
  end

  defp init_source(%{kind: :stateful} = entry),
    do: {:ok, StatefulCodec.stream_init(entry)}

  defp init_source(%{kind: :unicode, id: id} = entry)
       when id in [:ucs2, :utf16, :ucs4, :utf32],
       do: {:ok, UnicodeCodec.stream_init(entry)}

  defp init_source(%{
         kind: :external,
         decode_error_recovery: :stop,
         canonical: name
       }),
       do: {:error, {:streaming_unsupported, :source, name}}

  defp init_source(%{kind: :external, stateful?: false, codec: codec, canonical: name}) do
    if function_exported?(codec, :decode_chunk, 2),
      do: {:ok, nil},
      else: {:error, {:streaming_unsupported, :source, name}}
  end

  defp init_source(%{kind: :external, stateful?: true, codec: codec, canonical: name}) do
    if function_exported?(codec, :stream_decoder_init, 0) and
         function_exported?(codec, :decode_chunk, 3),
       do: init_external_state(codec, :stream_decoder_init, :source, name),
       else: {:error, {:streaming_unsupported, :source, name}}
  end

  defp init_source(_entry), do: {:ok, nil}

  defp init_target(%{kind: :stateful} = entry),
    do: {:ok, StatefulCodec.stream_encode_init(entry)}

  defp init_target(%{kind: :external, stateful?: false, codec: codec, canonical: name}) do
    if function_exported?(codec, :encode_chunk, 3),
      do: {:ok, nil},
      else: {:error, {:streaming_unsupported, :target, name}}
  end

  defp init_target(%{kind: :external, stateful?: true, codec: codec, canonical: name}) do
    if function_exported?(codec, :stream_encoder_init, 0) and
         function_exported?(codec, :encode_chunk, 4),
       do: init_external_state(codec, :stream_encoder_init, :target, name),
       else: {:error, {:streaming_unsupported, :target, name}}
  end

  defp init_target(_entry), do: {:ok, nil}

  defp init_external_state(codec, callback, direction, name) do
    case ExternalCallbacks.call(codec, callback, []) do
      {:called, state} -> {:ok, state}
      :missing -> {:error, {:streaming_unsupported, direction, name}}
    end
  end

  defp transform_chunk(chunk, state) when is_binary(chunk) do
    Tables.with_provider_snapshot(state.provider_snapshot, fn ->
      transform_chunk_with_provider(chunk, state)
    end)
  end

  defp transform_chunk(_chunk, _state),
    do: raise(ArgumentError, "stream input enumerable must emit binaries")

  defp transform_chunk_with_provider(chunk, state) do
    chunk = Iconvex.__stream_source_input__(state.from_entry, chunk, state.options)
    input = state.source_pending <> chunk

    with {:ok, codepoints, source_state, source_pending} <-
           decode_with_policy(
             state.from_entry,
             input,
             state.source_state,
             false,
             state.options,
             state.source_offset,
             [],
             target_arbitrator(state),
             []
           ),
         prepared <-
           Iconvex.__stream_prepare_target__(
             state.from_entry,
             state.to_entry,
             codepoints,
             state.options
           ),
         {:ok, output, target_state, target_pending} <-
           encode_chunk(
             state.to_entry,
             state.target_pending ++ prepared,
             state.target_state,
             false,
             state.options
           ) do
      consumed = byte_size(input) - byte_size(source_pending)

      {output, target_started?} =
        suppress_repeated_bom(state.to_entry, output, state.target_started?)

      next = %{
        state
        | source_pending: source_pending,
          source_offset: state.source_offset + consumed,
          source_state: source_state,
          target_pending: target_pending,
          target_state: target_state,
          target_started?: target_started?
      }

      {emit(output), next}
    else
      error ->
        raise_stream_error(error, state)
    end
  end

  defp finish_stream(state) do
    Tables.with_provider_snapshot(state.provider_snapshot, fn ->
      finish_stream_with_provider(state)
    end)
  end

  defp finish_stream_with_provider(state) do
    with {:ok, codepoints, source_state, <<>>} <-
           decode_with_policy(
             state.from_entry,
             state.source_pending,
             state.source_state,
             true,
             state.options,
             state.source_offset,
             [],
             target_arbitrator(state),
             []
           ),
         prepared <-
           Iconvex.__stream_prepare_target__(
             state.from_entry,
             state.to_entry,
             codepoints,
             state.options
           ),
         {:ok, output, target_state, []} <-
           encode_chunk(
             state.to_entry,
             state.target_pending ++ prepared,
             state.target_state,
             true,
             state.options
           ) do
      {output, target_started?} =
        suppress_repeated_bom(state.to_entry, output, state.target_started?)

      {emit(output),
       %{
         state
         | source_pending: <<>>,
           source_state: source_state,
           target_pending: [],
           target_state: target_state,
           target_started?: target_started?
       }}
    else
      error ->
        raise_stream_error(error, state)
    end
  end

  defp emit(<<>>), do: []
  defp emit(output), do: [output]

  defp target_arbitrator(state) do
    {state.to_entry,
     TargetArbitrator.from_stream(
       state.to_entry,
       state.target_state,
       state.target_pending
     )}
  end

  defp decode_with_policy(
         entry,
         input,
         source_state,
         final?,
         options,
         base_offset,
         acc,
         target_probe,
         deferred_codepoints
       ) do
    case decode_chunk(entry, input, source_state, final?, base_offset) do
      # UTF-7 owns open-shift bytes in its decoder state instead of returning a
      # growing generic pending binary. A later malformed close supplies one
      # tagged replay payload; reset the decoder and apply the normal strict or
      # recovery policy once from the unchanged absolute shift offset.
      {:replay_utf7_source, replay_offset, replay_input}
      when entry.kind == :stateful and entry.id == :utf7 and is_integer(replay_offset) and
             replay_offset >= 0 and is_binary(replay_input) ->
        decode_with_policy(
          entry,
          replay_input,
          StatefulCodec.stream_init(entry),
          final?,
          options,
          replay_offset,
          acc,
          target_probe,
          deferred_codepoints
        )

      {:ok, codepoints, next_source_state, pending} ->
        {:ok, finish_decoded(acc, codepoints), next_source_state, pending}

      {:error, kind, offset, sequence}
      when kind in [:invalid_sequence, :incomplete_sequence] and is_integer(offset) and
             is_binary(sequence) ->
        local_offset = local_error_offset(entry, base_offset, offset)

        if local_offset >= 0 and local_offset <= byte_size(input) do
          prefix = binary_part(input, 0, local_offset)

          with {:ok, prefix_codepoints, prefix_state, <<>>} <-
                 decode_recovery_prefix(
                   entry,
                   input,
                   prefix,
                   local_offset,
                   source_state,
                   base_offset
                 ) do
            remaining =
              binary_part(input, local_offset, byte_size(input) - local_offset)

            consumption = Iconvex.__decode_error_consumption__(entry, kind, sequence)

            cond do
              is_integer(consumption) and consumption > 0 and
                  byte_size(remaining) >= consumption ->
                <<consumed::binary-size(consumption), rest::binary>> = remaining
                absolute_offset = base_offset + local_offset

                with {:ok, target_probe} <-
                       arbitrate_target(
                         target_probe,
                         entry,
                         deferred_codepoints ++ prefix_codepoints,
                         options
                       ),
                     {:ok, replacement} <-
                       Iconvex.__stream_invalid_bytes__(
                         entry,
                         kind,
                         absolute_offset,
                         sequence,
                         consumed,
                         options
                       ) do
                  next_source_state =
                    decode_recovery_state(
                      entry,
                      prefix_state,
                      kind,
                      sequence,
                      consumed
                    )

                  decode_with_policy(
                    entry,
                    rest,
                    next_source_state,
                    final?,
                    options,
                    absolute_offset + consumption,
                    [replacement, prefix_codepoints | acc],
                    target_probe,
                    replacement
                  )
                end

              not final? and is_integer(consumption) and consumption > 0 ->
                {:ok, finish_decoded(acc, prefix_codepoints), prefix_state, remaining}

              final? and kind == :incomplete_sequence and sequence == <<>> and
                remaining == <<>> and options[:invalid] == :discard and
                  is_nil(options[:on_invalid_byte]) ->
                # Counted external frames can reach EOF while still declaring
                # a source unit that has no physical byte to consume. Plain
                # discard retains the already-decoded prefix; substitution and
                # callback policies still surface the structural truncation.
                {:ok, finish_decoded(acc, prefix_codepoints), prefix_state, <<>>}

              true ->
                with {:ok, _target_probe} <-
                       arbitrate_target(
                         target_probe,
                         entry,
                         deferred_codepoints ++ prefix_codepoints,
                         options
                       ) do
                  {:decode_error, kind, absolute_error_offset(entry, base_offset, offset),
                   sequence}
                end
            end
          end
        else
          {:decode_error, kind, absolute_error_offset(entry, base_offset, offset), sequence}
        end

      malformed ->
        malformed
    end
  end

  defp arbitrate_target(nil, _source, _codepoints, _options), do: {:ok, nil}

  defp arbitrate_target({target, target_probe}, source, codepoints, options) do
    case TargetArbitrator.probe(target_probe, source, target, codepoints, options) do
      {:ok, next_target_probe} -> {:ok, {target, next_target_probe}}
      error -> error
    end
  end

  # A source error makes the bytes before its offset a stable prefix, but it
  # does not make that prefix the end of the stream. Prefer a non-final decode
  # so stateful codecs carry their live state into recovery. Escape codecs can
  # still need final boundary semantics to turn a syntactic introducer into a
  # literal before a following malformed byte, so retain the final fallback
  # only when the non-final decoder reports pending bytes.
  defp decode_recovery_prefix(
         %{kind: :stateful, id: :utf7} = entry,
         _input,
         prefix,
         _local_offset,
         source_state,
         base_offset
       ) do
    # A following non-Base64 byte proves that a syntactically complete open
    # UTF-7 shift ends at this boundary. Finalize that shift before emitting
    # the malformed direct byte's recovery output; otherwise its buffered
    # code points would be committed only after the replacement.
    case decode_chunk(entry, prefix, source_state, true, base_offset) do
      {:ok, _codepoints, _next_source_state, <<>>} = result ->
        result

      _not_a_complete_shift ->
        decode_chunk(entry, prefix, source_state, false, base_offset)
    end
  end

  defp decode_recovery_prefix(
         %{kind: :escape} = entry,
         input,
         _prefix,
         local_offset,
         source_state,
         _base_offset
       ) do
    case EscapeCodec.decode_prefix(entry, input, local_offset) do
      {:ok, codepoints} -> {:ok, codepoints, source_state, <<>>}
      error -> error
    end
  end

  defp decode_recovery_prefix(
         entry,
         _input,
         prefix,
         _local_offset,
         source_state,
         base_offset
       ) do
    case decode_chunk(entry, prefix, source_state, false, base_offset) do
      {:ok, codepoints, next_source_state, <<>>} ->
        {:ok, codepoints, next_source_state, <<>>}

      _pending_or_non_incremental_prefix ->
        decode_chunk(entry, prefix, source_state, true, base_offset)
    end
  end

  defp decode_recovery_state(
         %{kind: :external, stateful?: true, codec: codec},
         state,
         kind,
         sequence,
         consumed
       ) do
    case ExternalCallbacks.call(codec, :decode_recovery_state, [state, kind, sequence, consumed]) do
      {:called, next_state} -> next_state
      :missing -> state
    end
  end

  defp decode_recovery_state(_entry, state, _kind, _sequence, _consumed), do: state

  defp finish_decoded([], codepoints), do: codepoints

  defp finish_decoded(acc, codepoints),
    do: acc |> :lists.reverse([codepoints]) |> List.flatten()

  defp decode_chunk(%{kind: :table} = entry, input, state, final?, _base_offset) do
    case TableCodec.decode_chunk(entry, input, final?) do
      {:ok, codepoints, pending} -> {:ok, codepoints, state, pending}
      error -> error
    end
  end

  defp decode_chunk(%{kind: :escape} = entry, input, state, final?, _base_offset) do
    case EscapeCodec.decode_chunk(entry, input, final?) do
      {:ok, codepoints, pending} -> {:ok, codepoints, state, pending}
      error -> error
    end
  end

  defp decode_chunk(
         %{kind: :external, stateful?: false, codec: codec, canonical: name},
         input,
         state,
         final?,
         _base_offset
       ) do
    case ExternalCallbacks.call(codec, :decode_chunk, [input, final?]) do
      {:called, {:ok, codepoints, pending}} -> {:ok, codepoints, state, pending}
      {:called, result} -> result
      :missing -> {:request_error, {:streaming_unsupported, :source, name}}
    end
  end

  defp decode_chunk(
         %{kind: :external, stateful?: true, codec: codec, canonical: name},
         input,
         state,
         final?,
         _base_offset
       ) do
    case ExternalCallbacks.call(codec, :decode_chunk, [input, state, final?]) do
      {:called, result} -> result
      :missing -> {:request_error, {:streaming_unsupported, :source, name}}
    end
  end

  defp decode_chunk(%{kind: :stateful} = entry, input, state, final?, base_offset),
    do: StatefulCodec.decode_chunk(entry, input, state, final?, base_offset)

  defp decode_chunk(
         %{kind: :unicode, id: id} = entry,
         input,
         state,
         final?,
         _base_offset
       )
       when id in [:ucs2, :utf16, :ucs4, :utf32],
       do: UnicodeCodec.decode_chunk(entry, input, state, final?)

  defp decode_chunk(entry, input, state, true, _base_offset) do
    case Iconvex.__stream_decode_strict__(entry, input) do
      {:ok, codepoints} -> {:ok, codepoints, state, <<>>}
      error -> error
    end
  end

  defp decode_chunk(entry, input, state, false, _base_offset) do
    case Iconvex.__stream_decode_strict__(entry, input) do
      {:ok, codepoints} ->
        {:ok, codepoints, state, <<>>}

      {:error, :incomplete_sequence, offset, sequence} = error
      when is_integer(offset) and offset >= 0 and offset <= byte_size(input) and
             is_binary(sequence) ->
        if offset + byte_size(sequence) == byte_size(input) do
          prefix = binary_part(input, 0, offset)
          pending = binary_part(input, offset, byte_size(input) - offset)

          case Iconvex.__stream_decode_strict__(entry, prefix) do
            {:ok, codepoints} -> {:ok, codepoints, state, pending}
            _invalid_prefix -> error
          end
        else
          error
        end

      error ->
        error
    end
  end

  defp encode_chunk(%{kind: :table} = entry, codepoints, state, final?, options) do
    case TableCodec.encode_chunk(
           entry,
           codepoints,
           final?,
           Iconvex.__stream_encode_policy__(options)
         ) do
      {:ok, output, pending} -> {:ok, output, state, pending}
      error -> normalize_encode_error(error)
    end
  end

  defp encode_chunk(
         %{kind: :external, stateful?: false, codec: codec, canonical: name},
         codepoints,
         state,
         final?,
         options
       ) do
    case ExternalCallbacks.call(codec, :encode_chunk, [
           codepoints,
           final?,
           Iconvex.__stream_encode_policy__(options)
         ]) do
      {:called, {:ok, output, pending}} -> {:ok, output, state, pending}
      {:called, result} -> normalize_encode_error(result)
      :missing -> {:request_error, {:streaming_unsupported, :target, name}}
    end
  end

  defp encode_chunk(
         %{kind: :external, stateful?: true, codec: codec, canonical: name},
         codepoints,
         state,
         final?,
         options
       ) do
    case ExternalCallbacks.call(codec, :encode_chunk, [
           codepoints,
           state,
           final?,
           Iconvex.__stream_encode_policy__(options)
         ]) do
      {:called, result} -> normalize_encode_error(result)
      :missing -> {:request_error, {:streaming_unsupported, :target, name}}
    end
  end

  defp encode_chunk(%{kind: :stateful} = entry, codepoints, state, final?, options),
    do:
      normalize_encode_error(
        StatefulCodec.encode_chunk(
          entry,
          codepoints,
          state,
          final?,
          Iconvex.__stream_encode_policy__(options)
        )
      )

  defp encode_chunk(entry, codepoints, state, _final?, options) do
    case Iconvex.__stream_encode_prepared__(entry, codepoints, options) do
      {:ok, output} -> {:ok, output, state, []}
      error -> normalize_encode_error(error)
    end
  end

  defp suppress_repeated_bom(%{id: :utf16}, <<0xFE, 0xFF, rest::binary>>, true),
    do: {rest, true}

  defp suppress_repeated_bom(%{id: :utf32}, <<0, 0, 0xFE, 0xFF, rest::binary>>, true),
    do: {rest, true}

  defp suppress_repeated_bom(_entry, output, started?),
    do: {output, started? or output != <<>>}

  defp local_error_offset(%{kind: :stateful}, base_offset, absolute_offset),
    do: absolute_offset - base_offset

  defp local_error_offset(_entry, _base_offset, relative_offset), do: relative_offset

  defp absolute_error_offset(%{kind: :stateful}, _base_offset, absolute_offset),
    do: absolute_offset

  defp absolute_error_offset(_entry, base_offset, relative_offset),
    do: base_offset + relative_offset

  defp normalize_encode_error({:error, kind, codepoint}),
    do: {:encode_error, kind, codepoint}

  defp normalize_encode_error(result), do: result

  defp raise_stream_error({:error, kind, offset, sequence}, state),
    do: raise_stream_error({:decode_error, kind, offset, sequence}, state)

  defp raise_stream_error({:decode_error, kind, offset, sequence}, state) do
    raise Error,
      kind: kind,
      encoding: state.from_entry.canonical,
      offset: offset,
      sequence: sequence
  end

  defp raise_stream_error({:encode_error, kind, codepoint}, state) do
    raise Error,
      kind: kind,
      encoding: state.to_entry.canonical,
      codepoint: codepoint
  end

  defp raise_stream_error({:request_error, reason}, _state),
    do: raise(ArgumentError, "invalid streaming callback result: #{inspect(reason)}")

  defp raise_stream_error(error, _state),
    do: raise(ArgumentError, "invalid streaming codec result: #{inspect(error)}")
end

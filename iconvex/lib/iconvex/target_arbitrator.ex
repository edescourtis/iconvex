defmodule Iconvex.TargetArbitrator do
  @moduledoc false

  alias Iconvex.{ExternalCallbacks, StatefulCodec, TableCodec}

  def init, do: :uninitialized

  def from_stream(%{kind: :table}, _target_state, target_pending),
    do: {:table, target_pending}

  def from_stream(%{kind: :stateful}, target_state, target_pending),
    do: {:stateful, target_state, target_pending}

  def from_stream(
        %{kind: :external, stateful?: false, codec: codec},
        _target_state,
        target_pending
      ),
      do: {:external_stateless, :stream, codec, target_pending, []}

  def from_stream(
        %{kind: :external, stateful?: true, codec: codec},
        target_state,
        target_pending
      ),
      do: {:external_stateful, :stream, codec, target_state, target_pending, []}

  def from_stream(_target, _target_state, _target_pending), do: :stateless

  def probe(:uninitialized, _source, _target, [], _options), do: {:ok, :uninitialized}

  def probe(:uninitialized, source, target, codepoints, options) do
    target
    |> init_one_shot()
    |> probe(source, target, codepoints, options)
  end

  def probe({:table, []} = probe, _source, _target, [], _options), do: {:ok, probe}

  def probe({:table, pending}, source, target, codepoints, options) do
    prepared = Iconvex.__stream_prepare_target__(source, target, codepoints, options)
    policy = Iconvex.__stream_encode_policy__(options)

    case TableCodec.encode_chunk(target, pending ++ prepared, false, policy) do
      {:ok, _output, next_pending} ->
        case TableCodec.encode_chunk(target, next_pending, true, policy) do
          {:ok, _final_output, []} -> {:ok, {:table, next_pending}}
          error -> normalize_encode_error(error)
        end

      error ->
        normalize_encode_error(error)
    end
  end

  def probe({:stateful, _target_state, []} = probe, _source, _target, [], _options),
    do: {:ok, probe}

  def probe({:stateful, target_state, pending}, source, target, codepoints, options) do
    prepared = Iconvex.__stream_prepare_target__(source, target, codepoints, options)
    policy = Iconvex.__stream_encode_policy__(options)

    case StatefulCodec.encode_chunk(
           target,
           pending ++ prepared,
           target_state,
           false,
           policy
         ) do
      {:ok, _output, next_target_state, next_pending} ->
        case StatefulCodec.encode_chunk(
               target,
               next_pending,
               next_target_state,
               true,
               policy
             ) do
          {:ok, _final_output, _final_target_state, []} ->
            {:ok, {:stateful, next_target_state, next_pending}}

          error ->
            normalize_encode_error(error)
        end

      error ->
        normalize_encode_error(error)
    end
  end

  def probe(
        {:external_stateless, _mode, _codec, [], _segments} = probe,
        _source,
        _target,
        [],
        _options
      ),
      do: {:ok, probe}

  def probe(
        {:external_stateless, mode, codec, pending, segments},
        source,
        target,
        codepoints,
        options
      ) do
    prepared = Iconvex.__stream_prepare_target__(source, target, codepoints, options)
    policy = Iconvex.__stream_encode_policy__(options)
    next_segments = [codepoints | segments]

    case ExternalCallbacks.call(codec, :encode_chunk, [pending ++ prepared, false, policy]) do
      {:called, {:ok, output, next_pending}}
      when is_binary(output) and is_list(next_pending) ->
        validate_external_stateless(
          mode,
          codec,
          next_pending,
          next_segments,
          source,
          target,
          options,
          policy
        )

      {:called, result} ->
        external_result_error(result, codec, {:encode_chunk, 3})

      :missing ->
        external_missing(mode, codec, next_segments, source, target, options)
    end
  end

  def probe(
        {:external_stateful, _mode, _codec, _target_state, [], _segments} = probe,
        _source,
        _target,
        [],
        _options
      ),
      do: {:ok, probe}

  def probe(
        {:external_stateful, mode, codec, target_state, pending, segments},
        source,
        target,
        codepoints,
        options
      ) do
    prepared = Iconvex.__stream_prepare_target__(source, target, codepoints, options)
    policy = Iconvex.__stream_encode_policy__(options)
    next_segments = [codepoints | segments]

    case ExternalCallbacks.call(codec, :encode_chunk, [
           pending ++ prepared,
           target_state,
           false,
           policy
         ]) do
      {:called, {:ok, output, next_target_state, next_pending}}
      when is_binary(output) and is_list(next_pending) ->
        validate_external_stateful(
          mode,
          codec,
          next_target_state,
          next_pending,
          next_segments,
          source,
          target,
          options,
          policy
        )

      {:called, result} ->
        external_result_error(result, codec, {:encode_chunk, 4})

      :missing ->
        external_missing(mode, codec, next_segments, source, target, options)
    end
  end

  # A successful opaque probe already validated the exact accumulated prefix.
  # When recovery contributes no Unicode before the next malformed source unit,
  # probing that unchanged prefix again cannot reveal an earlier target error.
  def probe({:opaque_external, _segments} = probe, _source, _target, [], _options),
    do: {:ok, probe}

  def probe({:opaque_external, segments}, source, target, codepoints, options) do
    probe_opaque([codepoints | segments], source, target, options)
  end

  def probe(:stateless, _source, _target, [], _options), do: {:ok, :stateless}

  def probe(:stateless, source, target, codepoints, options) do
    codepoints = Iconvex.__stream_prepare_target__(source, target, codepoints, options)

    case Iconvex.__stream_encode_prepared__(target, codepoints, options) do
      {:ok, _output} -> {:ok, :stateless}
      error -> error
    end
  end

  defp init_one_shot(%{kind: :table}), do: {:table, []}

  defp init_one_shot(%{kind: :stateful} = target),
    do: {:stateful, StatefulCodec.stream_encode_init(target), []}

  defp init_one_shot(%{kind: :external, stateful?: false, codec: codec}),
    do: {:external_stateless, :one_shot, codec, [], []}

  defp init_one_shot(%{kind: :external, stateful?: true, codec: codec}) do
    case ExternalCallbacks.call(codec, :stream_encoder_init, []) do
      {:called, target_state} ->
        {:external_stateful, :one_shot, codec, target_state, [], []}

      :missing ->
        {:opaque_external, []}
    end
  end

  defp init_one_shot(_target), do: :stateless

  defp validate_external_stateless(
         mode,
         codec,
         next_pending,
         next_segments,
         source,
         target,
         options,
         policy
       ) do
    case ExternalCallbacks.call(codec, :encode_chunk, [next_pending, true, policy]) do
      {:called, {:ok, output, []}} when is_binary(output) ->
        {:ok, {:external_stateless, mode, codec, next_pending, next_segments}}

      {:called, result} ->
        external_result_error(result, codec, {:encode_chunk, 3})

      :missing ->
        external_missing(mode, codec, next_segments, source, target, options)
    end
  end

  defp validate_external_stateful(
         mode,
         codec,
         next_target_state,
         next_pending,
         next_segments,
         source,
         target,
         options,
         policy
       ) do
    case ExternalCallbacks.call(codec, :encode_chunk, [
           next_pending,
           next_target_state,
           true,
           policy
         ]) do
      {:called, {:ok, output, _final_target_state, []}} when is_binary(output) ->
        {:ok, {:external_stateful, mode, codec, next_target_state, next_pending, next_segments}}

      {:called, result} ->
        external_result_error(result, codec, {:encode_chunk, 4})

      :missing ->
        external_missing(mode, codec, next_segments, source, target, options)
    end
  end

  defp external_missing(:one_shot, _codec, segments, source, target, options),
    do: probe_opaque(segments, source, target, options)

  defp external_missing(:stream, _codec, _segments, _source, target, _options),
    do: {:request_error, {:streaming_unsupported, :target, target.canonical}}

  defp probe_opaque(segments, source, target, options) do
    codepoints = segments |> :lists.reverse() |> List.flatten()
    prepared = Iconvex.__stream_prepare_target__(source, target, codepoints, options)

    case Iconvex.__stream_encode_prepared__(target, prepared, options) do
      {:ok, _output} -> {:ok, {:opaque_external, segments}}
      error -> error
    end
  end

  defp external_result_error(
         {:error, :unrepresentable_character, codepoint},
         _codec,
         _callback
       )
       when is_integer(codepoint) and codepoint >= 0,
       do: {:encode_error, :unrepresentable_character, codepoint}

  defp external_result_error(result, codec, callback),
    do: {:request_error, {:invalid_codec_callback_return, codec, callback, result}}

  defp normalize_encode_error({:error, kind, codepoint}),
    do: {:encode_error, kind, codepoint}

  defp normalize_encode_error(error), do: error
end

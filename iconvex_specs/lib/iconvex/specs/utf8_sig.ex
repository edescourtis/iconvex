defmodule Iconvex.Specs.UTF8Sig do
  @moduledoc "Python-compatible UTF-8-SIG: UTF-8 with one leading signature on encode."

  use Iconvex.Codec

  @signature <<0xEF, 0xBB, 0xBF>>
  @utf8 %{id: :utf8}

  @impl true
  def canonical_name, do: "UTF-8-SIG"

  @impl true
  def aliases, do: ["UTF8-SIG", "PYTHON-UTF-8-SIG"]

  @impl true
  def codec_id, do: :utf8_sig

  @impl true
  def stateful?, do: true

  @impl true
  def decode(input) when is_binary(input) do
    {payload, skipped} = payload(input)

    case Iconvex.UnicodeCodec.decode(@utf8, payload) do
      {:error, kind, offset, sequence} ->
        {:error, normalize_kind(kind, sequence), offset + skipped, sequence}

      result ->
        result
    end
  end

  @impl true
  def decode_discard(input) when is_binary(input) do
    {payload, _skipped} = payload(input)
    {:ok, decode_discard_loop(payload, [])}
  end

  @impl true
  def decode_to_utf8(input) when is_binary(input) do
    {payload, skipped} = payload(input)

    case Iconvex.UnicodeCodec.decode(@utf8, payload) do
      {:ok, _codepoints} ->
        {:ok, payload}

      {:error, kind, offset, sequence} ->
        {:error, normalize_kind(kind, sequence), offset + skipped, sequence}
    end
  end

  @impl true
  def encode(codepoints) when is_list(codepoints) do
    case Iconvex.UnicodeCodec.encode(@utf8, codepoints) do
      {:ok, encoded} -> {:ok, @signature <> encoded}
      error -> error
    end
  end

  @impl true
  def encode_discard(codepoints) when is_list(codepoints) do
    {:ok, encoded} = Iconvex.UnicodeCodec.encode_discard(@utf8, codepoints)
    {:ok, @signature <> encoded}
  end

  @impl true
  def encode_substitute(codepoints, replacer),
    do:
      Iconvex.Specs.CodecSupport.encode_substitute_transform(
        codepoints,
        &encode/1,
        replacer
      )

  @impl true
  def encode_from_utf8(input) when is_binary(input) do
    case Iconvex.UnicodeCodec.decode(@utf8, input) do
      {:ok, _codepoints} ->
        {:ok, @signature <> input}

      {:error, kind, offset, sequence} ->
        {:decode_error, normalize_kind(kind, sequence), offset, sequence}
    end
  end

  @impl true
  def stream_decoder_init, do: :initial

  @impl true
  def decode_chunk(input, :initial, final?) when is_binary(input) do
    cond do
      not final? and byte_size(input) < byte_size(@signature) and
          binary_part(@signature, 0, byte_size(input)) == input ->
        {:ok, [], :initial, input}

      byte_size(input) >= byte_size(@signature) and
          binary_part(input, 0, byte_size(@signature)) == @signature ->
        body = binary_part(input, byte_size(@signature), byte_size(input) - byte_size(@signature))
        decode_body(body, :body, final?, byte_size(@signature))

      true ->
        decode_body(input, :body, final?, 0)
    end
  end

  def decode_chunk(input, :body, final?) when is_binary(input),
    do: decode_body(input, :body, final?, 0)

  @impl true
  def stream_encoder_init, do: false

  @impl true
  def encode_chunk(codepoints, started?, final?, policy) when is_list(codepoints) do
    with {:ok, body} <- encode_with_policy(codepoints, policy) do
      emit_signature? = not started? and (body != <<>> or final?)
      prefix = if emit_signature?, do: @signature, else: <<>>
      {:ok, prefix <> body, started? or emit_signature?, []}
    end
  end

  @impl true
  def decode_error_consumption(_kind, sequence), do: max(byte_size(sequence), 1)

  defp payload(<<@signature, rest::binary>>), do: {rest, 3}
  defp payload(input), do: {input, 0}

  defp decode_body(input, state, final?, prefix_size) do
    case Iconvex.UnicodeCodec.decode(@utf8, input) do
      {:ok, codepoints} ->
        {:ok, codepoints, state, <<>>}

      {:error, :incomplete_sequence, offset, _sequence} when not final? ->
        prefix = binary_part(input, 0, offset)

        case Iconvex.UnicodeCodec.decode(@utf8, prefix) do
          {:ok, codepoints} ->
            pending = binary_part(input, offset, byte_size(input) - offset)
            {:ok, codepoints, state, pending}

          {:error, kind, nested_offset, nested_sequence} ->
            {:error, normalize_kind(kind, nested_sequence), prefix_size + nested_offset,
             nested_sequence}
        end

      {:error, kind, offset, sequence} ->
        {:error, normalize_kind(kind, sequence), prefix_size + offset, sequence}
    end
  end

  defp encode_with_policy(codepoints, :error),
    do: Iconvex.UnicodeCodec.encode(@utf8, codepoints)

  defp encode_with_policy(codepoints, :discard),
    do: Iconvex.UnicodeCodec.encode_discard(@utf8, codepoints)

  defp encode_with_policy(codepoints, {:replace, replacer}),
    do: Iconvex.UnicodeCodec.encode_substitute(@utf8, codepoints, replacer)

  defp normalize_kind(:incomplete_sequence, <<first, _rest::binary>>)
       when first not in 0xC2..0xF4,
       do: :invalid_sequence

  defp normalize_kind(kind, _sequence), do: kind

  defp decode_discard_loop(<<>>, acc), do: :lists.reverse(acc)

  defp decode_discard_loop(<<codepoint::utf8, rest::binary>>, acc),
    do: decode_discard_loop(rest, [codepoint | acc])

  defp decode_discard_loop(<<_byte, rest::binary>>, acc),
    do: decode_discard_loop(rest, acc)
end

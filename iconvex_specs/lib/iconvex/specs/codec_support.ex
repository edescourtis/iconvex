defmodule Iconvex.Specs.CodecSupport do
  @moduledoc false

  def decode(id, input), do: Iconvex.TableCodec.decode(entry(id), input)
  def decode_discard(id, input), do: Iconvex.TableCodec.decode_discard(entry(id), input)

  def decode_chunk(id, input, final?),
    do: Iconvex.TableCodec.decode_chunk(entry(id), input, final?)

  def decode_error_consumption(kind, sequence),
    do: Iconvex.TableCodec.decode_error_consumption(kind, sequence)

  def decode_provider(id, input), do: Iconvex.TableCodec.decode(provider_entry(id), input)

  def decode_discard_provider(id, input),
    do: Iconvex.TableCodec.decode_discard(provider_entry(id), input)

  def decode_to_utf8(id, input) do
    case Iconvex.TableCodec.decode_to_utf8(entry(id), input) do
      :miss ->
        case decode(id, input) do
          {:ok, codepoints} -> {:ok, List.to_string(codepoints)}
          error -> error
        end

      result ->
        result
    end
  end

  def decode_to_utf8_provider(id, input) do
    case Iconvex.TableCodec.decode_to_utf8(provider_entry(id), input) do
      :miss ->
        case decode_provider(id, input) do
          {:ok, codepoints} -> {:ok, List.to_string(codepoints)}
          error -> error
        end

      result ->
        result
    end
  end

  def encode(id, codepoints), do: Iconvex.TableCodec.encode(entry(id), codepoints)

  def encode_provider(id, codepoints),
    do: Iconvex.TableCodec.encode(provider_entry(id), codepoints)

  def encode_discard(id, codepoints),
    do: Iconvex.TableCodec.encode_discard(entry(id), codepoints)

  def encode_substitute(id, codepoints, replacer),
    do: Iconvex.TableCodec.encode_substitute(entry(id), codepoints, replacer)

  def encode_chunk(id, codepoints, final?, policy),
    do: Iconvex.TableCodec.encode_chunk(entry(id), codepoints, final?, policy)

  def encode_discard_provider(id, codepoints),
    do: Iconvex.TableCodec.encode_discard(provider_entry(id), codepoints)

  def encode_substitute_provider(id, codepoints, replacer),
    do: Iconvex.TableCodec.encode_substitute(provider_entry(id), codepoints, replacer)

  def encode_substitute_each(codepoints, encoder, replacer)
      when is_list(codepoints) and is_function(encoder, 1) and is_function(replacer, 1),
      do: encode_substitute_each_loop(codepoints, encoder, replacer, [])

  def encode_substitute_transform(codepoints, encoder, replacer)
      when is_list(codepoints) and is_function(encoder, 1) and is_function(replacer, 1) do
    case substitute_codepoints(codepoints, encoder, replacer, []) do
      {:ok, transformed} -> encoder.(:lists.reverse(transformed))
      error -> error
    end
  end

  def encode_from_utf8(id, input) do
    case Iconvex.TableCodec.encode_from_utf8(entry(id), input) do
      :miss -> encode_from_utf8_fallback(id, input, &encode/2)
      result -> result
    end
  end

  def encode_from_utf8_provider(id, input) do
    case Iconvex.TableCodec.encode_from_utf8(provider_entry(id), input) do
      :miss -> encode_from_utf8_fallback(id, input, &encode_provider/2)
      result -> result
    end
  end

  def encode_utf8(input, encoder) when is_binary(input) and is_function(encoder, 1) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        encoder.(codepoints)

      {:incomplete, converted, rest} ->
        first_error_or_utf8_error(converted, rest, input, :incomplete_sequence, encoder)

      {:error, converted, rest} ->
        first_error_or_utf8_error(converted, rest, input, :invalid_sequence, encoder)
    end
  end

  def encode_utf8(input, valid_encoder, prefix_encoder)
      when is_binary(input) and is_function(valid_encoder, 1) and
             is_function(prefix_encoder, 1) do
    if String.valid?(input) do
      valid_encoder.(input)
    else
      case :unicode.characters_to_list(input, :utf8) do
        {:incomplete, converted, rest} ->
          first_error_or_utf8_error(
            converted,
            rest,
            input,
            :incomplete_sequence,
            prefix_encoder
          )

        {:error, converted, rest} ->
          first_error_or_utf8_error(
            converted,
            rest,
            input,
            :invalid_sequence,
            prefix_encoder
          )
      end
    end
  end

  def malformed_utf8(input, offset \\ 0) when is_binary(input) do
    case :unicode.characters_to_list(input, :utf8) do
      {:incomplete, _converted, rest} ->
        {:decode_error, :incomplete_sequence, offset + byte_size(input) - byte_size(rest), rest}

      {:error, _converted, rest} ->
        {:decode_error, :invalid_sequence, offset + byte_size(input) - byte_size(rest), rest}
    end
  end

  defp encode_from_utf8_fallback(id, input, encoder) do
    encode_utf8(input, fn codepoints ->
      case encoder.(id, codepoints) do
        {:error, :unrepresentable_character, codepoint} ->
          {:encode_error, :unrepresentable_character, codepoint}

        result ->
          result
      end
    end)
  end

  defp first_error_or_utf8_error(converted, rest, input, kind, encoder) do
    case encoder.(converted) do
      {:ok, output} when is_binary(output) ->
        {:decode_error, kind, byte_size(input) - byte_size(rest), rest}

      earlier_error ->
        earlier_error
    end
  end

  defp encode_substitute_each_loop([], _encoder, _replacer, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute_each_loop([codepoint | rest], encoder, replacer, acc) do
    case encoder.([codepoint]) do
      {:ok, bytes} ->
        encode_substitute_each_loop(rest, encoder, replacer, [bytes | acc])

      {:error, :unrepresentable_character, ^codepoint} ->
        case encoder.(replacer.(codepoint)) do
          {:ok, replacement} ->
            encode_substitute_each_loop(rest, encoder, replacer, [replacement | acc])

          error ->
            error
        end

      error ->
        error
    end
  end

  defp substitute_codepoints([], _encoder, _replacer, acc), do: {:ok, acc}

  defp substitute_codepoints([codepoint | rest], encoder, replacer, acc) do
    case encoder.([codepoint]) do
      {:ok, _bytes} ->
        substitute_codepoints(rest, encoder, replacer, [codepoint | acc])

      {:error, :unrepresentable_character, ^codepoint} ->
        replacement = replacer.(codepoint)

        case encoder.(replacement) do
          {:ok, _bytes} ->
            substitute_codepoints(rest, encoder, replacer, :lists.reverse(replacement, acc))

          error ->
            error
        end

      error ->
        error
    end
  end

  defp entry(id), do: %{id: id, table_app: :iconvex_specs}
  defp provider_entry(id), do: %{id: id}
end

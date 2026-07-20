defmodule Iconvex.Specs.KermitVersionedSingleByte do
  @moduledoc false

  defmacro defcodec(module, canonical, aliases, codec_id, identity_prefix, high_hex, sources) do
    {high_hex, []} = Code.eval_quoted(high_hex, [], __CALLER__)
    {sources, []} = Code.eval_quoted(sources, [], __CALLER__)

    high =
      high_hex
      |> String.replace(~r/\s+/, "")
      |> Base.decode16!()
      |> then(fn binary ->
        for <<codepoint::unsigned-big-32 <- binary>> do
          if codepoint == 0xFFFFFFFF, do: nil, else: codepoint
        end
      end)

    if not is_integer(identity_prefix) or identity_prefix < 0 or identity_prefix > 256 do
      raise ArgumentError,
            "#{canonical} has an invalid identity-prefix length"
    end

    identity = if identity_prefix == 0, do: [], else: Enum.to_list(0..(identity_prefix - 1))
    described = identity ++ high

    if length(described) > 256 do
      raise ArgumentError, "#{canonical} describes more than 256 octets"
    end

    decode = described ++ List.duplicate(nil, 256 - length(described))
    ascii_identity_limit = min(identity_prefix, 0x80)

    decode_utf8 =
      Enum.map(decode, fn
        nil -> nil
        codepoint when codepoint < 0x80 -> codepoint
        codepoint -> <<codepoint::utf8>>
      end)

    encode =
      decode
      |> Enum.with_index()
      |> Enum.reject(fn {codepoint, _unit} -> is_nil(codepoint) end)
      |> Enum.reduce(%{}, fn {codepoint, unit}, acc -> Map.put_new(acc, codepoint, unit) end)

    external_resources =
      for source <- sources do
        quote do
          @external_resource unquote(source)
        end
      end

    quote do
      defmodule unquote(module) do
        @moduledoc "Optimized native versioned single-byte character set."

        use Iconvex.Codec

        unquote_splicing(external_resources)

        @chunk_units 4_096
        @utf8_chunk_bytes 65_536
        @ascii_identity_limit unquote(ascii_identity_limit)
        @decode unquote(Macro.escape(List.to_tuple(decode)))
        @decode_utf8 unquote(Macro.escape(List.to_tuple(decode_utf8)))
        @encode unquote(Macro.escape(encode))
        @impl true
        def canonical_name, do: unquote(canonical)

        @impl true
        def aliases, do: unquote(aliases)

        @impl true
        def codec_id, do: unquote(codec_id)

        @impl true
        def decode(input) when is_binary(input), do: decode_all(input, 0, [])

        @impl true
        def decode_discard(input) when is_binary(input), do: decode_discard_all(input, [])

        @impl true
        def encode(codepoints) when is_list(codepoints), do: encode_all(codepoints, [])

        @impl true
        def encode_discard(codepoints) when is_list(codepoints),
          do: encode_discard_all(codepoints, [])

        @impl true
        def encode_substitute(codepoints, replacer),
          do:
            Iconvex.Specs.CodecSupport.encode_substitute_each(
              codepoints,
              &encode/1,
              replacer
            )

        @impl true
        def decode_to_utf8(input) when is_binary(input),
          do: decode_utf8_all(input, 0, [], 0, [])

        @impl true
        def encode_from_utf8(input) when is_binary(input),
          do: encode_utf8_chunks(input, <<>>, 0, [])

        defp decode_all(<<>>, _offset, acc), do: {:ok, :lists.reverse(acc)}

        defp decode_all(<<unit, rest::binary>>, offset, acc) do
          case elem(@decode, unit) do
            nil -> {:error, :invalid_sequence, offset, <<unit>>}
            codepoint -> decode_all(rest, offset + 1, [codepoint | acc])
          end
        end

        defp decode_discard_all(<<>>, acc), do: {:ok, :lists.reverse(acc)}

        defp decode_discard_all(<<unit, rest::binary>>, acc) do
          case elem(@decode, unit) do
            nil -> decode_discard_all(rest, acc)
            codepoint -> decode_discard_all(rest, [codepoint | acc])
          end
        end

        defp encode_all([], acc), do: {:ok, reverse_binary(acc)}

        defp encode_all([codepoint | rest], acc) do
          case @encode do
            %{^codepoint => unit} -> encode_all(rest, [unit | acc])
            _ -> {:error, :unrepresentable_character, codepoint}
          end
        end

        defp encode_discard_all([], acc), do: {:ok, reverse_binary(acc)}

        defp encode_discard_all([codepoint | rest], acc) do
          case @encode do
            %{^codepoint => unit} -> encode_discard_all(rest, [unit | acc])
            _ -> encode_discard_all(rest, acc)
          end
        end

        defp decode_utf8_all(
               <<a, b, c, d, e, f, g, h, rest::binary>>,
               offset,
               acc,
               count,
               chunks
             )
             when a < @ascii_identity_limit and b < @ascii_identity_limit and
                    c < @ascii_identity_limit and d < @ascii_identity_limit and
                    e < @ascii_identity_limit and f < @ascii_identity_limit and
                    g < @ascii_identity_limit and h < @ascii_identity_limit and
                    count <= @chunk_units - 8 do
          next_acc = [<<a, b, c, d, e, f, g, h>> | acc]

          if count == @chunk_units - 8 do
            chunk = next_acc |> :lists.reverse() |> IO.iodata_to_binary()
            decode_utf8_all(rest, offset + 8, [], 0, [chunk | chunks])
          else
            decode_utf8_all(rest, offset + 8, next_acc, count + 8, chunks)
          end
        end

        defp decode_utf8_all(<<>>, _offset, acc, _count, chunks),
          do: {:ok, finish_iodata(acc, chunks)}

        defp decode_utf8_all(<<unit, rest::binary>>, offset, acc, count, chunks) do
          case elem(@decode_utf8, unit) do
            nil ->
              {:error, :invalid_sequence, offset, <<unit>>}

            encoded ->
              next_acc = [encoded | acc]

              if count == @chunk_units - 1 do
                chunk = next_acc |> :lists.reverse() |> IO.iodata_to_binary()
                decode_utf8_all(rest, offset + 1, [], 0, [chunk | chunks])
              else
                decode_utf8_all(rest, offset + 1, next_acc, count + 1, chunks)
              end
          end
        end

        defp encode_utf8_chunks(remaining, carry, offset, chunks) do
          {input, rest} = take_utf8_chunk(remaining, carry)

          case :unicode.characters_to_list(input, :utf8) do
            codepoints when is_list(codepoints) ->
              with {:ok, encoded} <- encode_all(codepoints, []) do
                if rest == <<>> do
                  {:ok, finish_binary_chunks(encoded, chunks)}
                else
                  encode_utf8_chunks(rest, <<>>, offset + byte_size(input), [encoded | chunks])
                end
              end

            {:incomplete, codepoints, tail} ->
              consumed = byte_size(input) - byte_size(tail)

              with {:ok, encoded} <- encode_all(codepoints, []) do
                if rest == <<>> do
                  malformed_utf8(tail, offset + consumed)
                else
                  encode_utf8_chunks(rest, tail, offset + consumed, [encoded | chunks])
                end
              end

            {:error, codepoints, tail} ->
              consumed = byte_size(input) - byte_size(tail)

              with {:ok, _encoded} <- encode_all(codepoints, []) do
                malformed_utf8(append_error_rest(tail, rest), offset + consumed)
              end
          end
        end

        defp take_utf8_chunk(remaining, <<>>) when byte_size(remaining) <= @utf8_chunk_bytes,
          do: {remaining, <<>>}

        defp take_utf8_chunk(remaining, carry) do
          available = @utf8_chunk_bytes - byte_size(carry)

          if byte_size(remaining) <= available do
            {<<carry::binary, remaining::binary>>, <<>>}
          else
            <<head::binary-size(available), rest::binary>> = remaining
            {<<carry::binary, head::binary>>, rest}
          end
        end

        defp append_error_rest(tail, <<>>), do: tail
        defp append_error_rest(tail, rest), do: <<tail::binary, rest::binary>>

        defp malformed_utf8(input, offset),
          do: Iconvex.Specs.CodecSupport.malformed_utf8(input, offset)

        defp reverse_binary(acc), do: acc |> :lists.reverse() |> :erlang.list_to_binary()

        defp finish_binary_chunks(binary, chunks),
          do: [binary | chunks] |> :lists.reverse() |> IO.iodata_to_binary()

        defp finish_iodata([], chunks),
          do: chunks |> :lists.reverse() |> IO.iodata_to_binary()

        defp finish_iodata(acc, chunks) do
          chunk = acc |> :lists.reverse() |> IO.iodata_to_binary()
          [chunk | chunks] |> :lists.reverse() |> IO.iodata_to_binary()
        end
      end
    end
  end
end

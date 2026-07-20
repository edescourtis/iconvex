defmodule Iconvex.Specs.DECNationalReplacementSets do
  @moduledoc false

  defmacro defcodec(module, canonical, aliases, codec_id, replacements_ast) do
    {replacements, []} = Code.eval_quoted(replacements_ast, [], __CALLER__)
    decode = Enum.map(0x00..0x7F, &Map.get(replacements, &1, &1))

    encode =
      decode
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {codepoint, unit}, acc -> Map.put_new(acc, codepoint, unit) end)

    ascii_encode = Enum.map(0x00..0x7F, &Map.get(encode, &1, -1))

    source_path =
      Path.expand(
        "../../../priv/sources/dec-terminal-character-sets/EK-VT3XX-TP-002_VT330_VT340_Text_Programming_198805.pdf",
        __DIR__
      )

    metadata_path =
      Path.expand(
        "../../../priv/sources/dec-terminal-character-sets/SOURCE_METADATA.md",
        __DIR__
      )

    quote do
      defmodule unquote(module) do
        @moduledoc "Seven-bit DEC national replacement character set."

        use Iconvex.Codec

        @source_path unquote(source_path)
        @source_metadata_path unquote(metadata_path)
        @external_resource @source_path
        @external_resource @source_metadata_path

        @chunk_units 4_096
        @compile {:inline, decode_utf8_codepoint: 6, utf8: 1}
        @decode unquote(Macro.escape(List.to_tuple(decode)))
        @encode unquote(Macro.escape(encode))
        @ascii_encode unquote(Macro.escape(List.to_tuple(ascii_encode)))

        @impl true
        def canonical_name, do: unquote(canonical)

        @impl true
        def aliases, do: unquote(aliases)

        @impl true
        def codec_id, do: unquote(codec_id)

        def unit_bits, do: 7
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
          do: encode_utf8_all(input, 0, [], 0, [])

        defp decode_all(<<>>, _offset, acc), do: {:ok, :lists.reverse(acc)}

        defp decode_all(<<unit, rest::binary>>, offset, acc) when unit < 0x80,
          do: decode_all(rest, offset + 1, [elem(@decode, unit) | acc])

        defp decode_all(<<unit, _rest::binary>>, offset, _acc),
          do: {:error, :invalid_sequence, offset, <<unit>>}

        defp decode_discard_all(<<>>, acc), do: {:ok, :lists.reverse(acc)}

        defp decode_discard_all(<<unit, rest::binary>>, acc) when unit < 0x80,
          do: decode_discard_all(rest, [elem(@decode, unit) | acc])

        defp decode_discard_all(<<_unit, rest::binary>>, acc),
          do: decode_discard_all(rest, acc)

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

        defp decode_utf8_all(<<>>, _offset, acc, _count, chunks),
          do: {:ok, finish_iodata(acc, chunks)}

        defp decode_utf8_all(<<unit, rest::binary>>, offset, acc, count, chunks)
             when unit < 0x80 do
          decode_utf8_codepoint(rest, offset, elem(@decode, unit), acc, count, chunks)
        end

        defp decode_utf8_all(<<unit, _rest::binary>>, offset, _acc, _count, _chunks),
          do: {:error, :invalid_sequence, offset, <<unit>>}

        defp decode_utf8_codepoint(rest, offset, codepoint, acc, count, chunks) do
          next_acc = [utf8(codepoint) | acc]

          if count == @chunk_units - 1 do
            chunk = next_acc |> :lists.reverse() |> IO.iodata_to_binary()
            decode_utf8_all(rest, offset + 1, [], 0, [chunk | chunks])
          else
            decode_utf8_all(rest, offset + 1, next_acc, count + 1, chunks)
          end
        end

        defp encode_utf8_all(<<>>, _offset, acc, _count, chunks),
          do: {:ok, finish_iodata(acc, chunks)}

        defp encode_utf8_all(<<codepoint, rest::binary>>, offset, acc, count, chunks)
             when codepoint < 0x80 do
          case elem(@ascii_encode, codepoint) do
            -1 -> {:error, :unrepresentable_character, codepoint}
            unit -> encode_utf8_unit(rest, offset, unit, 1, acc, count, chunks)
          end
        end

        defp encode_utf8_all(input, offset, acc, count, chunks) do
          case input do
            <<codepoint::utf8, rest::binary>> ->
              case @encode do
                %{^codepoint => unit} ->
                  width = byte_size(input) - byte_size(rest)
                  encode_utf8_unit(rest, offset, unit, width, acc, count, chunks)

                _ ->
                  {:error, :unrepresentable_character, codepoint}
              end

            _ ->
              malformed_utf8(input, offset)
          end
        end

        defp encode_utf8_unit(rest, offset, unit, width, acc, count, chunks) do
          next_acc = [unit | acc]

          if count == @chunk_units - 1 do
            chunk = next_acc |> :lists.reverse() |> :erlang.list_to_binary()
            encode_utf8_all(rest, offset + width, [], 0, [chunk | chunks])
          else
            encode_utf8_all(rest, offset + width, next_acc, count + 1, chunks)
          end
        end

        defp malformed_utf8(input, offset),
          do: Iconvex.Specs.CodecSupport.malformed_utf8(input, offset)

        defp reverse_binary(acc), do: acc |> :lists.reverse() |> :erlang.list_to_binary()
        defp utf8(codepoint) when codepoint < 0x80, do: codepoint
        defp utf8(codepoint), do: <<codepoint::utf8>>

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

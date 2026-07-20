defmodule Iconvex.Specs.RFC1345Mnemonic do
  @moduledoc "RFC 1345 MNEMONIC and MNEM transport charsets."

  @path Path.expand("../../../priv/rfc1345_mnemonics.etf", __DIR__)
  @external_resource @path
  @manifest @path |> File.read!() |> :erlang.binary_to_term()
  @decode Map.new(@manifest.mappings)
  @encode Enum.reduce(@manifest.mappings, %{}, fn {mnemonic, codepoint}, result ->
            Map.put_new(result, codepoint, mnemonic)
          end)

  def codecs, do: [Iconvex.Specs.Mnemonic, Iconvex.Specs.Mnem]
  def mappings, do: @manifest.mappings
  def source, do: @manifest.source

  def decode(input, kind) when is_binary(input), do: decode_all(input, kind, 0, [])
  def decode_discard(input, kind) when is_binary(input), do: decode_discard_all(input, kind, [])
  def encode(codepoints, kind) when is_list(codepoints), do: encode_all(codepoints, kind, [])

  def encode_discard(codepoints, kind) when is_list(codepoints),
    do: encode_discard_all(codepoints, kind, [])

  def decode_to_utf8(input, kind) do
    with {:ok, codepoints} <- decode(input, kind), do: {:ok, List.to_string(codepoints)}
  end

  def encode_from_utf8(input, kind) when is_binary(input) do
    Iconvex.Specs.CodecSupport.encode_utf8(input, &encode(&1, kind))
  end

  defp decode_all(<<>>, _kind, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_all(input, kind, offset, acc) do
    case decode_one(input, kind) do
      {:ok, codepoints, rest} ->
        consumed = byte_size(input) - byte_size(rest)
        decode_all(rest, kind, offset + consumed, :lists.reverse(codepoints, acc))

      {:error, reason, sequence} ->
        {:error, reason, offset, sequence}
    end
  end

  defp decode_one(input, kind) do
    intro = intro(kind)

    cond do
      String.starts_with?(input, intro <> intro) ->
        size = byte_size(intro) * 2
        <<_::binary-size(size), rest::binary>> = input
        {:ok, :binary.bin_to_list(intro), rest}

      String.starts_with?(input, intro) ->
        <<_::binary-size(byte_size(intro)), rest::binary>> = input
        decode_mnemonic(rest, intro, input)

      true ->
        case input do
          <<byte, rest::binary>> when byte < 0x80 -> {:ok, [byte], rest}
          <<byte, _::binary>> -> {:error, :invalid_sequence, <<byte>>}
          <<>> -> {:error, :incomplete_sequence, <<>>}
        end
    end
  end

  defp decode_mnemonic(<<>>, _intro, original),
    do: {:error, :incomplete_sequence, original}

  defp decode_mnemonic(<<?_, rest::binary>>, intro, original) do
    case variable_mnemonic(rest, [], 0) do
      {:ok, mnemonic, tail, consumed} ->
        encoded_size = byte_size(intro) + 1 + consumed
        encoded = binary_part(original, 0, encoded_size)
        decoded_mnemonic(mnemonic, encoded, tail)

      :incomplete ->
        {:error, :incomplete_sequence, original}
    end
  end

  defp decode_mnemonic(rest, intro, original) when byte_size(rest) < 2,
    do:
      {:error, :incomplete_sequence, binary_part(original, 0, byte_size(intro) + byte_size(rest))}

  defp decode_mnemonic(<<first, second, tail::binary>>, intro, _original) do
    encoded = intro <> <<first, second>>
    decoded_mnemonic(<<first, second>>, encoded, tail)
  end

  defp decoded_mnemonic(mnemonic, encoded, tail) do
    case Map.fetch(@decode, mnemonic) do
      {:ok, codepoint} -> {:ok, [codepoint], tail}
      :error -> {:ok, :binary.bin_to_list(encoded), tail}
    end
  end

  defp variable_mnemonic(<<>>, _acc, _consumed), do: :incomplete

  defp variable_mnemonic(<<?_, ?_, rest::binary>>, acc, consumed),
    do: variable_mnemonic(rest, [?_ | acc], consumed + 2)

  defp variable_mnemonic(<<?_, rest::binary>>, acc, consumed),
    do: {:ok, acc |> :lists.reverse() |> :binary.list_to_bin(), rest, consumed + 1}

  defp variable_mnemonic(<<byte, rest::binary>>, acc, consumed),
    do: variable_mnemonic(rest, [byte | acc], consumed + 1)

  defp encode_all([], _kind, acc), do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_all(codepoints, :mnem, acc) do
    case codepoints do
      [0x20, 0x08 | rest] -> encode_all(rest, :mnem, [intro(:mnem), intro(:mnem) | acc])
      [codepoint | rest] -> encode_codepoint(codepoint, rest, :mnem, acc)
      [] -> encode_all([], :mnem, acc)
    end
  end

  defp encode_all([?& | rest], :mnemonic, acc),
    do: encode_all(rest, :mnemonic, ["&&" | acc])

  defp encode_all([codepoint | rest], kind, acc),
    do: encode_codepoint(codepoint, rest, kind, acc)

  defp encode_codepoint(codepoint, rest, kind, acc)
       when is_integer(codepoint) and codepoint in 0..0x7F,
       do: encode_all(rest, kind, [<<codepoint>> | acc])

  defp encode_codepoint(codepoint, rest, kind, acc) when is_integer(codepoint) do
    case Map.fetch(@encode, codepoint) do
      {:ok, mnemonic} -> encode_all(rest, kind, [encoded_mnemonic(mnemonic, kind) | acc])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_codepoint(codepoint, _rest, _kind, _acc),
    do: {:error, :unrepresentable_character, codepoint}

  defp encoded_mnemonic(mnemonic, kind) when byte_size(mnemonic) <= 2,
    do: intro(kind) <> mnemonic

  defp encoded_mnemonic(mnemonic, kind) do
    escaped = :binary.replace(mnemonic, "_", "__", [:global])
    intro(kind) <> "_" <> escaped <> "_"
  end

  defp decode_discard_all(<<>>, _kind, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_all(input, kind, acc) do
    case decode_one(input, kind) do
      {:ok, codepoints, rest} ->
        decode_discard_all(rest, kind, :lists.reverse(codepoints, acc))

      {:error, _reason, sequence} ->
        discard = max(byte_size(sequence), 1)

        rest =
          binary_part(input, min(discard, byte_size(input)), max(byte_size(input) - discard, 0))

        decode_discard_all(rest, kind, acc)
    end
  end

  defp encode_discard_all([], _kind, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_discard_all(codepoints, :mnem, acc) do
    case codepoints do
      [0x20, 0x08 | rest] -> encode_discard_all(rest, :mnem, [intro(:mnem), intro(:mnem) | acc])
      [codepoint | rest] -> encode_discard_codepoint(codepoint, rest, :mnem, acc)
      [] -> encode_discard_all([], :mnem, acc)
    end
  end

  defp encode_discard_all([?& | rest], :mnemonic, acc),
    do: encode_discard_all(rest, :mnemonic, ["&&" | acc])

  defp encode_discard_all([codepoint | rest], kind, acc),
    do: encode_discard_codepoint(codepoint, rest, kind, acc)

  defp encode_discard_codepoint(codepoint, rest, kind, acc)
       when is_integer(codepoint) and codepoint in 0..0x7F,
       do: encode_discard_all(rest, kind, [<<codepoint>> | acc])

  defp encode_discard_codepoint(codepoint, rest, kind, acc) when is_integer(codepoint) do
    case Map.fetch(@encode, codepoint) do
      {:ok, mnemonic} -> encode_discard_all(rest, kind, [encoded_mnemonic(mnemonic, kind) | acc])
      :error -> encode_discard_all(rest, kind, acc)
    end
  end

  defp encode_discard_codepoint(_codepoint, rest, kind, acc),
    do: encode_discard_all(rest, kind, acc)

  defp intro(:mnemonic), do: "&"
  defp intro(:mnem), do: <<0x20, 0x08>>
end

defmodule Iconvex.Specs.Mnemonic do
  @moduledoc "RFC 1345 `mnemonic+ascii+38` shorthand."
  use Iconvex.Codec
  def canonical_name, do: "MNEMONIC"
  def aliases, do: ["csMnemonic", "mnemonic+ascii+38"]
  def codec_id, do: :rfc1345_mnemonic
  def stateful?, do: true
  def decode(input), do: Iconvex.Specs.RFC1345Mnemonic.decode(input, :mnemonic)
  def decode_discard(input), do: Iconvex.Specs.RFC1345Mnemonic.decode_discard(input, :mnemonic)
  def encode(codepoints), do: Iconvex.Specs.RFC1345Mnemonic.encode(codepoints, :mnemonic)

  def encode_discard(codepoints),
    do: Iconvex.Specs.RFC1345Mnemonic.encode_discard(codepoints, :mnemonic)

  def encode_substitute(codepoints, replacer),
    do:
      Iconvex.Specs.CodecSupport.encode_substitute_transform(
        codepoints,
        &encode/1,
        replacer
      )

  def decode_to_utf8(input), do: Iconvex.Specs.RFC1345Mnemonic.decode_to_utf8(input, :mnemonic)

  def encode_from_utf8(input),
    do: Iconvex.Specs.RFC1345Mnemonic.encode_from_utf8(input, :mnemonic)
end

defmodule Iconvex.Specs.Mnem do
  @moduledoc "RFC 1345 `mnemonic+ascii+8200` shorthand."
  use Iconvex.Codec
  def canonical_name, do: "MNEM"
  def aliases, do: ["csMnem", "mnemonic+ascii+8200"]
  def codec_id, do: :rfc1345_mnem
  def stateful?, do: true
  def decode(input), do: Iconvex.Specs.RFC1345Mnemonic.decode(input, :mnem)
  def decode_discard(input), do: Iconvex.Specs.RFC1345Mnemonic.decode_discard(input, :mnem)
  def encode(codepoints), do: Iconvex.Specs.RFC1345Mnemonic.encode(codepoints, :mnem)

  def encode_discard(codepoints),
    do: Iconvex.Specs.RFC1345Mnemonic.encode_discard(codepoints, :mnem)

  def encode_substitute(codepoints, replacer),
    do:
      Iconvex.Specs.CodecSupport.encode_substitute_transform(
        codepoints,
        &encode/1,
        replacer
      )

  def decode_to_utf8(input), do: Iconvex.Specs.RFC1345Mnemonic.decode_to_utf8(input, :mnem)
  def encode_from_utf8(input), do: Iconvex.Specs.RFC1345Mnemonic.encode_from_utf8(input, :mnem)
end

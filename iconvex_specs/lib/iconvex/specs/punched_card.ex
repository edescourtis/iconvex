defmodule Iconvex.Specs.PunchedCard do
  @moduledoc false

  import Bitwise
  alias Iconvex.Packed.LSB

  @chunk_units 4_096

  def encode_words(codepoints, encode, endian, policy \\ :error)
      when is_list(codepoints) and is_map(encode) and endian in [:big, :little] do
    encode_words_all(codepoints, encode, endian, policy, [], 0, [])
  end

  def decode_words(input, decode, endian, discard? \\ false)
      when is_binary(input) and is_tuple(decode) and endian in [:big, :little] do
    decode_words_all(input, decode, endian, discard?, 0, [])
  end

  def decode_words_to_utf8(input, decode, endian)
      when is_binary(input) and is_tuple(decode) and endian in [:big, :little] do
    decode_words_utf8(input, decode, endian, 0, [], 0, [])
  end

  def encode_words_from_utf8(input, encode, endian)
      when is_binary(input) and is_map(encode) and endian in [:big, :little] do
    encode_utf8_words(input, encode, endian, 0, [], 0, [])
  end

  def decode_chunk(input, decode, endian, final?)
      when is_binary(input) and is_boolean(final?) do
    stable_size =
      if final?, do: byte_size(input), else: byte_size(input) - rem(byte_size(input), 2)

    <<stable::binary-size(stable_size), pending::binary>> = input

    case decode_words(stable, decode, endian) do
      {:ok, _codepoints} when final? and pending != <<>> ->
        {:error, :incomplete_sequence, stable_size, pending}

      {:ok, codepoints} ->
        {:ok, codepoints, pending}

      error ->
        error
    end
  end

  def encode_chunk(codepoints, encode, endian, _final?, policy) when is_list(codepoints) do
    result =
      case policy do
        :error ->
          encode_words(codepoints, encode, endian)

        :discard ->
          encode_words(codepoints, encode, endian, :discard)

        {:replace, replacer} when is_function(replacer, 1) ->
          encode_words(codepoints, encode, endian, {:replace, replacer})
      end

    case result do
      {:ok, bytes} -> {:ok, bytes, []}
      error -> error
    end
  end

  def encode_packed(codepoints, encode, policy \\ :error)
      when is_list(codepoints) and is_map(encode) do
    encode_packed_all(codepoints, encode, policy, [], 0, [])
  end

  def decode_packed(input, decode, discard? \\ false)
      when is_bitstring(input) and is_tuple(decode) do
    decode_packed_all(input, decode, discard?, 0, [])
  end

  def encode_masks(codepoints, encode, policy \\ :error)
      when is_list(codepoints) and is_map(encode) do
    encode_masks_all(codepoints, encode, policy, [])
  end

  def pack_masks_msb(masks) when is_list(masks), do: pack_masks_msb_all(masks, 0, [])

  def pack_masks_lsb(masks) when is_list(masks) do
    case pack_masks_lsb_all(masks, 0, []) do
      {:ok, chunks, units} ->
        {:ok,
         %LSB{
           data: chunks |> :lists.reverse() |> IO.iodata_to_binary(),
           bit_size: units * 12,
           unit_bits: 12
         }}

      error ->
        error
    end
  end

  def decode_packed_lsb(input, decode, discard? \\ false)

  def decode_packed_lsb(%LSB{bit_order: bit_order}, _decode, _discard?)
      when bit_order != :lsb,
      do: {:error, :bit_order_mismatch}

  def decode_packed_lsb(%LSB{unit_bits: unit_bits}, _decode, _discard?)
      when unit_bits != 12,
      do: {:error, :unit_width_mismatch}

  def decode_packed_lsb(%LSB{data: data, bit_size: bit_size}, decode, discard?)
      when is_binary(data) and is_integer(bit_size) and bit_size >= 0 and is_tuple(decode) do
    expected_bytes = div(bit_size + 7, 8)
    complete_bits = bit_size - rem(bit_size, 12)
    complete_units = div(complete_bits, 12)
    tail_bits = bit_size - complete_bits

    cond do
      byte_size(data) != expected_bytes ->
        {:error, :invalid_bit_size}

      tail_bits == 0 and nonzero_lsb_padding?(data, bit_size) ->
        {:error, :nonzero_padding_bits}

      true ->
        case decode_lsb_units(data, complete_units, decode, discard?, 0, []) do
          {:ok, codepoints} when tail_bits == 0 ->
            {:ok, codepoints}

          {:ok, codepoints} when discard? ->
            if nonzero_lsb_padding?(data, bit_size) do
              {:error, :nonzero_padding_bits}
            else
              {:ok, codepoints}
            end

          {:ok, _codepoints} ->
            {:error, :incomplete_unit, complete_bits, tail_bits}

          error ->
            error
        end
    end
  end

  def decode_packed_lsb(_input, _decode, _discard?), do: {:error, :invalid_packed_transport}

  def encode_packed_from_utf8(input, encode, :msb) when is_binary(input) do
    with {:ok, codepoints} <- utf8_codepoints(input, encode) do
      encode_packed(codepoints, encode)
    end
  end

  def encode_packed_from_utf8(input, encode, :lsb) when is_binary(input) do
    with {:ok, codepoints} <- utf8_codepoints(input, encode),
         {:ok, masks} <- encode_masks(codepoints, encode) do
      pack_masks_lsb(masks)
    end
  end

  def decode_packed_to_utf8(input, decode, :msb) when is_bitstring(input) do
    case decode_packed(input, decode) do
      {:ok, codepoints} -> {:ok, List.to_string(codepoints)}
      error -> error
    end
  end

  def decode_packed_to_utf8(%LSB{bit_order: :lsb} = input, decode, :lsb) do
    case decode_packed_lsb(input, decode) do
      {:ok, codepoints} -> {:ok, List.to_string(codepoints)}
      error -> error
    end
  end

  def decode_packed_to_utf8(%LSB{}, _decode, :lsb), do: {:error, :bit_order_mismatch}
  def decode_packed_to_utf8(_input, _decode, _order), do: {:error, :invalid_packed_transport}

  defp encode_words_all([], _encode, _endian, _policy, acc, _count, chunks),
    do: {:ok, finish_binary(acc, chunks)}

  defp encode_words_all([codepoint | rest], encode, endian, policy, acc, count, chunks) do
    case Map.fetch(encode, codepoint) do
      {:ok, mask} ->
        {acc, count, chunks} = push_binary(word(mask, endian), acc, count, chunks)
        encode_words_all(rest, encode, endian, policy, acc, count, chunks)

      :error when policy == :discard ->
        encode_words_all(rest, encode, endian, policy, acc, count, chunks)

      :error ->
        encode_words_unrepresentable(
          codepoint,
          rest,
          encode,
          endian,
          policy,
          acc,
          count,
          chunks
        )
    end
  end

  defp encode_words_unrepresentable(
         codepoint,
         rest,
         encode,
         endian,
         {:replace, replacer} = policy,
         acc,
         count,
         chunks
       ) do
    case encode_word_replacement(replacer.(codepoint), encode, endian, acc, count, chunks) do
      {:ok, acc, count, chunks} ->
        encode_words_all(rest, encode, endian, policy, acc, count, chunks)

      error ->
        error
    end
  end

  defp encode_words_unrepresentable(
         codepoint,
         _rest,
         _encode,
         _endian,
         _policy,
         _acc,
         _count,
         _chunks
       ),
       do: {:error, :unrepresentable_character, codepoint}

  defp encode_word_replacement([], _encode, _endian, acc, count, chunks),
    do: {:ok, acc, count, chunks}

  defp encode_word_replacement(
         [codepoint | rest],
         encode,
         endian,
         acc,
         count,
         chunks
       ) do
    case Map.fetch(encode, codepoint) do
      {:ok, mask} ->
        {acc, count, chunks} = push_binary(word(mask, endian), acc, count, chunks)
        encode_word_replacement(rest, encode, endian, acc, count, chunks)

      :error ->
        {:error, :unrepresentable_character, codepoint}
    end
  end

  defp decode_words_all(<<>>, _decode, _endian, _discard?, _offset, acc),
    do: {:ok, :lists.reverse(acc)}

  defp decode_words_all(input, _decode, _endian, true, _offset, acc)
       when byte_size(input) < 2,
       do: {:ok, :lists.reverse(acc)}

  defp decode_words_all(input, _decode, _endian, false, offset, _acc)
       when byte_size(input) < 2,
       do: {:error, :incomplete_sequence, offset, input}

  defp decode_words_all(input, decode, endian, discard?, offset, acc) do
    {mask, raw, rest} = next_word(input, endian)

    case decoded(decode, mask) do
      codepoint when is_integer(codepoint) ->
        decode_words_all(rest, decode, endian, discard?, offset + 2, [codepoint | acc])

      _ when discard? ->
        decode_words_all(rest, decode, endian, true, offset + 2, acc)

      _ ->
        {:error, :invalid_sequence, offset, raw}
    end
  end

  defp decode_words_utf8(<<>>, _decode, _endian, _offset, acc, _count, chunks),
    do: {:ok, finish_binary(acc, chunks)}

  defp decode_words_utf8(input, _decode, _endian, offset, _acc, _count, _chunks)
       when byte_size(input) < 2,
       do: {:error, :incomplete_sequence, offset, input}

  defp decode_words_utf8(input, decode, endian, offset, acc, count, chunks) do
    {mask, raw, rest} = next_word(input, endian)

    case decoded(decode, mask) do
      codepoint when is_integer(codepoint) ->
        {acc, count, chunks} = push_binary(<<codepoint::utf8>>, acc, count, chunks)
        decode_words_utf8(rest, decode, endian, offset + 2, acc, count, chunks)

      _ ->
        {:error, :invalid_sequence, offset, raw}
    end
  end

  defp encode_utf8_words(<<>>, _encode, _endian, _offset, acc, _count, chunks),
    do: {:ok, finish_binary(acc, chunks)}

  defp encode_utf8_words(
         <<codepoint::utf8, rest::binary>>,
         encode,
         endian,
         offset,
         acc,
         count,
         chunks
       ) do
    case Map.fetch(encode, codepoint) do
      {:ok, mask} ->
        {acc, count, chunks} = push_binary(word(mask, endian), acc, count, chunks)

        encode_utf8_words(
          rest,
          encode,
          endian,
          offset + byte_size(<<codepoint::utf8>>),
          acc,
          count,
          chunks
        )

      :error ->
        {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_utf8_words(input, _encode, _endian, offset, _acc, _count, _chunks),
    do: Iconvex.Specs.CodecSupport.malformed_utf8(input, offset)

  defp encode_packed_all([], _encode, _policy, acc, _count, chunks),
    do: {:ok, finish_bitstring(acc, chunks)}

  defp encode_packed_all([codepoint | rest], encode, policy, acc, count, chunks) do
    case Map.fetch(encode, codepoint) do
      {:ok, mask} ->
        {acc, count, chunks} = push_bitstring(<<mask::12>>, acc, count, chunks)
        encode_packed_all(rest, encode, policy, acc, count, chunks)

      :error when policy == :discard ->
        encode_packed_all(rest, encode, policy, acc, count, chunks)

      :error ->
        encode_packed_unrepresentable(codepoint, rest, encode, policy, acc, count, chunks)
    end
  end

  defp encode_packed_unrepresentable(
         codepoint,
         rest,
         encode,
         {:replace, replacer} = policy,
         acc,
         count,
         chunks
       ) do
    case encode_packed_replacement(replacer.(codepoint), encode, acc, count, chunks) do
      {:ok, acc, count, chunks} ->
        encode_packed_all(rest, encode, policy, acc, count, chunks)

      error ->
        error
    end
  end

  defp encode_packed_unrepresentable(
         codepoint,
         _rest,
         _encode,
         _policy,
         _acc,
         _count,
         _chunks
       ),
       do: {:error, :unrepresentable_character, codepoint}

  defp encode_packed_replacement([], _encode, acc, count, chunks),
    do: {:ok, acc, count, chunks}

  defp encode_packed_replacement([codepoint | rest], encode, acc, count, chunks) do
    case Map.fetch(encode, codepoint) do
      {:ok, mask} ->
        {acc, count, chunks} = push_bitstring(<<mask::12>>, acc, count, chunks)
        encode_packed_replacement(rest, encode, acc, count, chunks)

      :error ->
        {:error, :unrepresentable_character, codepoint}
    end
  end

  defp decode_packed_all(<<>>, _decode, _discard?, _offset, acc),
    do: {:ok, :lists.reverse(acc)}

  defp decode_packed_all(input, _decode, true, _offset, acc) when bit_size(input) < 12,
    do: {:ok, :lists.reverse(acc)}

  defp decode_packed_all(input, _decode, false, offset, _acc) when bit_size(input) < 12,
    do: {:error, :incomplete_sequence, offset, input}

  defp decode_packed_all(<<mask::12, rest::bitstring>>, decode, discard?, offset, acc) do
    case decoded(decode, mask) do
      codepoint when is_integer(codepoint) ->
        decode_packed_all(rest, decode, discard?, offset + 12, [codepoint | acc])

      _ when discard? ->
        decode_packed_all(rest, decode, true, offset + 12, acc)

      _ ->
        {:error, :invalid_sequence, offset, <<mask::12>>}
    end
  end

  defp encode_masks_all([], _encode, _policy, acc), do: {:ok, :lists.reverse(acc)}

  defp encode_masks_all([codepoint | rest], encode, policy, acc) do
    case Map.fetch(encode, codepoint) do
      {:ok, mask} ->
        encode_masks_all(rest, encode, policy, [mask | acc])

      :error when policy == :discard ->
        encode_masks_all(rest, encode, policy, acc)

      :error ->
        encode_masks_unrepresentable(codepoint, rest, encode, policy, acc)
    end
  end

  defp encode_masks_unrepresentable(
         codepoint,
         rest,
         encode,
         {:replace, replacer} = policy,
         acc
       ) do
    case encode_mask_replacement(replacer.(codepoint), encode, acc) do
      {:ok, acc} -> encode_masks_all(rest, encode, policy, acc)
      error -> error
    end
  end

  defp encode_masks_unrepresentable(codepoint, _rest, _encode, _policy, _acc),
    do: {:error, :unrepresentable_character, codepoint}

  defp encode_mask_replacement([], _encode, acc), do: {:ok, acc}

  defp encode_mask_replacement([codepoint | rest], encode, acc) do
    case Map.fetch(encode, codepoint) do
      {:ok, mask} -> encode_mask_replacement(rest, encode, [mask | acc])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp pack_masks_msb_all([], _offset, acc),
    do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_bitstring()}

  defp pack_masks_msb_all([mask | rest], offset, acc)
       when is_integer(mask) and mask in 0..0xFFF,
       do: pack_masks_msb_all(rest, offset + 1, [<<mask::12>> | acc])

  defp pack_masks_msb_all([mask | _rest], offset, _acc),
    do: {:error, :unit_out_of_range, offset, mask}

  defp pack_masks_lsb_all([], units, acc), do: {:ok, acc, units}

  defp pack_masks_lsb_all([first, second | rest], units, acc) do
    cond do
      not (is_integer(first) and first in 0..0xFFF) ->
        {:error, :unit_out_of_range, units, first}

      not (is_integer(second) and second in 0..0xFFF) ->
        {:error, :unit_out_of_range, units + 1, second}

      true ->
        pack_masks_lsb_all(rest, units + 2, [<<first ||| second <<< 12::24-little>> | acc])
    end
  end

  defp pack_masks_lsb_all([last], units, acc)
       when is_integer(last) and last in 0..0xFFF,
       do: {:ok, [<<last::16-little>> | acc], units + 1}

  defp pack_masks_lsb_all([invalid | _rest], units, _acc),
    do: {:error, :unit_out_of_range, units, invalid}

  defp decode_lsb_units(_data, 0, _decode, _discard?, _offset, acc),
    do: {:ok, :lists.reverse(acc)}

  defp decode_lsb_units(
         <<value::24-little, rest::binary>>,
         units,
         decode,
         discard?,
         offset,
         acc
       )
       when units >= 2 do
    first = value &&& 0xFFF
    second = value >>> 12 &&& 0xFFF

    with {:ok, acc} <- decode_lsb_mask(first, decode, discard?, offset, acc),
         {:ok, acc} <- decode_lsb_mask(second, decode, discard?, offset + 12, acc) do
      decode_lsb_units(rest, units - 2, decode, discard?, offset + 24, acc)
    end
  end

  defp decode_lsb_units(<<value::16-little, _tail::binary>>, 1, decode, discard?, offset, acc) do
    case decode_lsb_mask(value &&& 0xFFF, decode, discard?, offset, acc) do
      {:ok, acc} -> {:ok, :lists.reverse(acc)}
      error -> error
    end
  end

  defp decode_lsb_mask(mask, decode, discard?, offset, acc) do
    case decoded(decode, mask) do
      codepoint when is_integer(codepoint) -> {:ok, [codepoint | acc]}
      _ when discard? -> {:ok, acc}
      _ -> {:error, :invalid_sequence, offset, mask}
    end
  end

  defp nonzero_lsb_padding?(_data, bit_size) when rem(bit_size, 8) == 0, do: false
  defp nonzero_lsb_padding?(<<>>, _bit_size), do: false

  defp nonzero_lsb_padding?(data, bit_size),
    do: :binary.last(data) >>> rem(bit_size, 8) != 0

  defp utf8_codepoints(input, encode) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        {:ok, codepoints}

      {:incomplete, converted, rest} ->
        packed_utf8_error_after_prefix(
          converted,
          encode,
          :incomplete_sequence,
          byte_size(input) - byte_size(rest),
          rest
        )

      {:error, converted, rest} ->
        packed_utf8_error_after_prefix(
          converted,
          encode,
          :invalid_sequence,
          byte_size(input) - byte_size(rest),
          rest
        )
    end
  end

  defp packed_utf8_error_after_prefix(converted, encode, kind, offset, rest) do
    case encode_masks(converted, encode) do
      {:error, _, _} = error -> error
      {:ok, _masks} -> {:decode_error, kind, offset, rest}
    end
  end

  defp decoded(decode, mask) when mask in 0..0xFFF, do: elem(decode, mask)
  defp decoded(_decode, _mask), do: nil

  defp next_word(<<mask::16-big, rest::binary>>, :big),
    do: {mask, <<mask::16-big>>, rest}

  defp next_word(<<mask::16-little, rest::binary>>, :little),
    do: {mask, <<mask::16-little>>, rest}

  defp word(mask, :big), do: <<mask::16-big>>
  defp word(mask, :little), do: <<mask::16-little>>

  defp push_binary(value, acc, count, chunks) when count == @chunk_units - 1 do
    chunk = [value | acc] |> :lists.reverse() |> IO.iodata_to_binary()
    {[], 0, [chunk | chunks]}
  end

  defp push_binary(value, acc, count, chunks), do: {[value | acc], count + 1, chunks}

  defp push_bitstring(value, acc, count, chunks) when count == @chunk_units - 1 do
    chunk = [value | acc] |> :lists.reverse() |> :erlang.list_to_bitstring()
    {[], 0, [chunk | chunks]}
  end

  defp push_bitstring(value, acc, count, chunks), do: {[value | acc], count + 1, chunks}

  defp finish_binary([], chunks),
    do: chunks |> :lists.reverse() |> IO.iodata_to_binary()

  defp finish_binary(acc, chunks) do
    chunk = acc |> :lists.reverse() |> IO.iodata_to_binary()
    [chunk | chunks] |> :lists.reverse() |> IO.iodata_to_binary()
  end

  defp finish_bitstring([], chunks),
    do: chunks |> :lists.reverse() |> :erlang.list_to_bitstring()

  defp finish_bitstring(acc, chunks) do
    chunk = acc |> :lists.reverse() |> :erlang.list_to_bitstring()
    [chunk | chunks] |> :lists.reverse() |> :erlang.list_to_bitstring()
  end
end

defmodule Iconvex.Specs.PunchedCard.Profile do
  @moduledoc false

  defmacro __using__(options) do
    canonical = Keyword.fetch!(options, :canonical)
    aliases = Keyword.fetch!(options, :aliases)
    mappings = Keyword.fetch!(options, :mappings)
    decode_aliases = Keyword.get(options, :decode_aliases, [])
    transports = Keyword.fetch!(options, :transports)
    source_sha256 = Keyword.fetch!(options, :source_sha256)
    source_url = Keyword.fetch!(options, :source_url)
    source_pages = Keyword.fetch!(options, :source_pages)
    printed_source_pages = Keyword.fetch!(options, :printed_source_pages)

    quote do
      alias Iconvex.Specs.PunchedCard, as: Engine

      @mappings unquote(mappings)
      @decode_aliases unquote(decode_aliases)
      @encode Map.new(@mappings)

      @decode (@mappings ++ @decode_aliases)
              |> Enum.reduce(List.duplicate(nil, 4_096), fn {codepoint, mask}, table ->
                List.replace_at(table, mask, codepoint)
              end)
              |> List.to_tuple()

      def canonical_name, do: unquote(canonical)
      def aliases, do: unquote(aliases)
      def unit_bits, do: 12
      def standard_packed_order, do: :msb
      def nonstandard_packed_orders, do: [:lsb]
      def transport_codecs, do: unquote(transports)

      def source_sha256, do: unquote(source_sha256)
      def source_url, do: unquote(source_url)
      def source_pages, do: unquote(source_pages)
      def printed_source_pages, do: unquote(printed_source_pages)
      def canonical_count, do: map_size(@encode)
      def decode_alias_count, do: length(@decode_aliases)

      def encode_packed(codepoints), do: Engine.encode_packed(codepoints, @encode)

      def encode_packed_discard(codepoints),
        do: Engine.encode_packed(codepoints, @encode, :discard)

      def encode_packed_substitute(codepoints, replacer),
        do: Engine.encode_packed(codepoints, @encode, {:replace, replacer})

      def decode_packed(input), do: Engine.decode_packed(input, @decode)
      def decode_packed_discard(input), do: Engine.decode_packed(input, @decode, true)

      def encode_packed_lsb(codepoints) do
        with {:ok, masks} <- Engine.encode_masks(codepoints, @encode) do
          Engine.pack_masks_lsb(masks)
        end
      end

      def encode_packed_lsb_discard(codepoints) do
        with {:ok, masks} <- Engine.encode_masks(codepoints, @encode, :discard) do
          Engine.pack_masks_lsb(masks)
        end
      end

      def encode_packed_lsb_substitute(codepoints, replacer) do
        with {:ok, masks} <-
               Engine.encode_masks(codepoints, @encode, {:replace, replacer}) do
          Engine.pack_masks_lsb(masks)
        end
      end

      def decode_packed_lsb(input), do: Engine.decode_packed_lsb(input, @decode)
      def decode_packed_lsb_discard(input), do: Engine.decode_packed_lsb(input, @decode, true)
      def pack_masks_msb(masks), do: Engine.pack_masks_msb(masks)
      def pack_masks_lsb(masks), do: Engine.pack_masks_lsb(masks)

      def encode_packed_from_utf8(input, order \\ :msb),
        do: Engine.encode_packed_from_utf8(input, @encode, order)

      def decode_packed_to_utf8(input, order \\ :msb),
        do: Engine.decode_packed_to_utf8(input, @decode, order)

      def decode_words(input, endian), do: Engine.decode_words(input, @decode, endian)

      def decode_words_discard(input, endian),
        do: Engine.decode_words(input, @decode, endian, true)

      def decode_words_to_utf8(input, endian),
        do: Engine.decode_words_to_utf8(input, @decode, endian)

      def encode_words(codepoints, endian), do: Engine.encode_words(codepoints, @encode, endian)

      def encode_words_discard(codepoints, endian),
        do: Engine.encode_words(codepoints, @encode, endian, :discard)

      def encode_words_substitute(codepoints, endian, replacer),
        do: Engine.encode_words(codepoints, @encode, endian, {:replace, replacer})

      def encode_words_from_utf8(input, endian),
        do: Engine.encode_words_from_utf8(input, @encode, endian)

      def decode_chunk(input, endian, final?),
        do: Engine.decode_chunk(input, @decode, endian, final?)

      def encode_chunk(codepoints, endian, final?, policy),
        do: Engine.encode_chunk(codepoints, @encode, endian, final?, policy)
    end
  end
end

defmodule Iconvex.Specs.PunchedCard.Transport do
  @moduledoc false

  defmacro __using__(options) do
    profile = Keyword.fetch!(options, :profile)
    endian = Keyword.fetch!(options, :endian)
    canonical = Keyword.fetch!(options, :canonical)
    aliases = Keyword.fetch!(options, :aliases)
    codec_id = Keyword.fetch!(options, :codec_id)

    quote do
      use Iconvex.Codec

      @profile unquote(profile)
      @endian unquote(endian)

      @impl true
      def canonical_name, do: unquote(canonical)

      @impl true
      def aliases, do: unquote(aliases)

      @impl true
      def codec_id, do: unquote(codec_id)

      def logical_profile, do: @profile
      def logical_unit_bits, do: 12
      def transport_word_bits, do: 16
      def source_sha256, do: @profile.source_sha256()
      def source_url, do: @profile.source_url()
      def source_pages, do: @profile.source_pages()
      def printed_source_pages, do: @profile.printed_source_pages()

      @impl true
      def decode(input), do: @profile.decode_words(input, @endian)

      @impl true
      def decode_discard(input), do: @profile.decode_words_discard(input, @endian)

      @impl true
      def decode_to_utf8(input), do: @profile.decode_words_to_utf8(input, @endian)

      @impl true
      def encode(codepoints), do: @profile.encode_words(codepoints, @endian)

      @impl true
      def encode_discard(codepoints), do: @profile.encode_words_discard(codepoints, @endian)

      @impl true
      def encode_substitute(codepoints, replacer),
        do: @profile.encode_words_substitute(codepoints, @endian, replacer)

      @impl true
      def encode_from_utf8(input), do: @profile.encode_words_from_utf8(input, @endian)

      @impl true
      def decode_chunk(input, final?), do: @profile.decode_chunk(input, @endian, final?)

      @impl true
      def decode_error_consumption(_kind, sequence) when byte_size(sequence) >= 2, do: 2

      def decode_error_consumption(_kind, _sequence), do: 1

      @impl true
      def encode_chunk(codepoints, final?, policy),
        do: @profile.encode_chunk(codepoints, @endian, final?, policy)
    end
  end
end

defmodule Iconvex.Specs.IBM7040HReport do
  @moduledoc "IBM-7040-H-REPORT logical 12-bit punched-card profile."

  use Iconvex.Specs.PunchedCard.Profile,
    canonical: "IBM-7040-H-REPORT",
    aliases: ["IBM-7044-H-REPORT"],
    mappings: [
      {0x20, 0x000},
      {0x39, 0x001},
      {0x38, 0x002},
      {0x37, 0x004},
      {0x221A, 0x006},
      {0x36, 0x008},
      {0x3E, 0x00A},
      {0x35, 0x010},
      {0x27, 0x012},
      {0x34, 0x020},
      {0x40, 0x022},
      {0x33, 0x040},
      {0x23, 0x042},
      {0x32, 0x080},
      {0x2422, 0x082},
      {0x31, 0x100},
      {0x30, 0x200},
      {0x5A, 0x201},
      {0x59, 0x202},
      {0x58, 0x204},
      {0x29FB, 0x206},
      {0x57, 0x208},
      {0x5C, 0x20A},
      {0x56, 0x210},
      {0x22CE, 0x212},
      {0x55, 0x220},
      {0x25, 0x222},
      {0x54, 0x240},
      {0x2C, 0x242},
      {0x53, 0x280},
      {0x2021, 0x282},
      {0x2F, 0x300},
      {0x2D, 0x400},
      {0x52, 0x401},
      {0x51, 0x402},
      {0x50, 0x404},
      {0x394, 0x406},
      {0x4F, 0x408},
      {0x3B, 0x40A},
      {0x4E, 0x410},
      {0x5D, 0x412},
      {0x4D, 0x420},
      {0x2A, 0x422},
      {0x4C, 0x440},
      {0x24, 0x442},
      {0x4B, 0x480},
      {0x4A, 0x500},
      {0x21, 0x600},
      {0x26, 0x800},
      {0x49, 0x801},
      {0x48, 0x802},
      {0x47, 0x804},
      {0x2BD2, 0x806},
      {0x46, 0x808},
      {0x3C, 0x80A},
      {0x45, 0x810},
      {0x5B, 0x812},
      {0x44, 0x820},
      {0x2311, 0x822},
      {0x43, 0x840},
      {0x2E, 0x842},
      {0x42, 0x880},
      {0x41, 0x900},
      {0x3F, 0xA00}
    ],
    decode_aliases: [],
    transports: [
      Iconvex.Specs.IBM7040HReport16BE,
      Iconvex.Specs.IBM7040HReport16LE
    ],
    source_sha256: "46336c0ed59e04fdc5c7c9553e668f8fcbb000caa88a54dca72d943d0fed28bb",
    source_url: "https://bitsavers.org/pdf/ibm/7040/22-6732-1_7040StudentText.pdf",
    source_pages: [23, 24],
    printed_source_pages: ["21", "22"]
end

defmodule Iconvex.Specs.IBM7040HReport16BE do
  @moduledoc "IBM-7040-H-REPORT in zero-padded 16-bit big-endian words."

  use Iconvex.Specs.PunchedCard.Transport,
    profile: Iconvex.Specs.IBM7040HReport,
    endian: :big,
    canonical: "IBM-7040-H-REPORT-16BE",
    aliases: ["IBM-7040-H-REPORT-BE", "IBM-7044-H-REPORT-16BE"],
    codec_id: :ibm_7040_h_report_16be
end

defmodule Iconvex.Specs.IBM7040HReport16LE do
  @moduledoc "IBM-7040-H-REPORT in zero-padded 16-bit little-endian words."

  use Iconvex.Specs.PunchedCard.Transport,
    profile: Iconvex.Specs.IBM7040HReport,
    endian: :little,
    canonical: "IBM-7040-H-REPORT-16LE",
    aliases: ["IBM-7040-H-REPORT-LE", "IBM-7044-H-REPORT-16LE"],
    codec_id: :ibm_7040_h_report_16le
end

defmodule Iconvex.Specs.IBM7040HProgram do
  @moduledoc "IBM-7040-H-PROGRAM logical 12-bit punched-card profile."

  use Iconvex.Specs.PunchedCard.Profile,
    canonical: "IBM-7040-H-PROGRAM",
    aliases: ["IBM-7044-H-PROGRAM"],
    mappings: [
      {0x20, 0x000},
      {0x39, 0x001},
      {0x38, 0x002},
      {0x37, 0x004},
      {0x221A, 0x006},
      {0x36, 0x008},
      {0x3E, 0x00A},
      {0x35, 0x010},
      {0x3A, 0x012},
      {0x34, 0x020},
      {0x27, 0x022},
      {0x33, 0x040},
      {0x3D, 0x042},
      {0x32, 0x080},
      {0x2422, 0x082},
      {0x31, 0x100},
      {0x30, 0x200},
      {0x5A, 0x201},
      {0x59, 0x202},
      {0x58, 0x204},
      {0x29FB, 0x206},
      {0x57, 0x208},
      {0x5C, 0x20A},
      {0x56, 0x210},
      {0x22CE, 0x212},
      {0x55, 0x220},
      {0x28, 0x222},
      {0x54, 0x240},
      {0x2C, 0x242},
      {0x53, 0x280},
      {0x2021, 0x282},
      {0x2F, 0x300},
      {0x2D, 0x400},
      {0x52, 0x401},
      {0x51, 0x402},
      {0x50, 0x404},
      {0x394, 0x406},
      {0x4F, 0x408},
      {0x3B, 0x40A},
      {0x4E, 0x410},
      {0x5D, 0x412},
      {0x4D, 0x420},
      {0x2A, 0x422},
      {0x4C, 0x440},
      {0x24, 0x442},
      {0x4B, 0x480},
      {0x4A, 0x500},
      {0x21, 0x600},
      {0x2B, 0x800},
      {0x49, 0x801},
      {0x48, 0x802},
      {0x47, 0x804},
      {0x2BD2, 0x806},
      {0x46, 0x808},
      {0x3C, 0x80A},
      {0x45, 0x810},
      {0x5B, 0x812},
      {0x44, 0x820},
      {0x29, 0x822},
      {0x43, 0x840},
      {0x2E, 0x842},
      {0x42, 0x880},
      {0x41, 0x900},
      {0x3F, 0xA00}
    ],
    decode_aliases: [],
    transports: [
      Iconvex.Specs.IBM7040HProgram16BE,
      Iconvex.Specs.IBM7040HProgram16LE
    ],
    source_sha256: "46336c0ed59e04fdc5c7c9553e668f8fcbb000caa88a54dca72d943d0fed28bb",
    source_url: "https://bitsavers.org/pdf/ibm/7040/22-6732-1_7040StudentText.pdf",
    source_pages: [23, 24],
    printed_source_pages: ["21", "22"]
end

defmodule Iconvex.Specs.IBM7040HProgram16BE do
  @moduledoc "IBM-7040-H-PROGRAM in zero-padded 16-bit big-endian words."

  use Iconvex.Specs.PunchedCard.Transport,
    profile: Iconvex.Specs.IBM7040HProgram,
    endian: :big,
    canonical: "IBM-7040-H-PROGRAM-16BE",
    aliases: ["IBM-7040-H-PROGRAM-BE", "IBM-7044-H-PROGRAM-16BE"],
    codec_id: :ibm_7040_h_program_16be
end

defmodule Iconvex.Specs.IBM7040HProgram16LE do
  @moduledoc "IBM-7040-H-PROGRAM in zero-padded 16-bit little-endian words."

  use Iconvex.Specs.PunchedCard.Transport,
    profile: Iconvex.Specs.IBM7040HProgram,
    endian: :little,
    canonical: "IBM-7040-H-PROGRAM-16LE",
    aliases: ["IBM-7040-H-PROGRAM-LE", "IBM-7044-H-PROGRAM-16LE"],
    codec_id: :ibm_7040_h_program_16le
end

defmodule Iconvex.Specs.IBM1401Card do
  @moduledoc "IBM-1401-CARD logical 12-bit punched-card profile."

  use Iconvex.Specs.PunchedCard.Profile,
    canonical: "IBM-1401-CARD",
    aliases: ["IBM1401-CARD"],
    mappings: [
      {0x20, 0x000},
      {0x39, 0x001},
      {0x38, 0x002},
      {0x37, 0x004},
      {0x221A, 0x006},
      {0x36, 0x008},
      {0x3E, 0x00A},
      {0x35, 0x010},
      {0x3A, 0x012},
      {0x34, 0x020},
      {0x40, 0x022},
      {0x33, 0x040},
      {0x23, 0x042},
      {0x32, 0x080},
      {0x31, 0x100},
      {0x30, 0x200},
      {0x5A, 0x201},
      {0x59, 0x202},
      {0x58, 0x204},
      {0x29FB, 0x206},
      {0x57, 0x208},
      {0x27, 0x20A},
      {0x56, 0x210},
      {0x22CE, 0x212},
      {0x55, 0x220},
      {0x25, 0x222},
      {0x54, 0x240},
      {0x2C, 0x242},
      {0x53, 0x280},
      {0x2021, 0x282},
      {0x2F, 0x300},
      {0x2D, 0x400},
      {0x52, 0x401},
      {0x51, 0x402},
      {0x50, 0x404},
      {0x394, 0x406},
      {0x4F, 0x408},
      {0x3B, 0x40A},
      {0x4E, 0x410},
      {0x29, 0x412},
      {0x4D, 0x420},
      {0x2A, 0x422},
      {0x4C, 0x440},
      {0x24, 0x442},
      {0x4B, 0x480},
      {0x4A, 0x500},
      {0x21, 0x600},
      {0x26, 0x800},
      {0x49, 0x801},
      {0x48, 0x802},
      {0x47, 0x804},
      {0x2BD2, 0x806},
      {0x46, 0x808},
      {0x3C, 0x80A},
      {0x45, 0x810},
      {0x28, 0x812},
      {0x44, 0x820},
      {0x2311, 0x822},
      {0x43, 0x840},
      {0x2E, 0x842},
      {0x42, 0x880},
      {0x41, 0x900},
      {0x3F, 0xA00}
    ],
    decode_aliases: [],
    transports: [
      Iconvex.Specs.IBM1401Card16BE,
      Iconvex.Specs.IBM1401Card16LE
    ],
    source_sha256: "ab9d79ef05aa5c23e83f251c829607c2e9cb2dd89b368dd4565bcaff79af6ef9",
    source_url: "https://www.bitsavers.org/pdf/ibm/1401/A24-1403-5_1401_Reference_Apr62.pdf",
    source_pages: [184],
    printed_source_pages: ["170"]
end

defmodule Iconvex.Specs.IBM1401Card16BE do
  @moduledoc "IBM-1401-CARD in zero-padded 16-bit big-endian words."

  use Iconvex.Specs.PunchedCard.Transport,
    profile: Iconvex.Specs.IBM1401Card,
    endian: :big,
    canonical: "IBM-1401-CARD-16BE",
    aliases: ["IBM-1401-CARD-BE", "IBM1401-CARD-16BE"],
    codec_id: :ibm_1401_card_16be
end

defmodule Iconvex.Specs.IBM1401Card16LE do
  @moduledoc "IBM-1401-CARD in zero-padded 16-bit little-endian words."

  use Iconvex.Specs.PunchedCard.Transport,
    profile: Iconvex.Specs.IBM1401Card,
    endian: :little,
    canonical: "IBM-1401-CARD-16LE",
    aliases: ["IBM-1401-CARD-LE", "IBM1401-CARD-16LE"],
    codec_id: :ibm_1401_card_16le
end

defmodule Iconvex.Specs.CDC167BCDHollerith1965 do
  @moduledoc "CDC-167-BCD-HOLLERITH-1965 logical 12-bit punched-card profile."

  use Iconvex.Specs.PunchedCard.Profile,
    canonical: "CDC-167-BCD-HOLLERITH-1965",
    aliases: ["CDC-166-BCD-HOLLERITH-1965"],
    mappings: [
      {0x20, 0x000},
      {0x39, 0x001},
      {0x38, 0x002},
      {0x37, 0x004},
      {0x5B, 0x006},
      {0x36, 0x008},
      {0xAC, 0x00A},
      {0x35, 0x010},
      {0x2264, 0x012},
      {0x34, 0x020},
      {0x2260, 0x022},
      {0x33, 0x040},
      {0x3D, 0x042},
      {0x32, 0x080},
      {0x31, 0x100},
      {0x30, 0x200},
      {0x5A, 0x201},
      {0x59, 0x202},
      {0x58, 0x204},
      {0x7E, 0x206},
      {0x57, 0x208},
      {0x2261, 0x20A},
      {0x56, 0x210},
      {0x2192, 0x212},
      {0x55, 0x220},
      {0x28, 0x222},
      {0x54, 0x240},
      {0x2C, 0x242},
      {0x53, 0x280},
      {0x5D, 0x282},
      {0x2F, 0x300},
      {0x2D, 0x400},
      {0x52, 0x401},
      {0x51, 0x402},
      {0x50, 0x404},
      {0x3E, 0x406},
      {0x4F, 0x408},
      {0x2193, 0x40A},
      {0x4E, 0x410},
      {0x2191, 0x412},
      {0x4D, 0x420},
      {0x2A, 0x422},
      {0x4C, 0x440},
      {0x24, 0x442},
      {0x4B, 0x480},
      {0x4A, 0x500},
      {0x25, 0x600},
      {0x2B, 0x800},
      {0x49, 0x801},
      {0x48, 0x802},
      {0x47, 0x804},
      {0x3B, 0x806},
      {0x46, 0x808},
      {0x3F, 0x80A},
      {0x45, 0x810},
      {0x2265, 0x812},
      {0x44, 0x820},
      {0x29, 0x822},
      {0x43, 0x840},
      {0x2E, 0x842},
      {0x42, 0x880},
      {0x41, 0x900},
      {0x3C, 0xA00}
    ],
    decode_aliases: [],
    transports: [
      Iconvex.Specs.CDC167BCDHollerith1965_16BE,
      Iconvex.Specs.CDC167BCDHollerith1965_16LE
    ],
    source_sha256: "f3dce73c357934c252d54563b2d9271bc46e990a1ddbeda5f9f0c24967175bbd",
    source_url:
      "https://www.bitsavers.org/pdf/cdc/160/options/60022000D_167-2_Card_Reader_Reference_196502.pdf",
    source_pages: [13],
    printed_source_pages: ["2-6"]
end

defmodule Iconvex.Specs.CDC167BCDHollerith1965_16BE do
  @moduledoc "CDC-167-BCD-HOLLERITH-1965 in zero-padded 16-bit big-endian words."

  use Iconvex.Specs.PunchedCard.Transport,
    profile: Iconvex.Specs.CDC167BCDHollerith1965,
    endian: :big,
    canonical: "CDC-167-BCD-HOLLERITH-1965-16BE",
    aliases: ["CDC-167-BCD-HOLLERITH-16BE", "CDC-166-BCD-HOLLERITH-16BE"],
    codec_id: :cdc_167_bcd_hollerith_1965_16be
end

defmodule Iconvex.Specs.CDC167BCDHollerith1965_16LE do
  @moduledoc "CDC-167-BCD-HOLLERITH-1965 in zero-padded 16-bit little-endian words."

  use Iconvex.Specs.PunchedCard.Transport,
    profile: Iconvex.Specs.CDC167BCDHollerith1965,
    endian: :little,
    canonical: "CDC-167-BCD-HOLLERITH-1965-16LE",
    aliases: ["CDC-167-BCD-HOLLERITH-16LE", "CDC-166-BCD-HOLLERITH-16LE"],
    codec_id: :cdc_167_bcd_hollerith_1965_16le
end

defmodule Iconvex.Specs.CDC6000StandardHollerith1970 do
  @moduledoc "CDC-6000-STANDARD-HOLLERITH-1970 logical 12-bit punched-card profile."

  use Iconvex.Specs.PunchedCard.Profile,
    canonical: "CDC-6000-STANDARD-HOLLERITH-1970",
    aliases: ["CDC-6000-HOLLERITH-1970"],
    mappings: [
      {0x20, 0x000},
      {0x39, 0x001},
      {0x38, 0x002},
      {0x37, 0x004},
      {0x5B, 0x006},
      {0x36, 0x008},
      {0x35, 0x010},
      {0x2264, 0x012},
      {0x34, 0x020},
      {0x2260, 0x022},
      {0x33, 0x040},
      {0x3D, 0x042},
      {0x32, 0x080},
      {0x3A, 0x082},
      {0x31, 0x100},
      {0x30, 0x200},
      {0x5A, 0x201},
      {0x59, 0x202},
      {0x58, 0x204},
      {0x2227, 0x206},
      {0x57, 0x208},
      {0x2261, 0x20A},
      {0x56, 0x210},
      {0x2192, 0x212},
      {0x55, 0x220},
      {0x28, 0x222},
      {0x54, 0x240},
      {0x2C, 0x242},
      {0x53, 0x280},
      {0x5D, 0x282},
      {0x2F, 0x300},
      {0x2D, 0x400},
      {0x52, 0x401},
      {0x51, 0x402},
      {0x50, 0x404},
      {0x3E, 0x406},
      {0x4F, 0x408},
      {0x2193, 0x40A},
      {0x4E, 0x410},
      {0x2191, 0x412},
      {0x4D, 0x420},
      {0x2A, 0x422},
      {0x4C, 0x440},
      {0x24, 0x442},
      {0x4B, 0x480},
      {0x4A, 0x500},
      {0x2228, 0x600},
      {0x2B, 0x800},
      {0x49, 0x801},
      {0x48, 0x802},
      {0x47, 0x804},
      {0x3B, 0x806},
      {0x46, 0x808},
      {0xAC, 0x80A},
      {0x45, 0x810},
      {0x2265, 0x812},
      {0x44, 0x820},
      {0x29, 0x822},
      {0x43, 0x840},
      {0x2E, 0x842},
      {0x42, 0x880},
      {0x41, 0x900},
      {0x3C, 0xA00}
    ],
    decode_aliases: [
      {0x2228, 0x482},
      {0x3C, 0x882}
    ],
    transports: [
      Iconvex.Specs.CDC6000StandardHollerith1970_16BE,
      Iconvex.Specs.CDC6000StandardHollerith1970_16LE
    ],
    source_sha256: "275d0c2e8b3edacbd356f614d1e8ee0b63b9c159f0e1f68583e7169546b4810d",
    source_url:
      "https://bitsavers.org/pdf/cdc/graphics/44616800-03_Interactive_Graphics_System_Prelim_Ref_197001.pdf",
    source_pages: [193, 194],
    printed_source_pages: ["C-1", "C-2"]
end

defmodule Iconvex.Specs.CDC6000StandardHollerith1970_16BE do
  @moduledoc "CDC-6000-STANDARD-HOLLERITH-1970 in zero-padded 16-bit big-endian words."

  use Iconvex.Specs.PunchedCard.Transport,
    profile: Iconvex.Specs.CDC6000StandardHollerith1970,
    endian: :big,
    canonical: "CDC-6000-STANDARD-HOLLERITH-1970-16BE",
    aliases: ["CDC-6000-HOLLERITH-16BE", "CDC-6000-STANDARD-HOLLERITH-16BE"],
    codec_id: :cdc_6000_standard_hollerith_1970_16be
end

defmodule Iconvex.Specs.CDC6000StandardHollerith1970_16LE do
  @moduledoc "CDC-6000-STANDARD-HOLLERITH-1970 in zero-padded 16-bit little-endian words."

  use Iconvex.Specs.PunchedCard.Transport,
    profile: Iconvex.Specs.CDC6000StandardHollerith1970,
    endian: :little,
    canonical: "CDC-6000-STANDARD-HOLLERITH-1970-16LE",
    aliases: ["CDC-6000-HOLLERITH-16LE", "CDC-6000-STANDARD-HOLLERITH-16LE"],
    codec_id: :cdc_6000_standard_hollerith_1970_16le
end

defmodule Iconvex.Specs.BCDCDCIowa do
  @moduledoc """
  Source-qualified 12-bit reconstruction of the Iowa `BCD-CDC` punched-card table.

  This logical profile is deliberately not exposed under the ambiguous generic
  `BCD-CDC` name. Its exact source identity remains part of every public name.
  """

  use Iconvex.Specs.PunchedCard.Profile,
    canonical: "BCD-CDC-IOWA",
    aliases: ["BCD-CDC-IOWA-RECONSTRUCTED"],
    mappings: [
      {0x20, 0x000},
      {0x39, 0x001},
      {0x38, 0x002},
      {0x37, 0x004},
      {0x5B, 0x006},
      {0x36, 0x008},
      {0x25, 0x00A},
      {0x35, 0x010},
      {0x2264, 0x012},
      {0x34, 0x020},
      {0x2260, 0x022},
      {0x33, 0x040},
      {0x3D, 0x042},
      {0x32, 0x080},
      {0x3A, 0x082},
      {0x31, 0x100},
      {0x30, 0x200},
      {0x5A, 0x201},
      {0x59, 0x202},
      {0x58, 0x204},
      {0x2227, 0x206},
      {0x57, 0x208},
      {0x2261, 0x20A},
      {0x56, 0x210},
      {0x2192, 0x212},
      {0x55, 0x220},
      {0x28, 0x222},
      {0x54, 0x240},
      {0x2C, 0x242},
      {0x53, 0x280},
      {0x5D, 0x282},
      {0x2F, 0x300},
      {0x2D, 0x400},
      {0x52, 0x401},
      {0x51, 0x402},
      {0x50, 0x404},
      {0x3E, 0x406},
      {0x4F, 0x408},
      {0x2193, 0x40A},
      {0x4E, 0x410},
      {0x2191, 0x412},
      {0x4D, 0x420},
      {0x2A, 0x422},
      {0x4C, 0x440},
      {0x24, 0x442},
      {0x4B, 0x480},
      {0x4A, 0x500},
      {0x2228, 0x602},
      {0x2B, 0x800},
      {0x49, 0x801},
      {0x48, 0x802},
      {0x47, 0x804},
      {0x3B, 0x806},
      {0x46, 0x808},
      {0xAC, 0x80A},
      {0x45, 0x810},
      {0x2265, 0x812},
      {0x44, 0x820},
      {0x29, 0x822},
      {0x43, 0x840},
      {0x2E, 0x842},
      {0x42, 0x880},
      {0x3C, 0xA02},
      {0x41, 0x900}
    ],
    decode_aliases: [],
    transports: [
      Iconvex.Specs.BCDCDCIowa16BE,
      Iconvex.Specs.BCDCDCIowa16LE
    ],
    source_sha256: "824e61a9687f7fa0b9c9dd3c966ca02020bf8af1ab6671e9bd2e131f22f47b18",
    source_url: "https://homepage.cs.uiowa.edu/~jones/cards/codes.html",
    source_pages: ["Control Data Corporation section"],
    printed_source_pages: []
end

defmodule Iconvex.Specs.BCDCDCIowa16BE do
  @moduledoc "BCD-CDC-IOWA in zero-padded 16-bit big-endian words."

  use Iconvex.Specs.PunchedCard.Transport,
    profile: Iconvex.Specs.BCDCDCIowa,
    endian: :big,
    canonical: "BCD-CDC-IOWA-16BE",
    aliases: ["BCD-CDC-IOWA-RECONSTRUCTED-16BE"],
    codec_id: :bcd_cdc_iowa_16be
end

defmodule Iconvex.Specs.BCDCDCIowa16LE do
  @moduledoc "BCD-CDC-IOWA in zero-padded 16-bit little-endian words."

  use Iconvex.Specs.PunchedCard.Transport,
    profile: Iconvex.Specs.BCDCDCIowa,
    endian: :little,
    canonical: "BCD-CDC-IOWA-16LE",
    aliases: ["BCD-CDC-IOWA-RECONSTRUCTED-16LE"],
    codec_id: :bcd_cdc_iowa_16le
end

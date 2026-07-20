defmodule Iconvex.EscapeCodec do
  @moduledoc false
  import Bitwise

  @hex_digits {?0, ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?a, ?b, ?c, ?d, ?e, ?f}
  @compile {:inline, encode_c99_codepoint: 1, hex: 2, hex_digit: 1}

  def decode(%{id: id}, input), do: decode_loop(id, input, 0, [])
  def decode_chunk(%{id: id}, input, final?), do: decode_chunk_loop(id, input, 0, [], final?)
  def decode_prefix(%{id: id}, input, offset), do: decode_prefix_loop(id, input, 0, [], offset)
  def encode(%{id: id}, codepoints), do: encode_loop(id, codepoints, [])
  def encode_discard(%{id: id}, codepoints), do: encode_discard_loop(id, codepoints, [])

  def decode_error_consumption(:incomplete_sequence, sequence) when is_binary(sequence),
    do: max(byte_size(sequence), 1)

  def decode_error_consumption(_kind, _sequence), do: 1

  def encode_substitute(%{id: id}, codepoints, replacer) when is_function(replacer, 1),
    do: encode_substitute_loop(id, codepoints, replacer, [])

  @doc false
  def decode_to_explicit_ucs4_discard(%{id: id}, input, endian)
      when id in [:c99, :java] and is_binary(input) and endian in [:big, :little],
      do: decode_to_ucs4_discard(id, input, endian, <<>>)

  @doc false
  def encode_java_explicit_ucs4_discard(input, endian)
      when is_binary(input) and endian in [:big, :little] do
    if rem(byte_size(input), 4) == 0 do
      output =
        for <<unit::binary-size(4) <- input>>,
            codepoint = read_ucs4(unit, endian),
            codepoint <= 0x10FFFF,
            into: <<>>,
            do: encode_codepoint(:java, codepoint) |> elem(1)

      {:ok, output}
    else
      :miss
    end
  end

  @doc false
  def encode_c99_explicit_ucs4_discard(input, endian)
      when is_binary(input) and endian in [:big, :little] do
    if rem(byte_size(input), 4) == 0 do
      {:ok, encode_c99_explicit_ucs4(input, endian, [])}
    else
      :miss
    end
  end

  defp decode_loop(_id, <<>>, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_loop(:c99, <<byte, rest::binary>>, offset, acc) when byte < 0xA0 and byte != ?\\,
    do: decode_loop(:c99, rest, offset + 1, [byte | acc])

  defp decode_loop(:java, <<byte, rest::binary>>, offset, acc) when byte != ?\\,
    do: decode_loop(:java, rest, offset + 1, [byte | acc])

  defp decode_loop(id, <<?\\, _::binary>> = input, offset, acc) do
    case escaped(id, input) do
      {:ok, codepoint, consumed} ->
        <<_::binary-size(consumed), rest::binary>> = input
        decode_loop(id, rest, offset + consumed, [codepoint | acc])

      :literal ->
        <<_backslash, rest::binary>> = input
        decode_loop(id, rest, offset + 1, [?\\ | acc])

      :incomplete ->
        {:error, :incomplete_sequence, offset, input}

      :invalid ->
        {:error, :invalid_sequence, offset, <<?\\>>}
    end
  end

  defp decode_loop(_id, input, offset, _acc),
    do: {:error, :invalid_sequence, offset, binary_part(input, 0, 1)}

  defp decode_to_ucs4_discard(_id, <<>>, _endian, acc), do: {:ok, acc}

  defp decode_to_ucs4_discard(:c99, <<byte, rest::binary>>, endian, acc)
       when byte < 0xA0 and byte != ?\\,
       do: decode_to_ucs4_discard(:c99, rest, endian, append_ucs4(acc, byte, endian))

  defp decode_to_ucs4_discard(:java, <<byte, rest::binary>>, endian, acc) when byte != ?\\,
    do: decode_to_ucs4_discard(:java, rest, endian, append_ucs4(acc, byte, endian))

  defp decode_to_ucs4_discard(id, <<?\\, _::binary>> = input, endian, acc) do
    case escaped(id, input) do
      {:ok, codepoint, consumed} ->
        <<_::binary-size(consumed), rest::binary>> = input

        decode_to_ucs4_discard(
          id,
          rest,
          endian,
          append_ucs4(acc, codepoint, endian)
        )

      :literal ->
        <<_backslash, rest::binary>> = input
        decode_to_ucs4_discard(id, rest, endian, append_ucs4(acc, ?\\, endian))

      :incomplete ->
        {:ok, acc}

      :invalid ->
        <<_discarded, rest::binary>> = input
        decode_to_ucs4_discard(id, rest, endian, acc)
    end
  end

  defp decode_to_ucs4_discard(id, <<_discarded, rest::binary>>, endian, acc),
    do: decode_to_ucs4_discard(id, rest, endian, acc)

  defp decode_chunk_loop(_id, <<>>, _offset, acc, _final?),
    do: {:ok, :lists.reverse(acc), <<>>}

  defp decode_chunk_loop(:c99, <<byte, rest::binary>>, offset, acc, final?)
       when byte < 0xA0 and byte != ?\\,
       do: decode_chunk_loop(:c99, rest, offset + 1, [byte | acc], final?)

  defp decode_chunk_loop(:java, <<byte, rest::binary>>, offset, acc, final?)
       when byte != ?\\,
       do: decode_chunk_loop(:java, rest, offset + 1, [byte | acc], final?)

  defp decode_chunk_loop(id, <<?\\, _::binary>> = input, offset, acc, final?) do
    case escaped(id, input) do
      {:ok, codepoint, consumed} ->
        <<_::binary-size(consumed), rest::binary>> = input
        decode_chunk_loop(id, rest, offset + consumed, [codepoint | acc], final?)

      :literal ->
        <<_backslash, rest::binary>> = input
        decode_chunk_loop(id, rest, offset + 1, [?\\ | acc], final?)

      :incomplete when final? ->
        {:error, :incomplete_sequence, offset, input}

      :incomplete ->
        {:ok, :lists.reverse(acc), input}

      :invalid ->
        {:error, :invalid_sequence, offset, <<?\\>>}
    end
  end

  defp decode_chunk_loop(_id, input, offset, _acc, _final?),
    do: {:error, :invalid_sequence, offset, binary_part(input, 0, 1)}

  defp decode_prefix_loop(_id, _input, offset, acc, offset),
    do: {:ok, :lists.reverse(acc)}

  defp decode_prefix_loop(:c99, <<byte, rest::binary>>, offset, acc, target)
       when byte < 0xA0 and byte != ?\\,
       do: decode_prefix_loop(:c99, rest, offset + 1, [byte | acc], target)

  defp decode_prefix_loop(:java, <<byte, rest::binary>>, offset, acc, target)
       when byte != ?\\,
       do: decode_prefix_loop(:java, rest, offset + 1, [byte | acc], target)

  defp decode_prefix_loop(id, <<?\\, _::binary>> = input, offset, acc, target) do
    case escaped(id, input) do
      {:ok, codepoint, consumed} ->
        <<_::binary-size(consumed), rest::binary>> = input
        decode_prefix_loop(id, rest, offset + consumed, [codepoint | acc], target)

      :literal ->
        <<_backslash, rest::binary>> = input
        decode_prefix_loop(id, rest, offset + 1, [?\\ | acc], target)

      kind when kind in [:incomplete, :invalid] ->
        {:error, kind, offset}
    end
  end

  defp decode_prefix_loop(_id, input, offset, _acc, _target),
    do: {:error, :invalid_sequence, offset, binary_part(input, 0, 1)}

  defp escaped(:c99, <<?\\, ?u, hex::binary-size(4), _::binary>>),
    do: c99_value(hex, 6)

  defp escaped(:c99, <<?\\, ?U, hex::binary-size(8), _::binary>>),
    do: c99_value(hex, 10)

  defp escaped(:c99, <<?\\>>), do: :incomplete

  defp escaped(:c99, <<?\\, ?u, rest::binary>>) when byte_size(rest) < 4,
    do: if(hex_prefix?(rest), do: :incomplete, else: :literal)

  defp escaped(:c99, <<?\\, ?U, rest::binary>>) when byte_size(rest) < 8,
    do: if(hex_prefix?(rest), do: :incomplete, else: :literal)

  defp escaped(:c99, _input), do: :literal

  defp escaped(:java, <<?\\, ?u, high_hex::binary-size(4), rest::binary>>) do
    case hex_value(high_hex) do
      {:ok, high} when high in 0xD800..0xDBFF -> java_low(high, rest)
      {:ok, high} when high not in 0xD800..0xDFFF -> {:ok, high, 6}
      _ -> :literal
    end
  end

  defp escaped(:java, <<?\\>>), do: :incomplete

  defp escaped(:java, <<?\\, ?u, rest::binary>>) when byte_size(rest) < 4,
    do: if(hex_prefix?(rest), do: :incomplete, else: :literal)

  defp escaped(:java, _input), do: :literal

  defp java_low(high, <<?\\, ?u, low_hex::binary-size(4), _::binary>>) do
    case hex_value(low_hex) do
      {:ok, low} when low in 0xDC00..0xDFFF ->
        {:ok, 0x10000 + ((high - 0xD800) <<< 10) + low - 0xDC00, 12}

      _ ->
        :literal
    end
  end

  defp java_low(_high, <<>>), do: :incomplete
  defp java_low(_high, <<?\\>>), do: :incomplete

  defp java_low(_high, <<?\\, ?u, rest::binary>>) when byte_size(rest) < 4,
    do: if(hex_prefix?(rest), do: :incomplete, else: :literal)

  defp java_low(_high, _rest), do: :literal

  defp c99_value(hex, consumed) do
    case hex_value(hex) do
      {:ok, parsed} ->
        value = if consumed == 10, do: parsed &&& 0xFFFFFFFF, else: parsed

        if (value >= 0xA0 and value not in 0xD800..0xDFFF) or
             value in [0x24, 0x40, 0x60],
           do: {:ok, value, consumed},
           else: :invalid

      :error ->
        :literal
    end
  end

  defp encode_loop(_id, [], acc), do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_loop(id, [codepoint | rest], acc) do
    case encode_codepoint(id, codepoint) do
      {:ok, bytes} -> encode_loop(id, rest, [bytes | acc])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_discard_loop(_id, [], acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_discard_loop(id, [codepoint | rest], acc) do
    case encode_codepoint(id, codepoint) do
      {:ok, bytes} -> encode_discard_loop(id, rest, [bytes | acc])
      :error -> encode_discard_loop(id, rest, acc)
    end
  end

  defp encode_substitute_loop(_id, [], _replacer, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute_loop(id, [codepoint | rest], replacer, acc) do
    case encode_codepoint(id, codepoint) do
      {:ok, bytes} ->
        encode_substitute_loop(id, rest, replacer, [bytes | acc])

      :error ->
        case encode_loop(id, replacer.(codepoint), []) do
          {:ok, replacement} ->
            encode_substitute_loop(id, rest, replacer, [replacement | acc])

          error ->
            error
        end
    end
  end

  defp encode_codepoint(:c99, codepoint) when codepoint in 0..0x9F, do: {:ok, <<codepoint>>}

  defp encode_codepoint(:c99, codepoint) when codepoint in 0xA0..0xFFFF,
    do: {:ok, "\\u" <> hex(codepoint, 4)}

  defp encode_codepoint(:c99, codepoint) when codepoint in 0x10000..0xFFFFFFFF,
    do: {:ok, "\\U" <> hex(codepoint, 8)}

  defp encode_codepoint(:java, codepoint) when codepoint in 0..0x7F, do: {:ok, <<codepoint>>}

  defp encode_codepoint(:java, codepoint) when codepoint in 0x80..0xFFFF,
    do: {:ok, "\\u" <> hex(codepoint, 4)}

  defp encode_codepoint(:java, codepoint) when codepoint in 0x10000..0x10FFFF do
    value = codepoint - 0x10000
    high = 0xD800 + (value >>> 10)
    low = 0xDC00 + (value &&& 0x3FF)
    {:ok, "\\u" <> hex(high, 4) <> "\\u" <> hex(low, 4)}
  end

  defp encode_codepoint(_id, _codepoint), do: :error

  defp encode_c99_explicit_ucs4(<<>>, _endian, acc),
    do: acc |> :lists.reverse() |> IO.iodata_to_binary()

  defp encode_c99_explicit_ucs4(
         <<codepoint::unsigned-big-32, rest::binary>>,
         :big,
         acc
       ),
       do: encode_c99_explicit_ucs4(rest, :big, [encode_c99_codepoint(codepoint) | acc])

  defp encode_c99_explicit_ucs4(
         <<codepoint::unsigned-little-32, rest::binary>>,
         :little,
         acc
       ),
       do: encode_c99_explicit_ucs4(rest, :little, [encode_c99_codepoint(codepoint) | acc])

  defp encode_c99_codepoint(codepoint) when codepoint <= 0x9F, do: codepoint

  defp encode_c99_codepoint(codepoint) when codepoint <= 0xFFFF,
    do: <<?\\, ?u, hex(codepoint, 4)::binary>>

  defp encode_c99_codepoint(codepoint),
    do: <<?\\, ?U, hex(codepoint, 8)::binary>>

  defp hex_value(binary), do: hex_value(binary, byte_size(binary) - 1, 0)

  defp hex_value(<<>>, _position, value), do: {:ok, value}

  defp hex_value(<<byte, rest::binary>>, position, value) do
    case hex_nibble(byte) do
      :error -> :error
      nibble -> hex_value(rest, position - 1, value ||| nibble <<< (position * 4))
    end
  end

  defp hex_nibble(byte) when byte in ?0..?9, do: byte - ?0
  defp hex_nibble(byte) when byte in ?A..?Z, do: byte - ?A + 10
  defp hex_nibble(byte) when byte in ?a..?z, do: byte - ?a + 10
  defp hex_nibble(_byte), do: :error

  defp hex_prefix?(binary) do
    Enum.all?(:binary.bin_to_list(binary), &(hex_nibble(&1) != :error))
  end

  defp hex(value, 4) do
    <<hex_digit(value >>> 12), hex_digit(value >>> 8), hex_digit(value >>> 4), hex_digit(value)>>
  end

  defp hex(value, 8) do
    <<hex_digit(value >>> 28), hex_digit(value >>> 24), hex_digit(value >>> 20),
      hex_digit(value >>> 16), hex_digit(value >>> 12), hex_digit(value >>> 8),
      hex_digit(value >>> 4), hex_digit(value)>>
  end

  defp hex_digit(value), do: elem(@hex_digits, value &&& 0x0F)

  defp append_ucs4(acc, codepoint, :big), do: <<acc::binary, codepoint::unsigned-big-32>>

  defp append_ucs4(acc, codepoint, :little),
    do: <<acc::binary, codepoint::unsigned-little-32>>

  defp read_ucs4(<<value::unsigned-big-32>>, :big), do: value
  defp read_ucs4(<<value::unsigned-little-32>>, :little), do: value
end

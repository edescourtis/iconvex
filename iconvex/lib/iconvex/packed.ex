defmodule Iconvex.Packed.LSB do
  @moduledoc """
  Packed least-significant-bit-first fixed-width unit stream.

  `unit_bits` describes the logical unit width and is not limited to the
  byte-backed widths accepted by `Iconvex.Packed.pack_lsb/2`. Codecs with
  wider logical units can construct and validate this transport directly.
  """

  @enforce_keys [:data, :bit_size, :unit_bits]
  defstruct [:data, :bit_size, :unit_bits, bit_order: :lsb]

  @type t :: %__MODULE__{
          data: binary(),
          bit_size: non_neg_integer(),
          unit_bits: pos_integer(),
          bit_order: :lsb
        }
end

defmodule Iconvex.Packed do
  @moduledoc """
  Packed transports for codecs that expose one fixed-width unit per octet.

  `pack/2` returns an exact MSB-first Elixir bitstring. `pack_lsb/2` returns a
  byte-backed stream plus its exact bit length because LSB-first padding lives
  in the high bits of the final octet and cannot be represented by an Elixir
  bitstring without changing wire order.
  """

  import Bitwise
  alias Iconvex.Error
  alias Iconvex.Packed.LSB
  @chunk_bytes 4_096
  @chunk_groups 1_024

  @type width :: 1..8
  @type error_result ::
          {:error, :invalid_unit_bits | :invalid_bit_size | :nonzero_padding_bits}
          | {:error, :bit_order_mismatch}
          | {:error, :incomplete_unit, non_neg_integer(), bitstring() | non_neg_integer()}
          | {:error, :unit_out_of_range, non_neg_integer(), byte()}

  @doc "Packs one byte-backed unit at a time into an exact MSB-first bitstring."
  @spec pack(binary(), width()) :: {:ok, bitstring()} | error_result()
  def pack(units, 6) when is_binary(units), do: pack_msb6(units, 0, [], 0, [])

  def pack(units, width) when is_binary(units) and width in 1..8 do
    pack_msb(units, width, (1 <<< width) - 1, 0, 0, 0, [], 0, [])
  end

  def pack(_units, _width), do: {:error, :invalid_unit_bits}

  @doc "Unpacks an exact MSB-first bitstring into one unit per byte."
  @spec unpack(bitstring(), width()) :: {:ok, binary()} | error_result()
  def unpack(input, 6) when is_bitstring(input), do: unpack_msb6(input, 0, [], 0, [])

  def unpack(input, width) when is_bitstring(input) and width in 1..8,
    do: unpack_msb(input, width, 0, [], 0, [])

  def unpack(_input, _width), do: {:error, :invalid_unit_bits}

  @doc "Packs units LSB-first and returns byte data plus its exact meaningful bit count."
  @spec pack_lsb(binary(), width()) :: {:ok, LSB.t()} | error_result()
  def pack_lsb(units, 6) when is_binary(units) do
    with {:ok, data} <- pack_lsb6(units, 0, [], 0, []) do
      {:ok, %LSB{data: data, bit_size: byte_size(units) * 6, unit_bits: 6}}
    end
  end

  def pack_lsb(units, width) when is_binary(units) and width in 1..8 do
    with {:ok, data} <-
           pack_lsb_units(units, width, (1 <<< width) - 1, 0, 0, 0, [], 0, []) do
      {:ok, %LSB{data: data, bit_size: byte_size(units) * width, unit_bits: width}}
    end
  end

  def pack_lsb(_units, _width), do: {:error, :invalid_unit_bits}

  @doc "Unpacks validated LSB-first byte data using an explicit meaningful bit count."
  @spec unpack_lsb(binary(), non_neg_integer(), width()) ::
          {:ok, binary()} | error_result()
  def unpack_lsb(data, bit_size, width)
      when is_binary(data) and is_integer(bit_size) and bit_size >= 0 and width in 1..8 do
    cond do
      byte_size(data) != div(bit_size + 7, 8) ->
        {:error, :invalid_bit_size}

      rem(bit_size, width) != 0 ->
        complete = bit_size - rem(bit_size, width)
        {:error, :incomplete_unit, complete, bit_size - complete}

      nonzero_padding?(data, bit_size) ->
        {:error, :nonzero_padding_bits}

      width == 6 ->
        units = div(bit_size, width)
        unpack_lsb6(data, units, [], 0, [])

      true ->
        units = div(bit_size, width)
        unpack_lsb_units(data, width, (1 <<< width) - 1, units, 0, 0, [], 0, [])
    end
  end

  def unpack_lsb(_data, _bit_size, _width), do: {:error, :invalid_unit_bits}

  @doc "Converts UTF-8 through an octet-backed codec, then MSB-first packs its units."
  @spec encode_from_utf8(binary(), Iconvex.encoding(), width()) ::
          {:ok, bitstring()} | {:error, term()}
  def encode_from_utf8(input, encoding, width) do
    with {:ok, units} <- Iconvex.convert(input, "UTF-8", encoding),
         {:ok, packed} <- pack(units, width) do
      {:ok, packed}
    end
  end

  @doc """
  MSB-first unpacks units, then converts them from the named codec to UTF-8.

  Semantic conversion failures use physical bit offsets. Their sequence is
  the exact MSB-first packed bitstring occupied by the failing units.
  """
  @spec decode_to_utf8(bitstring(), Iconvex.encoding(), width()) ::
          {:ok, binary()} | {:error, term()}
  def decode_to_utf8(input, encoding, width) do
    with {:ok, units} <- unpack(input, width) do
      units
      |> Iconvex.convert(encoding, "UTF-8")
      |> packed_conversion_result(width, :msb)
    end
  end

  @doc "Converts UTF-8 through an octet-backed codec, then LSB-first packs its units."
  @spec encode_from_utf8_lsb(binary(), Iconvex.encoding(), width()) ::
          {:ok, LSB.t()} | {:error, term()}
  def encode_from_utf8_lsb(input, encoding, width) do
    with {:ok, units} <- Iconvex.convert(input, "UTF-8", encoding),
         {:ok, packed} <- pack_lsb(units, width) do
      {:ok, packed}
    end
  end

  @doc """
  Unpacks an LSB stream, then converts its units from the named codec to UTF-8.

  Semantic conversion failures use physical bit offsets. Their sequence is a
  self-describing `Iconvex.Packed.LSB` fragment so its wire order and exact
  meaningful bit length survive error reporting.
  """
  @spec decode_to_utf8_lsb(LSB.t(), Iconvex.encoding()) :: {:ok, binary()} | {:error, term()}
  def decode_to_utf8_lsb(%LSB{bit_order: bit_order}, _encoding) when bit_order != :lsb,
    do: {:error, :bit_order_mismatch}

  def decode_to_utf8_lsb(%LSB{} = input, encoding) do
    with {:ok, units} <- unpack_lsb(input.data, input.bit_size, input.unit_bits) do
      units
      |> Iconvex.convert(encoding, "UTF-8")
      |> packed_conversion_result(input.unit_bits, :lsb)
    end
  end

  defp packed_conversion_result(
         {:error,
          %Error{
            kind: kind,
            offset: unit_offset,
            sequence: sequence
          } = error},
         width,
         order
       )
       when kind in [:invalid_sequence, :incomplete_sequence] and
              is_integer(unit_offset) and is_binary(sequence) do
    {:ok, packed_sequence} = pack_error_sequence(sequence, width, order)

    {:error,
     Error.exception(
       kind: kind,
       encoding: error.encoding,
       offset: unit_offset * width,
       offset_unit: :bit,
       sequence: packed_sequence
     )}
  end

  defp packed_conversion_result(result, _width, _order), do: result

  defp pack_error_sequence(sequence, width, :msb), do: pack(sequence, width)
  defp pack_error_sequence(sequence, width, :lsb), do: pack_lsb(sequence, width)

  defp pack_msb6(<<a, b, c, d, rest::binary>>, offset, group_acc, count, chunks)
       when a < 64 and b < 64 and c < 64 and d < 64 do
    next_acc = [<<a::6, b::6, c::6, d::6>> | group_acc]

    if count == @chunk_groups - 1 do
      chunk = next_acc |> :lists.reverse() |> IO.iodata_to_binary()
      pack_msb6(rest, offset + 4, [], 0, [chunk | chunks])
    else
      pack_msb6(rest, offset + 4, next_acc, count + 1, chunks)
    end
  end

  defp pack_msb6(<<a, b, c, d, _rest::binary>>, offset, _group_acc, _count, _chunks) do
    cond do
      a >= 64 -> {:error, :unit_out_of_range, offset, a}
      b >= 64 -> {:error, :unit_out_of_range, offset + 1, b}
      c >= 64 -> {:error, :unit_out_of_range, offset + 2, c}
      d >= 64 -> {:error, :unit_out_of_range, offset + 3, d}
    end
  end

  defp pack_msb6(rest, offset, group_acc, _count, chunks) do
    with {:ok, tail} <- pack_msb6_tail(rest, offset) do
      prefix = finish_iodata(group_acc, chunks)
      {:ok, <<prefix::binary, tail::bitstring>>}
    end
  end

  defp pack_msb6_tail(<<>>, _offset), do: {:ok, <<>>}
  defp pack_msb6_tail(<<a>>, _offset) when a < 64, do: {:ok, <<a::6>>}
  defp pack_msb6_tail(<<a, b>>, _offset) when a < 64 and b < 64, do: {:ok, <<a::6, b::6>>}

  defp pack_msb6_tail(<<a, b, c>>, _offset) when a < 64 and b < 64 and c < 64,
    do: {:ok, <<a::6, b::6, c::6>>}

  defp pack_msb6_tail(rest, offset) do
    rest
    |> :binary.bin_to_list()
    |> Enum.with_index(offset)
    |> Enum.find_value(fn {unit, unit_offset} ->
      if unit >= 64, do: {:error, :unit_out_of_range, unit_offset, unit}
    end)
  end

  defp unpack_msb6(<<>>, _offset, byte_acc, _count, chunks),
    do: {:ok, finish_binary(byte_acc, chunks)}

  defp unpack_msb6(input, offset, _byte_acc, _count, _chunks) when bit_size(input) < 6,
    do: {:error, :incomplete_unit, offset, input}

  defp unpack_msb6(
         <<a::6, b::6, c::6, d::6, rest::bitstring>>,
         offset,
         byte_acc,
         count,
         chunks
       ) do
    {byte_acc, count, chunks} = push_byte(a, byte_acc, count, chunks)
    {byte_acc, count, chunks} = push_byte(b, byte_acc, count, chunks)
    {byte_acc, count, chunks} = push_byte(c, byte_acc, count, chunks)
    {byte_acc, count, chunks} = push_byte(d, byte_acc, count, chunks)
    unpack_msb6(rest, offset + 24, byte_acc, count, chunks)
  end

  defp unpack_msb6(<<unit::6, rest::bitstring>>, offset, byte_acc, count, chunks) do
    {byte_acc, count, chunks} = push_byte(unit, byte_acc, count, chunks)
    unpack_msb6(rest, offset + 6, byte_acc, count, chunks)
  end

  defp pack_lsb6(<<a, b, c, d, rest::binary>>, offset, group_acc, count, chunks)
       when a < 64 and b < 64 and c < 64 and d < 64 do
    value = a ||| b <<< 6 ||| c <<< 12 ||| d <<< 18
    next_acc = [<<value::24-little>> | group_acc]

    if count == @chunk_groups - 1 do
      chunk = next_acc |> :lists.reverse() |> IO.iodata_to_binary()
      pack_lsb6(rest, offset + 4, [], 0, [chunk | chunks])
    else
      pack_lsb6(rest, offset + 4, next_acc, count + 1, chunks)
    end
  end

  defp pack_lsb6(<<a, b, c, d, _rest::binary>>, offset, _group_acc, _count, _chunks) do
    cond do
      a >= 64 -> {:error, :unit_out_of_range, offset, a}
      b >= 64 -> {:error, :unit_out_of_range, offset + 1, b}
      c >= 64 -> {:error, :unit_out_of_range, offset + 2, c}
      d >= 64 -> {:error, :unit_out_of_range, offset + 3, d}
    end
  end

  defp pack_lsb6(rest, offset, group_acc, _count, chunks) do
    with {:ok, tail} <- pack_lsb6_tail(rest, offset) do
      prefix = finish_iodata(group_acc, chunks)
      {:ok, prefix <> tail}
    end
  end

  defp pack_lsb6_tail(<<>>, _offset), do: {:ok, <<>>}
  defp pack_lsb6_tail(<<a>>, _offset) when a < 64, do: {:ok, <<a>>}

  defp pack_lsb6_tail(<<a, b>>, _offset) when a < 64 and b < 64,
    do: {:ok, <<a ||| b <<< 6::16-little>>}

  defp pack_lsb6_tail(<<a, b, c>>, _offset) when a < 64 and b < 64 and c < 64,
    do: {:ok, <<a ||| b <<< 6 ||| c <<< 12::24-little>>}

  defp pack_lsb6_tail(rest, offset), do: pack_msb6_tail(rest, offset)

  defp unpack_lsb6(_data, 0, byte_acc, _count, chunks),
    do: {:ok, finish_binary(byte_acc, chunks)}

  defp unpack_lsb6(
         <<value::24-little, rest::binary>>,
         remaining,
         byte_acc,
         count,
         chunks
       )
       when remaining >= 4 do
    {byte_acc, count, chunks} = push_byte(value &&& 0x3F, byte_acc, count, chunks)
    {byte_acc, count, chunks} = push_byte(value >>> 6 &&& 0x3F, byte_acc, count, chunks)
    {byte_acc, count, chunks} = push_byte(value >>> 12 &&& 0x3F, byte_acc, count, chunks)
    {byte_acc, count, chunks} = push_byte(value >>> 18 &&& 0x3F, byte_acc, count, chunks)
    unpack_lsb6(rest, remaining - 4, byte_acc, count, chunks)
  end

  defp unpack_lsb6(data, remaining, byte_acc, count, chunks) do
    value = :binary.decode_unsigned(data, :little)
    unpack_lsb6_tail(value, remaining, byte_acc, count, chunks)
  end

  defp unpack_lsb6_tail(_value, 0, byte_acc, _count, chunks),
    do: {:ok, finish_binary(byte_acc, chunks)}

  defp unpack_lsb6_tail(value, remaining, byte_acc, count, chunks) do
    {byte_acc, count, chunks} = push_byte(value &&& 0x3F, byte_acc, count, chunks)
    unpack_lsb6_tail(value >>> 6, remaining - 1, byte_acc, count, chunks)
  end

  defp pack_msb(
         <<>>,
         _width,
         _mask,
         buffer,
         bits,
         _offset,
         byte_acc,
         _count,
         chunks
       ) do
    binary = finish_binary(byte_acc, chunks)

    if bits == 0,
      do: {:ok, binary},
      else: {:ok, <<binary::binary, buffer::size(bits)>>}
  end

  defp pack_msb(
         <<unit, rest::binary>>,
         width,
         mask,
         buffer,
         bits,
         offset,
         byte_acc,
         count,
         chunks
       )
       when unit <= mask do
    buffer = buffer <<< width ||| unit
    bits = bits + width

    if bits >= 8 do
      remaining = bits - 8
      byte = buffer >>> remaining &&& 0xFF
      buffer = buffer &&& (1 <<< remaining) - 1
      {byte_acc, count, chunks} = push_byte(byte, byte_acc, count, chunks)

      pack_msb(
        rest,
        width,
        mask,
        buffer,
        remaining,
        offset + 1,
        byte_acc,
        count,
        chunks
      )
    else
      pack_msb(rest, width, mask, buffer, bits, offset + 1, byte_acc, count, chunks)
    end
  end

  defp pack_msb(
         <<unit, _rest::binary>>,
         _width,
         _mask,
         _buffer,
         _bits,
         offset,
         _byte_acc,
         _count,
         _chunks
       ),
       do: {:error, :unit_out_of_range, offset, unit}

  defp unpack_msb(<<>>, _width, _offset, byte_acc, _count, chunks),
    do: {:ok, finish_binary(byte_acc, chunks)}

  defp unpack_msb(input, width, offset, _byte_acc, _count, _chunks)
       when bit_size(input) < width,
       do: {:error, :incomplete_unit, offset, input}

  defp unpack_msb(input, width, offset, byte_acc, count, chunks) do
    <<unit::size(width), rest::bitstring>> = input
    {byte_acc, count, chunks} = push_byte(unit, byte_acc, count, chunks)
    unpack_msb(rest, width, offset + width, byte_acc, count, chunks)
  end

  defp pack_lsb_units(
         <<>>,
         _width,
         _mask,
         buffer,
         bits,
         _offset,
         byte_acc,
         count,
         chunks
       ) do
    {byte_acc, _count, chunks} =
      if bits == 0,
        do: {byte_acc, count, chunks},
        else: push_byte(buffer &&& 0xFF, byte_acc, count, chunks)

    {:ok, finish_binary(byte_acc, chunks)}
  end

  defp pack_lsb_units(
         <<unit, rest::binary>>,
         width,
         mask,
         buffer,
         bits,
         offset,
         byte_acc,
         count,
         chunks
       )
       when unit <= mask do
    buffer = buffer ||| unit <<< bits
    bits = bits + width

    {buffer, bits, byte_acc, count, chunks} =
      emit_octets(buffer, bits, byte_acc, count, chunks)

    pack_lsb_units(
      rest,
      width,
      mask,
      buffer,
      bits,
      offset + 1,
      byte_acc,
      count,
      chunks
    )
  end

  defp pack_lsb_units(
         <<unit, _rest::binary>>,
         _width,
         _mask,
         _buffer,
         _bits,
         offset,
         _byte_acc,
         _count,
         _chunks
       ),
       do: {:error, :unit_out_of_range, offset, unit}

  defp emit_octets(buffer, bits, byte_acc, count, chunks) when bits >= 8 do
    {byte_acc, count, chunks} = push_byte(buffer &&& 0xFF, byte_acc, count, chunks)
    emit_octets(buffer >>> 8, bits - 8, byte_acc, count, chunks)
  end

  defp emit_octets(buffer, bits, byte_acc, count, chunks),
    do: {buffer, bits, byte_acc, count, chunks}

  defp unpack_lsb_units(
         _data,
         _width,
         _mask,
         0,
         _buffer,
         _bits,
         byte_acc,
         _count,
         chunks
       ),
       do: {:ok, finish_binary(byte_acc, chunks)}

  defp unpack_lsb_units(
         data,
         width,
         mask,
         remaining,
         buffer,
         bits,
         byte_acc,
         count,
         chunks
       )
       when bits >= width do
    unit = buffer &&& mask
    {byte_acc, count, chunks} = push_byte(unit, byte_acc, count, chunks)

    unpack_lsb_units(
      data,
      width,
      mask,
      remaining - 1,
      buffer >>> width,
      bits - width,
      byte_acc,
      count,
      chunks
    )
  end

  defp unpack_lsb_units(
         <<byte, rest::binary>>,
         width,
         mask,
         remaining,
         buffer,
         bits,
         byte_acc,
         count,
         chunks
       ),
       do:
         unpack_lsb_units(
           rest,
           width,
           mask,
           remaining,
           buffer ||| byte <<< bits,
           bits + 8,
           byte_acc,
           count,
           chunks
         )

  defp push_byte(byte, byte_acc, count, chunks) when count == @chunk_bytes - 1 do
    chunk = [byte | byte_acc] |> :lists.reverse() |> :erlang.list_to_binary()
    {[], 0, [chunk | chunks]}
  end

  defp push_byte(byte, byte_acc, count, chunks),
    do: {[byte | byte_acc], count + 1, chunks}

  defp finish_binary([], chunks),
    do: chunks |> :lists.reverse() |> IO.iodata_to_binary()

  defp finish_binary(byte_acc, chunks) do
    chunk = byte_acc |> :lists.reverse() |> :erlang.list_to_binary()
    [chunk | chunks] |> :lists.reverse() |> IO.iodata_to_binary()
  end

  defp finish_iodata([], chunks),
    do: chunks |> :lists.reverse() |> IO.iodata_to_binary()

  defp finish_iodata(group_acc, chunks) do
    chunk = group_acc |> :lists.reverse() |> IO.iodata_to_binary()
    [chunk | chunks] |> :lists.reverse() |> IO.iodata_to_binary()
  end

  defp nonzero_padding?(<<>>, 0), do: false

  defp nonzero_padding?(data, bit_size) do
    case rem(bit_size, 8) do
      0 -> false
      used -> (:binary.last(data) &&& bnot((1 <<< used) - 1)) != 0
    end
  end
end

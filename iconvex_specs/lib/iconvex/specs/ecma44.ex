defmodule Iconvex.Specs.ECMA44.SourceAsset do
  @moduledoc false

  import Bitwise

  @expected_header "high_nibble,0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F"
  @expected_rows Enum.map(0..15, &(Integer.to_string(&1, 16) |> String.upcase()))
  @mask_pattern ~r/\A[0-9A-F]{3}\z/

  def validate!(table_bytes, options) when is_binary(table_bytes) and is_list(options) do
    verify_sha!(table_bytes, Keyword.fetch!(options, :source_table_sha256))
    expected_masks = Keyword.fetch!(options, :expected_masks)

    lines = String.split(table_bytes, "\n", trim: false)

    unless List.last(lines) == "" do
      raise "ECMA-44 source table must end with exactly one LF"
    end

    case Enum.drop(lines, -1) do
      [@expected_header | rows] -> parse_rows!(rows, expected_masks)
      [header | _rows] -> raise "unexpected ECMA-44 table header: #{inspect(header)}"
      [] -> raise "unexpected ECMA-44 table header: missing"
    end
  end

  defp verify_sha!(bytes, expected) do
    actual = bytes |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

    unless actual == expected do
      raise "ECMA-44 source table SHA-256 mismatch: expected #{expected}, got #{actual}"
    end
  end

  defp parse_rows!(rows, expected_masks) do
    unless length(rows) == 16 do
      raise "ECMA-44 source table must contain exactly sixteen data rows"
    end

    masks =
      @expected_rows
      |> Enum.zip(rows)
      |> Enum.flat_map(fn {expected_row, row} -> parse_row!(row, expected_row) end)
      |> List.to_tuple()

    unless tuple_size(masks) == 256 and
             masks |> Tuple.to_list() |> Enum.uniq() |> length() == 256 do
      raise "ECMA-44 source table must contain 256 unique masks"
    end

    unless Enum.all?(Tuple.to_list(masks), &physically_valid_mask?/1) do
      raise "ECMA-44 source table contains a physically invalid punched-card mask"
    end

    unless masks == expected_masks do
      raise "ECMA-44 source table does not match the hardcoded runtime mask tuple"
    end

    masks
  end

  defp parse_row!(row, expected_row) do
    case String.split(row, ",") do
      [^expected_row | cells] when length(cells) == 16 ->
        Enum.map(cells, &parse_mask!/1)

      [actual_row | _cells] ->
        raise "unexpected ECMA-44 high-nibble row: expected #{expected_row}, got #{actual_row}"

      [] ->
        raise "missing ECMA-44 high-nibble row #{expected_row}"
    end
  end

  defp parse_mask!(cell) do
    unless Regex.match?(@mask_pattern, cell) do
      raise "invalid ECMA-44 mask cell: #{inspect(cell)}"
    end

    String.to_integer(cell, 16)
  end

  defp physically_valid_mask?(mask) do
    digit = mask &&& 0x1FC
    digit == 0 or (digit &&& digit - 1) == 0
  end
end

defmodule Iconvex.Specs.ECMA44 do
  @moduledoc """
  Raw ECMA-44 code-combination to punched-card transport.

  This module maps opaque seven-bit or eight-bit code combinations to named
  physical rows on a twelve-row punched card. It deliberately does not use
  `Iconvex.Codec`, map bytes to Unicode scalars, or register names in the
  Unicode conversion pipeline.

  ECMA-44 defines physical card rows, not a serialized bit or byte order. The
  packed MSB, packed LSB, and zero-padded 16-bit word forms are explicit
  Iconvex library transports around the normative code-combination table.
  """

  import Bitwise
  alias Iconvex.Packed.LSB

  @chunk_units 4_096
  @source_dir Path.expand("../../../priv/sources/ecma-44", __DIR__)
  @source_table Path.join(@source_dir, "ecma44_table.csv")
  @source_metadata Path.join(@source_dir, "SOURCE_METADATA.md")
  @external_resource @source_table
  @external_resource @source_metadata
  @source_url "https://www.ecma-international.org/wp-content/uploads/ECMA-44_1st_edition_september_1975.pdf"
  @source_sha256 "09b71ed57db7a0b2c1e9bc7006f001df198450f37b706c01d2754ddb5a5de228"
  @source_table_sha256 "834abb8180af52f790f09ace4f6bc75953a2c8e0df98bb5dcb33f62d3a644995"
  @table_u16be_sha256 "bf6d824c690380439344c99e4ba68887241305b243456390aa23b8d94cc68119"
  @table_packed_msb_sha256 "218cced6aee83c5ec3fa8823761556c60f872ea367d24c66e2dd43a5b83b6a75"

  # Table 1 byte order, independently checked against the inverse Table 2.
  @masks {
    0xB03,
    0x901,
    0x881,
    0x841,
    0x005,
    0x213,
    0x20B,
    0x207,
    0x409,
    0x811,
    0x211,
    0x843,
    0x823,
    0x813,
    0x80B,
    0x807,
    0xD03,
    0x501,
    0x481,
    0x441,
    0x023,
    0x013,
    0x081,
    0x209,
    0x403,
    0x503,
    0x007,
    0x205,
    0x423,
    0x413,
    0x40B,
    0x407,
    0x000,
    0x806,
    0x006,
    0x042,
    0x442,
    0x222,
    0x800,
    0x012,
    0x812,
    0x412,
    0x422,
    0x80A,
    0x242,
    0x400,
    0x842,
    0x300,
    0x200,
    0x100,
    0x080,
    0x040,
    0x020,
    0x010,
    0x008,
    0x004,
    0x002,
    0x001,
    0x082,
    0x40A,
    0x822,
    0x00A,
    0x20A,
    0x206,
    0x022,
    0x900,
    0x880,
    0x840,
    0x820,
    0x810,
    0x808,
    0x804,
    0x802,
    0x801,
    0x500,
    0x480,
    0x440,
    0x420,
    0x410,
    0x408,
    0x404,
    0x402,
    0x401,
    0x280,
    0x240,
    0x220,
    0x210,
    0x208,
    0x204,
    0x202,
    0x201,
    0x882,
    0x282,
    0x482,
    0x406,
    0x212,
    0x102,
    0xB00,
    0xA80,
    0xA40,
    0xA20,
    0xA10,
    0xA08,
    0xA04,
    0xA02,
    0xA01,
    0xD00,
    0xC80,
    0xC40,
    0xC20,
    0xC10,
    0xC08,
    0xC04,
    0xC02,
    0xC01,
    0x680,
    0x640,
    0x620,
    0x610,
    0x608,
    0x604,
    0x602,
    0x601,
    0xA00,
    0xC00,
    0x600,
    0x700,
    0x805,
    0x703,
    0x301,
    0x281,
    0x241,
    0x221,
    0x411,
    0x809,
    0x405,
    0x203,
    0x303,
    0x283,
    0x243,
    0x223,
    0x903,
    0x883,
    0x443,
    0xF03,
    0x101,
    0x483,
    0x041,
    0x021,
    0x011,
    0x009,
    0x803,
    0x003,
    0x103,
    0x083,
    0x043,
    0x821,
    0x421,
    0x00B,
    0x701,
    0xB01,
    0xA81,
    0xA41,
    0xA21,
    0xA11,
    0xA09,
    0xA05,
    0xA03,
    0x902,
    0xD01,
    0xC81,
    0xC41,
    0xC21,
    0xC11,
    0xC09,
    0xC05,
    0xC03,
    0x502,
    0x681,
    0x641,
    0x621,
    0x611,
    0x609,
    0x605,
    0x603,
    0x302,
    0xE00,
    0xF01,
    0xE81,
    0xE41,
    0xE21,
    0xE11,
    0xE09,
    0xE05,
    0xE03,
    0xB02,
    0xA82,
    0xA42,
    0xA22,
    0xA12,
    0xA0A,
    0xA06,
    0xD02,
    0xC82,
    0xC42,
    0xC22,
    0xC12,
    0xC0A,
    0xC06,
    0x702,
    0x682,
    0x642,
    0x622,
    0x612,
    0x60A,
    0x606,
    0xF02,
    0xF00,
    0xE80,
    0xE40,
    0xE20,
    0xE10,
    0xE08,
    0xE04,
    0xE02,
    0xE01,
    0xE82,
    0xE42,
    0xE22,
    0xE12,
    0xE0A,
    0xE06,
    0xA83,
    0xA43,
    0xA23,
    0xA13,
    0xA0B,
    0xA07,
    0xC83,
    0xC43,
    0xC23,
    0xC13,
    0xC0B,
    0xC07,
    0x683,
    0x643,
    0x623,
    0x613,
    0x60B,
    0x607,
    0xE83,
    0xE43,
    0xE23,
    0xE13,
    0xE0B,
    0xE07
  }

  Iconvex.Specs.ECMA44.SourceAsset.validate!(File.read!(@source_table),
    source_table_sha256: @source_table_sha256,
    expected_masks: @masks
  )

  @decode @masks
          |> Tuple.to_list()
          |> Enum.with_index()
          |> Enum.reduce(:erlang.make_tuple(4_096, nil), fn {mask, byte}, table ->
            put_elem(table, mask, byte)
          end)

  @type mode :: :seven_bit | :eight_bit
  @type endian :: :big | :little

  @doc "Returns false because ECMA-44 binds raw code combinations, not Unicode."
  def unicode_character_encoding?, do: false

  @doc "ECMA-44 does not define a packed bit order."
  def standard_packed_order, do: nil

  @doc "Returns the two explicit library serialization orders."
  def library_packed_orders, do: [:msb, :lsb]

  def source_url, do: @source_url
  def source_sha256, do: @source_sha256
  def source_table_sha256, do: @source_table_sha256
  def source_pages, do: [9, 11]
  def printed_source_pages, do: ["4", "6"]
  def table_u16be_sha256, do: @table_u16be_sha256
  def table_packed_msb_sha256, do: @table_packed_msb_sha256

  @doc "Returns whether a mask obeys ECMA-44 clause 3.2's physical punch rule."
  def physically_valid_mask?(mask) when is_integer(mask) and mask in 0..0xFFF do
    digit = mask &&& 0x1FC
    digit == 0 or (digit &&& digit - 1) == 0
  end

  def physically_valid_mask?(_mask), do: false

  @doc "Maps raw code-combination bytes to physical 12-bit masks."
  @spec encode_masks(binary(), mode()) ::
          {:ok, [0..0xFFF]}
          | {:error, :invalid_code_combination, non_neg_integer(), byte()}
          | {:error, :invalid_mode | :invalid_input}
  def encode_masks(input, mode) when is_binary(input) do
    with {:ok, maximum} <- mode_maximum(mode) do
      encode_masks_all(input, maximum, 0, [])
    end
  end

  def encode_masks(_input, mode) do
    with {:ok, _maximum} <- mode_maximum(mode), do: {:error, :invalid_input}
  end

  @doc "Maps physical masks back to raw code-combination bytes."
  @spec decode_masks([term()], mode()) ::
          {:ok, binary()}
          | {:error, :invalid_sequence | :mask_out_of_range, non_neg_integer(), term()}
          | {:error, :invalid_mode | :invalid_input}
  def decode_masks(masks, mode) when is_list(masks) do
    with {:ok, maximum} <- mode_maximum(mode) do
      decode_masks_all(masks, maximum, 0, [], 0, [])
    end
  end

  def decode_masks(_masks, mode) do
    with {:ok, _maximum} <- mode_maximum(mode), do: {:error, :invalid_input}
  end

  @doc "Encodes raw code combinations as a contiguous MSB-first 12-bit bitstring."
  @spec encode_packed(binary(), mode()) :: {:ok, bitstring()} | {:error, term()}
  def encode_packed(input, mode) when is_binary(input) do
    with {:ok, maximum} <- mode_maximum(mode) do
      encode_packed_all(input, maximum, 0, [], 0, [])
    end
  end

  def encode_packed(_input, mode) do
    with {:ok, _maximum} <- mode_maximum(mode), do: {:error, :invalid_input}
  end

  @doc "Decodes a contiguous MSB-first 12-bit bitstring to raw bytes."
  @spec decode_packed(bitstring(), mode()) :: {:ok, binary()} | {:error, term()}
  def decode_packed(input, mode) when is_bitstring(input) do
    with {:ok, maximum} <- mode_maximum(mode) do
      decode_packed_all(input, maximum, 0, [], 0, [])
    end
  end

  def decode_packed(_input, mode) do
    with {:ok, _maximum} <- mode_maximum(mode), do: {:error, :invalid_input}
  end

  @doc "Encodes raw code combinations in the explicit library LSB-first container."
  @spec encode_packed_lsb(binary(), mode()) :: {:ok, LSB.t()} | {:error, term()}
  def encode_packed_lsb(input, mode) when is_binary(input) do
    with {:ok, maximum} <- mode_maximum(mode) do
      encode_packed_lsb_all(input, maximum, 0, [], 0, [])
    end
  end

  def encode_packed_lsb(_input, mode) do
    with {:ok, _maximum} <- mode_maximum(mode), do: {:error, :invalid_input}
  end

  @doc "Decodes a validated explicit library LSB-first container to raw bytes."
  @spec decode_packed_lsb(LSB.t(), mode()) :: {:ok, binary()} | {:error, term()}
  def decode_packed_lsb(%LSB{} = input, mode) do
    with {:ok, maximum} <- mode_maximum(mode) do
      decode_packed_lsb_transport(input, maximum)
    end
  end

  def decode_packed_lsb(_input, mode) do
    with {:ok, _maximum} <- mode_maximum(mode),
         do: {:error, :invalid_packed_transport}
  end

  @doc "Encodes raw code combinations as zero-padded 16-bit words."
  @spec encode_words(binary(), mode(), endian()) :: {:ok, binary()} | {:error, term()}
  def encode_words(input, mode, endian) when is_binary(input) and endian in [:big, :little] do
    with {:ok, maximum} <- mode_maximum(mode) do
      encode_words_all(input, maximum, endian, 0, [], 0, [])
    end
  end

  def encode_words(_input, mode, endian) do
    with {:ok, _maximum} <- mode_maximum(mode),
         true <- endian in [:big, :little] || {:error, :invalid_endian},
         do: {:error, :invalid_input}
  end

  @doc "Decodes zero-padded 16-bit words to raw code-combination bytes."
  @spec decode_words(binary(), mode(), endian()) :: {:ok, binary()} | {:error, term()}
  def decode_words(input, mode, endian) when is_binary(input) and endian in [:big, :little] do
    with {:ok, maximum} <- mode_maximum(mode) do
      decode_words_all(input, maximum, endian, 0, [], 0, [])
    end
  end

  def decode_words(_input, mode, endian) do
    with {:ok, _maximum} <- mode_maximum(mode),
         true <- endian in [:big, :little] || {:error, :invalid_endian},
         do: {:error, :invalid_input}
  end

  @doc "Decodes complete MSB-packed units and returns a non-final partial unit."
  @spec decode_packed_chunk(bitstring(), mode(), boolean()) ::
          {:ok, binary(), bitstring()} | {:error, term()}
  def decode_packed_chunk(input, mode, final?)
      when is_bitstring(input) and is_boolean(final?) do
    stable_size = bit_size(input) - rem(bit_size(input), 12)
    <<stable::bitstring-size(stable_size), pending::bitstring>> = input

    case decode_packed(stable, mode) do
      {:ok, _bytes} when final? and bit_size(pending) != 0 ->
        {:error, :incomplete_sequence, stable_size, pending}

      {:ok, bytes} ->
        {:ok, bytes, pending}

      error ->
        error
    end
  end

  def decode_packed_chunk(_input, mode, _final?) do
    with {:ok, _maximum} <- mode_maximum(mode), do: {:error, :invalid_input}
  end

  @doc "Decodes complete 16-bit words and returns a non-final partial word."
  @spec decode_words_chunk(binary(), mode(), endian(), boolean()) ::
          {:ok, binary(), binary()} | {:error, term()}
  def decode_words_chunk(input, mode, endian, final?)
      when is_binary(input) and endian in [:big, :little] and is_boolean(final?) do
    stable_size = byte_size(input) - rem(byte_size(input), 2)
    <<stable::binary-size(stable_size), pending::binary>> = input

    case decode_words(stable, mode, endian) do
      {:ok, _bytes} when final? and pending != <<>> ->
        {:error, :incomplete_sequence, stable_size, pending}

      {:ok, bytes} ->
        {:ok, bytes, pending}

      error ->
        error
    end
  end

  def decode_words_chunk(_input, mode, endian, _final?) do
    with {:ok, _maximum} <- mode_maximum(mode),
         true <- endian in [:big, :little] || {:error, :invalid_endian},
         do: {:error, :invalid_input}
  end

  defp encode_masks_all(<<>>, _maximum, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp encode_masks_all(<<byte, rest::binary>>, maximum, offset, acc)
       when byte <= maximum,
       do: encode_masks_all(rest, maximum, offset + 1, [elem(@masks, byte) | acc])

  defp encode_masks_all(<<byte, _rest::binary>>, _maximum, offset, _acc),
    do: {:error, :invalid_code_combination, offset, byte}

  defp decode_masks_all([], _maximum, _offset, byte_acc, _count, chunks),
    do: {:ok, finish_binary(byte_acc, chunks)}

  defp decode_masks_all([mask | rest], maximum, offset, byte_acc, count, chunks)
       when is_integer(mask) and mask in 0..0xFFF do
    case decoded(mask, maximum) do
      byte when is_integer(byte) ->
        {byte_acc, count, chunks} = push_byte(byte, byte_acc, count, chunks)
        decode_masks_all(rest, maximum, offset + 1, byte_acc, count, chunks)

      nil ->
        {:error, :invalid_sequence, offset, mask}
    end
  end

  defp decode_masks_all([mask | _rest], _maximum, offset, _byte_acc, _count, _chunks),
    do: {:error, :mask_out_of_range, offset, mask}

  defp encode_packed_all(<<>>, _maximum, _offset, acc, _count, chunks),
    do: {:ok, finish_bitstring(acc, chunks)}

  defp encode_packed_all(<<byte, rest::binary>>, maximum, offset, acc, count, chunks)
       when byte <= maximum do
    {acc, count, chunks} = push_bitstring(<<elem(@masks, byte)::12>>, acc, count, chunks)
    encode_packed_all(rest, maximum, offset + 1, acc, count, chunks)
  end

  defp encode_packed_all(<<byte, _rest::binary>>, _maximum, offset, _acc, _count, _chunks),
    do: {:error, :invalid_code_combination, offset, byte}

  defp decode_packed_all(<<>>, _maximum, _offset, byte_acc, _count, chunks),
    do: {:ok, finish_binary(byte_acc, chunks)}

  defp decode_packed_all(input, _maximum, offset, _byte_acc, _count, _chunks)
       when bit_size(input) < 12,
       do: {:error, :incomplete_sequence, offset, input}

  defp decode_packed_all(
         <<mask::12, rest::bitstring>>,
         maximum,
         offset,
         byte_acc,
         count,
         chunks
       ) do
    case decoded(mask, maximum) do
      byte when is_integer(byte) ->
        {byte_acc, count, chunks} = push_byte(byte, byte_acc, count, chunks)
        decode_packed_all(rest, maximum, offset + 12, byte_acc, count, chunks)

      nil ->
        {:error, :invalid_sequence, offset, <<mask::12>>}
    end
  end

  defp encode_packed_lsb_all(<<>>, _maximum, units, acc, _count, chunks) do
    {:ok,
     %LSB{
       data: finish_binary(acc, chunks),
       bit_size: units * 12,
       unit_bits: 12
     }}
  end

  defp encode_packed_lsb_all(
         <<first, second, rest::binary>>,
         maximum,
         units,
         acc,
         count,
         chunks
       ) do
    cond do
      first > maximum ->
        {:error, :invalid_code_combination, units, first}

      second > maximum ->
        {:error, :invalid_code_combination, units + 1, second}

      true ->
        value = elem(@masks, first) ||| elem(@masks, second) <<< 12
        {acc, count, chunks} = push_binary(<<value::24-little>>, acc, count, chunks)
        encode_packed_lsb_all(rest, maximum, units + 2, acc, count, chunks)
    end
  end

  defp encode_packed_lsb_all(<<last>>, maximum, units, acc, _count, chunks)
       when last <= maximum do
    data = finish_binary([<<elem(@masks, last)::16-little>> | acc], chunks)
    {:ok, %LSB{data: data, bit_size: (units + 1) * 12, unit_bits: 12}}
  end

  defp encode_packed_lsb_all(<<byte>>, _maximum, units, _acc, _count, _chunks),
    do: {:error, :invalid_code_combination, units, byte}

  defp decode_packed_lsb_transport(%LSB{bit_order: bit_order}, _maximum)
       when bit_order != :lsb,
       do: {:error, :bit_order_mismatch}

  defp decode_packed_lsb_transport(%LSB{unit_bits: unit_bits}, _maximum)
       when unit_bits != 12,
       do: {:error, :unit_width_mismatch}

  defp decode_packed_lsb_transport(%LSB{data: data, bit_size: bit_size}, maximum)
       when is_binary(data) and is_integer(bit_size) and bit_size >= 0 do
    expected_bytes = div(bit_size + 7, 8)

    cond do
      byte_size(data) != expected_bytes ->
        {:error, :invalid_bit_size}

      rem(bit_size, 12) != 0 ->
        complete = bit_size - rem(bit_size, 12)
        {:error, :incomplete_unit, complete, bit_size - complete}

      nonzero_lsb_padding?(data, bit_size) ->
        {:error, :nonzero_padding_bits}

      true ->
        decode_lsb_units(data, div(bit_size, 12), maximum, 0, [], 0, [])
    end
  end

  defp decode_packed_lsb_transport(_input, _maximum),
    do: {:error, :invalid_packed_transport}

  defp decode_lsb_units(_data, 0, _maximum, _offset, byte_acc, _count, chunks),
    do: {:ok, finish_binary(byte_acc, chunks)}

  defp decode_lsb_units(
         <<value::24-little, rest::binary>>,
         units,
         maximum,
         offset,
         byte_acc,
         count,
         chunks
       )
       when units >= 2 do
    first = value &&& 0xFFF
    second = value >>> 12 &&& 0xFFF

    case decoded(first, maximum) do
      byte when is_integer(byte) ->
        {byte_acc, count, chunks} = push_byte(byte, byte_acc, count, chunks)

        case decoded(second, maximum) do
          byte when is_integer(byte) ->
            {byte_acc, count, chunks} = push_byte(byte, byte_acc, count, chunks)

            decode_lsb_units(
              rest,
              units - 2,
              maximum,
              offset + 24,
              byte_acc,
              count,
              chunks
            )

          nil ->
            {:error, :invalid_sequence, offset + 12, second}
        end

      nil ->
        {:error, :invalid_sequence, offset, first}
    end
  end

  defp decode_lsb_units(
         <<value::16-little>>,
         1,
         maximum,
         offset,
         byte_acc,
         count,
         chunks
       ) do
    mask = value &&& 0xFFF

    case decoded(mask, maximum) do
      byte when is_integer(byte) ->
        {byte_acc, _count, chunks} = push_byte(byte, byte_acc, count, chunks)
        {:ok, finish_binary(byte_acc, chunks)}

      nil ->
        {:error, :invalid_sequence, offset, mask}
    end
  end

  defp encode_words_all(<<>>, _maximum, _endian, _offset, acc, _count, chunks),
    do: {:ok, finish_binary(acc, chunks)}

  defp encode_words_all(
         <<byte, rest::binary>>,
         maximum,
         endian,
         offset,
         acc,
         count,
         chunks
       )
       when byte <= maximum do
    {acc, count, chunks} = push_binary(word(elem(@masks, byte), endian), acc, count, chunks)
    encode_words_all(rest, maximum, endian, offset + 1, acc, count, chunks)
  end

  defp encode_words_all(
         <<byte, _rest::binary>>,
         _maximum,
         _endian,
         offset,
         _acc,
         _count,
         _chunks
       ),
       do: {:error, :invalid_code_combination, offset, byte}

  defp decode_words_all(<<>>, _maximum, _endian, _offset, byte_acc, _count, chunks),
    do: {:ok, finish_binary(byte_acc, chunks)}

  defp decode_words_all(input, _maximum, _endian, offset, _byte_acc, _count, _chunks)
       when byte_size(input) < 2,
       do: {:error, :incomplete_sequence, offset, input}

  defp decode_words_all(input, maximum, endian, offset, byte_acc, count, chunks) do
    {mask, raw, rest} = next_word(input, endian)

    case decoded(mask, maximum) do
      byte when is_integer(byte) ->
        {byte_acc, count, chunks} = push_byte(byte, byte_acc, count, chunks)
        decode_words_all(rest, maximum, endian, offset + 2, byte_acc, count, chunks)

      nil ->
        {:error, :invalid_sequence, offset, raw}
    end
  end

  defp decoded(mask, maximum) when is_integer(mask) and mask in 0..0xFFF do
    case elem(@decode, mask) do
      byte when is_integer(byte) and byte <= maximum -> byte
      _ -> nil
    end
  end

  defp decoded(_mask, _maximum), do: nil

  defp mode_maximum(:seven_bit), do: {:ok, 0x7F}
  defp mode_maximum(:eight_bit), do: {:ok, 0xFF}
  defp mode_maximum(_mode), do: {:error, :invalid_mode}

  defp next_word(<<mask::16-big, rest::binary>>, :big),
    do: {mask, <<mask::16-big>>, rest}

  defp next_word(<<mask::16-little, rest::binary>>, :little),
    do: {mask, <<mask::16-little>>, rest}

  defp word(mask, :big), do: <<mask::16-big>>
  defp word(mask, :little), do: <<mask::16-little>>

  defp nonzero_lsb_padding?(_data, bit_size) when rem(bit_size, 8) == 0, do: false
  defp nonzero_lsb_padding?(<<>>, _bit_size), do: false

  defp nonzero_lsb_padding?(data, bit_size),
    do: :binary.last(data) >>> rem(bit_size, 8) != 0

  defp push_byte(byte, acc, count, chunks) when count == @chunk_units - 1 do
    chunk = [byte | acc] |> :lists.reverse() |> :erlang.list_to_binary()
    {[], 0, [chunk | chunks]}
  end

  defp push_byte(byte, acc, count, chunks), do: {[byte | acc], count + 1, chunks}

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

defmodule Iconvex.Specs.RawTransports do
  @moduledoc """
  Inventory for raw transports that intentionally do not implement a Unicode
  character codec and therefore do not belong in `Iconvex.Specs.codecs/0`.
  """

  @profiles [
    %{
      canonical: "ECMA-44-7BIT-CARD-RAW",
      mode: :seven_bit,
      module: Iconvex.Specs.ECMA44,
      input_semantics: :raw_code_combination,
      input_unit_bits: 7,
      card_unit_bits: 12,
      standard_packed_order: nil,
      library_packed_orders: [:msb, :lsb],
      transport_names: [
        "ECMA-44-7BIT-CARD-RAW-PACKED-MSB",
        "ECMA-44-7BIT-CARD-RAW-PACKED-LSB",
        "ECMA-44-7BIT-CARD-RAW-16BE",
        "ECMA-44-7BIT-CARD-RAW-16LE"
      ],
      unicode_codec_registered: false
    },
    %{
      canonical: "ECMA-44-8BIT-CARD-RAW",
      mode: :eight_bit,
      module: Iconvex.Specs.ECMA44,
      input_semantics: :raw_code_combination,
      input_unit_bits: 8,
      card_unit_bits: 12,
      standard_packed_order: nil,
      library_packed_orders: [:msb, :lsb],
      transport_names: [
        "ECMA-44-8BIT-CARD-RAW-PACKED-MSB",
        "ECMA-44-8BIT-CARD-RAW-PACKED-LSB",
        "ECMA-44-8BIT-CARD-RAW-16BE",
        "ECMA-44-8BIT-CARD-RAW-16LE"
      ],
      unicode_codec_registered: false
    }
  ]

  @doc "Returns all raw, non-Unicode transport profiles."
  def profiles, do: @profiles

  @doc "Looks up a raw transport profile by canonical name or mode."
  def profile(mode) when mode in [:seven_bit, :eight_bit],
    do: Enum.find(@profiles, &(&1.mode == mode))

  def profile(name) when is_binary(name) do
    normalized = String.upcase(name, :ascii)
    Enum.find(@profiles, &(String.upcase(&1.canonical, :ascii) == normalized))
  end

  def profile(_name), do: nil
end

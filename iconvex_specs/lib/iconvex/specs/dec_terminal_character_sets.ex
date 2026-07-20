defmodule Iconvex.Specs.DECTerminalCharacterSets do
  @moduledoc false

  @source_dir Path.expand("../../../priv/sources/dec-terminal-character-sets", __DIR__)
  @source_path Path.join(
                 @source_dir,
                 "EK-VT3XX-TP-002_VT330_VT340_Text_Programming_198805.pdf"
               )
  @unicode_source_path Path.join(
                         @source_dir,
                         "Unicode_L2_1998_354_Terminal_Character_Sets_Proposal.pdf"
                       )
  @legacy_computing_source_path Path.expand(
                                  "../iso-ir-mosaic-technical/unicode-mappings/n5028.pdf",
                                  @source_dir
                                )
  @kermit_source_path Path.join(@source_dir, "kermit/ckcuni.c")
  @kermit_license_path Path.join(@source_dir, "kermit/COPYING")
  @source_metadata_path Path.join(@source_dir, "SOURCE_METADATA.md")

  @external_resource @source_path
  @external_resource @unicode_source_path
  @external_resource @legacy_computing_source_path
  @external_resource @kermit_source_path
  @external_resource @kermit_license_path
  @external_resource @source_metadata_path

  @chunk_units 4_096

  @special List.to_tuple(
             Enum.to_list(0x21..0x5E) ++
               [
                 0x00A0,
                 0x25C6,
                 0x1FB95,
                 0x2409,
                 0x240C,
                 0x240D,
                 0x240A,
                 0x00B0,
                 0x00B1,
                 0x2424,
                 0x240B,
                 0x2518,
                 0x2510,
                 0x250C,
                 0x2514,
                 0x253C,
                 0x23BA,
                 0x23BB,
                 0x2500,
                 0x23BC,
                 0x23BD,
                 0x251C,
                 0x2524,
                 0x2534,
                 0x252C,
                 0x2502,
                 0x2264,
                 0x2265,
                 0x03C0,
                 0x2260,
                 0x00A3,
                 0x00B7
               ]
           )

  @technical {
    0x23B7,
    0x250C,
    0x2500,
    0x2320,
    0x2321,
    0x2502,
    0x23A1,
    0x23A3,
    0x23A4,
    0x23A6,
    0x239B,
    0x239D,
    0x239E,
    0x23A0,
    0x23A8,
    0x23AC,
    0x23B2,
    0x23B3,
    0x2572,
    0x2571,
    0x23B4,
    0x23B5,
    0x232A,
    nil,
    nil,
    nil,
    nil,
    0x2264,
    0x2260,
    0x2265,
    0x222B,
    0x2234,
    0x221D,
    0x221E,
    0x00F7,
    0x0394,
    0x2207,
    0x03A6,
    0x0393,
    0x223C,
    0x2243,
    0x0398,
    0x00D7,
    0x039B,
    0x21D4,
    0x21D2,
    0x2261,
    0x03A0,
    0x03A8,
    nil,
    0x03A3,
    nil,
    nil,
    0x221A,
    0x03A9,
    0x039E,
    0x03D2,
    0x2282,
    0x2283,
    0x2229,
    0x222A,
    0x2227,
    0x2228,
    0x00AC,
    0x03B1,
    0x03B2,
    0x03C7,
    0x03B4,
    0x03B5,
    0x03C6,
    0x03B3,
    0x03B7,
    0x03B9,
    0x03B8,
    0x03BA,
    0x03BB,
    nil,
    0x03BD,
    0x2202,
    0x03C0,
    0x03C8,
    0x03C1,
    0x03C3,
    0x03C4,
    nil,
    0x0192,
    0x03C9,
    0x03BE,
    0x03C5,
    0x03B6,
    0x2190,
    0x2191,
    0x2192,
    0x2193
  }

  @tables %{special: @special, technical: @technical}

  @encoders Map.new(@tables, fn {set, table} ->
              encoder =
                table
                |> Tuple.to_list()
                |> Enum.with_index()
                |> Enum.reject(fn {codepoint, _index} -> is_nil(codepoint) end)
                |> Map.new()

              {set, encoder}
            end)

  def source_url,
    do:
      "https://bitsavers.org/pdf/dec/terminal/vt340/EK-VT3XX-TP-002_VT330_VT340_Text_Programming_198805.pdf"

  def unicode_source_url, do: "https://www.unicode.org/L2/L1998/98354.pdf"
  def legacy_computing_source_url, do: "https://www.unicode.org/L2/L2022/22020r2-n5028.pdf"
  def private_use_codepoints, do: []

  def decode(input, set, offset) when is_binary(input),
    do: decode_all(input, Map.fetch!(@tables, set), offset, 0, [])

  def decode_discard(input, set, offset) when is_binary(input),
    do: decode_discard_all(input, Map.fetch!(@tables, set), offset, [])

  def encode(codepoints, set, offset) when is_list(codepoints),
    do: encode_all(codepoints, Map.fetch!(@encoders, set), offset, [])

  def encode_discard(codepoints, set, offset) when is_list(codepoints),
    do: encode_discard_all(codepoints, Map.fetch!(@encoders, set), offset, [])

  def decode_to_utf8(input, set, offset) when is_binary(input),
    do: decode_utf8_all(input, Map.fetch!(@tables, set), offset, 0, [], 0, [])

  def encode_from_utf8(input, set, offset) when is_binary(input),
    do: encode_utf8_all(input, Map.fetch!(@encoders, set), offset, 0, [], 0, [])

  defp decode_all(<<>>, _table, _base, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_all(<<unit, rest::binary>>, table, base, offset, acc)
       when unit >= base and unit <= base + 93 do
    case elem(table, unit - base) do
      nil -> {:error, :invalid_sequence, offset, <<unit>>}
      codepoint -> decode_all(rest, table, base, offset + 1, [codepoint | acc])
    end
  end

  defp decode_all(<<unit, _rest::binary>>, _table, _base, offset, _acc),
    do: {:error, :invalid_sequence, offset, <<unit>>}

  defp decode_discard_all(<<>>, _table, _base, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_all(<<unit, rest::binary>>, table, base, acc)
       when unit >= base and unit <= base + 93 do
    case elem(table, unit - base) do
      nil -> decode_discard_all(rest, table, base, acc)
      codepoint -> decode_discard_all(rest, table, base, [codepoint | acc])
    end
  end

  defp decode_discard_all(<<_unit, rest::binary>>, table, base, acc),
    do: decode_discard_all(rest, table, base, acc)

  defp encode_all([], _encoder, _base, acc), do: {:ok, reverse_binary(acc)}

  defp encode_all([codepoint | rest], encoder, base, acc) do
    case encoder do
      %{^codepoint => index} -> encode_all(rest, encoder, base, [base + index | acc])
      _ -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_discard_all([], _encoder, _base, acc), do: {:ok, reverse_binary(acc)}

  defp encode_discard_all([codepoint | rest], encoder, base, acc) do
    case encoder do
      %{^codepoint => index} ->
        encode_discard_all(rest, encoder, base, [base + index | acc])

      _ ->
        encode_discard_all(rest, encoder, base, acc)
    end
  end

  defp decode_utf8_all(<<>>, _table, _base, _offset, acc, _count, chunks),
    do: {:ok, finish_iodata(acc, chunks)}

  defp decode_utf8_all(<<unit, rest::binary>>, table, base, offset, acc, count, chunks)
       when unit >= base and unit <= base + 93 do
    case elem(table, unit - base) do
      nil ->
        {:error, :invalid_sequence, offset, <<unit>>}

      codepoint ->
        decode_utf8_unit(rest, table, base, offset, codepoint, acc, count, chunks)
    end
  end

  defp decode_utf8_all(
         <<unit, _rest::binary>>,
         _table,
         _base,
         offset,
         _acc,
         _count,
         _chunks
       ),
       do: {:error, :invalid_sequence, offset, <<unit>>}

  defp decode_utf8_unit(rest, table, base, offset, codepoint, acc, count, chunks) do
    next_acc = [utf8(codepoint) | acc]

    if count == @chunk_units - 1 do
      chunk = next_acc |> :lists.reverse() |> IO.iodata_to_binary()
      decode_utf8_all(rest, table, base, offset + 1, [], 0, [chunk | chunks])
    else
      decode_utf8_all(rest, table, base, offset + 1, next_acc, count + 1, chunks)
    end
  end

  defp encode_utf8_all(<<>>, _encoder, _base, _offset, acc, _count, chunks),
    do: {:ok, finish_iodata(acc, chunks)}

  defp encode_utf8_all(
         <<codepoint, rest::binary>>,
         encoder,
         base,
         offset,
         acc,
         count,
         chunks
       )
       when codepoint < 0x80 do
    encode_utf8_codepoint(rest, encoder, base, offset, codepoint, 1, acc, count, chunks)
  end

  defp encode_utf8_all(input, encoder, base, offset, acc, count, chunks) do
    case input do
      <<codepoint::utf8, rest::binary>> ->
        width = byte_size(input) - byte_size(rest)

        encode_utf8_codepoint(
          rest,
          encoder,
          base,
          offset,
          codepoint,
          width,
          acc,
          count,
          chunks
        )

      _ ->
        Iconvex.Specs.CodecSupport.malformed_utf8(input, offset)
    end
  end

  defp encode_utf8_codepoint(
         rest,
         encoder,
         base,
         offset,
         codepoint,
         width,
         acc,
         count,
         chunks
       ) do
    case encoder do
      %{^codepoint => index} ->
        encode_utf8_unit(
          rest,
          encoder,
          base,
          offset + width,
          base + index,
          acc,
          count,
          chunks
        )

      _ ->
        {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_utf8_unit(rest, encoder, base, offset, unit, acc, count, chunks) do
    next_acc = [unit | acc]

    if count == @chunk_units - 1 do
      chunk = next_acc |> :lists.reverse() |> :erlang.list_to_binary()
      encode_utf8_all(rest, encoder, base, offset, [], 0, [chunk | chunks])
    else
      encode_utf8_all(rest, encoder, base, offset, next_acc, count + 1, chunks)
    end
  end

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

defmodule Iconvex.Specs.DECTerminalCharacterSets.Profile do
  @moduledoc false

  defmacro __using__(options) do
    set = Keyword.fetch!(options, :set)
    offset = Keyword.fetch!(options, :offset)
    invocation = Keyword.fetch!(options, :invocation)
    canonical = Keyword.fetch!(options, :canonical)
    aliases = Keyword.fetch!(options, :aliases)
    codec_id = Keyword.fetch!(options, :codec_id)
    source_page = if set == :special, do: 39, else: 40
    printed_source_page = if set == :special, do: 26, else: 27

    quote do
      use Iconvex.Codec
      alias Iconvex.Specs.DECTerminalCharacterSets, as: Engine

      @impl true
      def canonical_name, do: unquote(canonical)

      @impl true
      def aliases, do: unquote(aliases)

      @impl true
      def codec_id, do: unquote(codec_id)

      def unit_bits, do: 7
      def invocation, do: unquote(invocation)
      def source_page, do: unquote(source_page)
      def printed_source_page, do: unquote(printed_source_page)
      def source_url, do: Engine.source_url()
      def unicode_source_url, do: Engine.unicode_source_url()
      def legacy_computing_source_url, do: Engine.legacy_computing_source_url()
      def private_use_codepoints, do: Engine.private_use_codepoints()

      @impl true
      def decode(input), do: Engine.decode(input, unquote(set), unquote(offset))

      @impl true
      def decode_discard(input),
        do: Engine.decode_discard(input, unquote(set), unquote(offset))

      @impl true
      def encode(codepoints), do: Engine.encode(codepoints, unquote(set), unquote(offset))

      @impl true
      def encode_discard(codepoints),
        do: Engine.encode_discard(codepoints, unquote(set), unquote(offset))

      @impl true
      def encode_substitute(codepoints, replacer),
        do:
          Iconvex.Specs.CodecSupport.encode_substitute_each(
            codepoints,
            &encode/1,
            replacer
          )

      @impl true
      def decode_to_utf8(input),
        do: Engine.decode_to_utf8(input, unquote(set), unquote(offset))

      @impl true
      def encode_from_utf8(input),
        do: Engine.encode_from_utf8(input, unquote(set), unquote(offset))
    end
  end
end

defmodule Iconvex.Specs.DECSpecial do
  @moduledoc "DEC Special Graphic 94-character set invoked in GL."

  use Iconvex.Specs.DECTerminalCharacterSets.Profile,
    set: :special,
    offset: 0x21,
    invocation: :gl,
    canonical: "DEC-SPECIAL",
    aliases: [
      "DEC-SPECIAL-GL",
      "DEC-SPECIAL-GRAPHIC",
      "DEC-SPECIAL-GRAPHICS",
      "VT100-GRAPHICS",
      "VT100-LINE-DRAWING"
    ],
    codec_id: :dec_special
end

defmodule Iconvex.Specs.DECSpecialGR do
  @moduledoc "DEC Special Graphic 94-character set invoked in GR."

  use Iconvex.Specs.DECTerminalCharacterSets.Profile,
    set: :special,
    offset: 0xA1,
    invocation: :gr,
    canonical: "DEC-SPECIAL-GR",
    aliases: ["DEC-SPECIAL-GRAPHIC-GR", "DEC-SPECIAL-GRAPHICS-GR"],
    codec_id: :dec_special_gr
end

defmodule Iconvex.Specs.DECTechnical do
  @moduledoc "DEC Technical 94-character set invoked in GL."

  use Iconvex.Specs.DECTerminalCharacterSets.Profile,
    set: :technical,
    offset: 0x21,
    invocation: :gl,
    canonical: "DEC-TECHNICAL",
    aliases: [
      "DEC-TECHNICAL-CHARACTER-SET",
      "DEC-TECHNICAL-GL",
      "VT300-TECHNICAL",
      "VT300-TECHNICAL-GL"
    ],
    codec_id: :dec_technical
end

defmodule Iconvex.Specs.DECTechnicalGR do
  @moduledoc "DEC Technical 94-character set invoked in GR."

  use Iconvex.Specs.DECTerminalCharacterSets.Profile,
    set: :technical,
    offset: 0xA1,
    invocation: :gr,
    canonical: "DEC-TECHNICAL-GR",
    aliases: ["DEC-TECHNICAL-CHARACTER-SET-GR", "VT300-TECHNICAL-GR"],
    codec_id: :dec_technical_gr
end

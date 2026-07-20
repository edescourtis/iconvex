defmodule Iconvex.Specs.DECHebrew do
  @moduledoc false

  @source_dir Path.expand("../../../priv/sources/dec-hebrew-7", __DIR__)
  @guide_source_path Path.join(
                       @source_dir,
                       "Kennelly_Digital_Guide_To_Developing_International_Software_1991.pdf"
                     )
  @vt510_source_path Path.join(@source_dir, "vt510rmb.pdf")
  @source_metadata_path Path.join(@source_dir, "SOURCE_METADATA.md")
  @kermit_source_path Path.expand(
                        "../dec-terminal-character-sets/kermit/ckcuni.c",
                        @source_dir
                      )
  @kermit_license_path Path.expand(
                         "../dec-terminal-character-sets/kermit/COPYING",
                         @source_dir
                       )
  @dec_mcs_path Path.expand("../../../priv/tables/rfc1345_088.etf", __DIR__)

  @external_resource @guide_source_path
  @external_resource @vt510_source_path
  @external_resource @source_metadata_path
  @external_resource @kermit_source_path
  @external_resource @kermit_license_path
  @external_resource @dec_mcs_path

  @chunk_units 4_096
  @dec_mcs_one @dec_mcs_path |> File.read!() |> :erlang.binary_to_term() |> Map.fetch!(:one)

  @si960 0x00..0x7F
         |> Enum.map(fn
           unit when unit in 0x60..0x7A -> {0x05D0 + unit - 0x60}
           unit -> {unit}
         end)
         |> List.to_tuple()

  @dec_hebrew_8 0x00..0xFF
                |> Enum.map(fn
                  unit when unit in 0xE0..0xFA -> {0x05D0 + unit - 0xE0}
                  unit when unit in 0xC0..0xDF or unit in 0xFB..0xFF -> nil
                  unit -> elem(@dec_mcs_one, unit)
                end)
                |> List.to_tuple()

  @tables %{si960: @si960, dec_hebrew_8: @dec_hebrew_8}

  @encoders Map.new(@tables, fn {profile, table} ->
              encoder =
                table
                |> Tuple.to_list()
                |> Enum.with_index()
                |> Enum.reject(fn {mapping, _unit} -> is_nil(mapping) end)
                |> Map.new(fn {{codepoint}, unit} -> {codepoint, unit} end)

              {profile, encoder}
            end)

  def guide_source_url,
    do:
      "https://www.bitsavers.org/pdf/dec/_Books/_Digital_Press/Kennelly_Digital_Guide_To_Developing_International_Software_1991.pdf"

  def vt510_source_url, do: "https://vt100.net/mirror/mds-199909/cd3/term/vt510rmb.pdf"

  def decode(input, profile) when is_binary(input),
    do: decode_all(input, Map.fetch!(@tables, profile), 0, [])

  def decode_discard(input, profile) when is_binary(input),
    do: decode_discard_all(input, Map.fetch!(@tables, profile), [])

  def encode(codepoints, profile) when is_list(codepoints),
    do: encode_all(codepoints, Map.fetch!(@encoders, profile), [])

  def encode_discard(codepoints, profile) when is_list(codepoints),
    do: encode_discard_all(codepoints, Map.fetch!(@encoders, profile), [])

  def decode_to_utf8(input, profile) when is_binary(input),
    do: decode_utf8_all(input, Map.fetch!(@tables, profile), 0, [], 0, [])

  def encode_from_utf8(input, profile) when is_binary(input),
    do: encode_utf8_all(input, Map.fetch!(@encoders, profile), 0, [], 0, [])

  defp decode_all(<<>>, _table, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_all(<<unit, rest::binary>>, table, offset, acc)
       when unit < tuple_size(table) do
    case elem(table, unit) do
      nil -> {:error, :invalid_sequence, offset, <<unit>>}
      {codepoint} -> decode_all(rest, table, offset + 1, [codepoint | acc])
    end
  end

  defp decode_all(<<unit, _rest::binary>>, _table, offset, _acc),
    do: {:error, :invalid_sequence, offset, <<unit>>}

  defp decode_discard_all(<<>>, _table, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_all(<<unit, rest::binary>>, table, acc)
       when unit < tuple_size(table) do
    case elem(table, unit) do
      nil -> decode_discard_all(rest, table, acc)
      {codepoint} -> decode_discard_all(rest, table, [codepoint | acc])
    end
  end

  defp decode_discard_all(<<_unit, rest::binary>>, table, acc),
    do: decode_discard_all(rest, table, acc)

  defp encode_all([], _encoder, acc), do: {:ok, reverse_binary(acc)}

  defp encode_all([codepoint | rest], encoder, acc) do
    case encoder do
      %{^codepoint => unit} -> encode_all(rest, encoder, [unit | acc])
      _ -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_discard_all([], _encoder, acc), do: {:ok, reverse_binary(acc)}

  defp encode_discard_all([codepoint | rest], encoder, acc) do
    case encoder do
      %{^codepoint => unit} -> encode_discard_all(rest, encoder, [unit | acc])
      _ -> encode_discard_all(rest, encoder, acc)
    end
  end

  defp decode_utf8_all(<<>>, _table, _offset, acc, _count, chunks),
    do: {:ok, finish_iodata(acc, chunks)}

  defp decode_utf8_all(<<unit, rest::binary>>, table, offset, acc, count, chunks)
       when unit < tuple_size(table) do
    case elem(table, unit) do
      nil ->
        {:error, :invalid_sequence, offset, <<unit>>}

      {codepoint} ->
        next_acc = [utf8(codepoint) | acc]

        if count == @chunk_units - 1 do
          chunk = next_acc |> :lists.reverse() |> IO.iodata_to_binary()
          decode_utf8_all(rest, table, offset + 1, [], 0, [chunk | chunks])
        else
          decode_utf8_all(rest, table, offset + 1, next_acc, count + 1, chunks)
        end
    end
  end

  defp decode_utf8_all(
         <<unit, _rest::binary>>,
         _table,
         offset,
         _acc,
         _count,
         _chunks
       ),
       do: {:error, :invalid_sequence, offset, <<unit>>}

  defp encode_utf8_all(<<>>, _encoder, _offset, acc, _count, chunks),
    do: {:ok, finish_iodata(acc, chunks)}

  defp encode_utf8_all(<<codepoint, rest::binary>>, encoder, offset, acc, count, chunks)
       when codepoint < 0x80 do
    encode_utf8_codepoint(rest, encoder, offset, codepoint, 1, acc, count, chunks)
  end

  defp encode_utf8_all(input, encoder, offset, acc, count, chunks) do
    case input do
      <<codepoint::utf8, rest::binary>> ->
        width = byte_size(input) - byte_size(rest)
        encode_utf8_codepoint(rest, encoder, offset, codepoint, width, acc, count, chunks)

      _ ->
        malformed_utf8(input, offset)
    end
  end

  defp encode_utf8_codepoint(
         rest,
         encoder,
         offset,
         codepoint,
         width,
         acc,
         count,
         chunks
       ) do
    case encoder do
      %{^codepoint => unit} ->
        next_acc = [unit | acc]

        if count == @chunk_units - 1 do
          chunk = next_acc |> :lists.reverse() |> :erlang.list_to_binary()
          encode_utf8_all(rest, encoder, offset + width, [], 0, [chunk | chunks])
        else
          encode_utf8_all(rest, encoder, offset + width, next_acc, count + 1, chunks)
        end

      _ ->
        {:error, :unrepresentable_character, codepoint}
    end
  end

  defp malformed_utf8(input, offset),
    do: Iconvex.Specs.CodecSupport.malformed_utf8(input, offset)

  defp reverse_binary(acc), do: acc |> :lists.reverse() |> :erlang.list_to_binary()
  defp utf8(codepoint) when codepoint < 0x80, do: codepoint
  defp utf8(codepoint), do: <<codepoint::utf8>>

  defp finish_iodata([], chunks), do: chunks |> :lists.reverse() |> IO.iodata_to_binary()

  defp finish_iodata(acc, chunks) do
    chunk = acc |> :lists.reverse() |> IO.iodata_to_binary()
    [chunk | chunks] |> :lists.reverse() |> IO.iodata_to_binary()
  end
end

defmodule Iconvex.Specs.DECHebrew.Profile do
  @moduledoc false

  defmacro __using__(options) do
    profile = Keyword.fetch!(options, :profile)
    canonical = Keyword.fetch!(options, :canonical)
    aliases = Keyword.fetch!(options, :aliases)
    codec_id = Keyword.fetch!(options, :codec_id)
    unit_bits = Keyword.fetch!(options, :unit_bits)

    quote do
      use Iconvex.Codec
      alias Iconvex.Specs.DECHebrew, as: Engine

      @impl true
      def canonical_name, do: unquote(canonical)

      @impl true
      def aliases, do: unquote(aliases)

      @impl true
      def codec_id, do: unquote(codec_id)

      def unit_bits, do: unquote(unit_bits)
      def guide_source_page, do: 39
      def printed_guide_source_page, do: 19
      def vt510_source_page, do: 180
      def printed_vt510_source_page, do: "5-57"
      def guide_source_url, do: Engine.guide_source_url()
      def vt510_source_url, do: Engine.vt510_source_url()

      @impl true
      def decode(input), do: Engine.decode(input, unquote(profile))

      @impl true
      def decode_discard(input), do: Engine.decode_discard(input, unquote(profile))

      @impl true
      def encode(codepoints), do: Engine.encode(codepoints, unquote(profile))

      @impl true
      def encode_discard(codepoints), do: Engine.encode_discard(codepoints, unquote(profile))

      @impl true
      def encode_substitute(codepoints, replacer),
        do:
          Iconvex.Specs.CodecSupport.encode_substitute_each(
            codepoints,
            &encode/1,
            replacer
          )

      @impl true
      def decode_to_utf8(input), do: Engine.decode_to_utf8(input, unquote(profile))

      @impl true
      def encode_from_utf8(input), do: Engine.encode_from_utf8(input, unquote(profile))
    end
  end
end

defmodule Iconvex.Specs.SI960 do
  @moduledoc "DEC Hebrew 7-bit / Israeli Standard SI 960."

  use Iconvex.Specs.DECHebrew.Profile,
    profile: :si960,
    canonical: "SI-960",
    aliases: [
      "SI960",
      "HEBREW-7",
      "DEC-HEBREW-7",
      "DEC-HEBREW-7BIT",
      "DEC-7-BIT-HEBREW"
    ],
    codec_id: :si960,
    unit_bits: 7
end

defmodule Iconvex.Specs.DECHebrew8 do
  @moduledoc "DEC Hebrew 8-bit overlay on DEC Multinational."

  use Iconvex.Specs.DECHebrew.Profile,
    profile: :dec_hebrew_8,
    canonical: "DEC-HEBREW-8",
    aliases: ["DEC-HEBREW", "DEC-HEBREW-8BIT", "DEC-HEBREW-8-BIT"],
    codec_id: :dec_hebrew_8,
    unit_bits: 8
end

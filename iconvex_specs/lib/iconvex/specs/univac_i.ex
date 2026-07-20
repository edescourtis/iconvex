defmodule Iconvex.Specs.UNIVACI do
  @moduledoc false

  import Bitwise

  @table_path Path.expand(
                "../../../priv/sources/univac-i-1959/table_8_2.csv",
                __DIR__
              )
  @metadata_path Path.expand(
                   "../../../priv/sources/univac-i-1959/SOURCE_METADATA.md",
                   __DIR__
                 )
  @external_resource @table_path
  @external_resource @metadata_path

  @source_sha256 "2b4c3c18112a5a0820cf886e417cb605408b635fdc6bdaf658638c7d738c3efc"
  @reference_card_sha256 "87a6858433286efffcbf4c7bcdb96460d62ad656d06d7125af924fed4542d97f"
  @table_sha256 "61a1e290652c0a0dd658301cef5d96caa1ab3a6e7520752eeca4d9902fb5622a"
  @chunk_units 4_096
  @utf8_chunk_bytes 65_536

  # Figure 8-2, indexed as (zone << 4) | excess-three. The first cells in
  # zones 00, 01, and 10 are device actions established by the reference card.
  @semantic_base [
    :ignored,
    0x20,
    ?-,
    ?0,
    ?1,
    ?2,
    ?3,
    ?4,
    ?5,
    ?6,
    ?7,
    ?8,
    ?9,
    ?',
    ?&,
    ?(,
    0x0D,
    ?,,
    ?.,
    ?;,
    ?A,
    ?B,
    ?C,
    ?D,
    ?E,
    ?F,
    ?G,
    ?H,
    ?I,
    ?#,
    0x00A2,
    ?@,
    0x09,
    ?",
    ?|,
    ?),
    ?J,
    ?K,
    ?L,
    ?M,
    ?N,
    ?O,
    ?P,
    ?Q,
    ?R,
    ?$,
    ?*,
    ??,
    0x03A3,
    0x03B2,
    ?:,
    ?+,
    ?/,
    ?S,
    ?T,
    ?U,
    ?V,
    ?W,
    ?X,
    ?Y,
    ?Z,
    ?%,
    ?=,
    :unavailable
  ]

  @lossless_base List.replace_at(@semantic_base, 0, 0xF4040)
  @raw_base Enum.to_list(0xF4080..0xF40BF)

  unless Base.encode16(:crypto.hash(:sha256, File.read!(@table_path)), case: :lower) ==
           @table_sha256 do
    raise "UNIVAC I source table digest does not match its reviewed transcription"
  end

  source_mapping = fn
    "IGNORED" -> :ignored
    "UNAVAILABLE" -> :unavailable
    "U+" <> hex -> String.to_integer(hex, 16)
  end

  [_header | source_rows] = @table_path |> File.read!() |> String.split("\n", trim: true)

  parsed_source =
    Enum.map(source_rows, fn row ->
      [hex, zone, xs3, _glyph, semantic, lossless, raw, status] = String.split(row, ",")

      %{
        unit: String.to_integer(hex, 16),
        zone: String.to_integer(zone, 2),
        xs3: String.to_integer(xs3, 2),
        semantic: source_mapping.(semantic),
        lossless: source_mapping.(lossless),
        raw: source_mapping.(raw),
        status: status
      }
    end)

  unless Enum.map(parsed_source, & &1.unit) == Enum.to_list(0..63) and
           Enum.all?(parsed_source, &(&1.unit == (&1.zone <<< 4 ||| &1.xs3))) and
           Enum.map(parsed_source, & &1.semantic) == @semantic_base and
           Enum.map(parsed_source, & &1.lossless) == @lossless_base and
           Enum.map(parsed_source, & &1.raw) == @raw_base and
           Enum.count(parsed_source, &(&1.status == "assigned")) == 63 do
    raise "UNIVAC I runtime tables diverge from the complete source transcription"
  end

  odd_parity? = fn value ->
    value |> Integer.digits(2) |> Enum.sum() |> rem(2) == 1
  end

  checked_by_basic =
    for basic <- 0..63 do
      if odd_parity?.(basic), do: basic, else: basic ||| 0x40
    end

  tape_by_basic =
    Enum.map(checked_by_basic, fn checked ->
      (checked &&& 0x78) <<< 1 ||| 0x08 ||| (checked &&& 0x07)
    end)

  basic_table = fn mapping ->
    0..255
    |> Enum.map(fn
      byte when byte < 64 -> Enum.at(mapping, byte)
      _byte -> :invalid
    end)
    |> List.to_tuple()
  end

  checked_table =
    0..255
    |> Enum.map(fn byte ->
      if byte < 128 and odd_parity?.(byte) do
        Enum.at(@semantic_base, byte &&& 0x3F)
      else
        :invalid
      end
    end)
    |> List.to_tuple()

  tape_table =
    0..255
    |> Enum.map(fn byte ->
      checked = (byte &&& 0xF0) >>> 1 ||| (byte &&& 0x07)

      if (byte &&& 0x08) != 0 and odd_parity?.(checked) do
        Enum.at(@semantic_base, checked &&& 0x3F)
      else
        :invalid
      end
    end)
    |> List.to_tuple()

  @decode_tables %{
    semantic: basic_table.(@semantic_base),
    lossless_vpua: basic_table.(@lossless_base),
    raw_vpua: basic_table.(@raw_base),
    odd_parity_7bit: checked_table,
    paper_tape_row: tape_table
  }

  @decode_utf8_tables Map.new(@decode_tables, fn {profile, table} ->
                        utf8_table =
                          table
                          |> Tuple.to_list()
                          |> Enum.map(fn
                            codepoint when is_integer(codepoint) and codepoint < 0x80 ->
                              codepoint

                            codepoint when is_integer(codepoint) ->
                              <<codepoint::utf8>>

                            action ->
                              action
                          end)
                          |> List.to_tuple()

                        {profile, utf8_table}
                      end)

  output_units = %{
    semantic: Enum.to_list(0..63),
    lossless_vpua: Enum.to_list(0..63),
    raw_vpua: Enum.to_list(0..63),
    odd_parity_7bit: checked_by_basic,
    paper_tape_row: tape_by_basic
  }

  @encoders Map.new(@decode_tables, fn {profile, table} ->
              encoder =
                output_units
                |> Map.fetch!(profile)
                |> Enum.reduce(%{}, fn output_unit, acc ->
                  case elem(table, output_unit) do
                    codepoint when is_integer(codepoint) ->
                      Map.put_new(acc, codepoint, output_unit)

                    _action ->
                      acc
                  end
                end)

              {profile, encoder}
            end)

  def source_sha256, do: @source_sha256
  def reference_card_sha256, do: @reference_card_sha256
  def table_sha256, do: @table_sha256
  def source_pages, do: [129]
  def printed_source_pages, do: ["124"]

  def source_url,
    do: "https://bitsavers.org/pdf/univac/univac1/UNIVAC1_Programming_1959.pdf"

  def reference_card_url,
    do: "https://bitsavers.org/pdf/univac/univac1/UnivacI_RefCard.pdf"

  def decode(input, profile) when is_binary(input),
    do: decode_all(input, table(profile), 0, [])

  def decode_discard(input, profile) when is_binary(input),
    do: decode_discard_all(input, table(profile), [])

  def encode(codepoints, profile) when is_list(codepoints),
    do: encode_all(codepoints, encoder(profile), [])

  def encode_discard(codepoints, profile) when is_list(codepoints),
    do: encode_discard_all(codepoints, encoder(profile), [])

  def encode_substitute(codepoints, profile, replacer)
      when is_list(codepoints) and is_function(replacer, 1),
      do: encode_substitute_all(codepoints, encoder(profile), replacer, [])

  def decode_chunk(input, profile, _final?) when is_binary(input) do
    case decode(input, profile) do
      {:ok, codepoints} -> {:ok, codepoints, <<>>}
      error -> error
    end
  end

  def encode_chunk(codepoints, profile, _final?, policy) when is_list(codepoints) do
    result =
      case policy do
        :error -> encode(codepoints, profile)
        :discard -> encode_discard(codepoints, profile)
        {:replace, replacer} -> encode_substitute(codepoints, profile, replacer)
      end

    case result do
      {:ok, output} -> {:ok, output, []}
      error -> error
    end
  end

  def decode_to_utf8(input, profile) when is_binary(input),
    do: decode_utf8_all(input, utf8_table(profile), 0, [], 0, [])

  def encode_from_utf8(input, profile) when is_binary(input),
    do: encode_utf8_chunks(input, <<>>, encoder(profile), 0, [])

  defp table(profile), do: Map.fetch!(@decode_tables, profile)
  defp utf8_table(profile), do: Map.fetch!(@decode_utf8_tables, profile)
  defp encoder(profile), do: Map.fetch!(@encoders, profile)

  defp decode_all(<<>>, _table, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_all(<<unit, rest::binary>>, table, offset, acc) do
    case elem(table, unit) do
      codepoint when is_integer(codepoint) ->
        decode_all(rest, table, offset + 1, [codepoint | acc])

      :ignored ->
        decode_all(rest, table, offset + 1, acc)

      _invalid ->
        {:error, :invalid_sequence, offset, <<unit>>}
    end
  end

  defp decode_discard_all(<<>>, _table, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_all(<<unit, rest::binary>>, table, acc) do
    case elem(table, unit) do
      codepoint when is_integer(codepoint) -> decode_discard_all(rest, table, [codepoint | acc])
      _action -> decode_discard_all(rest, table, acc)
    end
  end

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

  defp encode_substitute_all([], _encoder, _replacer, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute_all([codepoint | rest], encoder, replacer, acc) do
    case encoder do
      %{^codepoint => unit} ->
        encode_substitute_all(rest, encoder, replacer, [unit | acc])

      _ ->
        case encode_all(replacer.(codepoint), encoder, []) do
          {:ok, replacement} ->
            encode_substitute_all(rest, encoder, replacer, [replacement | acc])

          error ->
            error
        end
    end
  end

  defp decode_utf8_all(<<>>, _table, _offset, acc, _count, chunks),
    do: {:ok, finish_iodata(acc, chunks)}

  defp decode_utf8_all(<<unit, rest::binary>>, table, offset, acc, count, chunks) do
    case elem(table, unit) do
      encoded when is_integer(encoded) or is_binary(encoded) ->
        {next_acc, next_count, next_chunks} = push_utf8(encoded, acc, count, chunks)
        decode_utf8_all(rest, table, offset + 1, next_acc, next_count, next_chunks)

      :ignored ->
        decode_utf8_all(rest, table, offset + 1, acc, count, chunks)

      _invalid ->
        {:error, :invalid_sequence, offset, <<unit>>}
    end
  end

  defp encode_utf8_chunks(remaining, carry, encoder, offset, chunks) do
    {input, rest} = take_utf8_chunk(remaining, carry)

    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        with {:ok, encoded} <- encode_all(codepoints, encoder, []) do
          if rest == <<>> do
            {:ok, finish_binary_chunks(encoded, chunks)}
          else
            encode_utf8_chunks(rest, <<>>, encoder, offset + byte_size(input), [encoded | chunks])
          end
        end

      {:incomplete, codepoints, tail} ->
        consumed = byte_size(input) - byte_size(tail)

        with {:ok, encoded} <- encode_all(codepoints, encoder, []) do
          if rest == <<>> do
            Iconvex.Specs.CodecSupport.malformed_utf8(tail, offset + consumed)
          else
            encode_utf8_chunks(rest, tail, encoder, offset + consumed, [encoded | chunks])
          end
        end

      {:error, codepoints, tail} ->
        consumed = byte_size(input) - byte_size(tail)

        with {:ok, _encoded} <- encode_all(codepoints, encoder, []) do
          Iconvex.Specs.CodecSupport.malformed_utf8(
            append_error_rest(tail, rest),
            offset + consumed
          )
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

  defp push_utf8(encoded, acc, count, chunks) when count == @chunk_units - 1 do
    chunk = [encoded | acc] |> :lists.reverse() |> IO.iodata_to_binary()
    {[], 0, [chunk | chunks]}
  end

  defp push_utf8(encoded, acc, count, chunks), do: {[encoded | acc], count + 1, chunks}
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

defmodule Iconvex.Specs.UNIVACI.Profile do
  @moduledoc false

  defmacro __using__(options) do
    profile = Keyword.fetch!(options, :profile)
    canonical = Keyword.fetch!(options, :canonical)
    aliases = Keyword.fetch!(options, :aliases)
    codec_id = Keyword.fetch!(options, :codec_id)
    unit_bits = Keyword.fetch!(options, :unit_bits)

    quote do
      use Iconvex.Codec
      alias Iconvex.Specs.UNIVACI, as: Engine

      @impl true
      def canonical_name, do: unquote(canonical)

      @impl true
      def aliases, do: unquote(aliases)

      @impl true
      def codec_id, do: unquote(codec_id)

      def unit_bits, do: unquote(unit_bits)
      def source_sha256, do: Engine.source_sha256()
      def reference_card_sha256, do: Engine.reference_card_sha256()
      def table_sha256, do: Engine.table_sha256()
      def source_pages, do: Engine.source_pages()
      def printed_source_pages, do: Engine.printed_source_pages()
      def source_url, do: Engine.source_url()
      def reference_card_url, do: Engine.reference_card_url()

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
        do: Engine.encode_substitute(codepoints, unquote(profile), replacer)

      @impl true
      def decode_chunk(input, final?), do: Engine.decode_chunk(input, unquote(profile), final?)

      @impl true
      def encode_chunk(codepoints, final?, policy),
        do: Engine.encode_chunk(codepoints, unquote(profile), final?, policy)

      @impl true
      def decode_to_utf8(input), do: Engine.decode_to_utf8(input, unquote(profile))

      @impl true
      def encode_from_utf8(input), do: Engine.encode_from_utf8(input, unquote(profile))
    end
  end
end

defmodule Iconvex.Specs.UNIVACIExpanded1959 do
  @moduledoc """
  Semantic profile of the expanded 63-character UNIVAC I code (1959).

  Printer-ignore produces no Unicode scalar; printer space, carriage return,
  and horizontal tab retain their device semantics. `0x3F` is unassigned.
  The byte API carries one six-bit unit per octet.
  """

  use Iconvex.Specs.UNIVACI.Profile,
    profile: :semantic,
    canonical: "UNIVAC-I-EXPANDED-1959",
    aliases: [
      "UNIVAC-I-63",
      "UNIVAC-I-XS3-63",
      "UNIVAC-I-EXPANDED-SIXBIT-1959",
      "SPERRY-RAND-UNIVAC-I-EXPANDED-1959"
    ],
    codec_id: :univac_i_expanded_1959,
    unit_bits: 6
end

defmodule Iconvex.Specs.UNIVACIExpanded1959LosslessVPUA do
  @moduledoc """
  Lossless UNIVAC I expanded-code profile.

  The printer-ignore unit maps to source-qualified U+F4040; ordinary graphics
  and device controls remain readable. The explicitly unused `0x3F` is invalid.
  """

  use Iconvex.Specs.UNIVACI.Profile,
    profile: :lossless_vpua,
    canonical: "UNIVAC-I-EXPANDED-1959-LOSSLESS-VPUA",
    aliases: ["UNIVAC-I-63-LOSSLESS-VPUA", "UNIVAC-I-XS3-63-LOSSLESS-VPUA"],
    codec_id: :univac_i_expanded_1959_lossless_vpua,
    unit_bits: 6
end

defmodule Iconvex.Specs.UNIVACIExpanded1959RawVPUA do
  @moduledoc """
  Forensic UNIVAC I expanded-code profile.

  Every six-bit pattern maps bijectively to U+F4080..U+F40BF, including the
  pattern that the 1959 source labels `NOT USED`.
  """

  use Iconvex.Specs.UNIVACI.Profile,
    profile: :raw_vpua,
    canonical: "UNIVAC-I-EXPANDED-1959-RAW-VPUA",
    aliases: ["UNIVAC-I-63-RAW-VPUA", "UNIVAC-I-XS3-63-RAW-VPUA"],
    codec_id: :univac_i_expanded_1959_raw_vpua,
    unit_bits: 6
end

defmodule Iconvex.Specs.UNIVACIExpanded1959OddParity7Bit do
  @moduledoc """
  UNIVAC I's checked seven-bit representation, one septet per octet.

  The leading check bit makes total parity odd. The lower six bits use the
  semantic 1959 profile; use `Iconvex.Specs.Packed` for contiguous septets.
  """

  use Iconvex.Specs.UNIVACI.Profile,
    profile: :odd_parity_7bit,
    canonical: "UNIVAC-I-EXPANDED-1959-ODD-PARITY-7BIT",
    aliases: [
      "UNIVAC-I-EXPANDED-1959-CHECKED",
      "UNIVAC-I-EXPANDED-1959-SEPTET",
      "UNIVAC-I-63-ODD-PARITY-7BIT"
    ],
    codec_id: :univac_i_expanded_1959_odd_parity_7bit,
    unit_bits: 7
end

defmodule Iconvex.Specs.UNIVACIExpanded1959PaperTapeRow do
  @moduledoc """
  Physical eight-track UNIVAC I paper-tape rows.

  Bits are ordered `1,2,3,4,S,5,6,7`; the sprocket track `S` must be set and
  character tracks 1..7 must have odd parity.
  """

  use Iconvex.Specs.UNIVACI.Profile,
    profile: :paper_tape_row,
    canonical: "UNIVAC-I-EXPANDED-1959-PAPER-TAPE-ROW",
    aliases: ["UNIVAC-I-63-PAPER-TAPE", "UNIVAC-I-TAPE-TRACK-1234S567"],
    codec_id: :univac_i_expanded_1959_paper_tape_row,
    unit_bits: 8
end

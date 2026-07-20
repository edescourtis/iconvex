defmodule Iconvex.Specs.Fieldata do
  @moduledoc false

  @generic_table_path Path.expand(
                        "../../../priv/sources/univac-1100-fieldata/table_6_1.csv",
                        __DIR__
                      )
  @generic_metadata_path Path.expand(
                           "../../../priv/sources/univac-1100-fieldata/SOURCE_METADATA.md",
                           __DIR__
                         )
  @console_table_path Path.expand(
                        "../../../priv/sources/univac-4009-fieldata/table_3_1.csv",
                        __DIR__
                      )
  @console_metadata_path Path.expand(
                           "../../../priv/sources/univac-4009-fieldata/SOURCE_METADATA.md",
                           __DIR__
                         )

  @external_resource @generic_table_path
  @external_resource @generic_metadata_path
  @external_resource @console_table_path
  @external_resource @console_metadata_path

  # Direct UTF-8 paths periodically materialize an output chunk. This keeps
  # temporary lists bounded on large files while retaining tail-recursive,
  # single-pass input processing.
  @chunk_units 4_096

  # UP-7824 Rev. 1, table 6-1. The runtime table is deliberately independent
  # of the CSV oracle pinned under priv/sources.
  @generic [
    ?@,
    ?[,
    ?],
    ?#,
    0x0394,
    0x20,
    ?A,
    ?B,
    ?C,
    ?D,
    ?E,
    ?F,
    ?G,
    ?H,
    ?I,
    ?J,
    ?K,
    ?L,
    ?M,
    ?N,
    ?O,
    ?P,
    ?Q,
    ?R,
    ?S,
    ?T,
    ?U,
    ?V,
    ?W,
    ?X,
    ?Y,
    ?Z,
    ?),
    ?-,
    ?+,
    ?<,
    ?=,
    ?>,
    ?&,
    ?$,
    ?*,
    ?(,
    ?%,
    ?:,
    ??,
    ?!,
    ?,,
    ?\\,
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
    ?;,
    ?/,
    ?.,
    0x2311,
    0x2260
  ]

  # UP-7604 Rev. 1, table 3-1. Atoms describe device actions rather than
  # Unicode characters: :ignored consumes a valid output unit and
  # :unavailable is invalid in that directional profile.
  @console_semantic @generic
                    |> List.replace_at(0o00, 0xF4000)
                    |> List.replace_at(0o03, 0x0085)
                    |> List.replace_at(0o04, :unavailable)
                    |> List.replace_at(0o46, ?_)
                    |> List.replace_at(0o52, ?")
                    |> List.replace_at(0o57, 0xF402F)
                    |> List.replace_at(0o77, 0x2191)

  @console_output @console_semantic
                  |> List.replace_at(0o00, :ignored)
                  |> List.replace_at(0o04, :ignored)

  @console_lossless List.replace_at(@console_semantic, 0o04, 0xF4004)
  @console_raw Enum.to_list(0xF4000..0xF403F)

  @tables %{
    generic: List.to_tuple(@generic),
    input: List.to_tuple(@console_semantic),
    output: List.to_tuple(@console_output),
    lossless_vpua: List.to_tuple(@console_lossless),
    raw_vpua: List.to_tuple(@console_raw)
  }

  @encoders Map.new(@tables, fn {profile, table} ->
              encoder =
                table
                |> Tuple.to_list()
                |> Enum.with_index()
                |> Enum.reduce(%{}, fn
                  {codepoint, unit}, acc when is_integer(codepoint) ->
                    Map.put(acc, codepoint, unit)

                  {_action, _unit}, acc ->
                    acc
                end)

              {profile, encoder}
            end)

  def source_sha256(:generic),
    do: "de2f25c0ebff74ee75c6fba8a4125b733800200525b8df84a9e40c667400f6ab"

  def source_sha256(profile) when profile in [:input, :output, :lossless_vpua, :raw_vpua],
    do: "469bcb196f0bc76b2bdbce3821a34fcd8e697bf20bb86a088746cd57ad673140"

  def source_pages(:generic), do: [113]
  def source_pages(profile) when profile in [:input, :output, :lossless_vpua, :raw_vpua], do: [19]

  def printed_source_pages(:generic), do: ["6-1"]

  def printed_source_pages(profile)
      when profile in [:input, :output, :lossless_vpua, :raw_vpua],
      do: ["3-4"]

  def source_url(:generic),
    do: "https://bitsavers.org/pdf/univac/1100/exec/UP-7824r1_EXEC_8_Hw_Sw_Summary_1974.pdf"

  def source_url(profile) when profile in [:input, :output, :lossless_vpua, :raw_vpua],
    do:
      "https://www.fourmilab.ch/documents/univac/manuals/pdf/1108/UP-7604r1_1106_1108_Systems_4009_Display_Console_Programmer_Reference_1974.pdf"

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
        :error ->
          encode(codepoints, profile)

        :discard ->
          encode_discard(codepoints, profile)

        {:replace, replacer} when is_function(replacer, 1) ->
          encode_substitute(codepoints, profile, replacer)
      end

    case result do
      {:ok, output} -> {:ok, output, []}
      error -> error
    end
  end

  def decode_to_utf8(input, profile) when is_binary(input),
    do: decode_utf8_all(input, table(profile), 0, [], 0, [])

  def encode_from_utf8(input, profile) when is_binary(input),
    do: encode_utf8_all(input, encoder(profile), 0, [], 0, [])

  defp table(profile), do: Map.fetch!(@tables, profile)
  defp encoder(profile), do: Map.fetch!(@encoders, profile)

  defp decode_all(<<>>, _table, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_all(<<unit, rest::binary>>, table, offset, acc) when unit < 64 do
    case elem(table, unit) do
      codepoint when is_integer(codepoint) ->
        decode_all(rest, table, offset + 1, [codepoint | acc])

      :ignored ->
        decode_all(rest, table, offset + 1, acc)

      :unavailable ->
        {:error, :invalid_sequence, offset, <<unit>>}
    end
  end

  defp decode_all(<<unit, _rest::binary>>, _table, offset, _acc),
    do: {:error, :invalid_sequence, offset, <<unit>>}

  defp decode_discard_all(<<>>, _table, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_all(<<unit, rest::binary>>, table, acc) when unit < 64 do
    case elem(table, unit) do
      codepoint when is_integer(codepoint) ->
        decode_discard_all(rest, table, [codepoint | acc])

      _action ->
        decode_discard_all(rest, table, acc)
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

  defp decode_utf8_all(<<unit, rest::binary>>, table, offset, acc, count, chunks)
       when unit < 64 do
    case elem(table, unit) do
      codepoint when is_integer(codepoint) ->
        {next_acc, next_count, next_chunks} = push_utf8(codepoint, acc, count, chunks)

        decode_utf8_all(
          rest,
          table,
          offset + 1,
          next_acc,
          next_count,
          next_chunks
        )

      :ignored ->
        decode_utf8_all(rest, table, offset + 1, acc, count, chunks)

      :unavailable ->
        {:error, :invalid_sequence, offset, <<unit>>}
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

  defp encode_utf8_all(
         <<codepoint, rest::binary>>,
         encoder,
         offset,
         acc,
         count,
         chunks
       )
       when codepoint < 0x80 do
    encode_utf8_codepoint(rest, encoder, offset + 1, codepoint, acc, count, chunks)
  end

  defp encode_utf8_all(input, encoder, offset, acc, count, chunks) do
    case input do
      <<codepoint::utf8, rest::binary>> ->
        consumed = byte_size(input) - byte_size(rest)

        encode_utf8_codepoint(
          rest,
          encoder,
          offset + consumed,
          codepoint,
          acc,
          count,
          chunks
        )

      _ ->
        Iconvex.Specs.CodecSupport.malformed_utf8(input, offset)
    end
  end

  defp encode_utf8_codepoint(rest, encoder, offset, codepoint, acc, count, chunks) do
    case encoder do
      %{^codepoint => unit} ->
        {next_acc, next_count, next_chunks} = push_unit(unit, acc, count, chunks)

        encode_utf8_all(
          rest,
          encoder,
          offset,
          next_acc,
          next_count,
          next_chunks
        )

      _ ->
        {:error, :unrepresentable_character, codepoint}
    end
  end

  defp push_utf8(codepoint, acc, count, chunks) when count == @chunk_units - 1 do
    chunk = [utf8(codepoint) | acc] |> :lists.reverse() |> IO.iodata_to_binary()
    {[], 0, [chunk | chunks]}
  end

  defp push_utf8(codepoint, acc, count, chunks),
    do: {[utf8(codepoint) | acc], count + 1, chunks}

  defp push_unit(unit, acc, count, chunks) when count == @chunk_units - 1 do
    chunk = [unit | acc] |> :lists.reverse() |> :erlang.list_to_binary()
    {[], 0, [chunk | chunks]}
  end

  defp push_unit(unit, acc, count, chunks), do: {[unit | acc], count + 1, chunks}

  defp utf8(codepoint) when codepoint < 0x80, do: codepoint
  defp utf8(codepoint), do: <<codepoint::utf8>>

  defp reverse_binary(acc), do: acc |> :lists.reverse() |> :erlang.list_to_binary()

  defp finish_iodata([], chunks),
    do: chunks |> :lists.reverse() |> IO.iodata_to_binary()

  defp finish_iodata(acc, chunks) do
    chunk = acc |> :lists.reverse() |> IO.iodata_to_binary()
    [chunk | chunks] |> :lists.reverse() |> IO.iodata_to_binary()
  end
end

defmodule Iconvex.Specs.Fieldata.Profile do
  @moduledoc false

  defmacro __using__(options) do
    profile = Keyword.fetch!(options, :profile)
    canonical = Keyword.fetch!(options, :canonical)
    aliases = Keyword.fetch!(options, :aliases)
    codec_id = Keyword.fetch!(options, :codec_id)

    quote do
      use Iconvex.Codec
      alias Iconvex.Specs.Fieldata, as: Engine

      @impl true
      def canonical_name, do: unquote(canonical)

      @impl true
      def aliases, do: unquote(aliases)

      @impl true
      def codec_id, do: unquote(codec_id)

      def unit_bits, do: 6
      def source_sha256, do: Engine.source_sha256(unquote(profile))
      def source_pages, do: Engine.source_pages(unquote(profile))
      def printed_source_pages, do: Engine.printed_source_pages(unquote(profile))
      def source_url, do: Engine.source_url(unquote(profile))

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
      def decode_chunk(input, final?),
        do: Engine.decode_chunk(input, unquote(profile), final?)

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

defmodule Iconvex.Specs.FieldataUNIVAC1100 do
  @moduledoc """
  The standard six-bit FIELDATA alphabet documented for the UNIVAC 1100
  Series. The byte API carries one six-bit unit in each octet; contiguous
  transports are provided by `Iconvex.Specs.Packed`.
  """

  use Iconvex.Specs.Fieldata.Profile,
    profile: :generic,
    canonical: "FIELDATA-UNIVAC-1100",
    aliases: [
      "EXEC-8-FIELDATA",
      "FIELDATA-1100",
      "UNIVAC-1100-FIELDATA",
      "SPERRY-UNIVAC-1100-FIELDATA",
      "UNIVAC-1106-FIELDATA",
      "UNIVAC-1108-FIELDATA",
      "UNISYS-FIELDATA"
    ],
    codec_id: :fieldata_univac_1100
end

defmodule Iconvex.Specs.FieldataUNIVAC4009Input do
  @moduledoc """
  The six-bit FIELDATA input view of the UNIVAC 4009 Display Console.

  Unit 04 is unavailable from the keyboard, NL is U+0085, and the proprietary
  master-space key retains a documented source-qualified VPUA identity.
  """

  use Iconvex.Specs.Fieldata.Profile,
    profile: :input,
    canonical: "FIELDATA-UNIVAC-4009-INPUT",
    aliases: [
      "UNIVAC-4009-FIELDATA-INPUT",
      "SPERRY-UNIVAC-4009-FIELDATA-INPUT"
    ],
    codec_id: :fieldata_univac_4009_input
end

defmodule Iconvex.Specs.FieldataUNIVAC4009Output do
  @moduledoc """
  The six-bit FIELDATA output view of the UNIVAC 4009 Display Console.

  The device ignores units 00 and 04. Unit 03 performs its combined-new-line
  action and maps to U+0085 without silently normalizing it to LF or CRLF.
  """

  use Iconvex.Specs.Fieldata.Profile,
    profile: :output,
    canonical: "FIELDATA-UNIVAC-4009-OUTPUT",
    aliases: [
      "UNIVAC-4009-FIELDATA-OUTPUT",
      "SPERRY-UNIVAC-4009-FIELDATA-OUTPUT"
    ],
    codec_id: :fieldata_univac_4009_output
end

defmodule Iconvex.Specs.FieldataUNIVAC4009LosslessVPUA do
  @moduledoc """
  A reversible semantic view of the UNIVAC 4009 table.

  Ordinary characters retain readable Unicode mappings. The proprietary
  master-space and diamond-enclosed wave glyph, plus the unavailable/ignored
  unit, use source-qualified Plane-15 private-use scalars.
  """

  use Iconvex.Specs.Fieldata.Profile,
    profile: :lossless_vpua,
    canonical: "FIELDATA-UNIVAC-4009-LOSSLESS-VPUA",
    aliases: [
      "UNIVAC-4009-FIELDATA-LOSSLESS-VPUA",
      "SPERRY-UNIVAC-4009-FIELDATA-LOSSLESS-VPUA"
    ],
    codec_id: :fieldata_univac_4009_lossless_vpua
end

defmodule Iconvex.Specs.FieldataUNIVAC4009RawVPUA do
  @moduledoc """
  A raw forensic view of UNIVAC 4009 FIELDATA.

  Unit `n` maps bijectively to U+F4000+`n`, preserving every source unit while
  making no potentially disputable semantic Unicode claim.
  """

  use Iconvex.Specs.Fieldata.Profile,
    profile: :raw_vpua,
    canonical: "FIELDATA-UNIVAC-4009-RAW-VPUA",
    aliases: [
      "UNIVAC-4009-FIELDATA-RAW-VPUA",
      "SPERRY-UNIVAC-4009-FIELDATA-RAW-VPUA"
    ],
    codec_id: :fieldata_univac_4009_raw_vpua
end

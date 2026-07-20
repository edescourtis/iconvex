defmodule Iconvex.Specs.TI89AMS20.SourceAsset do
  @moduledoc false

  @expected_preamble "# Independently derived from TI AMS 2.0 Appendix B, printed p555."
  @expected_header "# BYTE;SOURCE_GLYPH;VISIBLE;LOSSLESS_VPUA;RAW_VPUA"
  @profile_columns [source_glyph: 1, visible: 2, lossless_vpua: 3, raw_vpua: 4]

  def validate!(mapping_bytes, metadata_bytes, options)
      when is_binary(mapping_bytes) and is_binary(metadata_bytes) and is_list(options) do
    verify_sha!(:mapping, mapping_bytes, Keyword.fetch!(options, :mapping_sha256))
    verify_sha!(:metadata, metadata_bytes, Keyword.fetch!(options, :metadata_sha256))

    source_rows = extract_source_rows!(mapping_bytes)

    unless length(source_rows) == 256 do
      raise "TI AMS 2.0 mapping must contain exactly one ordered row for every byte 00..FF"
    end

    rows =
      source_rows
      |> Enum.with_index()
      |> Enum.map(fn {line, expected_byte} -> parse_row!(line, expected_byte) end)

    validate_unique_reverses!(rows)
    rows
  end

  defp verify_sha!(label, bytes, expected) do
    actual = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

    unless actual == expected do
      raise "TI AMS 2.0 #{label} asset SHA-256 mismatch: expected #{expected}, got #{actual}"
    end
  end

  defp extract_source_rows!(mapping_bytes) do
    case String.split(mapping_bytes, ~r/\R/, trim: true) do
      [@expected_preamble, @expected_header | source_rows] ->
        source_rows

      _ ->
        raise "unexpected TI AMS 2.0 mapping header; expected #{@expected_header}"
    end
  end

  defp parse_row!(line, expected_byte) do
    case String.split(line, ";") do
      [byte, source_glyph, visible, lossless_vpua, raw_vpua] ->
        expected_token = Base.encode16(<<expected_byte>>)

        unless byte == expected_token do
          raise "TI AMS 2.0 mapping must contain exactly one ordered row for every byte 00..FF; " <>
                  "BYTE must be exact two-digit uppercase hexadecimal #{expected_token}, " <>
                  "got #{inspect(byte)}"
        end

        {
          expected_byte,
          parse_sequence!(source_glyph),
          parse_sequence!(visible),
          parse_sequence!(lossless_vpua),
          parse_sequence!(raw_vpua)
        }

      _ ->
        raise "TI AMS 2.0 mapping row must contain exactly five fields: #{inspect(line)}"
    end
  end

  defp parse_sequence!(value) do
    case String.split(value, "+") do
      [codepoint] ->
        parse_scalar!(codepoint)

      [first, second] ->
        {parse_scalar!(first), parse_scalar!(second)}

      _ ->
        raise "TI AMS 2.0 mapping must contain one or two Unicode scalars: #{inspect(value)}"
    end
  end

  defp parse_scalar!(token) do
    if Regex.match?(~r/\A[0-9A-F]{4,6}\z/, token) do
      codepoint = String.to_integer(token, 16)

      if valid_scalar?(codepoint) do
        codepoint
      else
        raise "TI AMS 2.0 mapping contains invalid Unicode scalar: #{inspect(token)}"
      end
    else
      raise "TI AMS 2.0 mapping contains invalid Unicode scalar: #{inspect(token)}"
    end
  end

  defp valid_scalar?(codepoint),
    do: codepoint in 0x0000..0x10FFFF and codepoint not in 0xD800..0xDFFF

  defp validate_unique_reverses!(rows) do
    for {profile, column} <- @profile_columns do
      mappings = Enum.map(rows, &elem(&1, column))

      unless length(Enum.uniq(mappings)) == 256 do
        raise "TI AMS 2.0 #{profile} reverse mappings must be unique"
      end
    end
  end
end

defmodule Iconvex.Specs.TI89AMS20.Engine do
  @moduledoc false

  @mapping_path Path.expand(
                  "../../../priv/sources/ti-89-92-plus-ams-2.0/mapping.csv",
                  __DIR__
                )
  @metadata_path Path.expand(
                   "../../../priv/sources/ti-89-92-plus-ams-2.0/SOURCE_METADATA.md",
                   __DIR__
                 )

  @external_resource @mapping_path
  @external_resource @metadata_path

  @mapping_sha256 "be205ae316b916d6f2b386fd85729f51cdcd6852c9db64f014d0187a6345fb44"
  @metadata_sha256 "8d446d83fd5cda065ac304f416f84ea2d8754cb7d567bf390a0f980924bbf491"
  @source_sha256 "6e7266917fd2de05f7374ebe0de3ef898a06533e17fd9a5c6e4a3d3f237140a9"
  @corroborating_source_sha256 "95e086e54fa68df96b5a8249883a60797108dad2c32aa54b64fb84bf9150df1f"
  @source_url "https://education.ti.com/download/en/ed-tech/2110B5BC591D44E1AF4C28F00A6614B6/0470DB419F2144349E4032AFE3C0DD7E/8992bookeng.pdf"
  @corroborating_source_url "https://education.ti.com/download/en/ed-tech/FA1DC891957E4700B46A67255850C592/983EA8A4BA2A4AE9B2AF5EEEE922E3C1/TI-89_Guidebook_EN.pdf"

  @profiles %{source_glyph: 1, visible: 2, lossless_vpua: 3, raw_vpua: 4}
  @chunk_units 4_096

  @rows Iconvex.Specs.TI89AMS20.SourceAsset.validate!(
          File.read!(@mapping_path),
          File.read!(@metadata_path),
          mapping_sha256: @mapping_sha256,
          metadata_sha256: @metadata_sha256
        )

  @rows Enum.map(@rows, fn {byte, source_glyph, visible, lossless_vpua, raw_vpua} ->
          {byte, [source_glyph, visible, lossless_vpua, raw_vpua]}
        end)

  @tables Map.new(@profiles, fn {profile, column} ->
            table =
              @rows
              |> Enum.map(fn {_byte, mappings} -> Enum.at(mappings, column - 1) end)
              |> List.to_tuple()

            {profile, table}
          end)

  @single_encoders Map.new(@tables, fn {profile, table} ->
                     encoder =
                       table
                       |> Tuple.to_list()
                       |> Enum.with_index()
                       |> Enum.reduce(%{}, fn
                         {codepoint, byte}, acc when is_integer(codepoint) ->
                           Map.put(acc, codepoint, byte)

                         {_sequence, _byte}, acc ->
                           acc
                       end)

                     {profile, encoder}
                   end)

  @sequence_encoders Map.new(@tables, fn {profile, table} ->
                       encoder =
                         table
                         |> Tuple.to_list()
                         |> Enum.with_index()
                         |> Enum.reduce(%{}, fn
                           {sequence, byte}, acc when is_tuple(sequence) ->
                             Map.put(acc, sequence, byte)

                           {_codepoint, _byte}, acc ->
                             acc
                         end)

                       {profile, encoder}
                     end)

  @prefixes Map.new(@sequence_encoders, fn {profile, encoder} ->
              prefixes = encoder |> Map.keys() |> Enum.map(&elem(&1, 0)) |> MapSet.new()
              {profile, prefixes}
            end)

  @utf8_tables Map.new(@tables, fn {profile, table} ->
                 utf8 =
                   table
                   |> Tuple.to_list()
                   |> Enum.map(fn
                     codepoint when is_integer(codepoint) -> <<codepoint::utf8>>
                     sequence -> sequence |> Tuple.to_list() |> List.to_string()
                   end)
                   |> List.to_tuple()

                 {profile, utf8}
               end)

  def profiles, do: Map.keys(@profiles)
  def mapping_sha256, do: @mapping_sha256
  def metadata_sha256, do: @metadata_sha256
  def source_sha256, do: @source_sha256
  def source_pages, do: [436, 572]
  def printed_source_pages, do: [419, 555]
  def source_url, do: @source_url
  def corroborating_source_sha256, do: @corroborating_source_sha256
  def corroborating_source_pages, do: [926]
  def printed_corroborating_source_pages, do: [924]
  def corroborating_source_url, do: @corroborating_source_url

  def decode(input, profile) when is_binary(input),
    do: decode_all(input, table(profile), [])

  def decode_discard(input, profile) when is_binary(input), do: decode(input, profile)

  def decode_chunk(input, profile, _final?) when is_binary(input) do
    {:ok, codepoints} = decode(input, profile)
    {:ok, codepoints, <<>>}
  end

  def decode_to_utf8(input, profile) when is_binary(input),
    do: decode_utf8_all(input, utf8_table(profile), [], 0, [])

  def encode(codepoints, profile) when is_list(codepoints) do
    singles = single_encoder(profile)
    sequences = sequence_encoder(profile)

    if map_size(sequences) == 0,
      do: encode_single_all(codepoints, singles, []),
      else: encode_many_all(codepoints, singles, sequences, [])
  end

  def encode_discard(codepoints, profile) when is_list(codepoints) do
    singles = single_encoder(profile)
    sequences = sequence_encoder(profile)

    if map_size(sequences) == 0,
      do: encode_single_discard_all(codepoints, singles, []),
      else: encode_many_discard_all(codepoints, singles, sequences, [])
  end

  def encode_substitute(codepoints, profile, replacer)
      when is_list(codepoints) and is_function(replacer, 1) do
    singles = single_encoder(profile)
    sequences = sequence_encoder(profile)

    if map_size(sequences) == 0,
      do: encode_single_substitute_all(codepoints, profile, singles, replacer, []),
      else: encode_many_substitute_all(codepoints, profile, singles, sequences, replacer, [])
  end

  def encode_chunk(codepoints, profile, final?, policy)
      when is_list(codepoints) and is_boolean(final?) do
    singles = single_encoder(profile)
    sequences = sequence_encoder(profile)

    if map_size(sequences) == 0 do
      result = apply_policy(codepoints, profile, policy)

      case result do
        {:ok, bytes} -> {:ok, bytes, []}
        error -> error
      end
    else
      encode_chunk_many(
        codepoints,
        profile,
        singles,
        sequences,
        prefixes(profile),
        final?,
        policy,
        []
      )
    end
  end

  def encode_from_utf8(input, profile) when is_binary(input) do
    encode_utf8_all(
      input,
      profile,
      single_encoder(profile),
      sequence_encoder(profile),
      prefixes(profile),
      0,
      nil,
      [],
      0,
      []
    )
  end

  defp table(profile), do: Map.fetch!(@tables, profile)
  defp utf8_table(profile), do: Map.fetch!(@utf8_tables, profile)
  defp single_encoder(profile), do: Map.fetch!(@single_encoders, profile)
  defp sequence_encoder(profile), do: Map.fetch!(@sequence_encoders, profile)
  defp prefixes(profile), do: Map.fetch!(@prefixes, profile)

  defp decode_all(<<>>, _table, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_all(<<byte, rest::binary>>, table, acc) do
    case elem(table, byte) do
      codepoint when is_integer(codepoint) ->
        decode_all(rest, table, [codepoint | acc])

      {first, second} ->
        decode_all(rest, table, [second, first | acc])
    end
  end

  defp decode_utf8_all(<<>>, _table, acc, _count, chunks),
    do: {:ok, finish_iodata(acc, chunks)}

  defp decode_utf8_all(<<byte, rest::binary>>, table, acc, count, chunks) do
    {next_acc, next_count, next_chunks} = push_piece(elem(table, byte), acc, count, chunks)
    decode_utf8_all(rest, table, next_acc, next_count, next_chunks)
  end

  defp encode_single_all([], _singles, acc), do: {:ok, finish_bytes(acc)}

  defp encode_single_all([codepoint | rest], singles, acc) do
    case singles do
      %{^codepoint => byte} -> encode_single_all(rest, singles, [byte | acc])
      _ -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_many_all([], _singles, _sequences, acc), do: {:ok, finish_bytes(acc)}

  defp encode_many_all([first, second | rest], singles, sequences, acc) do
    case Map.fetch(sequences, {first, second}) do
      {:ok, byte} ->
        encode_many_all(rest, singles, sequences, [byte | acc])

      :error ->
        encode_many_single(first, [second | rest], singles, sequences, acc)
    end
  end

  defp encode_many_all([codepoint], singles, sequences, acc),
    do: encode_many_single(codepoint, [], singles, sequences, acc)

  defp encode_many_single(codepoint, rest, singles, sequences, acc) do
    case singles do
      %{^codepoint => byte} -> encode_many_all(rest, singles, sequences, [byte | acc])
      _ -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_single_discard_all([], _singles, acc), do: {:ok, finish_bytes(acc)}

  defp encode_single_discard_all([codepoint | rest], singles, acc) do
    case singles do
      %{^codepoint => byte} -> encode_single_discard_all(rest, singles, [byte | acc])
      _ -> encode_single_discard_all(rest, singles, acc)
    end
  end

  defp encode_many_discard_all([], _singles, _sequences, acc),
    do: {:ok, finish_bytes(acc)}

  defp encode_many_discard_all([first, second | rest], singles, sequences, acc) do
    case Map.fetch(sequences, {first, second}) do
      {:ok, byte} ->
        encode_many_discard_all(rest, singles, sequences, [byte | acc])

      :error ->
        encode_many_discard_single(first, [second | rest], singles, sequences, acc)
    end
  end

  defp encode_many_discard_all([codepoint], singles, sequences, acc),
    do: encode_many_discard_single(codepoint, [], singles, sequences, acc)

  defp encode_many_discard_single(codepoint, rest, singles, sequences, acc) do
    case singles do
      %{^codepoint => byte} ->
        encode_many_discard_all(rest, singles, sequences, [byte | acc])

      _ ->
        encode_many_discard_all(rest, singles, sequences, acc)
    end
  end

  defp encode_single_substitute_all([], _profile, _singles, _replacer, acc),
    do: {:ok, finish_bytes(acc)}

  defp encode_single_substitute_all([codepoint | rest], profile, singles, replacer, acc) do
    case singles do
      %{^codepoint => byte} ->
        encode_single_substitute_all(rest, profile, singles, replacer, [byte | acc])

      _ ->
        case encode(replacer.(codepoint), profile) do
          {:ok, replacement} ->
            encode_single_substitute_all(rest, profile, singles, replacer, [replacement | acc])

          error ->
            error
        end
    end
  end

  defp encode_many_substitute_all([], _profile, _singles, _sequences, _replacer, acc),
    do: {:ok, finish_bytes(acc)}

  defp encode_many_substitute_all(
         [first, second | rest],
         profile,
         singles,
         sequences,
         replacer,
         acc
       ) do
    case Map.fetch(sequences, {first, second}) do
      {:ok, byte} ->
        encode_many_substitute_all(rest, profile, singles, sequences, replacer, [byte | acc])

      :error ->
        encode_many_substitute_single(
          first,
          [second | rest],
          profile,
          singles,
          sequences,
          replacer,
          acc
        )
    end
  end

  defp encode_many_substitute_all(
         [codepoint],
         profile,
         singles,
         sequences,
         replacer,
         acc
       ),
       do:
         encode_many_substitute_single(
           codepoint,
           [],
           profile,
           singles,
           sequences,
           replacer,
           acc
         )

  defp encode_many_substitute_single(
         codepoint,
         rest,
         profile,
         singles,
         sequences,
         replacer,
         acc
       ) do
    case singles do
      %{^codepoint => byte} ->
        encode_many_substitute_all(rest, profile, singles, sequences, replacer, [byte | acc])

      _ ->
        case encode(replacer.(codepoint), profile) do
          {:ok, replacement} ->
            encode_many_substitute_all(
              rest,
              profile,
              singles,
              sequences,
              replacer,
              [replacement | acc]
            )

          error ->
            error
        end
    end
  end

  defp encode_chunk_many(
         [],
         _profile,
         _singles,
         _sequences,
         _prefixes,
         _final?,
         _policy,
         acc
       ),
       do: {:ok, finish_bytes(acc), []}

  defp encode_chunk_many(
         [first, second | rest],
         profile,
         singles,
         sequences,
         prefixes,
         final?,
         policy,
         acc
       ) do
    case Map.fetch(sequences, {first, second}) do
      {:ok, byte} ->
        encode_chunk_many(
          rest,
          profile,
          singles,
          sequences,
          prefixes,
          final?,
          policy,
          [byte | acc]
        )

      :error ->
        encode_chunk_single(
          first,
          [second | rest],
          profile,
          singles,
          sequences,
          prefixes,
          final?,
          policy,
          acc
        )
    end
  end

  defp encode_chunk_many(
         [codepoint],
         profile,
         singles,
         sequences,
         prefixes,
         final?,
         policy,
         acc
       ) do
    if not final? and MapSet.member?(prefixes, codepoint) do
      {:ok, finish_bytes(acc), [codepoint]}
    else
      encode_chunk_single(
        codepoint,
        [],
        profile,
        singles,
        sequences,
        prefixes,
        final?,
        policy,
        acc
      )
    end
  end

  defp encode_chunk_single(
         codepoint,
         rest,
         profile,
         singles,
         sequences,
         prefixes,
         final?,
         policy,
         acc
       ) do
    case singles do
      %{^codepoint => byte} ->
        encode_chunk_many(
          rest,
          profile,
          singles,
          sequences,
          prefixes,
          final?,
          policy,
          [byte | acc]
        )

      _ ->
        case stream_replacement(codepoint, profile, policy) do
          {:ok, replacement} ->
            encode_chunk_many(
              rest,
              profile,
              singles,
              sequences,
              prefixes,
              final?,
              policy,
              [replacement | acc]
            )

          error ->
            error
        end
    end
  end

  defp stream_replacement(codepoint, _profile, :error),
    do: {:error, :unrepresentable_character, codepoint}

  defp stream_replacement(_codepoint, _profile, :discard), do: {:ok, <<>>}

  defp stream_replacement(codepoint, profile, {:replace, replacer})
       when is_function(replacer, 1),
       do: encode(replacer.(codepoint), profile)

  defp apply_policy(codepoints, profile, :error), do: encode(codepoints, profile)
  defp apply_policy(codepoints, profile, :discard), do: encode_discard(codepoints, profile)

  defp apply_policy(codepoints, profile, {:replace, replacer}),
    do: encode_substitute(codepoints, profile, replacer)

  defp encode_utf8_all(
         <<>>,
         _profile,
         _singles,
         _sequences,
         _prefixes,
         _offset,
         nil,
         acc,
         _count,
         chunks
       ),
       do: {:ok, finish_iodata(acc, chunks)}

  defp encode_utf8_all(
         <<>>,
         _profile,
         singles,
         _sequences,
         _prefixes,
         _offset,
         pending,
         acc,
         count,
         chunks
       ) do
    case singles do
      %{^pending => byte} ->
        {next_acc, _next_count, next_chunks} = push_piece(byte, acc, count, chunks)
        {:ok, finish_iodata(next_acc, next_chunks)}

      _ ->
        {:error, :unrepresentable_character, pending}
    end
  end

  defp encode_utf8_all(
         input,
         profile,
         singles,
         sequences,
         prefixes,
         offset,
         pending,
         acc,
         count,
         chunks
       ) do
    case next_utf8(input) do
      {:ok, codepoint, rest, size} ->
        encode_utf8_codepoint(
          rest,
          profile,
          singles,
          sequences,
          prefixes,
          offset + size,
          pending,
          codepoint,
          acc,
          count,
          chunks
        )

      :error ->
        Iconvex.Specs.CodecSupport.malformed_utf8(input, offset)
    end
  end

  defp encode_utf8_codepoint(
         rest,
         profile,
         singles,
         sequences,
         prefixes,
         offset,
         nil,
         codepoint,
         acc,
         count,
         chunks
       ) do
    if MapSet.member?(prefixes, codepoint) do
      encode_utf8_all(
        rest,
        profile,
        singles,
        sequences,
        prefixes,
        offset,
        codepoint,
        acc,
        count,
        chunks
      )
    else
      case singles do
        %{^codepoint => byte} ->
          {next_acc, next_count, next_chunks} = push_piece(byte, acc, count, chunks)

          encode_utf8_all(
            rest,
            profile,
            singles,
            sequences,
            prefixes,
            offset,
            nil,
            next_acc,
            next_count,
            next_chunks
          )

        _ ->
          {:error, :unrepresentable_character, codepoint}
      end
    end
  end

  defp encode_utf8_codepoint(
         rest,
         profile,
         singles,
         sequences,
         prefixes,
         offset,
         pending,
         codepoint,
         acc,
         count,
         chunks
       ) do
    case Map.fetch(sequences, {pending, codepoint}) do
      {:ok, byte} ->
        {next_acc, next_count, next_chunks} = push_piece(byte, acc, count, chunks)

        encode_utf8_all(
          rest,
          profile,
          singles,
          sequences,
          prefixes,
          offset,
          nil,
          next_acc,
          next_count,
          next_chunks
        )

      :error ->
        case singles do
          %{^pending => byte} ->
            {next_acc, next_count, next_chunks} = push_piece(byte, acc, count, chunks)

            encode_utf8_codepoint(
              rest,
              profile,
              singles,
              sequences,
              prefixes,
              offset,
              nil,
              codepoint,
              next_acc,
              next_count,
              next_chunks
            )

          _ ->
            {:error, :unrepresentable_character, pending}
        end
    end
  end

  defp next_utf8(<<codepoint, rest::binary>>) when codepoint < 0x80,
    do: {:ok, codepoint, rest, 1}

  defp next_utf8(input) do
    case input do
      <<codepoint::utf8, rest::binary>> ->
        {:ok, codepoint, rest, byte_size(input) - byte_size(rest)}

      _ ->
        :error
    end
  end

  defp push_piece(piece, acc, count, chunks) when count == @chunk_units - 1 do
    chunk = [piece | acc] |> :lists.reverse() |> IO.iodata_to_binary()
    {[], 0, [chunk | chunks]}
  end

  defp push_piece(piece, acc, count, chunks), do: {[piece | acc], count + 1, chunks}

  defp finish_bytes(acc), do: acc |> :lists.reverse() |> IO.iodata_to_binary()

  defp finish_iodata([], chunks),
    do: chunks |> :lists.reverse() |> IO.iodata_to_binary()

  defp finish_iodata(acc, chunks) do
    chunk = acc |> :lists.reverse() |> IO.iodata_to_binary()
    [chunk | chunks] |> :lists.reverse() |> IO.iodata_to_binary()
  end
end

defmodule Iconvex.Specs.TI89AMS20.Profile do
  @moduledoc false

  defmacro __using__(options) do
    profile = Keyword.fetch!(options, :profile)
    canonical = Keyword.fetch!(options, :canonical)
    aliases = Keyword.fetch!(options, :aliases)
    codec_id = Keyword.fetch!(options, :codec_id)

    quote bind_quoted: [
            profile: profile,
            canonical: canonical,
            aliases: aliases,
            codec_id: codec_id
          ] do
      use Iconvex.Codec
      alias Iconvex.Specs.TI89AMS20.Engine

      @profile profile
      @canonical canonical
      @aliases aliases
      @codec_id codec_id

      @impl true
      def canonical_name, do: @canonical

      @impl true
      def aliases, do: @aliases

      @impl true
      def codec_id, do: @codec_id

      def unit_bits, do: 8
      def mapping_sha256, do: Engine.mapping_sha256()
      def metadata_sha256, do: Engine.metadata_sha256()
      def source_sha256, do: Engine.source_sha256()
      def source_pages, do: Engine.source_pages()
      def printed_source_pages, do: Engine.printed_source_pages()
      def source_url, do: Engine.source_url()
      def corroborating_source_sha256, do: Engine.corroborating_source_sha256()
      def corroborating_source_pages, do: Engine.corroborating_source_pages()
      def printed_corroborating_source_pages, do: Engine.printed_corroborating_source_pages()
      def corroborating_source_url, do: Engine.corroborating_source_url()

      @impl true
      def decode(input), do: Engine.decode(input, @profile)

      @impl true
      def decode_discard(input), do: Engine.decode_discard(input, @profile)

      @impl true
      def decode_chunk(input, final?), do: Engine.decode_chunk(input, @profile, final?)

      @impl true
      def decode_to_utf8(input), do: Engine.decode_to_utf8(input, @profile)

      @impl true
      def encode(codepoints), do: Engine.encode(codepoints, @profile)

      @impl true
      def encode_discard(codepoints), do: Engine.encode_discard(codepoints, @profile)

      @impl true
      def encode_substitute(codepoints, replacer),
        do: Engine.encode_substitute(codepoints, @profile, replacer)

      @impl true
      def encode_chunk(codepoints, final?, policy),
        do: Engine.encode_chunk(codepoints, @profile, final?, policy)

      @impl true
      def encode_from_utf8(input), do: Engine.encode_from_utf8(input, @profile)
    end
  end
end

defmodule Iconvex.Specs.TI89AMS20 do
  @moduledoc """
  Source-glyph profile for the TI-89 / TI-92 Plus AMS 2.0 character set.

  It preserves C0 control identities and uses audited readable glyph mappings
  without applying Unicode normalization or community mathematical semantics.
  """

  use Iconvex.Specs.TI89AMS20.Profile,
    profile: :source_glyph,
    canonical: "TI-89-92-PLUS-AMS-2.0",
    aliases: [
      "TI-89-AMS-2.0",
      "TI-92-PLUS-AMS-2.0",
      "TI89-AMS-2.0",
      "TI92PLUS-AMS-2.0"
    ],
    codec_id: :ti_89_92_plus_ams_2_0
end

defmodule Iconvex.Specs.TI89AMS20Visible do
  @moduledoc """
  Display-oriented AMS 2.0 profile using Unicode control pictures for the
  guidebook's printed C0 mnemonics.
  """

  use Iconvex.Specs.TI89AMS20.Profile,
    profile: :visible,
    canonical: "TI-89-92-PLUS-AMS-2.0-VISIBLE",
    aliases: ["TI-89-AMS-2.0-VISIBLE", "TI-92-PLUS-AMS-2.0-VISIBLE"],
    codec_id: :ti_89_92_plus_ams_2_0_visible
end

defmodule Iconvex.Specs.TI89AMS20LosslessVPUA do
  @moduledoc """
  Readable AMS 2.0 profile using source-qualified Plane-15 private-use scalars
  only for the seven cells whose Unicode semantics are not established.
  """

  use Iconvex.Specs.TI89AMS20.Profile,
    profile: :lossless_vpua,
    canonical: "TI-89-92-PLUS-AMS-2.0-LOSSLESS-VPUA",
    aliases: [
      "TI-89-AMS-2.0-LOSSLESS-VPUA",
      "TI-92-PLUS-AMS-2.0-LOSSLESS-VPUA"
    ],
    codec_id: :ti_89_92_plus_ams_2_0_lossless_vpua
end

defmodule Iconvex.Specs.TI89AMS20RawVPUA do
  @moduledoc """
  Forensic one-to-one AMS 2.0 mapping of all 256 bytes to U+F8A00–U+F8AFF.
  """

  use Iconvex.Specs.TI89AMS20.Profile,
    profile: :raw_vpua,
    canonical: "TI-89-92-PLUS-AMS-2.0-RAW-VPUA",
    aliases: ["TI-89-AMS-2.0-RAW-VPUA", "TI-92-PLUS-AMS-2.0-RAW-VPUA"],
    codec_id: :ti_89_92_plus_ams_2_0_raw_vpua
end

defmodule Iconvex.Specs.PASCII10.SourceAsset do
  @moduledoc false

  @header "byte_hex,status,urdu_kashmiri_best_fit,sindhi_best_fit,lossless_vpua_1,raw_vpua_1,provenance"
  @mapping_sha256 "335236d0b61cf050f3d0ab1d0fed7b66df6bb1c317da4291d109a8eb769d2cf5"
  @metadata_sha256 "7681febbdefbd5304a8f6402f7ebc34c742e0fdbaea0da690f7ca15e81d32c4e"
  @source_sha256 "8eb605e3a7e0dcfed1fdb58de7ddfa2171d964b7b43220a234cbd6924608ecea"
  @unassigned [0x80]
  @reserved [0xFA, 0xFB, 0xFE, 0xFF]
  @language_deltas [0x8C, 0x98, 0x9D, 0xAB, 0xBA]
  @source_vpua [0xC4, 0xD4, 0xEF]
  @projection_pattern ~r/\A[0-9A-F]{4,6}(?:\+[0-9A-F]{4,6})?\z/
  @provenance ~w(
    ascii_identity
    cdac_unassigned
    cdac_reserved
    cdac_cell_unicode17_name_glyph
    cdac_cell_unicode17_nearest_best_fit
    cdac_language_split_unicode17
    cdac_cell_iconvex_vpua
    cdac_cell_unicode17_nearest
    iconvex_logical_sequence_inference
  )

  @required_metadata [
    "PASCII (Perso-Arabic Standard for Information Interchange) Version 1.0",
    "October 2002",
    "physical PDF pages 4–7",
    "printed pages 61–64",
    "copyrighted reference only",
    "non-normative Unicode 17.0.0 best-fit projection",
    "Byte `80` is unassigned",
    "`CB` uses the nearest Unicode 17 best-fit scalar",
    "Persian and Arabic best-fit projections are intentionally withheld",
    "no unqualified PASCII alias",
    "LGPL-2.1-or-later",
    @source_sha256,
    @mapping_sha256
  ]

  @doc false
  def validate!(mapping_bytes, metadata_bytes, options)
      when is_binary(mapping_bytes) and is_binary(metadata_bytes) and is_list(options) do
    verify_sha!(:mapping, mapping_bytes, Keyword.fetch!(options, :mapping_sha256))
    verify_sha!(:metadata, metadata_bytes, Keyword.fetch!(options, :metadata_sha256))
    validate_metadata!(metadata_bytes)

    rows = parse_rows!(mapping_bytes)
    validate_source_domain!(rows)
    validate_projection_invariants!(rows)
    rows
  end

  def mapping_sha256, do: @mapping_sha256
  def metadata_sha256, do: @metadata_sha256
  def source_sha256, do: @source_sha256
  def source_size, do: 459_623
  def source_pages, do: %{physical_pdf: 4..7, printed: 61..64}
  def source_license, do: :copyrighted_reference_only

  def source_url,
    do:
      "https://www.cs.cmu.edu/afs/cs.cmu.edu/project/cmt-40/Nice/Urdu-MT/code/Tools/Encoding_Conversion/EncodingInfo/PASCIIStandard.pdf"

  defp verify_sha!(label, bytes, expected) do
    actual = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

    unless actual == expected do
      raise ArgumentError,
            "PASCII #{label} SHA-256 mismatch: expected #{expected}, got #{actual}"
    end
  end

  defp validate_metadata!(metadata) do
    unless Enum.all?(@required_metadata, &String.contains?(metadata, &1)) do
      raise ArgumentError, "PASCII metadata omits a required provenance or policy statement"
    end
  end

  defp parse_rows!(mapping_bytes) do
    if String.contains?(mapping_bytes, "\r") do
      raise ArgumentError, "PASCII mapping must use LF line endings"
    end

    lines = String.split(mapping_bytes, "\n", trim: false)

    unless List.last(lines) == "" and Enum.at(lines, -2) != "" do
      raise ArgumentError, "PASCII mapping must end with exactly one LF"
    end

    case Enum.drop(lines, -1) do
      [@header | source_rows] when length(source_rows) == 256 ->
        source_rows
        |> Enum.with_index()
        |> Enum.map(fn {row, byte} -> parse_row!(row, byte) end)

      [@header | source_rows] ->
        raise ArgumentError,
              "PASCII mapping must contain 256 data rows, got #{length(source_rows)}"

      [header | _rows] ->
        raise ArgumentError, "unexpected PASCII mapping header: #{inspect(header)}"

      [] ->
        raise ArgumentError, "unexpected PASCII mapping header: missing"
    end
  end

  defp parse_row!(row, expected_byte) do
    expected_hex = Base.encode16(<<expected_byte>>)

    case String.split(row, ",", parts: 7) do
      [^expected_hex, status, urdu, sindhi, lossless, raw, provenance] ->
        %{
          byte: expected_byte,
          status: parse_status!(status, expected_hex),
          urdu_kashmiri_best_fit: parse_projection!(urdu, expected_hex),
          sindhi_best_fit: parse_projection!(sindhi, expected_hex),
          lossless_vpua_1: parse_projection!(lossless, expected_hex),
          raw_vpua_1: parse_projection!(raw, expected_hex),
          provenance: parse_provenance!(provenance, expected_hex)
        }

      [byte_hex, _status, _urdu, _sindhi, _lossless, _raw, _provenance] ->
        raise ArgumentError,
              "PASCII mapping must contain ordered row #{expected_hex}; got #{inspect(byte_hex)}"

      _ ->
        raise ArgumentError, "PASCII row #{expected_hex} must contain exactly seven fields"
    end
  end

  defp parse_status!("ascii", _byte), do: :ascii
  defp parse_status!("assigned", _byte), do: :assigned
  defp parse_status!("unassigned", _byte), do: :unassigned
  defp parse_status!("reserved", _byte), do: :reserved

  defp parse_status!(status, byte),
    do: raise(ArgumentError, "PASCII row #{byte} has invalid status #{inspect(status)}")

  defp parse_projection!("", _byte), do: :invalid

  defp parse_projection!(projection, byte) do
    unless Regex.match?(@projection_pattern, projection) do
      raise ArgumentError,
            "PASCII row #{byte} has invalid Unicode projection #{inspect(projection)}"
    end

    values = projection |> String.split("+") |> Enum.map(&String.to_integer(&1, 16))

    unless Enum.all?(values, &unicode_scalar?/1) do
      raise ArgumentError, "PASCII row #{byte} contains a non-scalar Unicode value"
    end

    case values do
      [codepoint] -> codepoint
      [first, second] -> {first, second}
    end
  end

  defp parse_provenance!(provenance, _byte) when provenance in @provenance,
    do: provenance

  defp parse_provenance!(provenance, byte),
    do: raise(ArgumentError, "PASCII row #{byte} has invalid provenance #{inspect(provenance)}")

  defp validate_source_domain!(rows) do
    Enum.each(rows, fn row ->
      byte = row.byte

      cond do
        byte < 0x80 ->
          unless row.status == :ascii and row.urdu_kashmiri_best_fit == byte and
                   row.sindhi_best_fit == byte and row.lossless_vpua_1 == byte and
                   row.raw_vpua_1 == 0xF8D00 + byte and row.provenance == "ascii_identity" do
            raise ArgumentError, "PASCII ASCII identity invariants failed at byte #{hex(byte)}"
          end

        byte in @unassigned ->
          unless row.status == :unassigned and row.urdu_kashmiri_best_fit == :invalid and
                   row.sindhi_best_fit == :invalid and row.lossless_vpua_1 == :invalid and
                   row.raw_vpua_1 == 0xF8D00 + byte and row.provenance == "cdac_unassigned" do
            raise ArgumentError, "PASCII unassigned-cell invariants failed at byte #{hex(byte)}"
          end

        byte in @reserved ->
          unless row.status == :reserved and row.urdu_kashmiri_best_fit == :invalid and
                   row.sindhi_best_fit == :invalid and row.lossless_vpua_1 == :invalid and
                   row.raw_vpua_1 == 0xF8D00 + byte and row.provenance == "cdac_reserved" do
            raise ArgumentError, "PASCII reserved-cell invariants failed at byte #{hex(byte)}"
          end

        true ->
          unless row.status == :assigned and row.urdu_kashmiri_best_fit != :invalid and
                   row.sindhi_best_fit != :invalid and row.lossless_vpua_1 == 0xF8C00 + byte and
                   row.raw_vpua_1 == 0xF8D00 + byte do
            raise ArgumentError, "PASCII assigned-cell invariants failed at byte #{hex(byte)}"
          end
      end
    end)
  end

  defp validate_projection_invariants!(rows) do
    deltas =
      for row <- rows,
          row.urdu_kashmiri_best_fit != row.sindhi_best_fit,
          do: row.byte

    unless deltas == @language_deltas do
      raise ArgumentError, "PASCII language-profile deltas are not canonical"
    end

    expected_deltas = %{
      0x8C => {0x0679, 0x067D},
      0x98 => {0x0688, 0x068A},
      0x9D => {0x0691, 0x0699},
      0xAB => {0x06A9, 0x06AA},
      0xBA => {0x06CC, 0x064A}
    }

    language_ok? =
      Enum.all?(expected_deltas, fn {byte, {urdu, sindhi}} ->
        row = Enum.at(rows, byte)

        row.urdu_kashmiri_best_fit == urdu and row.sindhi_best_fit == sindhi and
          row.provenance == "cdac_language_split_unicode17"
      end)

    source_vpua =
      for row <- rows,
          row.urdu_kashmiri_best_fit == 0xF8C00 + row.byte and
            row.sindhi_best_fit == 0xF8C00 + row.byte,
          do: row.byte

    row_9e = Enum.at(rows, 0x9E)
    row_cb = Enum.at(rows, 0xCB)

    unless language_ok? and source_vpua == @source_vpua and
             row_9e.urdu_kashmiri_best_fit == {0x0699, 0x06BE} and
             row_9e.sindhi_best_fit == {0x0699, 0x06BE} and
             row_9e.provenance == "iconvex_logical_sequence_inference" and
             row_cb.urdu_kashmiri_best_fit == 0xFBC2 and
             row_cb.sindhi_best_fit == 0xFBC2 and
             row_cb.provenance == "cdac_cell_unicode17_nearest_best_fit" and
             sequence_count(rows, :urdu_kashmiri_best_fit) == 1 and
             sequence_count(rows, :sindhi_best_fit) == 1 and
             sequence_count(rows, :lossless_vpua_1) == 0 and
             sequence_count(rows, :raw_vpua_1) == 0 do
      raise ArgumentError, "PASCII Unicode 17 projection invariants are not canonical"
    end
  end

  defp sequence_count(rows, field),
    do: Enum.count(rows, &is_tuple(Map.fetch!(&1, field)))

  defp unicode_scalar?(codepoint),
    do: codepoint in 0..0x10FFFF and codepoint not in 0xD800..0xDFFF

  defp hex(byte), do: Base.encode16(<<byte>>)
end

defmodule Iconvex.Specs.PASCII10.Engine do
  @moduledoc false

  alias Iconvex.Specs.PASCII10.SourceAsset

  @source_dir Path.expand("../../../priv/sources/pascii-cdac-gist-1.0-2002", __DIR__)
  @mapping_path Path.join(@source_dir, "mapping.csv")
  @metadata_path Path.join(@source_dir, "SOURCE_METADATA.md")
  @external_resource @mapping_path
  @external_resource @metadata_path

  @mapping_sha256 "335236d0b61cf050f3d0ab1d0fed7b66df6bb1c317da4291d109a8eb769d2cf5"
  @metadata_sha256 "7681febbdefbd5304a8f6402f7ebc34c742e0fdbaea0da690f7ca15e81d32c4e"
  @profiles [:urdu_kashmiri_best_fit, :sindhi_best_fit, :lossless_vpua_1, :raw_vpua_1]
  @chunk_units 4_096

  rows =
    SourceAsset.validate!(File.read!(@mapping_path), File.read!(@metadata_path),
      mapping_sha256: @mapping_sha256,
      metadata_sha256: @metadata_sha256
    )

  tables =
    Map.new(@profiles, fn profile ->
      {profile, rows |> Enum.map(&Map.fetch!(&1, profile)) |> List.to_tuple()}
    end)

  single_encoders =
    Map.new(tables, fn {profile, table} ->
      encoder =
        table
        |> Tuple.to_list()
        |> Enum.with_index()
        |> Enum.reduce(%{}, fn
          {codepoint, byte}, acc when is_integer(codepoint) -> Map.put_new(acc, codepoint, byte)
          {_sequence_or_invalid, _byte}, acc -> acc
        end)

      {profile, encoder}
    end)

  sequence_encoders =
    Map.new(tables, fn {profile, table} ->
      encoder =
        table
        |> Tuple.to_list()
        |> Enum.with_index()
        |> Enum.reduce(%{}, fn
          {{first, second}, byte}, acc -> Map.put_new(acc, {first, second}, byte)
          {_scalar_or_invalid, _byte}, acc -> acc
        end)

      {profile, encoder}
    end)

  prefixes =
    Map.new(sequence_encoders, fn {profile, encoder} ->
      {profile, encoder |> Map.keys() |> Enum.map(&elem(&1, 0)) |> MapSet.new()}
    end)

  @tables tables
  @single_encoders single_encoders
  @sequence_encoders sequence_encoders
  @prefixes prefixes

  def decode(input, profile) when is_binary(input),
    do: decode_all(input, table(profile), 0, [])

  def decode_discard(input, profile) when is_binary(input),
    do: decode_discard_all(input, table(profile), [])

  def decode_chunk(input, profile, _final?) when is_binary(input) do
    case decode(input, profile) do
      {:ok, codepoints} -> {:ok, codepoints, <<>>}
      error -> error
    end
  end

  def decode_to_utf8(input, profile) when is_binary(input) do
    case decode(input, profile) do
      {:ok, codepoints} -> {:ok, List.to_string(codepoints)}
      error -> error
    end
  end

  def encode(codepoints, profile) when is_list(codepoints) do
    case encode_all(codepoints, profile, true, :error) do
      {:ok, bytes, []} -> {:ok, bytes}
      error -> error
    end
  end

  def encode_discard(codepoints, profile) when is_list(codepoints) do
    case encode_all(codepoints, profile, true, :discard) do
      {:ok, bytes, []} -> {:ok, bytes}
      error -> error
    end
  end

  def encode_substitute(codepoints, profile, replacer)
      when is_list(codepoints) and is_function(replacer, 1) do
    case encode_all(codepoints, profile, true, {:replace, replacer}) do
      {:ok, bytes, []} -> {:ok, bytes}
      error -> error
    end
  end

  def encode_chunk(codepoints, profile, final?, policy)
      when is_list(codepoints) and is_boolean(final?),
      do: encode_all(codepoints, profile, final?, policy)

  def encode_from_utf8(input, profile) when is_binary(input) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        encode(codepoints, profile)

      _malformed ->
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
  end

  defp table(profile), do: Map.fetch!(@tables, profile)
  defp single_encoder(profile), do: Map.fetch!(@single_encoders, profile)
  defp sequence_encoder(profile), do: Map.fetch!(@sequence_encoders, profile)
  defp prefixes(profile), do: Map.fetch!(@prefixes, profile)

  defp decode_all(<<>>, _table, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_all(<<byte, rest::binary>>, table, offset, acc) do
    case elem(table, byte) do
      :invalid ->
        {:error, :invalid_sequence, offset, <<byte>>}

      codepoint when is_integer(codepoint) ->
        decode_all(rest, table, offset + 1, [codepoint | acc])

      {first, second} ->
        decode_all(rest, table, offset + 1, [second, first | acc])
    end
  end

  defp decode_discard_all(<<>>, _table, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_all(<<byte, rest::binary>>, table, acc) do
    case elem(table, byte) do
      :invalid -> decode_discard_all(rest, table, acc)
      codepoint when is_integer(codepoint) -> decode_discard_all(rest, table, [codepoint | acc])
      {first, second} -> decode_discard_all(rest, table, [second, first | acc])
    end
  end

  defp encode_all(codepoints, profile, final?, policy) do
    encode_all(
      codepoints,
      profile,
      single_encoder(profile),
      sequence_encoder(profile),
      prefixes(profile),
      final?,
      policy,
      []
    )
  end

  defp encode_all([], _profile, _singles, _sequences, _prefixes, _final?, _policy, acc),
    do: {:ok, finish_bytes(acc), []}

  defp encode_all(
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
        encode_all(rest, profile, singles, sequences, prefixes, final?, policy, [byte | acc])

      :error ->
        encode_one(
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

  defp encode_all(
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
      encode_one(
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

  defp encode_one(
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
        encode_all(rest, profile, singles, sequences, prefixes, final?, policy, [byte | acc])

      _ ->
        case replacement(codepoint, profile, policy) do
          {:ok, bytes} ->
            encode_all(rest, profile, singles, sequences, prefixes, final?, policy, [bytes | acc])

          error ->
            error
        end
    end
  end

  defp replacement(codepoint, _profile, :error),
    do: {:error, :unrepresentable_character, codepoint}

  defp replacement(_codepoint, _profile, :discard), do: {:ok, <<>>}

  defp replacement(codepoint, profile, {:replace, replacer}) when is_function(replacer, 1),
    do: encode(replacer.(codepoint), profile)

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
        case pending do
          nil -> Iconvex.Specs.CodecSupport.malformed_utf8(input, offset)
          _ -> malformed_after_pending(input, offset, pending, singles)
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

  defp malformed_after_pending(input, offset, pending, singles) do
    case singles do
      %{^pending => _byte} -> Iconvex.Specs.CodecSupport.malformed_utf8(input, offset)
      _ -> {:error, :unrepresentable_character, pending}
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

defmodule Iconvex.Specs.PASCII10.Profile do
  @moduledoc false

  defmacro __using__(options) do
    profile = Keyword.fetch!(options, :profile)
    canonical = Keyword.fetch!(options, :canonical)
    codec_id = Keyword.fetch!(options, :codec_id)
    projection_status = Keyword.fetch!(options, :projection_status)

    quote bind_quoted: [
            profile: profile,
            canonical: canonical,
            codec_id: codec_id,
            projection_status: projection_status
          ] do
      use Iconvex.Codec

      alias Iconvex.Specs.PASCII10.Engine
      alias Iconvex.Specs.PASCII10.SourceAsset

      @profile profile
      @canonical canonical
      @codec_id codec_id
      @projection_status projection_status

      @impl true
      def canonical_name, do: @canonical

      @impl true
      def aliases, do: []

      @impl true
      def codec_id, do: @codec_id

      def unit_bits, do: 8
      def packed_applicability, do: :not_applicable_octet_codec
      def gnu_libiconv_support, do: :unsupported
      def projection_status, do: @projection_status
      def mapping_sha256, do: SourceAsset.mapping_sha256()
      def metadata_sha256, do: SourceAsset.metadata_sha256()
      def source_sha256, do: SourceAsset.source_sha256()
      def source_size, do: SourceAsset.source_size()
      def source_pages, do: SourceAsset.source_pages()
      def source_license, do: SourceAsset.source_license()
      def source_url, do: SourceAsset.source_url()

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

defmodule Iconvex.Specs.PASCII10UrduKashmiriBestFit do
  @moduledoc "C-DAC GIST PASCII 1.0 Urdu/Kashmiri Unicode 17 best-fit projection."

  use Iconvex.Specs.PASCII10.Profile,
    profile: :urdu_kashmiri_best_fit,
    canonical: "PASCII-CDAC-GIST-1.0-2002-URDU-KASHMIRI-UNICODE17-BEST-FIT",
    codec_id: :pascii_10_urdu_kashmiri_best_fit,
    projection_status: :non_normative_unicode_17_best_fit
end

defmodule Iconvex.Specs.PASCII10SindhiBestFit do
  @moduledoc "C-DAC GIST PASCII 1.0 Sindhi Unicode 17 best-fit projection."

  use Iconvex.Specs.PASCII10.Profile,
    profile: :sindhi_best_fit,
    canonical: "PASCII-CDAC-GIST-1.0-2002-SINDHI-UNICODE17-BEST-FIT",
    codec_id: :pascii_10_sindhi_best_fit,
    projection_status: :non_normative_unicode_17_best_fit
end

defmodule Iconvex.Specs.PASCII10LosslessVPUA1 do
  @moduledoc "Exact opaque source-identity profile for assigned C-DAC GIST PASCII 1.0 bytes."

  use Iconvex.Specs.PASCII10.Profile,
    profile: :lossless_vpua_1,
    canonical: "PASCII-CDAC-GIST-1.0-2002-LOSSLESS-VPUA-1",
    codec_id: :pascii_10_lossless_vpua_1,
    projection_status: :exact_source_identity_vpua
end

defmodule Iconvex.Specs.PASCII10RawVPUA1 do
  @moduledoc "Forensic one-to-one profile for all 256 C-DAC GIST PASCII 1.0 byte values."

  use Iconvex.Specs.PASCII10.Profile,
    profile: :raw_vpua_1,
    canonical: "PASCII-CDAC-GIST-1.0-2002-RAW-VPUA-1",
    codec_id: :pascii_10_raw_vpua_1,
    projection_status: :forensic_raw_vpua
end

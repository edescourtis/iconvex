defmodule Iconvex.Specs.CorkT1.SourceAsset do
  @moduledoc false

  @header "byte_hex,byte_octal,glyph_name,ec_unicode_sequence,cmap_unicode_sequence,status,notes"
  @difference_bytes [0x17, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x7F, 0x95, 0xB5]
  @mapping_pattern ~r/\A[0-9A-F]{4,6}(?:\+[0-9A-F]{4,6}){0,2}\z/
  @text_pattern ~r/\A[A-Za-z0-9_.-]+\z/
  @note_pattern ~r/\A[a-zA-Z0-9_]*\z/

  def validate!(mapping_bytes, metadata_bytes, options)
      when is_binary(mapping_bytes) and is_binary(metadata_bytes) and is_list(options) do
    verify_sha!(:mapping, mapping_bytes, Keyword.fetch!(options, :mapping_sha256))
    verify_sha!(:metadata, metadata_bytes, Keyword.fetch!(options, :metadata_sha256))
    validate_metadata!(metadata_bytes)

    rows = parse_rows!(mapping_bytes)
    validate_profile_invariants!(rows)
    rows
  end

  defp verify_sha!(label, bytes, expected) do
    actual = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

    unless actual == expected do
      raise ArgumentError,
            "Cork/T1 #{label} SHA-256 mismatch: expected #{expected}, got #{actual}"
    end
  end

  defp validate_metadata!(metadata) do
    required = [
      "LGPL-2.1-or-later",
      "Cork/T1 is a font-glyph encoding",
      "perthousandzero",
      "GNU libiconv does not expose Cork/T1"
    ]

    unless Enum.all?(required, &String.contains?(metadata, &1)) do
      raise ArgumentError, "Cork/T1 metadata omits a required provenance or policy statement"
    end
  end

  defp parse_rows!(mapping_bytes) do
    lines = String.split(mapping_bytes, "\n", trim: false)

    unless List.last(lines) == "" and Enum.at(lines, -2) != "" do
      raise ArgumentError, "Cork/T1 mapping must end with exactly one LF"
    end

    case Enum.drop(lines, -1) do
      [@header | source_rows] when length(source_rows) == 256 ->
        source_rows
        |> Enum.with_index()
        |> Enum.map(fn {row, byte} -> parse_row!(row, byte) end)

      [@header | source_rows] ->
        raise ArgumentError,
              "Cork/T1 mapping must contain 256 data rows, got #{length(source_rows)}"

      [header | _rows] ->
        raise ArgumentError, "unexpected Cork/T1 mapping header: #{inspect(header)}"

      [] ->
        raise ArgumentError, "unexpected Cork/T1 mapping header: missing"
    end
  end

  defp parse_row!(row, expected_byte) do
    case String.split(row, ",", parts: 7) do
      [hex, octal, glyph, ec, cmap, status, notes] ->
        expected_hex = expected_byte |> Integer.to_string(16) |> String.upcase() |> pad(2)
        expected_octal = expected_byte |> Integer.to_string(8) |> pad(3)

        unless hex == expected_hex do
          raise ArgumentError,
                "Cork/T1 mapping must contain ordered row #{expected_hex}; got #{inspect(hex)}"
        end

        unless octal == expected_octal do
          raise ArgumentError,
                "Cork/T1 row #{expected_hex} must use octal #{expected_octal}; got #{inspect(octal)}"
        end

        unless Regex.match?(@text_pattern, glyph) do
          raise ArgumentError, "Cork/T1 row #{expected_hex} has an invalid glyph name"
        end

        unless Regex.match?(@note_pattern, notes) do
          raise ArgumentError, "Cork/T1 row #{expected_hex} has an invalid note token"
        end

        %{
          byte: expected_byte,
          glyph: glyph,
          ec: parse_mapping!(ec, expected_hex, :ec),
          cmap: parse_mapping!(cmap, expected_hex, :cmap),
          status: parse_status!(status, expected_hex),
          notes: notes
        }

      _ ->
        raise ArgumentError,
              "Cork/T1 row #{Base.encode16(<<expected_byte>>)} must contain exactly seven fields"
    end
  end

  defp parse_mapping!("", _byte, _profile), do: :undefined

  defp parse_mapping!(mapping, byte, profile) do
    unless Regex.match?(@mapping_pattern, mapping) do
      raise ArgumentError,
            "Cork/T1 row #{byte} has invalid #{profile} Unicode sequence #{inspect(mapping)}"
    end

    codepoints = mapping |> String.split("+") |> Enum.map(&String.to_integer(&1, 16))

    unless Enum.all?(codepoints, &unicode_scalar?/1) do
      raise ArgumentError, "Cork/T1 row #{byte} contains a non-scalar Unicode value"
    end

    case codepoints do
      [codepoint] -> codepoint
      [first, second] -> {first, second}
      [first, second, third] -> {first, second, third}
    end
  end

  defp parse_status!("assigned", _byte), do: :assigned
  defp parse_status!("undefined", _byte), do: :undefined
  defp parse_status!("overloaded", _byte), do: :overloaded

  defp parse_status!(status, byte),
    do: raise(ArgumentError, "Cork/T1 row #{byte} has invalid status #{inspect(status)}")

  defp validate_profile_invariants!(rows) do
    undefined = Enum.filter(rows, &(&1.status == :undefined))
    overloaded = Enum.filter(rows, &(&1.status == :overloaded))
    differences = Enum.filter(rows, &(&1.ec != &1.cmap)) |> Enum.map(& &1.byte)

    unless Enum.map(undefined, & &1.byte) == [0x18] and
             Enum.map(overloaded, & &1.byte) == [0xD0] and
             differences == @difference_bytes do
      raise ArgumentError, "Cork/T1 source profile status or difference set is not canonical"
    end

    row_18 = Enum.at(rows, 0x18)
    row_d0 = Enum.at(rows, 0xD0)
    row_df = Enum.at(rows, 0xDF)

    unless row_18.glyph == "perthousandzero" and row_18.ec == :undefined and
             row_18.cmap == :undefined and row_d0.glyph == "Eth" and row_d0.ec == 0x00D0 and
             row_d0.cmap == 0x00D0 and row_df.ec == {?S, ?S} and row_df.cmap == {?S, ?S} do
      raise ArgumentError, "Cork/T1 special glyph semantics are not canonical"
    end

    ec = Enum.map(rows, & &1.ec) |> Enum.reject(&(&1 == :undefined))
    cmap = Enum.map(rows, & &1.cmap) |> Enum.reject(&(&1 == :undefined))

    unless length(ec) == 255 and length(Enum.uniq(ec)) == 254 and
             Enum.count(ec, &is_tuple/1) == 1 and length(cmap) == 255 and
             length(Enum.uniq(cmap)) == 255 and Enum.count(cmap, &is_tuple/1) == 6 do
      raise ArgumentError, "Cork/T1 source profile cardinalities are not canonical"
    end
  end

  defp unicode_scalar?(codepoint),
    do: codepoint in 0..0x10FFFF and codepoint not in 0xD800..0xDFFF

  defp pad(value, width), do: String.duplicate("0", width - byte_size(value)) <> value
end

defmodule Iconvex.Specs.CorkT1 do
  @moduledoc false

  defguardp ec_identity_byte(byte)
            when (byte in 0x21..0x26 or byte in 0x28..0x5F or byte in 0x61..0x7E) and
                   byte != ?S

  defguardp cmap_identity_byte(byte)
            when (byte in 0x21..0x26 or byte in 0x28..0x5F or byte in 0x61..0x7E) and
                   byte != ?S and byte != ?f

  @source_dir Path.expand("../../../priv/sources/cork-t1", __DIR__)
  @mapping_path Path.join(@source_dir, "cork_t1_slots.csv")
  @metadata_path Path.join(@source_dir, "SOURCE_METADATA.md")
  @external_resource @mapping_path
  @external_resource @metadata_path

  @mapping_sha256 "5a61cedd1713ec413c686b6fdcbb9791f2f9afca8a47d356eb1add25b5f458dc"
  @metadata_sha256 "783bfda2d4c8ef0d12f1c849b929dc8a3d3ad03bc9810a34639ef8f7c8b205db"
  @ferguson_sha256 "ce79e1e82074f4d48abd15c9bc4f38619d1469bf96c532941e3bbd1df409a74c"
  @ec_encoding_sha256 "bd865bb53fe3c2f479efa8e3d92e1027db5e64a1d7c0ced7884d6c9ee65c0b48"
  @latex_source_sha256 "61cc867257831d2611e2d96ead2a1882f03e4da27c095b642cc866984aac0bc2"
  @cmap_archive_sha256 "b5fffa016ac4571f0405592ac40bf231f9ddb6b1ce3100d17a33833284bbeb84"
  @t1_cmap_sha256 "e43d20b203a25786d101e757d312b3660bc2505d57251db7701cd3f69e6d1f42"
  @profile_differences [0x17, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x7F, 0x95, 0xB5]
  @non_ascii_patterns for(byte <- 0x80..0xFF, do: <<byte>>)
  @ec_utf8_fallback_patterns [<<?S>> | @non_ascii_patterns]
  @cmap_utf8_fallback_patterns [<<?f>>, <<?S>> | @non_ascii_patterns]
  @chunk_units 4_096

  @rows Iconvex.Specs.CorkT1.SourceAsset.validate!(
          File.read!(@mapping_path),
          File.read!(@metadata_path),
          mapping_sha256: @mapping_sha256,
          metadata_sha256: @metadata_sha256
        )

  @tables %{
    ec_glyph: @rows |> Enum.map(& &1.ec) |> List.to_tuple(),
    cmap_1_0j: @rows |> Enum.map(& &1.cmap) |> List.to_tuple()
  }

  @utf8_tables Map.new(@tables, fn {profile, table} ->
                 utf8_table =
                   table
                   |> Tuple.to_list()
                   |> Enum.map(fn
                     :undefined ->
                       :undefined

                     codepoint when codepoint < 0x80 ->
                       codepoint

                     codepoint when is_integer(codepoint) ->
                       <<codepoint::utf8>>

                     sequence when is_tuple(sequence) ->
                       sequence |> Tuple.to_list() |> List.to_string()
                   end)
                   |> List.to_tuple()

                 {profile, utf8_table}
               end)

  @single_encoders Map.new(@tables, fn {profile, table} ->
                     encoder =
                       table
                       |> Tuple.to_list()
                       |> Enum.with_index()
                       |> Enum.reduce(%{}, fn
                         {codepoint, byte}, acc when is_integer(codepoint) ->
                           Map.put_new(acc, codepoint, byte)

                         {_sequence_or_undefined, _byte}, acc ->
                           acc
                       end)

                     {profile, encoder}
                   end)

  def mapping_sha256, do: @mapping_sha256
  def metadata_sha256, do: @metadata_sha256
  def ferguson_sha256, do: @ferguson_sha256
  def ec_encoding_sha256, do: @ec_encoding_sha256
  def latex_source_sha256, do: @latex_source_sha256
  def cmap_archive_sha256, do: @cmap_archive_sha256
  def t1_cmap_sha256, do: @t1_cmap_sha256
  def profile_differences, do: @profile_differences

  def ferguson_url, do: "https://www.tug.org/TUGboat/tb11-4/tb30ferguson.pdf"
  def ec_encoding_url, do: "https://tug.ctan.org/info/fontname/ec.enc"

  def latex_source_url,
    do:
      "https://github.com/latex3/latex2e/blob/5954204ffe58a81db0e0de1335c62cd45c8caf9b/base/ltoutenc.dtx"

  def cmap_archive_url, do: "https://tug.ctan.org/macros/latex/contrib/cmap.zip"

  def profile_counts(profile) when profile in [:ec_glyph, :cmap_1_0j] do
    values = profile |> table() |> Tuple.to_list() |> Enum.reject(&(&1 == :undefined))

    %{
      defined: length(values),
      scalars: Enum.count(values, &is_integer/1),
      sequences: Enum.count(values, &is_tuple/1)
    }
  end

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

  def decode_to_utf8(input, profile) when is_binary(input),
    do: decode_utf8_all(input, utf8_table(profile), 0, [], 0, [])

  def encode(codepoints, profile) when is_list(codepoints) do
    case encode_all(codepoints, profile, true, :error) do
      {:ok, output, []} -> {:ok, output}
      error -> error
    end
  end

  def encode_discard(codepoints, profile) when is_list(codepoints) do
    case encode_all(codepoints, profile, true, :discard) do
      {:ok, output, []} -> {:ok, output}
      error -> error
    end
  end

  def encode_substitute(codepoints, profile, replacer)
      when is_list(codepoints) and is_function(replacer, 1) do
    case encode_all(codepoints, profile, true, {:replace, replacer}) do
      {:ok, output, []} -> {:ok, output}
      error -> error
    end
  end

  def encode_chunk(codepoints, profile, final?, policy)
      when is_list(codepoints) and is_boolean(final?),
      do: encode_all(codepoints, profile, final?, policy)

  def encode_from_utf8(<<first, _rest::binary>> = input, profile) when first >= 0x80,
    do: encode_from_unicode_list(input, profile)

  def encode_from_utf8(<<?S, _rest::binary>> = input, profile),
    do: encode_from_unicode_list(input, profile)

  def encode_from_utf8(<<?f, _rest::binary>> = input, :cmap_1_0j = profile),
    do: encode_from_unicode_list(input, profile)

  def encode_from_utf8(input, profile) when is_binary(input) do
    case :binary.match(input, utf8_fallback_patterns(profile)) do
      :nomatch -> encode_utf8_all(input, profile, single_encoder(profile), 0, [], [], 0, [])
      {_offset, _length} -> encode_from_unicode_list(input, profile)
    end
  end

  defp table(profile), do: Map.fetch!(@tables, profile)
  defp utf8_table(profile), do: Map.fetch!(@utf8_tables, profile)
  defp single_encoder(profile), do: Map.fetch!(@single_encoders, profile)
  defp utf8_fallback_patterns(:ec_glyph), do: @ec_utf8_fallback_patterns
  defp utf8_fallback_patterns(:cmap_1_0j), do: @cmap_utf8_fallback_patterns

  defp decode_all(<<>>, _table, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_all(<<byte, rest::binary>>, table, offset, acc) do
    case elem(table, byte) do
      :undefined ->
        {:error, :invalid_sequence, offset, <<byte>>}

      codepoint when is_integer(codepoint) ->
        decode_all(rest, table, offset + 1, [codepoint | acc])

      {first, second} ->
        decode_all(rest, table, offset + 1, [second, first | acc])

      {first, second, third} ->
        decode_all(rest, table, offset + 1, [third, second, first | acc])
    end
  end

  defp decode_discard_all(<<>>, _table, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_all(<<byte, rest::binary>>, table, acc) do
    case elem(table, byte) do
      :undefined -> decode_discard_all(rest, table, acc)
      codepoint when is_integer(codepoint) -> decode_discard_all(rest, table, [codepoint | acc])
      {first, second} -> decode_discard_all(rest, table, [second, first | acc])
      {first, second, third} -> decode_discard_all(rest, table, [third, second, first | acc])
    end
  end

  defp decode_utf8_all(<<>>, _table, _offset, acc, _count, chunks),
    do: {:ok, finish_iodata(acc, chunks)}

  defp decode_utf8_all(<<byte, rest::binary>>, table, offset, acc, count, chunks) do
    case elem(table, byte) do
      :undefined ->
        {:error, :invalid_sequence, offset, <<byte>>}

      piece ->
        {next_acc, next_count, next_chunks} = push_piece(piece, acc, count, chunks)
        decode_utf8_all(rest, table, offset + 1, next_acc, next_count, next_chunks)
    end
  end

  defp encode_all(codepoints, profile, final?, policy) do
    encode_loop(codepoints, profile, final?, policy, single_encoder(profile), [], 0, [])
  end

  defp encode_loop(codepoints, profile, final?, policy, singles, acc, count, chunks) do
    case next_token(codepoints, profile, final?) do
      :done ->
        {:ok, finish_iodata(acc, chunks), []}

      {:pending, pending} ->
        {:ok, finish_iodata(acc, chunks), pending}

      {:mapped, byte, rest} ->
        {next_acc, next_count, next_chunks} = push_piece(byte, acc, count, chunks)
        encode_loop(rest, profile, final?, policy, singles, next_acc, next_count, next_chunks)

      {:single, codepoint, rest} ->
        case singles do
          %{^codepoint => byte} ->
            {next_acc, next_count, next_chunks} = push_piece(byte, acc, count, chunks)
            encode_loop(rest, profile, final?, policy, singles, next_acc, next_count, next_chunks)

          _ ->
            encode_unrepresentable(
              codepoint,
              rest,
              profile,
              final?,
              policy,
              singles,
              acc,
              count,
              chunks
            )
        end
    end
  end

  defp next_token([], _profile, _final?), do: :done

  defp next_token([?f, ?f, ?i | rest], :cmap_1_0j, _final?),
    do: {:mapped, 0x1E, rest}

  defp next_token([?f, ?f, ?l | rest], :cmap_1_0j, _final?),
    do: {:mapped, 0x1F, rest}

  defp next_token([?f, ?f], :cmap_1_0j, false), do: {:pending, [?f, ?f]}
  defp next_token([?f, ?f | rest], :cmap_1_0j, _final?), do: {:mapped, 0x1B, rest}
  defp next_token([?f, ?i | rest], :cmap_1_0j, _final?), do: {:mapped, 0x1C, rest}
  defp next_token([?f, ?l | rest], :cmap_1_0j, _final?), do: {:mapped, 0x1D, rest}
  defp next_token([?f], :cmap_1_0j, false), do: {:pending, [?f]}
  defp next_token([?S, ?S | rest], _profile, _final?), do: {:mapped, 0xDF, rest}
  defp next_token([?S], _profile, false), do: {:pending, [?S]}
  defp next_token([codepoint | rest], _profile, _final?), do: {:single, codepoint, rest}

  defp encode_unrepresentable(
         codepoint,
         _rest,
         _profile,
         _final?,
         :error,
         _singles,
         _acc,
         _count,
         _chunks
       ),
       do: {:error, :unrepresentable_character, codepoint}

  defp encode_unrepresentable(
         _codepoint,
         rest,
         profile,
         final?,
         :discard,
         singles,
         acc,
         count,
         chunks
       ),
       do: encode_loop(rest, profile, final?, :discard, singles, acc, count, chunks)

  defp encode_unrepresentable(
         codepoint,
         rest,
         profile,
         final?,
         {:replace, replacer} = policy,
         singles,
         acc,
         count,
         chunks
       )
       when is_function(replacer, 1) do
    case encode(replacer.(codepoint), profile) do
      {:ok, replacement} ->
        {next_acc, next_count, next_chunks} = push_piece(replacement, acc, count, chunks)

        encode_loop(
          rest,
          profile,
          final?,
          policy,
          singles,
          next_acc,
          next_count,
          next_chunks
        )

      error ->
        error
    end
  end

  defp encode_utf8_all(<<>>, profile, singles, _offset, pending, acc, count, chunks) do
    case flush_pending(pending, profile, singles) do
      {:ok, pieces} ->
        {next_acc, _next_count, next_chunks} = push_pieces(pieces, acc, count, chunks)
        {:ok, finish_iodata(next_acc, next_chunks)}

      error ->
        error
    end
  end

  defp encode_utf8_all(
         <<b01, b02, b03, b04, b05, b06, b07, b08, b09, b10, b11, b12, b13, b14, b15, b16,
           rest::binary>>,
         :ec_glyph = profile,
         singles,
         offset,
         [],
         acc,
         count,
         chunks
       )
       when ec_identity_byte(b01) and ec_identity_byte(b02) and ec_identity_byte(b03) and
              ec_identity_byte(b04) and ec_identity_byte(b05) and ec_identity_byte(b06) and
              ec_identity_byte(b07) and ec_identity_byte(b08) and ec_identity_byte(b09) and
              ec_identity_byte(b10) and ec_identity_byte(b11) and ec_identity_byte(b12) and
              ec_identity_byte(b13) and ec_identity_byte(b14) and ec_identity_byte(b15) and
              ec_identity_byte(b16) do
    piece =
      <<b01, b02, b03, b04, b05, b06, b07, b08, b09, b10, b11, b12, b13, b14, b15, b16>>

    {next_acc, next_count, next_chunks} = push_piece(piece, acc, count, chunks)

    encode_utf8_all(
      rest,
      profile,
      singles,
      offset + 16,
      [],
      next_acc,
      next_count,
      next_chunks
    )
  end

  defp encode_utf8_all(
         <<b01, b02, b03, b04, b05, b06, b07, b08, b09, b10, b11, b12, b13, b14, b15, b16,
           rest::binary>>,
         :cmap_1_0j = profile,
         singles,
         offset,
         [],
         acc,
         count,
         chunks
       )
       when cmap_identity_byte(b01) and cmap_identity_byte(b02) and cmap_identity_byte(b03) and
              cmap_identity_byte(b04) and cmap_identity_byte(b05) and cmap_identity_byte(b06) and
              cmap_identity_byte(b07) and cmap_identity_byte(b08) and cmap_identity_byte(b09) and
              cmap_identity_byte(b10) and cmap_identity_byte(b11) and cmap_identity_byte(b12) and
              cmap_identity_byte(b13) and cmap_identity_byte(b14) and cmap_identity_byte(b15) and
              cmap_identity_byte(b16) do
    piece =
      <<b01, b02, b03, b04, b05, b06, b07, b08, b09, b10, b11, b12, b13, b14, b15, b16>>

    {next_acc, next_count, next_chunks} = push_piece(piece, acc, count, chunks)

    encode_utf8_all(
      rest,
      profile,
      singles,
      offset + 16,
      [],
      next_acc,
      next_count,
      next_chunks
    )
  end

  defp encode_utf8_all(input, profile, singles, offset, pending, acc, count, chunks) do
    case next_utf8(input) do
      {:ok, codepoint, rest, size} ->
        case feed_codepoint(pending, codepoint, profile, singles) do
          {:ok, pieces, next_pending} ->
            {next_acc, next_count, next_chunks} = push_pieces(pieces, acc, count, chunks)

            encode_utf8_all(
              rest,
              profile,
              singles,
              offset + size,
              next_pending,
              next_acc,
              next_count,
              next_chunks
            )

          error ->
            error
        end

      :error ->
        Iconvex.Specs.CodecSupport.malformed_utf8(input, offset)
    end
  end

  defp encode_from_unicode_list(input, profile) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        encode(codepoints, profile)

      {:incomplete, converted, rest} ->
        first_source_error(converted, profile, :incomplete_sequence, input, rest)

      {:error, converted, rest} ->
        first_source_error(converted, profile, :invalid_sequence, input, rest)
    end
  end

  defp first_source_error(converted, profile, kind, input, rest) do
    case encode(converted, profile) do
      {:ok, _prefix} ->
        {:decode_error, kind, byte_size(input) - byte_size(rest), rest}

      error ->
        error
    end
  end

  defp feed_codepoint([], ?S, _profile, _singles), do: {:ok, [], [?S]}
  defp feed_codepoint([], ?f, :cmap_1_0j, _singles), do: {:ok, [], [?f]}
  defp feed_codepoint([?S], ?S, _profile, _singles), do: {:ok, [0xDF], []}
  defp feed_codepoint([?f], ?f, :cmap_1_0j, _singles), do: {:ok, [], [?f, ?f]}
  defp feed_codepoint([?f], ?i, :cmap_1_0j, _singles), do: {:ok, [0x1C], []}
  defp feed_codepoint([?f], ?l, :cmap_1_0j, _singles), do: {:ok, [0x1D], []}
  defp feed_codepoint([?f, ?f], ?i, :cmap_1_0j, _singles), do: {:ok, [0x1E], []}
  defp feed_codepoint([?f, ?f], ?l, :cmap_1_0j, _singles), do: {:ok, [0x1F], []}

  defp feed_codepoint([?S], codepoint, profile, singles),
    do: prepend_stable(?S, codepoint, profile, singles)

  defp feed_codepoint([?f], codepoint, :cmap_1_0j, singles),
    do: prepend_stable(?f, codepoint, :cmap_1_0j, singles)

  defp feed_codepoint([?f, ?f], codepoint, :cmap_1_0j, singles) do
    case feed_codepoint([], codepoint, :cmap_1_0j, singles) do
      {:ok, pieces, pending} -> {:ok, [0x1B | pieces], pending}
      error -> error
    end
  end

  defp feed_codepoint([], codepoint, _profile, singles) do
    case singles do
      %{^codepoint => byte} -> {:ok, [byte], []}
      _ -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp prepend_stable(stable, codepoint, profile, singles) do
    byte = Map.fetch!(singles, stable)

    case feed_codepoint([], codepoint, profile, singles) do
      {:ok, pieces, pending} -> {:ok, [byte | pieces], pending}
      error -> error
    end
  end

  defp flush_pending([], _profile, _singles), do: {:ok, []}
  defp flush_pending([?f, ?f], :cmap_1_0j, _singles), do: {:ok, [0x1B]}

  defp flush_pending([codepoint], _profile, singles) do
    case singles do
      %{^codepoint => byte} -> {:ok, [byte]}
      _ -> {:error, :unrepresentable_character, codepoint}
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

  defp push_pieces([], acc, count, chunks), do: {acc, count, chunks}

  defp push_pieces([piece | rest], acc, count, chunks) do
    {next_acc, next_count, next_chunks} = push_piece(piece, acc, count, chunks)
    push_pieces(rest, next_acc, next_count, next_chunks)
  end

  defp push_piece(piece, acc, count, chunks) when count == @chunk_units - 1 do
    chunk = [piece | acc] |> :lists.reverse() |> IO.iodata_to_binary()
    {[], 0, [chunk | chunks]}
  end

  defp push_piece(piece, acc, count, chunks), do: {[piece | acc], count + 1, chunks}

  defp finish_iodata([], chunks),
    do: chunks |> :lists.reverse() |> IO.iodata_to_binary()

  defp finish_iodata(acc, chunks) do
    chunk = acc |> :lists.reverse() |> IO.iodata_to_binary()
    [chunk | chunks] |> :lists.reverse() |> IO.iodata_to_binary()
  end
end

defmodule Iconvex.Specs.CorkT1.Profile do
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
      alias Iconvex.Specs.CorkT1, as: Engine

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
      def ferguson_sha256, do: Engine.ferguson_sha256()
      def ec_encoding_sha256, do: Engine.ec_encoding_sha256()
      def latex_source_sha256, do: Engine.latex_source_sha256()
      def cmap_archive_sha256, do: Engine.cmap_archive_sha256()
      def t1_cmap_sha256, do: Engine.t1_cmap_sha256()
      def ferguson_url, do: Engine.ferguson_url()
      def ec_encoding_url, do: Engine.ec_encoding_url()
      def latex_source_url, do: Engine.latex_source_url()
      def cmap_archive_url, do: Engine.cmap_archive_url()

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

defmodule Iconvex.Specs.CorkT1ECGlyph do
  @moduledoc """
  Cork / TeX T1 profile preserving classic EC font-glyph identities.

  This is not a generic text encoding. Slot `0x18` has no Unicode mapping,
  slot `0x7F` duplicates the hyphen glyph at `0x2D`, slot `0xD0` selects the
  `/Eth` interpretation of LaTeX's overloaded `\\DH`/`\\DJ` slot, and classic
  slot `0xDF` decodes to the exact sequence `SS` rather than modern U+1E9E.
  """

  use Iconvex.Specs.CorkT1.Profile,
    profile: :ec_glyph,
    canonical: "TEX-T1-EC-GLYPH",
    aliases: [
      "T1",
      "TEX-T1",
      "CORK",
      "CORK-ENCODING",
      "CORKENCODING",
      "EC",
      "EC-ENCODING",
      "ECENCODING",
      "TEX-LATIN-1",
      "TEXLATIN1",
      "TEX256",
      "TEX256.ENC",
      "8T"
    ],
    codec_id: :tex_t1_ec_glyph
end

defmodule Iconvex.Specs.CorkT1CMap10J do
  @moduledoc """
  Unicode-extraction profile from CTAN `cmap` 1.0j's `TeX-T1-0` CMap.

  The upstream CMap specifies decoding only. Iconvex defines its inverse as a
  deterministic longest-match encoder: `ffi` and `ffl` win over `ff`, followed
  by `fi` and `fl`; `SS` maps to classic slot `0xDF`. Slot `0x18` is undefined.
  """

  use Iconvex.Specs.CorkT1.Profile,
    profile: :cmap_1_0j,
    canonical: "TEX-T1-CMAP-1.0J",
    aliases: ["T1-CMAP", "TEX-T1-CMAP", "TEX-T1-0"],
    codec_id: :tex_t1_cmap_1_0j
end

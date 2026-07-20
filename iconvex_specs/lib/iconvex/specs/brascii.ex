defmodule Iconvex.Specs.BraSCII.SourceAsset do
  @moduledoc false

  @header "byte_hex,unicode_hex,classification,status,notes"
  @hex_byte ~r/\A[0-9A-F]{2}\z/
  @hex_codepoint ~r/\A[0-9A-F]{4,6}\z/

  def validate!(mapping_bytes, metadata_bytes, options)
      when is_binary(mapping_bytes) and is_binary(metadata_bytes) and is_list(options) do
    verify_sha!(:mapping, mapping_bytes, Keyword.fetch!(options, :mapping_sha256))
    verify_sha!(:metadata, metadata_bytes, Keyword.fetch!(options, :metadata_sha256))
    validate_metadata!(metadata_bytes)

    rows = parse_rows!(mapping_bytes)
    validate_invariants!(rows)
    rows
  end

  defp verify_sha!(label, bytes, expected) do
    actual = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

    unless actual == expected do
      raise ArgumentError,
            "BraSCII #{label} SHA-256 mismatch: expected #{expected}, got #{actual}"
    end
  end

  defp validate_metadata!(metadata) do
    required = [
      "ABNT NBR 9611:1991",
      "Epson Stylus COLOR 200",
      "Star Micronics LC-8021",
      "ECMA-94",
      "C0 and C1",
      "LGPL-2.1-or-later",
      "GNU libiconv 1.19 does not expose BraSCII",
      "upstream PDFs are not redistributed"
    ]

    unless Enum.all?(required, &String.contains?(metadata, &1)) do
      raise ArgumentError, "BraSCII metadata omits a required provenance or policy statement"
    end
  end

  defp parse_rows!(mapping_bytes) do
    lines = String.split(mapping_bytes, "\n", trim: false)

    unless List.last(lines) == "" and Enum.at(lines, -2) != "" do
      raise ArgumentError, "BraSCII mapping must end with exactly one LF"
    end

    case Enum.drop(lines, -1) do
      [@header | source_rows] when length(source_rows) == 256 ->
        source_rows
        |> Enum.with_index()
        |> Enum.map(fn {row, byte} -> parse_row!(row, byte) end)

      [@header | source_rows] ->
        raise ArgumentError,
              "BraSCII mapping must contain 256 data rows, got #{length(source_rows)}"

      [header | _rows] ->
        raise ArgumentError, "unexpected BraSCII mapping header: #{inspect(header)}"

      [] ->
        raise ArgumentError, "unexpected BraSCII mapping header: missing"
    end
  end

  defp parse_row!(row, expected_byte) do
    case String.split(row, ",", parts: 5) do
      [byte_hex, codepoint_hex, classification, status, notes] ->
        unless Regex.match?(@hex_byte, byte_hex) do
          raise ArgumentError, "BraSCII row has invalid byte token #{inspect(byte_hex)}"
        end

        expected_hex = expected_byte |> Integer.to_string(16) |> String.upcase() |> pad(2)

        unless byte_hex == expected_hex do
          raise ArgumentError,
                "BraSCII mapping must contain ordered row #{expected_hex}; " <>
                  "got #{inspect(byte_hex)}"
        end

        unless Regex.match?(@hex_codepoint, codepoint_hex) do
          raise ArgumentError,
                "BraSCII row #{byte_hex} has invalid Unicode token #{inspect(codepoint_hex)}"
        end

        codepoint = String.to_integer(codepoint_hex, 16)

        unless unicode_scalar?(codepoint) do
          raise ArgumentError, "BraSCII row #{byte_hex} contains a non-scalar Unicode value"
        end

        %{
          byte: expected_byte,
          codepoint: codepoint,
          classification: classification,
          status: status,
          notes: notes
        }

      _ ->
        raise ArgumentError,
              "BraSCII row #{Base.encode16(<<expected_byte>>)} must contain exactly five fields"
    end
  end

  defp validate_invariants!(rows) do
    Enum.each(rows, fn row ->
      expected_codepoint =
        case row.byte do
          0xD7 -> 0x0152
          0xF7 -> 0x0153
          byte -> byte
        end

      {expected_classification, expected_status} = classification(row.byte)

      expected_notes =
        if row.byte in [0xD7, 0xF7], do: "brascii_oe_override", else: "identity"

      unless row.codepoint == expected_codepoint and
               row.classification == expected_classification and
               row.status == expected_status and row.notes == expected_notes do
        byte = row.byte |> Integer.to_string(16) |> String.upcase() |> pad(2)
        raise ArgumentError, "BraSCII row #{byte} violates the audited mapping contract"
      end
    end)

    codepoints = Enum.map(rows, & &1.codepoint)

    unless length(Enum.uniq(codepoints)) == 256 and
             0x00D7 not in codepoints and 0x00F7 not in codepoints and
             0x0152 in codepoints and 0x0153 in codepoints do
      raise ArgumentError, "BraSCII mapping must have the unique D7/F7 OE substitutions"
    end
  end

  defp classification(byte) when byte in 0x00..0x1F, do: {"c0_control", "control"}
  defp classification(0x20), do: {"ascii_graphic", "space"}
  defp classification(byte) when byte in 0x21..0x7E, do: {"ascii_graphic", "graphic"}
  defp classification(0x7F), do: {"delete_control", "control"}
  defp classification(byte) when byte in 0x80..0x9F, do: {"c1_control", "control"}
  defp classification(0xA0), do: {"g1_graphic", "space"}
  defp classification(byte) when byte in 0xA1..0xFF, do: {"g1_graphic", "graphic"}

  defp unicode_scalar?(codepoint),
    do: codepoint in 0..0x10FFFF and codepoint not in 0xD800..0xDFFF

  defp pad(value, width), do: String.duplicate("0", width - byte_size(value)) <> value
end

defmodule Iconvex.Specs.BraSCII do
  @moduledoc """
  BraSCII / Brazil-ABNT, the Brazilian Code for Information Interchange.

  The exact graphical repertoire is pinned to independent Epson and Star
  manufacturer tables for ABNT NBR 9611:1991 / code page 3847. It is the
  ISO-8859-1 layout with byte `D7` assigned to U+0152 and byte `F7` assigned
  to U+0153, so multiplication and division signs are not representable.

  The graphical standard does not turn printer commands into text. This codec
  uses a documented Unicode-identity transport for the C0 and C1 byte ranges.
  """

  use Iconvex.Codec

  @source_dir Path.expand("../../../priv/sources/brascii", __DIR__)
  @mapping_path Path.join(@source_dir, "brascii_nbr_9611.csv")
  @metadata_path Path.join(@source_dir, "SOURCE_METADATA.md")
  @external_resource @mapping_path
  @external_resource @metadata_path

  @mapping_sha256 "d3854633818c51e23aa189a5628a8356c5cfb36a3885da7ae9239a6a833944ac"
  @metadata_sha256 "f0c87c17e1ccfa6a601bbc0e8b55d5ca97b82d43eebed8091277748a37e3063c"
  @epson_sha256 "9c957a73217d9e39cfa9ba5c3f4b40cdcfe205e8b988ee2bf69268d12d8c697d"
  @star_sha256 "c723b37df1b936606d960754713c23ed9ac11be1f0cb3365300fad1c9521724b"
  @star_mirror_sha256 "b47aa8daac993cdfa128f5036aa3cef8b5a05315b15c865cea509e3c88b80157"
  @star_page_raster_sha256 "8f9a7a87454e8a58df381137714774844bd14a35ae5127a875a4eba0c9ebaca5"
  @ecma_sha256 "dd7541b58618e2995f77e28b07434626e03b299df60039d2861e10d414600ba1"
  @chunk_units 4_096
  @forbidden_latin1_utf8 [<<0x00D7::utf8>>, <<0x00F7::utf8>>]

  @rows Iconvex.Specs.BraSCII.SourceAsset.validate!(
          File.read!(@mapping_path),
          File.read!(@metadata_path),
          mapping_sha256: @mapping_sha256,
          metadata_sha256: @metadata_sha256
        )

  @table @rows |> Enum.map(& &1.codepoint) |> List.to_tuple()

  @impl true
  def canonical_name, do: "BRASCII"

  @impl true
  def aliases do
    [
      "BRA-SCII",
      "ABNT",
      "ABNT-BRASCII",
      "NBR-9611",
      "NBR-9611:1991",
      "NBR-9614",
      "NBR-9614:1986",
      "CP3847",
      "CODE-PAGE-3847",
      "BRAZIL-ABNT",
      "BRAZIL-ABNT-3847"
    ]
  end

  @impl true
  def codec_id, do: :brascii_nbr_9611_1991

  def unit_bits, do: 8
  def mapping_sha256, do: @mapping_sha256
  def metadata_sha256, do: @metadata_sha256
  def epson_source_sha256, do: @epson_sha256
  def star_source_sha256, do: @star_sha256
  def star_mirror_sha256, do: @star_mirror_sha256
  def star_page_raster_sha256, do: @star_page_raster_sha256
  def ecma_source_sha256, do: @ecma_sha256
  def epson_source_page, do: %{pdf: 119, printed: "B-5"}
  def star_source_page, do: %{pdf: 64, printed: 58}

  def epson_source_url,
    do: "https://files.support.epson.com/pdf/sc200_/sc200_u1.pdf"

  def star_source_url,
    do: "https://archive.org/download/manuallib-id-2525457/2525457.pdf"

  def star_mirror_url,
    do:
      "https://minuszerodegrees.net/manuals/Star%20Micronics/dot_matrix/" <>
        "Star%20Micronics%20-%20LC-8021%20-%20Users%20Manual.pdf"

  def ecma_source_url,
    do:
      "https://ecma-international.org/wp-content/uploads/" <>
        "ECMA-94_1st_edition_march_1985.pdf"

  def transport_policy do
    %{
      ascii: :identity,
      c0_controls: :unicode_identity,
      c1_controls: :unicode_identity,
      g1_graphics: :nbr_9611_1991
    }
  end

  @impl true
  def decode(input) when is_binary(input), do: decode_all(input, [])

  @impl true
  def decode_discard(input) when is_binary(input), do: decode_all(input, [])

  @impl true
  def decode_chunk(input, _final?) when is_binary(input) do
    {:ok, codepoints} = decode_all(input, [])
    {:ok, codepoints, <<>>}
  end

  @impl true
  def decode_to_utf8(input) when is_binary(input) do
    utf8 = :unicode.characters_to_binary(input, :latin1, :utf8)

    output =
      utf8
      |> :binary.replace(<<0x00D7::utf8>>, <<0x0152::utf8>>, [:global])
      |> :binary.replace(<<0x00F7::utf8>>, <<0x0153::utf8>>, [:global])

    {:ok, output}
  end

  @impl true
  def encode(codepoints) when is_list(codepoints), do: encode_all(codepoints, [])

  @impl true
  def encode_discard(codepoints) when is_list(codepoints),
    do: encode_discard_all(codepoints, [])

  @impl true
  def encode_substitute(codepoints, replacer)
      when is_list(codepoints) and is_function(replacer, 1),
      do: encode_substitute_all(codepoints, replacer, [])

  @impl true
  def encode_chunk(codepoints, _final?, :error) when is_list(codepoints) do
    case encode_all(codepoints, []) do
      {:ok, output} -> {:ok, output, []}
      error -> error
    end
  end

  def encode_chunk(codepoints, _final?, :discard) when is_list(codepoints) do
    {:ok, output} = encode_discard_all(codepoints, [])
    {:ok, output, []}
  end

  def encode_chunk(codepoints, _final?, {:replace, replacer})
      when is_list(codepoints) and is_function(replacer, 1) do
    case encode_substitute_all(codepoints, replacer, []) do
      {:ok, output} -> {:ok, output, []}
      error -> error
    end
  end

  @impl true
  def encode_from_utf8(input) when is_binary(input) do
    case :binary.match(input, @forbidden_latin1_utf8) do
      :nomatch -> encode_utf8_native(input)
      {_offset, _length} -> encode_utf8_all(input, 0, [], 0, [])
    end
  end

  defp decode_all(<<>>, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_all(<<byte, rest::binary>>, acc),
    do: decode_all(rest, [elem(@table, byte) | acc])

  defp encode_all([], acc), do: {:ok, reverse_binary(acc)}

  defp encode_all([codepoint | rest], acc) do
    case encoded_byte(codepoint) do
      {:ok, byte} -> encode_all(rest, [byte | acc])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_discard_all([], acc), do: {:ok, reverse_binary(acc)}

  defp encode_discard_all([codepoint | rest], acc) do
    case encoded_byte(codepoint) do
      {:ok, byte} -> encode_discard_all(rest, [byte | acc])
      :error -> encode_discard_all(rest, acc)
    end
  end

  defp encode_substitute_all([], _replacer, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute_all([codepoint | rest], replacer, acc) do
    case encoded_byte(codepoint) do
      {:ok, byte} ->
        encode_substitute_all(rest, replacer, [byte | acc])

      :error ->
        case encode_all(replacer.(codepoint), []) do
          {:ok, replacement} ->
            encode_substitute_all(rest, replacer, [replacement | acc])

          error ->
            error
        end
    end
  end

  defp encode_utf8_native(input) do
    prepared =
      input
      |> :binary.replace(<<0x0152::utf8>>, <<0x00D7::utf8>>, [:global])
      |> :binary.replace(<<0x0153::utf8>>, <<0x00F7::utf8>>, [:global])

    case :unicode.characters_to_binary(prepared, :utf8, :latin1) do
      output when is_binary(output) ->
        {:ok, output}

      {:incomplete, _converted, rest} ->
        {:decode_error, :incomplete_sequence, byte_size(prepared) - byte_size(rest), rest}

      {:error, _converted, rest} ->
        offset = byte_size(prepared) - byte_size(rest)

        case rest do
          <<codepoint::utf8, _tail::binary>> ->
            {:error, :unrepresentable_character, codepoint}

          _ ->
            Iconvex.Specs.CodecSupport.malformed_utf8(rest, offset)
        end
    end
  end

  defp encode_utf8_all(<<>>, _offset, acc, _count, chunks),
    do: {:ok, finish_iodata(acc, chunks)}

  defp encode_utf8_all(<<codepoint, rest::binary>>, offset, acc, count, chunks)
       when codepoint < 0x80 do
    push_utf8_byte(rest, offset + 1, codepoint, acc, count, chunks)
  end

  defp encode_utf8_all(input, offset, acc, count, chunks) do
    case input do
      <<codepoint::utf8, rest::binary>> ->
        width = byte_size(input) - byte_size(rest)

        case encoded_byte(codepoint) do
          {:ok, byte} -> push_utf8_byte(rest, offset + width, byte, acc, count, chunks)
          :error -> {:error, :unrepresentable_character, codepoint}
        end

      _ ->
        Iconvex.Specs.CodecSupport.malformed_utf8(input, offset)
    end
  end

  defp push_utf8_byte(rest, offset, byte, acc, count, chunks)
       when count == @chunk_units - 1 do
    chunk = [byte | acc] |> :lists.reverse() |> :erlang.list_to_binary()
    encode_utf8_all(rest, offset, [], 0, [chunk | chunks])
  end

  defp push_utf8_byte(rest, offset, byte, acc, count, chunks),
    do: encode_utf8_all(rest, offset, [byte | acc], count + 1, chunks)

  defp encoded_byte(0x0152), do: {:ok, 0xD7}
  defp encoded_byte(0x0153), do: {:ok, 0xF7}

  defp encoded_byte(codepoint)
       when codepoint in 0..0xFF and codepoint not in [0x00D7, 0x00F7],
       do: {:ok, codepoint}

  defp encoded_byte(_codepoint), do: :error

  defp reverse_binary(acc), do: acc |> :lists.reverse() |> :erlang.list_to_binary()

  defp finish_iodata([], chunks),
    do: chunks |> :lists.reverse() |> IO.iodata_to_binary()

  defp finish_iodata(acc, chunks) do
    chunk = acc |> :lists.reverse() |> :erlang.list_to_binary()
    [chunk | chunks] |> :lists.reverse() |> IO.iodata_to_binary()
  end
end

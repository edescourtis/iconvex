defmodule Iconvex.Specs.Kamenicky.SourceAsset do
  @moduledoc false

  @header "start_byte,original_unicode_scalars,mysql_unicode_scalars"
  @sequence_pattern ~r/\A[0-9A-F]{4,6}(?:\+[0-9A-F]{4,6}){15}\z/

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
            "Kamenicky/KEYBCS2 #{label} SHA-256 mismatch: expected #{expected}, got #{actual}"
    end
  end

  defp validate_metadata!(metadata) do
    required = [
      "Public Domain",
      "LGPL-2.1-or-later",
      "byte `AD`",
      "GNU libiconv 1.19",
      "Japanese IBM code page 895",
      "PC-BASIC"
    ]

    unless Enum.all?(required, &String.contains?(metadata, &1)) do
      raise ArgumentError,
            "Kamenicky/KEYBCS2 metadata omits a required provenance or policy statement"
    end
  end

  defp parse_rows!(mapping_bytes) do
    lines = String.split(mapping_bytes, "\n", trim: false)

    unless List.last(lines) == "" and Enum.at(lines, -2) != "" do
      raise ArgumentError, "Kamenicky/KEYBCS2 mapping must end with exactly one LF"
    end

    case Enum.drop(lines, -1) do
      [@header | source_rows] when length(source_rows) == 8 ->
        source_rows
        |> Enum.with_index()
        |> Enum.map(fn {row, index} -> parse_row!(row, 0x80 + index * 0x10) end)

      [@header | source_rows] ->
        raise ArgumentError,
              "Kamenicky/KEYBCS2 mapping must contain eight data blocks, got #{length(source_rows)}"

      [header | _rows] ->
        raise ArgumentError, "unexpected Kamenicky/KEYBCS2 mapping header: #{inspect(header)}"

      [] ->
        raise ArgumentError, "unexpected Kamenicky/KEYBCS2 mapping header: missing"
    end
  end

  defp parse_row!(row, expected_start) do
    case String.split(row, ",") do
      [start, original, mysql] ->
        expected_hex = expected_start |> Integer.to_string(16) |> String.upcase()

        unless start == expected_hex do
          raise ArgumentError,
                "Kamenicky/KEYBCS2 mapping must contain ordered block #{expected_hex}; " <>
                  "got #{inspect(start)}"
        end

        %{
          start: expected_start,
          original: parse_sequence!(original, expected_hex, :original),
          mysql: parse_sequence!(mysql, expected_hex, :mysql)
        }

      _ ->
        raise ArgumentError,
              "Kamenicky/KEYBCS2 block #{Integer.to_string(expected_start, 16)} " <>
                "must contain exactly three fields"
    end
  end

  defp parse_sequence!(sequence, block, profile) do
    unless Regex.match?(@sequence_pattern, sequence) do
      raise ArgumentError,
            "Kamenicky/KEYBCS2 block #{block} has an invalid #{profile} sequence"
    end

    values = sequence |> String.split("+") |> Enum.map(&String.to_integer(&1, 16))

    unless Enum.all?(values, &unicode_scalar?/1) do
      raise ArgumentError,
            "Kamenicky/KEYBCS2 block #{block} contains a non-scalar Unicode value"
    end

    values
  end

  defp validate_invariants!(rows) do
    identity = Enum.to_list(0x00..0x7F)
    original = identity ++ Enum.flat_map(rows, & &1.original)
    mysql = identity ++ Enum.flat_map(rows, & &1.mysql)

    unless length(original) == 256 and length(mysql) == 256 and
             length(Enum.uniq(original)) == 256 and length(Enum.uniq(mysql)) == 256 do
      raise ArgumentError,
            "Kamenicky/KEYBCS2 profiles must each define 256 unique scalar outputs"
    end

    differences =
      original
      |> Enum.zip(mysql)
      |> Enum.with_index()
      |> Enum.filter(fn {{left, right}, _byte} -> left != right end)

    unless differences == [{{0x00A7, 0x00A1}, 0xAD}] do
      raise ArgumentError,
            "Kamenicky/KEYBCS2 AD variant fork must be original U+00A7 versus MySQL U+00A1"
    end

    controls = Enum.to_list(0x00..0x1F) ++ [0x7F]

    unless Enum.all?(controls, fn byte -> Enum.at(original, byte) == byte end) do
      raise ArgumentError, "Kamenicky/KEYBCS2 text controls are not canonical"
    end
  end

  defp unicode_scalar?(codepoint),
    do: codepoint in 0x0000..0x10FFFF and codepoint not in 0xD800..0xDFFF
end

defmodule Iconvex.Specs.Kamenicky do
  @moduledoc false

  @source_dir Path.expand("../../../priv/sources/kamenicky-keybcs2", __DIR__)
  @mapping_path Path.join(@source_dir, "kamenicky_high_half.csv")
  @metadata_path Path.join(@source_dir, "SOURCE_METADATA.md")
  @external_resource @mapping_path
  @external_resource @metadata_path

  @mapping_sha256 "a506b2313878affe9450787797f3f38a95734b7dec7c75a47681dca5c3e19a50"
  @metadata_sha256 "0cd52d7d7b185c27727d244f13d9e7ac790824ef209f00e25f295020b8f110a5"
  @historical_source_sha256 "ac570cbd8f97bd22b65a19fe456f263508946417e46a83de232c583b62511a49"
  @fpc_source_sha256 "adfa9b04937649657bc462c5a63a95eba53c0a895396194d3d03236fcdb8573a"
  @mysql_source_sha256 "86852fa5aede60cdaaf7ce46281a60f707c8bc69067f26202127905e6b2aabe9"
  @gnu_libiconv_tar_sha256 "88dd96a8c0464eca144fc791ae60cd31cd8ee78321e67397e25fc095c4a19aa6"
  @chunk_units 4_096
  @utf8_chunk_bytes 65_536

  @rows Iconvex.Specs.Kamenicky.SourceAsset.validate!(
          File.read!(@mapping_path),
          File.read!(@metadata_path),
          mapping_sha256: @mapping_sha256,
          metadata_sha256: @metadata_sha256
        )

  @identity Enum.to_list(0x00..0x7F)
  @tables %{
    original: List.to_tuple(@identity ++ Enum.flat_map(@rows, & &1.original)),
    mysql: List.to_tuple(@identity ++ Enum.flat_map(@rows, & &1.mysql))
  }

  @utf8_tables Map.new(@tables, fn {profile, table} ->
                 utf8 =
                   table
                   |> Tuple.to_list()
                   |> Enum.map(fn
                     codepoint when codepoint < 0x80 -> codepoint
                     codepoint -> <<codepoint::utf8>>
                   end)
                   |> List.to_tuple()

                 {profile, utf8}
               end)

  @encoders Map.new(@tables, fn {profile, table} ->
              encoder =
                table
                |> Tuple.to_list()
                |> Enum.with_index()
                |> Map.new(fn {codepoint, byte} -> {codepoint, byte} end)

              {profile, encoder}
            end)

  def mapping_sha256, do: @mapping_sha256
  def metadata_sha256, do: @metadata_sha256
  def historical_source_sha256, do: @historical_source_sha256
  def fpc_source_sha256, do: @fpc_source_sha256
  def mysql_source_sha256, do: @mysql_source_sha256
  def gnu_libiconv_tar_sha256, do: @gnu_libiconv_tar_sha256

  def source_url,
    do: "https://ftp.fi.muni.cz/pub/localization/charsets/cs-encodings-faq"

  def fpc_source_url,
    do:
      "https://gitlab.com/freepascal.org/fpc/source/-/raw/" <>
        "fd6d7d680d3ec43c61c19c2c1a841b3fa90bca03/rtl/ucmaps/cp895.txt"

  def mysql_source_url,
    do:
      "https://raw.githubusercontent.com/mysql/mysql-server/" <>
        "d229bb760c49b65e19ec28342236961ad961d7fe/share/charsets/keybcs2.xml"

  def gnu_libiconv_supported?, do: false
  def defined_bytes(_profile), do: 256
  def reverse_policy(_profile), do: :exact_inverse
  def control_policy(_profile), do: :unicode_controls

  def decode(input, profile) when is_binary(input),
    do: decode_all(input, table(profile), [])

  def decode_discard(input, profile) when is_binary(input),
    do: decode(input, profile)

  def decode_chunk(input, profile, _final?) when is_binary(input) do
    {:ok, codepoints} = decode(input, profile)
    {:ok, codepoints, <<>>}
  end

  def decode_to_utf8(input, profile) when is_binary(input),
    do: decode_utf8_all(input, utf8_table(profile), [], 0, [])

  def encode(codepoints, profile) when is_list(codepoints),
    do: encode_all(codepoints, encoder(profile), [])

  def encode_discard(codepoints, profile) when is_list(codepoints),
    do: encode_discard_all(codepoints, encoder(profile), [])

  def encode_substitute(codepoints, profile, replacer)
      when is_list(codepoints) and is_function(replacer, 1),
      do:
        Iconvex.Specs.CodecSupport.encode_substitute_each(
          codepoints,
          &encode(&1, profile),
          replacer
        )

  def encode_chunk(codepoints, profile, _final?, :error) when is_list(codepoints) do
    case encode(codepoints, profile) do
      {:ok, output} -> {:ok, output, []}
      error -> error
    end
  end

  def encode_chunk(codepoints, profile, _final?, :discard) when is_list(codepoints) do
    {:ok, output} = encode_discard(codepoints, profile)
    {:ok, output, []}
  end

  def encode_chunk(codepoints, profile, _final?, {:replace, replacer})
      when is_list(codepoints) and is_function(replacer, 1) do
    case encode_substitute(codepoints, profile, replacer) do
      {:ok, output} -> {:ok, output, []}
      error -> error
    end
  end

  def encode_from_utf8(input, profile) when is_binary(input),
    do: encode_utf8_all(input, encoder(profile), 0, [], 0, [])

  defp table(profile), do: Map.fetch!(@tables, profile)
  defp utf8_table(profile), do: Map.fetch!(@utf8_tables, profile)
  defp encoder(profile), do: Map.fetch!(@encoders, profile)

  defp decode_all(<<>>, _table, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_all(<<a, b, c, d, e, f, g, h, rest::binary>>, table, acc)
       when a < 0x80 and b < 0x80 and c < 0x80 and d < 0x80 and e < 0x80 and f < 0x80 and
              g < 0x80 and h < 0x80,
       do: decode_all(rest, table, [h, g, f, e, d, c, b, a | acc])

  defp decode_all(<<byte, rest::binary>>, table, acc),
    do: decode_all(rest, table, [elem(table, byte) | acc])

  defp encode_all([], _encoder, acc), do: {:ok, finish_reversed_iodata(acc)}

  defp encode_all([a, b, c, d, e, f, g, h | rest], encoder, acc)
       when a < 0x80 and b < 0x80 and c < 0x80 and d < 0x80 and e < 0x80 and f < 0x80 and
              g < 0x80 and h < 0x80,
       do: encode_all(rest, encoder, [<<a, b, c, d, e, f, g, h>> | acc])

  defp encode_all([codepoint | rest], encoder, acc) do
    case encoder do
      %{^codepoint => byte} -> encode_all(rest, encoder, [byte | acc])
      _ -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_discard_all([], _encoder, acc), do: {:ok, finish_reversed_iodata(acc)}

  defp encode_discard_all([a, b, c, d, e, f, g, h | rest], encoder, acc)
       when a < 0x80 and b < 0x80 and c < 0x80 and d < 0x80 and e < 0x80 and f < 0x80 and
              g < 0x80 and h < 0x80,
       do: encode_discard_all(rest, encoder, [<<a, b, c, d, e, f, g, h>> | acc])

  defp encode_discard_all([codepoint | rest], encoder, acc) do
    case encoder do
      %{^codepoint => byte} -> encode_discard_all(rest, encoder, [byte | acc])
      _ -> encode_discard_all(rest, encoder, acc)
    end
  end

  defp decode_utf8_all(
         <<a, b, c, d, e, f, g, h, rest::binary>>,
         table,
         acc,
         count,
         chunks
       )
       when a < 0x80 and b < 0x80 and c < 0x80 and d < 0x80 and e < 0x80 and f < 0x80 and
              g < 0x80 and h < 0x80 and count <= @chunk_units - 8 do
    push_decode_utf8(rest, table, <<a, b, c, d, e, f, g, h>>, acc, count + 8, chunks)
  end

  defp decode_utf8_all(
         <<a, b, c, d, e, f, g, h, rest::binary>>,
         table,
         acc,
         count,
         chunks
       )
       when count <= @chunk_units - 8 do
    piece = [
      elem(table, a),
      elem(table, b),
      elem(table, c),
      elem(table, d),
      elem(table, e),
      elem(table, f),
      elem(table, g),
      elem(table, h)
    ]

    push_decode_utf8(rest, table, piece, acc, count + 8, chunks)
  end

  defp decode_utf8_all(<<>>, _table, acc, _count, chunks),
    do: {:ok, finish_chunks(acc, chunks)}

  defp decode_utf8_all(<<byte, rest::binary>>, table, acc, count, chunks),
    do: push_decode_utf8(rest, table, elem(table, byte), acc, count + 1, chunks)

  defp push_decode_utf8(rest, table, piece, acc, @chunk_units, chunks) do
    chunk = [piece | acc] |> :lists.reverse() |> IO.iodata_to_binary()
    decode_utf8_all(rest, table, [], 0, [chunk | chunks])
  end

  defp push_decode_utf8(rest, table, piece, acc, count, chunks),
    do: decode_utf8_all(rest, table, [piece | acc], count, chunks)

  defp encode_utf8_all(
         <<a, b, c, d, e, f, g, h, rest::binary>>,
         encoder,
         offset,
         acc,
         count,
         chunks
       )
       when a < 0x80 and b < 0x80 and c < 0x80 and d < 0x80 and e < 0x80 and f < 0x80 and
              g < 0x80 and h < 0x80 and count <= @chunk_units - 8 do
    push_encode_utf8(
      rest,
      encoder,
      offset + 8,
      <<a, b, c, d, e, f, g, h>>,
      acc,
      count + 8,
      chunks
    )
  end

  defp encode_utf8_all(<<>>, _encoder, _offset, acc, _count, chunks),
    do: {:ok, finish_chunks(acc, chunks)}

  defp encode_utf8_all(<<codepoint, rest::binary>>, encoder, offset, acc, count, chunks)
       when codepoint < 0x80,
       do: push_encode_utf8(rest, encoder, offset + 1, codepoint, acc, count + 1, chunks)

  defp encode_utf8_all(input, encoder, offset, acc, _count, chunks) do
    chunks = flush_encode_acc(acc, chunks)
    encode_unicode_chunks(input, <<>>, encoder, offset, chunks)
  end

  defp push_encode_utf8(rest, encoder, offset, piece, acc, @chunk_units, chunks) do
    chunk = [piece | acc] |> :lists.reverse() |> IO.iodata_to_binary()
    encode_utf8_all(rest, encoder, offset, [], 0, [chunk | chunks])
  end

  defp push_encode_utf8(rest, encoder, offset, piece, acc, count, chunks),
    do: encode_utf8_all(rest, encoder, offset, [piece | acc], count, chunks)

  defp encode_unicode_chunks(remaining, carry, encoder, offset, chunks) do
    {input, rest} = take_utf8_chunk(remaining, carry)

    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        with {:ok, encoded} <- encode_all(codepoints, encoder, []) do
          if rest == <<>> do
            {:ok, finish_binary_chunks(encoded, chunks)}
          else
            encode_unicode_chunks(
              rest,
              <<>>,
              encoder,
              offset + byte_size(input),
              [encoded | chunks]
            )
          end
        end

      {:incomplete, codepoints, tail} ->
        consumed = byte_size(input) - byte_size(tail)

        with {:ok, encoded} <- encode_all(codepoints, encoder, []) do
          if rest == <<>> do
            Iconvex.Specs.CodecSupport.malformed_utf8(tail, offset + consumed)
          else
            encode_unicode_chunks(
              rest,
              tail,
              encoder,
              offset + consumed,
              [encoded | chunks]
            )
          end
        end

      {:error, codepoints, tail} ->
        consumed = byte_size(input) - byte_size(tail)

        with {:ok, _encoded} <- encode_all(codepoints, encoder, []) do
          malformed = if rest == <<>>, do: tail, else: <<tail::binary, rest::binary>>
          Iconvex.Specs.CodecSupport.malformed_utf8(malformed, offset + consumed)
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

  defp flush_encode_acc([], chunks), do: chunks

  defp flush_encode_acc(acc, chunks),
    do: [acc |> :lists.reverse() |> IO.iodata_to_binary() | chunks]

  defp finish_binary_chunks(binary, chunks),
    do: [binary | chunks] |> :lists.reverse() |> IO.iodata_to_binary()

  defp finish_reversed_iodata(acc),
    do: acc |> :lists.reverse() |> IO.iodata_to_binary()

  defp finish_chunks([], chunks),
    do: chunks |> :lists.reverse() |> IO.iodata_to_binary()

  defp finish_chunks(acc, chunks) do
    chunk = acc |> :lists.reverse() |> IO.iodata_to_binary()
    [chunk | chunks] |> :lists.reverse() |> IO.iodata_to_binary()
  end
end

defmodule Iconvex.Specs.Kamenicky.Profile do
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
      alias Iconvex.Specs.Kamenicky, as: Engine

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
      def historical_source_sha256, do: Engine.historical_source_sha256()
      def fpc_source_sha256, do: Engine.fpc_source_sha256()
      def mysql_source_sha256, do: Engine.mysql_source_sha256()
      def gnu_libiconv_tar_sha256, do: Engine.gnu_libiconv_tar_sha256()
      def source_url, do: Engine.source_url()
      def fpc_source_url, do: Engine.fpc_source_url()
      def mysql_source_url, do: Engine.mysql_source_url()
      def gnu_libiconv_supported?, do: Engine.gnu_libiconv_supported?()
      def defined_bytes, do: Engine.defined_bytes(@profile)
      def reverse_policy, do: Engine.reverse_policy(@profile)
      def control_policy, do: Engine.control_policy(@profile)

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

defmodule Iconvex.Specs.KEYBCS2 do
  @moduledoc """
  Original Kamenicky brothers text encoding, historically named `KEYBCS2`.

  All 256 bytes are defined and reversible. C0 and DEL retain Unicode control
  semantics; byte `0xAD` is the original section sign U+00A7. Ambiguous IBM
  code-page numbers are deliberately not aliases.
  """

  use Iconvex.Specs.Kamenicky.Profile,
    profile: :original,
    canonical: "KEYBCS2",
    aliases: [
      "KAMENICKY",
      "KAMENICKY-ORIGINAL",
      "KAMENICKY-BROTHERS",
      "KEYBCS2-ORIGINAL"
    ],
    codec_id: :keybcs2
end

defmodule Iconvex.Specs.MySQLKEYBCS2 do
  @moduledoc """
  Source-qualified MySQL `keybcs2` text variant.

  It agrees with original KEYBCS2 at 255 bytes but maps byte `0xAD` to U+00A1
  instead of U+00A7. The distinct name prevents silent cross-system data loss.
  """

  use Iconvex.Specs.Kamenicky.Profile,
    profile: :mysql,
    canonical: "MYSQL-KEYBCS2",
    aliases: ["KEYBCS2-MYSQL", "MYSQL-KEYBCS2-AD-A1"],
    codec_id: :mysql_keybcs2
end

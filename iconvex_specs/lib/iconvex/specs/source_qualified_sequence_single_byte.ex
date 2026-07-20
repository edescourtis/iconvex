defmodule Iconvex.Specs.SourceQualifiedSequenceSingleByte.Engine do
  @moduledoc false

  @chunk_units 4_096

  def decode(input, table) when is_binary(input) and is_tuple(table),
    do: decode_loop(input, table, 0, [])

  def decode_discard(input, table) when is_binary(input) and is_tuple(table),
    do: {:ok, input |> decode_discard_loop(table, []) |> :lists.reverse()}

  def decode_to_utf8(input, table) when is_binary(input) and is_tuple(table),
    do: decode_utf8_loop(input, table, 0, [], 0, [])

  def decode_chunk(input, table) when is_binary(input) and is_tuple(table) do
    case decode(input, table) do
      {:ok, codepoints} -> {:ok, codepoints, <<>>}
      error -> error
    end
  end

  def encode(codepoints, encoder) when is_list(codepoints) and is_map(encoder) do
    case encode_loop(codepoints, encoder, true, :error, [], 0, []) do
      {:ok, output, []} -> {:ok, output}
      error -> error
    end
  end

  def encode_discard(codepoints, encoder) when is_list(codepoints) and is_map(encoder) do
    case encode_loop(codepoints, encoder, true, :discard, [], 0, []) do
      {:ok, output, []} -> {:ok, output}
      error -> error
    end
  end

  def encode_substitute(codepoints, encoder, replacer)
      when is_list(codepoints) and is_map(encoder) and is_function(replacer, 1) do
    case encode_loop(codepoints, encoder, true, {:replace, replacer}, [], 0, []) do
      {:ok, output, []} -> {:ok, output}
      error -> error
    end
  end

  def encode_chunk(codepoints, encoder, final?, policy)
      when is_list(codepoints) and is_map(encoder) and is_boolean(final?),
      do: encode_loop(codepoints, encoder, final?, policy, [], 0, [])

  def encode_from_utf8(input, encoder) when is_binary(input) and is_map(encoder) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        encode(codepoints, encoder)

      {:incomplete, converted, rest} ->
        utf8_error_after_prefix(
          converted,
          encoder,
          :incomplete_sequence,
          byte_size(input) - byte_size(rest),
          rest
        )

      {:error, converted, rest} ->
        utf8_error_after_prefix(
          converted,
          encoder,
          :invalid_sequence,
          byte_size(input) - byte_size(rest),
          rest
        )
    end
  end

  defp decode_loop(<<>>, _table, _offset, result), do: {:ok, :lists.reverse(result)}

  defp decode_loop(<<byte, rest::binary>>, table, offset, result) do
    case elem(table, byte) do
      nil ->
        {:error, :invalid_sequence, offset, <<byte>>}

      codepoint when is_integer(codepoint) ->
        decode_loop(rest, table, offset + 1, [codepoint | result])

      {first, second} ->
        decode_loop(rest, table, offset + 1, [second, first | result])

      {first, second, third} ->
        decode_loop(rest, table, offset + 1, [third, second, first | result])
    end
  end

  defp decode_discard_loop(<<>>, _table, result), do: result

  defp decode_discard_loop(<<byte, rest::binary>>, table, result) do
    case elem(table, byte) do
      nil ->
        decode_discard_loop(rest, table, result)

      codepoint when is_integer(codepoint) ->
        decode_discard_loop(rest, table, [codepoint | result])

      {first, second} ->
        decode_discard_loop(rest, table, [second, first | result])

      {first, second, third} ->
        decode_discard_loop(rest, table, [third, second, first | result])
    end
  end

  defp decode_utf8_loop(<<>>, _table, _offset, result, _count, chunks),
    do: {:ok, finish_iodata(result, chunks)}

  defp decode_utf8_loop(<<byte, rest::binary>>, table, offset, result, count, chunks) do
    case elem(table, byte) do
      nil ->
        {:error, :invalid_sequence, offset, <<byte>>}

      piece ->
        {next_result, next_count, next_chunks} = push_piece(piece, result, count, chunks)
        decode_utf8_loop(rest, table, offset + 1, next_result, next_count, next_chunks)
    end
  end

  defp encode_loop(codepoints, encoder, final?, policy, result, count, chunks) do
    case next_token(codepoints, encoder, final?) do
      :done ->
        {:ok, finish_iodata(result, chunks), []}

      {:pending, pending} ->
        {:ok, finish_iodata(result, chunks), pending}

      {:mapped, byte, rest} ->
        {next_result, next_count, next_chunks} = push_piece(byte, result, count, chunks)
        encode_loop(rest, encoder, final?, policy, next_result, next_count, next_chunks)

      {:single, codepoint, rest} ->
        case encoder.singles do
          %{^codepoint => byte} ->
            {next_result, next_count, next_chunks} = push_piece(byte, result, count, chunks)
            encode_loop(rest, encoder, final?, policy, next_result, next_count, next_chunks)

          _ ->
            encode_unrepresentable(
              codepoint,
              rest,
              encoder,
              final?,
              policy,
              result,
              count,
              chunks
            )
        end
    end
  end

  defp next_token([], _encoder, _final?), do: :done

  defp next_token([first, second, third | rest], encoder, _final?) do
    case encoder.sequence3 do
      %{{^first, ^second, ^third} => byte} ->
        {:mapped, byte, rest}

      _ ->
        next_two_or_single(first, second, [third | rest], encoder)
    end
  end

  defp next_token([first, second] = pending, encoder, false) do
    cond do
      Map.has_key?(encoder.prefix2, {first, second}) ->
        {:pending, pending}

      true ->
        next_two_or_single(first, second, [], encoder)
    end
  end

  defp next_token([first, second], encoder, true),
    do: next_two_or_single(first, second, [], encoder)

  defp next_token([first] = pending, encoder, false) do
    if Map.has_key?(encoder.prefix1, first),
      do: {:pending, pending},
      else: {:single, first, []}
  end

  defp next_token([first], _encoder, true), do: {:single, first, []}

  defp next_two_or_single(first, second, rest, encoder) do
    case encoder.sequence2 do
      %{{^first, ^second} => byte} -> {:mapped, byte, rest}
      _ -> {:single, first, [second | rest]}
    end
  end

  defp encode_unrepresentable(
         codepoint,
         _rest,
         _encoder,
         _final?,
         :error,
         _result,
         _count,
         _chunks
       ),
       do: {:error, :unrepresentable_character, codepoint}

  defp encode_unrepresentable(
         _codepoint,
         rest,
         encoder,
         final?,
         :discard,
         result,
         count,
         chunks
       ),
       do: encode_loop(rest, encoder, final?, :discard, result, count, chunks)

  defp encode_unrepresentable(
         codepoint,
         rest,
         encoder,
         final?,
         {:replace, replacer} = policy,
         result,
         count,
         chunks
       ) do
    case encode(replacer.(codepoint), encoder) do
      {:ok, replacement} ->
        {next_result, next_count, next_chunks} =
          push_piece(replacement, result, count, chunks)

        encode_loop(
          rest,
          encoder,
          final?,
          policy,
          next_result,
          next_count,
          next_chunks
        )

      error ->
        error
    end
  end

  defp utf8_error_after_prefix(converted, encoder, reason, offset, rest) do
    case encode(converted, encoder) do
      {:ok, _encoded_prefix} -> {:decode_error, reason, offset, rest}
      error -> error
    end
  end

  defp push_piece(piece, result, count, chunks) when count == @chunk_units - 1 do
    chunk = [piece | result] |> :lists.reverse() |> IO.iodata_to_binary()
    {[], 0, [chunk | chunks]}
  end

  defp push_piece(piece, result, count, chunks), do: {[piece | result], count + 1, chunks}

  defp finish_iodata([], chunks),
    do: chunks |> :lists.reverse() |> IO.iodata_to_binary()

  defp finish_iodata(result, chunks) do
    chunk = result |> :lists.reverse() |> IO.iodata_to_binary()
    [chunk | chunks] |> :lists.reverse() |> IO.iodata_to_binary()
  end
end

defmodule Iconvex.Specs.SourceQualifiedSequenceSingleByte do
  @moduledoc false

  @header "byte_hex,unicode_sequence,status"
  @mapping_pattern ~r/\A[0-9A-F]{4,6}(?:\+[0-9A-F]{4,6}){0,2}\z/

  defmacro defcodec(module_ast, options_ast) do
    module = Macro.expand(module_ast, __CALLER__)
    {options, []} = Code.eval_quoted(options_ast, [], __CALLER__)
    definition = build_definition!(module, options)

    quote bind_quoted: [module: module, definition: Macro.escape(definition)] do
      defmodule module do
        use Iconvex.Codec

        alias Iconvex.Specs.SourceQualifiedSequenceSingleByte.Engine

        @external_resource definition.mapping_path
        @external_resource definition.metadata_path
        @decode definition.decode
        @decode_utf8 definition.decode_utf8
        @encoder definition.encoder
        @canonical definition.canonical
        @codec_id definition.codec_id
        @mapping_sha256 definition.mapping_sha256
        @mapped_byte_count definition.mapped_byte_count
        @invalid_byte_count definition.invalid_byte_count
        @reserved_control_count definition.reserved_control_count
        @source_url definition.source_url
        @source_commit definition.source_commit
        @source_blob_sha256 definition.source_blob_sha256
        @source_blob_size definition.source_blob_size

        @impl true
        def canonical_name, do: @canonical

        @impl true
        def codec_id, do: @codec_id

        @impl true
        def decode(input) when is_binary(input), do: Engine.decode(input, @decode)

        @impl true
        def decode_discard(input) when is_binary(input),
          do: Engine.decode_discard(input, @decode)

        @impl true
        def decode_to_utf8(input) when is_binary(input),
          do: Engine.decode_to_utf8(input, @decode_utf8)

        @impl true
        def decode_chunk(input, _final?) when is_binary(input),
          do: Engine.decode_chunk(input, @decode)

        @impl true
        def encode(codepoints) when is_list(codepoints), do: Engine.encode(codepoints, @encoder)

        @impl true
        def encode_discard(codepoints) when is_list(codepoints),
          do: Engine.encode_discard(codepoints, @encoder)

        @impl true
        def encode_substitute(codepoints, replacer)
            when is_list(codepoints) and is_function(replacer, 1),
            do: Engine.encode_substitute(codepoints, @encoder, replacer)

        @impl true
        def encode_from_utf8(input) when is_binary(input),
          do: Engine.encode_from_utf8(input, @encoder)

        @impl true
        def encode_chunk(codepoints, final?, policy) when is_list(codepoints),
          do: Engine.encode_chunk(codepoints, @encoder, final?, policy)

        def __source_qualified_sequence_single_byte__, do: true
        def unit_bits, do: 8
        def inverse_policy, do: :unique_longest_match
        def provenance_qualification, do: :lietuvybe_commit_snapshot
        def blank_slot_policy, do: :strict_undefined
        def mapping_sha256, do: @mapping_sha256
        def mapped_byte_count, do: @mapped_byte_count
        def invalid_byte_count, do: @invalid_byte_count
        def reserved_control_count, do: @reserved_control_count
        def source_url, do: @source_url
        def source_commit, do: @source_commit
        def source_blob_sha256, do: @source_blob_sha256
        def source_blob_size, do: @source_blob_size
      end
    end
  end

  defp build_definition!(module, options) do
    required = [
      :canonical,
      :codec_id,
      :mapping_path,
      :mapping_sha256,
      :metadata_path,
      :mapped_byte_count,
      :invalid_byte_count,
      :reserved_control_count,
      :source_url,
      :source_commit,
      :source_blob_sha256,
      :source_blob_size
    ]

    for key <- required do
      Keyword.has_key?(options, key) ||
        raise ArgumentError, "#{inspect(module)} is missing required #{inspect(key)}"
    end

    canonical = Keyword.fetch!(options, :canonical)
    codec_id = Keyword.fetch!(options, :codec_id)
    mapping_path = Keyword.fetch!(options, :mapping_path)
    expected_mapping_sha256 = Keyword.fetch!(options, :mapping_sha256)
    metadata_path = Keyword.fetch!(options, :metadata_path)
    expected_mapped = Keyword.fetch!(options, :mapped_byte_count)
    expected_invalid = Keyword.fetch!(options, :invalid_byte_count)
    expected_reserved = Keyword.fetch!(options, :reserved_control_count)
    source_url = Keyword.fetch!(options, :source_url)
    source_commit = Keyword.fetch!(options, :source_commit)
    source_blob_sha256 = Keyword.fetch!(options, :source_blob_sha256)
    source_blob_size = Keyword.fetch!(options, :source_blob_size)

    unless is_binary(canonical) and
             Regex.match?(
               ~r/\ALIETUVYBE-[0-9A-F]{8}-LST-(?:1564|1590-[24])-2000-STRICT-BLANKS\z/,
               canonical
             ) do
      raise ArgumentError, "canonical name must be an explicit lietuvybė commit snapshot"
    end

    unless is_atom(codec_id), do: raise(ArgumentError, "codec_id must be an atom")

    for {label, digest} <- [mapping: expected_mapping_sha256, source: source_blob_sha256] do
      unless is_binary(digest) and Regex.match?(~r/\A[0-9a-f]{64}\z/, digest),
        do: raise(ArgumentError, "invalid #{label} SHA-256 for #{canonical}")
    end

    unless is_binary(source_commit) and Regex.match?(~r/\A[0-9a-f]{40}\z/, source_commit),
      do: raise(ArgumentError, "invalid source commit for #{canonical}")

    unless is_binary(source_url) and String.contains?(source_url, source_commit) and
             String.starts_with?(source_url, "https://raw.githubusercontent.com/lietuvybe-lt/"),
           do: raise(ArgumentError, "source URL is not pinned to the expected lietuvybė commit")

    unless is_integer(source_blob_size) and source_blob_size > 0,
      do: raise(ArgumentError, "invalid source blob size for #{canonical}")

    csv = File.read!(mapping_path)
    actual_mapping_sha256 = sha256(csv)

    unless actual_mapping_sha256 == expected_mapping_sha256 do
      raise ArgumentError,
            "mapping SHA-256 mismatch for #{canonical}: expected #{expected_mapping_sha256}, got #{actual_mapping_sha256}"
    end

    rows = parse_rows!(csv, canonical)
    mapped = Enum.count(rows, &(&1.mapping != nil))
    invalid = 256 - mapped
    reserved = Enum.count(rows, &(&1.status == :reserved_control))

    unless {mapped, invalid, reserved} ==
             {expected_mapped, expected_invalid, expected_reserved} do
      raise ArgumentError, "mapping/status cardinality mismatch for #{canonical}"
    end

    for {byte, codepoint} <- Enum.with_index(0..0x7F) do
      row = Enum.at(rows, codepoint)

      unless row.byte == byte and row.mapping == byte and row.status == :assigned,
        do: raise(ArgumentError, "ASCII identity is incomplete for #{canonical}")
    end

    complete_mappings = rows |> Enum.map(& &1.mapping) |> Enum.reject(&is_nil/1)

    unless length(complete_mappings) == length(Enum.uniq(complete_mappings)),
      do: raise(ArgumentError, "duplicate complete Unicode mapping in #{canonical}")

    metadata = File.read!(metadata_path)

    for pin <- [
          source_commit,
          source_blob_sha256,
          expected_mapping_sha256,
          "CC-BY-4.0",
          "not an implementation claim for the official standards",
          "strictly undefined"
        ] do
      unless String.contains?(metadata, pin),
        do: raise(ArgumentError, "metadata is missing #{inspect(pin)} for #{canonical}")
    end

    decode = rows |> Enum.map(& &1.mapping) |> List.to_tuple()

    decode_utf8 =
      rows
      |> Enum.map(fn
        %{mapping: nil} -> nil
        %{mapping: codepoint} when is_integer(codepoint) -> <<codepoint::utf8>>
        %{mapping: sequence} -> sequence |> Tuple.to_list() |> List.to_string()
      end)
      |> List.to_tuple()

    encoder = build_encoder(rows)

    %{
      canonical: canonical,
      codec_id: codec_id,
      mapping_path: mapping_path,
      metadata_path: metadata_path,
      mapping_sha256: expected_mapping_sha256,
      mapped_byte_count: expected_mapped,
      invalid_byte_count: expected_invalid,
      reserved_control_count: expected_reserved,
      source_url: source_url,
      source_commit: source_commit,
      source_blob_sha256: source_blob_sha256,
      source_blob_size: source_blob_size,
      decode: decode,
      decode_utf8: decode_utf8,
      encoder: encoder
    }
  end

  defp parse_rows!(csv, canonical) do
    lines = String.split(csv, "\n", trim: false)

    unless List.last(lines) == "" and Enum.at(lines, -2) != "" do
      raise ArgumentError, "mapping must end in exactly one LF for #{canonical}"
    end

    case Enum.drop(lines, -1) do
      [@header | source_rows] when length(source_rows) == 256 ->
        source_rows
        |> Enum.with_index()
        |> Enum.map(fn {row, byte} -> parse_row!(row, byte, canonical) end)

      [@header | source_rows] ->
        raise ArgumentError,
              "mapping must contain 256 data rows for #{canonical}, got #{length(source_rows)}"

      [header | _rows] ->
        raise ArgumentError, "unexpected mapping header #{inspect(header)} for #{canonical}"

      [] ->
        raise ArgumentError, "missing mapping header for #{canonical}"
    end
  end

  defp parse_row!(row, expected_byte, canonical) do
    expected_hex =
      expected_byte |> Integer.to_string(16) |> String.upcase() |> String.pad_leading(2, "0")

    case String.split(row, ",", parts: 3) do
      [^expected_hex, "", status] when status in ["undefined", "reserved_control"] ->
        %{byte: expected_byte, mapping: nil, status: String.to_atom(status)}

      [^expected_hex, sequence, "assigned"] ->
        unless Regex.match?(@mapping_pattern, sequence),
          do: raise(ArgumentError, "invalid Unicode sequence at #{expected_hex} for #{canonical}")

        codepoints = sequence |> String.split("+") |> Enum.map(&String.to_integer(&1, 16))

        unless Enum.all?(codepoints, &unicode_scalar?/1),
          do: raise(ArgumentError, "non-scalar Unicode value at #{expected_hex} for #{canonical}")

        mapping =
          case codepoints do
            [codepoint] -> codepoint
            [first, second] -> {first, second}
            [first, second, third] -> {first, second, third}
          end

        %{byte: expected_byte, mapping: mapping, status: :assigned}

      [actual_hex, _sequence, _status] when actual_hex != expected_hex ->
        raise ArgumentError,
              "mapping row order mismatch for #{canonical}: expected #{expected_hex}, got #{actual_hex}"

      _ ->
        raise ArgumentError, "invalid mapping row #{expected_hex} for #{canonical}"
    end
  end

  defp build_encoder(rows) do
    Enum.reduce(
      rows,
      %{singles: %{}, sequence2: %{}, sequence3: %{}, prefix1: %{}, prefix2: %{}},
      fn
        %{mapping: nil}, encoder ->
          encoder

        %{byte: byte, mapping: codepoint}, encoder when is_integer(codepoint) ->
          put_in(encoder, [:singles, codepoint], byte)

        %{byte: byte, mapping: {first, second}}, encoder ->
          encoder
          |> put_in([:sequence2, {first, second}], byte)
          |> put_in([:prefix1, first], true)

        %{byte: byte, mapping: {first, second, third}}, encoder ->
          encoder
          |> put_in([:sequence3, {first, second, third}], byte)
          |> put_in([:prefix1, first], true)
          |> put_in([:prefix2, {first, second}], true)
      end
    )
  end

  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

  defp unicode_scalar?(codepoint),
    do: codepoint in 0..0x10FFFF and codepoint not in 0xD800..0xDFFF
end

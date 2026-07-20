defmodule Iconvex.Specs.SourceQualifiedSingleByte.Engine do
  @moduledoc false

  def decode(input, table) when is_binary(input) and is_tuple(table),
    do: decode_loop(input, table, 0, [])

  def decode_discard(input, table) when is_binary(input) and is_tuple(table),
    do: {:ok, input |> decode_discard_loop(table, []) |> :lists.reverse()}

  def decode_to_utf8(input, table) when is_binary(input) and is_tuple(table),
    do: decode_utf8_loop(input, table, 0, [])

  def encode(codepoints, table) when is_list(codepoints) and is_map(table),
    do: encode_loop(codepoints, table, [])

  def encode_discard(codepoints, table) when is_list(codepoints) and is_map(table) do
    {:ok,
     codepoints
     |> encode_discard_loop(table, [])
     |> :lists.reverse()
     |> :erlang.list_to_binary()}
  end

  def encode_substitute(codepoints, table, replacer)
      when is_list(codepoints) and is_map(table) and is_function(replacer, 1),
      do: encode_substitute_loop(codepoints, table, replacer, [])

  def encode_from_utf8(input, table) when is_binary(input) and is_map(table) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        encode(codepoints, table)

      {:incomplete, converted, rest} ->
        utf8_error_after_prefix(
          converted,
          table,
          :incomplete_sequence,
          byte_size(input) - byte_size(rest),
          rest
        )

      {:error, converted, rest} ->
        utf8_error_after_prefix(
          converted,
          table,
          :invalid_sequence,
          byte_size(input) - byte_size(rest),
          rest
        )
    end
  end

  def decode_chunk(input, table) when is_binary(input) and is_tuple(table) do
    case decode(input, table) do
      {:ok, codepoints} -> {:ok, codepoints, <<>>}
      error -> error
    end
  end

  def encode_chunk(codepoints, table, :error), do: stream_result(encode(codepoints, table))

  def encode_chunk(codepoints, table, :discard),
    do: stream_result(encode_discard(codepoints, table))

  def encode_chunk(codepoints, table, {:replace, replacer}),
    do: stream_result(encode_substitute(codepoints, table, replacer))

  defp decode_loop(<<>>, _table, _offset, result), do: {:ok, :lists.reverse(result)}

  defp decode_loop(<<byte, rest::binary>>, table, offset, result) do
    case elem(table, byte) do
      nil -> {:error, :invalid_sequence, offset, <<byte>>}
      codepoint -> decode_loop(rest, table, offset + 1, [codepoint | result])
    end
  end

  defp decode_discard_loop(<<>>, _table, result), do: result

  defp decode_discard_loop(<<byte, rest::binary>>, table, result) do
    case elem(table, byte) do
      nil -> decode_discard_loop(rest, table, result)
      codepoint -> decode_discard_loop(rest, table, [codepoint | result])
    end
  end

  defp decode_utf8_loop(<<>>, _table, _offset, result) do
    {:ok, result |> :lists.reverse() |> IO.iodata_to_binary()}
  end

  defp decode_utf8_loop(<<byte, rest::binary>>, table, offset, result) do
    case elem(table, byte) do
      nil -> {:error, :invalid_sequence, offset, <<byte>>}
      utf8 -> decode_utf8_loop(rest, table, offset + 1, [utf8 | result])
    end
  end

  defp encode_loop([], _table, result) do
    {:ok, result |> :lists.reverse() |> :erlang.list_to_binary()}
  end

  defp encode_loop([codepoint | rest], table, result) do
    case Map.fetch(table, codepoint) do
      {:ok, byte} -> encode_loop(rest, table, [byte | result])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_discard_loop([], _table, result), do: result

  defp encode_discard_loop([codepoint | rest], table, result) do
    case Map.fetch(table, codepoint) do
      {:ok, byte} -> encode_discard_loop(rest, table, [byte | result])
      :error -> encode_discard_loop(rest, table, result)
    end
  end

  defp encode_substitute_loop([], _table, _replacer, result) do
    {:ok, result |> :lists.reverse() |> :erlang.list_to_binary()}
  end

  defp encode_substitute_loop([codepoint | rest], table, replacer, result) do
    case Map.fetch(table, codepoint) do
      {:ok, byte} ->
        encode_substitute_loop(rest, table, replacer, [byte | result])

      :error ->
        case encode_replacement(replacer.(codepoint), table, result) do
          {:ok, result} -> encode_substitute_loop(rest, table, replacer, result)
          error -> error
        end
    end
  end

  defp encode_replacement([], _table, result), do: {:ok, result}

  defp encode_replacement([codepoint | rest], table, result) do
    case Map.fetch(table, codepoint) do
      {:ok, byte} -> encode_replacement(rest, table, [byte | result])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp utf8_error_after_prefix(converted, table, reason, offset, rest) do
    case encode(converted, table) do
      {:ok, _encoded_prefix} -> {:decode_error, reason, offset, rest}
      error -> error
    end
  end

  defp stream_result({:ok, output}), do: {:ok, output, []}
  defp stream_result(error), do: error
end

defmodule Iconvex.Specs.SourceQualifiedSingleByte do
  @moduledoc false

  defmacro defcodec(module_ast, options_ast) do
    module = Macro.expand(module_ast, __CALLER__)
    {options, []} = Code.eval_quoted(options_ast, [], __CALLER__)
    definition = build_definition!(module, options)

    quote bind_quoted: [module: module, definition: Macro.escape(definition)] do
      defmodule module do
        use Iconvex.Codec

        alias Iconvex.Specs.SourceQualifiedSingleByte.Engine

        @external_resource definition.mapping_path
        @external_resource definition.metadata_path
        @decode definition.decode
        @decode_utf8 definition.decode_utf8
        @encode definition.encode
        @canonical definition.canonical
        @codec_id definition.codec_id
        @mapping_sha256 definition.mapping_sha256
        @mapped_byte_count definition.mapped_byte_count
        @invalid_byte_count definition.invalid_byte_count
        @source_url definition.source_url
        @source_version definition.source_version
        @source_date definition.source_date
        @source_size definition.source_size
        @source_sha256 definition.source_sha256

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
        def encode(codepoints) when is_list(codepoints), do: Engine.encode(codepoints, @encode)

        @impl true
        def encode_discard(codepoints) when is_list(codepoints),
          do: Engine.encode_discard(codepoints, @encode)

        @impl true
        def encode_substitute(codepoints, replacer)
            when is_list(codepoints) and is_function(replacer, 1),
            do: Engine.encode_substitute(codepoints, @encode, replacer)

        @impl true
        def encode_from_utf8(input) when is_binary(input),
          do: Engine.encode_from_utf8(input, @encode)

        @impl true
        def decode_chunk(input, _final?) when is_binary(input),
          do: Engine.decode_chunk(input, @decode)

        @impl true
        def encode_chunk(codepoints, _final?, policy) when is_list(codepoints),
          do: Engine.encode_chunk(codepoints, @encode, policy)

        def __source_qualified_single_byte__, do: true
        def unit_bits, do: 8
        def inverse_policy, do: :lowest_byte
        def provenance_qualification, do: :source_only_no_endorsement
        def mapping_sha256, do: @mapping_sha256
        def mapped_byte_count, do: @mapped_byte_count
        def invalid_byte_count, do: @invalid_byte_count
        def source_url, do: @source_url
        def source_version, do: @source_version
        def source_date, do: @source_date
        def source_size, do: @source_size
        def source_sha256, do: @source_sha256
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
      :source_url,
      :source_version,
      :source_date,
      :source_size,
      :source_sha256
    ]

    for key <- required do
      Keyword.has_key?(options, key) ||
        raise ArgumentError, "#{inspect(module)} is missing required #{inspect(key)}"
    end

    canonical = Keyword.fetch!(options, :canonical)
    mapping_path = Keyword.fetch!(options, :mapping_path)
    metadata_path = Keyword.fetch!(options, :metadata_path)
    expected_mapping_sha256 = Keyword.fetch!(options, :mapping_sha256)
    expected_count = Keyword.fetch!(options, :mapped_byte_count)
    source_url = Keyword.fetch!(options, :source_url)
    source_version = Keyword.fetch!(options, :source_version)
    source_date = Keyword.fetch!(options, :source_date)
    source_size = Keyword.fetch!(options, :source_size)
    source_sha256 = Keyword.fetch!(options, :source_sha256)

    unless is_binary(canonical) and Regex.match?(~r/^EVERTYPE-\d{4}-[A-Z0-9-]+$/, canonical),
      do: raise(ArgumentError, "canonical name must be explicitly Evertype/year qualified")

    unless is_atom(Keyword.fetch!(options, :codec_id)),
      do: raise(ArgumentError, "codec_id must be an atom")

    for {label, digest} <- [mapping: expected_mapping_sha256, source: source_sha256] do
      unless is_binary(digest) and Regex.match?(~r/^[0-9a-f]{64}$/, digest),
        do: raise(ArgumentError, "invalid #{label} SHA-256 for #{canonical}")
    end

    unless is_binary(source_url) and String.starts_with?(source_url, "https://www.evertype.com/"),
      do: raise(ArgumentError, "source URL must be an Evertype HTTPS URL")

    unless is_binary(source_version) and is_binary(source_date) and is_integer(source_size) and
             source_size > 0,
           do: raise(ArgumentError, "invalid source version/date/size for #{canonical}")

    csv = File.read!(mapping_path)
    actual_mapping_sha256 = sha256(csv)

    unless actual_mapping_sha256 == expected_mapping_sha256 do
      raise ArgumentError,
            "mapping SHA-256 mismatch for #{canonical}: expected #{expected_mapping_sha256}, got #{actual_mapping_sha256}"
    end

    pairs = parse_mapping!(csv, canonical)

    unless length(pairs) == expected_count,
      do: raise(ArgumentError, "mapped byte count mismatch for #{canonical}")

    controls = Map.new(for value <- 0..0x1F, do: {value, value}) |> Map.put(0x7F, 0x7F)
    mapping = Map.new(pairs)

    unless Map.take(mapping, Map.keys(controls)) == controls,
      do: raise(ArgumentError, "standard control mappings are incomplete for #{canonical}")

    metadata = File.read!(metadata_path)

    for pin <- [
          canonical,
          source_url,
          source_version,
          source_date,
          Integer.to_string(source_size),
          source_sha256,
          expected_mapping_sha256,
          "does not imply vendor authorship, affiliation, approval, or endorsement"
        ] do
      unless String.contains?(metadata, pin),
        do: raise(ArgumentError, "metadata is missing #{inspect(pin)} for #{canonical}")
    end

    decode = List.to_tuple(for byte <- 0..255, do: Map.get(mapping, byte))

    decode_utf8 =
      List.to_tuple(
        for byte <- 0..255 do
          case Map.get(mapping, byte) do
            nil -> nil
            codepoint -> <<codepoint::utf8>>
          end
        end
      )

    encode =
      Enum.reduce(pairs, %{}, fn {byte, codepoint}, inverse ->
        Map.put_new(inverse, codepoint, byte)
      end)

    %{
      canonical: canonical,
      codec_id: Keyword.fetch!(options, :codec_id),
      mapping_path: mapping_path,
      metadata_path: metadata_path,
      mapping_sha256: expected_mapping_sha256,
      mapped_byte_count: expected_count,
      invalid_byte_count: 256 - expected_count,
      source_url: source_url,
      source_version: source_version,
      source_date: source_date,
      source_size: source_size,
      source_sha256: source_sha256,
      decode: decode,
      decode_utf8: decode_utf8,
      encode: encode
    }
  end

  defp parse_mapping!(csv, canonical) do
    case String.split(csv, "\n", trim: true) do
      ["byte,unicode" | rows] ->
        pairs = Enum.map(rows, &parse_row!(&1, canonical))
        bytes = Enum.map(pairs, &elem(&1, 0))

        unless bytes == Enum.sort(bytes) and length(bytes) == length(Enum.uniq(bytes)),
          do: raise(ArgumentError, "mapping bytes must be unique and sorted for #{canonical}")

        pairs

      _ ->
        raise ArgumentError, "invalid normalized mapping header for #{canonical}"
    end
  end

  defp parse_row!(row, canonical) do
    with [byte_hex, codepoint_hex] <- String.split(row, ",", parts: 2),
         {byte, ""} <- Integer.parse(byte_hex, 16),
         {codepoint, ""} <- Integer.parse(codepoint_hex, 16),
         true <- byte in 0..255,
         true <- scalar?(codepoint) do
      {byte, codepoint}
    else
      _ -> raise ArgumentError, "invalid normalized mapping row #{inspect(row)} for #{canonical}"
    end
  end

  defp scalar?(codepoint),
    do: codepoint in 0..0xD7FF or codepoint in 0xE000..0x10FFFF

  defp sha256(bytes),
    do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end

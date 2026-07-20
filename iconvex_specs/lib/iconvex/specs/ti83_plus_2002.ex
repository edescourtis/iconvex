defmodule Iconvex.Specs.TI83Plus2002.SourceAsset do
  @moduledoc false

  @expected_header "BYTE;LARGE_READABLE;LARGE_LOSSLESS;LARGE_REVERSE;" <>
                     "SMALL_READABLE;SMALL_LOSSLESS;SMALL_REVERSE"

  def validate!(mapping_bytes, metadata_bytes, options)
      when is_binary(mapping_bytes) and is_binary(metadata_bytes) and is_list(options) do
    verify_sha!(:mapping, mapping_bytes, Keyword.fetch!(options, :mapping_sha256))
    verify_sha!(:metadata, metadata_bytes, Keyword.fetch!(options, :metadata_sha256))

    [header | source_rows] =
      mapping_bytes
      |> String.split(~r/\R/, trim: true)
      |> Enum.reject(&String.starts_with?(&1, "#"))
      |> Enum.map(&String.trim/1)

    unless header == @expected_header do
      raise "unexpected TI-83 Plus mapping header: #{inspect(header)}"
    end

    unless length(source_rows) == 256 do
      raise "TI-83 Plus mapping must contain exactly one ordered row for every byte 00..FF"
    end

    rows =
      source_rows
      |> Enum.with_index()
      |> Enum.map(fn {line, expected_byte} -> parse_row!(line, expected_byte) end)

    validate_byte_domain!(rows)
    validate_readable_policies!(rows)
    validate_canonical_reverses!(rows)
    validate_lossless_profiles!(rows)
    rows
  end

  defp verify_sha!(label, bytes, expected) do
    actual = :sha256 |> :crypto.hash(bytes) |> Base.encode16(case: :lower)

    unless actual == expected do
      raise "TI-83 Plus #{label} asset SHA-256 mismatch: expected #{expected}, got #{actual}"
    end
  end

  defp parse_row!(line, expected_byte) do
    case String.split(line, ";") do
      [
        byte,
        large_readable,
        large_lossless,
        large_reverse,
        small_readable,
        small_lossless,
        small_reverse
      ] ->
        expected_token = Base.encode16(<<expected_byte>>)

        unless byte == expected_token do
          raise "TI-83 Plus mapping must contain exactly one ordered row for every byte 00..FF; " <>
                  "BYTE must be exact two-digit uppercase hexadecimal #{expected_token}, " <>
                  "got #{inspect(byte)}"
        end

        {
          expected_byte,
          parse_sequence!(large_readable),
          parse_sequence!(large_lossless),
          parse_policy!(large_reverse),
          parse_sequence!(small_readable),
          parse_sequence!(small_lossless),
          parse_policy!(small_reverse)
        }

      _ ->
        raise "TI-83 Plus mapping row must contain exactly seven fields: #{inspect(line)}"
    end
  end

  defp parse_sequence!("-"), do: :invalid

  defp parse_sequence!(value) do
    codepoints = value |> String.split("+") |> Enum.map(&String.to_integer(&1, 16))

    case codepoints do
      [codepoint] ->
        if valid_scalar?(codepoint),
          do: codepoint,
          else: raise("invalid TI-83 Plus Unicode scalar in #{value}")

      [first, second] ->
        if valid_scalar?(first) and valid_scalar?(second),
          do: {first, second},
          else: raise("invalid TI-83 Plus Unicode sequence in #{value}")

      _ ->
        raise "TI-83 Plus mapping must contain one or two scalars: #{value}"
    end
  end

  defp parse_policy!("canonical"), do: :canonical
  defp parse_policy!("longest"), do: :longest
  defp parse_policy!("vpua"), do: :vpua
  defp parse_policy!("decode_only"), do: :decode_only
  defp parse_policy!("invalid"), do: :invalid
  defp parse_policy!("alias:" <> byte), do: {:alias, String.to_integer(byte, 16)}
  defp parse_policy!(value), do: raise("invalid TI-83 Plus reverse policy: #{inspect(value)}")

  defp valid_scalar?(codepoint),
    do: codepoint in 0..0x10FFFF and codepoint not in 0xD800..0xDFFF

  defp validate_byte_domain!(rows) do
    unless length(rows) == 256 and Enum.map(rows, &elem(&1, 0)) == Enum.to_list(0x00..0xFF) do
      raise "TI-83 Plus mapping must contain exactly one ordered row for every byte 00..FF"
    end
  end

  defp validate_readable_policies!(rows) do
    for {font, mapping_index, policy_index} <- [
          {:large, 1, 3},
          {:small, 4, 6}
        ],
        row <- rows do
      byte = elem(row, 0)
      mapping = elem(row, mapping_index)
      policy = elem(row, policy_index)

      case policy do
        :invalid when mapping == :invalid ->
          :ok

        :invalid ->
          raise "TI-83 Plus #{font} byte #{byte} marks a defined mapping invalid"

        {:alias, target} when target in 0x00..0xFF ->
          target_row = Enum.at(rows, target)
          target_mapping = elem(target_row, mapping_index)
          target_policy = elem(target_row, policy_index)

          unless mapping != :invalid and mapping == target_mapping do
            raise "TI-83 Plus #{font} byte #{byte} has an inconsistent alias target #{target}"
          end

          unless target_policy in [:canonical, :longest, :vpua] do
            raise "TI-83 Plus #{font} byte #{byte} alias target must be a canonical reverse owner"
          end

        {:alias, target} ->
          raise "TI-83 Plus #{font} byte #{byte} has an invalid alias target #{target}"

        :longest when is_tuple(mapping) ->
          :ok

        policy when policy in [:canonical, :vpua, :decode_only] and mapping != :invalid ->
          :ok

        _ ->
          raise "TI-83 Plus #{font} byte #{byte} has inconsistent mapping/reverse policy"
      end
    end
  end

  defp validate_canonical_reverses!(rows) do
    for {font, mapping_index, policy_index} <- [
          {:large, 1, 3},
          {:small, 4, 6}
        ] do
      canonical_mappings =
        for row <- rows,
            elem(row, policy_index) in [:canonical, :longest, :vpua],
            do: elem(row, mapping_index)

      unless length(canonical_mappings) == length(Enum.uniq(canonical_mappings)) do
        raise "TI-83 Plus #{font} canonical reverse mappings must be unique"
      end
    end
  end

  defp validate_lossless_profiles!(rows) do
    for {profile, mapping_index} <- [large_lossless: 2, small_lossless: 5] do
      mappings = Enum.map(rows, &elem(&1, mapping_index))

      unless Enum.all?(mappings, &(&1 != :invalid)) and length(Enum.uniq(mappings)) == 256 do
        raise "TI-83 Plus #{profile} mappings must be defined and bijective for all 256 bytes"
      end
    end
  end
end

defmodule Iconvex.Specs.TI83Plus2002.Engine do
  @moduledoc false

  @mapping_path Path.expand(
                  "../../../priv/sources/ti-83-plus-2002/mapping.csv",
                  __DIR__
                )
  @metadata_path Path.expand(
                   "../../../priv/sources/ti-83-plus-2002/SOURCE_METADATA.md",
                   __DIR__
                 )

  @external_resource @mapping_path
  @external_resource @metadata_path

  @mapping_sha256 "186d80d270a6a27815df8d0b5ff993c65b158efb7f3d6ddd27533feb9cb96ccc"
  @metadata_sha256 "31a7655c59eb3da1f7c6bb123f6eedb961f64ea2cb3a7e9240dc5e004e73aa8f"
  @source_sha256 "a07d2cae4d5be0529901c178acd80028d2a72c484a04c61cde104f34712cec55"
  @source_url "https://education.ti.com/download/en/ed-tech/830D08FF31804AEAA2F03B8F5E89AD14/672891A1E98349CAB91C11B4928C253C/sdk83pguide.pdf"
  @profiles [
    :large_readable,
    :large_lossless,
    :large_raw,
    :small_readable,
    :small_lossless,
    :small_raw
  ]
  @chunk_units 4_096

  mapping_bytes = File.read!(@mapping_path)
  metadata_bytes = File.read!(@metadata_path)

  rows =
    Iconvex.Specs.TI83Plus2002.SourceAsset.validate!(mapping_bytes, metadata_bytes,
      mapping_sha256: @mapping_sha256,
      metadata_sha256: @metadata_sha256
    )

  tables = %{
    large_readable: rows |> Enum.map(&elem(&1, 1)) |> List.to_tuple(),
    large_lossless: rows |> Enum.map(&elem(&1, 2)) |> List.to_tuple(),
    large_raw: 0x00..0xFF |> Enum.map(&(0xF8400 + &1)) |> List.to_tuple(),
    small_readable: rows |> Enum.map(&elem(&1, 4)) |> List.to_tuple(),
    small_lossless: rows |> Enum.map(&elem(&1, 5)) |> List.to_tuple(),
    small_raw: 0x00..0xFF |> Enum.map(&(0xF8600 + &1)) |> List.to_tuple()
  }

  reverse_policies = %{
    large_readable: rows |> Enum.map(&elem(&1, 3)) |> List.to_tuple(),
    small_readable: rows |> Enum.map(&elem(&1, 6)) |> List.to_tuple()
  }

  canonical_reverse? = fn profile, byte ->
    case Map.get(reverse_policies, profile) do
      nil -> true
      policies -> elem(policies, byte) in [:canonical, :longest, :vpua]
    end
  end

  single_encoders =
    Map.new(@profiles, fn profile ->
      encoder =
        tables
        |> Map.fetch!(profile)
        |> Tuple.to_list()
        |> Enum.with_index()
        |> Enum.reduce(%{}, fn
          {codepoint, byte}, acc when is_integer(codepoint) ->
            if canonical_reverse?.(profile, byte),
              do: Map.put(acc, codepoint, byte),
              else: acc

          {_sequence, _byte}, acc ->
            acc
        end)

      {profile, encoder}
    end)

  sequence_encoders =
    Map.new(@profiles, fn profile ->
      encoder =
        tables
        |> Map.fetch!(profile)
        |> Tuple.to_list()
        |> Enum.with_index()
        |> Enum.reduce(%{}, fn
          {{first, second}, byte}, acc ->
            if canonical_reverse?.(profile, byte),
              do: Map.put(acc, {first, second}, byte),
              else: acc

          {_mapping, _byte}, acc ->
            acc
        end)

      {profile, encoder}
    end)

  prefixes =
    Map.new(sequence_encoders, fn {profile, encoder} ->
      {profile, encoder |> Map.keys() |> Enum.map(&elem(&1, 0)) |> MapSet.new()}
    end)

  utf8_tables =
    Map.new(tables, fn {profile, table} ->
      utf8 =
        table
        |> Tuple.to_list()
        |> Enum.map(fn
          :invalid -> :invalid
          codepoint when is_integer(codepoint) -> <<codepoint::utf8>>
          {first, second} -> <<first::utf8, second::utf8>>
        end)
        |> List.to_tuple()

      {profile, utf8}
    end)

  @tables tables
  @single_encoders single_encoders
  @sequence_encoders sequence_encoders
  @prefixes prefixes
  @utf8_tables utf8_tables
  def profiles, do: @profiles
  def mapping_sha256, do: @mapping_sha256
  def metadata_sha256, do: @metadata_sha256
  def source_sha256, do: @source_sha256
  def source_url, do: @source_url

  def source_pages(profile) when profile in [:large_readable, :large_lossless, :large_raw],
    do: Enum.to_list(173..179)

  def source_pages(profile) when profile in [:small_readable, :small_lossless, :small_raw],
    do: Enum.to_list(180..187)

  def printed_source_pages(profile)
      when profile in [:large_readable, :large_lossless, :large_raw],
      do: Enum.to_list(156..162)

  def printed_source_pages(profile)
      when profile in [:small_readable, :small_lossless, :small_raw],
      do: Enum.to_list(163..170)

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

  defp decode_utf8_all(<<>>, _table, _offset, acc, _count, chunks),
    do: {:ok, finish_iodata(acc, chunks)}

  defp decode_utf8_all(<<byte, rest::binary>>, table, offset, acc, count, chunks) do
    case elem(table, byte) do
      :invalid ->
        {:error, :invalid_sequence, offset, <<byte>>}

      piece ->
        {next_acc, next_count, next_chunks} = push_piece(piece, acc, count, chunks)
        decode_utf8_all(rest, table, offset + 1, next_acc, next_count, next_chunks)
    end
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

defmodule Iconvex.Specs.TI83Plus2002.Profile do
  @moduledoc false

  defmacro __using__(options) do
    profile = Keyword.fetch!(options, :profile)
    canonical = Keyword.fetch!(options, :canonical)
    codec_id = Keyword.fetch!(options, :codec_id)

    quote bind_quoted: [profile: profile, canonical: canonical, codec_id: codec_id] do
      use Iconvex.Codec
      alias Iconvex.Specs.TI83Plus2002.Engine

      @profile profile
      @canonical canonical
      @codec_id codec_id

      @impl true
      def canonical_name, do: @canonical

      @impl true
      def aliases, do: []

      @impl true
      def codec_id, do: @codec_id

      def unit_bits, do: 8
      def mapping_sha256, do: Engine.mapping_sha256()
      def metadata_sha256, do: Engine.metadata_sha256()
      def source_sha256, do: Engine.source_sha256()
      def source_pages, do: Engine.source_pages(@profile)
      def printed_source_pages, do: Engine.printed_source_pages(@profile)
      def source_url, do: Engine.source_url()

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

defmodule Iconvex.Specs.TI83PlusLarge do
  @moduledoc "Readable large-font TI-83 Plus character profile from the 2002 developer guide."

  use Iconvex.Specs.TI83Plus2002.Profile,
    profile: :large_readable,
    canonical: "TI-83-PLUS-LARGE",
    codec_id: :ti_83_plus_large
end

defmodule Iconvex.Specs.TI83PlusLargeLosslessVPUA do
  @moduledoc "Mixed readable/lossless large-font TI-83 Plus profile."

  use Iconvex.Specs.TI83Plus2002.Profile,
    profile: :large_lossless,
    canonical: "TI-83-PLUS-LARGE-LOSSLESS-VPUA",
    codec_id: :ti_83_plus_large_lossless_vpua
end

defmodule Iconvex.Specs.TI83PlusLargeRawVPUA do
  @moduledoc "Forensic one-to-one large-font TI-83 Plus byte profile."

  use Iconvex.Specs.TI83Plus2002.Profile,
    profile: :large_raw,
    canonical: "TI-83-PLUS-LARGE-RAW-VPUA",
    codec_id: :ti_83_plus_large_raw_vpua
end

defmodule Iconvex.Specs.TI83PlusSmall do
  @moduledoc "Readable small-font TI-83 Plus character profile from the 2002 developer guide."

  use Iconvex.Specs.TI83Plus2002.Profile,
    profile: :small_readable,
    canonical: "TI-83-PLUS-SMALL",
    codec_id: :ti_83_plus_small
end

defmodule Iconvex.Specs.TI83PlusSmallLosslessVPUA do
  @moduledoc "Mixed readable/lossless small-font TI-83 Plus profile."

  use Iconvex.Specs.TI83Plus2002.Profile,
    profile: :small_lossless,
    canonical: "TI-83-PLUS-SMALL-LOSSLESS-VPUA",
    codec_id: :ti_83_plus_small_lossless_vpua
end

defmodule Iconvex.Specs.TI83PlusSmallRawVPUA do
  @moduledoc "Forensic one-to-one small-font TI-83 Plus byte profile."

  use Iconvex.Specs.TI83Plus2002.Profile,
    profile: :small_raw,
    canonical: "TI-83-PLUS-SMALL-RAW-VPUA",
    codec_id: :ti_83_plus_small_raw_vpua
end

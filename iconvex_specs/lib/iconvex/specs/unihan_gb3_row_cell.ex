defmodule Iconvex.Specs.UnihanGB3RowCell.Engine do
  @moduledoc false

  alias Iconvex.Specs.UnihanGB3RowCell.SourceAsset

  @source_dir Path.expand("../../../priv/sources/unihan-17.0.0-kgb3", __DIR__)
  @mapping_path Path.join(@source_dir, "row_cells.csv")
  @metadata_path Path.join(@source_dir, "SOURCE_METADATA.md")
  @external_resource @mapping_path
  @external_resource @metadata_path

  hashes = SourceAsset.expected_hashes()
  rows = SourceAsset.validate!(File.read!(@mapping_path), File.read!(@metadata_path), hashes)
  decode_by_index = Map.new(rows, &{(&1.row - 16) * 94 + &1.cell - 1, &1.scalar})

  @decode for(index <- 0..7_237, do: Map.get(decode_by_index, index)) |> List.to_tuple()
  @encode Map.new(rows, fn row ->
            {row.scalar, <<row.row + 0x20, row.cell + 0x20>>}
          end)

  @property_metadata %{
    aliases: [],
    assigned_tokens: 7_236,
    grammar: "[0-9]{4}",
    mapping_name: "UNIHAN-17.0.0-KGB3-ROW-CELL-DECIMAL-TOKEN",
    property_status: :provisional,
    reverse_policy: :unique,
    reverse_scalars: 7_236,
    stream_transport: :undefined,
    transport: :single_property_token,
    unicode_version: "17.0.0",
    unihan_property: :kGB3
  }

  @codec_metadata %{
    aliases: [],
    assigned_mappings: 7_236,
    canonical_name: "UNIHAN-17.0.0-KGB3-ROW-CELL-GL",
    coordinate_holes: [1893, 9294],
    mapping_sha256: hashes.mapping,
    metadata_sha256: hashes.metadata,
    profile: :raw_gl_row_cell,
    property_status: :provisional,
    unicode_version: "17.0.0",
    unihan_property: :kGB3
  }

  def property_metadata, do: @property_metadata
  def codec_metadata, do: @codec_metadata

  def decode(input) when is_binary(input), do: decode_all(input, 0, [])
  def decode_discard(input) when is_binary(input), do: decode_discard_all(input, [])
  def decode_to_utf8(input) when is_binary(input), do: decode_utf8_all(input, 0, [])

  def decode_chunk(input, final?) when is_binary(input) and is_boolean(final?) do
    stable_size = byte_size(input) - rem(byte_size(input), 2)
    <<stable::binary-size(stable_size), pending::binary>> = input

    case decode(stable) do
      {:ok, scalars} when pending == <<>> ->
        {:ok, scalars, <<>>}

      {:ok, _scalars} when final? ->
        <<lead>> = pending
        kind = if valid_lead?(lead), do: :incomplete_sequence, else: :invalid_sequence
        {:error, kind, stable_size, pending}

      {:ok, scalars} ->
        {:ok, scalars, pending}

      error ->
        error
    end
  end

  def encode(codepoints) when is_list(codepoints), do: encode_all(codepoints, [])
  def encode_discard(codepoints) when is_list(codepoints), do: encode_discard_all(codepoints, [])

  def encode_substitute(codepoints, replacer)
      when is_list(codepoints) and is_function(replacer, 1),
      do: encode_substitute_all(codepoints, replacer, [])

  def encode_chunk(codepoints, _final?, :error) when is_list(codepoints) do
    case encode(codepoints) do
      {:ok, output} -> {:ok, output, []}
      error -> error
    end
  end

  def encode_chunk(codepoints, _final?, :discard) when is_list(codepoints) do
    {:ok, output} = encode_discard(codepoints)
    {:ok, output, []}
  end

  def encode_chunk(codepoints, _final?, {:replace, replacer})
      when is_list(codepoints) and is_function(replacer, 1) do
    case encode_substitute(codepoints, replacer) do
      {:ok, output} -> {:ok, output, []}
      error -> error
    end
  end

  def encode_from_utf8(input) when is_binary(input), do: encode_utf8_all(input, 0, [])

  def decode_error_consumption(_kind, sequence)
      when is_binary(sequence) and byte_size(sequence) >= 2,
      do: 2

  def decode_error_consumption(_kind, _sequence), do: 1

  def decode_token(token) when is_binary(token) do
    with {:ok, coordinate} <- token_value(token) do
      case scalar_for_coordinate(coordinate) do
        nil -> {:error, {:unassigned_token, token}}
        scalar -> {:ok, scalar}
      end
    end
  end

  def decode_token(_token), do: {:error, {:invalid_argument, :token}}

  def decode_token_to_utf8(token) do
    case decode_token(token) do
      {:ok, scalar} -> {:ok, <<scalar::utf8>>}
      error -> error
    end
  end

  def encode_scalar(scalar) when is_integer(scalar) do
    cond do
      not valid_scalar?(scalar) ->
        {:error, {:invalid_unicode_scalar, scalar}}

      true ->
        case @encode do
          %{^scalar => bytes} -> {:ok, bytes_to_token(bytes)}
          _ -> {:error, {:unrepresentable_scalar, scalar}}
        end
    end
  end

  def encode_scalar(_scalar), do: {:error, {:invalid_argument, :scalar}}

  def encode_utf8_to_token(<<scalar::utf8>>), do: encode_scalar(scalar)

  def encode_utf8_to_token(input) when is_binary(input) do
    case :unicode.characters_to_list(input, :utf8) do
      [scalar] ->
        encode_scalar(scalar)

      scalars when is_list(scalars) ->
        {:error, {:invalid_scalar_count, length(scalars)}}

      {:error, _converted, <<byte, _rest::binary>> = rest} ->
        {:error, {:invalid_utf8, :invalid_sequence, byte_size(input) - byte_size(rest), <<byte>>}}

      {:incomplete, _converted, rest} ->
        {:error, {:invalid_utf8, :incomplete_sequence, byte_size(input) - byte_size(rest), rest}}
    end
  end

  def encode_utf8_to_token(_input), do: {:error, {:invalid_argument, :utf8}}

  defp decode_all(<<>>, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_all(<<lead, trail, rest::binary>>, offset, acc) do
    case scalar_for_bytes(lead, trail) do
      nil -> {:error, :invalid_sequence, offset, <<lead, trail>>}
      scalar -> decode_all(rest, offset + 2, [scalar | acc])
    end
  end

  defp decode_all(<<lead>>, offset, _acc) do
    kind = if valid_lead?(lead), do: :incomplete_sequence, else: :invalid_sequence
    {:error, kind, offset, <<lead>>}
  end

  defp decode_discard_all(<<>>, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_all(<<lead, trail, rest::binary>>, acc) do
    case scalar_for_bytes(lead, trail) do
      nil -> decode_discard_all(rest, acc)
      scalar -> decode_discard_all(rest, [scalar | acc])
    end
  end

  defp decode_discard_all(<<_pending>>, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_utf8_all(<<>>, _offset, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp decode_utf8_all(<<lead, trail, rest::binary>>, offset, acc) do
    case scalar_for_bytes(lead, trail) do
      nil -> {:error, :invalid_sequence, offset, <<lead, trail>>}
      scalar -> decode_utf8_all(rest, offset + 2, [<<scalar::utf8>> | acc])
    end
  end

  defp decode_utf8_all(<<lead>>, offset, _acc) do
    kind = if valid_lead?(lead), do: :incomplete_sequence, else: :invalid_sequence
    {:error, kind, offset, <<lead>>}
  end

  defp encode_all([], acc), do: {:ok, finish_bytes(acc)}

  defp encode_all([scalar | rest], acc) do
    case @encode do
      %{^scalar => bytes} -> encode_all(rest, [bytes | acc])
      _ -> {:error, :unrepresentable_character, scalar}
    end
  end

  defp encode_discard_all([], acc), do: {:ok, finish_bytes(acc)}

  defp encode_discard_all([scalar | rest], acc) do
    case @encode do
      %{^scalar => bytes} -> encode_discard_all(rest, [bytes | acc])
      _ -> encode_discard_all(rest, acc)
    end
  end

  defp encode_substitute_all([], _replacer, acc), do: {:ok, finish_bytes(acc)}

  defp encode_substitute_all([scalar | rest], replacer, acc) do
    case @encode do
      %{^scalar => bytes} ->
        encode_substitute_all(rest, replacer, [bytes | acc])

      _ ->
        case encode(replacer.(scalar)) do
          {:ok, replacement} -> encode_substitute_all(rest, replacer, [replacement | acc])
          error -> error
        end
    end
  end

  defp encode_utf8_all(<<>>, _offset, acc), do: {:ok, finish_bytes(acc)}

  defp encode_utf8_all(<<scalar::utf8, rest::binary>> = input, offset, acc) do
    case @encode do
      %{^scalar => bytes} ->
        consumed = byte_size(input) - byte_size(rest)
        encode_utf8_all(rest, offset + consumed, [bytes | acc])

      _ ->
        {:error, :unrepresentable_character, scalar}
    end
  end

  defp encode_utf8_all(input, offset, _acc),
    do: Iconvex.Specs.CodecSupport.malformed_utf8(input, offset)

  defp scalar_for_bytes(lead, trail)
       when lead in 0x30..0x7C and trail in 0x21..0x7E,
       do: elem(@decode, (lead - 0x30) * 94 + trail - 0x21)

  defp scalar_for_bytes(_lead, _trail), do: nil

  defp scalar_for_coordinate(coordinate) do
    row = div(coordinate, 100)
    cell = rem(coordinate, 100)

    if row in 16..92 and cell in 1..94,
      do: elem(@decode, (row - 16) * 94 + cell - 1),
      else: nil
  end

  defp bytes_to_token(<<lead, trail>>) do
    coordinate = (lead - 0x20) * 100 + trail - 0x20
    decimal_token(coordinate)
  end

  defp token_value(token) when byte_size(token) != 4,
    do: {:error, {:invalid_token_length, byte_size(token)}}

  defp token_value(<<a, b, c, d>>) do
    cond do
      a not in ?0..?9 -> {:error, {:invalid_token_digit, 0, <<a>>}}
      b not in ?0..?9 -> {:error, {:invalid_token_digit, 1, <<b>>}}
      c not in ?0..?9 -> {:error, {:invalid_token_digit, 2, <<c>>}}
      d not in ?0..?9 -> {:error, {:invalid_token_digit, 3, <<d>>}}
      true -> {:ok, (a - ?0) * 1_000 + (b - ?0) * 100 + (c - ?0) * 10 + d - ?0}
    end
  end

  defp decimal_token(value) do
    <<div(value, 1_000) + ?0, div(rem(value, 1_000), 100) + ?0, div(rem(value, 100), 10) + ?0,
      rem(value, 10) + ?0>>
  end

  defp valid_lead?(lead), do: lead in 0x30..0x7C
  defp valid_scalar?(scalar), do: scalar in 0..0x10FFFF and scalar not in 0xD800..0xDFFF
  defp finish_bytes(acc), do: acc |> :lists.reverse() |> IO.iodata_to_binary()
end

defmodule Iconvex.Specs.Unihan17KGB3RowCellDecimalToken do
  @moduledoc "Unicode 17 provisional kGB3 single row/cell decimal-token mapping."
  @behaviour Iconvex.Specs.PropertyTokenMapping
  alias Iconvex.Specs.UnihanGB3RowCell.Engine

  def mapping_name, do: Engine.property_metadata().mapping_name
  def metadata, do: Engine.property_metadata()
  def decode_token(token), do: Engine.decode_token(token)
  def decode_token_to_utf8(token), do: Engine.decode_token_to_utf8(token)
  def encode_scalar(scalar), do: Engine.encode_scalar(scalar)
  def encode_utf8_to_token(input), do: Engine.encode_utf8_to_token(input)
end

defmodule Iconvex.Specs.Unihan17KGB3RowCellGL do
  @moduledoc "Unicode 17 provisional kGB3 raw two-byte GL row/cell profile."
  use Iconvex.Codec
  alias Iconvex.Specs.UnihanGB3RowCell.Engine

  @impl true
  def canonical_name, do: "UNIHAN-17.0.0-KGB3-ROW-CELL-GL"

  @impl true
  def codec_id, do: :unihan_17_0_0_kgb3_row_cell_gl

  @impl true
  def decode(input), do: Engine.decode(input)

  @impl true
  def decode_discard(input), do: Engine.decode_discard(input)

  @impl true
  def decode_chunk(input, final?), do: Engine.decode_chunk(input, final?)

  @impl true
  def decode_to_utf8(input), do: Engine.decode_to_utf8(input)

  @impl true
  def decode_error_consumption(kind, sequence),
    do: Engine.decode_error_consumption(kind, sequence)

  @impl true
  def encode(codepoints), do: Engine.encode(codepoints)

  @impl true
  def encode_discard(codepoints), do: Engine.encode_discard(codepoints)

  @impl true
  def encode_substitute(codepoints, replacer), do: Engine.encode_substitute(codepoints, replacer)

  @impl true
  def encode_chunk(codepoints, final?, policy),
    do: Engine.encode_chunk(codepoints, final?, policy)

  @impl true
  def encode_from_utf8(input), do: Engine.encode_from_utf8(input)

  def metadata, do: Engine.codec_metadata()
end

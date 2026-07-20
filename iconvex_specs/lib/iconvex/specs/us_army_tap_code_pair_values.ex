require Iconvex.Specs.USArmyTapCodePairValues.SourceAsset

defmodule Iconvex.Specs.USArmyTapCodePairValues.DecodeBatchCompiler do
  @moduledoc false

  defmacro define(pair_count) when is_integer(pair_count) do
    pairs =
      for index <- 1..pair_count do
        {Macro.var(:"row#{index}", nil), Macro.var(:"column#{index}", nil)}
      end

    pattern = Enum.flat_map(pairs, fn {row, column} -> [row, column] end)
    rest = Macro.var(:rest, nil)
    offset = Macro.var(:offset, nil)
    acc = Macro.var(:acc, nil)

    guard =
      Enum.reduce(pairs, true, fn {row, column}, checks ->
        quote do
          unquote(checks) and unquote(row) >= 1 and unquote(row) <= 5 and
            unquote(column) >= 1 and unquote(column) <= 5
        end
      end)

    decoded =
      Enum.map(pairs, fn {row, column} ->
        quote do
          elem(@decode, (unquote(row) - 1) * 5 + unquote(column) - 1)
        end
      end)

    quote do
      defp decode_utf8_all(
             <<unquote_splicing(pattern), unquote(rest)::binary>>,
             unquote(offset),
             unquote(acc)
           )
           when unquote(guard) do
        decoded = <<unquote_splicing(decoded)>>

        decode_utf8_all(
          unquote(rest),
          unquote(offset) + unquote(pair_count * 2),
          [decoded | unquote(acc)]
        )
      end
    end
  end
end

defmodule Iconvex.Specs.USArmyTapCodePairValues do
  @moduledoc """
  U.S. Army GTA 31-70-001 Prisoner of War Tap Code word matrix.

  This is a source-qualified project transport for the Army card's abstract
  tap-count pairs. Each letter is serialized as two numeric octets in `1..5`:
  row count first, column count second. The fixed matrix contains uppercase
  `A` through `Z` except `K`; encoding `K` emits the `C` pair and decoding that
  pair canonically returns `C`.

  The Army's physical timing, number mode, word pauses, hand language, and
  alternate or scrambled matrices are outside this codec.
  """

  use Iconvex.Codec

  alias Iconvex.Specs.USArmyTapCodePairValues.SourceAsset
  require Iconvex.Specs.USArmyTapCodePairValues.DecodeBatchCompiler

  @rows SourceAsset.rows()
  @decode @rows |> Enum.map(& &1.unicode) |> List.to_tuple()
  @encode @rows
          |> Map.new(fn row -> {row.unicode, <<row.row, row.column>>} end)
          |> Map.put(?K, <<1, 3>>)
  @encode_ascii for codepoint <- ?A..?Z, do: Map.fetch!(@encode, codepoint)
  @encode_ascii List.to_tuple(@encode_ascii)
  @invalid_ascii_patterns for(byte <- 0..0xFF, byte not in ?A..?Z, do: <<byte>>)
  @invalid_ascii_pattern_key {__MODULE__, :invalid_ascii_pattern}
  @on_load :load_invalid_ascii_pattern

  defp load_invalid_ascii_pattern do
    :persistent_term.put(
      @invalid_ascii_pattern_key,
      :binary.compile_pattern(@invalid_ascii_patterns)
    )

    :ok
  end

  @impl true
  def canonical_name, do: "US-ARMY-GTA-31-70-001-TAP-CODE-PAIR-VALUES"

  @impl true
  def aliases do
    [
      "US-ARMY-POW-TAP-CODE-PAIR-VALUES",
      "GTA-31-70-001-TAP-CODE-PAIR-VALUES",
      "POW-TAP-CODE-5X5-PAIR-VALUES"
    ]
  end

  @impl true
  def codec_id, do: :us_army_gta_31_70_001_tap_code_pair_values

  @impl true
  def decode(input) when is_binary(input), do: decode_all(input, 0, [])

  @impl true
  def decode_discard(input) when is_binary(input), do: decode_discard_all(input, [])

  @impl true
  def encode(codepoints) when is_list(codepoints), do: encode_all(codepoints, [])

  @impl true
  def encode_discard(codepoints) when is_list(codepoints),
    do: encode_discard_all(codepoints, [])

  @impl true
  def encode_substitute(codepoints, replacer)
      when is_list(codepoints) and is_function(replacer, 1) do
    Iconvex.Specs.CodecSupport.encode_substitute_each(codepoints, &encode/1, replacer)
  end

  @impl true
  def decode_to_utf8(input) when is_binary(input), do: decode_utf8_all(input, 0, [])

  @impl true
  def encode_from_utf8(input) when is_binary(input) do
    case :binary.match(input, invalid_ascii_pattern()) do
      :nomatch ->
        {:ok, valid_ascii_to_pairs(input)}

      {invalid_offset, 1} ->
        <<_valid::binary-size(invalid_offset), invalid::binary>> = input

        case invalid do
          <<codepoint::utf8, _rest::binary>> ->
            {:error, :unrepresentable_character, codepoint}

          _malformed ->
            Iconvex.Specs.CodecSupport.malformed_utf8(invalid, invalid_offset)
        end
    end
  end

  @impl true
  def decode_error_consumption(:invalid_sequence, sequence) when byte_size(sequence) >= 2,
    do: 2

  def decode_error_consumption(:incomplete_sequence, sequence) when byte_size(sequence) >= 1,
    do: 1

  def decode_error_consumption(_kind, _sequence), do: 1

  @impl true
  def decode_chunk(input, final?) when is_binary(input) and is_boolean(final?) do
    stable_size = byte_size(input) - rem(byte_size(input), 2)
    <<stable::binary-size(stable_size), pending::binary>> = input

    case decode(stable) do
      {:ok, _codepoints} when final? and pending != <<>> ->
        {:error, :incomplete_sequence, stable_size, pending}

      {:ok, codepoints} ->
        {:ok, codepoints, pending}

      error ->
        error
    end
  end

  @impl true
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

  defp decode_all(<<>>, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_all(<<row, column, rest::binary>>, offset, acc)
       when row >= 1 and row <= 5 and column >= 1 and column <= 5 do
    codepoint = elem(@decode, (row - 1) * 5 + column - 1)
    decode_all(rest, offset + 2, [codepoint | acc])
  end

  defp decode_all(<<row, column, _rest::binary>>, offset, _acc),
    do: {:error, :invalid_sequence, offset, <<row, column>>}

  defp decode_all(pending, offset, _acc),
    do: {:error, :incomplete_sequence, offset, pending}

  defp decode_discard_all(<<>>, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_all(<<row, column, rest::binary>>, acc)
       when row >= 1 and row <= 5 and column >= 1 and column <= 5 do
    codepoint = elem(@decode, (row - 1) * 5 + column - 1)
    decode_discard_all(rest, [codepoint | acc])
  end

  defp decode_discard_all(<<_row, _column, rest::binary>>, acc),
    do: decode_discard_all(rest, acc)

  defp decode_discard_all(<<_pending>>, acc), do: {:ok, :lists.reverse(acc)}

  Iconvex.Specs.USArmyTapCodePairValues.DecodeBatchCompiler.define(32)

  defp decode_utf8_all(<<>>, _offset, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp decode_utf8_all(<<row, column, rest::binary>>, offset, acc)
       when row >= 1 and row <= 5 and column >= 1 and column <= 5 do
    codepoint = elem(@decode, (row - 1) * 5 + column - 1)
    decode_utf8_all(rest, offset + 2, [<<codepoint>> | acc])
  end

  defp decode_utf8_all(<<row, column, _rest::binary>>, offset, _acc),
    do: {:error, :invalid_sequence, offset, <<row, column>>}

  defp decode_utf8_all(pending, offset, _acc),
    do: {:error, :incomplete_sequence, offset, pending}

  defp encode_all([], acc), do: {:ok, finish_pairs(acc)}

  defp encode_all([codepoint | rest], acc) do
    case @encode do
      %{^codepoint => pair} -> encode_all(rest, [pair | acc])
      _ -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_discard_all([], acc), do: {:ok, finish_pairs(acc)}

  defp encode_discard_all([codepoint | rest], acc) do
    case @encode do
      %{^codepoint => pair} -> encode_discard_all(rest, [pair | acc])
      _ -> encode_discard_all(rest, acc)
    end
  end

  defp valid_ascii_to_pairs(source) do
    for <<codepoint <- source>>, into: <<>> do
      elem(@encode_ascii, codepoint - ?A)
    end
  end

  defp invalid_ascii_pattern,
    do: :persistent_term.get(@invalid_ascii_pattern_key)

  defp finish_pairs(acc), do: acc |> :lists.reverse() |> IO.iodata_to_binary()
end

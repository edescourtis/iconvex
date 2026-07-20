defmodule Iconvex.Specs.TACE16AppendixD2010.SourceAsset do
  @moduledoc false

  def load!(mapping_path, expected_sha256, metadata_path) do
    csv = File.read!(mapping_path)
    verify_sha!(csv, expected_sha256)

    rows =
      case String.split(csv, "\n", trim: true) do
        ["tace,unicode_sequence,status,name" | lines] -> Enum.map(lines, &parse_row!/1)
        _ -> raise ArgumentError, "invalid TACE16 Appendix D mapping header"
      end

    units = Enum.map(rows, & &1.unit)

    unless length(rows) == 380 and units == Enum.sort(units) and
             length(units) == length(Enum.uniq(units)) do
      raise ArgumentError, "TACE16 Appendix D units are not unique, sorted, and complete"
    end

    unless Enum.count(rows, &(&1.status == :equivalent)) == 360 and
             Enum.count(rows, &(&1.status == :pua_identity)) == 20 do
      raise ArgumentError, "TACE16 Appendix D disposition counts differ"
    end

    metadata = File.read!(metadata_path)

    for pin <- [
          expected_sha256,
          "78c77c607892d8f70bda3bbd9ca01371ddf2fe5fc8f3ef0481975d59abf3435c",
          "pages 35-47"
        ] do
      unless String.contains?(metadata, pin),
        do: raise(ArgumentError, "TACE metadata pin missing")
    end

    decode = Map.new(rows, &{&1.unit, &1.unicode})
    decode_utf8 = Map.new(rows, &{&1.unit, List.to_string(&1.unicode)})

    encoders =
      Enum.reduce(rows, %{one: %{}, two: %{}, three: %{}, four: %{}}, fn row, acc ->
        key = List.to_tuple(row.unicode)
        field = Enum.at([:one, :two, :three, :four], tuple_size(key) - 1)
        update_in(acc[field], &Map.put_new(&1, key, row.unit))
      end)

    prefixes =
      Enum.reduce(rows, %{one: MapSet.new(), two: MapSet.new(), three: MapSet.new()}, fn row,
                                                                                         acc ->
        case row.unicode do
          [a, b, c, _d] ->
            %{
              acc
              | one: MapSet.put(acc.one, a),
                two: MapSet.put(acc.two, {a, b}),
                three: MapSet.put(acc.three, {a, b, c})
            }

          [a, b, _c] ->
            %{acc | one: MapSet.put(acc.one, a), two: MapSet.put(acc.two, {a, b})}

          [a, _b] ->
            %{acc | one: MapSet.put(acc.one, a)}

          [_a] ->
            acc
        end
      end)

    %{decode: decode, decode_utf8: decode_utf8, encoders: encoders, prefixes: prefixes}
  end

  defp parse_row!(row) do
    with [unit_hex, sequence_hex, status, name] <- String.split(row, ",", parts: 4),
         {unit, ""} <- Integer.parse(unit_hex, 16),
         true <- unit in 0..0xFFFF,
         unicode when length(unicode) in 1..4 <- parse_sequence(sequence_hex),
         disposition when disposition in [:equivalent, :pua_identity] <- String.to_atom(status),
         true <- disposition != :pua_identity or unicode == [unit] do
      %{unit: unit, unicode: unicode, status: disposition, name: name}
    else
      _ -> raise ArgumentError, "invalid TACE16 Appendix D row #{inspect(row)}"
    end
  end

  defp parse_sequence(sequence) do
    sequence
    |> String.split("+", trim: true)
    |> Enum.map(fn value ->
      case Integer.parse(value, 16) do
        {codepoint, ""} when codepoint in 0..0xD7FF or codepoint in 0xE000..0x10FFFF -> codepoint
        _ -> raise ArgumentError, "invalid Unicode scalar in TACE16 mapping"
      end
    end)
  end

  defp verify_sha!(bytes, expected) do
    actual = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
    unless actual == expected, do: raise(ArgumentError, "TACE16 mapping SHA-256 mismatch")
  end
end

defmodule Iconvex.Specs.TACE16AppendixD2010.Engine do
  @moduledoc false
  @chunk_units 4_096

  def decode(input, decode, endian, discard? \\ false)
      when is_binary(input) and endian in [:big, :little] do
    decode_loop(input, decode, endian, discard?, 0, [])
  end

  def decode_to_utf8(input, decode_utf8, endian) do
    decode_utf8_loop(input, decode_utf8, endian, 0, [], 0, [])
  end

  def decode_chunk(input, decode, endian, final?) do
    stable_size = byte_size(input) - rem(byte_size(input), 2)
    <<stable::binary-size(stable_size), pending::binary>> = input

    case decode(stable, decode, endian) do
      {:ok, _codepoints} when final? and pending != <<>> ->
        {:error, :incomplete_sequence, stable_size, pending}

      {:ok, codepoints} ->
        {:ok, codepoints, pending}

      error ->
        error
    end
  end

  def encode(codepoints, encoders, prefixes, endian, final?, policy)
      when is_list(codepoints) and endian in [:big, :little] do
    encode_loop(codepoints, encoders, prefixes, endian, final?, policy, [], 0, [])
  end

  def encode_from_utf8(input, encoders, prefixes, endian) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        finish_encode(encode(codepoints, encoders, prefixes, endian, true, :error))

      {:incomplete, converted, rest} ->
        utf8_error(converted, rest, input, :incomplete_sequence, encoders, prefixes, endian)

      {:error, converted, rest} ->
        utf8_error(converted, rest, input, :invalid_sequence, encoders, prefixes, endian)
    end
  end

  def encode_complete(codepoints, encoders, prefixes, endian, policy) do
    encode(codepoints, encoders, prefixes, endian, true, policy) |> finish_encode()
  end

  def decode_units(units, decode) when is_list(units) do
    Enum.reduce_while(Enum.with_index(units), {:ok, []}, fn {unit, offset}, {:ok, acc} ->
      case Map.fetch(decode, unit) do
        {:ok, sequence} -> {:cont, {:ok, :lists.reverse(sequence, acc)}}
        :error -> {:halt, {:error, :invalid_sequence, offset, [unit]}}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, :lists.reverse(acc)}
      error -> error
    end
  end

  def encode_units(codepoints, encoders, prefixes) do
    case encode_complete(codepoints, encoders, prefixes, :big, :error) do
      {:ok, binary} -> {:ok, for(<<unit::16-big <- binary>>, do: unit)}
      error -> error
    end
  end

  defp decode_loop(<<>>, _decode, _endian, _discard?, _offset, acc),
    do: {:ok, :lists.reverse(acc)}

  defp decode_loop(input, _decode, _endian, true, _offset, acc) when byte_size(input) < 2,
    do: {:ok, :lists.reverse(acc)}

  defp decode_loop(input, _decode, _endian, false, offset, _acc) when byte_size(input) < 2,
    do: {:error, :incomplete_sequence, offset, input}

  defp decode_loop(input, decode, endian, discard?, offset, acc) do
    {unit, raw, rest} = next_word(input, endian)

    case Map.fetch(decode, unit) do
      {:ok, sequence} ->
        decode_loop(rest, decode, endian, discard?, offset + 2, :lists.reverse(sequence, acc))

      :error when discard? ->
        decode_loop(rest, decode, endian, true, offset + 2, acc)

      :error ->
        {:error, :invalid_sequence, offset, raw}
    end
  end

  defp decode_utf8_loop(<<>>, _decode, _endian, _offset, acc, _count, chunks),
    do: {:ok, finish_iodata(acc, chunks)}

  defp decode_utf8_loop(input, _decode, _endian, offset, _acc, _count, _chunks)
       when byte_size(input) < 2,
       do: {:error, :incomplete_sequence, offset, input}

  defp decode_utf8_loop(input, decode, endian, offset, acc, count, chunks) do
    {unit, raw, rest} = next_word(input, endian)

    case Map.fetch(decode, unit) do
      {:ok, piece} ->
        {acc, count, chunks} = push(piece, acc, count, chunks)
        decode_utf8_loop(rest, decode, endian, offset + 2, acc, count, chunks)

      :error ->
        {:error, :invalid_sequence, offset, raw}
    end
  end

  defp encode_loop(codepoints, encoders, prefixes, endian, final?, policy, acc, count, chunks) do
    case next_token(codepoints, encoders, prefixes, final?) do
      :done ->
        {:ok, finish_iodata(acc, chunks), []}

      {:pending, pending} ->
        {:ok, finish_iodata(acc, chunks), pending}

      {:mapped, unit, rest} ->
        {acc, count, chunks} = push(word(unit, endian), acc, count, chunks)
        encode_loop(rest, encoders, prefixes, endian, final?, policy, acc, count, chunks)

      {:single, codepoint, rest} ->
        unrepresentable(
          codepoint,
          rest,
          encoders,
          prefixes,
          endian,
          final?,
          policy,
          acc,
          count,
          chunks
        )
    end
  end

  defp next_token([], _encoders, _prefixes, _final?), do: :done

  defp next_token([a, b, c, d | rest], encoders, _prefixes, _final?) do
    cond do
      unit = encoders.four[{a, b, c, d}] -> {:mapped, unit, rest}
      unit = encoders.three[{a, b, c}] -> {:mapped, unit, [d | rest]}
      unit = encoders.two[{a, b}] -> {:mapped, unit, [c, d | rest]}
      unit = encoders.one[{a}] -> {:mapped, unit, [b, c, d | rest]}
      true -> {:single, a, [b, c, d | rest]}
    end
  end

  defp next_token([a, b, c] = pending, encoders, prefixes, false) do
    if MapSet.member?(prefixes.three, {a, b, c}),
      do: {:pending, pending},
      else: next_three(a, b, c, encoders)
  end

  defp next_token([a, b, c], encoders, _prefixes, true), do: next_three(a, b, c, encoders)

  defp next_token([a, b] = pending, encoders, prefixes, false) do
    if MapSet.member?(prefixes.two, {a, b}),
      do: {:pending, pending},
      else: next_two(a, b, encoders)
  end

  defp next_token([a, b], encoders, _prefixes, true), do: next_two(a, b, encoders)

  defp next_token([a] = pending, encoders, prefixes, false) do
    if MapSet.member?(prefixes.one, a), do: {:pending, pending}, else: next_one(a, encoders)
  end

  defp next_token([a], encoders, _prefixes, true), do: next_one(a, encoders)

  defp next_three(a, b, c, encoders) do
    cond do
      unit = encoders.three[{a, b, c}] -> {:mapped, unit, []}
      unit = encoders.two[{a, b}] -> {:mapped, unit, [c]}
      unit = encoders.one[{a}] -> {:mapped, unit, [b, c]}
      true -> {:single, a, [b, c]}
    end
  end

  defp next_two(a, b, encoders) do
    cond do
      unit = encoders.two[{a, b}] -> {:mapped, unit, []}
      unit = encoders.one[{a}] -> {:mapped, unit, [b]}
      true -> {:single, a, [b]}
    end
  end

  defp next_one(a, encoders) do
    case encoders.one do
      %{{^a} => unit} -> {:mapped, unit, []}
      _ -> {:single, a, []}
    end
  end

  defp unrepresentable(
         codepoint,
         _rest,
         _encoders,
         _prefixes,
         _endian,
         _final?,
         :error,
         _acc,
         _count,
         _chunks
       ),
       do: {:error, :unrepresentable_character, codepoint}

  defp unrepresentable(
         _codepoint,
         rest,
         encoders,
         prefixes,
         endian,
         final?,
         :discard,
         acc,
         count,
         chunks
       ),
       do: encode_loop(rest, encoders, prefixes, endian, final?, :discard, acc, count, chunks)

  defp unrepresentable(
         codepoint,
         rest,
         encoders,
         prefixes,
         endian,
         final?,
         {:replace, replacer} = policy,
         acc,
         count,
         chunks
       ) do
    case encode_complete(replacer.(codepoint), encoders, prefixes, endian, :error) do
      {:ok, replacement} ->
        {acc, count, chunks} = push(replacement, acc, count, chunks)
        encode_loop(rest, encoders, prefixes, endian, final?, policy, acc, count, chunks)

      error ->
        error
    end
  end

  defp utf8_error(converted, rest, input, kind, encoders, prefixes, endian) do
    case encode_complete(converted, encoders, prefixes, endian, :error) do
      {:ok, _} -> {:decode_error, kind, byte_size(input) - byte_size(rest), rest}
      error -> error
    end
  end

  defp finish_encode({:ok, output, []}), do: {:ok, output}
  defp finish_encode(error), do: error

  defp next_word(<<unit::16-big, rest::binary>>, :big), do: {unit, <<unit::16-big>>, rest}

  defp next_word(<<unit::16-little, rest::binary>>, :little),
    do: {unit, <<unit::16-little>>, rest}

  defp word(unit, :big), do: <<unit::16-big>>
  defp word(unit, :little), do: <<unit::16-little>>

  defp push(piece, acc, count, chunks) when count == @chunk_units - 1 do
    chunk = [piece | acc] |> :lists.reverse() |> IO.iodata_to_binary()
    {[], 0, [chunk | chunks]}
  end

  defp push(piece, acc, count, chunks), do: {[piece | acc], count + 1, chunks}

  defp finish_iodata([], chunks), do: chunks |> :lists.reverse() |> IO.iodata_to_binary()

  defp finish_iodata(acc, chunks),
    do:
      [[acc |> :lists.reverse() |> IO.iodata_to_binary()] | chunks]
      |> :lists.reverse()
      |> IO.iodata_to_binary()
end

defmodule Iconvex.Specs.TACE16AppendixD2010 do
  @moduledoc "Logical 16-bit TACE16 mapping from the 2010 Tamil Virtual University Appendix D."

  alias Iconvex.Specs.TACE16AppendixD2010.{Engine, SourceAsset}
  @source_dir Path.expand("../../../priv/sources/tace16-2010", __DIR__)
  @mapping_path Path.join(@source_dir, "appendix_d.csv")
  @metadata_path Path.join(@source_dir, "SOURCE_METADATA.md")
  @external_resource @mapping_path
  @external_resource @metadata_path
  @mapping_sha256 "f48482c6dc89c70b5c04dc5314cbccbec810a11b9484eb9216db662b03928ebe"
  @data SourceAsset.load!(@mapping_path, @mapping_sha256, @metadata_path)

  def canonical_name, do: "TAMILVU-TACE16-APPENDIX-D-2010"
  def unit_bits, do: 16
  def assigned_count, do: 380
  def equivalent_count, do: 360
  def pua_identity_count, do: 20
  def mapping_sha256, do: @mapping_sha256
  def source_sha256, do: "78c77c607892d8f70bda3bbd9ca01371ddf2fe5fc8f3ef0481975d59abf3435c"

  def transport_codecs,
    do: [Iconvex.Specs.TACE16AppendixD2010BE, Iconvex.Specs.TACE16AppendixD2010LE]

  def decode_unit(unit) do
    case Map.fetch(@data.decode, unit) do
      {:ok, sequence} -> {:ok, sequence}
      :error -> :error
    end
  end

  def decode_units(units), do: Engine.decode_units(units, @data.decode)

  def encode_units(codepoints),
    do: Engine.encode_units(codepoints, @data.encoders, @data.prefixes)

  def __data__, do: @data
end

defmodule Iconvex.Specs.TACE16AppendixD2010.Transport do
  @moduledoc false

  defmacro __using__(options) do
    endian = Keyword.fetch!(options, :endian)
    canonical = Keyword.fetch!(options, :canonical)
    aliases = Keyword.fetch!(options, :aliases)
    codec_id = Keyword.fetch!(options, :codec_id)

    quote bind_quoted: [
            endian: endian,
            canonical: canonical,
            aliases: aliases,
            codec_id: codec_id
          ] do
      use Iconvex.Codec
      alias Iconvex.Specs.TACE16AppendixD2010, as: Profile
      alias Iconvex.Specs.TACE16AppendixD2010.Engine
      @data Profile.__data__()
      @endian endian
      @canonical canonical
      @aliases aliases
      @codec_id codec_id

      @impl true
      def canonical_name, do: @canonical
      @impl true
      def aliases, do: @aliases
      @impl true
      def codec_id, do: @codec_id
      def logical_profile, do: Profile
      def logical_unit_bits, do: 16
      def transport_word_bits, do: 16
      def mapping_sha256, do: Profile.mapping_sha256()
      def source_sha256, do: Profile.source_sha256()

      @impl true
      def decode(input), do: Engine.decode(input, @data.decode, @endian)
      @impl true
      def decode_discard(input), do: Engine.decode(input, @data.decode, @endian, true)
      @impl true
      def decode_to_utf8(input), do: Engine.decode_to_utf8(input, @data.decode_utf8, @endian)
      @impl true
      def decode_chunk(input, final?),
        do: Engine.decode_chunk(input, @data.decode, @endian, final?)

      @impl true
      def decode_error_consumption(_kind, sequence) when byte_size(sequence) >= 2, do: 2
      def decode_error_consumption(_kind, _sequence), do: 1

      @impl true
      def encode(codepoints),
        do: Engine.encode_complete(codepoints, @data.encoders, @data.prefixes, @endian, :error)

      @impl true
      def encode_discard(codepoints),
        do: Engine.encode_complete(codepoints, @data.encoders, @data.prefixes, @endian, :discard)

      @impl true
      def encode_substitute(codepoints, replacer),
        do:
          Engine.encode_complete(
            codepoints,
            @data.encoders,
            @data.prefixes,
            @endian,
            {:replace, replacer}
          )

      @impl true
      def encode_from_utf8(input),
        do: Engine.encode_from_utf8(input, @data.encoders, @data.prefixes, @endian)

      @impl true
      def encode_chunk(codepoints, final?, policy),
        do: Engine.encode(codepoints, @data.encoders, @data.prefixes, @endian, final?, policy)
    end
  end
end

defmodule Iconvex.Specs.TACE16AppendixD2010BE do
  @moduledoc "TACE16 Appendix D 2010 in explicit big-endian 16-bit words without BOM."
  use Iconvex.Specs.TACE16AppendixD2010.Transport,
    endian: :big,
    canonical: "TAMILVU-TACE16-APPENDIX-D-2010-16BE",
    aliases: ["TACE16-APPENDIX-D-2010-BE"],
    codec_id: :tamilvu_tace16_appendix_d_2010_16be
end

defmodule Iconvex.Specs.TACE16AppendixD2010LE do
  @moduledoc "TACE16 Appendix D 2010 in explicit little-endian 16-bit words without BOM."
  use Iconvex.Specs.TACE16AppendixD2010.Transport,
    endian: :little,
    canonical: "TAMILVU-TACE16-APPENDIX-D-2010-16LE",
    aliases: ["TACE16-APPENDIX-D-2010-LE"],
    codec_id: :tamilvu_tace16_appendix_d_2010_16le
end

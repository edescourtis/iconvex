defmodule Iconvex.Specs.CDC612DisplayCode do
  @moduledoc false

  @source_path Path.expand(
                 "../../../priv/sources/cdc-display-code/60435600L_NOS_Version_1_Operators_Guide_May1980.pdf",
                 __DIR__
               )
  @external_resource @source_path
  @chunk_characters 4_096

  @encode64 for(
              codepoint <- 0x00..0x1F,
              do: <<0o76, codepoint + 0o40>>
            ) ++
              [
                <<0o55>>,
                <<0o66>>,
                <<0o64>>,
                <<0o60>>,
                <<0o53>>,
                <<0o63>>,
                <<0o67>>,
                <<0o70>>,
                <<0o51>>,
                <<0o52>>,
                <<0o47>>,
                <<0o45>>,
                <<0o56>>,
                <<0o46>>,
                <<0o57>>,
                <<0o50>>
              ] ++
              for(unit <- 0o33..0o44, do: <<unit>>) ++
              [
                <<0o74, 0o04>>,
                <<0o77>>,
                <<0o72>>,
                <<0o54>>,
                <<0o73>>,
                <<0o71>>,
                <<0o74, 0o01>>
              ] ++
              for(unit <- 0o01..0o32, do: <<unit>>) ++
              [
                <<0o61>>,
                <<0o75>>,
                <<0o62>>,
                <<0o74, 0o02>>,
                <<0o65>>,
                <<0o74, 0o07>>
              ] ++
              for(unit <- 0o01..0o32, do: <<0o76, unit>>) ++
              [
                <<0o76, 0o33>>,
                <<0o76, 0o34>>,
                <<0o76, 0o35>>,
                <<0o76, 0o36>>,
                <<0o76, 0o37>>
              ]

  @encode64_tuple List.to_tuple(@encode64)
  @encode63_tuple @encode64
                  |> List.replace_at(?%, nil)
                  |> List.replace_at(?:, <<0o63>>)
                  |> List.to_tuple()

  @direct64 [?:] ++
              Enum.to_list(?A..?Z) ++
              Enum.to_list(?0..?9) ++
              [?+, ?-, ?*, ?/, ?(, ?), ?$, ?=, 0x20, ?,, ?.] ++
              [?#, ?[, ?], ?%, ?", ?_, ?!, ?&, ?', ??, ?<, ?>, :escape74, ?\\, :escape76, ?;]

  @direct63 @direct64 |> List.replace_at(0o00, nil) |> List.replace_at(0o63, ?:)
  @direct64_tuple List.to_tuple(@direct64)
  @direct63_tuple List.to_tuple(@direct63)

  def source_pages, do: [165, 167, 168, 169, 170, 171]
  def printed_source_pages, do: ["A-1", "A-3", "A-4", "A-5", "A-6", "A-7"]

  def source_url,
    do:
      "https://bitsavers.org/pdf/cdc/cyber/nos/60435600L_NOS_Version_1_Operators_Guide_May1980.pdf"

  def decode(input, set) when is_binary(input),
    do: decode_all(input, direct_table(set), 0, [])

  def decode_discard(input, set) when is_binary(input),
    do: decode_discard_all(input, direct_table(set), [])

  def encode(codepoints, set) when is_list(codepoints),
    do: encode_all(codepoints, encode_table(set), [])

  def encode_discard(codepoints, set) when is_list(codepoints),
    do: encode_discard_all(codepoints, encode_table(set), [])

  def decode_to_utf8(input, set) when is_binary(input),
    do: decode_utf8_all(input, direct_table(set), 0, [], 0, [])

  def encode_from_utf8(input, set) when is_binary(input) do
    Iconvex.Specs.CodecSupport.encode_utf8(
      input,
      &encode_utf8_all(&1, encode_table(set), [], 0, []),
      &encode(&1, set)
    )
  end

  defp direct_table(:set63), do: @direct63_tuple
  defp direct_table(:set64), do: @direct64_tuple
  defp encode_table(:set63), do: @encode63_tuple
  defp encode_table(:set64), do: @encode64_tuple

  defp decode_all(<<>>, _table, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_all(<<unit, _rest::binary>>, _table, offset, _acc) when unit >= 64,
    do: {:error, :invalid_sequence, offset, <<unit>>}

  defp decode_all(<<prefix>>, _table, offset, _acc) when prefix in [0o74, 0o76],
    do: {:error, :incomplete_sequence, offset, <<prefix>>}

  defp decode_all(<<prefix, unit, rest::binary>>, table, offset, acc)
       when prefix in [0o74, 0o76] do
    case decode_pair(prefix, unit) do
      {:ok, codepoint} -> decode_all(rest, table, offset + 2, [codepoint | acc])
      :error -> {:error, :invalid_sequence, offset, <<prefix, unit>>}
    end
  end

  defp decode_all(<<unit, rest::binary>>, table, offset, acc) do
    case elem(table, unit) do
      codepoint when is_integer(codepoint) ->
        decode_all(rest, table, offset + 1, [codepoint | acc])

      _ ->
        {:error, :invalid_sequence, offset, <<unit>>}
    end
  end

  defp decode_discard_all(<<>>, _table, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_all(<<prefix>>, _table, acc) when prefix in [0o74, 0o76],
    do: {:ok, :lists.reverse(acc)}

  defp decode_discard_all(<<prefix, unit, rest::binary>>, table, acc)
       when prefix in [0o74, 0o76] do
    case decode_pair(prefix, unit) do
      {:ok, codepoint} -> decode_discard_all(rest, table, [codepoint | acc])
      :error -> decode_discard_all(rest, table, acc)
    end
  end

  defp decode_discard_all(<<unit, rest::binary>>, table, acc) when unit < 64 do
    case elem(table, unit) do
      codepoint when is_integer(codepoint) -> decode_discard_all(rest, table, [codepoint | acc])
      _ -> decode_discard_all(rest, table, acc)
    end
  end

  defp decode_discard_all(<<_unit, rest::binary>>, table, acc),
    do: decode_discard_all(rest, table, acc)

  defp decode_pair(0o74, 0o01), do: {:ok, ?@}
  defp decode_pair(0o74, 0o02), do: {:ok, ?^}
  defp decode_pair(0o74, 0o04), do: {:ok, ?:}
  defp decode_pair(0o74, 0o07), do: {:ok, ?`}
  defp decode_pair(0o76, unit) when unit in 0o01..0o32, do: {:ok, ?a + unit - 1}
  defp decode_pair(0o76, unit) when unit in 0o33..0o36, do: {:ok, ?{ + unit - 0o33}
  defp decode_pair(0o76, 0o37), do: {:ok, 0x7F}
  defp decode_pair(0o76, unit) when unit in 0o40..0o77, do: {:ok, unit - 0o40}
  defp decode_pair(_prefix, _unit), do: :error

  defp encode_all([], _table, acc), do: {:ok, finish_iodata(acc, [])}

  defp encode_all([codepoint | rest], table, acc)
       when codepoint >= 0 and codepoint < tuple_size(table) do
    case elem(table, codepoint) do
      nil -> {:error, :unrepresentable_character, codepoint}
      units -> encode_all(rest, table, [units | acc])
    end
  end

  defp encode_all([codepoint | _rest], _table, _acc),
    do: {:error, :unrepresentable_character, codepoint}

  defp encode_discard_all([], _table, acc), do: {:ok, finish_iodata(acc, [])}

  defp encode_discard_all([codepoint | rest], table, acc)
       when codepoint >= 0 and codepoint < tuple_size(table) do
    case elem(table, codepoint) do
      nil -> encode_discard_all(rest, table, acc)
      units -> encode_discard_all(rest, table, [units | acc])
    end
  end

  defp encode_discard_all([_codepoint | rest], table, acc),
    do: encode_discard_all(rest, table, acc)

  defp decode_utf8_all(<<>>, _table, _offset, acc, _count, chunks),
    do: {:ok, finish_iodata(acc, chunks)}

  defp decode_utf8_all(<<unit, _rest::binary>>, _table, offset, _acc, _count, _chunks)
       when unit >= 64,
       do: {:error, :invalid_sequence, offset, <<unit>>}

  defp decode_utf8_all(<<prefix>>, _table, offset, _acc, _count, _chunks)
       when prefix in [0o74, 0o76],
       do: {:error, :incomplete_sequence, offset, <<prefix>>}

  defp decode_utf8_all(<<prefix, unit, rest::binary>>, table, offset, acc, count, chunks)
       when prefix in [0o74, 0o76] do
    case decode_pair(prefix, unit) do
      {:ok, codepoint} ->
        decode_utf8_unit(rest, table, offset + 2, codepoint, acc, count, chunks)

      :error ->
        {:error, :invalid_sequence, offset, <<prefix, unit>>}
    end
  end

  defp decode_utf8_all(<<unit, rest::binary>>, table, offset, acc, count, chunks) do
    case elem(table, unit) do
      codepoint when is_integer(codepoint) ->
        decode_utf8_unit(rest, table, offset + 1, codepoint, acc, count, chunks)

      _ ->
        {:error, :invalid_sequence, offset, <<unit>>}
    end
  end

  defp decode_utf8_unit(rest, table, offset, codepoint, acc, count, chunks) do
    next_acc = [codepoint | acc]

    if count == @chunk_characters - 1 do
      chunk = next_acc |> :lists.reverse() |> :erlang.list_to_binary()
      decode_utf8_all(rest, table, offset, [], 0, [chunk | chunks])
    else
      decode_utf8_all(rest, table, offset, next_acc, count + 1, chunks)
    end
  end

  defp encode_utf8_all(<<>>, _table, acc, _count, chunks),
    do: {:ok, finish_iodata(acc, chunks)}

  defp encode_utf8_all(<<codepoint, rest::binary>>, table, acc, count, chunks)
       when codepoint < 0x80 do
    case elem(table, codepoint) do
      nil -> {:error, :unrepresentable_character, codepoint}
      units -> encode_utf8_unit(rest, table, units, acc, count, chunks)
    end
  end

  defp encode_utf8_all(<<codepoint::utf8, _rest::binary>>, _table, _acc, _count, _chunks),
    do: {:error, :unrepresentable_character, codepoint}

  defp encode_utf8_unit(rest, table, units, acc, count, chunks) do
    next_acc = [units | acc]

    if count == @chunk_characters - 1 do
      chunk = next_acc |> :lists.reverse() |> IO.iodata_to_binary()
      encode_utf8_all(rest, table, [], 0, [chunk | chunks])
    else
      encode_utf8_all(rest, table, next_acc, count + 1, chunks)
    end
  end

  defp finish_iodata([], chunks),
    do: chunks |> :lists.reverse() |> IO.iodata_to_binary()

  defp finish_iodata(acc, chunks) do
    chunk = acc |> :lists.reverse() |> IO.iodata_to_binary()
    [chunk | chunks] |> :lists.reverse() |> IO.iodata_to_binary()
  end
end

defmodule Iconvex.Specs.CDC612DisplayCode.Profile do
  @moduledoc false

  defmacro __using__(options) do
    set = Keyword.fetch!(options, :set)
    canonical = Keyword.fetch!(options, :canonical)
    aliases = Keyword.fetch!(options, :aliases)
    codec_id = Keyword.fetch!(options, :codec_id)

    quote do
      use Iconvex.Codec
      alias Iconvex.Specs.CDC612DisplayCode, as: Engine

      @impl true
      def canonical_name, do: unquote(canonical)

      @impl true
      def aliases, do: unquote(aliases)

      @impl true
      def codec_id, do: unquote(codec_id)

      def unit_bits, do: 6
      def variable_units_per_character, do: 1..2
      def source_pages, do: Engine.source_pages()
      def printed_source_pages, do: Engine.printed_source_pages()
      def source_url, do: Engine.source_url()

      @impl true
      def decode(input), do: Engine.decode(input, unquote(set))

      @impl true
      def decode_discard(input), do: Engine.decode_discard(input, unquote(set))

      @impl true
      def encode(codepoints), do: Engine.encode(codepoints, unquote(set))

      @impl true
      def encode_discard(codepoints), do: Engine.encode_discard(codepoints, unquote(set))

      @impl true
      def encode_substitute(codepoints, replacer),
        do:
          Iconvex.Specs.CodecSupport.encode_substitute_each(
            codepoints,
            &encode/1,
            replacer
          )

      @impl true
      def decode_to_utf8(input), do: Engine.decode_to_utf8(input, unquote(set))

      @impl true
      def encode_from_utf8(input), do: Engine.encode_from_utf8(input, unquote(set))
    end
  end
end

defmodule Iconvex.Specs.CDC612DisplayCode64 do
  @moduledoc "CDC NOS 6/12 Display Code using the 64-character colon/percent rules."

  use Iconvex.Specs.CDC612DisplayCode.Profile,
    set: :set64,
    canonical: "CDC-6-12-DISPLAY-CODE-64",
    aliases: [
      "CDC-6-12-DISPLAY-CODE",
      "CDC612-DISPLAY-CODE",
      "CDC-6-12",
      "NOS-6-12-DISPLAY-CODE",
      "NOS-6-12-CODE"
    ],
    codec_id: :cdc_6_12_display_code_64
end

defmodule Iconvex.Specs.CDC612DisplayCode63 do
  @moduledoc "CDC NOS 6/12 Display Code using the 63-character colon/percent anomaly."

  use Iconvex.Specs.CDC612DisplayCode.Profile,
    set: :set63,
    canonical: "CDC-6-12-DISPLAY-CODE-63",
    aliases: ["CDC612-DISPLAY-CODE-63", "NOS-6-12-DISPLAY-CODE-63", "NOS-6-12-CODE-63"],
    codec_id: :cdc_6_12_display_code_63
end

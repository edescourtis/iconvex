defmodule Iconvex.Specs.IBMPCMixed do
  @moduledoc false

  def decode(input, single_id, double_id, discard? \\ false) when is_binary(input) do
    tables = tables(single_id, double_id)
    decode_all(input, tables, discard?, 0, [])
  end

  def encode(codepoints, single_id, double_id, discard? \\ false) when is_list(codepoints) do
    tables = tables(single_id, double_id)
    encode_all(codepoints, tables, discard?, [])
  end

  def encode_substitute(codepoints, single_id, double_id, replacer)
      when is_list(codepoints) and is_function(replacer, 1) do
    encode_substitute_all(codepoints, [], false, tables(single_id, double_id), [], replacer)
  end

  def decode_to_utf8(input, single_id, double_id) do
    case decode(input, single_id, double_id) do
      {:ok, codepoints} -> {:ok, List.to_string(codepoints)}
      error -> error
    end
  end

  def encode_from_utf8(input, single_id, double_id) do
    Iconvex.Specs.CodecSupport.encode_utf8(
      input,
      &encode(&1, single_id, double_id)
    )
  end

  defp decode_all(<<>>, _tables, _discard?, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_all(<<byte, rest::binary>> = input, tables, discard?, offset, acc) do
    case elem(tables.single.one, byte) do
      tuple when is_tuple(tuple) ->
        decode_all(rest, tables, discard?, offset + 1, prepend(tuple, acc))

      nil when elem(tables.leads, byte) and rest == <<>> and discard? ->
        {:ok, :lists.reverse(acc)}

      nil when elem(tables.leads, byte) and rest == <<>> ->
        {:error, :incomplete_sequence, offset, input}

      nil when elem(tables.leads, byte) ->
        <<trail, remaining::binary>> = rest
        source = <<byte, trail>>

        case Map.get(tables.double.many, source) do
          tuple when is_tuple(tuple) ->
            decode_all(remaining, tables, discard?, offset + 2, prepend(tuple, acc))

          nil when discard? ->
            decode_all(rest, tables, true, offset + 1, acc)

          nil ->
            {:error, :invalid_sequence, offset, source}
        end

      nil when discard? ->
        decode_all(rest, tables, true, offset + 1, acc)

      nil ->
        {:error, :invalid_sequence, offset, <<byte>>}
    end
  end

  defp encode_all([], _tables, _discard?, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_all([codepoint | rest], tables, discard?, acc) do
    key = {codepoint}

    case Map.get(tables.single.encode, key) || Map.get(tables.double.encode, key) do
      source when is_binary(source) -> encode_all(rest, tables, discard?, [source | acc])
      nil when discard? -> encode_all(rest, tables, true, acc)
      nil -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_substitute_all([], resume, true, tables, acc, replacer),
    do: encode_substitute_all(resume, [], false, tables, acc, replacer)

  defp encode_substitute_all([], [], false, _tables, acc, _replacer),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute_all(
         [codepoint | rest],
         resume,
         replacement?,
         tables,
         acc,
         replacer
       ) do
    key = {codepoint}

    case Map.get(tables.single.encode, key) || Map.get(tables.double.encode, key) do
      source when is_binary(source) ->
        encode_substitute_all(rest, resume, replacement?, tables, [source | acc], replacer)

      nil when replacement? ->
        {:error, :unrepresentable_character, codepoint}

      nil ->
        encode_substitute_all(replacer.(codepoint), rest, true, tables, acc, replacer)
    end
  end

  defp tables(single_id, double_id) do
    key = {__MODULE__, single_id, double_id}

    case :persistent_term.get(key, nil) do
      nil ->
        single = Iconvex.Tables.fetch!(single_id)
        double = Iconvex.Tables.fetch!(double_id)

        leads =
          double.many
          |> Map.keys()
          |> Enum.reduce(:erlang.make_tuple(256, false), fn <<lead, _trail>>, acc ->
            put_elem(acc, lead, true)
          end)

        tables = %{single: single, double: double, leads: leads}
        :persistent_term.put(key, tables)
        tables

      tables ->
        tables
    end
  end

  defp prepend(tuple, acc), do: tuple |> Tuple.to_list() |> Enum.reverse(acc)
end

defmodule Iconvex.Specs.IBM934 do
  @moduledoc "IBM CCSID 934: Korean PC mixed data (CP891 SBCS plus CP926 DBCS)."
  use Iconvex.Codec
  alias Iconvex.Specs.IBMPCMixed, as: Engine

  def canonical_name, do: "IBM-934"
  def aliases, do: ["IBM934", "CP934", "CCSID934"]
  def codec_id, do: :ibm_934
  def decode(input), do: Engine.decode(input, :icu_archive_631, :icu_archive_669)
  def decode_discard(input), do: Engine.decode(input, :icu_archive_631, :icu_archive_669, true)
  def encode(codepoints), do: Engine.encode(codepoints, :icu_archive_631, :icu_archive_669)

  def encode_discard(codepoints),
    do: Engine.encode(codepoints, :icu_archive_631, :icu_archive_669, true)

  def encode_substitute(codepoints, replacer),
    do: Engine.encode_substitute(codepoints, :icu_archive_631, :icu_archive_669, replacer)

  def decode_to_utf8(input), do: Engine.decode_to_utf8(input, :icu_archive_631, :icu_archive_669)

  def encode_from_utf8(input),
    do: Engine.encode_from_utf8(input, :icu_archive_631, :icu_archive_669)
end

defmodule Iconvex.Specs.IBM938 do
  @moduledoc "IBM CCSID 938: Traditional Chinese PC mixed data (CP904 SBCS plus CP927 DBCS)."
  use Iconvex.Codec
  alias Iconvex.Specs.IBMPCMixed, as: Engine

  def canonical_name, do: "IBM-938"
  def aliases, do: ["IBM938", "CP938", "CCSID938"]
  def codec_id, do: :ibm_938
  def decode(input), do: Engine.decode(input, :icu_archive_647, :icu_archive_670)
  def decode_discard(input), do: Engine.decode(input, :icu_archive_647, :icu_archive_670, true)
  def encode(codepoints), do: Engine.encode(codepoints, :icu_archive_647, :icu_archive_670)

  def encode_discard(codepoints),
    do: Engine.encode(codepoints, :icu_archive_647, :icu_archive_670, true)

  def encode_substitute(codepoints, replacer),
    do: Engine.encode_substitute(codepoints, :icu_archive_647, :icu_archive_670, replacer)

  def decode_to_utf8(input), do: Engine.decode_to_utf8(input, :icu_archive_647, :icu_archive_670)

  def encode_from_utf8(input),
    do: Engine.encode_from_utf8(input, :icu_archive_647, :icu_archive_670)
end

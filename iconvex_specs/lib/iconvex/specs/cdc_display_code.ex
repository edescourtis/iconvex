defmodule Iconvex.Specs.CDCDisplayCode do
  @moduledoc false

  @source_path Path.expand(
                 "../../../priv/sources/cdc-display-code/60435600L_NOS_Version_1_Operators_Guide_May1980.pdf",
                 __DIR__
               )
  @external_resource @source_path
  @chunk_units 4_096

  @cdc64 [?:] ++
           Enum.to_list(?A..?Z) ++
           Enum.to_list(?0..?9) ++
           [?+, ?-, ?*, ?/, ?(, ?), ?$, ?=, 0x20, ?,, ?.] ++
           [0x2261, ?[, ?], ?%, 0x2260, 0x2192, 0x2228, 0x2227] ++
           [0x2191, 0x2193, ?<, ?>, 0x2264, 0x2265, 0x00AC, ?;]

  @ascii64 [?:] ++
             Enum.to_list(?A..?Z) ++
             Enum.to_list(?0..?9) ++
             [?+, ?-, ?*, ?/, ?(, ?), ?$, ?=, 0x20, ?,, ?.] ++
             [?#, ?[, ?], ?%, ?", ?_, ?!, ?&, ?', ??, ?<, ?>, ?@, ?\\, ?^, ?;]

  @cdc63 @cdc64 |> List.replace_at(0, nil) |> List.replace_at(0o63, ?:)
  @ascii63 @ascii64 |> List.replace_at(0, nil) |> List.replace_at(0o63, ?:)

  @tables %{
    cdc63: List.to_tuple(@cdc63),
    cdc64: List.to_tuple(@cdc64),
    ascii63: List.to_tuple(@ascii63),
    ascii64: List.to_tuple(@ascii64)
  }

  @encoders Map.new(@tables, fn {profile, table} ->
              encoder =
                table
                |> Tuple.to_list()
                |> Enum.with_index()
                |> Enum.reject(fn {codepoint, _unit} -> is_nil(codepoint) end)
                |> Map.new()

              {profile, encoder}
            end)

  def source_pages, do: [165, 166, 167, 168]
  def printed_source_pages, do: ["A-1", "A-2", "A-3", "A-4"]

  def source_url,
    do:
      "https://bitsavers.org/pdf/cdc/cyber/nos/60435600L_NOS_Version_1_Operators_Guide_May1980.pdf"

  def decode(input, profile) when is_binary(input),
    do: decode_all(input, Map.fetch!(@tables, profile), 0, [])

  def decode_discard(input, profile) when is_binary(input),
    do: decode_discard_all(input, Map.fetch!(@tables, profile), [])

  def encode(codepoints, profile) when is_list(codepoints),
    do: encode_all(codepoints, Map.fetch!(@encoders, profile), [])

  def encode_discard(codepoints, profile) when is_list(codepoints),
    do: encode_discard_all(codepoints, Map.fetch!(@encoders, profile), [])

  def decode_to_utf8(input, profile) when is_binary(input),
    do: decode_utf8_all(input, Map.fetch!(@tables, profile), 0, [], 0, [])

  def encode_from_utf8(input, profile) when is_binary(input) do
    Iconvex.Specs.CodecSupport.encode_utf8(
      input,
      &encode_utf8_all(&1, Map.fetch!(@encoders, profile), [], 0, []),
      &encode(&1, profile)
    )
  end

  defp decode_all(<<>>, _table, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_all(<<unit, rest::binary>>, table, offset, acc) when unit < 64 do
    case elem(table, unit) do
      nil -> {:error, :invalid_sequence, offset, <<unit>>}
      codepoint -> decode_all(rest, table, offset + 1, [codepoint | acc])
    end
  end

  defp decode_all(<<unit, _rest::binary>>, _table, offset, _acc),
    do: {:error, :invalid_sequence, offset, <<unit>>}

  defp decode_discard_all(<<>>, _table, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_all(<<unit, rest::binary>>, table, acc) when unit < 64 do
    case elem(table, unit) do
      nil -> decode_discard_all(rest, table, acc)
      codepoint -> decode_discard_all(rest, table, [codepoint | acc])
    end
  end

  defp decode_discard_all(<<_unit, rest::binary>>, table, acc),
    do: decode_discard_all(rest, table, acc)

  defp encode_all([], _encoder, acc), do: {:ok, reverse_binary(acc)}

  defp encode_all([codepoint | rest], encoder, acc) do
    case encoder do
      %{^codepoint => unit} -> encode_all(rest, encoder, [unit | acc])
      _ -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_discard_all([], _encoder, acc), do: {:ok, reverse_binary(acc)}

  defp encode_discard_all([codepoint | rest], encoder, acc) do
    case encoder do
      %{^codepoint => unit} -> encode_discard_all(rest, encoder, [unit | acc])
      _ -> encode_discard_all(rest, encoder, acc)
    end
  end

  defp decode_utf8_all(<<>>, _table, _offset, acc, _count, chunks),
    do: {:ok, finish_iodata(acc, chunks)}

  defp decode_utf8_all(<<unit, rest::binary>>, table, offset, acc, count, chunks)
       when unit < 64 do
    case elem(table, unit) do
      nil ->
        {:error, :invalid_sequence, offset, <<unit>>}

      codepoint ->
        next_acc = [utf8(codepoint) | acc]

        if count == @chunk_units - 1 do
          chunk = next_acc |> :lists.reverse() |> IO.iodata_to_binary()
          decode_utf8_all(rest, table, offset + 1, [], 0, [chunk | chunks])
        else
          decode_utf8_all(rest, table, offset + 1, next_acc, count + 1, chunks)
        end
    end
  end

  defp decode_utf8_all(<<unit, _rest::binary>>, _table, offset, _acc, _count, _chunks),
    do: {:error, :invalid_sequence, offset, <<unit>>}

  defp encode_utf8_all(<<>>, _encoder, acc, _count, chunks),
    do: {:ok, finish_iodata(acc, chunks)}

  defp encode_utf8_all(<<codepoint, rest::binary>>, encoder, acc, count, chunks)
       when codepoint < 0x80 do
    case encoder do
      %{^codepoint => unit} -> encode_utf8_unit(rest, encoder, unit, acc, count, chunks)
      _ -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_utf8_all(<<codepoint::utf8, rest::binary>>, encoder, acc, count, chunks) do
    case encoder do
      %{^codepoint => unit} -> encode_utf8_unit(rest, encoder, unit, acc, count, chunks)
      _ -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_utf8_unit(rest, encoder, unit, acc, count, chunks) do
    next_acc = [unit | acc]

    if count == @chunk_units - 1 do
      chunk = next_acc |> :lists.reverse() |> :erlang.list_to_binary()
      encode_utf8_all(rest, encoder, [], 0, [chunk | chunks])
    else
      encode_utf8_all(rest, encoder, next_acc, count + 1, chunks)
    end
  end

  defp reverse_binary(acc), do: acc |> :lists.reverse() |> :erlang.list_to_binary()
  defp utf8(codepoint) when codepoint < 0x80, do: codepoint
  defp utf8(codepoint), do: <<codepoint::utf8>>

  defp finish_iodata([], chunks),
    do: chunks |> :lists.reverse() |> IO.iodata_to_binary()

  defp finish_iodata(acc, chunks) do
    chunk = acc |> :lists.reverse() |> IO.iodata_to_binary()
    [chunk | chunks] |> :lists.reverse() |> IO.iodata_to_binary()
  end
end

defmodule Iconvex.Specs.CDCDisplayCode.Profile do
  @moduledoc false

  defmacro __using__(options) do
    profile = Keyword.fetch!(options, :profile)
    canonical = Keyword.fetch!(options, :canonical)
    aliases = Keyword.fetch!(options, :aliases)
    codec_id = Keyword.fetch!(options, :codec_id)

    quote do
      use Iconvex.Codec
      alias Iconvex.Specs.CDCDisplayCode, as: Engine

      @impl true
      def canonical_name, do: unquote(canonical)

      @impl true
      def aliases, do: unquote(aliases)

      @impl true
      def codec_id, do: unquote(codec_id)

      def unit_bits, do: 6
      def source_pages, do: Engine.source_pages()
      def printed_source_pages, do: Engine.printed_source_pages()
      def source_url, do: Engine.source_url()

      @impl true
      def decode(input), do: Engine.decode(input, unquote(profile))

      @impl true
      def decode_discard(input), do: Engine.decode_discard(input, unquote(profile))

      @impl true
      def encode(codepoints), do: Engine.encode(codepoints, unquote(profile))

      @impl true
      def encode_discard(codepoints), do: Engine.encode_discard(codepoints, unquote(profile))

      @impl true
      def encode_substitute(codepoints, replacer),
        do:
          Iconvex.Specs.CodecSupport.encode_substitute_each(
            codepoints,
            &encode/1,
            replacer
          )

      @impl true
      def decode_to_utf8(input), do: Engine.decode_to_utf8(input, unquote(profile))

      @impl true
      def encode_from_utf8(input), do: Engine.encode_from_utf8(input, unquote(profile))
    end
  end
end

defmodule Iconvex.Specs.CDCDisplayCode64 do
  @moduledoc "CDC NOS Display Code with the CDC graphic 64-character set."

  use Iconvex.Specs.CDCDisplayCode.Profile,
    profile: :cdc64,
    canonical: "CDC-DISPLAY-CODE-64",
    aliases: [
      "CDC-DISPLAY-CODE",
      "CDC-6000-DISPLAY-CODE",
      "CDC-CYBER-DISPLAY-CODE",
      "CDC-GRAPHIC-64"
    ],
    codec_id: :cdc_display_code_64
end

defmodule Iconvex.Specs.CDCDisplayCode63 do
  @moduledoc "CDC NOS Display Code with the CDC graphic 63-character anomaly."

  use Iconvex.Specs.CDCDisplayCode.Profile,
    profile: :cdc63,
    canonical: "CDC-DISPLAY-CODE-63",
    aliases: ["CDC-63-DISPLAY-CODE", "CDC-GRAPHIC-63"],
    codec_id: :cdc_display_code_63
end

defmodule Iconvex.Specs.CDCDisplayCodeASCII64 do
  @moduledoc "CDC NOS Display Code with the ASCII graphic 64-character set."

  use Iconvex.Specs.CDCDisplayCode.Profile,
    profile: :ascii64,
    canonical: "CDC-DISPLAY-CODE-ASCII-64",
    aliases: ["CDC-ASCII-DISPLAY-CODE-64", "CDC-ASCII-GRAPHIC-64"],
    codec_id: :cdc_display_code_ascii_64
end

defmodule Iconvex.Specs.CDCDisplayCodeASCII63 do
  @moduledoc "CDC NOS Display Code with the ASCII graphic 63-character anomaly."

  use Iconvex.Specs.CDCDisplayCode.Profile,
    profile: :ascii63,
    canonical: "CDC-DISPLAY-CODE-ASCII-63",
    aliases: ["CDC-ASCII-DISPLAY-CODE-63", "CDC-ASCII-GRAPHIC-63"],
    codec_id: :cdc_display_code_ascii_63
end

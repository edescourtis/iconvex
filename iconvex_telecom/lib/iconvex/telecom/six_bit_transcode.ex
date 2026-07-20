defmodule Iconvex.Telecom.SixBitTranscode do
  @moduledoc false

  @chunk_units 4_096

  @base [
    0x0001,
    0x0041,
    0x0042,
    0x0043,
    0x0044,
    0x0045,
    0x0046,
    0x0047,
    0x0048,
    0x0049,
    0x0002,
    0x002E,
    nil,
    0x0007,
    0x001A,
    0x0017,
    0x0026,
    0x004A,
    0x004B,
    0x004C,
    0x004D,
    0x004E,
    0x004F,
    0x0050,
    0x0051,
    0x0052,
    0x0020,
    0x0024,
    0x002A,
    0x001F,
    0x0004,
    0x0010,
    0x002D,
    0x002F,
    0x0053,
    0x0054,
    0x0055,
    0x0056,
    0x0057,
    0x0058,
    0x0059,
    0x005A,
    0x001B,
    0x0027,
    0x0025,
    0x0005,
    0x0003,
    0x0009,
    0x0030,
    0x0031,
    0x0032,
    0x0033,
    0x0034,
    0x0035,
    0x0036,
    0x0037,
    0x0038,
    0x0039,
    0x0016,
    0x0023,
    0x0040,
    0x0015,
    0x0019,
    0x007F
  ]

  @tables %{
    ibm_2780: @base |> List.replace_at(0x0C, 0x2311) |> List.to_tuple(),
    ibm_bsc: @base |> List.replace_at(0x0C, 0x003C) |> List.to_tuple()
  }

  @encoders Map.new(@tables, fn {profile, table} ->
              encoder = table |> Tuple.to_list() |> Enum.with_index() |> Map.new()
              {profile, encoder}
            end)

  def table(profile), do: profile |> decode_table() |> Tuple.to_list()

  def decode(input, profile) when is_binary(input),
    do: decode_all(input, decode_table(profile), 0, [])

  def decode_discard(input, profile) when is_binary(input),
    do: decode_discard_all(input, decode_table(profile), [])

  def encode(codepoints, profile) when is_list(codepoints),
    do: encode_all(codepoints, encode_table(profile), [])

  def encode_discard(codepoints, profile) when is_list(codepoints),
    do: encode_discard_all(codepoints, encode_table(profile), [])

  def decode_to_utf8(input, profile) when is_binary(input),
    do: decode_utf8_all(input, decode_table(profile), 0, [], 0, [])

  def encode_from_utf8(input, profile) when is_binary(input) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        encode(codepoints, profile)

      {:incomplete, converted, rest} ->
        encode_prefix_or_utf8_error(
          converted,
          profile,
          :incomplete_sequence,
          byte_size(input) - byte_size(rest),
          rest
        )

      {:error, converted, rest} ->
        encode_prefix_or_utf8_error(
          converted,
          profile,
          :invalid_sequence,
          byte_size(input) - byte_size(rest),
          rest
        )
    end
  end

  def decode_chunk(input, profile, _final?) when is_binary(input) do
    case decode(input, profile) do
      {:ok, codepoints} -> {:ok, codepoints, <<>>}
      error -> error
    end
  end

  def encode_chunk(codepoints, profile, _final?, policy) when is_list(codepoints) do
    result =
      case policy do
        :error -> encode(codepoints, profile)
        :discard -> encode_discard(codepoints, profile)
        {:replace, replacer} -> encode_substitute(codepoints, profile, replacer)
      end

    case result do
      {:ok, output} -> {:ok, output, []}
      error -> error
    end
  end

  def encode_substitute(codepoints, profile, replacer)
      when is_list(codepoints) and is_function(replacer, 1),
      do: encode_substitute_all(codepoints, encode_table(profile), replacer, [])

  defp decode_table(:ibm_2780), do: Map.fetch!(@tables, :ibm_2780)
  defp decode_table(:ibm_bsc), do: Map.fetch!(@tables, :ibm_bsc)
  defp encode_table(:ibm_2780), do: Map.fetch!(@encoders, :ibm_2780)
  defp encode_table(:ibm_bsc), do: Map.fetch!(@encoders, :ibm_bsc)

  defp decode_all(<<>>, _table, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_all(<<unit, rest::binary>>, table, offset, acc) when unit < 64,
    do: decode_all(rest, table, offset + 1, [elem(table, unit) | acc])

  defp decode_all(<<unit, _rest::binary>>, _table, offset, _acc),
    do: {:error, :invalid_sequence, offset, <<unit>>}

  defp decode_discard_all(<<>>, _table, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_all(<<unit, rest::binary>>, table, acc) when unit < 64,
    do: decode_discard_all(rest, table, [elem(table, unit) | acc])

  defp decode_discard_all(<<_unit, rest::binary>>, table, acc),
    do: decode_discard_all(rest, table, acc)

  defp encode_all([], _encoder, acc),
    do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_binary()}

  defp encode_all([codepoint | rest], encoder, acc) do
    case encoder do
      %{^codepoint => unit} -> encode_all(rest, encoder, [unit | acc])
      _ -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_discard_all([], _encoder, acc),
    do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_binary()}

  defp encode_discard_all([codepoint | rest], encoder, acc) do
    case encoder do
      %{^codepoint => unit} -> encode_discard_all(rest, encoder, [unit | acc])
      _ -> encode_discard_all(rest, encoder, acc)
    end
  end

  defp encode_substitute_all([], _encoder, _replacer, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute_all([codepoint | rest], encoder, replacer, acc) do
    case encoder do
      %{^codepoint => unit} ->
        encode_substitute_all(rest, encoder, replacer, [unit | acc])

      _ ->
        case encode_all(replacer.(codepoint), encoder, []) do
          {:ok, replacement} ->
            encode_substitute_all(rest, encoder, replacer, [replacement | acc])

          error ->
            error
        end
    end
  end

  defp decode_utf8_all(<<>>, _table, _offset, byte_acc, _count, chunks),
    do: {:ok, finish_utf8(byte_acc, chunks)}

  defp decode_utf8_all(<<unit, rest::binary>>, table, offset, byte_acc, count, chunks)
       when unit < 64 do
    next_acc = [<<elem(table, unit)::utf8>> | byte_acc]

    if count == @chunk_units - 1 do
      chunk = next_acc |> :lists.reverse() |> IO.iodata_to_binary()
      decode_utf8_all(rest, table, offset + 1, [], 0, [chunk | chunks])
    else
      decode_utf8_all(rest, table, offset + 1, next_acc, count + 1, chunks)
    end
  end

  defp decode_utf8_all(
         <<unit, _rest::binary>>,
         _table,
         offset,
         _byte_acc,
         _count,
         _chunks
       ),
       do: {:error, :invalid_sequence, offset, <<unit>>}

  defp finish_utf8(byte_acc, chunks) do
    tail = byte_acc |> :lists.reverse() |> IO.iodata_to_binary()

    case chunks do
      [] -> tail
      _ -> chunks |> :lists.reverse([tail]) |> IO.iodata_to_binary()
    end
  end

  defp encode_prefix_or_utf8_error(converted, profile, kind, offset, rest) do
    case encode(converted, profile) do
      {:ok, _encoded_prefix} -> {:decode_error, kind, offset, rest}
      error -> error
    end
  end
end

defmodule Iconvex.Telecom.IBM2780SixBitTranscode do
  @moduledoc "IBM 2780 Six-Bit Transcode from GA27-3005-3 (August 1971)."

  use Iconvex.Telecom.SubstitutionCodec

  alias Iconvex.Telecom.SixBitTranscode

  @profile :ibm_2780
  @source_url "https://www.bitsavers.org/pdf/ibm/2780/" <>
                "GA27-3005-3-2780_Data_Terminal_Description_Aug71.pdf"

  @impl true
  def canonical_name, do: "IBM-2780-SIX-BIT-TRANSCODE-GA27-3005-3"

  @impl true
  def aliases,
    do: [
      "IBM-2780-SIX-BIT-TRANSCODE-1971",
      "IBM-2780-TRANSCODE-1971",
      "IBM-GA27-3005-3-TRANSCODE"
    ]

  @impl true
  def codec_id, do: @profile

  def source_url, do: @source_url
  def source_sha256, do: "3e631b8851217a848da3e2ca4ebf673978dcc87ed238407e35399024e98a75a8"
  def source_size, do: 5_845_274
  def source_page, do: 10

  def mapping_sha256,
    do: "cbb94188f9ac1a8b9a95dcff91d0744c84f77ad53377d62dd76eff4d6a476416"

  def metadata_sha256,
    do: "3b9fe66217399b16b338ffa41209d2b77237886cde306e10e63f82374506908f"

  def table,
    do:
      SixBitTranscode.table(@profile)
      |> Enum.with_index()
      |> Map.new(fn {cp, unit} -> {unit, cp} end)

  @impl true
  def decode(input), do: SixBitTranscode.decode(input, @profile)

  @impl true
  def decode_discard(input), do: SixBitTranscode.decode_discard(input, @profile)

  @impl true
  def encode(codepoints), do: SixBitTranscode.encode(codepoints, @profile)

  @impl true
  def encode_discard(codepoints), do: SixBitTranscode.encode_discard(codepoints, @profile)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: SixBitTranscode.encode_substitute(codepoints, @profile, replacer)

  @impl true
  def decode_to_utf8(input), do: SixBitTranscode.decode_to_utf8(input, @profile)

  @impl true
  def encode_from_utf8(input), do: SixBitTranscode.encode_from_utf8(input, @profile)

  @impl true
  def decode_chunk(input, final?), do: SixBitTranscode.decode_chunk(input, @profile, final?)

  @impl true
  def encode_chunk(codepoints, final?, policy),
    do: SixBitTranscode.encode_chunk(codepoints, @profile, final?, policy)
end

defmodule Iconvex.Telecom.IBMBscSixBitTranscode do
  @moduledoc "IBM BSC Six-Bit Transcode from GA27-3004-2 (October 1970)."

  use Iconvex.Telecom.SubstitutionCodec

  alias Iconvex.Telecom.SixBitTranscode

  @profile :ibm_bsc
  @source_url "https://www.bitsavers.org/pdf/ibm/datacomm/" <>
                "GA27-3004-2_General_Information_Binary_Synchronous_Communications_Oct70.pdf"

  @impl true
  def canonical_name, do: "IBM-BSC-SIX-BIT-TRANSCODE-GA27-3004-2"

  @impl true
  def aliases,
    do: [
      "IBM-BSC-SIX-BIT-TRANSCODE-1970",
      "IBM-GA27-3004-2-TRANSCODE"
    ]

  @impl true
  def codec_id, do: @profile

  def source_url, do: @source_url
  def source_sha256, do: "2589c426624f8e57158fe8256fbeecc17d779d2b4ca4cd73caddd28c4dc2f67f"
  def source_size, do: 2_485_327
  def source_page, do: 11

  def mapping_sha256,
    do: "5dccf290006224a0de51dddda9ec227183f1527610f61cf2f70b606ccea7c31e"

  def metadata_sha256,
    do: "3b9fe66217399b16b338ffa41209d2b77237886cde306e10e63f82374506908f"

  def table,
    do:
      SixBitTranscode.table(@profile)
      |> Enum.with_index()
      |> Map.new(fn {cp, unit} -> {unit, cp} end)

  @impl true
  def decode(input), do: SixBitTranscode.decode(input, @profile)

  @impl true
  def decode_discard(input), do: SixBitTranscode.decode_discard(input, @profile)

  @impl true
  def encode(codepoints), do: SixBitTranscode.encode(codepoints, @profile)

  @impl true
  def encode_discard(codepoints), do: SixBitTranscode.encode_discard(codepoints, @profile)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: SixBitTranscode.encode_substitute(codepoints, @profile, replacer)

  @impl true
  def decode_to_utf8(input), do: SixBitTranscode.decode_to_utf8(input, @profile)

  @impl true
  def encode_from_utf8(input), do: SixBitTranscode.encode_from_utf8(input, @profile)

  @impl true
  def decode_chunk(input, final?), do: SixBitTranscode.decode_chunk(input, @profile, final?)

  @impl true
  def encode_chunk(codepoints, final?, policy),
    do: SixBitTranscode.encode_chunk(codepoints, @profile, final?, policy)
end

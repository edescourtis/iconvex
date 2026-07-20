defmodule Iconvex.Extras.CodecSupport do
  @moduledoc false
  @euc_jisx0213_pair_first [
    230,
    596,
    601,
    602,
    652,
    741,
    745,
    12_363,
    12_365,
    12_367,
    12_369,
    12_371,
    12_459,
    12_461,
    12_463,
    12_465,
    12_467,
    12_475,
    12_484,
    12_488,
    12_791
  ]
  @cp943_decode_cache {__MODULE__, :cp943_decode_cache, 1}
  @euc_jisx0213_double_decode_cache {__MODULE__, :euc_jisx0213_double_decode_cache, 1}
  @euc_jisx0213_triple_decode_cache {__MODULE__, :euc_jisx0213_triple_decode_cache, 1}
  @binary_cache_schema {:iconvex_extras_binary_cache, 1}
  @cp943_decode_cache_kind {:cp943_dense_u32be, 65_536, 1}
  @euc_jisx0213_double_cache_kind {:euc_jisx0213_double_u32be_pair, 65_536, 1}
  @euc_jisx0213_triple_cache_kind {:euc_jisx0213_triple_u32be_pair, 65_536, 1}
  @cp943_decode_cache_bytes 65_536 * 4
  @euc_jisx0213_decode_cache_bytes 65_536 * 8

  defguardp unmapped_jisx0213_codepoint(codepoint)
            when codepoint in 0xA000..0xEFFF or codepoint in 0x10000..0x1FFFF or
                   codepoint > 0x2A6B2

  def decode(id, input), do: Iconvex.TableCodec.decode(entry(id), input)

  def encode(:euc_jisx0213, codepoints) do
    table = Iconvex.Tables.fetch!(entry(:euc_jisx0213))
    encode_euc_jisx0213(codepoints, table.encode, [])
  end

  def encode(id, codepoints), do: Iconvex.TableCodec.encode(entry(id), codepoints)

  def encode_discard(:euc_jisx0213, codepoints) do
    table = Iconvex.Tables.fetch!(entry(:euc_jisx0213))
    {:ok, encode_euc_jisx0213_discard(codepoints, table.encode, [])}
  end

  def encode_discard(id, codepoints),
    do: Iconvex.TableCodec.encode_discard(entry(id), codepoints)

  def encode_substitute(:iso2022_jp3, codepoints, replacer) when is_function(replacer, 1),
    do: Iconvex.ISO2022JPCodec.encode_substitute(%{id: :iso2022_jp3}, codepoints, replacer)

  def encode_substitute(id, codepoints, replacer) when is_function(replacer, 1),
    do: Iconvex.TableCodec.encode_substitute(entry(id), codepoints, replacer)

  def decode_to_utf8(:cp943, input) do
    table = Iconvex.Tables.fetch!(entry(:cp943))
    decode_cp943_to_utf8(input, table.one, cp943_decode_cache(table.many), [])
  end

  def decode_to_utf8(:euc_jisx0213, input) do
    table = Iconvex.Tables.fetch!(entry(:euc_jisx0213))

    decode_euc_jisx0213_to_utf8(
      input,
      table.one,
      euc_jisx0213_double_decode_cache(table.many),
      euc_jisx0213_triple_decode_cache(table.many),
      []
    )
  end

  def decode_to_utf8(id, input), do: Iconvex.TableCodec.decode_to_utf8(entry(id), input)

  def decode_to_ucs4_discard(:euc_jisx0213, input, endian)
      when endian in [:big, :little],
      do: decode_euc_jisx0213_to_ucs4_discard(input, endian)

  def decode_to_ucs4_discard(:cp943, input, endian) when endian in [:big, :little] do
    id = :cp943

    case decode_to_utf8(id, input) do
      {:ok, utf8} ->
        case :unicode.characters_to_binary(utf8, :utf8, {:utf32, endian}) do
          output when is_binary(output) -> {:ok, output}
          _invalid_utf8 -> decode_to_ucs4_discard_fallback(id, input, endian)
        end

      :miss ->
        decode_to_ucs4_discard_fallback(id, input, endian)
    end
  end

  def decode_to_ucs4_discard(:iso2022_jp3, input, endian) when endian in [:big, :little],
    do:
      Iconvex.StatefulCodec.decode_to_explicit_ucs4_discard(
        %{id: :iso2022_jp3},
        input,
        endian
      )

  def decode_to_ucs4_discard(id, input, endian) when endian in [:big, :little],
    do: decode_to_ucs4_discard_fallback(id, input, endian)

  @doc false
  def decode_euc_jisx0213_to_ucs4_discard(input, endian)
      when is_binary(input) and endian in [:big, :little] do
    table = Iconvex.Tables.fetch!(entry(:euc_jisx0213))

    decode_euc_jisx0213_to_ucs4_discard(
      input,
      endian,
      table.one,
      euc_jisx0213_double_decode_cache(table.many),
      euc_jisx0213_triple_decode_cache(table.many),
      []
    )
  end

  def encode_from_ucs4_discard(id, input, endian)
      when id in [:euc_jisx0213, :shift_jisx0213] and endian in [:big, :little] and
             rem(byte_size(input), 4) == 0 do
    table = Iconvex.Tables.fetch!(entry(id))
    {:ok, encode_euc_jisx0213_from_ucs4_discard(input, endian, table.encode, [])}
  end

  def encode_from_ucs4_discard(:iso2022_jp3, input, endian) when endian in [:big, :little],
    do:
      Iconvex.StatefulCodec.encode_from_explicit_ucs4_discard(
        %{id: :iso2022_jp3},
        input,
        endian
      )

  def encode_from_ucs4_discard(id, input, endian),
    do: Iconvex.TableCodec.encode_from_explicit_ucs4_discard(entry(id), input, endian)

  def encode_from_utf8(id, input) do
    case Iconvex.TableCodec.encode_from_utf8(entry(id), input) do
      :miss -> encode_from_utf8_fallback(id, input)
      result -> result
    end
  end

  def decode_discard(:cp943, input) do
    table = Iconvex.Tables.fetch!(entry(:cp943))
    {:ok, decode_cp943_discard(input, table.one, cp943_decode_cache(table.many), [])}
  end

  def decode_discard(:euc_jisx0213, input) do
    table = Iconvex.Tables.fetch!(entry(:euc_jisx0213))

    {:ok,
     decode_euc_jisx0213_discard(
       input,
       table.one,
       euc_jisx0213_double_decode_cache(table.many),
       euc_jisx0213_triple_decode_cache(table.many),
       []
     )}
  end

  def decode_discard(id, input), do: Iconvex.TableCodec.decode_discard(entry(id), input)

  @doc false
  def optimized_discard_paths,
    do: %{cp943: [:decode], euc_jisx0213: [:decode, :encode]}

  @doc false
  def optimized_utf8_paths, do: [:cp943, :euc_jisx0213]

  @doc false
  def optimization_cache_sizes do
    cp943 = Iconvex.Tables.fetch!(entry(:cp943))
    euc = Iconvex.Tables.fetch!(entry(:euc_jisx0213))

    %{
      cp943_decode: byte_size(cp943_decode_cache(cp943.many)),
      euc_jisx0213_double_decode: byte_size(euc_jisx0213_double_decode_cache(euc.many)),
      euc_jisx0213_triple_decode: byte_size(euc_jisx0213_triple_decode_cache(euc.many))
    }
  end

  def decode_iso2022_jp3(input),
    do: Iconvex.ISO2022JPCodec.decode(%{id: :iso2022_jp3}, input)

  def encode_iso2022_jp3(codepoints),
    do: Iconvex.ISO2022JPCodec.encode(%{id: :iso2022_jp3}, codepoints)

  def encode_discard_iso2022_jp3(codepoints),
    do: Iconvex.ISO2022JPCodec.encode_discard(%{id: :iso2022_jp3}, codepoints)

  def decode_discard_iso2022_jp3(input),
    do: Iconvex.ISO2022JPCodec.decode_discard(%{id: :iso2022_jp3}, input)

  def stream_decoder_init_iso2022_jp3,
    do: Iconvex.StatefulCodec.stream_init(%{id: :iso2022_jp3})

  def decode_chunk_iso2022_jp3(input, state, final?),
    do:
      Iconvex.StatefulCodec.decode_chunk(
        %{id: :iso2022_jp3},
        input,
        state,
        final?,
        0
      )

  def stream_encoder_init_iso2022_jp3,
    do: Iconvex.StatefulCodec.stream_encode_init(%{id: :iso2022_jp3})

  def encode_chunk_iso2022_jp3(codepoints, state, final?, policy),
    do:
      Iconvex.StatefulCodec.encode_chunk(
        %{id: :iso2022_jp3},
        codepoints,
        state,
        final?,
        policy
      )

  defp encode_from_utf8_fallback(id, input) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        encode(id, codepoints)

      {:incomplete, _converted, rest} ->
        {:decode_error, :incomplete_sequence, byte_size(input) - byte_size(rest), rest}

      {:error, _converted, rest} ->
        {:decode_error, :invalid_sequence, byte_size(input) - byte_size(rest), rest}
    end
  end

  defp decode_to_ucs4_discard_fallback(id, input, endian),
    do: Iconvex.TableCodec.decode_to_explicit_ucs4_discard(entry(id), input, endian)

  defp encode_euc_jisx0213_from_ucs4_discard(<<>>, _endian, _map, acc),
    do: acc |> :lists.reverse() |> IO.iodata_to_binary()

  defp encode_euc_jisx0213_from_ucs4_discard(
         <<a::unsigned-big-32, b::unsigned-big-32, c::unsigned-big-32, d::unsigned-big-32,
           e::unsigned-big-32, f::unsigned-big-32, g::unsigned-big-32, h::unsigned-big-32,
           rest::binary>>,
         :big,
         map,
         acc
       )
       when unmapped_jisx0213_codepoint(a) and unmapped_jisx0213_codepoint(b) and
              unmapped_jisx0213_codepoint(c) and unmapped_jisx0213_codepoint(d) and
              unmapped_jisx0213_codepoint(e) and unmapped_jisx0213_codepoint(f) and
              unmapped_jisx0213_codepoint(g) and unmapped_jisx0213_codepoint(h),
       do: encode_euc_jisx0213_from_ucs4_discard(rest, :big, map, acc)

  defp encode_euc_jisx0213_from_ucs4_discard(
         <<a::unsigned-little-32, b::unsigned-little-32, c::unsigned-little-32,
           d::unsigned-little-32, e::unsigned-little-32, f::unsigned-little-32,
           g::unsigned-little-32, h::unsigned-little-32, rest::binary>>,
         :little,
         map,
         acc
       )
       when unmapped_jisx0213_codepoint(a) and unmapped_jisx0213_codepoint(b) and
              unmapped_jisx0213_codepoint(c) and unmapped_jisx0213_codepoint(d) and
              unmapped_jisx0213_codepoint(e) and unmapped_jisx0213_codepoint(f) and
              unmapped_jisx0213_codepoint(g) and unmapped_jisx0213_codepoint(h),
       do: encode_euc_jisx0213_from_ucs4_discard(rest, :little, map, acc)

  defp encode_euc_jisx0213_from_ucs4_discard(input, endian, map, acc) do
    {first, rest} = take_ucs4(input, endian)

    if first in @euc_jisx0213_pair_first and byte_size(rest) >= 4 do
      {second, after_second} = take_ucs4(rest, endian)

      case Map.fetch(map, {first, second}) do
        {:ok, bytes} ->
          encode_euc_jisx0213_from_ucs4_discard(after_second, endian, map, [bytes | acc])

        :error ->
          encode_euc_jisx0213_single_from_ucs4_discard(first, rest, endian, map, acc)
      end
    else
      encode_euc_jisx0213_single_from_ucs4_discard(first, rest, endian, map, acc)
    end
  end

  defp encode_euc_jisx0213_single_from_ucs4_discard(
         codepoint,
         rest,
         endian,
         map,
         acc
       )
       when unmapped_jisx0213_codepoint(codepoint),
       do: encode_euc_jisx0213_from_ucs4_discard(rest, endian, map, acc)

  defp encode_euc_jisx0213_single_from_ucs4_discard(
         codepoint,
         rest,
         endian,
         map,
         acc
       ) do
    case Map.fetch(map, {codepoint}) do
      {:ok, bytes} ->
        encode_euc_jisx0213_from_ucs4_discard(rest, endian, map, [bytes | acc])

      :error ->
        encode_euc_jisx0213_from_ucs4_discard(rest, endian, map, acc)
    end
  end

  defp take_ucs4(<<codepoint::unsigned-big-32, rest::binary>>, :big), do: {codepoint, rest}

  defp take_ucs4(<<codepoint::unsigned-little-32, rest::binary>>, :little),
    do: {codepoint, rest}

  defp encode_euc_jisx0213_discard([], _map, acc),
    do: acc |> :lists.reverse() |> IO.iodata_to_binary()

  defp encode_euc_jisx0213_discard([first, second | rest], map, acc)
       when first in @euc_jisx0213_pair_first do
    case Map.fetch(map, {first, second}) do
      {:ok, bytes} ->
        encode_euc_jisx0213_discard(rest, map, [bytes | acc])

      :error ->
        encode_euc_jisx0213_single_discard(first, [second | rest], map, acc)
    end
  end

  defp encode_euc_jisx0213_discard([codepoint | rest], map, acc),
    do: encode_euc_jisx0213_single_discard(codepoint, rest, map, acc)

  defp encode_euc_jisx0213_single_discard(codepoint, rest, map, acc) when codepoint <= 0x7F,
    do: encode_euc_jisx0213_discard(rest, map, [<<codepoint>> | acc])

  defp encode_euc_jisx0213_single_discard(codepoint, rest, map, acc)
       when codepoint in 0xA000..0xEFFF or codepoint in 0x10000..0x1FFFF or
              codepoint > 0x2A6B2,
       do: encode_euc_jisx0213_discard(rest, map, acc)

  defp encode_euc_jisx0213_single_discard(codepoint, rest, map, acc) do
    case Map.fetch(map, {codepoint}) do
      {:ok, bytes} -> encode_euc_jisx0213_discard(rest, map, [bytes | acc])
      :error -> encode_euc_jisx0213_discard(rest, map, acc)
    end
  end

  defp encode_euc_jisx0213([], _map, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_euc_jisx0213([first, second | rest], map, acc)
       when first in @euc_jisx0213_pair_first do
    case Map.fetch(map, {first, second}) do
      {:ok, bytes} -> encode_euc_jisx0213(rest, map, [bytes | acc])
      :error -> encode_euc_jisx0213_single(first, [second | rest], map, acc)
    end
  end

  defp encode_euc_jisx0213([codepoint | rest], map, acc),
    do: encode_euc_jisx0213_single(codepoint, rest, map, acc)

  defp encode_euc_jisx0213_single(codepoint, rest, map, acc) when codepoint <= 0x7F,
    do: encode_euc_jisx0213(rest, map, [<<codepoint>> | acc])

  defp encode_euc_jisx0213_single(codepoint, rest, map, acc) do
    case Map.fetch(map, {codepoint}) do
      {:ok, bytes} -> encode_euc_jisx0213(rest, map, [bytes | acc])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp decode_cp943_discard(<<>>, _one, _dense, acc), do: :lists.reverse(acc)

  defp decode_cp943_discard(<<byte, rest::binary>>, one, dense, acc)
       when byte <= 0x7F or byte in 0xA1..0xDF,
       do: decode_cp943_one_discard(byte, rest, one, dense, acc)

  defp decode_cp943_discard(<<first, second, rest::binary>>, one, dense, acc) do
    case dense_codepoint(dense, first, second) do
      0 ->
        decode_cp943_one_discard(first, <<second, rest::binary>>, one, dense, acc)

      stored ->
        decode_cp943_discard(rest, one, dense, [stored - 1 | acc])
    end
  end

  defp decode_cp943_discard(<<byte>>, one, dense, acc),
    do: decode_cp943_one_discard(byte, <<>>, one, dense, acc)

  defp decode_cp943_one_discard(byte, rest, one, dense, acc) do
    case elem(one, byte) do
      nil -> decode_cp943_discard(rest, one, dense, acc)
      codepoints -> decode_cp943_discard(rest, one, dense, prepend(codepoints, acc))
    end
  end

  defp decode_cp943_to_utf8(<<>>, _one, _dense, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp decode_cp943_to_utf8(<<byte, rest::binary>>, one, dense, acc)
       when byte <= 0x7F or byte in 0xA1..0xDF,
       do: decode_cp943_one_to_utf8(byte, rest, one, dense, acc)

  defp decode_cp943_to_utf8(<<first, second, rest::binary>>, one, dense, acc) do
    case dense_codepoint(dense, first, second) do
      0 ->
        decode_cp943_one_to_utf8(first, <<second, rest::binary>>, one, dense, acc)

      stored ->
        decode_cp943_to_utf8(rest, one, dense, [<<stored - 1::utf8>> | acc])
    end
  end

  defp decode_cp943_to_utf8(<<byte>>, one, dense, acc),
    do: decode_cp943_one_to_utf8(byte, <<>>, one, dense, acc)

  defp decode_cp943_one_to_utf8(byte, rest, one, dense, acc) do
    case elem(one, byte) do
      nil -> :miss
      codepoints -> decode_cp943_to_utf8(rest, one, dense, [tuple_utf8(codepoints) | acc])
    end
  end

  defp decode_euc_jisx0213_discard(<<>>, _one, _double, _triple, acc),
    do: :lists.reverse(acc)

  defp decode_euc_jisx0213_discard(
         <<0x8F, second, third, rest::binary>>,
         one,
         double,
         triple,
         acc
       ) do
    case dense_codepoints(triple, second, third) do
      {0, 0} ->
        decode_euc_jisx0213_one_discard(
          0x8F,
          <<second, third, rest::binary>>,
          one,
          double,
          triple,
          acc
        )

      stored ->
        decode_euc_jisx0213_discard(
          rest,
          one,
          double,
          triple,
          prepend_dense(stored, acc)
        )
    end
  end

  defp decode_euc_jisx0213_discard(
         <<first, second, rest::binary>>,
         one,
         double,
         triple,
         acc
       )
       when first == 0x8E or first in 0xA1..0xFE,
       do:
         decode_euc_jisx0213_pair_discard(
           first,
           second,
           rest,
           one,
           double,
           triple,
           acc
         )

  defp decode_euc_jisx0213_discard(<<byte, rest::binary>>, one, double, triple, acc),
    do: decode_euc_jisx0213_one_discard(byte, rest, one, double, triple, acc)

  defp decode_euc_jisx0213_pair_discard(first, second, rest, one, double, triple, acc) do
    case dense_codepoints(double, first, second) do
      {0, 0} ->
        decode_euc_jisx0213_one_discard(
          first,
          <<second, rest::binary>>,
          one,
          double,
          triple,
          acc
        )

      stored ->
        decode_euc_jisx0213_discard(
          rest,
          one,
          double,
          triple,
          prepend_dense(stored, acc)
        )
    end
  end

  defp decode_euc_jisx0213_one_discard(byte, rest, one, double, triple, acc) do
    case elem(one, byte) do
      nil ->
        decode_euc_jisx0213_discard(rest, one, double, triple, acc)

      codepoints ->
        decode_euc_jisx0213_discard(rest, one, double, triple, prepend(codepoints, acc))
    end
  end

  defp decode_euc_jisx0213_to_ucs4_discard(
         <<>>,
         _endian,
         _one,
         _double,
         _triple,
         acc
       ),
       do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp decode_euc_jisx0213_to_ucs4_discard(
         <<0x8F, second, third, rest::binary>>,
         endian,
         one,
         double,
         triple,
         acc
       ) do
    case dense_codepoints(triple, second, third) do
      {0, 0} ->
        decode_euc_jisx0213_one_to_ucs4_discard(
          0x8F,
          <<second, third, rest::binary>>,
          endian,
          one,
          double,
          triple,
          acc
        )

      stored ->
        decode_euc_jisx0213_to_ucs4_discard(
          rest,
          endian,
          one,
          double,
          triple,
          [dense_ucs4(stored, endian) | acc]
        )
    end
  end

  defp decode_euc_jisx0213_to_ucs4_discard(
         <<first, second, rest::binary>>,
         endian,
         one,
         double,
         triple,
         acc
       )
       when first == 0x8E or first in 0xA1..0xFE do
    case dense_codepoints(double, first, second) do
      {0, 0} ->
        decode_euc_jisx0213_one_to_ucs4_discard(
          first,
          <<second, rest::binary>>,
          endian,
          one,
          double,
          triple,
          acc
        )

      stored ->
        decode_euc_jisx0213_to_ucs4_discard(
          rest,
          endian,
          one,
          double,
          triple,
          [dense_ucs4(stored, endian) | acc]
        )
    end
  end

  defp decode_euc_jisx0213_to_ucs4_discard(
         <<byte, rest::binary>>,
         endian,
         one,
         double,
         triple,
         acc
       ),
       do:
         decode_euc_jisx0213_one_to_ucs4_discard(
           byte,
           rest,
           endian,
           one,
           double,
           triple,
           acc
         )

  defp decode_euc_jisx0213_one_to_ucs4_discard(
         byte,
         rest,
         endian,
         one,
         double,
         triple,
         acc
       ) do
    case elem(one, byte) do
      nil ->
        decode_euc_jisx0213_to_ucs4_discard(
          rest,
          endian,
          one,
          double,
          triple,
          acc
        )

      codepoints ->
        decode_euc_jisx0213_to_ucs4_discard(
          rest,
          endian,
          one,
          double,
          triple,
          [tuple_ucs4(codepoints, endian) | acc]
        )
    end
  end

  defp decode_euc_jisx0213_to_utf8(<<>>, _one, _double, _triple, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp decode_euc_jisx0213_to_utf8(
         <<0x8F, second, third, rest::binary>>,
         one,
         double,
         triple,
         acc
       ) do
    case dense_codepoints(triple, second, third) do
      {0, 0} ->
        decode_euc_jisx0213_one_to_utf8(
          0x8F,
          <<second, third, rest::binary>>,
          one,
          double,
          triple,
          acc
        )

      stored ->
        decode_euc_jisx0213_to_utf8(
          rest,
          one,
          double,
          triple,
          [dense_utf8(stored) | acc]
        )
    end
  end

  defp decode_euc_jisx0213_to_utf8(
         <<first, second, rest::binary>>,
         one,
         double,
         triple,
         acc
       )
       when first == 0x8E or first in 0xA1..0xFE do
    case dense_codepoints(double, first, second) do
      {0, 0} ->
        decode_euc_jisx0213_one_to_utf8(
          first,
          <<second, rest::binary>>,
          one,
          double,
          triple,
          acc
        )

      stored ->
        decode_euc_jisx0213_to_utf8(
          rest,
          one,
          double,
          triple,
          [dense_utf8(stored) | acc]
        )
    end
  end

  defp decode_euc_jisx0213_to_utf8(<<byte, rest::binary>>, one, double, triple, acc),
    do: decode_euc_jisx0213_one_to_utf8(byte, rest, one, double, triple, acc)

  defp decode_euc_jisx0213_one_to_utf8(byte, rest, one, double, triple, acc) do
    case elem(one, byte) do
      nil ->
        :miss

      codepoints ->
        decode_euc_jisx0213_to_utf8(
          rest,
          one,
          double,
          triple,
          [tuple_utf8(codepoints) | acc]
        )
    end
  end

  defp cp943_decode_cache(many) do
    cached_binary(@cp943_decode_cache, many, fn ->
      for first <- 0..0xFF, second <- 0..0xFF, into: <<>> do
        case Map.get(many, <<first, second>>) do
          {codepoint} -> <<codepoint + 1::unsigned-big-32>>
          nil -> <<0::unsigned-big-32>>
        end
      end
    end)
  end

  defp euc_jisx0213_double_decode_cache(many) do
    cached_binary(@euc_jisx0213_double_decode_cache, many, fn ->
      for first <- 0..0xFF, second <- 0..0xFF, into: <<>> do
        dense_codepoints_entry(Map.get(many, <<first, second>>))
      end
    end)
  end

  defp euc_jisx0213_triple_decode_cache(many) do
    cached_binary(@euc_jisx0213_triple_decode_cache, many, fn ->
      for second <- 0..0xFF, third <- 0..0xFF, into: <<>> do
        dense_codepoints_entry(Map.get(many, <<0x8F, second, third>>))
      end
    end)
  end

  defp cached_binary(key, source, build) do
    expected_bytes = cached_binary_size(key)
    kind = cached_binary_kind(key)

    case :persistent_term.get(key, :missing) do
      {@binary_cache_schema, ^kind, ^source, witness, binary}
      when is_binary(binary) and byte_size(binary) == expected_bytes ->
        if witness === cached_binary_witness(key, binary),
          do: binary,
          else: rebuild_cached_binary(key, kind, source, expected_bytes, build)

      _missing_or_stale ->
        rebuild_cached_binary(key, kind, source, expected_bytes, build)
    end
  end

  defp rebuild_cached_binary(key, kind, source, expected_bytes, build) do
    :global.trans({{{__MODULE__, :cache_build}, key}, self()}, fn ->
      case :persistent_term.get(key, :missing) do
        {@binary_cache_schema, ^kind, cached_source, witness, binary}
        when cached_source === source and is_binary(binary) and
               byte_size(binary) == expected_bytes ->
          if witness === cached_binary_witness(key, binary) do
            binary
          else
            build_and_publish_cached_binary(key, kind, source, expected_bytes, build)
          end

        _missing_stale_or_malformed ->
          build_and_publish_cached_binary(key, kind, source, expected_bytes, build)
      end
    end)
  end

  defp build_and_publish_cached_binary(key, kind, source, expected_bytes, build) do
    binary = build_cached_binary(key, expected_bytes, build)
    witness = cached_binary_witness(key, binary)
    :persistent_term.put(key, {@binary_cache_schema, kind, source, witness, binary})
    binary
  end

  defp build_cached_binary(key, expected_bytes, build) do
    binary = build.()

    if byte_size(binary) != expected_bytes do
      raise ArgumentError,
            "cache builder for #{inspect(key)} returned #{byte_size(binary)} bytes; " <>
              "expected #{expected_bytes}"
    end

    binary
  end

  defp cached_binary_size(@cp943_decode_cache), do: @cp943_decode_cache_bytes

  defp cached_binary_size(key)
       when key in [@euc_jisx0213_double_decode_cache, @euc_jisx0213_triple_decode_cache],
       do: @euc_jisx0213_decode_cache_bytes

  defp cached_binary_kind(@cp943_decode_cache), do: @cp943_decode_cache_kind

  defp cached_binary_kind(@euc_jisx0213_double_decode_cache),
    do: @euc_jisx0213_double_cache_kind

  defp cached_binary_kind(@euc_jisx0213_triple_decode_cache),
    do: @euc_jisx0213_triple_cache_kind

  # Cache hits validate a small versioned witness at fixed mapped positions.
  # This catches same-size stale/corrupt artifacts in constant time without
  # hashing the 256/512 KiB dense table on every conversion.
  defp cached_binary_witness(@cp943_decode_cache, binary) do
    {
      cached_word64(binary, 0),
      cached_word64(binary, 0x8140 * 4),
      cached_word64(binary, 0xE040 * 4),
      cached_word64(binary, 0xFA40 * 4),
      cached_word64(binary, @cp943_decode_cache_bytes - 8)
    }
  end

  defp cached_binary_witness(key, binary)
       when key in [@euc_jisx0213_double_decode_cache, @euc_jisx0213_triple_decode_cache] do
    {
      cached_word64(binary, 0),
      cached_word64(binary, 0x8EA1 * 8),
      cached_word64(binary, 0xA1A1 * 8),
      cached_word64(binary, 0xF4A1 * 8),
      cached_word64(binary, @euc_jisx0213_decode_cache_bytes - 8)
    }
  end

  defp cached_word64(binary, offset) do
    <<_prefix::binary-size(offset), word::unsigned-big-64, _rest::binary>> = binary
    word
  end

  defp dense_codepoints_entry(nil), do: <<0::unsigned-big-32, 0::unsigned-big-32>>

  defp dense_codepoints_entry({codepoint}),
    do: <<codepoint + 1::unsigned-big-32, 0::unsigned-big-32>>

  defp dense_codepoints_entry({first, second}),
    do: <<first + 1::unsigned-big-32, second + 1::unsigned-big-32>>

  defp dense_codepoint(binary, first, second) do
    offset = (first * 0x100 + second) * 4
    <<_::binary-size(offset), stored::unsigned-big-32, _::binary>> = binary
    stored
  end

  defp dense_codepoints(binary, first, second) do
    offset = (first * 0x100 + second) * 8

    <<_::binary-size(offset), stored_first::unsigned-big-32, stored_second::unsigned-big-32,
      _::binary>> = binary

    {stored_first, stored_second}
  end

  defp prepend_dense({stored_first, 0}, acc), do: [stored_first - 1 | acc]

  defp prepend_dense({stored_first, stored_second}, acc),
    do: [stored_second - 1, stored_first - 1 | acc]

  defp dense_utf8({stored_first, 0}), do: <<stored_first - 1::utf8>>

  defp dense_utf8({stored_first, stored_second}),
    do: <<stored_first - 1::utf8, stored_second - 1::utf8>>

  defp dense_ucs4({stored_first, 0}, :big),
    do: <<stored_first - 1::unsigned-big-32>>

  defp dense_ucs4({stored_first, stored_second}, :big),
    do: <<stored_first - 1::unsigned-big-32, stored_second - 1::unsigned-big-32>>

  defp dense_ucs4({stored_first, 0}, :little),
    do: <<stored_first - 1::unsigned-little-32>>

  defp dense_ucs4({stored_first, stored_second}, :little),
    do: <<stored_first - 1::unsigned-little-32, stored_second - 1::unsigned-little-32>>

  defp prepend(tuple, acc) when tuple_size(tuple) == 1, do: [elem(tuple, 0) | acc]
  defp prepend(tuple, acc) when tuple_size(tuple) == 2, do: [elem(tuple, 1), elem(tuple, 0) | acc]

  defp prepend(tuple, acc),
    do: tuple |> Tuple.to_list() |> :lists.reverse(acc)

  defp tuple_utf8({codepoint}), do: <<codepoint::utf8>>
  defp tuple_utf8({first, second}), do: <<first::utf8, second::utf8>>

  defp tuple_utf8(codepoints),
    do: codepoints |> Tuple.to_list() |> :unicode.characters_to_binary(:unicode, :utf8)

  defp tuple_ucs4({codepoint}, :big), do: <<codepoint::unsigned-big-32>>
  defp tuple_ucs4({codepoint}, :little), do: <<codepoint::unsigned-little-32>>

  defp tuple_ucs4({first, second}, :big),
    do: <<first::unsigned-big-32, second::unsigned-big-32>>

  defp tuple_ucs4({first, second}, :little),
    do: <<first::unsigned-little-32, second::unsigned-little-32>>

  defp tuple_ucs4(codepoints, endian) do
    codepoints
    |> Tuple.to_list()
    |> Enum.map(fn codepoint ->
      case endian do
        :big -> <<codepoint::unsigned-big-32>>
        :little -> <<codepoint::unsigned-little-32>>
      end
    end)
  end

  defp entry(id), do: %{id: id, table_app: :iconvex_extras}
end

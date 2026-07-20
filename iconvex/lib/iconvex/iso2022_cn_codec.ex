defmodule Iconvex.ISO2022CNCodec do
  @moduledoc false

  alias Iconvex.ISO2022CNEncoder
  alias Iconvex.StatefulPairCache
  alias Iconvex.Tables

  @base_designations [
    {<<0x1B, "$)A">>, {:g1, :gb2312}},
    {<<0x1B, "$)G">>, {:g1, 1}},
    {<<0x1B, "$*H">>, {:g2, 2}}
  ]
  @extended_designations @base_designations ++
                           [
                             {<<0x1B, "$)E">>, {:g1, :iso_ir_165}},
                             {<<0x1B, "$+I">>, {:g3, 3}},
                             {<<0x1B, "$+J">>, {:g3, 4}},
                             {<<0x1B, "$+K">>, {:g3, 5}},
                             {<<0x1B, "$+L">>, {:g3, 6}},
                             {<<0x1B, "$+M">>, {:g3, 7}}
                           ]

  def decode(%{id: variant}, input) when variant in [:iso2022_cn, :iso2022_cn_ext] do
    Tables.with_conversion_cache(fn ->
      decode_loop(variant, input, :ascii, nil, nil, nil, 0, [])
    end)
  end

  def decode_discard(%{id: variant}, input) when variant in [:iso2022_cn, :iso2022_cn_ext] do
    Tables.with_conversion_cache(fn ->
      decode_replace_loop(variant, input, :ascii, nil, nil, nil, fn _byte -> [] end, [])
    end)
  end

  def decode_substitute(%{id: variant}, input, replacer)
      when variant in [:iso2022_cn, :iso2022_cn_ext] and is_function(replacer, 1) do
    Tables.with_conversion_cache(fn ->
      decode_replace_loop(variant, input, :ascii, nil, nil, nil, replacer, [])
    end)
  end

  @doc false
  def decode_to_explicit_ucs4(%{id: variant}, input, endian)
      when variant in [:iso2022_cn, :iso2022_cn_ext] and endian in [:big, :little] do
    Tables.with_conversion_cache(fn ->
      decode_ucs4_loop(
        variant,
        input,
        :ascii,
        nil,
        nil,
        nil,
        endian,
        [],
        direct_tables(variant)
      )
    end)
  end

  def encode(%{id: variant}, codepoints) when variant in [:iso2022_cn, :iso2022_cn_ext],
    do:
      encode_loop(
        variant,
        codepoints,
        :ascii,
        nil,
        nil,
        nil,
        [],
        false,
        ISO2022CNEncoder.fetch(variant)
      )

  def encode_discard(%{id: variant}, codepoints)
      when variant in [:iso2022_cn, :iso2022_cn_ext],
      do:
        encode_loop(
          variant,
          codepoints,
          :ascii,
          nil,
          nil,
          nil,
          [],
          true,
          ISO2022CNEncoder.fetch(variant)
        )

  def encode_substitute(%{id: variant}, codepoints, replacer)
      when variant in [:iso2022_cn, :iso2022_cn_ext] and is_function(replacer, 1),
      do:
        encode_substitute_loop(
          variant,
          codepoints,
          [],
          false,
          :ascii,
          nil,
          nil,
          nil,
          [],
          replacer,
          ISO2022CNEncoder.fetch(variant)
        )

  def stream_encode_init(%{id: variant}) when variant in [:iso2022_cn, :iso2022_cn_ext],
    do: {:cn, :ascii, nil, nil, nil}

  def encode_chunk(
        %{id: variant},
        codepoints,
        {:cn, mode, g1, g2, g3},
        final?,
        policy
      )
      when variant in [:iso2022_cn, :iso2022_cn_ext] do
    stream_encode_loop(
      variant,
      codepoints,
      [],
      false,
      mode,
      g1,
      g2,
      g3,
      final?,
      policy,
      [],
      ISO2022CNEncoder.fetch(variant)
    )
  end

  defp decode_ucs4_loop(
         _variant,
         <<>>,
         _mode,
         _g1,
         _g2,
         _g3,
         _endian,
         acc,
         _tables
       ),
       do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp decode_ucs4_loop(
         variant,
         <<0x1B, ?N, first, second, rest::binary>>,
         mode,
         g1,
         2,
         g3,
         endian,
         acc,
         tables
       ) do
    case direct_decode_cns(2, first, second, tables, endian) do
      {:ok, bytes} ->
        decode_ucs4_loop(
          variant,
          rest,
          mode,
          g1,
          2,
          g3,
          endian,
          [bytes | acc],
          tables
        )

      :error ->
        decode_ucs4_loop(
          variant,
          <<?N, first, second, rest::binary>>,
          mode,
          g1,
          2,
          g3,
          endian,
          acc,
          tables
        )
    end
  end

  defp decode_ucs4_loop(
         variant,
         <<0x1B, ?O, first, second, rest::binary>>,
         mode,
         g1,
         g2,
         plane,
         endian,
         acc,
         tables
       )
       when plane in 3..7 do
    case direct_decode_cns(plane, first, second, tables, endian) do
      {:ok, bytes} ->
        decode_ucs4_loop(
          variant,
          rest,
          mode,
          g1,
          g2,
          plane,
          endian,
          [bytes | acc],
          tables
        )

      :error ->
        decode_ucs4_loop(
          variant,
          <<?O, first, second, rest::binary>>,
          mode,
          g1,
          g2,
          plane,
          endian,
          acc,
          tables
        )
    end
  end

  defp decode_ucs4_loop(
         variant,
         <<0x1B, _::binary>> = input,
         mode,
         g1,
         g2,
         g3,
         endian,
         acc,
         tables
       ) do
    case designation(variant, input) do
      {:g1, value} ->
        <<_::binary-size(4), rest::binary>> = input
        decode_ucs4_loop(variant, rest, mode, value, g2, g3, endian, acc, tables)

      {:g2, value} ->
        <<_::binary-size(4), rest::binary>> = input
        decode_ucs4_loop(variant, rest, mode, g1, value, g3, endian, acc, tables)

      {:g3, value} ->
        <<_::binary-size(4), rest::binary>> = input
        decode_ucs4_loop(variant, rest, mode, g1, g2, value, endian, acc, tables)

      :incomplete ->
        {:ok, finish_ucs4(acc)}

      :error ->
        <<_discarded_escape, rest::binary>> = input
        decode_ucs4_loop(variant, rest, mode, g1, g2, g3, endian, acc, tables)
    end
  end

  defp decode_ucs4_loop(
         variant,
         <<0x0E, rest::binary>>,
         _mode,
         g1,
         g2,
         g3,
         endian,
         acc,
         tables
       )
       when not is_nil(g1),
       do: decode_ucs4_loop(variant, rest, :twobyte, g1, g2, g3, endian, acc, tables)

  defp decode_ucs4_loop(
         variant,
         <<0x0E, rest::binary>>,
         mode,
         g1,
         g2,
         g3,
         endian,
         acc,
         tables
       ),
       do: decode_ucs4_loop(variant, rest, mode, g1, g2, g3, endian, acc, tables)

  defp decode_ucs4_loop(
         variant,
         <<0x0F, rest::binary>>,
         _mode,
         g1,
         g2,
         g3,
         endian,
         acc,
         tables
       ),
       do: decode_ucs4_loop(variant, rest, :ascii, g1, g2, g3, endian, acc, tables)

  defp decode_ucs4_loop(
         variant,
         <<byte, rest::binary>>,
         :ascii,
         g1,
         g2,
         g3,
         endian,
         acc,
         tables
       )
       when byte < 0x80,
       do:
         decode_ucs4_loop(
           variant,
           rest,
           :ascii,
           g1,
           g2,
           g3,
           endian,
           [ucs4(byte, endian) | acc],
           tables
         )

  defp decode_ucs4_loop(
         _variant,
         input,
         :twobyte,
         _g1,
         _g2,
         _g3,
         _endian,
         acc,
         _tables
       )
       when byte_size(input) < 2,
       do: {:ok, finish_ucs4(acc)}

  defp decode_ucs4_loop(
         variant,
         <<first, second, rest::binary>>,
         :twobyte,
         g1,
         g2,
         g3,
         endian,
         acc,
         tables
       )
       when first < 0x80 and second < 0x80 do
    result =
      case g1 do
        :gb2312 -> StatefulPairCache.lookup(tables.gb2312_dense, first, second, endian)
        :iso_ir_165 -> StatefulPairCache.lookup(tables.isoir165_dense, first, second, endian)
        1 -> direct_decode_cns(1, first, second, tables, endian)
      end

    case result do
      {:ok, bytes} ->
        decode_ucs4_loop(
          variant,
          rest,
          :twobyte,
          g1,
          g2,
          g3,
          endian,
          [bytes | acc],
          tables
        )

      :error ->
        decode_ucs4_loop(
          variant,
          <<second, rest::binary>>,
          :twobyte,
          g1,
          g2,
          g3,
          endian,
          acc,
          tables
        )
    end
  end

  defp decode_ucs4_loop(
         variant,
         <<_discarded, rest::binary>>,
         mode,
         g1,
         g2,
         g3,
         endian,
         acc,
         tables
       ),
       do: decode_ucs4_loop(variant, rest, mode, g1, g2, g3, endian, acc, tables)

  defp direct_tables(:iso2022_cn) do
    {gb2312_table, gb2312_identity} = Tables.fetch_with_identity!(%{id: :gb2312})
    {euc_tw_table, euc_tw_identity} = Tables.fetch_with_identity!(%{id: :euc_tw})
    gb2312 = gb2312_table.many
    euc_tw = euc_tw_table.many

    %{
      gb2312_dense: StatefulPairCache.seven_bit(:gb2312, gb2312, gb2312_identity),
      euc_tw_planes: StatefulPairCache.euc_tw_planes(euc_tw, euc_tw_identity)
    }
  end

  defp direct_tables(:iso2022_cn_ext) do
    {isoir165_table, isoir165_identity} = Tables.fetch_with_identity!(%{id: :isoir165})
    isoir165 = isoir165_table.many

    direct_tables(:iso2022_cn)
    |> Map.put(
      :isoir165_dense,
      StatefulPairCache.seven_bit(:isoir165, isoir165, isoir165_identity)
    )
  end

  defp direct_decode_cns(plane, first, second, %{euc_tw_planes: planes}, endian),
    do: StatefulPairCache.lookup(elem(planes, plane - 1), first, second, endian)

  defp ucs4(codepoint, :big), do: <<codepoint::unsigned-big-32>>
  defp ucs4(codepoint, :little), do: <<codepoint::unsigned-little-32>>

  defp finish_ucs4(acc), do: acc |> :lists.reverse() |> IO.iodata_to_binary()

  defp decode_loop(_variant, <<>>, _mode, _g1, _g2, _g3, _offset, acc),
    do: {:ok, :lists.reverse(acc)}

  defp decode_loop(
         variant,
         <<0x1B, ?N, first, second, rest::binary>>,
         mode,
         g1,
         2,
         g3,
         offset,
         acc
       ) do
    case decode_cns(2, first, second) do
      {:ok, cps} -> decode_loop(variant, rest, mode, g1, 2, g3, offset + 4, prepend(cps, acc))
      :error -> invalid(<<0x1B, ?N, first, second>>, offset)
    end
  end

  defp decode_loop(
         variant,
         <<0x1B, ?O, first, second, rest::binary>>,
         mode,
         g1,
         g2,
         plane,
         offset,
         acc
       )
       when plane in 3..7 do
    case decode_cns(plane, first, second) do
      {:ok, cps} -> decode_loop(variant, rest, mode, g1, g2, plane, offset + 4, prepend(cps, acc))
      :error -> invalid(<<0x1B, ?O, first, second>>, offset)
    end
  end

  defp decode_loop(
         _variant,
         <<0x1B, ?N>> = input,
         _mode,
         _g1,
         2,
         _g3,
         offset,
         _acc
       ),
       do: {:error, :incomplete_sequence, offset, input}

  defp decode_loop(
         _variant,
         <<0x1B, ?N, first>> = input,
         _mode,
         _g1,
         2,
         _g3,
         offset,
         _acc
       )
       when first in 0x21..0x7E,
       do: {:error, :incomplete_sequence, offset, input}

  defp decode_loop(
         _variant,
         <<0x1B, ?O>> = input,
         _mode,
         _g1,
         _g2,
         g3,
         offset,
         _acc
       )
       when g3 in 3..7,
       do: {:error, :incomplete_sequence, offset, input}

  defp decode_loop(
         _variant,
         <<0x1B, ?O, first>> = input,
         _mode,
         _g1,
         _g2,
         g3,
         offset,
         _acc
       )
       when g3 in 3..7 and first in 0x21..0x7E,
       do: {:error, :incomplete_sequence, offset, input}

  defp decode_loop(variant, <<0x1B, _::binary>> = input, mode, g1, g2, g3, offset, acc) do
    case designation(variant, input) do
      {:g1, value} ->
        <<_::binary-size(4), rest::binary>> = input
        decode_loop(variant, rest, mode, value, g2, g3, offset + 4, acc)

      {:g2, value} ->
        <<_::binary-size(4), rest::binary>> = input
        decode_loop(variant, rest, mode, g1, value, g3, offset + 4, acc)

      {:g3, value} ->
        <<_::binary-size(4), rest::binary>> = input
        decode_loop(variant, rest, mode, g1, g2, value, offset + 4, acc)

      :incomplete ->
        {:error, :incomplete_sequence, offset, input}

      :error ->
        invalid(binary_part(input, 0, min(4, byte_size(input))), offset)
    end
  end

  defp decode_loop(variant, <<0x0E, rest::binary>>, _mode, g1, g2, g3, offset, acc)
       when not is_nil(g1),
       do: decode_loop(variant, rest, :twobyte, g1, g2, g3, offset + 1, acc)

  defp decode_loop(_variant, <<0x0E, _::binary>>, _mode, _g1, _g2, _g3, offset, _acc),
    do: invalid(<<0x0E>>, offset)

  defp decode_loop(variant, <<0x0F, rest::binary>>, _mode, g1, g2, g3, offset, acc),
    do: decode_loop(variant, rest, :ascii, g1, g2, g3, offset + 1, acc)

  defp decode_loop(variant, <<byte, rest::binary>>, :ascii, g1, g2, g3, offset, acc)
       when byte < 0x80,
       do: decode_loop(variant, rest, :ascii, g1, g2, g3, offset + 1, [byte | acc])

  defp decode_loop(_variant, input, :twobyte, _g1, _g2, _g3, offset, _acc)
       when byte_size(input) < 2,
       do: {:error, :incomplete_sequence, offset, input}

  defp decode_loop(variant, <<first, second, rest::binary>>, :twobyte, g1, g2, g3, offset, acc)
       when first < 0x80 and second < 0x80 do
    result =
      case g1 do
        :gb2312 -> table_pair(:gb2312, <<first, second>>)
        :iso_ir_165 -> table_pair(:isoir165, <<first, second>>)
        1 -> decode_cns(1, first, second)
      end

    case result do
      {:ok, cps} ->
        decode_loop(variant, rest, :twobyte, g1, g2, g3, offset + 2, prepend(cps, acc))

      :error ->
        invalid(<<first, second>>, offset)
    end
  end

  defp decode_loop(_variant, input, _mode, _g1, _g2, _g3, offset, _acc),
    do: invalid(binary_part(input, 0, min(4, byte_size(input))), offset)

  defp decode_replace_loop(_variant, <<>>, _mode, _g1, _g2, _g3, _replacer, acc),
    do: {:ok, :lists.reverse(acc)}

  defp decode_replace_loop(variant, input, mode, g1, g2, g3, replacer, acc) do
    case input do
      <<0x1B, ?N, first, second, rest::binary>> when g2 == 2 ->
        case decode_cns(2, first, second) do
          {:ok, cps} ->
            decode_replace_loop(variant, rest, mode, g1, g2, g3, replacer, prepend(cps, acc))

          :error ->
            replace_head(variant, input, mode, g1, g2, g3, replacer, acc)
        end

      <<0x1B, ?O, first, second, rest::binary>> when g3 in 3..7 ->
        case decode_cns(g3, first, second) do
          {:ok, cps} ->
            decode_replace_loop(variant, rest, mode, g1, g2, g3, replacer, prepend(cps, acc))

          :error ->
            replace_head(variant, input, mode, g1, g2, g3, replacer, acc)
        end

      <<0x1B, _::binary>> ->
        case designation(variant, input) do
          {:g1, value} ->
            <<_::binary-size(4), rest::binary>> = input
            decode_replace_loop(variant, rest, mode, value, g2, g3, replacer, acc)

          {:g2, value} ->
            <<_::binary-size(4), rest::binary>> = input
            decode_replace_loop(variant, rest, mode, g1, value, g3, replacer, acc)

          {:g3, value} ->
            <<_::binary-size(4), rest::binary>> = input
            decode_replace_loop(variant, rest, mode, g1, g2, value, replacer, acc)

          :incomplete ->
            {:ok, replace_bytes(acc, input, replacer) |> :lists.reverse()}

          :error ->
            replace_head(variant, input, mode, g1, g2, g3, replacer, acc)
        end

      <<0x0E, rest::binary>> when not is_nil(g1) ->
        decode_replace_loop(variant, rest, :twobyte, g1, g2, g3, replacer, acc)

      <<0x0E, rest::binary>> ->
        decode_replace_loop(
          variant,
          rest,
          mode,
          g1,
          g2,
          g3,
          replacer,
          replace(0x0E, replacer, acc)
        )

      <<0x0F, rest::binary>> ->
        decode_replace_loop(variant, rest, :ascii, g1, g2, g3, replacer, acc)

      <<byte, rest::binary>> when mode == :ascii and byte < 0x80 ->
        decode_replace_loop(variant, rest, mode, g1, g2, g3, replacer, [byte | acc])

      _ when mode == :twobyte and byte_size(input) < 2 ->
        {:ok, replace_bytes(acc, input, replacer) |> :lists.reverse()}

      <<first, second, rest::binary>> when mode == :twobyte and first < 0x80 and second < 0x80 ->
        result =
          case g1 do
            :gb2312 -> table_pair(:gb2312, <<first, second>>)
            :iso_ir_165 -> table_pair(:isoir165, <<first, second>>)
            1 -> decode_cns(1, first, second)
          end

        case result do
          {:ok, cps} ->
            decode_replace_loop(variant, rest, mode, g1, g2, g3, replacer, prepend(cps, acc))

          :error ->
            replace_head(variant, input, mode, g1, g2, g3, replacer, acc)
        end

      _ ->
        replace_head(variant, input, mode, g1, g2, g3, replacer, acc)
    end
  end

  defp replace_head(variant, <<byte, rest::binary>>, mode, g1, g2, g3, replacer, acc),
    do:
      decode_replace_loop(
        variant,
        rest,
        mode,
        g1,
        g2,
        g3,
        replacer,
        replace(byte, replacer, acc)
      )

  defp stream_encode_loop(
         variant,
         [],
         resume,
         true,
         mode,
         g1,
         g2,
         g3,
         final?,
         policy,
         acc,
         dispatch
       ),
       do:
         stream_encode_loop(
           variant,
           resume,
           [],
           false,
           mode,
           g1,
           g2,
           g3,
           final?,
           policy,
           acc,
           dispatch
         )

  defp stream_encode_loop(
         _variant,
         [],
         [],
         false,
         mode,
         g1,
         g2,
         g3,
         final?,
         _policy,
         acc,
         _dispatch
       ) do
    suffix = if final? and mode != :ascii, do: <<0x0F>>, else: <<>>
    next_mode = if final?, do: :ascii, else: mode

    {:ok, acc |> :lists.reverse([suffix]) |> IO.iodata_to_binary(), {:cn, next_mode, g1, g2, g3},
     []}
  end

  defp stream_encode_loop(
         variant,
         [codepoint | rest],
         resume,
         replacement?,
         mode,
         g1,
         g2,
         g3,
         final?,
         policy,
         acc,
         dispatch
       )
       when codepoint in 0..0x7F do
    shift = if mode == :ascii, do: <<>>, else: <<0x0F>>
    reset? = codepoint in [?\n, ?\r]

    stream_encode_loop(
      variant,
      rest,
      resume,
      replacement?,
      :ascii,
      if(reset?, do: nil, else: g1),
      if(reset?, do: nil, else: g2),
      if(reset?, do: nil, else: g3),
      final?,
      policy,
      [<<codepoint>>, shift | acc],
      dispatch
    )
  end

  defp stream_encode_loop(
         variant,
         [codepoint | rest],
         resume,
         replacement?,
         mode,
         g1,
         g2,
         g3,
         final?,
         policy,
         acc,
         dispatch
       ) do
    case Map.fetch(dispatch, codepoint) do
      {:ok, {:g1, target, pair}} ->
        designate = if g1 == target, do: <<>>, else: g1_designation(target)
        shift = if mode == :twobyte, do: <<>>, else: <<0x0E>>

        stream_encode_loop(
          variant,
          rest,
          resume,
          replacement?,
          :twobyte,
          target,
          g2,
          g3,
          final?,
          policy,
          [pair, shift, designate | acc],
          dispatch
        )

      {:ok, {:g2, 2, pair}} ->
        designate = if g2 == 2, do: <<>>, else: <<0x1B, "$*H">>

        stream_encode_loop(
          variant,
          rest,
          resume,
          replacement?,
          mode,
          g1,
          2,
          g3,
          final?,
          policy,
          [<<0x1B, ?N, pair::binary>>, designate | acc],
          dispatch
        )

      {:ok, {:g3, plane, pair}} ->
        designate = if g3 == plane, do: <<>>, else: <<0x1B, "$+", plane + 0x46>>

        stream_encode_loop(
          variant,
          rest,
          resume,
          replacement?,
          mode,
          g1,
          g2,
          plane,
          final?,
          policy,
          [<<0x1B, ?O, pair::binary>>, designate | acc],
          dispatch
        )

      :error when replacement? ->
        {:error, :unrepresentable_character, codepoint}

      :error ->
        case policy do
          :error ->
            {:error, :unrepresentable_character, codepoint}

          :discard ->
            stream_encode_loop(
              variant,
              rest,
              resume,
              false,
              mode,
              g1,
              g2,
              g3,
              final?,
              policy,
              acc,
              dispatch
            )

          {:replace, replacer} ->
            stream_encode_loop(
              variant,
              replacer.(codepoint),
              rest,
              true,
              mode,
              g1,
              g2,
              g3,
              final?,
              policy,
              acc,
              dispatch
            )
        end
    end
  end

  defp encode_loop(_variant, [], mode, _g1, _g2, _g3, acc, _discard?, _dispatch) do
    suffix = if mode == :ascii, do: "", else: <<0x0F>>
    {:ok, acc |> :lists.reverse([suffix]) |> IO.iodata_to_binary()}
  end

  defp encode_loop(
         variant,
         [codepoint | rest],
         mode,
         g1,
         g2,
         g3,
         acc,
         discard?,
         dispatch
       )
       when codepoint in 0..0x7F do
    shift = if mode == :ascii, do: "", else: <<0x0F>>
    reset? = codepoint in [?\n, ?\r]

    encode_loop(
      variant,
      rest,
      :ascii,
      if(reset?, do: nil, else: g1),
      if(reset?, do: nil, else: g2),
      if(reset?, do: nil, else: g3),
      [<<codepoint>>, shift | acc],
      discard?,
      dispatch
    )
  end

  defp encode_loop(
         variant,
         [codepoint | rest],
         mode,
         g1,
         g2,
         g3,
         acc,
         discard?,
         dispatch
       ) do
    case Map.fetch(dispatch, codepoint) do
      {:ok, {:g1, target, pair}} ->
        designate = if g1 == target, do: "", else: g1_designation(target)
        shift = if mode == :twobyte, do: "", else: <<0x0E>>

        encode_loop(
          variant,
          rest,
          :twobyte,
          target,
          g2,
          g3,
          [pair, shift, designate | acc],
          discard?,
          dispatch
        )

      {:ok, {:g2, 2, pair}} ->
        designate = if g2 == 2, do: "", else: <<0x1B, "$*H">>

        encode_loop(
          variant,
          rest,
          mode,
          g1,
          2,
          g3,
          [<<0x1B, ?N, pair::binary>>, designate | acc],
          discard?,
          dispatch
        )

      {:ok, {:g3, plane, pair}} ->
        designate = if g3 == plane, do: "", else: <<0x1B, "$+", plane + 0x46>>

        encode_loop(
          variant,
          rest,
          mode,
          g1,
          g2,
          plane,
          [<<0x1B, ?O, pair::binary>>, designate | acc],
          discard?,
          dispatch
        )

      :error when discard? ->
        encode_loop(variant, rest, mode, g1, g2, g3, acc, discard?, dispatch)

      :error ->
        {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_substitute_loop(
         variant,
         [],
         resume,
         true,
         mode,
         g1,
         g2,
         g3,
         acc,
         replacer,
         dispatch
       ),
       do:
         encode_substitute_loop(
           variant,
           resume,
           [],
           false,
           mode,
           g1,
           g2,
           g3,
           acc,
           replacer,
           dispatch
         )

  defp encode_substitute_loop(
         _variant,
         [],
         [],
         false,
         mode,
         _g1,
         _g2,
         _g3,
         acc,
         _replacer,
         _dispatch
       ) do
    suffix = if mode == :ascii, do: "", else: <<0x0F>>
    {:ok, acc |> :lists.reverse([suffix]) |> IO.iodata_to_binary()}
  end

  defp encode_substitute_loop(
         variant,
         [codepoint | rest],
         resume,
         replacement?,
         mode,
         g1,
         g2,
         g3,
         acc,
         replacer,
         dispatch
       )
       when codepoint in 0..0x7F do
    shift = if mode == :ascii, do: "", else: <<0x0F>>
    reset? = codepoint in [?\n, ?\r]

    encode_substitute_loop(
      variant,
      rest,
      resume,
      replacement?,
      :ascii,
      if(reset?, do: nil, else: g1),
      if(reset?, do: nil, else: g2),
      if(reset?, do: nil, else: g3),
      [<<codepoint>>, shift | acc],
      replacer,
      dispatch
    )
  end

  defp encode_substitute_loop(
         variant,
         [codepoint | rest],
         resume,
         replacement?,
         mode,
         g1,
         g2,
         g3,
         acc,
         replacer,
         dispatch
       ) do
    case Map.fetch(dispatch, codepoint) do
      {:ok, {:g1, target, pair}} ->
        designate = if g1 == target, do: "", else: g1_designation(target)
        shift = if mode == :twobyte, do: "", else: <<0x0E>>

        encode_substitute_loop(
          variant,
          rest,
          resume,
          replacement?,
          :twobyte,
          target,
          g2,
          g3,
          [pair, shift, designate | acc],
          replacer,
          dispatch
        )

      {:ok, {:g2, 2, pair}} ->
        designate = if g2 == 2, do: "", else: <<0x1B, "$*H">>

        encode_substitute_loop(
          variant,
          rest,
          resume,
          replacement?,
          mode,
          g1,
          2,
          g3,
          [<<0x1B, ?N, pair::binary>>, designate | acc],
          replacer,
          dispatch
        )

      {:ok, {:g3, plane, pair}} ->
        designate = if g3 == plane, do: "", else: <<0x1B, "$+", plane + 0x46>>

        encode_substitute_loop(
          variant,
          rest,
          resume,
          replacement?,
          mode,
          g1,
          g2,
          plane,
          [<<0x1B, ?O, pair::binary>>, designate | acc],
          replacer,
          dispatch
        )

      :error when replacement? ->
        {:error, :unrepresentable_character, codepoint}

      :error ->
        encode_substitute_loop(
          variant,
          replacer.(codepoint),
          rest,
          true,
          mode,
          g1,
          g2,
          g3,
          acc,
          replacer,
          dispatch
        )
    end
  end

  defp designation(variant, input) do
    choices = if variant == :iso2022_cn_ext, do: @extended_designations, else: @base_designations

    case Enum.find(choices, fn {bytes, _} -> starts_with?(input, bytes) end) do
      {_bytes, action} ->
        action

      nil ->
        if byte_size(input) < 4 and
             Enum.any?(choices, fn {bytes, _} -> starts_with?(bytes, input) end),
           do: :incomplete,
           else: :error
    end
  end

  defp decode_cns(1, first, second),
    do: table_pair(:euc_tw, <<first + 0x80, second + 0x80>>)

  defp decode_cns(plane, first, second),
    do: table_pair(:euc_tw, <<0x8E, plane + 0xA0, first + 0x80, second + 0x80>>)

  defp table_pair(id, pair) do
    case Map.fetch(Tables.fetch!(id).many, pair) do
      {:ok, codepoints} -> {:ok, codepoints}
      :error -> :error
    end
  end

  defp g1_designation(:gb2312), do: <<0x1B, "$)A">>
  defp g1_designation(1), do: <<0x1B, "$)G">>
  defp g1_designation(:iso_ir_165), do: <<0x1B, "$)E">>

  defp starts_with?(binary, prefix) when byte_size(binary) >= byte_size(prefix),
    do: binary_part(binary, 0, byte_size(prefix)) == prefix

  defp starts_with?(_binary, _prefix), do: false

  defp invalid(sequence, offset), do: {:error, :invalid_sequence, offset, sequence}

  defp replace(byte, replacer, acc), do: :lists.reverse(replacer.(byte), acc)
  defp replace_bytes(acc, <<>>, _replacer), do: acc

  defp replace_bytes(acc, <<byte, rest::binary>>, replacer),
    do: replace_bytes(replace(byte, replacer, acc), rest, replacer)

  defp prepend(tuple, acc) when tuple_size(tuple) == 1, do: [elem(tuple, 0) | acc]
  defp prepend(tuple, acc), do: tuple |> Tuple.to_list() |> :lists.reverse(acc)
end

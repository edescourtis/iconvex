defmodule Iconvex.ISO2022JPCodec do
  @moduledoc false

  alias Iconvex.ISO2022JPEncoder
  alias Iconvex.StatefulPairCache
  alias Iconvex.Tables

  @jp_variants ~w(iso2022_jp iso2022_jp1 iso2022_jp2 iso2022_jp3 iso2022_jpms iso2022_jp_ext)a
  @two_byte_modes ~w(jis0208 jis0212 jis0212_pyext gb2312 ksc5601 jis0213_1 jis0213_2 jis0208ms jis0212ms)a
  @base_escapes [
    {<<0x1B, "$@">>, {:mode, :jis0208}},
    {<<0x1B, "$B">>, {:mode, :jis0208}},
    {<<0x1B, "(B">>, {:mode, :ascii}},
    {<<0x1B, "(J">>, {:mode, :roman}}
  ]
  @escapes_by_variant %{
    iso2022_jp: @base_escapes,
    iso2022_jp1: [{<<0x1B, "$(D">>, {:mode, :jis0212}} | @base_escapes],
    iso2022_jp_ext: [
      {<<0x1B, "$(D">>, {:mode, :jis0212_pyext}},
      {<<0x1B, "(I">>, {:mode, :kana}}
      | @base_escapes
    ],
    iso2022_jp2: [
      {<<0x1B, "$(D">>, {:mode, :jis0212}},
      {<<0x1B, "$(C">>, {:mode, :ksc5601}},
      {<<0x1B, "$A">>, {:mode, :gb2312}},
      {<<0x1B, "(I">>, {:mode, :kana}},
      {<<0x1B, ".A">>, {:g2, :iso8859_1}},
      {<<0x1B, ".F">>, {:g2, :iso8859_7}}
      | @base_escapes
    ],
    iso2022_jp3: [
      {<<0x1B, "$(O">>, {:mode, :jis0213_1}},
      {<<0x1B, "$(Q">>, {:mode, :jis0213_1}},
      {<<0x1B, "$(P">>, {:mode, :jis0213_2}},
      {<<0x1B, "(I">>, {:mode, :kana}}
      | @base_escapes
    ],
    iso2022_jpms: [
      {<<0x1B, "$(D">>, {:mode, :jis0212ms}},
      {<<0x1B, "(I">>, {:mode, :kana}},
      {<<0x1B, "$@">>, {:mode, :jis0208ms}},
      {<<0x1B, "$B">>, {:mode, :jis0208ms}},
      {<<0x1B, "(B">>, {:mode, :ascii}},
      {<<0x1B, "(J">>, {:mode, :roman}}
    ]
  }

  def decode(%{id: variant}, input) when variant in @jp_variants do
    Tables.with_conversion_cache(fn -> decode_loop(variant, input, :ascii, nil, 0, []) end)
  end

  def decode_discard(%{id: variant}, input) when variant in @jp_variants do
    Tables.with_conversion_cache(fn ->
      decode_replace_loop(variant, input, :ascii, nil, fn _byte -> [] end, [])
    end)
  end

  def decode_substitute(%{id: variant}, input, replacer)
      when variant in @jp_variants and is_function(replacer, 1) do
    Tables.with_conversion_cache(fn ->
      decode_replace_loop(variant, input, :ascii, nil, replacer, [])
    end)
  end

  @doc false
  def decode_to_explicit_ucs4(%{id: variant}, input, endian)
      when variant in @jp_variants and endian in [:big, :little] do
    Tables.with_conversion_cache(fn ->
      decode_ucs4_loop(
        variant,
        input,
        :ascii,
        nil,
        endian,
        [],
        direct_tables(variant)
      )
    end)
  end

  @doc false
  def encode_from_explicit_ucs4_discard(%{id: variant}, input, endian)
      when variant in @jp_variants and endian in [:big, :little] do
    if rem(byte_size(input), 4) == 0 do
      encode_ucs4_loop(
        variant,
        input,
        endian,
        :ascii,
        initial_encoder_state(variant, nil),
        [],
        ISO2022JPEncoder.fetch(variant)
      )
    else
      :miss
    end
  end

  def encode(%{id: variant}, codepoints) when variant in @jp_variants,
    do:
      encode_loop(
        variant,
        codepoints,
        :ascii,
        initial_encoder_state(variant, nil),
        [],
        false,
        ISO2022JPEncoder.fetch(variant)
      )

  def encode_discard(%{id: variant}, codepoints) when variant in @jp_variants,
    do:
      encode_loop(
        variant,
        codepoints,
        :ascii,
        initial_encoder_state(variant, nil),
        [],
        true,
        ISO2022JPEncoder.fetch(variant)
      )

  def encode_substitute(%{id: variant}, codepoints, replacer)
      when variant in @jp_variants and is_function(replacer, 1),
      do:
        encode_substitute_loop(
          variant,
          codepoints,
          [],
          false,
          :ascii,
          initial_encoder_state(variant, nil),
          [],
          replacer,
          ISO2022JPEncoder.fetch(variant)
        )

  def stream_encode_init(%{id: variant}) when variant in @jp_variants,
    do: {:jp, :ascii, nil}

  def encode_chunk(%{id: variant}, codepoints, {:jp, mode, g2}, final?, policy)
      when variant in @jp_variants do
    encode_chunk_with_state(
      variant,
      codepoints,
      mode,
      initial_encoder_state(variant, g2),
      final?,
      policy
    )
  end

  def encode_chunk(
        %{id: :iso2022_jp2},
        codepoints,
        {:jp, mode, g2, language},
        final?,
        policy
      ) do
    encode_chunk_with_state(
      :iso2022_jp2,
      codepoints,
      mode,
      {:jp2, g2, language},
      final?,
      policy
    )
  end

  defp encode_chunk_with_state(variant, codepoints, mode, encoder_state, final?, policy) do
    dispatch = ISO2022JPEncoder.fetch(variant)

    stream_encode_loop(
      variant,
      codepoints,
      [],
      false,
      mode,
      encoder_state,
      final?,
      policy,
      [],
      dispatch
    )
  end

  defp encode_ucs4_loop(_variant, <<>>, _endian, mode, _g2, acc, _dispatch) do
    suffix = if mode == :ascii, do: <<>>, else: <<0x1B, "(B">>
    {:ok, acc |> :lists.reverse([suffix]) |> IO.iodata_to_binary()}
  end

  defp encode_ucs4_loop(
         variant,
         <<a::unsigned-big-32, b::unsigned-big-32, c::unsigned-big-32, d::unsigned-big-32,
           e::unsigned-big-32, f::unsigned-big-32, g::unsigned-big-32, h::unsigned-big-32,
           i::unsigned-big-32, j::unsigned-big-32, k::unsigned-big-32, l::unsigned-big-32,
           m::unsigned-big-32, n::unsigned-big-32, o::unsigned-big-32, p::unsigned-big-32,
           rest::binary>>,
         :big,
         mode,
         g2,
         acc,
         %{direct_max: maximum} = dispatch
       )
       when a > maximum and b > maximum and c > maximum and d > maximum and e > maximum and
              f > maximum and g > maximum and h > maximum and i > maximum and j > maximum and
              k > maximum and l > maximum and m > maximum and n > maximum and o > maximum and
              p > maximum,
       do: encode_ucs4_loop(variant, rest, :big, mode, g2, acc, dispatch)

  defp encode_ucs4_loop(
         variant,
         <<a::unsigned-little-32, b::unsigned-little-32, c::unsigned-little-32,
           d::unsigned-little-32, e::unsigned-little-32, f::unsigned-little-32,
           g::unsigned-little-32, h::unsigned-little-32, i::unsigned-little-32,
           j::unsigned-little-32, k::unsigned-little-32, l::unsigned-little-32,
           m::unsigned-little-32, n::unsigned-little-32, o::unsigned-little-32,
           p::unsigned-little-32, rest::binary>>,
         :little,
         mode,
         g2,
         acc,
         %{direct_max: maximum} = dispatch
       )
       when a > maximum and b > maximum and c > maximum and d > maximum and e > maximum and
              f > maximum and g > maximum and h > maximum and i > maximum and j > maximum and
              k > maximum and l > maximum and m > maximum and n > maximum and o > maximum and
              p > maximum,
       do: encode_ucs4_loop(variant, rest, :little, mode, g2, acc, dispatch)

  defp encode_ucs4_loop(
         :iso2022_jp2 = variant,
         input,
         endian,
         mode,
         g2,
         acc,
         dispatch
       ) do
    {codepoint, rest} = take_ucs4(input, endian)

    if codepoint in 0xE0000..0xE007F do
      encode_ucs4_loop(
        variant,
        rest,
        endian,
        mode,
        update_language(g2, codepoint),
        acc,
        dispatch
      )
    else
      encode_ucs4_choice(variant, input, endian, mode, g2, acc, dispatch)
    end
  end

  defp encode_ucs4_loop(variant, input, endian, mode, g2, acc, dispatch),
    do: encode_ucs4_choice(variant, input, endian, mode, g2, acc, dispatch)

  defp encode_ucs4_choice(variant, input, endian, mode, g2, acc, dispatch) do
    {codepoint, rest} = take_ucs4(input, endian)
    next_codepoint = ucs4_lookahead(rest, endian)
    g2 = reset_temporary_language(g2)

    case direct_encoder_choose(variant, dispatch, codepoint, next_codepoint, encoder_language(g2)) do
      {:primary, next_mode, bytes, consumed} ->
        designation = if mode == next_mode, do: <<>>, else: designation(next_mode)
        next_g2 = if codepoint in [?\n, ?\r], do: clear_encoder_g2(g2), else: g2

        encode_ucs4_loop(
          variant,
          drop_ucs4(input, consumed),
          endian,
          next_mode,
          next_g2,
          [bytes, designation | acc],
          dispatch
        )

      {:g2, next_g2, byte} ->
        designation =
          if encoder_g2(g2) == next_g2, do: <<>>, else: g2_designation(next_g2)

        encode_ucs4_loop(
          variant,
          rest,
          endian,
          mode,
          put_encoder_g2(g2, next_g2),
          [<<0x1B, ?N, byte>>, designation | acc],
          dispatch
        )

      :error ->
        encode_ucs4_loop(variant, rest, endian, mode, g2, acc, dispatch)
    end
  end

  defp take_ucs4(<<codepoint::unsigned-big-32, rest::binary>>, :big),
    do: {codepoint, rest}

  defp take_ucs4(<<codepoint::unsigned-little-32, rest::binary>>, :little),
    do: {codepoint, rest}

  defp ucs4_lookahead(<<>>, _endian), do: []
  defp ucs4_lookahead(input, endian), do: elem(take_ucs4(input, endian), 0)

  defp direct_encoder_choose(:iso2022_jp2, dispatch, codepoint, next_codepoint, language) do
    codepoints =
      case next_codepoint do
        [] -> [codepoint]
        next -> [codepoint, next]
      end

    ISO2022JPEncoder.choose(dispatch, codepoints, language)
  end

  defp direct_encoder_choose(_variant, _dispatch, codepoint, _next, _language)
       when codepoint in 0..0x7F,
       do: {:primary, :ascii, <<codepoint>>, 1}

  defp direct_encoder_choose(_variant, dispatch, codepoint, next_codepoint, _language) do
    pair =
      case next_codepoint do
        [] -> :error
        next -> Map.fetch(dispatch.pairs, {codepoint, next})
      end

    case pair do
      {:ok, {mode, bytes}} ->
        {:primary, mode, bytes, 2}

      :error ->
        case Map.fetch(dispatch.singles, codepoint) do
          {:ok, {:primary, mode, bytes}} -> {:primary, mode, bytes, 1}
          {:ok, {:g2, id, byte}} -> {:g2, id, byte}
          :error -> :error
        end
    end
  end

  defp drop_ucs4(input, count),
    do: binary_part(input, count * 4, byte_size(input) - count * 4)

  defp decode_ucs4_loop(_variant, <<>>, _mode, _g2, _endian, acc, _tables),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp decode_ucs4_loop(
         :iso2022_jp2 = variant,
         <<0x1B, ?N, byte, rest::binary>>,
         mode,
         g2,
         endian,
         acc,
         tables
       )
       when not is_nil(g2) and byte < 0x80 do
    case direct_decode_g2(g2, byte, tables) do
      {:ok, codepoint} ->
        decode_ucs4_loop(
          variant,
          rest,
          mode,
          g2,
          endian,
          [ucs4(codepoint, endian) | acc],
          tables
        )

      :error ->
        decode_ucs4_loop(
          variant,
          <<?N, byte, rest::binary>>,
          mode,
          g2,
          endian,
          acc,
          tables
        )
    end
  end

  defp decode_ucs4_loop(variant, <<0x1B, _::binary>> = input, mode, g2, endian, acc, tables) do
    case escape(variant, input) do
      {:mode, next_mode, count} ->
        <<_::binary-size(count), rest::binary>> = input
        decode_ucs4_loop(variant, rest, next_mode, g2, endian, acc, tables)

      {:g2, next_g2, count} ->
        <<_::binary-size(count), rest::binary>> = input
        decode_ucs4_loop(variant, rest, mode, next_g2, endian, acc, tables)

      :incomplete ->
        {:ok, finish_ucs4(acc)}

      :error ->
        <<_discarded_escape, rest::binary>> = input
        decode_ucs4_loop(variant, rest, mode, g2, endian, acc, tables)
    end
  end

  defp decode_ucs4_loop(
         :iso2022_jpms = variant,
         <<0x0E, rest::binary>>,
         :roman,
         g2,
         endian,
         acc,
         tables
       ),
       do: decode_ucs4_loop(variant, rest, :kana, g2, endian, acc, tables)

  defp decode_ucs4_loop(
         :iso2022_jpms = variant,
         <<0x0F, rest::binary>>,
         :kana,
         g2,
         endian,
         acc,
         tables
       ),
       do: decode_ucs4_loop(variant, rest, :roman, g2, endian, acc, tables)

  defp decode_ucs4_loop(
         :iso2022_jpms = variant,
         <<byte, rest::binary>>,
         mode,
         g2,
         endian,
         acc,
         tables
       )
       when byte in [0x0E, 0x0F],
       do: decode_ucs4_loop(variant, rest, mode, g2, endian, acc, tables)

  defp decode_ucs4_loop(
         :iso2022_jp_ext = variant,
         <<byte, rest::binary>>,
         mode,
         g2,
         endian,
         acc,
         tables
       )
       when byte in 0x00..0x1A or byte in 0x1C..0x1F,
       do:
         decode_ucs4_loop(
           variant,
           rest,
           mode,
           g2,
           endian,
           [ucs4(byte, endian) | acc],
           tables
         )

  defp decode_ucs4_loop(
         variant,
         <<byte, rest::binary>>,
         mode,
         g2,
         endian,
         acc,
         tables
       )
       when mode in [:ascii, :roman, :kana] and byte < 0x80 do
    case direct_decode_single(mode, byte, tables) do
      {:ok, codepoint} ->
        decode_ucs4_loop(
          variant,
          rest,
          mode,
          g2,
          endian,
          [ucs4(codepoint, endian) | acc],
          tables
        )

      :error ->
        decode_ucs4_loop(variant, rest, mode, g2, endian, acc, tables)
    end
  end

  defp decode_ucs4_loop(_variant, input, mode, _g2, _endian, acc, _tables)
       when mode in @two_byte_modes and byte_size(input) < 2,
       do: {:ok, finish_ucs4(acc)}

  defp decode_ucs4_loop(
         variant,
         <<first, second, rest::binary>>,
         mode,
         g2,
         endian,
         acc,
         tables
       )
       when mode in @two_byte_modes and first < 0x80 and second < 0x80 do
    case direct_decode_pair(mode, first, second, tables) do
      {:ok, codepoints} ->
        decode_ucs4_loop(
          variant,
          rest,
          mode,
          g2,
          endian,
          [ucs4_tuple(codepoints, endian) | acc],
          tables
        )

      {:encoded, bytes} ->
        decode_ucs4_loop(
          variant,
          rest,
          mode,
          g2,
          endian,
          [select_endian(bytes, endian) | acc],
          tables
        )

      :error ->
        decode_ucs4_loop(
          variant,
          <<second, rest::binary>>,
          mode,
          g2,
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
         g2,
         endian,
         acc,
         tables
       ),
       do: decode_ucs4_loop(variant, rest, mode, g2, endian, acc, tables)

  defp direct_tables(variant) do
    {jisx0208_table, jisx0208_identity} = Tables.fetch_with_identity!(%{id: :jisx0208})
    jisx0208 = jisx0208_table.many

    base = %{
      jisx0208: jisx0208,
      jisx0208_dense: StatefulPairCache.seven_bit(:jisx0208, jisx0208, jisx0208_identity)
    }

    case variant do
      :iso2022_jp ->
        base

      :iso2022_jp1 ->
        add_direct_table(base, :jisx0212)

      :iso2022_jp_ext ->
        base
        |> add_direct_table(:jisx0212)
        |> Map.put(:jisx0201, Tables.fetch!(:jisx0201).one)

      :iso2022_jp2 ->
        base
        |> add_direct_table(:jisx0212)
        |> add_direct_table(:gb2312)
        |> add_direct_table(:ksc5601)
        |> Map.put(:jisx0201, Tables.fetch!(:jisx0201).one)
        |> Map.put(:iso8859_1, Tables.fetch!(:iso8859_1).one)
        |> Map.put(:iso8859_7, Tables.fetch!(:iso8859_7).one)

      :iso2022_jp3 ->
        {euc_jisx0213_table, euc_jisx0213_identity} =
          Tables.fetch_with_identity!(%{id: :euc_jisx0213})

        euc_jisx0213 = euc_jisx0213_table.many

        base
        |> Map.put(:euc_jisx0213, euc_jisx0213)
        |> Map.put(
          :jis0213_dense,
          StatefulPairCache.euc_jisx0213_planes(euc_jisx0213, euc_jisx0213_identity)
        )
        |> Map.put(:jisx0201, Tables.fetch!(:jisx0201).one)

      :iso2022_jpms ->
        base
        |> add_direct_table(:jisx0212)
        |> Map.put(:jisx0201, Tables.fetch!(:jisx0201).one)
        |> Map.put(:cp50221_0208_ext, Tables.fetch!(:cp50221_0208_ext).decode)
        |> Map.put(:cp50221_0212_ext, Tables.fetch!(:cp50221_0212_ext).decode)
        |> Map.put(:cp932, Tables.fetch!(:cp932).many)
    end
  end

  defp add_direct_table(tables, id) do
    {table, identity} = Tables.fetch_with_identity!(%{id: id})
    source = table.many

    tables
    |> Map.put(id, source)
    |> Map.put(dense_key(id), StatefulPairCache.seven_bit(id, source, identity))
  end

  defp dense_key(:jisx0212), do: :jisx0212_dense
  defp dense_key(:gb2312), do: :gb2312_dense
  defp dense_key(:ksc5601), do: :ksc5601_dense

  defp direct_decode_single(:ascii, byte, _tables), do: {:ok, byte}
  defp direct_decode_single(:roman, 0x5C, _tables), do: {:ok, 0x00A5}
  defp direct_decode_single(:roman, 0x7E, _tables), do: {:ok, 0x203E}
  defp direct_decode_single(:roman, byte, _tables), do: {:ok, byte}

  defp direct_decode_single(:kana, byte, %{jisx0201: one}) when byte in 0x21..0x5F do
    case elem(one, byte + 0x80) do
      nil -> :error
      codepoints -> {:ok, elem(codepoints, 0)}
    end
  end

  defp direct_decode_single(:kana, _byte, _tables), do: :error

  defp direct_decode_g2(id, byte, tables) do
    case elem(Map.fetch!(tables, id), byte + 0x80) do
      nil -> :error
      codepoints -> {:ok, elem(codepoints, 0)}
    end
  end

  defp direct_decode_pair(:jis0208, first, second, %{jisx0208_dense: dense}),
    do: direct_dense_endians(dense, first, second)

  defp direct_decode_pair(:jis0212, first, second, %{jisx0212_dense: dense}),
    do: direct_dense_endians(dense, first, second)

  defp direct_decode_pair(:jis0212_pyext, 0x22, 0x37, _tables), do: {:ok, {0x007E}}

  defp direct_decode_pair(:jis0212_pyext, first, second, %{jisx0212_dense: dense}),
    do: direct_dense_endians(dense, first, second)

  defp direct_decode_pair(:gb2312, first, second, %{gb2312_dense: dense}),
    do: direct_dense_endians(dense, first, second)

  defp direct_decode_pair(:ksc5601, first, second, %{ksc5601_dense: dense}),
    do: direct_dense_endians(dense, first, second)

  defp direct_decode_pair(:jis0213_1, first, second, %{jis0213_dense: {plane1, _plane2}}),
    do: direct_dense_pair(plane1, first, second)

  defp direct_decode_pair(:jis0213_2, first, second, %{jis0213_dense: {_plane1, plane2}}),
    do: direct_dense_pair(plane2, first, second)

  defp direct_decode_pair(:jis0208ms, 0x2D, cell, %{cp50221_0208_ext: map})
       when cell in 0x21..0x79 do
    case Map.fetch(map, cell - 0x21 + 1) do
      {:ok, codepoint} -> {:ok, {codepoint}}
      :error -> :error
    end
  end

  defp direct_decode_pair(:jis0208ms, row, cell, %{jisx0208_dense: dense}) when row < 0x75,
    do: direct_dense_endians(dense, row, cell)

  defp direct_decode_pair(:jis0208ms, row, cell, tables)
       when row in 0x75..0x7E and cell in 0x21..0x7E do
    cp932 =
      with true <- row in 0x79..0x7C,
           {:ok, bytes} <- jis_to_sjis(<<row, cell>>),
           {:ok, codepoints} <- Map.fetch(tables.cp932, bytes) do
        {:ok, codepoints}
      else
        _not_cp932 -> :error
      end

    case cp932 do
      {:ok, _codepoints} = result -> result
      :error -> {:ok, {0xE000 + (row - 0x75) * 94 + cell - 0x21}}
    end
  end

  defp direct_decode_pair(:jis0208ms, _row, _cell, _tables), do: :error

  defp direct_decode_pair(:jis0212ms, row, cell, %{jisx0212_dense: dense}) when row < 0x73,
    do: direct_dense_endians(dense, row, cell)

  defp direct_decode_pair(:jis0212ms, row, cell, %{cp50221_0212_ext: map})
       when row in 0x73..0x74 and cell in 0x21..0x7E do
    case Map.fetch(map, (row - 0x73) * 94 + (cell - 0x21) + 1) do
      {:ok, codepoint} -> {:ok, {codepoint}}
      :error -> :error
    end
  end

  defp direct_decode_pair(:jis0212ms, row, cell, _tables)
       when row in 0x75..0x7E and cell in 0x21..0x7E,
       do: {:ok, {0xE3AC + (row - 0x75) * 94 + cell - 0x21}}

  defp direct_decode_pair(:jis0212ms, _row, _cell, _tables), do: :error

  defp direct_dense_endians(dense, first, second) do
    case StatefulPairCache.lookup_endians(dense, first, second) do
      {:ok, endians} -> {:encoded, endians}
      :error -> :error
    end
  end

  defp direct_dense_pair(dense, first, second)
       when first in 0x21..0x7E and second in 0x21..0x7E do
    case elem(dense, (first - 0x21) * 94 + second - 0x21) do
      nil -> :error
      encoded -> {:encoded, encoded}
    end
  end

  defp select_endian({big, _little}, :big), do: big
  defp select_endian({_big, little}, :little), do: little

  defp ucs4(codepoint, :big), do: <<codepoint::unsigned-big-32>>
  defp ucs4(codepoint, :little), do: <<codepoint::unsigned-little-32>>

  defp ucs4_tuple(tuple, endian),
    do: tuple |> Tuple.to_list() |> Enum.map(&ucs4(&1, endian))

  defp finish_ucs4(acc), do: acc |> :lists.reverse() |> IO.iodata_to_binary()

  defp decode_loop(_variant, <<>>, _mode, _g2, _offset, acc),
    do: {:ok, :lists.reverse(acc)}

  defp decode_loop(
         :iso2022_jp2 = variant,
         <<0x1B, ?N, byte, rest::binary>>,
         mode,
         g2,
         offset,
         acc
       )
       when not is_nil(g2) and byte < 0x80 do
    case decode_g2(g2, byte) do
      {:ok, codepoint} -> decode_loop(variant, rest, mode, g2, offset + 3, [codepoint | acc])
      :error -> invalid(<<0x1B, ?N, byte>>, offset)
    end
  end

  defp decode_loop(
         :iso2022_jp2,
         <<0x1B, ?N>> = input,
         _mode,
         g2,
         offset,
         _acc
       )
       when not is_nil(g2),
       do: {:error, :incomplete_sequence, offset, input}

  defp decode_loop(variant, <<0x1B, _::binary>> = input, mode, g2, offset, acc) do
    case escape(variant, input) do
      {:mode, next_mode, count} ->
        <<_::binary-size(count), rest::binary>> = input
        decode_loop(variant, rest, next_mode, g2, offset + count, acc)

      {:g2, next_g2, count} ->
        <<_::binary-size(count), rest::binary>> = input
        decode_loop(variant, rest, mode, next_g2, offset + count, acc)

      :incomplete ->
        {:error, :incomplete_sequence, offset, input}

      :error ->
        invalid(binary_part(input, 0, min(4, byte_size(input))), offset)
    end
  end

  defp decode_loop(:iso2022_jpms = variant, <<0x0E, rest::binary>>, :roman, g2, offset, acc),
    do: decode_loop(variant, rest, :kana, g2, offset + 1, acc)

  defp decode_loop(:iso2022_jpms = variant, <<0x0F, rest::binary>>, :kana, g2, offset, acc),
    do: decode_loop(variant, rest, :roman, g2, offset + 1, acc)

  defp decode_loop(:iso2022_jpms = variant, <<byte, rest::binary>>, mode, g2, offset, acc)
       when byte in [0x0E, 0x0F] do
    decode_loop(variant, rest, mode, g2, offset + 1, acc)
  end

  defp decode_loop(
         :iso2022_jp_ext = variant,
         <<byte, rest::binary>>,
         mode,
         g2,
         offset,
         acc
       )
       when byte in 0x00..0x1A or byte in 0x1C..0x1F do
    decode_loop(variant, rest, mode, g2, offset + 1, [byte | acc])
  end

  defp decode_loop(variant, <<byte, rest::binary>>, mode, g2, offset, acc)
       when mode in [:ascii, :roman, :kana] and byte < 0x80 do
    case decode_single(mode, byte) do
      {:ok, codepoint} -> decode_loop(variant, rest, mode, g2, offset + 1, [codepoint | acc])
      :error -> invalid(<<byte>>, offset)
    end
  end

  defp decode_loop(_variant, input, mode, _g2, offset, _acc)
       when mode in @two_byte_modes and byte_size(input) < 2,
       do: {:error, :incomplete_sequence, offset, input}

  defp decode_loop(variant, <<first, second, rest::binary>>, mode, g2, offset, acc)
       when mode in @two_byte_modes and first < 0x80 and second < 0x80 do
    pair = <<first, second>>

    case decode_pair(mode, pair) do
      {:ok, codepoints} ->
        decode_loop(variant, rest, mode, g2, offset + 2, prepend(codepoints, acc))

      :error ->
        invalid(pair, offset)
    end
  end

  defp decode_loop(_variant, input, _mode, _g2, offset, _acc),
    do: invalid(binary_part(input, 0, min(2, byte_size(input))), offset)

  defp decode_replace_loop(_variant, <<>>, _mode, _g2, _replacer, acc),
    do: {:ok, :lists.reverse(acc)}

  defp decode_replace_loop(
         :iso2022_jp2 = variant,
         <<0x1B, ?N, byte, rest::binary>>,
         mode,
         g2,
         replacer,
         acc
       )
       when not is_nil(g2) and byte < 0x80 do
    case decode_g2(g2, byte) do
      {:ok, codepoint} ->
        decode_replace_loop(variant, rest, mode, g2, replacer, [codepoint | acc])

      :error ->
        decode_replace_loop(
          variant,
          <<?N, byte, rest::binary>>,
          mode,
          g2,
          replacer,
          replace(0x1B, replacer, acc)
        )
    end
  end

  defp decode_replace_loop(variant, <<0x1B, _::binary>> = input, mode, g2, replacer, acc) do
    case escape(variant, input) do
      {:mode, next_mode, count} ->
        <<_::binary-size(count), rest::binary>> = input
        decode_replace_loop(variant, rest, next_mode, g2, replacer, acc)

      {:g2, next_g2, count} ->
        <<_::binary-size(count), rest::binary>> = input
        decode_replace_loop(variant, rest, mode, next_g2, replacer, acc)

      :incomplete ->
        {:ok, acc |> replace_bytes(input, replacer) |> :lists.reverse()}

      :error ->
        <<byte, rest::binary>> = input
        decode_replace_loop(variant, rest, mode, g2, replacer, replace(byte, replacer, acc))
    end
  end

  defp decode_replace_loop(
         :iso2022_jpms = variant,
         <<0x0E, rest::binary>>,
         :roman,
         g2,
         replacer,
         acc
       ),
       do: decode_replace_loop(variant, rest, :kana, g2, replacer, acc)

  defp decode_replace_loop(
         :iso2022_jpms = variant,
         <<0x0F, rest::binary>>,
         :kana,
         g2,
         replacer,
         acc
       ),
       do: decode_replace_loop(variant, rest, :roman, g2, replacer, acc)

  defp decode_replace_loop(
         :iso2022_jpms = variant,
         <<byte, rest::binary>>,
         mode,
         g2,
         replacer,
         acc
       )
       when byte in [0x0E, 0x0F],
       do: decode_replace_loop(variant, rest, mode, g2, replacer, acc)

  defp decode_replace_loop(
         :iso2022_jp_ext = variant,
         <<byte, rest::binary>>,
         mode,
         g2,
         replacer,
         acc
       )
       when byte in 0x00..0x1A or byte in 0x1C..0x1F do
    decode_replace_loop(variant, rest, mode, g2, replacer, [byte | acc])
  end

  defp decode_replace_loop(variant, <<byte, rest::binary>>, mode, g2, replacer, acc)
       when mode in [:ascii, :roman, :kana] and byte < 0x80 do
    case decode_single(mode, byte) do
      {:ok, codepoint} ->
        decode_replace_loop(variant, rest, mode, g2, replacer, [codepoint | acc])

      :error ->
        decode_replace_loop(variant, rest, mode, g2, replacer, replace(byte, replacer, acc))
    end
  end

  defp decode_replace_loop(_variant, input, _mode, _g2, replacer, acc)
       when byte_size(input) < 2,
       do: {:ok, acc |> replace_bytes(input, replacer) |> :lists.reverse()}

  defp decode_replace_loop(
         variant,
         <<first, second, rest::binary>> = input,
         mode,
         g2,
         replacer,
         acc
       )
       when mode in @two_byte_modes and first < 0x80 and second < 0x80 do
    case decode_pair(mode, <<first, second>>) do
      {:ok, codepoints} ->
        decode_replace_loop(variant, rest, mode, g2, replacer, prepend(codepoints, acc))

      :error ->
        <<byte, tail::binary>> = input
        decode_replace_loop(variant, tail, mode, g2, replacer, replace(byte, replacer, acc))
    end
  end

  defp decode_replace_loop(variant, <<byte, rest::binary>>, mode, g2, replacer, acc),
    do: decode_replace_loop(variant, rest, mode, g2, replacer, replace(byte, replacer, acc))

  defp stream_encode_loop(
         variant,
         [],
         resume,
         true,
         mode,
         g2,
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
           g2,
           final?,
           policy,
           acc,
           dispatch
         )

  defp stream_encode_loop(
         variant,
         [],
         [],
         false,
         mode,
         g2,
         final?,
         _policy,
         acc,
         _dispatch
       ) do
    suffix = if final? and mode != :ascii, do: <<0x1B, "(B">>, else: <<>>
    next_mode = if final?, do: :ascii, else: mode

    {:ok, acc |> :lists.reverse([suffix]) |> IO.iodata_to_binary(),
     stream_encoder_state(variant, next_mode, g2), []}
  end

  defp stream_encode_loop(
         variant,
         [codepoint],
         [],
         false,
         mode,
         g2,
         false,
         _policy,
         acc,
         %{pairs: pairs}
       )
       when map_size(pairs) > 0,
       do:
         {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary(),
          stream_encoder_state(variant, mode, g2), [codepoint]}

  defp stream_encode_loop(
         :iso2022_jp2 = variant,
         [codepoint | rest],
         resume,
         replacement?,
         mode,
         g2,
         final?,
         policy,
         acc,
         dispatch
       )
       when codepoint in 0xE0000..0xE007F do
    stream_encode_loop(
      variant,
      rest,
      resume,
      replacement?,
      mode,
      update_language(g2, codepoint),
      final?,
      policy,
      acc,
      dispatch
    )
  end

  defp stream_encode_loop(
         variant,
         codepoints,
         resume,
         replacement?,
         mode,
         g2,
         final?,
         policy,
         acc,
         dispatch
       ) do
    g2 = reset_temporary_language(g2)

    case ISO2022JPEncoder.choose(dispatch, codepoints, encoder_language(g2)) do
      {:primary, next_mode, bytes, consumed} ->
        designation = if mode == next_mode, do: <<>>, else: designation(next_mode)
        next_g2 = if hd(codepoints) in [?\n, ?\r], do: clear_encoder_g2(g2), else: g2

        stream_encode_loop(
          variant,
          drop_codepoints(codepoints, consumed),
          resume,
          replacement?,
          next_mode,
          next_g2,
          final?,
          policy,
          [bytes, designation | acc],
          dispatch
        )

      {:g2, next_g2, byte} ->
        designation =
          if encoder_g2(g2) == next_g2, do: <<>>, else: g2_designation(next_g2)

        stream_encode_loop(
          variant,
          tl(codepoints),
          resume,
          replacement?,
          mode,
          put_encoder_g2(g2, next_g2),
          final?,
          policy,
          [<<0x1B, ?N, byte>>, designation | acc],
          dispatch
        )

      :error when replacement? ->
        {:error, :unrepresentable_character, hd(codepoints)}

      :error ->
        case policy do
          :error ->
            {:error, :unrepresentable_character, hd(codepoints)}

          :discard ->
            stream_encode_loop(
              variant,
              tl(codepoints),
              resume,
              false,
              mode,
              g2,
              final?,
              policy,
              acc,
              dispatch
            )

          {:replace, replacer} ->
            stream_encode_loop(
              variant,
              replacer.(hd(codepoints)),
              tl(codepoints),
              true,
              mode,
              g2,
              final?,
              policy,
              acc,
              dispatch
            )
        end
    end
  end

  defp encode_loop(_variant, [], mode, _g2, acc, _discard?, _dispatch) do
    suffix = if mode == :ascii, do: "", else: <<0x1B, "(B">>
    {:ok, acc |> :lists.reverse([suffix]) |> IO.iodata_to_binary()}
  end

  defp encode_loop(
         :iso2022_jp2 = variant,
         [codepoint | rest],
         mode,
         g2,
         acc,
         discard?,
         dispatch
       )
       when codepoint in 0xE0000..0xE007F do
    encode_loop(variant, rest, mode, update_language(g2, codepoint), acc, discard?, dispatch)
  end

  defp encode_loop(variant, codepoints, mode, g2, acc, discard?, dispatch) do
    g2 = reset_temporary_language(g2)

    case ISO2022JPEncoder.choose(dispatch, codepoints, encoder_language(g2)) do
      {:primary, next_mode, bytes, consumed} ->
        designation = if mode == next_mode, do: "", else: designation(next_mode)
        next_g2 = if hd(codepoints) in [?\n, ?\r], do: clear_encoder_g2(g2), else: g2

        encode_loop(
          variant,
          drop_codepoints(codepoints, consumed),
          next_mode,
          next_g2,
          [bytes, designation | acc],
          discard?,
          dispatch
        )

      {:g2, next_g2, byte} ->
        designation =
          if encoder_g2(g2) == next_g2, do: "", else: g2_designation(next_g2)

        encode_loop(
          variant,
          tl(codepoints),
          mode,
          put_encoder_g2(g2, next_g2),
          [<<0x1B, ?N, byte>>, designation | acc],
          discard?,
          dispatch
        )

      :error when discard? ->
        encode_loop(variant, tl(codepoints), mode, g2, acc, discard?, dispatch)

      :error ->
        {:error, :unrepresentable_character, hd(codepoints)}
    end
  end

  defp encode_substitute_loop(
         variant,
         [],
         resume,
         true,
         mode,
         g2,
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
           g2,
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
         _g2,
         acc,
         _replacer,
         _dispatch
       ) do
    suffix = if mode == :ascii, do: "", else: <<0x1B, "(B">>
    {:ok, acc |> :lists.reverse([suffix]) |> IO.iodata_to_binary()}
  end

  defp encode_substitute_loop(
         :iso2022_jp2 = variant,
         [codepoint | rest],
         resume,
         replacement?,
         mode,
         g2,
         acc,
         replacer,
         dispatch
       )
       when codepoint in 0xE0000..0xE007F do
    encode_substitute_loop(
      variant,
      rest,
      resume,
      replacement?,
      mode,
      update_language(g2, codepoint),
      acc,
      replacer,
      dispatch
    )
  end

  defp encode_substitute_loop(
         variant,
         codepoints,
         resume,
         replacement?,
         mode,
         g2,
         acc,
         replacer,
         dispatch
       ) do
    g2 = reset_temporary_language(g2)

    case ISO2022JPEncoder.choose(dispatch, codepoints, encoder_language(g2)) do
      {:primary, next_mode, bytes, consumed} ->
        designation = if mode == next_mode, do: "", else: designation(next_mode)
        next_g2 = if hd(codepoints) in [?\n, ?\r], do: clear_encoder_g2(g2), else: g2

        encode_substitute_loop(
          variant,
          drop_codepoints(codepoints, consumed),
          resume,
          replacement?,
          next_mode,
          next_g2,
          [bytes, designation | acc],
          replacer,
          dispatch
        )

      {:g2, next_g2, byte} ->
        designation =
          if encoder_g2(g2) == next_g2, do: "", else: g2_designation(next_g2)

        encode_substitute_loop(
          variant,
          tl(codepoints),
          resume,
          replacement?,
          mode,
          put_encoder_g2(g2, next_g2),
          [<<0x1B, ?N, byte>>, designation | acc],
          replacer,
          dispatch
        )

      :error when replacement? ->
        {:error, :unrepresentable_character, hd(codepoints)}

      :error ->
        encode_substitute_loop(
          variant,
          replacer.(hd(codepoints)),
          tl(codepoints),
          true,
          mode,
          g2,
          acc,
          replacer,
          dispatch
        )
    end
  end

  defp escape(variant, input) do
    candidates = escapes(variant)

    case Enum.find(candidates, fn {bytes, _action} -> binary_starts_with?(input, bytes) end) do
      {bytes, {:mode, mode}} ->
        {:mode, mode, byte_size(bytes)}

      {bytes, {:g2, g2}} ->
        {:g2, g2, byte_size(bytes)}

      nil ->
        if Enum.any?(candidates, fn {bytes, _} -> binary_starts_with?(bytes, input) end),
          do: :incomplete,
          else: :error
    end
  end

  defp escapes(variant), do: Map.fetch!(@escapes_by_variant, variant)

  defp decode_single(:ascii, byte), do: {:ok, byte}
  defp decode_single(:roman, 0x5C), do: {:ok, 0x00A5}
  defp decode_single(:roman, 0x7E), do: {:ok, 0x203E}
  defp decode_single(:roman, byte), do: {:ok, byte}

  defp decode_single(:kana, byte) when byte in 0x21..0x5F do
    case elem(Tables.fetch!(:jisx0201).one, byte + 0x80) do
      nil -> :error
      codepoints -> {:ok, elem(codepoints, 0)}
    end
  end

  defp decode_single(:kana, _byte), do: :error

  defp decode_pair(:jis0208, pair), do: table_pair(:jisx0208, pair)
  defp decode_pair(:jis0212, pair), do: table_pair(:jisx0212, pair)
  defp decode_pair(:jis0212_pyext, <<0x22, 0x37>>), do: {:ok, {0x007E}}
  defp decode_pair(:jis0212_pyext, pair), do: table_pair(:jisx0212, pair)
  defp decode_pair(:gb2312, pair), do: table_pair(:gb2312, pair)
  defp decode_pair(:ksc5601, pair), do: table_pair(:ksc5601, pair)

  defp decode_pair(:jis0213_1, <<first, second>>),
    do: table_pair(:euc_jisx0213, <<first + 0x80, second + 0x80>>)

  defp decode_pair(:jis0213_2, <<first, second>>),
    do: table_pair(:euc_jisx0213, <<0x8F, first + 0x80, second + 0x80>>)

  defp decode_pair(:jis0208ms, <<0x2D, cell>>) when cell in 0x21..0x79 do
    index = cell - 0x21 + 1

    case Map.fetch(Tables.fetch!(:cp50221_0208_ext).decode, index) do
      {:ok, codepoint} -> {:ok, {codepoint}}
      :error -> :error
    end
  end

  defp decode_pair(:jis0208ms, <<row, _cell>> = pair) when row < 0x75,
    do: decode_pair(:jis0208, pair)

  defp decode_pair(:jis0208ms, <<row, cell>> = pair)
       when row in 0x75..0x7E and cell in 0x21..0x7E do
    case if(row in 0x79..0x7C, do: ms_cp932_pair(pair), else: :error) do
      {:ok, _} = result -> result
      :error -> {:ok, {0xE000 + (row - 0x75) * 94 + cell - 0x21}}
    end
  end

  defp decode_pair(:jis0208ms, _pair), do: :error

  defp decode_pair(:jis0212ms, <<row, _cell>> = pair) when row < 0x73,
    do: decode_pair(:jis0212, pair)

  defp decode_pair(:jis0212ms, <<row, cell>>)
       when row in 0x73..0x74 and cell in 0x21..0x7E do
    index = (row - 0x73) * 94 + (cell - 0x21) + 1

    case Map.fetch(Tables.fetch!(:cp50221_0212_ext).decode, index) do
      {:ok, codepoint} -> {:ok, {codepoint}}
      :error -> :error
    end
  end

  defp decode_pair(:jis0212ms, <<row, cell>>) when row in 0x75..0x7E and cell in 0x21..0x7E,
    do: {:ok, {0xE3AC + (row - 0x75) * 94 + cell - 0x21}}

  defp decode_pair(:jis0212ms, _pair), do: :error

  defp table_pair(id, pair) do
    case Map.fetch(Tables.fetch!(id).many, pair) do
      {:ok, codepoints} -> {:ok, codepoints}
      :error -> :error
    end
  end

  defp decode_g2(id, byte) do
    case elem(Tables.fetch!(id).one, byte + 0x80) do
      nil -> :error
      codepoints -> {:ok, elem(codepoints, 0)}
    end
  end

  defp designation(:ascii), do: <<0x1B, "(B">>
  defp designation(:roman), do: <<0x1B, "(J">>
  defp designation(:kana), do: <<0x1B, "(I">>
  defp designation(:jis0208), do: <<0x1B, "$B">>
  defp designation(:jis0212), do: <<0x1B, "$(D">>
  defp designation(:jis0212_pyext), do: <<0x1B, "$(D">>
  defp designation(:gb2312), do: <<0x1B, "$A">>
  defp designation(:ksc5601), do: <<0x1B, "$(C">>
  defp designation(:jis0213_1), do: <<0x1B, "$(Q">>
  defp designation(:jis0213_2), do: <<0x1B, "$(P">>
  defp designation(:jis0208ms), do: <<0x1B, "$B">>
  defp designation(:jis0212ms), do: <<0x1B, "$(D">>

  defp g2_designation(:iso8859_1), do: <<0x1B, ".A">>
  defp g2_designation(:iso8859_7), do: <<0x1B, ".F">>

  defp initial_encoder_state(:iso2022_jp2, g2), do: {:jp2, g2, :none}
  defp initial_encoder_state(_variant, g2), do: g2

  defp stream_encoder_state(:iso2022_jp2, mode, {:jp2, g2, :none}),
    do: {:jp, mode, g2}

  defp stream_encoder_state(:iso2022_jp2, mode, {:jp2, g2, language}),
    do: {:jp, mode, g2, language}

  defp stream_encoder_state(_variant, mode, g2), do: {:jp, mode, g2}

  defp encoder_language({:jp2, _g2, language}), do: language
  defp encoder_language(_state), do: :none

  defp encoder_g2({:jp2, g2, _language}), do: g2
  defp encoder_g2(g2), do: g2

  defp put_encoder_g2({:jp2, _g2, language}, g2), do: {:jp2, g2, language}
  defp put_encoder_g2(_current, g2), do: g2

  defp clear_encoder_g2({:jp2, _g2, language}), do: {:jp2, nil, language}
  defp clear_encoder_g2(_g2), do: nil

  defp reset_temporary_language({:jp2, g2, language})
       when language in [:start, :j, :k, :z],
       do: {:jp2, g2, :none}

  defp reset_temporary_language(state), do: state

  defp update_language({:jp2, g2, _language}, 0xE0001), do: {:jp2, g2, :start}
  defp update_language({:jp2, g2, _language}, 0xE007F), do: {:jp2, g2, :none}

  defp update_language({:jp2, g2, language}, codepoint)
       when codepoint in 0xE0000..0xE007F do
    tag = codepoint - 0xE0000
    tag = if tag in ?A..?Z, do: tag + (?a - ?A), else: tag

    next_language =
      case {language, tag} do
        {:start, ?j} -> :j
        {:j, ?a} -> :ja
        {:start, ?k} -> :k
        {:k, ?o} -> :ko
        {:start, ?z} -> :z
        {:z, ?h} -> :zh
        {temporary, _tag} when temporary in [:start, :j, :k, :z] -> :none
        {completed, _tag} when completed in [:ja, :ko, :zh] -> completed
        {:none, _tag} -> :none
        {_unknown, _tag} -> :none
      end

    {:jp2, g2, next_language}
  end

  defp ms_cp932_pair(pair) do
    case jis_to_sjis(pair) do
      {:ok, shift_jis} -> table_pair(:cp932, shift_jis)
      :error -> :error
    end
  end

  defp jis_to_sjis(<<row, cell>>) when row in 0x21..0x7E and cell in 0x21..0x7E do
    lead0 = div(row - 0x21, 2) + 0x81
    lead = if lead0 > 0x9F, do: lead0 + 0x40, else: lead0

    trail =
      if rem(row - 0x21, 2) == 0 do
        value = cell + 0x1F
        if value >= 0x7F, do: value + 1, else: value
      else
        cell + 0x7E
      end

    if lead <= 0xFC and trail <= 0xFC, do: {:ok, <<lead, trail>>}, else: :error
  end

  defp binary_starts_with?(binary, prefix) when byte_size(binary) >= byte_size(prefix),
    do: binary_part(binary, 0, byte_size(prefix)) == prefix

  defp binary_starts_with?(_binary, _prefix), do: false

  defp invalid(sequence, offset), do: {:error, :invalid_sequence, offset, sequence}

  defp replace(byte, replacer, acc), do: :lists.reverse(replacer.(byte), acc)
  defp replace_bytes(acc, <<>>, _replacer), do: acc

  defp replace_bytes(acc, <<byte, rest::binary>>, replacer),
    do: replace_bytes(replace(byte, replacer, acc), rest, replacer)

  defp prepend(tuple, acc) when tuple_size(tuple) == 1, do: [elem(tuple, 0) | acc]
  defp prepend(tuple, acc), do: tuple |> Tuple.to_list() |> :lists.reverse(acc)

  defp drop_codepoints([_first | rest], 1), do: rest
  defp drop_codepoints([_first, _second | rest], 2), do: rest
end

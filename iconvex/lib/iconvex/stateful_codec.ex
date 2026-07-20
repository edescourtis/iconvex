defmodule Iconvex.StatefulCodec do
  @moduledoc false

  alias Iconvex.Tables
  alias Iconvex.StatefulPairCache
  alias Iconvex.ISO2022JPCodec
  alias Iconvex.ISO2022CNCodec
  alias Iconvex.UTF7Codec

  @jp_variants ~w(iso2022_jp iso2022_jp1 iso2022_jp2 iso2022_jp3 iso2022_jpms iso2022_jp_ext)a
  @jp_two_byte_modes ~w(jis0208 jis0212 jis0212_pyext gb2312 ksc5601 jis0213_1 jis0213_2 jis0208ms jis0212ms)a
  @jp_base_escapes [
    {<<0x1B, "$@">>, {:mode, :jis0208}},
    {<<0x1B, "$B">>, {:mode, :jis0208}},
    {<<0x1B, "(B">>, {:mode, :ascii}},
    {<<0x1B, "(J">>, {:mode, :roman}}
  ]
  @jp_escapes_by_variant %{
    iso2022_jp: @jp_base_escapes,
    iso2022_jp1: [{<<0x1B, "$(D">>, {:mode, :jis0212}} | @jp_base_escapes],
    iso2022_jp_ext: [
      {<<0x1B, "$(D">>, {:mode, :jis0212_pyext}},
      {<<0x1B, "(I">>, {:mode, :kana}}
      | @jp_base_escapes
    ],
    iso2022_jp2: [
      {<<0x1B, "$(D">>, {:mode, :jis0212}},
      {<<0x1B, "$(C">>, {:mode, :ksc5601}},
      {<<0x1B, "$A">>, {:mode, :gb2312}},
      {<<0x1B, "(I">>, {:mode, :kana}},
      {<<0x1B, ".A">>, {:g2, :iso8859_1}},
      {<<0x1B, ".F">>, {:g2, :iso8859_7}}
      | @jp_base_escapes
    ],
    iso2022_jp3: [
      {<<0x1B, "$(O">>, {:mode, :jis0213_1}},
      {<<0x1B, "$(Q">>, {:mode, :jis0213_1}},
      {<<0x1B, "$(P">>, {:mode, :jis0213_2}},
      {<<0x1B, "(I">>, {:mode, :kana}}
      | @jp_base_escapes
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

  def stream_init(%{id: :hz}), do: {:hz, false}
  def stream_init(%{id: :iso2022_kr}), do: {:kr, :ascii, false}
  def stream_init(%{id: id}) when id in @jp_variants, do: {:jp, :ascii, nil}

  def stream_init(%{id: id}) when id in [:iso2022_cn, :iso2022_cn_ext],
    do: {:cn, :ascii, nil, nil, nil}

  def stream_init(%{id: :utf7}), do: UTF7Codec.stream_init()

  def decode_chunk(%{id: :utf7}, input, state, final?, base_offset),
    do: UTF7Codec.decode_chunk(input, state, final?, base_offset)

  def decode_chunk(entry, input, state, final?, base_offset) do
    prefix = stream_prefix(entry, state)
    prefix_size = byte_size(prefix)
    combined = prefix <> input

    case decode(entry, combined) do
      {:ok, codepoints} ->
        {:ok, codepoints, scan_stream(entry, input, state), <<>>}

      {:error, :incomplete_sequence, offset, _sequence} when not final? ->
        local_offset = max(offset - prefix_size, 0)
        stable = binary_part(input, 0, local_offset)
        pending = binary_part(input, local_offset, byte_size(input) - local_offset)

        case decode(entry, prefix <> stable) do
          {:ok, codepoints} ->
            {:ok, codepoints, scan_stream(entry, stable, state), pending}

          error ->
            adjust_stream_error(error, prefix_size, base_offset)
        end

      {:error, :invalid_sequence, offset, _sequence} = error when not final? ->
        if defer_iso2022_escape_diagnostic?(entry, combined, offset) do
          local_offset = max(offset - prefix_size, 0)
          stable = binary_part(input, 0, local_offset)
          pending = binary_part(input, local_offset, byte_size(input) - local_offset)

          case decode(entry, prefix <> stable) do
            {:ok, codepoints} ->
              {:ok, codepoints, scan_stream(entry, stable, state), pending}

            prefix_error ->
              adjust_stream_error(prefix_error, prefix_size, base_offset)
          end
        else
          adjust_stream_error(error, prefix_size, base_offset)
        end

      {:error, kind, offset, sequence} ->
        {:error, kind, base_offset + max(offset - prefix_size, 0), sequence}
    end
  end

  def stream_encode_init(%{id: :hz}), do: {:hz, false}
  def stream_encode_init(%{id: :iso2022_kr}), do: {:kr, :ascii, false}

  def stream_encode_init(%{id: id} = entry) when id in @jp_variants,
    do: ISO2022JPCodec.stream_encode_init(entry)

  def stream_encode_init(%{id: id} = entry) when id in [:iso2022_cn, :iso2022_cn_ext],
    do: ISO2022CNCodec.stream_encode_init(entry)

  def stream_encode_init(%{id: :utf7}), do: UTF7Codec.stream_encode_init()

  def encode_chunk(%{id: :hz}, codepoints, {:hz, gb?}, final?, policy),
    do:
      hz_stream_encode(
        codepoints,
        [],
        false,
        gb?,
        final?,
        policy,
        [],
        Tables.fetch!(:gb2312).encode
      )

  def encode_chunk(%{id: :iso2022_kr}, codepoints, {:kr, mode, designated?}, final?, policy),
    do:
      kr_stream_encode(
        codepoints,
        [],
        false,
        mode,
        designated?,
        final?,
        policy,
        [],
        Tables.fetch!(:ksc5601).encode
      )

  def encode_chunk(%{id: id} = entry, codepoints, state, final?, policy)
      when id in @jp_variants,
      do: ISO2022JPCodec.encode_chunk(entry, codepoints, state, final?, policy)

  def encode_chunk(%{id: id} = entry, codepoints, state, final?, policy)
      when id in [:iso2022_cn, :iso2022_cn_ext],
      do: ISO2022CNCodec.encode_chunk(entry, codepoints, state, final?, policy)

  def encode_chunk(%{id: :utf7}, codepoints, state, final?, policy),
    do: UTF7Codec.encode_chunk(codepoints, state, final?, policy)

  def decode(%{id: :hz}, input) do
    Tables.with_conversion_cache(fn -> hz_decode(input, false, 0, []) end)
  end

  def decode(%{id: :iso2022_kr}, input) do
    Tables.with_conversion_cache(fn -> kr_decode(input, :ascii, false, 0, []) end)
  end

  def decode(%{id: id} = entry, input)
      when id in @jp_variants,
      do: ISO2022JPCodec.decode(entry, input)

  def decode(%{id: id} = entry, input) when id in [:iso2022_cn, :iso2022_cn_ext],
    do: ISO2022CNCodec.decode(entry, input)

  def decode(%{id: :utf7} = entry, input), do: UTF7Codec.decode(entry, input)

  def decode(_entry, _input), do: {:error, :unsupported_conversion, 0, <<>>}

  @doc false
  def decode_to_explicit_ucs4_discard(%{id: :hz}, input, endian)
      when endian in [:big, :little] do
    Tables.with_conversion_cache(fn ->
      {table, identity} = Tables.fetch_with_identity!(%{id: :gb2312})
      source = table.many

      hz_decode_ucs4_discard(
        input,
        false,
        endian,
        [],
        StatefulPairCache.seven_bit(:gb2312, source, identity)
      )
    end)
  end

  def decode_to_explicit_ucs4_discard(%{id: :iso2022_kr}, input, endian)
      when endian in [:big, :little] do
    Tables.with_conversion_cache(fn ->
      {table, identity} = Tables.fetch_with_identity!(%{id: :ksc5601})
      source = table.many

      kr_decode_ucs4(
        input,
        :ascii,
        false,
        endian,
        <<>>,
        StatefulPairCache.seven_bit(:ksc5601, source, identity)
      )
    end)
  end

  def decode_to_explicit_ucs4_discard(%{id: id} = entry, input, endian)
      when id in @jp_variants and endian in [:big, :little],
      do: ISO2022JPCodec.decode_to_explicit_ucs4(entry, input, endian)

  def decode_to_explicit_ucs4_discard(%{id: id} = entry, input, endian)
      when id in [:iso2022_cn, :iso2022_cn_ext] and endian in [:big, :little],
      do: ISO2022CNCodec.decode_to_explicit_ucs4(entry, input, endian)

  def decode_to_explicit_ucs4_discard(_entry, _input, _endian), do: :miss

  @doc false
  def encode_from_explicit_ucs4_discard(%{id: :hz}, input, endian)
      when endian in [:big, :little] do
    if rem(byte_size(input), 4) == 0 do
      hz_encode_ucs4_discard(input, endian, false, [], Tables.fetch!(:gb2312).encode)
    else
      :miss
    end
  end

  def encode_from_explicit_ucs4_discard(%{id: :iso2022_kr}, input, endian)
      when endian in [:big, :little] do
    if rem(byte_size(input), 4) == 0 do
      kr_encode_ucs4_discard(
        input,
        endian,
        :ascii,
        false,
        [],
        Tables.fetch!(:ksc5601).encode
      )
    else
      :miss
    end
  end

  def encode_from_explicit_ucs4_discard(%{id: id} = entry, input, endian)
      when id in @jp_variants and endian in [:big, :little],
      do: ISO2022JPCodec.encode_from_explicit_ucs4_discard(entry, input, endian)

  def encode_from_explicit_ucs4_discard(_entry, _input, _endian), do: :miss

  def decode_discard(%{id: id} = entry, input)
      when id in @jp_variants,
      do: ISO2022JPCodec.decode_discard(entry, input)

  def decode_discard(%{id: :hz}, input) do
    Tables.with_conversion_cache(fn ->
      hz_decode_replace(input, false, fn _byte -> [] end, [])
    end)
  end

  def decode_discard(%{id: :iso2022_kr}, input) do
    Tables.with_conversion_cache(fn ->
      kr_decode_replace(input, :ascii, false, fn _byte -> [] end, [])
    end)
  end

  def decode_discard(%{id: id} = entry, input) when id in [:iso2022_cn, :iso2022_cn_ext],
    do: ISO2022CNCodec.decode_discard(entry, input)

  def decode_discard(%{id: :utf7} = entry, input), do: UTF7Codec.decode_discard(entry, input)

  def decode_substitute(%{id: id} = entry, input, replacer)
      when id in @jp_variants,
      do: ISO2022JPCodec.decode_substitute(entry, input, replacer)

  def decode_substitute(%{id: :hz}, input, replacer) do
    Tables.with_conversion_cache(fn -> hz_decode_replace(input, false, replacer, []) end)
  end

  def decode_substitute(%{id: :iso2022_kr}, input, replacer) do
    Tables.with_conversion_cache(fn ->
      kr_decode_replace(input, :ascii, false, replacer, [])
    end)
  end

  def decode_substitute(%{id: id} = entry, input, replacer)
      when id in [:iso2022_cn, :iso2022_cn_ext],
      do: ISO2022CNCodec.decode_substitute(entry, input, replacer)

  def decode_substitute(%{id: :utf7} = entry, input, replacer),
    do: UTF7Codec.decode_substitute(entry, input, replacer)

  def encode(%{id: :hz}, codepoints),
    do: hz_encode(codepoints, false, [], false, Tables.fetch!(:gb2312).encode)

  def encode(%{id: :iso2022_kr}, codepoints),
    do: kr_encode(codepoints, :ascii, false, [], false, Tables.fetch!(:ksc5601).encode)

  def encode(%{id: id} = entry, codepoints)
      when id in @jp_variants,
      do: ISO2022JPCodec.encode(entry, codepoints)

  def encode(%{id: id} = entry, codepoints) when id in [:iso2022_cn, :iso2022_cn_ext],
    do: ISO2022CNCodec.encode(entry, codepoints)

  def encode(%{id: :utf7} = entry, codepoints), do: UTF7Codec.encode(entry, codepoints)

  def encode(_entry, _codepoints), do: {:error, :unsupported_conversion, 0}

  def encode_discard(%{id: :hz}, codepoints),
    do: hz_encode(codepoints, false, [], true, Tables.fetch!(:gb2312).encode)

  def encode_discard(%{id: :iso2022_kr}, codepoints),
    do: kr_encode(codepoints, :ascii, false, [], true, Tables.fetch!(:ksc5601).encode)

  def encode_discard(%{id: id} = entry, codepoints)
      when id in @jp_variants,
      do: ISO2022JPCodec.encode_discard(entry, codepoints)

  def encode_discard(%{id: id} = entry, codepoints)
      when id in [:iso2022_cn, :iso2022_cn_ext],
      do: ISO2022CNCodec.encode_discard(entry, codepoints)

  def encode_discard(%{id: :utf7} = entry, codepoints),
    do: UTF7Codec.encode_discard(entry, codepoints)

  def encode_discard(_entry, _codepoints), do: {:error, :unsupported_conversion, 0}

  def encode_substitute(%{id: :hz}, codepoints, replacer) when is_function(replacer, 1),
    do:
      hz_encode_substitute(
        codepoints,
        [],
        false,
        false,
        [],
        replacer,
        Tables.fetch!(:gb2312).encode
      )

  def encode_substitute(%{id: :iso2022_kr}, codepoints, replacer)
      when is_function(replacer, 1),
      do:
        kr_encode_substitute(
          codepoints,
          [],
          false,
          :ascii,
          false,
          [],
          replacer,
          Tables.fetch!(:ksc5601).encode
        )

  def encode_substitute(%{id: id} = entry, codepoints, replacer)
      when id in @jp_variants and
             is_function(replacer, 1),
      do: ISO2022JPCodec.encode_substitute(entry, codepoints, replacer)

  def encode_substitute(%{id: id} = entry, codepoints, replacer)
      when id in [:iso2022_cn, :iso2022_cn_ext] and is_function(replacer, 1),
      do: ISO2022CNCodec.encode_substitute(entry, codepoints, replacer)

  def encode_substitute(%{id: :utf7} = entry, codepoints, replacer)
      when is_function(replacer, 1),
      do: UTF7Codec.encode_substitute(entry, codepoints, replacer)

  def encode_substitute(_entry, _codepoints, _replacer),
    do: {:error, :unsupported_conversion, 0}

  defp adjust_stream_error({:error, kind, offset, sequence}, prefix_size, base_offset),
    do: {:error, kind, base_offset + max(offset - prefix_size, 0), sequence}

  defp defer_iso2022_escape_diagnostic?(%{id: id}, input, offset)
       when (id in @jp_variants or id in [:iso2022_cn, :iso2022_cn_ext]) and
              is_integer(offset) and offset >= 0 do
    available = byte_size(input) - offset

    available in 1..3 and :binary.at(input, offset) == 0x1B
  end

  defp defer_iso2022_escape_diagnostic?(_entry, _input, _offset), do: false

  defp stream_prefix(%{id: :hz}, {:hz, true}), do: "~{"
  defp stream_prefix(%{id: :hz}, {:hz, false}), do: <<>>

  defp stream_prefix(%{id: :iso2022_kr}, {:kr, mode, designated?}) do
    designation = if designated?, do: <<0x1B, "$)C">>, else: <<>>
    shift = if mode == :ksc5601, do: <<0x0E>>, else: <<>>
    designation <> shift
  end

  defp stream_prefix(%{id: id}, {:jp, mode, g2}) when id in @jp_variants do
    jp_g2_prefix(g2) <> jp_mode_prefix(mode)
  end

  defp stream_prefix(
         %{id: id},
         {:cn, mode, g1, g2, g3}
       )
       when id in [:iso2022_cn, :iso2022_cn_ext] do
    cn_g1_prefix(g1) <>
      cn_g2_prefix(g2) <>
      cn_g3_prefix(g3) <>
      if(mode == :twobyte, do: <<0x0E>>, else: <<>>)
  end

  defp scan_stream(%{id: :hz}, input, state), do: scan_hz(input, state)
  defp scan_stream(%{id: :iso2022_kr}, input, state), do: scan_kr(input, state)

  defp scan_stream(%{id: id}, input, state) when id in @jp_variants,
    do: scan_jp(id, input, state)

  defp scan_stream(%{id: id}, input, state) when id in [:iso2022_cn, :iso2022_cn_ext],
    do: scan_cn(input, state)

  defp scan_hz(<<>>, state), do: state
  defp scan_hz(<<?~, ?{, rest::binary>>, {:hz, false}), do: scan_hz(rest, {:hz, true})
  defp scan_hz(<<?~, ?}, rest::binary>>, {:hz, true}), do: scan_hz(rest, {:hz, false})
  defp scan_hz(<<?~, ?~, rest::binary>>, {:hz, false} = state), do: scan_hz(rest, state)
  defp scan_hz(<<?~, ?\n, rest::binary>>, {:hz, false} = state), do: scan_hz(rest, state)
  defp scan_hz(<<_first, _second, rest::binary>>, {:hz, true} = state), do: scan_hz(rest, state)
  defp scan_hz(<<_byte, rest::binary>>, state), do: scan_hz(rest, state)

  defp scan_kr(<<>>, state), do: state

  defp scan_kr(<<0x1B, "$)C", rest::binary>>, {:kr, mode, _designated?}),
    do: scan_kr(rest, {:kr, mode, true})

  defp scan_kr(<<0x0E, rest::binary>>, {:kr, _mode, true}),
    do: scan_kr(rest, {:kr, :ksc5601, true})

  defp scan_kr(<<0x0F, rest::binary>>, {:kr, _mode, designated?}),
    do: scan_kr(rest, {:kr, :ascii, designated?})

  defp scan_kr(<<_first, _second, rest::binary>>, {:kr, :ksc5601, true} = state),
    do: scan_kr(rest, state)

  defp scan_kr(<<_byte, rest::binary>>, state), do: scan_kr(rest, state)

  defp scan_jp(_variant, <<>>, state), do: state

  defp scan_jp(:iso2022_jp2 = variant, <<0x1B, ?N, _byte, rest::binary>>, state),
    do: scan_jp(variant, rest, state)

  defp scan_jp(variant, <<0x1B, _::binary>> = input, {:jp, mode, g2}) do
    {bytes, action} =
      Enum.find(jp_escapes(variant), fn {bytes, _} -> starts_with?(input, bytes) end)

    <<_::binary-size(byte_size(bytes)), rest::binary>> = input

    state =
      case action do
        {:mode, next_mode} -> {:jp, next_mode, g2}
        {:g2, next_g2} -> {:jp, mode, next_g2}
      end

    scan_jp(variant, rest, state)
  end

  defp scan_jp(
         :iso2022_jpms = variant,
         <<shift, rest::binary>>,
         {:jp, mode, g2}
       )
       when shift in [0x0E, 0x0F] do
    next_mode =
      case {shift, mode} do
        {0x0E, :roman} -> :kana
        {0x0F, :kana} -> :roman
        _ignored_shift -> mode
      end

    scan_jp(variant, rest, {:jp, next_mode, g2})
  end

  defp scan_jp(variant, <<_first, _second, rest::binary>>, {:jp, mode, _g2} = state)
       when mode in @jp_two_byte_modes,
       do: scan_jp(variant, rest, state)

  defp scan_jp(variant, <<_byte, rest::binary>>, state), do: scan_jp(variant, rest, state)

  defp scan_cn(<<>>, state), do: state

  defp scan_cn(<<0x1B, marker, _first, _second, rest::binary>>, state)
       when marker in [?N, ?O],
       do: scan_cn(rest, state)

  defp scan_cn(<<0x1B, "$)", value, rest::binary>>, {:cn, mode, _g1, g2, g3}) do
    g1 = %{?A => :gb2312, ?G => 1, ?E => :iso_ir_165} |> Map.fetch!(value)
    scan_cn(rest, {:cn, mode, g1, g2, g3})
  end

  defp scan_cn(<<0x1B, "$*H", rest::binary>>, {:cn, mode, g1, _g2, g3}),
    do: scan_cn(rest, {:cn, mode, g1, 2, g3})

  defp scan_cn(<<0x1B, "$+", value, rest::binary>>, {:cn, mode, g1, g2, _g3}),
    do: scan_cn(rest, {:cn, mode, g1, g2, value - 0x46})

  defp scan_cn(<<0x0E, rest::binary>>, {:cn, _mode, g1, g2, g3}),
    do: scan_cn(rest, {:cn, :twobyte, g1, g2, g3})

  defp scan_cn(<<0x0F, rest::binary>>, {:cn, _mode, g1, g2, g3}),
    do: scan_cn(rest, {:cn, :ascii, g1, g2, g3})

  defp scan_cn(<<_first, _second, rest::binary>>, {:cn, :twobyte, _, _, _} = state),
    do: scan_cn(rest, state)

  defp scan_cn(<<_byte, rest::binary>>, state), do: scan_cn(rest, state)

  defp jp_mode_prefix(:ascii), do: <<>>
  defp jp_mode_prefix(:roman), do: <<0x1B, "(J">>
  defp jp_mode_prefix(:kana), do: <<0x1B, "(I">>
  defp jp_mode_prefix(:jis0208), do: <<0x1B, "$B">>
  defp jp_mode_prefix(:jis0212), do: <<0x1B, "$(D">>
  defp jp_mode_prefix(:jis0212_pyext), do: <<0x1B, "$(D">>
  defp jp_mode_prefix(:gb2312), do: <<0x1B, "$A">>
  defp jp_mode_prefix(:ksc5601), do: <<0x1B, "$(C">>
  defp jp_mode_prefix(:jis0213_1), do: <<0x1B, "$(O">>
  defp jp_mode_prefix(:jis0213_2), do: <<0x1B, "$(P">>
  defp jp_mode_prefix(:jis0208ms), do: <<0x1B, "$B">>
  defp jp_mode_prefix(:jis0212ms), do: <<0x1B, "$(D">>

  defp jp_g2_prefix(nil), do: <<>>
  defp jp_g2_prefix(:iso8859_1), do: <<0x1B, ".A">>
  defp jp_g2_prefix(:iso8859_7), do: <<0x1B, ".F">>

  defp cn_g1_prefix(nil), do: <<>>
  defp cn_g1_prefix(:gb2312), do: <<0x1B, "$)A">>
  defp cn_g1_prefix(1), do: <<0x1B, "$)G">>
  defp cn_g1_prefix(:iso_ir_165), do: <<0x1B, "$)E">>

  defp cn_g2_prefix(nil), do: <<>>
  defp cn_g2_prefix(2), do: <<0x1B, "$*H">>

  defp cn_g3_prefix(nil), do: <<>>
  defp cn_g3_prefix(plane), do: <<0x1B, "$+", plane + 0x46>>

  defp jp_escapes(variant), do: Map.fetch!(@jp_escapes_by_variant, variant)

  defp starts_with?(binary, prefix) when byte_size(binary) >= byte_size(prefix),
    do: binary_part(binary, 0, byte_size(prefix)) == prefix

  defp starts_with?(_binary, _prefix), do: false

  defp hz_stream_encode([], resume, true, gb?, final?, policy, acc, map),
    do: hz_stream_encode(resume, [], false, gb?, final?, policy, acc, map)

  defp hz_stream_encode([], [], false, gb?, final?, _policy, acc, _map) do
    suffix = if final? and gb?, do: "~}", else: <<>>
    next_gb? = if final?, do: false, else: gb?

    {:ok, acc |> :lists.reverse([suffix]) |> IO.iodata_to_binary(), {:hz, next_gb?}, []}
  end

  defp hz_stream_encode(
         [codepoint | rest],
         resume,
         replacement?,
         gb?,
         final?,
         policy,
         acc,
         map
       )
       when codepoint in 0..0x7F do
    shift = if gb?, do: "~}", else: <<>>

    hz_stream_encode(
      rest,
      resume,
      replacement?,
      false,
      final?,
      policy,
      [<<codepoint>>, shift | acc],
      map
    )
  end

  defp hz_stream_encode(
         [codepoint | rest],
         resume,
         replacement?,
         gb?,
         final?,
         policy,
         acc,
         map
       ) do
    case Map.fetch(map, {codepoint}) do
      {:ok, pair} ->
        shift = if gb?, do: <<>>, else: "~{"

        hz_stream_encode(
          rest,
          resume,
          replacement?,
          true,
          final?,
          policy,
          [pair, shift | acc],
          map
        )

      :error ->
        stream_unrepresentable(
          codepoint,
          rest,
          resume,
          replacement?,
          policy,
          fn next, next_resume, next_replacement? ->
            hz_stream_encode(
              next,
              next_resume,
              next_replacement?,
              gb?,
              final?,
              policy,
              acc,
              map
            )
          end
        )
    end
  end

  defp kr_stream_encode([], resume, true, mode, designated?, final?, policy, acc, map),
    do: kr_stream_encode(resume, [], false, mode, designated?, final?, policy, acc, map)

  defp kr_stream_encode([], [], false, mode, designated?, final?, _policy, acc, _map) do
    suffix = if final? and mode != :ascii, do: <<0x0F>>, else: <<>>
    next_mode = if final?, do: :ascii, else: mode

    {:ok, acc |> :lists.reverse([suffix]) |> IO.iodata_to_binary(), {:kr, next_mode, designated?},
     []}
  end

  defp kr_stream_encode(
         [codepoint | rest],
         resume,
         replacement?,
         mode,
         designated?,
         final?,
         policy,
         acc,
         map
       )
       when codepoint in 0..0x7F do
    shift = if mode == :ascii, do: <<>>, else: <<0x0F>>
    next_designated? = if codepoint in [?\n, ?\r], do: false, else: designated?

    kr_stream_encode(
      rest,
      resume,
      replacement?,
      :ascii,
      next_designated?,
      final?,
      policy,
      [<<codepoint>>, shift | acc],
      map
    )
  end

  defp kr_stream_encode(
         [codepoint | rest],
         resume,
         replacement?,
         mode,
         designated?,
         final?,
         policy,
         acc,
         map
       ) do
    case Map.fetch(map, {codepoint}) do
      {:ok, pair} ->
        designation = if designated?, do: <<>>, else: <<0x1B, "$)C">>
        shift = if mode == :ksc5601, do: <<>>, else: <<0x0E>>

        kr_stream_encode(
          rest,
          resume,
          replacement?,
          :ksc5601,
          true,
          final?,
          policy,
          [pair, shift, designation | acc],
          map
        )

      :error ->
        stream_unrepresentable(
          codepoint,
          rest,
          resume,
          replacement?,
          policy,
          fn next, next_resume, next_replacement? ->
            kr_stream_encode(
              next,
              next_resume,
              next_replacement?,
              mode,
              designated?,
              final?,
              policy,
              acc,
              map
            )
          end
        )
    end
  end

  defp stream_unrepresentable(codepoint, _rest, _resume, true, _policy, _continue),
    do: {:error, :unrepresentable_character, codepoint}

  defp stream_unrepresentable(codepoint, _rest, _resume, false, :error, _continue),
    do: {:error, :unrepresentable_character, codepoint}

  defp stream_unrepresentable(_codepoint, rest, resume, false, :discard, continue),
    do: continue.(rest, resume, false)

  defp stream_unrepresentable(codepoint, rest, _resume, false, {:replace, replacer}, continue),
    do: continue.(replacer.(codepoint), rest, true)

  defp hz_decode_ucs4_discard(<<>>, _gb?, _endian, acc, _decode_map),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp hz_decode_ucs4_discard(<<?~, rest::binary>>, gb?, endian, acc, decode_map) do
    case {gb?, rest} do
      {false, <<?~, tail::binary>>} ->
        hz_decode_ucs4_discard(tail, false, endian, [ucs4(?~, endian) | acc], decode_map)

      {false, <<?{, tail::binary>>} ->
        hz_decode_ucs4_discard(tail, true, endian, acc, decode_map)

      {false, <<?\n, tail::binary>>} ->
        hz_decode_ucs4_discard(tail, false, endian, acc, decode_map)

      {true, <<?}, tail::binary>>} ->
        hz_decode_ucs4_discard(tail, false, endian, acc, decode_map)

      {_, <<>>} ->
        {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

      _invalid_tilde ->
        hz_decode_ucs4_discard(rest, gb?, endian, acc, decode_map)
    end
  end

  defp hz_decode_ucs4_discard(<<byte, rest::binary>>, false, endian, acc, decode_map)
       when byte < 0x80,
       do:
         hz_decode_ucs4_discard(
           rest,
           false,
           endian,
           [ucs4(byte, endian) | acc],
           decode_map
         )

  defp hz_decode_ucs4_discard(input, true, endian, acc, decode_map)
       when byte_size(input) < 2,
       do: hz_decode_ucs4_discard(<<>>, true, endian, acc, decode_map)

  defp hz_decode_ucs4_discard(
         <<first, second, rest::binary>> = input,
         true,
         endian,
         acc,
         decode_map
       )
       when first in 0x21..0x7E and second in 0x21..0x7E do
    case StatefulPairCache.lookup(decode_map, first, second, endian) do
      {:ok, bytes} ->
        hz_decode_ucs4_discard(
          rest,
          true,
          endian,
          [bytes | acc],
          decode_map
        )

      :error ->
        <<_discarded, tail::binary>> = input
        hz_decode_ucs4_discard(tail, true, endian, acc, decode_map)
    end
  end

  defp hz_decode_ucs4_discard(<<_discarded, rest::binary>>, gb?, endian, acc, decode_map),
    do: hz_decode_ucs4_discard(rest, gb?, endian, acc, decode_map)

  defp hz_decode(<<>>, _gb?, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp hz_decode(<<?~, rest::binary>> = input, gb?, offset, acc) do
    case {gb?, rest} do
      {false, <<?~, tail::binary>>} -> hz_decode(tail, false, offset + 2, [?~ | acc])
      {false, <<?{, tail::binary>>} -> hz_decode(tail, true, offset + 2, acc)
      {false, <<?\n, tail::binary>>} -> hz_decode(tail, false, offset + 2, acc)
      {true, <<?}, tail::binary>>} -> hz_decode(tail, false, offset + 2, acc)
      {_, <<>>} -> {:error, :incomplete_sequence, offset, input}
      _ -> {:error, :invalid_sequence, offset, binary_part(input, 0, min(2, byte_size(input)))}
    end
  end

  defp hz_decode(<<byte, rest::binary>>, false, offset, acc) when byte < 0x80,
    do: hz_decode(rest, false, offset + 1, [byte | acc])

  defp hz_decode(input, true, offset, _acc) when byte_size(input) < 2,
    do: {:error, :incomplete_sequence, offset, input}

  defp hz_decode(<<first, second, rest::binary>>, true, offset, acc)
       when first in 0x21..0x7E and second in 0x21..0x7E do
    pair = <<first, second>>

    case Map.fetch(Tables.fetch!(:gb2312).many, pair) do
      {:ok, codepoints} -> hz_decode(rest, true, offset + 2, prepend(codepoints, acc))
      :error -> {:error, :invalid_sequence, offset, pair}
    end
  end

  defp hz_decode(input, false, offset, _acc),
    do: {:error, :invalid_sequence, offset, binary_part(input, 0, 1)}

  defp hz_decode(input, true, offset, _acc),
    do: {:error, :invalid_sequence, offset, binary_part(input, 0, min(2, byte_size(input)))}

  defp hz_decode_replace(<<>>, _gb?, _replacer, acc), do: {:ok, :lists.reverse(acc)}

  defp hz_decode_replace(<<?~, rest::binary>> = input, gb?, replacer, acc) do
    case {gb?, rest} do
      {false, <<?~, tail::binary>>} -> hz_decode_replace(tail, false, replacer, [?~ | acc])
      {false, <<?{, tail::binary>>} -> hz_decode_replace(tail, true, replacer, acc)
      {false, <<?\n, tail::binary>>} -> hz_decode_replace(tail, false, replacer, acc)
      {true, <<?}, tail::binary>>} -> hz_decode_replace(tail, false, replacer, acc)
      {_, <<>>} -> {:ok, replace_bytes(acc, input, replacer) |> :lists.reverse()}
      _ -> hz_decode_replace(rest, gb?, replacer, replace(?~, replacer, acc))
    end
  end

  defp hz_decode_replace(<<byte, rest::binary>>, false, replacer, acc) when byte < 0x80,
    do: hz_decode_replace(rest, false, replacer, [byte | acc])

  defp hz_decode_replace(input, true, replacer, acc) when byte_size(input) < 2,
    do: {:ok, replace_bytes(acc, input, replacer) |> :lists.reverse()}

  defp hz_decode_replace(<<first, second, rest::binary>> = input, true, replacer, acc)
       when first in 0x21..0x7E and second in 0x21..0x7E do
    case Map.fetch(Tables.fetch!(:gb2312).many, <<first, second>>) do
      {:ok, codepoints} ->
        hz_decode_replace(rest, true, replacer, prepend(codepoints, acc))

      :error ->
        <<byte, tail::binary>> = input
        hz_decode_replace(tail, true, replacer, replace(byte, replacer, acc))
    end
  end

  defp hz_decode_replace(<<byte, rest::binary>>, gb?, replacer, acc),
    do: hz_decode_replace(rest, gb?, replacer, replace(byte, replacer, acc))

  defp hz_encode([], gb?, acc, _discard?, _encode_map) do
    suffix = if gb?, do: "~}", else: ""
    {:ok, acc |> :lists.reverse([suffix]) |> IO.iodata_to_binary()}
  end

  defp hz_encode([codepoint | rest], gb?, acc, discard?, encode_map)
       when codepoint in 0..0x7F do
    shift = if gb?, do: "~}", else: ""
    hz_encode(rest, false, [<<codepoint>>, shift | acc], discard?, encode_map)
  end

  defp hz_encode([codepoint | rest], gb?, acc, discard?, encode_map) do
    case Map.fetch(encode_map, {codepoint}) do
      {:ok, pair} ->
        shift = if gb?, do: "", else: "~{"
        hz_encode(rest, true, [pair, shift | acc], discard?, encode_map)

      :error when discard? ->
        hz_encode(rest, gb?, acc, discard?, encode_map)

      :error ->
        {:error, :unrepresentable_character, codepoint}
    end
  end

  defp hz_encode_ucs4_discard(<<>>, _endian, gb?, acc, _encode_map) do
    suffix = if gb?, do: "~}", else: ""
    {:ok, acc |> :lists.reverse([suffix]) |> IO.iodata_to_binary()}
  end

  defp hz_encode_ucs4_discard(input, endian, gb?, acc, encode_map) do
    case skip_non_bmp_ucs4_block(input, endian) do
      {:skip, rest} ->
        hz_encode_ucs4_discard(rest, endian, gb?, acc, encode_map)

      :keep ->
        {codepoint, rest} = take_explicit_ucs4(input, endian)

        cond do
          codepoint <= 0x7F ->
            shift = if gb?, do: "~}", else: ""

            hz_encode_ucs4_discard(
              rest,
              endian,
              false,
              [<<codepoint>>, shift | acc],
              encode_map
            )

          true ->
            case Map.fetch(encode_map, {codepoint}) do
              {:ok, pair} ->
                shift = if gb?, do: "", else: "~{"
                hz_encode_ucs4_discard(rest, endian, true, [pair, shift | acc], encode_map)

              :error ->
                hz_encode_ucs4_discard(rest, endian, gb?, acc, encode_map)
            end
        end
    end
  end

  defp hz_encode_substitute([], resume, true, gb?, acc, replacer, encode_map),
    do: hz_encode_substitute(resume, [], false, gb?, acc, replacer, encode_map)

  defp hz_encode_substitute([], [], false, gb?, acc, _replacer, _encode_map) do
    suffix = if gb?, do: "~}", else: ""
    {:ok, acc |> :lists.reverse([suffix]) |> IO.iodata_to_binary()}
  end

  defp hz_encode_substitute(
         [codepoint | rest],
         resume,
         replacement?,
         gb?,
         acc,
         replacer,
         encode_map
       )
       when codepoint in 0..0x7F do
    shift = if gb?, do: "~}", else: ""

    hz_encode_substitute(
      rest,
      resume,
      replacement?,
      false,
      [<<codepoint>>, shift | acc],
      replacer,
      encode_map
    )
  end

  defp hz_encode_substitute(
         [codepoint | rest],
         resume,
         replacement?,
         gb?,
         acc,
         replacer,
         encode_map
       ) do
    case Map.fetch(encode_map, {codepoint}) do
      {:ok, pair} ->
        shift = if gb?, do: "", else: "~{"

        hz_encode_substitute(
          rest,
          resume,
          replacement?,
          true,
          [pair, shift | acc],
          replacer,
          encode_map
        )

      :error when replacement? ->
        {:error, :unrepresentable_character, codepoint}

      :error ->
        hz_encode_substitute(replacer.(codepoint), rest, true, gb?, acc, replacer, encode_map)
    end
  end

  defp kr_decode_ucs4(<<>>, _mode, _designated?, _endian, acc, _decode_map),
    do: {:ok, acc}

  defp kr_decode_ucs4(
         <<0x1B, "$)C", rest::binary>>,
         mode,
         _designated?,
         endian,
         acc,
         decode_map
       ),
       do: kr_decode_ucs4(rest, mode, true, endian, acc, decode_map)

  defp kr_decode_ucs4(<<0x1B, _::binary>> = input, mode, designated?, endian, acc, decode_map) do
    if byte_size(input) < 4 do
      {:ok, acc}
    else
      <<_discarded_escape, rest::binary>> = input
      kr_decode_ucs4(rest, mode, designated?, endian, acc, decode_map)
    end
  end

  defp kr_decode_ucs4(<<0x0E, rest::binary>>, _mode, true, endian, acc, decode_map),
    do: kr_decode_ucs4(rest, :ksc5601, true, endian, acc, decode_map)

  defp kr_decode_ucs4(<<0x0E, rest::binary>>, mode, false, endian, acc, decode_map),
    do: kr_decode_ucs4(rest, mode, false, endian, acc, decode_map)

  defp kr_decode_ucs4(<<0x0F, rest::binary>>, _mode, designated?, endian, acc, decode_map),
    do: kr_decode_ucs4(rest, :ascii, designated?, endian, acc, decode_map)

  defp kr_decode_ucs4(
         <<byte, rest::binary>>,
         :ascii,
         designated?,
         endian,
         acc,
         decode_map
       )
       when byte < 0x80,
       do:
         kr_decode_ucs4(
           rest,
           :ascii,
           designated?,
           endian,
           <<acc::binary, ucs4(byte, endian)::binary>>,
           decode_map
         )

  defp kr_decode_ucs4(input, :ksc5601, _designated?, _endian, acc, _decode_map)
       when byte_size(input) < 2,
       do: {:ok, acc}

  defp kr_decode_ucs4(
         <<first, second, rest::binary>>,
         :ksc5601,
         designated?,
         endian,
         acc,
         decode_map
       )
       when first in 0x21..0x7E and second in 0x21..0x7E do
    # The descriptor is already a validated, fixed 94x94 tuple. Keep this
    # lookup in the hot recursion instead of paying one cross-module dispatch
    # for every Korean pair in the stream.
    case elem(decode_map, (first - 0x21) * 94 + second - 0x21) do
      {big, little} when is_binary(big) and is_binary(little) ->
        bytes = if endian == :big, do: big, else: little

        kr_decode_ucs4(
          rest,
          :ksc5601,
          designated?,
          endian,
          <<acc::binary, bytes::binary>>,
          decode_map
        )

      _missing_or_malformed ->
        kr_decode_ucs4(
          <<second, rest::binary>>,
          :ksc5601,
          designated?,
          endian,
          acc,
          decode_map
        )
    end
  end

  defp kr_decode_ucs4(
         <<_discarded, rest::binary>>,
         mode,
         designated?,
         endian,
         acc,
         decode_map
       ),
       do: kr_decode_ucs4(rest, mode, designated?, endian, acc, decode_map)

  defp kr_decode(<<>>, _mode, _designated?, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp kr_decode(<<0x1B, "$)C", rest::binary>>, mode, _designated?, offset, acc),
    do: kr_decode(rest, mode, true, offset + 4, acc)

  defp kr_decode(<<0x1B, _::binary>> = input, _mode, _designated?, offset, _acc) do
    kind = if byte_size(input) < 4, do: :incomplete_sequence, else: :invalid_sequence
    {:error, kind, offset, binary_part(input, 0, min(4, byte_size(input)))}
  end

  defp kr_decode(<<0x0E, rest::binary>>, _mode, true, offset, acc),
    do: kr_decode(rest, :ksc5601, true, offset + 1, acc)

  defp kr_decode(<<0x0E, _::binary>> = input, _mode, false, offset, _acc),
    do: {:error, :invalid_sequence, offset, binary_part(input, 0, 1)}

  defp kr_decode(<<0x0F, rest::binary>>, _mode, designated?, offset, acc),
    do: kr_decode(rest, :ascii, designated?, offset + 1, acc)

  defp kr_decode(<<byte, rest::binary>>, :ascii, designated?, offset, acc) when byte < 0x80,
    do: kr_decode(rest, :ascii, designated?, offset + 1, [byte | acc])

  defp kr_decode(input, :ksc5601, _designated?, offset, _acc) when byte_size(input) < 2,
    do: {:error, :incomplete_sequence, offset, input}

  defp kr_decode(<<first, second, rest::binary>>, :ksc5601, designated?, offset, acc)
       when first < 0x80 and second < 0x80 do
    pair = <<first, second>>

    case Map.fetch(Tables.fetch!(:ksc5601).many, pair) do
      {:ok, codepoints} ->
        kr_decode(rest, :ksc5601, designated?, offset + 2, prepend(codepoints, acc))

      :error ->
        {:error, :invalid_sequence, offset, pair}
    end
  end

  defp kr_decode(input, _mode, _designated?, offset, _acc),
    do: {:error, :invalid_sequence, offset, binary_part(input, 0, min(2, byte_size(input)))}

  defp kr_decode_replace(<<>>, _mode, _designated?, _replacer, acc),
    do: {:ok, :lists.reverse(acc)}

  defp kr_decode_replace(<<0x1B, "$)C", rest::binary>>, mode, _designated?, replacer, acc),
    do: kr_decode_replace(rest, mode, true, replacer, acc)

  defp kr_decode_replace(<<0x1B, _::binary>> = input, mode, designated?, replacer, acc) do
    if byte_size(input) < 4 do
      {:ok, replace_bytes(acc, input, replacer) |> :lists.reverse()}
    else
      <<byte, rest::binary>> = input
      kr_decode_replace(rest, mode, designated?, replacer, replace(byte, replacer, acc))
    end
  end

  defp kr_decode_replace(<<0x0E, rest::binary>>, _mode, true, replacer, acc),
    do: kr_decode_replace(rest, :ksc5601, true, replacer, acc)

  defp kr_decode_replace(<<0x0E, rest::binary>>, mode, false, replacer, acc),
    do: kr_decode_replace(rest, mode, false, replacer, replace(0x0E, replacer, acc))

  defp kr_decode_replace(<<0x0F, rest::binary>>, _mode, designated?, replacer, acc),
    do: kr_decode_replace(rest, :ascii, designated?, replacer, acc)

  defp kr_decode_replace(<<byte, rest::binary>>, :ascii, designated?, replacer, acc)
       when byte < 0x80,
       do: kr_decode_replace(rest, :ascii, designated?, replacer, [byte | acc])

  defp kr_decode_replace(input, :ksc5601, _designated?, replacer, acc)
       when byte_size(input) < 2,
       do: {:ok, replace_bytes(acc, input, replacer) |> :lists.reverse()}

  defp kr_decode_replace(
         <<first, second, rest::binary>> = input,
         :ksc5601,
         designated?,
         replacer,
         acc
       )
       when first < 0x80 and second < 0x80 do
    case Map.fetch(Tables.fetch!(:ksc5601).many, <<first, second>>) do
      {:ok, codepoints} ->
        kr_decode_replace(rest, :ksc5601, designated?, replacer, prepend(codepoints, acc))

      :error ->
        <<byte, tail::binary>> = input
        kr_decode_replace(tail, :ksc5601, designated?, replacer, replace(byte, replacer, acc))
    end
  end

  defp kr_decode_replace(<<byte, rest::binary>>, mode, designated?, replacer, acc),
    do: kr_decode_replace(rest, mode, designated?, replacer, replace(byte, replacer, acc))

  defp kr_encode([], mode, _designated?, acc, _discard?, _encode_map) do
    suffix = if mode == :ascii, do: "", else: <<0x0F>>
    {:ok, acc |> :lists.reverse([suffix]) |> IO.iodata_to_binary()}
  end

  defp kr_encode([codepoint | rest], mode, designated?, acc, discard?, encode_map)
       when codepoint in 0..0x7F do
    shift = if mode == :ascii, do: "", else: <<0x0F>>
    next_designated? = if codepoint in [?\n, ?\r], do: false, else: designated?

    kr_encode(
      rest,
      :ascii,
      next_designated?,
      [<<codepoint>>, shift | acc],
      discard?,
      encode_map
    )
  end

  defp kr_encode([codepoint | rest], mode, designated?, acc, discard?, encode_map) do
    case Map.fetch(encode_map, {codepoint}) do
      {:ok, pair} ->
        designation = if designated?, do: "", else: <<0x1B, "$)C">>
        shift = if mode == :ksc5601, do: "", else: <<0x0E>>

        kr_encode(
          rest,
          :ksc5601,
          true,
          [pair, shift, designation | acc],
          discard?,
          encode_map
        )

      :error when discard? ->
        kr_encode(rest, mode, designated?, acc, discard?, encode_map)

      :error ->
        {:error, :unrepresentable_character, codepoint}
    end
  end

  defp kr_encode_ucs4_discard(<<>>, _endian, mode, _designated?, acc, _encode_map) do
    suffix = if mode == :ascii, do: "", else: <<0x0F>>
    {:ok, acc |> :lists.reverse([suffix]) |> IO.iodata_to_binary()}
  end

  defp kr_encode_ucs4_discard(input, endian, mode, designated?, acc, encode_map) do
    case skip_non_bmp_ucs4_block(input, endian) do
      {:skip, rest} ->
        kr_encode_ucs4_discard(rest, endian, mode, designated?, acc, encode_map)

      :keep ->
        {codepoint, rest} = take_explicit_ucs4(input, endian)

        cond do
          codepoint <= 0x7F ->
            shift = if mode == :ascii, do: "", else: <<0x0F>>
            next_designated? = if codepoint in [?\n, ?\r], do: false, else: designated?

            kr_encode_ucs4_discard(
              rest,
              endian,
              :ascii,
              next_designated?,
              [<<codepoint>>, shift | acc],
              encode_map
            )

          true ->
            case Map.fetch(encode_map, {codepoint}) do
              {:ok, pair} ->
                designation = if designated?, do: "", else: <<0x1B, "$)C">>
                shift = if mode == :ksc5601, do: "", else: <<0x0E>>

                kr_encode_ucs4_discard(
                  rest,
                  endian,
                  :ksc5601,
                  true,
                  [pair, shift, designation | acc],
                  encode_map
                )

              :error ->
                kr_encode_ucs4_discard(rest, endian, mode, designated?, acc, encode_map)
            end
        end
    end
  end

  defp kr_encode_substitute(
         [],
         resume,
         true,
         mode,
         designated?,
         acc,
         replacer,
         encode_map
       ),
       do:
         kr_encode_substitute(
           resume,
           [],
           false,
           mode,
           designated?,
           acc,
           replacer,
           encode_map
         )

  defp kr_encode_substitute(
         [],
         [],
         false,
         mode,
         _designated?,
         acc,
         _replacer,
         _encode_map
       ) do
    suffix = if mode == :ascii, do: "", else: <<0x0F>>
    {:ok, acc |> :lists.reverse([suffix]) |> IO.iodata_to_binary()}
  end

  defp kr_encode_substitute(
         [codepoint | rest],
         resume,
         replacement?,
         mode,
         designated?,
         acc,
         replacer,
         encode_map
       )
       when codepoint in 0..0x7F do
    shift = if mode == :ascii, do: "", else: <<0x0F>>
    next_designated? = if codepoint in [?\n, ?\r], do: false, else: designated?

    kr_encode_substitute(
      rest,
      resume,
      replacement?,
      :ascii,
      next_designated?,
      [<<codepoint>>, shift | acc],
      replacer,
      encode_map
    )
  end

  defp kr_encode_substitute(
         [codepoint | rest],
         resume,
         replacement?,
         mode,
         designated?,
         acc,
         replacer,
         encode_map
       ) do
    case Map.fetch(encode_map, {codepoint}) do
      {:ok, pair} ->
        designation = if designated?, do: "", else: <<0x1B, "$)C">>
        shift = if mode == :ksc5601, do: "", else: <<0x0E>>

        kr_encode_substitute(
          rest,
          resume,
          replacement?,
          :ksc5601,
          true,
          [pair, shift, designation | acc],
          replacer,
          encode_map
        )

      :error when replacement? ->
        {:error, :unrepresentable_character, codepoint}

      :error ->
        kr_encode_substitute(
          replacer.(codepoint),
          rest,
          true,
          mode,
          designated?,
          acc,
          replacer,
          encode_map
        )
    end
  end

  defp skip_non_bmp_ucs4_block(
         <<a::unsigned-big-32, b::unsigned-big-32, c::unsigned-big-32, d::unsigned-big-32,
           e::unsigned-big-32, f::unsigned-big-32, g::unsigned-big-32, h::unsigned-big-32,
           i::unsigned-big-32, j::unsigned-big-32, k::unsigned-big-32, l::unsigned-big-32,
           m::unsigned-big-32, n::unsigned-big-32, o::unsigned-big-32, p::unsigned-big-32,
           rest::binary>>,
         :big
       )
       when a > 0xFFFF and b > 0xFFFF and c > 0xFFFF and d > 0xFFFF and e > 0xFFFF and
              f > 0xFFFF and g > 0xFFFF and h > 0xFFFF and i > 0xFFFF and j > 0xFFFF and
              k > 0xFFFF and l > 0xFFFF and m > 0xFFFF and n > 0xFFFF and o > 0xFFFF and
              p > 0xFFFF,
       do: {:skip, rest}

  defp skip_non_bmp_ucs4_block(
         <<a::unsigned-little-32, b::unsigned-little-32, c::unsigned-little-32,
           d::unsigned-little-32, e::unsigned-little-32, f::unsigned-little-32,
           g::unsigned-little-32, h::unsigned-little-32, i::unsigned-little-32,
           j::unsigned-little-32, k::unsigned-little-32, l::unsigned-little-32,
           m::unsigned-little-32, n::unsigned-little-32, o::unsigned-little-32,
           p::unsigned-little-32, rest::binary>>,
         :little
       )
       when a > 0xFFFF and b > 0xFFFF and c > 0xFFFF and d > 0xFFFF and e > 0xFFFF and
              f > 0xFFFF and g > 0xFFFF and h > 0xFFFF and i > 0xFFFF and j > 0xFFFF and
              k > 0xFFFF and l > 0xFFFF and m > 0xFFFF and n > 0xFFFF and o > 0xFFFF and
              p > 0xFFFF,
       do: {:skip, rest}

  defp skip_non_bmp_ucs4_block(_input, _endian), do: :keep

  defp take_explicit_ucs4(<<codepoint::unsigned-big-32, rest::binary>>, :big),
    do: {codepoint, rest}

  defp take_explicit_ucs4(<<codepoint::unsigned-little-32, rest::binary>>, :little),
    do: {codepoint, rest}

  defp ucs4(codepoint, :big), do: <<codepoint::unsigned-big-32>>
  defp ucs4(codepoint, :little), do: <<codepoint::unsigned-little-32>>

  defp prepend(tuple, acc) when tuple_size(tuple) == 1, do: [elem(tuple, 0) | acc]
  defp prepend(tuple, acc), do: tuple |> Tuple.to_list() |> :lists.reverse(acc)

  defp replace(byte, replacer, acc), do: :lists.reverse(replacer.(byte), acc)
  defp replace_bytes(acc, <<>>, _replacer), do: acc

  defp replace_bytes(acc, <<byte, rest::binary>>, replacer),
    do: replace_bytes(replace(byte, replacer, acc), rest, replacer)
end

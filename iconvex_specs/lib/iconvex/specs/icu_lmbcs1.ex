defmodule Iconvex.Specs.ICULMBCS1.Data do
  @moduledoc false

  @path Path.expand("../../../priv/icu_lmbcs1.etf", __DIR__)
  @external_resource @path

  def fetch, do: Iconvex.Specs.RuntimeAsset.fetch(__MODULE__, @path)
end

defmodule Iconvex.Specs.ICULMBCS1 do
  @moduledoc """
  Pure Elixir port of ICU 78.3's Lotus Multi-Byte Character Set, LMBCS-1.

  This implements optimization group 1, all thirteen national subconverters,
  Lotus's exception and control groups, doubled single-byte MBCS forms, and
  the UTF-16 compatibility group. The annotated ICU source and every UCM
  mapping loaded by it are pinned in the source repository and bound into the
  shipped manifest by per-file and aggregate SHA-256 digests.
  """

  use Iconvex.Codec
  alias Iconvex.Specs.ICULMBCS1.Data

  @manifest_path Path.expand("../../../priv/icu_lmbcs1_manifest.etf", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()
  @sbcs_groups [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x08, 0x0B]
  @mbcs_groups [0x10, 0x11, 0x12, 0x13]
  @all_groups @sbcs_groups ++ @mbcs_groups
  @latin_locale_exceptions [0x00A7, 0x00A8, 0x00B0, 0x00B1, 0x00B4, 0x00B6, 0x00D7, 0x00F7]

  @impl true
  def canonical_name, do: @manifest.canonical_name

  def aliases, do: @manifest.aliases

  @impl true
  def codec_id, do: :icu_lmbcs1
  def aggregate_sha256, do: @manifest.aggregate_sha256
  def release, do: @manifest.release
  def revision, do: @manifest.revision
  def source_url, do: @manifest.source_url
  def sources, do: @manifest.sources

  @impl true
  def encode(codepoints) when is_list(codepoints) do
    encode(codepoints, 1)
  end

  @doc false
  def encode(codepoints, optimization_group)
      when is_list(codepoints) and optimization_group in @all_groups do
    encode_loop(codepoints, Data.fetch(), optimization_group, 0, [], false)
  end

  @impl true
  def encode_discard(codepoints) when is_list(codepoints) do
    encode_discard(codepoints, 1)
  end

  @doc false
  def encode_discard(codepoints, optimization_group)
      when is_list(codepoints) and optimization_group in @all_groups do
    encode_loop(codepoints, Data.fetch(), optimization_group, 0, [], true)
  end

  @impl true
  def encode_substitute(codepoints, replacer)
      when is_list(codepoints) and is_function(replacer, 1) do
    encode_substitute(codepoints, replacer, 1)
  end

  @doc false
  def encode_substitute(codepoints, replacer, optimization_group)
      when is_list(codepoints) and is_function(replacer, 1) and
             optimization_group in @all_groups do
    encode_substitute_loop(
      codepoints,
      [],
      false,
      Data.fetch(),
      optimization_group,
      0,
      [],
      replacer
    )
  end

  @impl true
  def decode(input) when is_binary(input) do
    decode(input, 1)
  end

  @doc false
  def decode(input, optimization_group)
      when is_binary(input) and optimization_group in @all_groups do
    decode_loop(
      input,
      Map.put(Data.fetch(), :optimization_group, optimization_group),
      0,
      [],
      nil,
      false
    )
  end

  @impl true
  def decode_discard(input) when is_binary(input) do
    decode_discard(input, 1)
  end

  @doc false
  def decode_discard(input, optimization_group)
      when is_binary(input) and optimization_group in @all_groups do
    decode_loop(
      input,
      Map.put(Data.fetch(), :optimization_group, optimization_group),
      0,
      [],
      nil,
      true
    )
  end

  @impl true
  def decode_to_utf8(input) do
    decode_to_utf8(input, 1)
  end

  @doc false
  def decode_to_utf8(input, optimization_group) do
    with {:ok, codepoints} <- decode(input, optimization_group),
         do: {:ok, List.to_string(codepoints)}
  end

  @impl true
  def encode_from_utf8(input) when is_binary(input) do
    encode_from_utf8(input, 1)
  end

  @doc false
  def encode_from_utf8(input, optimization_group)
      when is_binary(input) and optimization_group in @all_groups do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        encode(codepoints, optimization_group)

      {:error, converted, rest} ->
        {:decode_error, :invalid_sequence, utf8_size(converted), rest}

      {:incomplete, converted, rest} ->
        {:decode_error, :incomplete_sequence, utf8_size(converted), rest}
    end
  end

  @impl true
  def decode_chunk(input, final?) when is_binary(input) and is_boolean(final?),
    do: decode_chunk_for_group(input, final?, 1)

  @doc false
  def decode_chunk_for_group(input, final?, optimization_group)
      when is_binary(input) and is_boolean(final?) and optimization_group in @all_groups do
    case decode(input, optimization_group) do
      {:ok, codepoints} ->
        {:ok, codepoints, <<>>}

      {:error, :incomplete_sequence, offset, fragment} = error when not final? ->
        chunk_prefix(input, optimization_group, offset, fragment, error)

      {:error, :invalid_sequence, offset, fragment} = error when not final? ->
        pending_high_chunk(input, optimization_group, offset, fragment, error)

      error ->
        error
    end
  end

  @impl true
  def decode_error_consumption(_kind, sequence) when is_binary(sequence),
    do: max(byte_size(sequence), 1)

  @impl true
  def encode_chunk(codepoints, final?, policy)
      when is_list(codepoints) and is_boolean(final?),
      do: encode_chunk_for_group(codepoints, final?, policy, 1)

  @doc false
  def encode_chunk_for_group(codepoints, _final?, policy, optimization_group)
      when is_list(codepoints) and optimization_group in @all_groups do
    result =
      case policy do
        :error ->
          encode(codepoints, optimization_group)

        :discard ->
          encode_discard(codepoints, optimization_group)

        {:replace, replacer} when is_function(replacer, 1) ->
          encode_substitute(codepoints, replacer, optimization_group)
      end

    case result do
      {:ok, output} -> {:ok, output, []}
      error -> error
    end
  end

  defp encode_loop([], _data, _optimization_group, _last_group, acc, _discard?) do
    {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}
  end

  defp encode_loop([codepoint | rest], data, optimization_group, last_group, acc, discard?)
       when codepoint in 0..0xFFFF do
    case encode_unit(codepoint, data, optimization_group, last_group) do
      {:ok, bytes, next_group} ->
        encode_loop(rest, data, optimization_group, next_group, [bytes | acc], discard?)

      :error when discard? ->
        encode_loop(rest, data, optimization_group, last_group, acc, true)

      :error ->
        {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_loop([codepoint | rest], data, optimization_group, last_group, acc, discard?)
       when codepoint in 0x10000..0x10FFFF do
    value = codepoint - 0x10000
    lead = 0xD800 + Bitwise.bsr(value, 10)
    trail = 0xDC00 + Bitwise.band(value, 0x3FF)
    {:ok, lead_bytes, last_group} = encode_unit(lead, data, optimization_group, last_group)
    {:ok, trail_bytes, last_group} = encode_unit(trail, data, optimization_group, last_group)

    encode_loop(
      rest,
      data,
      optimization_group,
      last_group,
      [[lead_bytes, trail_bytes] | acc],
      discard?
    )
  end

  defp encode_loop([_codepoint | rest], data, optimization_group, last_group, acc, true) do
    encode_loop(rest, data, optimization_group, last_group, acc, true)
  end

  defp encode_loop(
         [codepoint | _rest],
         _data,
         _optimization_group,
         _last_group,
         _acc,
         false
       ) do
    {:error, :unrepresentable_character, codepoint}
  end

  defp encode_substitute_loop(
         [],
         resume,
         true,
         data,
         optimization_group,
         last_group,
         acc,
         replacer
       ),
       do:
         encode_substitute_loop(
           resume,
           [],
           false,
           data,
           optimization_group,
           last_group,
           acc,
           replacer
         )

  defp encode_substitute_loop(
         [],
         [],
         false,
         _data,
         _optimization_group,
         _last_group,
         acc,
         _replacer
       ),
       do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute_loop(
         [codepoint | rest],
         resume,
         replacement?,
         data,
         optimization_group,
         last_group,
         acc,
         replacer
       )
       when codepoint in 0..0xFFFF do
    case encode_unit(codepoint, data, optimization_group, last_group) do
      {:ok, bytes, next_group} ->
        encode_substitute_loop(
          rest,
          resume,
          replacement?,
          data,
          optimization_group,
          next_group,
          [bytes | acc],
          replacer
        )

      :error when replacement? ->
        {:error, :unrepresentable_character, codepoint}

      :error ->
        encode_substitute_loop(
          replacer.(codepoint),
          rest,
          true,
          data,
          optimization_group,
          last_group,
          acc,
          replacer
        )
    end
  end

  defp encode_substitute_loop(
         [codepoint | rest],
         resume,
         replacement?,
         data,
         optimization_group,
         last_group,
         acc,
         replacer
       )
       when codepoint in 0x10000..0x10FFFF do
    value = codepoint - 0x10000
    lead = 0xD800 + Bitwise.bsr(value, 10)
    trail = 0xDC00 + Bitwise.band(value, 0x3FF)
    {:ok, lead_bytes, last_group} = encode_unit(lead, data, optimization_group, last_group)
    {:ok, trail_bytes, last_group} = encode_unit(trail, data, optimization_group, last_group)

    encode_substitute_loop(
      rest,
      resume,
      replacement?,
      data,
      optimization_group,
      last_group,
      [[lead_bytes, trail_bytes] | acc],
      replacer
    )
  end

  defp encode_substitute_loop(
         [codepoint | _rest],
         _resume,
         true,
         _data,
         _optimization_group,
         _last_group,
         _acc,
         _replacer
       ),
       do: {:error, :unrepresentable_character, codepoint}

  defp encode_substitute_loop(
         [codepoint | rest],
         _resume,
         false,
         data,
         optimization_group,
         last_group,
         acc,
         replacer
       ),
       do:
         encode_substitute_loop(
           replacer.(codepoint),
           rest,
           true,
           data,
           optimization_group,
           last_group,
           acc,
           replacer
         )

  defp encode_unit(unit, _data, _optimization_group, last_group)
       when (unit > 0x1F and unit < 0x80) or unit in [0, 0x09, 0x0A, 0x0D, 0x19] do
    {:ok, <<unit>>, last_group}
  end

  defp encode_unit(unit, data, optimization_group, last_group) do
    group = :binary.at(data.classification, unit)

    cond do
      group == 0x14 ->
        {:ok, unicode_group(unit), last_group}

      group == 0x0F ->
        {:ok, control_group(unit), last_group}

      group < 0x14 ->
        case conversion_worker(group, unit, data, optimization_group, last_group) do
          {:ok, bytes, next_group} ->
            select_result(bytes, next_group)

          {:miss, next_group} ->
            select_ambiguous(group, unit, data, optimization_group, next_group)
        end

      true ->
        select_ambiguous(group, unit, data, optimization_group, last_group)
    end
  end

  defp select_result(bytes, group), do: {:ok, bytes, group}

  defp select_ambiguous(class, unit, data, optimization_group, last_group) do
    locale_group = latin_locale_group(unit)

    with {:miss, last_group, tried} <-
           try_nondefault_compatibility(
             optimization_group,
             class,
             unit,
             data,
             last_group,
             0
           ),
         {:miss, last_group, tried} <-
           try_if_matching(
             locale_group,
             class,
             unit,
             data,
             optimization_group,
             last_group,
             tried
           ),
         {:miss, last_group, tried} <-
           try_if_matching(
             last_group,
             class,
             unit,
             data,
             optimization_group,
             last_group,
             tried
           ),
         {:miss, last_group, tried} <-
           try_groups(
             candidate_groups(class),
             unit,
             data,
             optimization_group,
             last_group,
             tried
           ),
         {:miss, last_group, _tried} <-
           try_exception(class, unit, data, optimization_group, last_group, tried) do
      {:ok, unicode_group(unit), last_group}
    else
      {:ok, bytes, group, _tried} -> {:ok, bytes, group}
    end
  end

  # ICU 78.3's non-default compatibility branch deliberately checks Latin-1
  # and the Lotus exception table before its normal candidate scan. Although
  # the upstream comment calls this an optimization-group check, the executable
  # code selects localeConverterIndex; without a requested locale that is zero
  # except for the temporary Latin-1 rule applied to U+0080..U+00FF.
  defp try_nondefault_compatibility(1, _class, _unit, _data, last_group, tried),
    do: {:miss, last_group, tried}

  defp try_nondefault_compatibility(
         optimization_group,
         class,
         unit,
         data,
         last_group,
         tried
       ) do
    if ambiguous_match?(class, optimization_group) do
      case try_group(1, unit, data, optimization_group, last_group, tried, false) do
        {:ok, _bytes, _group, _tried} = found ->
          found

        {:miss, next_group, tried} ->
          try_group(0, unit, data, optimization_group, next_group, tried, false)
      end
    else
      {:miss, last_group, tried}
    end
  end

  defp try_if_matching(
         0,
         _class,
         _unit,
         _data,
         _optimization_group,
         last_group,
         tried
       ),
       do: {:miss, last_group, tried}

  defp try_if_matching(
         group,
         class,
         unit,
         data,
         optimization_group,
         last_group,
         tried
       ) do
    if ambiguous_match?(class, group),
      do: try_group(group, unit, data, optimization_group, last_group, tried, false),
      else: {:miss, last_group, tried}
  end

  defp try_groups([], _unit, _data, _optimization_group, last_group, tried),
    do: {:miss, last_group, tried}

  defp try_groups([group | rest], unit, data, optimization_group, last_group, tried) do
    case try_group(group, unit, data, optimization_group, last_group, tried, true) do
      {:ok, _bytes, _group, _tried} = found ->
        found

      {:miss, next_group, tried} ->
        try_groups(rest, unit, data, optimization_group, next_group, tried)
    end
  end

  defp try_exception(0x81, _unit, _data, _optimization_group, last_group, tried),
    do: {:miss, last_group, tried}

  defp try_exception(_class, unit, data, optimization_group, last_group, tried),
    do: try_group(0, unit, data, optimization_group, last_group, tried, false)

  defp try_group(group, unit, data, optimization_group, last_group, tried, honor_tried?) do
    bit = Bitwise.bsl(1, group)

    if honor_tried? and Bitwise.band(tried, bit) != 0 do
      {:miss, last_group, tried}
    else
      tried = Bitwise.bor(tried, bit)

      case conversion_worker(group, unit, data, optimization_group, last_group) do
        {:ok, bytes, next_group} -> {:ok, bytes, next_group, tried}
        {:miss, next_group} -> {:miss, next_group, tried}
      end
    end
  end

  defp conversion_worker(group, unit, data, optimization_group, last_group) do
    case Map.fetch(Map.fetch!(data.groups, group).encode, unit) do
      {:ok, <<first, _::binary>> = converted} ->
        if byte_size(converted) == 1 and first < 0x20 do
          {:miss, group}
        else
          {:ok, format_group(group, converted, optimization_group), group}
        end

      :error ->
        {:miss, last_group}
    end
  end

  defp format_group(0, converted, _optimization_group), do: converted

  defp format_group(group, converted, group), do: converted

  defp format_group(group, <<byte>>, _optimization_group) when group >= 0x10,
    do: <<group, group, byte>>

  defp format_group(group, converted, _optimization_group),
    do: <<group, converted::binary>>

  defp unicode_group(unit) do
    high = Bitwise.bsr(unit, 8)
    low = Bitwise.band(unit, 0xFF)
    if low == 0, do: <<0x14, 0xF6, high>>, else: <<0x14, high, low>>
  end

  defp control_group(unit) when unit <= 0x1F, do: <<0x0F, unit + 0x20>>
  defp control_group(unit), do: <<0x0F, unit>>

  defp latin_locale_group(unit) when unit in 0x80..0xFF and unit not in @latin_locale_exceptions,
    do: 1

  defp latin_locale_group(_unit), do: 0
  defp ambiguous_match?(0x80, group), do: group < 0x10
  defp ambiguous_match?(0x81, group), do: group >= 0x10
  defp ambiguous_match?(0x82, _group), do: true
  defp ambiguous_match?(_class, _group), do: false
  defp candidate_groups(0x81), do: @mbcs_groups
  defp candidate_groups(0x82), do: @all_groups
  defp candidate_groups(_class), do: @sbcs_groups

  defp decode_loop(<<>>, _data, _offset, acc, nil, _discard?),
    do: {:ok, :lists.reverse(acc)}

  defp decode_loop(<<>>, _data, _offset, acc, {_lead, _pending_offset, _fragment}, true),
    do: {:ok, :lists.reverse(acc)}

  defp decode_loop(<<>>, _data, _offset, _acc, {_lead, pending_offset, fragment}, false),
    do: {:error, :invalid_sequence, pending_offset, fragment}

  defp decode_loop(input, data, offset, acc, pending, discard?) do
    case decode_one(input, data) do
      {:ok, unit, size} ->
        fragment = binary_part(input, 0, size)
        <<_::binary-size(size), rest::binary>> = input

        append_unit(
          unit,
          fragment,
          rest,
          data,
          offset,
          size,
          acc,
          pending,
          discard?
        )

      :incomplete ->
        cond do
          not discard? and not is_nil(pending) ->
            pending_surrogate_error(pending)

          discard? ->
            {:ok, :lists.reverse(acc)}

          true ->
            {:error, :incomplete_sequence, offset, input}
        end

      {:invalid, _size} when not discard? and not is_nil(pending) ->
        pending_surrogate_error(pending)

      {:invalid, size} when discard? ->
        size = min(max(size, 1), byte_size(input))
        <<_::binary-size(size), rest::binary>> = input
        decode_loop(rest, data, offset + size, acc, nil, true)

      {:invalid, size} ->
        size = min(max(size, 1), byte_size(input))
        {:error, :invalid_sequence, offset, binary_part(input, 0, size)}
    end
  end

  defp append_unit(unit, fragment, rest, data, offset, size, acc, nil, discard?)
       when unit in 0xD800..0xDBFF do
    decode_loop(rest, data, offset + size, acc, {unit, offset, fragment}, discard?)
  end

  defp append_unit(
         unit,
         _fragment,
         rest,
         data,
         offset,
         size,
         acc,
         {lead, _lead_offset, _},
         discard?
       )
       when unit in 0xDC00..0xDFFF do
    codepoint = 0x10000 + Bitwise.bsl(lead - 0xD800, 10) + unit - 0xDC00
    decode_loop(rest, data, offset + size, [codepoint | acc], nil, discard?)
  end

  defp append_unit(unit, _fragment, rest, data, offset, size, acc, nil, true)
       when unit in 0xDC00..0xDFFF do
    decode_loop(rest, data, offset + size, acc, nil, true)
  end

  defp append_unit(unit, fragment, _rest, _data, offset, _size, _acc, nil, false)
       when unit in 0xDC00..0xDFFF do
    {:error, :invalid_sequence, offset, fragment}
  end

  defp append_unit(
         unit,
         fragment,
         rest,
         data,
         offset,
         size,
         acc,
         {_lead, _lead_offset, _lead_fragment},
         true
       ) do
    append_unit(unit, fragment, rest, data, offset, size, acc, nil, true)
  end

  defp append_unit(
         _unit,
         _fragment,
         _rest,
         _data,
         _offset,
         _size,
         _acc,
         {_lead, lead_offset, lead_fragment},
         false
       ) do
    {:error, :invalid_sequence, lead_offset, lead_fragment}
  end

  defp append_unit(unit, _fragment, rest, data, offset, size, acc, nil, discard?) do
    decode_loop(rest, data, offset + size, [unit | acc], nil, discard?)
  end

  defp decode_one(<<byte, _::binary>>, _data)
       when (byte > 0x1F and byte < 0x80) or byte in [0, 0x09, 0x0A, 0x0D, 0x19],
       do: {:ok, byte, 1}

  defp decode_one(<<0x0F>>, _data), do: :incomplete

  defp decode_one(<<0x0F, byte, _::binary>>, _data) do
    cond do
      byte < 0x20 -> {:invalid, 2}
      byte < 0x80 -> {:ok, byte - 0x20, 2}
      true -> {:ok, byte, 2}
    end
  end

  defp decode_one(<<0x14, _::binary>> = input, _data) when byte_size(input) < 3,
    do: :incomplete

  defp decode_one(<<0x14, high, low, _::binary>>, _data) do
    unit = if high == 0xF6, do: Bitwise.bsl(low, 8), else: Bitwise.bsl(high, 8) + low
    if unit >= 0xFFFE, do: {:invalid, 3}, else: {:ok, unit, 3}
  end

  defp decode_one(<<group, _::binary>> = input, data) when group <= 0x20 do
    case Map.fetch(data.groups, group) do
      :error ->
        {:invalid, 1}

      {:ok, table} when group >= 0x10 ->
        decode_mbcs_group(input, group, table.decode)

      {:ok, table} ->
        decode_sbcs_group(input, group, table.decode, data.groups[0].decode)
    end
  end

  defp decode_one(<<byte, _::binary>> = input, data) when byte >= 0x80 do
    optimization_group = data.optimization_group
    table = Map.fetch!(data.groups, optimization_group)

    if optimization_group >= 0x10 do
      decode_implicit_mbcs(input, optimization_group, table.decode)
    else
      case Map.fetch(table.decode, <<byte>>) do
        {:ok, unit} -> {:ok, unit, 1}
        :error -> {:invalid, 1}
      end
    end
  end

  defp decode_one(_input, _data), do: {:invalid, 1}

  defp decode_sbcs_group(<<_input_group>>, _expected_group, _decode, _exceptions),
    do: :incomplete

  defp decode_sbcs_group(<<group, byte, _::binary>>, _group, decode, exceptions) do
    mapping = if byte >= 0x80, do: decode, else: exceptions
    key = if byte >= 0x80, do: <<byte>>, else: <<group, byte>>

    case Map.fetch(mapping, key) do
      {:ok, unit} -> {:ok, unit, 2}
      :error -> {:invalid, 2}
    end
  end

  defp decode_mbcs_group(input, _group, _decode) when byte_size(input) < 3,
    do: :incomplete

  defp decode_mbcs_group(<<group, first, second, _::binary>>, group, decode) do
    key = if first == group, do: <<second>>, else: <<first, second>>

    case Map.fetch(decode, key) do
      {:ok, unit} -> {:ok, unit, 3}
      :error -> {:invalid, 3}
    end
  end

  defp decode_implicit_mbcs(<<first>>, group, decode) do
    if mbcs_lead_byte?(group, first) do
      :incomplete
    else
      case Map.fetch(decode, <<first>>) do
        {:ok, unit} -> {:ok, unit, 1}
        :error -> {:invalid, 1}
      end
    end
  end

  defp decode_implicit_mbcs(<<first, second, _::binary>>, group, decode) do
    if mbcs_lead_byte?(group, first) do
      case Map.fetch(decode, <<first, second>>) do
        {:ok, unit} -> {:ok, unit, 2}
        :error -> {:invalid, 2}
      end
    else
      case Map.fetch(decode, <<first>>) do
        {:ok, unit} -> {:ok, unit, 1}
        :error -> {:invalid, 1}
      end
    end
  end

  # Exact state-machine lead ranges pinned in the four ICU 78.3 UCM headers.
  defp mbcs_lead_byte?(0x10, byte),
    do: byte in 0x81..0x9F or byte in 0xE0..0xFC

  defp mbcs_lead_byte?(group, byte) when group in [0x11, 0x12, 0x13],
    do: byte in 0x81..0xFE

  defp chunk_prefix(input, optimization_group, offset, fragment, original_error) do
    if offset + byte_size(fragment) == byte_size(input) do
      prefix = binary_part(input, 0, offset)

      case decode(prefix, optimization_group) do
        {:ok, codepoints} ->
          {:ok, codepoints, fragment}

        {:error, :invalid_sequence, pending_offset, pending_fragment}
        when pending_offset + byte_size(pending_fragment) == byte_size(prefix) ->
          if high_surrogate_fragment?(pending_fragment) do
            stable = binary_part(prefix, 0, pending_offset)

            case decode(stable, optimization_group) do
              {:ok, codepoints} ->
                pending = binary_part(input, pending_offset, byte_size(input) - pending_offset)
                {:ok, codepoints, pending}

              _invalid_stable_prefix ->
                original_error
            end
          else
            original_error
          end

        _invalid_prefix ->
          original_error
      end
    else
      original_error
    end
  end

  defp pending_high_chunk(input, optimization_group, offset, fragment, original_error) do
    suffix_offset = offset + byte_size(fragment)

    if high_surrogate_fragment?(fragment) and suffix_offset <= byte_size(input) do
      suffix = binary_part(input, suffix_offset, byte_size(input) - suffix_offset)

      if suffix == <<>> or potentially_low_surrogate_fragment?(suffix) do
        stable = binary_part(input, 0, offset)

        case decode(stable, optimization_group) do
          {:ok, codepoints} ->
            pending = binary_part(input, offset, byte_size(input) - offset)
            {:ok, codepoints, pending}

          _invalid_stable_prefix ->
            original_error
        end
      else
        original_error
      end
    else
      original_error
    end
  end

  defp high_surrogate_fragment?(<<0x14, high, low>>) do
    unit = if high == 0xF6, do: Bitwise.bsl(low, 8), else: Bitwise.bsl(high, 8) + low
    unit in 0xD800..0xDBFF
  end

  defp high_surrogate_fragment?(_fragment), do: false

  defp pending_surrogate_error({_lead, offset, fragment}),
    do: {:error, :invalid_sequence, offset, fragment}

  defp potentially_low_surrogate_fragment?(<<0x14>>), do: true
  defp potentially_low_surrogate_fragment?(<<0x14, 0xF6>>), do: true

  defp potentially_low_surrogate_fragment?(<<0x14, high>>)
       when high in 0xDC..0xDF,
       do: true

  defp potentially_low_surrogate_fragment?(_fragment), do: false

  defp utf8_size(codepoints), do: codepoints |> List.to_string() |> byte_size()
end

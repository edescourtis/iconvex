defmodule Iconvex.Specs.UTF6 do
  @moduledoc """
  Native implementation of `draft-ietf-idn-utf6-00`.

  UTF-6 is a whole-hostname ASCII-compatible transform. Each dot-separated
  component is compressed as UTF-16 code units, encoded with variable-length
  hexadecimal values, and prefixed with `wq--`. It is not the unrelated UTF-6
  alias sometimes used for CESU-8.
  """

  use Iconvex.Codec

  import Bitwise

  @source_dir Path.expand("../../../priv/sources/draft-ietf-idn-utf6-00", __DIR__)
  @draft Path.join(@source_dir, "draft-ietf-idn-utf6-00.txt")
  @metadata Path.join(@source_dir, "SOURCE_METADATA.md")
  @upstream_notice Path.join(@source_dir, "UPSTREAM-NOTICE.txt")
  @external_resource @draft
  @external_resource @metadata
  @external_resource @upstream_notice
  @draft_sha256 "80033b5e41bc9f2fd01bddf99a300827b837f06ba93ef303bc54bc53df3755ca"
  @prefix "wq--"
  @max_label_bytes 63
  @max_minimal_payload_units @max_label_bytes - byte_size(@prefix)

  @impl true
  def canonical_name, do: "UTF-6"

  @impl true
  def aliases, do: ["UTF6", "DRAFT-IETF-IDN-UTF6-00"]

  @impl true
  def codec_id, do: :utf6_draft_ietf_idn_00

  def draft_revision, do: "draft-ietf-idn-utf6-00"
  def source_sha256, do: @draft_sha256

  @impl true
  def decode_error_recovery, do: :stop

  @impl true
  def decode_error_consumption(_kind, sequence) when is_binary(sequence),
    do: max(byte_size(sequence), 1)

  @impl true
  def decode(input) when is_binary(input) do
    case decode_host(input) do
      {:ok, codepoints} -> {:ok, codepoints}
      {:error, kind, offset, sequence, _partial} -> {:error, kind, offset, sequence}
    end
  end

  @impl true
  def decode_discard(input) when is_binary(input) do
    case decode_host(input) do
      {:ok, codepoints} -> {:ok, codepoints}
      {:error, _kind, _offset, _sequence, partial} -> {:ok, partial}
    end
  end

  @impl true
  def encode(codepoints) when is_list(codepoints) do
    case codepoints do
      [] -> {:ok, <<>>}
      _ -> encode_components(codepoints, [])
    end
  end

  @impl true
  def encode_discard(codepoints) when is_list(codepoints),
    do: encode_discard_components(codepoints, [], [], 0)

  @impl true
  def encode_substitute(codepoints, replacer)
      when is_list(codepoints) and is_function(replacer, 1) do
    codepoints
    |> Enum.map(&{&1, true})
    |> encode_with_substitution(replacer)
  end

  @impl true
  def decode_to_utf8(input) when is_binary(input) do
    with {:ok, codepoints} <- decode(input), do: {:ok, List.to_string(codepoints)}
  end

  @impl true
  def encode_from_utf8(input) when is_binary(input) do
    if String.valid?(input) do
      encode(String.to_charlist(input))
    else
      Iconvex.Specs.CodecSupport.malformed_utf8(input)
    end
  end

  defp encode_components(codepoints, acc) do
    case take_component(codepoints, [], 0) do
      {:ok, component, [], false} ->
        with {:ok, label} <- encode_component(component) do
          {:ok, [label | acc] |> :lists.reverse() |> IO.iodata_to_binary()}
        end

      {:ok, component, [], true} ->
        with {:ok, _label} <- encode_component(component) do
          {:error, :unrepresentable_character, ?.}
        end

      {:ok, component, rest, true} ->
        with {:ok, label} <- encode_component(component) do
          encode_components(rest, [".", label | acc])
        end

      {:error, codepoint} ->
        {:error, :unrepresentable_character, codepoint}
    end
  end

  defp take_component([], acc, _unit_count),
    do: {:ok, :lists.reverse(acc), [], false}

  defp take_component([?. | _rest], [], _unit_count), do: {:error, ?.}

  defp take_component([?. | rest], acc, _unit_count),
    do: {:ok, :lists.reverse(acc), rest, true}

  defp take_component([codepoint | rest], acc, unit_count) do
    if valid_scalar?(codepoint) do
      additional_units = if codepoint > 0xFFFF, do: 2, else: 1
      next_count = unit_count + additional_units

      if next_count > @max_minimal_payload_units do
        {:error, codepoint}
      else
        take_component(rest, [codepoint | acc], next_count)
      end
    else
      {:error, codepoint}
    end
  end

  defp encode_component(component) do
    if :lists.last(component) == ?- do
      {:error, :unrepresentable_character, ?-}
    else
      units = to_utf16_units(component, [])
      {header, header_size, mask} = compression_header(units)
      {payload, payload_size} = encode_units(units, mask, [], 0)
      label_size = byte_size(@prefix) + header_size + payload_size

      if label_size <= @max_label_bytes do
        {:ok, IO.iodata_to_binary([@prefix, header, payload])}
      else
        {:error, :unrepresentable_character, :lists.last(component)}
      end
    end
  end

  defp to_utf16_units([], acc), do: :lists.reverse(acc)

  defp to_utf16_units([?- | rest], acc),
    do: to_utf16_units(rest, [:hyphen | acc])

  defp to_utf16_units([codepoint | rest], acc) when codepoint <= 0xFFFF,
    do: to_utf16_units(rest, [codepoint | acc])

  defp to_utf16_units([codepoint | rest], acc) do
    value = codepoint - 0x10000
    high = 0xD800 + (value >>> 10)
    low = 0xDC00 + (value &&& 0x3FF)
    to_utf16_units(rest, [low, high | acc])
  end

  defp compression_header(units) do
    {count, high_byte, high_nibble, same_byte?, same_nibble?} =
      compression_state(units, 0, nil, nil, true, true)

    cond do
      count < 2 ->
        {[], 0, 0xFFFF}

      same_byte? ->
        encoded = encode_vle(high_byte)
        {["y", encoded], 1 + byte_size(encoded), 0x00FF}

      same_nibble? ->
        encoded = encode_vle(high_nibble)
        {["z", encoded], 1 + byte_size(encoded), 0x0FFF}

      true ->
        {[], 0, 0xFFFF}
    end
  end

  defp compression_state([], count, high_byte, high_nibble, same_byte?, same_nibble?),
    do: {count, high_byte, high_nibble, same_byte?, same_nibble?}

  defp compression_state(
         [:hyphen | rest],
         count,
         high_byte,
         high_nibble,
         same_byte?,
         same_nibble?
       ),
       do: compression_state(rest, count, high_byte, high_nibble, same_byte?, same_nibble?)

  defp compression_state([unit | rest], 0, _high_byte, _high_nibble, _same_byte?, _same_nibble?) do
    compression_state(rest, 1, unit >>> 8, unit >>> 12, true, true)
  end

  defp compression_state([unit | rest], count, high_byte, high_nibble, same_byte?, same_nibble?) do
    compression_state(
      rest,
      count + 1,
      high_byte,
      high_nibble,
      same_byte? and unit >>> 8 == high_byte,
      same_nibble? and unit >>> 12 == high_nibble
    )
  end

  defp encode_units([], _mask, acc, size), do: {:lists.reverse(acc), size}

  defp encode_units([:hyphen | rest], mask, acc, size),
    do: encode_units(rest, mask, ["-" | acc], size + 1)

  defp encode_units([unit | rest], mask, acc, size) do
    encoded = encode_vle(unit &&& mask)
    encode_units(rest, mask, [encoded | acc], size + byte_size(encoded))
  end

  defp encode_vle(value) when value <= 0xF, do: <<?g + value>>

  defp encode_vle(value) when value <= 0xFF,
    do: <<?g + (value >>> 4), hex_digit(value &&& 0xF)>>

  defp encode_vle(value) when value <= 0xFFF,
    do: <<?g + (value >>> 8), hex_digit(value >>> 4 &&& 0xF), hex_digit(value &&& 0xF)>>

  defp encode_vle(value),
    do:
      <<?g + (value >>> 12), hex_digit(value >>> 8 &&& 0xF), hex_digit(value >>> 4 &&& 0xF),
        hex_digit(value &&& 0xF)>>

  defp hex_digit(value) when value < 10, do: ?0 + value
  defp hex_digit(value), do: ?a + value - 10

  defp decode_host(<<>>), do: {:ok, []}
  defp decode_host(input), do: decode_labels(input, 0, [], false)

  defp decode_labels(input, base_offset, acc, separator_pending?) do
    case :binary.match(input, ".") do
      :nomatch ->
        decode_last_label(input, base_offset, acc, separator_pending?)

      {0, 1} ->
        {:error, :invalid_sequence, base_offset, ".", :lists.reverse(acc)}

      {label_size, 1} ->
        label = binary_part(input, 0, label_size)
        rest_size = byte_size(input) - label_size - 1
        rest = binary_part(input, label_size + 1, rest_size)

        case decode_label(label, base_offset) do
          {:ok, component} ->
            next_acc = merge_component(component, acc, separator_pending?)

            if rest == <<>> do
              {:error, :invalid_sequence, base_offset + label_size, ".", :lists.reverse(next_acc)}
            else
              decode_labels(rest, base_offset + label_size + 1, next_acc, true)
            end

          {:error, kind, offset, sequence, partial} ->
            partial_acc = merge_partial(partial, acc, separator_pending?)
            {:error, kind, offset, sequence, :lists.reverse(partial_acc)}
        end
    end
  end

  defp decode_last_label(label, base_offset, acc, separator_pending?) do
    case decode_label(label, base_offset) do
      {:ok, component} ->
        component
        |> merge_component(acc, separator_pending?)
        |> :lists.reverse()
        |> then(&{:ok, &1})

      {:error, kind, offset, sequence, partial} ->
        partial_acc = merge_partial(partial, acc, separator_pending?)
        {:error, kind, offset, sequence, :lists.reverse(partial_acc)}
    end
  end

  defp merge_component(component, acc, separator_pending?) do
    acc = if separator_pending?, do: [?. | acc], else: acc
    Enum.reduce(component, acc, fn codepoint, output -> [codepoint | output] end)
  end

  defp merge_partial([], acc, _separator_pending?), do: acc

  defp merge_partial(partial, acc, separator_pending?),
    do: merge_component(partial, acc, separator_pending?)

  defp decode_label(label, base_offset) do
    with :ok <- validate_label(label, base_offset),
         {:ok, payload} <- remove_prefix(label, base_offset) do
      decode_payload(payload, base_offset + byte_size(@prefix))
    else
      {:error, kind, offset, sequence} -> {:error, kind, offset, sequence, []}
    end
  end

  defp validate_label(label, base_offset) when byte_size(label) > @max_label_bytes do
    byte = binary_part(label, @max_label_bytes, 1)
    {:error, :invalid_sequence, base_offset + @max_label_bytes, byte}
  end

  defp validate_label(label, base_offset) do
    with :ok <- validate_label_bytes(label, base_offset, 0),
         :ok <- validate_label_edges(label, base_offset) do
      :ok
    end
  end

  defp validate_label_bytes(<<>>, _base_offset, _index), do: :ok

  defp validate_label_bytes(<<byte, rest::binary>>, base_offset, index) do
    if dns_label_byte?(byte) do
      validate_label_bytes(rest, base_offset, index + 1)
    else
      {:error, :invalid_sequence, base_offset + index, <<byte>>}
    end
  end

  defp validate_label_edges(<<>>, base_offset),
    do: {:error, :invalid_sequence, base_offset, "."}

  defp validate_label_edges(label, base_offset) do
    first = :binary.first(label)
    last_index = byte_size(label) - 1
    last = :binary.at(label, last_index)

    cond do
      not ascii_alnum?(first) ->
        {:error, :invalid_sequence, base_offset, <<first>>}

      not ascii_alnum?(last) ->
        {:error, :invalid_sequence, base_offset + last_index, <<last>>}

      true ->
        :ok
    end
  end

  defp remove_prefix(label, base_offset) when byte_size(label) < byte_size(@prefix) do
    compare_short_prefix(label, @prefix, base_offset, 0)
  end

  defp remove_prefix(<<a, b, c, d, payload::binary>>, base_offset) do
    expected = [?w, ?q, ?-, ?-]
    actual = [ascii_lower(a), ascii_lower(b), c, d]

    case first_mismatch(actual, expected, 0) do
      nil ->
        {:ok, payload}

      index ->
        {:error, :invalid_sequence, base_offset + index, <<:binary.at(<<a, b, c, d>>, index)>>}
    end
  end

  defp compare_short_prefix(<<>>, _expected, base_offset, index),
    do: {:error, :incomplete_sequence, base_offset, binary_part(@prefix, 0, max(index, 1))}

  defp compare_short_prefix(
         <<byte, rest::binary>>,
         <<expected, expected_rest::binary>>,
         base_offset,
         index
       ) do
    actual = if expected in ?a..?z, do: ascii_lower(byte), else: byte

    if actual == expected do
      compare_short_prefix(rest, expected_rest, base_offset, index + 1)
    else
      {:error, :invalid_sequence, base_offset + index, <<byte>>}
    end
  end

  defp first_mismatch([], [], _index), do: nil

  defp first_mismatch([same | rest], [same | expected], index),
    do: first_mismatch(rest, expected, index + 1)

  defp first_mismatch(_actual, _expected, index), do: index

  defp decode_payload(<<header, rest::binary>> = payload, base_offset)
       when header in [?y, ?Y, ?z, ?Z] do
    if rest == <<>> do
      {:error, :incomplete_sequence, base_offset, <<header>>, []}
    else
      {maximum, shift} = if ascii_lower(header) == ?y, do: {0xFF, 8}, else: {0xF, 12}

      case take_vle(rest, base_offset + 1, maximum) do
        {:ok, common, remaining, consumed, _raw} ->
          if remaining == <<>> do
            {:error, :invalid_sequence, base_offset, payload, []}
          else
            parse_units(
              remaining,
              base_offset + 1 + consumed,
              common <<< shift,
              if(shift == 8, do: 0xFF, else: 0xFFF),
              nil,
              []
            )
          end

        {:error, kind, offset, sequence} ->
          {:error, kind, offset, sequence, []}
      end
    end
  end

  defp decode_payload(payload, base_offset),
    do: parse_units(payload, base_offset, 0, 0xFFFF, nil, [])

  defp parse_units(<<>>, _offset, _common, _maximum, nil, acc),
    do: {:ok, :lists.reverse(acc)}

  defp parse_units(<<>>, _offset, _common, _maximum, {_high, high_offset, raw}, acc),
    do: {:error, :incomplete_sequence, high_offset, raw, :lists.reverse(acc)}

  defp parse_units(<<?-, rest::binary>>, offset, common, maximum, pending_high, acc) do
    accept_unit(?-, offset, "-", rest, offset + 1, common, maximum, pending_high, acc)
  end

  defp parse_units(input, offset, common, maximum, pending_high, acc) do
    case take_vle(input, offset, maximum) do
      {:ok, partial, rest, consumed, raw} ->
        accept_unit(
          common + partial,
          offset,
          raw,
          rest,
          offset + consumed,
          common,
          maximum,
          pending_high,
          acc
        )

      {:error, kind, error_offset, sequence} ->
        {:error, kind, error_offset, sequence, :lists.reverse(acc)}
    end
  end

  defp accept_unit(
         unit,
         unit_offset,
         raw,
         rest,
         next_offset,
         common,
         maximum,
         nil,
         acc
       )
       when unit in 0xD800..0xDBFF do
    parse_units(rest, next_offset, common, maximum, {unit, unit_offset, raw}, acc)
  end

  defp accept_unit(
         unit,
         unit_offset,
         raw,
         _rest,
         _next_offset,
         _common,
         _maximum,
         nil,
         acc
       )
       when unit in 0xDC00..0xDFFF do
    {:error, :invalid_sequence, unit_offset, raw, :lists.reverse(acc)}
  end

  defp accept_unit(
         unit,
         unit_offset,
         raw,
         _rest,
         _next_offset,
         _common,
         _maximum,
         {high, high_offset, high_raw},
         acc
       )
       when unit not in 0xDC00..0xDFFF do
    _ = {unit_offset, raw, high}
    {:error, :invalid_sequence, high_offset, high_raw, :lists.reverse(acc)}
  end

  defp accept_unit(
         low,
         _unit_offset,
         _raw,
         rest,
         next_offset,
         common,
         maximum,
         {high, _high_offset, _high_raw},
         acc
       ) do
    scalar = 0x10000 + ((high - 0xD800) <<< 10) + (low - 0xDC00)
    parse_units(rest, next_offset, common, maximum, nil, [scalar | acc])
  end

  defp accept_unit(unit, _unit_offset, _raw, rest, next_offset, common, maximum, nil, acc),
    do: parse_units(rest, next_offset, common, maximum, nil, [unit | acc])

  defp take_vle(<<byte, rest::binary>>, offset, maximum) do
    initial = ascii_lower(byte)

    if initial in ?g..?v do
      take_vle_cont(rest, offset, maximum, initial - ?g, <<byte>>, 1)
    else
      {:error, :invalid_sequence, offset, <<byte>>}
    end
  end

  defp take_vle(<<>>, offset, _maximum),
    do: {:error, :incomplete_sequence, offset, "?"}

  defp take_vle_cont(<<byte, rest::binary>> = input, offset, maximum, value, raw, consumed) do
    case hex_value(byte) do
      {:ok, digit} ->
        next_value = value <<< 4 ||| digit
        next_raw = raw <> <<byte>>

        if next_value <= maximum do
          take_vle_cont(rest, offset, maximum, next_value, next_raw, consumed + 1)
        else
          {:error, :invalid_sequence, offset, next_raw}
        end

      :error ->
        {:ok, value, input, consumed, raw}
    end
  end

  defp take_vle_cont(<<>>, _offset, _maximum, value, raw, consumed),
    do: {:ok, value, <<>>, consumed, raw}

  defp hex_value(byte) when byte in ?0..?9, do: {:ok, byte - ?0}
  defp hex_value(byte) when byte in ?a..?f, do: {:ok, byte - ?a + 10}
  defp hex_value(byte) when byte in ?A..?F, do: {:ok, byte - ?A + 10}
  defp hex_value(_byte), do: :error

  # UTF-6 can reject a perfectly valid Unicode scalar because its position
  # creates an empty DNS component, a terminal hyphen, or a label longer than
  # 63 octets. Policy recovery therefore cannot merely filter invalid scalar
  # values. Discard walks components once; substitution normalizes dot
  # structure once, then handles each bounded component independently.
  # Replacement entries are tagged as protected so an invalid replacement is
  # reported instead of recursively substituted forever.
  defp encode_discard_components([], component, labels, _unit_count) do
    labels
    |> finish_discard_component(component)
    |> :lists.reverse()
    |> Enum.intersperse(".")
    |> IO.iodata_to_binary()
    |> then(&{:ok, &1})
  end

  defp encode_discard_components(
         [?. | rest],
         component,
         labels,
         _unit_count
       ) do
    encode_discard_components(rest, [], finish_discard_component(labels, component), 0)
  end

  defp encode_discard_components(
         [codepoint | rest],
         component,
         labels,
         unit_count
       ) do
    cond do
      not valid_scalar?(codepoint) ->
        encode_discard_components(rest, component, labels, unit_count)

      true ->
        additional_units = if codepoint > 0xFFFF, do: 2, else: 1
        next_count = unit_count + additional_units

        if next_count > @max_minimal_payload_units do
          encode_discard_components(rest, component, labels, unit_count)
        else
          encode_discard_components(
            rest,
            [codepoint | component],
            labels,
            next_count
          )
        end
    end
  end

  defp finish_discard_component(labels, component) do
    case drop_terminal_hyphens(component) do
      [] -> labels
      retained -> [fit_discard_component(retained) | labels]
    end
  end

  defp drop_terminal_hyphens([?- | rest]), do: drop_terminal_hyphens(rest)
  defp drop_terminal_hyphens(component), do: component

  defp fit_discard_component(reversed_component) do
    component = :lists.reverse(reversed_component)

    case encode_component(component) do
      {:ok, label} ->
        label

      {:error, :unrepresentable_character, _codepoint} ->
        reversed_component |> tl() |> fit_discard_component()
    end
  end

  defp encode_with_substitution(items, replacer) do
    process_substitution(items, replacer, [], 0, [], nil, nil)
  end

  defp replacement_items(replacement) when is_list(replacement),
    do: {:ok, Enum.map(replacement, &{&1, false})}

  defp replacement_items(other), do: {:error, other}

  defp process_substitution([], replacer, [], _unit_count, completed, leading, nil) do
    if is_nil(leading) do
      finish_substitution(completed)
    else
      recover_empty_substitution([], replacer, completed, leading)
    end
  end

  defp process_substitution(
         [],
         replacer,
         current,
         _unit_count,
         completed,
         leading,
         nil
       ) do
    case fit_substitution_component(current, replacer) do
      {:ok, label} ->
        finish_substitution([{label, :lists.reverse(current), leading} | completed])

      {:retry, modified} ->
        retry_substitution_component(modified, [], replacer, completed, leading)

      {:error, _codepoint} = error ->
        policy_error(error)
    end
  end

  defp process_substitution(
         [],
         replacer,
         current,
         unit_count,
         completed,
         leading,
         {separator, _label}
       ) do
    with {:ok, replacement} <- substitute_item(separator, replacer) do
      process_substitution(
        replacement,
        replacer,
        current,
        unit_count,
        completed,
        leading,
        nil
      )
    else
      error -> policy_error(error)
    end
  end

  defp process_substitution(
         [{?., _replaceable?} = item | rest],
         replacer,
         current,
         unit_count,
         completed,
         leading,
         {separator, label}
       ) do
    with {:ok, replacement} <- substitute_item(item, replacer) do
      process_substitution(
        replacement ++ rest,
        replacer,
        current,
        unit_count,
        completed,
        leading,
        {separator, label}
      )
    else
      error -> policy_error(error)
    end
  end

  defp process_substitution(
         [{?., _replaceable?} = item | rest],
         replacer,
         [],
         _unit_count,
         completed,
         leading,
         nil
       ) do
    with {:ok, replacement} <- substitute_item(item, replacer) do
      process_substitution(replacement ++ rest, replacer, [], 0, completed, leading, nil)
    else
      error -> policy_error(error)
    end
  end

  defp process_substitution(
         [{?., _replaceable?} = item | rest],
         replacer,
         current,
         unit_count,
         completed,
         leading,
         nil
       ) do
    case fit_substitution_component(current, replacer) do
      {:ok, label} ->
        process_substitution(
          rest,
          replacer,
          current,
          unit_count,
          completed,
          leading,
          {item, label}
        )

      {:retry, modified} ->
        retry_substitution_component(
          modified,
          [item | rest],
          replacer,
          completed,
          leading
        )

      {:error, _codepoint} = error ->
        policy_error(error)
    end
  end

  defp process_substitution(
         [item | rest],
         replacer,
         current,
         current_unit_count,
         completed,
         leading,
         {separator, label} = pending
       ) do
    case accept_substitution_item(item, 0, replacer) do
      {:ok, next_unit_count} ->
        entry = {label, :lists.reverse(current), leading}

        process_substitution(
          rest,
          replacer,
          [item],
          next_unit_count,
          [entry | completed],
          separator,
          nil
        )

      {:replace, replacement} ->
        process_substitution(
          replacement ++ rest,
          replacer,
          current,
          current_unit_count,
          completed,
          leading,
          pending
        )

      {:error, _codepoint} = error ->
        policy_error(error)
    end
  end

  defp process_substitution(
         [item | rest],
         replacer,
         current,
         unit_count,
         completed,
         leading,
         nil
       ) do
    case accept_substitution_item(item, unit_count, replacer) do
      {:ok, next_unit_count} ->
        process_substitution(
          rest,
          replacer,
          [item | current],
          next_unit_count,
          completed,
          leading,
          nil
        )

      {:replace, replacement} ->
        process_substitution(
          replacement ++ rest,
          replacer,
          current,
          unit_count,
          completed,
          leading,
          nil
        )

      {:error, _codepoint} = error ->
        policy_error(error)
    end
  end

  defp accept_substitution_item({codepoint, _replaceable?} = item, unit_count, replacer) do
    additional_units = if valid_scalar?(codepoint) and codepoint > 0xFFFF, do: 2, else: 1

    if valid_scalar?(codepoint) and
         unit_count + additional_units <= @max_minimal_payload_units do
      {:ok, unit_count + additional_units}
    else
      case substitute_item(item, replacer) do
        {:ok, replacement} -> {:replace, replacement}
        {:error, _codepoint} = error -> error
      end
    end
  end

  defp fit_substitution_component(current, replacer) do
    codepoints = current |> :lists.reverse() |> Enum.map(&elem(&1, 0))

    case encode_component(codepoints) do
      {:ok, label} ->
        {:ok, label}

      {:error, :unrepresentable_character, _codepoint} ->
        [last | retained] = current

        case substitute_item(last, replacer) do
          {:ok, replacement} -> {:retry, :lists.reverse(retained) ++ replacement}
          {:error, _codepoint} = error -> error
        end
    end
  end

  defp retry_substitution_component(modified, suffix, replacer, completed, leading) do
    if modified == [] do
      recover_empty_substitution(suffix, replacer, completed, leading)
    else
      process_substitution(modified ++ suffix, replacer, [], 0, completed, leading, nil)
    end
  end

  defp recover_empty_substitution(
         [{?., _replaceable?} = separator | rest],
         replacer,
         completed,
         nil
       ) do
    with {:ok, replacement} <- substitute_item(separator, replacer) do
      process_substitution(replacement ++ rest, replacer, [], 0, completed, nil, nil)
    else
      error -> policy_error(error)
    end
  end

  defp recover_empty_substitution(
         [{?., _replaceable?} = separator | rest],
         replacer,
         [{label, previous, previous_leading} | completed],
         leading
       ) do
    with {:ok, replacement} <- substitute_item(separator, replacer) do
      process_substitution(
        replacement ++ rest,
        replacer,
        :lists.reverse(previous),
        substitution_unit_count(previous),
        completed,
        previous_leading,
        {leading, label}
      )
    else
      error -> policy_error(error)
    end
  end

  defp recover_empty_substitution(suffix, replacer, completed, nil),
    do: process_substitution(suffix, replacer, [], 0, completed, nil, nil)

  defp recover_empty_substitution(
         suffix,
         replacer,
         [{_label, previous, previous_leading} | completed],
         leading
       ) do
    with {:ok, replacement} <- substitute_item(leading, replacer) do
      process_substitution(
        previous ++ replacement ++ suffix,
        replacer,
        [],
        0,
        completed,
        previous_leading,
        nil
      )
    else
      error -> policy_error(error)
    end
  end

  defp finish_substitution(completed) do
    completed
    |> :lists.reverse()
    |> Enum.map(fn {label, _items, _leading} -> label end)
    |> Enum.intersperse(".")
    |> IO.iodata_to_binary()
    |> then(&{:ok, &1})
  end

  defp substitution_unit_count(items) do
    Enum.reduce(items, 0, fn {codepoint, _replaceable?}, count ->
      count + if(codepoint > 0xFFFF, do: 2, else: 1)
    end)
  end

  defp policy_error({:error, codepoint}),
    do: {:error, :unrepresentable_character, codepoint}

  defp substitute_item({codepoint, true}, replacer),
    do: replacement_items(replacer.(codepoint))

  defp substitute_item({codepoint, false}, _replacer), do: {:error, codepoint}

  defp valid_scalar?(value),
    do: is_integer(value) and value in 0..0x10FFFF and value not in 0xD800..0xDFFF

  defp dns_label_byte?(byte), do: ascii_alnum?(byte) or byte == ?-

  defp ascii_alnum?(byte),
    do: byte in ?0..?9 or byte in ?A..?Z or byte in ?a..?z

  defp ascii_lower(byte) when byte in ?A..?Z, do: byte + 32
  defp ascii_lower(byte), do: byte
end

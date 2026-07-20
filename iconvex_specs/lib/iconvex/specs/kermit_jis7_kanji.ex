defmodule Iconvex.Specs.KermitJIS7Kanji do
  @moduledoc """
  Native Elixir port of Kermit's source-qualified `JIS7-KANJI` file codec.

  This is the three-state Kermit profile: JIS X 0201 Roman initially,
  SO/SI-invoked halfwidth Katakana, and JIS X 0208 selected by `ESC $ B` or
  `ESC $ @`. It is deliberately distinct from ICU `JIS7` and generic
  ISO-2022-JP profiles.

  The valid state language follows pinned Kermit source exactly. Malformed
  input uses Iconvex's strict, offset-bearing error contract rather than
  Kermit's permissive replacement/pass-through behavior.
  """

  use Iconvex.Codec

  @esc 0x1B
  @so 0x0E
  @si 0x0F
  @forbidden_controls [@so, @si, @esc]

  @mapping_path Path.expand("../../../priv/sources/JIS0208.TXT", __DIR__)
  @kermit_mapping_path Path.expand(
                         "../../../priv/sources/dec-terminal-character-sets/kermit/ckcuni.c",
                         __DIR__
                       )
  @license_path Path.expand(
                  "../../../priv/sources/dec-terminal-character-sets/kermit/COPYING",
                  __DIR__
                )
  @source_directory Path.expand("../../../priv/sources/kermit-jis7-kanji", __DIR__)
  @metadata_path Path.join(@source_directory, "SOURCE_METADATA.md")
  @ckuxla_path Path.join(@source_directory, "ckuxla.c")
  @ckcfns_path Path.join(@source_directory, "ckcfns.c")
  @ckuxla_header_path Path.join(@source_directory, "ckuxla.h")

  @external_resource @mapping_path
  @external_resource @kermit_mapping_path
  @external_resource @license_path
  @external_resource @metadata_path
  @external_resource @ckuxla_path
  @external_resource @ckcfns_path
  @external_resource @ckuxla_header_path

  @source_revision "8e977425d2f7f618d14aa466d516e9b79787ffc6"
  @source_sha256 %{
    "ckuxla.c" => "d4e73639659b948d4233431d541d4bd2938f0cae2505a0b00aa3aa52abb44dd0",
    "ckcfns.c" => "e18da89dfa6cdaafd29483722fba7370648526d176cb300037c2fff83fc1942f",
    "ckuxla.h" => "3352daca1cef3d015ad53d64032d49df1a4efac6f3013f8a75b975b4a63f97ee"
  }
  @mapping_sha256 "1c571870457f19c97720631fa83ee491549a96ba1436da1296786a67d8632e87"
  @kermit_mapping_sha256 "af93d5a1c779aa73fa3221ab5ec0125de20267110cf23395971ce35cc88527ca"
  @source_license_sha256 "067b8c8fc98d9359dfbd211820e1d57bed1e173144a184a21e8ead802b6502be"

  @jis0208_rows @mapping_path
                |> File.stream!()
                |> Stream.reject(&String.starts_with?(&1, "#"))
                |> Stream.map(&String.split/1)
                |> Stream.filter(&(length(&1) >= 3))
                |> Enum.map(fn [_shift_jis, "0x" <> jis, "0x" <> unicode | _comment] ->
                  <<row::binary-size(2), cell::binary-size(2)>> = jis

                  {
                    {String.to_integer(row, 16), String.to_integer(cell, 16)},
                    String.to_integer(unicode, 16)
                  }
                end)

  @jis0208_decode Map.new(@jis0208_rows)
  @decode_table (for row <- 0x21..0x7E, cell <- 0x21..0x7E do
                   Map.get(@jis0208_decode, {row, cell})
                 end)
                |> List.to_tuple()
  # These source bounds in un_to_sj() make 38 otherwise mapped characters
  # decode-only: Greek above U+039C and fullwidth U+FFE3/U+FFE5.
  @jis0208_encode_rows Enum.reject(@jis0208_rows, fn {_pair, codepoint} ->
                         codepoint in 0x039D..0x0400 or codepoint in [0xFFE3, 0xFFE5]
                       end)
  @encode_table Map.new(@jis0208_encode_rows, fn {{row, cell}, codepoint} ->
                  {codepoint, <<row, cell>>}
                end)
  @mapping_count map_size(@jis0208_decode)
  @encoder_mapping_count map_size(@encode_table)
  @representable_count @encoder_mapping_count + 188

  @type state :: :roman | :kana | :kanji
  @type encode_policy ::
          :error | :discard | {:replace, (non_neg_integer() -> [non_neg_integer()])}

  @impl true
  def canonical_name, do: "JIS7-KANJI"

  @impl true
  def aliases, do: ["ISO2022JP-KANJI", "KERMIT-JIS7-KANJI"]

  @impl true
  def codec_id, do: :kermit_jis7_kanji

  @impl true
  def stateful?, do: true

  def source_revision, do: @source_revision
  def source_sha256, do: @source_sha256
  def mapping_sha256, do: @mapping_sha256
  def kermit_mapping_sha256, do: @kermit_mapping_sha256
  def source_license_sha256, do: @source_license_sha256
  def mapping_count, do: @mapping_count
  def encoder_mapping_count, do: @encoder_mapping_count
  def representable_count, do: @representable_count

  @impl true
  def decode(input) when is_binary(input) do
    case decode_loop(input, :roman, true, 0, [], :error) do
      {:ok, codepoints, _state, <<>>} -> {:ok, codepoints}
      error -> error
    end
  end

  @impl true
  def decode_discard(input) when is_binary(input) do
    {:ok, codepoints, _state, <<>>} = decode_loop(input, :roman, true, 0, [], :discard)
    {:ok, codepoints}
  end

  @impl true
  def decode_to_utf8(input) when is_binary(input) do
    with {:ok, codepoints} <- decode(input), do: {:ok, List.to_string(codepoints)}
  end

  @impl true
  def encode(codepoints) when is_list(codepoints), do: encode_complete(codepoints, :error)

  @impl true
  def encode_discard(codepoints) when is_list(codepoints),
    do: encode_complete(codepoints, :discard)

  @impl true
  def encode_substitute(codepoints, replacer)
      when is_list(codepoints) and is_function(replacer, 1),
      do: encode_complete(codepoints, {:replace, replacer})

  @impl true
  def encode_from_utf8(input) when is_binary(input) do
    if direct_ascii?(input) do
      {:ok, input}
    else
      case :unicode.characters_to_list(input, :utf8) do
        codepoints when is_list(codepoints) ->
          encode(codepoints)

        {kind, converted, rest} when kind in [:error, :incomplete] ->
          case encode(converted) do
            {:ok, _prefix} ->
              error_kind = if kind == :error, do: :invalid_sequence, else: :incomplete_sequence
              {:decode_error, error_kind, byte_size(input) - byte_size(rest), rest}

            error ->
              error
          end
      end
    end
  end

  @impl true
  def decode_error_consumption(_kind, sequence) when is_binary(sequence),
    do: max(byte_size(sequence), 1)

  @impl true
  def stream_decoder_init, do: :roman

  @impl true
  def decode_chunk(input, state, final?)
      when is_binary(input) and state in [:roman, :kana, :kanji] and is_boolean(final?),
      do: decode_loop(input, state, final?, 0, [], :error)

  @impl true
  def stream_encoder_init, do: :roman

  @impl true
  def encode_chunk(codepoints, state, final?, policy)
      when is_list(codepoints) and state in [:roman, :kana, :kanji] and is_boolean(final?) do
    {mode, replacer} = normalize_policy(policy)

    result =
      if mode == :error,
        do: encode_strict_loop(codepoints, state, []),
        else: encode_loop(codepoints, state, mode, replacer, [])

    case result do
      {:ok, acc, next_state} ->
        {suffix, final_state} =
          if final?, do: terminal_reset(next_state), else: {<<>>, next_state}

        output = [Enum.reverse(acc), suffix] |> IO.iodata_to_binary()
        {:ok, output, final_state, []}

      error ->
        error
    end
  end

  defp decode_loop(<<>>, state, _final?, _offset, acc, _policy),
    do: {:ok, :lists.reverse(acc), state, <<>>}

  defp decode_loop(<<@esc>> = pending, state, final?, offset, acc, policy),
    do: incomplete(pending, state, final?, offset, acc, policy)

  defp decode_loop(<<@esc, @esc, rest::binary>>, state, final?, offset, acc, policy),
    do: decode_loop(rest, state, final?, offset + 2, acc, policy)

  defp decode_loop(<<@esc, marker>> = pending, state, final?, offset, acc, policy)
       when marker in [?$, ?(],
       do: incomplete(pending, state, final?, offset, acc, policy)

  defp decode_loop(<<@esc, ?$, designation, rest::binary>>, _state, final?, offset, acc, policy)
       when designation in [?@, ?B],
       do: decode_loop(rest, :kanji, final?, offset + 3, acc, policy)

  defp decode_loop(<<@esc, ?(, designation, rest::binary>>, _state, final?, offset, acc, policy)
       when designation in [?B, ?J],
       do: decode_loop(rest, :roman, final?, offset + 3, acc, policy)

  defp decode_loop(
         <<@esc, marker, _designation, _rest::binary>> = input,
         state,
         final?,
         offset,
         acc,
         policy
       )
       when marker in [?$, ?(],
       do: invalid(input, 3, state, final?, offset, acc, policy)

  defp decode_loop(<<@esc, _unknown, _rest::binary>> = input, state, final?, offset, acc, policy),
    do: invalid(input, 2, state, final?, offset, acc, policy)

  defp decode_loop(<<@so, rest::binary>>, _state, final?, offset, acc, policy),
    do: decode_loop(rest, :kana, final?, offset + 1, acc, policy)

  defp decode_loop(<<@si, rest::binary>>, _state, final?, offset, acc, policy),
    do: decode_loop(rest, :roman, final?, offset + 1, acc, policy)

  defp decode_loop(<<byte, rest::binary>>, :roman, final?, offset, acc, policy)
       when byte <= 0x7F do
    codepoint = if byte == 0x5C, do: 0x00A5, else: if(byte == 0x7E, do: 0x203E, else: byte)
    decode_loop(rest, :roman, final?, offset + 1, [codepoint | acc], policy)
  end

  defp decode_loop(<<byte, rest::binary>>, :kana, final?, offset, acc, policy)
       when byte < 0x21 or byte == 0x7F,
       do: decode_loop(rest, :kana, final?, offset + 1, [byte | acc], policy)

  defp decode_loop(<<byte, rest::binary>>, :kana, final?, offset, acc, policy)
       when byte in 0x21..0x5F,
       do: decode_loop(rest, :kana, final?, offset + 1, [byte + 0xFF40 | acc], policy)

  defp decode_loop(<<byte, _rest::binary>> = input, :kana, final?, offset, acc, policy)
       when byte <= 0x7F,
       do: invalid(input, 1, :kana, final?, offset, acc, policy)

  defp decode_loop(<<byte, rest::binary>>, :kanji, final?, offset, acc, policy)
       when byte < 0x21 or byte == 0x7F,
       do: decode_loop(rest, :kanji, final?, offset + 1, [byte | acc], policy)

  defp decode_loop(<<first>>, :kanji, final?, offset, acc, policy)
       when first in 0x21..0x7E,
       do: incomplete(<<first>>, :kanji, final?, offset, acc, policy)

  defp decode_loop(<<first, second, rest::binary>> = input, :kanji, final?, offset, acc, policy)
       when first in 0x21..0x7E do
    codepoint = if second in 0x21..0x7E, do: decode_pair(first, second), else: nil

    if codepoint do
      decode_loop(rest, :kanji, final?, offset + 2, [codepoint | acc], policy)
    else
      invalid(input, 2, :kanji, final?, offset, acc, policy)
    end
  end

  defp decode_loop(<<_byte, _rest::binary>> = input, state, final?, offset, acc, policy),
    do: invalid(input, 1, state, final?, offset, acc, policy)

  defp decode_pair(first, second) do
    elem(@decode_table, (first - 0x21) * 94 + second - 0x21)
  end

  defp incomplete(pending, state, false, _offset, acc, _policy),
    do: {:ok, :lists.reverse(acc), state, pending}

  defp incomplete(_pending, state, true, _offset, acc, :discard),
    do: {:ok, :lists.reverse(acc), state, <<>>}

  defp incomplete(pending, _state, true, offset, _acc, :error),
    do: {:error, :incomplete_sequence, offset, pending}

  defp invalid(input, size, state, final?, offset, acc, :discard) do
    <<_invalid::binary-size(size), rest::binary>> = input
    decode_loop(rest, state, final?, offset + size, acc, :discard)
  end

  defp invalid(input, size, _state, _final?, offset, _acc, :error),
    do: {:error, :invalid_sequence, offset, binary_part(input, 0, size)}

  defp encode_complete(codepoints, policy) do
    {mode, replacer} = normalize_policy(policy)

    result =
      if mode == :error,
        do: encode_strict_loop(codepoints, :roman, []),
        else: encode_loop(codepoints, :roman, mode, replacer, [])

    case result do
      {:ok, acc, state} ->
        {suffix, :roman} = terminal_reset(state)
        {:ok, [Enum.reverse(acc), suffix] |> IO.iodata_to_binary()}

      error ->
        error
    end
  end

  defp normalize_policy(:error), do: {:error, nil}
  defp normalize_policy(:discard), do: {:discard, nil}

  defp normalize_policy({:replace, replacer}) when is_function(replacer, 1),
    do: {:replace, replacer}

  defp encode_strict_loop([], state, acc), do: {:ok, acc, state}

  defp encode_strict_loop([codepoint | rest], state, acc) do
    case encoded(codepoint) do
      {:ok, charset, bytes} ->
        {output, next_state} = emit(state, charset, bytes)
        encode_strict_loop(rest, next_state, [output | acc])

      :error ->
        {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_loop([], state, _policy, _replacer, acc), do: {:ok, acc, state}

  defp encode_loop([codepoint | rest], state, policy, replacer, acc) do
    case encoded(codepoint) do
      {:ok, charset, bytes} ->
        {output, next_state} = emit(state, charset, bytes)
        encode_loop(rest, next_state, policy, replacer, [output | acc])

      :error when policy == :discard ->
        encode_loop(rest, state, policy, replacer, acc)

      :error when policy == :replace ->
        replacement = replacer.(codepoint)

        case encode_strict_loop(replacement, state, acc) do
          {:ok, replacement_acc, replacement_state} ->
            encode_loop(rest, replacement_state, policy, replacer, replacement_acc)

          error ->
            error
        end

      :error ->
        {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encoded(codepoint) when codepoint in @forbidden_controls, do: :error
  defp encoded(0x00A5), do: {:ok, :roman, <<0x5C>>}
  defp encoded(0x203E), do: {:ok, :roman, <<0x7E>>}

  defp encoded(codepoint) when codepoint in 0xFF61..0xFF9F,
    do: {:ok, :kana, <<codepoint - 0xFF40>>}

  defp encoded(codepoint)
       when codepoint in 0x00..0x7F and codepoint not in [0x5C, 0x7E],
       do: {:ok, :roman, <<codepoint>>}

  defp encoded(codepoint) do
    case Map.fetch(@encode_table, codepoint) do
      {:ok, bytes} -> {:ok, :kanji, bytes}
      :error -> :error
    end
  end

  defp direct_ascii?(<<>>), do: true

  defp direct_ascii?(<<byte, rest::binary>>)
       when byte <= 0x7F and byte not in [@so, @si, @esc, 0x5C, 0x7E],
       do: direct_ascii?(rest)

  defp direct_ascii?(_input), do: false

  defp emit(:roman, :roman, bytes), do: {bytes, :roman}
  defp emit(:roman, :kana, bytes), do: {<<@so, bytes::binary>>, :kana}
  defp emit(:roman, :kanji, bytes), do: {<<@esc, "$B", bytes::binary>>, :kanji}
  defp emit(:kana, :roman, bytes), do: {<<@si, bytes::binary>>, :roman}
  defp emit(:kana, :kana, bytes), do: {bytes, :kana}
  defp emit(:kana, :kanji, bytes), do: {<<@si, @esc, "$B", bytes::binary>>, :kanji}
  defp emit(:kanji, :roman, bytes), do: {<<@esc, "(J", bytes::binary>>, :roman}
  defp emit(:kanji, :kana, bytes), do: {<<@esc, "(J", @so, bytes::binary>>, :kana}
  defp emit(:kanji, :kanji, bytes), do: {bytes, :kanji}

  defp terminal_reset(:roman), do: {<<>>, :roman}
  defp terminal_reset(:kana), do: {<<@si>>, :roman}
  defp terminal_reset(:kanji), do: {<<@esc, "(J">>, :roman}
end

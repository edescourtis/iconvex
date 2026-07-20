defmodule Iconvex.Specs.FormalSignWriting do
  @moduledoc """
  Strict lexical conversion between Formal SignWriting in ASCII (FSW) and the
  v1.0.0 SignWriting in Unicode (SWU) design.

  This codec accepts complete lexical tokens: one-byte structural markers,
  six-byte symbols, and seven-byte coordinates. It deliberately does not make
  arbitrary lexical token streams into signs; use `valid_sign?/1` or
  `validate_sign/1` for the separate full-sign grammar.

  SWU is experimental and is not the Unicode Standard's SignWriting encoding.
  """

  use Iconvex.Codec

  @source_dir Path.expand(
                "../../../priv/sources/formal-signwriting-1.0.0",
                __DIR__
              )
  @contract_path Path.join(@source_dir, "mapping_contract.csv")
  @metadata_path Path.join(@source_dir, "SOURCE_METADATA.md")
  @exceptions_path Path.join(@source_dir, "ORACLE_EXCEPTIONS.md")
  @external_resource @contract_path
  @external_resource @metadata_path
  @external_resource @exceptions_path

  @source_sha256 "b8a660c6e884a351bf846e8ccfa459e9fa2a3ac4fe0b18546303169a1c306870"
  @technical_paper_sha256 "8c75daac3229de9c9c297c457bf3fc48c231c84bc4d267a59c1d9ff9a3e4bed0"
  @grammar_notes_sha256 "bbc5c5b865cc50c30122611956473818116a0b1b1371a92b1d0579deeb1b8dcb"
  @grammar_paper_sha256 "34e2d7156db91fd3d1ab0e6075c45bf8096c634a6edf6ab98edf723ed2bac75b"
  @source_archive_sha256 "ba881a636c08a35c498ed7f9dc3262b6ba3a98918cff88818cddafbfc7079fb9"
  @source_commit "99e0258ed19db56d89099dc43e15fa5c82719983"
  @contract_sha256 "67add2e9c0fab3d92890d57bde81f9824289b3ab98ba4c13c67bb49153262131"
  @draft_11_sha256 "db8830a22a80791e9eb9c2374a585c9422dd7f6ad50ab0f2160f332f9c0c06bb"

  @number_first 0x1D80C
  @number_last 0x1D9FF
  @null 0x40000
  @symbol_first 0x40001
  @symbol_last 0x4F428
  @symbol_count 62_504
  @utf8_chunk_bytes 65_536
  @direct_utf8_bytes 1_048_576

  @expected_contract [
    "kind,fsw_domain,swu_domain,count,exact_rule",
    "marker,A|B|L|M|R,U+1D800..U+1D804,5,ordered one-to-one",
    "number,250..749,U+1D80C..U+1D9FF,500,swu=U+1D80C+(number-250)",
    "null,S00000,U+40000,1,one-to-one",
    "symbol,S10000..S38b07,U+40001..U+4F428,62504,id=((base-0x100)*96)+(fill*16)+rotation+1;swu=U+40000+id"
  ]

  contract = File.read!(@contract_path)

  actual_contract_sha256 =
    contract
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)

  unless actual_contract_sha256 == @contract_sha256 and
           String.split(contract, "\n", trim: true) == @expected_contract do
    raise "Formal SignWriting v1.0.0 mapping contract failed digest or content validation"
  end

  metadata = File.read!(@metadata_path)
  exceptions = File.read!(@exceptions_path)

  unless Enum.all?(
           [
             @source_sha256,
             @technical_paper_sha256,
             @grammar_notes_sha256,
             @grammar_paper_sha256,
             @source_archive_sha256,
             @source_commit
           ],
           &String.contains?(metadata, &1)
         ) and
           String.contains?(metadata, "CC BY 4.0") and
           String.contains?(metadata, "LGPL-2.1-or-later") and
           String.contains?(exceptions, @draft_11_sha256) do
    raise "Formal SignWriting v1.0.0 source metadata failed attribution validation"
  end

  @hex_bytes "0123456789abcdef"

  @base_prefixes 0x100..0x38B
                 |> Enum.map(fn base ->
                   encoded = base |> Integer.to_string(16) |> String.downcase()
                   "S" <> String.pad_leading(encoded, 3, "0")
                 end)
                 |> List.to_tuple()

  @impl true
  def canonical_name, do: "FSW"

  @impl true
  def aliases do
    [
      "FORMAL-SIGNWRITING-IN-ASCII",
      "FORMAL-SIGNWRITING-ASCII",
      "FSW-ASCII",
      "FSW-2012"
    ]
  end

  @impl true
  def codec_id, do: :formal_signwriting_v1_0_0

  def source_sha256, do: @source_sha256
  def technical_paper_sha256, do: @technical_paper_sha256
  def grammar_notes_sha256, do: @grammar_notes_sha256
  def grammar_paper_sha256, do: @grammar_paper_sha256
  def source_archive_sha256, do: @source_archive_sha256
  def source_commit, do: @source_commit
  def mapping_contract_sha256, do: @contract_sha256

  def source_url do
    "https://zenodo.org/api/records/20272667/files/" <>
      "fsw-and-swu-technical-notes-v1.0.0.md/content"
  end

  def series_doi, do: "10.5281/zenodo.20074767"
  def fsw_swu_doi, do: "10.5281/zenodo.20272667"
  def grammar_doi, do: "10.5281/zenodo.20272691"

  @impl true
  def decode(input) when is_binary(input) do
    case decode_loop(input, true, 0, []) do
      {:ok, codepoints, <<>>} -> {:ok, codepoints}
      error -> error
    end
  end

  @impl true
  def decode_discard(input) when is_binary(input), do: decode_discard_loop(input, [])

  @impl true
  def decode_chunk(input, final?) when is_binary(input) and is_boolean(final?),
    do: decode_loop(input, final?, 0, [])

  @impl true
  def encode(codepoints) when is_list(codepoints) do
    case encode_loop(codepoints, true, :error, []) do
      {:ok, output, []} -> {:ok, output}
      error -> error
    end
  end

  @impl true
  def encode_discard(codepoints) when is_list(codepoints) do
    case encode_loop(codepoints, true, :discard, []) do
      {:ok, output, []} -> {:ok, output}
      error -> error
    end
  end

  @impl true
  def encode_substitute(codepoints, replacer)
      when is_list(codepoints) and is_function(replacer, 1) do
    case encode_loop(codepoints, true, {:replace, replacer}, []) do
      {:ok, output, []} -> {:ok, output}
      error -> error
    end
  end

  @impl true
  def encode_chunk(codepoints, final?, policy)
      when is_list(codepoints) and is_boolean(final?),
      do: encode_loop(codepoints, final?, policy, [])

  @impl true
  def decode_to_utf8(input) when is_binary(input) and byte_size(input) <= @direct_utf8_bytes do
    with {:ok, codepoints} <- decode(input), do: {:ok, List.to_string(codepoints)}
  end

  def decode_to_utf8(input) when is_binary(input),
    do: decode_utf8_chunks(input, <<>>, 0, [])

  @impl true
  def encode_from_utf8(input) when is_binary(input),
    do: encode_utf8_chunks(input, <<>>, [], 0, [])

  @doc "Converts a complete FSW lexical-token stream to SWU UTF-8."
  def fsw_to_swu(input) when is_binary(input), do: decode_to_utf8(input)

  @doc "Converts a complete SWU UTF-8 lexical-token stream to FSW ASCII."
  def swu_to_fsw(input) when is_binary(input), do: encode_from_utf8(input)

  @doc "Returns true only for one complete sign under the separate v1.0.0 grammar."
  def valid_sign?(input) when is_binary(input), do: validate_sign(input) == :ok

  @doc "Validates one full FSW sign without changing the lexical codec's domain."
  def validate_sign(input) when is_binary(input) do
    case parse_sign(input) do
      {:ok, <<>>, _offset} ->
        :ok

      {:ok, rest, offset} ->
        {:error, :invalid_sign, offset, rest}

      {:error, offset, rest} ->
        {:error, :invalid_sign, offset, rest}
    end
  end

  defp decode_loop(<<>>, _final?, _offset, acc),
    do: {:ok, :lists.reverse(acc), <<>>}

  defp decode_loop(input, final?, offset, acc) do
    case decode_one(input) do
      {:ok, codepoints, rest} ->
        consumed = byte_size(input) - byte_size(rest)
        decode_loop(rest, final?, offset + consumed, Enum.reverse(codepoints, acc))

      :pending when final? ->
        {:error, :incomplete_sequence, offset, input}

      :pending ->
        {:ok, :lists.reverse(acc), input}

      {:error, sequence} ->
        {:error, :invalid_sequence, offset, sequence}
    end
  end

  defp decode_one(<<marker, rest::binary>>) when marker in [?A, ?B, ?L, ?M, ?R],
    do: {:ok, [marker_scalar(marker)], rest}

  defp decode_one(<<?S, _rest::binary>> = input) when byte_size(input) < 6 do
    if symbol_prefix?(input), do: :pending, else: {:error, first_byte(input)}
  end

  defp decode_one(<<?S, _rest::binary>> = input) do
    <<token::binary-size(6), rest::binary>> = input

    case symbol_scalar(token) do
      {:ok, scalar} -> {:ok, [scalar], rest}
      :error -> {:error, token}
    end
  end

  defp decode_one(<<digit, _rest::binary>> = input)
       when digit in ?0..?9 and byte_size(input) < 7 do
    if coordinate_prefix?(input), do: :pending, else: {:error, first_byte(input)}
  end

  defp decode_one(<<digit, _rest::binary>> = input) when digit in ?0..?9 do
    <<token::binary-size(7), rest::binary>> = input

    case coordinate_scalars(token) do
      {:ok, first, second} -> {:ok, [first, second], rest}
      :error -> {:error, token}
    end
  end

  defp decode_one(<<byte, _rest::binary>>), do: {:error, <<byte>>}
  defp decode_one(<<>>), do: :pending

  defp decode_discard_loop(<<>>, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_loop(input, acc) do
    case decode_one(input) do
      {:ok, codepoints, rest} ->
        decode_discard_loop(rest, Enum.reverse(codepoints, acc))

      :pending ->
        {:ok, :lists.reverse(acc)}

      {:error, _sequence} ->
        <<_byte, rest::binary>> = input
        decode_discard_loop(rest, acc)
    end
  end

  defp decode_utf8_chunks(remaining, carry, offset, chunks) do
    {input, rest} = take_bounded_chunk(remaining, carry)
    final? = rest == <<>>

    case decode_loop(input, final?, 0, []) do
      {:ok, codepoints, pending} ->
        encoded = List.to_string(codepoints)
        next_chunks = [encoded | chunks]

        if final? do
          {:ok, next_chunks |> :lists.reverse() |> IO.iodata_to_binary()}
        else
          consumed = byte_size(input) - byte_size(pending)
          decode_utf8_chunks(rest, pending, offset + consumed, next_chunks)
        end

      {:error, kind, local_offset, sequence} ->
        {:error, kind, offset + local_offset, sequence}
    end
  end

  defp encode_loop([], _final?, _policy, acc),
    do: {:ok, reverse_output(acc), []}

  defp encode_loop([number], false, _policy, acc) when number in @number_first..@number_last,
    do: {:ok, reverse_output(acc), [number]}

  defp encode_loop([number], true, policy, acc) when number in @number_first..@number_last,
    do: recover_unrepresentable(number, [], true, policy, acc)

  defp encode_loop([first, second | rest], final?, policy, acc)
       when first in @number_first..@number_last and second in @number_first..@number_last do
    fragment = coordinate_fragment(first, second)
    encode_loop(rest, final?, policy, [fragment | acc])
  end

  defp encode_loop([number | rest], final?, policy, acc)
       when number in @number_first..@number_last,
       do: recover_unrepresentable(number, rest, final?, policy, acc)

  defp encode_loop([scalar | rest], final?, policy, acc) do
    case scalar_fragment(scalar) do
      {:ok, fragment} -> encode_loop(rest, final?, policy, [fragment | acc])
      :error -> recover_unrepresentable(scalar, rest, final?, policy, acc)
    end
  end

  defp recover_unrepresentable(scalar, _rest, _final?, :error, _acc),
    do: {:error, :unrepresentable_character, scalar}

  defp recover_unrepresentable(_scalar, rest, final?, :discard, acc),
    do: encode_loop(rest, final?, :discard, acc)

  defp recover_unrepresentable(scalar, rest, final?, {:replace, replacer} = policy, acc) do
    case encode(replacer.(scalar)) do
      {:ok, replacement} -> encode_loop(rest, final?, policy, [replacement | acc])
      error -> error
    end
  end

  defp encode_utf8_chunks(remaining, carry, pending, offset, chunks) do
    {input, rest} = take_bounded_chunk(remaining, carry)

    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        final? = rest == <<>>

        case encode_loop(pending ++ codepoints, final?, :error, []) do
          {:ok, encoded, next_pending} ->
            next_chunks = [encoded | chunks]

            if final? do
              {:ok, next_chunks |> :lists.reverse() |> IO.iodata_to_binary()}
            else
              encode_utf8_chunks(rest, <<>>, next_pending, offset + byte_size(input), next_chunks)
            end

          error ->
            error
        end

      {:incomplete, codepoints, tail} ->
        consumed = byte_size(input) - byte_size(tail)

        if rest == <<>> do
          case encode_loop(pending ++ codepoints, true, :error, []) do
            {:ok, _encoded, []} ->
              {:decode_error, :incomplete_sequence, offset + consumed, tail}

            error ->
              error
          end
        else
          case encode_loop(pending ++ codepoints, false, :error, []) do
            {:ok, encoded, next_pending} ->
              encode_utf8_chunks(
                rest,
                tail,
                next_pending,
                offset + consumed,
                [encoded | chunks]
              )

            error ->
              error
          end
        end

      {:error, codepoints, tail} ->
        consumed = byte_size(input) - byte_size(tail)

        case encode_loop(pending ++ codepoints, true, :error, []) do
          {:ok, _encoded, []} ->
            {:decode_error, :invalid_sequence, offset + consumed, append_rest(tail, rest)}

          error ->
            error
        end
    end
  end

  defp take_bounded_chunk(remaining, <<>>) when byte_size(remaining) <= @utf8_chunk_bytes,
    do: {remaining, <<>>}

  defp take_bounded_chunk(remaining, carry) do
    available = @utf8_chunk_bytes - byte_size(carry)

    if byte_size(remaining) <= available do
      {<<carry::binary, remaining::binary>>, <<>>}
    else
      <<head::binary-size(available), rest::binary>> = remaining
      {<<carry::binary, head::binary>>, rest}
    end
  end

  defp append_rest(tail, <<>>), do: tail
  defp append_rest(tail, rest), do: <<tail::binary, rest::binary>>

  defp symbol_scalar("S00000"), do: {:ok, @null}

  defp symbol_scalar(<<?S, b1, b2, b3, fill_byte, rotation_byte>>) do
    with {:ok, h1} <- hex_value(b1),
         {:ok, h2} <- hex_value(b2),
         {:ok, h3} <- hex_value(b3),
         true <- fill_byte in ?0..?5,
         {:ok, rotation} <- hex_value(rotation_byte) do
      base = h1 * 256 + h2 * 16 + h3
      fill = fill_byte - ?0
      id = (base - 0x100) * 96 + fill * 16 + rotation + 1

      if base in 0x100..0x38B and id in 1..@symbol_count,
        do: {:ok, @null + id},
        else: :error
    else
      _invalid -> :error
    end
  end

  defp coordinate_scalars(<<a, b, c, ?x, d, e, f>>) do
    first = decimal3(a, b, c)
    second = decimal3(d, e, f)

    if first in 250..749 and second in 250..749 do
      {:ok, @number_first + first - 250, @number_first + second - 250}
    else
      :error
    end
  end

  defp coordinate_scalars(_token), do: :error

  defp decimal3(a, b, c)
       when a in ?0..?9 and b in ?0..?9 and c in ?0..?9,
       do: (a - ?0) * 100 + (b - ?0) * 10 + c - ?0

  defp decimal3(_a, _b, _c), do: -1

  defp marker_scalar(?A), do: 0x1D800
  defp marker_scalar(?B), do: 0x1D801
  defp marker_scalar(?L), do: 0x1D802
  defp marker_scalar(?M), do: 0x1D803
  defp marker_scalar(?R), do: 0x1D804

  defp scalar_fragment(0x1D800), do: {:ok, ?A}
  defp scalar_fragment(0x1D801), do: {:ok, ?B}
  defp scalar_fragment(0x1D802), do: {:ok, ?L}
  defp scalar_fragment(0x1D803), do: {:ok, ?M}
  defp scalar_fragment(0x1D804), do: {:ok, ?R}
  defp scalar_fragment(@null), do: {:ok, "S00000"}

  defp scalar_fragment(scalar) when scalar in @symbol_first..@symbol_last do
    q = scalar - @symbol_first
    base_offset = div(q, 96)
    remainder = rem(q, 96)
    fill = div(remainder, 16)
    rotation = rem(remainder, 16)

    {:ok,
     [
       elem(@base_prefixes, base_offset),
       fill + ?0,
       :binary.at(@hex_bytes, rotation)
     ]}
  end

  defp scalar_fragment(_scalar), do: :error

  defp coordinate_fragment(first, second) do
    first_number = first - @number_first + 250
    second_number = second - @number_first + 250

    <<
      div(first_number, 100) + ?0,
      div(rem(first_number, 100), 10) + ?0,
      rem(first_number, 10) + ?0,
      ?x,
      div(second_number, 100) + ?0,
      div(rem(second_number, 100), 10) + ?0,
      rem(second_number, 10) + ?0
    >>
  end

  defp hex_value(byte) when byte in ?0..?9, do: {:ok, byte - ?0}
  defp hex_value(byte) when byte in ?a..?f, do: {:ok, byte - ?a + 10}
  defp hex_value(_byte), do: :error

  defp symbol_prefix?(<<?S, suffix::binary>>) when byte_size(suffix) < 5 do
    null_prefix? = Enum.all?(:binary.bin_to_list(suffix), &(&1 == ?0))
    null_prefix? or ordinary_symbol_prefix?(suffix)
  end

  defp symbol_prefix?(_input), do: false

  defp ordinary_symbol_prefix?(suffix) do
    suffix
    |> :binary.bin_to_list()
    |> Enum.with_index()
    |> Enum.all?(fn {byte, index} -> symbol_prefix_byte?(suffix, index, byte) end)
  end

  defp symbol_prefix_byte?(_suffix, 0, byte), do: byte in ?1..?3

  defp symbol_prefix_byte?(suffix, 1, byte) do
    case :binary.at(suffix, 0) do
      first when first in ?1..?2 -> lowercase_hex?(byte)
      ?3 -> byte in ?0..?8
      _other -> false
    end
  end

  defp symbol_prefix_byte?(suffix, 2, byte) do
    first = :binary.at(suffix, 0)
    second = :binary.at(suffix, 1)

    cond do
      first in ?1..?2 -> lowercase_hex?(byte)
      first == ?3 and second in ?0..?7 -> lowercase_hex?(byte)
      first == ?3 and second == ?8 -> byte in ?0..?b
      true -> false
    end
  end

  defp symbol_prefix_byte?(suffix, 3, byte) do
    base = binary_hex3(suffix)
    (byte in ?0..?5 and base in 0x100..0x38A) or (base == 0x38B and byte == ?0)
  end

  defp binary_hex3(<<a, b, c, _rest::binary>>) do
    {:ok, h1} = hex_value(a)
    {:ok, h2} = hex_value(b)
    {:ok, h3} = hex_value(c)
    h1 * 256 + h2 * 16 + h3
  end

  defp coordinate_prefix?(input) when byte_size(input) < 7 do
    input
    |> :binary.bin_to_list()
    |> Enum.with_index()
    |> Enum.all?(fn {byte, index} -> coordinate_prefix_byte?(input, index, byte) end)
  end

  defp coordinate_prefix_byte?(_input, index, byte) when index in [0, 4],
    do: byte in ?2..?7

  defp coordinate_prefix_byte?(input, index, byte) when index in [1, 5] do
    first_index = if index == 1, do: 0, else: 4

    case :binary.at(input, first_index) do
      ?2 -> byte in ?5..?9
      ?7 -> byte in ?0..?4
      first when first in ?3..?6 -> byte in ?0..?9
      _other -> false
    end
  end

  defp coordinate_prefix_byte?(_input, index, byte) when index in [2, 6],
    do: byte in ?0..?9

  defp coordinate_prefix_byte?(_input, 3, byte), do: byte == ?x

  defp lowercase_hex?(byte), do: byte in ?0..?9 or byte in ?a..?f
  defp first_byte(<<byte, _rest::binary>>), do: <<byte>>

  defp reverse_output(acc), do: acc |> :lists.reverse() |> IO.iodata_to_binary()

  defp parse_sign(<<?A, rest::binary>>), do: parse_prefix_items(rest, 1, 0)
  defp parse_sign(input), do: parse_signbox(input, 0)

  defp parse_prefix_items(<<marker, _rest::binary>> = input, offset, count)
       when marker in [?B, ?L, ?M, ?R] and count > 0,
       do: parse_signbox(input, offset)

  defp parse_prefix_items(<<?S, _rest::binary>> = input, offset, count)
       when byte_size(input) >= 6 do
    <<token::binary-size(6), rest::binary>> = input

    case symbol_scalar(token) do
      {:ok, scalar} when scalar == @null or scalar in @symbol_first..@symbol_last ->
        parse_prefix_items(rest, offset + 6, count + 1)

      _invalid ->
        {:error, offset, input}
    end
  end

  defp parse_prefix_items(input, offset, _count), do: {:error, offset, input}

  defp parse_signbox(<<marker, rest::binary>>, offset) when marker in [?B, ?L, ?M, ?R] do
    case parse_coordinate(rest) do
      {:ok, after_coordinate} ->
        parse_spatial(after_coordinate, offset + 8)

      :error ->
        {:error, offset + 1, rest}
    end
  end

  defp parse_signbox(input, offset), do: {:error, offset, input}

  defp parse_spatial(<<>>, offset), do: {:ok, <<>>, offset}

  defp parse_spatial(<<?S, _rest::binary>> = input, offset) when byte_size(input) >= 13 do
    <<symbol::binary-size(6), coordinate::binary-size(7), rest::binary>> = input

    case {symbol_scalar(symbol), coordinate_scalars(coordinate)} do
      {{:ok, scalar}, {:ok, _first, _second}} when scalar in @symbol_first..@symbol_last ->
        parse_spatial(rest, offset + 13)

      _invalid ->
        {:error, offset, input}
    end
  end

  defp parse_spatial(input, offset), do: {:error, offset, input}

  defp parse_coordinate(input) when byte_size(input) >= 7 do
    <<coordinate::binary-size(7), rest::binary>> = input

    case coordinate_scalars(coordinate) do
      {:ok, _first, _second} -> {:ok, rest}
      :error -> :error
    end
  end

  defp parse_coordinate(_input), do: :error
end

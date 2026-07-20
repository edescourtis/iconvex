defmodule Iconvex.Specs.IBM965 do
  @moduledoc """
  IBM CCSID 965: ASCII CP367 plus CNS 11643 plane-1 CP960 under IBM's
  escape-sequence ISO-2022 encoding scheme.
  """

  use Iconvex.Codec

  @designation <<0x1B, "$)G">>
  @table_id :icu_archive_729

  @impl true
  def canonical_name, do: "IBM-965"

  @impl true
  def aliases, do: ["IBM965", "CP965", "CCSID965"]

  @impl true
  def codec_id, do: :ibm_965

  @impl true
  def stateful?, do: true

  @impl true
  def decode(input) when is_binary(input),
    do: decode_all(input, false, false, false, 0, [])

  @impl true
  def decode_discard(input) when is_binary(input),
    do: decode_all(input, true, false, false, 0, [])

  @impl true
  def encode(codepoints) when is_list(codepoints),
    do: encode_all(codepoints, false, false, false, [])

  @impl true
  def encode_discard(codepoints) when is_list(codepoints),
    do: encode_all(codepoints, true, false, false, [])

  @impl true
  def encode_substitute(codepoints, replacer)
      when is_list(codepoints) and is_function(replacer, 1),
      do: encode_substitute_all(codepoints, [], false, false, false, [], replacer)

  @impl true
  def decode_to_utf8(input) do
    case decode(input) do
      {:ok, codepoints} -> {:ok, List.to_string(codepoints)}
      error -> error
    end
  end

  @impl true
  def encode_from_utf8(input), do: Iconvex.Specs.CodecSupport.encode_utf8(input, &encode/1)

  defp decode_all(<<>>, _discard?, _designated?, _shifted?, _offset, acc),
    do: {:ok, :lists.reverse(acc)}

  defp decode_all(<<0x1B, _::binary>> = input, discard?, designated?, shifted?, offset, acc) do
    cond do
      byte_size(input) >= 4 and binary_part(input, 0, 4) == @designation ->
        <<_::binary-size(4), rest::binary>> = input
        decode_all(rest, discard?, true, shifted?, offset + 4, acc)

      byte_size(input) < 4 and prefix_of_designation?(input) and discard? ->
        {:ok, :lists.reverse(acc)}

      byte_size(input) < 4 and prefix_of_designation?(input) ->
        {:error, :incomplete_sequence, offset, input}

      discard? ->
        <<_escape, rest::binary>> = input
        decode_all(rest, true, designated?, shifted?, offset + 1, acc)

      true ->
        count = min(4, byte_size(input))
        {:error, :invalid_sequence, offset, binary_part(input, 0, count)}
    end
  end

  defp decode_all(<<0x0E, rest::binary>>, discard?, true, _shifted?, offset, acc),
    do: decode_all(rest, discard?, true, true, offset + 1, acc)

  defp decode_all(<<0x0E, rest::binary>>, true, designated?, shifted?, offset, acc),
    do: decode_all(rest, true, designated?, shifted?, offset + 1, acc)

  defp decode_all(<<0x0E>>, false, false, _shifted?, offset, _acc),
    do: {:error, :invalid_sequence, offset, <<0x0E>>}

  defp decode_all(<<0x0E, _::binary>>, false, false, _shifted?, offset, _acc),
    do: {:error, :invalid_sequence, offset, <<0x0E>>}

  defp decode_all(<<0x0F, rest::binary>>, discard?, designated?, _shifted?, offset, acc),
    do: decode_all(rest, discard?, designated?, false, offset + 1, acc)

  defp decode_all(<<byte, rest::binary>>, discard?, _designated?, _shifted?, offset, acc)
       when byte in [0x0A, 0x0D],
       do: decode_all(rest, discard?, false, false, offset + 1, [byte | acc])

  defp decode_all(<<byte, rest::binary>>, discard?, designated?, false, offset, acc)
       when byte <= 0x7F,
       do: decode_all(rest, discard?, designated?, false, offset + 1, [byte | acc])

  defp decode_all(input, true, designated?, true, offset, acc) when byte_size(input) < 2,
    do: decode_all(<<>>, true, designated?, true, offset + byte_size(input), acc)

  defp decode_all(input, false, _designated?, true, offset, _acc) when byte_size(input) < 2,
    do: {:error, :incomplete_sequence, offset, input}

  defp decode_all(<<first, second, rest::binary>>, discard?, designated?, true, offset, acc)
       when first in 0x21..0x7E and second in 0x21..0x7E do
    source = <<first + 0x80, second + 0x80>>

    case Map.get(table().many, source) do
      nil when discard? -> decode_all(rest, true, designated?, true, offset + 2, acc)
      nil -> {:error, :invalid_sequence, offset, <<first, second>>}
      tuple -> decode_all(rest, discard?, designated?, true, offset + 2, prepend(tuple, acc))
    end
  end

  defp decode_all(<<_byte, rest::binary>>, true, designated?, shifted?, offset, acc),
    do: decode_all(rest, true, designated?, shifted?, offset + 1, acc)

  defp decode_all(<<byte, _rest::binary>>, false, _designated?, _shifted?, offset, _acc),
    do: {:error, :invalid_sequence, offset, <<byte>>}

  defp encode_all([], _discard?, _designated?, false, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_all([], _discard?, _designated?, true, acc),
    do: {:ok, [<<0x0F>> | acc] |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_all([codepoint | rest], discard?, _designated?, shifted?, acc)
       when codepoint in [0x0A, 0x0D] do
    shift = if shifted?, do: <<0x0F>>, else: <<>>
    encode_all(rest, discard?, false, false, [<<codepoint>>, shift | acc])
  end

  defp encode_all([codepoint | rest], discard?, designated?, shifted?, acc)
       when codepoint in 0..0x7F do
    shift = if shifted?, do: <<0x0F>>, else: <<>>
    encode_all(rest, discard?, designated?, false, [<<codepoint>>, shift | acc])
  end

  defp encode_all([codepoint | rest], discard?, designated?, shifted?, acc) do
    case Map.get(table().encode, {codepoint}) do
      <<first, second>> ->
        designation = if designated?, do: <<>>, else: @designation
        shift = if shifted?, do: <<>>, else: <<0x0E>>
        pair = <<first - 0x80, second - 0x80>>
        encode_all(rest, discard?, true, true, [pair, shift, designation | acc])

      nil when discard? ->
        encode_all(rest, true, designated?, shifted?, acc)

      nil ->
        {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_substitute_all(
         [],
         resume,
         true,
         designated?,
         shifted?,
         acc,
         replacer
       ),
       do:
         encode_substitute_all(
           resume,
           [],
           false,
           designated?,
           shifted?,
           acc,
           replacer
         )

  defp encode_substitute_all([], [], false, _designated?, false, acc, _replacer),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute_all([], [], false, _designated?, true, acc, _replacer),
    do: {:ok, [<<0x0F>> | acc] |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute_all(
         [codepoint | rest],
         resume,
         replacement?,
         _designated?,
         shifted?,
         acc,
         replacer
       )
       when codepoint in [0x0A, 0x0D] do
    shift = if shifted?, do: <<0x0F>>, else: <<>>

    encode_substitute_all(
      rest,
      resume,
      replacement?,
      false,
      false,
      [<<codepoint>>, shift | acc],
      replacer
    )
  end

  defp encode_substitute_all(
         [codepoint | rest],
         resume,
         replacement?,
         designated?,
         shifted?,
         acc,
         replacer
       )
       when codepoint in 0..0x7F do
    shift = if shifted?, do: <<0x0F>>, else: <<>>

    encode_substitute_all(
      rest,
      resume,
      replacement?,
      designated?,
      false,
      [<<codepoint>>, shift | acc],
      replacer
    )
  end

  defp encode_substitute_all(
         [codepoint | rest],
         resume,
         replacement?,
         designated?,
         shifted?,
         acc,
         replacer
       ) do
    case Map.get(table().encode, {codepoint}) do
      <<first, second>> ->
        designation = if designated?, do: <<>>, else: @designation
        shift = if shifted?, do: <<>>, else: <<0x0E>>
        pair = <<first - 0x80, second - 0x80>>

        encode_substitute_all(
          rest,
          resume,
          replacement?,
          true,
          true,
          [pair, shift, designation | acc],
          replacer
        )

      nil when replacement? ->
        {:error, :unrepresentable_character, codepoint}

      nil ->
        encode_substitute_all(
          replacer.(codepoint),
          rest,
          true,
          designated?,
          shifted?,
          acc,
          replacer
        )
    end
  end

  defp table, do: Iconvex.Tables.fetch!(@table_id)

  defp prefix_of_designation?(input) do
    binary_part(@designation, 0, byte_size(input)) == input
  end

  defp prepend(tuple, acc), do: tuple |> Tuple.to_list() |> Enum.reverse(acc)
end

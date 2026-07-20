defmodule Iconvex.Specs.ISO2022G1 do
  @moduledoc false

  def decode(input, profile, discard?) when is_binary(input),
    do: decode_all(input, profile, discard?, false, false, 0, [])

  def encode(codepoints, profile, discard?) when is_list(codepoints),
    do: encode_all(codepoints, profile, discard?, false, false, [])

  def encode_substitute(codepoints, profile, replacer)
      when is_list(codepoints) and is_function(replacer, 1),
      do: encode_substitute_all(codepoints, [], false, profile, false, false, [], replacer)

  def decode_to_utf8(input, profile) do
    case decode(input, profile, false) do
      {:ok, codepoints} -> {:ok, List.to_string(codepoints)}
      error -> error
    end
  end

  def encode_from_utf8(input, profile) do
    Iconvex.Specs.CodecSupport.encode_utf8(input, &encode(&1, profile, false))
  end

  defp decode_all(<<>>, _profile, _discard?, _designated?, _shifted?, _offset, acc),
    do: {:ok, :lists.reverse(acc)}

  defp decode_all(
         <<0x1B, _::binary>> = input,
         profile,
         discard?,
         designated?,
         shifted?,
         offset,
         acc
       ) do
    designation = profile.designation

    cond do
      byte_size(input) >= byte_size(designation) and
          binary_part(input, 0, byte_size(designation)) == designation ->
        size = byte_size(designation)
        <<_::binary-size(size), rest::binary>> = input
        decode_all(rest, profile, discard?, true, shifted?, offset + size, acc)

      byte_size(input) < byte_size(designation) and prefix?(designation, input) and discard? ->
        {:ok, :lists.reverse(acc)}

      byte_size(input) < byte_size(designation) and prefix?(designation, input) ->
        {:error, :incomplete_sequence, offset, input}

      discard? ->
        <<_escape, rest::binary>> = input
        decode_all(rest, profile, true, designated?, shifted?, offset + 1, acc)

      true ->
        count = min(byte_size(designation), byte_size(input))
        {:error, :invalid_sequence, offset, binary_part(input, 0, count)}
    end
  end

  defp decode_all(<<0x0E, rest::binary>>, profile, discard?, true, _shifted?, offset, acc),
    do: decode_all(rest, profile, discard?, true, true, offset + 1, acc)

  defp decode_all(<<0x0E, rest::binary>>, profile, true, designated?, shifted?, offset, acc),
    do: decode_all(rest, profile, true, designated?, shifted?, offset + 1, acc)

  defp decode_all(<<0x0E, _::binary>>, _profile, false, false, _shifted?, offset, _acc),
    do: {:error, :invalid_sequence, offset, <<0x0E>>}

  defp decode_all(<<0x0F, rest::binary>>, profile, discard?, designated?, _shifted?, offset, acc),
    do: decode_all(rest, profile, discard?, designated?, false, offset + 1, acc)

  defp decode_all(<<byte, rest::binary>>, profile, discard?, _designated?, _shifted?, offset, acc)
       when byte in [0x0A, 0x0D],
       do: decode_all(rest, profile, discard?, false, false, offset + 1, [byte | acc])

  defp decode_all(<<byte, rest::binary>>, profile, discard?, designated?, false, offset, acc)
       when byte <= 0x7F,
       do: decode_all(rest, profile, discard?, designated?, false, offset + 1, [byte | acc])

  defp decode_all(input, profile, true, designated?, true, offset, acc)
       when byte_size(input) < 2,
       do: decode_all(<<>>, profile, true, designated?, true, offset + byte_size(input), acc)

  defp decode_all(input, _profile, false, _designated?, true, offset, _acc)
       when byte_size(input) < 2,
       do: {:error, :incomplete_sequence, offset, input}

  defp decode_all(
         <<first, second, rest::binary>>,
         profile,
         discard?,
         designated?,
         true,
         offset,
         acc
       )
       when first in 0x21..0x7E and second in 0x21..0x7E do
    case Map.get(table(profile).many, <<first + 0x80, second + 0x80>>) do
      nil when discard? ->
        decode_all(rest, profile, true, designated?, true, offset + 2, acc)

      nil ->
        {:error, :invalid_sequence, offset, <<first, second>>}

      tuple ->
        decode_all(rest, profile, discard?, designated?, true, offset + 2, prepend(tuple, acc))
    end
  end

  defp decode_all(<<_byte, rest::binary>>, profile, true, designated?, shifted?, offset, acc),
    do: decode_all(rest, profile, true, designated?, shifted?, offset + 1, acc)

  defp decode_all(<<byte, _::binary>>, _profile, false, _designated?, _shifted?, offset, _acc),
    do: {:error, :invalid_sequence, offset, <<byte>>}

  defp encode_all([], _profile, _discard?, _designated?, false, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_all([], _profile, _discard?, _designated?, true, acc),
    do: {:ok, [<<0x0F>> | acc] |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_all([codepoint | rest], profile, discard?, _designated?, shifted?, acc)
       when codepoint in [0x0A, 0x0D] do
    shift = if shifted?, do: <<0x0F>>, else: <<>>
    encode_all(rest, profile, discard?, false, false, [<<codepoint>>, shift | acc])
  end

  defp encode_all([codepoint | rest], profile, discard?, designated?, shifted?, acc)
       when codepoint in 0..0x7F do
    shift = if shifted?, do: <<0x0F>>, else: <<>>
    encode_all(rest, profile, discard?, designated?, false, [<<codepoint>>, shift | acc])
  end

  defp encode_all([codepoint | rest], profile, discard?, designated?, shifted?, acc) do
    case Map.get(table(profile).encode, {codepoint}) do
      <<first, second>> ->
        designation = if designated?, do: <<>>, else: profile.designation
        shift = if shifted?, do: <<>>, else: <<0x0E>>

        encode_all(
          rest,
          profile,
          discard?,
          true,
          true,
          [<<first - 0x80, second - 0x80>>, shift, designation | acc]
        )

      nil when discard? ->
        encode_all(rest, profile, true, designated?, shifted?, acc)

      nil ->
        {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_substitute_all(
         [],
         resume,
         true,
         profile,
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
           profile,
           designated?,
           shifted?,
           acc,
           replacer
         )

  defp encode_substitute_all(
         [],
         [],
         false,
         _profile,
         _designated?,
         false,
         acc,
         _replacer
       ),
       do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute_all(
         [],
         [],
         false,
         _profile,
         _designated?,
         true,
         acc,
         _replacer
       ),
       do: {:ok, [<<0x0F>> | acc] |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute_all(
         [codepoint | rest],
         resume,
         replacement?,
         profile,
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
      profile,
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
         profile,
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
      profile,
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
         profile,
         designated?,
         shifted?,
         acc,
         replacer
       ) do
    case Map.get(table(profile).encode, {codepoint}) do
      <<first, second>> ->
        designation = if designated?, do: <<>>, else: profile.designation
        shift = if shifted?, do: <<>>, else: <<0x0E>>

        encode_substitute_all(
          rest,
          resume,
          replacement?,
          profile,
          true,
          true,
          [<<first - 0x80, second - 0x80>>, shift, designation | acc],
          replacer
        )

      nil when replacement? ->
        {:error, :unrepresentable_character, codepoint}

      nil ->
        encode_substitute_all(
          replacer.(codepoint),
          rest,
          true,
          profile,
          designated?,
          shifted?,
          acc,
          replacer
        )
    end
  end

  defp table(profile), do: Iconvex.Tables.fetch!(profile.table_id)
  defp prefix?(designation, input), do: binary_part(designation, 0, byte_size(input)) == input
  defp prepend(tuple, acc), do: tuple |> Tuple.to_list() |> Enum.reverse(acc)
end

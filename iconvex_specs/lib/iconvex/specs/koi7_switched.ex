defmodule Iconvex.Specs.KOI7Switched do
  @moduledoc """
  The stateful 7-bit KOI7 CES registered by IANA.

  Octal 016 selects ISO 5427, octal 017 selects ISO 646 IRV, and the
  initial state is ISO 646 IRV. The component ISO 5427 table is the complete,
  audited RFC 1345 table already shipped by this package.
  """

  use Iconvex.Codec

  @iso_5427_path Path.expand("../../../priv/tables/rfc1345_022.etf", __DIR__)
  @external_resource @iso_5427_path
  @iso_5427_table @iso_5427_path |> File.read!() |> :erlang.binary_to_term()
  @iso_5427_one @iso_5427_table.one
  @iso_5427_encode @iso_5427_table.encode
                   |> Enum.reduce(%{}, fn
                     {{codepoint}, <<byte>>}, result when byte not in [0o16, 0o17] ->
                       Map.put_new(result, codepoint, byte)

                     _, result ->
                       result
                   end)

  @impl true
  def canonical_name, do: "KOI7-switched"

  @impl true
  def aliases, do: ["csKOI7switched"]

  @impl true
  def codec_id, do: :koi7_switched

  @impl true
  def stateful?, do: true

  def source_url, do: "https://www.iana.org/assignments/charset-reg/KOI7-switched"

  @impl true
  def decode(input) when is_binary(input), do: decode_all(input, :ascii, 0, [])

  @impl true
  def decode_discard(input) when is_binary(input), do: decode_discard_all(input, :ascii, [])

  @impl true
  def encode(codepoints) when is_list(codepoints), do: encode_all(codepoints, :ascii, [])

  @impl true
  def encode_discard(codepoints) when is_list(codepoints),
    do: encode_discard_all(codepoints, :ascii, [])

  @impl true
  def encode_substitute(codepoints, replacer)
      when is_list(codepoints) and is_function(replacer, 1),
      do: encode_substitute_all(codepoints, [], false, :ascii, [], replacer)

  @impl true
  def decode_to_utf8(input) do
    with {:ok, codepoints} <- decode(input), do: {:ok, List.to_string(codepoints)}
  end

  @impl true
  def encode_from_utf8(input) when is_binary(input),
    do: Iconvex.Specs.CodecSupport.encode_utf8(input, &encode/1)

  defp decode_all(<<>>, _state, _offset, result), do: {:ok, :lists.reverse(result)}

  defp decode_all(<<0o16, rest::binary>>, _state, offset, result),
    do: decode_all(rest, :iso_5427, offset + 1, result)

  defp decode_all(<<0o17, rest::binary>>, _state, offset, result),
    do: decode_all(rest, :ascii, offset + 1, result)

  defp decode_all(<<byte, rest::binary>>, :ascii, offset, result) when byte < 0x80,
    do: decode_all(rest, :ascii, offset + 1, [byte | result])

  defp decode_all(<<byte, rest::binary>>, :iso_5427, offset, result) when byte < 0x80 do
    case elem(@iso_5427_one, byte) do
      {codepoint} -> decode_all(rest, :iso_5427, offset + 1, [codepoint | result])
      _ -> {:error, :invalid_sequence, offset, <<byte>>}
    end
  end

  defp decode_all(<<byte, _::binary>>, _state, offset, _result),
    do: {:error, :invalid_sequence, offset, <<byte>>}

  defp decode_discard_all(<<>>, _state, result), do: {:ok, :lists.reverse(result)}

  defp decode_discard_all(<<0o16, rest::binary>>, _state, result),
    do: decode_discard_all(rest, :iso_5427, result)

  defp decode_discard_all(<<0o17, rest::binary>>, _state, result),
    do: decode_discard_all(rest, :ascii, result)

  defp decode_discard_all(<<byte, rest::binary>>, :ascii, result) when byte < 0x80,
    do: decode_discard_all(rest, :ascii, [byte | result])

  defp decode_discard_all(<<byte, rest::binary>>, :iso_5427, result) when byte < 0x80 do
    case elem(@iso_5427_one, byte) do
      {codepoint} -> decode_discard_all(rest, :iso_5427, [codepoint | result])
      _ -> decode_discard_all(rest, :iso_5427, result)
    end
  end

  defp decode_discard_all(<<_byte, rest::binary>>, state, result),
    do: decode_discard_all(rest, state, result)

  defp encode_all([], _state, result),
    do: {:ok, result |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_all([codepoint | rest], state, result) do
    case encode_one(codepoint, state) do
      {:ok, bytes, next_state} -> encode_all(rest, next_state, [bytes | result])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_discard_all([], _state, result),
    do: {:ok, result |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_discard_all([codepoint | rest], state, result) do
    case encode_one(codepoint, state) do
      {:ok, bytes, next_state} -> encode_discard_all(rest, next_state, [bytes | result])
      :error -> encode_discard_all(rest, state, result)
    end
  end

  defp encode_substitute_all([], resume, true, state, result, replacer),
    do: encode_substitute_all(resume, [], false, state, result, replacer)

  defp encode_substitute_all([], [], false, _state, result, _replacer),
    do: {:ok, result |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute_all(
         [codepoint | rest],
         resume,
         replacement?,
         state,
         result,
         replacer
       ) do
    case encode_one(codepoint, state) do
      {:ok, bytes, next_state} ->
        encode_substitute_all(
          rest,
          resume,
          replacement?,
          next_state,
          [bytes | result],
          replacer
        )

      :error when replacement? ->
        {:error, :unrepresentable_character, codepoint}

      :error ->
        encode_substitute_all(replacer.(codepoint), rest, true, state, result, replacer)
    end
  end

  defp encode_one(codepoint, :ascii)
       when is_integer(codepoint) and codepoint in 0..0x7F and codepoint not in [0o16, 0o17],
       do: {:ok, <<codepoint>>, :ascii}

  defp encode_one(codepoint, :iso_5427) do
    case Map.fetch(@iso_5427_encode, codepoint) do
      {:ok, byte} -> {:ok, <<byte>>, :iso_5427}
      :error -> encode_ascii_with_switch(codepoint)
    end
  end

  defp encode_one(codepoint, :ascii) do
    case Map.fetch(@iso_5427_encode, codepoint) do
      {:ok, byte} -> {:ok, <<0o16, byte>>, :iso_5427}
      :error -> :error
    end
  end

  defp encode_ascii_with_switch(codepoint)
       when is_integer(codepoint) and codepoint in 0..0x7F and codepoint not in [0o16, 0o17],
       do: {:ok, <<0o17, codepoint>>, :ascii}

  defp encode_ascii_with_switch(_codepoint), do: :error
end

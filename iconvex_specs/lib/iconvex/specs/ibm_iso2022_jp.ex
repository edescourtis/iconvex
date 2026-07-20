defmodule Iconvex.Specs.IBMISO2022JP do
  @moduledoc false

  alias Iconvex.Tables

  @profiles %{
    ibm5052: %{
      single: :icu_archive_632,
      double: :icu_archive_723,
      designation: <<0x1B, "$B">>,
      return: <<0x1B, "(J">>,
      high_bit?: true
    },
    ibm5053: %{
      single: :icu_archive_632,
      double: :icu_archive_726,
      designation: <<0x1B, "$@">>,
      return: <<0x1B, "(J">>,
      high_bit?: false
    },
    ibm958: %{
      single: :ascii,
      double: :icu_archive_723,
      designation: <<0x1B, "$B">>,
      return: <<0x1B, "(B">>,
      high_bit?: true
    },
    ibm5055: %{
      single: :ascii,
      double: :icu_archive_726,
      designation: <<0x1B, "$@">>,
      return: <<0x1B, "(B">>,
      high_bit?: false
    }
  }

  def decode(id, input) do
    profile = Map.fetch!(@profiles, id)
    decode_loop(input, profile, :single, 0, [], false)
  end

  def decode_discard(id, input) do
    profile = Map.fetch!(@profiles, id)
    decode_loop(input, profile, :single, 0, [], true)
  end

  def decode_to_utf8(id, input) do
    case decode(id, input) do
      {:ok, codepoints} -> {:ok, List.to_string(codepoints)}
      error -> error
    end
  end

  def encode(id, codepoints),
    do: encode_all(codepoints, Map.fetch!(@profiles, id), :single, [], false)

  def encode_discard(id, codepoints),
    do: encode_all(codepoints, Map.fetch!(@profiles, id), :single, [], true)

  def encode_substitute(id, codepoints, replacer)
      when is_list(codepoints) and is_function(replacer, 1),
      do:
        encode_substitute_all(
          codepoints,
          [],
          false,
          Map.fetch!(@profiles, id),
          :single,
          [],
          replacer
        )

  def encode_from_utf8(id, input) do
    Iconvex.Specs.CodecSupport.encode_utf8(input, fn codepoints ->
      case encode(id, codepoints) do
        {:error, :unrepresentable_character, codepoint} ->
          {:encode_error, :unrepresentable_character, codepoint}

        result ->
          result
      end
    end)
  end

  defp decode_loop(<<>>, _profile, _mode, _offset, acc, _discard?),
    do: {:ok, :lists.reverse(acc)}

  defp decode_loop(<<0x1B, _::binary>> = input, profile, mode, offset, acc, discard?) do
    case escape(input, profile) do
      {:ok, next_mode} ->
        <<_::binary-size(3), rest::binary>> = input
        decode_loop(rest, profile, next_mode, offset + 3, acc, discard?)

      :incomplete when discard? ->
        {:ok, :lists.reverse(acc)}

      :incomplete ->
        {:error, :incomplete_sequence, offset, input}

      :error when discard? ->
        <<_byte, rest::binary>> = input
        decode_loop(rest, profile, mode, offset + 1, acc, discard?)

      :error ->
        size = min(3, byte_size(input))
        {:error, :invalid_sequence, offset, binary_part(input, 0, size)}
    end
  end

  defp decode_loop(<<byte, rest::binary>>, profile, :single, offset, acc, discard?)
       when byte < 0x80 do
    case decode_single(profile.single, byte) do
      nil when discard? ->
        decode_loop(rest, profile, :single, offset + 1, acc, discard?)

      nil ->
        {:error, :invalid_sequence, offset, <<byte>>}

      codepoints ->
        decode_loop(rest, profile, :single, offset + 1, prepend(codepoints, acc), discard?)
    end
  end

  defp decode_loop(input, _profile, :double, offset, acc, discard?) when byte_size(input) < 2 do
    if discard?,
      do: {:ok, :lists.reverse(acc)},
      else: {:error, :incomplete_sequence, offset, input}
  end

  defp decode_loop(
         <<first, second, rest::binary>> = input,
         profile,
         :double,
         offset,
         acc,
         discard?
       )
       when first in 0x21..0x7E and second in 0x21..0x7E do
    case decode_double(profile, first, second) do
      nil when discard? ->
        <<_byte, tail::binary>> = input
        decode_loop(tail, profile, :double, offset + 1, acc, discard?)

      nil ->
        {:error, :invalid_sequence, offset, <<first, second>>}

      codepoints ->
        decode_loop(rest, profile, :double, offset + 2, prepend(codepoints, acc), discard?)
    end
  end

  defp decode_loop(<<_byte, rest::binary>>, profile, mode, offset, acc, true),
    do: decode_loop(rest, profile, mode, offset + 1, acc, true)

  defp decode_loop(<<byte, _::binary>>, _profile, _mode, offset, _acc, false),
    do: {:error, :invalid_sequence, offset, <<byte>>}

  defp escape(input, profile) do
    cond do
      starts_with?(input, profile.designation) -> {:ok, :double}
      starts_with?(input, profile.return) -> {:ok, :single}
      byte_size(input) < 3 and starts_with?(profile.designation, input) -> :incomplete
      byte_size(input) < 3 and starts_with?(profile.return, input) -> :incomplete
      true -> :error
    end
  end

  defp decode_single(:ascii, byte), do: {byte}
  defp decode_single(id, byte), do: elem(Tables.fetch!(id).one, byte)

  defp decode_double(profile, first, second) do
    bytes =
      if profile.high_bit?,
        do: <<first + 0x80, second + 0x80>>,
        else: <<first, second>>

    Map.get(Tables.fetch!(profile.double).many, bytes)
  end

  defp encode_all([], profile, mode, acc, _discard?) do
    suffix = if mode == :double, do: profile.return, else: ""
    {:ok, acc |> :lists.reverse([suffix]) |> IO.iodata_to_binary()}
  end

  defp encode_all([codepoint | rest], profile, mode, acc, discard?) do
    case encode_codepoint(profile, codepoint) do
      {:ok, next_mode, bytes} ->
        shift = shift(mode, next_mode, profile)
        encode_all(rest, profile, next_mode, [bytes, shift | acc], discard?)

      :error when discard? ->
        encode_all(rest, profile, mode, acc, discard?)

      :error ->
        {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_substitute_all([], resume, true, profile, mode, acc, replacer),
    do: encode_substitute_all(resume, [], false, profile, mode, acc, replacer)

  defp encode_substitute_all([], [], false, profile, mode, acc, _replacer) do
    suffix = if mode == :double, do: profile.return, else: ""
    {:ok, acc |> :lists.reverse([suffix]) |> IO.iodata_to_binary()}
  end

  defp encode_substitute_all(
         [codepoint | rest],
         resume,
         replacement?,
         profile,
         mode,
         acc,
         replacer
       ) do
    case encode_codepoint(profile, codepoint) do
      {:ok, next_mode, bytes} ->
        shift = shift(mode, next_mode, profile)

        encode_substitute_all(
          rest,
          resume,
          replacement?,
          profile,
          next_mode,
          [bytes, shift | acc],
          replacer
        )

      :error when replacement? ->
        {:error, :unrepresentable_character, codepoint}

      :error ->
        encode_substitute_all(
          replacer.(codepoint),
          rest,
          true,
          profile,
          mode,
          acc,
          replacer
        )
    end
  end

  defp encode_codepoint(profile, codepoint) do
    case encode_single(profile.single, codepoint) do
      {:ok, byte} -> {:ok, :single, <<byte>>}
      :error -> encode_double(profile, codepoint)
    end
  end

  defp encode_single(:ascii, codepoint) when codepoint in 0..0x7F and codepoint != 0x1B,
    do: {:ok, codepoint}

  defp encode_single(:ascii, _codepoint), do: :error

  defp encode_single(id, codepoint) do
    case Map.fetch(Tables.fetch!(id).encode, {codepoint}) do
      {:ok, <<byte>>} when byte < 0x80 and byte != 0x1B -> {:ok, byte}
      _ -> :error
    end
  end

  defp encode_double(profile, codepoint) do
    case Map.fetch(Tables.fetch!(profile.double).encode, {codepoint}) do
      {:ok, <<first, second>>}
      when profile.high_bit? and first in 0xA1..0xFE and second in 0xA1..0xFE ->
        {:ok, :double, <<first - 0x80, second - 0x80>>}

      {:ok, <<first, second>>}
      when not profile.high_bit? and first in 0x21..0x7E and second in 0x21..0x7E ->
        {:ok, :double, <<first, second>>}

      _ ->
        :error
    end
  end

  defp shift(mode, mode, _profile), do: ""
  defp shift(_mode, :double, profile), do: profile.designation
  defp shift(_mode, :single, profile), do: profile.return

  defp starts_with?(binary, prefix) when byte_size(binary) >= byte_size(prefix),
    do: binary_part(binary, 0, byte_size(prefix)) == prefix

  defp starts_with?(_binary, _prefix), do: false

  defp prepend(tuple, acc) when tuple_size(tuple) == 1, do: [elem(tuple, 0) | acc]
  defp prepend(tuple, acc), do: tuple |> Tuple.to_list() |> :lists.reverse(acc)
end

defmodule Iconvex.Specs.IBM5052 do
  @moduledoc "IBM ISO-2022 Japanese profile with IBM-895 Roman and IBM-952 JIS X 0208-1983."
  use Iconvex.Codec
  alias Iconvex.Specs.IBMISO2022JP, as: Engine

  def canonical_name, do: "IBM-5052"
  def aliases, do: ["IBM5052", "CP5052", "CCSID5052", "IBM-956", "IBM956", "CP956", "CCSID956"]
  def codec_id, do: :ibm5052
  def stateful?, do: true
  def decode(input), do: Engine.decode(:ibm5052, input)
  def decode_discard(input), do: Engine.decode_discard(:ibm5052, input)
  def decode_to_utf8(input), do: Engine.decode_to_utf8(:ibm5052, input)
  def encode(codepoints), do: Engine.encode(:ibm5052, codepoints)
  def encode_discard(codepoints), do: Engine.encode_discard(:ibm5052, codepoints)

  def encode_substitute(codepoints, replacer),
    do: Engine.encode_substitute(:ibm5052, codepoints, replacer)

  def encode_from_utf8(input), do: Engine.encode_from_utf8(:ibm5052, input)
end

defmodule Iconvex.Specs.IBM5053 do
  @moduledoc "IBM ISO-2022 Japanese profile with IBM-895 Roman and IBM-955 JIS X 0208-1978."
  use Iconvex.Codec
  alias Iconvex.Specs.IBMISO2022JP, as: Engine

  def canonical_name, do: "IBM-5053"
  def aliases, do: ["IBM5053", "CP5053", "CCSID5053", "IBM-957", "IBM957", "CP957", "CCSID957"]
  def codec_id, do: :ibm5053
  def stateful?, do: true
  def decode(input), do: Engine.decode(:ibm5053, input)
  def decode_discard(input), do: Engine.decode_discard(:ibm5053, input)
  def decode_to_utf8(input), do: Engine.decode_to_utf8(:ibm5053, input)
  def encode(codepoints), do: Engine.encode(:ibm5053, codepoints)
  def encode_discard(codepoints), do: Engine.encode_discard(:ibm5053, codepoints)

  def encode_substitute(codepoints, replacer),
    do: Engine.encode_substitute(:ibm5053, codepoints, replacer)

  def encode_from_utf8(input), do: Engine.encode_from_utf8(:ibm5053, input)
end

defmodule Iconvex.Specs.IBM958 do
  @moduledoc "IBM ISO-2022 Japanese profile with ASCII and IBM-952 JIS X 0208-1983."
  use Iconvex.Codec
  alias Iconvex.Specs.IBMISO2022JP, as: Engine

  def canonical_name, do: "IBM-958"
  def aliases, do: ["IBM958", "CP958", "CCSID958"]
  def codec_id, do: :ibm958
  def stateful?, do: true
  def decode(input), do: Engine.decode(:ibm958, input)
  def decode_discard(input), do: Engine.decode_discard(:ibm958, input)
  def decode_to_utf8(input), do: Engine.decode_to_utf8(:ibm958, input)
  def encode(codepoints), do: Engine.encode(:ibm958, codepoints)
  def encode_discard(codepoints), do: Engine.encode_discard(:ibm958, codepoints)

  def encode_substitute(codepoints, replacer),
    do: Engine.encode_substitute(:ibm958, codepoints, replacer)

  def encode_from_utf8(input), do: Engine.encode_from_utf8(:ibm958, input)
end

defmodule Iconvex.Specs.IBM5055 do
  @moduledoc "IBM ISO-2022 Japanese profile with ASCII and IBM-955 JIS X 0208-1978."
  use Iconvex.Codec
  alias Iconvex.Specs.IBMISO2022JP, as: Engine

  def canonical_name, do: "IBM-5055"
  def aliases, do: ["IBM5055", "CP5055", "CCSID5055", "IBM-959", "IBM959", "CP959", "CCSID959"]
  def codec_id, do: :ibm5055
  def stateful?, do: true
  def decode(input), do: Engine.decode(:ibm5055, input)
  def decode_discard(input), do: Engine.decode_discard(:ibm5055, input)
  def decode_to_utf8(input), do: Engine.decode_to_utf8(:ibm5055, input)
  def encode(codepoints), do: Engine.encode(:ibm5055, codepoints)
  def encode_discard(codepoints), do: Engine.encode_discard(:ibm5055, codepoints)

  def encode_substitute(codepoints, replacer),
    do: Engine.encode_substitute(:ibm5055, codepoints, replacer)

  def encode_from_utf8(input), do: Engine.encode_from_utf8(:ibm5055, input)
end

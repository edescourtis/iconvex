defmodule Iconvex.Specs.IANAISO10646Profiles do
  @moduledoc "RFC 1815 and IANA ISO-10646 16-bit big-endian repertoire profiles."

  import Bitwise

  @data_path Path.expand("../../../priv/iana_iso10646_profiles.etf", __DIR__)
  @manifest_path Path.expand("../../../priv/iana_iso10646_profiles_manifest.etf", __DIR__)
  @external_resource @data_path
  @external_resource @manifest_path
  @bitsets @data_path |> File.read!() |> :erlang.binary_to_term()
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()

  def profiles, do: @manifest.profiles
  def manifest, do: @manifest

  def decode(profile, input) when is_binary(input),
    do: decode_units(input, Map.fetch!(@bitsets, profile), 0, [])

  def decode_discard(profile, input) when is_binary(input),
    do: decode_discard_units(input, Map.fetch!(@bitsets, profile), [])

  def decode_to_utf8(profile, input) when is_binary(input),
    do: decode_utf8_units(input, Map.fetch!(@bitsets, profile), 0, [])

  def encode(profile, codepoints) when is_list(codepoints),
    do: encode_units(codepoints, Map.fetch!(@bitsets, profile), [])

  def encode_discard(profile, codepoints) when is_list(codepoints),
    do: encode_discard_units(codepoints, Map.fetch!(@bitsets, profile), [])

  def encode_from_utf8(profile, input) when is_binary(input),
    do: encode_utf8_units(input, Map.fetch!(@bitsets, profile), 0, [])

  defp decode_units(<<>>, _bitset, _offset, result), do: {:ok, :lists.reverse(result)}

  defp decode_units(<<byte>>, _bitset, offset, _result),
    do: {:error, :incomplete_sequence, offset, <<byte>>}

  defp decode_units(<<codepoint::16-big, rest::binary>>, bitset, offset, result) do
    if allowed?(bitset, codepoint),
      do: decode_units(rest, bitset, offset + 2, [codepoint | result]),
      else: {:error, :invalid_sequence, offset, <<codepoint::16-big>>}
  end

  defp decode_discard_units(<<>>, _bitset, result), do: {:ok, :lists.reverse(result)}
  defp decode_discard_units(<<_byte>>, _bitset, result), do: {:ok, :lists.reverse(result)}

  defp decode_discard_units(<<codepoint::16-big, rest::binary>>, bitset, result) do
    if allowed?(bitset, codepoint),
      do: decode_discard_units(rest, bitset, [codepoint | result]),
      else: decode_discard_units(rest, bitset, result)
  end

  defp decode_utf8_units(<<>>, _bitset, _offset, result),
    do: {:ok, result |> :lists.reverse() |> IO.iodata_to_binary()}

  defp decode_utf8_units(<<byte>>, _bitset, offset, _result),
    do: {:error, :incomplete_sequence, offset, <<byte>>}

  defp decode_utf8_units(<<codepoint::16-big, rest::binary>>, bitset, offset, result) do
    if allowed?(bitset, codepoint),
      do: decode_utf8_units(rest, bitset, offset + 2, [<<codepoint::utf8>> | result]),
      else: {:error, :invalid_sequence, offset, <<codepoint::16-big>>}
  end

  defp encode_units([], _bitset, result),
    do: {:ok, result |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_units([codepoint | rest], bitset, result) do
    if allowed?(bitset, codepoint),
      do: encode_units(rest, bitset, [<<codepoint::16-big>> | result]),
      else: {:error, :unrepresentable_character, codepoint}
  end

  defp encode_discard_units([], _bitset, result),
    do: {:ok, result |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_discard_units([codepoint | rest], bitset, result) do
    if allowed?(bitset, codepoint),
      do: encode_discard_units(rest, bitset, [<<codepoint::16-big>> | result]),
      else: encode_discard_units(rest, bitset, result)
  end

  defp encode_utf8_units(<<>>, _bitset, _offset, result),
    do: {:ok, result |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_utf8_units(<<codepoint::utf8, rest::binary>>, bitset, offset, result) do
    if allowed?(bitset, codepoint) do
      encode_utf8_units(
        rest,
        bitset,
        offset + byte_size(<<codepoint::utf8>>),
        [<<codepoint::16-big>> | result]
      )
    else
      {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_utf8_units(input, _bitset, offset, _result) do
    case :unicode.characters_to_list(input, :utf8) do
      {:incomplete, converted, rest} ->
        {:decode_error, :incomplete_sequence, offset + utf8_size(converted), rest}

      {:error, converted, rest} ->
        {:decode_error, :invalid_sequence, offset + utf8_size(converted), rest}
    end
  end

  defp allowed?(bitset, codepoint) when codepoint in 0..0xFFFF do
    byte = :binary.at(bitset, codepoint >>> 3)
    (byte &&& 1 <<< (codepoint &&& 7)) != 0
  end

  defp allowed?(_bitset, _codepoint), do: false
  defp utf8_size(codepoints), do: codepoints |> List.to_string() |> byte_size()
end

defmodule Iconvex.Specs.IANAISO10646Profiles.Codecs do
  @moduledoc false
  @manifest_path Path.expand("../../../priv/iana_iso10646_profiles_manifest.etf", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()
  @modules Enum.map(
             @manifest.profiles,
             &Module.concat(__MODULE__, &1.profile |> Atom.to_string() |> Macro.camelize())
           )

  def modules, do: @modules
end

manifest_path = Path.expand("../../../priv/iana_iso10646_profiles_manifest.etf", __DIR__)

for entry <- manifest_path |> File.read!() |> :erlang.binary_to_term() |> Map.fetch!(:profiles) do
  module =
    Module.concat(
      Iconvex.Specs.IANAISO10646Profiles.Codecs,
      Macro.camelize(to_string(entry.profile))
    )

  defmodule module do
    use Iconvex.Codec
    @entry entry
    alias Iconvex.Specs.IANAISO10646Profiles, as: Engine

    @impl true
    def canonical_name, do: @entry.name
    @impl true
    def aliases, do: @entry.aliases
    @impl true
    def codec_id, do: @entry.id
    @impl true
    def decode(input), do: Engine.decode(@entry.profile, input)
    @impl true
    def decode_discard(input), do: Engine.decode_discard(@entry.profile, input)
    @impl true
    def decode_to_utf8(input), do: Engine.decode_to_utf8(@entry.profile, input)
    @impl true
    def encode(codepoints), do: Engine.encode(@entry.profile, codepoints)
    @impl true
    def encode_discard(codepoints), do: Engine.encode_discard(@entry.profile, codepoints)
    @impl true
    def encode_substitute(codepoints, replacer),
      do:
        Iconvex.Specs.CodecSupport.encode_substitute_each(
          codepoints,
          &encode/1,
          replacer
        )

    @impl true
    def encode_from_utf8(input), do: Engine.encode_from_utf8(@entry.profile, input)
  end
end

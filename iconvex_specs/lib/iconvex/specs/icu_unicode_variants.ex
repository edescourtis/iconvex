defmodule Iconvex.Specs.ICUUnicodeVariants do
  @moduledoc "ICU 78.3 platform-endian and Java-compatible Unicode variants."

  @manifest_path Path.expand("../../../priv/icu_unicode_variants_manifest.etf", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()
  @entries Map.new(@manifest.encodings, &{&1.variant, &1})

  def aggregate_sha256, do: @manifest.aggregate_sha256
  def entries, do: @manifest.encodings
  def entry(variant), do: Map.fetch!(@entries, variant)
  def revision, do: @manifest.revision
  def sources, do: @manifest.sources

  def decode(:utf16_v1, <<>>), do: {:ok, []}

  def decode(:utf16_v1, input) when byte_size(input) < 2,
    do: {:error, :incomplete_sequence, 0, input}

  def decode(:utf16_v1, <<0xFE, 0xFF, rest::binary>>), do: raw_decode(:utf16be, rest)
  def decode(:utf16_v1, <<0xFF, 0xFE, rest::binary>>), do: raw_decode(:utf16le, rest)

  def decode(:utf16_v1, <<first, second, _::binary>>),
    do: {:error, :invalid_sequence, 0, <<first, second>>}

  def decode(:utf16_v2, <<0xFE, 0xFF, rest::binary>>), do: raw_decode(:utf16be, rest)
  def decode(:utf16_v2, <<0xFF, 0xFE, rest::binary>>), do: raw_decode(:utf16le, rest)
  def decode(:utf16_v2, input), do: raw_decode(:utf16be, input)
  def decode(variant, input), do: raw_decode(raw_id(variant), input)

  def decode_discard(:utf16_v1, <<>>), do: {:ok, []}

  def decode_discard(:utf16_v1, input) when byte_size(input) < 2,
    do: {:ok, []}

  def decode_discard(:utf16_v1, <<0xFE, 0xFF, rest::binary>>),
    do: raw_decode_discard(:utf16be, rest)

  def decode_discard(:utf16_v1, <<0xFF, 0xFE, rest::binary>>),
    do: raw_decode_discard(:utf16le, rest)

  def decode_discard(:utf16_v1, <<_first, _second, rest::binary>>),
    do: raw_decode_discard(:utf16be, rest)

  def decode_discard(:utf16_v2, <<0xFE, 0xFF, rest::binary>>),
    do: raw_decode_discard(:utf16be, rest)

  def decode_discard(:utf16_v2, <<0xFF, 0xFE, rest::binary>>),
    do: raw_decode_discard(:utf16le, rest)

  def decode_discard(:utf16_v2, input), do: raw_decode_discard(:utf16be, input)
  def decode_discard(variant, input), do: raw_decode_discard(raw_id(variant), input)

  def encode(:utf16_v1, codepoints) do
    endian = :erlang.system_info(:endian)

    with {:ok, encoded} <- raw_encode(utf16_id(endian), codepoints) do
      {:ok, prefix(codepoints, utf16_bom(endian)) <> encoded}
    end
  end

  def encode(:utf16_v2, codepoints) do
    with {:ok, encoded} <- raw_encode(:utf16be, codepoints) do
      {:ok, prefix(codepoints, <<0xFE, 0xFF>>) <> encoded}
    end
  end

  def encode(variant, codepoints), do: raw_encode(raw_id(variant), codepoints)

  def encode_discard(:utf16_v1, codepoints) do
    endian = :erlang.system_info(:endian)
    {:ok, encoded} = raw_encode_discard(utf16_id(endian), codepoints)
    {:ok, prefix(codepoints, utf16_bom(endian)) <> encoded}
  end

  def encode_discard(:utf16_v2, codepoints) do
    {:ok, encoded} = raw_encode_discard(:utf16be, codepoints)
    {:ok, prefix(codepoints, <<0xFE, 0xFF>>) <> encoded}
  end

  def encode_discard(variant, codepoints), do: raw_encode_discard(raw_id(variant), codepoints)

  def encode_substitute(variant, codepoints, replacer),
    do:
      Iconvex.Specs.CodecSupport.encode_substitute_transform(
        codepoints,
        &encode(variant, &1),
        replacer
      )

  def decode_to_utf8(variant, input) do
    with {:ok, codepoints} <- decode(variant, input), do: {:ok, List.to_string(codepoints)}
  end

  def encode_from_utf8(variant, input) when is_binary(input) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        encode(variant, codepoints)

      {:error, converted, rest} ->
        {:decode_error, :invalid_sequence, utf8_size(converted), rest}

      {:incomplete, converted, rest} ->
        {:decode_error, :incomplete_sequence, utf8_size(converted), rest}
    end
  end

  defp raw_decode(id, input), do: Iconvex.UnicodeCodec.decode(%{id: id}, input)
  defp raw_encode(id, codepoints), do: Iconvex.UnicodeCodec.encode(%{id: id}, codepoints)

  defp raw_encode_discard(id, codepoints),
    do: Iconvex.UnicodeCodec.encode_discard(%{id: id}, codepoints)

  defp raw_decode_discard(id, input), do: raw_decode_discard(id, input, [])

  defp raw_decode_discard(_id, <<>>, acc), do: {:ok, acc |> :lists.reverse() |> List.flatten()}

  defp raw_decode_discard(id, input, acc) do
    case raw_decode(id, input) do
      {:ok, codepoints} ->
        {:ok, acc |> :lists.reverse([codepoints]) |> List.flatten()}

      {:error, :incomplete_sequence, offset, _sequence} ->
        prefix = binary_part(input, 0, offset)
        decoded = if prefix == <<>>, do: [], else: elem(raw_decode(id, prefix), 1)
        {:ok, acc |> :lists.reverse([decoded]) |> List.flatten()}

      {:error, :invalid_sequence, offset, sequence} ->
        prefix = binary_part(input, 0, offset)
        decoded = if prefix == <<>>, do: [], else: elem(raw_decode(id, prefix), 1)
        consumed = offset + max(byte_size(sequence), unit_size(id))
        remaining = max(byte_size(input) - consumed, 0)
        rest = binary_part(input, min(consumed, byte_size(input)), remaining)
        raw_decode_discard(id, rest, [decoded | acc])
    end
  end

  defp raw_id(:utf16_platform), do: utf16_id(:erlang.system_info(:endian))
  defp raw_id(:utf16_opposite), do: utf16_id(opposite(:erlang.system_info(:endian)))
  defp raw_id(:utf32_platform), do: utf32_id(:erlang.system_info(:endian))
  defp raw_id(:utf32_opposite), do: utf32_id(opposite(:erlang.system_info(:endian)))
  defp utf16_id(:big), do: :utf16be
  defp utf16_id(:little), do: :utf16le
  defp utf32_id(:big), do: :utf32be
  defp utf32_id(:little), do: :utf32le
  defp utf16_bom(:big), do: <<0xFE, 0xFF>>
  defp utf16_bom(:little), do: <<0xFF, 0xFE>>
  defp opposite(:big), do: :little
  defp opposite(:little), do: :big
  defp prefix([], _bom), do: <<>>
  defp prefix(_codepoints, bom), do: bom
  defp unit_size(id) when id in [:utf16, :utf16be, :utf16le], do: 2
  defp unit_size(_id), do: 4
  defp utf8_size(codepoints), do: codepoints |> List.to_string() |> byte_size()
end

for {module, variant} <- [
      {Iconvex.Specs.ICUUTF16PlatformEndian, :utf16_platform},
      {Iconvex.Specs.ICUUTF16OppositeEndian, :utf16_opposite},
      {Iconvex.Specs.ICUUTF32PlatformEndian, :utf32_platform},
      {Iconvex.Specs.ICUUTF32OppositeEndian, :utf32_opposite},
      {Iconvex.Specs.ICUUTF16Version1, :utf16_v1},
      {Iconvex.Specs.ICUUTF16Version2, :utf16_v2}
    ] do
  defmodule module do
    @moduledoc false
    use Iconvex.Codec
    @variant variant
    alias Iconvex.Specs.ICUUnicodeVariants, as: Engine

    @impl true
    def canonical_name, do: Engine.entry(@variant).name
    @impl true
    def codec_id, do: Engine.entry(@variant).id
    @impl true
    def decode(input), do: Engine.decode(@variant, input)
    @impl true
    def decode_discard(input), do: Engine.decode_discard(@variant, input)
    @impl true
    def encode(codepoints), do: Engine.encode(@variant, codepoints)
    @impl true
    def encode_discard(codepoints), do: Engine.encode_discard(@variant, codepoints)
    @impl true
    def encode_substitute(codepoints, replacer),
      do: Engine.encode_substitute(@variant, codepoints, replacer)

    @impl true
    def decode_to_utf8(input), do: Engine.decode_to_utf8(@variant, input)
    @impl true
    def encode_from_utf8(input), do: Engine.encode_from_utf8(@variant, input)
  end
end

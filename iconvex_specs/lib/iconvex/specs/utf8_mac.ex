defmodule Iconvex.Specs.UTF8Mac do
  @moduledoc """
  Apple's UTF-8-MAC converter for the frozen HFS Plus Unicode 3.2 rules.

  The implementation follows Apple libiconv 115.100.1's current UTF8MAC
  module: it decomposes the module's 970 BMP characters, handles all 11,172
  Hangul syllables algorithmically, and greedily precomposes supported input
  pairs on decode. The Apple format is UCS-2-era and therefore does not admit
  supplementary code points; this implementation rejects them instead of
  reproducing the C adapter's lossy 16-bit truncation edge case.
  """

  use Iconvex.Codec

  @manifest_path Path.expand("../../../priv/utf8_mac_manifest.etf", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()
  @decompose @manifest.decompose
  @compose @manifest.compose
  @decompose_utf8 Map.new(@decompose, fn {codepoint, replacement} ->
                    {codepoint, List.to_string(replacement)}
                  end)
  @utf8 %{id: :utf8}

  @sbase 0xAC00
  @lbase 0x1100
  @vbase 0x1161
  @tbase 0x11A7
  @scount 11_172
  @lcount 19
  @vcount 21
  @tcount 28
  @ncount @vcount * @tcount

  @impl true
  def canonical_name, do: "UTF-8-MAC"

  @impl true
  def aliases, do: ["UTF8-MAC", "UTF-8-HFS", "UTF8-HFS", "UTF-8-HFS-PLUS"]

  @impl true
  def codec_id, do: :utf8_mac

  @impl true
  def stateful?, do: true

  @doc "Returns the pinned source SHA-256 map."
  def source_hashes, do: @manifest.source_hashes

  @doc "Returns all 970 effective Unicode 3.2 decomposition mappings."
  def decomposition_table, do: @decompose

  @doc "Returns auditable source and table metadata."
  def source_manifest,
    do:
      Map.take(@manifest, [
        :aggregate_sha256,
        :apple_release,
        :apple_revision,
        :composition_exclusions,
        :composition_pairs,
        :composition_pairs_implementation_only,
        :composition_pairs_standard_only,
        :historic_table_rows,
        :implementation_additions,
        :implementation_removals,
        :implementation_rows,
        :source_hashes,
        :source_urls,
        :unicode_version
      ])

  @impl true
  def decode(input) when is_binary(input) do
    case Iconvex.UnicodeCodec.decode(@utf8, input) do
      {:ok, _codepoints} ->
        decode_valid(input, 0, [])

      {:error, kind, offset, sequence} ->
        {:error, normalize_kind(kind, sequence), offset, sequence}
    end
  end

  @impl true
  def decode_discard(input) when is_binary(input) do
    input
    |> decode_discard_valid([])
    |> precompose()
    |> then(&{:ok, &1})
  end

  @impl true
  def decode_to_utf8(input) when is_binary(input) do
    with {:ok, codepoints} <- decode(input), do: {:ok, List.to_string(codepoints)}
  end

  @impl true
  def encode(codepoints) when is_list(codepoints), do: encode_all(codepoints, [])

  @impl true
  def encode_discard(codepoints) when is_list(codepoints),
    do: encode_discard_all(codepoints, [])

  @impl true
  def encode_substitute(codepoints, replacer),
    do:
      Iconvex.Specs.CodecSupport.encode_substitute_transform(
        codepoints,
        &encode/1,
        replacer
      )

  @impl true
  def encode_from_utf8(input) when is_binary(input) do
    case Iconvex.UnicodeCodec.decode(@utf8, input) do
      {:ok, codepoints} ->
        encode(codepoints)

      {:error, kind, offset, sequence} ->
        first_encode_error_or_decode(input, kind, offset, sequence)
    end
  end

  defp first_encode_error_or_decode(input, kind, offset, sequence) do
    prefix = binary_part(input, 0, offset)

    case Iconvex.UnicodeCodec.decode(@utf8, prefix) do
      {:ok, codepoints} ->
        case encode(codepoints) do
          {:ok, _output} ->
            {:decode_error, normalize_kind(kind, sequence), offset, sequence}

          earlier_error ->
            earlier_error
        end

      _malformed_prefix ->
        {:decode_error, normalize_kind(kind, sequence), offset, sequence}
    end
  end

  defp decode_valid(<<>>, _offset, acc), do: {:ok, acc |> :lists.reverse() |> precompose()}

  defp decode_valid(<<codepoint::utf8, rest::binary>> = input, offset, acc) do
    consumed = byte_size(input) - byte_size(rest)
    sequence = binary_part(input, 0, consumed)

    if decodable?(codepoint) do
      decode_valid(rest, offset + consumed, [codepoint | acc])
    else
      {:error, :invalid_sequence, offset, sequence}
    end
  end

  defp decode_discard_valid(<<>>, acc), do: :lists.reverse(acc)

  defp decode_discard_valid(<<codepoint::utf8, rest::binary>>, acc) do
    if decodable?(codepoint),
      do: decode_discard_valid(rest, [codepoint | acc]),
      else: decode_discard_valid(rest, acc)
  end

  defp decode_discard_valid(<<_byte, rest::binary>>, acc),
    do: decode_discard_valid(rest, acc)

  defp decodable?(codepoint), do: codepoint <= 0xFFFF and codepoint not in [0xFFFE, 0xFFFF]

  defp encode_all([], acc), do: {:ok, binary_result(acc)}

  defp encode_all([codepoint | rest], acc) do
    case encoded(codepoint) do
      {:ok, bytes} -> encode_all(rest, [bytes | acc])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_discard_all([], acc), do: {:ok, binary_result(acc)}

  defp encode_discard_all([codepoint | rest], acc) do
    case encoded(codepoint) do
      {:ok, bytes} -> encode_discard_all(rest, [bytes | acc])
      :error -> encode_discard_all(rest, acc)
    end
  end

  defp encoded(codepoint)
       when is_integer(codepoint) and codepoint in 0..0xFFFF and
              codepoint not in 0xD800..0xDFFF and codepoint not in [0xFEFF, 0xFFFE] do
    cond do
      codepoint in @sbase..(@sbase + @scount - 1) ->
        {:ok, codepoint |> decompose_hangul() |> List.to_string()}

      Map.has_key?(@decompose_utf8, codepoint) ->
        {:ok, Map.fetch!(@decompose_utf8, codepoint)}

      true ->
        {:ok, <<codepoint::utf8>>}
    end
  end

  defp encoded(_codepoint), do: :error

  defp decompose_hangul(syllable) do
    index = syllable - @sbase
    leading = @lbase + div(index, @ncount)
    vowel = @vbase + div(rem(index, @ncount), @tcount)

    case rem(index, @tcount) do
      0 -> [leading, vowel]
      trailing -> [leading, vowel, @tbase + trailing]
    end
  end

  defp precompose([]), do: []
  defp precompose([base | rest]), do: precompose_base(base, rest, [])

  defp precompose_base(base, [], acc), do: :lists.reverse([base | acc])

  defp precompose_base(base, [combining | rest], acc) do
    case combined(base, combining) do
      nil -> precompose_base(combining, rest, [base | acc])
      composite -> precompose_base(composite, rest, acc)
    end
  end

  defp combined(base, combining)
       when base in @lbase..(@lbase + @lcount - 1)//1 and
              combining in @vbase..(@vbase + @vcount - 1)//1 do
    @sbase + (base - @lbase) * @ncount + (combining - @vbase) * @tcount
  end

  defp combined(base, combining)
       when base in @sbase..(@sbase + @scount - 1)//1 and
              combining in (@tbase + 1)..(@tbase + @tcount - 1)//1 do
    if rem(base - @sbase, @tcount) == 0, do: base + combining - @tbase, else: nil
  end

  defp combined(base, combining), do: Map.get(@compose, {base, combining})

  defp normalize_kind(:incomplete_sequence, <<first, _rest::binary>>)
       when first not in 0xC2..0xF4,
       do: :invalid_sequence

  defp normalize_kind(kind, _sequence), do: kind

  defp binary_result(acc), do: acc |> :lists.reverse() |> IO.iodata_to_binary()
end

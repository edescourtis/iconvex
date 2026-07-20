defmodule Iconvex.Specs.IBMAdditionalCodePages do
  @moduledoc false

  @source_dir Path.expand("../../../priv/sources/ibm-additional-code-pages", __DIR__)
  @sources_root Path.expand("../../../priv/sources", __DIR__)
  @source_metadata_path Path.join(@source_dir, "SOURCE_METADATA.md")
  @chunk_units 4_096

  @join_sources [
    "ibm-additional-code-pages/CP00293.txt",
    "ibm-additional-code-pages/CP00437.txt",
    "ibm-additional-code-pages/CP00775.txt",
    "ibm-additional-code-pages/CP00850.txt",
    "ibm-additional-code-pages/CP00857.txt",
    "ibm-additional-code-pages/CP00875.txt",
    "ibm-additional-code-pages/CP01254.txt",
    "icu-data-archive/ibm-293_P100-1995.ucm",
    "icu-data-archive/ibm-437_P100-1995.ucm",
    "icu-data-archive/ibm-775_P100-1996.ucm",
    "icu-78.3/ibm-850_P100-1995.ucm",
    "icu-data-archive/ibm-857_P100-1995.ucm",
    "icu-data-archive/ibm-875_P100-1995.ucm",
    "icu-data-archive/ibm-1254_P100-1995.ucm"
  ]

  @source_digests %{
    "ibm-additional-code-pages/CP00293.txt" =>
      "0f723444e11f78432168fe7c12d10c036593ac70330e18195a8e1e5cd2875e64",
    "ibm-additional-code-pages/CP00310.pdf" =>
      "af8c6a11e3e630eb136753fcafee48fd1bda2dc154d38183a58b1c87e4edcf0f",
    "ibm-additional-code-pages/CP00310.txt" =>
      "a5fcdf29fe3de63927b7ab29fd2c03a6aecbd12f3909051b23a09cbb2d15e99c",
    "ibm-additional-code-pages/CP00437.txt" =>
      "973a8ef3aa0690fd4ea918e7142f1447d0d16a68003eb9b761e028d8ab2b5638",
    "ibm-additional-code-pages/CP00775.txt" =>
      "8b06074e87afef2b3228f301dbcf764b1e286f65286598656d316c67fe46aa3c",
    "ibm-additional-code-pages/CP00850.txt" =>
      "68cefeb52ce17ec100c4d845872dd03589432f4986a92ff8548c6fa2aed333a7",
    "ibm-additional-code-pages/CP00857.txt" =>
      "2a17021d45c8235ed7732db16271083adc26114889f02241e1d47b74fe9b571a",
    "ibm-additional-code-pages/CP00875.txt" =>
      "baaf5f62fb24fd81cf030af62ef6ec0e34d4fe9645ca197c714c74d076d5a20c",
    "ibm-additional-code-pages/CP00907.pdf" =>
      "f643cce61bfdd3698538ca36c6ed574e557acac1f10017b8d29548b897af2ed2",
    "ibm-additional-code-pages/CP01116.pdf" =>
      "e7f62540a940647735bab74e32f81ad26520c18d677bd66f21126c2040cdaa88",
    "ibm-additional-code-pages/CP01117.pdf" =>
      "b43b945bff9a0757d218e216aa63ba41bd414e6e575499f186dd3a5c9b726655",
    "ibm-additional-code-pages/CP01254.txt" =>
      "c13575bc25e7339bbd4cd7b1c7f8617103fa7d4a110d7e88d77431eaeaae694d",
    "ibm-additional-code-pages/CP01287.pdf" =>
      "7acba5b3ec8770714b7321cfd14cfa6446ef0ddb3a78dbf8eb56c1a404b96b96",
    "ibm-additional-code-pages/CP01287.txt" =>
      "d69294ca9e92e4ba1d70efbe0e7e2a19312e2e74530adbd82d01773c15fd3282",
    "ibm-additional-code-pages/CP01288.pdf" =>
      "89c87f75c8c71d072be4daf9da52a465828a40cc390d0dcbc09f0558792290bb",
    "ibm-additional-code-pages/CP01288.txt" =>
      "7e2428fb5c507610c57f0f3c4ff1e93b1ec1c9a4e26c2b27f07b2b4d19dc583f",
    "ibm-additional-code-pages/DEC-PPL2-1994.pdf" =>
      "0d47bb9b30100ab2b24bdf05cf565775970442736a42c7cbb9f98ca55a4cf13f",
    "ibm-additional-code-pages/cp1116-850-p100-composite.map" =>
      "0a802f4be6b771ad0b4c7d1f958da0f599025337b5592f917bc520081a0020cb",
    "ibm-additional-code-pages/cp1117-437-p100-composite.map" =>
      "9f00f6453bd43c81723b8f272999293d1fe2ddcf85ea8cce5b3f04e8d0ffd91e",
    "ibm-additional-code-pages/cp1287-dec-1994.map" =>
      "542afe11b341a24a9ac9547d2144e2aa88e0b2dc959bbf1c984b8ff6d6795525",
    "ibm-additional-code-pages/cp1288-dec-1994.map" =>
      "6cb89e4f2a571b9664a8c8cd66a12bf3ce221153f44adee2c8ec4fa396ba03ba",
    "ibm-additional-code-pages/cp310-293-p100-composite-vpua.map" =>
      "2165de9ceec4811cc4305d3c3b45d595ddaf450ab3d4dff3b25bf62b8058494e",
    "ibm-additional-code-pages/cp310-tnz-07d60f4.map" =>
      "96cdf110667cdc28bb0f5e4b3a7185e3427d295f7f132f0a66e906f5bedbe932",
    "ibm-additional-code-pages/cp907-cdra-p100-vpua-composite.map" =>
      "57f3c8b9b9a0cc40119e27315eb9748d75380d2690cd14b4816f0f9451299134",
    "ibm-additional-code-pages/ibm-tnz-cp310-07d60f4.py" =>
      "204acf3acc22396487b6cb450874af3f41e73f59fcbdcb16a86fa62c4f87ca42",
    "icu-78.3/ibm-850_P100-1995.ucm" =>
      "15bbc9b79c1082c6a5ded898de123c062bd67fccfc0ac62bac9d96f73bfa8435",
    "icu-data-archive/ibm-1254_P100-1995.ucm" =>
      "81fd4890f30a47f3f5cf46e447d49a6d53aa2f7f10dd3ee857a73ea707ba86d1",
    "icu-data-archive/ibm-293_P100-1995.ucm" =>
      "70ca25804681baa573f84ec694951e50c0598d815d7683762e3281047abe1c14",
    "icu-data-archive/ibm-437_P100-1995.ucm" =>
      "4875092cba330259cebbd4534634d83078cc1ea9470ad1c0eb17843fddea099b",
    "icu-data-archive/ibm-775_P100-1996.ucm" =>
      "6bc21a45b66dc1a28393d73370faa611c427f71b036e1a31bda9b6fc6a808ba2",
    "icu-data-archive/ibm-857_P100-1995.ucm" =>
      "83bac1ad2e228a243f8afc542695429dce608508def6a29a4915f6426c5406b9",
    "icu-data-archive/ibm-875_P100-1995.ucm" =>
      "c77699ab4daffc76b16f7201c2204b64703180073d0efcf2dab696fb8a3b4a3d"
  }

  @profile_specs %{
    ibm_310_293_p100_composite_vpua: %{
      map: "ibm-additional-code-pages/cp310-293-p100-composite-vpua.map",
      digest: "2165de9ceec4811cc4305d3c3b45d595ddaf450ab3d4dff3b25bf62b8058494e",
      sources:
        @join_sources ++
          [
            "ibm-additional-code-pages/CP00310.txt",
            "ibm-additional-code-pages/CP00310.pdf",
            "ibm-additional-code-pages/ibm-tnz-cp310-07d60f4.py",
            "ibm-additional-code-pages/cp310-293-p100-composite-vpua.map"
          ]
    },
    ibm_tnz_cp310_b1eae3c: %{
      map: "ibm-additional-code-pages/cp310-tnz-07d60f4.map",
      digest: "96cdf110667cdc28bb0f5e4b3a7185e3427d295f7f132f0a66e906f5bedbe932",
      sources: [
        "ibm-additional-code-pages/ibm-tnz-cp310-07d60f4.py",
        "ibm-additional-code-pages/cp310-tnz-07d60f4.map"
      ]
    },
    ibm_907_cdra_p100_vpua_composite: %{
      map: "ibm-additional-code-pages/cp907-cdra-p100-vpua-composite.map",
      digest: "57f3c8b9b9a0cc40119e27315eb9748d75380d2690cd14b4816f0f9451299134",
      sources:
        @join_sources ++
          [
            "ibm-additional-code-pages/CP00907.pdf",
            "ibm-additional-code-pages/cp907-cdra-p100-vpua-composite.map"
          ]
    },
    ibm_1116_850_p100_composite: %{
      map: "ibm-additional-code-pages/cp1116-850-p100-composite.map",
      digest: "0a802f4be6b771ad0b4c7d1f958da0f599025337b5592f917bc520081a0020cb",
      sources:
        @join_sources ++
          [
            "ibm-additional-code-pages/CP01116.pdf",
            "ibm-additional-code-pages/cp1116-850-p100-composite.map"
          ]
    },
    ibm_1117_437_p100_composite: %{
      map: "ibm-additional-code-pages/cp1117-437-p100-composite.map",
      digest: "9f00f6453bd43c81723b8f272999293d1fe2ddcf85ea8cce5b3f04e8d0ffd91e",
      sources:
        @join_sources ++
          [
            "ibm-additional-code-pages/CP01117.pdf",
            "ibm-additional-code-pages/cp1117-437-p100-composite.map"
          ]
    },
    dec_greek_8_1994: %{
      map: "ibm-additional-code-pages/cp1287-dec-1994.map",
      digest: "542afe11b341a24a9ac9547d2144e2aa88e0b2dc959bbf1c984b8ff6d6795525",
      sources: [
        "ibm-additional-code-pages/CP01287.txt",
        "ibm-additional-code-pages/CP01287.pdf",
        "ibm-additional-code-pages/DEC-PPL2-1994.pdf",
        "ibm-additional-code-pages/cp1287-dec-1994.map"
      ]
    },
    dec_turkish_8_1994: %{
      map: "ibm-additional-code-pages/cp1288-dec-1994.map",
      digest: "6cb89e4f2a571b9664a8c8cd66a12bf3ce221153f44adee2c8ec4fa396ba03ba",
      sources: [
        "ibm-additional-code-pages/CP01288.txt",
        "ibm-additional-code-pages/CP01288.pdf",
        "ibm-additional-code-pages/DEC-PPL2-1994.pdf",
        "ibm-additional-code-pages/cp1288-dec-1994.map"
      ]
    }
  }

  @external_resource @source_metadata_path

  for {_id, spec} <- @profile_specs do
    @external_resource Path.join(@sources_root, spec.map)
  end

  @profiles Map.new(@profile_specs, fn {id, spec} ->
              path = Path.join(@sources_root, spec.map)
              body = File.read!(path)
              digest = :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)

              if digest != spec.digest do
                raise "mapping digest mismatch for #{path}: expected #{spec.digest}, got #{digest}"
              end

              rows = String.split(body, "\n", trim: true)

              if length(rows) != 256 do
                raise "expected 256 mapping rows in #{path}, got #{length(rows)}"
              end

              table =
                rows
                |> Enum.with_index()
                |> Enum.map(fn {line, expected_byte} ->
                  [byte_hex, rhs] = String.split(line, "=", parts: 2)
                  byte = String.to_integer(byte_hex, 16)

                  if byte != expected_byte do
                    raise "out-of-order byte #{byte_hex} in #{path}; expected #{expected_byte}"
                  end

                  case rhs do
                    "UNDEFINED" ->
                      nil

                    _ ->
                      codepoints =
                        Regex.scan(~r/U\+([0-9A-F]{4,6})/, rhs, capture: :all_but_first)

                      normalized = Enum.map_join(codepoints, "+", fn [hex] -> "U+" <> hex end)

                      if codepoints == [] or normalized != rhs do
                        raise "invalid mapping #{inspect(rhs)} for byte #{byte_hex} in #{path}"
                      end

                      codepoints
                      |> Enum.map(fn [hex] -> String.to_integer(hex, 16) end)
                      |> List.to_tuple()
                  end
                end)

              max_codepoints =
                Enum.reduce(table, 0, fn
                  nil, maximum -> maximum
                  mapping, maximum -> max(tuple_size(mapping), maximum)
                end)

              if max_codepoints != 1 do
                raise "#{path} is not a source-exact single-code-point table"
              end

              scalar_table =
                Enum.map(table, fn
                  nil -> nil
                  {codepoint} -> codepoint
                end)

              encoder =
                scalar_table
                |> Enum.with_index()
                |> Enum.reduce(%{}, fn
                  {nil, _byte}, acc -> acc
                  {codepoint, byte}, acc -> Map.put(acc, codepoint, byte)
                end)

              utf8 =
                Enum.map(scalar_table, fn
                  nil -> nil
                  codepoint -> <<codepoint::utf8>>
                end)

              identity? = fn first, last ->
                Enum.all?(first..last, fn byte -> Enum.at(scalar_table, byte) == byte end)
              end

              identity_range =
                cond do
                  identity?.(0x00, 0x7F) -> {0x00, 0x7F}
                  identity?.(0x20, 0x7E) -> {0x20, 0x7E}
                  true -> nil
                end

              manifest =
                Map.new(spec.sources, fn relative_path ->
                  {relative_path, Map.fetch!(@source_digests, relative_path)}
                end)

              {id,
               %{
                 table: List.to_tuple(scalar_table),
                 utf8: List.to_tuple(utf8),
                 encoder: encoder,
                 identity_range: identity_range,
                 map_relative: spec.map,
                 digest: spec.digest,
                 manifest: manifest
               }}
            end)

  def source_map_path(profile) do
    Path.join([runtime_priv_dir(), "sources", profile!(profile).map_relative])
  end

  def mapping_sha256(profile), do: profile!(profile).digest

  def source_metadata_path do
    Path.join([runtime_priv_dir(), "sources", "ibm-additional-code-pages", "SOURCE_METADATA.md"])
  end

  def source_manifest(profile), do: profile!(profile).manifest

  defp runtime_priv_dir do
    :iconvex_specs
    |> :code.priv_dir()
    |> List.to_string()
  end

  def decode(input, profile) when is_binary(input) do
    %{table: table} = profile!(profile)
    decode_all(input, table, 0, [])
  end

  def decode_discard(input, profile) when is_binary(input) do
    %{table: table} = profile!(profile)
    decode_discard_all(input, table, [])
  end

  def encode(codepoints, profile) when is_list(codepoints) do
    %{encoder: encoder} = profile!(profile)
    encode_all(codepoints, encoder, [])
  end

  def encode_discard(codepoints, profile) when is_list(codepoints) do
    %{encoder: encoder} = profile!(profile)
    encode_discard_all(codepoints, encoder, [])
  end

  def encode_substitute(codepoints, profile, replacer)
      when is_list(codepoints) and is_function(replacer, 1) do
    %{encoder: encoder} = profile!(profile)
    encode_substitute_all(codepoints, encoder, replacer, [])
  end

  def decode_to_utf8(input, profile) when is_binary(input) do
    %{utf8: utf8, identity_range: identity_range} = profile!(profile)
    decode_utf8_all(input, utf8, identity_range, 0, [], 0, [])
  end

  def encode_from_utf8(input, profile) when is_binary(input) do
    %{encoder: encoder, identity_range: identity_range} = profile!(profile)
    encode_utf8_all(input, encoder, identity_range, 0, [], 0, [])
  end

  def decode_chunk(input, profile, _final?) do
    case decode(input, profile) do
      {:ok, codepoints} -> {:ok, codepoints, <<>>}
      error -> error
    end
  end

  def encode_chunk(codepoints, profile, _final?, policy) do
    result =
      case policy do
        :error -> encode(codepoints, profile)
        :discard -> encode_discard(codepoints, profile)
        {:replace, replacer} -> encode_substitute(codepoints, profile, replacer)
      end

    case result do
      {:ok, output} -> {:ok, output, []}
      error -> error
    end
  end

  defp decode_all(<<>>, _table, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_all(<<byte, rest::binary>>, table, offset, acc) do
    case elem(table, byte) do
      nil -> {:error, :invalid_sequence, offset, <<byte>>}
      codepoint -> decode_all(rest, table, offset + 1, [codepoint | acc])
    end
  end

  defp decode_discard_all(<<>>, _table, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_all(<<byte, rest::binary>>, table, acc) do
    case elem(table, byte) do
      nil -> decode_discard_all(rest, table, acc)
      codepoint -> decode_discard_all(rest, table, [codepoint | acc])
    end
  end

  defp encode_all([], _encoder, acc),
    do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_binary()}

  defp encode_all([codepoint | rest], encoder, acc) do
    case Map.fetch(encoder, codepoint) do
      {:ok, byte} -> encode_all(rest, encoder, [byte | acc])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_discard_all([], _encoder, acc),
    do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_binary()}

  defp encode_discard_all([codepoint | rest], encoder, acc) do
    case Map.fetch(encoder, codepoint) do
      {:ok, byte} -> encode_discard_all(rest, encoder, [byte | acc])
      :error -> encode_discard_all(rest, encoder, acc)
    end
  end

  defp encode_substitute_all([], _encoder, _replacer, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute_all([codepoint | rest], encoder, replacer, acc) do
    case Map.fetch(encoder, codepoint) do
      {:ok, byte} ->
        encode_substitute_all(rest, encoder, replacer, [byte | acc])

      :error ->
        case encode_all(replacer.(codepoint), encoder, []) do
          {:ok, replacement} ->
            encode_substitute_all(rest, encoder, replacer, [replacement | acc])

          error ->
            error
        end
    end
  end

  defp decode_utf8_all(<<>>, _table, _identity_range, _offset, acc, _count, chunks),
    do: {:ok, finish_iodata(acc, chunks)}

  defp decode_utf8_all(
         <<a, b, c, d, e, f, g, h, rest::binary>>,
         table,
         {minimum, maximum} = identity_range,
         offset,
         acc,
         count,
         chunks
       )
       when a >= minimum and a <= maximum and b >= minimum and b <= maximum and
              c >= minimum and c <= maximum and d >= minimum and d <= maximum and
              e >= minimum and e <= maximum and f >= minimum and f <= maximum and
              g >= minimum and g <= maximum and h >= minimum and h <= maximum do
    decode_utf8_piece(
      rest,
      table,
      identity_range,
      offset + 8,
      <<a, b, c, d, e, f, g, h>>,
      8,
      acc,
      count,
      chunks
    )
  end

  defp decode_utf8_all(
         <<byte, rest::binary>>,
         table,
         identity_range,
         offset,
         acc,
         count,
         chunks
       ) do
    case elem(table, byte) do
      nil ->
        {:error, :invalid_sequence, offset, <<byte>>}

      utf8 ->
        decode_utf8_piece(
          rest,
          table,
          identity_range,
          offset + 1,
          utf8,
          1,
          acc,
          count,
          chunks
        )
    end
  end

  defp decode_utf8_piece(
         rest,
         table,
         identity_range,
         offset,
         piece,
         units,
         acc,
         count,
         chunks
       ) do
    next_acc = [piece | acc]
    next_count = count + units

    if next_count >= @chunk_units do
      chunk = next_acc |> :lists.reverse() |> IO.iodata_to_binary()
      decode_utf8_all(rest, table, identity_range, offset, [], 0, [chunk | chunks])
    else
      decode_utf8_all(
        rest,
        table,
        identity_range,
        offset,
        next_acc,
        next_count,
        chunks
      )
    end
  end

  defp encode_utf8_all(<<>>, _encoder, _identity_range, _offset, acc, _count, chunks),
    do: {:ok, finish_iodata(acc, chunks)}

  defp encode_utf8_all(
         <<a, b, c, d, e, f, g, h, rest::binary>>,
         encoder,
         {minimum, maximum} = identity_range,
         offset,
         acc,
         count,
         chunks
       )
       when a >= minimum and a <= maximum and b >= minimum and b <= maximum and
              c >= minimum and c <= maximum and d >= minimum and d <= maximum and
              e >= minimum and e <= maximum and f >= minimum and f <= maximum and
              g >= minimum and g <= maximum and h >= minimum and h <= maximum do
    encode_utf8_piece(
      rest,
      encoder,
      identity_range,
      offset + 8,
      <<a, b, c, d, e, f, g, h>>,
      8,
      acc,
      count,
      chunks
    )
  end

  defp encode_utf8_all(
         <<codepoint, rest::binary>>,
         encoder,
         identity_range,
         offset,
         acc,
         count,
         chunks
       )
       when codepoint < 0x80 do
    encode_utf8_codepoint(
      rest,
      encoder,
      identity_range,
      offset,
      codepoint,
      1,
      acc,
      count,
      chunks
    )
  end

  defp encode_utf8_all(input, encoder, identity_range, offset, acc, count, chunks) do
    case input do
      <<codepoint::utf8, rest::binary>> ->
        width = byte_size(input) - byte_size(rest)

        encode_utf8_codepoint(
          rest,
          encoder,
          identity_range,
          offset,
          codepoint,
          width,
          acc,
          count,
          chunks
        )

      _ ->
        Iconvex.Specs.CodecSupport.malformed_utf8(input, offset)
    end
  end

  defp encode_utf8_codepoint(
         rest,
         encoder,
         identity_range,
         offset,
         codepoint,
         width,
         acc,
         count,
         chunks
       ) do
    case Map.fetch(encoder, codepoint) do
      {:ok, byte} ->
        encode_utf8_piece(
          rest,
          encoder,
          identity_range,
          offset + width,
          byte,
          1,
          acc,
          count,
          chunks
        )

      :error ->
        {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_utf8_piece(
         rest,
         encoder,
         identity_range,
         offset,
         piece,
         units,
         acc,
         count,
         chunks
       ) do
    next_acc = [piece | acc]
    next_count = count + units

    if next_count >= @chunk_units do
      chunk = next_acc |> :lists.reverse() |> IO.iodata_to_binary()
      encode_utf8_all(rest, encoder, identity_range, offset, [], 0, [chunk | chunks])
    else
      encode_utf8_all(
        rest,
        encoder,
        identity_range,
        offset,
        next_acc,
        next_count,
        chunks
      )
    end
  end

  defp profile!(profile), do: Map.fetch!(@profiles, profile)

  defp finish_iodata([], chunks),
    do: chunks |> :lists.reverse() |> IO.iodata_to_binary()

  defp finish_iodata(acc, chunks) do
    chunk = acc |> :lists.reverse() |> IO.iodata_to_binary()
    [chunk | chunks] |> :lists.reverse() |> IO.iodata_to_binary()
  end
end

defmodule Iconvex.Specs.IBMAdditionalCodePages.Profile do
  @moduledoc false

  defmacro __using__(options) do
    profile = Keyword.fetch!(options, :profile)
    canonical = Keyword.fetch!(options, :canonical)
    aliases = Keyword.fetch!(options, :aliases)
    codec_id = Keyword.fetch!(options, :codec_id)
    moduledoc = Keyword.fetch!(options, :moduledoc)

    quote bind_quoted: [
            profile: profile,
            canonical: canonical,
            aliases: aliases,
            codec_id: codec_id,
            moduledoc: moduledoc
          ] do
      @moduledoc moduledoc
      use Iconvex.Codec
      alias Iconvex.Specs.IBMAdditionalCodePages, as: Engine

      @profile profile
      @canonical canonical
      @aliases aliases
      @codec_id codec_id

      @impl true
      def canonical_name, do: @canonical

      @impl true
      def aliases, do: @aliases

      @impl true
      def codec_id, do: @codec_id

      def unit_bits, do: 8
      def source_map_path, do: Engine.source_map_path(@profile)
      def mapping_sha256, do: Engine.mapping_sha256(@profile)
      def source_metadata_path, do: Engine.source_metadata_path()
      def source_manifest, do: Engine.source_manifest(@profile)

      @impl true
      def decode(input), do: Engine.decode(input, @profile)

      @impl true
      def decode_discard(input), do: Engine.decode_discard(input, @profile)

      @impl true
      def encode(codepoints), do: Engine.encode(codepoints, @profile)

      @impl true
      def encode_discard(codepoints), do: Engine.encode_discard(codepoints, @profile)

      @impl true
      def encode_substitute(codepoints, replacer),
        do: Engine.encode_substitute(codepoints, @profile, replacer)

      @impl true
      def decode_to_utf8(input), do: Engine.decode_to_utf8(input, @profile)

      @impl true
      def encode_from_utf8(input), do: Engine.encode_from_utf8(input, @profile)

      @impl true
      def decode_chunk(input, final?), do: Engine.decode_chunk(input, @profile, final?)

      @impl true
      def encode_chunk(codepoints, final?, policy),
        do: Engine.encode_chunk(codepoints, @profile, final?, policy)
    end
  end
end

defmodule Iconvex.Specs.IBM310293P100CompositeVPUA do
  use Iconvex.Specs.IBMAdditionalCodePages.Profile,
    profile: :ibm_310_293_p100_composite_vpua,
    canonical: "IBM-310-293-P100-COMPOSITE-VPUA",
    aliases: [
      "IBM310-293-P100-COMPOSITE-VPUA",
      "CP310-293-P100-COMPOSITE-VPUA",
      "IBM-310-293-P100-VPUA"
    ],
    codec_id: :ibm_310_293_p100_composite_vpua,
    moduledoc: "Explicit IBM CP310 GCGID interoperability join with IBM-293 P100 VPUA priority."
end

defmodule Iconvex.Specs.IBMTNZCP310B1EAE3C do
  use Iconvex.Specs.IBMAdditionalCodePages.Profile,
    profile: :ibm_tnz_cp310_b1eae3c,
    canonical: "IBM-TNZ-CP310-B1EAE3C",
    aliases: [
      "IBM-TNZ-CP310-07D60F4",
      "TNZ-CP310-B1EAE3C",
      "TNZ-CP310-07D60F4",
      "CP310-TNZ-07D60F4"
    ],
    codec_id: :ibm_tnz_cp310_b1eae3c,
    moduledoc: "Byte-exact CP310 mapping from IBM/tnz commit b1eae3c and blob 07d60f4."
end

defmodule Iconvex.Specs.IBM907CDRAP100VPUAComposite do
  use Iconvex.Specs.IBMAdditionalCodePages.Profile,
    profile: :ibm_907_cdra_p100_vpua_composite,
    canonical: "IBM-907-CDRA-P100-VPUA-COMPOSITE",
    aliases: [
      "IBM907-CDRA-P100-VPUA-COMPOSITE",
      "CP907-CDRA-P100-VPUA-COMPOSITE",
      "IBM-907-P100-VPUA-COMPOSITE"
    ],
    codec_id: :ibm_907_cdra_p100_vpua_composite,
    moduledoc: "Explicit IBM CP907 CDRA GCGID/P100 VPUA interoperability profile."
end

defmodule Iconvex.Specs.IBM1116850P100Composite do
  use Iconvex.Specs.IBMAdditionalCodePages.Profile,
    profile: :ibm_1116_850_p100_composite,
    canonical: "IBM-1116-850-P100-COMPOSITE",
    aliases: [
      "IBM1116-850-P100-COMPOSITE",
      "CP1116-850-P100-COMPOSITE",
      "IBM-1116-P100-COMPOSITE"
    ],
    codec_id: :ibm_1116_850_p100_composite,
    moduledoc: "Explicit IBM CP1116 GCGID interoperability profile using IBM-850 P100."
end

defmodule Iconvex.Specs.IBM1117437P100Composite do
  use Iconvex.Specs.IBMAdditionalCodePages.Profile,
    profile: :ibm_1117_437_p100_composite,
    canonical: "IBM-1117-437-P100-COMPOSITE",
    aliases: [
      "IBM1117-437-P100-COMPOSITE",
      "CP1117-437-P100-COMPOSITE",
      "IBM-1117-P100-COMPOSITE"
    ],
    codec_id: :ibm_1117_437_p100_composite,
    moduledoc: "Explicit IBM CP1117 GCGID interoperability profile using IBM-437 P100."
end

defmodule Iconvex.Specs.DECGreek81994 do
  use Iconvex.Specs.IBMAdditionalCodePages.Profile,
    profile: :dec_greek_8_1994,
    canonical: "DEC-GREEK-8-1994",
    aliases: [
      "DEC-GREEK-8",
      "DEC-GREEK-8-BIT",
      "DEC-GREEK",
      "EL8DEC",
      "IBM-1287",
      "IBM1287",
      "CP1287",
      "CCSID1287"
    ],
    codec_id: :dec_greek_8_1994,
    moduledoc: "DEC Greek 8-bit character set from the revised August 1994 DEC manual."
end

defmodule Iconvex.Specs.DECTurkish81994 do
  use Iconvex.Specs.IBMAdditionalCodePages.Profile,
    profile: :dec_turkish_8_1994,
    canonical: "DEC-TURKISH-8-1994",
    aliases: [
      "DEC-TURKISH-8",
      "DEC-TURKISH-8-BIT",
      "DEC-TURKISH",
      "TR8DEC",
      "IBM-1288",
      "IBM1288",
      "CP1288",
      "CCSID1288"
    ],
    codec_id: :dec_turkish_8_1994,
    moduledoc: "DEC Turkish 8-bit character set from the revised August 1994 DEC manual."
end

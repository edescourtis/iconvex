defmodule Iconvex.Specs.GlyphVectorUnicode.SourceAsset do
  @moduledoc false

  def load!(
        mapping_path,
        expected_sha256,
        expected_count,
        metadata_path,
        metadata_pins,
        source_pins
      ) do
    mapping = File.read!(mapping_path)
    verify_sha!("mapping", mapping, expected_sha256)

    Enum.each(source_pins, fn {label, path, expected} ->
      verify_sha!(label, File.read!(path), expected)
    end)

    pairs =
      case String.split(mapping, "\n", trim: true) do
        ["byte,unicode" | rows] -> Enum.map(rows, &parse_row!/1)
        _ -> raise ArgumentError, "invalid glyph-vector mapping header"
      end

    bytes = Enum.map(pairs, &elem(&1, 0))

    unless length(pairs) == expected_count and bytes == Enum.sort(bytes) and
             length(bytes) == length(Enum.uniq(bytes)) do
      raise ArgumentError, "glyph-vector mapping count/order is not exact"
    end

    metadata = File.read!(metadata_path)

    unless Enum.all?(metadata_pins, &String.contains?(metadata, &1)) do
      raise ArgumentError, "glyph-vector metadata omits a required provenance pin"
    end

    decode_map = Map.new(pairs)
    decode = List.to_tuple(for byte <- 0..255, do: Map.get(decode_map, byte))

    decode_utf8 =
      List.to_tuple(
        for byte <- 0..255 do
          case Map.get(decode_map, byte) do
            nil -> nil
            codepoint -> <<codepoint::utf8>>
          end
        end
      )

    encode =
      Enum.reduce(pairs, %{}, fn {byte, codepoint}, acc ->
        Map.update(acc, codepoint, byte, &min(&1, byte))
      end)

    %{decode: decode, decode_utf8: decode_utf8, encode: encode}
  end

  defp parse_row!(row) do
    with [byte_hex, codepoint_hex] <- String.split(row, ",", parts: 2),
         {byte, ""} <- Integer.parse(byte_hex, 16),
         {codepoint, ""} <- Integer.parse(codepoint_hex, 16),
         true <- byte in 0..255,
         true <- scalar?(codepoint) do
      {byte, codepoint}
    else
      _ -> raise ArgumentError, "invalid glyph-vector mapping row #{inspect(row)}"
    end
  end

  defp verify_sha!(label, bytes, expected) do
    actual = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
    unless actual == expected, do: raise(ArgumentError, "#{label} SHA-256 mismatch")
  end

  defp scalar?(codepoint),
    do: codepoint in 0..0xD7FF or codepoint in 0xE000..0x10FFFF
end

defmodule Iconvex.Specs.GlyphVectorUnicode.Profile do
  @moduledoc false

  defmacro __using__(options) do
    canonical = Keyword.fetch!(options, :canonical)
    aliases = Keyword.fetch!(options, :aliases)
    codec_id = Keyword.fetch!(options, :codec_id)
    mapping_file = Keyword.fetch!(options, :mapping_file)
    mapping_sha256 = Keyword.fetch!(options, :mapping_sha256)
    mapped_count = Keyword.fetch!(options, :mapped_count)
    vector_file = Keyword.fetch!(options, :vector_file)
    vector_sha256 = Keyword.fetch!(options, :vector_sha256)
    source_dir = Path.expand("../../../priv/sources/glyph-vector-unicode", __DIR__)
    mapping_path = Path.join(source_dir, mapping_file)
    vector_path = Path.join(source_dir, vector_file)
    agl_path = Path.join(source_dir, "glyphlist-4036a9ca.txt")
    agl_license_path = Path.join(source_dir, "AGL_LICENSE.md")
    metadata_path = Path.join(source_dir, "SOURCE_METADATA.md")

    data =
      Iconvex.Specs.GlyphVectorUnicode.SourceAsset.load!(
        mapping_path,
        mapping_sha256,
        mapped_count,
        metadata_path,
        [
          canonical,
          mapping_sha256,
          vector_sha256,
          "4036a9ca80a62f64f9de4f7321a9a045ad0ecfd6",
          "a3b2f61ced9f3644cc0d4ecde5c59df34ca286c689d9484a43a710a81c466789"
        ],
        [
          {"encoding vector", vector_path, vector_sha256},
          {"Adobe Glyph List", agl_path,
           "a3b2f61ced9f3644cc0d4ecde5c59df34ca286c689d9484a43a710a81c466789"},
          {"Adobe Glyph List license", agl_license_path,
           "58147d341e7a34aa2196862395a34d2fd95716c41d5ed26efb59ab0e12f92089"}
        ]
      )

    quote bind_quoted: [
            canonical: canonical,
            aliases: aliases,
            codec_id: codec_id,
            mapping_path: mapping_path,
            vector_path: vector_path,
            agl_path: agl_path,
            agl_license_path: agl_license_path,
            metadata_path: metadata_path,
            mapping_sha256: mapping_sha256,
            vector_sha256: vector_sha256,
            mapped_count: mapped_count,
            data: Macro.escape(data)
          ] do
      use Iconvex.Codec

      alias Iconvex.Specs.SourceQualifiedSingleByte.Engine

      @external_resource mapping_path
      @external_resource vector_path
      @external_resource agl_path
      @external_resource agl_license_path
      @external_resource metadata_path
      @decode data.decode
      @decode_utf8 data.decode_utf8
      @encode data.encode
      @canonical canonical
      @aliases aliases
      @codec_id codec_id
      @mapping_sha256 mapping_sha256
      @vector_sha256 vector_sha256
      @mapped_count mapped_count

      @impl true
      def canonical_name, do: @canonical

      @impl true
      def aliases, do: @aliases

      @impl true
      def codec_id, do: @codec_id

      def unit_bits, do: 8
      def mapped_count, do: @mapped_count
      def invalid_count, do: 256 - @mapped_count
      def inverse_policy, do: :lowest_byte
      def mapping_sha256, do: @mapping_sha256
      def vector_sha256, do: @vector_sha256
      def agl_commit, do: "4036a9ca80a62f64f9de4f7321a9a045ad0ecfd6"
      def agl_sha256, do: "a3b2f61ced9f3644cc0d4ecde5c59df34ca286c689d9484a43a710a81c466789"

      @impl true
      def decode(input), do: Engine.decode(input, @decode)

      @impl true
      def decode_discard(input), do: Engine.decode_discard(input, @decode)

      @impl true
      def decode_to_utf8(input), do: Engine.decode_to_utf8(input, @decode_utf8)

      @impl true
      def decode_chunk(input, _final?), do: Engine.decode_chunk(input, @decode)

      @impl true
      def encode(codepoints), do: Engine.encode(codepoints, @encode)

      @impl true
      def encode_discard(codepoints), do: Engine.encode_discard(codepoints, @encode)

      @impl true
      def encode_substitute(codepoints, replacer),
        do: Engine.encode_substitute(codepoints, @encode, replacer)

      @impl true
      def encode_from_utf8(input), do: Engine.encode_from_utf8(input, @encode)

      @impl true
      def encode_chunk(codepoints, _final?, policy),
        do: Engine.encode_chunk(codepoints, @encode, policy)
    end
  end
end

defmodule Iconvex.Specs.LY1TexnANSI11AGL4036A9CA do
  @moduledoc "Source-qualified CTAN LY1/TeX'n'ANSI 1.1 vector through pinned Adobe AGL."

  use Iconvex.Specs.GlyphVectorUnicode.Profile,
    canonical: "CTAN-LY1-TEXNANSI-1.1-AGL-4036A9CA",
    aliases: ["CTAN-TEXNANSI-1.1-AGL-4036A9CA"],
    codec_id: :ctan_ly1_texnansi_1_1_agl_4036a9ca,
    mapping_file: "ly1_agl_4036a9ca.csv",
    mapping_sha256: "df9bb4301cb8280827f55c99224c03f8775e5767d6ded5741d4da68cdaa01d21",
    mapped_count: 250,
    vector_file: "texnansi-1.1.enc",
    vector_sha256: "cd006b13b530d7bfd386396c7f1138488d2b336f40508552b41952a83cdb0601"
end

defmodule Iconvex.Specs.PostScript3ISOLatin1AGL4036A9CA do
  @moduledoc "Source-qualified PostScript LanguageLevel 3 ISOLatin1Encoding through pinned AGL."

  use Iconvex.Specs.GlyphVectorUnicode.Profile,
    canonical: "ADOBE-POSTSCRIPT-3-ISOLATIN1-AGL-4036A9CA",
    aliases: ["ADOBE-POSTSCRIPT-3-ISOLATIN1ENCODING-AGL-4036A9CA"],
    codec_id: :adobe_postscript_3_isolatin1_agl_4036a9ca,
    mapping_file: "postscript3_isolatin1_agl_4036a9ca.csv",
    mapping_sha256: "926b7598f3738ab3db3e2315daeace041aec7570270702fb1b19eccb7418e624",
    mapped_count: 205,
    vector_file: "postscript3_isolatin1_vector.csv",
    vector_sha256: "2d48471248773a8faa94fb773707b05ac8b757cca1b53f3a267792e0f3697315"
end

defmodule Iconvex.Specs.GlyphVectorUnicode.Codecs do
  @moduledoc "Exact source-qualified glyph-vector Unicode codecs."

  def modules do
    [
      Iconvex.Specs.LY1TexnANSI11AGL4036A9CA,
      Iconvex.Specs.PostScript3ISOLatin1AGL4036A9CA
    ]
  end
end

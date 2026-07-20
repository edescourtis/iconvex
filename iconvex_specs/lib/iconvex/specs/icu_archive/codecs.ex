defmodule Iconvex.Specs.ICUArchive.Codecs do
  @moduledoc false
  @path Path.expand("../../../../priv/icu_archive_manifest.etf", __DIR__)
  @external_resource @path
  @manifest @path |> File.read!() |> :erlang.binary_to_term()
  @modules Enum.map(@manifest.encodings, &Module.concat(__MODULE__, "C#{&1.index}"))
  def modules, do: @modules
end

path = Path.expand("../../../../priv/icu_archive_manifest.etf", __DIR__)

for entry <- path |> File.read!() |> :erlang.binary_to_term() |> Map.fetch!(:encodings) do
  module = Module.concat(Iconvex.Specs.ICUArchive.Codecs, "C#{entry.index}")

  if entry.stateful do
    defmodule module do
      use Iconvex.Codec
      @entry entry
      def canonical_name, do: @entry.name
      def aliases, do: []
      def stateful?, do: true
      def codec_id, do: @entry.id
      def decode(input), do: Iconvex.Specs.ICUEBCDICStateful.Engine.decode(@entry.id, input)

      def decode_discard(input),
        do: Iconvex.Specs.ICUEBCDICStateful.Engine.decode_discard(@entry.id, input)

      def decode_to_utf8(input),
        do: Iconvex.Specs.ICUEBCDICStateful.Engine.decode_to_utf8(@entry.id, input)

      def encode(codepoints),
        do: Iconvex.Specs.ICUEBCDICStateful.Engine.encode(@entry.id, codepoints)

      def encode_discard(codepoints),
        do: Iconvex.Specs.ICUEBCDICStateful.Engine.encode_discard(@entry.id, codepoints)

      def encode_substitute(codepoints, replacer),
        do:
          Iconvex.Specs.ICUEBCDICStateful.Engine.encode_substitute(
            @entry.id,
            codepoints,
            replacer
          )

      def encode_from_utf8(input),
        do: Iconvex.Specs.ICUEBCDICStateful.Engine.encode_from_utf8(@entry.id, input)
    end
  else
    defmodule module do
      use Iconvex.Codec
      @entry entry
      def canonical_name, do: @entry.name
      def aliases, do: []
      def codec_id, do: @entry.id
      def decode(input), do: Iconvex.Specs.CodecSupport.decode_provider(@entry.id, input)

      def decode_discard(input),
        do: Iconvex.Specs.CodecSupport.decode_discard_provider(@entry.id, input)

      def decode_error_consumption(kind, sequence),
        do: Iconvex.Specs.CodecSupport.decode_error_consumption(kind, sequence)

      def decode_to_utf8(input),
        do: Iconvex.Specs.CodecSupport.decode_to_utf8_provider(@entry.id, input)

      def encode(codepoints),
        do: Iconvex.Specs.CodecSupport.encode_provider(@entry.id, codepoints)

      def encode_discard(codepoints),
        do: Iconvex.Specs.CodecSupport.encode_discard_provider(@entry.id, codepoints)

      def encode_substitute(codepoints, replacer),
        do:
          Iconvex.Specs.CodecSupport.encode_substitute_provider(
            @entry.id,
            codepoints,
            replacer
          )

      def encode_from_utf8(input),
        do: Iconvex.Specs.CodecSupport.encode_from_utf8_provider(@entry.id, input)
    end
  end
end

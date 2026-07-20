defmodule Iconvex.Specs.KPS956697.Codecs do
  @moduledoc false
  @path Path.expand("../../../../priv/kps9566_97_manifest.etf", __DIR__)
  @external_resource @path
  @manifest @path |> File.read!() |> :erlang.binary_to_term()
  @modules Enum.map(@manifest.encodings, &Module.concat(__MODULE__, "C#{&1.index}"))
  def modules, do: @modules
end

path = Path.expand("../../../../priv/kps9566_97_manifest.etf", __DIR__)

for entry <- path |> File.read!() |> :erlang.binary_to_term() |> Map.fetch!(:encodings) do
  module = Module.concat(Iconvex.Specs.KPS956697.Codecs, "C#{entry.index}")

  defmodule module do
    use Iconvex.Codec
    @entry entry
    def canonical_name, do: @entry.name
    def aliases, do: @entry.aliases
    def codec_id, do: @entry.id
    def decode(input), do: Iconvex.Specs.CodecSupport.decode(@entry.id, input)
    def decode_discard(input), do: Iconvex.Specs.CodecSupport.decode_discard(@entry.id, input)
    def decode_to_utf8(input), do: Iconvex.Specs.CodecSupport.decode_to_utf8(@entry.id, input)
    def encode(codepoints), do: Iconvex.Specs.CodecSupport.encode(@entry.id, codepoints)

    def encode_discard(codepoints),
      do: Iconvex.Specs.CodecSupport.encode_discard(@entry.id, codepoints)

    def encode_substitute(codepoints, replacer),
      do: Iconvex.Specs.CodecSupport.encode_substitute(@entry.id, codepoints, replacer)

    def encode_from_utf8(input), do: Iconvex.Specs.CodecSupport.encode_from_utf8(@entry.id, input)
  end
end

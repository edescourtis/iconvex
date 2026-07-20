defmodule Iconvex.Specs.LegacyComputingN5028.Codecs do
  @moduledoc false
  @path Path.expand("../../../../priv/legacy_computing_n5028_manifest.etf", __DIR__)
  @external_resource @path
  @manifest @path |> File.read!() |> :erlang.binary_to_term()
  @modules Enum.map(@manifest.encodings, &Module.concat(__MODULE__, "C#{&1.index}"))
  def modules, do: @modules
end

path = Path.expand("../../../../priv/legacy_computing_n5028_manifest.etf", __DIR__)

for entry <- path |> File.read!() |> :erlang.binary_to_term() |> Map.fetch!(:encodings) do
  module = Module.concat(Iconvex.Specs.LegacyComputingN5028.Codecs, "C#{entry.index}")

  defmodule module do
    use Iconvex.Codec
    alias Iconvex.Specs.CodecSupport
    @entry entry

    @impl true
    def canonical_name, do: @entry.name

    @impl true
    def aliases, do: @entry.aliases

    @impl true
    def codec_id, do: @entry.id

    @impl true
    def decode(input), do: CodecSupport.decode(@entry.id, input)

    @impl true
    def decode_discard(input), do: CodecSupport.decode_discard(@entry.id, input)

    @impl true
    def decode_chunk(input, final?), do: CodecSupport.decode_chunk(@entry.id, input, final?)

    @impl true
    def decode_error_consumption(kind, sequence),
      do: CodecSupport.decode_error_consumption(kind, sequence)

    @impl true
    def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(@entry.id, input)

    @impl true
    def encode(codepoints), do: CodecSupport.encode(@entry.id, codepoints)

    @impl true
    def encode_discard(codepoints), do: CodecSupport.encode_discard(@entry.id, codepoints)

    @impl true
    def encode_substitute(codepoints, replacer),
      do: CodecSupport.encode_substitute(@entry.id, codepoints, replacer)

    @impl true
    def encode_chunk(codepoints, final?, policy),
      do: CodecSupport.encode_chunk(@entry.id, codepoints, final?, policy)

    @impl true
    def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(@entry.id, input)
  end
end

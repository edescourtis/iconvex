defmodule Iconvex.Specs.RFC1345.Codecs do
  @moduledoc false

  @manifest_path Path.expand("../../../../priv/rfc1345_manifest.etf", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()

  @modules Enum.map(@manifest.encodings, fn entry ->
             Module.concat(
               __MODULE__,
               "C#{String.pad_leading(Integer.to_string(entry.index), 3, "0")}"
             )
           end)

  def modules, do: @modules
end

manifest_path = Path.expand("../../../../priv/rfc1345_manifest.etf", __DIR__)
manifest = manifest_path |> File.read!() |> :erlang.binary_to_term()

for entry <- manifest.encodings do
  module =
    Module.concat(
      Iconvex.Specs.RFC1345.Codecs,
      "C#{String.pad_leading(Integer.to_string(entry.index), 3, "0")}"
    )

  defmodule module do
    use Iconvex.Codec
    alias Iconvex.Specs.CodecSupport

    @id entry.id
    @canonical entry.name

    @impl true
    def canonical_name, do: @canonical

    # Aliases are filtered dynamically by the application so this package can
    # coexist with core, extras, and other external codec packages.
    @impl true
    def aliases, do: []

    @impl true
    def codec_id, do: @id

    @impl true
    def decode(input), do: CodecSupport.decode(@id, input)

    @impl true
    def decode_discard(input), do: CodecSupport.decode_discard(@id, input)

    @impl true
    def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(@id, input)

    @impl true
    def encode(codepoints), do: CodecSupport.encode(@id, codepoints)

    @impl true
    def encode_discard(codepoints), do: CodecSupport.encode_discard(@id, codepoints)

    @impl true
    def encode_substitute(codepoints, replacer),
      do: CodecSupport.encode_substitute(@id, codepoints, replacer)

    @impl true
    def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(@id, input)
  end
end

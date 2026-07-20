defmodule Iconvex.Specs.ISOIR169 do
  @moduledoc "ISO-IR-169, the registered two-byte Blissymbolics graphic set."

  use Iconvex.Codec

  @manifest_path Path.expand("../../../priv/iso_ir_169_manifest.etf", __DIR__)
  @source_directory Path.expand("../../../priv/sources/iso-ir-169", __DIR__)
  @external_resource @manifest_path
  @external_resource Path.join(@source_directory, "169.pdf")
  @external_resource Path.join(@source_directory, "mappings.txt")
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()

  @impl true
  def canonical_name, do: @manifest.name

  @impl true
  def aliases, do: @manifest.aliases

  @impl true
  def codec_id, do: @manifest.id

  @impl true
  def decode(input), do: Iconvex.Specs.CodecSupport.decode(@manifest.id, input)

  @impl true
  def decode_discard(input), do: Iconvex.Specs.CodecSupport.decode_discard(@manifest.id, input)

  @impl true
  def decode_to_utf8(input), do: Iconvex.Specs.CodecSupport.decode_to_utf8(@manifest.id, input)

  @impl true
  def encode(codepoints), do: Iconvex.Specs.CodecSupport.encode(@manifest.id, codepoints)

  @impl true
  def encode_discard(codepoints),
    do: Iconvex.Specs.CodecSupport.encode_discard(@manifest.id, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: Iconvex.Specs.CodecSupport.encode_substitute(@manifest.id, codepoints, replacer)

  @impl true
  def encode_from_utf8(input),
    do: Iconvex.Specs.CodecSupport.encode_from_utf8(@manifest.id, input)

  def entry, do: @manifest
  def manifest, do: @manifest
end

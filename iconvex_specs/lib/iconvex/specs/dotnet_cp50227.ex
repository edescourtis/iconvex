defmodule Iconvex.Specs.DotnetCP50227 do
  @moduledoc "The .NET runtime's `x-cp50227` compatibility codec, delegated exactly to CP936."

  use Iconvex.Codec

  @entry %{id: :cp936, table_app: :iconvex}

  @impl true
  def canonical_name, do: "x-cp50227"

  @impl true
  def aliases, do: ["CP50227", "windows-50227"]

  @impl true
  def codec_id, do: :dotnet_cp50227

  @impl true
  def decode(input), do: Iconvex.TableCodec.decode(@entry, input)

  @impl true
  def decode_discard(input), do: Iconvex.TableCodec.decode_discard(@entry, input)

  @impl true
  def decode_to_utf8(input), do: Iconvex.TableCodec.decode_to_utf8(@entry, input)

  @impl true
  def encode(codepoints), do: Iconvex.TableCodec.encode(@entry, codepoints)

  @impl true
  def encode_discard(codepoints), do: Iconvex.TableCodec.encode_discard(@entry, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: Iconvex.TableCodec.encode_substitute(@entry, codepoints, replacer)

  @impl true
  def encode_from_utf8(input), do: Iconvex.TableCodec.encode_from_utf8(@entry, input)

  def source_url,
    do:
      "https://github.com/dotnet/runtime/blob/dbb2178288bb4e1e8f1fde3958be3bd75573c459/src/libraries/System.Text.Encoding.CodePages/src/System/Text/CodePagesEncodingProvider.cs"
end

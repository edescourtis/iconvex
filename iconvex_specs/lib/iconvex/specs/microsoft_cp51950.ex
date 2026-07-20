defmodule Iconvex.Specs.MicrosoftCP51950 do
  @moduledoc "Microsoft CP51950, the Windows identifier for EUC-TW."

  use Iconvex.Codec

  @entry %{id: :euc_tw, table_app: :iconvex}

  @impl true
  def canonical_name, do: "CP51950"

  @impl true
  def aliases, do: ["windows-51950"]

  @impl true
  def codec_id, do: :microsoft_cp51950

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
    do: "https://learn.microsoft.com/en-us/windows/win32/intl/code-page-identifiers"
end

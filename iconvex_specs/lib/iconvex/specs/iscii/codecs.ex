defmodule Iconvex.Specs.ISCII.Codecs do
  @moduledoc false

  alias Iconvex.Specs.ISCII.Data

  @entries Data.fetch().encodings
  @modules Enum.map(@entries, fn entry ->
             suffix = entry.name |> String.replace(~r/[^A-Za-z0-9]/, "_")
             Module.concat(__MODULE__, suffix)
           end)

  def modules, do: @modules
end

for entry <- Iconvex.Specs.ISCII.Data.fetch().encodings do
  suffix = entry.name |> String.replace(~r/[^A-Za-z0-9]/, "_")
  module = Module.concat(Iconvex.Specs.ISCII.Codecs, suffix)

  defmodule module do
    use Iconvex.Codec

    @entry entry

    @impl true
    def canonical_name, do: @entry.name

    @impl true
    def aliases, do: @entry.aliases

    @impl true
    def codec_id, do: String.to_atom("iscii_#{@entry.version}_#{String.downcase(@entry.name)}")

    @impl true
    def stateful?, do: true

    @impl true
    def decode(input), do: Iconvex.Specs.ISCII.decode(@entry.name, input)

    @impl true
    def decode_discard(input), do: Iconvex.Specs.ISCII.decode_discard(@entry.name, input)

    @impl true
    def encode(codepoints), do: Iconvex.Specs.ISCII.encode(@entry.name, codepoints)

    @impl true
    def encode_discard(codepoints),
      do: Iconvex.Specs.ISCII.encode_discard(@entry.name, codepoints)

    @impl true
    def encode_substitute(codepoints, replacer),
      do: Iconvex.Specs.ISCII.encode_substitute(@entry.name, codepoints, replacer)

    @impl true
    def decode_to_utf8(input) do
      with {:ok, codepoints} <- decode(input), do: {:ok, List.to_string(codepoints)}
    end

    @impl true
    def encode_from_utf8(input),
      do: Iconvex.Specs.CodecSupport.encode_utf8(input, &encode/1)
  end
end

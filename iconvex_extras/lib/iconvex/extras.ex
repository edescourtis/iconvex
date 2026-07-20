defmodule Iconvex.Extras do
  @moduledoc "Optional GNU libiconv extra and platform codecs for Iconvex."

  def codecs, do: Iconvex.Extras.Codecs.modules()
  def encodings, do: Enum.map(codecs(), & &1.canonical_name()) |> Enum.sort()
end

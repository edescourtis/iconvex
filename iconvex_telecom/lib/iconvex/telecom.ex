defmodule Iconvex.Telecom do
  @moduledoc "Pure Elixir telecom codecs supplied as external codecs for Iconvex."

  def codecs, do: Iconvex.Telecom.Codecs.modules()
  def encodings, do: codecs() |> Enum.map(& &1.canonical_name()) |> Enum.sort()
  def packed_codecs, do: Iconvex.Telecom.Packed.profiles()
end

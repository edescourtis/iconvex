defmodule Iconvex.Telecom.ITA4.Packing do
  @moduledoc "Packs and unpacks consecutive ITA4 six-unit signals."

  @doc "Packs one-signal-per-octet input into consecutive six-bit units."
  def pack(signals), do: Iconvex.Telecom.AIS6.Packing.pack(signals)

  @doc "Unpacks a bitstring whose size is an exact multiple of six."
  def unpack(packed), do: Iconvex.Telecom.AIS6.Packing.unpack(packed)
end

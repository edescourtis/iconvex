defmodule Iconvex.Telecom.ITA3.Packing do
  @moduledoc "Packs and unpacks consecutive ITA3 seven-unit signals."

  @doc "Packs one-signal-per-octet input into consecutive seven-bit units."
  def pack(signals), do: Iconvex.Telecom.CCIR476.Packing.pack(signals)

  @doc "Unpacks a bitstring whose size is an exact multiple of seven."
  def unpack(packed), do: Iconvex.Telecom.CCIR476.Packing.unpack(packed)
end

defmodule Iconvex.Specs.IBM1175 do
  @moduledoc """
  IBM CCSID 1175, the EBCDIC Turkish euro-and-lira revision.

  The byte table is the pinned IBM-authored ICU mapping whose historical source
  name remains `ibm-1155_P100-1999`, but whose current round-trip mapping carries
  the CCSID 1175 lira update at byte `9A`. All 256 mappings are independently
  proven equal to IBM CDRA's 2013 `0497B4B0.TXMAP` table.
  """

  use Iconvex.Codec

  @table_id :icu_archive_374

  @impl true
  def canonical_name, do: "IBM-1175"

  @impl true
  def aliases, do: ["IBM1175", "CP1175", "CCSID1175"]

  @impl true
  def codec_id, do: @table_id

  @impl true
  def decode(input), do: Iconvex.Specs.CodecSupport.decode_provider(@table_id, input)

  @impl true
  def decode_discard(input),
    do: Iconvex.Specs.CodecSupport.decode_discard_provider(@table_id, input)

  @impl true
  def decode_to_utf8(input),
    do: Iconvex.Specs.CodecSupport.decode_to_utf8_provider(@table_id, input)

  @impl true
  def encode(codepoints), do: Iconvex.Specs.CodecSupport.encode_provider(@table_id, codepoints)

  @impl true
  def encode_discard(codepoints),
    do: Iconvex.Specs.CodecSupport.encode_discard_provider(@table_id, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: Iconvex.Specs.CodecSupport.encode_substitute_provider(@table_id, codepoints, replacer)

  @impl true
  def encode_from_utf8(input),
    do: Iconvex.Specs.CodecSupport.encode_from_utf8_provider(@table_id, input)
end

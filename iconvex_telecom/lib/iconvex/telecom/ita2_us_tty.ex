defmodule Iconvex.Telecom.ITA2USTTY do
  @moduledoc """
  American Teletypewriter (US TTY) national variant of ITA2.

  It retains ITA2's five-bit letters/figures machinery while assigning the
  United States figures positions for BELL, dollar, apostrophe, exclamation,
  quotation mark, number sign, and ampersand. One five-bit unit is stored per
  octet with the upper three bits zero; `Iconvex.Telecom.ITA2.Packing` is
  compatible with its consecutive-bit form.
  """

  use Iconvex.Telecom.SubstitutionCodec

  alias Iconvex.Telecom.FiveUnitShift

  @letters %{
    0 => 0x0000,
    1 => ?E,
    2 => ?\n,
    3 => ?A,
    4 => ?\s,
    5 => ?S,
    6 => ?I,
    7 => ?U,
    8 => ?\r,
    9 => ?D,
    10 => ?R,
    11 => ?J,
    12 => ?N,
    13 => ?F,
    14 => ?C,
    15 => ?K,
    16 => ?T,
    17 => ?Z,
    18 => ?L,
    19 => ?W,
    20 => ?H,
    21 => ?Y,
    22 => ?P,
    23 => ?Q,
    24 => ?O,
    25 => ?B,
    26 => ?G,
    28 => ?M,
    29 => ?X,
    30 => ?V
  }

  @figures %{
    0 => 0x0000,
    1 => ?3,
    2 => ?\n,
    3 => ?-,
    4 => ?\s,
    5 => 0x0007,
    6 => ?8,
    7 => ?7,
    8 => ?\r,
    9 => ?$,
    10 => ?4,
    11 => ?',
    12 => ?,,
    13 => ?!,
    14 => ?:,
    15 => ?(,
    16 => ?5,
    17 => ?\",
    18 => ?),
    19 => ?2,
    20 => ?#,
    21 => ?6,
    22 => ?0,
    23 => ?1,
    24 => ?9,
    25 => ??,
    26 => ?&,
    28 => ?.,
    29 => ?/,
    30 => ?;
  }

  @decode %{
    letters: 0..31 |> Enum.map(&Map.get(@letters, &1)) |> List.to_tuple(),
    figures: 0..31 |> Enum.map(&Map.get(@figures, &1)) |> List.to_tuple()
  }
  @encode %{
    letters: Map.new(@letters, fn {code, cp} -> {cp, code} end),
    figures: Map.new(@figures, fn {code, cp} -> {cp, code} end)
  }
  @order [:letters, :figures]
  @search Enum.reduce(@order, %{}, fn mode, acc ->
            Enum.reduce(Map.fetch!(@encode, mode), acc, fn {codepoint, code}, inner ->
              Map.put_new(inner, codepoint, {mode, code})
            end)
          end)
  @config %{
    initial: :letters,
    decode: @decode,
    encode: @encode,
    shifts: %{27 => :figures, 31 => :letters},
    shift_codes: %{letters: 31, figures: 27},
    order: @order,
    search: @search,
    aliases: %{}
  }

  @source_manifest %{
    source_sha256: "40cb4b8b1e4d891ea7b3356588c913592fee617dff07413bdc7df99a777d1298",
    source_url: "https://dflund.se/~triad/krad/recode/baudot.html",
    table: "US TTY"
  }

  @impl true
  def canonical_name, do: "ITA2-US-TTY"

  @impl true
  def aliases,
    do: ["US-TTY", "USTTY", "US-BAUDOT", "AMERICAN-TELETYPEWRITER-CODE"]

  @impl true
  def stateful?, do: true

  @doc "Returns the exact two US TTY register tables."
  def tables, do: [letters: @letters, figures: @figures]

  @doc "Returns the pinned public table source identity."
  def source_manifest, do: @source_manifest

  @impl true
  def decode(input), do: FiveUnitShift.decode(input, @config)
  @impl true
  def decode_discard(input), do: FiveUnitShift.decode_discard(input, @config)
  @impl true
  def decode_to_utf8(input), do: FiveUnitShift.decode_to_utf8(input, @config)
  @impl true
  def encode(codepoints), do: FiveUnitShift.encode(codepoints, @config)
  @impl true
  def encode_discard(codepoints), do: FiveUnitShift.encode_discard(codepoints, @config)
  @impl true
  def encode_from_utf8(input), do: FiveUnitShift.encode_from_utf8(input, @config)
end

defmodule Iconvex.Telecom.MTK2 do
  @moduledoc """
  Soviet/Russian MTK-2 three-register telegraph code.

  MTK-2 extends the ITA2 five-bit patterns with Latin, Russian, and figures
  registers. Codes 31, 0, and 27 select those registers respectively. The
  representation is one five-bit unit per octet; `Iconvex.Telecom.ITA2.Packing`
  can be used for a consecutive-bit stream.
  """

  use Iconvex.Telecom.SubstitutionCodec

  alias Iconvex.Telecom.FiveUnitShift

  @latin %{
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

  @russian %{
    1 => ?Е,
    2 => ?\n,
    3 => ?А,
    4 => ?\s,
    5 => ?С,
    6 => ?И,
    7 => ?У,
    8 => ?\r,
    9 => ?Д,
    10 => ?Р,
    11 => ?Й,
    12 => ?Н,
    13 => ?Ф,
    14 => ?Ц,
    15 => ?К,
    16 => ?Т,
    17 => ?З,
    18 => ?Л,
    19 => ?В,
    20 => ?Х,
    21 => ?Ы,
    22 => ?П,
    23 => ?Я,
    24 => ?О,
    25 => ?Б,
    26 => ?Г,
    28 => ?М,
    29 => ?Ь,
    30 => ?Ж
  }

  @figures %{
    1 => ?3,
    2 => ?\n,
    3 => ?-,
    4 => ?\s,
    5 => ?',
    6 => ?8,
    7 => ?7,
    8 => ?\r,
    9 => 0x0005,
    10 => ?4,
    11 => ?Ю,
    12 => ?,,
    13 => ?Э,
    14 => ?:,
    15 => ?(,
    16 => ?5,
    17 => ?+,
    18 => ?),
    19 => ?2,
    20 => ?Щ,
    21 => ?6,
    22 => ?0,
    23 => ?1,
    24 => ?9,
    25 => ??,
    26 => ?Ш,
    28 => ?.,
    29 => ?/,
    30 => ?=
  }

  @decode %{
    latin: 0..31 |> Enum.map(&Map.get(@latin, &1)) |> List.to_tuple(),
    russian: 0..31 |> Enum.map(&Map.get(@russian, &1)) |> List.to_tuple(),
    figures: 0..31 |> Enum.map(&Map.get(@figures, &1)) |> List.to_tuple()
  }
  @encode %{
    latin: Map.new(@latin, fn {code, cp} -> {cp, code} end),
    russian: Map.new(@russian, fn {code, cp} -> {cp, code} end),
    figures: Map.new(@figures, fn {code, cp} -> {cp, code} end)
  }
  @shift_codes %{latin: 31, russian: 0, figures: 27}
  @order [:latin, :russian, :figures]
  @search Enum.reduce(@order, %{}, fn mode, acc ->
            Enum.reduce(Map.fetch!(@encode, mode), acc, fn {codepoint, code}, inner ->
              Map.put_new(inner, codepoint, {mode, code})
            end)
          end)
  @config %{
    initial: :latin,
    decode: @decode,
    encode: @encode,
    shifts: %{31 => :latin, 0 => :russian, 27 => :figures},
    shift_codes: @shift_codes,
    order: @order,
    search: @search,
    aliases: %{?Ч => {:figures, 10}, 0x0007 => {:figures, 11}}
  }

  @source_manifest %{
    legal_source: "Russian Ministry of Communications Order No. 15 (2009)",
    source_sha256: "57d20a87f3996f54f33a3410da70db02c89320faf1ddc0368b077e00e6c41c30",
    source_url:
      "https://normativ.kontur.ru/document/1/235062-prikaz-minkomsvyazi-rf-ot-29-01-2009-n-15"
  }

  @impl true
  def canonical_name, do: "MTK-2"

  @impl true
  def aliases,
    do: ["MKT-2", "RUSSIAN-BAUDOT", "CYRILLIC-ITA2", "RUSSIAN-ITA2"]

  @impl true
  def stateful?, do: true

  @doc "Returns all three executable MTK-2 register tables."
  def tables, do: [latin: @latin, russian: @russian, figures: @figures]

  @doc "Returns each register-select code."
  def shift_codes, do: @shift_codes

  @doc "Returns the pinned government source identity."
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

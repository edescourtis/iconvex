defmodule Iconvex.Telecom.MTK2Test do
  use ExUnit.Case, async: false

  alias Iconvex.Telecom.MTK2

  @source_sha256 "57d20a87f3996f54f33a3410da70db02c89320faf1ddc0368b077e00e6c41c30"

  @latin %{
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
    30 => ?V,
    1 => ?E
  }

  @russian %{
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
    30 => ?Ж,
    1 => ?Е
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

  test "registers the Soviet/Russian three-register telegraph code" do
    for name <- ["MTK-2", "MKT-2", "RUSSIAN-BAUDOT", "CYRILLIC-ITA2"] do
      assert Iconvex.canonical_name(name) == {:ok, "MTK-2"}
    end
  end

  test "pins the government-published table source" do
    assert MTK2.source_manifest() == %{
             legal_source: "Russian Ministry of Communications Order No. 15 (2009)",
             source_sha256: @source_sha256,
             source_url:
               "https://normativ.kontur.ru/document/1/235062-prikaz-minkomsvyazi-rf-ot-29-01-2009-n-15"
           }
  end

  test "ports every Latin, Russian, and figures assignment" do
    assert MTK2.tables() == [latin: @latin, russian: @russian, figures: @figures]

    for {mode, shift, table} <- [
          {:latin, 31, @latin},
          {:russian, 0, @russian},
          {:figures, 27, @figures}
        ] do
      assert MTK2.shift_codes()[mode] == shift

      for {code, codepoint} <- table do
        assert MTK2.decode(<<shift, code>>) == {:ok, [codepoint]}
      end
    end
  end

  test "round-trips every unambiguous graphic and control through all three modes" do
    repertoire =
      ((@latin |> Map.values()) ++ (@russian |> Map.values()) ++ (@figures |> Map.values()))
      |> Enum.uniq()

    assert {:ok, encoded} = MTK2.encode(repertoire)
    assert MTK2.decode(encoded) == {:ok, repertoire}
  end

  test "documents the two nationally specified noninjective aliases" do
    assert MTK2.encode([?Ч]) == {:ok, <<27, 10>>}
    assert MTK2.decode(<<27, 10>>) == {:ok, [?4]}

    assert MTK2.encode([0x0007]) == {:ok, <<27, 11>>}
    assert MTK2.decode(<<27, 11>>) == {:ok, [?Ю]}
  end

  test "exhausts all five-bit states and rejects every high-bit octet" do
    for byte <- 32..255 do
      assert MTK2.decode(<<byte>>) == {:error, :invalid_sequence, 0, <<byte>>}
    end

    for shift <- [0, 27, 31] do
      assert MTK2.decode(<<shift>>) == {:ok, []}
    end

    assert MTK2.decode_discard(<<255, 0, 3>>) == {:ok, [?А]}
    assert MTK2.encode_discard([?А, 0x2603, ?4]) == {:ok, <<0, 3, 27, 10>>}
  end
end

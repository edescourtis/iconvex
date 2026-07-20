defmodule Iconvex.Telecom.ITA2USTTYTest do
  use ExUnit.Case, async: false

  alias Iconvex.Telecom.ITA2USTTY

  @source_sha256 "40cb4b8b1e4d891ea7b3356588c913592fee617dff07413bdc7df99a777d1298"

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

  test "registers the American Teletypewriter code names" do
    for name <- ["ITA2-US-TTY", "US-TTY", "USTTY", "AMERICAN-TELETYPEWRITER-CODE"] do
      assert Iconvex.canonical_name(name) == {:ok, "ITA2-US-TTY"}
    end
  end

  test "pins the complete published US TTY table source" do
    assert ITA2USTTY.source_manifest() == %{
             source_sha256: @source_sha256,
             source_url: "https://dflund.se/~triad/krad/recode/baudot.html",
             table: "US TTY"
           }
  end

  test "implements every letters and figures assignment" do
    assert ITA2USTTY.tables() == [letters: @letters, figures: @figures]

    for {code, codepoint} <- @letters do
      assert ITA2USTTY.decode(<<31, code>>) == {:ok, [codepoint]}
    end

    for {code, codepoint} <- @figures do
      assert ITA2USTTY.decode(<<27, code>>) == {:ok, [codepoint]}
    end
  end

  test "covers the national positions that differ from international ITA2" do
    expected = %{5 => 0x0007, 9 => ?$, 11 => ?', 13 => ?!, 17 => ?\", 20 => ?#, 26 => ?&}

    for {code, codepoint} <- expected do
      assert @figures[code] == codepoint
      assert ITA2USTTY.decode(<<27, code>>) == {:ok, [codepoint]}
      assert ITA2USTTY.encode([codepoint]) == {:ok, <<27, code>>}
    end
  end

  test "round-trips the complete representable repertoire through shifts" do
    repertoire =
      ((@letters |> Map.values()) ++ (@figures |> Map.values()))
      |> Enum.uniq()

    assert {:ok, encoded} = ITA2USTTY.encode(repertoire)
    assert ITA2USTTY.decode(encoded) == {:ok, repertoire}
  end

  test "classifies every octet and supports discard" do
    for byte <- 32..255 do
      assert ITA2USTTY.decode(<<byte>>) == {:error, :invalid_sequence, 0, <<byte>>}
    end

    assert ITA2USTTY.decode_discard(<<255, 31, 3>>) == {:ok, [?A]}
    assert ITA2USTTY.encode_discard([?A, 0x2603, ?$]) == {:ok, <<3, 27, 9>>}
  end
end

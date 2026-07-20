defmodule Iconvex.Specs.VIQRTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.VIQR

  test "implements RFC 1456 Vietnamese quoted-readable sequences" do
    assert VIQR.encode(String.to_charlist("Nước Việt Nam")) == {:ok, "Nu+o+'c Vie^.t Nam"}
    assert VIQR.decode("Nu+o+'c Vie^.t Nam") == {:ok, String.to_charlist("Nước Việt Nam")}
    assert VIQR.decode("DD dd") == {:ok, String.to_charlist("Đ đ")}
  end

  test "quotes literal punctuation that would otherwise compose" do
    assert VIQR.encode(String.to_charlist("How are you?")) == {:ok, "How are you\\?"}
    assert VIQR.decode("How are you\\?") == {:ok, String.to_charlist("How are you?")}
    assert VIQR.encode(String.to_charlist("DD")) == {:ok, "D\\D"}
    assert VIQR.decode("D\\D") == {:ok, String.to_charlist("DD")}
  end

  test "executes all 134 RFC assignments in both directions" do
    assert VIQR.source().sha256 ==
             "4bd921e49d84cf4e265ae8eb201f87fbe9ea596943464605b3010b634bf6f87d"

    assert length(VIQR.mappings()) == 134

    for %{token: token, codepoint: codepoint} <- VIQR.mappings() do
      assert VIQR.decode(token) == {:ok, [codepoint]}
      assert VIQR.encode([codepoint]) == {:ok, token}
    end
  end

  test "round-trips every adjacent pair and every ambiguous ASCII triple" do
    repertoire = Enum.to_list(0..127) ++ Enum.map(VIQR.mappings(), & &1.codepoint)

    for first <- repertoire, second <- repertoire do
      codepoints = [first, second]
      assert {:ok, encoded} = VIQR.encode(codepoints)
      assert VIQR.decode(encoded) == {:ok, codepoints}
    end

    ambiguous = ~c"AaEeIiOoUuYyDd^+(+'`?~.\\"

    for first <- ambiguous, second <- ambiguous, third <- ambiguous do
      codepoints = [first, second, third]
      assert {:ok, encoded} = VIQR.encode(codepoints)
      assert VIQR.decode(encoded) == {:ok, codepoints}
    end
  end
end

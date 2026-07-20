defmodule Iconvex.Specs.ICUSwapLFNLTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.ICUSwapLFNL

  @canonical_names [
    "ibm-37_P100-1995,swaplfnl",
    "ibm-924_P100-1998,swaplfnl",
    "ibm-1047_P100-1995,swaplfnl",
    "ibm-1140_P100-1997,swaplfnl",
    "ibm-1141_P100-1997,swaplfnl",
    "ibm-1142_P100-1997,swaplfnl",
    "ibm-1143_P100-1997,swaplfnl",
    "ibm-1144_P100-1997,swaplfnl",
    "ibm-1145_P100-1997,swaplfnl",
    "ibm-1146_P100-1997,swaplfnl",
    "ibm-1147_P100-1997,swaplfnl",
    "ibm-1148_P100-1997,swaplfnl",
    "ibm-1149_P100-1997,swaplfnl",
    "ibm-1153_P100-1999,swaplfnl",
    "ibm-12712_P100-1998,swaplfnl",
    "ibm-16804_X110-1999,swaplfnl"
  ]

  test "catalogues all ICU swaplfnl converter revisions" do
    assert ICUSwapLFNL.revision() == "21d1eb0f306e1141c10931e914dfc038c06121da"
    assert ICUSwapLFNL.release() == "78.3"

    assert ICUSwapLFNL.aggregate_sha256() ==
             "6ff0878ba966c53e6ca3d2b68ffb83128fe7edcf0efec7a5c54e4658349226ae"

    assert Enum.map(ICUSwapLFNL.encodings(), & &1.name) == @canonical_names
    assert length(ICUSwapLFNL.codecs()) == 16
  end

  test "swaps only EBCDIC LF and NL while preserving every other byte" do
    for {entry, codec} <- Enum.zip(ICUSwapLFNL.encodings(), ICUSwapLFNL.codecs()) do
      assert codec.decode(entry.lf_byte) == {:ok, [0x0A]}
      assert codec.decode(entry.nl_byte) == {:ok, [0x85]}
      assert codec.encode([0x0A, 0x85]) == {:ok, entry.lf_byte <> entry.nl_byte}

      base = %{id: entry.base_id, table_app: :iconvex_specs}
      base_table = Iconvex.Tables.fetch!(base)

      for byte <- 0..255, <<byte>> not in [entry.lf_byte, entry.nl_byte] do
        assert codec.decode(<<byte>>) == Iconvex.TableCodec.decode(base, <<byte>>)
      end

      for {codepoints, bytes} <- base_table.encode do
        expected =
          case codepoints do
            {0x0A} -> entry.lf_byte
            {0x85} -> entry.nl_byte
            _ -> bytes
          end

        assert codec.encode(Tuple.to_list(codepoints)) == {:ok, expected}
      end
    end
  end

  test "registers ICU and Java/S390 aliases as first-class external codecs" do
    assert Iconvex.canonical_name("ibm-37-s390") ==
             {:ok, "ibm-37_P100-1995,swaplfnl"}

    assert Iconvex.canonical_name("IBM924_LF") ==
             {:ok, "ibm-924_P100-1998,swaplfnl"}

    assert Iconvex.canonical_name("IBM1047_LF") ==
             {:ok, "ibm-1047_P100-1995,swaplfnl"}

    assert Iconvex.canonical_name("IBM1141_LF") ==
             {:ok, "ibm-1141_P100-1997,swaplfnl"}
  end
end

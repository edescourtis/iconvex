defmodule Iconvex.Specs.RFC1345ContractTest do
  use ExUnit.Case, async: true

  alias Iconvex.Specs.RFC1345

  test "imports every coded character set defined by RFC 1345" do
    encodings = RFC1345.encodings()

    assert length(encodings) == 145
    assert Enum.uniq_by(encodings, &String.upcase(&1.name, :ascii)) == encodings
    assert Enum.all?(encodings, &(&1.source == "RFC 1345"))
    assert Enum.any?(encodings, &(&1.name == "T.61-8bit"))
    assert Enum.any?(encodings, &(&1.name == "BS_viewdata"))
    assert Enum.any?(encodings, &(&1.name == "EBCDIC-US"))
  end

  test "implements T.61 combining sequences, not only its one-byte cells" do
    assert RFC1345.decode("T.61-8bit", <<0xC2, ?e>>) == {:ok, [0x00E9]}
    assert RFC1345.encode("T.61-8bit", [0x00E9]) == {:ok, <<0xC2, ?e>>}
    assert RFC1345.decode("T.61-8bit", <<0xE1>>) == {:ok, [0x00C6]}
  end

  test "implements legacy EBCDIC and 7-bit national sets" do
    assert RFC1345.decode("EBCDIC-US", <<0xC1, 0x81, 0xF0>>) == {:ok, [?A, ?a, ?0]}
    assert RFC1345.encode("EBCDIC-US", [?A, ?a, ?0]) == {:ok, <<0xC1, 0x81, 0xF0>>}

    assert RFC1345.decode("BS_4730", <<0x23>>) == {:ok, [0x00A3]}
    assert RFC1345.encode("BS_4730", [0x00A3]) == {:ok, <<0x23>>}
  end

  test "pins source and generated mapping provenance" do
    assert RFC1345.source() == %{
             name: "RFC 1345",
             sha256: "d1a4b6a3d6514f8ea96b74e49af40edae5c8edfcc1b1e7d9d7caebc9d622e3b0",
             url: "https://www.rfc-editor.org/rfc/rfc1345.txt"
           }
  end
end

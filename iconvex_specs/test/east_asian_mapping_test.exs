defmodule Iconvex.Specs.EastAsianMappingTest do
  use ExUnit.Case, async: true

  alias Iconvex.Specs.RFC1345

  test "pins the Unicode mapping sources used to complete RFC synthetic grid mnemonics" do
    assert RFC1345.mapping_sources() == [
             %{
               name: "CP936.TXT",
               sha256: "b86f601c575e9ab457380b6f7abef03c75499cc6075bdc8b4b27f3f2de74bf6a",
               url: "https://www.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WINDOWS/CP936.TXT"
             },
             %{
               name: "JIS0208.TXT",
               sha256: "1c571870457f19c97720631fa83ee491549a96ba1436da1296786a67d8632e87",
               url: "https://www.unicode.org/Public/MAPPINGS/OBSOLETE/EASTASIA/JIS/JIS0208.TXT"
             },
             %{
               name: "JIS0212.TXT",
               sha256: "477820bb3055bbcc90880d788cd95607d221dc94457bae249231adecf13c12e6",
               url: "https://www.unicode.org/Public/MAPPINGS/OBSOLETE/EASTASIA/JIS/JIS0212.TXT"
             },
             %{
               name: "KSX1001.TXT",
               sha256: "d8d2a35206ac0ea2865f5d801c9d6717f735bf46f263a658a64a960abe59e371",
               url: "https://www.unicode.org/Public/MAPPINGS/OBSOLETE/EASTASIA/KSC/KSX1001.TXT"
             }
           ]
  end

  test "fills the JIS, GB, and KS grid positions from their Unicode mappings" do
    assert RFC1345.decode("JIS_C6226-1983", <<0x30, 0x21>>) == {:ok, [0x4E9C]}
    assert RFC1345.decode("GB_2312-80", <<0x30, 0x21>>) == {:ok, [0x554A]}
    assert RFC1345.decode("KS_C_5601-1987", <<0x30, 0x21>>) == {:ok, [0xAC00]}
    assert RFC1345.decode("JIS_X0212-1990", <<0x30, 0x21>>) == {:ok, [0x4E02]}

    completed = ["JIS_C6226-1983", "GB_2312-80", "KS_C_5601-1987", "JIS_X0212-1990"]

    for name <- completed do
      assert Enum.find(RFC1345.encodings(), &(&1.name == name)).unresolved_spec_positions == 0
    end
  end
end

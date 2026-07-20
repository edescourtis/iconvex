defmodule Iconvex.Specs.ICUArchiveContractTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.ICUArchive

  @revision "d7d6dd5bb68930c5e6b3dd4491574153d3a1ba5a"

  test "pins every historical ICU data-repository UCM revision" do
    assert ICUArchive.revision() == @revision
    assert length(ICUArchive.encodings()) == 1_050

    assert Enum.frequencies_by(ICUArchive.encodings(), & &1.uconv_class) == %{
             "DBCS" => 66,
             "EBCDIC_STATEFUL" => 46,
             "MBCS" => 149,
             "SBCS" => 760,
             "UNCLASSIFIED" => 29
           }

    assert Enum.uniq_by(ICUArchive.encodings(), &String.downcase(&1.name)) ==
             ICUArchive.encodings()
  end

  test "uses the source filename as the lossless canonical revision name" do
    entry =
      Enum.find(ICUArchive.encodings(), fn entry ->
        entry.source_file == "glibc-ANSI_X3.110-2.1.2.ucm"
      end)

    assert entry.name == "ICU-ARCHIVE-glibc-ANSI_X3.110-2.1.2"
    assert entry.source_name == "glibc-ANSI_X3.110-2.1.2"
    assert entry.code_set_name == "ANSI_X3.110"
  end

  test "registers every archive revision without overriding existing codec names" do
    for entry <- ICUArchive.encodings() do
      assert Iconvex.canonical_name(entry.name) == {:ok, entry.name}
    end
  end

  test "exposes IANA IBM-Symbols through ICU's exact ibm-259 mapping" do
    entry = Enum.find(ICUArchive.encodings(), &(&1.source_name == "ibm-259_P100-1995"))
    assert Enum.all?(["ibm-259", "IBM-Symbols", "csIBMSymbols"], &(&1 in entry.aliases))

    for name <- ["ibm-259", "IBM-Symbols", "csIBMSymbols"] do
      assert {:ok, %{canonical: "ICU-ARCHIVE-ibm-259_P100-1995"}} =
               Iconvex.Registry.resolve(name)
    end
  end
end

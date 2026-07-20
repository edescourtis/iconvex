defmodule Iconvex.Specs.FinalResearchClosureRegistrationTest do
  use ExUnit.Case, async: false

  @expected_canonicals [
    "ADOBE-POSTSCRIPT-3-ISOLATIN1-AGL-4036A9CA",
    "CTAN-LY1-TEXNANSI-1.1-AGL-4036A9CA",
    "WIKIPEDIA-REV1340817319-EKI-SAMI-WIN-CP1270",
    "TAMILVU-TACE16-APPENDIX-D-2010-16BE",
    "TAMILVU-TACE16-APPENDIX-D-2010-16LE",
    "WANG-1983-WISCII-PDF-F4043449-WIKIPEDIA-REV1352856854",
    "WIKIPEDIA-REV1354794598-PARATYPE-WINDOWS-POLYTONIC-GREEK"
  ]

  test "RED: every final research-closure codec is centrally registered" do
    registrations = Iconvex.Specs.registrations()
    canonicals = MapSet.new(registrations, & &1.canonical)

    assert MapSet.subset?(MapSet.new(@expected_canonicals), canonicals)

    for canonical <- @expected_canonicals do
      assert [registration] = Enum.filter(registrations, &(&1.canonical == canonical))
      assert registration.codec.canonical_name() == canonical
    end
  end
end

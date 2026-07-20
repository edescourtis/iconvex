defmodule Iconvex.Specs.UNIVACFieldataAliasGlyphReviewTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.FieldataUNIVAC1100

  @catalog Path.expand("../../iconvex/research/known_encodings.csv", __DIR__)
  @canonical "FIELDATA-UNIVAC-1100"
  @ambiguous_labels ["FIELDATA-UNIVAC", "UNIVAC-FIELDATA"]
  @semantic_4009_profiles [
    Iconvex.Specs.FieldataUNIVAC4009Input,
    Iconvex.Specs.FieldataUNIVAC4009Output,
    Iconvex.Specs.FieldataUNIVAC4009LosslessVPUA
  ]

  test "RED: every catalogued UNIVAC 1100 runtime label resolves through the registry" do
    row =
      @catalog
      |> File.read!()
      |> String.split("\n")
      |> Enum.find(&String.contains?(&1, ",UNIVAC 1100 Series FIELDATA,"))

    assert row
    [_id, _title, labels | _rest] = String.split(row, ",", parts: 4)
    runtime_labels = String.split(labels, " | ")

    for label <- runtime_labels do
      assert Iconvex.canonical_name(label) == {:ok, @canonical}, label
    end

    for ambiguous <- @ambiguous_labels do
      refute ambiguous in runtime_labels
      assert Iconvex.canonical_name(ambiguous) == :error
    end

    assert FieldataUNIVAC1100.canonical_name() == @canonical
  end

  test "RED: the proprietary 4009 unit 57 glyph uses its source-qualified VPUA identity" do
    for codec <- @semantic_4009_profiles do
      assert codec.decode(<<0o57>>) == {:ok, [0xF402F]}
      assert codec.encode([0xF402F]) == {:ok, <<0o57>>}

      assert codec.encode([0x1F6D1]) ==
               {:error, :unrepresentable_character, 0x1F6D1}
    end
  end
end

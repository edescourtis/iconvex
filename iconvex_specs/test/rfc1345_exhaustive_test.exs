defmodule Iconvex.Specs.RFC1345ExhaustiveTest do
  use ExUnit.Case, async: true

  alias Iconvex.Specs.RFC1345

  test "publishes honest aggregate coverage instead of counting undefined cells as codecs" do
    summary = RFC1345.coverage_summary()

    assert summary.charsets == 145
    assert summary.decode_mappings == 53_565
    assert summary.combining_mappings == 990
    assert summary.intentional_undefined_positions > 0
    assert summary.unresolved_spec_positions > 0
    assert summary.complete_charsets + summary.partial_charsets == 145
    assert summary.complete_charsets == 143
  end

  test "pins and applies complete RFC 1345 errata tables" do
    assert RFC1345.errata_source() == %{
             name: "RFC 1345 Errata",
             sha256: "d11430dad27d385a6ec8872963e265f480c349cc1c18e0a6e9951e1f55d56ed7",
             url: "https://errata.rfc-editor.org/search/?rfc_number=1345&presentation=records"
           }

    assert Enum.count(RFC1345.encodings(), &is_integer(&1.errata)) == 38

    assert Enum.find(RFC1345.encodings(), &(&1.name == "IBM423")).layout_error ==
             {:code_byte_overflow, 271}
  end

  test "every generated canonical encoder mapping decodes to its original codepoints" do
    for entry <- RFC1345.encodings() do
      table = Iconvex.Tables.fetch!(%{id: entry.id, table_app: :iconvex_specs})

      mismatches =
        Enum.count(table.encode, fn {codepoints, bytes} ->
          RFC1345.decode(entry.name, bytes) != {:ok, Tuple.to_list(codepoints)}
        end)

      assert mismatches == entry.non_roundtrip_encode_mappings
      assert mismatches <= entry.duplicate_mappings
    end
  end

  test "every concrete decoder cell survives a decode-encode-decode cycle" do
    for entry <- RFC1345.encodings() do
      table = Iconvex.Tables.fetch!(%{id: entry.id, table_app: :iconvex_specs})

      mappings =
        Map.merge(
          table.many,
          table.one
          |> Tuple.to_list()
          |> Enum.with_index()
          |> Enum.reject(fn {value, _byte} -> is_nil(value) end)
          |> Map.new(fn {value, byte} -> {<<byte>>, value} end)
        )

      for {bytes, codepoints} <- mappings do
        assert {:ok, encoded} = RFC1345.encode(entry.name, Tuple.to_list(codepoints))

        assert RFC1345.decode(entry.name, encoded) == {:ok, Tuple.to_list(codepoints)},
               "#{entry.name} failed at #{inspect(bytes)}"
      end
    end
  end
end

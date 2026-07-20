defmodule Iconvex.Specs.ELOT927ProfilesTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.Packed

  @kermit_codec Iconvex.Specs.KermitELOT927Greek
  @kermit_source_path Path.expand(
                        "../priv/sources/dec-terminal-character-sets/kermit/ckcuni.c",
                        __DIR__
                      )
  @metadata_path Path.expand("../priv/sources/elot927/SOURCE_METADATA.md", __DIR__)
  @kermit_sha256 "af93d5a1c779aa73fa3221ab5ec0125de20267110cf23395971ce35cc88527ca"
  @iso_ir_88_sha256 "0bcae39e969ce89ad4b926cc0b0cc7c838a6720e99461f19460c9d9d2e7d815c"

  test "RED: standard ELOT 927 aliases the exact ISO-IR-88 greek7 mapping" do
    assert Iconvex.canonical_name("ELOT-927") == {:ok, "greek7"}
    assert Iconvex.canonical_name("ELOT927") == {:ok, "greek7"}

    for byte <- 0x00..0x7F do
      assert normalized(Iconvex.convert(<<byte>>, "ELOT-927", "UTF-32BE")) ==
               standard_oracle(byte)
    end

    assert %{canonical: "greek7", unit_bits: 7} = Packed.profile("ELOT-927")

    for order <- [:msb, :lsb] do
      assert {:ok, packed} = Packed.encode_from_utf8("ΑΒΩ", "ELOT-927", order)
      assert Packed.decode_to_utf8(packed, "ELOT-927", order) == {:ok, "ΑΒΩ"}
    end
  end

  test "pins the rendered ISO registration decision and licensed Kermit source" do
    metadata = File.read!(@metadata_path)

    assert metadata =~ @iso_ir_88_sha256
    assert metadata =~ "positions 41–5A"
    assert metadata =~ "positions 61–7A"
    assert metadata =~ "54 printable positions"
    assert sha256(File.read!(@kermit_source_path)) == @kermit_sha256
    refute function_exported?(@kermit_codec, :source_path, 0)
    refute function_exported?(@kermit_codec, :source_license_path, 0)
    refute function_exported?(@kermit_codec, :source_metadata_path, 0)
  end

  test "the separately named Kermit profile decodes all 128 septets exactly" do
    table = kermit_table()
    assert length(table) == 128

    for {codepoint, unit} <- Enum.with_index(table) do
      assert apply(@kermit_codec, :decode, [<<unit>>]) == {:ok, [codepoint]}
    end

    assert Enum.count(
             Enum.zip(table, Enum.map(0x00..0x7F, &standard_codepoint/1)),
             fn {left, right} -> left != right end
           ) == 54
  end

  test "Kermit profile encoding is the canonical inverse of its non-injective table" do
    table = kermit_table()

    table
    |> Enum.uniq()
    |> Enum.each(fn codepoint ->
      canonical_unit = Enum.find_index(table, &(&1 == codepoint))
      assert apply(@kermit_codec, :encode, [[codepoint]]) == {:ok, <<canonical_unit>>}
    end)

    assert apply(@kermit_codec, :encode, [[?a]]) ==
             {:error, :unrepresentable_character, ?a}

    assert apply(@kermit_codec, :encode, [[0x03B1]]) ==
             {:error, :unrepresentable_character, 0x03B1}

    assert apply(@kermit_codec, :decode, [<<0x79, 0x7A>>]) == {:ok, [0x20, 0x20]}
    assert apply(@kermit_codec, :encode, [[0x20]]) == {:ok, <<0x20>>}
  end

  test "strict, discard, direct UTF-8, aliases, and packed orders are complete" do
    for unit <- 0x80..0xFF do
      assert apply(@kermit_codec, :decode, [<<unit>>]) ==
               {:error, :invalid_sequence, 0, <<unit>>}
    end

    assert apply(@kermit_codec, :decode_discard, [<<0x41, 0x80, 0x61, 0x78>>]) ==
             {:ok, [?A, 0x0391, 0x03A9]}

    assert apply(@kermit_codec, :encode_discard, [[?A, ?a, 0x0391, 0x03B1, 0x03A9]]) ==
             {:ok, <<0x41, 0x61, 0x78>>}

    assert apply(@kermit_codec, :decode_to_utf8, [<<0x41, 0x61, 0x78>>]) == {:ok, "AΑΩ"}
    assert apply(@kermit_codec, :encode_from_utf8, ["AΑΩ"]) == {:ok, <<0x41, 0x61, 0x78>>}

    assert Iconvex.canonical_name("ELOT927-GREEK") ==
             {:ok, "KERMIT-ELOT927-GREEK"}

    assert Iconvex.canonical_name("DEC-GREEK-7-UPPER") ==
             {:ok, "KERMIT-ELOT927-GREEK"}

    assert %{canonical: "KERMIT-ELOT927-GREEK", unit_bits: 7} =
             Packed.profile("ELOT927-GREEK")

    for order <- [:msb, :lsb] do
      assert {:ok, packed} = Packed.encode_from_utf8("AΑΩ", "ELOT927-GREEK", order)
      assert Packed.decode_to_utf8(packed, "ELOT927-GREEK", order) == {:ok, "AΑΩ"}
    end
  end

  defp standard_oracle(byte) when byte in [0x4A, 0x57, 0x6A], do: :undefined
  defp standard_oracle(0x24), do: 0x00A4
  defp standard_oracle(byte) when byte in 0x41..0x49, do: 0x0391 + byte - 0x41
  defp standard_oracle(byte) when byte in 0x4B..0x52, do: 0x039A + byte - 0x4B
  defp standard_oracle(byte) when byte in 0x53..0x56, do: 0x03A3 + byte - 0x53
  defp standard_oracle(byte) when byte in 0x58..0x5A, do: 0x03A7 + byte - 0x58
  defp standard_oracle(byte) when byte in 0x61..0x69, do: 0x03B1 + byte - 0x61
  defp standard_oracle(byte) when byte in 0x6B..0x72, do: 0x03BA + byte - 0x6B
  defp standard_oracle(byte) when byte in 0x73..0x76, do: 0x03C3 + byte - 0x73
  defp standard_oracle(0x77), do: 0x03C2
  defp standard_oracle(byte) when byte in 0x78..0x7A, do: 0x03C7 + byte - 0x78
  defp standard_oracle(0x7E), do: 0x203E
  defp standard_oracle(byte), do: byte

  defp standard_codepoint(byte) do
    case standard_oracle(byte) do
      :undefined -> 0xFFFD
      codepoint -> codepoint
    end
  end

  defp kermit_table do
    Enum.to_list(0x00..0x20) ++ source_table("u_elot927") ++ [0x7F]
  end

  defp source_table(table_name) do
    source = File.read!(@kermit_source_path)

    pattern =
      ~r/struct\s+x_to_unicode\s+#{Regex.escape(table_name)}\s*=\s*\{(?<body>.*?)\n\};/s

    %{"body" => body} = Regex.named_captures(pattern, source)

    ~r/0x([0-9A-Fa-f]+)/
    |> Regex.scan(body, capture: :all_but_first)
    |> Enum.map(fn [hex] -> String.to_integer(hex, 16) end)
  end

  defp normalized({:ok, <<codepoint::unsigned-big-32>>}), do: codepoint
  defp normalized({:error, %Iconvex.Error{kind: :invalid_sequence}}), do: :undefined
  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end

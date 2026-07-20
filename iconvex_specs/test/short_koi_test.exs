defmodule Iconvex.Specs.ShortKOITest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.Packed

  @codec Iconvex.Specs.ShortKOI
  @source_path Path.expand(
                 "../priv/sources/dec-terminal-character-sets/kermit/ckcuni.c",
                 __DIR__
               )
  @license_path Path.expand(
                  "../priv/sources/dec-terminal-character-sets/kermit/COPYING",
                  __DIR__
                )
  @metadata_path Path.expand("../priv/sources/short-koi/SOURCE_METADATA.md", __DIR__)
  @source_sha256 "af93d5a1c779aa73fa3221ab5ec0125de20267110cf23395971ce35cc88527ca"
  @license_sha256 "067b8c8fc98d9359dfbd211820e1d57bed1e173144a184a21e8ead802b6502be"

  test "RED: pins the licensed mapping source and KOI-7 N2 identification" do
    assert sha256(File.read!(@source_path)) == @source_sha256
    assert sha256(File.read!(@license_path)) == @license_sha256
    assert File.read!(@metadata_path) =~ "KOI-7 N2"
    assert File.read!(@metadata_path) =~ "GOST 13052"
    refute function_exported?(@codec, :source_path, 0)
    refute function_exported?(@codec, :source_license_path, 0)
    refute function_exported?(@codec, :source_metadata_path, 0)
    assert apply(@codec, :unit_bits, []) == 7
  end

  test "implements and reverses all 128 septets from the pinned source table" do
    table = full_table()
    assert length(table) == 128
    assert length(Enum.uniq(table)) == 128

    for {codepoint, unit} <- Enum.with_index(table) do
      assert apply(@codec, :decode, [<<unit>>]) == {:ok, [codepoint]}
      assert apply(@codec, :encode, [[codepoint]]) == {:ok, <<unit>>}
    end
  end

  test "rejects every high octet with exact offsets" do
    for unit <- 0x80..0xFF do
      assert apply(@codec, :decode, [<<unit>>]) ==
               {:error, :invalid_sequence, 0, <<unit>>}

      assert apply(@codec, :decode, [<<0, unit>>]) ==
               {:error, :invalid_sequence, 1, <<unit>>}
    end

    assert apply(@codec, :encode, [[?a]]) ==
             {:error, :unrepresentable_character, ?a}
  end

  test "strict, discard, and direct UTF-8 paths preserve the stateless mapping" do
    assert apply(@codec, :decode_discard, [<<0x41, 0x80, 0x60, 0x61>>]) ==
             {:ok, [?A, 0x042E, 0x0410]}

    assert apply(@codec, :encode_discard, [[?A, ?a, 0x042E, 0x0410]]) ==
             {:ok, <<0x41, 0x60, 0x61>>}

    assert apply(@codec, :decode_to_utf8, [<<0x41, 0x60, 0x61>>]) == {:ok, "AЮА"}
    assert apply(@codec, :encode_from_utf8, ["AЮА"]) == {:ok, <<0x41, 0x60, 0x61>>}

    assert apply(@codec, :encode_from_utf8, [<<?A, 0xFF>>]) ==
             {:decode_error, :invalid_sequence, 1, <<0xFF>>}
  end

  test "registers historical aliases and both explicit packed septet orders" do
    assert Iconvex.canonical_name("KOI-7") == {:ok, "SHORT-KOI"}
    assert Iconvex.canonical_name("KOI-7-N2") == {:ok, "SHORT-KOI"}
    assert Iconvex.canonical_name("VKD") == {:ok, "SHORT-KOI"}

    assert %{canonical: "SHORT-KOI", unit_bits: 7, standard_order: :msb} =
             Packed.profile("KOI7-N2")

    assert {:ok, <<0x41::7, 0x60::7, 0x61::7>> = msb} =
             Packed.encode_from_utf8("AЮА", "SHORT-KOI", :msb)

    assert Packed.decode_to_utf8(msb, "SHORT-KOI", :msb) == {:ok, "AЮА"}

    assert {:ok, %Iconvex.Packed.LSB{bit_size: 21} = lsb} =
             Packed.encode_from_utf8("AЮА", "SHORT-KOI", :lsb)

    assert Packed.decode_to_utf8(lsb, "SHORT-KOI", :lsb) == {:ok, "AЮА"}
  end

  defp full_table do
    Enum.to_list(0x00..0x20) ++ source_table() ++ [0x7F]
  end

  defp source_table do
    source = File.read!(@source_path)

    %{"body" => body} =
      Regex.named_captures(
        ~r/struct\s+x_to_unicode\s+u_koi7\s*=\s*\{(?<body>.*?)\n\};/s,
        source
      )

    ~r/0x([0-9A-Fa-f]+)/
    |> Regex.scan(body, capture: :all_but_first)
    |> Enum.map(fn [hex] -> String.to_integer(hex, 16) end)
  end

  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end

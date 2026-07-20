defmodule Iconvex.Specs.EvertypeSourceQualifiedTest do
  use ExUnit.Case, async: true

  @source_dir Path.expand("../priv/sources/evertype-source-qualified", __DIR__)
  @metadata Path.join(@source_dir, "SOURCE_METADATA.md")

  @profiles [
    %{
      module: Iconvex.Specs.Evertype.Latin8Extended2001,
      canonical: "EVERTYPE-2001-LATIN-8-EXTENDED",
      file: "latin8_extended.csv",
      source_url: "https://www.evertype.com/standards/mappings/pc/LATIN8EX.TXT",
      source_version: "1.00",
      source_date: "2001-11-10",
      source_size: 10_813,
      source_sha256: "bf737b4ade62c97acd5969f75916142748fcde041e8c97fd6663863ccc96a975",
      mapping_sha256: "53750c83e4958e7f530f7eaa59163689caa12c3916cb4103ff066952ab61a13b",
      mapped: 249,
      invalid: 7,
      vector: {0x80, 0x20AC}
    },
    %{
      module: Iconvex.Specs.Evertype.MacArmenian2001,
      canonical: "EVERTYPE-2001-MAC-ARMENIAN",
      file: "mac_armenian.csv",
      source_url: "https://www.evertype.com/standards/mappings/mac/ARMENIAN.TXT",
      source_version: "1.00",
      source_date: "2001-11-10",
      source_size: 10_137,
      source_sha256: "c194770439215b4fb2c9b3a5f232a9ae35371ccf8fbf26f9c13e03afe61a8536",
      mapping_sha256: "696a5f6cd8145857990cf5e0c762c4f91ebb48f07f1744eff84ef0a56f7faba5",
      mapped: 256,
      invalid: 0,
      vector: {0x80, 0x0531}
    },
    %{
      module: Iconvex.Specs.Evertype.MacBarentsCyrillic2001,
      canonical: "EVERTYPE-2001-MAC-BARENTS-CYRILLIC",
      file: "mac_barents_cyrillic.csv",
      source_url: "https://www.evertype.com/standards/mappings/mac/BARENCYR.TXT",
      source_version: "1.00",
      source_date: "2001-11-10",
      source_size: 11_171,
      source_sha256: "c8b84a870ff5344965a1874ca0001735e3e403c22a4f50c71979d90bd6a1fe31",
      mapping_sha256: "f95ab935a572d1ee82b44228b610156bc2a75d07a3a85cd1d5988a587a751cfd",
      mapped: 254,
      invalid: 2,
      vector: {0x80, 0x0410}
    },
    %{
      module: Iconvex.Specs.Evertype.MacGeorgian2002,
      canonical: "EVERTYPE-2002-MAC-GEORGIAN",
      file: "mac_georgian.csv",
      source_url: "https://www.evertype.com/standards/mappings/mac/GEORGIAN.TXT",
      source_version: "1.01",
      source_date: "2002-02-20",
      source_size: 9_763,
      source_sha256: "fcd491dbb7916fe477a2bab79872cef498d3a418594eba307ccbd14d095ce8cf",
      mapping_sha256: "2d668f14a934f457495dc86a698f03845525cc9ff43f837fb0f3f98f41819897",
      mapped: 256,
      invalid: 0,
      vector: {0x80, 0x10A0}
    },
    %{
      module: Iconvex.Specs.Evertype.MacMalteseEsperanto2001,
      canonical: "EVERTYPE-2001-MAC-MALTESE-ESPERANTO",
      file: "mac_maltese_esperanto.csv",
      source_url: "https://www.evertype.com/standards/mappings/mac/MALTESE.TXT",
      source_version: "1.00",
      source_date: "2001-11-10",
      source_size: 11_671,
      source_sha256: "a902a920790704905a9aa7d5ea03d19996c4bfe6e46501f53878f9b27107ef41",
      mapping_sha256: "ed4516ebd16e1d715c2c271becf11cfcca8a57c0cf4e4f173d142393c8a88ffe",
      mapped: 256,
      invalid: 0,
      vector: {0x80, 0x00C4}
    },
    %{
      module: Iconvex.Specs.Evertype.MacOgham2001,
      canonical: "EVERTYPE-2001-MAC-OGHAM",
      file: "mac_ogham.csv",
      source_url: "https://www.evertype.com/standards/mappings/mac/OGHAM.TXT",
      source_version: "1.00",
      source_date: "2001-11-10",
      source_size: 6_422,
      source_sha256: "d95239fc60b38ef80488cbc55b342a9d695953802ecce869077212256e50a13a",
      mapping_sha256: "77a027e95f55949aa22756f45f14b7fb03253ff87d67311252d21910fccee3bf",
      mapped: 167,
      invalid: 89,
      vector: {0xE0, 0x1680}
    },
    %{
      module: Iconvex.Specs.Evertype.MacTurkicCyrillic2002,
      canonical: "EVERTYPE-2002-MAC-TURKIC-CYRILLIC",
      file: "mac_turkic_cyrillic.csv",
      source_url: "https://www.evertype.com/standards/mappings/mac/TURKCYR.TXT",
      source_version: "1.01",
      source_date: "2002-02-20",
      source_size: 11_974,
      source_sha256: "26175fa84c20db0cab9c11ec532c622490796c6de1561b58313ed090a644e968",
      mapping_sha256: "228b19300e6baefda3e6aa9d4e89343f42a660bd3d5989cbd52f9dae585a6277",
      mapped: 256,
      invalid: 0,
      vector: {0x80, 0x0410}
    }
  ]

  test "RED: normalized artifacts and source/version/SHA pins are exact" do
    metadata = File.read!(@metadata)

    assert metadata =~ "does not imply vendor authorship, affiliation, approval, or endorsement"
    assert metadata =~ "CER-GS 1.01 blocker"
    assert metadata =~ "9aece7742b4fc70f6047f888815efc1f21f08b521c03e07ed96e91b50fc25f36"

    for profile <- @profiles do
      path = Path.join(@source_dir, profile.file)
      pairs = parse_mapping(path)

      assert sha256(File.read!(path)) == profile.mapping_sha256
      assert length(pairs) == profile.mapped
      assert 256 - length(pairs) == profile.invalid

      assert Enum.map(pairs, &elem(&1, 0)) ==
               pairs |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> Enum.sort()

      assert Enum.all?(pairs, fn {byte, codepoint} -> byte in 0..255 and scalar?(codepoint) end)

      for value <- 0..0x1F, do: assert({value, value} in pairs)
      assert {0x7F, 0x7F} in pairs

      for pin <- [
            profile.canonical,
            profile.source_url,
            profile.source_version,
            profile.source_date,
            profile.source_sha256,
            profile.mapping_sha256
          ] do
        assert metadata =~ pin
      end
    end
  end

  test "RED: the seven codecs expose only source-qualified registry identities" do
    modules = Enum.map(@profiles, & &1.module)

    assert Iconvex.Specs.evertype_source_qualified_codecs() == modules

    for profile <- @profiles do
      codec = profile.module
      assert codec.canonical_name() == profile.canonical
      assert codec.aliases() == []

      assert %{codec: ^codec, canonical: canonical, aliases: []} =
               Enum.find(Iconvex.Specs.registrations(), &(&1.codec == codec))

      assert canonical == profile.canonical
      assert {:ok, %{codec: ^codec, canonical: ^canonical}} = Iconvex.Registry.resolve(canonical)
    end

    for generic <- [
          "LATIN-8-EXTENDED",
          "MAC-ARMENIAN",
          "MAC-BARENTS-CYRILLIC",
          "MAC-GEORGIAN",
          "MAC-MALTESE-ESPERANTO",
          "MAC-OGHAM",
          "MAC-TURKIC-CYRILLIC"
        ] do
      case Iconvex.Registry.resolve(generic) do
        {:ok, %{codec: codec}} -> refute codec in modules
        :error -> :ok
      end
    end
  end

  test "RED: every codec is built by the reusable native engine and pins provenance" do
    for profile <- @profiles do
      codec = profile.module

      assert codec.__source_qualified_single_byte__()
      assert codec.unit_bits() == 8
      assert codec.inverse_policy() == :lowest_byte
      assert codec.provenance_qualification() == :source_only_no_endorsement
      assert codec.source_url() == profile.source_url
      assert codec.source_version() == profile.source_version
      assert codec.source_date() == profile.source_date
      assert codec.source_size() == profile.source_size
      assert codec.source_sha256() == profile.source_sha256
      assert codec.mapping_sha256() == profile.mapping_sha256
      assert codec.mapped_byte_count() == profile.mapped
      assert codec.invalid_byte_count() == profile.invalid
    end
  end

  test "RED: pinned vectors and all 256 decode positions match the independent artifacts" do
    for profile <- @profiles do
      codec = profile.module
      mapping = Map.new(parse_mapping(Path.join(@source_dir, profile.file)))
      inverse = canonical_inverse(mapping)
      {vector_byte, vector_codepoint} = profile.vector

      assert codec.decode(<<vector_byte>>) == {:ok, [vector_codepoint]}
      assert codec.encode([vector_codepoint]) == {:ok, <<Map.fetch!(inverse, vector_codepoint)>>}

      for byte <- 0..255 do
        case Map.fetch(mapping, byte) do
          {:ok, codepoint} ->
            assert codec.decode(<<byte>>) == {:ok, [codepoint]}
            assert codec.decode_discard(<<byte>>) == {:ok, [codepoint]}
            assert codec.decode_to_utf8(<<byte>>) == {:ok, <<codepoint::utf8>>}
            assert codec.encode([codepoint]) == {:ok, <<Map.fetch!(inverse, codepoint)>>}

          :error ->
            assert codec.decode(<<byte>>) ==
                     {:error, :invalid_sequence, 0, <<byte>>}

            assert codec.decode_discard(<<byte>>) == {:ok, []}
        end
      end
    end
  end

  test "RED: duplicate inverse, error offsets, discard, substitution, streams, and UTF-8 are deterministic" do
    barents = Iconvex.Specs.Evertype.MacBarentsCyrillic2001
    assert barents.decode(<<0xC2, 0xC3>>) == {:ok, [0x0304, 0x0304]}
    assert barents.encode([0x0304]) == {:ok, <<0xC2>>}

    for profile <- @profiles do
      codec = profile.module

      assert codec.encode([?A, 0x10FFFF, ?B]) ==
               {:error, :unrepresentable_character, 0x10FFFF}

      assert codec.encode_discard([?A, 0x10FFFF, ?B]) == {:ok, "AB"}

      assert codec.encode_substitute([?A, 0x10FFFF, ?B], fn 0x10FFFF -> ~c"?" end) ==
               {:ok, "A?B"}

      assert codec.encode_substitute([0x10FFFF], fn 0x10FFFF -> [0x10FFFE] end) ==
               {:error, :unrepresentable_character, 0x10FFFE}

      assert codec.decode_chunk("AB", false) == {:ok, ~c"AB", <<>>}
      assert codec.encode_chunk(~c"AB", false, :error) == {:ok, "AB", []}
      assert codec.encode_chunk([?A, 0x10FFFF, ?B], true, :discard) == {:ok, "AB", []}

      assert codec.encode_chunk(
               [?A, 0x10FFFF, ?B],
               true,
               {:replace, fn 0x10FFFF -> ~c"?" end}
             ) == {:ok, "A?B", []}

      assert codec.encode_from_utf8("A" <> <<0xE2, 0x82>>) ==
               {:decode_error, :incomplete_sequence, 1, <<0xE2, 0x82>>}

      assert codec.encode_from_utf8("A" <> <<0xFF>>) ==
               {:decode_error, :invalid_sequence, 1, <<0xFF>>}

      assert codec.encode_from_utf8(<<0x10FFFF::utf8, 0xFF>>) ==
               {:error, :unrepresentable_character, 0x10FFFF}

      mapping = Map.new(parse_mapping(Path.join(@source_dir, profile.file)))

      case Enum.find(0..255, &(not Map.has_key?(mapping, &1))) do
        nil ->
          :ok

        invalid ->
          assert codec.decode(<<0x41, invalid, 0x42>>) ==
                   {:error, :invalid_sequence, 1, <<invalid>>}

          assert codec.decode_discard(<<0x41, invalid, 0x42>>) == {:ok, ~c"AB"}

          assert codec.decode_chunk(<<0x41, invalid, 0x42>>, false) ==
                   {:error, :invalid_sequence, 1, <<invalid>>}

          assert {:error,
                  %Iconvex.Error{
                    kind: :invalid_sequence,
                    offset: 1,
                    sequence: <<^invalid>>
                  }} =
                   Iconvex.convert(
                     <<0x41, invalid, 0x42>>,
                     profile.canonical,
                     "UTF-8"
                   )

          assert Iconvex.convert(
                   <<0x41, invalid, 0x42>>,
                   profile.canonical,
                   "UTF-8",
                   invalid: :discard
                 ) == {:ok, "AB"}
      end
    end
  end

  defp parse_mapping(path) do
    ["byte,unicode" | rows] = path |> File.read!() |> String.split("\n", trim: true)

    Enum.map(rows, fn row ->
      [byte, codepoint] = String.split(row, ",", parts: 2)
      {String.to_integer(byte, 16), String.to_integer(codepoint, 16)}
    end)
  end

  defp canonical_inverse(mapping) do
    mapping
    |> Enum.sort()
    |> Enum.reduce(%{}, fn {byte, codepoint}, inverse ->
      Map.put_new(inverse, codepoint, byte)
    end)
  end

  defp scalar?(codepoint),
    do: codepoint in 0..0xD7FF or codepoint in 0xE000..0x10FFFF

  defp sha256(bytes),
    do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end

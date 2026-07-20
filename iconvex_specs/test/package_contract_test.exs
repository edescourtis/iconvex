defmodule Iconvex.Specs.PackageContractTest do
  use ExUnit.Case, async: false

  @root Path.expand("..", __DIR__)
  @quarantined_openjdk_release_paths ~w(
    lib/iconvex/specs/openjdk_utf16le_bom.ex
    lib/iconvex/specs/openjdk_utf32_bom.ex
    lib/iconvex/specs/openjdk_ms950_hkscs_xp.ex
    lib/iconvex/specs/openjdk_euc_jp_open.ex
    lib/iconvex/specs/openjdk_iso2022_cn.ex
    lib/iconvex/specs/openjdk_iso2022_jp.ex
    priv/openjdk_euc_jp_open_manifest.etf
    priv/openjdk_iso2022_cn.etf
    priv/openjdk_iso2022_cn_manifest.etf
    priv/openjdk_iso2022_jp.etf
    priv/openjdk_iso2022_jp_manifest.etf
    priv/openjdk_ms950_hkscs_xp_manifest.etf
    priv/tables/openjdk_euc_jp_open.etf
    priv/tables/openjdk_ms950_hkscs_xp.etf
  )

  @packaged_provenance_codecs [
    Iconvex.Specs.DECGreek81994,
    Iconvex.Specs.DECTurkish81994,
    Iconvex.Specs.IBM1116850P100Composite,
    Iconvex.Specs.IBM1117437P100Composite,
    Iconvex.Specs.IBM310293P100CompositeVPUA,
    Iconvex.Specs.IBM907CDRAP100VPUAComposite,
    Iconvex.Specs.IBMTNZCP310B1EAE3C
  ]

  test "RED: packaged README links Iconvex through its durable package page" do
    readme = File.read!(Path.join(@root, "README.md"))

    assert readme =~ "[`iconvex`](https://hex.pm/packages/iconvex)"
    refute readme =~ "](../iconvex)"
  end

  test "release metadata includes the OTP crypto runtime used by shipped validators" do
    assert {:ok, applications} = :application.get_key(:iconvex_specs, :applications)

    assert :crypto in applications

    assert :crypto in Enum.map(Application.started_applications(), &elem(&1, 0))

    high_hex = Iconvex.Specs.ABICOMP.SourceAsset.high_hex()
    assert byte_size(high_hex) == 1_024
  end

  test "checked-in Hex tarballs contain no quarantined OpenJDK runtime artifacts" do
    for tarball <- Path.wildcard(Path.join(@root, "iconvex_specs-*.tar")) do
      stale_entries =
        tarball
        |> hex_tar_entries!()
        |> Enum.filter(&(&1 in @quarantined_openjdk_release_paths))

      assert stale_entries == [],
             "#{Path.basename(tarball)} is pre-quarantine and ships: #{Enum.join(stale_entries, ", ")}"
    end
  end

  test "RED: Hex exclusion rules deny quarantined runtime assets even if they reappear" do
    exclude_patterns =
      Mix.Project.config()
      |> Keyword.fetch!(:package)
      |> Keyword.fetch!(:exclude_patterns)

    forbidden_paths =
      Enum.filter(@quarantined_openjdk_release_paths, &String.starts_with?(&1, "priv/")) ++
        ["priv/._openjdk_iso2022_cn.etf", "priv/tables/._openjdk_euc_jp_open.etf"]

    for path <- forbidden_paths do
      assert Enum.any?(exclude_patterns, &Regex.match?(&1, path)),
             "Hex exclusion rules do not reject #{path}"
    end
  end

  test "RED: new source-qualified mapping evidence is selected into the Hex package" do
    files = Mix.Project.config() |> Keyword.fetch!(:package) |> Keyword.fetch!(:files)

    for selector <- [
          "priv/sources/abc800-basic-ii/*.csv",
          "priv/sources/abc800-basic-ii/SOURCE_METADATA.md",
          "priv/sources/rfc698-stanford/*.csv",
          "priv/sources/rfc698-stanford/SOURCE_METADATA.md",
          "priv/sources/evertype-source-qualified/*.csv",
          "priv/sources/evertype-source-qualified/SOURCE_METADATA.md",
          "priv/sources/secondary-source-qualified-single-byte/*",
          "priv/sources/glyph-vector-unicode/*",
          "priv/sources/tace16-2010/*",
          "EVERTYPE_SOURCE_QUALIFIED.md"
        ] do
      assert selector in files
    end
  end

  test "RED: final research-closure codecs are named in every release evidence document" do
    names = [
      "CTAN-LY1-TEXNANSI-1.1-AGL-4036A9CA",
      "ADOBE-POSTSCRIPT-3-ISOLATIN1-AGL-4036A9CA",
      "TAMILVU-TACE16-APPENDIX-D-2010-16BE",
      "TAMILVU-TACE16-APPENDIX-D-2010-16LE",
      "WANG-1983-WISCII-PDF-F4043449-WIKIPEDIA-REV1352856854",
      "WIKIPEDIA-REV1354794598-PARATYPE-WINDOWS-POLYTONIC-GREEK",
      "WIKIPEDIA-REV1340817319-EKI-SAMI-WIN-CP1270"
    ]

    for filename <-
          ~w(README.md SUPPORTED_ENCODINGS.md CHANGELOG.md SOURCES.md BENCHMARKS.md CONFORMANCE.md) do
      document = filename |> Path.expand(Path.expand("..", __DIR__)) |> File.read!()
      for name <- names, do: assert(document =~ name, "#{filename} is missing #{name}")
    end
  end

  test "public provenance path helpers only expose packaged release assets" do
    {:ok, modules} = :application.get_key(:iconvex_specs, :modules)

    actual =
      for module <- modules,
          {name, arity} <- module.__info__(:functions),
          helper_name?(name),
          do: {module, name, arity}

    expected =
      [
        {Iconvex.Specs.IBMAdditionalCodePages, :source_map_path, 1},
        {Iconvex.Specs.IBMAdditionalCodePages, :source_metadata_path, 0}
      ] ++
        for module <- @packaged_provenance_codecs,
            name <- [:source_map_path, :source_metadata_path],
            do: {module, name, 0}

    assert Enum.sort(actual) == Enum.sort(expected)

    runtime_priv = :iconvex_specs |> :code.priv_dir() |> List.to_string()

    for codec <- @packaged_provenance_codecs,
        path <- [codec.source_map_path(), codec.source_metadata_path()] do
      assert File.regular?(path)
      refute path |> Path.relative_to(runtime_priv) |> String.starts_with?("..")
    end
  end

  defp helper_name?(name) do
    name = Atom.to_string(name)

    String.contains?(name, "path") or String.ends_with?(name, "_directory")
  end

  defp hex_tar_entries!(path) do
    {:ok, outer_entries} = :erl_tar.extract(String.to_charlist(path), [:memory])

    {_, compressed_contents} =
      Enum.find(outer_entries, fn {name, _bytes} ->
        List.to_string(name) == "contents.tar.gz"
      end)

    {:ok, inner_entries} =
      :erl_tar.extract({:binary, :zlib.gunzip(compressed_contents)}, [:memory])

    Enum.map(inner_entries, fn {name, _bytes} -> List.to_string(name) end)
  end

  test "public supported-codec list excludes quarantined RFC definitions" do
    assert length(Iconvex.Specs.codecs()) == 1_841
    assert length(Iconvex.Specs.encodings()) == 1_841
    refute "JIS_C6226-1978" in Iconvex.Specs.encodings()
    refute "IBM423" in Iconvex.Specs.encodings()
    assert "BOCU-1" in Iconvex.Specs.encodings()
    assert "SCSU" in Iconvex.Specs.encodings()
    assert "ADOBE-STANDARD-ENCODING" in Iconvex.Specs.encodings()
    assert "MacCeltic" in Iconvex.Specs.encodings()
    assert "MARC-8" in Iconvex.Specs.encodings()
    assert "ANSEL" in Iconvex.Specs.encodings()
    assert "ISCII-91" in Iconvex.Specs.encodings()
    assert "x-iscii-ma" in Iconvex.Specs.encodings()
    assert "TSCII" in Iconvex.Specs.encodings()
    assert "BRF" in Iconvex.Specs.encodings()
    assert "EUC-JP-MS" in Iconvex.Specs.encodings()
    assert "ISO_6937" in Iconvex.Specs.encodings()
    assert "WIN-SAMI-2" in Iconvex.Specs.encodings()
    assert "ibm-803_P100-1999" in Iconvex.Specs.encodings()
    assert "macos-6_2-10.4" in Iconvex.Specs.encodings()
    assert "euc-jp-2007" in Iconvex.Specs.encodings()
    assert "ibm-16684_P110-2003" in Iconvex.Specs.encodings()
    assert "ibm-930_P120-1999" in Iconvex.Specs.encodings()
    assert "ibm-1388_P100-2024" in Iconvex.Specs.encodings()
    assert "ICU-ARCHIVE-glibc-ANSI_X3.110-2.1.2" in Iconvex.Specs.encodings()
    assert "ICU-ARCHIVE-java-ISO2022KR-1.3_P" in Iconvex.Specs.encodings()
    assert "APL-ISO-IR-68" in Iconvex.Specs.encodings()
    assert "APL-ISO-IR-68-2004" in Iconvex.Specs.encodings()
    assert "KPS-9566-2003" in Iconvex.Specs.encodings()
    assert "ibm-1047_P100-1995,swaplfnl" in Iconvex.Specs.encodings()
    assert "WINDOWS-BESTFIT-1252" in Iconvex.Specs.encodings()
    assert "US-ASCII-QUOTES" in Iconvex.Specs.encodings()
    assert "MNEMONIC" in Iconvex.Specs.encodings()
    assert "MNEM" in Iconvex.Specs.encodings()
    assert "VIQR" in Iconvex.Specs.encodings()
    assert "UTF-1" in Iconvex.Specs.encodings()
    assert "UTF-5" in Iconvex.Specs.encodings()
    assert "UTF-6" in Iconvex.Specs.encodings()
    assert "CDC-6-12-DISPLAY-CODE-63" in Iconvex.Specs.encodings()
    assert "CDC-6-12-DISPLAY-CODE-64" in Iconvex.Specs.encodings()
    assert "CDC-DISPLAY-CODE-63" in Iconvex.Specs.encodings()
    assert "CDC-DISPLAY-CODE-64" in Iconvex.Specs.encodings()
    assert "CDC-DISPLAY-CODE-ASCII-63" in Iconvex.Specs.encodings()
    assert "CDC-DISPLAY-CODE-ASCII-64" in Iconvex.Specs.encodings()
    assert "DEC-SPECIAL" in Iconvex.Specs.encodings()
    assert "DEC-SPECIAL-GR" in Iconvex.Specs.encodings()
    assert "DEC-TECHNICAL" in Iconvex.Specs.encodings()
    assert "DEC-TECHNICAL-GR" in Iconvex.Specs.encodings()
    assert "SI-960" in Iconvex.Specs.encodings()
    assert "DEC-HEBREW-8" in Iconvex.Specs.encodings()
    assert "DEC-SIXBIT" in Iconvex.Specs.encodings()
    assert "KEYBCS2" in Iconvex.Specs.encodings()
    assert "MYSQL-KEYBCS2" in Iconvex.Specs.encodings()
    assert "ABICOMP" in Iconvex.Specs.encodings()
    assert "BRASCII" in Iconvex.Specs.encodings()
    assert "JIS7-KANJI" in Iconvex.Specs.encodings()
    assert "MACOS_ESPERANTO" in Iconvex.Specs.encodings()
    assert "VSCII-2" in Iconvex.Specs.encodings()
    assert "LICS" in Iconvex.Specs.encodings()
    assert "US-ARMY-GTA-31-70-001-TAP-CODE-PAIR-VALUES" in Iconvex.Specs.encodings()
    refute "TAP-CODE" in Iconvex.Specs.encodings()
    assert "PDP-1-CONCISE-1960-INITIAL-LOWER" in Iconvex.Specs.encodings()
    assert "PDP-1-CONCISE-1960-INITIAL-UPPER" in Iconvex.Specs.encodings()
    assert "PDP-1-FRIDEN-FPC-8-1960-INITIAL-LOWER" in Iconvex.Specs.encodings()
    assert "PDP-1-FRIDEN-FPC-8-1960-INITIAL-UPPER" in Iconvex.Specs.encodings()
    assert "PDP-1-CONCISE-FIODEC-1963-INITIAL-LOWER" in Iconvex.Specs.encodings()
    assert "PDP-1-CONCISE-FIODEC-1963-INITIAL-UPPER" in Iconvex.Specs.encodings()
    assert "PDP-1-FIODEC-ODD-PARITY-8BIT-1963-INITIAL-LOWER" in Iconvex.Specs.encodings()
    assert "PDP-1-FIODEC-ODD-PARITY-8BIT-1963-INITIAL-UPPER" in Iconvex.Specs.encodings()
    assert "FIELDATA-UNIVAC-1100" in Iconvex.Specs.encodings()
    assert "FIELDATA-UNIVAC-4009-INPUT" in Iconvex.Specs.encodings()
    assert "FIELDATA-UNIVAC-4009-OUTPUT" in Iconvex.Specs.encodings()
    assert "FIELDATA-UNIVAC-4009-LOSSLESS-VPUA" in Iconvex.Specs.encodings()
    assert "FIELDATA-UNIVAC-4009-RAW-VPUA" in Iconvex.Specs.encodings()
    assert "TI-89-92-PLUS-AMS-2.0" in Iconvex.Specs.encodings()
    assert "TI-89-92-PLUS-AMS-2.0-VISIBLE" in Iconvex.Specs.encodings()
    assert "TI-89-92-PLUS-AMS-2.0-LOSSLESS-VPUA" in Iconvex.Specs.encodings()
    assert "TI-89-92-PLUS-AMS-2.0-RAW-VPUA" in Iconvex.Specs.encodings()
    assert "TI-83-PLUS-LARGE" in Iconvex.Specs.encodings()
    assert "TI-83-PLUS-LARGE-LOSSLESS-VPUA" in Iconvex.Specs.encodings()
    assert "TI-83-PLUS-LARGE-RAW-VPUA" in Iconvex.Specs.encodings()
    assert "TI-83-PLUS-SMALL" in Iconvex.Specs.encodings()
    assert "TI-83-PLUS-SMALL-LOSSLESS-VPUA" in Iconvex.Specs.encodings()
    assert "TI-83-PLUS-SMALL-RAW-VPUA" in Iconvex.Specs.encodings()
    assert "DEC-RADIX-50-16BE" in Iconvex.Specs.encodings()
    assert "DEC-RADIX-50-16LE" in Iconvex.Specs.encodings()
    assert "DEC-RADIX-50-18BIT-24BE" in Iconvex.Specs.encodings()
    assert "DEC-RADIX-50-18BIT-24LE" in Iconvex.Specs.encodings()
    assert "DEC-RADIX-50-36BIT-40BE" in Iconvex.Specs.encodings()
    assert "DEC-RADIX-50-36BIT-40LE" in Iconvex.Specs.encodings()
    assert "ECMA-1" in Iconvex.Specs.encodings()
    assert "ISO-IR-208" in Iconvex.Specs.encodings()
    assert "ISO-IR-234" in Iconvex.Specs.encodings()
    assert "ISO-IR-164" in Iconvex.Specs.encodings()
    assert "ISO-IR-167" in Iconvex.Specs.encodings()
    assert "KOI7-switched" in Iconvex.Specs.encodings()
    assert "SHORT-KOI" in Iconvex.Specs.encodings()
    assert "KOI8-F" in Iconvex.Specs.encodings()
    assert "KERMIT-ELOT927-GREEK" in Iconvex.Specs.encodings()
    assert "GREEK-ISO" in Iconvex.Specs.encodings()
    assert "HEBREW-ISO" in Iconvex.Specs.encodings()
    assert "LATIN6-ISO" in Iconvex.Specs.encodings()
    assert "MACINTOSH-LATIN" in Iconvex.Specs.encodings()
    assert "BULGARIA-PC" in Iconvex.Specs.encodings()
    assert "MAZOVIA" in Iconvex.Specs.encodings()
    assert "QNX-CONSOLE" in Iconvex.Specs.encodings()
    assert "DG-INTERNATIONAL" in Iconvex.Specs.encodings()
    assert "KERMIT-DG-LINEDRAWING" in Iconvex.Specs.encodings()
    assert "KERMIT-DG-WORDPROCESSING" in Iconvex.Specs.encodings()
    assert "KERMIT-HP-MATH-TECHNICAL" in Iconvex.Specs.encodings()
    assert "KERMIT-SNI-BRACKETS" in Iconvex.Specs.encodings()
    assert "KERMIT-SNI-EURO" in Iconvex.Specs.encodings()
    assert "KERMIT-SNI-FACET" in Iconvex.Specs.encodings()
    assert "KERMIT-SNI-IBM" in Iconvex.Specs.encodings()
    assert "DEC-NRC-UNITED-KINGDOM" in Iconvex.Specs.encodings()
    assert "DEC-NRC-DUTCH" in Iconvex.Specs.encodings()
    assert "DEC-NRC-FINNISH" in Iconvex.Specs.encodings()
    assert "DEC-NRC-FRENCH" in Iconvex.Specs.encodings()
    assert "DEC-NRC-FRENCH-CANADIAN" in Iconvex.Specs.encodings()
    assert "DEC-NRC-GERMAN" in Iconvex.Specs.encodings()
    assert "DEC-NRC-ITALIAN" in Iconvex.Specs.encodings()
    assert "DEC-NRC-NORWEGIAN-DANISH" in Iconvex.Specs.encodings()
    assert "DEC-NRC-PORTUGUESE" in Iconvex.Specs.encodings()
    assert "DEC-NRC-SPANISH" in Iconvex.Specs.encodings()
    assert "DEC-NRC-SWEDISH" in Iconvex.Specs.encodings()
    assert "DEC-NRC-SWISS" in Iconvex.Specs.encodings()
    assert "ICONVEX-UTF-32BE-SIGNATURE" in Iconvex.Specs.encodings()
    assert "ICONVEX-UTF-32LE-SIGNATURE" in Iconvex.Specs.encodings()
    assert "ICONVEX-UTF-16-SIGNATURE-LE-DEFAULT" in Iconvex.Specs.encodings()
    refute "x-MS950-HKSCS-XP" in Iconvex.Specs.encodings()
    refute "x-eucJP-Open" in Iconvex.Specs.encodings()
    refute "x-windows-50220" in Iconvex.Specs.encodings()
    refute "x-windows-50221" in Iconvex.Specs.encodings()
    refute "x-windows-iso2022jp" in Iconvex.Specs.encodings()
    refute "x-ISO-2022-CN-GB" in Iconvex.Specs.encodings()
    refute "x-ISO-2022-CN-CNS" in Iconvex.Specs.encodings()
    assert "UTF16_PlatformEndian" in Iconvex.Specs.encodings()
    assert "UTF16_OppositeEndian" in Iconvex.Specs.encodings()
    assert "UTF32_PlatformEndian" in Iconvex.Specs.encodings()
    assert "UTF32_OppositeEndian" in Iconvex.Specs.encodings()
    assert "UTF-16,version=1" in Iconvex.Specs.encodings()
    assert "UTF-16,version=2" in Iconvex.Specs.encodings()
    assert "JIS7" in Iconvex.Specs.encodings()
    assert "JIS8" in Iconvex.Specs.encodings()
    assert "LMBCS-1" in Iconvex.Specs.encodings()
    assert "IBM-310-293-P100-COMPOSITE-VPUA" in Iconvex.Specs.encodings()
    assert "IBM-TNZ-CP310-B1EAE3C" in Iconvex.Specs.encodings()
    assert "IBM-907-CDRA-P100-VPUA-COMPOSITE" in Iconvex.Specs.encodings()
    assert "IBM-1116-850-P100-COMPOSITE" in Iconvex.Specs.encodings()
    assert "IBM-1117-437-P100-COMPOSITE" in Iconvex.Specs.encodings()
    assert "DEC-GREEK-8-1994" in Iconvex.Specs.encodings()
    assert "DEC-TURKISH-8-1994" in Iconvex.Specs.encodings()

    for group <- [2, 3, 4, 5, 6, 8, 11, 16, 17, 18, 19],
        do: assert("LMBCS-#{group}" in Iconvex.Specs.encodings())

    assert "x11-compound-text" in Iconvex.Specs.encodings()
    assert "x-Europa" in Iconvex.Specs.encodings()
    assert "CP51950" in Iconvex.Specs.encodings()
    assert "x-cp50227" in Iconvex.Specs.encodings()
    assert "Amiga-1251" in Iconvex.Specs.encodings()
    assert "Extended_UNIX_Code_Fixed_Width_for_Japanese" in Iconvex.Specs.encodings()
    assert "HP-Math8" in Iconvex.Specs.encodings()
    assert "Microsoft-Publishing" in Iconvex.Specs.encodings()
    assert "Ventura-International" in Iconvex.Specs.encodings()
    assert "ISO-10646-UCS-Basic" in Iconvex.Specs.encodings()
    assert "ISO-10646-Unicode-Latin1" in Iconvex.Specs.encodings()
    assert "ISO-10646-J-1" in Iconvex.Specs.encodings()
    assert "ISO-IR-171" in Iconvex.Specs.encodings()
    assert "ISO-IR-187" in Iconvex.Specs.encodings()
    assert "ISO-IR-228" in Iconvex.Specs.encodings()
    assert "ISO-IR-229" in Iconvex.Specs.encodings()
    assert "ISO-IR-233" in Iconvex.Specs.encodings()
    assert "ISO-IR-31" in Iconvex.Specs.encodings()
    assert "ISO-IR-198" in Iconvex.Specs.encodings()
    assert "IBM-5052" in Iconvex.Specs.encodings()
    assert "IBM-5053" in Iconvex.Specs.encodings()
    assert "IBM-958" in Iconvex.Specs.encodings()
    assert "IBM-5055" in Iconvex.Specs.encodings()
    assert "IBM-965" in Iconvex.Specs.encodings()
    assert "IBM-1175" in Iconvex.Specs.encodings()
    assert "IBM-17354" in Iconvex.Specs.encodings()
    assert "IBM-934" in Iconvex.Specs.encodings()
    assert "IBM-938" in Iconvex.Specs.encodings()
    assert "UTF-9-16BE" in Iconvex.Specs.encodings()
    assert "UTF-9-16LE" in Iconvex.Specs.encodings()
    assert "UTF-18-24BE" in Iconvex.Specs.encodings()
    assert "UTF-18-24LE" in Iconvex.Specs.encodings()
  end

  test "RED: release-facing support documents state the live aggregate cardinalities" do
    root = Path.expand("..", __DIR__)
    readme = File.read!(Path.join(root, "README.md"))
    supported = File.read!(Path.join(root, "SUPPORTED_ENCODINGS.md"))

    assert readme =~ "1,841 byte-pipeline codecs"
    assert String.replace(readme, ~r/\s+/, " ") =~ "2,093 unique canonical"
    assert supported =~ "**1,841** registered canonical codecs"
    assert supported =~ "the 1,841 registered codec count"
  end

  test "support documents identify the exhaustive inventory and every inventory generator" do
    readme = File.read!(Path.join(@root, "README.md"))
    supported = File.read!(Path.join(@root, "SUPPORTED_ENCODINGS.md"))
    normalized_readme = String.replace(readme, ~r/\s+/, " ")
    normalized_supported = String.replace(supported, ~r/\s+/, " ")

    assert normalized_readme =~
             "SUPPORTED_CODEC_INVENTORY.csv) for every registered canonical name and alias"

    assert normalized_readme =~
             "SUPPORTED_ENCODINGS.md) summarizes codec families and exact mapping counts"

    for generator <- [
          "generate_codec_inventory.exs",
          "generate_non_octet_codec_inventory.exs",
          "generate_packed_codec_inventory.exs",
          "generate_property_token_mapping_inventory.exs",
          "generate_raw_transport_inventory.exs"
        ] do
      assert readme =~ "mix run tools/#{generator}",
             "README regeneration commands omit #{generator}"
    end

    assert normalized_supported =~
             "Only the RFC 1345 section below is generated by `tools/import_rfc1345.exs`"

    assert normalized_supported =~
             "Package-wide summaries and exact inventory links are maintained with the named inventory generators"

    refute supported =~
             "Generated by `tools/import_rfc1345.exs`; do not edit by hand."
  end

  test "RED: packaged changelog documents the GNU/RFC 1345 compatibility migration" do
    changelog = File.read!("CHANGELOG.md")
    mix_source = File.read!("mix.exs")

    assert mix_source =~ "CHANGELOG.md"
    assert changelog =~ "Breaking compatibility"
    assert changelog =~ "758/758"
    assert changelog =~ "RFC1345:IBM037"
    assert changelog =~ "Iconvex.Specs.RFC1345.decode/2"

    for name <- ~w(
          IBM037 IBM1026 IBM273 IBM277 IBM278 IBM280 IBM284 IBM285 IBM297 IBM424
          IBM437 IBM500 IBM852 IBM855 IBM857 IBM860 IBM861 IBM863 IBM864 IBM865
          IBM869 IBM870 IBM871 IBM880 IBM905
        ) do
      assert changelog =~ name
    end
  end

  test "catalogued list retains both quarantined definitions for auditability" do
    assert length(Iconvex.Specs.catalogued_encodings()) == 1_843
    assert "JIS_C6226-1978" in Iconvex.Specs.catalogued_encodings()
    assert "IBM423" in Iconvex.Specs.catalogued_encodings()
  end

  test "generated inventory is an exact runtime canonical-name and alias snapshot" do
    csv_field = fn value ->
      if String.contains?(value, [",", "\"", "\n", "\r"]) do
        "\"" <> String.replace(value, "\"", "\"\"") <> "\""
      else
        value
      end
    end

    rows =
      Iconvex.Specs.registrations()
      |> Enum.sort_by(&{&1.canonical, inspect(&1.codec)})
      |> Enum.map(fn registration ->
        [
          registration.canonical,
          registration.aliases |> Enum.sort() |> Enum.join("|"),
          inspect(registration.codec),
          to_string(registration.codec.stateful?())
        ]
        |> Enum.map_join(",", csv_field)
      end)

    expected = Enum.join(["canonical,aliases,module,stateful" | rows], "\n") <> "\n"

    assert length(rows) == 1_841
    assert File.read!("SUPPORTED_CODEC_INVENTORY.csv") == expected
  end

  test "all 1,050 ICU archive tables are owned by the three release shards" do
    for {range, app} <- [
          {1..350, :iconvex_specs_icu_archive_a},
          {351..700, :iconvex_specs_icu_archive_b},
          {701..1050, :iconvex_specs_icu_archive_c}
        ],
        index <- range do
      id = String.to_atom("icu_archive_#{index}")

      assert {^app, {:owned, token}} =
               :persistent_term.get({{Iconvex.Tables, :provider}, id})

      assert is_reference(token)

      assert app
             |> :code.priv_dir()
             |> Path.join("tables/#{id}.etf")
             |> File.regular?()
    end
  end

  test "archive-backed bridge codecs load every callback through release-shard providers" do
    for {codec, id, app} <- [
          {Iconvex.Specs.IBM1175, :icu_archive_374, :iconvex_specs_icu_archive_b},
          {Iconvex.Specs.ISOIR42, :icu_archive_726, :iconvex_specs_icu_archive_c}
        ] do
      provider_cache = {{Iconvex.Tables, :table}, app, id}
      main_cache = {{Iconvex.Tables, :table}, :iconvex_specs, id}

      operations = [
        {fn -> codec.decode(<<>>) end, {:ok, []}},
        {fn -> codec.decode_discard(<<>>) end, {:ok, []}},
        {fn -> codec.decode_to_utf8(<<>>) end, {:ok, ""}},
        {fn -> codec.encode([]) end, {:ok, <<>>}},
        {fn -> codec.encode_discard([]) end, {:ok, <<>>}},
        {fn -> codec.encode_substitute([], fn _codepoint -> [0x3F] end) end, {:ok, <<>>}},
        {fn -> codec.encode_from_utf8("") end, {:ok, <<>>}}
      ]

      for {operation, expected} <- operations do
        :persistent_term.erase(provider_cache)
        :persistent_term.erase(main_cache)

        assert operation.() == expected
        assert :persistent_term.get(provider_cache, :missing) != :missing
        assert :persistent_term.get(main_cache, :missing) == :missing
      end
    end
  end
end

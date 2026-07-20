defmodule Iconvex.ResearchCatalogTest do
  use ExUnit.Case, async: true

  @catalog Path.expand("../research/known_encodings.csv", __DIR__)
  @gnu_unsupported Path.expand("../research/gnu_libiconv_1_19_unsupported.csv", __DIR__)
  @high_gap_audit Path.expand("../research/HIGH_PRIORITY_CODEC_GAPS.tsv", __DIR__)
  @catalog_summary Path.expand("../research/KNOWN_ENCODINGS.md", __DIR__)
  @non_codec_dispositions Path.expand("../research/NON_CODEC_DISPOSITIONS.md", __DIR__)
  @catalog_manifest Path.expand("../research/encoding_catalog_manifest.json", __DIR__)
  @closure_audit Path.expand("../research/CATALOG_CLOSURE_AUDIT.tsv", __DIR__)
  @ambiguous_primary_blockers Path.expand(
                                "../../iconvex_specs/priv/sources/ambiguous-primary-codecs/BLOCKERS.md",
                                __DIR__
                              )
  @gnu_definitions Path.expand(
                     "fixtures/gnu-libiconv-1.19-encodings/encodings.def",
                     __DIR__
                   )
  @runtime_names Path.expand("../SUPPORTED_NAME_INVENTORY.csv", __DIR__)

  test "RED: non-codec dispositions never describe implemented exact profiles as gaps" do
    dispositions = File.read!(@non_codec_dispositions)

    for {catalog_name, stale_claim} <- [
          {"TI-83 Plus character set", "TI-83 Plus character set` and `TI-89"},
          {"TI-89 / TI-92 Plus character set",
           "remain explicit high-confidence `codec_gap` rows"},
          {"JIS7-KANJI", "`JIS7-KANJI` remains a `codec_gap`"}
        ] do
      row =
        @catalog
        |> File.stream!()
        |> Enum.find(&String.contains?(&1, ",#{catalog_name},"))

      assert row, catalog_name
      assert String.ends_with?(String.trim(row), ",implemented"), catalog_name
      refute String.contains?(dispositions, stale_claim), stale_claim
    end

    assert dispositions =~
             "TI-83 Plus, TI-89/TI-92 Plus, and source-qualified JIS7-KANJI profiles are implemented"
  end

  test "RED: UTF-5 is an exact draft-backed implementation rather than a Wikipedia candidate" do
    rows = @catalog |> File.read!() |> String.split("\n", trim: true)
    assert [row] = Enum.filter(rows, &String.contains?(&1, ",UTF-5,"))

    assert String.contains?(row, "DRAFT-JSENG-UTF5-01")
    assert String.contains?(row, "draft-jseng-utf5-01")
    assert String.contains?(row, "https://www.ietf.org/archive/id/draft-jseng-utf5-01.txt")
    assert String.contains?(row, ",high,")
    assert String.contains?(row, ",yes,")
    assert String.ends_with?(String.trim(row), ",implemented")
  end

  test "RED: UTF-6 is an exact draft-backed implementation rather than a Wikipedia candidate" do
    rows = @catalog |> File.read!() |> String.split("\n", trim: true)
    assert [row] = Enum.filter(rows, &String.contains?(&1, ",UTF-6,"))

    assert String.contains?(row, "DRAFT-IETF-IDN-UTF6-00")
    assert String.contains?(row, "draft-ietf-idn-utf6-00")
    assert String.contains?(row, "https://www.ietf.org/archive/id/draft-ietf-idn-utf6-00.txt")
    assert String.contains?(row, ",high,")
    assert String.contains?(row, ",yes,")
    assert String.ends_with?(String.trim(row), ",implemented")
  end

  test "RED: PASCII is closed only by explicit C-DAC source and projection profiles" do
    [header | rows] = @catalog |> File.read!() |> String.split("\n", trim: true)

    assert [row] =
             Enum.filter(
               rows,
               &String.contains?(
                 &1,
                 ",Perso-Arabic Script Code for Information Interchange,"
               )
             )

    record = Enum.zip(csv_fields(header), csv_fields(row)) |> Map.new()
    aliases = String.split(record["aliases"], " | ", trim: true)

    assert record["name"] == "Perso-Arabic Script Code for Information Interchange"

    for identity <- [
          "PASCII-CDAC-GIST-1.0-2002-LOSSLESS-VPUA-1",
          "PASCII-CDAC-GIST-1.0-2002-RAW-VPUA-1",
          "PASCII-CDAC-GIST-1.0-2002-URDU-KASHMIRI-UNICODE17-BEST-FIT",
          "PASCII-CDAC-GIST-1.0-2002-SINDHI-UNICODE17-BEST-FIT"
        ] do
      assert identity in aliases
    end

    refute "PASCII" in aliases
    assert record["source_urls"] =~ "PASCIIStandard.pdf"
    assert record["statuses"] =~ "primary_government_byte_chart_with_explicit_projection_policy"
    assert record["confidence"] == "high"
    assert record["iconvex"] == "yes"
    assert record["implementation_disposition"] == "implemented"
  end

  test "RED: all ten primary IBM 24/26 arrangements are exact implemented catalog profiles" do
    rows = @catalog |> File.read!() |> String.split("\n", trim: true)

    source =
      "https://bitsavers.org/pdf/ibm/punchedCard/Keypunch/024-026/A24-0520-3_24_26_Card_Punch_Reference_Manual_Oct1965.pdf"

    for arrangement <- ~w(A B C D E F G H J K) do
      exact = "IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-#{arrangement}"
      assert [row] = Enum.filter(rows, &String.contains?(&1, exact)), exact
      assert String.contains?(row, source), exact
      assert String.contains?(row, "primary_historical_manual_exact_mapping"), exact
      assert String.contains?(row, ",high,"), exact
      assert String.contains?(row, ",yes,"), exact
      assert String.ends_with?(String.trim(row), ",implemented"), exact
    end

    commercial = Enum.find(rows, &String.contains?(&1, ",IBM 026 Commercial card code,"))
    fortran = Enum.find(rows, &String.contains?(&1, ",IBM 026 FORTRAN card code,"))
    assert commercial =~ "BCD-A"
    assert fortran =~ "BCD-H"
    assert String.ends_with?(String.trim(commercial), ",implemented")
    assert String.ends_with?(String.trim(fortran), ",implemented")
  end

  test "RED: every remaining gap and research candidate has one evidence-backed closure audit" do
    unresolved =
      @catalog
      |> File.stream!()
      |> Stream.drop(1)
      |> Stream.map(&String.trim/1)
      |> Stream.filter(fn line ->
        String.ends_with?(line, ",codec_gap") or
          String.ends_with?(line, ",research_candidate")
      end)
      |> Map.new(fn line ->
        [catalog_id | _rest] = String.split(line, ",", parts: 2)

        disposition =
          if String.ends_with?(line, ",codec_gap"), do: "codec_gap", else: "research_candidate"

        {catalog_id, disposition}
      end)

    [header | rows] = @closure_audit |> File.read!() |> String.split("\n", trim: true)

    assert header ==
             "catalog_id\tname\tcurrent_disposition\tclosure_class\tsource_grade\ttarget_disposition\trecommended_package\tauthoritative_or_best_evidence\trequired_closure"

    audited =
      Map.new(rows, fn row ->
        assert [
                 catalog_id,
                 name,
                 current_disposition,
                 closure_class,
                 source_grade,
                 target_disposition,
                 recommended_package,
                 evidence,
                 required_closure
               ] = String.split(row, "\t")

        for {label, value} <- [
              name: name,
              closure_class: closure_class,
              source_grade: source_grade,
              target_disposition: target_disposition,
              recommended_package: recommended_package,
              evidence: evidence,
              required_closure: required_closure
            ] do
          assert String.trim(value) != "", "#{catalog_id} has empty #{label}"
        end

        assert current_disposition in ["codec_gap", "research_candidate"]
        {catalog_id, current_disposition}
      end)

    assert map_size(unresolved) == 200
    assert map_size(audited) == 200
    assert audited == unresolved
  end

  test "RED: unavailable primary sources are not queued as exact codecs" do
    [_header | rows] = @closure_audit |> File.read!() |> String.split("\n", trim: true)

    audited =
      Map.new(rows, fn row ->
        [catalog_id | fields] = String.split(row, "\t")
        {catalog_id, fields}
      end)

    assert [
             "Code page 1050",
             "research_candidate",
             "candidate_blocked_missing_exact_primary_artifact",
             "B1 primary description without pinned table",
             "blocked_missing_primary_artifact",
             "iconvex_specs",
             _evidence,
             cp1050_closure
           ] = Map.fetch!(audited, "ENC-0147")

    assert cp1050_closure =~ "exact primary artifact"

    assert [
             "Main code page (Russian)",
             "research_candidate",
             "candidate_blocked_primary_source_unavailable",
             "B1 cited primary scans unavailable",
             "blocked_source_unavailable",
             "iconvex_specs",
             _evidence,
             russian_closure
           ] = Map.fetch!(audited, "ENC-1250")

    assert russian_closure =~ "replacement primary"
  end

  test "RED: contradictory and incomplete primary mappings remain auditable blockers" do
    [_header | rows] = @closure_audit |> File.read!() |> String.split("\n", trim: true)

    audited =
      Map.new(rows, fn row ->
        fields = String.split(row, "\t")
        assert length(fields) == 9
        [catalog_id | rest] = fields
        {catalog_id, rest}
      end)

    expected = %{
      "ENC-0095" =>
        {"CER-GS", "candidate_blocked_contradictory_published_mapping",
         "B1 published source-qualified table is internally contradictory"},
      "ENC-0149" =>
        {"Code page 1058", "candidate_blocked_incomplete_primary_unicode_binding",
         "B1 primary byte-to-GCGID grid; exact Unicode binding incomplete"},
      "ENC-0167" =>
        {"Code page 1118", "candidate_blocked_ambiguous_text_vs_graphic_profile",
         "B1 primary graphic GCGID grid; exact text-converter identity unresolved"},
      "ENC-0266" =>
        {"Code page 899", "candidate_blocked_two_primary_unicode_bindings",
         "B1 primary byte/GCGID tables plus pinned IBM P100 join; two bindings unresolved"},
      "ENC-0961" =>
        {"IBMEL card character set", "gap_blocked_unnamed_unicode_binding",
         "B1 complete secondary punch table; one semantic Unicode binding absent"},
      "ENC-1442" =>
        {"UNIVAC 1108 punched-card code", "gap_blocked_two_unnamed_graphics",
         "B1 secondary reconstruction explicitly leaves two graphics unnamed"}
    }

    for {catalog_id, {name, closure_class, source_grade}} <- expected do
      assert [
               ^name,
               current_disposition,
               ^closure_class,
               ^source_grade,
               "retain_unimplemented_blocker",
               "iconvex_specs",
               evidence,
               required_closure
             ] = Map.fetch!(audited, catalog_id)

      assert current_disposition in ["codec_gap", "research_candidate"]
      assert evidence =~ "SHA-256"
      assert evidence =~ "ambiguous-primary-codecs/BLOCKERS.md"
      assert required_closure =~ "Do not implement"
    end

    blockers = File.read!(@ambiguous_primary_blockers)

    for fact <- [
          "B7=U+1E40 and B7=U+1E41",
          "5E `SD150200`",
          "EF `SA140000`",
          "99 `SM600001`",
          "0x282 `subscript ten`",
          "0x006 and 0x806"
        ] do
      assert blockers =~ fact
    end
  end

  test "RED: evidence-conflicted historical profiles remain precise unimplemented blockers" do
    [_header | rows] = @closure_audit |> File.read!() |> String.split("\n", trim: true)

    audited =
      Map.new(rows, fn row ->
        fields = String.split(row, "\t")
        assert length(fields) == 9
        [catalog_id | rest] = fields
        {catalog_id, rest}
      end)

    expected = %{
      "ENC-0067" =>
        {"Bitstream International Character Set", "codec_gap",
         "gap_blocked_non_octet_and_incomplete_unicode_binding",
         "B1 secondary two-byte chart with unresolved non-Unicode glyphs",
         "d4d327400fecdaa4ce3cb2f74369c893c6921774b9255aa835aebe5e28ddb636",
         "secondary-source-qualified-single-byte/BLOCKERS.md",
         ["Do not implement", "primary BICS framing", "non-Unicode"]},
      "ENC-0546" =>
        {"Hollerith consensus punched-card code", "codec_gap",
         "gap_blocked_source_declared_variant_cells",
         "B1 complete secondary historical chart with four explicitly variable cells",
         "824e61a9687f7fa0b9c9dd3c966ca02020bf8af1ab6671e9bd2e131f22f47b18",
         "punched-card-codes/hollerith_consensus_iowa_824e61a9_blocker.md",
         ["Do not implement", "four variant cells", "canonical inverse"]},
      "ENC-0985" =>
        {"Iran System encoding standard", "codec_gap",
         "gap_blocked_license_and_conflicting_unicode_semantics",
         "B1 authoritative mapping is redistribution-restricted; licensed secondary semantics conflict",
         "e31f8d325640aff859f2ce53c6b69e650a0084c42ba6dcbaddaeccdf82b0e1e3",
         "secondary-source-qualified-single-byte/BLOCKERS.md",
         ["Do not implement", "redistribution permission", "Unicode semantic profile"]},
      "ENC-1265" =>
        {"Modified HP Roman-8", "research_candidate",
         "candidate_blocked_multiple_versions_and_ambiguous_unicode_bindings",
         "B1 secondary source defines two variants with alternative Unicode mappings",
         "c4cd07bb1be71bd5267eb9f6222839451ce344637e39e8a5b4ad0d5ffe4832a0",
         "secondary-source-qualified-single-byte/BLOCKERS.md",
         ["Do not implement", "separate", "primary charts", "inverse"]}
    }

    for {catalog_id,
         {name, current_disposition, closure_class, source_grade, evidence_pin, blocker_path,
          closure_facts}} <- expected do
      assert [
               ^name,
               ^current_disposition,
               ^closure_class,
               ^source_grade,
               "retain_unimplemented_blocker",
               "iconvex_specs",
               evidence,
               required_closure
             ] = Map.fetch!(audited, catalog_id)

      assert evidence =~ evidence_pin
      assert evidence =~ blocker_path

      for fact <- closure_facts do
        assert required_closure =~ fact, "#{catalog_id} is missing closure fact #{inspect(fact)}"
      end
    end
  end

  test "RED: GammaPro keyboard layouts are blocked until an exact character mapping exists" do
    [_header | rows] = @closure_audit |> File.read!() |> String.split("\n", trim: true)

    audited =
      Map.new(rows, fn row ->
        [catalog_id | fields] = String.split(row, "\t")
        {catalog_id, fields}
      end)

    for {catalog_id, name, language} <- [
          {"ENC-1519", "Windows Cyrillic + French", "French"},
          {"ENC-1520", "Windows Cyrillic + German", "German"}
        ] do
      assert [
               ^name,
               "research_candidate",
               "candidate_blocked_missing_exact_primary_mapping",
               "B1 complete secondary table; cited primary is keyboard-layout metadata only",
               "retain_unimplemented_blocker",
               "iconvex_specs",
               evidence,
               required_closure
             ] = Map.fetch!(audited, catalog_id)

      assert evidence =~ "gammapro.com/keyboard.html"
      assert evidence =~ "oldid="
      assert required_closure =~ language
      assert required_closure =~ "byte-to-Unicode"
    end
  end

  test "RED: the exact-codec implementation queue is completely closed" do
    [_header | rows] = @closure_audit |> File.read!() |> String.split("\n", trim: true)

    queued =
      Enum.flat_map(rows, fn row ->
        case String.split(row, "\t") do
          [catalog_id, name, _current, _class, _grade, "implement_exact_codec" | _rest] ->
            ["#{catalog_id} #{name}"]

          _other ->
            []
        end
      end)

    assert queued == [],
           "exact codecs still queued without an implementation or evidence blocker:\n" <>
             Enum.join(queued, "\n")
  end

  test "RED: exact source-qualified research profiles are implemented without unsafe generic aliases" do
    [header | rows] = @catalog |> File.read!() |> String.split("\n", trim: true)

    records =
      Map.new(rows, fn row ->
        record = Enum.zip(csv_fields(header), csv_fields(row)) |> Map.new()
        {record["name"], record}
      end)

    expected = %{
      "ABC 800" => ["LUXOR-ABC800-BASIC-II-1981-CHARACTER-MODE"],
      "DEC 026 card code" => ["DEC-026-CARD-IOWA-824E61A9"],
      "DEC 029 card code" => ["DEC-029-CARD-IOWA-824E61A9"],
      "EBCD card character set" => ["EBCD-CARD-IOWA-824E61A9"],
      "Extended Latin-8" => ["EVERTYPE-2001-LATIN-8-EXTENDED"],
      "GE 600 punched-card code" => ["GE-600-CARD-IOWA-824E61A9"],
      "IBM 029 card code" => ["IBM-029-CARD-IOWA-824E61A9"],
      "LST 1564" => ["LIETUVYBE-52A97895-LST-1564-2000-STRICT-BLANKS"],
      "LST 1590-2" => ["LIETUVYBE-52A97895-LST-1590-2-2000-STRICT-BLANKS"],
      "LST 1590-4" => ["LIETUVYBE-52A97895-LST-1590-4-2000-STRICT-BLANKS"],
      "Mac OS Armenian" => ["EVERTYPE-2001-MAC-ARMENIAN"],
      "Mac OS Barents Cyrillic" => ["EVERTYPE-2001-MAC-BARENTS-CYRILLIC"],
      "Mac OS Georgian" => ["EVERTYPE-2002-MAC-GEORGIAN"],
      "Mac OS Maltese/Esperanto encoding" => ["EVERTYPE-2001-MAC-MALTESE-ESPERANTO"],
      "Mac OS Ogham" => ["EVERTYPE-2001-MAC-OGHAM"],
      "Mac OS Turkic Cyrillic" => ["EVERTYPE-2002-MAC-TURKIC-CYRILLIC"],
      "OT1 encoding" => ["TEX-OT1-CMAP-1.0J", "TEX-OT1TT-CMAP-1.0J"],
      "Stanford Extended ASCII" => [
        "RFC698-SU-AI-STANFORD-1975-FORMAT-EFFECTOR",
        "RFC698-SU-AI-STANFORD-1975-HIDDEN-GRAPHICS"
      ],
      "VNI Character Set" => [
        "VIETUNICODE-2002-VNI-ASCII-DOS",
        "VIETUNICODE-2002-VNI-ANSI-WIN-UNIX",
        "VIETUNICODE-2002-VNI-MAC",
        "VIETUNICODE-2002-VNI-INTERNET-MAIL"
      ]
    }

    for {name, source_qualified_identities} <- expected do
      record = Map.fetch!(records, name)
      aliases = String.split(record["aliases"], " | ", trim: true)

      assert record["iconvex"] == "yes", name
      assert record["implementation_disposition"] == "implemented", name

      for identity <- source_qualified_identities do
        assert identity in aliases, "#{name} is missing #{identity}"
      end
    end

    closure = File.read!(@closure_audit)
    for name <- Map.keys(expected), do: refute(closure =~ "\t#{name}\t")
  end

  test "RED: final research-closure profiles are exact implemented catalog entries" do
    [header | rows] = @catalog |> File.read!() |> String.split("\n", trim: true)

    records =
      Map.new(rows, fn row ->
        record = Enum.zip(csv_fields(header), csv_fields(row)) |> Map.new()
        {record["name"], record}
      end)

    expected = %{
      "LY1 encoding" => ["CTAN-LY1-TEXNANSI-1.1-AGL-4036A9CA"],
      "PostScript Latin 1 Encoding" => ["ADOBE-POSTSCRIPT-3-ISOLATIN1-AGL-4036A9CA"],
      "Tamil All Character Encoding" => [
        "TAMILVU-TACE16-APPENDIX-D-2010-16BE",
        "TAMILVU-TACE16-APPENDIX-D-2010-16LE"
      ],
      "Wang International Standard Code for Information Interchange" => [
        "WANG-1983-WISCII-PDF-F4043449-WIKIPEDIA-REV1352856854"
      ],
      "Windows Polytonic Greek" => [
        "WIKIPEDIA-REV1354794598-PARATYPE-WINDOWS-POLYTONIC-GREEK"
      ],
      "Windows-1270" => ["WIKIPEDIA-REV1340817319-EKI-SAMI-WIN-CP1270"]
    }

    for {name, identities} <- expected do
      record = Map.fetch!(records, name)
      aliases = String.split(record["aliases"], " | ", trim: true)

      assert record["iconvex"] == "yes", name
      assert record["implementation_disposition"] == "implemented", name

      for identity <- identities,
          do: assert(identity in aliases, "#{name} is missing #{identity}")
    end

    closure = File.read!(@closure_audit)
    for name <- Map.keys(expected), do: refute(closure =~ "\t#{name}\t")
  end

  test "RED: TACE16 is merged into its implemented Tamil All Character Encoding concept" do
    [header | rows] = @catalog |> File.read!() |> String.split("\n", trim: true)

    records =
      Map.new(rows, fn row ->
        record = Enum.zip(csv_fields(header), csv_fields(row)) |> Map.new()
        {record["name"], record}
      end)

    refute Map.has_key?(records, "TACE16")

    record = Map.fetch!(records, "Tamil All Character Encoding")
    aliases = String.split(record["aliases"], " | ", trim: true)

    assert "TACE16" in aliases
    assert record["source_ids"] =~ "wikipedia:pageid 41675931"
    assert record["source_ids"] =~ "wikipedia:pageid 41675869"
    assert record["implementation_disposition"] == "implemented"
    refute File.read!(@closure_audit) =~ "\tTACE16\t"
  end

  test "RED: Unihan property profiles and the kGB3 GL child are explicit without false generic aliases" do
    rows = @catalog |> File.read!() |> String.split("\n", trim: true)

    profiles = [
      "UNIHAN-17.0.0-KMAINLANDTELEGRAPH-DECIMAL-TOKEN",
      "UNIHAN-17.0.0-KTAIWANTELEGRAPH-DECIMAL-TOKEN-READABLE",
      "UNIHAN-17.0.0-KTAIWANTELEGRAPH-DECIMAL-TOKEN-LOSSLESS-VPUA-1",
      "UNIHAN-17.0.0-KGB3-ROW-CELL-DECIMAL-TOKEN"
    ]

    for profile <- profiles do
      assert [row] = Enum.filter(rows, &String.contains?(&1, ",#{profile},")), profile
      assert String.contains?(row, "unicode_property_token_mapping"), profile

      assert String.contains?(row, "https://www.unicode.org/Public/17.0.0/ucd/Unihan.zip"),
             profile

      assert String.contains?(row, ",high,no,,no,"), profile

      assert String.ends_with?(
               String.trim(row),
               ",implemented_property_token_mapping"
             ),
             profile
    end

    generic = Enum.filter(rows, &String.contains?(&1, ",Chinese telegraph code,"))
    assert [generic] = generic
    assert String.ends_with?(String.trim(generic), ",codec_gap")
    refute Enum.any?(profiles, &String.contains?(generic, &1))

    assert [kgb3_gl] =
             Enum.filter(
               rows,
               &String.contains?(&1, ",UNIHAN-17.0.0-KGB3-ROW-CELL-GL,")
             )

    assert kgb3_gl =~ "unicode_property_row_cell_codec"
    assert kgb3_gl =~ ",high,"
    assert kgb3_gl =~ ",yes,"
    assert String.ends_with?(String.trim(kgb3_gl), ",implemented")

    assert [gb13131] = Enum.filter(rows, &String.contains?(&1, ",GB 13131–91,"))
    assert String.ends_with?(String.trim(gb13131), ",codec_gap")
    refute gb13131 =~ "UNIHAN-17.0.0-KGB3-ROW-CELL-GL"

    data_rows = tl(rows)
    assert length(data_rows) == 1_626
    assert Enum.count(data_rows, &String.ends_with?(String.trim(&1), ",implemented")) == 1_331
    assert Enum.count(data_rows, &String.ends_with?(String.trim(&1), ",codec_gap")) == 79

    assert Enum.count(
             data_rows,
             &String.ends_with?(String.trim(&1), ",implemented_property_token_mapping")
           ) == 4

    assert Enum.count(
             data_rows,
             &String.ends_with?(String.trim(&1), ",property_token_mapping_gap")
           ) == 0

    assert File.read!(@catalog_summary) =~
             "Implemented property-token mappings: **4**; property-token mapping gaps: **0**."

    assert File.read!(@catalog_summary) =~
             "Actionable codec gaps: **79**; research candidates: **121**; other audited non-codec/deferred records: **91**."

    assert File.read!(@catalog_manifest) =~ ~s("implemented_property_token_mapping": 4)
    assert File.read!(@catalog_manifest) =~ ~s("property_token_mapping_gap": 0)
    assert File.read!(@catalog_manifest) =~ ~s("implemented": 1331)
    assert File.read!(@catalog_manifest) =~ ~s("codec_gap": 79)
    assert File.read!(@catalog_manifest) =~ ~s("supplement": 134)
  end

  test "RED: KOI8-F is backed by the complete source-qualified NMSU mapping" do
    rows = @catalog |> File.read!() |> String.split("\n", trim: true)
    assert [row] = Enum.filter(rows, &String.contains?(&1, ",KOI8-F,"))

    assert String.contains?(
             row,
             "web.archive.org/web/20200712005106id_/http://sofia.nmsu.edu/~mleisher/Software/csets/KOI8UNI.TXT"
           )

    assert String.contains?(row, "KOI8-F-NMSU-2008")
    assert String.contains?(row, ",high,")
    assert String.contains?(row, ",yes,")
    assert String.contains?(row, "source_qualified_unicode_mapping")
    assert String.ends_with?(String.trim(row), ",implemented")
  end

  test "RED: property-token implementation disposition is backed by the shipped inventory" do
    python = System.find_executable("python3") || flunk("python3 is unavailable")
    generator = Path.expand("../tools/build_encoding_catalog.py", __DIR__)

    probe = """
    import importlib.util
    import sys

    spec = importlib.util.spec_from_file_location("iconvex_catalog", sys.argv[1])
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)

    expected = {
        module.key("UNIHAN-17.0.0-KMAINLANDTELEGRAPH-DECIMAL-TOKEN"),
        module.key("UNIHAN-17.0.0-KTAIWANTELEGRAPH-DECIMAL-TOKEN-READABLE"),
        module.key("UNIHAN-17.0.0-KTAIWANTELEGRAPH-DECIMAL-TOKEN-LOSSLESS-VPUA-1"),
        module.key("UNIHAN-17.0.0-KGB3-ROW-CELL-DECIMAL-TOKEN"),
    }
    assert module.IMPLEMENTED_PROPERTY_TOKEN_MAPPING_KEYS == expected

    for name in expected:
        item = {
            "name": name,
            "kinds": ["unicode_property_token_mapping"],
            "iconvex": "no",
            "confidence": "high",
        }
        assert module.implementation_disposition(item) == "implemented_property_token_mapping"

    for iconvex in ("no", "yes"):
        future = {
            "name": "UNIHAN-FUTURE-RESEARCH-ONLY-PROPERTY-TOKEN",
            "kinds": ["unicode_property_token_mapping"],
            "iconvex": iconvex,
            "confidence": "high",
        }
        assert module.implementation_disposition(future) == "property_token_mapping_gap"

        colliding_future = {
            "name": "Adobe-Japan1",
            "kinds": ["unicode_property_token_mapping"],
            "iconvex": iconvex,
            "confidence": "high",
        }
        assert module.implementation_disposition(colliding_future) == "property_token_mapping_gap"
    """

    {output, status} = System.cmd(python, ["-c", probe, generator], stderr_to_stdout: true)
    assert status == 0, output
  end

  test "RED: every remaining high-confidence codec gap has an exact blocker audit" do
    catalog_lines = @catalog |> File.read!() |> String.split("\n")

    catalog_gaps =
      catalog_lines
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(String.contains?(&1, ",high,") and String.ends_with?(&1, ",codec_gap")))
      |> Enum.map(fn line ->
        [_, name | _] = csv_fields(line)
        name
      end)
      |> Enum.sort()

    [header | rows] = @high_gap_audit |> File.read!() |> String.split("\n", trim: true)
    assert header == "canonical\tauthority\tartifact_checked\tblocking_evidence"

    audited =
      Enum.map(rows, fn row ->
        [canonical, authority, artifact, blocker] = String.split(row, "\t")
        assert authority != ""
        assert artifact != ""
        assert blocker != ""
        canonical
      end)
      |> Enum.sort()

    assert length(audited) == 33
    assert audited == catalog_gaps
  end

  test "OpenJDK internal helpers are classified as components rather than public codec gaps" do
    lines = @catalog |> File.read!() |> String.split("\n")

    for name <- [
          "SimpleEUCEncoder",
          "x-JIS0208_MS5022X",
          "x-JIS0208_MS932",
          "x-JIS0208_Solaris",
          "x-JIS0212_MS5022X",
          "x-JIS0212_Solaris"
        ] do
      row = Enum.find(lines, &String.contains?(&1, name))
      assert row, name
      assert String.contains?(row, ",openjdk_internal_component,candidate,")
    end
  end

  test "GPL-derived OpenJDK variants are explicit codec gaps" do
    lines = @catalog |> File.read!() |> String.split("\n")

    for name <- [
          "x-eucJP-Open",
          "x-MS950-HKSCS-XP",
          "x-windows-50220",
          "x-windows-50221",
          "x-windows-iso2022jp",
          "x-ISO-2022-CN-GB",
          "x-ISO-2022-CN-CNS"
        ] do
      row = Enum.find(lines, &String.contains?(&1, ",#{name},"))
      assert row
      assert String.contains?(row, ",no,")
      assert String.ends_with?(String.trim(row), ",codec_gap")
    end
  end

  test "RED: RFC 3492 Punycode is source-bound and implemented externally" do
    row =
      @catalog
      |> File.read!()
      |> String.split("\n")
      |> Enum.find(&String.contains?(&1, ",Punycode,"))

    assert row
    assert String.contains?(row, "RFC-3492")
    assert String.contains?(row, "rfc3492")
    assert String.contains?(row, "https://www.rfc-editor.org/rfc/rfc3492")
    assert String.contains?(row, ",yes,")
    assert String.ends_with?(String.trim(row), ",implemented")
  end

  test "RED: primary punched-card profiles are source-bound and versioned" do
    rows = @catalog |> File.read!() |> String.split("\n")

    expected = %{
      "IBM H code (report-writing)" => {"IBM-7040-H-REPORT", "22-6732-1_7040StudentText.pdf"},
      "IBM H code (programming)" => {"IBM-7040-H-PROGRAM", "22-6732-1_7040StudentText.pdf"},
      "IBM 1401 card code" => {"IBM-1401-CARD", "A24-1403-5_1401_Reference_Apr62.pdf"},
      "CDC-167-BCD-HOLLERITH-1965" =>
        {"CDC-167-BCD-HOLLERITH-1965", "60022000D_167-2_Card_Reader_Reference_196502.pdf"},
      "CDC-6000-STANDARD-HOLLERITH-1970" =>
        {"CDC-6000-STANDARD-HOLLERITH-1970",
         "44616800-03_Interactive_Graphics_System_Prelim_Ref_197001.pdf"}
    }

    for {title, {runtime_name, source}} <- expected do
      matching = Enum.filter(rows, &String.contains?(&1, ",#{title},"))
      assert [row] = matching, title
      assert String.contains?(row, runtime_name), title
      assert String.contains?(row, source), title
      assert String.contains?(row, ",yes,"), title
      assert String.ends_with?(String.trim(row), ",implemented"), title
    end

    generic = Enum.find(rows, &String.contains?(&1, ",CDC punched-card BCD,"))
    assert generic
    assert String.starts_with?(generic, "ENC-0091,")
    assert String.contains?(generic, "BCD-CDC")
    assert String.ends_with?(String.trim(generic), ",codec_gap")

    reconstructed =
      Enum.find(rows, &String.contains?(&1, ",CDC punched-card BCD (Iowa reconstruction),"))

    assert reconstructed
    assert String.starts_with?(reconstructed, "ENC-0092,")
    assert String.contains?(reconstructed, "BCD-CDC-IOWA")
    assert String.contains?(reconstructed, "source_qualified_punched_card_encoding")
    assert String.contains?(reconstructed, ",medium,")
    assert String.contains?(reconstructed, ",no,,yes,")
    assert String.ends_with?(String.trim(reconstructed), ",implemented")
  end

  test "RED: generic Transcode stays open while both IBM six-bit profiles are exact" do
    rows = @catalog |> File.read!() |> String.split("\n", trim: true)

    assert [generic] = Enum.filter(rows, &String.contains?(&1, ",Transcode,"))
    assert String.starts_with?(generic, "ENC-1413,")
    assert String.contains?(generic, "six-bit code units")
    refute String.contains?(generic, "width 7 bits")
    assert String.contains?(generic, "GA27-3005-3-2780_Data_Terminal_Description_Aug71.pdf")

    assert String.contains?(
             generic,
             "GA27-3004-2_General_Information_Binary_Synchronous_Communications_Oct70.pdf"
           )

    refute String.contains?(generic, "\\|")
    assert String.ends_with?(String.trim(generic), ",3,codec_gap")
    assert String.ends_with?(String.trim(generic), ",codec_gap")

    profiles = [
      {"Transcode (IBM 2780 GA27-3005-3)", "IBM-2780-SIX-BIT-TRANSCODE-GA27-3005-3",
       "GA27-3005-3", "U+2311"},
      {"Transcode (IBM BSC GA27-3004-2)", "IBM-BSC-SIX-BIT-TRANSCODE-GA27-3004-2", "GA27-3004-2",
       "U+003C"}
    ]

    for {name, canonical, manual, divergent_scalar} <- profiles do
      assert [row] = Enum.filter(rows, &String.contains?(&1, ",#{name},")), name
      assert String.contains?(row, canonical), name
      assert String.contains?(row, manual), name
      assert String.contains?(row, divergent_scalar), name
      assert String.contains?(row, "source_qualified_six_bit_telecom_encoding"), name
      assert String.contains?(row, ",high,"), name
      assert String.contains?(row, ",yes,"), name
      assert String.ends_with?(String.trim(row), ",implemented"), name
    end

    data_rows = tl(rows)
    assert length(data_rows) == 1_626
    assert Enum.count(data_rows, &String.ends_with?(String.trim(&1), ",implemented")) == 1_331
    assert Enum.count(data_rows, &String.ends_with?(String.trim(&1), ",codec_gap")) == 79
    assert File.read!(@catalog_manifest) =~ ~s("implemented": 1331)
    assert File.read!(@catalog_manifest) =~ ~s("codec_gap": 79)
    assert File.read!(@catalog_manifest) =~ ~s("supplement": 134)
  end

  test "audited ICU stateful codecs are marked implemented" do
    lines = @catalog |> File.read!() |> String.split("\n")

    for name <- ["JIS7", "JIS8", "LMBCS-1", "x11-compound-text"] do
      row = Enum.find(lines, &String.contains?(&1, ",#{name},"))
      assert row
      assert String.contains?(row, ",yes,")
    end
  end

  test "RED: every executable ICU LMBCS optimization group is explicit" do
    rows = @catalog |> File.read!() |> String.split("\n")
    executable_groups = [1, 2, 3, 4, 5, 6, 8, 11, 16, 17, 18, 19]

    for group <- executable_groups do
      name = "LMBCS-#{group}"
      matching = Enum.filter(rows, &String.contains?(&1, ",#{name},"))
      assert [row] = matching, name
      assert String.contains?(row, "ucnv_lmb.cpp"), name
      assert String.contains?(row, ",yes,"), name
      assert String.ends_with?(String.trim(row), ",implemented"), name
    end

    for undefined_group <- [7, 9, 10, 12, 13, 14, 15, 20] do
      refute Enum.any?(rows, &String.contains?(&1, ",LMBCS-#{undefined_group},"))
    end
  end

  test "RED: exact IBM composite/revision profiles and DEC 1994 pages are explicit" do
    rows = @catalog |> File.read!() |> String.split("\n")

    implemented = [
      {"IBM-310-293-P100-COMPOSITE-VPUA", "CP00310.txt"},
      {"IBM-TNZ-CP310-B1EAE3C", "IBM/tnz/blob/b1eae3c"},
      {"IBM-907-CDRA-P100-VPUA-COMPOSITE", "cp00907z.pdf"},
      {"IBM-1116-850-P100-COMPOSITE", "cp01116z.pdf"},
      {"IBM-1117-437-P100-COMPOSITE", "cp01117z.pdf"},
      {"DEC-GREEK-8-1994", "PPLV2PMB.PDF"},
      {"DEC-TURKISH-8-1994", "PPLV2PMB.PDF"}
    ]

    for {name, source_marker} <- implemented do
      matching = Enum.filter(rows, &String.contains?(&1, ",#{name},"))
      assert [row] = matching, name
      assert String.contains?(row, source_marker), name
      assert String.contains?(row, ",high,"), name
      assert String.contains?(row, ",yes,"), name
      assert String.ends_with?(String.trim(row), ",implemented"), name
    end

    # These composite/revision profiles do not claim to be generic mappings
    # for the under-specified IBM pages.  The four generic catalog records must
    # therefore remain gaps until an exact Unicode profile is selected.
    for generic <- ["Code page 310", "Code page 907", "Code page 1116", "Code page 1117"] do
      matching = Enum.filter(rows, &String.contains?(&1, ",#{generic},"))
      assert [row] = matching, generic
      assert String.ends_with?(String.trim(row), ",codec_gap"), generic
    end

    # CP1287/1288 are the exact DEC Greek/Turkish 1994 profiles and must merge
    # into the corresponding source-bound rows rather than remain generic gaps.
    for {name, alias_name} <- [
          {"DEC-GREEK-8-1994", "IBM-1287"},
          {"DEC-TURKISH-8-1994", "IBM-1288"}
        ] do
      row = Enum.find(rows, &String.contains?(&1, ",#{name},"))
      assert row
      assert String.contains?(row, alias_name)
      assert String.ends_with?(String.trim(row), ",implemented")
    end
  end

  test "RED: authoritative FIELDATA and TI-83 profiles are source-bound" do
    rows = @catalog |> File.read!() |> String.split("\n")

    implemented = %{
      "UNIVAC 1100 Series FIELDATA" =>
        {"UP-7824r1_EXEC_8",
         [
           "FIELDATA-UNIVAC-1100",
           "UNIVAC-1100-FIELDATA",
           "FIELDATA-1100",
           "UNISYS-FIELDATA",
           "EXEC-8-FIELDATA",
           "UNIVAC-1106-FIELDATA",
           "UNIVAC-1108-FIELDATA"
         ]},
      "UNIVAC 4009 FIELDATA" =>
        {"UP-7604r1_1106_1108",
         for(
           suffix <- ["INPUT", "OUTPUT", "LOSSLESS-VPUA", "RAW-VPUA"],
           prefix <- ["FIELDATA-UNIVAC-4009", "UNIVAC-4009-FIELDATA"],
           do: "#{prefix}-#{suffix}"
         )},
      "TI-83 Plus character set" =>
        {"sdk83pguide.pdf",
         for(
           font <- ["LARGE", "SMALL"],
           suffix <- ["", "-LOSSLESS-VPUA", "-RAW-VPUA"],
           do: "TI-83-PLUS-#{font}#{suffix}"
         )}
    }

    for {name, {source_marker, runtime_labels}} <- implemented do
      matching = Enum.filter(rows, &String.contains?(&1, ",#{name},"))
      assert [row] = matching, name
      assert String.contains?(row, source_marker), name
      assert String.contains?(row, ",high,"), name
      assert String.contains?(row, ",yes,"), name
      assert String.ends_with?(String.trim(row), ",implemented"), name

      for runtime_label <- runtime_labels do
        assert String.contains?(row, runtime_label), "#{name}: #{runtime_label}"
      end
    end

    univac_1100 = Enum.find(rows, &String.contains?(&1, ",UNIVAC 1100 Series FIELDATA,"))
    refute String.contains?(univac_1100, "UNIVAC-FIELDATA")
    refute String.contains?(univac_1100, "FIELDATA-UNIVAC |")

    refute @high_gap_audit
           |> File.read!()
           |> String.contains?("TI-83 Plus character set\t")

    umbrella = Enum.find(rows, &String.contains?(&1, ",Fieldata,"))
    assert umbrella
    assert String.ends_with?(String.trim(umbrella), ",encoding_family")
  end

  test "Wikipedia's 'Code page N' titles match implemented CP aliases" do
    lines = @catalog |> File.read!() |> String.split("\n")

    for name <- ["Code page 437", "Code page 708", "Code page 720"] do
      row = Enum.find(lines, &String.contains?(&1, ",#{name},"))
      assert row
      assert String.contains?(row, ",yes,")
    end
  end

  test "RED: IBM 932 and 949 research titles join the pinned GNU codec identities" do
    rows = @catalog |> File.read!() |> String.split("\n", trim: true)
    gnu_definitions = File.read!(@gnu_definitions)
    runtime_names = File.read!(@runtime_names)

    assert Regex.match?(~r/DEFALIAS\(\s*"IBM-932".*?cp932\)/s, gnu_definitions)
    assert Regex.match?(~r/DEFALIAS\(\s*"IBM-949".*?cp949\)/s, gnu_definitions)
    assert String.contains?(runtime_names, "IBM-932,CP932")
    assert String.contains?(runtime_names, "IBM-949,CP949")

    assert [cp932] = Enum.filter(rows, &String.contains?(&1, "wikidata:Q25000674"))
    assert String.contains?(cp932, ",CP932,")
    assert String.contains?(cp932, "IBM Code page 932")
    assert String.contains?(cp932, "Code page 932 (IBM)")
    assert String.contains?(cp932, "wikipedia:pageid 2996905")
    assert String.contains?(cp932, ",yes,CP932,yes,")
    assert String.ends_with?(String.trim(cp932), ",implemented")

    assert [cp949] =
             Enum.filter(rows, &String.contains?(&1, "wikipedia:pageid 49785516"))

    assert String.contains?(cp949, ",CP949,")
    assert String.contains?(cp949, "Code page 949 (IBM)")
    assert String.contains?(cp949, "IBM-949")
    assert String.contains?(cp949, ",yes,CP949,yes,")
    assert String.ends_with?(String.trim(cp949), ",implemented")

    unsupported = File.read!(@gnu_unsupported)
    refute String.contains?(unsupported, "wikidata:Q25000674")
    refute String.contains?(unsupported, "wikipedia:pageid 2996905")
    refute String.contains?(unsupported, "wikidata:Q48739550")
    refute String.contains?(unsupported, "wikipedia:pageid 49785516")
  end

  test "RED: unlabeled Wikidata Q17190477 uses its authoritative U-PRESS label" do
    rows = @catalog |> File.read!() |> String.split("\n", trim: true)

    refute Enum.any?(rows, &String.contains?(&1, ",Q17190477,"))
    assert [u_press] = Enum.filter(rows, &String.contains?(&1, ",U-PRESS,"))
    assert String.contains?(u_press, "wikidata:Q17190477")
    assert String.contains?(u_press, "https://www.wikidata.org/wiki/Q17190477")
    assert String.ends_with?(String.trim(u_press), ",codec_gap")

    assert File.read!(@gnu_unsupported) =~ ",U-PRESS,"
  end

  test "Wikipedia titles for already implemented authoritative mappings are bridged" do
    lines = @catalog |> File.read!() |> String.split("\n")

    for name <- [
          "Indian Script Code for Information Interchange",
          "DEC Radix-50",
          "DEC SIXBIT/ECMA-1",
          "Mac OS Devanagari encoding",
          "Mac OS Keyboard encoding",
          "Mac OS Sámi",
          "MacArabic encoding",
          "Tamil Script Code for Information Interchange",
          "ZX Spectrum +3 character set"
        ] do
      row = Enum.find(lines, &String.contains?(&1, name))
      assert row
      assert String.contains?(row, ",yes,"), name
      assert String.ends_with?(String.trim(row), ",implemented"), name
    end
  end

  test "RED: audited descriptive titles join their exact implemented codecs" do
    rows = @catalog |> File.read!() |> String.split("\n")

    exact = [
      {"American National Standard for Extended Latin Alphabet Coded Character Set for Bibliographic Use",
       "ANSEL"},
      {"Binary Ordered Compression for Unicode", "BOCU-1"},
      {"CCIT 2", "ITA2"},
      {"Compatibility Encoding Scheme for UTF-16: 8-Bit", "CESU-8"},
      {"HKSCS-1999", "BIG5-HKSCS:1999"},
      {"HKSCS-2001", "BIG5-HKSCS:2001"},
      {"HKSCS-2004", "BIG5-HKSCS:2004"},
      {"HKSCS-2008", "Big5-HKSCS"},
      {"ITU T.51", "ISO_6937"},
      {"T.51/ISO/IEC 6937", "ISO_6937"},
      {"KOI8-E", "ECMA-cyrillic"},
      {"Mazovia encoding", "MAZOVIA"},
      {"MIK code page", "MIK"},
      {"NeXT character set", "NEXTSTEP"},
      {"NeXT code page", "NEXTSTEP"},
      {"Standard Compression Scheme for Unicode", "SCSU"},
      {"Wobbly Transformation Format", "WTF-8"}
    ]

    for {title, canonical} <- exact do
      matching =
        Enum.filter(rows, fn row ->
          String.contains?(row, ",#{title},") or
            String.contains?(row, ",#{title} |") or
            String.contains?(row, "| #{title} |") or
            String.contains?(row, "| #{title},")
        end)

      assert [row] = matching, title
      assert String.contains?(row, canonical), "#{title} did not join #{canonical}"
      assert String.ends_with?(String.trim(row), ",implemented"), title
    end
  end

  test "RED: aggregate standards and repertoires are not counted as missing codecs" do
    rows = @catalog |> File.read!() |> String.split("\n")

    expected = %{
      "ArmSCII" => "encoding_family",
      "Compatibility Encoding Scheme for UTF-16" => "encoding_family",
      "GOST 10859" => "encoding_family",
      "HKSCS" => "repertoire_profile",
      "HKSCS IDS" => "mapping_notation",
      "JUS I.B1.003" => "encoding_family",
      "KOI8-B" => "repertoire_profile",
      "Teletext" => "encoding_family",
      "Teletext character set" => "encoding_family",
      "UTF-9 and UTF-18" => "encoding_family"
    }

    for {name, disposition} <- expected do
      row = Enum.find(rows, &String.contains?(&1, ",#{name},"))
      assert row, name
      assert String.ends_with?(String.trim(row), ",#{disposition}"), name
    end
  end

  test "RED: adjacent formats and umbrella records have conservative dispositions" do
    rows = @catalog |> File.read!() |> String.split("\n")

    expected = %{
      "Adobe-Japan1" => "repertoire_profile",
      "Advanced Video Attribute Terminal Assembler and Recreator" => "terminal_protocol",
      "alphanumeric" => "repertoire_abstraction",
      "base 45" => "binary_transform",
      "base64-codec" => "binary_transform",
      "BCDIC" => "encoding_family",
      "Bookshelf Symbol 7" => "font_identity",
      "Braille code" => "writing_system",
      "bz2-codec" => "compression_transform",
      "Cariadings" => "font_identity",
      "Casio calculator character sets" => "encoding_family",
      "Fieldata" => "encoding_family",
      "hex-codec" => "binary_transform",
      "International maritime signal flags" => "visual_signaling_system",
      "JIS kanji codes" => "encoding_family",
      "JIS X 0211" => "control_standard",
      "JIS X 0213" => "repertoire_profile",
      "JIS X 0221" => "encoding_family",
      "Juki Toitsu Moji" => "repertoire_profile",
      "Lotus Multi-Byte Character Set" => "encoding_family",
      "Marlett" => "font_identity",
      "mbcs" => "platform_adapter",
      "Microsoft Standard Japanese Character Set" => "repertoire_profile",
      "Moji Joho Kiban Ideographs" => "repertoire_profile",
      "Q11496598" => "repertoire_profile",
      "Q65228706" => "repertoire_profile",
      "Q65274238" => "repertoire_profile",
      "quopri-codec" => "binary_transform",
      "rot-13" => "text_transform",
      "SignWriting in Unicode" => "unicode_representation_profile",
      "Six-bit character code" => "encoding_family",
      "Swedish ASCII" => "encoding_family",
      "Symbol" => "font_identity",
      "The Unicode® Standard" => "encoding_family",
      "TI calculator character sets" => "encoding_family",
      "Unicode emoji variation sequence" => "unicode_sequence_profile",
      "Unicode variation sequence" => "unicode_sequence_mechanism",
      "URW Dingbats" => "font_identity",
      "uu-codec" => "binary_transform",
      "variable-length code" => "coding_technique",
      "Videotex character set" => "encoding_family",
      "Webdings" => "font_identity",
      "Wingdings" => "font_identity",
      "Wingdings 2" => "font_identity",
      "Wingdings 3" => "font_identity",
      "YUSCII" => "encoding_family",
      "zlib-codec" => "compression_transform"
    }

    for {name, disposition} <- expected do
      row = Enum.find(rows, &String.contains?(&1, ",#{name},"))
      assert row, name
      assert String.ends_with?(String.trim(row), ",#{disposition}"), name
    end

    for unresolved <- ["Mojikyō", "U-PRESS"] do
      row = Enum.find(rows, &String.contains?(&1, ",#{unresolved},"))
      assert row, unresolved
      assert String.ends_with?(String.trim(row), ",codec_gap"), unresolved
    end
  end

  test "RED: Wikidata Q8815 joins the exact US-ASCII identity" do
    matching =
      @catalog
      |> File.read!()
      |> String.split("\n")
      |> Enum.filter(&String.contains?(&1, "Q8815"))

    assert [row] = matching
    assert String.contains?(row, ",US-ASCII,")
    assert String.contains?(row, "https://www.wikidata.org/wiki/Q8815")
    assert String.contains?(row, "https://www.rfc-editor.org/rfc/rfc20")
    assert String.contains?(row, ",yes,US-ASCII,")
    assert String.ends_with?(String.trim(row), ",implemented")
  end

  test "RED: audited classic-Mac titles join the correct versioned identity group" do
    rows = @catalog |> File.read!() |> String.split("\n")

    groups = [
      {"Mac OS Central European encoding", "MacCentralEurope"},
      {"Macintosh Central European encoding", "MacCentralEurope"},
      {"Mac OS Chinese Simplified", "Mac OS Chinsimp"},
      {"Mac OS Croatian encoding", "MacCroatian"},
      {"MacCroatian encoding", "MacCroatian"},
      {"Mac OS Cyrillic encoding", "x-mac-cyrillic"},
      {"Macintosh Cyrillic encoding", "x-mac-cyrillic"},
      {"Mac OS Greek encoding", "MacGreek"},
      {"Mac OS Icelandic encoding", "MacIceland"},
      {"Mac OS Romanian encoding", "Mac OS Romanian"},
      {"MacRomanian encoding", "Mac OS Romanian"},
      {"Mac OS Turkish encoding", "MacTurkish"},
      {"MacTurkish encoding", "MacTurkish"},
      {"Mac OS Ukrainian encoding", "MacUkraine"},
      {"Macintosh Ukrainian encoding", "MacUkraine"},
      {"Macintosh Latin encoding", "MACINTOSH-LATIN"}
    ]

    for {title, identity} <- groups do
      matching =
        Enum.filter(rows, fn row ->
          String.contains?(row, ",#{title},") or
            String.contains?(row, ",#{title} |") or
            String.contains?(row, "| #{title} |") or
            String.contains?(row, "| #{title},")
        end)

      assert [row] = matching, title
      assert String.contains?(row, identity), "#{title} did not join #{identity}"
      assert String.ends_with?(String.trim(row), ",implemented"), title
    end
  end

  test "DEC Radix-50 is backed by distinct PDP-9, PDP-10, and PDP-11 manuals" do
    row =
      @catalog
      |> File.read!()
      |> String.split("\n")
      |> Enum.find(&String.contains?(&1, ",DEC Radix-50,"))

    assert row
    assert String.contains?(row, "DEC-9A-GUAB-D_UTILITIES.pdf")
    assert String.contains?(row, "AA-C780C-TB_Macro_Assembler_Reference_Manual_Apr78.pdf")
    assert String.contains?(row, "DEC-11-LFLRA_FORTRAN_Language_Reference_Manual_Jun77.pdf")
    assert String.contains?(row, "DEC-RADIX-50-18BIT")
    assert String.contains?(row, "DEC-RADIX-50-36BIT")
    assert String.ends_with?(String.trim(row), ",implemented")
  end

  test "CDC Display Code is backed by its NOS 63/64-character tables" do
    row =
      @catalog
      |> File.read!()
      |> String.split("\n")
      |> Enum.find(&String.contains?(&1, ",CDC display code,"))

    assert row
    assert String.contains?(row, "60435600L_NOS_Version_1_Operators_Guide_May1980.pdf")
    assert String.contains?(row, "CDC-DISPLAY-CODE-63")
    assert String.contains?(row, "CDC-DISPLAY-CODE-64")
    assert String.contains?(row, "CDC-DISPLAY-CODE-ASCII-63")
    assert String.contains?(row, "CDC-DISPLAY-CODE-ASCII-64")
    assert String.contains?(row, "CDC-6-12-DISPLAY-CODE-63")
    assert String.contains?(row, "CDC-6-12-DISPLAY-CODE-64")
    assert String.ends_with?(String.trim(row), ",implemented")
  end

  test "DEC terminal glyph-set identities converge on the pinned VT3xx tables" do
    rows =
      @catalog
      |> File.read!()
      |> String.split("\n")

    special_rows =
      Enum.filter(rows, fn row ->
        String.contains?(row, ",DEC Special Graphics,") or
          String.contains?(row, ",DEC Special Graphics character set,") or
          String.contains?(row, ",DEC-SPECIAL,")
      end)

    technical_rows =
      Enum.filter(rows, fn row ->
        String.contains?(row, ",DEC Technical Character Set,") or
          String.contains?(row, ",DEC-TECHNICAL,")
      end)

    assert [special] = special_rows
    assert String.contains?(special, "DEC-SPECIAL-GR")
    assert String.contains?(special, "VT100-LINE-DRAWING")
    assert String.contains?(special, "EK-VT3XX-TP-002")
    assert String.contains?(special, ",high,")
    assert String.ends_with?(String.trim(special), ",implemented")

    assert [technical] = technical_rows
    assert String.contains?(technical, "DEC-TECHNICAL-GR")
    assert String.contains?(technical, "VT300-TECHNICAL")
    assert String.contains?(technical, "EK-VT3XX-TP-002")
    assert String.contains?(technical, ",high,")
    assert String.ends_with?(String.trim(technical), ",implemented")
  end

  test "RED: SI 960 and DEC Hebrew retain separate source-bound identities" do
    rows =
      @catalog
      |> File.read!()
      |> String.split("\n")

    si960_rows =
      Enum.filter(rows, fn row ->
        String.contains?(row, ",SI 960,") or String.contains?(row, ",HEBREW-7,")
      end)

    dec_hebrew_rows = Enum.filter(rows, &String.contains?(&1, ",DEC Hebrew,"))

    assert [si960] = si960_rows
    assert String.contains?(si960, "SI 960")
    assert String.contains?(si960, "SI-960")
    assert String.contains?(si960, "HEBREW-7")

    assert String.contains?(
             si960,
             "Kennelly_Digital_Guide_To_Developing_International_Software_1991.pdf"
           )

    refute String.contains?(si960, "DEC-HEBREW-8")
    assert String.ends_with?(String.trim(si960), ",implemented")

    assert [dec_hebrew] = dec_hebrew_rows
    assert String.contains?(dec_hebrew, "DEC-HEBREW-8")
    assert String.contains?(dec_hebrew, "DEC-HEBREW-8BIT")

    assert String.contains?(
             dec_hebrew,
             "Kennelly_Digital_Guide_To_Developing_International_Software_1991.pdf"
           )

    refute String.contains?(dec_hebrew, "SI-960")
    refute String.contains?(dec_hebrew, "HEBREW-7")
    assert String.ends_with?(String.trim(dec_hebrew), ",implemented")
  end

  test "RED: exact Kermit legacy titles join byte-identical implemented codecs" do
    rows = @catalog |> File.read!() |> String.split("\n")

    exact = [
      {"ARABIC-ISO", "ISO-8859-6"},
      {"CYRILLIC-ISO", "ISO-8859-5"},
      {"LATIN1-ISO", "ISO-8859-1"},
      {"LATIN2-ISO", "ISO-8859-2"},
      {"LATIN3-ISO", "ISO-8859-3"},
      {"LATIN4-ISO", "ISO-8859-4"},
      {"LATIN5-ISO", "ISO-8859-9"},
      {"LATIN9-ISO", "ISO-8859-15"},
      {"KOI8-CRYILLIC", "KOI-8"},
      {"CANADIAN-FRENCH", "CSA_Z243.4-1985-1"},
      {"DANISH", "DS_2089"},
      {"FRENCH", "NF_Z_62-010_(1973)"},
      {"GERMAN", "DIN_66003"},
      {"ITALIAN", "IT"},
      {"JAPANESE-ROMAN", "JIS_C6220-1969-ro"},
      {"SPANISH", "ES"}
    ]

    for {legacy, canonical} <- exact do
      refute Enum.any?(rows, &String.contains?(&1, ",#{legacy},")),
             "#{legacy} remained a standalone catalog row"

      row = Enum.find(rows, &String.contains?(&1, ",#{canonical},"))
      assert row, "missing canonical row #{canonical}"
      assert String.contains?(row, legacy)
      assert String.ends_with?(String.trim(row), ",implemented")
    end

    # The four previously distinct mappings now have exact versioned native
    # profiles. ELOT 928 and Greek ISO are byte-identical and therefore join;
    # the other three stay separate from their near-match modern codecs.
    refute Enum.any?(rows, fn row ->
             match?([_catalog_id, "ELOT928-GREEK", _rest], String.split(row, ",", parts: 3))
           end)

    greek = Enum.find(rows, &String.contains?(&1, ",GREEK-ISO,"))
    assert greek
    assert String.contains?(greek, "ELOT928-GREEK")
    assert String.contains?(greek, ",yes,")
    assert String.ends_with?(String.trim(greek), ",implemented")

    for distinct <- ["HEBREW-ISO", "LATIN6-ISO", "MACINTOSH-LATIN"] do
      row = Enum.find(rows, &String.contains?(&1, ",#{distinct},"))
      assert row, distinct
      assert String.contains?(row, ",yes,"), distinct
      assert String.ends_with?(String.trim(row), ",implemented"), distinct
    end
  end

  test "RED: Short KOI joins the KOI-7 research title as an implemented codec" do
    rows = @catalog |> File.read!() |> String.split("\n")

    refute Enum.any?(rows, &String.contains?(&1, ",KOI7,"))

    row = Enum.find(rows, &String.contains?(&1, ",SHORT-KOI,"))
    assert row
    assert String.contains?(row, "KOI7")
    assert String.contains?(row, ",yes,")
    assert String.ends_with?(String.trim(row), ",implemented")
  end

  test "RED: standard and Kermit ELOT 927 profiles have distinct implemented rows" do
    rows = @catalog |> File.read!() |> String.split("\n")

    refute Enum.any?(rows, &String.contains?(&1, ",ELOT 927,"))

    standard = Enum.find(rows, &String.contains?(&1, ",greek7,"))
    assert standard
    assert String.contains?(standard, "ELOT 927")
    assert String.ends_with?(String.trim(standard), ",implemented")

    kermit = Enum.find(rows, &String.contains?(&1, ",ELOT927-GREEK,"))
    assert kermit
    assert String.contains?(kermit, ",yes,")
    assert String.ends_with?(String.trim(kermit), ",implemented")
  end

  test "RED: EBCDIC numeric titles and DEC Multinational join exact implemented codecs" do
    lines = @catalog |> File.read!() |> String.split("\n")

    for number <- [
          "037",
          "1025",
          "1026",
          "1047",
          "273",
          "277",
          "278",
          "280",
          "284",
          "285",
          "297",
          "423",
          "424",
          "500",
          "870",
          "871",
          "875",
          "880",
          "905",
          "924"
        ] do
      matching = Enum.filter(lines, &String.contains?(&1, "EBCDIC #{number}"))
      assert [row] = matching
      assert String.contains?(row, ",yes,IBM-#{number},"), number
      assert String.ends_with?(String.trim(row), ",implemented"), number
    end

    dec_mcs = Enum.filter(lines, &String.contains?(&1, "Multinational Character Set"))
    assert [dec_mcs] = dec_mcs
    assert String.contains?(dec_mcs, ",DEC-MCS,")
    assert String.ends_with?(String.trim(dec_mcs), ",implemented")

    for unresolved <- ["EBCDIC 001", "EBCDIC 8859"] do
      row = Enum.find(lines, &String.contains?(&1, ",#{unresolved},"))
      assert row
      assert String.ends_with?(String.trim(row), ",codec_gap")
    end
  end

  test "standards and repertoire families are not misreported as byte codecs" do
    lines = @catalog |> File.read!() |> String.split("\n")

    expected = %{
      "EBCDIC" => "encoding_family",
      "ECMA-48" => "control_standard",
      "ECMA-6" => "encoding_family",
      "ISO 646" => "encoding_family",
      "ISO/IEC 10646 (Unicode)" => "encoding_family",
      "ISO/IEC 8859" => "encoding_family",
      "ISO/IEC 8859-12" => "withdrawn_unassigned_part",
      "Portable character set" => "repertoire_abstraction"
    }

    for {name, disposition} <- expected do
      row = Enum.find(lines, &String.contains?(&1, ",#{name},"))
      assert row
      assert String.ends_with?(String.trim(row), ",#{disposition}"), name
    end
  end

  test "ISO/IEC 8859 part titles merge with GNU and Iconvex spellings" do
    lines = @catalog |> File.read!() |> String.split("\n")

    for name <- ["ISO/IEC 8859-1", "ISO/IEC 8859-2", "ISO/IEC 8859-16"] do
      row = Enum.find(lines, &String.contains?(&1, name))
      assert row
      assert String.contains?(row, ",yes,ISO-8859-"), name
      assert String.ends_with?(String.trim(row), ",implemented"), name
    end
  end

  test "Unicode mapping components and IANA PCL symbol sets are marked implemented" do
    lines = @catalog |> File.read!() |> String.split("\n")

    for name <- ["HANGUL", "IBMGRAPH", "HP-DeskTop", "Ventura-Math"] do
      row = Enum.find(lines, &String.contains?(&1, ",#{name},"))
      assert row
      assert String.contains?(row, ",yes,")
    end
  end

  test "WG2 N5028 legacy computer families are marked implemented" do
    lines = @catalog |> File.read!() |> String.split("\n")

    for name <- [
          "Amstrad CPC character set",
          "Apple II character set",
          "ATASCII",
          "PETSCII",
          "TRS-80 character set",
          "ZX Spectrum character set"
        ] do
      row = Enum.find(lines, &String.contains?(&1, ",#{name},"))
      assert row
      assert String.contains?(row, ",yes,")
    end
  end

  test "audited ISO-IR graphic sets are not reported as research gaps" do
    lines = @catalog |> File.read!() |> String.split("\n")

    for name <- [
          "Arabic Character Set CODAR-U IERA (Morocco)",
          "Blissymbol Graphic Character Set",
          "DPRK Standard Korean Graphic Character Set for Information Interchange",
          "Extended Graphic Character Set for Bibliography ISO 5426-1980",
          "Japanese Character Set JISC C 6226-1978",
          "Mosaic-1 Set of Data Syntax I of CCITT Rec. T.101",
          "Technical Character Set No.1: IEC Publication 1289"
        ] do
      row = Enum.find(lines, &String.contains?(&1, ",#{name},"))
      assert row
      assert String.contains?(row, ",yes,")
    end
  end

  test "valid IBM UTF-16 CCSIDs are supported while retired 61952 is not" do
    lines = @catalog |> File.read!() |> String.split("\n")

    for name <- ["IBM-1200", "IBM-13488", "IBM-5054"] do
      row = Enum.find(lines, &String.contains?(&1, ",#{name},"))
      assert row
      assert String.contains?(row, ",yes,")
    end

    retired = Enum.find(lines, &String.contains?(&1, ",IBM-61952,"))
    assert retired
    assert String.contains?(retired, ",no,")
  end

  test "runtime-inventoried telecom standards are not reported as research gaps" do
    lines = @catalog |> File.read!() |> String.split("\n")

    for name <- [
          "Baudot code / ITA1",
          "International Telegraph Alphabet No. 1",
          "International Telegraph Alphabet No. 2",
          "International Telegraph Alphabet No. 3",
          "ITA3",
          "Morse code",
          "Recommendation V.3 IA5"
        ] do
      row = Enum.find(lines, &String.contains?(&1, ",#{name},"))
      assert row
      assert String.contains?(row, ",yes,")
    end
  end

  test "all DEC national replacement titles resolve to audited runtime codecs" do
    lines = @catalog |> File.read!() |> String.split("\n")

    for name <- [
          "BRITISH",
          "DUTCH",
          "FINNISH",
          "NORWEGIAN",
          "PORTUGUESE",
          "SWEDISH",
          "SWISS"
        ] do
      row = Enum.find(lines, &String.contains?(&1, name))
      assert row, name
      assert String.contains?(row, ",yes,"), name
      assert String.ends_with?(String.trim(row), ",implemented"), name
    end
  end

  test "RED: exact Kermit DG, HP, and SNI subsets close only audited catalog gaps" do
    lines = @catalog |> File.read!() |> String.split("\n")

    for name <- [
          "DG-LINEDRAWING",
          "DG-WORDPROCESSING",
          "HP-MATH-TECHNICAL",
          "SNI-BRACKETS",
          "SNI-EURO",
          "SNI-FACET",
          "SNI-IBM"
        ] do
      row = Enum.find(lines, &String.contains?(&1, ",#{name},"))
      assert row, name
      assert String.contains?(row, ",yes,"), name
      assert String.ends_with?(String.trim(row), ",implemented"), name
    end

    for unchecked <- ["DG-SPECIALGRAPHICS", "HP-LINE-DRAWING"] do
      row = Enum.find(lines, &String.contains?(&1, ",#{unchecked},"))
      assert row, unchecked
      assert String.contains?(row, ",no,"), unchecked
      assert String.ends_with?(String.trim(row), ",codec_gap"), unchecked
    end
  end

  test "RED: the exact TI-89/TI-92 Plus AMS 2.0 table closes its catalog gap" do
    row =
      @catalog
      |> File.read!()
      |> String.split("\n")
      |> Enum.find(&String.contains?(&1, ",TI-89 / TI-92 Plus character set,"))

    assert row
    assert String.contains?(row, "TI-89-92-PLUS-AMS-2.0")
    assert String.contains?(row, "AMS 2.0")
    assert String.contains?(row, ",no,,yes,")
    assert String.ends_with?(String.trim(row), ",implemented")

    refute @high_gap_audit
           |> File.read!()
           |> String.contains?("TI-89 / TI-92 Plus character set\t")
  end

  test "RED: ECMA-44 closes as an explicit raw transport rather than a Unicode codec" do
    row =
      @catalog
      |> File.read!()
      |> String.split("\n")
      |> Enum.find(&String.contains?(&1, ",ECMA-44 punched-card representation,"))

    assert row
    assert String.contains?(row, "ECMA-44-7BIT-CARD-RAW")
    assert String.contains?(row, "ECMA-44-8BIT-CARD-RAW")
    assert row |> String.downcase() |> String.contains?("raw code-combination")
    assert String.contains?(row, ",no,,yes,")
    assert String.ends_with?(String.trim(row), ",implemented")
  end

  test "RED: the exact expanded UNIVAC I family closes only its source-qualified gap" do
    lines = @catalog |> File.read!() |> String.split("\n")
    row = Enum.find(lines, &String.contains?(&1, ",UNIVAC-I-EXPANDED-1959,"))

    assert row
    assert String.contains?(row, "UNIVAC I character code")
    assert String.contains?(row, "UNIVAC-I-EXPANDED-1959-ODD-PARITY-7BIT")
    assert String.contains?(row, "UNIVAC-I-EXPANDED-1959-PAPER-TAPE-ROW")
    assert String.contains?(row, ",high,")
    assert String.contains?(row, ",no,,yes,")
    assert String.ends_with?(String.trim(row), ",implemented")

    refute Enum.any?(lines, &String.contains?(&1, ",UNIVAC I character code,"))
    assert File.read!(@catalog_summary) =~ "Actionable codec gaps: **79**"
  end

  test "RED: exact Cork T1 and TeX OML/OMS profiles close their three audited gaps" do
    lines = @catalog |> File.read!() |> String.split("\n")

    expected = [
      {"Cork encoding", ["TEX-T1-EC-GLYPH", "TEX-T1-CMAP-1.0J"], "tb30ferguson.pdf"},
      {"OML encoding", ["TEX-LIVE-OML-CMMI10-TOUNICODE-2026"], "mathcapture-tag-001.tpf"},
      {"OMS encoding", ["TEX-LIVE-OMS-CMSY10-TOUNICODE-2026"], "mathcapture-tag-001.tpf"}
    ]

    for {name, profiles, source_fragment} <- expected do
      assert [row] = Enum.filter(lines, &String.contains?(&1, ",#{name},")), name
      assert String.contains?(row, source_fragment), name
      assert String.contains?(row, ",high,"), name
      assert String.contains?(row, ",no,,yes,"), name
      assert String.ends_with?(String.trim(row), ",implemented"), name

      for profile <- profiles do
        assert String.contains?(row, profile), "#{name}: #{profile}"
      end
    end

    assert File.read!(@catalog_summary) =~ "Actionable codec gaps: **79**"
  end

  test "RED: strict Formal SignWriting v1.0.0 closes the exact FSW ASCII gap" do
    lines = @catalog |> File.read!() |> String.split("\n")
    assert [row] = Enum.filter(lines, &String.contains?(&1, ",Formal SignWriting,"))
    assert String.contains?(row, "FSW")
    assert String.contains?(row, "FORMAL-SIGNWRITING-IN-ASCII")
    assert String.contains?(row, "zenodo.20272667")
    assert String.contains?(row, ",high,")
    assert String.contains?(row, ",no,,yes,")
    assert String.ends_with?(String.trim(row), ",implemented")
    assert File.read!(@catalog_summary) =~ "Actionable codec gaps: **79**"
  end

  test "RED: exact PDP-1 revisions, transports, and initial states close the umbrella gap" do
    lines = @catalog |> File.read!() |> String.split("\n")
    assert [row] = Enum.filter(lines, &String.contains?(&1, ",PDP-1 alphanumeric codes,"))

    profiles = [
      "PDP-1-CONCISE-1960-INITIAL-LOWER",
      "PDP-1-CONCISE-1960-INITIAL-UPPER",
      "PDP-1-FRIDEN-FPC-8-1960-INITIAL-LOWER",
      "PDP-1-FRIDEN-FPC-8-1960-INITIAL-UPPER",
      "PDP-1-CONCISE-FIODEC-1963-INITIAL-LOWER",
      "PDP-1-CONCISE-FIODEC-1963-INITIAL-UPPER",
      "PDP-1-FIODEC-ODD-PARITY-8BIT-1963-INITIAL-LOWER",
      "PDP-1-FIODEC-ODD-PARITY-8BIT-1963-INITIAL-UPPER"
    ]

    for profile <- profiles, do: assert(String.contains?(row, profile), profile)

    assert String.contains?(row, "F15_PDP1_Handbook_Apr60.pdf")
    assert String.contains?(row, "F15D_PDP1_Handbook_Oct63.pdf")
    assert String.contains?(row, ",high,")
    assert String.contains?(row, ",no,,yes,")
    assert String.ends_with?(String.trim(row), ",implemented")

    refute Enum.any?(lines, fn line ->
             String.contains?(line, ",PDP-1,") or String.contains?(line, ",FIODEC,")
           end)

    assert File.read!(@catalog_summary) =~ "Actionable codec gaps: **79**"
  end

  test "RED: original and MySQL KEYBCS2 profiles close the Kamenický gap without numeric aliases" do
    lines = @catalog |> File.read!() |> String.split("\n")
    assert [row] = Enum.filter(lines, &String.contains?(&1, ",Kamenický encoding,"))
    assert String.contains?(row, "KEYBCS2")
    assert String.contains?(row, "MYSQL-KEYBCS2")
    assert String.contains?(row, "cs-encodings-faq")
    assert String.contains?(row, "keybcs2.xml")
    assert String.contains?(row, ",high,")
    assert String.contains?(row, ",no,,yes,")
    assert String.ends_with?(String.trim(row), ",implemented")

    [_catalog_id, _name, aliases, _rest] = String.split(row, ",", parts: 4)

    for ambiguous <- ["CP895", "CP867", "DOS-895"],
        do: refute(String.contains?(aliases, ambiguous), ambiguous)

    assert File.read!(@catalog_summary) =~ "Actionable codec gaps: **79**"
  end

  test "RED: ABICOMP, BraSCII, and Kermit JIS7-KANJI close exact source-qualified gaps" do
    rows = @catalog |> File.read!() |> String.split("\n")

    expected = [
      {"ABICOMP character set", ["ABICOMP", "CP3848"], ["2525457.pdf", "749516.pdf"]},
      {"BraSCII", ["BRASCII", "CP3847"], ["sc200_u1.pdf", "2525457.pdf"]},
      {"JIS7-KANJI", ["ISO2022JP-KANJI", "KERMIT-JIS7-KANJI"], ["ckuxla.c", "JIS0208.TXT"]}
    ]

    for {name, profiles, sources} <- expected do
      assert [row] = Enum.filter(rows, &String.contains?(&1, ",#{name},")), name

      for profile <- profiles, do: assert(String.contains?(row, profile), "#{name}: #{profile}")
      for source <- sources, do: assert(String.contains?(row, source), "#{name}: #{source}")

      assert String.contains?(row, ",high,"), name
      assert String.contains?(row, ",no,,yes,"), name
      assert String.ends_with?(String.trim(row), ",implemented"), name
    end

    jis = Enum.find(rows, &String.contains?(&1, ",JIS7-KANJI,"))
    refute String.contains?(jis, " | JIS7 |")
    refute String.contains?(jis, " | ISO-2022-JP |")
    assert File.read!(@catalog_summary) =~ "Actionable codec gaps: **79**"
  end

  test "RED: MacOS Esperanto and VSCII-2 close exact source-qualified gaps" do
    rows = @catalog |> File.read!() |> String.split("\n")

    expected = [
      {"MacEsperanto encoding", ["MACOS_ESPERANTO", "MACESPERANTO"],
       ["eo-table.html", "Table version: 0.3"]},
      {"VSCII", ["VSCII-2", "ISO-IR-180", "VN2"], ["ir/180.pdf", "TCVN5712-2.TXT"]}
    ]

    for {name, profiles, sources} <- expected do
      assert [row] = Enum.filter(rows, &String.contains?(&1, ",#{name},")), name

      for profile <- profiles, do: assert(String.contains?(row, profile), "#{name}: #{profile}")
      for source <- sources, do: assert(String.contains?(row, source), "#{name}: #{source}")

      assert String.contains?(row, ",high,"), name
      assert String.contains?(row, ",no,,yes,"), name
      assert String.ends_with?(String.trim(row), ",implemented"), name
    end

    vscii = Enum.find(rows, &String.contains?(&1, ",VSCII,"))
    refute String.contains?(vscii, "VISCII1.1")
    refute String.contains?(vscii, "TCVN5712-1")
    assert File.read!(@catalog_summary) =~ "Actionable codec gaps: **79**"
  end

  test "RED: exact HP LICS and Army tap pair values close only their source-qualified gaps" do
    rows = @catalog |> File.read!() |> String.split("\n")

    assert [lics] =
             Enum.filter(rows, &String.contains?(&1, ",Lotus International Character Set,"))

    assert String.contains?(lics, "LICS"), lics
    assert String.contains?(lics, "LOTUS-INTERNATIONAL-CHARACTER-SET"), lics
    assert String.contains?(lics, "95LX_UsersGuide_F1000-90001_826pages_Jun91.pdf"), lics

    assert String.contains?(
             lics,
             "https://bitsavers.org/pdf/xerox/viewpoint/VP_2.0/610E12320_File_Conversion_Reference_Volume_10_May88.pdf"
           ),
           lics

    assert String.contains?(lics, "June 1991"), lics
    assert String.contains?(lics, "May 1988"), lics
    assert String.contains?(lics, "earlier incomplete profile is not equivalent"), lics
    assert String.contains?(lics, ",high,"), lics
    assert String.contains?(lics, ",no,,yes,"), lics
    assert String.ends_with?(String.trim(lics), ",implemented")

    [_catalog_id, _name, lics_aliases, _rest] = String.split(lics, ",", parts: 4)
    assert String.split(lics_aliases, " | ") == ["LICS", "LOTUS-INTERNATIONAL-CHARACTER-SET"]

    assert [tap] = Enum.filter(rows, &String.contains?(&1, ",tap code,"))

    for profile <- [
          "US-ARMY-GTA-31-70-001-TAP-CODE-PAIR-VALUES",
          "US-ARMY-POW-TAP-CODE-PAIR-VALUES",
          "GTA-31-70-001-TAP-CODE-PAIR-VALUES",
          "POW-TAP-CODE-5X5-PAIR-VALUES"
        ],
        do: assert(String.contains?(tap, profile), profile)

    assert String.contains?(tap, "gta31_70_001.pdf"), tap

    assert String.contains?(
             tap,
             "https://www.history.navy.mil/content/dam/nhhc/research/publications/Publication-PDF/BattleBehindBars.pdf"
           ),
           tap

    assert String.contains?(tap, "January 2015"), tap
    assert String.contains?(tap, "numeric pair values"), tap
    assert String.contains?(tap, "not physical U.S. Army wire bytes"), tap
    assert String.contains?(tap, "spaces, numbers, and alternate matrices remain excluded"), tap
    assert String.contains?(tap, ",high,"), tap
    assert String.contains?(tap, ",no,,yes,"), tap
    assert String.ends_with?(String.trim(tap), ",implemented")

    [_catalog_id, _name, tap_aliases, _rest] = String.split(tap, ",", parts: 4)

    assert String.split(tap_aliases, " | ") == [
             "GTA-31-70-001-TAP-CODE-PAIR-VALUES",
             "POW-TAP-CODE-5X5-PAIR-VALUES",
             "US-ARMY-GTA-31-70-001-TAP-CODE-PAIR-VALUES",
             "US-ARMY-POW-TAP-CODE-PAIR-VALUES"
           ]

    for excluded <- [
          "TAP-CODE-NUMBERS",
          "TAP-CODE-HAND-LANGUAGE",
          "TAP-CODE-SCRAMBLED-MATRIX"
        ],
        do: refute(String.contains?(tap, excluded), excluded)

    assert File.read!(@catalog_summary) =~ "Actionable codec gaps: **79**"
    assert File.read!(@catalog_manifest) =~ ~s("supplement": 134)
  end

  test "non-codec records have explicit implementation dispositions" do
    lines = @catalog |> File.read!() |> String.split("\n")

    expected = %{
      "Mac OS Corpchar" => "registry_component",
      "SGML" => "entity_mapping",
      "CHAR" => "platform_adapter",
      "WCHAR_T" => "platform_adapter",
      "Audio Data Syntax of CCITT Rec. T.101" => "non_text_coding_system",
      "IBM-61952" => "retired_invalid",
      "IBM-65535" => "control_value",
      "ISO-Unicode-IBM-1261" => "repertoire_profile",
      "UNKNOWN-8BIT" => "placeholder",
      "Windows code page 709" => "codec_gap"
    }

    for {name, disposition} <- expected do
      row = Enum.find(lines, &String.contains?(&1, ",#{name},"))
      assert row
      assert String.ends_with?(String.trim(row), ",#{disposition}")
    end
  end

  defp csv_fields(line),
    do: parse_csv_fields(String.trim_trailing(line, "\r"), false, [], [])

  defp parse_csv_fields(<<>>, false, field, fields),
    do: :lists.reverse([csv_field(field) | fields])

  defp parse_csv_fields(<<?\", ?\", rest::binary>>, true, field, fields),
    do: parse_csv_fields(rest, true, [?\" | field], fields)

  defp parse_csv_fields(<<?\", rest::binary>>, true, field, fields),
    do: parse_csv_fields(rest, false, field, fields)

  defp parse_csv_fields(<<?\", rest::binary>>, false, [], fields),
    do: parse_csv_fields(rest, true, [], fields)

  defp parse_csv_fields(<<?,, rest::binary>>, false, field, fields),
    do: parse_csv_fields(rest, false, [], [csv_field(field) | fields])

  defp parse_csv_fields(<<byte, rest::binary>>, quoted?, field, fields),
    do: parse_csv_fields(rest, quoted?, [byte | field], fields)

  defp csv_field(reversed_bytes),
    do: reversed_bytes |> :lists.reverse() |> :erlang.list_to_binary()
end

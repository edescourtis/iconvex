defmodule Iconvex.Specs.FullStackSupportToolTest do
  use ExUnit.Case, async: false

  @workspace Path.expand("../..", __DIR__)
  @tool Path.expand("../tools/full_stack_support.exs", __DIR__)
  @integration Path.join(@workspace, "iconvex_integration")
  @checked_report Path.join(@workspace, "ICONVEX_FULL_STACK_SUPPORT.md")

  @expected_owner_counts %{
    "iconvex" => 112,
    "iconvex_extras" => 86,
    "iconvex_telecom" => 54,
    "iconvex_specs" => 1_841
  }

  @reclaimed_gnu_spellings %{
    "IBM037" => "IBM-037",
    "IBM1026" => "IBM-1026",
    "IBM273" => "IBM-273",
    "IBM277" => "IBM-277",
    "IBM278" => "IBM-278",
    "IBM280" => "IBM-280",
    "IBM284" => "IBM-284",
    "IBM285" => "IBM-285",
    "IBM297" => "IBM-297",
    "IBM424" => "IBM-424",
    "IBM437" => "CP437",
    "IBM500" => "IBM-500",
    "IBM852" => "CP852",
    "IBM855" => "CP855",
    "IBM857" => "CP857",
    "IBM860" => "CP860",
    "IBM861" => "CP861",
    "IBM863" => "CP863",
    "IBM864" => "CP864",
    "IBM865" => "CP865",
    "IBM869" => "CP869",
    "IBM870" => "IBM-870",
    "IBM871" => "IBM-871",
    "IBM880" => "IBM-880",
    "IBM905" => "IBM-905"
  }

  @tag timeout: 300_000
  test "RED: full-stack report proves GNU parity and exact package ownership before emission" do
    output_path =
      Path.join(
        System.tmp_dir!(),
        "iconvex-full-stack-support-#{System.unique_integer([:positive])}.md"
      )

    on_exit(fn -> File.rm(output_path) end)

    child_build_path =
      System.get_env(
        "ICONVEX_FULL_STACK_CHILD_BUILD_PATH",
        Path.join(@integration, ".build-full-stack-support-tool-test")
      )

    {output, status} =
      System.cmd(System.find_executable("mix"), ["run", @tool],
        cd: @integration,
        env: [
          {"MIX_ENV", "test"},
          {"MIX_BUILD_PATH", child_build_path},
          {"ERL_FLAGS", System.get_env("ICONVEX_FULL_STACK_CHILD_ERL_FLAGS", "+S 8:8")},
          {"ICONVEX_FULL_STACK_SUPPORT_OUTPUT", output_path}
        ],
        stderr_to_stdout: true
      )

    assert status == 0, output
    assert File.regular?(output_path), output
    document = File.read!(output_path)

    expected_evidence = [
      "Archive codecs measured from `Iconvex.Specs.ICUArchive.encodings/0`: **1,050**",
      "`iconvex_specs_icu_archive_a`: **350** provider-owned tables",
      "`iconvex_specs_icu_archive_b`: **350** provider-owned tables",
      "`iconvex_specs_icu_archive_c`: **350** provider-owned tables",
      "The runtime provider union exactly equals the 1,050 manifest IDs",
      "[198-codec exhaustive GNU differential](iconvex_extras/EXHAUSTIVE_UNICODE_DIFFERENTIAL.md)",
      "Iconvex alias-routing equivalence"
    ]

    forbidden_evidence = [
      "Exhaustive GNU alias equivalence",
      "exhaustively decode-compared with its GNU target",
      "The 1,050 codecs stored across the three ICU archive shards"
    ]

    assert {
             Enum.reject(expected_evidence, &String.contains?(document, &1)),
             Enum.filter(forbidden_evidence, &String.contains?(document, &1))
           } == {[], []}

    assert document =~ "Parsed GNU spellings verified: **758/758**"
    assert document =~ "Direct GNU canonical targets: **758**"
    assert document =~ "GNU spellings reclaimed from RFC 1345 identities: **25**"

    for marker <- [
          "Core `iconvex`: **112**",
          "`iconvex_extras`: **86**",
          "`iconvex_telecom`: **54**",
          "`iconvex_specs`: **1,841**",
          "Full Iconvex stack canonical codecs: **2,093**",
          "GNU libiconv 1.19 `--enable-extra-encodings` fixed codecs: **198**"
        ] do
      assert document =~ marker
    end

    owner_rows =
      ~r/^\| `([^`]+)` \| `(iconvex(?:_extras|_telecom|_specs)?)` \| (Yes|No) \|$/m
      |> Regex.scan(document, capture: :all_but_first)

    assert length(owner_rows) == 2_093
    assert owner_rows |> Enum.map(&hd/1) |> Enum.uniq() |> length() == 2_093

    assert Enum.frequencies_by(owner_rows, &Enum.at(&1, 1)) == @expected_owner_counts
    assert Enum.count(owner_rows, &(List.last(&1) == "Yes")) == 198
    assert Enum.count(owner_rows, &(List.last(&1) == "No")) == 1_895

    assert File.read!(@checked_report) == document

    for {source_name, gnu_canonical} <- @reclaimed_gnu_spellings do
      assert document =~
               "| `#{source_name}` | `#{gnu_canonical}` | `RFC1345:#{source_name}` | 256/256 |"
    end

    source = File.read!(@tool)
    assert source =~ "gnu_definition_files"
    assert source =~ "gnu_reclaimed_spellings"
    assert source =~ "gnu_exhaustive_report"
    assert source =~ "passed: 198"
    assert source =~ "mismatches: 0"
    assert source =~ "archive_entries = Iconvex.Specs.ICUArchive.encodings()"
    assert source =~ ":persistent_term.get()"
    assert source =~ "Iconvex.canonical_name(source_name)"
    assert source =~ "for byte <- 0..255"
    refute source =~ ~s("all 758 GNU spellings resolve in Iconvex)
  end

  test "Specs documents identify the measured archive-provider evidence" do
    for relative <- ["iconvex_specs/README.md", "iconvex_specs/SUPPORTED_ENCODINGS.md"] do
      document = File.read!(Path.join(@workspace, relative))

      assert document =~
               "The workspace aggregate derives the archive count from `Iconvex.Specs.ICUArchive.encodings/0`"

      assert document =~
               "verifies that the live three-shard provider union exactly owns those manifest IDs"
    end
  end

  @tag timeout: 300_000
  test "GNU evidence requires the extra-encodings provenance marker as well as exact totals" do
    evidence_path =
      Path.join(
        System.tmp_dir!(),
        "iconvex-gnu-evidence-without-extra-marker-#{System.unique_integer([:positive])}.md"
      )

    output_path =
      Path.join(
        System.tmp_dir!(),
        "iconvex-full-stack-invalid-gnu-evidence-#{System.unique_integer([:positive])}.md"
      )

    on_exit(fn ->
      File.rm(evidence_path)
      File.rm(output_path)
    end)

    checked_evidence =
      File.read!(Path.join(@workspace, "iconvex_extras/EXHAUSTIVE_UNICODE_DIFFERENTIAL.md"))

    evidence_without_extra_marker =
      String.replace(
        checked_evidence,
        "- Reference: **iconv (GNU libiconv 1.19)**, built with `--enable-extra-encodings`",
        "- Reference: **iconv (GNU libiconv 1.19)**"
      )

    refute evidence_without_extra_marker == checked_evidence
    File.write!(evidence_path, evidence_without_extra_marker)

    child_build_path =
      System.get_env(
        "ICONVEX_FULL_STACK_CHILD_BUILD_PATH",
        Path.join(@integration, ".build-full-stack-support-tool-test")
      )

    {output, status} =
      System.cmd(System.find_executable("mix"), ["run", @tool],
        cd: @integration,
        env: [
          {"MIX_ENV", "test"},
          {"MIX_BUILD_PATH", child_build_path},
          {"ERL_FLAGS", System.get_env("ICONVEX_FULL_STACK_CHILD_ERL_FLAGS", "+S 8:8")},
          {"ICONVEX_FULL_STACK_SUPPORT_OUTPUT", output_path},
          {"ICONVEX_GNU_EXHAUSTIVE_REPORT", evidence_path}
        ],
        stderr_to_stdout: true
      )

    refute status == 0, output

    assert output =~
             "combined exhaustive GNU differential is not a clean 198-codec GNU libiconv 1.19 run"

    refute File.exists?(output_path)
  end

  test "publishable package READMEs name the workspace aggregate without a broken artifact link" do
    for relative <- [
          "iconvex/README.md",
          "iconvex_extras/README.md",
          "iconvex_telecom/README.md",
          "iconvex_specs/README.md"
        ] do
      readme = File.read!(Path.join(@workspace, relative))

      assert readme =~ "full-stack codec comparison at `../ICONVEX_FULL_STACK_SUPPORT.md`",
             "#{relative} does not name the workspace-relative full-stack comparison"

      refute readme =~ "](../ICONVEX_FULL_STACK_SUPPORT.md)",
             "#{relative} exposes an ExDoc link to a file absent from the package artifact"

      assert readme =~ "workspace-level integration evidence",
             "#{relative} does not disclose that the aggregate is workspace-level evidence"

      assert readme =~ "not included in this package artifact",
             "#{relative} does not disclose that the aggregate is absent from the package artifact"
    end
  end
end

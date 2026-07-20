defmodule Iconvex.Specs.RecentSourceQualifiedBenchmarkContractTest do
  use ExUnit.Case, async: false

  @contract_start "<!-- recent-source-qualified-benchmark-contract:start -->"
  @contract_end "<!-- recent-source-qualified-benchmark-contract:end -->"

  @batches [
    %{
      id: "tex-oml-oms",
      claim: "median-direct-composed:2-profiles",
      runtime: "lib/iconvex/specs/tex_math_encodings.ex",
      benchmark: "bench/tex_math_encodings_bench.exs",
      schema: nil,
      modules: [
        Iconvex.Specs.TeXLiveOMLCMMI10ToUnicode2026,
        Iconvex.Specs.TeXLiveOMSCMSY10ToUnicode2026
      ],
      assets: [
        "priv/sources/tex-live-oml-oms-2026/SOURCE_METADATA.md",
        "priv/sources/tex-live-oml-oms-2026/oml_tounicode.csv",
        "priv/sources/tex-live-oml-oms-2026/oms_tounicode.csv"
      ]
    },
    %{
      id: "cork-t1",
      claim: "gated-schema-v1:2-profiles:3-corpora",
      runtime: "lib/iconvex/specs/cork_t1.ex",
      benchmark: "bench/cork_t1_benchmark.exs",
      schema: "iconvex-cork-t1-benchmark",
      modules: [Iconvex.Specs.CorkT1ECGlyph, Iconvex.Specs.CorkT1CMap10J],
      assets: [
        "priv/sources/cork-t1/SOURCE_METADATA.md",
        "priv/sources/cork-t1/cork_t1_slots.csv"
      ]
    },
    %{
      id: "ot1-cmap-1.0j",
      claim: "gated-schema-v1:2-profiles:3-corpora",
      runtime: "lib/iconvex/specs/ot1_cmap.ex",
      benchmark: "bench/ot1_cmap_benchmark.exs",
      schema: "iconvex-ot1-cmap-benchmark",
      modules: [Iconvex.Specs.OT1CMap10J, Iconvex.Specs.OT1TTCMap10J],
      assets: [
        "priv/sources/ot1-cmap-1.0j/SOURCE_METADATA.md",
        "priv/sources/ot1-cmap-1.0j/ot1.cmap",
        "priv/sources/ot1-cmap-1.0j/ot1tt.cmap"
      ]
    },
    %{
      id: "formal-signwriting",
      claim: "gated-schema-v1:63010-mappings",
      runtime: "lib/iconvex/specs/formal_signwriting.ex",
      benchmark: "bench/formal_signwriting_bench.exs",
      schema: "iconvex-formal-signwriting-benchmark",
      modules: [Iconvex.Specs.FormalSignWriting],
      assets: [
        "priv/sources/formal-signwriting-1.0.0/ORACLE_EXCEPTIONS.md",
        "priv/sources/formal-signwriting-1.0.0/SOURCE_METADATA.md",
        "priv/sources/formal-signwriting-1.0.0/mapping_contract.csv"
      ]
    },
    %{
      id: "pdp1-character-codes",
      claim: "gated-schema-v1:4-transports:8-profiles",
      runtime: "lib/iconvex/specs/pdp1_character_codes.ex",
      benchmark: "bench/pdp1_character_codes_bench.exs",
      schema: "iconvex-pdp1-character-codes-benchmark",
      modules: [
        Iconvex.Specs.PDP1Concise1960InitialLower,
        Iconvex.Specs.PDP1Concise1960InitialUpper,
        Iconvex.Specs.PDP1FridenFPC81960InitialLower,
        Iconvex.Specs.PDP1FridenFPC81960InitialUpper,
        Iconvex.Specs.PDP1ConciseFIODEC1963InitialLower,
        Iconvex.Specs.PDP1ConciseFIODEC1963InitialUpper,
        Iconvex.Specs.PDP1FIODECOddParity8Bit1963InitialLower,
        Iconvex.Specs.PDP1FIODECOddParity8Bit1963InitialUpper
      ],
      assets: [
        "priv/sources/pdp1-character-codes/SOURCE_METADATA.md",
        "priv/sources/pdp1-character-codes/pdp1_1960.csv",
        "priv/sources/pdp1-character-codes/pdp1_fiodec_1963.csv"
      ]
    },
    %{
      id: "kamenicky-keybcs2",
      claim: "gated-schema-v1:2-profiles:2-corpora",
      runtime: "lib/iconvex/specs/kamenicky_keybcs2.ex",
      benchmark: "bench/kamenicky_keybcs2_benchmark.exs",
      schema: "iconvex-kamenicky-keybcs2-benchmark",
      modules: [Iconvex.Specs.KEYBCS2, Iconvex.Specs.MySQLKEYBCS2],
      assets: [
        "priv/sources/kamenicky-keybcs2/SOURCE_METADATA.md",
        "priv/sources/kamenicky-keybcs2/kamenicky_high_half.csv"
      ]
    },
    %{
      id: "abicomp",
      claim: "gated-schema-v1:1-profile:3-corpora",
      runtime: "lib/iconvex/specs/abicomp.ex",
      benchmark: "bench/abicomp_benchmark.exs",
      schema: "iconvex-abicomp-benchmark",
      modules: [Iconvex.Specs.ABICOMP],
      assets: [
        "priv/sources/abicomp/SOURCE_METADATA.md",
        "priv/sources/abicomp/abicomp.csv"
      ]
    },
    %{
      id: "brascii",
      claim: "gated-schema-v1:256-byte-classification",
      runtime: "lib/iconvex/specs/brascii.ex",
      benchmark: "bench/brascii_bench.exs",
      schema: "iconvex-brascii-benchmark",
      modules: [Iconvex.Specs.BraSCII],
      assets: [
        "priv/sources/brascii/SOURCE_METADATA.md",
        "priv/sources/brascii/brascii_nbr_9611.csv"
      ]
    },
    %{
      id: "macos-esperanto",
      claim: "gated-schema-v1:256-unique-octets",
      runtime: "lib/iconvex/specs/mac_esperanto.ex",
      benchmark: "bench/mac_esperanto_bench.exs",
      schema: "iconvex-mac-esperanto-benchmark",
      modules: [Iconvex.Specs.MacEsperanto],
      assets: [
        "priv/sources/mac-esperanto/SOURCE_METADATA.md",
        "priv/sources/mac-esperanto/macos_esperanto_0_3.csv"
      ]
    },
    %{
      id: "vscii-2",
      claim: "gated-schema-v1:1-profile:4-corpora",
      runtime: "lib/iconvex/specs/vscii2.ex",
      benchmark: "bench/vscii2_benchmark.exs",
      schema: "iconvex-vscii2-benchmark",
      modules: [Iconvex.Specs.VSCII2],
      assets: [
        "priv/sources/vscii-2/SOURCE_METADATA.md",
        "priv/sources/vscii-2/vscii2.csv"
      ]
    },
    %{
      id: "kermit-jis7-kanji",
      claim: "gated-schema-v1:2-corpora:4-gates",
      runtime: "lib/iconvex/specs/kermit_jis7_kanji.ex",
      benchmark: "bench/kermit_jis7_kanji_benchmark.exs",
      schema: "iconvex-kermit-jis7-kanji-benchmark",
      modules: [Iconvex.Specs.KermitJIS7Kanji],
      assets: [
        "priv/sources/JIS0208.TXT",
        "priv/sources/dec-terminal-character-sets/kermit/COPYING",
        "priv/sources/dec-terminal-character-sets/kermit/ckcuni.c",
        "priv/sources/kermit-jis7-kanji/SOURCE_METADATA.md",
        "priv/sources/kermit-jis7-kanji/ckcfns.c",
        "priv/sources/kermit-jis7-kanji/ckuxla.c",
        "priv/sources/kermit-jis7-kanji/ckuxla.h"
      ]
    },
    %{
      id: "lotus-lics",
      claim: "gated-schema-v1:239-assigned-octets:234-unique-scalars",
      runtime: "lib/iconvex/specs/lotus_lics.ex",
      benchmark: "bench/lotus_lics_benchmark.exs",
      schema: "iconvex-lotus-lics-benchmark",
      modules: [Iconvex.Specs.LotusLICS],
      assets: [
        "priv/sources/lotus-lics/SOURCE_METADATA.md",
        "priv/sources/lotus-lics/lotus_lics_hp_1991.csv"
      ]
    },
    %{
      id: "us-army-tap-code-pair-values",
      claim: "gated-schema-v1:25-pairs:4-corpora",
      runtime: "lib/iconvex/specs/us_army_tap_code_pair_values.ex",
      benchmark: "bench/us_army_tap_code_pair_values_benchmark.exs",
      schema: "iconvex-us-army-tap-code-pair-values-benchmark",
      modules: [Iconvex.Specs.USArmyTapCodePairValues],
      assets: [
        "priv/sources/us-army-tap-code/SOURCE_METADATA.md",
        "priv/sources/us-army-tap-code/pairs.csv"
      ]
    },
    %{
      id: "pascii-cdac-gist-1.0-2002",
      claim: "gated-schema-v1:4-profiles:16-paths",
      runtime: "lib/iconvex/specs/pascii_10.ex",
      benchmark: "bench/pascii_10_benchmark.exs",
      schema: "iconvex-pascii-1.0-benchmark",
      modules: [
        Iconvex.Specs.PASCII10UrduKashmiriBestFit,
        Iconvex.Specs.PASCII10SindhiBestFit,
        Iconvex.Specs.PASCII10LosslessVPUA1,
        Iconvex.Specs.PASCII10RawVPUA1
      ],
      assets: [
        "priv/sources/pascii-cdac-gist-1.0-2002/SOURCE_METADATA.md",
        "priv/sources/pascii-cdac-gist-1.0-2002/mapping.csv"
      ]
    }
  ]

  test "RED: benchmark claims bind exact runtime and harness sources to release selection" do
    root = Path.expand("..", __DIR__)
    document = File.read!(Path.join(root, "BENCHMARKS.md"))
    rows = contract_rows(document)
    package = Mix.Project.config() |> Keyword.fetch!(:package)
    package_files = Keyword.fetch!(package, :files)
    registered = MapSet.new(Iconvex.Specs.codecs())

    assert Mix.Project.config()[:app] == :iconvex_specs
    assert Map.keys(rows) |> Enum.sort() == Enum.map(@batches, & &1.id) |> Enum.sort()

    for batch <- @batches do
      row = Map.fetch!(rows, batch.id)

      assert row.claim == batch.claim
      assert row.package == "iconvex_specs"
      assert row.runtime_sha256 == sha256(root, batch.runtime)
      assert row.benchmark_sha256 == sha256(root, batch.benchmark)
      assert row.release_selection == "runtime+evidence"
      assert row.harness_selection == "development-only"

      assert selected_by_package?(root, package_files, batch.runtime)
      refute selected_by_package?(root, package_files, batch.benchmark)

      for asset <- batch.assets do
        assert File.regular?(Path.join(root, asset))
        assert selected_by_package?(root, package_files, asset)
      end

      for module <- batch.modules, do: assert(MapSet.member?(registered, module))

      benchmark_source = File.read!(Path.join(root, batch.benchmark))

      if batch.schema do
        assert benchmark_source =~ batch.schema
        assert benchmark_source =~ "--quick"
        assert benchmark_source =~ "summary\\t"
      else
        assert benchmark_source =~ "direct/composed"
        assert benchmark_source =~ "@samples"
        assert benchmark_source =~ "@warmups"
      end
    end

    for evidence <- ~w(BENCHMARKS.md CONFORMANCE.md SOURCES.md) do
      assert selected_by_package?(root, package_files, evidence)
    end
  end

  test "RED: PASCII throughput gate forbids a regression beyond the recorded 30x ceiling" do
    root = Path.expand("..", __DIR__)
    benchmark = File.read!(Path.join(root, "bench/pascii_10_benchmark.exs"))
    document = File.read!(Path.join(root, "BENCHMARKS.md"))

    [_, floor_text] = Regex.run(~r/@throughput_floor\s+([0-9]+(?:\.[0-9]+)?)/, benchmark)
    floor = String.to_float(floor_text)
    minimum_floor = 5.684 / 30

    assert floor >= minimum_floor,
           "PASCII floor #{floor} permits more than a 30x regression from 5.684 MiB/s"

    assert document =~ "throughput must exceed 0.19 MiB/s"

    assert document =~
             "| PASCII C-DAC GIST 1.0 | 4 profiles × direct/public encode/decode | 0.19 MiB/s |"
  end

  test "RED: Cork reduction scaling is isolated from ordinary-heap GC steps" do
    benchmark =
      "../bench/cork_t1_benchmark.exs"
      |> Path.expand(__DIR__)
      |> File.read!()

    assert benchmark =~ "@reduction_bounds {1.60, 2.60}"
    assert benchmark =~ "@reduction_heap_words 1_000_000"
    assert benchmark =~ "spawn_opt("
    assert benchmark =~ "{:min_heap_size, @reduction_heap_words}"
  end

  defp contract_rows(document) do
    [_before, after_start] = String.split(document, @contract_start, parts: 2)
    [contract, _after] = String.split(after_start, @contract_end, parts: 2)

    contract
    |> String.split("\n", trim: true)
    |> Enum.filter(&String.starts_with?(String.trim(&1), "| `"))
    |> Map.new(fn line ->
      [id, claim, package, runtime_sha256, benchmark_sha256, release_selection, harness_selection] =
        line
        |> String.trim()
        |> String.trim("|")
        |> String.split("|")
        |> Enum.map(&(&1 |> String.trim() |> String.trim("`")))

      {id,
       %{
         claim: claim,
         package: package,
         runtime_sha256: runtime_sha256,
         benchmark_sha256: benchmark_sha256,
         release_selection: release_selection,
         harness_selection: harness_selection
       }}
    end)
  end

  defp sha256(root, relative) do
    root
    |> Path.join(relative)
    |> File.read!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp selected_by_package?(root, selectors, relative) do
    target = Path.join(root, relative)

    Enum.any?(selectors, fn selector ->
      absolute_selector = Path.join(root, selector)

      cond do
        File.dir?(absolute_selector) ->
          relative == selector or String.starts_with?(relative, selector <> "/")

        String.contains?(selector, ["*", "?", "["]) ->
          target in Path.wildcard(absolute_selector, match_dot: true)

        true ->
          selector == relative
      end
    end)
  end
end

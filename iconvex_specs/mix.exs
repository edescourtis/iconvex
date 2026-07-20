defmodule IconvexSpecs.MixProject do
  use Mix.Project

  @source_url "https://github.com/edescourtis/iconvex"

  def project do
    [
      app: :iconvex_specs,
      version: "0.1.0",
      elixir: "~> 1.16",
      description: "Public-specification codecs for Iconvex",
      source_url: @source_url,
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps()
    ]
  end

  def application, do: [mod: {Iconvex.Specs.Application, []}, extra_applications: [:crypto]]

  defp deps do
    [iconvex_dependency() | archive_dependencies()]
  end

  defp iconvex_dependency do
    case System.get_env("ICONVEX_PATH") do
      nil -> {:iconvex, "~> 0.1.0"}
      path -> {:iconvex, "~> 0.1.0", path: path}
    end
  end

  defp archive_dependencies do
    for shard <- ~w(a b c) do
      app = String.to_atom("iconvex_specs_icu_archive_#{shard}")

      case System.get_env("ICONVEX_ARCHIVE_PATH") do
        nil ->
          {app, "~> 0.1.0"}

        root ->
          {app, "~> 0.1.0", path: Path.join(root, Atom.to_string(app))}
      end
    end
  end

  defp package do
    [
      licenses: [
        "LGPL-2.1-or-later",
        "LPPL-1.0-or-later",
        "LPPL-1.3c-or-later",
        "Apache-2.0",
        "Unicode-3.0",
        "BSD-2-Clause",
        "BSD-3-Clause",
        "MIT"
      ],
      links: %{
        "GitHub" => @source_url,
        "Iconvex" => "https://hex.pm/packages/iconvex"
      },
      exclude_patterns: [
        ~r|^priv/tables/icu_archive_\d+\.etf$|,
        ~r|^priv/(?:tables/)?(?:\._)?openjdk_.*\.etf$|
      ],
      files:
        [
          "priv/sources/punched-card-codes/hollerith_consensus_iowa_824e61a9_blocker.md",
          "priv/sources/iconvex-unicode-signature-profiles/SOURCE_METADATA.md",
          "ICONVEX_UNICODE_SIGNATURE_PROFILES.md"
        ] ++
          ~w(lib priv/*.etf priv/tables priv/sources/ecma-44/*.csv priv/sources/ecma-44/SOURCE_METADATA.md priv/sources/punched-card-codes/*.csv priv/sources/punched-card-codes/PROFILE_DISPOSITION.md priv/sources/punched-card-codes/SOURCE_METADATA.md priv/sources/pascii-cdac-gist-1.0-2002/mapping.csv priv/sources/pascii-cdac-gist-1.0-2002/SOURCE_METADATA.md priv/sources/ti-89-92-plus-ams-2.0/mapping.csv priv/sources/ti-89-92-plus-ams-2.0/SOURCE_METADATA.md priv/sources/ti-83-plus-2002/mapping.csv priv/sources/ti-83-plus-2002/SOURCE_METADATA.md priv/sources/unihan-17.0.0-telegraph/mainland_tokens.csv priv/sources/unihan-17.0.0-telegraph/taiwan_tokens.csv priv/sources/unihan-17.0.0-telegraph/taiwan_policy.csv priv/sources/unihan-17.0.0-telegraph/SOURCE_METADATA.md priv/sources/unihan-17.0.0-kgb3/row_cells.csv priv/sources/unihan-17.0.0-kgb3/SOURCE_METADATA.md priv/sources/ibm-additional-code-pages/*.map priv/sources/ibm-additional-code-pages/SOURCE_METADATA.md priv/sources/draft-jseng-utf5-01/* priv/sources/draft-ietf-idn-utf6-00/* priv/sources/JIS0208.TXT priv/sources/dec-terminal-character-sets/kermit/COPYING priv/sources/dec-terminal-character-sets/kermit/ckcuni.c priv/sources/kermit-jis7-kanji/* priv/sources/kermit-vendor-8bit/SOURCE_METADATA.md priv/sources/koi8-f/KOI8UNI.TXT priv/sources/koi8-f/SOURCE_METADATA.md priv/sources/kamenicky-keybcs2/*.csv priv/sources/kamenicky-keybcs2/SOURCE_METADATA.md priv/sources/abicomp/*.csv priv/sources/abicomp/SOURCE_METADATA.md priv/sources/abc800-basic-ii/*.csv priv/sources/abc800-basic-ii/SOURCE_METADATA.md priv/sources/rfc698-stanford/*.csv priv/sources/rfc698-stanford/SOURCE_METADATA.md priv/sources/evertype-source-qualified/*.csv priv/sources/evertype-source-qualified/SOURCE_METADATA.md priv/sources/lietuvybe-lst-source-qualified/*.csv priv/sources/lietuvybe-lst-source-qualified/SOURCE_METADATA.md priv/sources/vietunicode-vni-2002/vni_profiles.csv priv/sources/vietunicode-vni-2002/SOURCE_METADATA.md priv/sources/secondary-source-qualified-single-byte/* priv/sources/glyph-vector-unicode/* priv/sources/tace16-2010/* priv/sources/brascii/*.csv priv/sources/brascii/SOURCE_METADATA.md priv/sources/mac-esperanto/*.csv priv/sources/mac-esperanto/SOURCE_METADATA.md priv/sources/vscii-2/*.csv priv/sources/vscii-2/SOURCE_METADATA.md priv/sources/lotus-lics/*.csv priv/sources/lotus-lics/SOURCE_METADATA.md priv/sources/us-army-tap-code/*.csv priv/sources/us-army-tap-code/SOURCE_METADATA.md priv/sources/ibm-24-26-arrangements/*.csv priv/sources/ibm-24-26-arrangements/SOURCE_METADATA.md priv/sources/univac-i-1959/*.csv priv/sources/univac-i-1959/SOURCE_METADATA.md priv/sources/tex-live-oml-oms-2026/*.csv priv/sources/tex-live-oml-oms-2026/SOURCE_METADATA.md priv/sources/cork-t1/*.csv priv/sources/cork-t1/SOURCE_METADATA.md priv/sources/ot1-cmap-1.0j/*.cmap priv/sources/ot1-cmap-1.0j/SOURCE_METADATA.md priv/sources/formal-signwriting-1.0.0/* priv/sources/pdp1-character-codes/*.csv priv/sources/pdp1-character-codes/SOURCE_METADATA.md priv/sources/univac-1100-fieldata/*.csv priv/sources/univac-1100-fieldata/SOURCE_METADATA.md priv/sources/univac-4009-fieldata/*.csv priv/sources/univac-4009-fieldata/SOURCE_METADATA.md mix.exs README.md CHANGELOG.md SUPPORTED_ENCODINGS.md SUPPORTED_CODEC_INVENTORY.csv SUPPORTED_PROPERTY_TOKEN_MAPPING_INVENTORY.csv SUPPORTED_NON_OCTET_CODEC_INVENTORY.csv SUPPORTED_PACKED_CODEC_INVENTORY.csv SUPPORTED_RAW_TRANSPORT_INVENTORY.csv UNIHAN_TELEGRAPH_PROPERTY_TOKENS.md UNIHAN_GB3_ROW_CELL.md ECMA44_RAW_TRANSPORT.md ICU_UCM_ENCODINGS.md ICU_MULTIBYTE_ENCODINGS.md ICU_EBCDIC_STATEFUL_ENCODINGS.md ICU_ARCHIVE_ENCODINGS.md ICU_ARCHIVE_DIFFERENTIAL.md ICU_SWAP_LFNL_ENCODINGS.md ICU_UNICODE_VARIANTS.md ICU_JIS7_JIS8.md ICU_LMBCS1.md ICU_LMBCS_DIFFERENTIAL.md ICU_X11_COMPOUND_TEXT.md IANA_PCL_SYMBOL_SETS.md IANA_ISO10646_PROFILES.md IBM_UNICODE_CCSIDS.md WINDOWS_BEST_FIT_ENCODINGS.md UNICODE_LEGACY_ENCODINGS.md UNICODE_MAPPING_COMPONENTS.md LEGACY_COMPUTING_N5028.md ISO_IR_MODERN_ENCODINGS.md ISO_IR_CNS11643.md ISO_IR_JISX0213.md ISO_IR_HISTORICAL_GRAPHIC.md ISO_IR_MOSAIC_TECHNICAL.md ISO_IR_169.md ISO_IR_42.md KPS9566_97.md VPUA_ALLOCATIONS.md EVERTYPE_SOURCE_QUALIFIED.md CONFORMANCE.md BENCHMARKS.md TDD_LOG.md SOURCES.md ALGORITHMIC_DIFFERENTIAL.md LICENSE LICENSE.APACHE-2.0 LICENSE.UNICODE LICENSE.MIT-NMSU LICENSE.BSD-2-CLAUSE licenses/upstream/LPPL-1.0.txt licenses/upstream/LPPL-1.3c.txt NOTICE)
    ]
  end
end

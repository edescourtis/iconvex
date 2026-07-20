defmodule Iconvex.Specs.LicenseContractTest do
  use ExUnit.Case, async: true

  @root Path.expand("..", __DIR__)
  @libiconv_lgpl_sha256 "20e50fe7aae3e56378ebf0417d9de904f55a0e61e4df315333e632a4d3555d95"
  @kermit_license_sha256 "067b8c8fc98d9359dfbd211820e1d57bed1e173144a184a21e8ead802b6502be"
  @kermit_license_path "priv/sources/dec-terminal-character-sets/kermit/COPYING"
  @kermit_source_metadata_path "priv/sources/kermit-vendor-8bit/SOURCE_METADATA.md"
  @koi8_f_license_sha256 "453f7f1cbd5504398ebee03e90d7ebf1ccc80ef9661cabb779ce749099666ef4"
  @koi8_f_source_sha256 "9b24e0aa3d0eaf1ebacfb7cbb1ef435793c7542a3cf99fc20f90923fccba15cd"
  @koi8_f_license_path "LICENSE.MIT-NMSU"
  @koi8_f_source_path "priv/sources/koi8-f/KOI8UNI.TXT"
  @koi8_f_source_metadata_path "priv/sources/koi8-f/SOURCE_METADATA.md"
  @bsd_2_clause_license_path "LICENSE.BSD-2-CLAUSE"
  @bsd_2_clause_license_sha256 "10a62f2fa2653c3a669e0a17ebd06fa8300d2f949aee2b1f191d957eada61618"
  @openjdk_source_directories ~w(
    priv/sources/openjdk-euc-jp-open
    priv/sources/openjdk-iso2022-cn
    priv/sources/openjdk-iso2022-jp
    priv/sources/openjdk-ms950-hkscs-xp
  )
  @apsl_source_directory "priv/sources/utf8-mac"
  @vni_packaged_paths ~w(
    priv/sources/vietunicode-vni-2002/vni_profiles.csv
    priv/sources/vietunicode-vni-2002/SOURCE_METADATA.md
  )
  @vni_repository_only_paths ~w(
    priv/sources/vietunicode-vni-2002/vni.html
    priv/sources/vietunicode-vni-2002/vni.html.base64
  )
  @lppl_1_0_license_path "licenses/upstream/LPPL-1.0.txt"
  @lppl_1_3c_license_path "licenses/upstream/LPPL-1.3c.txt"
  @lppl_1_0_license_sha256 "89358c7072db622ba6d8ac9b4a322984853dd6d870f93c39efdb3f6a22719cd2"
  @lppl_1_3c_license_sha256 "3d262cdf34dafa6955f703c634a8c238ec44109bc8dd6ef34fb7aa54809f7e66"
  @unicode_signature_metadata_path "priv/sources/iconvex-unicode-signature-profiles/SOURCE_METADATA.md"
  @unicode_signature_document_path "ICONVEX_UNICODE_SIGNATURE_PROFILES.md"
  @neutral_signature_names ~w(
    ICONVEX-UTF-16-SIGNATURE-LE-DEFAULT
    ICONVEX-UTF-32BE-SIGNATURE
    ICONVEX-UTF-32LE-SIGNATURE
  )
  @openjdk_signature_names ~w(
    x-UTF-16LE-BOM
    UTF-16LE-BOM
    UTF_16LE_BOM
    X-UTF-32BE-BOM
    UTF-32BE-BOM
    UTF_32BE_BOM
    X-UTF-32LE-BOM
    UTF-32LE-BOM
    UTF_32LE_BOM
  )

  test "original library code uses GNU libiconv's LGPL-2.1-or-later license" do
    license = File.read!(Path.join(@root, "LICENSE"))
    package = Mix.Project.config() |> Keyword.fetch!(:package)

    assert sha256(license) == @libiconv_lgpl_sha256
    assert "LGPL-2.1-or-later" in Keyword.fetch!(package, :licenses)
    assert File.regular?(Path.join(@root, "LICENSE.APACHE-2.0"))
    assert File.regular?(Path.join(@root, "LICENSE.UNICODE"))
  end

  test "Hex release ships complete Kermit BSD-3-Clause terms and source metadata" do
    package = Mix.Project.config() |> Keyword.fetch!(:package)
    package_files = Keyword.fetch!(package, :files)

    assert "BSD-3-Clause" in Keyword.fetch!(package, :licenses)
    assert @kermit_license_path in package_files
    assert @kermit_source_metadata_path in package_files

    license = File.read!(Path.join(@root, @kermit_license_path))
    source_metadata = File.read!(Path.join(@root, @kermit_source_metadata_path))
    normalized_license = String.replace(license, ~r/\s+/, " ")

    assert sha256(license) == @kermit_license_sha256
    assert normalized_license =~ "Redistributions of source code must retain"
    assert normalized_license =~ "Redistributions in binary form must reproduce"
    assert normalized_license =~ "Neither the name of Columbia University"

    assert normalized_license =~
             "THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS"

    assert normalized_license =~
             "IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE"

    assert source_metadata =~ @kermit_license_path
  end

  test "Hex release ships the exact KOI8-F source, provenance, and MIT terms" do
    package = Mix.Project.config() |> Keyword.fetch!(:package)
    package_files = Keyword.fetch!(package, :files)

    assert "MIT" in Keyword.fetch!(package, :licenses)
    assert @koi8_f_license_path in package_files
    assert @koi8_f_source_path in package_files
    assert @koi8_f_source_metadata_path in package_files

    license = File.read!(Path.join(@root, @koi8_f_license_path))
    source = File.read!(Path.join(@root, @koi8_f_source_path))
    metadata = File.read!(Path.join(@root, @koi8_f_source_metadata_path))

    assert sha256(license) == @koi8_f_license_sha256
    assert sha256(source) == @koi8_f_source_sha256
    assert source =~ "Copyright 2008 Department of Mathematical Sciences"
    assert source =~ "Permission is hereby granted, free of charge"
    assert metadata =~ @koi8_f_source_sha256
    assert metadata =~ @koi8_f_license_sha256
    assert metadata =~ @koi8_f_license_path
  end

  test "GPL-derived OpenJDK ISO-2022 work is quarantined outside the LGPL runtime" do
    notice = File.read!(Path.join(@root, "NOTICE"))
    readme = File.read!(Path.join(@root, "README.md"))
    jp_document = File.read!(Path.join(@root, "OPENJDK_ISO2022_JP.md"))
    cn_document = File.read!(Path.join(@root, "OPENJDK_ISO2022_CN.md"))

    for document <- [jp_document, cn_document] do
      assert document =~ "source-informed translation"
      assert document =~ "quarantined"
      assert document =~ "not shipped"
    end

    for relative <- [
          "priv/sources/openjdk-iso2022-jp/SOURCE_METADATA.md",
          "priv/sources/openjdk-iso2022-cn/SOURCE_METADATA.md"
        ] do
      metadata = File.read!(Path.join(@root, relative))

      refute metadata =~ "independently written Elixir implementation"
      assert metadata =~ "source-informed translation"
      assert metadata =~ "quarantined"
      assert metadata =~ "repository-only"
    end

    refute notice =~ "the independent Elixir implementation remains LGPL-2.1-or-later"
    assert notice =~ "OpenJDK quarantine"
    assert String.replace(notice, ~r/\s+/, " ") =~ "not shipped"
    assert readme =~ "OpenJDK quarantine"
    assert readme =~ "not registered"

    refute File.exists?(Path.join(@root, "lib/iconvex/specs/openjdk_iso2022_jp.ex"))
    refute File.exists?(Path.join(@root, "lib/iconvex/specs/openjdk_iso2022_cn.ex"))
  end

  test "RED: signature profiles have a neutral LGPL provenance and no OpenJDK runtime identity" do
    package_files =
      Mix.Project.config() |> Keyword.fetch!(:package) |> Keyword.fetch!(:files)

    assert @unicode_signature_metadata_path in package_files
    assert @unicode_signature_document_path in package_files

    metadata = File.read!(Path.join(@root, @unicode_signature_metadata_path))
    document = File.read!(Path.join(@root, @unicode_signature_document_path))
    sources = File.read!(Path.join(@root, "SOURCES.md"))

    for text <- [metadata, document, sources] do
      assert text =~ "Unicode Standard 16.0.0"
      assert text =~ "LGPL-2.1-or-later"
      assert text =~ "Iconvex-defined"
      assert text =~ "not a Unicode-standard encoding scheme"
      refute text =~ "github.com/openjdk"
    end

    refute File.exists?(Path.join(@root, "lib/iconvex/specs/openjdk_utf16le_bom.ex"))
    refute File.exists?(Path.join(@root, "lib/iconvex/specs/openjdk_utf32_bom.ex"))

    assert File.regular?(
             Path.join(@root, "lib/iconvex/specs/iconvex_unicode_signature_profiles.ex")
           )

    assert length(Iconvex.Specs.encodings()) == 1_841

    for name <- @neutral_signature_names do
      assert name in Iconvex.Specs.encodings()
      assert {:ok, ^name} = Iconvex.canonical_name(name)
    end

    for name <- @openjdk_signature_names do
      refute name in Iconvex.Specs.encodings()
      assert :error = Iconvex.canonical_name(name)
    end
  end

  test "UTF-8-MAC generated tables ship the retained BSD-2-Clause attribution" do
    package = Mix.Project.config() |> Keyword.fetch!(:package)
    package_files = Keyword.fetch!(package, :files)
    source_metadata = File.read!(Path.join(@root, "priv/sources/utf8-mac/SOURCE_METADATA.md"))
    notice = File.read!(Path.join(@root, "NOTICE"))
    readme = File.read!(Path.join(@root, "README.md"))
    source_inventory = File.read!(Path.join(@root, "SOURCES.md"))
    utf8_mac_document = File.read!(Path.join(@root, "UTF8_MAC.md"))

    assert "BSD-2-Clause" in Keyword.fetch!(package, :licenses)
    assert @bsd_2_clause_license_path in package_files

    license = File.read!(Path.join(@root, @bsd_2_clause_license_path))
    normalized_license = String.replace(license, ~r/\s+/, " ")

    assert sha256(license) == @bsd_2_clause_license_sha256
    assert normalized_license =~ "Copyright (c) 2022 Apple Computer, Inc."
    assert normalized_license =~ "Redistribution and use in source and binary forms"
    assert normalized_license =~ "THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS"
    assert source_metadata =~ "generated runtime manifest"
    assert source_metadata =~ @bsd_2_clause_license_path
    assert notice =~ ~r/generated\s+`priv\/utf8_mac_manifest\.etf` is shipped/
    assert notice =~ @bsd_2_clause_license_path
    assert readme =~ @bsd_2_clause_license_path
    assert source_inventory =~ "generated runtime manifest"
    assert source_inventory =~ @bsd_2_clause_license_path
    assert utf8_mac_document =~ @bsd_2_clause_license_path
  end

  test "effective Hex manifest excludes GPL and APSL upstream source trees" do
    package_files =
      Mix.Project.config() |> Keyword.fetch!(:package) |> Keyword.fetch!(:files)

    for directory <- @openjdk_source_directories do
      files = Path.wildcard(Path.join([@root, directory, "**", "*"]), match_dot: true)
      assert files != []

      for path <- files, File.regular?(path) do
        relative = Path.relative_to(path, @root)
        refute selected_by_package?(package_files, relative), "Hex selects GPL source #{relative}"
      end
    end

    apsl_files = [
      Path.join(@apsl_source_directory, "libiconv_test.c"),
      Path.join(@apsl_source_directory, "LICENSE.APSL-1.0")
    ]

    for relative <- apsl_files do
      assert File.regular?(Path.join(@root, relative))
      refute selected_by_package?(package_files, relative), "Hex selects APSL source #{relative}"
    end

    removed_runtime_assets = [
      "priv/openjdk_iso2022_jp.etf",
      "priv/openjdk_iso2022_jp_manifest.etf",
      "priv/openjdk_iso2022_cn.etf",
      "priv/openjdk_iso2022_cn_manifest.etf"
    ]

    for relative <- removed_runtime_assets do
      refute File.exists?(Path.join(@root, relative))
      refute selected_by_package?(package_files, relative)
    end

    for relative <- ["OPENJDK_ISO2022_JP.md", "OPENJDK_ISO2022_CN.md"] do
      assert File.regular?(Path.join(@root, relative))
      refute selected_by_package?(package_files, relative)
    end

    for relative <- ["priv/utf8_mac_manifest.etf"] do
      assert selected_by_package?(package_files, relative)
    end
  end

  test "Hex release packages normalized VNI evidence but excludes unlicensed raw snapshots" do
    package_files =
      Mix.Project.config() |> Keyword.fetch!(:package) |> Keyword.fetch!(:files)

    for relative <- @vni_packaged_paths do
      assert File.regular?(Path.join(@root, relative))

      assert selected_by_package?(package_files, relative),
             "Hex omits required VNI asset #{relative}"
    end

    for relative <- @vni_repository_only_paths do
      assert File.regular?(Path.join(@root, relative))

      refute selected_by_package?(package_files, relative),
             "Hex selects repository-only VNI snapshot #{relative}"
    end

    metadata =
      @root
      |> Path.join(List.last(@vni_packaged_paths))
      |> File.read!()
      |> String.replace(~r/\s+/, " ")

    assert metadata =~ "vni.html"
    assert metadata =~ "repository-only"
    assert metadata =~ "not redistributed in the Hex package"
  end

  test "Hex release ships complete LPPL 1.0 and 1.3c terms for verbatim CTAN assets" do
    package = Mix.Project.config() |> Keyword.fetch!(:package)
    licenses = Keyword.fetch!(package, :licenses)
    package_files = Keyword.fetch!(package, :files)

    assert "LPPL-1.0-or-later" in licenses
    assert "LPPL-1.3c-or-later" in licenses

    for {path, expected_sha256, version_pattern} <- [
          {@lppl_1_0_license_path, @lppl_1_0_license_sha256, ~r/LPPL Version 1\.0\s+1999-03-01/},
          {@lppl_1_3c_license_path, @lppl_1_3c_license_sha256,
           ~r/LPPL Version 1\.3c\s+2008-05-04/}
        ] do
      assert path in package_files
      license = File.read!(Path.join(@root, path))
      assert sha256(license) == expected_sha256
      assert license =~ version_pattern
      assert license =~ "Everyone"
      assert license =~ "WARRANTY"
    end

    glyph_metadata =
      File.read!(Path.join(@root, "priv/sources/glyph-vector-unicode/SOURCE_METADATA.md"))

    ot1_metadata = File.read!(Path.join(@root, "priv/sources/ot1-cmap-1.0j/SOURCE_METADATA.md"))
    readme = File.read!(Path.join(@root, "README.md"))
    notice = File.read!(Path.join(@root, "NOTICE"))

    assert glyph_metadata =~ "LPPL-1.0-or-later"
    assert glyph_metadata =~ "60ceab0c10da129230b18dbd73ef8994dad546e21197298e6d7930d9f8dc20e0"
    assert glyph_metadata =~ @lppl_1_0_license_path
    assert ot1_metadata =~ "LPPL-1.3c-or-later"
    assert ot1_metadata =~ "67123f5846b014963904c7395605d3521e98e11493be933aacf45e2bb3c12327"
    assert ot1_metadata =~ @lppl_1_3c_license_path

    for document <- [readme, notice] do
      assert document =~ "LPPL-1.0-or-later"
      assert document =~ "LPPL-1.3c-or-later"
      assert document =~ @lppl_1_0_license_path
      assert document =~ @lppl_1_3c_license_path
    end
  end

  defp selected_by_package?(selectors, relative) do
    target = Path.join(@root, relative)

    Enum.any?(selectors, fn selector ->
      absolute_selector = Path.join(@root, selector)

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

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

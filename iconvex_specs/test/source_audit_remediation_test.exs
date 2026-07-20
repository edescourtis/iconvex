defmodule Iconvex.Specs.SourceAuditRemediationTest do
  use ExUnit.Case, async: true

  @root Path.expand("..", __DIR__)
  @openjdk_revision "6ae23a0d6574dc8139aea93ea3c562a7410fcb34"
  @openjdk_dirs ~w(
    openjdk-euc-jp-open
    openjdk-iso2022-cn
    openjdk-iso2022-jp
    openjdk-ms950-hkscs-xp
  )
  @openjdk_license_sha256 "4b9abebc4338048a7c2dc184e9f800deb349366bdf28eb23c2677a77b4c87726"
  @openjdk_additional_sha256 "a69bce275ba7a3570af6579cb0f55682cd75fedfcd49e0e8e9022270c447c916"
  @apsl_1_sha256 "54702bc17c8ac3601637577c8f92e5992be79110df72c7ff6fe20d75d4df2745"
  @psf_2_sha256 "b0e25a78cffb43f4d92de8b61ccfa1f1f98ecbc22330b54b5251e7b6ba010231"

  @metadata_families [
    {"cpython-3.14.6-iso2022-jp-ext", "CPython `v3.14.6`",
     "Python Software Foundation License Version 2"},
    {"dotnet-runtime-codepages", "dbb2178288bb4e1e8f1fde3958be3bd75573c459", "MIT"},
    {"glibc-e5145be467bed28bafde33a51df97840be37065e-ibm423",
     "e5145be467bed28bafde33a51df97840be37065e", "LGPL-2.1-or-later"},
    {"windows-best-fit", "https://www.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WindowsBestFit",
     "Unicode License V3"},
    {"iana", "https://www.iana.org/assignments/charset-reg/Amiga-1251", "repository-only"},
    {"iana-iso10646", "https://www.rfc-editor.org/rfc/rfc1815.txt", "repository-only"},
    {"iana-pcl-symbol-sets", "409356a1ad15aeca1280bb91aed58564c5524540", "repository-only"},
    {"ibm-unicode-ccsids", "https://www.ibm.com/docs/en/i/7.4.0", "repository-only"}
  ]

  test "RED: every retained OpenJDK source set carries its exact GPLv2/Classpath bundle" do
    for directory <- @openjdk_dirs do
      source_dir = Path.join([@root, "priv", "sources", directory])
      license_path = Path.join(source_dir, "LICENSE")
      additional_path = Path.join(source_dir, "ADDITIONAL_LICENSE_INFO")
      metadata_path = Path.join(source_dir, "SOURCE_METADATA.md")

      assert sha256_file(license_path) == @openjdk_license_sha256
      assert sha256_file(additional_path) == @openjdk_additional_sha256

      metadata = File.read!(metadata_path)
      assert metadata =~ @openjdk_revision
      assert metadata =~ "GPL-2.0-only WITH Classpath-exception-2.0"
      assert metadata =~ @openjdk_license_sha256
      assert metadata =~ @openjdk_additional_sha256
      assert metadata =~ "https://github.com/openjdk/jdk/blob/#{@openjdk_revision}/"

      source_dir
      |> File.ls!()
      |> Enum.reject(&(&1 in ~w(LICENSE ADDITIONAL_LICENSE_INFO SOURCE_METADATA.md)))
      |> Enum.each(fn source ->
        assert metadata =~ "`#{source}`"
        assert metadata =~ sha256_file(Path.join(source_dir, source))
      end)
    end
  end

  test "RED: UTF-8-MAC retains exact APSL terms and source-by-source ownership" do
    source_dir = Path.join([@root, "priv", "sources", "utf8-mac"])
    metadata = File.read!(Path.join(source_dir, "SOURCE_METADATA.md"))

    assert sha256_file(Path.join(source_dir, "LICENSE.APSL-1.0")) == @apsl_1_sha256
    assert metadata =~ @apsl_1_sha256
    assert metadata =~ "libiconv_test.c"
    assert metadata =~ "APSL-1.0"
    assert metadata =~ "citrus_utf8mac.c"
    assert metadata =~ "BSD-2-Clause"
    assert metadata =~ "tn1150table.html"
    assert metadata =~ "Copyright 2018 Apple Inc. All Rights Reserved"
    assert metadata =~ "UnicodeData-3.2.0.txt"
    assert metadata =~ "Unicode License V3"

    for source <- File.ls!(source_dir), source not in ~w(LICENSE.APSL-1.0 SOURCE_METADATA.md) do
      assert metadata =~ "`#{source}`"
      assert metadata =~ sha256_file(Path.join(source_dir, source))
    end
  end

  test "RED: every newly audited family has exact file metadata and no blanket LGPL claim" do
    for {directory, provenance, terms} <- @metadata_families do
      source_dir = Path.join([@root, "priv", "sources", directory])
      metadata = File.read!(Path.join(source_dir, "SOURCE_METADATA.md"))

      assert metadata =~ provenance
      assert metadata =~ terms

      source_dir
      |> File.ls!()
      |> Enum.reject(&(&1 == "SOURCE_METADATA.md"))
      |> Enum.each(fn source ->
        assert metadata =~ "`#{source}`"
        assert metadata =~ sha256_file(Path.join(source_dir, source))
      end)
    end

    assert sha256_file(Path.join([@root, "priv", "sources", "rfc3492", "CPYTHON-LICENSE.txt"])) ==
             @psf_2_sha256
  end

  test "RED: source and notice documents classify all audited upstream artifacts" do
    sources = File.read!(Path.join(@root, "SOURCES.md"))
    notice = File.read!(Path.join(@root, "NOTICE"))

    for marker <- [
          "OpenJDK quarantine",
          "CPython ISO-2022-JP-EXT",
          ".NET x-Europa and x-cp50227",
          "glibc IBM423",
          "UTF-8-MAC / HFS Plus",
          "Microsoft Windows Best Fit",
          "IANA registry-derived families",
          "IBM Unicode CCSID reference"
        ] do
      assert sources =~ marker
      assert notice =~ marker
    end

    assert notice =~ "repository-only"
    assert notice =~ "not LGPL-covered upstream material"
  end

  test "RED: one executable benchmark gates every audited runtime family" do
    benchmark_path = Path.join(@root, "bench/source_audit_families_benchmark.exs")
    benchmark = File.read!(benchmark_path)
    documentation = File.read!(Path.join(@root, "BENCHMARKS.md"))

    assert benchmark =~ "--quick"
    assert benchmark =~ "@slowdown_ceiling 30.0"
    assert benchmark =~ "summary\\t"
    assert benchmark =~ "CPythonISO2022JPExt"

    for family <- ~w(utf8-mac cpython dotnet glibc windows-best-fit iana ibm-ccsid) do
      assert benchmark =~ ~s(family: "#{family}")
      assert documentation =~ "`#{family}`"
    end

    assert documentation =~ "source-audit-families-benchmark:start"
    assert documentation =~ sha256_file(benchmark_path)
    assert documentation =~ "30x"
  end

  defp sha256_file(path), do: path |> File.read!() |> sha256()
  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

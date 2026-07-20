defmodule Iconvex.Specs.AlgorithmicDifferentialArtifactTest do
  use ExUnit.Case, async: true

  @report Path.expand("../ALGORITHMIC_DIFFERENTIAL.md", __DIR__)
  @runner Path.expand("../tools/exhaustive_algorithmic_differential.exs", __DIR__)
  @runtime_sources ~w(
    bocu1.ex
    cesu8.ex
    imap_utf7.ex
    java_modified_utf8.ex
    punycode.ex
    scsu.ex
    utf5.ex
    utf6.ex
    utf1.ex
    utf_ebcdic.ex
    x_user_defined.ex
  )
  @digest "d037f6200ae8845906b4372a8b3fcd39730e3a61c4af0e354823010e6f93be54"

  test "checked-in differential evidence covers every full-repertoire algorithmic codec" do
    assert File.regular?(@runner)
    report = File.read!(@report)
    runner_digest = sha256(File.read!(@runner))

    runtime_digest =
      @runtime_sources
      |> Enum.map(fn name ->
        path = Path.expand("../lib/iconvex/specs/#{name}", __DIR__)
        [name, 0, File.read!(path), 0]
      end)
      |> IO.iodata_to_binary()
      |> sha256()

    assert report =~ "Unicode scalars: **1,112,064/1,112,064**"
    assert report =~ "Corpus SHA-256: `#{@digest}`"
    assert report =~ "Runner SHA-256: `#{runner_digest}`"
    assert report =~ "Runtime SHA-256: `#{runtime_digest}`"
    assert report =~ "Codecs passed: **10/10**"
    assert report =~ "Mismatches: **0**"

    for codec <- [
          "BOCU-1",
          "CESU-8",
          "UTF-7-IMAP",
          "SCSU",
          "JAVA-MODIFIED-UTF-8",
          "PUNYCODE",
          "UTF-EBCDIC",
          "UTF-1",
          "UTF-5",
          "X-USER-DEFINED"
        ] do
      assert report =~ "| `#{codec}` | PASS |"
    end

    utf6_source = File.read!(Path.expand("../lib/iconvex/specs/utf6.ex", __DIR__))
    utf6_digest = sha256(utf6_source)

    assert report =~ "Explicit non-row disposition: **UTF-6 excluded**"
    assert report =~ "63-byte hostname-label limit"
    assert report =~ "monolithic 1,112,064-scalar corpus is not a valid UTF-6 value"
    assert report =~ "UTF-6 runtime SHA-256: `#{utf6_digest}`"
    assert report =~ "`test/utf6_test.exs` checks every Unicode scalar"
    refute report =~ "| `UTF-6` |"
  end

  defp sha256(binary) do
    binary
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end

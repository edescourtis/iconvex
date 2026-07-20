defmodule IconvexIntegration.GeneratedSupportDocumentContractTest do
  use ExUnit.Case, async: false

  @moduletag timeout: 30_000
  @workspace Path.expand("../..", __DIR__)
  @core_root Path.join(@workspace, "iconvex")
  @extras_root Path.join(@workspace, "iconvex_extras")
  @generator Path.join(@core_root, "tools/generate_registry.exs")
  @definitions Path.join(@core_root, "test/fixtures/gnu-libiconv-1.19-encodings")

  @generated_paths [
    "iconvex/lib/iconvex/registry.ex",
    "iconvex/priv",
    "iconvex/SUPPORTED_ENCODINGS.md",
    "iconvex_extras/lib/iconvex/extras/codecs.ex",
    "iconvex_extras/priv",
    "iconvex_extras/SUPPORTED_ENCODINGS.md"
  ]

  test "support-document reports are exact, deterministic, and non-mutating" do
    before_snapshot = generated_snapshot()

    core_first = report!("core")
    extras_first = report!("extras")
    core_second = report!("core")
    extras_second = report!("extras")

    assert core_first == core_second
    assert extras_first == extras_second
    assert core_first == File.read!(Path.join(@core_root, "SUPPORTED_ENCODINGS.md"))
    assert extras_first == File.read!(Path.join(@extras_root, "SUPPORTED_ENCODINGS.md"))

    assert core_first =~ "Additional audited specification/ICU aliases: **25**"
    assert core_first =~ "Total resolved fixed-codec spellings: **783**"
    assert core_first =~ "exact 51-codec packed-profile inventory"
    assert core_first =~ "its 441 normalized names"
    refute core_first =~ "ISO-IR-180"

    normalized_extras = String.replace(extras_first, ~r/\s+/, " ")
    assert normalized_extras =~ "**25** audited specification/ICU aliases"
    assert normalized_extras =~ "**783** total resolved fixed-codec spellings"

    assert generated_snapshot() == before_snapshot
  end

  test "full regeneration preserves the ISO-2022-JP-3 streaming surface" do
    generator = File.read!(@generator)

    for callback <- [
          "def stream_decoder_init, do: CodecSupport.stream_decoder_init_iso2022_jp3()",
          "def decode_chunk(input, state, final?)",
          "def stream_encoder_init, do: CodecSupport.stream_encoder_init_iso2022_jp3()",
          "def encode_chunk(codepoints, state, final?, policy)"
        ] do
      assert generator =~ callback,
             "full registry generator would omit ISO-2022-JP-3 callback: #{callback}"
    end
  end

  defp report!(target) do
    {output, status} =
      System.cmd(
        "elixir",
        [@generator, @definitions, "--report-supported-encodings", target],
        cd: @core_root,
        stderr_to_stdout: true
      )

    assert status == 0,
           "support-document report for #{target} failed with status #{status}:\n#{output}"

    output
  end

  defp generated_snapshot do
    @generated_paths
    |> Enum.flat_map(fn relative ->
      path = Path.join(@workspace, relative)

      if File.dir?(path) do
        Path.wildcard(Path.join(path, "**/*"))
      else
        [path]
      end
    end)
    |> Enum.filter(&File.regular?/1)
    |> Enum.sort()
    |> Map.new(fn path ->
      relative = Path.relative_to(path, @workspace)
      {relative, :crypto.hash(:sha256, File.read!(path))}
    end)
  end
end

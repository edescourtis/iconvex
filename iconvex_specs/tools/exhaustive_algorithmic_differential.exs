root = Path.expand("..", __DIR__)
corpus_path = Path.join(root, "test/fixtures/all-unicode-scalars.utf32be")
report_path = Path.join(root, "ALGORITHMIC_DIFFERENTIAL.md")
expected_digest = "d037f6200ae8845906b4372a8b3fcd39730e3a61c4af0e354823010e6f93be54"

unless File.regular?(corpus_path) do
  Code.require_file(Path.join(__DIR__, "generate_unicode_scalar_corpus.exs"))
end

corpus = File.read!(corpus_path)
digest = corpus |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

unless byte_size(corpus) == 1_112_064 * 4 and digest == expected_digest do
  raise "Unicode scalar corpus failed size or SHA-256 verification"
end

codepoints = for <<codepoint::unsigned-big-32 <- corpus>>, do: codepoint

uconv =
  System.get_env("ICU_UCONV") ||
    System.find_executable("uconv") ||
    Path.wildcard("/opt/homebrew/Cellar/icu4c*/**/bin/uconv") |> Enum.sort() |> List.last() ||
    raise "set ICU_UCONV to an ICU uconv executable"

{version, 0} = System.cmd(uconv, ["--version"], stderr_to_stdout: true)
version = version |> String.split("\n", trim: true) |> List.first()

sha256 = fn binary ->
  binary |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
end

runtime_sources = ~w(
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

runner_digest = __ENV__.file |> File.read!() |> sha256.()

runtime_digest =
  runtime_sources
  |> Enum.map(fn name ->
    path = Path.join(root, "lib/iconvex/specs/#{name}")
    [name, 0, File.read!(path), 0]
  end)
  |> IO.iodata_to_binary()
  |> sha256.()

utf6_runtime_digest =
  root
  |> Path.join("lib/iconvex/specs/utf6.ex")
  |> File.read!()
  |> sha256.()

timed = fn fun ->
  started = System.monotonic_time(:millisecond)
  value = fun.()
  {value, System.monotonic_time(:millisecond) - started}
end

oracle_encode = fn name ->
  case System.cmd(uconv, ["-f", "UTF-32BE", "-t", name, corpus_path]) do
    {output, 0} -> output
    {_output, status} -> raise "ICU encode #{name} exited #{status}"
  end
end

oracle_decode = fn name, bytes ->
  path =
    Path.join(
      System.tmp_dir!(),
      "iconvex-specs-#{System.unique_integer([:positive, :monotonic])}.bin"
    )

  File.write!(path, bytes)

  try do
    case System.cmd(uconv, ["-f", name, "-t", "UTF-32BE", path]) do
      {output, 0} -> output
      {_output, status} -> raise "ICU decode #{name} exited #{status}"
    end
  after
    File.rm(path)
  end
end

oracle_codecs = [
  {Iconvex.Specs.BOCU1, "BOCU-1", :exact},
  {Iconvex.Specs.CESU8, "CESU-8", :exact},
  {Iconvex.Specs.IMAPUTF7, "IMAP-mailbox-name", :imap_flush},
  {Iconvex.Specs.SCSU, "SCSU", :non_unique}
]

results =
  Enum.map(oracle_codecs, fn {codec, oracle_name, comparison} ->
    IO.puts("checking #{codec.canonical_name()} against ICU #{oracle_name}...")

    {{ours, oracle}, elapsed} =
      timed.(fn ->
        {:ok, ours} = codec.encode(codepoints)
        oracle = oracle_encode.(oracle_name)

        # ICU 78's command-line driver leaves its final IMAP shift in the
        # converter error buffer for very large inputs. The converter source
        # requires and emits the final '-', so normalize that one CLI byte.
        oracle =
          if comparison == :imap_flush and not String.ends_with?(oracle, "-") do
            oracle <> "-"
          else
            oracle
          end

        {ours, oracle}
      end)

    own_roundtrip = codec.decode(ours) == {:ok, codepoints}
    :erlang.garbage_collect(self())
    oracle_cross_decode = codec.decode(oracle) == {:ok, codepoints}
    :erlang.garbage_collect(self())
    icu_cross_decode = oracle_decode.(oracle_name, ours) == corpus
    exact = comparison == :non_unique or ours == oracle

    result = %{
      name: codec.canonical_name(),
      result: own_roundtrip and oracle_cross_decode and icu_cross_decode and exact,
      bytes: byte_size(ours),
      digest: sha256.(ours),
      oracle_bytes: byte_size(oracle),
      exact: if(comparison == :non_unique, do: "N/A (non-unique)", else: to_string(exact)),
      elapsed: elapsed
    }

    :erlang.garbage_collect(self())
    result
  end)

self_results =
  Enum.map(
    [
      Iconvex.Specs.JavaModifiedUTF8,
      Iconvex.Specs.Punycode,
      Iconvex.Specs.UTFEBCDIC,
      Iconvex.Specs.UTF1,
      Iconvex.Specs.UTF5
    ],
    fn codec ->
      IO.puts("checking #{codec.canonical_name()} against its specification...")

      {{encoded, ok}, elapsed} =
        timed.(fn ->
          {:ok, encoded} = codec.encode(codepoints)
          {encoded, codec.decode(encoded) == {:ok, codepoints}}
        end)

      result = %{
        name: codec.canonical_name(),
        result: ok,
        bytes: byte_size(encoded),
        digest: sha256.(encoded),
        oracle_bytes: 0,
        exact: "N/A (normative specification)",
        elapsed: elapsed
      }

      :erlang.garbage_collect(self())
      result
    end
  )

bytes = :binary.list_to_bin(Enum.to_list(0..255))
{:ok, xud_codepoints} = Iconvex.Specs.XUserDefined.decode(bytes)

xud = %{
  name: Iconvex.Specs.XUserDefined.canonical_name(),
  result:
    length(xud_codepoints) == 256 and
      Iconvex.Specs.XUserDefined.encode(xud_codepoints) == {:ok, bytes},
  bytes: 256,
  digest: sha256.(bytes),
  oracle_bytes: 0,
  exact: "complete 256-byte repertoire",
  elapsed: 0
}

results = results ++ self_results ++ [xud]
passed = Enum.count(results, & &1.result)

rows =
  Enum.map(results, fn result ->
    status = if result.result, do: "PASS", else: "FAIL"

    "| `#{result.name}` | #{status} | #{result.bytes} | `#{result.digest}` | " <>
      "#{result.oracle_bytes} | #{result.exact} | #{result.elapsed} |\n"
  end)

document = [
  "# Algorithmic Codec Differential\n\n",
  "Generated by `tools/exhaustive_algorithmic_differential.exs`. Every one of the ",
  "1,112,064 Unicode scalar values is encoded and decoded in a single stateful stream. ",
  "For ICU-supported codecs, ICU's bytes are decoded by Iconvex and Iconvex's bytes are ",
  "decoded by ICU. BOCU-1, CESU-8, and modified IMAP UTF-7 also require byte-identical ",
  "encoder output; SCSU permits multiple conformant compressed forms. Punycode's full ",
  "scalar-stream row is a normative RFC round trip; its independent pinned CPython ",
  "differential is exercised by the focused conformance suite. UTF-5's row is a ",
  "source-exact draft round trip over the same complete scalar stream.\n\n",
  "- Unicode scalars: **1,112,064/1,112,064**\n",
  "- Corpus: `test/fixtures/all-unicode-scalars.utf32be`\n",
  "- Corpus bytes: **#{byte_size(corpus)}**\n",
  "- Corpus SHA-256: `#{digest}`\n",
  "- Runner SHA-256: `#{runner_digest}`\n",
  "- Runtime SHA-256: `#{runtime_digest}`\n",
  "- Codecs passed: **#{passed}/#{length(results)}**\n",
  "- Mismatches: **#{length(results) - passed}**\n",
  "- Explicit non-row disposition: **UTF-6 excluded** because its source draft's ",
  "63-byte hostname-label limit means the monolithic 1,112,064-scalar corpus is not a ",
  "valid UTF-6 value.\n",
  "- UTF-6 runtime SHA-256: `#{utf6_runtime_digest}`; exhaustive alternative: ",
  "`test/utf6_test.exs` checks every Unicode scalar in a reverse-legal hostname context ",
  "and enforces the 63-byte label limit.\n",
  "- Independent oracle: **#{version}** (`#{uconv}`)\n\n",
  "| Codec | Result | Iconvex bytes | Iconvex SHA-256 | Oracle bytes | Encoder equality | ms |\n",
  "|---|---:|---:|---|---:|---|---:|\n",
  rows
]

File.write!(report_path, document)
IO.puts("#{passed}/#{length(results)} codecs passed; report: #{report_path}")

unless passed == length(results), do: System.halt(1)

defmodule Iconvex.Specs.PunycodeTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.Punycode

  @rfc Path.expand("../priv/sources/rfc3492/rfc3492.txt", __DIR__)
  @oracle Path.expand("../priv/sources/rfc3492/cpython-3.14.6-punycode.py", __DIR__)
  @oracle_license Path.expand("../priv/sources/rfc3492/CPYTHON-LICENSE.txt", __DIR__)
  @metadata Path.expand("../priv/sources/rfc3492/SOURCE_METADATA.md", __DIR__)

  test "RED: every RFC 3492 section 7.1 vector encodes canonically and decodes exactly" do
    vectors = rfc_vectors()
    assert Enum.map(vectors, &elem(&1, 0)) == Enum.map(?A..?S, &<<&1>>)

    for {label, codepoints, encoded} <- vectors do
      assert Punycode.encode(codepoints) == {:ok, canonical_rfc_output(encoded)},
             "RFC vector #{label} canonical encode"

      assert Punycode.decode(encoded) == {:ok, codepoints}, "RFC vector #{label} decode"
    end
  end

  test "matches CPython 3.14.6 on deterministic scalar properties" do
    corpus = property_corpus()
    python = python_encode(corpus)

    assert length(python) == length(corpus)

    for {codepoints, expected} <- Enum.zip(corpus, python) do
      assert Punycode.encode(codepoints) == {:ok, expected}
      assert Punycode.decode(expected) == {:ok, codepoints}
      assert Punycode.decode(mix_ascii_case(expected)) == {:ok, codepoints}
    end
  end

  @tag timeout: :infinity
  test "exhausts duplicate-heavy rank and reverse-insertion cases" do
    alphabet = [?A, ?-, 0x80, 0x81, 0x82]
    oracle_cases = Enum.flat_map(0..5, &sequences(alphabet, &1))
    roundtrip_cases = Enum.flat_map(0..7, &sequences(alphabet, &1))

    assert length(oracle_cases) == 3_906
    assert length(roundtrip_cases) == 97_656

    for {codepoints, expected} <- Enum.zip(oracle_cases, python_encode(oracle_cases)) do
      assert Punycode.encode(codepoints) == {:ok, expected}
    end

    for codepoints <- roundtrip_cases do
      assert {:ok, encoded} = Punycode.encode(codepoints)
      assert Punycode.decode(encoded) == {:ok, codepoints}
    end
  end

  test "matches CPython's strict valid/malformed boundary and reports native offsets" do
    terminated_overflow = String.duplicate("9", 512) <> "a"

    cases = [
      <<>>,
      "-",
      "abc-",
      "abc",
      "a--",
      "z",
      "a-z",
      "a-!",
      <<0x80, ?->>,
      "99999999999999999999999",
      "zzzzzzzzzzzzzzzzzzzzzzz",
      terminated_overflow
    ]

    expected_statuses = python_decode_statuses(cases)

    actual_statuses =
      Enum.map(cases, fn input ->
        case Punycode.decode(input) do
          {:ok, _codepoints} -> :ok
          {:error, _kind, _offset, _sequence} -> :error
        end
      end)

    assert actual_statuses == expected_statuses
    assert Punycode.decode("z") == {:error, :incomplete_sequence, 0, "z"}
    assert Punycode.decode("a-z") == {:error, :incomplete_sequence, 2, "z"}
    assert Punycode.decode("a-!") == {:error, :invalid_sequence, 2, "!"}
    assert Punycode.decode(<<?A, 0x80, ?->>) == {:error, :invalid_sequence, 1, <<0x80>>}

    assert Punycode.decode(terminated_overflow) ==
             {:error, :invalid_sequence, 0, terminated_overflow}

    assert Punycode.decode_discard(terminated_overflow) == {:ok, []}
  end

  test "exhaustively matches pinned CPython on every input through two octets" do
    cases =
      [<<>>] ++
        Enum.map(0..0xFF, &<<&1>>) ++
        for(first <- 0..0xFF, second <- 0..0xFF, do: <<first, second>>)

    expected = python_decode_results(cases)

    actual =
      Enum.map(cases, fn input ->
        case Punycode.decode(input) do
          {:ok, codepoints} -> {:ok, codepoints}
          {:error, _kind, _offset, _sequence} -> :error
        end
      end)

    assert length(expected) == 65_793
    assert actual == expected
  end

  test "RED: ordered non-basic paths do not rescan or recopy the full input" do
    corpora = [
      {Enum.to_list(0x1000..0x13E7), Enum.to_list(0x1000..0x17CF)},
      {alternating_scalars(1_000), alternating_scalars(2_000)}
    ]

    for {small, large} <- corpora do
      {:ok, small_encoded} = Punycode.encode(small)
      {:ok, large_encoded} = Punycode.encode(large)

      # Warm both paths before counting scheduler reductions. This is a
      # deterministic algorithmic gate, not a wall-clock assertion.
      assert Punycode.decode(small_encoded) == {:ok, small}
      assert Punycode.decode(large_encoded) == {:ok, large}

      small_reductions = decode_reductions(small_encoded, small)
      large_reductions = decode_reductions(large_encoded, large)
      small_encode_reductions = encode_reductions(small, small_encoded)
      large_encode_reductions = encode_reductions(large, large_encoded)

      assert large_reductions / small_reductions < 3.0
      assert large_encode_reductions / small_encode_reductions < 3.0
    end
  end

  test "invalid scalar policies are native, deterministic, and preserve one whole-string pass" do
    valid = [?A, ?B, 0x1F600]
    invalid = [?A, 0xD800, ?B, 0x11_0000, 0x1F600]

    assert Punycode.encode(invalid) == {:error, :unrepresentable_character, 0xD800}
    assert Punycode.encode_discard(invalid) == Punycode.encode(valid)

    replacer = fn
      0xD800 -> ~c"<SURROGATE>"
      0x11_0000 -> ~c"<TOO-LARGE>"
    end

    substituted = [?A] ++ ~c"<SURROGATE>" ++ [?B] ++ ~c"<TOO-LARGE>" ++ [0x1F600]
    assert Punycode.encode_substitute(invalid, replacer) == Punycode.encode(substituted)

    # Punycode is a whole-string transform: CPython's ignore policy retains
    # the decoded basic prefix and stops when generalized integers lose sync.
    assert Punycode.decode_discard(<<?A, 0x80, ?B, ?->>) == {:ok, ~c"AB"}
    assert Punycode.decode_discard("abc-!garbage") == {:ok, ~c"abc"}
  end

  test "whole-string callback recovery never decodes an incomplete prefix or desynchronized tail" do
    parent = self()

    handler = fn event ->
      send(parent, {:punycode_invalid, event})
      :discard
    end

    assert Punycode.decode("a-z!more") == {:error, :invalid_sequence, 3, "!"}
    assert Punycode.decode("a-z") == {:error, :incomplete_sequence, 2, "z"}
    assert Punycode.decode_discard("a-z!more") == {:ok, ~c"a"}

    assert Iconvex.convert("a-z!more", "PUNYCODE", "UTF-8", on_invalid_byte: handler) ==
             {:ok, "a"}

    assert_receive {:punycode_invalid,
                    %Iconvex.InvalidByte{
                      encoding: "PUNYCODE",
                      kind: :invalid_sequence,
                      offset: 3,
                      byte: ?!,
                      sequence: "!"
                    }}

    refute_receive {:punycode_invalid, _}

    assert Iconvex.convert("a-z!more", "PUNYCODE", "UTF-8", byte_substitute: "<%02x>") ==
             {:ok, "a<21>"}

    assert Iconvex.convert("abc-!garbage", "PUNYCODE", "UTF-8",
             on_invalid_byte: fn _ -> :discard end
           ) == {:ok, "abc"}
  end

  test "registry, public policies, and direct UTF-8 callbacks use the native codec" do
    assert Iconvex.canonical_name("rfc-3492") == {:ok, "PUNYCODE"}
    assert Iconvex.canonical_name("bootstring-punycode") == {:ok, "PUNYCODE"}

    input = "Hello Καλημέρα 日本語 😀"
    codepoints = String.to_charlist(input)
    assert {:ok, encoded} = Punycode.encode(codepoints)

    trace_calls(
      [
        {Punycode, :decode, 1},
        {Punycode, :decode_to_utf8, 1},
        {Punycode, :encode, 1},
        {Punycode, :encode_from_utf8, 1}
      ],
      fn ->
        assert Iconvex.convert(encoded, "PUNYCODE", "UTF-8") == {:ok, input}
        assert Iconvex.convert(input, "UTF-8", "PUNYCODE") == {:ok, encoded}
        assert trace_count({Punycode, :decode_to_utf8, 1}) == 1
        assert trace_count({Punycode, :encode_from_utf8, 1}) == 1
        assert trace_count({Punycode, :decode, 1}) == 1
        assert trace_count({Punycode, :encode, 1}) == 1
      end
    )

    assert Punycode.encode_from_utf8(<<?A, 0xC2>>) ==
             {:decode_error, :incomplete_sequence, 1, <<0xC2>>}

    assert Punycode.encode_from_utf8(<<?A, 0xFF>>) ==
             {:decode_error, :invalid_sequence, 1, <<0xFF>>}

    assert Iconvex.convert("abc-!garbage", "PUNYCODE", "UTF-8", invalid: :discard) ==
             {:ok, "abc"}

    surrogate = <<0xED, 0xA0, 0x80>>

    assert Iconvex.convert(surrogate, "WTF-8", "PUNYCODE", unrepresentable: :discard) ==
             Punycode.encode([])

    assert Iconvex.convert(
             surrogate,
             "WTF-8",
             "PUNYCODE",
             unicode_substitute: "<U+%04X>"
           ) == Punycode.encode(~c"<U+D800>")
  end

  test "repeated public substitution dispatches to encode_substitute exactly once" do
    input = :binary.copy(<<0xED, 0xA0, 0x80>>, 400)
    expected = String.duplicate("<U+D800>", 400) |> String.to_charlist() |> Punycode.encode()

    trace_calls([{Punycode, :encode, 1}, {Punycode, :encode_substitute, 2}], fn ->
      assert {:ok, output} =
               Iconvex.convert(
                 input,
                 "WTF-8",
                 "PUNYCODE",
                 unicode_substitute: "<U+%04X>"
               )

      assert {:ok, output} == expected
      assert trace_count({Punycode, :encode_substitute, 2}) == 1
      assert trace_count({Punycode, :encode, 1}) == 1
    end)
  end

  test "the normative RFC and independent executable oracle are immutable and licensed" do
    assert sha256(@rfc) == "d1848b1b4f01e20708a64f42394e5f4b840141935bed7f09ad7baeb6693b8772"
    assert sha256(@oracle) == "1e8d57e06e9b527009c35f2a1486ab56b51540e817f5bd8f239dc71e3fc0b014"

    assert sha256(@oracle_license) ==
             "b0e25a78cffb43f4d92de8b61ccfa1f1f98ecbc22330b54b5251e7b6ba010231"

    metadata = File.read!(@metadata)
    assert metadata =~ "RFC 3492"
    assert metadata =~ "CPython `v3.14.6`"
    assert File.read!(@oracle) =~ "def punycode_encode(text):"
    assert File.read!(@oracle_license) =~ "PYTHON SOFTWARE FOUNDATION LICENSE VERSION 2"
  end

  defp rfc_vectors do
    [_before, examples] = String.split(File.read!(@rfc), "\n7.1 Sample strings\n", parts: 2)
    [examples, _after] = String.split(examples, "\n7.2 Decoding traces\n", parts: 2)

    ~r/(?ms)^\s+\(([A-S])\)(.*?)(?=^\s+\([A-S]\)|\z)/
    |> Regex.scan(examples, capture: :all_but_first)
    |> Enum.map(fn [label, body] ->
      codepoints =
        ~r/[uU]\+([0-9A-Fa-f]+)/
        |> Regex.scan(body, capture: :all_but_first)
        |> Enum.map(fn [hex] -> String.to_integer(hex, 16) end)

      {label, codepoints, rfc_encoded(body)}
    end)
  end

  defp rfc_encoded(body) do
    lines = String.split(body, "\n")
    index = Enum.find_index(lines, &String.contains?(&1, "Punycode:"))
    [_, first] = String.split(Enum.at(lines, index), "Punycode:", parts: 2)
    collect_rfc_encoded(String.trim(first), lines, index + 1)
  end

  defp collect_rfc_encoded(part, lines, index) do
    if String.ends_with?(part, "\\") do
      prefix = String.trim_trailing(part, "\\")
      collect_rfc_encoded(prefix <> String.trim(Enum.at(lines, index)), lines, index + 1)
    else
      part
    end
  end

  defp canonical_rfc_output(bytes) do
    suffix_start =
      case :binary.matches(bytes, "-") do
        [] -> 0
        matches -> matches |> List.last() |> elem(0) |> Kernel.+(1)
      end

    <<prefix::binary-size(suffix_start), suffix::binary>> = bytes
    prefix <> String.downcase(suffix, :ascii)
  end

  defp property_corpus do
    boundaries = [0, 1, 0x2D, 0x7F, 0x80, 0x7FF, 0x800, 0xD7FF, 0xE000, 0xFFFF, 0x10000, 0x10FFFF]
    {random, _state} = random_corpus(512, :rand.seed_s(:exsss, {3492, 128, 72}), [])

    [[], ~c"ASCII", ~c"a-b-c", boundaries, Enum.reverse(boundaries) | random]
  end

  defp random_corpus(0, state, acc), do: {Enum.reverse(acc), state}

  defp random_corpus(count, state, acc) do
    {length, state} = :rand.uniform_s(48, state)
    {codepoints, state} = random_scalars(length - 1, state, [])
    random_corpus(count - 1, state, [codepoints | acc])
  end

  defp random_scalars(0, state, acc), do: {Enum.reverse(acc), state}

  defp random_scalars(count, state, acc) do
    {value, state} = :rand.uniform_s(0x10_0000, state)
    codepoint = value - 1
    codepoint = if codepoint in 0xD800..0xDFFF, do: codepoint + 0x800, else: codepoint
    random_scalars(count - 1, state, [codepoint | acc])
  end

  defp sequences(_alphabet, 0), do: [[]]

  defp sequences(alphabet, length) do
    for head <- alphabet, tail <- sequences(alphabet, length - 1), do: [head | tail]
  end

  defp python_encode(corpus) do
    script = """
    import importlib.util, sys
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location('pinned_punycode', sys.argv[1])
    punycode = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(punycode)
    for line in sys.argv[2].splitlines():
        points = [] if not line.strip() else [int(value, 16) for value in line.strip().split(',')]
        print(punycode.punycode_encode(''.join(chr(value) for value in points)).hex())
    """

    input =
      corpus
      |> Enum.map_join("\n", fn codepoints ->
        Enum.map_join(codepoints, ",", &Integer.to_string(&1, 16))
      end)
      |> Kernel.<>("\n")

    {output, 0} = System.cmd(python!(), ["-c", script, @oracle, input])

    output
    |> String.split("\n", trim: false)
    |> Enum.drop(-1)
    |> Enum.map(&Base.decode16!(String.upcase(&1)))
  end

  defp python_decode_statuses(cases) do
    script = """
    import importlib.util, sys
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location('pinned_punycode', sys.argv[1])
    punycode = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(punycode)
    for line in sys.argv[2].splitlines():
        data = bytes.fromhex(line.strip())
        try:
            punycode.punycode_decode(data, 'strict')
            print('ok')
        except (UnicodeDecodeError, OverflowError):
            print('error')
    """

    input = Enum.map_join(cases, "\n", &Base.encode16(&1, case: :lower)) <> "\n"
    {output, 0} = System.cmd(python!(), ["-c", script, @oracle, input])

    output
    |> String.split("\n", trim: true)
    |> Enum.map(&String.to_atom/1)
  end

  defp python_decode_results(cases) do
    script = """
    import importlib.util, sys
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location('pinned_punycode', sys.argv[1])
    punycode = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(punycode)
    with open(sys.argv[2], 'rt', encoding='ascii') as corpus:
        for line in corpus:
            data = bytes.fromhex(line.strip())
            try:
                decoded = punycode.punycode_decode(data, 'strict')
                print('ok:' + ','.join(f'{ord(char):X}' for char in decoded))
            except (UnicodeDecodeError, OverflowError):
                print('error')
    """

    path =
      Path.join(
        System.tmp_dir!(),
        "iconvex-punycode-corpus-#{System.unique_integer([:positive, :monotonic])}.txt"
      )

    File.write!(path, Enum.map_join(cases, "\n", &Base.encode16/1) <> "\n")

    try do
      {output, 0} = System.cmd(python!(), ["-c", script, @oracle, path])

      output
      |> String.split("\n", trim: true)
      |> Enum.map(fn
        "error" ->
          :error

        "ok:" <> values ->
          codepoints =
            if values == "" do
              []
            else
              values |> String.split(",") |> Enum.map(&String.to_integer(&1, 16))
            end

          {:ok, codepoints}
      end)
    after
      File.rm(path)
    end
  end

  defp mix_ascii_case(bytes) do
    suffix_start =
      case :binary.matches(bytes, "-") do
        [] -> 0
        matches -> matches |> List.last() |> elem(0) |> Kernel.+(1)
      end

    <<prefix::binary-size(suffix_start), suffix::binary>> = bytes

    mixed_suffix =
      suffix
      |> :binary.bin_to_list()
      |> Enum.with_index()
      |> Enum.map(fn
        {byte, index} when byte in ?a..?z and rem(index, 2) == 0 -> byte - 32
        {byte, _index} -> byte
      end)
      |> :erlang.list_to_binary()

    prefix <> mixed_suffix
  end

  defp trace_calls(mfas, function) do
    Enum.each(mfas, fn {module, _name, _arity} -> Code.ensure_loaded!(module) end)
    Enum.each(mfas, &:erlang.trace_pattern(&1, true, [:local, :call_count]))

    try do
      function.()
    after
      Enum.each(mfas, &:erlang.trace_pattern(&1, false, [:local, :call_count]))
    end
  end

  defp trace_count(mfa) do
    {:call_count, count} = :erlang.trace_info(mfa, :call_count)
    count
  end

  defp decode_reductions(encoded, expected) do
    :erlang.garbage_collect()
    {:reductions, before_count} = Process.info(self(), :reductions)
    assert Punycode.decode(encoded) == {:ok, expected}
    {:reductions, after_count} = Process.info(self(), :reductions)
    after_count - before_count
  end

  defp encode_reductions(codepoints, expected) do
    :erlang.garbage_collect()
    {:reductions, before_count} = Process.info(self(), :reductions)
    assert Punycode.encode(codepoints) == {:ok, expected}
    {:reductions, after_count} = Process.info(self(), :reductions)
    after_count - before_count
  end

  defp alternating_scalars(length) do
    odds = for value <- (length - 1)..1//-2, do: 0x2000 + value
    evens = for value <- 2..length//2, do: 0x2000 + value
    odds ++ evens
  end

  defp python!, do: System.find_executable("python3") || flunk("python3 executable required")

  defp sha256(path) do
    path |> File.read!() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
  end
end

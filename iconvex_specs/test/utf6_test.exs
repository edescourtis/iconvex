defmodule Iconvex.Specs.UTF6Test do
  use ExUnit.Case, async: false

  import Bitwise

  alias Iconvex.Specs.UTF6

  @draft Path.expand("../priv/sources/draft-ietf-idn-utf6-00/draft-ietf-idn-utf6-00.txt", __DIR__)
  @metadata Path.expand("../priv/sources/draft-ietf-idn-utf6-00/SOURCE_METADATA.md", __DIR__)
  @draft_sha256 "80033b5e41bc9f2fd01bddf99a300827b837f06ba93ef303bc54bc53df3755ca"

  test "RED: draft section 3 and compression branch vectors are exact" do
    arabic = [
      0x0645,
      0x0648,
      0x0642,
      0x0639,
      ?.,
      0x0648,
      0x0644,
      0x064A,
      0x062F,
      ?.,
      0x0634,
      0x0631,
      0x0643,
      0x0629
    ]

    vectors = [
      {arabic, "wq--ymk5k8k2j9.wq--ymk8k4kaif.wq--ymj4j1k3i9"},
      {~c"A-B", "wq--ygk1-k2"},
      {[0x305D, 0x3ABC], "wq--zjldqbc"},
      {[0x305D, 0x5834, 0x6240], "wq--j05dl834m240"},
      {[0x1F600], "wq--zto3du00"}
    ]

    for {codepoints, encoded} <- vectors do
      assert UTF6.encode(codepoints) == {:ok, encoded}
      assert UTF6.decode(encoded) == {:ok, codepoints}
      assert UTF6.decode(String.upcase(encoded, :ascii)) == {:ok, codepoints}
    end

    assert File.read!(@draft) =~ "wq--ymk5k8k2j9.wq--ymk8k4kaif.wq--ymj4j1k3i9"
  end

  @tag timeout: :infinity
  test "every Unicode scalar round-trips in a reverse-legal hostname context" do
    for codepoint <- 0..0x10FFFF, codepoint not in 0xD800..0xDFFF do
      context =
        case codepoint do
          ?. -> ~c"A.B"
          ?- -> ~c"A-B"
          _ -> [codepoint]
        end

      assert {:ok, encoded} = UTF6.encode(context)
      assert UTF6.decode(encoded) == {:ok, context}

      for label <- String.split(encoded, ".") do
        assert byte_size(label) <= 63
        assert label =~ ~r/^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$/
      end
    end
  end

  test "all high-byte and high-nibble compression choices reconstruct exact UTF-16 units" do
    for high_byte <- 0..0xFF do
      units = [high_byte <<< 8 ||| 0x21, high_byte <<< 8 ||| 0xFE]
      codepoints = units_to_scalars(units)

      if codepoints != :invalid do
        assert {:ok, "wq--y" <> _ = encoded} = UTF6.encode(codepoints)
        assert UTF6.decode(encoded) == {:ok, codepoints}
      end
    end

    for high_nibble <- 0..0xF,
        first_byte <- 0..0xF,
        second_byte <- 0..0xF,
        first_byte != second_byte do
      units = [
        high_nibble <<< 12 ||| first_byte <<< 8 ||| 0x21,
        high_nibble <<< 12 ||| second_byte <<< 8 ||| 0xFE
      ]

      codepoints = units_to_scalars(units)

      if codepoints != :invalid do
        assert {:ok, "wq--z" <> _ = encoded} = UTF6.encode(codepoints)
        assert UTF6.decode(encoded) == {:ok, codepoints}
      end
    end

    assert {:ok, "wq--" <> uncompressed} = UTF6.encode([0x305D, 0x5834])
    refute String.starts_with?(uncompressed, ["y", "z"])
  end

  test "reverse accepts DNS case folding but rejects malformed grammar and bounded values" do
    assert UTF6.decode("") == {:ok, []}
    assert UTF6.encode([]) == {:ok, ""}

    malformed = [
      {".", :invalid_sequence},
      {"wq--h.", :invalid_sequence},
      {".wq--h", :invalid_sequence},
      {"wq--h..wq--h", :invalid_sequence},
      {"abc", :invalid_sequence},
      {"wq-x", :invalid_sequence},
      {"wq--", :invalid_sequence},
      {"wq--y", :incomplete_sequence},
      {"wq--z", :incomplete_sequence},
      {"wq--yg", :invalid_sequence},
      {"wq--zg", :invalid_sequence},
      {"wq--yh00g", :invalid_sequence},
      {"wq--zh0g", :invalid_sequence},
      {"wq--ygh00", :invalid_sequence},
      {"wq--zgh000", :invalid_sequence},
      {"wq--h0000", :invalid_sequence},
      {"wq--0", :invalid_sequence},
      {"wq--w", :invalid_sequence},
      {"wq--h-", :invalid_sequence},
      {"wq--h_", :invalid_sequence},
      {<<"wq--h", 0x80>>, :invalid_sequence},
      {String.duplicate("a", 64), :invalid_sequence}
    ]

    for {input, expected_kind} <- malformed do
      assert {:error, ^expected_kind, offset, sequence} = UTF6.decode(input), input
      assert is_integer(offset) and offset >= 0
      assert is_binary(sequence) and byte_size(sequence) > 0
      assert match?({:ok, _}, UTF6.decode_discard(input))
    end
  end

  test "unpaired UTF-16 surrogates are rejected without leaking surrogate codepoints" do
    assert UTF6.decode("wq--t800") == {:error, :incomplete_sequence, 4, "t800"}
    assert UTF6.decode("wq--te00") == {:error, :invalid_sequence, 4, "te00"}

    assert UTF6.decode("wq--t800h") ==
             {:error, :invalid_sequence, 4, "t800"}

    assert UTF6.decode("wq--t800t801") ==
             {:error, :invalid_sequence, 4, "t800"}

    assert UTF6.decode_discard("wq--ht800") == {:ok, [1]}
    assert {:ok, [0x10FFFF]} = UTF6.decode(elem(UTF6.encode([0x10FFFF]), 1))
  end

  test "forward structural policy never emits a reverse-illegal label" do
    assert UTF6.encode(~c"A.") == {:error, :unrepresentable_character, ?.}
    assert UTF6.encode(~c".A") == {:error, :unrepresentable_character, ?.}
    assert UTF6.encode(~c"A..B") == {:error, :unrepresentable_character, ?.}
    assert UTF6.encode(~c"A-") == {:error, :unrepresentable_character, ?-}

    assert {:ok, accepted} = UTF6.encode(List.duplicate(?A, 28))
    assert byte_size(accepted) == 62
    assert UTF6.decode(accepted) == {:ok, List.duplicate(?A, 28)}

    assert UTF6.encode(List.duplicate(?A, 29)) ==
             {:error, :unrepresentable_character, ?A}

    assert match?({:ok, _}, UTF6.encode(List.duplicate(0, 57)))

    assert UTF6.encode(List.duplicate(0, 58)) ==
             {:error, :unrepresentable_character, 0}
  end

  test "RED: valid-scalar structural failures honor discard and substitution policies" do
    discard_cases = [
      {~c"A.", ~c"A"},
      {~c".A", ~c"A"},
      {~c"A..B", ~c"A.B"},
      {~c"A-", ~c"A"},
      {List.duplicate(?A, 29), List.duplicate(?A, 28)},
      {List.duplicate(?-, 58) ++ [0x1F600, 1], List.duplicate(?-, 58) ++ [1]}
    ]

    for {input, retained} <- discard_cases do
      assert UTF6.encode_discard(input) == UTF6.encode(retained)

      utf8 = List.to_string(input)

      assert Iconvex.convert(utf8, "UTF-8", "UTF-6", unrepresentable: :discard) ==
               UTF6.encode(retained)
    end

    substitute_cases = [
      {~c"A.", ~c"AX"},
      {~c".A", ~c"XA"},
      {~c"A..B", ~c"A.XB"},
      {~c"A-", ~c"AX"}
    ]

    for {input, replaced} <- substitute_cases do
      assert UTF6.encode_substitute(input, fn _codepoint -> ~c"X" end) ==
               UTF6.encode(replaced)
    end

    for {input, replaced} <- [
          {~c"A.", ~c"AX002E"},
          {~c".A", ~c"X002EA"},
          {~c"A..B", ~c"A.X002EB"},
          {~c"A-", ~c"AX002D"}
        ] do
      assert Iconvex.convert(List.to_string(input), "UTF-8", "UTF-6", unicode_substitute: "X%04X") ==
               UTF6.encode(replaced)
    end

    overlong = List.duplicate(?A, 29)
    replaced_tail = List.duplicate(?A, 28) ++ [0]

    assert UTF6.encode_substitute(overlong, fn ?A -> [0] end) ==
             UTF6.encode(replaced_tail)
  end

  test "scalar policies, UTF-8 fast paths, identity, and whole-string recovery are native" do
    invalid = [?A, 0xD800, ?B, 0x11_0000, 0x1F600]
    valid = [?A, ?B, 0x1F600]

    assert UTF6.encode(invalid) == {:error, :unrepresentable_character, 0xD800}
    assert UTF6.encode_discard(invalid) == UTF6.encode(valid)

    replacer = fn
      0xD800 -> ~c"SURROGATE"
      0x11_0000 -> ~c"TOO-LARGE"
    end

    replacement = ~c"ASURROGATEBTOO-LARGE" ++ [0x1F600]
    assert UTF6.encode_substitute(invalid, replacer) == UTF6.encode(replacement)

    utf8 = "A-Καλημέρα.日本語.😀"
    assert {:ok, encoded} = UTF6.encode_from_utf8(utf8)
    assert UTF6.decode_to_utf8(encoded) == {:ok, utf8}

    assert UTF6.encode_from_utf8(<<?A, 0xC2>>) ==
             {:decode_error, :incomplete_sequence, 1, <<0xC2>>}

    assert UTF6.encode_from_utf8(<<?A, 0xFF>>) ==
             {:decode_error, :invalid_sequence, 1, <<0xFF>>}

    assert UTF6.canonical_name() == "UTF-6"
    assert UTF6.aliases() == ["UTF6", "DRAFT-IETF-IDN-UTF6-00"]
    assert UTF6.codec_id() == :utf6_draft_ietf_idn_00
    assert UTF6.decode_error_recovery() == :stop
    assert UTF6.decode_error_consumption(:invalid_sequence, "abc") == 3
  end

  test "RED: shared registry, package inventory, and public conversion expose only exact identities" do
    assert UTF6 in Iconvex.Specs.codecs()
    assert "UTF-6" in Iconvex.Specs.encodings()
    assert Iconvex.canonical_name("utf6") == {:ok, "UTF-6"}
    assert Iconvex.canonical_name("draft-ietf-idn-utf6-00") == {:ok, "UTF-6"}

    input = "A-B.😀"
    assert Iconvex.convert(input, "UTF-8", "UTF-6") == {:ok, "wq--ygk1-k2.wq--zto3du00"}
    assert Iconvex.convert("wq--ygk1-k2.wq--zto3du00", "UTF-6", "UTF-8") == {:ok, input}

    registrations = Iconvex.Specs.registrations()
    assert length(registrations) == 1_841

    assert Enum.count(registrations, &(&1.codec == UTF6)) == 1

    assert File.read!("SUPPORTED_CODEC_INVENTORY.csv") =~
             "UTF-6,DRAFT-IETF-IDN-UTF6-00|UTF6,Iconvex.Specs.UTF6,false\n"

    refute UTF6 in Iconvex.Specs.non_octet_codecs()
    refute UTF6 in Iconvex.Specs.packed_codecs()
    assert length(Iconvex.Specs.non_octet_codecs()) == 25
    assert length(Iconvex.Specs.packed_codecs()) == 62

    package_files = Mix.Project.config() |> Keyword.fetch!(:package) |> Keyword.fetch!(:files)
    assert "priv/sources/draft-ietf-idn-utf6-00/*" in package_files

    for source <- [@draft, @metadata, Path.join(Path.dirname(@draft), "UPSTREAM-NOTICE.txt")] do
      assert File.regular?(source)
    end
  end

  test "whole-string discard retains only a synchronized Unicode prefix" do
    assert UTF6.decode_discard("wq--h.wq--i.wq--!") == {:ok, [1, ?., 2]}
    assert UTF6.decode_discard("wq--h.wq--it800") == {:ok, [1, ?., 2]}
    assert UTF6.decode_discard("bad.wq--h1") == {:ok, []}
  end

  test "source bytes, revision, interpretation, and redistribution terms are pinned" do
    assert sha256(@draft) == @draft_sha256
    assert UTF6.draft_revision() == "draft-ietf-idn-utf6-00"
    assert UTF6.source_sha256() == @draft_sha256

    metadata = File.read!(@metadata)
    assert metadata =~ "The distribution of this document is unlimited."
    assert metadata =~ "display-set typo"
    assert metadata =~ "UTF-16 code units"
    assert metadata =~ @draft_sha256
  end

  test "scheduler reductions establish deterministic linear whole-hostname scaling" do
    small = repeated_hostname(1_000)
    large = repeated_hostname(2_000)
    {:ok, small_encoded} = UTF6.encode(small)
    {:ok, large_encoded} = UTF6.encode(large)

    assert UTF6.decode(small_encoded) == {:ok, small}
    assert UTF6.decode(large_encoded) == {:ok, large}

    encode_ratio =
      reductions(fn -> UTF6.encode(large) end) /
        max(reductions(fn -> UTF6.encode(small) end), 1)

    decode_ratio =
      reductions(fn -> UTF6.decode(large_encoded) end) /
        max(reductions(fn -> UTF6.decode(small_encoded) end), 1)

    assert encode_ratio > 1.65 and encode_ratio < 2.35
    assert decode_ratio > 1.65 and decode_ratio < 2.35
  end

  test "structural discard recovery stays linear across repeated empty labels" do
    small = List.duplicate(~c"A..", 2_000) |> List.flatten()
    large = small ++ small

    assert {:ok, small_encoded} = UTF6.encode_discard(small)
    assert {:ok, large_encoded} = UTF6.encode_discard(large)
    assert byte_size(large_encoded) == byte_size(small_encoded) * 2 + 1

    ratio =
      reductions(fn -> UTF6.encode_discard(large) end) /
        max(reductions(fn -> UTF6.encode_discard(small) end), 1)

    assert ratio > 1.65 and ratio < 2.35
  end

  test "RED: structural substitution stays linear across repeated empty labels" do
    small = List.duplicate(~c"A..", 1_000) |> List.flatten()
    large = small ++ small
    replacer = fn ?. -> ~c"X" end

    assert {:ok, small_encoded} = UTF6.encode_substitute(small, replacer)
    assert {:ok, large_encoded} = UTF6.encode_substitute(large, replacer)
    assert byte_size(large_encoded) > byte_size(small_encoded)

    ratio =
      reductions(fn -> UTF6.encode_substitute(large, replacer) end) /
        max(reductions(fn -> UTF6.encode_substitute(small, replacer) end), 1)

    assert ratio > 1.65 and ratio < 2.35
  end

  test "RED: structural substitution preserves strict error order with dot-bearing replacements" do
    replacer = fn
      ?- -> ~c"Y"
      ?. -> ~c"X"
    end

    assert UTF6.encode(~c"A-.") == {:error, :unrepresentable_character, ?-}
    assert UTF6.encode_substitute(~c"A-.", replacer) == UTF6.encode(~c"AYX")

    small = repeated_terminal_hyphen_hostname(200)
    large = repeated_terminal_hyphen_hostname(400)
    dot_replacer = fn ?- -> ~c"X.Y" end

    assert {:ok, small_encoded} = UTF6.encode_substitute(small, dot_replacer)
    assert {:ok, large_encoded} = UTF6.encode_substitute(large, dot_replacer)
    assert byte_size(large_encoded) > byte_size(small_encoded)

    ratio =
      reductions(fn -> UTF6.encode_substitute(large, dot_replacer) end) /
        max(reductions(fn -> UTF6.encode_substitute(small, dot_replacer) end), 1)

    assert ratio > 1.65 and ratio < 2.35
  end

  defp units_to_scalars(units), do: units_to_scalars(units, [])
  defp units_to_scalars([], acc), do: :lists.reverse(acc)

  defp units_to_scalars([high, low | rest], acc)
       when high in 0xD800..0xDBFF and low in 0xDC00..0xDFFF do
    scalar = 0x10000 + ((high - 0xD800) <<< 10) + (low - 0xDC00)
    units_to_scalars(rest, [scalar | acc])
  end

  defp units_to_scalars([unit | _rest], _acc) when unit in 0xD800..0xDFFF, do: :invalid
  defp units_to_scalars([unit | rest], acc), do: units_to_scalars(rest, [unit | acc])

  defp repeated_hostname(components) do
    component = [0x0645, 0x0648, ?-, 0x0642]

    1..components
    |> Enum.intersperse(:separator)
    |> Enum.flat_map(fn
      :separator -> [?.]
      _index -> component
    end)
  end

  defp repeated_terminal_hyphen_hostname(components) do
    1..components
    |> Enum.map(fn _index -> ~c"A-" end)
    |> Enum.intersperse(~c".")
    |> List.flatten()
  end

  defp reductions(function) do
    parent = self()
    token = make_ref()

    spawn(fn ->
      :erlang.garbage_collect()
      {:reductions, before_count} = Process.info(self(), :reductions)
      result = function.()
      {:reductions, after_count} = Process.info(self(), :reductions)
      send(parent, {token, result, after_count - before_count})
    end)

    receive do
      {^token, {:ok, _value}, count} -> count
      {^token, other, _count} -> flunk("UTF-6 reduction path failed: #{inspect(other)}")
    after
      30_000 -> flunk("UTF-6 reduction measurement timed out")
    end
  end

  defp sha256(path) do
    path |> File.read!() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
  end
end

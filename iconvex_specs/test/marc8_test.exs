defmodule Iconvex.Specs.MARC8Test do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.{ANSEL, MARC8}

  test "pins the complete Library of Congress MARC-8 code-table source" do
    assert MARC8.source() == %{
             name: "MARC 21 Code Tables",
             sha256: "3e54ea62d494671cb07b3c931eda76c7f5052b204722bf576038ecbb8fb958c5",
             url: "https://www.loc.gov/marc/specifications/codetables.xml"
           }

    assert MARC8.coverage_summary() == %{
             character_sets: 12,
             combining_mappings: 60,
             primary_mappings: 16_395,
             reserved_escape_mappings: 1,
             second_half_markers: 2
           }
  end

  test "reorders MARC-8 combining marks around their Unicode base" do
    assert MARC8.decode(<<0xE2, ?e>>) == {:ok, [?e, 0x0301]}
    assert MARC8.encode([?e, 0x0301]) == {:ok, <<0xE2, ?e>>}

    assert MARC8.encode([0x00E9]) == {:ok, <<0xE2, ?e>>}
    assert MARC8.decode(<<0xE2, ?e>>) == {:ok, String.to_charlist("e\u0301")}
  end

  test "converts MARC spanning ligature and double-tilde half markers" do
    assert MARC8.decode(<<0xEB, ?a, 0xEC, ?b>>) == {:ok, [?a, 0x0361, ?b]}
    assert MARC8.encode([?a, 0x0361, ?b]) == {:ok, <<0xEB, ?a, 0xEC, ?b>>}

    assert MARC8.decode(<<0xFA, ?a, 0xFB, ?b>>) == {:ok, [?a, 0x0360, ?b]}
    assert MARC8.encode([?a, 0x0360, ?b]) == {:ok, <<0xFA, ?a, 0xFB, ?b>>}
  end

  test "implements custom, ISO 2022 one-byte, and 24-bit EACC designations" do
    assert MARC8.decode(<<0x1B, ?g, ?a, 0x1B, ?s, ?A>>) == {:ok, [0x03B1, ?A]}

    assert MARC8.decode(<<0x1B, ?(, ?2, 0x60, 0x1B, ?(, ?B, ?A>>) ==
             {:ok, [0x05D0, ?A]}

    assert MARC8.decode(<<0x1B, ?$, ?1, 0x21, 0x30, 0x21>>) == {:ok, [0x4E00]}

    assert MARC8.encode([0x03B1, 0x05D0, 0x4E00])
           |> then(fn {:ok, bytes} ->
             MARC8.decode(bytes)
           end) == {:ok, [0x03B1, 0x05D0, 0x4E00]}
  end

  test "supports G1 invocation and keeps fixed controls independent of designations" do
    assert MARC8.decode(<<0x1B, ?), ?2, 0xE0, 0x1D>>) == {:ok, [0x05D0, 0x001D]}
  end

  test "strictly distinguishes incomplete and invalid escape or multibyte sequences" do
    assert MARC8.decode(<<0x1B>>) == {:error, :incomplete_sequence, 0, <<0x1B>>}
    assert MARC8.decode(<<0x1B, ?(>>) == {:error, :incomplete_sequence, 0, <<0x1B, ?(>>}

    assert MARC8.decode(<<0x1B, ?$, ?1, 0x21>>) ==
             {:error, :incomplete_sequence, 3, <<0x21>>}

    assert MARC8.decode(<<0x1B, ?(, ?Z>>) ==
             {:error, :invalid_sequence, 0, <<0x1B, ?(, ?Z>>}
  end

  test "executes every primary LOC mapping in a valid MARC-8 stream" do
    for entry <- MARC8.mapping_entries(), entry.kind == :primary do
      input = MARC8.sample_stream(entry)

      expected =
        cond do
          entry.codepoint in [0x0360, 0x0361] -> [?A, entry.codepoint, ?B]
          entry.combining -> [?A, entry.codepoint]
          true -> [entry.codepoint]
        end

      assert MARC8.decode(input) == {:ok, expected},
             "#{entry.set} #{Base.encode16(entry.bytes)} failed"

      assert {:ok, canonical} = MARC8.encode(expected)
      assert MARC8.decode(canonical) == {:ok, expected}
    end
  end

  test "ANSEL is available as a strict default ASCII plus Extended Latin codec" do
    assert ANSEL.decode(<<0xE2, ?e>>) == {:ok, [?e, 0x0301]}
    assert ANSEL.encode([?e, 0x0301]) == {:ok, <<0xE2, ?e>>}
    assert ANSEL.decode(<<0x1B>>) == {:ok, [0x001B]}
    assert ANSEL.decode(<<0x1B, ?g, ?a>>) == {:ok, [0x001B, ?g, ?a]}
    assert ANSEL.encode([0x05D0]) == {:error, :unrepresentable_character, 0x05D0}
  end

  test "registers MARC-8 and ANSEL as external codecs" do
    assert Iconvex.canonical_name("MARC8") == {:ok, "MARC-8"}
    assert Iconvex.canonical_name("Z39.47") == {:ok, "ANSEL"}

    assert Iconvex.convert(<<0xE2, ?e>>, "MARC-8", "UTF-8") ==
             {:ok, "e\u0301"}
  end
end

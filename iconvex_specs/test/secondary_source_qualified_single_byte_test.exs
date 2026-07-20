defmodule Iconvex.Specs.SecondarySourceQualifiedSingleByteTest do
  use ExUnit.Case, async: false

  @source_dir Path.expand("../priv/sources/secondary-source-qualified-single-byte", __DIR__)
  @metadata Path.join(@source_dir, "SOURCE_METADATA.md")
  @blockers Path.join(@source_dir, "BLOCKERS.md")

  @profiles [
    %{
      module: Iconvex.Specs.Secondary.WangWiscii1983WikipediaRev1352856854,
      canonical: "WANG-1983-WISCII-PDF-F4043449-WIKIPEDIA-REV1352856854",
      file: "wang_wiscii.csv",
      mapping_sha256: "f40f80a592676f36f782481d9826996528471589795f969fe817fc3ac2c50bb7",
      mapped: 221,
      invalid: 35,
      source_identity:
        "Wang Laboratories, VS Multi-Station User's Reference, document 800-1149-01, " <>
          "December 1983, Appendix D page D-1",
      source_sha256: "f4043449df7ca900a8d2aef137b82ade74f6dcff46aed8b7d49f57af927b7dfe",
      source_size: 7_151_974,
      vector: {0xB7, [0x013F, 0x004C]}
    },
    %{
      module: Iconvex.Specs.Secondary.WikipediaWindowsPolytonicGreekRev1354794598,
      canonical: "WIKIPEDIA-REV1354794598-PARATYPE-WINDOWS-POLYTONIC-GREEK",
      file: "windows_polytonic_greek.csv",
      mapping_sha256: "12774c7a072e9976b6903f8388130891833a24d10086e59d6878ebf45d99d324",
      mapped: 256,
      invalid: 0,
      source_identity: "Wikipedia revision 1354794598 (current B5/FF ordering)",
      source_sha256: "5e7b59478b825549f63553c06e0e19a3cc2e6de1c334507a9797f605eec10a0f",
      source_size: 22_122,
      vector: {0xFF, [0x1FA3]}
    },
    %{
      module: Iconvex.Specs.Secondary.WikipediaEkiSamiWinCp1270Rev1340817319,
      canonical: "WIKIPEDIA-REV1340817319-EKI-SAMI-WIN-CP1270",
      file: "eki_sami_win_cp1270.csv",
      mapping_sha256: "9fdf47f7766938ab266cd5b9776d00329cf4083c1ce68af4fc4ce0a439ea32e4",
      mapped: 249,
      invalid: 7,
      source_identity: "Wikipedia revision 1340817319 corroborated by EKI HTML SHA-256 f25f60fa",
      source_sha256: "2dc0a6b1da5d1d279f4334cd1f8d95a9c878d022c02f6a27bd25eaf80d84ec57",
      source_size: 16_887,
      vector: {0x80, [0x20AC]}
    }
  ]

  setup_all do
    registrations =
      for profile <- @profiles do
        case Iconvex.register_codec_if_absent(profile.module) do
          {:ok, token} -> {profile.module, token}
          {:error, reason} -> raise "external registration failed: #{inspect(reason)}"
        end
      end

    on_exit(fn ->
      Enum.each(registrations, fn
        {_module, :existing} -> :ok
        {module, token} -> assert :ok = Iconvex.unregister_codec(module, token)
      end)
    end)

    :ok
  end

  test "RED: three exact codecs and three evidence blockers are exposed as one family" do
    family = Iconvex.Specs.SecondarySourceQualifiedSingleByte.Codecs
    assert Code.ensure_loaded?(family)
    assert apply(family, :modules, []) == Enum.map(@profiles, & &1.module)

    assert apply(family, :blocked_rows, []) == [
             %{id: "ENC-0067", disposition: :blocked_exact_evidence},
             %{id: "ENC-0985", disposition: :blocked_license_and_semantics},
             %{id: "ENC-1265", disposition: :blocked_ambiguous_profiles}
           ]
  end

  test "RED: normalized artifacts, complete cardinalities, and provenance pins are immutable" do
    metadata = File.read!(@metadata)

    assert metadata =~ "LGPL-2.1-or-later"
    assert metadata =~ "CC BY-SA 4.0"
    assert metadata =~ "does not imply vendor authorship, affiliation, approval, or endorsement"

    for profile <- @profiles do
      path = Path.join(@source_dir, profile.file)
      rows = parse_mapping(path)

      assert sha256(File.read!(path)) == profile.mapping_sha256
      assert length(rows) == 256
      assert Enum.count(rows, & &1.mapping) == profile.mapped
      assert Enum.count(rows, &is_nil(&1.mapping)) == profile.invalid

      assert Enum.map(rows, & &1.byte) == Enum.to_list(0..255)
      assert Enum.all?(rows, &valid_row?/1)

      for pin <- [
            profile.canonical,
            profile.source_identity,
            profile.source_sha256,
            profile.mapping_sha256,
            Integer.to_string(profile.source_size)
          ] do
        assert metadata =~ pin
      end
    end
  end

  test "RED: WISCII separates copyrighted chart evidence from the CC BY-SA Unicode binding" do
    wang = Iconvex.Specs.Secondary.WangWiscii1983WikipediaRev1352856854

    assert apply(wang, :source_identity, []) ==
             "Wang Laboratories, VS Multi-Station User's Reference, document 800-1149-01, " <>
               "December 1983, Appendix D page D-1"

    assert apply(wang, :source_license, []) == "NOASSERTION"

    assert apply(wang, :provenance, []) == %{
             normalized_mapping: %{
               license: "LGPL-2.1-or-later",
               sha256: "f40f80a592676f36f782481d9826996528471589795f969fe817fc3ac2c50bb7"
             },
             primary_chart: %{
               bundled: false,
               identity:
                 "Wang Laboratories, VS Multi-Station User's Reference, document 800-1149-01, " <>
                   "December 1983, Appendix D page D-1",
               rights: :copyrighted_documentation_no_redistribution_license_identified,
               sha256: "f4043449df7ca900a8d2aef137b82ade74f6dcff46aed8b7d49f57af927b7dfe",
               size: 7_151_974,
               url:
                 "https://bitsavers.org/pdf/wang/vs/800-1149-01_VS_Multi-Station_Users_Ref_198312.pdf"
             },
             unicode_binding: %{
               bundled: false,
               identity: "Wikipedia revision 1352856854",
               license: "CC-BY-SA-4.0",
               mediawiki_sha1: "8a2bed93cde9e5a4ac2983bbb0ce52369c5dcfc0",
               sha256: "1a9fceddcf9c4c647c88d750cdd60d9d14aecb339d727d3f7d781a826d85367f",
               size: 16_842,
               url: "https://en.wikipedia.org/w/index.php?oldid=1352856854"
             }
           }
  end

  test "RED: identities are content-qualified, alias-free, and expose the native fast path" do
    for profile <- @profiles do
      codec = profile.module

      assert apply(codec, :canonical_name, []) == profile.canonical
      assert apply(codec, :aliases, []) == []
      assert apply(codec, :__secondary_source_qualified_single_byte__, [])
      assert apply(codec, :unit_bits, []) == 8
      assert apply(codec, :inverse_policy, []) == :lowest_byte_longest_sequence
      assert apply(codec, :blank_slot_policy, []) == :strict_undefined
      assert apply(codec, :provenance_qualification, []) == :content_qualified_no_endorsement
      assert apply(codec, :mapping_sha256, []) == profile.mapping_sha256
      assert apply(codec, :mapped_byte_count, []) == profile.mapped
      assert apply(codec, :invalid_byte_count, []) == profile.invalid
      assert apply(codec, :source_identity, []) == profile.source_identity
      assert apply(codec, :source_sha256, []) == profile.source_sha256
      assert apply(codec, :source_size, []) == profile.source_size

      canonical = profile.canonical
      assert {:ok, ^canonical} = Iconvex.canonical_name(canonical)
    end

    for generic <- [
          "WISCII",
          "WANG-INTERNATIONAL",
          "WINDOWS-POLYTONIC-GREEK",
          "CP1270",
          "WINDOWS-1270",
          "SAMI-WIN"
        ] do
      case Iconvex.Registry.resolve(generic) do
        {:ok, %{codec: codec}} -> refute codec in Enum.map(@profiles, & &1.module)
        :error -> :ok
      end
    end
  end

  test "RED: every one of the 768 byte positions matches its independent artifact" do
    for profile <- @profiles do
      codec = profile.module
      rows = parse_mapping(Path.join(@source_dir, profile.file))
      inverse = canonical_inverse(rows)
      {vector_byte, vector_mapping} = profile.vector

      assert apply(codec, :decode, [<<vector_byte>>]) == {:ok, vector_mapping}
      assert apply(codec, :encode, [vector_mapping]) == {:ok, <<vector_byte>>}

      for row <- rows do
        case row.mapping do
          nil ->
            assert apply(codec, :decode, [<<row.byte>>]) ==
                     {:error, :invalid_sequence, 0, <<row.byte>>}

            assert apply(codec, :decode_discard, [<<row.byte>>]) == {:ok, []}

          mapping ->
            assert apply(codec, :decode, [<<row.byte>>]) == {:ok, mapping}
            assert apply(codec, :decode_discard, [<<row.byte>>]) == {:ok, mapping}
            assert apply(codec, :decode_to_utf8, [<<row.byte>>]) == {:ok, List.to_string(mapping)}

            assert apply(codec, :encode, [mapping]) ==
                     {:ok, <<Map.fetch!(inverse, List.to_tuple(mapping))>>}
        end
      end
    end
  end

  test "RED: duplicate inverses, sequence lookahead, policies, streams, and malformed UTF-8 are exact" do
    wang = Iconvex.Specs.Secondary.WangWiscii1983WikipediaRev1352856854

    assert apply(wang, :decode, [<<0x5E, 0x8B>>]) == {:ok, [0x2191, 0x2191]}
    assert apply(wang, :encode, [[0x2191]]) == {:ok, <<0x5E>>}
    assert apply(wang, :encode, [[0x013F, 0x004C]]) == {:ok, <<0xB7>>}
    assert apply(wang, :encode_chunk, [[0x013F], false, :error]) == {:ok, <<>>, [0x013F]}
    assert apply(wang, :encode_chunk, [[0x013F, 0x004C], true, :error]) == {:ok, <<0xB7>>, []}

    for profile <- @profiles do
      codec = profile.module
      rows = parse_mapping(Path.join(@source_dir, profile.file))

      [first, second] =
        rows
        |> Enum.filter(&(is_list(&1.mapping) and length(&1.mapping) == 1))
        |> Enum.take(2)

      [first_codepoint] = first.mapping
      [second_codepoint] = second.mapping
      source_codepoints = [first_codepoint, 0x10FFFF, second_codepoint]
      expected_discard = <<first.byte, second.byte>>
      expected_replace = <<first.byte, first.byte, second.byte>>

      assert apply(codec, :encode, [source_codepoints]) ==
               {:error, :unrepresentable_character, 0x10FFFF}

      assert apply(codec, :encode_discard, [source_codepoints]) == {:ok, expected_discard}

      assert apply(codec, :encode_substitute, [
               source_codepoints,
               fn 0x10FFFF -> [first_codepoint] end
             ]) == {:ok, expected_replace}

      assert apply(codec, :encode_substitute, [
               [0x10FFFF],
               fn 0x10FFFF -> [0x10FFFE] end
             ]) == {:error, :unrepresentable_character, 0x10FFFE}

      assert apply(codec, :decode_chunk, [expected_discard, false]) ==
               {:ok, [first_codepoint, second_codepoint], <<>>}

      assert apply(codec, :encode_chunk, [
               [first_codepoint, second_codepoint],
               false,
               :error
             ]) == {:ok, expected_discard, []}

      assert apply(codec, :encode_chunk, [source_codepoints, true, :discard]) ==
               {:ok, expected_discard, []}

      prefix = <<first_codepoint::utf8>>

      assert apply(codec, :encode_from_utf8, [prefix <> <<0xE2, 0x82>>]) ==
               {:decode_error, :incomplete_sequence, byte_size(prefix), <<0xE2, 0x82>>}

      assert apply(codec, :encode_from_utf8, [prefix <> <<0xFF>>]) ==
               {:decode_error, :invalid_sequence, byte_size(prefix), <<0xFF>>}

      assert apply(codec, :encode_from_utf8, [<<0x10FFFF::utf8, 0xFF>>]) ==
               {:error, :unrepresentable_character, 0x10FFFF}
    end
  end

  @tag timeout: 180_000
  test "RED: every Unicode scalar has exactly the artifact-defined encode result" do
    for profile <- @profiles do
      codec = profile.module
      rows = parse_mapping(Path.join(@source_dir, profile.file))
      inverse = canonical_inverse(rows)

      for codepoint <- scalar_stream() do
        expected =
          case Map.fetch(inverse, {codepoint}) do
            {:ok, byte} -> {:ok, <<byte>>}
            :error -> {:error, :unrepresentable_character, codepoint}
          end

        assert apply(codec, :encode, [[codepoint]]) == expected
      end
    end
  end

  test "RED: public conversion and streaming work through the external-codec contract" do
    for profile <- @profiles do
      rows = parse_mapping(Path.join(@source_dir, profile.file))
      valid_rows = Enum.reject(rows, &is_nil(&1.mapping))
      sample_rows = Enum.take(valid_rows, 64)
      bytes = sample_rows |> Enum.map(& &1.byte) |> :erlang.list_to_binary()
      codepoints = Enum.flat_map(sample_rows, & &1.mapping)
      utf8 = List.to_string(codepoints)

      assert Iconvex.convert(bytes, profile.canonical, "UTF-8") == {:ok, utf8}

      assert Iconvex.convert(utf8, "UTF-8", profile.canonical) ==
               {:ok, canonical_bytes(codepoints, rows)}

      chunks = for <<byte <- bytes>>, do: <<byte>>
      assert {:ok, stream} = Iconvex.stream(chunks, profile.canonical, "UTF-8")
      assert stream |> Enum.to_list() |> IO.iodata_to_binary() == utf8

      case Enum.find(rows, &is_nil(&1.mapping)) do
        nil ->
          :ok

        invalid ->
          invalid_byte = invalid.byte
          [left, right] = Enum.take(valid_rows, 2)
          input = <<left.byte, invalid_byte, right.byte>>
          recovered = List.to_string(left.mapping ++ right.mapping)

          assert {:error,
                  %Iconvex.Error{
                    kind: :invalid_sequence,
                    offset: 1,
                    sequence: <<^invalid_byte>>
                  }} = Iconvex.convert(input, profile.canonical, "UTF-8")

          assert Iconvex.convert(
                   input,
                   profile.canonical,
                   "UTF-8",
                   invalid: :discard
                 ) == {:ok, recovered}
      end
    end
  end

  test "RED: blockers preserve the exact evidence conflict instead of inventing codecs" do
    blockers = File.read!(@blockers)

    for pin <- [
          "ENC-0067",
          "d4d327400fecdaa4ce3cb2f74369c893c6921774b9255aa835aebe5e28ddb636",
          "two-byte",
          "not in Unicode",
          "ENC-0985",
          "e31f8d325640aff859f2ce53c6b69e650a0084c42ba6dcbaddaeccdf82b0e1e3",
          "All Rights reserved",
          "joining-control sequences",
          "ENC-1265",
          "c4cd07bb1be71bd5267eb9f6222839451ce344637e39e8a5b4ad0d5ffe4832a0",
          "1984 variant I",
          "1986 variant II",
          "U+02CB or U+0060",
          "U+00B5 or U+03BC"
        ] do
      assert blockers =~ pin
    end
  end

  defp parse_mapping(path) do
    ["byte_hex,unicode_sequence,status" | source_rows] =
      path |> File.read!() |> String.split("\n", trim: true)

    Enum.map(source_rows, fn row ->
      [byte_hex, sequence, status] = String.split(row, ",", parts: 3)

      mapping =
        case {sequence, status} do
          {"", "undefined"} ->
            nil

          {sequence, "assigned"} ->
            sequence |> String.split("+") |> Enum.map(&String.to_integer(&1, 16))
        end

      %{byte: String.to_integer(byte_hex, 16), mapping: mapping, status: status}
    end)
  end

  defp canonical_inverse(rows) do
    Enum.reduce(rows, %{}, fn
      %{mapping: nil}, inverse ->
        inverse

      %{byte: byte, mapping: mapping}, inverse ->
        Map.put_new(inverse, List.to_tuple(mapping), byte)
    end)
  end

  defp canonical_bytes(codepoints, rows) do
    encoder = canonical_inverse(rows)
    encode_reference(codepoints, encoder, [])
  end

  defp encode_reference([], _encoder, result),
    do: result |> :lists.reverse() |> :erlang.list_to_binary()

  defp encode_reference([a, b | rest], encoder, result) do
    case Map.fetch(encoder, {a, b}) do
      {:ok, byte} -> encode_reference(rest, encoder, [byte | result])
      :error -> encode_reference([b | rest], encoder, [Map.fetch!(encoder, {a}) | result])
    end
  end

  defp encode_reference([a | rest], encoder, result),
    do: encode_reference(rest, encoder, [Map.fetch!(encoder, {a}) | result])

  defp valid_row?(%{byte: byte, mapping: nil, status: "undefined"}), do: byte in 0..255

  defp valid_row?(%{byte: byte, mapping: mapping, status: "assigned"}) do
    byte in 0..255 and length(mapping) in 1..3 and Enum.all?(mapping, &scalar?/1)
  end

  defp scalar_stream,
    do: Stream.concat(0x0000..0xD7FF, 0xE000..0x10FFFF)

  defp scalar?(codepoint),
    do: codepoint in 0..0xD7FF or codepoint in 0xE000..0x10FFFF

  defp sha256(bytes),
    do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end

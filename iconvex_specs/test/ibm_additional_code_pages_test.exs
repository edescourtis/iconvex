defmodule Iconvex.Specs.IBMAdditionalCodePagesTest do
  use ExUnit.Case, async: true

  @source_dir Path.expand("../priv/sources/ibm-additional-code-pages", __DIR__)
  @sources_root Path.expand("../priv/sources", __DIR__)

  @join_sources [
    "ibm-additional-code-pages/CP00293.txt",
    "ibm-additional-code-pages/CP00437.txt",
    "ibm-additional-code-pages/CP00775.txt",
    "ibm-additional-code-pages/CP00850.txt",
    "ibm-additional-code-pages/CP00857.txt",
    "ibm-additional-code-pages/CP00875.txt",
    "ibm-additional-code-pages/CP01254.txt",
    "icu-data-archive/ibm-293_P100-1995.ucm",
    "icu-data-archive/ibm-437_P100-1995.ucm",
    "icu-data-archive/ibm-775_P100-1996.ucm",
    "icu-78.3/ibm-850_P100-1995.ucm",
    "icu-data-archive/ibm-857_P100-1995.ucm",
    "icu-data-archive/ibm-875_P100-1995.ucm",
    "icu-data-archive/ibm-1254_P100-1995.ucm"
  ]

  @profiles [
    %{
      codec: Iconvex.Specs.IBM310293P100CompositeVPUA,
      canonical: "IBM-310-293-P100-COMPOSITE-VPUA",
      map: "cp310-293-p100-composite-vpua.map",
      digest: "2165de9ceec4811cc4305d3c3b45d595ddaf450ab3d4dff3b25bf62b8058494e",
      defined: 139,
      collisions: %{},
      sources:
        @join_sources ++
          [
            "ibm-additional-code-pages/CP00310.txt",
            "ibm-additional-code-pages/CP00310.pdf",
            "ibm-additional-code-pages/ibm-tnz-cp310-07d60f4.py",
            "ibm-additional-code-pages/cp310-293-p100-composite-vpua.map"
          ]
    },
    %{
      codec: Iconvex.Specs.IBMTNZCP310B1EAE3C,
      canonical: "IBM-TNZ-CP310-B1EAE3C",
      map: "cp310-tnz-07d60f4.map",
      digest: "96cdf110667cdc28bb0f5e4b3a7185e3427d295f7f132f0a66e906f5bedbe932",
      defined: 143,
      collisions: %{0x2502 => 0xBF},
      sources: [
        "ibm-additional-code-pages/ibm-tnz-cp310-07d60f4.py",
        "ibm-additional-code-pages/cp310-tnz-07d60f4.map"
      ]
    },
    %{
      codec: Iconvex.Specs.IBM907CDRAP100VPUAComposite,
      canonical: "IBM-907-CDRA-P100-VPUA-COMPOSITE",
      map: "cp907-cdra-p100-vpua-composite.map",
      digest: "57f3c8b9b9a0cc40119e27315eb9748d75380d2690cd14b4816f0f9451299134",
      defined: 242,
      collisions: %{},
      sources:
        @join_sources ++
          [
            "ibm-additional-code-pages/CP00907.pdf",
            "ibm-additional-code-pages/cp907-cdra-p100-vpua-composite.map"
          ]
    },
    %{
      codec: Iconvex.Specs.IBM1116850P100Composite,
      canonical: "IBM-1116-850-P100-COMPOSITE",
      map: "cp1116-850-p100-composite.map",
      digest: "0a802f4be6b771ad0b4c7d1f958da0f599025337b5592f917bc520081a0020cb",
      defined: 255,
      collisions: %{0x00B6 => 0xF4, 0x00A7 => 0xF5},
      sources:
        @join_sources ++
          [
            "ibm-additional-code-pages/CP01116.pdf",
            "ibm-additional-code-pages/cp1116-850-p100-composite.map"
          ]
    },
    %{
      codec: Iconvex.Specs.IBM1117437P100Composite,
      canonical: "IBM-1117-437-P100-COMPOSITE",
      map: "cp1117-437-p100-composite.map",
      digest: "9f00f6453bd43c81723b8f272999293d1fe2ddcf85ea8cce5b3f04e8d0ffd91e",
      defined: 254,
      collisions: %{0x00B6 => 0xF4},
      sources:
        @join_sources ++
          [
            "ibm-additional-code-pages/CP01117.pdf",
            "ibm-additional-code-pages/cp1117-437-p100-composite.map"
          ]
    },
    %{
      codec: Iconvex.Specs.DECGreek81994,
      canonical: "DEC-GREEK-8-1994",
      map: "cp1287-dec-1994.map",
      digest: "542afe11b341a24a9ac9547d2144e2aa88e0b2dc959bbf1c984b8ff6d6795525",
      defined: 242,
      collisions: %{},
      sources: [
        "ibm-additional-code-pages/CP01287.txt",
        "ibm-additional-code-pages/CP01287.pdf",
        "ibm-additional-code-pages/DEC-PPL2-1994.pdf",
        "ibm-additional-code-pages/cp1287-dec-1994.map"
      ]
    },
    %{
      codec: Iconvex.Specs.DECTurkish81994,
      canonical: "DEC-TURKISH-8-1994",
      map: "cp1288-dec-1994.map",
      digest: "6cb89e4f2a571b9664a8c8cd66a12bf3ce221153f44adee2c8ec4fa396ba03ba",
      defined: 248,
      collisions: %{},
      sources: [
        "ibm-additional-code-pages/CP01288.txt",
        "ibm-additional-code-pages/CP01288.pdf",
        "ibm-additional-code-pages/DEC-PPL2-1994.pdf",
        "ibm-additional-code-pages/cp1288-dec-1994.map"
      ]
    }
  ]

  for profile <- @profiles do
    canonical = profile.canonical

    describe canonical do
      test "pins the exact 256-row source vector and digest" do
        profile = unquote(Macro.escape(profile))
        path = Path.join(@source_dir, profile.map)
        body = File.read!(path)

        assert byte_size(body) > 0
        assert length(String.split(body, "\n", trim: true)) == 256
        assert sha256(body) == profile.digest
        runtime_priv = :iconvex_specs |> :code.priv_dir() |> List.to_string()

        runtime_map_path =
          Path.join([runtime_priv, "sources", "ibm-additional-code-pages", profile.map])

        assert profile.codec.source_map_path() == runtime_map_path
        assert File.read!(profile.codec.source_map_path()) == body
        assert profile.codec.mapping_sha256() == profile.digest

        assert profile.codec.source_metadata_path() ==
                 Path.join([
                   runtime_priv,
                   "sources",
                   "ibm-additional-code-pages",
                   "SOURCE_METADATA.md"
                 ])

        assert File.regular?(profile.codec.source_metadata_path())
      end

      test "pins every primary and deterministic-join input by SHA-256" do
        profile = unquote(Macro.escape(profile))
        manifest = profile.codec.source_manifest()

        relative_paths =
          manifest
          |> Map.keys()
          |> Enum.sort()

        assert relative_paths == Enum.sort(profile.sources)

        for {relative_path, digest} <- manifest do
          path = Path.join(@sources_root, relative_path)
          assert File.regular?(path)
          assert path |> File.read!() |> sha256() == digest
        end
      end

      test "decodes all 256 bytes exactly, including every reserved cell" do
        profile = unquote(Macro.escape(profile))
        expected = parse_map(Path.join(@source_dir, profile.map))

        assert Code.ensure_loaded?(profile.codec)
        assert profile.codec.canonical_name() == profile.canonical
        refute profile.codec.stateful?()

        assert Enum.count(expected, fn {_byte, mapping} -> mapping != :undefined end) ==
                 profile.defined

        for {byte, mapping} <- expected do
          case mapping do
            :undefined ->
              assert profile.codec.decode(<<byte>>) ==
                       {:error, :invalid_sequence, 0, <<byte>>}

            codepoints ->
              assert profile.codec.decode(<<byte>>) == {:ok, codepoints}
          end
        end
      end

      test "round-trips the full repertoire with explicit collision policy" do
        profile = unquote(Macro.escape(profile))
        expected = parse_map(Path.join(@source_dir, profile.map))

        by_mapping =
          expected
          |> Enum.reject(fn {_byte, mapping} -> mapping == :undefined end)
          |> Enum.group_by(fn {_byte, mapping} -> mapping end, fn {byte, _mapping} -> byte end)

        actual_collisions =
          for {[codepoint], bytes} <- by_mapping,
              length(bytes) > 1,
              into: %{},
              do: {codepoint, List.last(bytes)}

        assert actual_collisions == profile.collisions

        for {mapping, bytes} <- by_mapping do
          canonical_byte = List.last(bytes)
          assert profile.codec.encode(mapping) == {:ok, <<canonical_byte>>}
          assert {:ok, ^mapping} = profile.codec.decode(<<canonical_byte>>)
        end

        assert profile.codec.encode([0x10FFFF]) ==
                 {:error, :unrepresentable_character, 0x10FFFF}
      end

      test "fast UTF-8 and discard entry points retain exact semantics" do
        profile = unquote(Macro.escape(profile))
        expected = parse_map(Path.join(@source_dir, profile.map))
        defined = Enum.reject(expected, fn {_byte, mapping} -> mapping == :undefined end)
        {sample_bytes, sample_codepoints} = sample(defined)
        utf8 = List.to_string(sample_codepoints)

        assert profile.codec.decode(sample_bytes) == {:ok, sample_codepoints}
        assert profile.codec.decode_to_utf8(sample_bytes) == {:ok, utf8}
        assert profile.codec.encode_from_utf8(utf8) == profile.codec.encode(sample_codepoints)

        undefined =
          Enum.find_value(expected, fn {byte, mapping} -> mapping == :undefined && byte end)

        if undefined do
          assert profile.codec.decode_discard(<<undefined>> <> sample_bytes) ==
                   {:ok, sample_codepoints}
        end

        assert profile.codec.encode_discard([0x10FFFF | sample_codepoints]) ==
                 profile.codec.encode(sample_codepoints)
      end

      test "chunk boundaries, stream callbacks, substitutions, and error offsets stay exact" do
        profile = unquote(Macro.escape(profile))
        expected = parse_map(Path.join(@source_dir, profile.map))
        defined = Enum.reject(expected, fn {_byte, mapping} -> mapping == :undefined end)
        source = for {byte, _mapping} <- defined, into: <<>>, do: <<byte>>
        codepoints = Enum.flat_map(defined, fn {_byte, mapping} -> mapping end)
        long_source = :binary.copy(source, 40)
        long_codepoints = List.duplicate(codepoints, 40) |> List.flatten()
        utf8 = List.to_string(long_codepoints)

        assert byte_size(long_source) > 4_096
        assert profile.codec.decode_to_utf8(long_source) == {:ok, utf8}

        assert profile.codec.decode_chunk(long_source, true) ==
                 {:ok, long_codepoints, <<>>}

        assert {:ok, encoded} = profile.codec.encode(long_codepoints)
        assert profile.codec.encode_from_utf8(utf8) == {:ok, encoded}

        assert profile.codec.encode_chunk(long_codepoints, true, :error) ==
                 {:ok, encoded, []}

        {[replacement], _byte} =
          defined
          |> Enum.map(fn {byte, mapping} -> {mapping, byte} end)
          |> Enum.find(fn {mapping, _byte} -> length(mapping) == 1 end)

        assert profile.codec.encode_substitute([0x10FFFF], fn _ -> [replacement] end) ==
                 profile.codec.encode([replacement])

        case Enum.find(expected, fn {_byte, mapping} -> mapping == :undefined end) do
          {undefined, :undefined} ->
            prefix = binary_part(source, 0, 17)

            assert profile.codec.decode(prefix <> <<undefined>>) ==
                     {:error, :invalid_sequence, 17, <<undefined>>}

          nil ->
            :ok
        end
      end
    end
  end

  test "composite profiles do not claim unversioned page aliases" do
    generic = ~w(IBM-310 CP310 IBM-907 CP907 IBM-1116 CP1116 IBM-1117 CP1117)

    composites = [
      Iconvex.Specs.IBM310293P100CompositeVPUA,
      Iconvex.Specs.IBMTNZCP310B1EAE3C,
      Iconvex.Specs.IBM907CDRAP100VPUAComposite,
      Iconvex.Specs.IBM1116850P100Composite,
      Iconvex.Specs.IBM1117437P100Composite
    ]

    for codec <- composites do
      refute codec.canonical_name() in generic
      assert MapSet.disjoint?(MapSet.new(codec.aliases()), MapSet.new(generic))
    end
  end

  test "the direct DEC profiles expose conventional page aliases" do
    assert "IBM-1287" in Iconvex.Specs.DECGreek81994.aliases()
    assert "CP1287" in Iconvex.Specs.DECGreek81994.aliases()
    assert "EL8DEC" in Iconvex.Specs.DECGreek81994.aliases()
    assert "IBM-1288" in Iconvex.Specs.DECTurkish81994.aliases()
    assert "CP1288" in Iconvex.Specs.DECTurkish81994.aliases()
    assert "TR8DEC" in Iconvex.Specs.DECTurkish81994.aliases()
  end

  test "the UTF-8 fast path reports malformed input at byte-exact offsets" do
    codec = Iconvex.Specs.DECTurkish81994

    assert codec.encode_from_utf8(<<"ok", 0xE2, 0x82>>) ==
             {:decode_error, :incomplete_sequence, 2, <<0xE2, 0x82>>}

    assert codec.encode_from_utf8(<<"ok", 0xFF>>) ==
             {:decode_error, :invalid_sequence, 2, <<0xFF>>}
  end

  defp parse_map(path) do
    path
    |> File.stream!([], :line)
    |> Enum.map(fn line ->
      [byte, rhs] = line |> String.trim() |> String.split("=", parts: 2)

      mapping =
        case rhs do
          "UNDEFINED" ->
            :undefined

          _ ->
            Regex.scan(~r/U\+([0-9A-F]+)/, rhs, capture: :all_but_first)
            |> Enum.map(fn [hex] -> String.to_integer(hex, 16) end)
        end

      {String.to_integer(byte, 16), mapping}
    end)
  end

  defp sample(defined) do
    defined
    |> Enum.take_every(max(div(length(defined), 16), 1))
    |> Enum.take(16)
    |> Enum.reduce({<<>>, []}, fn {byte, mapping}, {bytes, codepoints} ->
      {bytes <> <<byte>>, codepoints ++ mapping}
    end)
  end

  defp sha256(body), do: :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)
end

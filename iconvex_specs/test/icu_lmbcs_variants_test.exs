defmodule Iconvex.Specs.ICULMBCSVariantsTest do
  use ExUnit.Case, async: false

  @benchmark Path.expand("../bench/icu_lmbcs_variants_benchmark.exs", __DIR__)
  @benchmarks_doc Path.expand("../BENCHMARKS.md", __DIR__)

  @variants [
    {2, Iconvex.Specs.ICULMBCS2, 0x03A9, <<0xD5>>},
    {3, Iconvex.Specs.ICULMBCS3, 0x05D0, <<0xE0>>},
    {4, Iconvex.Specs.ICULMBCS4, 0x0634, <<0xD4>>},
    {5, Iconvex.Specs.ICULMBCS5, 0x0416, <<0xC6>>},
    {6, Iconvex.Specs.ICULMBCS6, 0x0104, <<0xA4>>},
    {8, Iconvex.Specs.ICULMBCS8, 0x011F, <<0xF0>>},
    {11, Iconvex.Specs.ICULMBCS11, 0x0E01, <<0xA1>>},
    {16, Iconvex.Specs.ICULMBCS16, 0x3042, <<0x82, 0xA0>>},
    {17, Iconvex.Specs.ICULMBCS17, 0xAC00, <<0xB0, 0xA1>>},
    {18, Iconvex.Specs.ICULMBCS18, 0xF600, <<0x8C, 0xEB>>},
    {19, Iconvex.Specs.ICULMBCS19, 0x9FA5, <<0xFD, 0x9B>>}
  ]

  test "RED: executable performance evidence covers all twelve ICU groups" do
    script = File.read!(@benchmark)
    documentation = File.read!(@benchmarks_doc)

    assert script =~ "benchmark_trials = 3"
    assert script =~ "ratio > 30.0"

    for group <- [1, 2, 3, 4, 5, 6, 8, 11, 16, 17, 18, 19] do
      assert script =~ "{#{group}, Iconvex.Specs.ICULMBCS#{group}}", "LMBCS-#{group} script row"
      assert documentation =~ "| LMBCS-#{group} |", "LMBCS-#{group} documentation row"
    end
  end

  @oracle_encodings %{
    2 => {6_480_803, "e52d9d79c4c7a9b5e415869ef11046f0072335bc9ac4ce21ee6cfb023fa49861"},
    3 => {6_480_816, "ce9396f83c8fcd6aa5692acad9c432a7bcaaaed8d155f71372582fa16bba5475"},
    4 => {6_480_809, "ead2cc9f1f427fad5b2aba774c17d10a5e5275b9722b5496d083f9b97e391fae"},
    5 => {6_480_774, "d95aecd8027776fbe7b4f39f3af8f9d0622fb10fa0ac453a62826f4437b9eb28"},
    6 => {6_480_817, "b97facc9c56304b6efcc3487a0b58b7d0e65e6180d356e6832c5c052fd3eebee"},
    8 => {6_480_866, "27f8cd05a72b72fee914def4eae24589baf7d4da60efdc93d99aa00e3528a422"},
    11 => {6_480_774, "9317ca095504f41bf6be58ed65ec4717067cd4c406f01c3b54d7a9e0325d3527"},
    16 => {6_478_603, "5ada4bbba306c660914fb6a3deb811462ea07cb331b0a267c1f0f6e7c00e8b26"},
    17 => {6_468_824, "cf2fa57272bca6cacb44ff2d312910f31ceaae00bd9f35c2efb89a9b8e10d9ba"},
    18 => {6_476_418, "812ad25076bf5530a91b0403ba6383fbf88bc24047895d118cf5bbe22058305b"},
    19 => {6_459_881, "8ded5d0636e59bcbbb415cbd24e8e5c3cadc82c41f05c400519d8ce2e85ab397"}
  }

  @implicit_mapping_counts %{
    2 => 127,
    3 => 117,
    4 => 128,
    5 => 128,
    6 => 127,
    8 => 128,
    11 => 128,
    16 => 9_667,
    17 => 17_238,
    18 => 19_722,
    19 => 23_942
  }

  test "implements exactly ICU 78.3's eleven additional optimization groups" do
    for {group, module, codepoint, oracle_bytes} <- @variants do
      assert module.canonical_name() == "LMBCS-#{group}"
      assert module.aliases() == []
      assert module.optimization_group() == group
      assert module.encode([codepoint]) == {:ok, oracle_bytes}
      assert module.decode(oracle_bytes) == {:ok, [codepoint]}
      canonical = "LMBCS-#{group}"

      assert {:ok, %{canonical: ^canonical, codec: ^module}} =
               Iconvex.Registry.resolve("lmbcs-#{group}")
    end

    for unsupported <- [7, 9, 10, 12, 13, 14, 15, 20],
        do: assert(Iconvex.Registry.resolve("LMBCS-#{unsupported}") == :error)
  end

  @tag timeout: 180_000
  test "matches one batched ICU 78.3 call over all 1,112,064 Unicode scalars" do
    fixture = Path.expand("fixtures/all-unicode-scalars.utf32be", __DIR__)
    codepoints = scalar_codepoints(fixture)
    assert length(codepoints) == 1_112_064

    oracle = verified_uconv()

    for {group, module, _codepoint, _bytes} <- @variants do
      assert {:ok, encoded} = module.encode(codepoints)
      {expected_size, expected_sha} = Map.fetch!(@oracle_encodings, group)
      assert byte_size(encoded) == expected_size
      assert sha256(encoded) == expected_sha

      if oracle do
        assert {^encoded, 0} =
                 System.cmd(oracle, [
                   "--block-size",
                   "5000000",
                   "--from-callback",
                   "stop",
                   "--to-callback",
                   "stop",
                   "-f",
                   "UTF-32BE",
                   "-t",
                   "LMBCS-#{group}",
                   fixture
                 ])
      end
    end
  end

  test "decodes every reachable implicit optimization-group mapping" do
    data = Iconvex.Specs.ICULMBCS1.Data.fetch()

    for {group, module, _codepoint, _bytes} <- @variants do
      rows =
        data.groups[group].decode
        |> Enum.filter(fn {bytes, _codepoint} -> implicit_form?(group, bytes) end)
        |> Enum.sort()

      assert length(rows) == Map.fetch!(@implicit_mapping_counts, group)

      encoded = rows |> Enum.map(&elem(&1, 0)) |> IO.iodata_to_binary()
      expected = Enum.map(rows, &elem(&1, 1))
      assert module.decode(encoded) == {:ok, expected}
    end
  end

  @tag timeout: 60_000
  test "cross-decodes every reachable explicit form from all thirteen subconverters" do
    data = Iconvex.Specs.ICULMBCS1.Data.fetch()

    rows =
      for {group, table} <- data.groups,
          {bytes, codepoint} <- table.decode,
          encoded <- explicit_forms(group, bytes),
          do: {encoded, codepoint}

    assert length(rows) == 72_378
    encoded = rows |> Enum.map(&elem(&1, 0)) |> IO.iodata_to_binary()
    expected = Enum.map(rows, &elem(&1, 1))

    for {_group, module, _codepoint, _bytes} <- @variants do
      assert module.decode(encoded) == {:ok, expected}
    end
  end

  test "keeps shared group forms explicit and only elides the selected group" do
    assert Iconvex.Specs.ICULMBCS1.encode([0x00E9]) == {:ok, <<0x82>>}

    for {_group, module, _codepoint, _bytes} <- @variants do
      assert module.encode([0x00E9]) == {:ok, <<0x01, 0x82>>}
      assert module.decode(<<0x01, 0x82>>) == {:ok, [0x00E9]}
    end

    # ICU's ambiguous-MBCS scan remains group-ordered; choosing LMBCS-18 does
    # not force every shared Han mapping into group 18.
    assert Iconvex.Specs.ICULMBCS18.encode([0x4E2D]) == {:ok, <<0x10, 0x92, 0x86>>}
    assert Iconvex.Specs.ICULMBCS18.encode([0xF600]) == {:ok, <<0x8C, 0xEB>>}
  end

  test "covers malformed, incomplete, discard, surrogate, and direct UTF-8 boundaries" do
    for {group, module, codepoint, oracle_bytes} <- @variants do
      assert module.decode(<<0x07, 0x80>>) ==
               {:error, :invalid_sequence, 0, <<0x07>>}

      assert module.decode(<<group>>) ==
               {:error, :incomplete_sequence, 0, <<group>>}

      assert module.decode(<<0x14>>) ==
               {:error, :incomplete_sequence, 0, <<0x14>>}

      assert module.decode(<<0x14, 0xD8>>) ==
               {:error, :incomplete_sequence, 0, <<0x14, 0xD8>>}

      assert module.decode(<<0x14, 0xD8, 0x00>>) ==
               {:error, :invalid_sequence, 0, <<0x14, 0xD8, 0x00>>}

      assert module.decode(<<0x14, 0xDC, 0x00>>) ==
               {:error, :invalid_sequence, 0, <<0x14, 0xDC, 0x00>>}

      assert module.decode(<<0x14, 0xFF, 0xFE>>) ==
               {:error, :invalid_sequence, 0, <<0x14, 0xFF, 0xFE>>}

      assert module.decode_discard(<<0x14, 0xD8, 0x00, ?A>>) == {:ok, [?A]}

      if group >= 0x10 do
        assert module.decode(<<group, 0x81>>) ==
                 {:error, :incomplete_sequence, 0, <<group, 0x81>>}

        assert module.decode(<<0x81>>) ==
                 {:error, :incomplete_sequence, 0, <<0x81>>}

        assert module.decode(<<0x81, 0x30>>) ==
                 {:error, :invalid_sequence, 0, <<0x81, 0x30>>}

        assert module.decode_discard(<<0x81, 0x30, ?A>>) == {:ok, [?A]}
      end

      sample = [?A, codepoint, 0x1F600]
      utf8 = List.to_string(sample)
      assert module.encode_from_utf8(utf8) == module.encode(sample)
      assert module.decode_to_utf8(elem(module.encode(sample), 1)) == {:ok, utf8}

      assert module.encode_from_utf8(<<0xFF>>) ==
               {:decode_error, :invalid_sequence, 0, <<0xFF>>}

      assert module.encode_from_utf8(<<0xF0, 0x9F>>) ==
               {:decode_error, :incomplete_sequence, 0, <<0xF0, 0x9F>>}

      assert module.encode([?A, 0x110000, ?B]) ==
               {:error, :unrepresentable_character, 0x110000}

      assert module.encode_discard([?A, 0x110000, ?B]) == {:ok, "AB"}

      assert module.encode_substitute([?A, 0x110000, ?B], fn 0x110000 -> ~c"<?>" end) ==
               {:ok, "A<?>B"}

      assert module.decode(oracle_bytes) == {:ok, [codepoint]}
    end
  end

  test "streams across every byte boundary including MBCS and surrogate pairs" do
    for {_group, module, codepoint, _oracle_bytes} <- @variants do
      codepoints = [?A, codepoint, 0x4E2D, 0x1F600, ?B]
      utf8 = List.to_string(codepoints)
      {:ok, encoded} = module.encode(codepoints)
      encoded_chunks = for <<byte <- encoded>>, do: <<byte>>

      assert {:ok, decoded_stream} =
               Iconvex.stream(encoded_chunks, module.canonical_name(), "UTF-8")

      assert decoded_stream |> Enum.to_list() |> IO.iodata_to_binary() == utf8

      utf8_chunks = for <<byte <- utf8>>, do: <<byte>>

      assert {:ok, encoded_stream} =
               Iconvex.stream(utf8_chunks, "UTF-8", module.canonical_name())

      streamed = encoded_stream |> Enum.to_list() |> IO.iodata_to_binary()
      assert module.decode(streamed) == {:ok, codepoints}
    end
  end

  test "pins the exact release-78.3 implementation and converter-list evidence" do
    source = Path.expand("../priv/sources/icu-78.3-lmbcs1", __DIR__)

    assert sha256(File.read!(Path.join(source, "ucnv_lmb.cpp"))) ==
             "0ca62b7469713bb992f418dc216e0395b175e51047f6a56e67b7524b1452f39b"

    assert sha256(File.read!(Path.join(source, "convrtrs.txt"))) ==
             "29340d12f664416d51c9b9d8d34e6364a10b456e668eb3155fd5f59beaf743e9"

    source_text = File.read!(Path.join(source, "ucnv_lmb.cpp"))
    aliases_text = File.read!(Path.join(source, "convrtrs.txt"))

    for {group, _module, _codepoint, _bytes} <- @variants do
      assert source_text =~ "DEFINE_LMBCS_OPEN(#{group})"
      assert source_text =~ "DECLARE_LMBCS_DATA(#{group})"
      assert aliases_text =~ "#LMBCS-#{group}"
    end

    for {_group, module, _codepoint, _bytes} <- @variants do
      refute function_exported?(module, :source_directory, 0)
      assert module.source_url() == Iconvex.Specs.ICULMBCS1.source_url()
      assert module.sources() == Iconvex.Specs.ICULMBCS1.sources()
    end

    for unsupported <- [7, 9, 10, 12, 13, 14, 15, 20] do
      refute source_text =~ "DEFINE_LMBCS_OPEN(#{unsupported})"
      refute source_text =~ "DECLARE_LMBCS_DATA(#{unsupported})"
    end
  end

  defp implicit_form?(group, <<byte>>) when group < 0x10, do: byte >= 0x80
  defp implicit_form?(group, <<byte>>) when group >= 0x10, do: byte >= 0x80
  defp implicit_form?(group, <<first, _second>>) when group >= 0x10, do: first >= 0x80
  defp implicit_form?(_group, _bytes), do: false

  defp explicit_forms(0, bytes) when byte_size(bytes) == 2, do: [bytes]

  defp explicit_forms(group, <<byte>>) when group < 0x10 and byte >= 0x80,
    do: [<<group, byte>>]

  defp explicit_forms(group, <<byte>>) when group >= 0x10,
    do: [<<group, group, byte>>]

  defp explicit_forms(group, <<first, second>>) when group >= 0x10,
    do: [<<group, first, second>>]

  defp explicit_forms(_group, _bytes), do: []

  defp scalar_codepoints(path), do: for(<<codepoint::32-big <- File.read!(path)>>, do: codepoint)

  defp verified_uconv do
    candidates = [
      System.get_env("ICONVEX_ICU_UCONV"),
      "/opt/homebrew/Cellar/icu4c@78/78.3/bin/uconv",
      "/opt/homebrew/opt/icu4c@78/bin/uconv"
    ]

    Enum.find(candidates, fn
      nil ->
        false

      path ->
        File.regular?(path) and
          case System.cmd(path, ["--version"]) do
            {version, 0} -> version =~ "ICU 78.3"
            _other -> false
          end
    end)
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

defmodule Iconvex.Specs.KamenickyKeybcs2Test do
  use ExUnit.Case, async: false

  @original Module.concat([Iconvex, Specs, KEYBCS2])
  @mysql Module.concat([Iconvex, Specs, MySQLKEYBCS2])
  @source_asset Module.concat([Iconvex, Specs, Kamenicky, SourceAsset])
  @codecs [@original, @mysql]

  @source_dir Path.expand("../priv/sources/kamenicky-keybcs2", __DIR__)
  @mapping Path.join(@source_dir, "kamenicky_high_half.csv")
  @metadata Path.join(@source_dir, "SOURCE_METADATA.md")
  @mapping_sha256 "a506b2313878affe9450787797f3f38a95734b7dec7c75a47681dca5c3e19a50"
  @metadata_sha256 "0cd52d7d7b185c27727d244f13d9e7ac790824ef209f00e25f295020b8f110a5"

  @original_high """
  010C 00FC 00E9 010F 00E4 010E 0164 010D 011B 011A 0139 00CD 013E 013A 00C4 00C1
  00C9 017E 017D 00F4 00F6 00D3 016F 00DA 00FD 00D6 00DC 0160 013D 00DD 0158 0165
  00E1 00ED 00F3 00FA 0148 0147 016E 00D4 0161 0159 0155 0154 00BC 00A7 00AB 00BB
  2591 2592 2593 2502 2524 2561 2562 2556 2555 2563 2551 2557 255D 255C 255B 2510
  2514 2534 252C 251C 2500 253C 255E 255F 255A 2554 2569 2566 2560 2550 256C 2567
  2568 2564 2565 2559 2558 2552 2553 256B 256A 2518 250C 2588 2584 258C 2590 2580
  03B1 00DF 0393 03C0 03A3 03C3 00B5 03C4 03A6 0398 03A9 03B4 221E 03C6 03B5 2229
  2261 00B1 2265 2264 2320 2321 00F7 2248 00B0 2219 00B7 221A 207F 00B2 25A0 00A0
  """

  @original_oracle Enum.to_list(0x00..0x7F) ++
                     (@original_high
                      |> String.split()
                      |> Enum.map(&String.to_integer(&1, 16)))
  @mysql_oracle List.replace_at(@original_oracle, 0xAD, 0x00A1)

  test "RED: audited source assets and both exact text profiles exist" do
    assert File.regular?(@mapping)
    assert File.regular?(@metadata)
    assert sha256_bytes(File.read!(@mapping)) == @mapping_sha256
    assert sha256_bytes(File.read!(@metadata)) == @metadata_sha256
    assert Code.ensure_loaded?(@source_asset)

    for codec <- @codecs do
      assert Code.ensure_loaded?(codec)
      assert call(codec, :unit_bits, []) == 8
      assert call(codec, :mapping_sha256, []) == @mapping_sha256
      assert call(codec, :metadata_sha256, []) == @metadata_sha256
      assert call(codec, :defined_bytes, []) == 256
      assert call(codec, :reverse_policy, []) == :exact_inverse
      assert call(codec, :control_policy, []) == :unicode_controls
    end
  end

  test "the normalized source records eight ordered 16-byte blocks" do
    rows = source_rows()

    assert length(rows) == 8
    assert Enum.map(rows, & &1.start) == Enum.to_list(0x80..0xF0//0x10)
    assert Enum.flat_map(rows, & &1.original) == Enum.drop(@original_oracle, 0x80)
    assert Enum.flat_map(rows, & &1.mysql) == Enum.drop(@mysql_oracle, 0x80)

    assert rows
           |> Enum.zip(Enum.drop(rows, 1))
           |> Enum.all?(fn {left, right} -> left.start + 0x10 == right.start end)
  end

  test "both profiles exhaustively decode all 256 bytes against independent matrices" do
    for {codec, oracle} <- [{@original, @original_oracle}, {@mysql, @mysql_oracle}],
        byte <- 0x00..0xFF do
      assert call(codec, :decode, [<<byte>>]) == {:ok, [Enum.at(oracle, byte)]}
    end

    source = :erlang.list_to_binary(Enum.to_list(0x00..0xFF))

    for {codec, oracle} <- [{@original, @original_oracle}, {@mysql, @mysql_oracle}] do
      assert call(codec, :decode, [source]) == {:ok, oracle}
      assert call(codec, :decode_to_utf8, [source]) == {:ok, List.to_string(oracle)}
    end
  end

  test "every output is unique, so every byte has an exact reverse mapping" do
    source = :erlang.list_to_binary(Enum.to_list(0x00..0xFF))

    for {codec, oracle} <- [{@original, @original_oracle}, {@mysql, @mysql_oracle}] do
      assert length(Enum.uniq(oracle)) == 256
      assert call(codec, :encode, [oracle]) == {:ok, source}
      assert call(codec, :encode_from_utf8, [List.to_string(oracle)]) == {:ok, source}

      for {codepoint, byte} <- Enum.with_index(oracle) do
        assert call(codec, :encode, [[codepoint]]) == {:ok, <<byte>>}
      end
    end
  end

  test "the original and MySQL variants differ only at byte AD" do
    differences =
      @original_oracle
      |> Enum.zip(@mysql_oracle)
      |> Enum.with_index()
      |> Enum.filter(fn {{left, right}, _byte} -> left != right end)

    assert differences == [{{0x00A7, 0x00A1}, 0xAD}]
    assert call(@original, :decode, [<<0xAD>>]) == {:ok, [0x00A7]}
    assert call(@mysql, :decode, [<<0xAD>>]) == {:ok, [0x00A1]}
    assert call(@original, :encode, [[0x00A1]]) == unrepresentable(0x00A1)
    assert call(@mysql, :encode, [[0x00A7]]) == unrepresentable(0x00A7)
  end

  test "C0, ASCII, and DEL use canonical text semantics rather than CP437 font glyphs" do
    controls = Enum.to_list(0x00..0x1F) ++ [0x7F]

    for codec <- @codecs do
      assert call(codec, :decode, [:erlang.list_to_binary(controls)]) == {:ok, controls}
      assert call(codec, :encode, [controls]) == {:ok, :erlang.list_to_binary(controls)}

      for glyph <- [0x263A, 0x2665, 0x2302] do
        assert call(codec, :encode, [[glyph]]) == unrepresentable(glyph)
      end
    end
  end

  test "strict, discard, substitution, chunk, and malformed UTF-8 paths are explicit" do
    for codec <- @codecs do
      assert call(codec, :encode, [[?A, 0x1F642, ?B]]) == unrepresentable(0x1F642)
      assert call(codec, :encode_discard, [[?A, 0x1F642, ?B]]) == {:ok, "AB"}

      assert call(codec, :encode_substitute, [
               [?A, 0x1F642, ?B],
               fn 0x1F642 -> ~c"?" end
             ]) == {:ok, "A?B"}

      assert call(codec, :decode_discard, [<<0x00, 0xFF>>]) ==
               call(codec, :decode, [<<0x00, 0xFF>>])

      assert call(codec, :decode_chunk, [<<0x80, 0xAD>>, false]) ==
               {:ok, [oracle_for(codec, 0x80), oracle_for(codec, 0xAD)], <<>>}

      assert call(codec, :encode_chunk, [[?A, ?B], false, :error]) == {:ok, "AB", []}

      assert call(codec, :encode_chunk, [[?A, 0x1F642, ?B], true, :discard]) ==
               {:ok, "AB", []}

      assert call(codec, :encode_chunk, [
               [?A, 0x1F642, ?B],
               true,
               {:replace, fn 0x1F642 -> ~c"?" end}
             ]) == {:ok, "A?B", []}

      assert call(codec, :encode_from_utf8, ["A" <> <<0xE2, 0x82>>]) ==
               {:decode_error, :incomplete_sequence, 1, <<0xE2, 0x82>>}

      assert call(codec, :encode_from_utf8, ["A" <> <<0xFF>>]) ==
               {:decode_error, :invalid_sequence, 1, <<0xFF>>}

      assert call(codec, :encode_from_utf8, [<<0x1F642::utf8, 0xFF>>]) ==
               unrepresentable(0x1F642)
    end
  end

  test "identity, safe aliases, provenance, and collision exclusions are explicit" do
    assert call(@original, :canonical_name, []) == "KEYBCS2"
    assert call(@mysql, :canonical_name, []) == "MYSQL-KEYBCS2"

    assert call(@original, :aliases, []) == [
             "KAMENICKY",
             "KAMENICKY-ORIGINAL",
             "KAMENICKY-BROTHERS",
             "KEYBCS2-ORIGINAL"
           ]

    assert call(@mysql, :aliases, []) == ["KEYBCS2-MYSQL", "MYSQL-KEYBCS2-AD-A1"]

    for codec <- @codecs,
        collision <- ["CP895", "CP-895", "895", "DOS-895", "CP867", "NEC-867", "3844"] do
      refute collision in call(codec, :aliases, [])
    end

    assert call(@original, :source_url, []) =~ "cs-encodings-faq"
    assert call(@original, :fpc_source_url, []) =~ "fd6d7d680d3ec43c61c19c2c1a841b3fa90bca03"
    assert call(@mysql, :mysql_source_url, []) =~ "d229bb760c49b65e19ec28342236961ad961d7fe"

    assert call(@original, :historical_source_sha256, []) ==
             "ac570cbd8f97bd22b65a19fe456f263508946417e46a83de232c583b62511a49"

    assert call(@original, :fpc_source_sha256, []) ==
             "adfa9b04937649657bc462c5a63a95eba53c0a895396194d3d03236fcdb8573a"

    assert call(@mysql, :mysql_source_sha256, []) ==
             "86852fa5aede60cdaaf7ce46281a60f707c8bc69067f26202127905e6b2aabe9"

    assert call(@original, :gnu_libiconv_tar_sha256, []) ==
             "88dd96a8c0464eca144fc791ae60cd31cd8ee78321e67397e25fc095c4a19aa6"

    refute call(@original, :gnu_libiconv_supported?, [])

    metadata = File.read!(@metadata)
    assert metadata =~ "Public Domain"
    assert metadata =~ "LGPL-2.1-or-later"
    assert metadata =~ "byte `AD`"
    assert metadata =~ "GNU libiconv 1.19"
    assert metadata =~ "Japanese IBM code page 895"
    assert metadata =~ "PC-BASIC"
  end

  test "the source validator locks digests, ordering, scalars, cardinality, and the AD fork" do
    csv = File.read!(@mapping)
    metadata = File.read!(@metadata)

    rows =
      call(@source_asset, :validate!, [
        csv,
        metadata,
        [mapping_sha256: @mapping_sha256, metadata_sha256: @metadata_sha256]
      ])

    assert length(rows) == 8

    assert_raise ArgumentError, ~r/mapping SHA-256 mismatch/, fn ->
      call(@source_asset, :validate!, [
        csv <> "x",
        metadata,
        [mapping_sha256: @mapping_sha256, metadata_sha256: @metadata_sha256]
      ])
    end

    reordered = reorder_first_two_rows(csv)

    assert_raise ArgumentError, ~r/ordered block.*80/i, fn ->
      call(@source_asset, :validate!, [
        reordered,
        metadata,
        [mapping_sha256: sha256_bytes(reordered), metadata_sha256: @metadata_sha256]
      ])
    end

    collapsed = String.replace(csv, "00A1", "00A7")

    assert_raise ArgumentError, ~r/AD variant fork/, fn ->
      call(@source_asset, :validate!, [
        collapsed,
        metadata,
        [mapping_sha256: sha256_bytes(collapsed), metadata_sha256: @metadata_sha256]
      ])
    end
  end

  test "direct UTF-8 paths remain linear across output chunk boundaries" do
    for codec <- @codecs do
      source = :binary.copy(<<?A>>, 8_193)
      assert call(codec, :decode_to_utf8, [source]) == {:ok, source}
      assert call(codec, :encode_from_utf8, [source]) == {:ok, source}

      small_decode =
        reductions(fn -> call(codec, :decode_to_utf8, [:binary.copy(<<?A>>, 32_768)]) end)

      large_decode =
        reductions(fn -> call(codec, :decode_to_utf8, [:binary.copy(<<?A>>, 65_536)]) end)

      small_encode =
        reductions(fn -> call(codec, :encode_from_utf8, [:binary.copy("A", 32_768)]) end)

      large_encode =
        reductions(fn -> call(codec, :encode_from_utf8, [:binary.copy("A", 65_536)]) end)

      assert_ratio(large_decode / small_decode)
      assert_ratio(large_encode / small_encode)
    end
  end

  test "public streaming is byte-identical at every source and UTF-8 split" do
    source = :erlang.list_to_binary(Enum.to_list(0x00..0xFF))

    for codec <- @codecs do
      canonical = call(codec, :canonical_name, [])
      {:ok, text} = call(codec, :decode_to_utf8, [source])

      for split <- 0..byte_size(source) do
        <<left::binary-size(split), right::binary>> = source
        assert {:ok, converter} = Iconvex.new(canonical, "UTF-8")
        assert {:ok, <<>>, converter} = Iconvex.feed(converter, left)
        assert {:ok, <<>>, converter} = Iconvex.feed(converter, right)
        assert {:ok, ^text} = Iconvex.finish(converter)
      end

      for split <- 0..byte_size(text) do
        <<left::binary-size(split), right::binary>> = text
        assert {:ok, converter} = Iconvex.new("UTF-8", canonical)
        assert {:ok, <<>>, converter} = Iconvex.feed(converter, left)
        assert {:ok, <<>>, converter} = Iconvex.feed(converter, right)
        assert {:ok, ^source} = Iconvex.finish(converter)
      end
    end
  end

  defp source_rows do
    [header | rows] = @mapping |> File.read!() |> String.split("\n", trim: true)
    assert header == "start_byte,original_unicode_scalars,mysql_unicode_scalars"

    Enum.map(rows, fn row ->
      [start, original, mysql] = String.split(row, ",")

      %{
        start: String.to_integer(start, 16),
        original: parse_sequence(original),
        mysql: parse_sequence(mysql)
      }
    end)
  end

  defp parse_sequence(value),
    do: value |> String.split("+") |> Enum.map(&String.to_integer(&1, 16))

  defp oracle_for(@original, byte), do: Enum.at(@original_oracle, byte)
  defp oracle_for(@mysql, byte), do: Enum.at(@mysql_oracle, byte)

  defp unrepresentable(codepoint),
    do: {:error, :unrepresentable_character, codepoint}

  defp call(module, function, arguments), do: apply(module, function, arguments)

  defp reorder_first_two_rows(csv) do
    [header, first, second | rest] = String.split(csv, "\n", trim: true)
    Enum.join([header, second, first | rest], "\n") <> "\n"
  end

  defp sha256_bytes(bytes),
    do: bytes |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

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
      {^token, {:ok, _result}, count} -> count
    after
      15_000 -> flunk("reduction measurement timed out")
    end
  end

  defp assert_ratio(ratio), do: assert(ratio >= 1.60 and ratio <= 2.60)
end

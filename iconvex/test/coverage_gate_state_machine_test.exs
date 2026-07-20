defmodule Iconvex.CoverageGateStateMachineTest do
  use ExUnit.Case, async: false

  alias Iconvex.{
    ISO2022CNCodec,
    ISO2022CNEncoder,
    ISO2022JPCodec,
    StatefulCodec,
    TableCodec,
    Tables
  }

  @fixtures Path.expand("fixtures/gnu-libiconv-1.19", __DIR__)
  @direct_path_fixtures [
    {"HZ", :hz, true},
    {"ISO-2022-KR", :iso2022_kr, true},
    {"ISO-2022-JP", :iso2022_jp, true},
    {"ISO-2022-JP-1", :iso2022_jp1, true},
    {"ISO-2022-JP-2", :iso2022_jp2, true},
    {"ISO-2022-JP-MS", :iso2022_jpms, true},
    {"ISO-2022-CN", :iso2022_cn, false},
    {"ISO-2022-CN-EXT", :iso2022_cn_ext, false}
  ]

  test "stateful direct paths exercise every formerly warmed variant through codec behavior" do
    for {encoding, id, direct_encode?} <- @direct_path_fixtures do
      encoded = File.read!(Path.join(@fixtures, "#{encoding}-snippet"))
      utf8 = File.read!(Path.join(@fixtures, "#{encoding}-snippet.UTF-8"))
      entry = %{id: id}

      for endian <- [:big, :little] do
        explicit = :unicode.characters_to_binary(utf8, :utf8, {:utf32, endian})

        assert StatefulCodec.decode_to_explicit_ucs4_discard(entry, encoded, endian) ==
                 {:ok, explicit}

        if direct_encode? do
          assert StatefulCodec.encode_from_explicit_ucs4_discard(entry, explicit, endian) ==
                   {:ok, encoded}
        else
          assert {:ok, codepoints} = ISO2022CNCodec.decode(entry, encoded)
          assert ISO2022CNCodec.encode(entry, codepoints) == {:ok, encoded}
        end
      end
    end

    assert StatefulCodec.decode_to_explicit_ucs4_discard(%{id: :unknown}, "A", :big) ==
             :miss

    assert StatefulCodec.decode_to_explicit_ucs4_discard(%{id: :hz}, "A", :middle) ==
             :miss

    assert StatefulCodec.encode_from_explicit_ucs4_discard(%{id: :unknown}, <<?A::32>>, :big) ==
             :miss

    assert StatefulCodec.encode_from_explicit_ucs4_discard(
             %{id: :iso2022_cn},
             <<?A::32>>,
             :big
           ) == :miss
  end

  test "ISO-2022-JP-2 direct UCS-4 preserves G2 reuse, designation reset, and block discard" do
    entry = %{id: :iso2022_jp2}
    codepoints = [0xA0, 0xA0, 0x037A, ?\n, 0xA0]
    assert {:ok, expected} = ISO2022JPCodec.encode_discard(entry, codepoints)

    assert expected ==
             <<0x1B, ".A", 0x1B, ?N, 0x20, 0x1B, ?N, 0x20, 0x1B, ".F", 0x1B, ?N, 0x2A, ?\n, 0x1B,
               ".A", 0x1B, ?N, 0x20>>

    for endian <- [:big, :little] do
      explicit = explicit_ucs4(codepoints, endian)

      assert StatefulCodec.encode_from_explicit_ucs4_discard(entry, explicit, endian) ==
               {:ok, expected}

      assert ISO2022JPCodec.decode_to_explicit_ucs4(entry, expected, endian) ==
               {:ok, explicit}

      high = explicit_ucs4(List.duplicate(0x110000, 16), endian)

      assert StatefulCodec.encode_from_explicit_ucs4_discard(
               entry,
               high <> explicit_ucs4([?A], endian),
               endian
             ) == {:ok, "A"}
    end
  end

  test "ISO-2022-JP direct discard retains MS shift semantics and malformed recovery" do
    cases = [
      {%{id: :iso2022_jp2}, <<0x1B, ".A", 0x1B, ?N, 0x7F, ?A>>},
      {%{id: :iso2022_jpms}, <<0x1B, "(J", 0x0E, 0x21, 0x0F, ?A, 0x0F>>},
      {%{id: :iso2022_jpms}, <<0x1B, "$B", 0x2D, 0x3F, 0x1B, "(B", ?A>>},
      {%{id: :iso2022_jpms}, <<0x1B, "$(D", 0x73, 0x2B, 0x1B, "(B", ?A>>}
    ]

    for {entry, input} <- cases do
      assert {:ok, codepoints} = ISO2022JPCodec.decode_discard(entry, input)

      for endian <- [:big, :little] do
        assert ISO2022JPCodec.decode_to_explicit_ucs4(entry, input, endian) ==
                 {:ok, explicit_ucs4(codepoints, endian)}
      end
    end

    greek = Tables.fetch!(:iso8859_7).one

    {undefined_index, nil} =
      0x80..0xFF
      |> Enum.map(&{&1, elem(greek, &1)})
      |> Enum.find(fn {_index, value} -> is_nil(value) end)

    invalid_g2 = <<0x1B, ".F", 0x1B, ?N, undefined_index - 0x80, ?A>>
    assert {:ok, recovered} = ISO2022JPCodec.decode_discard(%{id: :iso2022_jp2}, invalid_g2)

    assert ISO2022JPCodec.decode_to_explicit_ucs4(%{id: :iso2022_jp2}, invalid_g2, :big) ==
             {:ok, explicit_ucs4(recovered, :big)}
  end

  test "ISO-2022-JP direct discard covers JP-EXT Roman, kana, and Python mappings" do
    entry = %{id: :iso2022_jp_ext}
    input = <<0x1B, "(J", ?\\, ?~, 0x1B, "(I", 0x20, 0x21, 0x1B, "$(D", 0x22, 0x37>>
    kana = elem(elem(Tables.fetch!(:jisx0201).one, 0xA1), 0)
    expected = [0x00A5, 0x203E, kana, ?~]

    assert ISO2022JPCodec.decode_discard(entry, input) == {:ok, expected}
    assert {:ok, encoded} = ISO2022JPCodec.encode_discard(entry, expected)

    for endian <- [:big, :little] do
      explicit = explicit_ucs4(expected, endian)

      assert ISO2022JPCodec.decode_to_explicit_ucs4(entry, input, endian) ==
               {:ok, explicit}

      assert StatefulCodec.encode_from_explicit_ucs4_discard(entry, explicit, endian) ==
               {:ok, encoded}
    end
  end

  test "ISO-2022-JP-3 direct discard retains both planes and composite mappings" do
    table_key = {{Tables, :table}, :iconvex, :euc_jisx0213}
    previous = :persistent_term.get(table_key, :missing)
    cache_version = {1, Application.spec(:iconvex, :vsn) || ~c"unloaded"}

    table = %{
      one: Tuple.duplicate(nil, 256),
      many: %{
        <<0xA1, 0xA1>> => {0x1000},
        <<0x8F, 0xA1, 0xA1>> => {0x1001},
        <<0xA1, 0xA2>> => {0x1002, 0x0300}
      },
      encode: %{
        {0x1000} => <<0xA1, 0xA1>>,
        {0x1001} => <<0x8F, 0xA1, 0xA1>>,
        {0x1002, 0x0300} => <<0xA1, 0xA2>>
      },
      prefixes: MapSet.new([<<0x8F>>, <<0x8F, 0xA1>>]),
      max_input: 3,
      max_codepoints: 2
    }

    :persistent_term.put(table_key, {1, cache_version, table})

    on_exit(fn ->
      case previous do
        :missing -> :persistent_term.erase(table_key)
        value -> :persistent_term.put(table_key, value)
      end
    end)

    entry = %{id: :iso2022_jp3}

    input =
      <<0x1B, "$(Q", 0x21, 0x21, 0x1B, "$(P", 0x21, 0x21, 0x1B, "$(Q", 0x21, 0x22, 0x21, 0x23>>

    expected = [0x1000, 0x1001, 0x1002, 0x0300]
    assert ISO2022JPCodec.decode_discard(entry, input) == {:ok, expected}
    assert {:ok, encoded} = ISO2022JPCodec.encode_discard(entry, expected)

    for endian <- [:big, :little] do
      explicit = explicit_ucs4(expected, endian)

      assert ISO2022JPCodec.decode_to_explicit_ucs4(entry, input, endian) ==
               {:ok, explicit}

      assert StatefulCodec.encode_from_explicit_ucs4_discard(entry, explicit, endian) ==
               {:ok, encoded}
    end
  end

  test "ISO-2022-CN-EXT direct UCS-4 covers every designated plane in both byte orders" do
    entry = %{id: :iso2022_cn_ext}
    dispatch = ISO2022CNEncoder.fetch(:iso2022_cn_ext)

    selectors = [
      &match?({:g1, :gb2312, _pair}, &1),
      &match?({:g1, 1, _pair}, &1),
      &match?({:g1, :iso_ir_165, _pair}, &1),
      (&match?({:g2, 2, _pair}, &1))
      | for(plane <- 3..7, do: &match?({:g3, ^plane, _pair}, &1))
    ]

    codepoints =
      Enum.map(selectors, fn selector ->
        {codepoint, _action} =
          Enum.find(dispatch, fn {_codepoint, action} -> selector.(action) end)

        codepoint
      end)

    assert length(codepoints) == 9
    assert {:ok, encoded} = ISO2022CNCodec.encode(entry, codepoints)
    assert {:ok, ^codepoints} = ISO2022CNCodec.decode(entry, encoded)

    for endian <- [:big, :little] do
      assert ISO2022CNCodec.decode_to_explicit_ucs4(entry, encoded, endian) ==
               {:ok, explicit_ucs4(codepoints, endian)}
    end
  end

  test "ISO-2022-CN direct discard agrees with staged recovery for malformed and truncated sets" do
    cases = [
      {%{id: :iso2022_cn}, <<0x1B, "$)A", 0x0E, 0, 0, 0x0F, ?A>>},
      {%{id: :iso2022_cn}, <<0x1B, "$*H", 0x1B, ?N, 0, 0, ?A>>},
      {%{id: :iso2022_cn_ext}, <<0x1B, "$+I", 0x1B, ?O, 0, 0, ?A>>},
      {%{id: :iso2022_cn}, <<0x1B, "$)A", 0x0E, 0x21>>},
      {%{id: :iso2022_cn_ext}, <<0x1B, "$)E", 0x0E, 0x21>>}
    ]

    for {entry, input} <- cases do
      assert {:ok, codepoints} = ISO2022CNCodec.decode_discard(entry, input)

      for endian <- [:big, :little] do
        assert ISO2022CNCodec.decode_to_explicit_ucs4(entry, input, endian) ==
                 {:ok, explicit_ucs4(codepoints, endian)}
      end
    end
  end

  test "generic multibyte table fallback preserves expanded mappings and incomplete prefixes" do
    id = :iconvex_coverage_gate_multibyte
    table_key = {{Tables, :table}, :iconvex, id}
    trie_key = {TableCodec, :variable_width_trie, :iconvex, id, 1}
    cache_version = {1, Application.spec(:iconvex, :vsn) || ~c"unloaded"}

    one =
      nil
      |> List.duplicate(256)
      |> List.replace_at(?A, {?A, 0x0300, 0xFE0F})
      |> List.replace_at(?B, {?B})
      |> List.to_tuple()

    table = %{
      one: one,
      many: %{<<0x81, 0x40, 0x41>> => {0x4E00, 0x0301, 0xFE0F}},
      encode: %{},
      prefixes: MapSet.new([<<0x81>>, <<0x81, 0x40>>]),
      max_input: 3,
      max_codepoints: 3
    }

    :persistent_term.put(table_key, {1, cache_version, table})

    on_exit(fn ->
      :persistent_term.erase(table_key)
      :persistent_term.erase(trie_key)
    end)

    entry = %{id: id, table_app: :iconvex}
    input = <<?A, 0xFF, 0x81, 0x40, 0x41, ?B, 0x81>>
    expected = [?A, 0x0300, 0xFE0F, 0x4E00, 0x0301, 0xFE0F, ?B]

    assert TableCodec.decode_discard(entry, input) == {:ok, expected}

    for endian <- [:big, :little] do
      assert TableCodec.decode_to_explicit_ucs4_discard(entry, input, endian) ==
               {:ok, explicit_ucs4(expected, endian)}
    end

    assert TableCodec.decode_single_to_explicit_ucs4_discard(entry, input, :big) == :miss
    assert TableCodec.decode_to_explicit_ucs4_discard(entry, input, :middle) == :miss
    assert TableCodec.encode_from_explicit_ucs4_discard(entry, <<?A::32>>, :big) == :miss
    assert TableCodec.encode_from_explicit_ucs4_discard(entry, <<0>>, :middle) == :miss
  end

  test "single-byte direct decode preserves two-codepoint expansions in either byte order" do
    id = :iconvex_coverage_gate_single_expansion
    table_key = {{Tables, :table}, :iconvex, id}
    cache_version = {1, Application.spec(:iconvex, :vsn) || ~c"unloaded"}

    one =
      nil
      |> List.duplicate(256)
      |> List.replace_at(?A, {?A, 0x0301})
      |> List.replace_at(?B, {?B})
      |> List.to_tuple()

    table = %{
      one: one,
      many: %{},
      encode: %{},
      prefixes: MapSet.new(),
      max_input: 1,
      max_codepoints: 2
    }

    :persistent_term.put(table_key, {1, cache_version, table})
    on_exit(fn -> :persistent_term.erase(table_key) end)

    entry = %{id: id}
    input = <<?A, ?B, 0xFF>>
    expected = [?A, 0x0301, ?B]

    assert TableCodec.decode_to_utf8(entry, input) == {:error, :invalid_sequence, 2, <<0xFF>>}

    for endian <- [:big, :little] do
      assert TableCodec.decode_to_explicit_ucs4_discard(entry, input, endian) ==
               {:ok, explicit_ucs4(expected, endian)}
    end
  end

  test "Vietnamese non-compositions and stream replacement failures remain observable" do
    for id <- [:cp1258, :tcvn] do
      entry = %{id: id}
      table = Tables.fetch!(entry)

      {base, next} =
        Enum.find_value(table.vietnamese_base_bytes, fn base ->
          case Enum.find(0..255, fn byte ->
                 not is_nil(elem(table.one, byte)) and
                   not Map.has_key?(table.many, <<base, byte>>)
               end) do
            nil -> nil
            byte -> {base, byte}
          end
        end)

      expected = Tuple.to_list(elem(table.one, base)) ++ Tuple.to_list(elem(table.one, next))

      assert TableCodec.decode_chunk(entry, <<base, next>>, false) ==
               {:ok, expected, <<>>}
    end

    assert TableCodec.encode_chunk(
             %{id: :big5hkscs2008},
             [0x110000, ?A],
             false,
             {:replace, fn _ -> [0x110000] end}
           ) == {:error, :unrepresentable_character, 0x110000}
  end

  test "ISO-2022-KR direct discard preserves invalid and incomplete shifted pairs" do
    entry = %{id: :iso2022_kr}

    for input <- [
          <<0x1B, "$)C", 0x0E, 0x21>>,
          <<0x1B, "$)C", 0x0E, 0, 0, 0x0F, ?A>>
        ] do
      assert {:ok, codepoints} = StatefulCodec.decode_discard(entry, input)

      for endian <- [:big, :little] do
        assert StatefulCodec.decode_to_explicit_ucs4_discard(entry, input, endian) ==
                 {:ok, explicit_ucs4(codepoints, endian)}
      end
    end

    assert StatefulCodec.encode_substitute(entry, [0x110000], fn _ -> [0x110000] end) ==
             {:error, :unrepresentable_character, 0x110000}
  end

  defp explicit_ucs4(codepoints, :big) do
    for codepoint <- codepoints, into: <<>>, do: <<codepoint::unsigned-big-32>>
  end

  defp explicit_ucs4(codepoints, :little) do
    for codepoint <- codepoints, into: <<>>, do: <<codepoint::unsigned-little-32>>
  end
end

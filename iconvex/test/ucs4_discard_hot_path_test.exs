defmodule Iconvex.UCS4DiscardHotPathTest do
  use ExUnit.Case, async: false

  alias Iconvex.{TableCodec, UnicodeCodec}

  @corpus Path.expand("fixtures/all-unicode-codepoints.ucs4be", __DIR__)

  test "all-codepoint UCS-4BE discard paths preserve bytes without staged codepoint lists" do
    corpus = File.read!(@corpus)

    {results, calls} =
      count_calls(
        [
          {UnicodeCodec, :decode, 2},
          {TableCodec, :encode_discard, 2},
          {TableCodec, :decode_discard, 2}
        ],
        fn ->
          utf8 = Iconvex.convert!(corpus, "UCS-4BE", "UTF-8", unrepresentable: :discard)
          ascii = Iconvex.convert!(corpus, "UCS-4BE", "US-ASCII", unrepresentable: :discard)

          ascii_roundtrip =
            Iconvex.convert!(
              :binary.list_to_bin(Enum.to_list(0..255)),
              "US-ASCII",
              "UCS-4BE",
              invalid: :discard
            )

          {utf8, ascii, ascii_roundtrip}
        end
      )

    {utf8, ascii, ascii_roundtrip} = results

    expected_utf8 =
      for <<codepoint::unsigned-big-32 <- corpus>>,
          codepoint not in 0xD800..0xDFFF,
          into: <<>>,
          do: <<codepoint::utf8>>

    expected_ascii = :binary.list_to_bin(Enum.to_list(0..127))
    expected_ascii_roundtrip = for codepoint <- 0..127, into: <<>>, do: <<codepoint::32>>

    assert utf8 == expected_utf8
    assert ascii == expected_ascii
    assert ascii_roundtrip == expected_ascii_roundtrip

    assert calls == %{
             {UnicodeCodec, :decode, 2} => 0,
             {TableCodec, :encode_discard, 2} => 0,
             {TableCodec, :decode_discard, 2} => 0
           }
  end

  test "explicit UCS-4 endian variants discard only non-scalars and preserve malformed tails" do
    endian = :erlang.system_info(:endian)
    swapped = if endian == :big, do: :little, else: :big

    values = [0, ?A, 0xD800, 0xDFFF, 0x1F600, 0x11_0000, 0xFFFFFFFF]
    utf8 = <<0, ?A, 0x1F600::utf8>>
    ascii = <<0, ?A>>

    for {source, source_endian} <- [
          {"UCS-4BE", :big},
          {"UCS-4LE", :little},
          {"UCS-4-INTERNAL", endian},
          {"UCS-4-SWAPPED", swapped}
        ] do
      input = Enum.map_join(values, &word32(&1, source_endian))

      assert Iconvex.convert!(input, source, "UTF-8", unrepresentable: :discard) == utf8
      assert Iconvex.convert!(input, source, "US-ASCII", unrepresentable: :discard) == ascii
      assert Iconvex.convert!(<<>>, source, "UTF-8", unrepresentable: :discard) == <<>>
      assert Iconvex.convert!(<<>>, source, "US-ASCII", unrepresentable: :discard) == <<>>

      for tail_size <- 1..3 do
        tail = :binary.copy(<<0xAA>>, tail_size)
        malformed = word32(?A, source_endian) <> tail

        assert {:error,
                %Iconvex.Error{
                  kind: :incomplete_sequence,
                  offset: 4,
                  sequence: ^tail
                }} =
                 Iconvex.convert(malformed, source, "UTF-8", unrepresentable: :discard)

        assert Iconvex.convert(
                 malformed,
                 source,
                 "UTF-8",
                 invalid: :discard,
                 unrepresentable: :discard
               ) == {:ok, "A"}
      end
    end
  end

  test "explicit UCS-4 callbacks and transforming policies retain the general pipeline" do
    parent = self()
    malformed = <<?A::unsigned-big-32, 0xAA, 0xBB>>

    callback = fn event ->
      send(parent, {:invalid, event})
      {:replace, ??}
    end

    assert Iconvex.convert(
             malformed,
             "UCS-4BE",
             "UTF-8",
             unrepresentable: :discard,
             on_invalid_byte: callback
           ) == {:ok, "A?"}

    assert_receive {:invalid,
                    %Iconvex.InvalidByte{
                      kind: :incomplete_sequence,
                      offset: 4,
                      byte: 0xAA,
                      sequence: <<0xAA, 0xBB>>
                    }}

    transliterated_source = <<?A::unsigned-big-32, 0xE9::unsigned-big-32>>

    assert Iconvex.convert(transliterated_source, "UCS-4BE", "US-ASCII",
             transliterate: true,
             unrepresentable: :discard
           ) == {:ok, "A'e"}

    substituted_source =
      <<?A::unsigned-big-32, 0xE9::unsigned-big-32, 0xD800::unsigned-big-32>>

    assert Iconvex.convert(substituted_source, "UCS-4BE", "US-ASCII",
             unicode_substitute: "<U+%04X>"
           ) ==
             {:ok, "A<U+00E9><U+D800>"}
  end

  test "single-byte table decode writes every expanded codepoint in target byte order" do
    id = :iconvex_test_ucs4_expanding_single_byte
    cache_key = {{Iconvex.Tables, :table}, :iconvex, id}
    cache_version = {1, Application.spec(:iconvex, :vsn) || ~c"unloaded"}

    one =
      nil
      |> List.duplicate(256)
      |> List.replace_at(0x6F, {0xF860, ?F, ?1})
      |> List.to_tuple()

    table = %{
      one: one,
      many: %{},
      encode: %{},
      prefixes: MapSet.new(),
      max_input: 1,
      max_codepoints: 3
    }

    :persistent_term.put(cache_key, {1, cache_version, table})
    on_exit(fn -> :persistent_term.erase(cache_key) end)

    entry = %{id: id}

    assert TableCodec.decode_single_to_explicit_ucs4_discard(entry, <<0x6F, 0xFF>>, :big) ==
             {:ok, <<0xF860::unsigned-big-32, ?F::unsigned-big-32, ?1::unsigned-big-32>>}

    assert TableCodec.decode_single_to_explicit_ucs4_discard(entry, <<0x6F, 0xFF>>, :little) ==
             {:ok, <<0xF860::unsigned-little-32, ?F::unsigned-little-32, ?1::unsigned-little-32>>}
  end

  test "generic multibyte table decode writes UCS-4 directly with exact discard recovery" do
    id = :iconvex_test_ucs4_multibyte_table
    cache_key = {{Iconvex.Tables, :table}, :iconvex, id}
    cache_version = {1, Application.spec(:iconvex, :vsn) || ~c"unloaded"}

    one =
      nil
      |> List.duplicate(256)
      |> List.replace_at(?A, {?A})
      |> List.to_tuple()

    table = %{
      one: one,
      many: %{<<0x81, 0x40>> => {0x4E00}, <<0x81, 0x41>> => {0xF860, ?F, ?1}},
      encode: %{},
      prefixes: MapSet.new([<<0x81>>]),
      max_input: 2,
      max_codepoints: 3
    }

    :persistent_term.put(cache_key, {1, cache_version, table})
    on_exit(fn -> :persistent_term.erase(cache_key) end)
    entry = %{id: id}
    input = <<?A, 0xFF, 0x81, 0x40, 0x81, 0x41, 0x81>>

    assert TableCodec.decode_to_explicit_ucs4_discard(entry, input, :big) ==
             {:ok,
              <<?A::unsigned-big-32, 0x4E00::unsigned-big-32, 0xF860::unsigned-big-32,
                ?F::unsigned-big-32, ?1::unsigned-big-32>>}

    assert {:ok, codepoints} = TableCodec.decode_discard(entry, input)
    assert {:ok, expected} = UnicodeCodec.encode(%{id: :ucs4le}, codepoints)

    assert TableCodec.decode_to_explicit_ucs4_discard(entry, input, :little) ==
             {:ok, expected}
  end

  test "real CP932 and EUC-CN multibyte tables match staged discard decoding" do
    for id <- [:cp932, :euc_cn] do
      entry = %{id: id}
      table = Iconvex.Tables.fetch!(entry)

      encoded =
        table.many
        |> Map.keys()
        |> Enum.sort()
        |> IO.iodata_to_binary()
        |> then(&(&1 <> <<0xFF>>))

      assert {:ok, codepoints} = TableCodec.decode_discard(entry, encoded)

      for endian <- [:big, :little] do
        expected = IO.iodata_to_binary(Enum.map(codepoints, &word32(&1, endian)))

        assert TableCodec.decode_to_explicit_ucs4_discard(entry, encoded, endian) ==
                 {:ok, expected}
      end
    end
  end

  test "variable-width and Vietnamese tables retain longest-match discard boundaries" do
    for id <- [:cp1255, :euc_jp, :euc_tw, :cp1258, :tcvn] do
      entry = %{id: id}
      table = Iconvex.Tables.fetch!(entry)
      prefix = Enum.min_by(table.prefixes, &byte_size/1)

      encoded =
        table.many
        |> Map.keys()
        |> Enum.sort()
        |> IO.iodata_to_binary()
        |> then(&(&1 <> <<0xFF, ?A>> <> prefix))

      assert {:ok, codepoints} = TableCodec.decode_discard(entry, encoded)

      for endian <- [:big, :little] do
        expected = IO.iodata_to_binary(Enum.map(codepoints, &word32(&1, endian)))

        assert TableCodec.decode_to_explicit_ucs4_discard(entry, encoded, endian) ==
                 {:ok, expected}
      end
    end
  end

  test "EUC-JP direct discard decode bypasses the recursive variable-width matcher" do
    entry = %{id: :euc_jp}
    table = Iconvex.Tables.fetch!(entry)
    matcher = {TableCodec, :longest_trie_match, 4}
    direct_matcher = {TableCodec, :euc_jp_trie_match, 2}

    boundary_bytes = [0x00, 0x20, 0x7F, 0x80, 0x8E, 0x8F, 0xA0, 0xA1, 0xDF, 0xFE, 0xFF]

    two_byte_grid =
      for first <- boundary_bytes, second <- boundary_bytes do
        <<first, second, ?A>>
      end

    three_byte_grid =
      for second <- boundary_bytes, third <- boundary_bytes do
        <<0x8F, second, third, ?A>>
      end

    input =
      IO.iodata_to_binary([
        <<0xFF, ?A>>,
        table.many |> Map.keys() |> Enum.sort(),
        two_byte_grid,
        three_byte_grid,
        # Both are valid EUC-JP prefixes, but incomplete at end of input.
        <<0x8F, 0xA1>>
      ])

    assert {:ok, codepoints} = TableCodec.decode_discard(entry, input)

    for endian <- [:big, :little] do
      expected = IO.iodata_to_binary(Enum.map(codepoints, &word32(&1, endian)))

      {result, calls} =
        count_calls([matcher, direct_matcher], fn ->
          TableCodec.decode_to_explicit_ucs4_discard(entry, input, endian)
        end)

      assert result == {:ok, expected}
      assert calls[matcher] == 0
      assert calls[direct_matcher] > 0
    end
  end

  test "EUC-JP direct trie fails closed and repairs a malformed cached branch" do
    entry = %{id: :euc_jp}
    table = Iconvex.Tables.fetch!(entry)

    {bytes, {codepoint}} =
      Enum.find(table.many, fn
        {<<0x8F, _::binary>>, _codepoints} -> false
        {_two_byte_mapping, _codepoints} -> true
      end)

    assert TableCodec.decode_to_explicit_ucs4_discard(entry, bytes, :big) ==
             {:ok, word32(codepoint, :big)}

    cache_key = {TableCodec, :variable_width_decode_trie, :iconvex, :euc_jp, 1}
    previous = :persistent_term.get(cache_key)

    on_exit(fn -> :persistent_term.put(cache_key, previous) end)

    {schema, kind, source, trie} = previous
    <<first, _second>> = bytes
    poisoned = put_elem(trie, first, :malformed)
    :persistent_term.put(cache_key, {schema, kind, source, poisoned})

    assert TableCodec.decode_to_explicit_ucs4_discard(entry, bytes, :big) ==
             {:ok, word32(codepoint, :big)}

    assert {^schema, ^kind, ^source, repaired} = :persistent_term.get(cache_key)
    refute repaired === poisoned
  end

  test "external EUC-JP provider preserves output across fast-to-generic fallback" do
    app = :iconvex_test_euc_jp_provider
    entry = %{id: :euc_jp}
    table_key = {{Iconvex.Tables, :table}, app, :euc_jp}
    trie_key = {TableCodec, :variable_width_decode_trie, :iconvex, :euc_jp, 1}
    previous_trie = :persistent_term.get(trie_key, :missing)
    cache_version = {1, Application.spec(app, :vsn) || ~c"unloaded"}

    one =
      nil
      |> List.duplicate(256)
      |> List.replace_at(?A, {?A})
      |> List.to_tuple()

    table = %{
      one: one,
      many: %{
        <<0x82, 0x42>> => {0x2605},
        <<0x81, 0x40>> => {0x2603},
        <<0x81, 0x40, 0x41>> => {0x2604}
      },
      encode: %{},
      prefixes: MapSet.new([<<0x81>>, <<0x81, 0x40>>, <<0x82>>]),
      max_input: 3,
      max_codepoints: 1
    }

    on_exit(fn ->
      Iconvex.Tables.unregister_provider(:euc_jp, app)
      :persistent_term.erase(table_key)

      case previous_trie do
        :missing -> :persistent_term.erase(trie_key)
        value -> :persistent_term.put(trie_key, value)
      end
    end)

    :persistent_term.put(table_key, {1, cache_version, make_ref(), table})
    assert :ok = Iconvex.Tables.register_provider(:euc_jp, app)

    input =
      <<0x82, 0x42, 0x81, 0x40, 0x41, 0x81, 0x40, 0x81, 0x40, 0xFF, ?A, 0x81>>

    assert {:ok, codepoints = [0x2605, 0x2604, 0x2603, 0x2603, ?A]} =
             TableCodec.decode_discard(entry, input)

    direct_matcher = {TableCodec, :euc_jp_trie_match, 2}
    generic_matcher = {TableCodec, :longest_trie_match, 4}

    for endian <- [:big, :little] do
      expected = IO.iodata_to_binary(Enum.map(codepoints, &word32(&1, endian)))

      {result, calls} =
        count_calls([direct_matcher, generic_matcher], fn ->
          TableCodec.decode_to_explicit_ucs4_discard(entry, input, endian)
        end)

      assert result == {:ok, expected}
      assert calls[direct_matcher] > 0
      assert calls[generic_matcher] > 0
    end
  end

  test "sparse variable-width tries bypass recursive matching for ordinary bytes" do
    entry = %{id: :cp1255}
    input = :binary.copy("ASCII-only CP1255 reverse path\n", 32)
    matcher = {TableCodec, :longest_trie_match, 4}

    expected =
      for <<byte <- input>>, into: <<>> do
        <<byte::unsigned-big-32>>
      end

    {result, calls} =
      count_calls([matcher], fn ->
        TableCodec.decode_to_explicit_ucs4_discard(entry, input, :big)
      end)

    assert result == {:ok, expected}
    assert calls[matcher] == 0
  end

  test "direct dense and single-byte UCS-4 decoding avoids one binary per mapping" do
    dense_entry = %{id: :cp932}
    dense_table = Iconvex.Tables.fetch!(dense_entry)

    {dense_bytes, {dense_codepoint}} =
      Enum.find(dense_table.many, fn {_bytes, value} -> tuple_size(value) == 1 end)

    dense_input = :binary.copy(dense_bytes, 2_048)
    single_input = :binary.copy("A", 4_096)
    word_builder = {TableCodec, :ucs4_word, 2}
    tuple_builder = {TableCodec, :codepoints_to_ucs4, 2}

    {results, calls} =
      count_calls([word_builder, tuple_builder], fn ->
        for endian <- [:big, :little] do
          {
            TableCodec.decode_to_explicit_ucs4_discard(dense_entry, dense_input, endian),
            TableCodec.decode_single_to_explicit_ucs4_discard(
              %{id: :cp1252},
              single_input,
              endian
            )
          }
        end
      end)

    for {endian, {{:ok, dense}, {:ok, single}}} <- Enum.zip([:big, :little], results) do
      assert dense == :binary.copy(word32(dense_codepoint, endian), 2_048)
      assert single == :binary.copy(word32(?A, endian), 4_096)
    end

    assert calls[word_builder] == 0
    assert calls[tuple_builder] == 0
  end

  test "ASCII direct UCS-4 discard bypasses table loading for every input byte" do
    input = IO.iodata_to_binary(for byte <- 0..0xFF, do: <<byte>>)
    fetch = {Iconvex.Tables, :fetch!, 1}

    for endian <- [:big, :little] do
      expected = IO.iodata_to_binary(for codepoint <- 0..0x7F, do: word32(codepoint, endian))

      {result, calls} =
        count_calls([fetch], fn ->
          TableCodec.decode_to_explicit_ucs4_discard(%{id: :ascii}, input, endian)
        end)

      assert result == {:ok, expected}
      assert calls[fetch] == 0
    end
  end

  test "dense two-byte cache follows a reloaded provider table" do
    id = :cp932
    entry = %{id: id}
    table = Iconvex.Tables.fetch!(entry)
    {bytes, {original}} = Enum.find(table.many, fn {_bytes, value} -> tuple_size(value) == 1 end)
    replacement = if original == 0x2603, do: 0x2604, else: 0x2603

    assert TableCodec.decode_to_explicit_ucs4_discard(entry, bytes, :big) ==
             {:ok, word32(original, :big)}

    cache_key = {{Iconvex.Tables, :table}, :iconvex, id}
    previous = :persistent_term.get(cache_key)
    cache_version = {1, Application.spec(:iconvex, :vsn) || ~c"unloaded"}
    changed = put_in(table, [:many, bytes], {replacement})

    :persistent_term.put(cache_key, {1, cache_version, changed})
    on_exit(fn -> :persistent_term.put(cache_key, previous) end)

    assert TableCodec.decode_to_explicit_ucs4_discard(entry, bytes, :big) ==
             {:ok, word32(replacement, :big)}
  end

  test "variable-width trie follows a reloaded provider table" do
    id = :cp1255
    entry = %{id: id}
    table = Iconvex.Tables.fetch!(entry)
    {bytes, {original}} = Enum.find(table.many, fn {_bytes, value} -> tuple_size(value) == 1 end)
    replacement = if original == 0x2603, do: 0x2604, else: 0x2603

    assert TableCodec.decode_to_explicit_ucs4_discard(entry, bytes, :little) ==
             {:ok, word32(original, :little)}

    cache_key = {{Iconvex.Tables, :table}, :iconvex, id}
    previous = :persistent_term.get(cache_key)
    cache_version = {1, Application.spec(:iconvex, :vsn) || ~c"unloaded"}
    changed = put_in(table, [:many, bytes], {replacement})

    :persistent_term.put(cache_key, {1, cache_version, changed})
    on_exit(fn -> :persistent_term.put(cache_key, previous) end)

    assert TableCodec.decode_to_explicit_ucs4_discard(entry, bytes, :little) ==
             {:ok, word32(replacement, :little)}
  end

  test "UCS-4 table encoder preserves longest-match semantics for two-codepoint keys" do
    id = :iconvex_test_ucs4_sequence_table
    cache_key = {{Iconvex.Tables, :table}, :iconvex, id}
    cache_version = {1, Application.spec(:iconvex, :vsn) || ~c"unloaded"}

    table = %{
      one: Tuple.duplicate(nil, 256),
      many: %{},
      encode: %{{?A, 0x0300} => <<1>>, {?A} => <<2>>, {?B} => <<3>>},
      prefixes: MapSet.new(),
      max_input: 1,
      max_codepoints: 2
    }

    :persistent_term.put(cache_key, {1, cache_version, table})
    on_exit(fn -> :persistent_term.erase(cache_key) end)

    for endian <- [:big, :little] do
      input =
        IO.iodata_to_binary([
          word32(?A, endian),
          word32(0x0300, endian),
          word32(?A, endian),
          word32(0x110000, endian),
          word32(?B, endian)
        ])

      assert TableCodec.encode_from_explicit_ucs4_discard(%{id: id}, input, endian) ==
               {:ok, <<1, 2, 3>>}
    end
  end

  test "single-byte discard decode supports every explicit UCS-4 target endian" do
    input = <<?A, 0xFF, ?B>>
    endian = :erlang.system_info(:endian)
    swapped = if endian == :big, do: :little, else: :big

    for {target, target_endian} <- [
          {"UCS-4BE", :big},
          {"UCS-4LE", :little},
          {"UCS-4-INTERNAL", endian},
          {"UCS-4-SWAPPED", swapped}
        ] do
      assert Iconvex.convert!(input, "US-ASCII", target, invalid: :discard) ==
               word32(?A, target_endian) <> word32(?B, target_endian)
    end

    parent = self()

    assert Iconvex.convert(input, "US-ASCII", "UCS-4BE",
             invalid: :discard,
             on_invalid_byte: fn event ->
               send(parent, {:invalid, event})
               {:replace, ??}
             end
           ) == {:ok, <<?A::32, ??::32, ?B::32>>}

    assert_receive {:invalid,
                    %Iconvex.InvalidByte{
                      kind: :invalid_sequence,
                      offset: 1,
                      byte: 0xFF,
                      sequence: <<0xFF>>
                    }}
  end

  defp count_calls(mfas, function) do
    Enum.each(mfas, fn {module, _name, _arity} = mfa ->
      Code.ensure_loaded!(module)
      :erlang.trace_pattern(mfa, true, [:local, :call_count])
    end)

    try do
      result = function.()

      calls =
        Map.new(mfas, fn mfa ->
          {:call_count, count} = :erlang.trace_info(mfa, :call_count)
          {mfa, count}
        end)

      {result, calls}
    after
      Enum.each(mfas, &:erlang.trace_pattern(&1, false, [:local, :call_count]))
    end
  end

  defp word32(codepoint, :big), do: <<codepoint::unsigned-big-32>>
  defp word32(codepoint, :little), do: <<codepoint::unsigned-little-32>>
end

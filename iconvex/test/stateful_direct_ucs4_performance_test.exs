defmodule Iconvex.StatefulDirectUCS4PerformanceTest do
  use ExUnit.Case, async: false

  alias Iconvex.{Registry, StatefulCodec, StatefulPairCache, UTF7Codec}

  @fixtures Path.expand("fixtures/gnu-libiconv-1.19", __DIR__)
  @encodings [
    "HZ",
    "ISO-2022-KR",
    "ISO-2022-JP",
    "ISO-2022-JP-1",
    "ISO-2022-JP-2",
    "ISO-2022-JP-MS",
    "ISO-2022-CN",
    "ISO-2022-CN-EXT"
  ]

  test "RED: valid stateful input decodes directly to explicit UCS-4 in either byte order" do
    for encoding <- @encodings do
      encoded = File.read!(Path.join(@fixtures, "#{encoding}-snippet"))
      utf8 = File.read!(Path.join(@fixtures, "#{encoding}-snippet.UTF-8"))
      {:ok, entry} = Registry.resolve(encoding)

      expected_big = :unicode.characters_to_binary(utf8, :utf8, {:utf32, :big})
      expected_little = :unicode.characters_to_binary(utf8, :utf8, {:utf32, :little})

      assert StatefulCodec.decode_to_explicit_ucs4_discard(entry, encoded, :big) ==
               {:ok, expected_big}

      assert StatefulCodec.decode_to_explicit_ucs4_discard(entry, encoded, :little) ==
               {:ok, expected_little}
    end
  end

  test "RED: direct decoding performs the same malformed-input discard recovery" do
    malformed = [
      {"HZ", "~"},
      {"ISO-2022-KR", <<0x1B, ?$, ?)>>},
      {"ISO-2022-JP", <<0x1B, ?$>>},
      {"ISO-2022-JP-1", <<0x1B, ?$, ?(>>},
      {"ISO-2022-JP-2", <<0x1B, ?N>>},
      {"ISO-2022-JP-MS", <<0x1B, ?$, ?(>>},
      {"ISO-2022-CN", <<0x1B, ?$, ?)>>},
      {"ISO-2022-CN-EXT", <<0x1B, ?$, ?+>>}
    ]

    for {encoding, input} <- malformed do
      {:ok, entry} = Registry.resolve(encoding)
      {:ok, expected_codepoints} = StatefulCodec.decode_discard(entry, input)

      expected =
        for codepoint <- expected_codepoints, into: <<>>, do: <<codepoint::unsigned-big-32>>

      assert StatefulCodec.decode_to_explicit_ucs4_discard(entry, input, :big) == {:ok, expected}
    end
  end

  test "RED: explicit UCS-4 encoding bypasses the million-element intermediate list" do
    for encoding <- ["ISO-2022-JP", "ISO-2022-JP-1", "ISO-2022-JP-2", "ISO-2022-JP-MS"] do
      encoded = File.read!(Path.join(@fixtures, "#{encoding}-snippet"))
      utf8 = File.read!(Path.join(@fixtures, "#{encoding}-snippet.UTF-8"))
      {:ok, entry} = Registry.resolve(encoding)

      for endian <- [:big, :little] do
        explicit = :unicode.characters_to_binary(utf8, :utf8, {:utf32, endian})

        assert StatefulCodec.encode_from_explicit_ucs4_discard(entry, explicit, endian) ==
                 {:ok, encoded}

        unrepresentable =
          explicit <> if(endian == :big, do: <<0x10FFFF::32>>, else: <<0x10FFFF::little-32>>)

        assert StatefulCodec.encode_from_explicit_ucs4_discard(entry, unrepresentable, endian) ==
                 {:ok, encoded}
      end
    end
  end

  test "RED: HZ and ISO-2022-KR encode explicit UCS-4 directly in either byte order" do
    for encoding <- ["HZ", "ISO-2022-KR"] do
      encoded = File.read!(Path.join(@fixtures, "#{encoding}-snippet"))
      utf8 = File.read!(Path.join(@fixtures, "#{encoding}-snippet.UTF-8"))
      {:ok, entry} = Registry.resolve(encoding)

      for endian <- [:big, :little] do
        explicit = :unicode.characters_to_binary(utf8, :utf8, {:utf32, endian})
        high_word = if endian == :big, do: <<0x10FFFF::32>>, else: <<0x10FFFF::little-32>>

        assert StatefulCodec.encode_from_explicit_ucs4_discard(entry, explicit, endian) ==
                 {:ok, encoded}

        assert StatefulCodec.encode_from_explicit_ucs4_discard(
                 entry,
                 explicit <> :binary.copy(high_word, 16),
                 endian
               ) == {:ok, encoded}
      end
    end
  end

  test "HZ and ISO-2022-KR direct encoders match staged discard for every BMP unit" do
    codepoints = Enum.to_list(0x0000..0xFFFF)

    explicit_big =
      for codepoint <- codepoints, into: <<>>, do: <<codepoint::unsigned-big-32>>

    explicit_little =
      for codepoint <- codepoints, into: <<>>, do: <<codepoint::unsigned-little-32>>

    for encoding <- ["HZ", "ISO-2022-KR"] do
      {:ok, entry} = Registry.resolve(encoding)
      {:ok, expected} = StatefulCodec.encode_discard(entry, codepoints)

      assert StatefulCodec.encode_from_explicit_ucs4_discard(entry, explicit_big, :big) ==
               {:ok, expected}

      assert StatefulCodec.encode_from_explicit_ucs4_discard(entry, explicit_little, :little) ==
               {:ok, expected}
    end
  end

  test "UTF-7 keeps its GNU surrogate-recovery route ahead of the generic stateful route" do
    Code.ensure_loaded!(UTF7Codec)
    Code.ensure_loaded!(StatefulCodec)
    utf7_mfa = {UTF7Codec, :decode_discard_gnu_ucs4, 2}
    stateful_mfa = {StatefulCodec, :decode_to_explicit_ucs4_discard, 3}
    :erlang.trace_pattern(utf7_mfa, true, [:local, :call_count])
    :erlang.trace_pattern(stateful_mfa, true, [:local, :call_count])

    try do
      assert Iconvex.convert!("+2AA-", "UTF-7", "UCS-4BE", invalid: :discard) == <<>>

      assert :erlang.trace_info(utf7_mfa, :call_count) == {:call_count, 1}
      assert :erlang.trace_info(stateful_mfa, :call_count) == {:call_count, 0}
    after
      :erlang.trace_pattern(utf7_mfa, false, [:local, :call_count])
      :erlang.trace_pattern(stateful_mfa, false, [:local, :call_count])
    end
  end

  test "RED: public explicit UCS-4 conversion dispatches to the stateful direct encoder" do
    Code.ensure_loaded!(StatefulCodec)
    mfa = {StatefulCodec, :encode_from_explicit_ucs4_discard, 3}
    :erlang.trace_pattern(mfa, true, [:local, :call_count])

    try do
      utf8 = File.read!(Path.join(@fixtures, "ISO-2022-JP-snippet.UTF-8"))
      expected = File.read!(Path.join(@fixtures, "ISO-2022-JP-snippet"))
      explicit = :unicode.characters_to_binary(utf8, :utf8, {:utf32, :big})

      assert Iconvex.convert!(explicit, "UCS-4BE", "ISO-2022-JP", unrepresentable: :discard) ==
               expected

      assert :erlang.trace_info(mfa, :call_count) == {:call_count, 1}
    after
      :erlang.trace_pattern(mfa, false, [:local, :call_count])
    end
  end

  test "RED: public HZ and ISO-2022-KR conversions use the direct UCS-4 encoder" do
    Code.ensure_loaded!(StatefulCodec)
    mfa = {StatefulCodec, :encode_from_explicit_ucs4_discard, 3}
    :erlang.trace_pattern(mfa, true, [:local, :call_count])

    try do
      for encoding <- ["HZ", "ISO-2022-KR"] do
        utf8 = File.read!(Path.join(@fixtures, "#{encoding}-snippet.UTF-8"))
        expected = File.read!(Path.join(@fixtures, "#{encoding}-snippet"))
        explicit = :unicode.characters_to_binary(utf8, :utf8, {:utf32, :little})

        assert Iconvex.convert!(explicit, "UCS-4LE", encoding, unrepresentable: :discard) ==
                 expected
      end

      assert :erlang.trace_info(mfa, :call_count) == {:call_count, 2}
    after
      :erlang.trace_pattern(mfa, false, [:local, :call_count])
    end
  end

  @tag timeout: 300_000
  test "107,590 adversarial short inputs preserve staged discard semantics in both endians" do
    categories = [
      {[%{id: :hz}], [0x00, ?A, ?~, ?{, ?}, ?\n, ?!, 0x7F, 0x80]},
      {[%{id: :iso2022_kr}], [0x00, ?A, 0x1B, ?$, ?), ?C, 0x0E, 0x0F, ?!, 0x80]},
      {[
         %{id: :iso2022_jp},
         %{id: :iso2022_jp1},
         %{id: :iso2022_jp2},
         %{id: :iso2022_jpms},
         %{id: :iso2022_jp_ext}
       ], [0x00, ?A, 0x1B, ?$, ?@, ?B, ?(, ?J, ?N, 0x80]},
      {[%{id: :iso2022_jp2}], [0x00, 0x1B, ?$, ?(, ?), ?A, ?B, ?C, ?D, ?N, 0x80]},
      {[%{id: :iso2022_cn}, %{id: :iso2022_cn_ext}],
       [0x00, 0x1B, ?$, ?), ?*, ?+, ?A, ?E, ?G, ?H, ?N, ?O, 0x80]},
      {[%{id: :iso2022_cn_ext}], [0x0E, 0x0F, 0x1B, ?$, ?+, ?I, ?J, ?K, ?L, ?M, ?O, ?!, 0x80]}
    ]

    count =
      categories
      |> Task.async_stream(
        fn {entries, alphabet} ->
          each_short_binary(alphabet, fn input ->
            entry = Enum.at(entries, :erlang.phash2(input, length(entries)))
            {:ok, codepoints} = StatefulCodec.decode_discard(entry, input)

            for endian <- [:big, :little] do
              expected = encode_ucs4(codepoints, endian)

              assert StatefulCodec.decode_to_explicit_ucs4_discard(entry, input, endian) ==
                       {:ok, expected}
            end
          end)
        end,
        max_concurrency: length(categories),
        ordered: false,
        timeout: 300_000
      )
      |> Enum.reduce(0, fn {:ok, category_count}, total -> total + category_count end)

    assert count == 107_590

    for {entry, input} <- [
          {%{id: :iso2022_kr}, <<0x1B, "$)C", 0x0E, 0x47>>},
          {%{id: :iso2022_cn}, <<0x1B, "$)A", 0x0E, 0x21>>}
        ] do
      assert StatefulCodec.decode_discard(entry, input) == {:ok, []}

      for endian <- [:big, :little] do
        assert StatefulCodec.decode_to_explicit_ucs4_discard(entry, input, endian) ==
                 {:ok, <<>>}
      end
    end
  end

  test "RED: concurrent cold pair-cache callers publish exactly one descriptor build" do
    codepoints = List.to_tuple(List.duplicate(0x41, 32))

    source =
      for first <- 0x21..0x7E, second <- 0x21..0x7E, into: %{} do
        {<<first, second>>, codepoints}
      end

    cache_id = :stateful_pair_cache_concurrency_probe
    key = {StatefulPairCache, {:seven_bit, cache_id}, 1}
    integrity_key = {StatefulPairCache, :integrity, {:seven_bit, cache_id}, 1}
    previous = :persistent_term.get(key, :missing)
    previous_integrity = :persistent_term.get(integrity_key, :missing)
    Code.ensure_loaded!(StatefulPairCache)
    mfa = {StatefulPairCache, :build_seven_bit, 1}

    on_exit(fn ->
      :erlang.trace_pattern(mfa, false, [:local])

      case previous do
        :missing -> :persistent_term.erase(key)
        value -> :persistent_term.put(key, value)
      end

      case previous_integrity do
        :missing -> :persistent_term.erase(integrity_key)
        value -> :persistent_term.put(integrity_key, value)
      end
    end)

    :persistent_term.erase(key)
    :persistent_term.erase(integrity_key)
    :erlang.trace_pattern(mfa, true, [:local])

    parent = self()

    tasks =
      for _index <- 1..32 do
        Task.async(fn ->
          send(parent, {:pair_cache_ready, self()})

          receive do
            :build_pair_cache -> StatefulPairCache.seven_bit(cache_id, source)
          end
        end)
      end

    workers =
      for _index <- 1..32 do
        assert_receive {:pair_cache_ready, worker}, 5_000
        worker
      end

    Enum.each(workers, &:erlang.trace(&1, true, [:call, {:tracer, self()}]))
    Enum.each(workers, &send(&1, :build_pair_cache))

    assert_receive {:trace, first_builder, :call,
                    {StatefulPairCache, :build_seven_bit, [_source]}},
                   5_000

    assert :erlang.suspend_process(first_builder)

    competing_builder =
      receive do
        {:trace, worker, :call, {StatefulPairCache, :build_seven_bit, [_source]}}
        when worker != first_builder ->
          worker
      after
        100 -> nil
      end

    :erlang.resume_process(first_builder)
    assert competing_builder == nil

    descriptors = Enum.map(tasks, &Task.await(&1, 30_000))

    [first | rest] = descriptors
    assert Enum.all?(rest, &(&1 === first))

    assert {1, {:seven_bit, ^cache_id}, ^source, ^first, witness} =
             :persistent_term.get(key)

    assert {1, {:seven_bit, ^cache_id}, ^source, ^witness} =
             :persistent_term.get(integrity_key)
  end

  test "RED: a same-source malformed pair descriptor is rejected and rebuilt" do
    source = Iconvex.Tables.fetch!(:gb2312).many
    key = {StatefulPairCache, {:seven_bit, :gb2312}, 1}
    integrity_key = {StatefulPairCache, :integrity, {:seven_bit, :gb2312}, 1}
    previous = :persistent_term.get(key, :missing)
    previous_integrity = :persistent_term.get(integrity_key, :missing)

    on_exit(fn ->
      case previous do
        :missing -> :persistent_term.erase(key)
        value -> :persistent_term.put(key, value)
      end

      case previous_integrity do
        :missing -> :persistent_term.erase(integrity_key)
        value -> :persistent_term.put(integrity_key, value)
      end
    end)

    :persistent_term.put(key, {source, :poison})

    {<<first, second>>, codepoints} =
      Enum.find(source, fn
        {<<first, second>>, _codepoints} -> first in 0x21..0x7E and second in 0x21..0x7E
        _other -> false
      end)

    dense = StatefulPairCache.seven_bit(:gb2312, source)

    assert StatefulPairCache.lookup(dense, first, second, :big) ==
             {:ok, encode_ucs4(Tuple.to_list(codepoints), :big)}
  end

  test "RED: a same-sized descriptor with a malformed entry is rejected and rebuilt" do
    source = Iconvex.Tables.fetch!(:gb2312).many
    cache_id = {:seven_bit, :gb2312}
    key = {StatefulPairCache, cache_id, 1}
    integrity_key = {StatefulPairCache, :integrity, cache_id, 1}
    previous = :persistent_term.get(key, :missing)
    previous_integrity = :persistent_term.get(integrity_key, :missing)

    on_exit(fn ->
      case previous do
        :missing -> :persistent_term.erase(key)
        value -> :persistent_term.put(key, value)
      end

      case previous_integrity do
        :missing -> :persistent_term.erase(integrity_key)
        value -> :persistent_term.put(integrity_key, value)
      end
    end)

    {<<first, second>>, codepoints} =
      Enum.find(source, fn
        {<<first, second>>, _codepoints} -> first in 0x21..0x7E and second in 0x21..0x7E
        _other -> false
      end)

    dense = StatefulPairCache.seven_bit(:gb2312, source)
    index = (first - 0x21) * 94 + second - 0x21
    malformed = put_elem(dense, index, :poison)

    assert StatefulPairCache.lookup(malformed, first, second, :big) == :error

    :persistent_term.put(key, {1, cache_id, source, malformed, make_ref()})

    rebuilt = StatefulPairCache.seven_bit(:gb2312, source)
    refute rebuilt === malformed

    assert {1, ^cache_id, ^source, ^rebuilt, witness} = :persistent_term.get(key)
    assert {1, ^cache_id, ^source, ^witness} = :persistent_term.get(integrity_key)

    assert StatefulPairCache.lookup(rebuilt, first, second, :big) ==
             {:ok, encode_ucs4(Tuple.to_list(codepoints), :big)}
  end

  test "RED: production pair caches validate table generations without retaining source maps" do
    cache_id = :stateful_pair_cache_identity_probe
    descriptor_id = {:seven_bit, cache_id}
    key = {StatefulPairCache, descriptor_id, 1}
    integrity_key = {StatefulPairCache, :integrity, descriptor_id, 1}
    previous = :persistent_term.get(key, :missing)
    previous_integrity = :persistent_term.get(integrity_key, :missing)

    on_exit(fn ->
      case previous do
        :missing -> :persistent_term.erase(key)
        value -> :persistent_term.put(key, value)
      end

      case previous_integrity do
        :missing -> :persistent_term.erase(integrity_key)
        value -> :persistent_term.put(integrity_key, value)
      end
    end)

    source = %{
      <<0x21, 0x21>> => {0x41},
      <<0x21, 0x22>> => {0x42}
    }

    first_identity = make_ref()
    first = StatefulPairCache.seven_bit(cache_id, source, first_identity)

    assert {1, ^descriptor_id, ^first_identity, ^first, first_witness} =
             :persistent_term.get(key)

    assert {1, ^descriptor_id, ^first_identity, ^first_witness} =
             :persistent_term.get(integrity_key)

    assert StatefulPairCache.seven_bit(cache_id, Map.new(source), first_identity) === first

    assert {1, ^descriptor_id, ^first_identity, ^first, ^first_witness} =
             :persistent_term.get(key)

    second_identity = make_ref()
    second = StatefulPairCache.seven_bit(cache_id, source, second_identity)

    assert {1, ^descriptor_id, ^second_identity, ^second, second_witness} =
             :persistent_term.get(key)

    refute second_witness == first_witness

    assert {1, ^descriptor_id, ^second_identity, ^second_witness} =
             :persistent_term.get(integrity_key)
  end

  defp each_short_binary(alphabet, function) do
    Enum.reduce(0..4, 0, fn size, count ->
      count + each_fixed_binary(alphabet, size, <<>>, function)
    end)
  end

  defp each_fixed_binary(_alphabet, 0, prefix, function) do
    function.(prefix)
    1
  end

  defp each_fixed_binary(alphabet, remaining, prefix, function) do
    Enum.reduce(alphabet, 0, fn byte, count ->
      count + each_fixed_binary(alphabet, remaining - 1, <<prefix::binary, byte>>, function)
    end)
  end

  defp encode_ucs4(codepoints, :big),
    do: for(codepoint <- codepoints, into: <<>>, do: <<codepoint::unsigned-big-32>>)

  defp encode_ucs4(codepoints, :little),
    do: for(codepoint <- codepoints, into: <<>>, do: <<codepoint::unsigned-little-32>>)
end

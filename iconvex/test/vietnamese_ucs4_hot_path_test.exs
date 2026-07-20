defmodule Iconvex.VietnameseUCS4HotPathTest do
  use ExUnit.Case, async: false

  alias Iconvex.{TableCodec, UnicodeCodec}

  @corpus Path.expand("fixtures/all-unicode-codepoints.ucs4be", __DIR__)

  test "TCVN exhaustive reverse bypasses the 65,536-entry dense per-byte walker" do
    entry = %{id: :tcvn}
    corpus = File.read!(@corpus)

    encoded =
      Iconvex.convert!(corpus, "UCS-4BE", "TCVN", unrepresentable: :discard)

    assert byte_size(encoded) == 382
    assert {:ok, codepoints} = TableCodec.decode_discard(entry, encoded)

    direct = {TableCodec, :decode_to_explicit_ucs4_discard, 3}
    sparse_walker = {TableCodec, :decode_vietnamese_sparse_to_ucs4_discard, 4}
    dense_walker = {TableCodec, :decode_dense_two_byte_to_ucs4_discard, 5}

    {results, calls} =
      count_calls([direct, sparse_walker, dense_walker], fn ->
        for endian <- [:big, :little] do
          TableCodec.decode_to_explicit_ucs4_discard(entry, encoded, endian)
        end
      end)

    for {endian, result} <- Enum.zip([:big, :little], results) do
      assert {:ok, expected} = UnicodeCodec.encode(%{id: ucs4_id(endian)}, codepoints)
      assert result == {:ok, expected}
    end

    assert calls[direct] == 2
    assert calls[sparse_walker] == 2
    assert calls[dense_walker] == 0
  end

  test "Vietnamese sparse decoding matches staged discard across every byte pair boundary" do
    input =
      for first <- 0..0xFF, second <- 0..0xFF, into: <<>> do
        <<first, second>>
      end

    for id <- [:cp1258, :tcvn] do
      entry = %{id: id}
      assert {:ok, codepoints} = TableCodec.decode_discard(entry, input)

      for endian <- [:big, :little] do
        assert {:ok, expected} = UnicodeCodec.encode(%{id: ucs4_id(endian)}, codepoints)

        assert TableCodec.decode_to_explicit_ucs4_discard(entry, input, endian) ==
                 {:ok, expected}
      end
    end
  end

  test "Vietnamese sparse cache repairs a malformed selected row before reuse" do
    entry = %{id: :tcvn}
    table = Iconvex.Tables.fetch!(entry)
    {bytes, {codepoint}} = Enum.at(table.many, 0)

    assert TableCodec.decode_to_explicit_ucs4_discard(entry, bytes, :big) ==
             {:ok, <<codepoint::unsigned-big-32>>}

    cache_key =
      {TableCodec, :vietnamese_sparse_two_byte_decode, :iconvex, :tcvn, 1}

    previous = :persistent_term.get(cache_key)
    on_exit(fn -> :persistent_term.put(cache_key, previous) end)

    {schema, kind, identity, root} = previous
    <<first, _second>> = bytes
    poisoned = put_elem(root, first, :malformed)
    :persistent_term.put(cache_key, {schema, kind, identity, poisoned})

    assert TableCodec.decode_to_explicit_ucs4_discard(entry, bytes, :big) ==
             {:ok, <<codepoint::unsigned-big-32>>}

    assert {^schema, ^kind, ^identity, repaired} = :persistent_term.get(cache_key)
    refute repaired === poisoned
  end

  test "Vietnamese sparse cache follows an external table generation identity" do
    app = :iconvex_test_vietnamese_sparse_provider
    id = :tcvn
    entry = %{id: id, table_app: app}
    table_key = {{Iconvex.Tables, :table}, app, id}
    sparse_key = {TableCodec, :vietnamese_sparse_two_byte_decode, app, id, 1}
    version = {1, ~c"unloaded"}
    table = Iconvex.Tables.fetch!(id)
    {bytes, {original}} = Enum.at(table.many, 0)
    replacement = if original == 0x2603, do: 0x2604, else: 0x2603

    on_exit(fn ->
      :persistent_term.erase(table_key)
      :persistent_term.erase(sparse_key)
    end)

    first_identity = make_ref()
    :persistent_term.put(table_key, {1, version, first_identity, table})

    assert TableCodec.decode_to_explicit_ucs4_discard(entry, bytes, :little) ==
             {:ok, <<original::unsigned-little-32>>}

    assert {_schema, _kind, ^first_identity, _root} = :persistent_term.get(sparse_key)

    second_identity = make_ref()
    changed = put_in(table, [:many, bytes], {replacement})
    :persistent_term.put(table_key, {1, version, second_identity, changed})

    assert TableCodec.decode_to_explicit_ucs4_discard(entry, bytes, :little) ==
             {:ok, <<replacement::unsigned-little-32>>}

    assert {_schema, _kind, ^second_identity, _root} = :persistent_term.get(sparse_key)
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

  defp ucs4_id(:big), do: :ucs4be
  defp ucs4_id(:little), do: :ucs4le
end

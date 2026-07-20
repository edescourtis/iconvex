defmodule Iconvex.GeneratedTableConformanceTest do
  use ExUnit.Case, async: false

  alias Iconvex.{GB18030Codec, Registry, TableCodec, Tables}

  test "every registered encoding has a native codec implementation" do
    assert Enum.all?(Iconvex.encodings(), fn name ->
             {:ok, entry} = Registry.resolve(name)
             entry.kind in [:table, :unicode, :escape, :gb18030, :stateful]
           end)
  end

  test "all packed GNU mapping entries decode and encode semantically" do
    entries =
      Iconvex.encodings()
      |> Enum.map(fn name -> elem(Registry.resolve(name), 1) end)
      |> Enum.uniq_by(& &1.id)
      |> Enum.filter(&(&1.kind in [:table, :gb18030]))

    for entry <- entries do
      table = Tables.fetch!(entry.id)

      mappings =
        table.one
        |> Tuple.to_list()
        |> Enum.with_index()
        |> Enum.flat_map(fn
          {nil, _byte} -> []
          {codepoints, byte} -> [{<<byte>>, codepoints}]
        end)
        |> Kernel.++(Enum.sort(table.many))

      separator =
        case Map.fetch(table.encode, {0}) do
          {:ok, bytes} -> {bytes, {0}}
          :error -> hd(mappings)
        end

      mappings = Enum.intersperse(mappings, separator)

      input = IO.iodata_to_binary(Enum.map(mappings, &elem(&1, 0)))
      expected = mappings |> Enum.flat_map(&Tuple.to_list(elem(&1, 1)))

      decoder = if entry.kind == :gb18030, do: GB18030Codec, else: TableCodec
      assert decoder.decode(entry, input) == {:ok, expected}, entry.canonical

      assert {:ok, encoded} = decoder.encode(entry, expected)
      assert decoder.decode(entry, encoded) == {:ok, expected}, entry.canonical
    end
  end
end

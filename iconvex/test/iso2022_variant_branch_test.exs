defmodule Iconvex.ISO2022VariantBranchTest do
  use ExUnit.Case, async: false

  alias Iconvex.{ISO2022CNCodec, ISO2022JPCodec, StatefulCodec, Tables}

  setup do
    key = {{Tables, :table}, :iconvex, :euc_jisx0213}
    version = {1, Application.spec(:iconvex, :vsn)}

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

    :persistent_term.put(key, {1, version, table})
    on_exit(fn -> :persistent_term.erase(key) end)
    :ok
  end

  test "JP-2 exercises both G2 sets, repeated designation, language tags, and errors" do
    entry = %{id: :iso2022_jp2}
    codepoints = [0xA0, 0xA0, 0x037A]

    assert {:ok, encoded} = ISO2022JPCodec.encode(entry, codepoints)
    assert encoded =~ <<0x1B, ".A", 0x1B, ?N>>
    assert encoded =~ <<0x1B, ".F", 0x1B, ?N>>
    assert {:ok, ^codepoints} = ISO2022JPCodec.decode(entry, encoded)
    assert {:ok, ^codepoints} = ISO2022JPCodec.decode_discard(entry, encoded)
    assert {:ok, ^codepoints} = ISO2022JPCodec.decode_substitute(entry, encoded, fn _ -> [?x] end)

    tagged = [0xE0001, 0xA0, 0xE007F, 0xA0]
    assert {:ok, tagged_encoded} = ISO2022JPCodec.encode(entry, tagged)
    assert {:ok, [0xA0, 0xA0]} = ISO2022JPCodec.decode(entry, tagged_encoded)

    assert {:error, :incomplete_sequence, 0, <<0x1B, ?.>>} =
             ISO2022JPCodec.decode(entry, <<0x1B, ?.>>)

    assert {:error, :invalid_sequence, 3, <<0x1B, ?N, 0x7F>>} =
             ISO2022JPCodec.decode(entry, <<0x1B, ".F", 0x1B, ?N, 0x7F>>)

    assert {:ok, [?x, ?N, 0x7F]} =
             ISO2022JPCodec.decode_substitute(
               entry,
               <<0x1B, ".F", 0x1B, ?N, 0x7F>>,
               fn _ -> [?x] end
             )

    assert {:error, :unrepresentable_character, 0x110000} =
             ISO2022JPCodec.encode(entry, [0x110000])

    assert {:ok, <<>>} = ISO2022JPCodec.encode_discard(entry, [0x110000])
  end

  test "JP extension covers JIS0212 preference, kana, controls, and Python mapping" do
    entry = %{id: :iso2022_jp_ext}
    jis0208 = Tables.fetch!(:jisx0208).encode

    codepoint =
      Tables.fetch!(:jisx0212).encode
      |> Map.keys()
      |> Enum.find(fn key -> tuple_size(key) == 1 and not Map.has_key?(jis0208, key) end)
      |> elem(0)

    for codepoints <- [[codepoint], [0xFF61], [0x00A5], [0x203E]] do
      assert {:ok, encoded} = ISO2022JPCodec.encode(entry, codepoints)
      assert {:ok, ^codepoints} = ISO2022JPCodec.decode(entry, encoded)
    end

    assert {:ok, [0x1A]} = ISO2022JPCodec.decode(entry, <<0x1A>>)
    assert {:ok, [0x1A]} = ISO2022JPCodec.decode_discard(entry, <<0x1A>>)

    assert {:ok, [?~]} =
             ISO2022JPCodec.decode(entry, <<0x1B, "$(D", 0x22, 0x37, 0x1B, "(B">>)

    assert {:error, :unrepresentable_character, 0xFF5E} = ISO2022JPCodec.encode(entry, [0xFF5E])
  end

  test "stateful routing includes the JP extension and its Python JIS0212 mode" do
    entry = %{id: :iso2022_jp_ext}
    designation = <<0x1B, "$(D">>
    pair = <<0x22, 0x37>>
    input = designation <> pair

    assert StatefulCodec.decode_discard(entry, input) == {:ok, [?~]}
    assert StatefulCodec.decode_substitute(entry, input, fn _ -> [?x] end) == {:ok, [?~]}

    initial = StatefulCodec.stream_init(entry)

    assert {:ok, [], shifted, <<>>} =
             StatefulCodec.decode_chunk(entry, designation, initial, false, 0)

    assert shifted == {:jp, :jis0212_pyext, nil}

    assert StatefulCodec.decode_chunk(entry, pair, shifted, true, byte_size(designation)) ==
             {:ok, [?~], shifted, <<>>}
  end

  test "JP-3 external-table engine covers plane 1, plane 2, and composite mappings" do
    entry = %{id: :iso2022_jp3}
    codepoints = [0x1000, 0x1001, 0x1002, 0x0300]

    assert {:ok, encoded} = ISO2022JPCodec.encode(entry, codepoints)
    assert encoded =~ <<0x1B, "$(Q">>
    assert encoded =~ <<0x1B, "$(P">>
    assert {:ok, ^codepoints} = ISO2022JPCodec.decode(entry, encoded)

    assert {:ok, one} = ISO2022JPCodec.encode(entry, [0x1000])
    assert {:ok, [0x1000]} = ISO2022JPCodec.decode(entry, one)

    assert {:ok, substituted} =
             ISO2022JPCodec.encode_substitute(entry, [0x1000, 0x110000, 0x1001], fn _ ->
               [?x]
             end)

    assert {:ok, [0x1000, ?x, 0x1001]} = ISO2022JPCodec.decode(entry, substituted)

    assert {:error, :invalid_sequence, 4, <<0, 0>>} =
             ISO2022JPCodec.decode(entry, <<0x1B, "$(Q", 0, 0>>)

    assert {:ok, []} = ISO2022JPCodec.decode_discard(entry, <<0x1B, "$(P", 0>>)
  end

  test "JP-MS covers SO/SI kana, ignored shifts, private rows, and malformed pairs" do
    entry = %{id: :iso2022_jpms}
    kana = elem(elem(Tables.fetch!(:jisx0201).one, 0xA1), 0)

    input = <<0x1B, "(J", 0x0E, 0x21, 0x0F, ?A, 0x0F>>
    assert {:ok, [^kana, ?A]} = ISO2022JPCodec.decode(entry, input)
    assert {:ok, [^kana, ?A]} = ISO2022JPCodec.decode_discard(entry, input)
    assert {:ok, [^kana, ?A]} = ISO2022JPCodec.decode_substitute(entry, input, fn _ -> [?x] end)
    assert {:ok, encoded_kana} = ISO2022JPCodec.encode(entry, [kana, ?A])
    assert {:ok, [^kana, ?A]} = ISO2022JPCodec.decode(entry, encoded_kana)
    assert {:ok, [0x10]} = ISO2022JPCodec.decode_discard(entry, <<0x0E, 0x0F, 0x10>>)

    assert {:error, :invalid_sequence, 3, <<0x20>>} =
             ISO2022JPCodec.decode(entry, <<0x1B, "(I", 0x20>>)

    assert {:ok, []} = ISO2022JPCodec.decode_discard(entry, <<0x1B, "(I", 0x20>>)

    assert {:ok, [?x]} =
             ISO2022JPCodec.decode_substitute(entry, <<0x1B, "(I", 0x20>>, fn _ -> [?x] end)

    assert {:error, :incomplete_sequence, 3, <<0x21>>} =
             ISO2022JPCodec.decode(entry, <<0x1B, "$B", 0x21>>)

    for codepoint <- [0xE000, 0xE3AC, 0x663B, 0xFFE2, 0xFFE4] do
      assert {:ok, encoded} = ISO2022JPCodec.encode(entry, [codepoint])
      assert {:ok, [^codepoint]} = ISO2022JPCodec.decode(entry, encoded)
    end

    assert {:error, :invalid_sequence, 3, <<0, 0>>} =
             ISO2022JPCodec.decode(entry, <<0x1B, "$B", 0, 0>>)

    assert {:ok, [?A]} =
             ISO2022JPCodec.decode_discard(
               entry,
               <<0x1B, "$B", 0, 0, 0x1B, "(B", ?A>>
             )
  end

  test "CN variants cover G1 CNS, G2, G3, replacement, truncation, and strict errors" do
    euc_tw = Tables.fetch!(:euc_tw).encode
    gb2312 = Tables.fetch!(:gb2312).encode

    plane_codepoint = fn plane ->
      euc_tw
      |> Enum.find(fn
        {{codepoint}, <<0x8E, plane_byte, _first, _second>>} ->
          plane_byte == plane + 0xA0 and not Map.has_key?(gb2312, {codepoint})

        _ ->
          false
      end)
      |> elem(0)
      |> elem(0)
    end

    plane1 =
      euc_tw
      |> Enum.find(fn
        {{codepoint}, <<_first, _second>>} -> not Map.has_key?(gb2312, {codepoint})
        _ -> false
      end)
      |> elem(0)
      |> elem(0)

    cases = [
      {%{id: :iso2022_cn}, [plane1, plane_codepoint.(2)]},
      {%{id: :iso2022_cn_ext}, [plane1, plane_codepoint.(2), plane_codepoint.(3)]}
    ]

    for {entry, codepoints} <- cases do
      assert {:ok, encoded} = ISO2022CNCodec.encode(entry, codepoints)
      assert {:ok, ^codepoints} = ISO2022CNCodec.decode(entry, encoded)

      malformed = encoded <> <<0xFF>>
      assert {:ok, ^codepoints} = ISO2022CNCodec.decode_discard(entry, malformed)

      assert {:ok, substituted} =
               ISO2022CNCodec.decode_substitute(entry, malformed, fn _ -> [?x] end)

      assert substituted == codepoints ++ [?x]
    end

    cn = %{id: :iso2022_cn}
    ext = %{id: :iso2022_cn_ext}

    assert {:error, :incomplete_sequence, 0, <<0x1B, ?$>>} =
             ISO2022CNCodec.decode(cn, <<0x1B, ?$>>)

    assert {:error, :invalid_sequence, 0, <<0x0E>>} = ISO2022CNCodec.decode(cn, <<0x0E>>)

    assert {:error, :incomplete_sequence, 5, <<0x21>>} =
             ISO2022CNCodec.decode(cn, <<0x1B, "$)A", 0x0E, 0x21>>)

    assert {:error, :invalid_sequence, 4, <<0x1B, ?N, 0, 0>>} =
             ISO2022CNCodec.decode(cn, <<0x1B, "$*H", 0x1B, ?N, 0, 0>>)

    assert {:error, :invalid_sequence, 4, <<0x1B, ?O, 0, 0>>} =
             ISO2022CNCodec.decode(ext, <<0x1B, "$+I", 0x1B, ?O, 0, 0>>)

    assert {:error, :unrepresentable_character, 0x110000} =
             ISO2022CNCodec.encode(cn, [0x110000])

    assert {:ok, <<>>} = ISO2022CNCodec.encode_discard(cn, [0x110000])
  end
end

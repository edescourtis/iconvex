defmodule Iconvex.Specs.GlyphVectorTACEClosureTest do
  use ExUnit.Case, async: false

  @moduletag timeout: :infinity

  alias Iconvex.Specs.GlyphVectorUnicode.Codecs, as: GlyphCodecs
  alias Iconvex.Specs.LY1TexnANSI11AGL4036A9CA, as: LY1
  alias Iconvex.Specs.PostScript3ISOLatin1AGL4036A9CA, as: PSLatin1
  alias Iconvex.Specs.TACE16AppendixD2010, as: TACE
  alias Iconvex.Specs.TACE16AppendixD2010BE, as: TACEBE
  alias Iconvex.Specs.TACE16AppendixD2010LE, as: TACELE

  @root Path.expand("..", __DIR__)
  @glyph_dir Path.join(@root, "priv/sources/glyph-vector-unicode")
  @tace_dir Path.join(@root, "priv/sources/tace16-2010")
  @unicode_corpus Path.join(@root, "test/fixtures/all-unicode-scalars.utf32be")

  @agl_commit "4036a9ca80a62f64f9de4f7321a9a045ad0ecfd6"
  @agl_sha256 "a3b2f61ced9f3644cc0d4ecde5c59df34ca286c689d9484a43a710a81c466789"
  @agl_license_sha256 "58147d341e7a34aa2196862395a34d2fd95716c41d5ed26efb59ab0e12f92089"
  @ly1_vector_sha256 "cd006b13b530d7bfd386396c7f1138488d2b336f40508552b41952a83cdb0601"
  @ly1_archive_sha256 "e6a43938a3b8e375fe52763a1cab1de849879d4bb4b0998414c190ad20f07e0a"
  @plrm_sha256 "6b29e79e4ab64aaa61a3fb27a0f36838c01f2530362873ac316bdb493a1bab6b"
  @tace_source_sha256 "78c77c607892d8f70bda3bbd9ca01371ddf2fe5fc8f3ef0481975d59abf3435c"
  @unicode_corpus_sha256 "d037f6200ae8845906b4372a8b3fcd39730e3a61c4af0e354823010e6f93be54"

  @glyph_profiles [
    {LY1, "ly1_agl_4036a9ca.csv", 250, 6},
    {PSLatin1, "postscript3_isolatin1_agl_4036a9ca.csv", 205, 51}
  ]
  @tace_profiles [{TACEBE, :big}, {TACELE, :little}]

  test "RED: source-qualified names, source artifacts, and provenance boundaries are exact" do
    assert GlyphCodecs.modules() == [LY1, PSLatin1]
    assert TACE.transport_codecs() == [TACEBE, TACELE]

    assert LY1.canonical_name() == "CTAN-LY1-TEXNANSI-1.1-AGL-4036A9CA"
    assert LY1.aliases() == ["CTAN-TEXNANSI-1.1-AGL-4036A9CA"]

    assert PSLatin1.canonical_name() ==
             "ADOBE-POSTSCRIPT-3-ISOLATIN1-AGL-4036A9CA"

    assert PSLatin1.aliases() == [
             "ADOBE-POSTSCRIPT-3-ISOLATIN1ENCODING-AGL-4036A9CA"
           ]

    assert TACE.canonical_name() == "TAMILVU-TACE16-APPENDIX-D-2010"
    assert TACEBE.canonical_name() == "TAMILVU-TACE16-APPENDIX-D-2010-16BE"
    assert TACELE.canonical_name() == "TAMILVU-TACE16-APPENDIX-D-2010-16LE"

    for ambiguous <- ["LY1", "TEXNANSI", "POSTSCRIPT-LATIN-1", "ISOLATIN1ENCODING", "TACE16"] do
      refute ambiguous in LY1.aliases()
      refute ambiguous in PSLatin1.aliases()
      refute ambiguous in TACEBE.aliases()
      refute ambiguous in TACELE.aliases()
    end

    assert sha256(File.read!(Path.join(@glyph_dir, "texnansi-1.1.enc"))) ==
             @ly1_vector_sha256

    assert sha256(File.read!(Path.join(@glyph_dir, "glyphlist-4036a9ca.txt"))) == @agl_sha256

    agl_license = File.read!(Path.join(@glyph_dir, "AGL_LICENSE.md"))
    assert sha256(agl_license) == @agl_license_sha256
    assert agl_license =~ "Redistributions of source code must retain"
    assert agl_license =~ "Neither the name of Adobe"
    assert File.read!(Path.join(@glyph_dir, "SOURCE_METADATA.md")) =~ @agl_commit

    metadata = File.read!(Path.join(@glyph_dir, "SOURCE_METADATA.md"))
    assert metadata =~ @ly1_archive_sha256
    assert metadata =~ @plrm_sha256
    assert metadata =~ "LPPL"
    assert metadata =~ "BSD-3-Clause"
    assert metadata =~ "cwm"
    assert metadata =~ "does not imply Adobe authorship, affiliation, approval, or endorsement"

    tace_metadata = File.read!(Path.join(@tace_dir, "SOURCE_METADATA.md"))
    assert tace_metadata =~ @tace_source_sha256
    assert tace_metadata =~ "Appendix D"
    assert tace_metadata =~ "pages 35-47"
    assert tace_metadata =~ "20"
    assert tace_metadata =~ "PUA"
    assert tace_metadata =~ "byte order"
  end

  test "RED: both glyph-vector profiles exhaust all 256 source octets" do
    for {codec, filename, mapped, invalid} <- @glyph_profiles do
      oracle = glyph_oracle(filename)
      assert map_size(oracle) == mapped
      assert codec.mapped_count() == mapped
      assert codec.invalid_count() == invalid

      for byte <- 0..255 do
        case Map.fetch(oracle, byte) do
          {:ok, codepoint} ->
            assert codec.decode(<<byte>>) == {:ok, [codepoint]}
            assert codec.decode_to_utf8(<<byte>>) == {:ok, <<codepoint::utf8>>}

          :error ->
            assert codec.decode(<<byte>>) == {:error, :invalid_sequence, 0, <<byte>>}
        end
      end
    end

    ly1 = glyph_oracle("ly1_agl_4036a9ca.csv")
    refute Map.has_key?(ly1, 0x00)
    refute Map.has_key?(ly1, 0x0A)
    assert ly1[0x0B] == 0xFB00
    assert ly1[0x0E] == 0xFB03
    assert ly1[0x1D] == 0x00C6
    assert ly1[0x80] == 0x0141
    assert ly1[0xAD] == 0x00AD

    ps = glyph_oracle("postscript3_isolatin1_agl_4036a9ca.csv")
    assert ps[0x27] == 0x2019
    assert ps[0x60] == 0x2018
    assert ps[0x90] == 0x0131
    assert ps[0xA0] == 0x0020
    assert ps[0xAD] == 0x002D
    refute Map.has_key?(ps, 0x99)
    refute Map.has_key?(ps, 0x9C)
  end

  test "RED: glyph-vector inverses use the lowest source byte and all recovery paths progress" do
    for {codec, filename, _mapped, _invalid} <- @glyph_profiles do
      oracle = glyph_oracle(filename)

      inverse =
        Enum.reduce(oracle, %{}, fn {byte, codepoint}, acc ->
          Map.update(acc, codepoint, byte, &min(&1, byte))
        end)

      for {codepoint, byte} <- inverse do
        assert codec.encode([codepoint]) == {:ok, <<byte>>}
        assert codec.encode_from_utf8(<<codepoint::utf8>>) == {:ok, <<byte>>}
      end

      invalid = Enum.find(0..255, &(not Map.has_key?(oracle, &1)))
      valid = inverse |> Enum.min_by(&elem(&1, 1)) |> elem(1)

      assert codec.decode(<<valid, invalid, valid>>) ==
               {:error, :invalid_sequence, 1, <<invalid>>}

      expected = oracle[valid]
      assert codec.decode_discard(<<invalid, valid, invalid>>) == {:ok, [expected]}
      assert codec.encode([expected, 0x1F600]) == {:error, :unrepresentable_character, 0x1F600}
      assert codec.encode_discard([expected, 0x1F600, expected]) == {:ok, <<valid, valid>>}

      assert codec.encode_substitute([expected, 0x1F600], fn _ -> [expected] end) ==
               {:ok, <<valid, valid>>}

      assert codec.encode_from_utf8(<<expected::utf8, 0xE2, 0x82>>) ==
               {:decode_error, :incomplete_sequence, byte_size(<<expected::utf8>>),
                <<0xE2, 0x82>>}

      assert codec.encode_from_utf8(<<expected::utf8, 0xFF>>) ==
               {:decode_error, :invalid_sequence, byte_size(<<expected::utf8>>), <<0xFF>>}
    end

    assert LY1.encode([0x02C6]) == {:ok, <<0x5E>>}
    assert LY1.encode([0x00C6]) == {:ok, <<0x1D>>}
    assert PSLatin1.encode([0x0020]) == {:ok, <<0x20>>}
    assert PSLatin1.encode([0x002D]) == {:ok, <<0x2D>>}
  end

  test "RED: every Unicode scalar exposes exactly the glyph-vector encoder keys" do
    corpus = File.read!(@unicode_corpus)
    assert sha256(corpus) == @unicode_corpus_sha256
    codepoints = for <<codepoint::unsigned-big-32 <- corpus>>, do: codepoint
    assert length(codepoints) == 1_112_064

    for {codec, filename, _mapped, _invalid} <- @glyph_profiles do
      inverse =
        filename
        |> glyph_oracle()
        |> Enum.reduce(%{}, fn {byte, codepoint}, acc ->
          Map.update(acc, codepoint, byte, &min(&1, byte))
        end)

      assert {:ok, encoded} = codec.encode_discard(codepoints)
      assert byte_size(encoded) == map_size(inverse)
      assert codec.decode(encoded) == {:ok, Enum.sort(Map.keys(inverse))}
    end
  end

  test "RED: every Unicode scalar exposes exactly the TACE singleton encoder keys" do
    corpus = File.read!(@unicode_corpus)
    assert sha256(corpus) == @unicode_corpus_sha256
    codepoints = for <<codepoint::unsigned-big-32 <- corpus>>, do: codepoint
    assert length(codepoints) == 1_112_064

    singleton_inverse =
      Enum.reduce(tace_oracle(), %{}, fn
        {unit, %{unicode: [codepoint]}}, acc -> Map.update(acc, codepoint, unit, &min(&1, unit))
        {_unit, _row}, acc -> acc
      end)

    expected_pairs = Enum.sort(singleton_inverse)
    expected_codepoints = Enum.map(expected_pairs, &elem(&1, 0))

    for {codec, endian} <- @tace_profiles do
      expected = for {_codepoint, unit} <- expected_pairs, into: <<>>, do: word(unit, endian)
      assert codec.encode_discard(codepoints) == {:ok, expected}
      assert codec.decode(expected) == {:ok, expected_codepoints}
    end
  end

  test "RED: Appendix D has exactly 380 assigned units and exact equivalents" do
    oracle = tace_oracle()
    assert map_size(oracle) == 380
    assert Enum.count(oracle, fn {_unit, row} -> row.status == :equivalent end) == 360
    assert Enum.count(oracle, fn {_unit, row} -> row.status == :pua_identity end) == 20

    assert TACE.assigned_count() == 380
    assert TACE.equivalent_count() == 360
    assert TACE.pua_identity_count() == 20

    assert oracle[0xE100].unicode == [0x0BF3]
    assert oracle[0xE108].unicode == [0xE108]
    assert oracle[0xE1A0].unicode == [0xE1A0]
    assert oracle[0xE1F0].unicode == [0x0BCD]
    refute Map.has_key?(oracle, 0xE1F1)
    assert oracle[0xE201].unicode == [0x0B85]
    assert oracle[0xE210].unicode == [0x0B95, 0x0BCD]
    assert oracle[0xE211].unicode == [0x0B95]
    assert oracle[0xE38C].unicode == [0x0B95, 0x0BCD, 0x0BB7, 0x0BCC]
    assert oracle[0xE38D].unicode == [0x0BB6, 0x0BCD, 0x0BB0, 0x0BC0]

    for unit <- 0..0xFFFF do
      case Map.fetch(oracle, unit) do
        {:ok, %{unicode: expected}} -> assert TACE.decode_unit(unit) == {:ok, expected}
        :error -> assert TACE.decode_unit(unit) == :error
      end
    end
  end

  test "RED: both explicit TACE word orders exhaust all 65,536 words" do
    oracle = tace_oracle()

    for {codec, endian} <- @tace_profiles, unit <- 0..0xFFFF do
      raw = word(unit, endian)

      case Map.fetch(oracle, unit) do
        {:ok, %{unicode: expected}} ->
          assert codec.decode(raw) == {:ok, expected}
          assert codec.decode_to_utf8(raw) == {:ok, List.to_string(expected)}

        :error ->
          assert codec.decode(raw) == {:error, :invalid_sequence, 0, raw}
      end
    end
  end

  test "RED: TACE inverse is exact, longest matching, and stream-safe through four scalars" do
    oracle = tace_oracle()

    for {unit, %{unicode: codepoints}} <- oracle do
      assert TACE.encode_units(codepoints) == {:ok, [unit]}

      for {codec, endian} <- @tace_profiles do
        assert codec.encode(codepoints) == {:ok, word(unit, endian)}
        assert codec.encode_from_utf8(List.to_string(codepoints)) == {:ok, word(unit, endian)}
      end
    end

    kssa = [0x0B95, 0x0BCD, 0x0BB7]
    kssau = kssa ++ [0x0BCC]
    shrii = [0x0BB6, 0x0BCD, 0x0BB0, 0x0BC0]

    assert TACEBE.encode(kssau ++ shrii) ==
             {:ok, <<0xE38C::16-big, 0xE38D::16-big>>}

    assert TACEBE.encode_chunk([0x0B95], false, :error) == {:ok, <<>>, [0x0B95]}

    assert TACEBE.encode_chunk([0x0B95, 0x0BCD], false, :error) ==
             {:ok, <<>>, [0x0B95, 0x0BCD]}

    assert TACEBE.encode_chunk(kssa, false, :error) == {:ok, <<>>, kssa}
    assert TACEBE.encode_chunk(kssau, false, :error) == {:ok, <<0xE38C::16-big>>, []}
    assert TACEBE.encode_chunk(shrii, false, :error) == {:ok, <<0xE38D::16-big>>, []}
    assert TACEBE.encode_chunk(kssa, true, :error) == {:ok, <<0xE381::16-big>>, []}
  end

  test "RED: TACE invalid, incomplete, discard, substitute, and UTF-8 paths preserve progress" do
    for {codec, endian} <- @tace_profiles do
      valid = word(0xE211, endian)
      invalid = word(0x0000, endian)

      assert codec.decode(valid <> invalid <> valid) ==
               {:error, :invalid_sequence, 2, invalid}

      assert codec.decode(valid <> <<0x12>>) ==
               {:error, :incomplete_sequence, 2, <<0x12>>}

      assert codec.decode_discard(invalid <> valid <> <<0x12>>) == {:ok, [0x0B95]}
      assert codec.encode([0x0B95, 0x1F600]) == {:error, :unrepresentable_character, 0x1F600}
      assert codec.encode_discard([0x1F600, 0x0B95, 0x1F600]) == {:ok, valid}

      assert codec.encode_substitute([0x1F600], fn _ -> [0x0B95] end) == {:ok, valid}

      assert codec.encode_from_utf8(<<0x0B95::utf8, 0xE2, 0x82>>) ==
               {:decode_error, :incomplete_sequence, byte_size(<<0x0B95::utf8>>), <<0xE2, 0x82>>}

      assert codec.encode_from_utf8(<<0x0B95::utf8, 0xFF>>) ==
               {:decode_error, :invalid_sequence, byte_size(<<0x0B95::utf8>>), <<0xFF>>}

      assert codec.decode_chunk(binary_part(valid, 0, 1), false) ==
               {:ok, [], binary_part(valid, 0, 1)}

      assert codec.decode_error_consumption(:invalid_sequence, invalid) == 2
    end
  end

  test "RED: public conversion and streaming preserve the central external registrations" do
    codecs = [LY1, PSLatin1, TACEBE, TACELE]

    tokens =
      Enum.map(codecs, fn codec ->
        assert {:ok, token} = Iconvex.register_codec_if_absent(codec)
        {codec, token}
      end)

    try do
      assert Iconvex.convert(<<0x0B, 0x0E>>, LY1.canonical_name(), "UTF-8") ==
               {:ok, <<0xFB00::utf8, 0xFB03::utf8>>}

      assert Iconvex.convert(<<0x27, 0x60, 0xA0>>, PSLatin1.canonical_name(), "UTF-8") ==
               {:ok, <<0x2019::utf8, 0x2018::utf8, 0x20>>}

      tamil = List.to_string([0x0B95, 0x0BCD, 0x0BB7, 0x0BCC, 0x0BB6, 0x0BCD, 0x0BB0, 0x0BC0])

      for {codec, endian} <- @tace_profiles do
        input = word(0xE38C, endian) <> word(0xE38D, endian)
        assert Iconvex.convert(input, codec.canonical_name(), "UTF-8") == {:ok, tamil}
        assert Iconvex.convert(tamil, "UTF-8", codec.canonical_name()) == {:ok, input}

        for split <- 0..byte_size(input) do
          chunks = [
            binary_part(input, 0, split),
            binary_part(input, split, byte_size(input) - split)
          ]

          assert {:ok, stream} = Iconvex.stream(chunks, codec.canonical_name(), "UTF-8")
          assert stream |> Enum.to_list() |> IO.iodata_to_binary() == tamil
        end

        for split <- 0..byte_size(tamil) do
          chunks = [
            binary_part(tamil, 0, split),
            binary_part(tamil, split, byte_size(tamil) - split)
          ]

          assert {:ok, stream} = Iconvex.stream(chunks, "UTF-8", codec.canonical_name())
          assert stream |> Enum.to_list() |> IO.iodata_to_binary() == input
        end
      end

      for {codec, input, text} <- [
            {LY1, <<0x0B, 0x0E>>, <<0xFB00::utf8, 0xFB03::utf8>>},
            {PSLatin1, <<0x27, 0x60>>, <<0x2019::utf8, 0x2018::utf8>>}
          ] do
        for split <- 0..byte_size(input) do
          chunks = [
            binary_part(input, 0, split),
            binary_part(input, split, byte_size(input) - split)
          ]

          assert {:ok, stream} = Iconvex.stream(chunks, codec.canonical_name(), "UTF-8")
          assert stream |> Enum.to_list() |> IO.iodata_to_binary() == text
        end

        for split <- 0..byte_size(text) do
          chunks = [
            binary_part(text, 0, split),
            binary_part(text, split, byte_size(text) - split)
          ]

          assert {:ok, stream} = Iconvex.stream(chunks, "UTF-8", codec.canonical_name())
          assert stream |> Enum.to_list() |> IO.iodata_to_binary() == input
        end
      end
    after
      for {codec, token} <- tokens, is_reference(token) do
        assert :ok = Iconvex.unregister_codec(codec, token)
      end
    end

    for codec <- codecs do
      assert {:ok, %{codec: ^codec}} = Iconvex.Registry.resolve(codec)
    end
  end

  test "RED: native loops stay linear by process reductions" do
    short_glyph = List.duplicate(?A, 20_000)
    long_glyph = List.duplicate(?A, 40_000)
    short_tace = List.duplicate(0x0B95, 20_000)
    long_tace = List.duplicate(0x0B95, 40_000)

    assert_linear(fn -> LY1.encode(short_glyph) end, fn -> LY1.encode(long_glyph) end)
    assert_linear(fn -> PSLatin1.encode(short_glyph) end, fn -> PSLatin1.encode(long_glyph) end)
    assert_linear(fn -> TACEBE.encode(short_tace) end, fn -> TACEBE.encode(long_tace) end)

    assert {:ok, short_words} = TACEBE.encode(short_tace)
    assert {:ok, long_words} = TACEBE.encode(long_tace)
    assert_linear(fn -> TACEBE.decode(short_words) end, fn -> TACEBE.decode(long_words) end)
  end

  defp assert_linear(short_fun, long_fun) do
    {short, {:ok, _}} = reductions(short_fun)
    {long, {:ok, _}} = reductions(long_fun)
    assert long / max(short, 1) < 2.35
  end

  defp reductions(fun) do
    :erlang.garbage_collect()
    before = elem(Process.info(self(), :reductions), 1)
    result = fun.()
    after_count = elem(Process.info(self(), :reductions), 1)
    {after_count - before, result}
  end

  defp glyph_oracle(filename) do
    Path.join(@glyph_dir, filename)
    |> File.stream!()
    |> Stream.drop(1)
    |> Enum.reduce(%{}, fn line, acc ->
      [byte, codepoint] = line |> String.trim() |> String.split(",", parts: 2)
      Map.put(acc, String.to_integer(byte, 16), String.to_integer(codepoint, 16))
    end)
  end

  defp tace_oracle do
    Path.join(@tace_dir, "appendix_d.csv")
    |> File.stream!()
    |> Stream.drop(1)
    |> Enum.reduce(%{}, fn line, acc ->
      [unit, sequence, status, _name] = line |> String.trim() |> String.split(",", parts: 4)

      unicode =
        sequence
        |> String.split("+", trim: true)
        |> Enum.map(&String.to_integer(&1, 16))

      Map.put(acc, String.to_integer(unit, 16), %{
        unicode: unicode,
        status: String.to_atom(status)
      })
    end)
  end

  defp word(unit, :big), do: <<unit::16-big>>
  defp word(unit, :little), do: <<unit::16-little>>

  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end

defmodule Iconvex.Specs.IBM029CardIowaTest do
  use ExUnit.Case, async: false

  @moduletag timeout: :infinity

  import Bitwise

  alias Iconvex.Packed.LSB

  @profile Iconvex.Specs.IBM029CardIowa824E61A9
  @be Iconvex.Specs.IBM029CardIowa824E61A9_16BE
  @le Iconvex.Specs.IBM029CardIowa824E61A9_16LE

  @source_dir Path.expand("../priv/sources/punched-card-codes", __DIR__)
  @source_path Path.join(@source_dir, "uiowa-punched-card-codes.html")
  @mapping_path Path.join(@source_dir, "ibm_029_card_iowa_824e61a9.csv")
  @source_sha256 "824e61a9687f7fa0b9c9dd3c966ca02020bf8af1ab6671e9bd2e131f22f47b18"

  @unicode_corpus Path.expand("fixtures/all-unicode-scalars.utf32be", __DIR__)
  @unicode_corpus_sha256 "d037f6200ae8845906b4372a8b3fcd39730e3a61c4af0e354823010e6f93be54"

  test "RED: Iowa snapshot and normalized IBM 029 extraction are digest-pinned and exact" do
    assert Code.ensure_loaded?(@profile)
    assert sha256(File.read!(@source_path)) == @source_sha256

    normalized = normalized_rows()
    extracted = iowa_ibm_029_mapping()

    assert length(normalized) == 64
    assert normalized |> Enum.map(& &1.source_column) == Enum.to_list(0..63)

    assert Enum.map(normalized, &Map.take(&1, [:source_column, :codepoint, :mask])) ==
             extracted

    assert sha256(File.read!(@mapping_path)) == @profile.normalized_mapping_sha256()
    assert @profile.source_sha256() == @source_sha256
    assert @profile.source_url() == "https://homepage.cs.uiowa.edu/~jones/cards/codes.html"
    assert @profile.source_pages() == ["IBM model 029 keypunch section"]
    assert @profile.printed_source_pages() == []
  end

  test "RED: the source's punched blank is decode-only and no-punch remains canonical" do
    canonical = canonical_rows()
    aliases = alias_rows()

    assert length(canonical) == 63
    assert length(aliases) == 1

    assert aliases == [
             %{source_column: 58, codepoint: 0x20, mask: 0x282, disposition: :decode_alias}
           ]

    assert canonical |> Enum.map(& &1.codepoint) |> Enum.uniq() |> length() == 63
    assert canonical |> Enum.map(& &1.mask) |> Enum.uniq() |> length() == 63

    assert @profile.canonical_count() == 63
    assert @profile.decode_alias_count() == 1
    assert @profile.encode_packed([0x20]) == {:ok, <<0x000::12>>}
    assert @profile.decode_packed(<<0x000::12, 0x282::12>>) == {:ok, [0x20, 0x20]}

    for codec <- [@be, @le] do
      assert codec.source_sha256() == @source_sha256
      assert codec.source_url() == @profile.source_url()
    end
  end

  test "RED: every canonical character is exact in logical, BE, LE, MSB, and LSB forms" do
    codepoints = Enum.map(canonical_rows(), & &1.codepoint)
    text = List.to_string(codepoints)

    for %{codepoint: codepoint, mask: mask} <- canonical_rows() do
      assert @profile.encode_packed([codepoint]) == {:ok, <<mask::12>>}
      assert @profile.decode_packed(<<mask::12>>) == {:ok, [codepoint]}

      assert {:ok, %LSB{unit_bits: 12, bit_size: 12} = packed_lsb} =
               @profile.encode_packed_lsb([codepoint])

      assert @profile.decode_packed_lsb(packed_lsb) == {:ok, [codepoint]}
      assert @be.encode([codepoint]) == {:ok, <<mask::16-big>>}
      assert @be.decode(<<mask::16-big>>) == {:ok, [codepoint]}
      assert @le.encode([codepoint]) == {:ok, <<mask::16-little>>}
      assert @le.decode(<<mask::16-little>>) == {:ok, [codepoint]}
    end

    assert {:ok, packed_msb} = @profile.encode_packed_from_utf8(text, :msb)
    assert @profile.decode_packed_to_utf8(packed_msb, :msb) == {:ok, text}

    assert {:ok, %LSB{} = packed_lsb} = @profile.encode_packed_from_utf8(text, :lsb)
    assert @profile.decode_packed_to_utf8(packed_lsb, :lsb) == {:ok, text}

    assert {:ok, words_be} = @be.encode_from_utf8(text)
    assert @be.decode_to_utf8(words_be) == {:ok, text}

    assert {:ok, words_le} = @le.encode_from_utf8(text)
    assert @le.decode_to_utf8(words_le) == {:ok, text}
  end

  test "RED: all 4096 masks have exactly the source-documented disposition" do
    accepted = Map.new(normalized_rows(), &{&1.mask, &1.codepoint})

    for mask <- 0..0xFFF do
      expected = Map.fetch(accepted, mask)
      assert_decode(expected, @profile.decode_packed(<<mask::12>>), 0, <<mask::12>>)
      assert_decode(expected, @be.decode(<<mask::16-big>>), 0, <<mask::16-big>>)
      assert_decode(expected, @le.decode(<<mask::16-little>>), 0, <<mask::16-little>>)

      assert {:ok, %LSB{} = packed_lsb} = @profile.pack_masks_lsb([mask])
      assert_decode(expected, @profile.decode_packed_lsb(packed_lsb), 0, mask)
    end
  end

  test "RED: the complete Unicode scalar corpus exposes no accidental encoder keys" do
    corpus = File.read!(@unicode_corpus)
    assert sha256(corpus) == @unicode_corpus_sha256

    codepoints = for <<codepoint::unsigned-big-32 <- corpus>>, do: codepoint
    expected = canonical_rows() |> Enum.map(& &1.codepoint) |> Enum.sort()

    assert length(codepoints) == 1_112_064
    assert {:ok, packed} = @profile.encode_packed_discard(codepoints)
    assert @profile.decode_packed(packed) == {:ok, expected}
    assert @profile.encode_packed(expected) == {:ok, packed}

    for codec <- [@be, @le] do
      assert {:ok, words} = codec.encode_discard(codepoints)
      assert codec.decode(words) == {:ok, expected}
      assert codec.encode(expected) == {:ok, words}
    end
  end

  test "RED: strict, discard, substitution, and incomplete-unit recovery always progress" do
    valid = 0x900
    invalid = 0xFFF

    assert @profile.decode_packed(<<valid::12, invalid::12, valid::12>>) ==
             {:error, :invalid_sequence, 12, <<invalid::12>>}

    assert @profile.decode_packed_discard(<<valid::12, invalid::12, valid::12>>) ==
             {:ok, [?A, ?A]}

    assert @profile.decode_packed(<<valid::12, 0b10101::5>>) ==
             {:error, :incomplete_sequence, 12, <<0b10101::5>>}

    assert @profile.decode_packed_discard(<<valid::12, 0b10101::5>>) == {:ok, [?A]}

    assert @profile.encode_packed([?A, 0x1F600, ?B]) ==
             {:error, :unrepresentable_character, 0x1F600}

    assert @profile.encode_packed_discard([?A, 0x1F600, ?B]) ==
             @profile.encode_packed(~c"AB")

    assert @profile.encode_packed_substitute([?A, 0x1F600, ?B], fn _ -> [0x20] end) ==
             @profile.encode_packed(~c"A B")

    assert {:ok, %LSB{} = valid_lsb} = @profile.pack_masks_lsb([valid])
    <<low, high>> = valid_lsb.data

    partial_lsb = %{valid_lsb | data: <<low, high ||| 0xA0, 0x01>>, bit_size: 17}
    assert @profile.decode_packed_lsb(partial_lsb) == {:error, :incomplete_unit, 12, 5}
    assert @profile.decode_packed_lsb_discard(partial_lsb) == {:ok, [?A]}

    for {codec, endian} <- [{@be, :big}, {@le, :little}] do
      valid_word = word(valid, endian)
      invalid_word = word(invalid, endian)

      assert codec.decode(valid_word <> invalid_word <> valid_word) ==
               {:error, :invalid_sequence, 2, invalid_word}

      assert codec.decode_discard(valid_word <> invalid_word <> valid_word <> <<0x12>>) ==
               {:ok, [?A, ?A]}

      assert codec.decode(valid_word <> <<0x12>>) ==
               {:error, :incomplete_sequence, 2, <<0x12>>}

      high_nibble_word = word(0x1000 ||| valid, endian)

      assert codec.decode(high_nibble_word) ==
               {:error, :invalid_sequence, 0, high_nibble_word}

      assert codec.encode_substitute([?A, 0x1F600, ?B], fn _ -> [0x20] end) ==
               codec.encode(~c"A B")
    end
  end

  test "RED: one-shot and stream decoding agree at every byte split" do
    for {codec, endian} <- [{@be, :big}, {@le, :little}] do
      assert {:ok, token} = Iconvex.register_codec_if_absent(codec)

      try do
        valid_input = words([0x900, 0x880, 0x840, 0x820], endian)

        for split <- 0..byte_size(valid_input) do
          chunks = [
            binary_part(valid_input, 0, split),
            binary_part(valid_input, split, byte_size(valid_input) - split)
          ]

          assert {:ok, stream} = Iconvex.stream(chunks, codec.canonical_name(), "UTF-8")
          assert stream |> Enum.to_list() |> IO.iodata_to_binary() == "ABCD"
        end

        invalid_input = word(0x1900, endian) <> word(0x001, endian)

        assert Iconvex.convert(
                 invalid_input,
                 codec.canonical_name(),
                 "UTF-8",
                 invalid: :discard
               ) == {:ok, "9"}

        for split <- 0..byte_size(invalid_input) do
          chunks = [
            binary_part(invalid_input, 0, split),
            binary_part(invalid_input, split, byte_size(invalid_input) - split)
          ]

          assert {:ok, stream} =
                   Iconvex.stream(chunks, codec.canonical_name(), "UTF-8", invalid: :discard)

          assert stream |> Enum.to_list() |> IO.iodata_to_binary() == "9"
        end
      after
        if is_reference(token), do: assert(:ok == Iconvex.unregister_codec(codec, token))
      end

      assert {:ok, %{codec: ^codec}} = Iconvex.Registry.resolve(codec)
    end
  end

  test "RED: only content-addressed Iowa names identify this profile" do
    assert @profile.canonical_name() == "IBM-029-CARD-IOWA-824E61A9"
    assert @profile.aliases() == ["IBM-029-PUNCHED-CARD-IOWA-824E61A9"]
    assert @profile.standard_packed_order() == :msb
    assert @profile.nonstandard_packed_orders() == [:lsb]
    assert @profile.transport_codecs() == [@be, @le]

    assert @be.canonical_name() == "IBM-029-CARD-IOWA-824E61A9-16BE"
    assert @le.canonical_name() == "IBM-029-CARD-IOWA-824E61A9-16LE"

    for name <- ["IBM-029", "IBM029", "IBM 029 card code", "IBM-029-CARD"] do
      refute name in @profile.aliases()
      assert Iconvex.Specs.Packed.profile(name) == nil
    end
  end

  test "RED: native word and packed loops remain linear by process reductions" do
    short = List.duplicate(?A, 20_000)
    long = List.duplicate(?A, 40_000)

    assert {:ok, short_words} = @be.encode(short)
    assert {:ok, long_words} = @be.encode(long)
    assert {:ok, short_packed} = @profile.encode_packed(short)
    assert {:ok, long_packed} = @profile.encode_packed(long)

    for {short_fun, long_fun} <- [
          {fn -> @be.encode(short) end, fn -> @be.encode(long) end},
          {fn -> @be.decode(short_words) end, fn -> @be.decode(long_words) end},
          {fn -> @profile.encode_packed(short) end, fn -> @profile.encode_packed(long) end},
          {fn -> @profile.decode_packed(short_packed) end,
           fn -> @profile.decode_packed(long_packed) end}
        ] do
      assert {:ok, _} = short_fun.()
      short_reductions = reductions(short_fun)
      long_reductions = reductions(long_fun)
      ratio = long_reductions / short_reductions
      assert ratio > 1.70 and ratio < 2.30
    end
  end

  test "RED: focused benchmark compares all transports with source-derived reference loops" do
    root = Path.expand("..", __DIR__)
    benchmark = Path.join(root, "bench/ibm_029_card_iowa_benchmark.exs")
    source = File.read!(benchmark)

    assert source =~ "ibm_029_card_iowa_824e61a9.csv"
    assert source =~ "reference_msb_encode"
    assert source =~ "reference_lsb_encode"
    assert source =~ "reference_word_encode"

    mix = System.find_executable("mix") || flunk("mix executable is unavailable")

    env = [
      {"MIX_ENV", "test"},
      {"MIX_BUILD_PATH", Path.expand(Mix.Project.build_path(), root)},
      {"ICONVEX_PATH", Path.expand("../iconvex", root)},
      {"ICONVEX_ARCHIVE_PATH", Path.expand("..", root)}
    ]

    {output, status} =
      System.cmd(
        mix,
        ["run", "--no-compile", benchmark, "--quick"],
        cd: root,
        env: env,
        stderr_to_stdout: true
      )

    assert status == 0, output

    for operation <- [
          "packed MSB encode",
          "packed MSB decode",
          "packed LSB encode",
          "packed LSB decode",
          "16BE encode",
          "16BE decode",
          "16LE encode",
          "16LE decode"
        ] do
      assert output =~ "#{operation} native / source-derived reference:"
    end

    assert output =~ "all 8 native/reference 30x ceiling gates passed"
    assert output =~ "all 8 reduction-scaling gates passed"
  end

  defp normalized_rows do
    @mapping_path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> tl()
    |> Enum.map(fn line ->
      [column, codepoint, mask, disposition] = String.split(line, ",")

      %{
        source_column: String.to_integer(column),
        codepoint: codepoint |> String.trim_leading("U+") |> String.to_integer(16),
        mask: mask |> String.trim_leading("0x") |> String.to_integer(16),
        disposition: String.to_existing_atom(disposition)
      }
    end)
  end

  defp canonical_rows, do: Enum.filter(normalized_rows(), &(&1.disposition == :canonical))
  defp alias_rows, do: Enum.filter(normalized_rows(), &(&1.disposition == :decode_alias))

  defp iowa_ibm_029_mapping do
    block =
      @source_path
      |> File.read!()
      |> String.split("<H3><A NAME=029>The IBM model 029 keypunch</A></H3>", parts: 2)
      |> List.last()
      |> String.split("<PRE WIDTH=70>", parts: 2)
      |> List.last()
      |> String.split("</PRE>", parts: 2)
      |> List.first()

    lines = String.split(block, "\n")
    header = Enum.find(lines, &String.starts_with?(&1, "029  "))

    codepoints =
      header
      |> binary_part(4, byte_size(header) - 4)
      |> String.replace("&amp;", "&")
      |> String.replace("&quot;", "\"")
      |> String.replace("&#162;", "¢")
      |> String.replace("&lt;", "<")
      |> String.replace("&#172;", "¬")
      |> String.replace("&gt;", ">")
      |> String.to_charlist()

    assert length(codepoints) == 64

    punch_rows = [
      {"12 /", 0x800},
      {"11|", 0x400},
      {" 0|", 0x200},
      {" 1|", 0x100},
      {" 2|", 0x080},
      {" 3|", 0x040},
      {" 4|", 0x020},
      {" 5|", 0x010},
      {" 6|", 0x008},
      {" 7|", 0x004},
      {" 8|", 0x002},
      {" 9|", 0x001}
    ]

    cells =
      Enum.map(punch_rows, fn {prefix, bit} ->
        line = Enum.find(lines, &String.starts_with?(&1, prefix))
        row = line |> binary_part(4, byte_size(line) - 4) |> String.pad_trailing(64)
        {row, bit}
      end)

    codepoints
    |> Enum.with_index()
    |> Enum.map(fn {codepoint, column} ->
      mask =
        Enum.reduce(cells, 0, fn {row, bit}, acc ->
          if :binary.at(row, column) == ?O, do: acc ||| bit, else: acc
        end)

      %{source_column: column, codepoint: codepoint, mask: mask}
    end)
  end

  defp assert_decode({:ok, codepoint}, actual, _offset, _sequence),
    do: assert(actual == {:ok, [codepoint]})

  defp assert_decode(:error, actual, offset, sequence),
    do: assert(actual == {:error, :invalid_sequence, offset, sequence})

  defp words(masks, endian), do: masks |> Enum.map(&word(&1, endian)) |> IO.iodata_to_binary()
  defp word(mask, :big), do: <<mask::16-big>>
  defp word(mask, :little), do: <<mask::16-little>>

  defp reductions(function) do
    {:reductions, before_count} = Process.info(self(), :reductions)
    assert {:ok, _} = function.()
    {:reductions, after_count} = Process.info(self(), :reductions)
    after_count - before_count
  end

  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end

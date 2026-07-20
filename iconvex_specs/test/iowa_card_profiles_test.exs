defmodule Iconvex.Specs.IowaCardProfilesTest do
  use ExUnit.Case, async: false

  @moduletag timeout: :infinity

  import Bitwise

  alias Iconvex.Packed.LSB

  @source_dir Path.expand("../priv/sources/punched-card-codes", __DIR__)
  @source_path Path.join(@source_dir, "uiowa-punched-card-codes.html")
  @source_sha256 "824e61a9687f7fa0b9c9dd3c966ca02020bf8af1ab6671e9bd2e131f22f47b18"

  @unicode_corpus Path.expand("fixtures/all-unicode-scalars.utf32be", __DIR__)
  @unicode_corpus_sha256 "d037f6200ae8845906b4372a8b3fcd39730e3a61c4af0e354823010e6f93be54"

  @profiles [
    %{
      key: :dec_026,
      tag: "DEC6",
      canonical: "DEC-026-CARD-IOWA-824E61A9",
      logical: Iconvex.Specs.DEC026CardIowa824E61A9,
      be: Iconvex.Specs.DEC026CardIowa824E61A9_16BE,
      le: Iconvex.Specs.DEC026CardIowa824E61A9_16LE,
      csv: "dec_026_card_iowa_824e61a9.csv",
      csv_sha256: "b5e4bd965af2c72f2b643e2681792e2c39d5dc25819268181f74f2cac94cc5d4"
    },
    %{
      key: :dec_029,
      tag: "DEC9",
      canonical: "DEC-029-CARD-IOWA-824E61A9",
      logical: Iconvex.Specs.DEC029CardIowa824E61A9,
      be: Iconvex.Specs.DEC029CardIowa824E61A9_16BE,
      le: Iconvex.Specs.DEC029CardIowa824E61A9_16LE,
      csv: "dec_029_card_iowa_824e61a9.csv",
      csv_sha256: "810293f09cc61dc043f122465edb13a85d319f0c5c494882b7e9a715dc5222ba"
    },
    %{
      key: :ebcd,
      tag: "EBCD",
      canonical: "EBCD-CARD-IOWA-824E61A9",
      logical: Iconvex.Specs.EBCDCardIowa824E61A9,
      be: Iconvex.Specs.EBCDCardIowa824E61A9_16BE,
      le: Iconvex.Specs.EBCDCardIowa824E61A9_16LE,
      csv: "ebcd_card_iowa_824e61a9.csv",
      csv_sha256: "1a57f8721c556354d6b3dde76d62ab9fbe6d8e405d4d7bf93e053d989bc4f588"
    },
    %{
      key: :ge_600,
      tag: "GE  ",
      canonical: "GE-600-CARD-IOWA-824E61A9",
      logical: Iconvex.Specs.GE600CardIowa824E61A9,
      be: Iconvex.Specs.GE600CardIowa824E61A9_16BE,
      le: Iconvex.Specs.GE600CardIowa824E61A9_16LE,
      csv: "ge_600_card_iowa_824e61a9.csv",
      csv_sha256: "d2e0846ed24df4b20492191a781238fb9e507b0628173ca504091a0c38313c7d"
    }
  ]

  test "RED: the four complete Iowa tables are independently extracted and digest-pinned" do
    html = File.read!(@source_path)
    assert sha256(html) == @source_sha256
    assert html =~ "0-8-2 punch shown as _ should be printed as an\nassignment arrow"
    assert html =~ "11-8-2 punch shown as ^ should be printed as an\nup-arrow"
    assert html =~ "it is possible that the problem is with the\nhandbook"
    assert html =~ "The EBCD and IBMEL character sets come from Dik Winter's collection"

    for profile <- @profiles do
      assert Code.ensure_loaded?(profile.logical)
      assert Code.ensure_loaded?(profile.be)
      assert Code.ensure_loaded?(profile.le)

      rows = normalized_rows(profile)
      extracted = source_rows(profile)

      assert length(rows) == 64
      assert Enum.map(rows, & &1.source_column) == Enum.to_list(0..63)
      assert Enum.map(rows, &Map.take(&1, [:source_column, :codepoint, :mask])) == extracted
      assert Enum.all?(rows, &(&1.disposition == :canonical))
      assert rows |> Enum.map(& &1.codepoint) |> Enum.uniq() |> length() == 64
      assert rows |> Enum.map(& &1.mask) |> Enum.uniq() |> length() == 64

      csv = File.read!(Path.join(@source_dir, profile.csv))
      assert sha256(csv) == profile.csv_sha256
      assert apply(profile.logical, :normalized_mapping_sha256, []) == profile.csv_sha256
      assert apply(profile.logical, :source_sha256, []) == @source_sha256

      assert apply(profile.logical, :source_url, []) ==
               "https://homepage.cs.uiowa.edu/~jones/cards/codes.html"
    end
  end

  test "RED: every source column is exact in logical, BE, LE, MSB, and LSB forms" do
    for profile <- @profiles do
      rows = normalized_rows(profile)
      codepoints = Enum.map(rows, & &1.codepoint)
      text = List.to_string(codepoints)

      for %{codepoint: codepoint, mask: mask} <- rows do
        assert call(profile.logical, :encode_packed, [[codepoint]]) == {:ok, <<mask::12>>}
        assert call(profile.logical, :decode_packed, [<<mask::12>>]) == {:ok, [codepoint]}

        assert {:ok, %LSB{unit_bits: 12, bit_size: 12} = packed_lsb} =
                 call(profile.logical, :encode_packed_lsb, [[codepoint]])

        assert call(profile.logical, :decode_packed_lsb, [packed_lsb]) == {:ok, [codepoint]}
        assert call(profile.be, :encode, [[codepoint]]) == {:ok, <<mask::16-big>>}
        assert call(profile.be, :decode, [<<mask::16-big>>]) == {:ok, [codepoint]}
        assert call(profile.le, :encode, [[codepoint]]) == {:ok, <<mask::16-little>>}
        assert call(profile.le, :decode, [<<mask::16-little>>]) == {:ok, [codepoint]}
      end

      assert {:ok, packed_msb} =
               call(profile.logical, :encode_packed_from_utf8, [text, :msb])

      assert call(profile.logical, :decode_packed_to_utf8, [packed_msb, :msb]) == {:ok, text}

      assert {:ok, %LSB{} = packed_lsb} =
               call(profile.logical, :encode_packed_from_utf8, [text, :lsb])

      assert call(profile.logical, :decode_packed_to_utf8, [packed_lsb, :lsb]) == {:ok, text}

      for codec <- [profile.be, profile.le] do
        assert {:ok, words} = call(codec, :encode_from_utf8, [text])
        assert call(codec, :decode_to_utf8, [words]) == {:ok, text}
      end
    end
  end

  test "RED: all 4096 masks have exactly the source-documented disposition" do
    for profile <- @profiles do
      accepted = Map.new(normalized_rows(profile), &{&1.mask, &1.codepoint})

      for mask <- 0..0xFFF do
        expected = Map.fetch(accepted, mask)

        assert_decode(
          expected,
          call(profile.logical, :decode_packed, [<<mask::12>>]),
          0,
          <<mask::12>>
        )

        assert_decode(
          expected,
          call(profile.be, :decode, [<<mask::16-big>>]),
          0,
          <<mask::16-big>>
        )

        assert_decode(
          expected,
          call(profile.le, :decode, [<<mask::16-little>>]),
          0,
          <<mask::16-little>>
        )

        assert {:ok, %LSB{} = packed_lsb} = call(profile.logical, :pack_masks_lsb, [[mask]])
        assert_decode(expected, call(profile.logical, :decode_packed_lsb, [packed_lsb]), 0, mask)
      end
    end
  end

  test "RED: the all-Unicode corpus exposes no accidental encoder keys" do
    corpus = File.read!(@unicode_corpus)
    assert sha256(corpus) == @unicode_corpus_sha256
    codepoints = for <<codepoint::unsigned-big-32 <- corpus>>, do: codepoint
    assert length(codepoints) == 1_112_064

    for profile <- @profiles do
      expected = normalized_rows(profile) |> Enum.map(& &1.codepoint) |> Enum.sort()
      assert {:ok, packed} = call(profile.logical, :encode_packed_discard, [codepoints])
      assert call(profile.logical, :decode_packed, [packed]) == {:ok, expected}
      assert call(profile.logical, :encode_packed, [expected]) == {:ok, packed}

      for codec <- [profile.be, profile.le] do
        assert call(codec, :logical_profile, []) == profile.logical
        assert {:ok, words} = call(codec, :encode_discard, [codepoints])
        assert call(codec, :decode, [words]) == {:ok, expected}
      end
    end
  end

  test "RED: strict, discard, substitution, incomplete-unit, and high-nibble recovery progress" do
    for profile <- @profiles do
      valid = source_rows(profile) |> Enum.at(13) |> Map.fetch!(:mask)
      valid_codepoint = source_rows(profile) |> Enum.at(13) |> Map.fetch!(:codepoint)
      invalid = 0xFFF

      assert call(profile.logical, :decode_packed, [<<valid::12, invalid::12, valid::12>>]) ==
               {:error, :invalid_sequence, 12, <<invalid::12>>}

      assert call(profile.logical, :decode_packed_discard, [<<valid::12, invalid::12, valid::12>>]) ==
               {:ok, [valid_codepoint, valid_codepoint]}

      assert call(profile.logical, :decode_packed, [<<valid::12, 0b10101::5>>]) ==
               {:error, :incomplete_sequence, 12, <<0b10101::5>>}

      assert call(profile.logical, :encode_packed, [[valid_codepoint, 0x1F600]]) ==
               {:error, :unrepresentable_character, 0x1F600}

      assert call(profile.logical, :encode_packed_substitute, [
               [valid_codepoint, 0x1F600],
               fn _ -> [0x20] end
             ]) == call(profile.logical, :encode_packed, [[valid_codepoint, 0x20]])

      for {codec, endian} <- [{profile.be, :big}, {profile.le, :little}] do
        valid_word = word(valid, endian)
        invalid_word = word(invalid, endian)

        assert call(codec, :decode, [valid_word <> invalid_word <> valid_word]) ==
                 {:error, :invalid_sequence, 2, invalid_word}

        assert call(codec, :decode_discard, [valid_word <> invalid_word <> valid_word <> <<0x12>>]) ==
                 {:ok, [valid_codepoint, valid_codepoint]}

        assert call(codec, :decode, [valid_word <> <<0x12>>]) ==
                 {:error, :incomplete_sequence, 2, <<0x12>>}

        high_nibble_word = word(0x1000 ||| valid, endian)

        assert call(codec, :decode, [high_nibble_word]) ==
                 {:error, :invalid_sequence, 0, high_nibble_word}
      end
    end
  end

  test "RED: one-shot and stream decoding agree at every byte boundary" do
    for profile <- @profiles, {codec, endian} <- [{profile.be, :big}, {profile.le, :little}] do
      assert {:ok, token} = Iconvex.register_codec_if_absent(codec)

      try do
        rows = Enum.take(source_rows(profile), 4)
        input = rows |> Enum.map(&word(&1.mask, endian)) |> IO.iodata_to_binary()
        expected = rows |> Enum.map(& &1.codepoint) |> List.to_string()
        canonical = call(codec, :canonical_name, [])

        assert Iconvex.convert(input, canonical, "UTF-8") == {:ok, expected}
        assert Iconvex.convert(expected, "UTF-8", canonical) == {:ok, input}

        for split <- 0..byte_size(input) do
          chunks = [
            binary_part(input, 0, split),
            binary_part(input, split, byte_size(input) - split)
          ]

          assert {:ok, stream} = Iconvex.stream(chunks, canonical, "UTF-8")
          assert stream |> Enum.to_list() |> IO.iodata_to_binary() == expected
        end

        invalid = word(0xFFF, endian) <> word(hd(rows).mask, endian)

        assert {:error, %Iconvex.Error{kind: :invalid_sequence, offset: 0}} =
                 Iconvex.convert(invalid, canonical, "UTF-8")

        assert Iconvex.convert(invalid, canonical, "UTF-8", invalid: :discard) ==
                 {:ok, List.to_string([hd(rows).codepoint])}

        for split <- 0..byte_size(invalid) do
          chunks = [
            binary_part(invalid, 0, split),
            binary_part(invalid, split, byte_size(invalid) - split)
          ]

          assert {:ok, stream} = Iconvex.stream(chunks, canonical, "UTF-8", invalid: :discard)

          assert stream |> Enum.to_list() |> IO.iodata_to_binary() ==
                   List.to_string([hd(rows).codepoint])
        end
      after
        if is_reference(token), do: assert(:ok == Iconvex.unregister_codec(codec, token))
      end

      assert {:ok, %{codec: ^codec}} = Iconvex.Registry.resolve(codec)
    end
  end

  test "RED: only content-addressed Iowa identities are public and centrally registered" do
    registrations = Iconvex.Specs.registrations()
    logical = Iconvex.Specs.non_octet_codecs()
    packed = Iconvex.Specs.Packed.all_profiles()

    for profile <- @profiles do
      assert call(profile.logical, :canonical_name, []) == profile.canonical
      assert call(profile.logical, :canonical_count, []) == 64
      assert call(profile.logical, :decode_alias_count, []) == 0
      assert call(profile.logical, :standard_packed_order, []) == :msb
      assert call(profile.logical, :nonstandard_packed_orders, []) == [:lsb]
      assert call(profile.logical, :transport_codecs, []) == [profile.be, profile.le]
      assert profile.logical in logical

      assert Enum.any?(
               packed,
               &(&1.codec == profile.logical and &1.canonical == profile.canonical)
             )

      for codec <- [profile.be, profile.le] do
        assert Enum.any?(registrations, &(&1.codec == codec and &1.source == "SPECS"))
      end

      generic = profile.canonical |> String.split("-IOWA-") |> hd()
      refute generic in call(profile.logical, :aliases, [])
      assert Iconvex.Specs.Packed.profile(generic) == nil
    end
  end

  test "RED: native word and packed loops remain linear by process reductions" do
    for profile <- @profiles do
      codepoint = source_rows(profile) |> Enum.at(13) |> Map.fetch!(:codepoint)
      short = List.duplicate(codepoint, 10_000)
      long = List.duplicate(codepoint, 20_000)

      assert {:ok, short_words} = call(profile.be, :encode, [short])
      assert {:ok, long_words} = call(profile.be, :encode, [long])
      assert {:ok, short_packed} = call(profile.logical, :encode_packed, [short])
      assert {:ok, long_packed} = call(profile.logical, :encode_packed, [long])

      for {short_fun, long_fun} <- [
            {fn -> call(profile.be, :encode, [short]) end,
             fn -> call(profile.be, :encode, [long]) end},
            {fn -> call(profile.be, :decode, [short_words]) end,
             fn -> call(profile.be, :decode, [long_words]) end},
            {fn -> call(profile.logical, :encode_packed, [short]) end,
             fn -> call(profile.logical, :encode_packed, [long]) end},
            {fn -> call(profile.logical, :decode_packed, [short_packed]) end,
             fn -> call(profile.logical, :decode_packed, [long_packed]) end}
          ] do
        short_reductions = reductions(short_fun)
        long_reductions = reductions(long_fun)
        ratio = long_reductions / short_reductions
        assert ratio > 1.70 and ratio < 2.30
      end
    end
  end

  test "RED: focused benchmark covers every exact profile and transport against source loops" do
    root = Path.expand("..", __DIR__)
    benchmark = Path.join(root, "bench/iowa_card_profiles_benchmark.exs")
    source = File.read!(benchmark)

    for profile <- @profiles do
      assert source =~ profile.csv
      assert source =~ profile.canonical
    end

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
      System.cmd(mix, ["run", "--no-compile", benchmark, "--quick"],
        cd: root,
        env: env,
        stderr_to_stdout: true
      )

    assert status == 0, output
    assert output =~ "all 32 native/reference 30x ceiling gates passed"
    assert output =~ "all 32 reduction-scaling gates passed"
  end

  test "RED: Hollerith consensus remains blocked because the source explicitly varies cells" do
    html = File.read!(@source_path)

    consensus =
      html
      |> String.split("the &quot;consensus code&quot;", parts: 2)
      |> List.last()
      |> String.split("<H3>The IBM model 026 keypunch</H3>", parts: 2)
      |> List.first()

    assert consensus =~ "shown with ?"
    assert consensus =~ "some variation in the coding"
    assert length(Regex.scan(~r/\?/, consensus)) >= 4
    refute Code.ensure_loaded?(Iconvex.Specs.HollerithConsensusCardIowa824E61A9)
  end

  defp normalized_rows(profile) do
    profile.csv
    |> then(&Path.join(@source_dir, &1))
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

  defp source_rows(profile) do
    lines =
      @source_path
      |> File.read!()
      |> String.split("\n")

    header_index = Enum.find_index(lines, &String.starts_with?(&1, profile.tag))
    line = Enum.at(lines, header_index)

    codepoints =
      line
      |> binary_part(4, byte_size(line) - 4)
      |> decode_entities()
      |> String.to_charlist()
      |> apply_source_corrections(profile.key)

    assert length(codepoints) == 64

    diagram = lines |> Enum.drop(header_index + 1) |> Enum.take_while(&(&1 != "</PRE>"))

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
        row = Enum.find(diagram, &String.starts_with?(&1, prefix))
        row = row |> binary_part(4, byte_size(row) - 4) |> String.pad_trailing(64)
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

  defp decode_entities(value) do
    value
    |> String.replace("&amp;", "&")
    |> String.replace("&quot;", "\"")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
  end

  defp apply_source_corrections(codepoints, :ge_600) do
    codepoints
    |> List.replace_at(52, 0x2191)
    |> List.replace_at(58, 0x2190)
  end

  defp apply_source_corrections(codepoints, _profile), do: codepoints

  defp assert_decode({:ok, codepoint}, actual, _offset, _sequence),
    do: assert(actual == {:ok, [codepoint]})

  defp assert_decode(:error, actual, offset, sequence),
    do: assert(actual == {:error, :invalid_sequence, offset, sequence})

  defp call(module, function, arguments), do: apply(module, function, arguments)
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

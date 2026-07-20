defmodule Iconvex.Specs.ECMA44RawTransportTest do
  use ExUnit.Case, async: true
  @moduletag timeout: :infinity

  import Bitwise
  alias Iconvex.Packed.LSB
  alias Iconvex.Specs.ECMA44
  alias Iconvex.Specs.RawTransports

  @ecma44_module_path Path.expand("../lib/iconvex/specs/ecma44.ex", __DIR__)
  @source_table_path Path.expand("../priv/sources/ecma-44/ecma44_table.csv", __DIR__)
  @source_metadata_path Path.expand("../priv/sources/ecma-44/SOURCE_METADATA.md", __DIR__)
  @source_table_sha256 "834abb8180af52f790f09ace4f6bc75953a2c8e0df98bb5dcb33f62d3a644995"

  # Independently transcribed from ECMA-44 Table 2 (PDF page 11, printed page 6).
  # Tuple position is the eight-bit combination and the value is the physical
  # card mask in row order 12, 11, 0, 1, ..., 9.
  @masks [
    0xB03,
    0x901,
    0x881,
    0x841,
    0x005,
    0x213,
    0x20B,
    0x207,
    0x409,
    0x811,
    0x211,
    0x843,
    0x823,
    0x813,
    0x80B,
    0x807,
    0xD03,
    0x501,
    0x481,
    0x441,
    0x023,
    0x013,
    0x081,
    0x209,
    0x403,
    0x503,
    0x007,
    0x205,
    0x423,
    0x413,
    0x40B,
    0x407,
    0x000,
    0x806,
    0x006,
    0x042,
    0x442,
    0x222,
    0x800,
    0x012,
    0x812,
    0x412,
    0x422,
    0x80A,
    0x242,
    0x400,
    0x842,
    0x300,
    0x200,
    0x100,
    0x080,
    0x040,
    0x020,
    0x010,
    0x008,
    0x004,
    0x002,
    0x001,
    0x082,
    0x40A,
    0x822,
    0x00A,
    0x20A,
    0x206,
    0x022,
    0x900,
    0x880,
    0x840,
    0x820,
    0x810,
    0x808,
    0x804,
    0x802,
    0x801,
    0x500,
    0x480,
    0x440,
    0x420,
    0x410,
    0x408,
    0x404,
    0x402,
    0x401,
    0x280,
    0x240,
    0x220,
    0x210,
    0x208,
    0x204,
    0x202,
    0x201,
    0x882,
    0x282,
    0x482,
    0x406,
    0x212,
    0x102,
    0xB00,
    0xA80,
    0xA40,
    0xA20,
    0xA10,
    0xA08,
    0xA04,
    0xA02,
    0xA01,
    0xD00,
    0xC80,
    0xC40,
    0xC20,
    0xC10,
    0xC08,
    0xC04,
    0xC02,
    0xC01,
    0x680,
    0x640,
    0x620,
    0x610,
    0x608,
    0x604,
    0x602,
    0x601,
    0xA00,
    0xC00,
    0x600,
    0x700,
    0x805,
    0x703,
    0x301,
    0x281,
    0x241,
    0x221,
    0x411,
    0x809,
    0x405,
    0x203,
    0x303,
    0x283,
    0x243,
    0x223,
    0x903,
    0x883,
    0x443,
    0xF03,
    0x101,
    0x483,
    0x041,
    0x021,
    0x011,
    0x009,
    0x803,
    0x003,
    0x103,
    0x083,
    0x043,
    0x821,
    0x421,
    0x00B,
    0x701,
    0xB01,
    0xA81,
    0xA41,
    0xA21,
    0xA11,
    0xA09,
    0xA05,
    0xA03,
    0x902,
    0xD01,
    0xC81,
    0xC41,
    0xC21,
    0xC11,
    0xC09,
    0xC05,
    0xC03,
    0x502,
    0x681,
    0x641,
    0x621,
    0x611,
    0x609,
    0x605,
    0x603,
    0x302,
    0xE00,
    0xF01,
    0xE81,
    0xE41,
    0xE21,
    0xE11,
    0xE09,
    0xE05,
    0xE03,
    0xB02,
    0xA82,
    0xA42,
    0xA22,
    0xA12,
    0xA0A,
    0xA06,
    0xD02,
    0xC82,
    0xC42,
    0xC22,
    0xC12,
    0xC0A,
    0xC06,
    0x702,
    0x682,
    0x642,
    0x622,
    0x612,
    0x60A,
    0x606,
    0xF02,
    0xF00,
    0xE80,
    0xE40,
    0xE20,
    0xE10,
    0xE08,
    0xE04,
    0xE02,
    0xE01,
    0xE82,
    0xE42,
    0xE22,
    0xE12,
    0xE0A,
    0xE06,
    0xA83,
    0xA43,
    0xA23,
    0xA13,
    0xA0B,
    0xA07,
    0xC83,
    0xC43,
    0xC23,
    0xC13,
    0xC0B,
    0xC07,
    0x683,
    0x643,
    0x623,
    0x613,
    0x60B,
    0x607,
    0xE83,
    0xE43,
    0xE23,
    0xE13,
    0xE0B,
    0xE07
  ]

  @input 0..255 |> Enum.to_list() |> :erlang.list_to_binary()
  @seven_bit_input 0..127 |> Enum.to_list() |> :erlang.list_to_binary()
  @inverse @masks |> Enum.with_index() |> Map.new()
  @seven_bit_inverse @masks |> Enum.take(128) |> Enum.with_index() |> Map.new()

  test "RED: ECMA-44 remains a raw code-combination transport outside Unicode registries" do
    assert ECMA44.unicode_character_encoding?() == false
    assert ECMA44.standard_packed_order() == nil
    assert ECMA44.library_packed_orders() == [:msb, :lsb]
    refute function_exported?(ECMA44, :decode_to_utf8, 1)
    refute function_exported?(ECMA44, :encode_from_utf8, 1)

    registered = Iconvex.Specs.codecs() ++ Iconvex.Specs.catalogued_codecs()
    refute ECMA44 in registered
    refute ECMA44 in Iconvex.Specs.non_octet_codecs()
    refute Enum.any?(Iconvex.Specs.Packed.all_profiles(), &(&1.codec == ECMA44))

    for name <- ["ECMA-44", "ECMA-44-7BIT-CARD-RAW", "ECMA-44-8BIT-CARD-RAW"] do
      assert Iconvex.canonical_name(name) == :error
    end
  end

  test "RED: independently transcribed table and durable source metadata are exact" do
    assert length(@masks) == 256
    assert length(Enum.uniq(@masks)) == 256

    assert ECMA44.source_url() ==
             "https://www.ecma-international.org/wp-content/uploads/ECMA-44_1st_edition_september_1975.pdf"

    assert ECMA44.source_sha256() ==
             "09b71ed57db7a0b2c1e9bc7006f001df198450f37b706c01d2754ddb5a5de228"

    assert ECMA44.source_pages() == [9, 11]
    assert ECMA44.printed_source_pages() == ["4", "6"]

    u16be = @masks |> Enum.map(&<<&1::16-big>>) |> IO.iodata_to_binary()
    msb = pack_msb(@masks)

    assert sha256(u16be) ==
             "bf6d824c690380439344c99e4ba68887241305b243456390aa23b8d94cc68119"

    assert sha256(msb) ==
             "218cced6aee83c5ec3fa8823761556c60f872ea367d24c66e2dd43a5b83b6a75"

    assert ECMA44.table_u16be_sha256() == sha256(u16be)
    assert ECMA44.table_packed_msb_sha256() == sha256(msb)

    assert ECMA44.source_table_sha256() ==
             "834abb8180af52f790f09ace4f6bc75953a2c8e0df98bb5dcb33f62d3a644995"

    assert source_table_masks() == @masks

    assert File.read!("priv/sources/ecma-44/ecma44_table.csv") |> sha256() ==
             "834abb8180af52f790f09ace4f6bc75953a2c8e0df98bb5dcb33f62d3a644995"

    metadata = File.read!("priv/sources/ecma-44/SOURCE_METADATA.md")
    assert metadata =~ ECMA44.source_url()
    assert metadata =~ ECMA44.source_sha256()
    assert metadata =~ "not a Unicode character encoding"
    refute metadata =~ "ECMA-44_1st_edition_september_1975.pdf is packaged"
  end

  test "RED: source validator binds exact CSV bytes, schema, and runtime semantics" do
    table = File.read!(@source_table_path)
    validator = Iconvex.Specs.ECMA44.SourceAsset

    assert validator.validate!(table,
             source_table_sha256: @source_table_sha256,
             expected_masks: List.to_tuple(@masks)
           ) == List.to_tuple(@masks)

    assert_raise RuntimeError, ~r/source table SHA-256 mismatch/, fn ->
      validator.validate!(table <> "\n",
        source_table_sha256: @source_table_sha256,
        expected_masks: List.to_tuple(@masks)
      )
    end

    wrong_header = String.replace(table, "high_nibble", "wrong_header", global: false)

    assert_raise RuntimeError, ~r/unexpected ECMA-44 table header/, fn ->
      validator.validate!(wrong_header,
        source_table_sha256: sha256(wrong_header),
        expected_masks: List.to_tuple(@masks)
      )
    end

    swapped_masks = String.replace(table, "0,B03,901", "0,901,B03", global: false)

    assert_raise RuntimeError, ~r/does not match the hardcoded runtime mask tuple/, fn ->
      validator.validate!(swapped_masks,
        source_table_sha256: sha256(swapped_masks),
        expected_masks: List.to_tuple(@masks)
      )
    end
  end

  test "RED: a downstream consumer cannot compile after packaged CSV tampering" do
    root =
      Path.join(
        System.tmp_dir!(),
        "iconvex-ecma44-consumer-#{System.unique_integer([:positive])}"
      )

    source_path = Path.join(root, "lib/iconvex/specs/ecma44.ex")
    table_path = Path.join(root, "priv/sources/ecma-44/ecma44_table.csv")
    metadata_path = Path.join(root, "priv/sources/ecma-44/SOURCE_METADATA.md")

    File.mkdir_p!(Path.dirname(source_path))
    File.mkdir_p!(Path.dirname(table_path))

    source =
      @ecma44_module_path
      |> File.read!()
      |> String.split("\ndefmodule Iconvex.Specs.RawTransports", parts: 2)
      |> hd()
      |> String.replace(
        "Iconvex.Specs.ECMA44",
        "Iconvex.Specs.ECMA44TamperedConsumer"
      )

    File.write!(source_path, source)
    File.write!(table_path, File.read!(@source_table_path) <> "\n")
    File.cp!(@source_metadata_path, metadata_path)
    on_exit(fn -> File.rm_rf!(root) end)

    assert_raise RuntimeError, ~r/source table SHA-256 mismatch/, fn ->
      Code.compile_file(source_path)
    end
  end

  test "RED: all 256 eight-bit combinations are byte-exact in every raw transport" do
    assert ECMA44.encode_masks(@input, :eight_bit) == {:ok, @masks}
    assert ECMA44.decode_masks(@masks, :eight_bit) == {:ok, @input}

    assert ECMA44.encode_packed(@input, :eight_bit) == {:ok, pack_msb(@masks)}
    assert ECMA44.decode_packed(pack_msb(@masks), :eight_bit) == {:ok, @input}

    assert ECMA44.encode_packed_lsb(@input, :eight_bit) == {:ok, pack_lsb(@masks)}
    assert ECMA44.decode_packed_lsb(pack_lsb(@masks), :eight_bit) == {:ok, @input}

    for endian <- [:big, :little] do
      words = words(@masks, endian)
      assert ECMA44.encode_words(@input, :eight_bit, endian) == {:ok, words}
      assert ECMA44.decode_words(words, :eight_bit, endian) == {:ok, @input}
    end
  end

  test "RED: seven-bit mode is exactly the first half and rejects every upper combination" do
    masks = Enum.take(@masks, 128)
    assert ECMA44.encode_masks(@seven_bit_input, :seven_bit) == {:ok, masks}
    assert ECMA44.decode_masks(masks, :seven_bit) == {:ok, @seven_bit_input}
    assert ECMA44.encode_packed(@seven_bit_input, :seven_bit) == {:ok, pack_msb(masks)}
    assert ECMA44.decode_packed(pack_msb(masks), :seven_bit) == {:ok, @seven_bit_input}
    assert ECMA44.encode_packed_lsb(@seven_bit_input, :seven_bit) == {:ok, pack_lsb(masks)}
    assert ECMA44.decode_packed_lsb(pack_lsb(masks), :seven_bit) == {:ok, @seven_bit_input}

    for byte <- 0x80..0xFF do
      offset = byte - 0x80
      input = 0x80..byte |> Enum.to_list() |> :erlang.list_to_binary()

      for operation <- [:encode_masks, :encode_packed, :encode_packed_lsb] do
        assert apply(ECMA44, operation, [input, :seven_bit]) ==
                 {:error, :invalid_code_combination, 0, 0x80}
      end

      for endian <- [:big, :little] do
        assert ECMA44.encode_words(input, :seven_bit, endian) ==
                 {:error, :invalid_code_combination, 0, 0x80}
      end

      mask = Enum.at(@masks, byte)

      assert ECMA44.decode_masks([mask], :seven_bit) ==
               {:error, :invalid_sequence, 0, mask}

      assert ECMA44.decode_packed(<<mask::12>>, :seven_bit) ==
               {:error, :invalid_sequence, 0, <<mask::12>>}

      assert ECMA44.decode_packed_lsb(pack_lsb([mask]), :seven_bit) ==
               {:error, :invalid_sequence, 0, mask}

      assert offset in 0..127
    end
  end

  test "RED: every one of 4096 masks has the exact eight- and seven-bit disposition" do
    for mask <- 0..0xFFF do
      assert_mask_disposition(mask, :eight_bit, @inverse)
      assert_mask_disposition(mask, :seven_bit, @seven_bit_inverse)
    end
  end

  test "RED: the table covers exactly all physically valid ECMA-44 patterns" do
    expected =
      for zone <- 0..0x1F,
          digit <- [0, 0x100, 0x080, 0x040, 0x020, 0x010, 0x008, 0x004] do
        zone_mask =
          (zone &&& 0x10) <<< 7 |||
            (zone &&& 0x08) <<< 7 |||
            (zone &&& 0x04) <<< 7 |||
            (zone &&& 0x02) <<< 0 |||
            (zone &&& 0x01) <<< 0

        zone_mask ||| digit
      end

    assert MapSet.new(expected) == MapSet.new(@masks)

    for mask <- 0..0xFFF do
      physical = popcount(mask &&& 0x1FC) <= 1
      assert ECMA44.physically_valid_mask?(mask) == physical
      assert mask in @masks == physical
    end

    refute ECMA44.physically_valid_mask?(-1)
    refute ECMA44.physically_valid_mask?(0x1000)
    refute ECMA44.physically_valid_mask?(:not_a_mask)
  end

  test "RED: normative anchors include blank, Hollerith-compatible graphics, and Table 2 example" do
    anchors = [
      {0x00, 0xB03},
      {0x20, 0x000},
      {0x30, 0x200},
      {0x31, 0x100},
      {0x39, 0x001},
      {0x41, 0x900},
      {0x4A, 0x500},
      {0x53, 0x280},
      {0x6B, 0xC80},
      {0xFF, 0xE07}
    ]

    for {byte, mask} <- anchors do
      assert ECMA44.encode_masks(<<byte>>, :eight_bit) == {:ok, [mask]}
      assert ECMA44.decode_masks([mask], :eight_bit) == {:ok, <<byte>>}
    end
  end

  test "RED: malformed and incomplete transports report physical bit or byte offsets" do
    valid = Enum.at(@masks, ?A)
    invalid = Enum.find(0..0xFFF, &(not Map.has_key?(@inverse, &1)))

    assert ECMA44.decode_masks([valid, invalid, valid], :eight_bit) ==
             {:error, :invalid_sequence, 1, invalid}

    assert ECMA44.decode_masks([valid, 0x1000], :eight_bit) ==
             {:error, :mask_out_of_range, 1, 0x1000}

    assert ECMA44.decode_masks([valid, :bad], :eight_bit) ==
             {:error, :mask_out_of_range, 1, :bad}

    assert ECMA44.decode_packed(<<valid::12, invalid::12, valid::12>>, :eight_bit) ==
             {:error, :invalid_sequence, 12, <<invalid::12>>}

    assert ECMA44.decode_packed(<<valid::12, 0b10101::5>>, :eight_bit) ==
             {:error, :incomplete_sequence, 12, <<0b10101::5>>}

    for endian <- [:big, :little] do
      input = words([valid, invalid, valid], endian)

      assert ECMA44.decode_words(input, :eight_bit, endian) ==
               {:error, :invalid_sequence, 2, word(invalid, endian)}

      assert ECMA44.decode_words(word(valid, endian) <> <<0x12>>, :eight_bit, endian) ==
               {:error, :incomplete_sequence, 2, <<0x12>>}

      high_word = word(0x1000 ||| valid, endian)

      assert ECMA44.decode_words(high_word, :eight_bit, endian) ==
               {:error, :invalid_sequence, 0, high_word}
    end
  end

  test "RED: LSB shape, width, meaningful length, and padding are strict" do
    mask = Enum.at(@masks, ?A)
    valid = pack_lsb([mask])

    assert ECMA44.decode_packed_lsb(%{valid | bit_order: :msb}, :eight_bit) ==
             {:error, :bit_order_mismatch}

    assert ECMA44.decode_packed_lsb(%{valid | unit_bits: 11}, :eight_bit) ==
             {:error, :unit_width_mismatch}

    assert ECMA44.decode_packed_lsb(%{valid | data: <<0>>}, :eight_bit) ==
             {:error, :invalid_bit_size}

    assert ECMA44.decode_packed_lsb(%LSB{data: <<0>>, bit_size: 5, unit_bits: 12}, :eight_bit) ==
             {:error, :incomplete_unit, 0, 5}

    assert ECMA44.decode_packed_lsb(
             %LSB{data: <<0x00, 0xF0>>, bit_size: 12, unit_bits: 12},
             :eight_bit
           ) == {:error, :nonzero_padding_bits}

    assert ECMA44.decode_packed_lsb(<<0>>, :eight_bit) ==
             {:error, :invalid_packed_transport}
  end

  test "RED: chunk helpers retain partial physical units without inventing Unicode streaming" do
    a = Enum.at(@masks, ?A)
    b = Enum.at(@masks, ?B)
    <<b_first::4, b_rest::8>> = <<b::12>>

    assert ECMA44.decode_packed_chunk(<<a::12, b_first::4>>, :eight_bit, false) ==
             {:ok, "A", <<b_first::4>>}

    assert ECMA44.decode_packed_chunk(<<b_first::4>>, :eight_bit, true) ==
             {:error, :incomplete_sequence, 0, <<b_first::4>>}

    assert ECMA44.decode_packed_chunk(<<b_first::4, b_rest::8>>, :eight_bit, true) ==
             {:ok, "B", <<>>}

    for endian <- [:big, :little] do
      encoded = word(a, endian) <> word(b, endian)
      <<first::binary-size(3), final_byte::binary>> = encoded
      <<_complete::binary-size(2), carried::binary>> = first

      assert ECMA44.decode_words_chunk(first, :eight_bit, endian, false) ==
               {:ok, "A", carried}

      assert ECMA44.decode_words_chunk(carried, :eight_bit, endian, true) ==
               {:error, :incomplete_sequence, 0, carried}

      assert ECMA44.decode_words_chunk(
               carried <> final_byte,
               :eight_bit,
               endian,
               true
             ) ==
               {:ok, "B", <<>>}
    end
  end

  test "RED: raw inventories name semantics and never claim a registered character codec" do
    profiles = RawTransports.profiles()

    assert Enum.map(profiles, & &1.canonical) == [
             "ECMA-44-7BIT-CARD-RAW",
             "ECMA-44-8BIT-CARD-RAW"
           ]

    for profile <- profiles do
      assert profile.module == ECMA44
      assert profile.input_semantics == :raw_code_combination
      assert profile.input_unit_bits in [7, 8]
      assert profile.card_unit_bits == 12
      assert profile.standard_packed_order == nil
      assert profile.library_packed_orders == [:msb, :lsb]
      assert profile.unicode_codec_registered == false
      assert RawTransports.profile(profile.canonical) == profile
    end

    assert RawTransports.profile("missing") == nil

    expected =
      "canonical,mode,module,input_semantics,input_unit_bits,card_unit_bits,standard_packed_order,library_packed_orders,transport_names,unicode_codec_registered\n" <>
        "ECMA-44-7BIT-CARD-RAW,seven_bit,Iconvex.Specs.ECMA44,raw_code_combination,7,12,,msb|lsb,ECMA-44-7BIT-CARD-RAW-PACKED-MSB|ECMA-44-7BIT-CARD-RAW-PACKED-LSB|ECMA-44-7BIT-CARD-RAW-16BE|ECMA-44-7BIT-CARD-RAW-16LE,false\n" <>
        "ECMA-44-8BIT-CARD-RAW,eight_bit,Iconvex.Specs.ECMA44,raw_code_combination,8,12,,msb|lsb,ECMA-44-8BIT-CARD-RAW-PACKED-MSB|ECMA-44-8BIT-CARD-RAW-PACKED-LSB|ECMA-44-8BIT-CARD-RAW-16BE|ECMA-44-8BIT-CARD-RAW-16LE,false\n"

    assert File.read!("SUPPORTED_RAW_TRANSPORT_INVENTORY.csv") == expected
  end

  test "RED: release manifest ships the raw audit evidence but not the source PDF" do
    files = Mix.Project.config() |> Keyword.fetch!(:package) |> Keyword.fetch!(:files)

    for path <- [
          "priv/sources/ecma-44/*.csv",
          "priv/sources/ecma-44/SOURCE_METADATA.md",
          "SUPPORTED_RAW_TRANSPORT_INVENTORY.csv",
          "ECMA44_RAW_TRANSPORT.md"
        ] do
      assert path in files, "release manifest omits #{path}"
    end

    refute Enum.any?(files, &String.ends_with?(&1, ".pdf"))
  end

  test "RED: native raw loops remain linear across large inputs" do
    short = :binary.copy(<<0x6B>>, 20_000)
    long = :binary.copy(<<0x6B>>, 40_000)

    operations = [
      fn input -> ECMA44.encode_masks(input, :eight_bit) end,
      fn input -> ECMA44.encode_packed(input, :eight_bit) end,
      fn input -> ECMA44.encode_packed_lsb(input, :eight_bit) end,
      fn input -> ECMA44.encode_words(input, :eight_bit, :big) end
    ]

    for operation <- operations do
      assert {:ok, _} = operation.(short)
      short_reductions = reductions(fn -> assert {:ok, _} = operation.(short) end)
      long_reductions = reductions(fn -> assert {:ok, _} = operation.(long) end)
      ratio = long_reductions / short_reductions
      assert ratio > 1.70 and ratio < 2.30
    end
  end

  defp assert_mask_disposition(mask, mode, inverse) do
    case inverse do
      %{^mask => byte} ->
        assert ECMA44.decode_masks([mask], mode) == {:ok, <<byte>>}
        assert ECMA44.decode_packed(<<mask::12>>, mode) == {:ok, <<byte>>}
        assert ECMA44.decode_packed_lsb(pack_lsb([mask]), mode) == {:ok, <<byte>>}

        for endian <- [:big, :little] do
          assert ECMA44.decode_words(word(mask, endian), mode, endian) == {:ok, <<byte>>}
        end

      _ ->
        assert ECMA44.decode_masks([mask], mode) ==
                 {:error, :invalid_sequence, 0, mask}

        assert ECMA44.decode_packed(<<mask::12>>, mode) ==
                 {:error, :invalid_sequence, 0, <<mask::12>>}

        assert ECMA44.decode_packed_lsb(pack_lsb([mask]), mode) ==
                 {:error, :invalid_sequence, 0, mask}

        for endian <- [:big, :little] do
          raw = word(mask, endian)

          assert ECMA44.decode_words(raw, mode, endian) ==
                   {:error, :invalid_sequence, 0, raw}
        end
    end
  end

  defp pack_msb(masks), do: Enum.reduce(masks, <<>>, &<<&2::bitstring, &1::12>>)

  defp pack_lsb(masks) do
    data =
      masks
      |> Enum.chunk_every(2)
      |> Enum.map(fn
        [first, second] -> <<first ||| second <<< 12::24-little>>
        [last] -> <<last::16-little>>
      end)
      |> IO.iodata_to_binary()

    %LSB{data: data, bit_size: length(masks) * 12, unit_bits: 12}
  end

  defp words(masks, endian), do: masks |> Enum.map(&word(&1, endian)) |> IO.iodata_to_binary()
  defp word(mask, :big), do: <<mask::16-big>>
  defp word(mask, :little), do: <<mask::16-little>>

  defp popcount(value), do: popcount(value, 0)
  defp popcount(0, count), do: count
  defp popcount(value, count), do: popcount(value &&& value - 1, count + 1)

  defp reductions(function) do
    for _ <- 1..3 do
      Task.async(fn ->
        # A fresh heap keeps a preceding test's garbage collection from being
        # charged to only one side of the 2x-input comparison.
        :erlang.garbage_collect()
        {:reductions, before_count} = Process.info(self(), :reductions)
        function.()
        {:reductions, after_count} = Process.info(self(), :reductions)
        after_count - before_count
      end)
      |> Task.await(30_000)
    end
    |> Enum.sort()
    |> Enum.at(1)
  end

  defp source_table_masks do
    "priv/sources/ecma-44/ecma44_table.csv"
    |> File.read!()
    |> String.split("\n", trim: true)
    |> tl()
    |> Enum.flat_map(fn row ->
      [_high_nibble | masks] = String.split(row, ",")
      Enum.map(masks, &String.to_integer(&1, 16))
    end)
  end

  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end

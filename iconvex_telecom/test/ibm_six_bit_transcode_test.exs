defmodule Iconvex.Telecom.IBMSixBitTranscodeTest do
  use ExUnit.Case, async: false

  alias Iconvex.Packed.LSB
  alias Iconvex.Telecom.{IBMBscSixBitTranscode, IBM2780SixBitTranscode, Packed}

  @common [
    0x0001,
    0x0041,
    0x0042,
    0x0043,
    0x0044,
    0x0045,
    0x0046,
    0x0047,
    0x0048,
    0x0049,
    0x0002,
    0x002E,
    nil,
    0x0007,
    0x001A,
    0x0017,
    0x0026,
    0x004A,
    0x004B,
    0x004C,
    0x004D,
    0x004E,
    0x004F,
    0x0050,
    0x0051,
    0x0052,
    0x0020,
    0x0024,
    0x002A,
    0x001F,
    0x0004,
    0x0010,
    0x002D,
    0x002F,
    0x0053,
    0x0054,
    0x0055,
    0x0056,
    0x0057,
    0x0058,
    0x0059,
    0x005A,
    0x001B,
    0x0027,
    0x0025,
    0x0005,
    0x0003,
    0x0009,
    0x0030,
    0x0031,
    0x0032,
    0x0033,
    0x0034,
    0x0035,
    0x0036,
    0x0037,
    0x0038,
    0x0039,
    0x0016,
    0x0023,
    0x0040,
    0x0015,
    0x0019,
    0x007F
  ]

  @profiles [
    %{
      codec: IBM2780SixBitTranscode,
      canonical: "IBM-2780-SIX-BIT-TRANSCODE-GA27-3005-3",
      aliases: [
        "IBM-2780-SIX-BIT-TRANSCODE-1971",
        "IBM-2780-TRANSCODE-1971",
        "IBM-GA27-3005-3-TRANSCODE"
      ],
      replacement: 0x2311,
      csv: "ga27-3005-3.csv",
      source_url:
        "https://www.bitsavers.org/pdf/ibm/2780/" <>
          "GA27-3005-3-2780_Data_Terminal_Description_Aug71.pdf",
      source_sha256: "3e631b8851217a848da3e2ca4ebf673978dcc87ed238407e35399024e98a75a8",
      source_size: 5_845_274,
      source_page: 10,
      mapping_sha256: "cbb94188f9ac1a8b9a95dcff91d0744c84f77ad53377d62dd76eff4d6a476416",
      utf8_sha256: "c91492d13ffbde11b898979d852b9178b9ed311f821df97e361571969578d8cd"
    },
    %{
      codec: IBMBscSixBitTranscode,
      canonical: "IBM-BSC-SIX-BIT-TRANSCODE-GA27-3004-2",
      aliases: [
        "IBM-BSC-SIX-BIT-TRANSCODE-1970",
        "IBM-GA27-3004-2-TRANSCODE"
      ],
      replacement: 0x003C,
      csv: "ga27-3004-2.csv",
      source_url:
        "https://www.bitsavers.org/pdf/ibm/datacomm/" <>
          "GA27-3004-2_General_Information_Binary_Synchronous_Communications_Oct70.pdf",
      source_sha256: "2589c426624f8e57158fe8256fbeecc17d779d2b4ca4cd73caddd28c4dc2f67f",
      source_size: 2_485_327,
      source_page: 11,
      mapping_sha256: "5dccf290006224a0de51dddda9ec227183f1527610f61cf2f70b606ccea7c31e",
      utf8_sha256: "d6c174218479da991d9f7a8b0950ffb646f92b5ba1b95cec55a4034ece85121f"
    }
  ]

  @source_dir Path.expand("../priv/sources/ibm-six-bit-transcode", __DIR__)
  @metadata Path.join(@source_dir, "SOURCE_METADATA.md")
  @metadata_sha256 "3b9fe66217399b16b338ffa41209d2b77237886cde306e10e63f82374506908f"
  @full_units 0..63 |> Enum.to_list() |> :erlang.list_to_binary()
  @full_msb "00108310518720928b30d38f41149351559761969b71d79f8218a39259a7a29aabb2dbafc31cb3d35db7e39ebbf3dfbf"
  @full_lsb "40200c44611c48a22c4ce33c50244d54655d58a66d5ce77d60288e64699e68aaae6cebbe702ccf746ddf78aeef7cefff"

  test "RED: normalized source evidence pins both primary manuals without redistributing PDFs" do
    assert File.regular?(@metadata)
    metadata = File.read!(@metadata)
    assert sha256(metadata) == @metadata_sha256

    for profile <- @profiles do
      csv = Path.join(@source_dir, profile.csv)
      assert File.regular?(csv)
      assert sha256(File.read!(csv)) == profile.mapping_sha256
      assert csv_vector(csv) == vector(profile)

      assert metadata =~ profile.source_url
      assert metadata =~ profile.source_sha256
      assert metadata =~ Integer.to_string(profile.source_size)
      assert metadata =~ "physical PDF page #{profile.source_page}"
      assert metadata =~ profile.mapping_sha256

      assert profile.codec.source_url() == profile.source_url
      assert profile.codec.source_sha256() == profile.source_sha256
      assert profile.codec.source_size() == profile.source_size
      assert profile.codec.source_page() == profile.source_page
      assert profile.codec.mapping_sha256() == profile.mapping_sha256
      assert profile.codec.metadata_sha256() == @metadata_sha256
    end

    assert metadata =~ "low-order first (543210)"
    assert metadata =~ "parity is not part of the six-bit wire unit"
    assert metadata =~ "VRC is unavailable for Six-Bit Transcode"
    assert metadata =~ "raw PDFs are excluded"
    assert Path.wildcard(Path.join(@source_dir, "*.pdf")) == []

    parity_bits =
      for unit <- 0..63, into: <<>> do
        parity = if rem(unit |> Integer.digits(2) |> Enum.sum(), 2) == 0, do: 1, else: 0
        <<parity::1>>
      end

    assert Base.encode16(parity_bits, case: :lower) == "9669699669969669"
  end

  test "RED: independently pinned vectors exhaust all 64 assignments and full UTF-8 digests" do
    for profile <- @profiles do
      vector = vector(profile)
      text = List.to_string(vector)

      assert length(vector) == 64
      assert MapSet.size(MapSet.new(vector)) == 64

      assert profile.codec.table() ==
               vector |> Enum.with_index() |> Map.new(fn {cp, unit} -> {unit, cp} end)

      assert profile.codec.decode(@full_units) == {:ok, vector}
      assert profile.codec.encode(vector) == {:ok, @full_units}
      assert profile.codec.decode_to_utf8(@full_units) == {:ok, text}
      assert profile.codec.encode_from_utf8(text) == {:ok, @full_units}
      assert sha256(text) == profile.utf8_sha256

      for {codepoint, unit} <- Enum.with_index(vector) do
        assert profile.codec.decode(<<unit>>) == {:ok, [codepoint]}
        assert profile.codec.encode([codepoint]) == {:ok, <<unit>>}
      end
    end
  end

  test "RED: the manuals differ at exactly unit 0x0C and the identities stay distinct" do
    left = vector(Enum.at(@profiles, 0))
    right = vector(Enum.at(@profiles, 1))

    assert Enum.with_index(left)
           |> Enum.filter(fn {codepoint, unit} -> codepoint != Enum.at(right, unit) end) ==
             [{0x2311, 0x0C}]

    assert IBM2780SixBitTranscode.decode(<<0x0C>>) == {:ok, [0x2311]}
    assert IBMBscSixBitTranscode.decode(<<0x0C>>) == {:ok, [?<]}
    assert IBM2780SixBitTranscode.encode([?<]) == {:error, :unrepresentable_character, ?<}
    assert IBMBscSixBitTranscode.encode([0x2311]) == {:error, :unrepresentable_character, 0x2311}
  end

  test "RED: every one of 256 octets has an exact result and high bits are always invalid" do
    for profile <- @profiles, byte <- 0..255 do
      if byte < 64 do
        assert profile.codec.decode(<<byte>>) == {:ok, [Enum.at(vector(profile), byte)]}
      else
        assert profile.codec.decode(<<byte>>) == {:error, :invalid_sequence, 0, <<byte>>}

        assert profile.codec.decode(<<0x01, byte>>) ==
                 {:error, :invalid_sequence, 1, <<byte>>}
      end
    end

    for profile <- @profiles do
      assert profile.codec.decode_discard(<<0x01, 0x40, 0x02, 0xFF, 0x03>>) ==
               {:ok, [?A, ?B, ?C]}

      assert profile.codec.decode(<<0x3F, 0x40>>) ==
               {:error, :invalid_sequence, 1, <<0x40>>}
    end
  end

  @tag timeout: 120_000
  test "RED: the encoder accepts exactly its 64 mappings over every Unicode scalar" do
    for profile <- @profiles do
      inverse = vector(profile) |> Enum.with_index() |> Map.new()

      for range <- [0..0xD7FF, 0xE000..0x10FFFF], codepoint <- range do
        case inverse do
          %{^codepoint => unit} ->
            assert profile.codec.encode([codepoint]) == {:ok, <<unit>>}

          _ ->
            assert profile.codec.encode([codepoint]) ==
                     {:error, :unrepresentable_character, codepoint}
        end
      end
    end
  end

  test "RED: direct, discard, substitute, and malformed UTF-8 paths retain exact errors" do
    for profile <- @profiles do
      codec = profile.codec
      assert codec.decode(<<0x01, 0xFF, 0x02>>) == {:error, :invalid_sequence, 1, <<0xFF>>}
      assert codec.decode_discard(<<0x01, 0xFF, 0x02>>) == {:ok, ~c"AB"}
      assert codec.encode_discard([?A, 0x1F642, ?B]) == {:ok, <<0x01, 0x02>>}

      assert codec.encode_substitute([?A, 0x1F642, ?B], fn 0x1F642 -> [?C] end) ==
               {:ok, <<0x01, 0x03, 0x02>>}

      assert codec.encode_from_utf8(<<"A", 0xFF, "B">>) ==
               {:decode_error, :invalid_sequence, 1, <<0xFF, "B">>}

      assert codec.encode_from_utf8(<<"A", 0xE2, 0x82>>) ==
               {:decode_error, :incomplete_sequence, 1, <<0xE2, 0x82>>}

      assert Iconvex.convert(<<0x01, 0xFF, 0x02>>, profile.canonical, "UTF-8", invalid: :discard) ==
               {:ok, "AB"}

      assert Iconvex.convert("A🙂B", "UTF-8", profile.canonical, unicode_substitute: "%X") ==
               {:ok, <<0x01, 0x31, 0x06, 0x36, 0x34, 0x32, 0x02>>}
    end
  end

  test "RED: streaming agrees at every source and UTF-8 split and reports absolute offsets" do
    for profile <- @profiles do
      source = @full_units
      text = vector(profile) |> List.to_string()

      for split <- 0..byte_size(source) do
        {left, right} = :erlang.split_binary(source, split)
        assert stream_binary([left, right], profile.canonical, "UTF-8") == text
      end

      for split <- 0..byte_size(text) do
        {left, right} = :erlang.split_binary(text, split)
        assert stream_binary([left, right], "UTF-8", profile.canonical) == source
      end

      error =
        assert_raise Iconvex.Error, fn ->
          stream_binary([<<0x01>>, <<0x02, 0xFF>>, <<0x03>>], profile.canonical, "UTF-8")
        end

      assert error.kind == :invalid_sequence
      assert error.offset == 2
      assert error.sequence == <<0xFF>>
    end
  end

  test "RED: registry names are source-qualified and generic Transcode identities remain unclaimed" do
    for profile <- @profiles do
      codec = profile.codec
      assert codec.canonical_name() == profile.canonical
      assert codec.aliases() == profile.aliases
      assert codec.stateful?() == false
      assert Iconvex.canonical_name(profile.canonical) == {:ok, profile.canonical}

      for alias_name <- profile.aliases do
        assert Iconvex.canonical_name(alias_name) == {:ok, profile.canonical}
      end
    end

    for generic <- [
          "TRANSCODE",
          "SIX-BIT-TRANSCODE",
          "SIX-BIT-TRANSMISSION-CODE",
          "IBM-TRANSCODE",
          "IBM-SIX-BIT-TRANSCODE",
          "IBM-BSC-TRANSCODE"
        ] do
      assert Iconvex.canonical_name(generic) == :error
    end
  end

  test "RED: historical LSB and explicit MSB packed transports match every pinned vector" do
    full_msb = Base.decode16!(@full_msb, case: :mixed)
    full_lsb = Base.decode16!(@full_lsb, case: :mixed)

    for profile <- @profiles do
      text = vector(profile) |> List.to_string()
      packed_profile = Packed.profile(profile.canonical)
      assert packed_profile.codec == profile.codec
      assert packed_profile.unit_bits == 6
      assert packed_profile.standard_order == :lsb

      assert Packed.encode_from_utf8(text, profile.canonical) ==
               {:ok, %LSB{data: full_lsb, bit_size: 384, unit_bits: 6}}

      assert Packed.encode_from_utf8(text, profile.canonical, :msb) == {:ok, full_msb}

      assert Packed.decode_to_utf8(
               %LSB{data: full_lsb, bit_size: 384, unit_bits: 6},
               profile.canonical
             ) == {:ok, text}

      assert Packed.decode_to_utf8(full_msb, profile.canonical, :msb) == {:ok, text}

      assert Packed.encode_from_utf8("ABCD", profile.canonical) ==
               {:ok, %LSB{data: <<0x81, 0x30, 0x10>>, bit_size: 24, unit_bits: 6}}

      assert Packed.encode_from_utf8("ABCD", profile.canonical, :msb) ==
               {:ok, <<0x04, 0x20, 0xC4>>}

      for {sample, data, bits} <- [
            {"A", <<0x01>>, 6},
            {"AB", <<0x81, 0x00>>, 12},
            {"ABC", <<0x81, 0x30, 0x00>>, 18},
            {"ABCD", <<0x81, 0x30, 0x10>>, 24}
          ] do
        assert Packed.encode_from_utf8(sample, profile.canonical) ==
                 {:ok, %LSB{data: data, bit_size: bits, unit_bits: 6}}
      end

      special_text = <<0x0001::utf8, 0x0002::utf8, profile.replacement::utf8, 0x007F::utf8>>

      assert Packed.encode_from_utf8(special_text, profile.canonical) ==
               {:ok, %LSB{data: <<0x80, 0xC2, 0xFC>>, bit_size: 24, unit_bits: 6}}

      assert Packed.encode_from_utf8(special_text, profile.canonical, :msb) ==
               {:ok, <<0x00, 0xA3, 0x3F>>}
    end
  end

  test "RED: packed decoders reject every malformed length, padding, width, and transport kind" do
    for profile <- @profiles do
      assert Packed.decode_to_utf8(<<1::5>>, profile.canonical, :msb) ==
               {:error, :incomplete_unit, 0, <<1::5>>}

      assert Packed.decode_to_utf8(
               %LSB{data: <<0>>, bit_size: 5, unit_bits: 6},
               profile.canonical,
               :lsb
             ) == {:error, :incomplete_unit, 0, 5}

      assert Packed.decode_to_utf8(
               %LSB{data: <<0>>, bit_size: 9, unit_bits: 6},
               profile.canonical,
               :lsb
             ) == {:error, :invalid_bit_size}

      assert Packed.decode_to_utf8(
               %LSB{data: <<0xC0>>, bit_size: 6, unit_bits: 6},
               profile.canonical,
               :lsb
             ) == {:error, :nonzero_padding_bits}

      assert Packed.decode_to_utf8(
               %LSB{data: <<0x41>>, bit_size: 6, unit_bits: 6},
               profile.canonical,
               :lsb
             ) == {:error, :nonzero_padding_bits}

      assert Packed.decode_to_utf8(
               %LSB{data: <<0>>, bit_size: 5, unit_bits: 5},
               profile.canonical,
               :lsb
             ) == {:error, :unit_width_mismatch}

      assert Packed.decode_to_utf8(<<0>>, profile.canonical, :lsb) ==
               {:error, :invalid_packed_transport}
    end
  end

  test "RED: runtime and generated inventories expose both codecs and four explicit packed names" do
    codec_inventory = File.read!("SUPPORTED_CODEC_INVENTORY.csv")
    packed_inventory = File.read!("SUPPORTED_PACKED_CODEC_INVENTORY.csv")

    for profile <- @profiles do
      assert profile.codec in Iconvex.Telecom.codecs()
      assert codec_inventory =~ profile.canonical

      assert packed_inventory =~
               "#{profile.canonical},6,lsb,#{inspect(profile.codec)}," <>
                 "#{profile.canonical}-PACKED-MSB|#{profile.canonical}-PACKED-LSB"
    end
  end

  test "RED: package selectors include normalized mappings and metadata but no raw IBM manual" do
    package_files = Mix.Project.config() |> Keyword.fetch!(:package) |> Keyword.fetch!(:files)
    assert "priv" in package_files

    for relative <- ["ga27-3005-3.csv", "ga27-3004-2.csv", "SOURCE_METADATA.md"] do
      assert File.regular?(Path.join(@source_dir, relative))
    end

    refute Enum.any?(Path.wildcard(Path.expand("../priv/**/*", __DIR__)), fn path ->
             String.ends_with?(String.downcase(path), ".pdf")
           end)

    archive = Path.expand("../iconvex_telecom-0.1.0.tar", __DIR__)

    if File.regular?(archive) do
      {compressed_contents, 0} = System.cmd("tar", ["-xOf", archive, "contents.tar.gz"])
      {:ok, entries} = :erl_tar.table({:binary, compressed_contents}, [:compressed])
      names = Enum.map(entries, &to_string/1)

      for relative <- ["ga27-3005-3.csv", "ga27-3004-2.csv", "SOURCE_METADATA.md"] do
        assert "priv/sources/ibm-six-bit-transcode/#{relative}" in names
      end

      refute Enum.any?(names, &String.starts_with?(&1, "tmp/"))
      refute Enum.any?(names, &String.ends_with?(String.downcase(&1), ".pdf"))
    end
  end

  test "RED: native direct paths scale linearly within the deterministic 30x ceiling" do
    for profile <- @profiles do
      alphabet = @full_units
      small_source = repeat_to_size(alphabet, 32_768)
      large_source = repeat_to_size(alphabet, 65_536)
      {:ok, small_text} = profile.codec.decode_to_utf8(small_source)
      {:ok, large_text} = profile.codec.decode_to_utf8(large_source)

      native_decode_small = reductions(fn -> profile.codec.decode_to_utf8(small_source) end)
      native_decode_large = reductions(fn -> profile.codec.decode_to_utf8(large_source) end)
      native_encode_small = reductions(fn -> profile.codec.encode_from_utf8(small_text) end)
      native_encode_large = reductions(fn -> profile.codec.encode_from_utf8(large_text) end)

      reference_decode = reductions(fn -> reference_decode(profile, large_source) end)
      reference_encode = reductions(fn -> reference_encode(profile, large_text) end)

      assert_ratio(native_decode_large / native_decode_small, 1.60, 2.60)
      assert_ratio(native_encode_large / native_encode_small, 1.60, 2.60)
      assert native_decode_large / max(reference_decode, 1) <= 30.0
      assert native_encode_large / max(reference_encode, 1) <= 30.0
    end
  end

  defp vector(profile), do: List.replace_at(@common, 0x0C, profile.replacement)

  defp csv_vector(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> then(fn ["unit_hex,unicode_hex" | rows] -> rows end)
    |> Enum.with_index()
    |> Enum.map(fn {row, expected_unit} ->
      [unit_hex, unicode_hex] = String.split(row, ",", parts: 2)
      assert String.to_integer(unit_hex, 16) == expected_unit
      String.to_integer(unicode_hex, 16)
    end)
  end

  defp stream_binary(chunks, from, to) do
    {:ok, stream} = Iconvex.stream(chunks, from, to)
    stream |> Enum.to_list() |> IO.iodata_to_binary()
  end

  defp reference_decode(profile, source) do
    table = vector(profile) |> List.to_tuple()
    {:ok, source |> :binary.bin_to_list() |> Enum.map(&elem(table, &1)) |> List.to_string()}
  end

  defp reference_encode(profile, text) do
    inverse = vector(profile) |> Enum.with_index() |> Map.new()

    {:ok,
     text
     |> :unicode.characters_to_list(:utf8)
     |> Enum.map(&Map.fetch!(inverse, &1))
     |> :erlang.list_to_binary()}
  end

  defp repeat_to_size(alphabet, size) do
    copies = div(size + byte_size(alphabet) - 1, byte_size(alphabet))
    alphabet |> :binary.copy(copies) |> binary_part(0, size)
  end

  defp reductions(function) do
    :erlang.garbage_collect()
    {:reductions, before_count} = Process.info(self(), :reductions)
    assert {:ok, _output} = function.()
    {:reductions, after_count} = Process.info(self(), :reductions)
    after_count - before_count
  end

  defp assert_ratio(actual, minimum, maximum) do
    assert actual >= minimum and actual <= maximum,
           "expected reduction scaling #{actual} in #{minimum}..#{maximum}"
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

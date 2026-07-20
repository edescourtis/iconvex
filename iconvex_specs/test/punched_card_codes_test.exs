defmodule Iconvex.Specs.PunchedCardCodesTest do
  use ExUnit.Case, async: false
  @moduletag timeout: :infinity

  import Bitwise
  alias Iconvex.Packed.LSB

  @source_dir Path.expand("../priv/sources/punched-card-codes", __DIR__)
  @unicode_corpus Path.expand("fixtures/all-unicode-scalars.utf32be", __DIR__)
  @unicode_corpus_sha256 "d037f6200ae8845906b4372a8b3fcd39730e3a61c4af0e354823010e6f93be54"

  @profiles [
    %{
      id: "IBM-7040-H-REPORT",
      logical: Iconvex.Specs.IBM7040HReport,
      be: Iconvex.Specs.IBM7040HReport16BE,
      le: Iconvex.Specs.IBM7040HReport16LE,
      be_aliases: ["IBM-7040-H-REPORT-BE", "IBM-7044-H-REPORT-16BE"],
      le_aliases: ["IBM-7040-H-REPORT-LE", "IBM-7044-H-REPORT-16LE"]
    },
    %{
      id: "IBM-7040-H-PROGRAM",
      logical: Iconvex.Specs.IBM7040HProgram,
      be: Iconvex.Specs.IBM7040HProgram16BE,
      le: Iconvex.Specs.IBM7040HProgram16LE,
      be_aliases: ["IBM-7040-H-PROGRAM-BE", "IBM-7044-H-PROGRAM-16BE"],
      le_aliases: ["IBM-7040-H-PROGRAM-LE", "IBM-7044-H-PROGRAM-16LE"]
    },
    %{
      id: "IBM-1401-CARD",
      logical: Iconvex.Specs.IBM1401Card,
      be: Iconvex.Specs.IBM1401Card16BE,
      le: Iconvex.Specs.IBM1401Card16LE,
      be_aliases: ["IBM-1401-CARD-BE", "IBM1401-CARD-16BE"],
      le_aliases: ["IBM-1401-CARD-LE", "IBM1401-CARD-16LE"]
    },
    %{
      id: "CDC-167-BCD-HOLLERITH-1965",
      logical: Iconvex.Specs.CDC167BCDHollerith1965,
      be: Iconvex.Specs.CDC167BCDHollerith1965_16BE,
      le: Iconvex.Specs.CDC167BCDHollerith1965_16LE,
      be_aliases: ["CDC-167-BCD-HOLLERITH-16BE", "CDC-166-BCD-HOLLERITH-16BE"],
      le_aliases: ["CDC-167-BCD-HOLLERITH-16LE", "CDC-166-BCD-HOLLERITH-16LE"]
    },
    %{
      id: "CDC-6000-STANDARD-HOLLERITH-1970",
      logical: Iconvex.Specs.CDC6000StandardHollerith1970,
      be: Iconvex.Specs.CDC6000StandardHollerith1970_16BE,
      le: Iconvex.Specs.CDC6000StandardHollerith1970_16LE,
      be_aliases: ["CDC-6000-HOLLERITH-16BE", "CDC-6000-STANDARD-HOLLERITH-16BE"],
      le_aliases: ["CDC-6000-HOLLERITH-16LE", "CDC-6000-STANDARD-HOLLERITH-16LE"]
    },
    %{
      id: "BCD-CDC-IOWA",
      logical: Iconvex.Specs.BCDCDCIowa,
      be: Iconvex.Specs.BCDCDCIowa16BE,
      le: Iconvex.Specs.BCDCDCIowa16LE,
      be_aliases: ["BCD-CDC-IOWA-RECONSTRUCTED-16BE"],
      le_aliases: ["BCD-CDC-IOWA-RECONSTRUCTED-16LE"]
    }
  ]

  @canonical_rows @source_dir
                  |> Path.join("canonical_maps.csv")
                  |> File.read!()
                  |> String.split("\n", trim: true)
                  |> tl()
                  |> Enum.map(fn line ->
                    [profile, codepoint, _name, _punches, mask, _canonical, _decode, _source] =
                      line
                      |> String.trim_leading("\"")
                      |> String.trim_trailing("\"")
                      |> String.split("\",\"")

                    %{
                      profile: profile,
                      codepoint: codepoint |> String.trim_leading("U+") |> String.to_integer(16),
                      mask: mask |> String.trim_leading("0x") |> String.to_integer(16)
                    }
                  end)

  @decode_aliases @source_dir
                  |> Path.join("decode_aliases.csv")
                  |> File.read!()
                  |> String.split("\n", trim: true)
                  |> tl()
                  |> Enum.map(fn line ->
                    [profile, codepoint, _name, _punches, mask, _canonical, _decode, _source] =
                      line
                      |> String.trim_leading("\"")
                      |> String.trim_trailing("\"")
                      |> String.split("\",\"")

                    %{
                      profile: profile,
                      codepoint: codepoint |> String.trim_leading("U+") |> String.to_integer(16),
                      mask: mask |> String.trim_leading("0x") |> String.to_integer(16)
                    }
                  end)

  @digests %{
    "ibm-7040-7044-student-text-c22-6732-1.pdf" =>
      "46336c0ed59e04fdc5c7c9553e668f8fcbb000caa88a54dca72d943d0fed28bb",
    "ibm-1401-reference-a24-1403-5.pdf" =>
      "ab9d79ef05aa5c23e83f251c829607c2e9cb2dd89b368dd4565bcaff79af6ef9",
    "cdc-167-2-card-reader-60022000d.pdf" =>
      "f3dce73c357934c252d54563b2d9271bc46e990a1ddbeda5f9f0c24967175bbd",
    "cdc-punched-card-equipment-training-60239300.pdf" =>
      "e908fedc429cf9f65495d588092988c2a4d79d1159bdb290a63196f5566f467d",
    "cdc-6000-interactive-graphics-44616800-rev03.pdf" =>
      "275d0c2e8b3edacbd356f614d1e8ee0b63b9c159f0e1f68583e7169546b4810d",
    "uiowa-punched-card-codes.html" =>
      "824e61a9687f7fa0b9c9dd3c966ca02020bf8af1ab6671e9bd2e131f22f47b18",
    "unicode-l2-15-083r-group-mark.pdf" =>
      "421c2a627a43a7b26c252024e480b59e8c61f42e9ddab660bba8a2ca350f3eee",
    "canonical_maps.csv" => "541347c32f7610d3830b9259a68891b6ae2a410b1251f039f37930b83c3476c7",
    "decode_aliases.csv" => "da98e499e2b860bea2f35b7fbd66e14db1142047a7ac9ffe5b84174875b65323"
  }

  test "RED: primary manuals and correction evidence are digest-pinned" do
    for {filename, expected} <- @digests do
      assert @source_dir |> Path.join(filename) |> File.read!() |> sha256() == expected
    end
  end

  test "RED: published codecs expose durable provenance, not checkout-only paths" do
    for profile <- @profiles do
      refute function_exported?(profile.logical, :source_path, 0)
      refute function_exported?(profile.logical, :unicode_binding_source_path, 0)
      assert String.starts_with?(profile.logical.source_url(), "https://")
      assert profile.logical.source_sha256() =~ ~r/\A[0-9a-f]{64}\z/
      assert profile.logical.source_pages() != []

      for codec <- [profile.be, profile.le] do
        refute function_exported?(codec, :source_path, 0)
        assert codec.source_url() == profile.logical.source_url()
        assert codec.source_sha256() == profile.logical.source_sha256()
      end
    end
  end

  test "RED: runtime exposes only the source-qualified Iowa reconstruction" do
    iowa = profile("BCD-CDC-IOWA")

    assert iowa.logical.aliases() == ["BCD-CDC-IOWA-RECONSTRUCTED"]
    assert iowa.logical.canonical_count() == 64
    assert iowa.logical.decode_alias_count() == 0
    assert iowa.logical.source_url() == "https://homepage.cs.uiowa.edu/~jones/cards/codes.html"

    assert iowa.be in Iconvex.Specs.additional_codecs()
    assert iowa.le in Iconvex.Specs.additional_codecs()
    assert Iconvex.Specs.Packed.profile("BCD-CDC-IOWA-RECONSTRUCTED").codec == iowa.logical

    for ambiguous <- ["BCD-CDC", "CDC punched-card BCD", "CDC-PUNCHED-CARD-BCD"] do
      assert Iconvex.canonical_name(ambiguous) == :error
      assert Iconvex.Specs.Packed.profile(ambiguous) == nil
    end
  end

  test "RED: the pinned Iowa diagram independently reconstructs every CDC mask" do
    extracted = iowa_html_mapping()
    normalized = rows("BCD-CDC-IOWA") |> Map.new(&{&1.codepoint, &1.mask})

    assert map_size(extracted) == 64
    assert extracted[?<] == 0xA02
    assert extracted == normalized
  end

  test "RED: release packages normalized punched-card evidence but not copyrighted artifacts" do
    package_files = Mix.Project.config() |> Keyword.fetch!(:package) |> Keyword.fetch!(:files)

    assert "priv/sources/punched-card-codes/*.csv" in package_files
    assert "priv/sources/punched-card-codes/PROFILE_DISPOSITION.md" in package_files
    assert "priv/sources/punched-card-codes/SOURCE_METADATA.md" in package_files

    assert "priv/sources/punched-card-codes/hollerith_consensus_iowa_824e61a9_blocker.md" in package_files

    refute "priv/sources/punched-card-codes/*" in package_files

    for artifact <- [
          "priv/sources/punched-card-codes/*.pdf",
          "priv/sources/punched-card-codes/*.html"
        ] do
      refute artifact in package_files
    end
  end

  test "RED: reviewed extraction has exact profile counts and one-to-one canonical rows" do
    expected = %{
      "IBM-7040-H-REPORT" => 64,
      "IBM-7040-H-PROGRAM" => 64,
      "IBM-1401-CARD" => 63,
      "CDC-167-BCD-HOLLERITH-1965" => 63,
      "CDC-6000-STANDARD-HOLLERITH-1970" => 63,
      "BCD-CDC-IOWA" => 64
    }

    assert @canonical_rows |> Enum.frequencies_by(& &1.profile) == expected

    for {profile, count} <- expected do
      profile_rows = rows(profile)
      assert profile_rows |> Enum.map(& &1.codepoint) |> Enum.uniq() |> length() == count
      assert profile_rows |> Enum.map(& &1.mask) |> Enum.uniq() |> length() == count
    end

    assert @decode_aliases == [
             %{profile: "CDC-6000-STANDARD-HOLLERITH-1970", codepoint: 0x2228, mask: 0x482},
             %{profile: "CDC-6000-STANDARD-HOLLERITH-1970", codepoint: ?<, mask: 0x882}
           ]
  end

  test "RED: every primary canonical mapping is exact in packed and word transports" do
    for profile <- @profiles,
        %{codepoint: codepoint, mask: mask} <- rows(profile.id) do
      assert profile.logical.encode_packed([codepoint]) == {:ok, <<mask::12>>}
      assert profile.logical.decode_packed(<<mask::12>>) == {:ok, [codepoint]}
      assert profile.be.encode([codepoint]) == {:ok, <<mask::16-big>>}
      assert profile.le.encode([codepoint]) == {:ok, <<mask::16-little>>}
      assert profile.be.decode(<<mask::16-big>>) == {:ok, [codepoint]}
      assert profile.le.decode(<<mask::16-little>>) == {:ok, [codepoint]}
    end
  end

  test "RED: the complete Unicode scalar corpus exposes no accidental encoder keys" do
    corpus = File.read!(@unicode_corpus)
    assert sha256(corpus) == @unicode_corpus_sha256
    codepoints = for <<codepoint::unsigned-big-32 <- corpus>>, do: codepoint
    assert length(codepoints) == 1_112_064

    for profile <- @profiles do
      expected = profile.id |> rows() |> Enum.map(& &1.codepoint) |> Enum.sort()

      assert {:ok, packed} = profile.logical.encode_packed_discard(codepoints)
      assert profile.logical.decode_packed(packed) == {:ok, expected}
      assert profile.logical.encode_packed(expected) == {:ok, packed}

      for codec <- [profile.be, profile.le] do
        assert {:ok, words} = codec.encode_discard(codepoints)
        assert codec.decode(words) == {:ok, expected}
        assert codec.encode(expected) == {:ok, words}
      end
    end
  end

  test "RED: all 4096 masks have exactly the documented strict disposition" do
    for profile <- @profiles do
      accepted = accepted_by_mask(profile.id)

      for mask <- 0..0xFFF do
        case accepted do
          %{^mask => codepoint} ->
            assert profile.logical.decode_packed(<<mask::12>>) == {:ok, [codepoint]}
            assert profile.be.decode(<<mask::16-big>>) == {:ok, [codepoint]}
            assert profile.le.decode(<<mask::16-little>>) == {:ok, [codepoint]}

          _ ->
            assert profile.logical.decode_packed(<<mask::12>>) ==
                     {:error, :invalid_sequence, 0, <<mask::12>>}

            assert profile.be.decode(<<mask::16-big>>) ==
                     {:error, :invalid_sequence, 0, <<mask::16-big>>}

            assert profile.le.decode(<<mask::16-little>>) ==
                     {:error, :invalid_sequence, 0, <<mask::16-little>>}
        end
      end
    end
  end

  test "RED: CDC 1970 aliases decode but canonical inverse never emits them" do
    profile = profile("CDC-6000-STANDARD-HOLLERITH-1970")

    assert profile.logical.decode_packed(<<0x482::12>>) == {:ok, [0x2228]}
    assert profile.logical.decode_packed(<<0x882::12>>) == {:ok, [?<]}
    assert profile.logical.encode_packed([0x2228, ?<]) == {:ok, <<0x600::12, 0xA00::12>>}
    assert profile.be.decode(<<0x482::16-big, 0x882::16-big>>) == {:ok, [0x2228, ?<]}
    assert profile.le.decode(<<0x482::16-little, 0x882::16-little>>) == {:ok, [0x2228, ?<]}
  end

  test "RED: invalid and incomplete offsets preserve full unit framing" do
    for profile <- @profiles do
      accepted = accepted_by_mask(profile.id)
      valid = mask_for(profile.id, ?A)
      invalid = Enum.find(0..0xFFF, &(not Map.has_key?(accepted, &1)))

      assert profile.logical.decode_packed(<<valid::12, invalid::12, valid::12>>) ==
               {:error, :invalid_sequence, 12, <<invalid::12>>}

      assert profile.logical.decode_packed(<<valid::12, 0b10101::5>>) ==
               {:error, :incomplete_sequence, 12, <<0b10101::5>>}

      assert profile.logical.decode_packed_discard(<<valid::12, invalid::12, valid::12>>) ==
               {:ok, [?A, ?A]}

      assert profile.logical.decode_packed_discard(<<valid::12, 0b10101::5>>) == {:ok, [?A]}

      for {codec, endian} <- [{profile.be, :big}, {profile.le, :little}] do
        assert codec.decode(words([valid, invalid, valid], endian)) ==
                 {:error, :invalid_sequence, 2, word(invalid, endian)}

        assert codec.decode(word(valid, endian) <> <<0x12>>) ==
                 {:error, :incomplete_sequence, 2, <<0x12>>}

        assert codec.decode(word(0x1000 ||| valid, endian)) ==
                 {:error, :invalid_sequence, 0, word(0x1000 ||| valid, endian)}

        assert codec.decode_discard(words([valid, invalid, valid], endian) <> <<0x12>>) ==
                 {:ok, [?A, ?A]}
      end
    end
  end

  test "RED: strict discard substitution and direct UTF-8 paths agree" do
    for profile <- @profiles, codec <- [profile.be, profile.le] do
      codepoints = rows(profile.id) |> Enum.map(& &1.codepoint)
      text = List.to_string(codepoints)

      assert {:ok, encoded} = codec.encode(codepoints)
      assert codec.decode(encoded) == {:ok, codepoints}
      assert codec.decode_to_utf8(encoded) == {:ok, text}
      assert codec.encode_from_utf8(text) == {:ok, encoded}

      assert codec.encode([?A, 0x1F600, ?B]) ==
               {:error, :unrepresentable_character, 0x1F600}

      assert codec.encode_discard([?A, 0x1F600, ?B]) == codec.encode(~c"AB")

      assert codec.encode_substitute([?A, 0x1F600, ?B], fn 0x1F600 -> [0x20] end) ==
               codec.encode(~c"A B")

      assert codec.encode_from_utf8(<<?A, 0xFF>>) ==
               {:decode_error, :invalid_sequence, 1, <<0xFF>>}

      assert Iconvex.convert("A😀B", "UTF-8", codec.canonical_name(), unicode_substitute: "%04X") ==
               codec.encode(~c"A1F600B")
    end
  end

  test "RED: 16BE and 16LE transports and aliases register without generic ambiguity" do
    for profile <- @profiles do
      for {codec, suffix, aliases} <- [
            {profile.be, "16BE", profile.be_aliases},
            {profile.le, "16LE", profile.le_aliases}
          ] do
        canonical = "#{profile.id}-#{suffix}"
        assert codec.canonical_name() == canonical
        assert codec.aliases() == aliases
        assert Iconvex.canonical_name(canonical) == {:ok, canonical}

        for alias_name <- aliases do
          assert Iconvex.canonical_name(alias_name) == {:ok, canonical}
        end
      end

      assert Iconvex.canonical_name(profile.id) == :error
    end
  end

  test "RED: packed mask errors identify the exact unit and value" do
    profile = profile("IBM-7040-H-REPORT")
    logical = profile.logical

    for packer <- [
          fn masks -> logical.pack_masks_msb(masks) end,
          fn masks -> logical.pack_masks_lsb(masks) end
        ] do
      assert packer.([0x1000, 0x123]) == {:error, :unit_out_of_range, 0, 0x1000}
      assert packer.([0x123, 0x1000]) == {:error, :unit_out_of_range, 1, 0x1000}
    end
  end

  test "RED: logical profiles are published in both non-octet inventories" do
    non_octet = Iconvex.Specs.non_octet_codecs()
    packed = Iconvex.Specs.packed_codecs()

    non_octet_inventory =
      Path.expand("../../../SUPPORTED_NON_OCTET_CODEC_INVENTORY.csv", @source_dir)

    packed_inventory = Path.expand("../../../SUPPORTED_PACKED_CODEC_INVENTORY.csv", @source_dir)

    assert non_octet_inventory
           |> File.stream!()
           |> Enum.take(1) == ["canonical,aliases,module,unit_bits,transports\n"]

    assert packed_inventory
           |> File.stream!()
           |> Enum.take(1) ==
             ["canonical,aliases,unit_bits,standard_order,module,packed_names\n"]

    non_octet_csv = File.read!(non_octet_inventory)
    packed_csv = File.read!(packed_inventory)

    for profile <- @profiles do
      assert profile.logical in non_octet

      alias_field = profile.logical.aliases() |> Enum.sort() |> Enum.join("|")
      assert String.contains?(non_octet_csv, "#{profile.id},#{alias_field},")
      assert String.contains?(packed_csv, "#{profile.id},#{alias_field},")

      assert Enum.any?(packed, fn metadata ->
               metadata.canonical == profile.id and metadata.codec == profile.logical and
                 metadata.unit_bits == 12
             end)
    end
  end

  test "RED: packed MSB and explicitly nonstandard LSB preserve exact bits" do
    profile = profile("IBM-7040-H-REPORT")

    assert Iconvex.Specs.Packed.wide_profiles()
           |> Enum.map(& &1.canonical)
           |> Enum.take(length(@profiles)) == Enum.map(@profiles, & &1.id)

    for wide <- @profiles do
      metadata = Iconvex.Specs.Packed.profile(wide.id)
      codepoints = rows(wide.id) |> Enum.map(& &1.codepoint)
      text = List.to_string(codepoints)

      assert metadata.codec == wide.logical
      assert metadata.unit_bits == 12
      assert metadata.standard_order == :msb
      assert metadata.nonstandard_orders == [:lsb]
      assert Iconvex.Specs.Packed.profile(wide.logical) == metadata

      for alias_name <- wide.logical.aliases() do
        assert Iconvex.Specs.Packed.profile(alias_name) == metadata
      end

      assert Iconvex.Specs.Packed.encode_from_utf8(text, wide.id, :standard) ==
               wide.logical.encode_packed(codepoints)

      assert {:ok, msb} = wide.logical.encode_packed(codepoints)
      assert Iconvex.Specs.Packed.decode_to_utf8(msb, wide.id, :standard) == {:ok, text}

      assert Iconvex.Specs.Packed.encode_from_utf8(text, wide.id, :lsb) ==
               wide.logical.encode_packed_lsb(codepoints)

      assert {:ok, lsb} = wide.logical.encode_packed_lsb(codepoints)
      assert Iconvex.Specs.Packed.decode_to_utf8(lsb, wide.id, :lsb) == {:ok, text}
    end

    assert profile.logical.pack_masks_msb([0x123, 0xABC]) == {:ok, <<0x12, 0x3A, 0xBC>>}

    assert profile.logical.pack_masks_lsb([0x123, 0xABC]) ==
             {:ok, %LSB{data: <<0x23, 0xC1, 0xAB>>, bit_size: 24, unit_bits: 12}}

    for profile <- @profiles do
      codepoints = rows(profile.id) |> Enum.map(& &1.codepoint)

      assert {:ok, msb} = profile.logical.encode_packed(codepoints)
      assert bit_size(msb) == length(codepoints) * 12
      assert profile.logical.decode_packed(msb) == {:ok, codepoints}

      assert {:ok, %LSB{unit_bits: 12} = lsb} =
               profile.logical.encode_packed_lsb(codepoints)

      assert lsb.bit_size == length(codepoints) * 12
      assert profile.logical.decode_packed_lsb(lsb) == {:ok, codepoints}
    end

    assert profile.logical.decode_packed_lsb(%LSB{
             data: <<0xFF>>,
             bit_size: 5,
             unit_bits: 12
           }) == {:error, :incomplete_unit, 0, 5}

    assert profile.logical.decode_packed_lsb(%LSB{
             data: <<0>>,
             bit_size: 8,
             unit_bits: 8
           }) == {:error, :unit_width_mismatch}

    assert profile.logical.decode_packed_lsb(%LSB{
             data: <<0x00, 0xF0>>,
             bit_size: 12,
             unit_bits: 12
           }) == {:error, :nonzero_padding_bits}
  end

  test "RED: LSB partial tails honor discard and preserve first-error precedence" do
    for profile <- @profiles do
      valid = mask_for(profile.id, ?A)
      invalid = Enum.find(0..0xFFF, &(not Map.has_key?(accepted_by_mask(profile.id), &1)))

      assert {:ok, %LSB{} = valid_lsb} = profile.logical.pack_masks_lsb([valid])
      <<low, high>> = valid_lsb.data

      valid_with_tail = %{
        valid_lsb
        | data: <<low, high ||| 0xA0, 0x01>>,
          bit_size: 17
      }

      assert profile.logical.decode_packed_lsb(valid_with_tail) ==
               {:error, :incomplete_unit, 12, 5}

      assert profile.logical.decode_packed_lsb_discard(valid_with_tail) == {:ok, [?A]}

      assert {:ok, %LSB{} = invalid_lsb} = profile.logical.pack_masks_lsb([invalid])
      invalid_with_tail = %{invalid_lsb | data: invalid_lsb.data <> <<0>>, bit_size: 17}

      assert profile.logical.decode_packed_lsb(invalid_with_tail) ==
               {:error, :invalid_sequence, 0, invalid}

      assert profile.logical.decode_packed_lsb_discard(invalid_with_tail) == {:ok, []}

      assert {:ok, %LSB{} = two_units} = profile.logical.pack_masks_lsb([valid, invalid])
      two_units_with_tail = %{two_units | data: two_units.data <> <<0>>, bit_size: 29}

      assert profile.logical.decode_packed_lsb(two_units_with_tail) ==
               {:error, :invalid_sequence, 12, invalid}

      assert profile.logical.decode_packed_lsb_discard(two_units_with_tail) == {:ok, [?A]}
    end
  end

  test "all twelve-bit packed profiles preserve UTF-8 first-error ordering" do
    earlier_unrepresentable = <<0x1F600::utf8, 0xFF>>

    for profile <- Iconvex.Specs.Packed.wide_profiles(), order <- [:msb, :lsb] do
      assert profile.codec.encode_packed_from_utf8(earlier_unrepresentable, order) ==
               {:error, :unrepresentable_character, 0x1F600}

      assert Iconvex.Specs.Packed.encode_from_utf8(
               earlier_unrepresentable,
               profile.canonical,
               order
             ) == {:error, :unrepresentable_character, 0x1F600}
    end

    assert Iconvex.Specs.IBM1401Card.encode_packed_from_utf8(<<?A, 0xFF>>, :msb) ==
             {:decode_error, :invalid_sequence, 1, <<0xFF>>}
  end

  test "RED: packed transport shape and declared bit order never crash or cross-decode" do
    name = "IBM-7040-H-REPORT"
    {:ok, msb} = Iconvex.Specs.Packed.encode_from_utf8("A", name, :msb)
    {:ok, %LSB{} = lsb} = Iconvex.Specs.Packed.encode_from_utf8("A", name, :lsb)

    assert Iconvex.Specs.Packed.decode_to_utf8(lsb, name, :msb) ==
             {:error, :invalid_packed_transport}

    assert Iconvex.Specs.Packed.decode_to_utf8(msb, name, :lsb) ==
             {:error, :invalid_packed_transport}

    forged = %{lsb | bit_order: :msb}

    assert Iconvex.Specs.Packed.decode_to_utf8(forged, name, :lsb) ==
             {:error, :bit_order_mismatch}
  end

  test "RED: every generated packed name resolves and selects its declared order" do
    inventory = Path.expand("../../../SUPPORTED_PACKED_CODEC_INVENTORY.csv", @source_dir)

    inventory
    |> File.stream!()
    |> Stream.drop(1)
    |> Enum.each(fn line ->
      [canonical, _aliases, _bits, _standard, _module, packed_names] =
        line |> String.trim() |> String.split(",")

      [msb_name, lsb_name] = String.split(packed_names, "|")
      metadata = Iconvex.Specs.Packed.profile(msb_name)
      assert metadata.canonical == canonical
      assert Iconvex.Specs.Packed.profile(lsb_name) == metadata
      sample = packed_sample(metadata)

      assert {:ok, msb} = Iconvex.Specs.Packed.encode_from_utf8(sample, msb_name)
      assert is_bitstring(msb)
      assert Iconvex.Specs.Packed.decode_to_utf8(msb, msb_name) == {:ok, sample}

      assert {:ok, %LSB{bit_order: :lsb} = lsb} =
               Iconvex.Specs.Packed.encode_from_utf8(sample, lsb_name)

      assert Iconvex.Specs.Packed.decode_to_utf8(lsb, lsb_name) == {:ok, sample}

      assert Iconvex.Specs.Packed.encode_from_utf8(sample, msb_name, :lsb) ==
               {:error, :bit_order_mismatch}
    end)
  end

  test "RED: allocation and stream chunk boundaries remain exact" do
    profile = profile("IBM-7040-H-REPORT")

    for length <- [4_095, 4_096, 4_097] do
      codepoints = List.duplicate(?A, length)
      text = :binary.copy("A", length)

      assert {:ok, words} = profile.be.encode(codepoints)
      assert byte_size(words) == length * 2
      assert profile.be.decode(words) == {:ok, codepoints}
      assert profile.be.decode_to_utf8(words) == {:ok, text}

      assert {:ok, packed} = profile.logical.encode_packed(codepoints)
      assert bit_size(packed) == length * 12
      assert profile.logical.decode_packed(packed) == {:ok, codepoints}
    end

    {:ok, encoded} = profile.be.encode(~c"ABCD")
    chunks = for <<byte <- encoded>>, do: <<byte>>
    assert {:ok, stream} = Iconvex.stream(chunks, profile.be.canonical_name(), "UTF-8")
    assert stream |> Enum.to_list() |> IO.iodata_to_binary() == "ABCD"

    invalid_then_valid = <<0x10, 0x09, 0x00, 0x01>>

    assert Iconvex.convert(
             invalid_then_valid,
             profile.be.canonical_name(),
             "UTF-8",
             invalid: :discard
           ) == {:ok, "9"}

    byte_chunks = for <<byte <- invalid_then_valid>>, do: <<byte>>

    assert {:ok, discard_stream} =
             Iconvex.stream(
               byte_chunks,
               profile.be.canonical_name(),
               "UTF-8",
               invalid: :discard
             )

    assert discard_stream |> Enum.to_list() |> IO.iodata_to_binary() == "9"
  end

  test "RED: one-shot and every stream split recover whole 16-bit words" do
    profile = profile("IBM-7040-H-REPORT")
    valid = mask_for(profile.id, ?9)

    for {codec, endian} <- [{profile.be, :big}, {profile.le, :little}] do
      invalid_word = word(0x1000 ||| valid, endian)
      input = invalid_word <> word(valid, endian)

      substitute =
        invalid_word
        |> :binary.bin_to_list()
        |> Enum.map_join(fn byte ->
          "<#{byte |> Integer.to_string(16) |> String.pad_leading(2, "0")}>"
        end)
        |> Kernel.<>("9")

      <<first_invalid_byte, _::binary>> = invalid_word

      handler = fn event ->
        send(self(), {:invalid_word_event, event})
        :discard
      end

      assert Iconvex.convert(input, codec.canonical_name(), "UTF-8", on_invalid_byte: handler) ==
               {:ok, "9"}

      assert_receive {:invalid_word_event,
                      %Iconvex.InvalidByte{
                        encoding: encoding,
                        kind: :invalid_sequence,
                        offset: 0,
                        byte: ^first_invalid_byte,
                        sequence: ^invalid_word
                      }}

      assert encoding == codec.canonical_name()
      refute_receive {:invalid_word_event, _}

      assert {:ok, event_stream} =
               Iconvex.stream(
                 [binary_part(input, 0, 1), binary_part(input, 1, byte_size(input) - 1)],
                 codec.canonical_name(),
                 "UTF-8",
                 on_invalid_byte: handler
               )

      assert event_stream |> Enum.to_list() |> IO.iodata_to_binary() == "9"

      assert_receive {:invalid_word_event,
                      %Iconvex.InvalidByte{
                        encoding: ^encoding,
                        kind: :invalid_sequence,
                        offset: 0,
                        byte: ^first_invalid_byte,
                        sequence: ^invalid_word
                      }}

      refute_receive {:invalid_word_event, _}

      policies = [
        {[invalid: :discard], "9"},
        {[on_invalid_byte: fn _invalid -> :discard end], "9"},
        {[byte_substitute: "<%02x>"], substitute}
      ]

      for {options, expected} <- policies do
        assert Iconvex.convert(input, codec.canonical_name(), "UTF-8", options) ==
                 {:ok, expected}

        for split <- 0..byte_size(input) do
          chunks = [
            binary_part(input, 0, split),
            binary_part(input, split, byte_size(input) - split)
          ]

          assert {:ok, stream} = Iconvex.stream(chunks, codec.canonical_name(), "UTF-8", options)
          assert stream |> Enum.to_list() |> IO.iodata_to_binary() == expected
        end
      end
    end
  end

  test "RED: native loops scale linearly by process reductions" do
    profile = profile("IBM-7040-H-REPORT")
    short = List.duplicate(?A, 20_000)
    long = List.duplicate(?A, 40_000)

    assert {:ok, _} = profile.be.encode(short)
    short_reductions = reductions(fn -> assert {:ok, _} = profile.be.encode(short) end)
    long_reductions = reductions(fn -> assert {:ok, _} = profile.be.encode(long) end)
    ratio = long_reductions / short_reductions
    assert ratio > 1.75 and ratio < 2.25
  end

  defp profile(id), do: Enum.find(@profiles, &(&1.id == id))
  defp rows(id), do: Enum.filter(@canonical_rows, &(&1.profile == id))

  defp accepted_by_mask(id) do
    (rows(id) ++ Enum.filter(@decode_aliases, &(&1.profile == id)))
    |> Map.new(&{&1.mask, &1.codepoint})
  end

  defp mask_for(id, codepoint) do
    %{mask: mask} = Enum.find(rows(id), &(&1.codepoint == codepoint))
    mask
  end

  defp packed_sample(%{unit_bits: 12, codec: codec}) do
    case codec.encode_packed([?A]) do
      {:ok, _packed} -> "A"
      error -> flunk("#{inspect(codec)} has no punched-card A sample: #{inspect(error)}")
    end
  end

  defp packed_sample(%{unit_bits: width, canonical: canonical}) do
    Enum.find_value(0..((1 <<< width) - 1), fn unit ->
      case Iconvex.convert(<<unit>>, canonical, "UTF-8") do
        {:ok, <<_::utf8>> = text} -> text
        _ -> nil
      end
    end) || flunk("#{canonical} has no single-scalar packed sample")
  end

  defp iowa_html_mapping do
    html = File.read!(Path.join(@source_dir, "uiowa-punched-card-codes.html"))

    block =
      html
      |> String.split("<H3>Control Data Corporation</H3>", parts: 2)
      |> List.last()
      |> String.split("<PRE WIDTH=70>", parts: 2)
      |> List.last()
      |> String.split("</PRE>", parts: 2)
      |> List.first()

    lines = String.split(block, "\n")
    header = Enum.find(lines, &String.starts_with?(&1, "CDC  "))

    codepoints =
      header
      |> binary_part(4, byte_size(header) - 4)
      |> String.replace("<EM CLASS=U>&lt;</EM>", "≤")
      |> String.replace("<EM CLASS=U>&gt;</EM>", "≥")
      |> String.replace("<EM CLASS=U>=</EM>", "≡")
      |> String.replace("&#177;", "≠")
      |> String.replace("&lt;", "<")
      |> String.replace("&gt;", ">")
      |> String.replace("&#172;", "¬")
      |> String.replace("&#166;", "↓")
      |> String.replace("v", "∨")
      |> String.replace("|", "↑")
      |> String.replace("a", "→")
      |> String.replace("^", "∧")
      |> String.to_charlist()

    if length(codepoints) != 64, do: raise("Iowa CDC header no longer has 64 columns")

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
    |> Map.new(fn {codepoint, column} ->
      mask =
        Enum.reduce(cells, 0, fn {row, bit}, acc ->
          if :binary.at(row, column) == ?O, do: acc ||| bit, else: acc
        end)

      {codepoint, mask}
    end)
  end

  defp words(masks, endian), do: masks |> Enum.map(&word(&1, endian)) |> IO.iodata_to_binary()
  defp word(mask, :big), do: <<mask::16-big>>
  defp word(mask, :little), do: <<mask::16-little>>

  defp reductions(function) do
    {:reductions, before} = Process.info(self(), :reductions)
    function.()
    {:reductions, after_count} = Process.info(self(), :reductions)
    after_count - before
  end

  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end

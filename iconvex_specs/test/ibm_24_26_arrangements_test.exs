defmodule Iconvex.Specs.IBM2426ArrangementsTest do
  use ExUnit.Case, async: false

  @moduletag timeout: :infinity

  import Bitwise
  alias Iconvex.Packed.LSB

  @letters ~w(A B C D E F G H J K)
  @source_dir Path.expand("../priv/sources/ibm-24-26-arrangements", __DIR__)
  @manual Path.join(@source_dir, "A24-0520-3_24_26_Card_Punch_Reference_Manual_Oct1965.pdf")
  @table Path.join(@source_dir, "figure_23_arrangements.csv")
  @metadata Path.join(@source_dir, "SOURCE_METADATA.md")
  @unicode_corpus Path.expand("fixtures/all-unicode-scalars.utf32be", __DIR__)
  @manual_sha256 "8d1f8e0b937989fa720d434b636bc829899414b7f11396b436ccd68b2265c91b"
  @mapping_sha256 "edb7190244bbf1bca034453bc7de16ccc78d5a3d86c5f5957ec82a2f93d25733"
  @metadata_sha256 "eb261f34e7d19f2308608e14dc0597b4e4949252586b7a28cd5aaf962f78111c"
  @unicode_corpus_sha256 "d037f6200ae8845906b4372a8b3fcd39730e3a61c4af0e354823010e6f93be54"

  @columns [
    {1, "12", "12", 0x800},
    {2, "12-3-8", "12+3+8", 0x842},
    {3, "12-4-8", "12+4+8", 0x822},
    {4, "11", "11", 0x400},
    {5, "11-3-8", "11+3+8", 0x442},
    {6, "11-4-8", "11+4+8", 0x422},
    {7, "0-3-8", "0+3+8", 0x242},
    {8, "0-4-8", "0+4+8", 0x222},
    {9, "0-1", "0+1", 0x300},
    {10, "3-8", "3+8", 0x042},
    {11, "4-8", "4+8", 0x022}
  ]

  @graphics %{
    "A" => [?&, ?., 0x2311, ?-, ?$, ?*, ?,, ?%, ?/, ?#, ?@],
    "B" => [?/, ?., 0x2311, ?-, ?$, ?*, ?,, ?%, ?&, ?#, ?@],
    "C" => [?&, ?., 0x2311, ?-, ?$, ?*, ?,, ?%, ?0, ?#, ?@],
    "D" => [?-, ?., 0x2311, ?-, ?$, ?*, ?,, ?%, ?/, ?#, ?@],
    "E" => [?-, ?., ?<, ?/, ?., ?*, ?,, ?%, ?&, ?#, ?>],
    "F" => [?+, ?., ?), ?-, ?$, ?*, ?,, ?(, ?/, ?=, ?-],
    "G" => [?+, ?., 0x2311, ?-, ?$, ?*, ?,, ?%, ?/, ?+, ?-],
    "H" => [?+, ?., ?), ?-, ?$, ?*, ?,, ?(, ?/, ?=, 0x2032],
    "J" => [?+, ?., 0x2311, ?-, ?$, ?*, ?,, ?%, ?/, ?#, ?@],
    "K" => [?+, ?., ?), ?-, ?$, ?*, ?,, ?(, ?/, ?=, ?@]
  }

  @profiles (for letter <- @letters do
               logical = Module.concat(Iconvex.Specs, "IBM2426Arrangement#{letter}")
               be = Module.concat(Iconvex.Specs, "IBM2426Arrangement#{letter}16BE")
               le = Module.concat(Iconvex.Specs, "IBM2426Arrangement#{letter}16LE")
               canonical = "IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-#{letter}"

               aliases =
                 case letter do
                   "A" ->
                     [
                       "IBM-24-26-ARRANGEMENT-A",
                       "IBM 026 Commercial card code",
                       "IBM-026-COMMERCIAL-CARD-CODE",
                       "BCD-A"
                     ]

                   "H" ->
                     [
                       "IBM-24-26-ARRANGEMENT-H",
                       "IBM 026 FORTRAN card code",
                       "IBM-026-FORTRAN-CARD-CODE",
                       "BCD-H"
                     ]

                   _ ->
                     ["IBM-24-26-ARRANGEMENT-#{letter}"]
                 end

               %{
                 letter: letter,
                 canonical: canonical,
                 aliases: aliases,
                 logical: logical,
                 be: be,
                 le: le
               }
             end)

  test "RED: pins the primary IBM manual and exact Figure 23 extraction" do
    assert File.regular?(@manual)
    assert File.regular?(@table)
    assert File.regular?(@metadata)
    assert sha256(File.read!(@manual)) == @manual_sha256
    assert sha256(File.read!(@table)) == @mapping_sha256
    assert sha256(File.read!(@metadata)) == @metadata_sha256
    assert File.stat!(@manual).size == 6_161_673

    rows = source_rows()
    assert length(rows) == 110

    expected =
      for letter <- @letters,
          {{index, label, punches, mask}, codepoint} <-
            Enum.zip(@columns, Map.fetch!(@graphics, letter)) do
        canonical? = first_reverse_mask(letter, codepoint) == mask

        %{
          arrangement: letter,
          column_index: index,
          column_label: label,
          punch_rows: punches,
          mask: mask,
          codepoint: codepoint,
          canonical_encode: canonical?
        }
      end

    assert rows == expected

    metadata = File.read!(@metadata)
    assert metadata =~ "A24-0520-3"
    assert metadata =~ "Minor Revision, October 1965"
    assert metadata =~ "physical PDF page 28 / printed page 27 / Figure 23"
    assert metadata =~ "physical PDF page 37 / printed page 36 / Figure 28"
    assert metadata =~ @manual_sha256
    assert metadata =~ "U+2311 SQUARE LOZENGE"
    assert metadata =~ "U+2032 PRIME"
    assert metadata =~ "base-before-Figure-23, then left-to-right"
    assert metadata =~ "LGPL-2.1-or-later"
  end

  test "RED: all ten logical profiles expose exact mappings and deterministic inverses" do
    for profile <- @profiles do
      assert Code.ensure_loaded?(profile.logical)
      assert profile.logical.canonical_name() == profile.canonical
      assert profile.logical.aliases() == profile.aliases
      assert profile.logical.arrangement() == profile.letter
      assert profile.logical.unit_bits() == 12
      assert profile.logical.standard_packed_order() == :msb
      assert profile.logical.nonstandard_packed_orders() == [:lsb]
      assert profile.logical.source_sha256() == @manual_sha256
      assert profile.logical.source_pages() == [28, 37]
      assert profile.logical.printed_source_pages() == ["27", "36"]
      assert profile.logical.reverse_policy() == :base_then_figure_23_left_to_right

      canonical = canonical_map(profile.letter)
      accepted = accepted_map(profile.letter)
      assert profile.logical.canonical_count() == map_size(canonical)
      assert profile.logical.decode_alias_count() == map_size(accepted) - map_size(canonical)

      for {codepoint, mask} <- canonical do
        assert profile.logical.encode_packed([codepoint]) == {:ok, <<mask::12>>}
      end

      for {mask, codepoint} <- accepted do
        assert profile.logical.decode_packed(<<mask::12>>) == {:ok, [codepoint]}
      end
    end

    assert profile("C").logical.encode_packed(~c"0") == {:ok, <<0x200::12>>}
    assert profile("C").logical.decode_packed(<<0x300::12>>) == {:ok, ~c"0"}
    assert profile("D").logical.encode_packed(~c"-") == {:ok, <<0x800::12>>}
    assert profile("D").logical.decode_packed(<<0x400::12>>) == {:ok, ~c"-"}
    assert profile("E").logical.encode_packed(~c".") == {:ok, <<0x842::12>>}
    assert profile("E").logical.decode_packed(<<0x442::12>>) == {:ok, ~c"."}
    assert profile("F").logical.encode_packed(~c"-") == {:ok, <<0x400::12>>}
    assert profile("F").logical.decode_packed(<<0x022::12>>) == {:ok, ~c"-"}
    assert profile("G").logical.encode_packed(~c"+") == {:ok, <<0x800::12>>}
    assert profile("G").logical.decode_packed(<<0x042::12>>) == {:ok, ~c"+"}
    assert profile("H").logical.encode_packed([0x2032]) == {:ok, <<0x022::12>>}
  end

  test "RED: every one of 4096 masks per arrangement has an exact disposition in all transports" do
    for profile <- @profiles do
      accepted = accepted_map(profile.letter)

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

  test "RED: every Unicode scalar is classified in packed, LSB, 16BE, and 16LE paths" do
    corpus = File.read!(@unicode_corpus)
    assert sha256(corpus) == @unicode_corpus_sha256
    codepoints = for <<codepoint::unsigned-big-32 <- corpus>>, do: codepoint
    assert length(codepoints) == 1_112_064

    for profile <- @profiles do
      expected = canonical_map(profile.letter) |> Map.keys() |> Enum.sort()

      assert {:ok, packed} = profile.logical.encode_packed_discard(codepoints)
      assert profile.logical.decode_packed(packed) == {:ok, expected}

      assert {:ok, %LSB{} = lsb} = profile.logical.encode_packed_lsb_discard(codepoints)
      assert profile.logical.decode_packed_lsb(lsb) == {:ok, expected}

      for codec <- [profile.be, profile.le] do
        assert {:ok, words} = codec.encode_discard(codepoints)
        assert codec.decode(words) == {:ok, expected}
      end
    end
  end

  test "RED: packed orders preserve bits and reject malformed or incomplete units" do
    for profile <- @profiles do
      canonical = canonical_map(profile.letter)
      sample = canonical |> Map.keys() |> Enum.sort()
      masks = Enum.map(sample, &Map.fetch!(canonical, &1))

      assert {:ok, msb} = profile.logical.encode_packed(sample)
      assert msb == for(mask <- masks, into: <<>>, do: <<mask::12>>)
      assert profile.logical.decode_packed(msb) == {:ok, sample}

      assert {:ok, %LSB{bit_order: :lsb, unit_bits: 12} = lsb} =
               profile.logical.encode_packed_lsb(sample)

      assert lsb.bit_size == length(sample) * 12
      assert profile.logical.decode_packed_lsb(lsb) == {:ok, sample}

      accepted = accepted_map(profile.letter)
      invalid = Enum.find(0..0xFFF, &(not Map.has_key?(accepted, &1)))
      valid = Map.fetch!(canonical, ?A)

      assert profile.logical.decode_packed(<<valid::12, invalid::12, 0b10101::5>>) ==
               {:error, :invalid_sequence, 12, <<invalid::12>>}

      assert profile.logical.decode_packed(<<valid::12, 0b10101::5>>) ==
               {:error, :incomplete_sequence, 12, <<0b10101::5>>}

      assert profile.logical.decode_packed_discard(<<valid::12, invalid::12, 0b10101::5>>) ==
               {:ok, [?A]}

      assert profile.logical.decode_packed_lsb(%LSB{
               data: <<0xFF>>,
               bit_size: 5,
               unit_bits: 12
             }) == {:error, :incomplete_unit, 0, 5}

      assert profile.logical.decode_packed_lsb(%LSB{
               data: <<0x00, 0xF0>>,
               bit_size: 12,
               unit_bits: 12
             }) == {:error, :nonzero_padding_bits}
    end
  end

  test "RED: strict discard replacement and direct UTF-8 paths agree for all profiles" do
    for profile <- @profiles do
      canonical = canonical_map(profile.letter)
      replacement_mask = Map.fetch!(canonical, ?A)

      assert profile.logical.encode_packed([?A, 0x1F600]) ==
               {:error, :unrepresentable_character, 0x1F600}

      assert profile.logical.encode_packed_discard([?A, 0x1F600]) ==
               {:ok, <<replacement_mask::12>>}

      assert profile.logical.encode_packed_substitute([0x1F600], fn _ -> [?A] end) ==
               {:ok, <<replacement_mask::12>>}

      assert {:ok, lsb} =
               profile.logical.encode_packed_lsb_substitute([0x1F600], fn _ -> [?A] end)

      assert profile.logical.decode_packed_lsb(lsb) == {:ok, [?A]}

      for codec <- [profile.be, profile.le] do
        assert {:ok, encoded} = codec.encode(~c"A0Z")
        assert codec.decode(encoded) == {:ok, ~c"A0Z"}
        assert codec.decode_to_utf8(encoded) == {:ok, "A0Z"}
        assert codec.encode_from_utf8("A0Z") == {:ok, encoded}

        assert codec.encode([?A, 0x1F600]) ==
                 {:error, :unrepresentable_character, 0x1F600}

        assert codec.encode_discard([?A, 0x1F600]) == codec.encode(~c"A")
        assert codec.encode_substitute([0x1F600], fn _ -> [?A] end) == codec.encode(~c"A")

        assert codec.encode_from_utf8(<<?A, 0xFF>>) ==
                 {:decode_error, :invalid_sequence, 1, <<0xFF>>}
      end
    end
  end

  test "RED: invalid words recover atomically under every policy and stream split" do
    for profile <- @profiles, {codec, endian} <- [{profile.be, :big}, {profile.le, :little}] do
      valid = Map.fetch!(canonical_map(profile.letter), ?A)
      invalid_word = word(0x1000 ||| valid, endian)
      valid_word = word(valid, endian)
      input = invalid_word <> valid_word

      hex_replacement =
        invalid_word
        |> :binary.bin_to_list()
        |> Enum.map_join(fn byte ->
          "<#{byte |> Integer.to_string(16) |> String.pad_leading(2, "0")}>"
        end)
        |> Kernel.<>("A")

      policies = [
        {[invalid: :discard], "A"},
        {[on_invalid_byte: fn _ -> :discard end], "A"},
        {[byte_substitute: "<%02x>"], hex_replacement}
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

      assert codec.decode(valid_word <> <<0x12>>) ==
               {:error, :incomplete_sequence, 2, <<0x12>>}
    end
  end

  test "RED: exact transport aliases register while generic IBM names stay unclaimed" do
    for profile <- @profiles do
      assert profile.logical.transport_codecs() == [profile.be, profile.le]

      for {codec, suffix} <- [{profile.be, "16BE"}, {profile.le, "16LE"}] do
        canonical = "#{profile.canonical}-#{suffix}"

        aliases =
          profile.aliases
          |> Enum.reject(&String.contains?(&1, " "))
          |> Enum.map(&"#{&1}-#{suffix}")

        assert codec.canonical_name() == canonical
        assert codec.aliases() == aliases
        assert codec.logical_profile() == profile.logical
        assert Iconvex.canonical_name(canonical) == {:ok, canonical}

        for alias_name <- aliases do
          assert Iconvex.canonical_name(alias_name) == {:ok, canonical}
        end
      end

      assert Iconvex.canonical_name(profile.canonical) == :error
    end

    for generic <- ["IBM-24", "IBM-26", "IBM-026"] do
      assert Iconvex.canonical_name(generic) == :error
      assert Iconvex.Specs.Packed.profile(generic) == nil
    end

    for registration <- Iconvex.Specs.registrations(), alias_name <- registration.aliases do
      assert String.match?(alias_name, ~r/^[\x21-\x7e]+$/)
      refute String.contains?(alias_name, "/")
    end
  end

  test "RED: logical and byte profiles appear in generated inventories" do
    non_octet_csv = File.read!(Path.expand("../SUPPORTED_NON_OCTET_CODEC_INVENTORY.csv", __DIR__))
    packed_csv = File.read!(Path.expand("../SUPPORTED_PACKED_CODEC_INVENTORY.csv", __DIR__))
    byte_csv = File.read!(Path.expand("../SUPPORTED_CODEC_INVENTORY.csv", __DIR__))

    for profile <- @profiles do
      assert profile.logical in Iconvex.Specs.non_octet_codecs()
      assert Enum.any?(Iconvex.Specs.packed_codecs(), &(&1.codec == profile.logical))
      alias_field = profile.aliases |> Enum.sort() |> Enum.join("|")
      assert non_octet_csv =~ "#{profile.canonical},#{alias_field},"
      assert packed_csv =~ "#{profile.canonical},#{alias_field},"
      assert byte_csv =~ "#{profile.canonical}-16BE,"
      assert byte_csv =~ "#{profile.canonical}-16LE,"
    end
  end

  defp profile(letter), do: Enum.find(@profiles, &(&1.letter == letter))

  defp base_rows do
    [{?\s, 0x000}, {?0, 0x200}] ++
      for(number <- 1..9, do: {?0 + number, 1 <<< (9 - number)}) ++
      for(number <- 1..9, do: {?A + number - 1, 0x800 ||| 1 <<< (9 - number)}) ++
      for(number <- 1..9, do: {?J + number - 1, 0x400 ||| 1 <<< (9 - number)}) ++
      for(number <- 2..9, do: {?S + number - 2, 0x200 ||| 1 <<< (9 - number)})
  end

  defp special_rows(letter) do
    Enum.zip(@columns, Map.fetch!(@graphics, letter))
    |> Enum.map(fn {{_index, _label, _punches, mask}, codepoint} -> {codepoint, mask} end)
  end

  defp canonical_map(letter) do
    Enum.reduce(base_rows() ++ special_rows(letter), %{}, fn {codepoint, mask}, acc ->
      Map.put_new(acc, codepoint, mask)
    end)
  end

  defp accepted_map(letter),
    do: Map.new(base_rows() ++ special_rows(letter), fn {cp, mask} -> {mask, cp} end)

  defp first_reverse_mask(letter, codepoint) do
    canonical_map(letter) |> Map.fetch!(codepoint)
  end

  defp source_rows do
    @table
    |> File.stream!()
    |> Stream.drop(1)
    |> Enum.map(fn line ->
      [arrangement, index, label, punches, mask, codepoint, canonical, accepted] =
        line |> String.trim() |> String.split(",")

      assert accepted == "yes"

      %{
        arrangement: arrangement,
        column_index: String.to_integer(index),
        column_label: label,
        punch_rows: punches,
        mask: parse_hex(mask),
        codepoint: parse_hex(codepoint),
        canonical_encode: canonical == "yes"
      }
    end)
  end

  defp word(mask, :big), do: <<mask::16-big>>
  defp word(mask, :little), do: <<mask::16-little>>
  defp parse_hex("0x" <> hex), do: String.to_integer(hex, 16)
  defp parse_hex("U+" <> hex), do: String.to_integer(hex, 16)
  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end

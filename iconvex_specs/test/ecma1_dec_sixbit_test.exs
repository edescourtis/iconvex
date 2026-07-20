defmodule Iconvex.Specs.ECMA1DECSIXBITTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.{DECSIXBIT, ECMA1, Packed}

  @source_directory Path.expand("../priv/sources/ecma1-dec-sixbit", __DIR__)
  @ecma1_source_path Path.join(@source_directory, "ECMA-1_1st_edition_march_1963.pdf")
  @dec_source_path Path.join(@source_directory, "Sze_Introduction_to_DEC_System-10_1974.pdf")
  @ecma1_sha256 "3bef4151a3aac5d78b1c7d6d91946d58447cd8f3388ed274e768a37967ebeb09"
  @dec_sha256 "a0a9bfc284963056b6fd39d099e3eee76946b0404542e52bae050b798d79bce5"

  @ecma1_codepoints [
    0x20,
    0x09,
    0x0A,
    0x0B,
    0x0C,
    0x0D,
    0x0E,
    0x0F,
    ?(,
    ?),
    ?*,
    ?+,
    ?,,
    ?-,
    ?.,
    ?/,
    ?0,
    ?1,
    ?2,
    ?3,
    ?4,
    ?5,
    ?6,
    ?7,
    ?8,
    ?9,
    ?:,
    ?;,
    ?<,
    ?=,
    ?>,
    ??,
    0x00,
    ?A,
    ?B,
    ?C,
    ?D,
    ?E,
    ?F,
    ?G,
    ?H,
    ?I,
    ?J,
    ?K,
    ?L,
    ?M,
    ?N,
    ?O,
    ?P,
    ?Q,
    ?R,
    ?S,
    ?T,
    ?U,
    ?V,
    ?W,
    ?X,
    ?Y,
    ?Z,
    ?[,
    ?\\,
    ?],
    0x1B,
    0x7F
  ]

  test "RED: pins the official scanned ECMA-1 table and DEC SIXBIT derivation" do
    assert sha256(File.read!(@ecma1_source_path)) == @ecma1_sha256
    assert sha256(File.read!(@dec_source_path)) == @dec_sha256
    assert ECMA1.source_page() == 6
    assert DECSIXBIT.source_page() == 20
    assert ECMA1.unit_bits() == 6
    assert DECSIXBIT.unit_bits() == 6
    assert String.starts_with?(ECMA1.source_url(), "https://ecma-international.org/")
    assert String.starts_with?(DECSIXBIT.source_url(), "https://bitsavers.org/")
  end

  test "implements all 64 primary ECMA-1 assignments" do
    units = :binary.list_to_bin(Enum.to_list(0..63))
    assert ECMA1.decode(units) == {:ok, @ecma1_codepoints}

    for {codepoint, unit} <- Enum.with_index(@ecma1_codepoints) do
      assert ECMA1.encode([codepoint]) == {:ok, <<unit>>}
    end

    assert ECMA1.decode(<<64>>) == {:error, :invalid_sequence, 0, <<64>>}
    assert ECMA1.decode(<<0, 64>>) == {:error, :invalid_sequence, 1, <<64>>}
    assert ECMA1.encode([?a]) == {:error, :unrepresentable_character, ?a}
  end

  test "implements DEC SIXBIT's complete ASCII projection and lowercase folding" do
    units = :binary.list_to_bin(Enum.to_list(0..63))
    assert DECSIXBIT.decode(units) == {:ok, Enum.to_list(0x20..0x5F)}
    assert DECSIXBIT.encode(Enum.to_list(0x20..0x5F)) == {:ok, units}
    assert DECSIXBIT.encode(~c"abc") == {:ok, <<33, 34, 35>>}
    assert DECSIXBIT.decode(<<33, 34, 35>>) == {:ok, ~c"ABC"}
    assert DECSIXBIT.decode(<<64>>) == {:error, :invalid_sequence, 0, <<64>>}
    assert DECSIXBIT.decode(<<33, 64>>) == {:error, :invalid_sequence, 1, <<64>>}
    assert DECSIXBIT.encode([0x2603]) == {:error, :unrepresentable_character, 0x2603}
  end

  test "registers both external codecs and publishes explicit six-bit packed transports" do
    assert Iconvex.canonical_name("ECMA-1") == {:ok, "ECMA-1"}
    assert Iconvex.canonical_name("DEC-SIXBIT") == {:ok, "DEC-SIXBIT"}

    assert Enum.map(Packed.profiles(), & &1.canonical) == [
             "CDC-6-12-DISPLAY-CODE-63",
             "CDC-6-12-DISPLAY-CODE-64",
             "CDC-DISPLAY-CODE-63",
             "CDC-DISPLAY-CODE-64",
             "CDC-DISPLAY-CODE-ASCII-63",
             "CDC-DISPLAY-CODE-ASCII-64",
             "DEC-SPECIAL",
             "DEC-TECHNICAL",
             "SI-960",
             "SHORT-KOI",
             "greek7",
             "KERMIT-ELOT927-GREEK",
             "DEC-NRC-UNITED-KINGDOM",
             "DEC-NRC-DUTCH",
             "DEC-NRC-FINNISH",
             "DEC-NRC-FRENCH",
             "DEC-NRC-FRENCH-CANADIAN",
             "DEC-NRC-GERMAN",
             "DEC-NRC-ITALIAN",
             "DEC-NRC-NORWEGIAN-DANISH",
             "DEC-NRC-PORTUGUESE",
             "DEC-NRC-SPANISH",
             "DEC-NRC-SWEDISH",
             "DEC-NRC-SWISS",
             "DEC-SIXBIT",
             "ECMA-1",
             "TEX-LIVE-OML-CMMI10-TOUNICODE-2026",
             "TEX-LIVE-OMS-CMSY10-TOUNICODE-2026",
             "PDP-1-CONCISE-1960-INITIAL-LOWER",
             "PDP-1-CONCISE-1960-INITIAL-UPPER",
             "PDP-1-CONCISE-FIODEC-1963-INITIAL-LOWER",
             "PDP-1-CONCISE-FIODEC-1963-INITIAL-UPPER",
             "UNIVAC-I-EXPANDED-1959",
             "UNIVAC-I-EXPANDED-1959-LOSSLESS-VPUA",
             "UNIVAC-I-EXPANDED-1959-RAW-VPUA",
             "UNIVAC-I-EXPANDED-1959-ODD-PARITY-7BIT",
             "FIELDATA-UNIVAC-1100",
             "FIELDATA-UNIVAC-4009-INPUT",
             "FIELDATA-UNIVAC-4009-OUTPUT",
             "FIELDATA-UNIVAC-4009-LOSSLESS-VPUA",
             "FIELDATA-UNIVAC-4009-RAW-VPUA"
           ]

    assert Enum.map(Packed.profiles(), & &1.unit_bits) ==
             List.duplicate(6, 6) ++
               List.duplicate(7, 18) ++
               List.duplicate(6, 2) ++
               List.duplicate(7, 2) ++
               List.duplicate(6, 4) ++
               List.duplicate(6, 3) ++ [7] ++ List.duplicate(6, 5)

    assert Packed.profile(DECSIXBIT).canonical == "DEC-SIXBIT"
    assert Packed.profile("PDP-10-SIXBIT").codec == DECSIXBIT
    assert Packed.profile(ECMA1).canonical == "ECMA-1"

    assert {:ok, <<33::6, 34::6, 35::6>> = msb} =
             Packed.encode_from_utf8("ABC", "DEC-SIXBIT", :msb)

    assert Packed.decode_to_utf8(msb, "DEC-SIXBIT", :msb) == {:ok, "ABC"}

    assert {:ok, %Iconvex.Packed.LSB{bit_size: 18} = lsb} =
             Packed.encode_from_utf8("ABC", "DEC-SIXBIT", :lsb)

    assert Packed.decode_to_utf8(lsb, "DEC-SIXBIT", :lsb) == {:ok, "ABC"}

    assert {:ok, standard} = Packed.encode_from_utf8("ABC", "ECMA1")
    assert Packed.decode_to_utf8(standard, "ECMA1") == {:ok, "ABC"}
  end

  test "discard and direct UTF-8 paths stay strict and linear" do
    assert ECMA1.decode_discard(<<0, 64, 1>>) == {:ok, [0x20, 0x09]}
    assert ECMA1.encode_discard([?A, ?a, ?B]) == {:ok, <<33, 34>>}
    assert ECMA1.decode_to_utf8(<<33, 34, 35>>) == {:ok, "ABC"}
    assert ECMA1.encode_from_utf8("ABC") == {:ok, <<33, 34, 35>>}

    assert {:decode_error, :invalid_sequence, 1, <<0xFF>>} =
             ECMA1.encode_from_utf8(<<?A, 0xFF>>)

    assert DECSIXBIT.decode_discard(<<33, 255, 34>>) == {:ok, ~c"AB"}
    assert DECSIXBIT.encode_discard([?A, 0x2603, ?b]) == {:ok, <<33, 34>>}
    assert DECSIXBIT.decode_to_utf8(<<33, 34, 35>>) == {:ok, "ABC"}
    assert DECSIXBIT.encode_from_utf8("Abc") == {:ok, <<33, 34, 35>>}

    assert {:decode_error, :invalid_sequence, 1, <<0xFF>>} =
             DECSIXBIT.encode_from_utf8(<<?A, 0xFF>>)
  end

  test "every packed profile round-trips both orders and rejects malformed transports" do
    for profile <- Packed.profiles(), order <- [:msb, :lsb] do
      sample =
        case profile.canonical do
          "DEC-TECHNICAL" -> "αβχ"
          "greek7" -> "ΑΒΓ"
          "DEC-NRC-FRENCH" -> "àçé"
          "DEC-NRC-FRENCH-CANADIAN" -> "àçé"
          "DEC-NRC-GERMAN" -> "ÄÖÜ"
          "DEC-NRC-ITALIAN" -> "àòè"
          "DEC-NRC-NORWEGIAN-DANISH" -> "ÆØÅ"
          "DEC-NRC-SPANISH" -> "Ññç"
          "UNIVAC-I-EXPANDED-1959-RAW-VPUA" -> List.to_string([0xF4094, 0xF4095, 0xF4096])
          "FIELDATA-UNIVAC-4009-RAW-VPUA" -> List.to_string([0xF4006, 0xF4007, 0xF4008])
          _ -> "ABC"
        end

      assert {:ok, packed} = Packed.encode_from_utf8(sample, profile.canonical, order)
      assert Packed.decode_to_utf8(packed, profile.canonical, order) == {:ok, sample}
    end

    assert Packed.encode_from_utf8("A", "UNKNOWN") ==
             {:error, :unsupported_packed_encoding}

    assert Packed.decode_to_utf8(<<>>, "UNKNOWN") ==
             {:error, :unsupported_packed_encoding}

    assert Packed.decode_to_utf8(<<1::5>>, "ECMA-1", :msb) ==
             {:error, :incomplete_unit, 0, <<1::5>>}

    assert Packed.decode_to_utf8(
             %Iconvex.Packed.LSB{data: <<0>>, bit_size: 5, unit_bits: 5},
             "ECMA-1",
             :lsb
           ) == {:error, :unit_width_mismatch}

    assert Packed.encode_from_utf8("A", "ECMA-1", :sideways) ==
             {:error, :invalid_bit_order}

    assert Packed.decode_to_utf8(<<>>, "ECMA-1", :sideways) ==
             {:error, :invalid_bit_order}
  end

  test "generated packed inventory is exact runtime metadata" do
    csv_field = fn value ->
      if String.contains?(value, [",", "\"", "\n", "\r"]) do
        "\"" <> String.replace(value, "\"", "\"\"") <> "\""
      else
        value
      end
    end

    rows =
      Packed.all_profiles()
      |> Enum.map(fn profile ->
        aliases =
          if Code.ensure_loaded?(profile.codec) and function_exported?(profile.codec, :aliases, 0),
            do: profile.codec.aliases() |> Enum.sort() |> Enum.join("|"),
            else: ""

        [
          profile.canonical,
          aliases,
          profile.unit_bits,
          profile.standard_order,
          inspect(profile.codec),
          "#{profile.canonical}-PACKED-MSB|#{profile.canonical}-PACKED-LSB"
        ]
        |> Enum.map(&to_string/1)
        |> Enum.map_join(",", csv_field)
      end)

    expected =
      Enum.join(["canonical,aliases,unit_bits,standard_order,module,packed_names" | rows], "\n") <>
        "\n"

    assert File.read!("SUPPORTED_PACKED_CODEC_INVENTORY.csv") == expected
  end

  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end

defmodule Iconvex.Telecom.PackedCodecInventoryTest do
  use ExUnit.Case, async: false
  import Bitwise

  test "RED: every fixed non-octet-width telecom codec has packed transports" do
    profiles = Iconvex.Telecom.Packed.profiles()

    assert length(profiles) == 51
    assert Enum.map(profiles, & &1.canonical) == Enum.sort(Enum.map(profiles, & &1.canonical))
    assert Enum.frequencies_by(profiles, & &1.unit_bits) == %{5 => 5, 6 => 4, 7 => 42}

    all = MapSet.new(Iconvex.Telecom.codecs())
    packed = MapSet.new(profiles, & &1.codec)

    assert MapSet.difference(all, packed) ==
             MapSet.new([
               Iconvex.Telecom.Morse,
               Iconvex.Telecom.TBCDCodec,
               Iconvex.Telecom.SIMAlphaIdentifierCodec
             ])

    for spec <- Iconvex.Telecom.Codecs.specs() do
      assert Enum.any?(profiles, &(&1.codec == spec.module and &1.unit_bits == 7))
    end
  end

  test "all 51 profiles round-trip representative text in both bit orders" do
    for profile <- Iconvex.Telecom.Packed.profiles() do
      sample = representative(profile)
      assert {:ok, msb} = Iconvex.Telecom.Packed.encode_from_utf8(sample, profile.canonical, :msb)
      assert is_bitstring(msb)

      assert Iconvex.Telecom.Packed.decode_to_utf8(msb, profile.canonical, :msb) ==
               {:ok, sample}

      assert {:ok, %Iconvex.Packed.LSB{} = lsb} =
               Iconvex.Telecom.Packed.encode_from_utf8(sample, profile.canonical, :lsb)

      assert Iconvex.Telecom.Packed.decode_to_utf8(lsb, profile.canonical, :lsb) ==
               {:ok, sample}
    end
  end

  test "RED: all 102 packed names and every packed alias select their named order" do
    profiles = Iconvex.Telecom.Packed.profiles()

    canonical_packed_names =
      for profile <- profiles,
          order <- [:msb, :lsb] do
        packed_name(profile.canonical, order)
      end

    assert length(canonical_packed_names) == 102
    assert MapSet.size(MapSet.new(canonical_packed_names)) == 102

    for profile <- profiles,
        base_name <- [profile.canonical | profile.codec.aliases()],
        order <- [:msb, :lsb] do
      name = packed_name(base_name, order)
      opposite = opposite_order(order)
      sample = representative(profile)

      assert Iconvex.Telecom.Packed.profile(name) == profile

      assert {:ok, packed} =
               Iconvex.Telecom.Packed.encode_from_utf8(sample, name)

      assert Iconvex.Telecom.Packed.decode_to_utf8(packed, name) == {:ok, sample}

      assert Iconvex.Telecom.Packed.encode_from_utf8(sample, name, order) ==
               {:ok, packed}

      assert Iconvex.Telecom.Packed.decode_to_utf8(packed, name, order) ==
               {:ok, sample}

      assert Iconvex.Telecom.Packed.encode_from_utf8(sample, name, opposite) ==
               {:error, :bit_order_mismatch}

      assert Iconvex.Telecom.Packed.decode_to_utf8(packed, name, opposite) ==
               {:error, :bit_order_mismatch}
    end
  end

  test "RED: every LSB profile rejects a transport tagged with the wrong bit order" do
    for profile <- Iconvex.Telecom.Packed.profiles() do
      sample = representative(profile)

      assert {:ok, %Iconvex.Packed.LSB{} = packed} =
               Iconvex.Telecom.Packed.encode_from_utf8(sample, profile.canonical, :lsb)

      mistagged = %{packed | bit_order: :msb}

      assert Iconvex.Telecom.Packed.decode_to_utf8(mistagged, profile.canonical, :lsb) ==
               {:error, :bit_order_mismatch}
    end
  end

  test "RED: semantic packed decode failures use physical bit offsets and fragments" do
    for {encoding, width, valid_unit, invalid_unit} <- [
          {"ITA1", 5, 5, 7},
          {"ITA3", 7, 7, 0},
          {"ITA4", 6, 1, 0},
          {"CCIR476", 7, 15, 0}
        ] do
      units = <<valid_unit, valid_unit, invalid_unit>>
      expected_offset = 2 * width

      assert {:ok, msb} = Iconvex.Packed.pack(units, width)

      assert Iconvex.Telecom.Packed.decode_to_utf8(msb, encoding, :msb) ==
               {:error, :invalid_sequence, expected_offset, <<invalid_unit::size(width)>>}

      assert {:ok, %Iconvex.Packed.LSB{} = lsb} = Iconvex.Packed.pack_lsb(units, width)

      assert Iconvex.Telecom.Packed.decode_to_utf8(lsb, encoding, :lsb) ==
               {:error, :invalid_sequence, expected_offset, invalid_unit}
    end
  end

  test "standard order is explicit and GSM matches canonical TPDU vector" do
    assert {:ok, %Iconvex.Packed.LSB{} = packed} =
             Iconvex.Telecom.Packed.encode_from_utf8("hellohello", "GSM0338")

    assert packed.bit_size == 70
    assert Base.encode16(packed.data) == "E8329BFD4697D9EC37"
    assert Iconvex.Telecom.Packed.decode_to_utf8(packed, "GSM0338") == {:ok, "hellohello"}

    assert Iconvex.Telecom.Packed.profile("GSM-03.38-TURKISH").canonical ==
             "GSM0338-TURKISH"

    assert Iconvex.Telecom.Packed.profile("ITA2").standard_order == :lsb
    assert Iconvex.Telecom.Packed.profile("AIS6").standard_order == :msb
  end

  test "generated packed inventory is exact runtime metadata" do
    rows =
      Iconvex.Telecom.Packed.profiles()
      |> Enum.map(fn profile ->
        Enum.join(
          [
            profile.canonical,
            profile.unit_bits,
            profile.standard_order,
            inspect(profile.codec),
            "#{profile.canonical}-PACKED-MSB|#{profile.canonical}-PACKED-LSB"
          ],
          ","
        )
      end)

    expected =
      Enum.join(
        ["canonical,unit_bits,standard_order,module,packed_names" | rows],
        "\n"
      ) <> "\n"

    assert File.read!("SUPPORTED_PACKED_CODEC_INVENTORY.csv") == expected
  end

  defp representative(profile) do
    Enum.find_value(0..((1 <<< profile.unit_bits) - 1), fn unit ->
      with {:ok, codepoints} when codepoints != [] <- profile.codec.decode(<<unit>>),
           {:ok, _encoded} <- profile.codec.encode(codepoints) do
        List.to_string(codepoints)
      else
        _ -> nil
      end
    end) || flunk("no representable packed unit for #{profile.canonical}")
  end

  defp packed_name(base_name, order),
    do: "#{base_name}-PACKED-#{order |> Atom.to_string() |> String.upcase()}"

  defp opposite_order(:msb), do: :lsb
  defp opposite_order(:lsb), do: :msb
end

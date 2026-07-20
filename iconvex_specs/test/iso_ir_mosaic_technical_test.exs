defmodule Iconvex.Specs.ISOIRMosaicTechnicalTest do
  use ExUnit.Case, async: false

  @manifest Path.expand("../priv/iso_ir_mosaic_technical_manifest.etf", __DIR__)

  @specs [
    {"ISO-IR-71", ["ISOIR71", "ISO_71", "CCITT-MOSAIC-2"], 71, 94, 94},
    {"ISO-IR-129", ["ISOIR129", "ISO_129", "CCITT-T101-III-SUPPL"], 129, 65, 64},
    {"ISO-IR-137", ["ISOIR137", "ISO_137", "CCITT-T101-I-MOSAIC-1"], 137, 59, 59},
    {"ISO-IR-173", ["ISOIR173", "ISO_173", "CCITT-T101-III-MOSAIC"], 173, 92, 92},
    {"ISO-IR-181", ["ISOIR181", "ISO_181", "IEC-1289-TECHNICAL-1"], 181, 83, 82}
  ]

  @registration_hashes %{
    71 => "e6b6e5c08bd91ed12d1913325d050f1199827ac059d2b2933cc93afaff2da6ac",
    129 => "fe65b23482cace6a79ec2cc737021219f54b901e07565d193e69a44a14008dae",
    137 => "d7252c700eaa517b49912c2465a14a4f9ce4e5daba6f07f255778f61678f88a9",
    173 => "ea156b45c3e9aa67b397a4cbdc9f2a776c21806a621a4dae7df0f4e18947318c",
    181 => "64ff12a2897e0fd168f78cf96c634892893ae072f354f26fb988bfabfa08e1ad"
  }

  @iso_ir_71_values [
    0x1FB00,
    0x1FB01,
    0x1FB02,
    0x1FB03,
    0x1FB04,
    0x1FB05,
    0x1FB06,
    0x1FB07,
    0x1FB08,
    0x1FB09,
    0x1FB0A,
    0x1FB0B,
    0x1FB0C,
    0x1FB0D,
    0x1FB0E,
    0x1FB0F,
    0x1FB10,
    0x1FB11,
    0x1FB12,
    0x1FB13,
    0x258C,
    0x1FB14,
    0x1FB15,
    0x1FB16,
    0x1FB17,
    0x1FB18,
    0x1FB19,
    0x1FB1A,
    0x1FB1B,
    0x1FB1C,
    0x1FB1D,
    0x1FB3C,
    0x1FB3D,
    0x1FB3E,
    0x1FB3F,
    0x1FB40,
    0x25E3,
    0x1FB41,
    0x1FB42,
    0x1FB43,
    0x1FB44,
    0x1FB45,
    0x1FB46,
    0x1FB68,
    0x1FB69,
    0x1FB70,
    0x1FB95,
    0x1FB47,
    0x1FB48,
    0x1FB49,
    0x1FB4A,
    0x1FB4B,
    0x25E2,
    0x1FB4C,
    0x1FB4D,
    0x1FB4E,
    0x1FB4F,
    0x1FB50,
    0x1FB51,
    0x1FB6A,
    0x1FB6B,
    0x1FB75,
    0x2588,
    0x1FB1E,
    0x1FB1F,
    0x1FB20,
    0x1FB21,
    0x1FB22,
    0x1FB23,
    0x1FB24,
    0x1FB25,
    0x1FB26,
    0x1FB27,
    0x2590,
    0x1FB28,
    0x1FB29,
    0x1FB2A,
    0x1FB2B,
    0x1FB2C,
    0x1FB2D,
    0x1FB2E,
    0x1FB2F,
    0x1FB30,
    0x1FB31,
    0x1FB32,
    0x1FB33,
    0x1FB34,
    0x1FB35,
    0x1FB36,
    0x1FB37,
    0x1FB38,
    0x1FB39,
    0x1FB3A,
    0x1FB3B
  ]

  @iso_ir_181_values [
    0x00A0,
    0x2510,
    0x238D,
    0x238E,
    0x25C7,
    0x238F,
    0x2390,
    0x2391,
    0x2392,
    0x00A9,
    0x2264,
    0x226A,
    0x00AC,
    0x00AD,
    0x00AE,
    nil,
    0x00B0,
    0x00B1,
    0x00F7,
    0x221E,
    0x222B,
    0x2026,
    0x2260,
    0x2219,
    0x2248,
    0x2261,
    0x2265,
    0x226B,
    0x2122,
    0x2104,
    0x2014,
    0x2393,
    0x2030,
    0x2190,
    nil,
    0x0393,
    0x25B3,
    0x25C1,
    0x25BD,
    0x25B7,
    0x0398,
    0x2229,
    0x2394,
    0x039B,
    nil,
    nil,
    0x039E,
    nil,
    0x03A0,
    0x2192,
    nil,
    0x03A3,
    nil,
    0x03A5,
    0x03A6,
    0x00D7,
    0x03A8,
    0x03A9,
    0x25A1,
    0x2300,
    0x2220,
    0x223C,
    0x2248,
    0x224B,
    nil,
    0x03B1,
    0x03B2,
    0x03B3,
    0x03B4,
    0x220A,
    0x03B6,
    0x03B7,
    0x03B8,
    0x03B9,
    0x03F0,
    0x03BB,
    0x03BC,
    0x03BD,
    0x03BE,
    nil,
    0x03C0,
    0x03F1,
    nil,
    0x03C3,
    0x03C4,
    0x03C5,
    0x03C6,
    0x03C7,
    0x03C8,
    0x03C9,
    0x03D1,
    0x03D5,
    0x03B5,
    nil,
    nil,
    nil
  ]

  test "registers every mosaic and technical set with its public aliases" do
    for {canonical, aliases, _registration, _decode, _encode} <- @specs,
        name <- [canonical | aliases] do
      assert {:ok, %{canonical: ^canonical}} = Iconvex.Registry.resolve(name)
    end
  end

  test "pins every official registration and the normative cross-mapping sources" do
    manifest = manifest()

    assert Enum.map(manifest.encodings, &{&1.registration, &1.registration_sha256}) ==
             Enum.map(@specs, fn {_name, _aliases, registration, _decode, _encode} ->
               {registration, @registration_hashes[registration]}
             end)

    assert manifest.t101_sha256 ==
             "3ef283abe293cf2f8d531bccfa5716afb0969584527156ace3e164b25b768fbc"

    assert manifest.n2032_sha256 ==
             "ef4320cb50aff5b41a05211f89c433a08dc3966959fb7c4e732a81a61f9d9ac3"

    assert manifest.n5028_sha256 ==
             "e64a54b4b223b5e6a9d686a7a7ddd1fc98d0bc88585059be02078b082a760e61"

    assert manifest.teletext_g3_sha256 ==
             "7a22e3566484d5f3f2fc645107588e521c8eb755fbd7b302180608d68ae8a7c3"
  end

  test "publishes the exact mapping cardinalities and explicit PUA policy" do
    manifest = manifest()

    assert Enum.map(manifest.encodings, fn entry ->
             {entry.registration, entry.decode_mappings, entry.encode_mappings,
              entry.private_use_mappings}
           end) == [
             {71, 94, 94, 0},
             {129, 65, 64, 0},
             {137, 59, 59, 12},
             {173, 92, 92, 15},
             {181, 83, 82, 0}
           ]
  end

  test "exhausts every possible input byte against independent specification maps" do
    expected = expected_mappings()

    for {canonical, _aliases, registration, decode_count, _encode_count} <- @specs do
      assert map_size(expected[registration]) == decode_count

      for byte <- 0..255 do
        result =
          case Map.fetch(expected[registration], <<byte>>) do
            {:ok, [codepoint]} -> {:ok, <<codepoint::utf8>>}
            :error -> {:error, :invalid_sequence}
          end

        assert normalized(Iconvex.convert(<<byte>>, canonical, "UTF-8")) == result
      end
    end
  end

  test "round-trips every canonical mapping and preserves documented decode duplicates" do
    expected = expected_mappings()

    for {canonical, _aliases, registration, _decode_count, encode_count} <- @specs do
      encode = canonical_encode(expected[registration])
      assert map_size(encode) == encode_count

      for {[codepoint], bytes} <- encode do
        assert Iconvex.convert(<<codepoint::utf8>>, "UTF-8", canonical) == {:ok, bytes}
      end
    end

    assert Iconvex.convert(<<0x5F>>, "ISO-IR-129", "UTF-8") == {:ok, <<0x2588::utf8>>}
    assert Iconvex.convert(<<0x7F>>, "ISO-IR-129", "UTF-8") == {:ok, <<0x2588::utf8>>}
    assert Iconvex.convert(<<0x2588::utf8>>, "UTF-8", "ISO-IR-129") == {:ok, <<0x5F>>}

    assert Iconvex.convert(<<0x38>>, "ISO-IR-181", "UTF-8") == {:ok, <<0x2248::utf8>>}
    assert Iconvex.convert(<<0x5E>>, "ISO-IR-181", "UTF-8") == {:ok, <<0x2248::utf8>>}
    assert Iconvex.convert(<<0x2248::utf8>>, "UTF-8", "ISO-IR-181") == {:ok, <<0x38>>}
  end

  test "uses the revised WG2 mapping for the IEC middle-dot symbol" do
    assert Iconvex.convert(<<0x37>>, "ISO-IR-181", "UTF-8") == {:ok, <<0x2219::utf8>>}
    refute Iconvex.convert(<<0x37>>, "ISO-IR-181", "UTF-8") == {:ok, <<0x22C5::utf8>>}
  end

  @tag timeout: 120_000
  test "checks singleton encoding over every Unicode scalar" do
    all_scalars =
      0..0x10FFFF
      |> Stream.reject(&(&1 in 0xD800..0xDFFF))
      |> Stream.chunk_every(4_096)
      |> Enum.map(&List.to_string/1)
      |> IO.iodata_to_binary()

    for {canonical, _aliases, registration, _decode_count, _encode_count} <- @specs do
      output =
        expected_mappings()[registration]
        |> canonical_encode()
        |> Enum.sort()
        |> Enum.map(fn {_codepoints, bytes} -> bytes end)
        |> IO.iodata_to_binary()

      assert Iconvex.convert(all_scalars, "UTF-8", canonical, unrepresentable: :discard) ==
               {:ok, output}
    end
  end

  defp manifest, do: @manifest |> File.read!() |> :erlang.binary_to_term()

  defp expected_mappings do
    %{
      71 => byte_map(0x21, @iso_ir_71_values),
      129 => iso_ir_129(),
      137 => iso_ir_137(),
      173 => iso_ir_173(),
      181 => byte_map(0x20, @iso_ir_181_values)
    }
  end

  defp iso_ir_129 do
    first = Enum.to_list(0x1FB00..0x1FB13) ++ [0x258C] ++ Enum.to_list(0x1FB14..0x1FB1D)
    last = Enum.to_list(0x1FB1E..0x1FB27) ++ [0x2590] ++ Enum.to_list(0x1FB28..0x1FB3B)

    byte_map(0x21, first)
    |> Map.merge(byte_map(0x60, last))
    |> Map.merge(%{<<0x20>> => [0x00A0], <<0x5F>> => [0x2588], <<0x7F>> => [0x2588]})
  end

  defp iso_ir_137 do
    general = %{
      0x21 => 0x2596,
      0x22 => 0x25AA,
      0x23 => 0x1CE47,
      0x24 => 0x259F,
      0x27 => 0x25B6,
      0x29 => 0x1F837,
      0x2C => 0x1FB9B,
      0x2D => 0x1FBE3,
      0x2E => 0x1FBEB,
      0x30 => 0x2584,
      0x31 => 0x2597,
      0x32 => 0x25AC,
      0x33 => 0x1CE50,
      0x34 => 0x2599,
      0x37 => 0x25C0,
      0x39 => 0x1F835,
      0x3C => 0x1FB9A,
      0x3D => 0x1FBE1,
      0x3E => 0x1FBE9
    }

    private_use =
      [0x25, 0x26, 0x28, 0x2A, 0x2B, 0x2F, 0x35, 0x36, 0x38, 0x3A, 0x3B, 0x3F]
      |> Map.new(fn byte -> {byte, 0xF700 + byte} end)

    general
    |> Map.merge(private_use)
    |> Map.merge(sg29_to_sg56())
    |> encoded_map()
  end

  defp iso_ir_173 do
    byte_to_dg =
      Enum.zip(0x21..0x2D, 33..45)
      |> Enum.concat([{0x2F, 46}])
      |> Enum.concat(Enum.zip(0x30..0x3A, 52..62))
      |> Enum.concat(Enum.zip(0x3B..0x3F, [51, 50, 49, 48, 47]))
      |> Enum.concat(Enum.zip(0x40..0x4C, 1..13))
      |> Enum.concat(Enum.zip(0x4D..0x4F, 29..31))
      |> Enum.concat(Enum.zip(0x50..0x5E, 14..28))
      |> Enum.concat([{0x5F, 63}, {0x6E, 64}, {0x6F, 65}])

    drawing =
      Map.new(byte_to_dg, fn {byte, dg} ->
        codepoint = Map.get(drawing_unicode(), dg, 0xF800 + dg)
        {byte, codepoint}
      end)

    drawing
    |> Map.merge(sg29_to_sg56())
    |> encoded_map()
  end

  defp drawing_unicode do
    %{
      1 => 0x2537,
      2 => 0x252F,
      3 => 0x251D,
      4 => 0x2525,
      5 => 0x1FBA4,
      6 => 0x1FBA5,
      7 => 0x1FBA6,
      8 => 0x1FBA7,
      9 => 0x1FBA0,
      10 => 0x1FBA1,
      11 => 0x1FBA2,
      12 => 0x1FBA3,
      13 => 0x253F,
      14 => 0x2502,
      15 => 0x2500,
      16 => 0x250C,
      17 => 0x2510,
      18 => 0x2514,
      19 => 0x2518,
      20 => 0x251C,
      21 => 0x2524,
      22 => 0x252C,
      23 => 0x2534,
      24 => 0x253C,
      25 => 0x2B62,
      26 => 0x2B60,
      27 => 0x2B61,
      28 => 0x2B63,
      29 => 0x2022,
      30 => 0x25CF,
      31 => 0x25CB,
      33 => 0x2571,
      34 => 0x2572,
      35 => 0x2503,
      36 => 0x2501,
      37 => 0x250F,
      38 => 0x2513,
      39 => 0x2517,
      40 => 0x251B,
      41 => 0x2523,
      42 => 0x252B,
      43 => 0x2533,
      44 => 0x253B,
      45 => 0x254B,
      46 => 0x2520,
      47 => 0x2528,
      48 => 0x2532,
      49 => 0x253A,
      50 => 0x2542
    }
  end

  defp sg29_to_sg56 do
    values = [
      0x1FB52,
      0x1FB53,
      0x1FB54,
      0x1FB55,
      0x1FB56,
      0x25E5,
      0x1FB57,
      0x1FB58,
      0x1FB59,
      0x1FB5A,
      0x1FB5B,
      0x1FB5C,
      0x1FB6C,
      0x1FB6D,
      0x1FB5D,
      0x1FB5E,
      0x1FB5F,
      0x1FB60,
      0x1FB61,
      0x25E4,
      0x1FB62,
      0x1FB63,
      0x1FB64,
      0x1FB65,
      0x1FB66,
      0x1FB67,
      0x1FB6E,
      0x1FB6F
    ]

    Enum.zip(Enum.to_list(0x60..0x6D) ++ Enum.to_list(0x70..0x7D), values)
    |> Map.new()
  end

  defp byte_map(start, values) do
    start..(start + length(values) - 1)
    |> Enum.zip(values)
    |> Enum.reject(fn {_byte, codepoint} -> is_nil(codepoint) end)
    |> Map.new(fn {byte, codepoint} -> {<<byte>>, [codepoint]} end)
  end

  defp encoded_map(mapping),
    do: Map.new(mapping, fn {byte, codepoint} -> {<<byte>>, [codepoint]} end)

  defp canonical_encode(decode) do
    decode
    |> Enum.sort()
    |> Enum.reduce(%{}, fn {bytes, codepoints}, result ->
      Map.put_new(result, codepoints, bytes)
    end)
  end

  defp normalized({:ok, output}), do: {:ok, output}
  defp normalized({:error, %Iconvex.Error{kind: reason}}), do: {:error, reason}
  defp normalized({:error, reason, _output}), do: {:error, reason}
end

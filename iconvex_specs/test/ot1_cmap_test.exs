defmodule Iconvex.Specs.OT1CMapTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.OT1CMap10J, as: OT1
  alias Iconvex.Specs.OT1TTCMap10J, as: OT1TT

  @root Path.expand("..", __DIR__)
  @source_dir Path.join(@root, "priv/sources/ot1-cmap-1.0j")
  @ot1_path Path.join(@source_dir, "ot1.cmap")
  @ot1tt_path Path.join(@source_dir, "ot1tt.cmap")
  @metadata_path Path.join(@source_dir, "SOURCE_METADATA.md")

  @ot1_sha256 "2c7325ed9ad97da701f43737f0762c181878b8d770b5abf37df8728216f9e646"
  @ot1tt_sha256 "58b4f178ac815587ccf5165cd3cc13816000f1338b05706717bdbc8345d75af3"
  @archive_sha256 "b5fffa016ac4571f0405592ac40bf231f9ddb6b1ce3100d17a33833284bbeb84"
  @latex_sha256 "61cc867257831d2611e2d96ead2a1882f03e4da27c095b642cc866984aac0bc2"

  @common %{
    0x00 => [0x0393],
    0x01 => [0x0394],
    0x02 => [0x0398],
    0x03 => [0x039B],
    0x04 => [0x039E],
    0x05 => [0x03A0],
    0x06 => [0x03A3],
    0x07 => [0x03D2],
    0x08 => [0x03A6],
    0x09 => [0x03A8],
    0x0A => [0x03A9],
    0x10 => [0x0131],
    0x11 => [0x0237],
    0x12 => [0x0060],
    0x13 => [0x00B4],
    0x14 => [0x02C7],
    0x15 => [0x02D8],
    0x16 => [0x00AF],
    0x17 => [0x02DA],
    0x18 => [0x00B8],
    0x19 => [0x00DF],
    0x1A => [0x00E6],
    0x1B => [0x0153],
    0x1C => [0x00F8],
    0x1D => [0x00C6],
    0x1E => [0x0152],
    0x1F => [0x00D8],
    0x27 => [0x2019],
    0x60 => [0x2018],
    0x7F => [0x00A8]
  }

  @ot1_oracle @common
              |> Map.merge(%{
                0x0B => ~c"ff",
                0x0C => ~c"fi",
                0x0D => ~c"fl",
                0x0E => ~c"ffi",
                0x0F => ~c"ffl",
                0x21 => [?\!],
                0x22 => [0x201D],
                0x3C => [0x00A1],
                0x3D => [?=],
                0x3E => [0x00BF],
                0x5C => [0x201C],
                0x5F => [0x02D9],
                0x7B => [0x2013],
                0x7C => [0x2014],
                0x7D => [0x02DD],
                0x7E => [0x02DC]
              })
              |> Map.merge(Map.new(0x23..0x26, &{&1, [&1]}))
              |> Map.merge(Map.new(0x28..0x3B, &{&1, [&1]}))
              |> Map.merge(Map.new(0x3F..0x5B, &{&1, [&1]}))
              |> Map.merge(Map.new(0x5D..0x5E, &{&1, [&1]}))
              |> Map.merge(Map.new(0x61..0x7A, &{&1, [&1]}))

  @ot1tt_oracle @common
                |> Map.merge(%{
                  0x0B => [0x2191],
                  0x0C => [0x2193],
                  0x0D => [?'],
                  0x0E => [0x00A1],
                  0x0F => [0x00BF],
                  0x20 => [0x2423]
                })
                |> Map.merge(Map.new(0x21..0x26, &{&1, [&1]}))
                |> Map.merge(Map.new(0x28..0x5F, &{&1, [&1]}))
                |> Map.merge(Map.new(0x61..0x7E, &{&1, [&1]}))

  @profiles [{OT1, @ot1_oracle}, {OT1TT, @ot1tt_oracle}]

  test "RED: both versioned CTAN CMap profiles and exact upstream artifacts exist" do
    assert OT1 in Iconvex.Specs.additional_codecs()
    assert OT1TT in Iconvex.Specs.additional_codecs()

    assert OT1.canonical_name() == "TEX-OT1-CMAP-1.0J"
    assert OT1.aliases() == ["TEX-OT1-0-CMAP-1.0J"]
    assert OT1TT.canonical_name() == "TEX-OT1TT-CMAP-1.0J"
    assert OT1TT.aliases() == ["TEX-OT1TT-0-CMAP-1.0J"]

    assert {:ok, %{codec: OT1}} = Iconvex.ExternalRegistry.resolve(OT1.canonical_name())
    assert {:ok, %{codec: OT1TT}} = Iconvex.ExternalRegistry.resolve(OT1TT.canonical_name())
    assert :error = Iconvex.ExternalRegistry.resolve("OT1")

    assert sha256(File.read!(@ot1_path)) == @ot1_sha256
    assert sha256(File.read!(@ot1tt_path)) == @ot1tt_sha256

    metadata = File.read!(@metadata_path)
    assert metadata =~ @archive_sha256
    assert metadata =~ @latex_sha256
    assert metadata =~ "LPPL-1.3c-or-later"
    assert metadata =~ "OT1 normal and typewriter mappings are distinct"
    assert metadata =~ "GNU libiconv does not expose these source-qualified profiles"
  end

  test "RED: independent CMap oracles exhaust all 256 source octets" do
    assert map_size(@ot1_oracle) == 127
    refute Map.has_key?(@ot1_oracle, 0x20)
    assert map_size(@ot1tt_oracle) == 128

    for {codec, oracle} <- @profiles, byte <- 0..255 do
      case Map.fetch(oracle, byte) do
        {:ok, expected} ->
          assert codec.decode(<<byte>>) == {:ok, expected}
          assert codec.decode_to_utf8(<<byte>>) == {:ok, List.to_string(expected)}

        :error ->
          assert codec.decode(<<byte>>) == {:error, :invalid_sequence, 0, <<byte>>}
      end
    end
  end

  test "RED: the deterministic inverse is exact and uses longest sequence matching" do
    for {codec, oracle} <- @profiles, {byte, codepoints} <- oracle do
      assert codec.encode(codepoints) == {:ok, <<byte>>}
      assert codec.encode_from_utf8(List.to_string(codepoints)) == {:ok, <<byte>>}
    end

    assert OT1.encode(~c"ffifflfffifl") == {:ok, <<0x0E, 0x0F, 0x0B, 0x0C, 0x0D>>}

    assert OT1.encode_from_utf8("ffifflfffifl") ==
             {:ok, <<0x0E, 0x0F, 0x0B, 0x0C, 0x0D>>}

    assert OT1TT.encode(~c"ffiffl") == {:ok, "ffiffl"}

    assert OT1.encode_chunk(~c"f", false, :error) == {:ok, <<>>, ~c"f"}
    assert OT1.encode_chunk(~c"ff", false, :error) == {:ok, <<>>, ~c"ff"}
    assert OT1.encode_chunk(~c"ffi", false, :error) == {:ok, <<0x0E>>, []}
    assert OT1.encode_chunk(~c"ffA", false, :error) == {:ok, <<0x0B, ?A>>, []}
    assert OT1.encode_chunk(~c"ff", true, :error) == {:ok, <<0x0B>>, []}
  end

  test "RED: invalid input and output policies preserve exact progress and offsets" do
    assert OT1.decode(<<0x41, 0x20, 0x42>>) ==
             {:error, :invalid_sequence, 1, <<0x20>>}

    assert OT1.decode_discard(<<0x80, 0x41, 0x20, 0x42, 0xFF>>) == {:ok, ~c"AB"}
    assert OT1TT.decode_discard(<<0x80, 0x41, 0xFF>>) == {:ok, ~c"A"}

    assert OT1.encode([?A, 0x20AC]) == {:error, :unrepresentable_character, 0x20AC}
    assert OT1.encode_discard([?A, 0x20AC, ?B]) == {:ok, "AB"}

    assert OT1.encode_substitute([?A, 0x20AC, ?B], fn 0x20AC -> [?\?] end) ==
             {:ok, "A?B"}

    for codec <- [OT1, OT1TT] do
      assert codec.encode_from_utf8(<<"A", 0xE2, 0x82>>) ==
               {:decode_error, :incomplete_sequence, 1, <<0xE2, 0x82>>}

      assert codec.encode_from_utf8(<<"A", 0xFF>>) ==
               {:decode_error, :invalid_sequence, 1, <<0xFF>>}
    end
  end

  test "RED: every Unicode scalar is either canonically representable or explicitly discarded" do
    for {codec, oracle} <- @profiles do
      scalar_inverse =
        for {byte, [codepoint]} <- oracle, into: %{}, do: {codepoint, byte}

      for {codepoint, byte} <- scalar_inverse do
        assert codec.encode([codepoint]) == {:ok, <<byte>>}
      end

      representable = scalar_inverse |> Map.keys() |> MapSet.new()

      for first <- 0..0x10FFFF//4096 do
        unrepresentable =
          first..min(first + 4095, 0x10FFFF)
          |> Enum.reject(&(&1 in 0xD800..0xDFFF))
          |> Enum.reject(&MapSet.member?(representable, &1))

        assert codec.encode_discard(unrepresentable) == {:ok, <<>>}
      end
    end
  end

  test "RED: public one-shot conversion follows the source-qualified profiles" do
    source = <<0x00, 0x0E, 0x21, 0x7F>>
    expected = <<0x0393::utf8, ?f, ?f, ?i, ?\!, 0x00A8::utf8>>

    assert Iconvex.convert(source, OT1.canonical_name(), "UTF-8") == {:ok, expected}
    assert Iconvex.convert(expected, "UTF-8", OT1.canonical_name()) == {:ok, source}

    assert Iconvex.convert(<<0x20, 0x0B, 0x0C>>, OT1TT.canonical_name(), "UTF-8") ==
             {:ok, <<0x2423::utf8, 0x2191::utf8, 0x2193::utf8>>}

    assert Iconvex.convert(<<0x20, ?A>>, OT1.canonical_name(), "UTF-8", invalid: :discard) ==
             {:ok, "A"}
  end

  defp sha256(bytes),
    do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end

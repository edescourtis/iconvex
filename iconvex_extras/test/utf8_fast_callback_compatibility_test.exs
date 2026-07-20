defmodule Iconvex.Extras.UTF8FastCallbackCompatibilityTest do
  use ExUnit.Case, async: false

  @codecs [
    Iconvex.Extras.Codecs.EucJisx0213,
    Iconvex.Extras.Codecs.ShiftJisx0213
  ]

  test "multi-codepoint table callbacks never leak the internal fast-path miss sentinel" do
    sample = "Aあ"

    for codec <- @codecs do
      assert {:ok, _encoded} = expected = codec.encode(String.to_charlist(sample))
      assert codec.encode_from_utf8(sample) == expected

      assert codec.encode_from_utf8(<<0x10FFFF::utf8>>) ==
               {:error, :unrepresentable_character, 0x10FFFF}

      assert codec.encode_from_utf8(<<"A", 0xFF>>) ==
               {:decode_error, :invalid_sequence, 1, <<0xFF>>}

      assert codec.encode_from_utf8(<<"A", 0xE2, 0x82>>) ==
               {:decode_error, :incomplete_sequence, 1, <<0xE2, 0x82>>}
    end
  end
end

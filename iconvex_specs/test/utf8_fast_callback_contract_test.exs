defmodule Iconvex.Specs.UTF8FastCallbackContractTest do
  use ExUnit.Case, async: true

  @codecs [
    Iconvex.Specs.BOCU1,
    Iconvex.Specs.CDC612DisplayCode63,
    Iconvex.Specs.CDCDisplayCode63,
    Iconvex.Specs.CESU8,
    Iconvex.Specs.DECHebrew8,
    Iconvex.Specs.DECNRCDutch,
    Iconvex.Specs.DECRadix50BE16,
    Iconvex.Specs.DECRadix50PDP9BE24,
    Iconvex.Specs.DECSIXBIT,
    Iconvex.Specs.DECSpecial,
    Iconvex.Specs.DotnetXEuropa,
    Iconvex.Specs.ECMA1,
    Iconvex.Specs.FieldataUNIVAC1100,
    Iconvex.Specs.FieldataUNIVAC4009Input,
    Iconvex.Specs.FieldataUNIVAC4009Output,
    Iconvex.Specs.FieldataUNIVAC4009LosslessVPUA,
    Iconvex.Specs.IANAAmiga1251,
    Iconvex.Specs.IMAPUTF7,
    Iconvex.Specs.JavaModifiedUTF8,
    Iconvex.Specs.KermitBulgariaPC,
    Iconvex.Specs.KermitDGInternational,
    Iconvex.Specs.KermitELOT927Greek,
    Iconvex.Specs.KermitMazovia,
    Iconvex.Specs.KermitQNXConsole,
    Iconvex.Specs.KOI7Switched,
    Iconvex.Specs.KOI8F,
    Iconvex.Specs.Mnemonic,
    Iconvex.Specs.SCSU,
    Iconvex.Specs.ShortKOI,
    Iconvex.Specs.UTF1,
    Iconvex.Specs.IconvexUTF16SignatureLEDefault,
    Iconvex.Specs.IconvexUTF32BESignature,
    Iconvex.Specs.UTFEBCDIC,
    Iconvex.Specs.VIQR,
    Iconvex.Specs.XUserDefined
  ]

  test "optimized UTF-8 encoders preserve invalid tail, offset, and sequence" do
    for codec <- @codecs do
      assert codec.encode_from_utf8(<<"A", 0xFF, "B">>) ==
               {:decode_error, :invalid_sequence, 1, <<0xFF, "B">>},
             inspect(codec)
    end

    raw_prefix = <<0xF4006::utf8>>

    assert Iconvex.Specs.FieldataUNIVAC4009RawVPUA.encode_from_utf8(raw_prefix <> <<0xFF, "B">>) ==
             {:decode_error, :invalid_sequence, byte_size(raw_prefix), <<0xFF, "B">>}
  end

  test "optimized UTF-8 encoders preserve truncated tail, offset, and sequence" do
    for codec <- @codecs do
      assert codec.encode_from_utf8(<<"A", 0xE2, 0x82>>) ==
               {:decode_error, :incomplete_sequence, 1, <<0xE2, 0x82>>},
             inspect(codec)
    end

    raw_prefix = <<0xF4006::utf8>>

    assert Iconvex.Specs.FieldataUNIVAC4009RawVPUA.encode_from_utf8(raw_prefix <> <<0xE2, 0x82>>) ==
             {:decode_error, :incomplete_sequence, byte_size(raw_prefix), <<0xE2, 0x82>>}
  end
end

defmodule Iconvex.Telecom.SIMAlphaIdentifierTest do
  use ExUnit.Case, async: true

  alias Iconvex.Telecom.SIMAlphaIdentifier

  test "decodes GSM-default alpha identifiers and FF record padding" do
    assert SIMAlphaIdentifier.decode(<<0x41, 0x42, 0x43, 0xFF, 0xFF>>) == {:ok, "ABC"}
  end

  test "supports the 0x80 uncompressed UCS2 form" do
    encoded = <<0x80, 0x00, 0x41, 0x04, 0x10, 0xFF>>
    assert SIMAlphaIdentifier.decode(encoded) == {:ok, "AА"}
    assert SIMAlphaIdentifier.encode("AА", mode: :ucs2) == {:ok, <<0x80, 0x00, 0x41, 0x04, 0x10>>}
  end

  test "supports mixed GSM and compressed 0x81 and 0x82 UCS2 forms" do
    assert SIMAlphaIdentifier.decode(<<0x81, 2, 0x08, 0x41, 0x90, 0xFF>>) == {:ok, "AА"}

    assert SIMAlphaIdentifier.decode(<<0x82, 2, 0x04, 0x00, 0x41, 0x90, 0xFF>>) ==
             {:ok, "AА"}

    assert SIMAlphaIdentifier.encode("AА", mode: :compressed_81) ==
             {:ok, <<0x81, 2, 0x08, 0x41, 0x90>>}

    assert SIMAlphaIdentifier.encode("AА", mode: :compressed_82) ==
             {:ok, <<0x82, 2, 0x04, 0x10, 0x41, 0x80>>}
  end

  test "auto chooses GSM when possible and UCS2 otherwise" do
    assert SIMAlphaIdentifier.encode("ABC") == {:ok, "ABC"}
    assert SIMAlphaIdentifier.encode("AА") == {:ok, <<0x81, 2, 0x08, 0x41, 0x90>>}
  end

  test "rejects truncated and impossible compressed forms" do
    assert SIMAlphaIdentifier.decode(<<0x80, 0x00>>) == {:error, :truncated_ucs2}

    assert SIMAlphaIdentifier.decode(<<0x81, 2, 0x08, 0x90>>) ==
             {:error, :truncated_alpha_identifier}

    assert SIMAlphaIdentifier.encode("A🙂", mode: :compressed_81) ==
             {:error, :not_representable_in_compressed_81}
  end
end

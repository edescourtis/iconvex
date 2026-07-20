defmodule Iconvex.Specs.IMAPUTF7Test do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.IMAPUTF7

  test "matches the RFC 3501 multilingual mailbox vector" do
    utf8 = "~peter/mail/台北/日本語"
    encoded = "~peter/mail/&U,BTFw-/&ZeVnLIqe-"

    assert IMAPUTF7.encode(String.to_charlist(utf8)) == {:ok, encoded}
    assert IMAPUTF7.decode(encoded) == {:ok, String.to_charlist(utf8)}
  end

  test "uses ampersand-minus and leaves other printable ASCII direct" do
    assert IMAPUTF7.encode(String.to_charlist("A&B+~\\")) == {:ok, "A&-B+~\\"}
    assert IMAPUTF7.decode("A&-B+~\\") == {:ok, String.to_charlist("A&B+~\\")}
  end

  test "rejects missing shifts, malformed base64, and encoded direct ASCII" do
    assert IMAPUTF7.decode("&Jjo!") == {:error, :incomplete_sequence, 0, "&Jjo!"}
    assert IMAPUTF7.decode("&A-") == {:error, :invalid_sequence, 0, "&A-"}
    assert IMAPUTF7.decode("&AGE-") == {:error, :invalid_sequence, 0, "&AGE-"}
    assert IMAPUTF7.decode(<<0x80>>) == {:error, :invalid_sequence, 0, <<0x80>>}
  end

  test "registers the RFC codec aliases" do
    assert Iconvex.canonical_name("IMAP-UTF-7") == {:ok, "UTF-7-IMAP"}
    assert Iconvex.convert("&U,BTFw-", "UTF-7-IMAP", "UTF-8") == {:ok, "台北"}
  end
end

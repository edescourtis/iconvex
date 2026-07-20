defmodule Iconvex.Telecom.GSM0338ContractTest do
  use ExUnit.Case, async: true

  alias Iconvex.Telecom.GSM0338

  @languages [
    :turkish,
    :spanish,
    :portuguese,
    :bengali,
    :gujarati,
    :hindi,
    :kannada,
    :malayalam,
    :oriya,
    :punjabi,
    :tamil,
    :telugu,
    :urdu
  ]

  test "exposes every 3GPP national table and the Spanish locking-table gap" do
    assert Enum.map(GSM0338.single_shift_tables(), & &1.name) == [:default | @languages]

    assert Enum.map(GSM0338.locking_tables(), & &1.name) ==
             [:default | @languages -- [:spanish]]

    refute GSM0338.locking_table?(:spanish)
    assert GSM0338.single_shift_table?(:spanish)

    pairs = GSM0338.valid_pairs()
    assert length(pairs) == 182
    assert %{locking: :portuguese, single_shift: :bengali} in pairs
    refute %{locking: :spanish, single_shift: :default} in pairs
  end

  test "uses unpacked SMPP septets and the default extension table" do
    assert GSM0338.decode("hello") == {:ok, ~c"hello"}
    assert GSM0338.encode(~c"hello") == {:ok, "hello"}
    assert GSM0338.decode(<<0x1B, 0x65>>) == {:ok, [0x20AC]}
    assert GSM0338.encode([0x20AC]) == {:ok, <<0x1B, 0x65>>}
    assert GSM0338.encode_utf8("€") == {:ok, <<0x1B, 0x65>>}
  end

  test "allows independent locking and single-shift national tables" do
    options = [locking: :portuguese, single_shift: :bengali]

    assert GSM0338.decode(<<0x04, 0x1B, 0x19>>, options) == {:ok, [0x00EA, 0x09E6]}
    assert GSM0338.encode([0x00EA, 0x09E6], options) == {:ok, <<0x04, 0x1B, 0x19>>}
  end

  test "reports malformed unpacked input precisely" do
    assert GSM0338.decode(<<0x80>>) == {:error, :invalid_sequence, 0, <<0x80>>}
    assert GSM0338.decode(<<0x1B>>) == {:ok, [0x20]}
    assert GSM0338.decode_discard(<<0x80, ?A, 0x1B>>) == {:ok, [?A, 0x20]}

    assert GSM0338.encode_utf8(<<?A, 0xFF>>) ==
             {:error, :invalid_sequence, 1, <<0xFF>>}

    assert GSM0338.encode_utf8(<<0xE2, 0x82>>) ==
             {:error, :incomplete_sequence, 0, <<0xE2, 0x82>>}
  end

  test "rejects absent tables instead of silently selecting a fallback" do
    assert GSM0338.decode("A", locking: :spanish) == {:error, {:unknown_locking_table, :spanish}}

    assert GSM0338.decode("A", single_shift: :missing) ==
             {:error, {:unknown_single_shift_table, :missing}}
  end
end

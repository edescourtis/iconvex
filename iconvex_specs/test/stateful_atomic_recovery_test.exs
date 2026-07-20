defmodule Iconvex.Specs.StatefulAtomicRecoveryTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.{
    IMAPUTF7,
    IconvexUTF16SignatureLEDefault,
    IconvexUTF32BESignature,
    IconvexUTF32LESignature,
    SCSU,
    UTF8Sig
  }

  @signature_cases [
    {UTF8Sig, "UTF-8-SIG", <<0xEF, 0xBB, 0xBF, ?A, 0xFF, 0xEF, 0xBB, 0xBF, ?B>>, "A\uFEFFB",
     "A?\uFEFFB", "A<ff>\uFEFFB"},
    {IconvexUTF16SignatureLEDefault, "ICONVEX-UTF-16-SIGNATURE-LE-DEFAULT",
     <<0xFE, 0xFF, 0x00, ?A, 0xDC, 0x00, 0xFE, 0xFF, 0x00, ?B>>, "A\uFEFFB", "A?\uFEFFB",
     "A<dc><00>\uFEFFB"},
    {IconvexUTF32BESignature, "ICONVEX-UTF-32BE-SIGNATURE",
     <<0x00, 0x00, 0xFE, 0xFF, 0x00, 0x00, 0x00, ?A, 0x00, 0x00, 0xD8, 0x00, 0x00, 0x00, 0xFE,
       0xFF, 0x00, 0x00, 0x00, ?B>>, "A\uFEFFB", "A?\uFEFFB", "A<00><00><d8><00>\uFEFFB"},
    {IconvexUTF32LESignature, "ICONVEX-UTF-32LE-SIGNATURE",
     <<0xFF, 0xFE, 0x00, 0x00, ?A, 0x00, 0x00, 0x00, 0x00, 0xD8, 0x00, 0x00, 0xFF, 0xFE, 0x00,
       0x00, ?B, 0x00, 0x00, 0x00>>, "A\uFEFFB", "A?\uFEFFB", "A<00><d8><00><00>\uFEFFB"}
  ]

  @atomic_cases [
    {IMAPUTF7, "UTF-7-IMAP", "&A-A", "A", "?A", "<26><41><2d>A"},
    {SCSU, "SCSU", <<0x18, 0x00, ?A>>, "A", "?A", "<18><00>A"}
  ]

  test "RED: signature decoders retain beginning-of-stream and endian state during recovery" do
    for {codec, encoding, input, discarded, replaced, substituted} <- @signature_cases do
      assert {:ok, String.to_charlist(discarded)} == codec.decode_discard(input)
      assert_recovery_at_every_split(encoding, input, discarded, replaced, substituted)
    end
  end

  test "RED: framed invalid source units recover atomically at every split" do
    for {codec, encoding, input, discarded, replaced, substituted} <- @atomic_cases do
      assert {:error, :invalid_sequence, 0, sequence} = codec.decode(input)
      assert codec.decode_error_consumption(:invalid_sequence, sequence) == byte_size(sequence)
      assert {:ok, String.to_charlist(discarded)} == codec.decode_discard(input)
      assert_recovery_at_every_split(encoding, input, discarded, replaced, substituted)
    end
  end

  defp assert_recovery_at_every_split(encoding, input, discarded, replaced, substituted) do
    discard_callback = fn _event -> :discard end
    replace_callback = fn _event -> {:replace, "?"} end

    assert Iconvex.convert(input, encoding, "UTF-8", on_invalid_byte: discard_callback) ==
             {:ok, discarded}

    assert Iconvex.convert(input, encoding, "UTF-8", on_invalid_byte: replace_callback) ==
             {:ok, replaced}

    assert Iconvex.convert(input, encoding, "UTF-8", byte_substitute: "<%02x>") ==
             {:ok, substituted}

    for split <- 0..byte_size(input) do
      chunks = split_binary(input, split)

      assert stream(chunks, encoding, on_invalid_byte: discard_callback) == discarded,
             "callback discard mismatch for #{encoding} split #{split}"

      assert stream(chunks, encoding, on_invalid_byte: replace_callback) == replaced,
             "callback replacement mismatch for #{encoding} split #{split}"

      assert stream(chunks, encoding, byte_substitute: "<%02x>") == substituted,
             "byte substitution mismatch for #{encoding} split #{split}"
    end
  end

  defp split_binary(input, split) do
    [
      binary_part(input, 0, split),
      binary_part(input, split, byte_size(input) - split)
    ]
  end

  defp stream(chunks, encoding, options) do
    assert {:ok, stream} = Iconvex.stream(chunks, encoding, "UTF-8", options)
    stream |> Enum.to_list() |> IO.iodata_to_binary()
  end
end

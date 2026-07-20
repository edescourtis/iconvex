defmodule Iconvex.Specs.ReviewRigorStreamRecoveryTest do
  use ExUnit.Case, async: false

  @lmbcs_modules [
    Iconvex.Specs.ICULMBCS1,
    Iconvex.Specs.ICULMBCS2,
    Iconvex.Specs.ICULMBCS3,
    Iconvex.Specs.ICULMBCS4,
    Iconvex.Specs.ICULMBCS5,
    Iconvex.Specs.ICULMBCS6,
    Iconvex.Specs.ICULMBCS8,
    Iconvex.Specs.ICULMBCS11,
    Iconvex.Specs.ICULMBCS16,
    Iconvex.Specs.ICULMBCS17,
    Iconvex.Specs.ICULMBCS18,
    Iconvex.Specs.ICULMBCS19
  ]

  @lmbcs_invalid_units [
    <<0x0F, 0x1F>>,
    <<0x10, 0x81, 0x30>>
  ]

  @unihan Iconvex.Specs.Unihan17KGB3RowCellGL

  test "RED: every LMBCS profile recovers complete native two- and three-byte units" do
    for module <- @lmbcs_modules, invalid <- @lmbcs_invalid_units do
      canonical = module.canonical_name()
      input = invalid <> "A"
      substitution = substituted_bytes(invalid) <> "A"

      assert module.decode(input) ==
               {:error, :invalid_sequence, 0, invalid},
             "#{canonical} strict diagnostic for #{inspect(invalid)}"

      assert module.decode_error_consumption(:invalid_sequence, invalid) == byte_size(invalid)
      assert convert(input, canonical, invalid: :discard) == "A"
      assert convert(input, canonical, byte_substitute: "<%02X>") == substitution

      assert_callback_recovery(
        fn handler -> convert(input, canonical, on_invalid_byte: handler) end,
        canonical,
        [{0, invalid}],
        "!A"
      )

      for split <- 0..byte_size(input) do
        chunks = split_at(input, split)

        assert stream(chunks, canonical, invalid: :discard) == "A",
               "#{canonical} discard at split #{split} for #{inspect(invalid)}"

        assert stream(chunks, canonical, byte_substitute: "<%02X>") == substitution,
               "#{canonical} substitution at split #{split} for #{inspect(invalid)}"

        assert_callback_recovery(
          fn handler -> stream(chunks, canonical, on_invalid_byte: handler) end,
          canonical,
          [{0, invalid}],
          "!A"
        )
      end
    end
  end

  test "RED: LMBCS-16 does not reinterpret an invalid implicit MBCS trail as ASCII" do
    invalid = <<0x8A, 0x32>>
    input = invalid <> "A"
    canonical = Iconvex.Specs.ICULMBCS16.canonical_name()

    assert Iconvex.Specs.ICULMBCS16.decode(input) ==
             {:error, :invalid_sequence, 0, invalid}

    assert Iconvex.Specs.ICULMBCS16.decode_discard(input) == {:ok, ~c"A"}
    assert convert(input, canonical, invalid: :discard) == "A"
    assert convert(input, canonical, byte_substitute: "<%02X>") == "<8A><32>A"

    for split <- 0..byte_size(input) do
      chunks = split_at(input, split)
      assert stream(chunks, canonical, invalid: :discard) == "A"
      assert stream(chunks, canonical, byte_substitute: "<%02X>") == "<8A><32>A"

      assert_callback_recovery(
        fn handler -> stream(chunks, canonical, on_invalid_byte: handler) end,
        canonical,
        [{0, invalid}],
        "!A"
      )
    end
  end

  test "RED: Unihan fixed pairs retain an odd non-final byte at every split" do
    input = <<0x2F, 0x30, 0x21>>
    canonical = @unihan.canonical_name()
    malformed_pair = <<0x2F, 0x30>>
    malformed_tail = <<0x21>>

    assert @unihan.decode(input) ==
             {:error, :invalid_sequence, 0, malformed_pair}

    assert @unihan.decode_discard(input) == {:ok, []}
    assert @unihan.decode_chunk(malformed_tail, false) == {:ok, [], malformed_tail}

    assert @unihan.decode_chunk(malformed_tail, true) ==
             {:error, :invalid_sequence, 0, malformed_tail}

    assert convert(input, canonical, invalid: :discard) == ""
    assert convert(input, canonical, byte_substitute: "<%02X>") == "<2F><30><21>"

    assert_callback_recovery(
      fn handler -> convert(input, canonical, on_invalid_byte: handler) end,
      canonical,
      [{0, malformed_pair}, {2, malformed_tail}],
      "!!"
    )

    for split <- 0..byte_size(input) do
      chunks = split_at(input, split)

      assert_stream_error(chunks, canonical, :invalid_sequence, 0, malformed_pair)
      assert stream(chunks, canonical, invalid: :discard) == ""
      assert stream(chunks, canonical, byte_substitute: "<%02X>") == "<2F><30><21>"

      assert_callback_recovery(
        fn handler -> stream(chunks, canonical, on_invalid_byte: handler) end,
        canonical,
        [{0, malformed_pair}, {2, malformed_tail}],
        "!!"
      )
    end
  end

  defp convert(input, from, options) do
    assert {:ok, output} = Iconvex.convert(input, from, "UTF-8", options)
    output
  end

  defp stream(chunks, from, options) do
    assert {:ok, output} = Iconvex.stream(chunks, from, "UTF-8", options)
    output |> Enum.to_list() |> IO.iodata_to_binary()
  end

  defp assert_stream_error(chunks, from, kind, offset, sequence) do
    assert {:ok, output} = Iconvex.stream(chunks, from, "UTF-8")

    error =
      assert_raise Iconvex.Error, fn ->
        output |> Enum.to_list() |> IO.iodata_to_binary()
      end

    assert error.kind == kind
    assert error.encoding == from
    assert error.offset == offset
    assert error.sequence == sequence
  end

  defp assert_callback_recovery(operation, encoding, expected_events, expected_output) do
    owner = self()
    reference = make_ref()

    handler = fn event ->
      send(owner, {reference, event})
      {:replace, "!"}
    end

    assert operation.(handler) == expected_output

    events = receive_events(reference, [])

    assert Enum.map(events, &{&1.offset, &1.sequence}) == expected_events

    for %Iconvex.InvalidByte{encoding: actual, kind: kind, byte: byte, sequence: sequence} <-
          events do
      assert actual == encoding
      assert kind == :invalid_sequence
      assert byte == :binary.first(sequence)
    end
  end

  defp receive_events(reference, acc) do
    receive do
      {^reference, %Iconvex.InvalidByte{} = event} -> receive_events(reference, [event | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp split_at(input, offset) do
    [
      binary_part(input, 0, offset),
      binary_part(input, offset, byte_size(input) - offset)
    ]
  end

  defp substituted_bytes(bytes) do
    bytes
    |> :binary.bin_to_list()
    |> Enum.map_join(&"<#{&1 |> Integer.to_string(16) |> String.pad_leading(2, "0")}>")
    |> String.upcase()
  end
end

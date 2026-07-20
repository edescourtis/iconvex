defmodule Iconvex.Specs.LMBCSPendingSurrogateRecoveryTest do
  use ExUnit.Case, async: false

  @profiles [
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

  @high_surrogate <<0x14, 0xD8, 0x00>>
  @malformed_control <<0x0F, 0x1F>>
  @low_surrogate <<0x14, 0xDC, 0x00>>

  test "a malformed unit cannot hide or bridge a pending LMBCS high surrogate" do
    input = @high_surrogate <> @malformed_control <> @low_surrogate <> "A"

    events = [
      {:invalid_sequence, 0, 0x14, @high_surrogate},
      {:invalid_sequence, 3, 0x0F, @malformed_control},
      {:invalid_sequence, 5, 0x14, @low_surrogate}
    ]

    for profile <- @profiles do
      encoding = profile.canonical_name()

      assert profile.decode(input) ==
               {:error, :invalid_sequence, 0, @high_surrogate},
             "#{encoding} native strict"

      assert profile.decode_discard(input) == {:ok, ~c"A"},
             "#{encoding} native discard"

      assert_convert_error(input, encoding, :invalid_sequence, 0, @high_surrogate)
      assert convert(input, encoding, invalid: :discard) == "A"
      assert convert(input, encoding, byte_substitute: "<%02X>") == substituted(input)

      assert_callback(
        fn handler -> convert(input, encoding, on_invalid_byte: handler) end,
        encoding,
        events,
        "!!!A"
      )

      for split <- 0..byte_size(input) do
        chunks = split_at(input, split)

        assert_stream_error(chunks, encoding, :invalid_sequence, 0, @high_surrogate)
        assert stream(chunks, encoding, invalid: :discard) == "A"
        assert stream(chunks, encoding, byte_substitute: "<%02X>") == substituted(input)

        assert_callback(
          fn handler -> stream(chunks, encoding, on_invalid_byte: handler) end,
          encoding,
          events,
          "!!!A"
        )
      end
    end
  end

  test "an incomplete unit after a pending LMBCS high surrogate is diagnosed second" do
    incomplete_control = <<0x0F>>
    input = @high_surrogate <> incomplete_control

    events = [
      {:invalid_sequence, 0, 0x14, @high_surrogate},
      {:incomplete_sequence, 3, 0x0F, incomplete_control}
    ]

    for profile <- @profiles do
      encoding = profile.canonical_name()

      assert profile.decode(input) ==
               {:error, :invalid_sequence, 0, @high_surrogate},
             "#{encoding} native strict"

      assert profile.decode_discard(input) == {:ok, []},
             "#{encoding} native discard"

      assert_convert_error(input, encoding, :invalid_sequence, 0, @high_surrogate)
      assert convert(input, encoding, invalid: :discard) == ""
      assert convert(input, encoding, byte_substitute: "<%02X>") == substituted(input)

      assert_callback(
        fn handler -> convert(input, encoding, on_invalid_byte: handler) end,
        encoding,
        events,
        "!!"
      )

      for split <- 0..byte_size(input) do
        chunks = split_at(input, split)

        assert_stream_error(chunks, encoding, :invalid_sequence, 0, @high_surrogate)
        assert stream(chunks, encoding, invalid: :discard) == ""
        assert stream(chunks, encoding, byte_substitute: "<%02X>") == substituted(input)

        assert_callback(
          fn handler -> stream(chunks, encoding, on_invalid_byte: handler) end,
          encoding,
          events,
          "!!"
        )
      end
    end
  end

  test "potential low-surrogate prefixes stay buffered but are final errors after a pending high" do
    for follower <- [<<0x14>>, <<0x14, 0xF6>>, <<0x14, 0xDC>>], profile <- @profiles do
      input = @high_surrogate <> follower
      encoding = profile.canonical_name()

      events = [
        {:invalid_sequence, 0, 0x14, @high_surrogate},
        {:incomplete_sequence, 3, 0x14, follower}
      ]

      assert profile.decode(input) == {:error, :invalid_sequence, 0, @high_surrogate}
      assert profile.decode_chunk(input, false) == {:ok, [], input}
      assert profile.decode_chunk(input, true) == {:error, :invalid_sequence, 0, @high_surrogate}
      assert profile.decode_discard(input) == {:ok, []}

      assert_convert_error(input, encoding, :invalid_sequence, 0, @high_surrogate)
      assert convert(input, encoding, invalid: :discard) == ""
      assert convert(input, encoding, byte_substitute: "<%02X>") == substituted(input)

      assert_callback(
        fn handler -> convert(input, encoding, on_invalid_byte: handler) end,
        encoding,
        events,
        "!!"
      )

      for split <- 0..byte_size(input) do
        chunks = split_at(input, split)

        assert_stream_error(chunks, encoding, :invalid_sequence, 0, @high_surrogate)
        assert stream(chunks, encoding, invalid: :discard) == ""
        assert stream(chunks, encoding, byte_substitute: "<%02X>") == substituted(input)

        assert_callback(
          fn handler -> stream(chunks, encoding, on_invalid_byte: handler) end,
          encoding,
          events,
          "!!"
        )
      end
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

  defp assert_convert_error(input, from, kind, offset, sequence) do
    assert {:error,
            %Iconvex.Error{
              kind: ^kind,
              encoding: ^from,
              offset: ^offset,
              sequence: ^sequence
            }} = Iconvex.convert(input, from, "UTF-8")
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

  defp assert_callback(operation, encoding, expected_events, expected_output) do
    owner = self()
    reference = make_ref()

    handler = fn event ->
      send(owner, {reference, event})
      {:replace, "!"}
    end

    assert operation.(handler) == expected_output

    events = receive_events(reference, [])

    assert Enum.all?(events, &(&1.encoding == encoding))

    actual_events = Enum.map(events, &{&1.kind, &1.offset, &1.byte, &1.sequence})

    assert actual_events == expected_events
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

  defp substituted(input) do
    input
    |> :binary.bin_to_list()
    |> Enum.map_join(fn
      ?A -> "A"
      byte -> "<#{byte |> Integer.to_string(16) |> String.pad_leading(2, "0")}>"
    end)
    |> String.upcase()
  end
end

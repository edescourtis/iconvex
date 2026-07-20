defmodule Iconvex.UTF7Test do
  use ExUnit.Case, async: true

  @fixtures Path.expand("fixtures/gnu-libiconv-1.19", __DIR__)

  test "GNU libiconv 1.19 UTF-7 snippet decodes and re-encodes" do
    encoded = File.read!(Path.join(@fixtures, "UTF-7-snippet"))
    utf8 = File.read!(Path.join(@fixtures, "UTF-7-snippet.UTF-8"))

    assert Iconvex.convert(encoded, "UTF-7", "UTF-8") == {:ok, utf8}
    assert Iconvex.convert(utf8, "UTF-8", "UTF-7") == {:ok, encoded}
  end

  test "UTF-7 handles direct characters, plus, and surrogate pairs" do
    assert Iconvex.convert("A+-+2D3eAA-", "UTF-7", "UTF-8") == {:ok, "A+😀"}
    assert Iconvex.convert("A+😀", "UTF-8", "UTF-7") == {:ok, "A+-+2D3eAA-"}
  end

  test "UTF-7 rejects malformed base64 shifts" do
    assert {:error, %Iconvex.Error{kind: :invalid_sequence, offset: 1}} =
             Iconvex.convert("+A-", "UTF-7", "UTF-8")
  end

  test "UTF-7 Stream withholds shifted output until its padding is validated" do
    parent = self()

    source =
      ["+AEJ", "!"]
      |> Stream.map(fn chunk ->
        send(parent, {:read_malformed_utf7, chunk})
        chunk
      end)

    error =
      assert_raise Iconvex.Error, fn ->
        source
        |> Iconvex.stream!("UTF-7", "UTF-8")
        |> Enum.take(1)
      end

    assert error.kind == :invalid_sequence
    assert error.offset == 0
    assert error.sequence == "+AEJ"
    assert_received {:read_malformed_utf7, "+AEJ"}
    assert_received {:read_malformed_utf7, "!"}
  end

  test "UTF-7 Stream releases a valid shifted run at an implicit close without over-reading" do
    parent = self()

    source =
      ["+AEI", "!", "tail"]
      |> Stream.map(fn chunk ->
        send(parent, {:read_valid_utf7, chunk})
        chunk
      end)

    assert source
           |> Iconvex.stream!("UTF-7", "UTF-8")
           |> Enum.take(1) == ["B!"]

    assert_received {:read_valid_utf7, "+AEI"}
    assert_received {:read_valid_utf7, "!"}
    refute_received {:read_valid_utf7, "tail"}

    assert ["+AEI"] |> Iconvex.stream!("UTF-7", "UTF-8") |> Enum.join() == "B"
  end

  test "UTF-7 Stream malformed recovery is one-shot exact at every split" do
    for input <- ["+A!", "+AEJ!", "+AEIA", "+B"] do
      assert {:ok, discarded} =
               Iconvex.convert(input, "UTF-7", "UTF-8", invalid: :discard)

      assert {:ok, substituted} =
               Iconvex.convert(input, "UTF-7", "UTF-8", byte_substitute: "<%02x>")

      for split <- 0..byte_size(input) do
        <<first::binary-size(split), second::binary>> = input

        assert [first, second]
               |> Iconvex.stream!("UTF-7", "UTF-8", invalid: :discard)
               |> Enum.join() == discarded,
               "discard input #{inspect(input)} split #{split}"

        assert [first, second]
               |> Iconvex.stream!("UTF-7", "UTF-8", byte_substitute: "<%02x>")
               |> Enum.join() == substituted,
               "substitute input #{inspect(input)} split #{split}"
      end
    end
  end

  test "UTF-7 one-shot callbacks recover malformed shifts exactly like Stream" do
    for {input, sequence, expected} <- [
          {"+A!", "+A", "?A!"},
          {"+AEJ!", "+AEJ", "?AEJ!"},
          {"+B", "+B", "?B"}
        ] do
      parent = self()

      one_shot_callback = fn event ->
        send(parent, {:one_shot_utf7_invalid, input, event})
        {:replace, "?"}
      end

      assert Iconvex.convert(input, "UTF-7", "UTF-8", on_invalid_byte: one_shot_callback) ==
               {:ok, expected}

      assert_received {:one_shot_utf7_invalid, ^input, %Iconvex.InvalidByte{} = one_shot_event}

      stream_callback = fn event ->
        send(parent, {:stream_utf7_invalid, input, event})
        {:replace, "?"}
      end

      assert [input]
             |> Iconvex.stream!("UTF-7", "UTF-8", on_invalid_byte: stream_callback)
             |> Enum.join() == expected

      assert_received {:stream_utf7_invalid, ^input, %Iconvex.InvalidByte{} = stream_event}
      assert one_shot_event == stream_event

      assert %Iconvex.InvalidByte{
               kind: :invalid_sequence,
               offset: 0,
               byte: ?+,
               sequence: ^sequence
             } = one_shot_event

      assert {:error, %Iconvex.Error{} = one_shot_error} =
               Iconvex.convert(input, "UTF-7", "UTF-8", on_invalid_byte: fn _ -> :error end)

      stream_error =
        assert_raise Iconvex.Error, fn ->
          [input]
          |> Iconvex.stream!("UTF-7", "UTF-8", on_invalid_byte: fn _ -> :error end)
          |> Enum.to_list()
        end

      assert {one_shot_error.kind, one_shot_error.offset, one_shot_error.sequence} ==
               {stream_error.kind, stream_error.offset, stream_error.sequence}
    end
  end

  test "UTF-7 empty-shift callbacks frame only the introducer at every split" do
    for {input, expected_output, expected_events} <- [
          {"+!", "?!", [{:invalid_sequence, 0, ?+, "+"}]},
          {<<?+, 0x80>>, "??",
           [
             {:invalid_sequence, 0, ?+, "+"},
             {:invalid_sequence, 1, 0x80, <<0x80>>}
           ]}
        ] do
      assert {:error,
              %Iconvex.Error{
                kind: :invalid_sequence,
                offset: 0,
                sequence: "+"
              }} = Iconvex.convert(input, "UTF-7", "UTF-8")

      for split <- 0..byte_size(input) do
        <<left::binary-size(split), right::binary>> = input

        error =
          assert_raise Iconvex.Error, fn ->
            [left, right]
            |> Iconvex.stream!("UTF-7", "UTF-8")
            |> Enum.to_list()
          end

        assert {error.kind, error.offset, error.sequence} ==
                 {:invalid_sequence, 0, "+"}
      end

      {one_shot_output, one_shot_events} = capture_utf7_callback(input, :one_shot)
      assert one_shot_output == expected_output
      assert event_frames(one_shot_events) == expected_events

      for split <- 0..byte_size(input) do
        {stream_output, stream_events} = capture_utf7_callback(input, {:stream, split})
        assert stream_output == expected_output
        assert stream_events == one_shot_events
      end
    end
  end

  test "UTF-7 callback framing is one-shot exact for every short malformed split" do
    alphabet = [?+, ?-, ?A, ?!, 0x80]

    for size <- 0..4,
        input <- fixed_width_binaries(alphabet, size) do
      {one_shot_output, one_shot_events} = capture_utf7_callback(input, :one_shot)

      for split <- 0..byte_size(input) do
        assert capture_utf7_callback(input, {:stream, split}) ==
                 {one_shot_output, one_shot_events},
               "UTF-7 callback parity for #{inspect(input)} at split #{split}"
      end
    end
  end

  test "UTF-7 Stream callback receives the shift introducer and original source bytes" do
    for split <- 0..byte_size("+A!") do
      parent = self()
      <<first::binary-size(split), second::binary>> = "+A!"

      output =
        [first, second]
        |> Iconvex.stream!("UTF-7", "UTF-8",
          on_invalid_byte: fn event ->
            send(parent, {:utf7_invalid, split, event})
            {:replace, "<+>"}
          end
        )
        |> Enum.join()

      assert output == "<+>A!"

      assert_received {:utf7_invalid, ^split,
                       %Iconvex.InvalidByte{
                         kind: :invalid_sequence,
                         offset: 0,
                         byte: ?+,
                         sequence: "+A"
                       }}
    end
  end

  test "UTF-7 Stream strict failures retain original shifted source at every split" do
    for {input, sequence} <- [
          {"+AEJ!", "+AEJ"},
          {"+AEIA", "+AEIA"},
          {"+B", "+B"},
          {"+3AA-", "+3AA"},
          {"+2AAAQQ-", "+2AAAQQ"}
        ],
        split <- 0..byte_size(input) do
      <<first::binary-size(split), second::binary>> = input

      error =
        assert_raise Iconvex.Error, fn ->
          [first, second]
          |> Iconvex.stream!("UTF-7", "UTF-8")
          |> Enum.to_list()
        end

      assert error.kind == :invalid_sequence
      assert error.offset == 0
      assert error.sequence == sequence
    end
  end

  test "UTF-7 incremental state owns an open shift without replay pending" do
    {state, offset} =
      "+AEI"
      |> :binary.bin_to_list()
      |> Enum.reduce({Iconvex.UTF7Codec.stream_init(), 0}, fn byte, {state, offset} ->
        assert {:ok, [], next_state, <<>>} =
                 Iconvex.UTF7Codec.decode_chunk(<<byte>>, state, false, offset)

        {next_state, offset + 1}
      end)

    assert {:ok, ~c"B", %{mode: :direct}, <<>>} =
             Iconvex.UTF7Codec.decode_chunk(<<>>, state, true, offset)
  end

  test "UTF-7 byte-at-a-time decoding keeps bounded linear reduction scaling" do
    small = byte_at_a_time_reductions(1_000)
    large = byte_at_a_time_reductions(2_000)

    # Doubling the shifted source may double useful decoding work. This leaves
    # another 50% margin for GC and scheduler-independent BEAM bookkeeping,
    # while rejecting the previous growing-prefix replay (about 3.5x here).
    assert large < small * 3
  end

  test "UTF-7 byte-at-a-time strict and recovery paths replay malformed source once" do
    input = "+AEJ!"
    chunks = for <<byte <- input>>, do: <<byte>>

    error =
      assert_raise Iconvex.Error, fn ->
        chunks
        |> Iconvex.stream!("UTF-7", "UTF-8")
        |> Enum.to_list()
      end

    assert {error.kind, error.offset, error.sequence} == {:invalid_sequence, 0, "+AEJ"}

    assert chunks
           |> Iconvex.stream!("UTF-7", "UTF-8", invalid: :discard)
           |> Enum.join() == "AEJ!"

    assert chunks
           |> Iconvex.stream!("UTF-7", "UTF-8", byte_substitute: "<%02x>")
           |> Enum.join() == "<2b>AEJ!"

    parent = self()

    assert chunks
           |> Iconvex.stream!("UTF-7", "UTF-8",
             on_invalid_byte: fn event ->
               send(parent, {:utf7_byte_at_a_time_invalid, event})
               {:replace, "<+>"}
             end
           )
           |> Enum.join() == "<+>AEJ!"

    assert_received {:utf7_byte_at_a_time_invalid,
                     %Iconvex.InvalidByte{
                       kind: :invalid_sequence,
                       offset: 0,
                       byte: ?+,
                       sequence: "+AEJ"
                     }}

    refute_received {:utf7_byte_at_a_time_invalid, _duplicate}
  end

  test "UTF-7 byte-at-a-time implicit and explicit closes release exactly once" do
    for input <- ["+AEI!", "+AEI-"] do
      chunks = for <<byte <- input>>, do: <<byte>>

      expected = if String.ends_with?(input, "!"), do: "B!", else: "B"

      assert chunks
             |> Iconvex.stream!("UTF-7", "UTF-8")
             |> Enum.join() == expected
    end
  end

  defp byte_at_a_time_reductions(codepoint_count) do
    expected = String.duplicate("é", codepoint_count)
    assert {:ok, encoded} = Iconvex.convert(expected, "UTF-8", "UTF-7")
    chunks = for <<byte <- encoded>>, do: <<byte>>

    task =
      Task.async(fn ->
        {:reductions, before} = Process.info(self(), :reductions)

        assert chunks
               |> Iconvex.stream!("UTF-7", "UTF-8")
               |> Enum.join() == expected

        {:reductions, after_decode} = Process.info(self(), :reductions)
        after_decode - before
      end)

    Task.await(task, 30_000)
  end

  defp capture_utf7_callback(input, mode) do
    owner = self()
    reference = make_ref()

    callback = fn event ->
      send(owner, {reference, event})
      {:replace, "?"}
    end

    output =
      case mode do
        :one_shot ->
          assert {:ok, converted} =
                   Iconvex.convert(input, "UTF-7", "UTF-8", on_invalid_byte: callback)

          converted

        {:stream, split} ->
          <<left::binary-size(split), right::binary>> = input

          [left, right]
          |> Iconvex.stream!("UTF-7", "UTF-8", on_invalid_byte: callback)
          |> Enum.join()
      end

    {output, collect_utf7_events(reference, [])}
  end

  defp collect_utf7_events(reference, acc) do
    receive do
      {^reference, %Iconvex.InvalidByte{} = event} ->
        collect_utf7_events(reference, [event | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp event_frames(events) do
    Enum.map(events, &{&1.kind, &1.offset, &1.byte, &1.sequence})
  end

  defp fixed_width_binaries(_alphabet, 0), do: [<<>>]

  defp fixed_width_binaries(alphabet, size) do
    for prefix <- fixed_width_binaries(alphabet, size - 1),
        byte <- alphabet,
        do: prefix <> <<byte>>
  end
end

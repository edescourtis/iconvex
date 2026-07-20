defmodule Iconvex.StatefulCallbackRecoveryTest do
  use ExUnit.Case, async: false

  @fixtures [
    {"HZ", "~{VPND~}", 4, "中", "文"},
    {"ISO-2022-KR", <<0x1B, "$)C", 0x0E, "GQ1[", 0x0F>>, 7, "한", "글"},
    {"ISO-2022-JP", <<0x1B, "$BF|K\\", 0x1B, "(B">>, 5, "日", "本"},
    {"ISO-2022-JP-1", <<0x1B, "$BF|K\\", 0x1B, "(B">>, 5, "日", "本"},
    {"ISO-2022-JP-2", <<0x1B, "$BF|K\\", 0x1B, "(B">>, 5, "日", "本"},
    {"ISO-2022-JP-MS", <<0x1B, "$BF|K\\", 0x1B, "(B">>, 5, "日", "本"},
    {"ISO-2022-CN", <<0x1B, "$)A", 0x0E, "VPND", 0x0F>>, 7, "中", "文"},
    {"ISO-2022-CN-EXT", <<0x1B, "$)A", 0x0E, "VPND", 0x0F>>, 7, "中", "文"}
  ]

  test "callback default discard retains state in one-shot and every Stream split" do
    for fixture <- @fixtures do
      assert_policy_parity(fixture, :default, [invalid: :discard], fn left, right ->
        left <> right
      end)
    end
  end

  test "callback default byte substitution retains state in one-shot and every Stream split" do
    for fixture <- @fixtures do
      assert_policy_parity(fixture, :default, [byte_substitute: "<%02x>"], fn left, right ->
        left <> "<ff>" <> right
      end)
    end
  end

  test "callback replacement retains state in one-shot and every Stream split" do
    for fixture <- @fixtures do
      assert_policy_parity(fixture, {:replace, "?"}, [], fn left, right ->
        left <> "?" <> right
      end)
    end
  end

  test "callback discard decision retains state in one-shot and every Stream split" do
    for fixture <- @fixtures do
      assert_policy_parity(fixture, :discard, [], fn left, right -> left <> right end)
    end
  end

  test "stateful source preserves an earlier target error before a later callback" do
    owner = self()
    call = make_ref()
    valid = <<0x1B, "$BF|K\\", 0x1B, "(B">>
    input = insert_invalid(valid, 5)

    handler = fn event ->
      send(owner, {call, event})
      :discard
    end

    assert {:error,
            %Iconvex.Error{
              kind: :unrepresentable_character,
              encoding: "US-ASCII",
              codepoint: 0x65E5
            }} = Iconvex.convert(input, "ISO-2022-JP", "ASCII", on_invalid_byte: handler)

    refute_received {^call, _event}

    for split <- 0..byte_size(input) do
      chunks = [
        binary_part(input, 0, split),
        binary_part(input, split, byte_size(input) - split)
      ]

      error =
        assert_raise Iconvex.Error, fn ->
          chunks
          |> Iconvex.stream!("ISO-2022-JP", "ASCII", on_invalid_byte: handler)
          |> Enum.to_list()
        end

      assert error.kind == :unrepresentable_character
      assert error.encoding == "US-ASCII"
      assert error.codepoint == 0x65E5
      refute_received {^call, _event}
    end
  end

  test "multiple callback recoveries retain state and absolute offsets" do
    for {encoding, valid, invalid_offset, left, right} <- @fixtures do
      <<prefix::binary-size(invalid_offset), second_character::binary-size(2), suffix::binary>> =
        valid

      input = prefix <> <<0xFF>> <> second_character <> <<0xFE>> <> suffix
      expected = left <> right
      expected_offsets = [invalid_offset, invalid_offset + 3]

      assert_multiple_recovery(
        fn handler -> Iconvex.convert(input, encoding, "UTF-8", on_invalid_byte: handler) end,
        {:ok, expected},
        expected_offsets
      )

      for split <- 0..byte_size(input) do
        chunks = [
          binary_part(input, 0, split),
          binary_part(input, split, byte_size(input) - split)
        ]

        assert_multiple_recovery(
          fn handler ->
            chunks
            |> Iconvex.stream!(encoding, "UTF-8", on_invalid_byte: handler)
            |> Enum.join()
          end,
          expected,
          expected_offsets
        )
      end
    end
  end

  test "invalid callback returns retain one-shot and Stream error semantics" do
    {encoding, valid, invalid_offset, _left, _right} =
      Enum.find(@fixtures, fn {name, _valid, _offset, _left, _right} ->
        name == "ISO-2022-JP"
      end)

    input = insert_invalid(valid, invalid_offset)
    handler = fn _event -> :invalid_decision end

    assert {:error, {:invalid_callback_return, :on_invalid_byte, :invalid_decision}} =
             Iconvex.convert(input, encoding, "UTF-8", on_invalid_byte: handler)

    for split <- 0..byte_size(input) do
      chunks = [
        binary_part(input, 0, split),
        binary_part(input, split, byte_size(input) - split)
      ]

      assert_raise ArgumentError,
                   "invalid streaming callback result: " <>
                     "{:invalid_callback_return, :on_invalid_byte, :invalid_decision}",
                   fn ->
                     chunks
                     |> Iconvex.stream!(encoding, "UTF-8", on_invalid_byte: handler)
                     |> Enum.to_list()
                   end
    end
  end

  defp assert_policy_parity(
         {encoding, valid, invalid_offset, left, right},
         decision,
         options,
         expected
       ) do
    input = insert_invalid(valid, invalid_offset)
    expected = expected.(left, right)

    assert_recovery(
      fn handler ->
        Iconvex.convert(input, encoding, "UTF-8", options ++ [on_invalid_byte: handler])
      end,
      {:ok, expected},
      encoding,
      invalid_offset,
      decision
    )

    for split <- 0..byte_size(input) do
      chunks = [
        binary_part(input, 0, split),
        binary_part(input, split, byte_size(input) - split)
      ]

      assert_recovery(
        fn handler ->
          chunks
          |> Iconvex.stream!(encoding, "UTF-8", options ++ [on_invalid_byte: handler])
          |> Enum.join()
        end,
        expected,
        encoding,
        invalid_offset,
        decision
      )
    end
  end

  defp assert_recovery(convert, expected, encoding, invalid_offset, decision) do
    owner = self()
    call = make_ref()

    handler = fn event ->
      send(owner, {call, event})
      decision
    end

    assert convert.(handler) == expected

    assert_received {^call,
                     %Iconvex.InvalidByte{
                       encoding: ^encoding,
                       kind: :invalid_sequence,
                       offset: ^invalid_offset,
                       byte: 0xFF,
                       sequence: <<0xFF, _rest::binary>>
                     }}

    refute_received {^call, _unexpected_second_event}
  end

  defp assert_multiple_recovery(convert, expected, expected_offsets) do
    owner = self()
    call = make_ref()

    handler = fn event ->
      send(owner, {call, event.offset})
      :discard
    end

    assert convert.(handler) == expected

    for offset <- expected_offsets do
      assert_received {^call, ^offset}
    end

    refute_received {^call, _unexpected_offset}
  end

  defp insert_invalid(valid, offset) do
    <<prefix::binary-size(offset), suffix::binary>> = valid
    prefix <> <<0xFF>> <> suffix
  end
end

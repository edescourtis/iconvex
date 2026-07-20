defmodule Iconvex.Telecom.SIMAlphaRecoveryTest do
  use ExUnit.Case, async: false

  alias Iconvex.Telecom.{SIMAlphaIdentifier, SIMAlphaIdentifierCodec}

  @input <<0x80, 0xD8, 0x00, 0x00, 0x41>>
  @invalid_unit <<0xD8, 0x00>>
  @compressed_input <<0x82, 3, 0xD8, 0x00, 0x80, 0x41, 0x42>>
  @compressed_missing_payload [<<0x81, 2, 0x00, ?A>>, <<0x82, 2, 0x00, 0x00, ?A>>]
  @surrogate_before_odd_tail <<0x80, 0xD8, 0x00, 0x00>>
  @boundary_gsm_prefix <<0x83, 0x80, 0x00>> <> :binary.copy("A", 252)
  @overlong_boundary_gsm @boundary_gsm_prefix <> "B"

  test "invalid first GSM octet commits recovery before later 0x80/0x81/0x82 bytes" do
    for reserved_header <- [0x80, 0x81, 0x82] do
      input = <<0x83, reserved_header, 0x00, ?A>>
      expected = "@A"
      header_hex = reserved_header |> Integer.to_string(16) |> String.pad_leading(2, "0")
      substitute_expected = "<83><#{header_hex}>@A"
      events = [{0, 0x83, <<0x83>>}, {1, reserved_header, <<reserved_header>>}]

      assert SIMAlphaIdentifierCodec.decode(input) ==
               {:error, :invalid_sequence, 0, <<0x83>>}

      assert SIMAlphaIdentifierCodec.decode_discard(input) ==
               {:ok, String.to_charlist(expected)}

      assert source_result(input, :one_shot, []) ==
               {:error, :invalid_sequence, 0, <<0x83>>}

      assert source_result(input, :one_shot, invalid: :discard) == {:ok, expected}

      assert source_result(input, :one_shot, byte_substitute: "<%02x>") ==
               {:ok, substitute_expected}

      assert callback_source_result(input, :one_shot, :discard) ==
               {{:ok, expected}, events}

      assert callback_source_result(input, :one_shot, {:replace, "?"}) ==
               {{:ok, "??@A"}, events}

      for split <- 0..byte_size(input) do
        assert source_result(input, split, []) ==
                 {:error, :invalid_sequence, 0, <<0x83>>}

        assert source_result(input, split, invalid: :discard) == {:ok, expected}

        assert source_result(input, split, byte_substitute: "<%02x>") ==
                 {:ok, substitute_expected}

        assert callback_source_result(input, split, :discard) == {{:ok, expected}, events}

        assert callback_source_result(input, split, {:replace, "?"}) ==
                 {{:ok, "??@A"}, events}
      end
    end
  end

  test "initial GSM recovery and first-error ordering hold at the 255/256-byte boundary" do
    assert byte_size(@boundary_gsm_prefix) == 255
    assert byte_size(@overlong_boundary_gsm) == 256

    expected = "@" <> :binary.copy("A", 252)
    substitute_expected = "<83><80>" <> expected <> "<42>"
    callback_expected = "??" <> expected <> "?"

    assert SIMAlphaIdentifierCodec.decode(@overlong_boundary_gsm) ==
             {:error, :invalid_sequence, 0, <<0x83>>}

    assert SIMAlphaIdentifierCodec.decode_discard(@overlong_boundary_gsm) ==
             {:ok, String.to_charlist(expected)}

    for split <- 0..byte_size(@overlong_boundary_gsm) do
      assert source_result(@overlong_boundary_gsm, split, []) ==
               {:error, :invalid_sequence, 0, <<0x83>>}

      assert source_result(@overlong_boundary_gsm, split, invalid: :discard) ==
               {:ok, expected}

      assert source_result(@overlong_boundary_gsm, split, byte_substitute: "<%02x>") ==
               {:ok, substitute_expected}

      assert callback_source_result(@overlong_boundary_gsm, split, {:replace, "?"}) ==
               {{:ok, callback_expected},
                [
                  {0, 0x83, <<0x83>>},
                  {1, 0x80, <<0x80>>},
                  {255, ?B, "B"}
                ]}
    end
  end

  test "0x80 decoding reports an earlier surrogate before an odd terminal byte" do
    assert SIMAlphaIdentifier.decode(@surrogate_before_odd_tail) ==
             {:error, {:invalid_ucs2, 0xD800}}

    assert SIMAlphaIdentifierCodec.decode(@surrogate_before_odd_tail) ==
             {:error, :invalid_sequence, 1, <<0xD8, 0x00>>}

    assert SIMAlphaIdentifierCodec.decode_to_utf8(@surrogate_before_odd_tail) ==
             {:error, :invalid_sequence, 1, <<0xD8, 0x00>>}
  end

  test "one-shot conversion reports the earlier 0x80 surrogate" do
    assert {:error,
            %Iconvex.Error{
              kind: :invalid_sequence,
              encoding: "SIM-ALPHA-IDENTIFIER",
              offset: 1,
              sequence: <<0xD8, 0x00>>
            }} =
             Iconvex.convert(
               @surrogate_before_odd_tail,
               SIMAlphaIdentifierCodec,
               "UTF-8"
             )
  end

  test "every stream split reports the earlier 0x80 surrogate" do
    for split <- 0..byte_size(@surrogate_before_odd_tail) do
      error =
        assert_raise Iconvex.Error, fn ->
          @surrogate_before_odd_tail
          |> split_at(split)
          |> Iconvex.stream!(SIMAlphaIdentifierCodec, "UTF-8")
          |> Enum.to_list()
        end

      assert %Iconvex.Error{
               kind: :invalid_sequence,
               encoding: "SIM-ALPHA-IDENTIFIER",
               offset: 1,
               sequence: <<0xD8, 0x00>>
             } = error
    end
  end

  test "UCS-2 discard and replacement preserve the 0x80 frame and suffix" do
    assert SIMAlphaIdentifierCodec.decode_discard(@input) == {:ok, [?A]}

    assert Iconvex.convert(@input, SIMAlphaIdentifierCodec, "UTF-8", invalid: :discard) ==
             {:ok, "A"}

    assert Iconvex.convert(@input, SIMAlphaIdentifierCodec, "UTF-8", byte_substitute: "<%02x>") ==
             {:ok, "<d8><00>A"}

    assert_callback_result(:discard, "A", :one_shot)
    assert_callback_result({:replace, "?"}, "?A", :one_shot)
  end

  test "every stream split retains UCS-2 mode through invalid-unit recovery" do
    for split <- 0..byte_size(@input) do
      assert stream_join(split, invalid: :discard) == "A"
      assert stream_join(split, byte_substitute: "<%02x>") == "<d8><00>A"
      assert_callback_result(:discard, "A", split)
      assert_callback_result({:replace, "?"}, "?A", split)
    end
  end

  test "compressed recovery advances the declared payload length before its suffix" do
    assert SIMAlphaIdentifierCodec.decode_discard(@compressed_input) == {:ok, ~c"AB"}

    assert Iconvex.convert(
             @compressed_input,
             SIMAlphaIdentifierCodec,
             "UTF-8",
             byte_substitute: "<%02x>"
           ) == {:ok, "<80>AB"}

    for split <- 0..byte_size(@compressed_input) do
      assert compressed_stream_join(split, invalid: :discard) == "AB"
      assert compressed_stream_join(split, byte_substitute: "<%02x>") == "<80>AB"
    end
  end

  test "compressed discard retains its prefix when the final declared payload byte is absent" do
    for input <- @compressed_missing_payload do
      assert SIMAlphaIdentifierCodec.decode_discard(input) == {:ok, [?A]}

      assert Iconvex.convert(input, SIMAlphaIdentifierCodec, "UTF-8", invalid: :discard) ==
               {:ok, "A"}

      for split <- 0..byte_size(input) do
        assert input
               |> split_at(split)
               |> Iconvex.stream!(SIMAlphaIdentifierCodec, "UTF-8", invalid: :discard)
               |> Enum.join() == "A"
      end
    end
  end

  test "an absent compressed payload byte remains an error for other policies" do
    parent = self()

    callback = fn event ->
      send(parent, {:unexpected_missing_payload_callback, event})
      :discard
    end

    for input <- @compressed_missing_payload do
      expected_offset = byte_size(input)

      assert SIMAlphaIdentifierCodec.decode(input) ==
               {:error, :incomplete_sequence, expected_offset, <<>>}

      assert SIMAlphaIdentifierCodec.decode_to_utf8(input) ==
               {:error, :incomplete_sequence, expected_offset, <<>>}

      for options <- [[], [byte_substitute: "<%02x>"], [on_invalid_byte: callback]] do
        assert {:error,
                %Iconvex.Error{
                  kind: :incomplete_sequence,
                  encoding: "SIM-ALPHA-IDENTIFIER",
                  offset: ^expected_offset,
                  sequence: <<>>
                }} = Iconvex.convert(input, SIMAlphaIdentifierCodec, "UTF-8", options)

        for split <- 0..byte_size(input) do
          error =
            assert_raise Iconvex.Error, fn ->
              input
              |> split_at(split)
              |> Iconvex.stream!(SIMAlphaIdentifierCodec, "UTF-8", options)
              |> Enum.to_list()
            end

          assert %Iconvex.Error{
                   kind: :incomplete_sequence,
                   encoding: "SIM-ALPHA-IDENTIFIER",
                   offset: ^expected_offset,
                   sequence: <<>>
                 } = error
        end
      end
    end

    refute_receive {:unexpected_missing_payload_callback, _event}
  end

  test "all four SIM forms and the buffered target remain split-invariant" do
    cases = [
      {<<0x41, 0x42, 0xFF, 0xFF>>, "AB"},
      {<<0x80, 0x00, 0x41, 0x04, 0x10>>, "AА"},
      {<<0x81, 2, 0x08, 0x41, 0x90, 0xFF>>, "AА"},
      {<<0x82, 2, 0x04, 0x00, 0x41, 0x90, 0xFF>>, "AА"}
    ]

    for {input, expected} <- cases, split <- 0..byte_size(input) do
      assert input
             |> split_at(split)
             |> Iconvex.stream!(SIMAlphaIdentifierCodec, "UTF-8")
             |> Enum.join() == expected
    end

    utf8 = "AА"
    assert {:ok, expected_encoding} = Iconvex.convert(utf8, "UTF-8", SIMAlphaIdentifierCodec)

    for split <- 0..byte_size(utf8) do
      assert utf8
             |> split_at(split)
             |> Iconvex.stream!("UTF-8", SIMAlphaIdentifierCodec)
             |> Enum.join() == expected_encoding
    end
  end

  defp assert_callback_result(decision, expected, mode) do
    parent = self()
    tag = make_ref()

    callback = fn event ->
      send(parent, {tag, event})
      decision
    end

    result =
      case mode do
        :one_shot ->
          assert {:ok, output} =
                   Iconvex.convert(@input, SIMAlphaIdentifierCodec, "UTF-8",
                     on_invalid_byte: callback
                   )

          output

        split ->
          stream_join(split, on_invalid_byte: callback)
      end

    assert result == expected

    assert_receive {^tag,
                    %Iconvex.InvalidByte{
                      encoding: "SIM-ALPHA-IDENTIFIER",
                      kind: :invalid_sequence,
                      offset: 1,
                      byte: 0xD8,
                      sequence: @invalid_unit
                    }}

    refute_receive {^tag, _additional_event}
  end

  defp stream_join(split, options) do
    [
      binary_part(@input, 0, split),
      binary_part(@input, split, byte_size(@input) - split)
    ]
    |> Iconvex.stream!(SIMAlphaIdentifierCodec, "UTF-8", options)
    |> Enum.join()
  end

  defp compressed_stream_join(split, options) do
    [
      binary_part(@compressed_input, 0, split),
      binary_part(@compressed_input, split, byte_size(@compressed_input) - split)
    ]
    |> Iconvex.stream!(SIMAlphaIdentifierCodec, "UTF-8", options)
    |> Enum.join()
  end

  defp source_result(input, :one_shot, options) do
    case Iconvex.convert(input, SIMAlphaIdentifierCodec, "UTF-8", options) do
      {:error, %Iconvex.Error{} = error} ->
        {:error, error.kind, error.offset, error.sequence}

      result ->
        result
    end
  end

  defp source_result(input, split, options) when is_integer(split) do
    try do
      {:ok,
       input
       |> split_at(split)
       |> Iconvex.stream!(SIMAlphaIdentifierCodec, "UTF-8", options)
       |> Enum.join()}
    rescue
      error in Iconvex.Error -> {:error, error.kind, error.offset, error.sequence}
    end
  end

  defp callback_source_result(input, mode, decision) do
    key = {:sim_initial_recovery_events, make_ref()}
    Process.put(key, [])

    callback = fn event ->
      frame = {event.offset, event.byte, event.sequence}
      Process.put(key, [frame | Process.get(key)])
      decision
    end

    result = source_result(input, mode, on_invalid_byte: callback)
    events = key |> Process.delete() |> Enum.reverse()
    {result, events}
  end

  defp split_at(input, split) do
    [
      binary_part(input, 0, split),
      binary_part(input, split, byte_size(input) - split)
    ]
  end
end

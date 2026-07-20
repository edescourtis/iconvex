defmodule Iconvex.Telecom.SIMAlphaBoundsTest do
  use ExUnit.Case, async: false

  alias Iconvex.Telecom.{SIMAlphaIdentifier, SIMAlphaIdentifierCodec}

  @max_bytes 255
  @max_gsm :binary.copy("A", @max_bytes)
  @overlong_gsm @max_gsm <> "BC"

  test "low-level APIs enforce the complete 255-byte record limit in every form" do
    assert SIMAlphaIdentifier.max_bytes() == @max_bytes
    assert SIMAlphaIdentifierCodec.max_bytes() == @max_bytes

    assert SIMAlphaIdentifier.decode(@max_gsm) == {:ok, @max_gsm}

    assert SIMAlphaIdentifier.decode(@max_gsm <> "B") ==
             {:error, {:alpha_identifier_too_long, 256}}

    assert SIMAlphaIdentifier.encode(@max_gsm) == {:ok, @max_gsm}

    assert SIMAlphaIdentifier.encode(@max_gsm <> "B") ==
             {:error, {:alpha_identifier_too_long, 256}}

    ucs2_max = String.duplicate(<<0x0100::utf8>>, 127)
    assert {:ok, encoded_ucs2} = SIMAlphaIdentifier.encode(ucs2_max, mode: :ucs2)
    assert byte_size(encoded_ucs2) == @max_bytes
    assert SIMAlphaIdentifier.decode(encoded_ucs2) == {:ok, ucs2_max}

    assert SIMAlphaIdentifier.encode(ucs2_max <> <<0x0100::utf8>>, mode: :ucs2) ==
             {:error, {:alpha_identifier_too_long, 257}}

    compressed_81_max = String.duplicate(<<0x0400::utf8>>, 252)

    assert {:ok, encoded_81} =
             SIMAlphaIdentifier.encode(compressed_81_max, mode: :compressed_81)

    assert byte_size(encoded_81) == @max_bytes
    assert SIMAlphaIdentifier.decode(encoded_81) == {:ok, compressed_81_max}

    assert SIMAlphaIdentifier.encode(
             compressed_81_max <> <<0x0400::utf8>>,
             mode: :compressed_81
           ) == {:error, {:alpha_identifier_too_long, 256}}

    compressed_82_max = String.duplicate(<<0x9000::utf8>>, 251)

    assert {:ok, encoded_82} =
             SIMAlphaIdentifier.encode(compressed_82_max, mode: :compressed_82)

    assert byte_size(encoded_82) == @max_bytes
    assert SIMAlphaIdentifier.decode(encoded_82) == {:ok, compressed_82_max}

    assert SIMAlphaIdentifier.encode(
             compressed_82_max <> <<0x9000::utf8>>,
             mode: :compressed_82
           ) == {:error, {:alpha_identifier_too_long, 256}}
  end

  test "target buffering is finite and overflow is the existing typed encode error" do
    state =
      Enum.reduce(1..@max_bytes, SIMAlphaIdentifierCodec.stream_encoder_init(), fn _, state ->
        assert {:ok, <<>>, next_state, []} =
                 SIMAlphaIdentifierCodec.encode_chunk([?A], state, false, :error)

        assert length(next_state) <= @max_bytes
        next_state
      end)

    assert length(state) == @max_bytes

    assert SIMAlphaIdentifierCodec.encode_chunk([?A], state, false, :error) ==
             {:error, :unrepresentable_character, ?A}

    assert {:ok, @max_gsm, [], []} =
             SIMAlphaIdentifierCodec.encode_chunk([], state, true, :error)

    codepoints = :binary.bin_to_list(@max_gsm <> "B")

    assert SIMAlphaIdentifierCodec.encode(codepoints) ==
             {:error, :unrepresentable_character, ?B}

    assert {:error,
            %Iconvex.Error{
              kind: :unrepresentable_character,
              encoding: "SIM-ALPHA-IDENTIFIER",
              codepoint: ?B
            }} = Iconvex.convert(@max_gsm <> "B", "UTF-8", SIMAlphaIdentifierCodec)

    for split <- 0..byte_size(@max_gsm <> "B") do
      error =
        assert_raise Iconvex.Error, fn ->
          (@max_gsm <> "B")
          |> split_at(split)
          |> Iconvex.stream!("UTF-8", SIMAlphaIdentifierCodec)
          |> Enum.to_list()
        end

      assert %Iconvex.Error{
               kind: :unrepresentable_character,
               encoding: "SIM-ALPHA-IDENTIFIER",
               codepoint: ?B
             } = error
    end
  end

  test "target discard and substitution stay bounded and deterministic" do
    emoji = 0x1F600

    assert {:ok, <<>>, [], []} =
             SIMAlphaIdentifierCodec.encode_chunk(
               List.duplicate(emoji, 10_000),
               SIMAlphaIdentifierCodec.stream_encoder_init(),
               false,
               :discard
             )

    replacement = fn ^emoji -> [?A] end

    assert {:ok, <<>>, replacement_state, []} =
             SIMAlphaIdentifierCodec.encode_chunk(
               List.duplicate(emoji, @max_bytes),
               SIMAlphaIdentifierCodec.stream_encoder_init(),
               false,
               {:replace, replacement}
             )

    assert length(replacement_state) == @max_bytes

    assert SIMAlphaIdentifierCodec.encode_chunk(
             [emoji],
             replacement_state,
             false,
             {:replace, replacement}
           ) == {:error, :unrepresentable_character, ?A}

    assert Iconvex.convert(
             :binary.copy(<<emoji::utf8>>, 10_000),
             "UTF-8",
             SIMAlphaIdentifierCodec,
             unrepresentable: :discard
           ) == {:ok, <<>>}

    substituted = :binary.copy(<<emoji::utf8>>, @max_bytes + 1)

    assert {:error,
            %Iconvex.Error{
              kind: :unrepresentable_character,
              encoding: "SIM-ALPHA-IDENTIFIER",
              codepoint: ?1
            }} =
             Iconvex.convert(substituted, "UTF-8", SIMAlphaIdentifierCodec,
               unicode_substitute: "%X"
             )
  end

  test "source state and pending bytes never admit a 256th record byte" do
    initial = SIMAlphaIdentifierCodec.stream_decoder_init()
    max_codepoints = List.duplicate(?A, @max_bytes)

    assert {:ok, ^max_codepoints, state, <<>>} =
             SIMAlphaIdentifierCodec.decode_chunk(@max_gsm, initial, false)

    assert {:sim_alpha_identifier, @max_bytes, :gsm} = state

    assert SIMAlphaIdentifierCodec.decode_chunk("B", state, false) ==
             {:error, :invalid_sequence, 0, "B"}

    pending_input = :binary.copy("A", @max_bytes - 1) <> <<0x1B>>
    pending_codepoints = List.duplicate(?A, @max_bytes - 1)
    pending_total = @max_bytes - 1

    assert {:ok, ^pending_codepoints, pending_state, <<0x1B>>} =
             SIMAlphaIdentifierCodec.decode_chunk(pending_input, initial, false)

    assert {:sim_alpha_identifier, ^pending_total, :gsm} = pending_state
    assert @max_bytes - 1 + byte_size(<<0x1B>>) == @max_bytes
  end

  test "decoder totals exclude pending bytes and their sum is bounded at every split" do
    ucs2 = String.duplicate(<<0x0100::utf8>>, 127)
    compressed_81 = String.duplicate(<<0x0400::utf8>>, 252)
    compressed_82 = String.duplicate(<<0x9000::utf8>>, 251)

    assert {:ok, ucs2_record} = SIMAlphaIdentifier.encode(ucs2, mode: :ucs2)

    assert {:ok, compressed_81_record} =
             SIMAlphaIdentifier.encode(compressed_81, mode: :compressed_81)

    assert {:ok, compressed_82_record} =
             SIMAlphaIdentifier.encode(compressed_82, mode: :compressed_82)

    records = [
      @max_gsm,
      :binary.copy("A", @max_bytes - 1) <> <<0x1B>>,
      ucs2_record,
      compressed_81_record,
      compressed_82_record
    ]

    for record <- records, split <- 0..byte_size(record) do
      prefix = binary_part(record, 0, split)
      suffix = binary_part(record, split, byte_size(record) - split)

      assert {:ok, _codepoints, prefix_state, prefix_pending} =
               SIMAlphaIdentifierCodec.decode_chunk(
                 prefix,
                 SIMAlphaIdentifierCodec.stream_decoder_init(),
                 false
               )

      prefix_total = assert_decoder_bound(prefix_state, prefix_pending)
      assert prefix_total == byte_size(prefix) - byte_size(prefix_pending)

      final_input = prefix_pending <> suffix

      assert {:ok, _codepoints, final_state, final_pending} =
               SIMAlphaIdentifierCodec.decode_chunk(final_input, prefix_state, true)

      final_total = assert_decoder_bound(final_state, final_pending)

      assert final_total ==
               prefix_total + byte_size(final_input) - byte_size(final_pending)

      assert final_pending == <<>>
      assert final_total == @max_bytes
    end
  end

  test "strict source overflow is exact while recovery treats excess bytes consistently" do
    assert SIMAlphaIdentifierCodec.decode(@overlong_gsm) ==
             {:error, :invalid_sequence, @max_bytes, "B"}

    assert SIMAlphaIdentifierCodec.decode_to_utf8(@overlong_gsm) ==
             {:error, :invalid_sequence, @max_bytes, "B"}

    assert SIMAlphaIdentifierCodec.decode_discard(@overlong_gsm) ==
             {:ok, List.duplicate(?A, @max_bytes)}

    assert_source_error(Iconvex.convert(@overlong_gsm, SIMAlphaIdentifierCodec, "UTF-8"))

    assert Iconvex.convert(@overlong_gsm, SIMAlphaIdentifierCodec, "UTF-8", invalid: :discard) ==
             {:ok, @max_gsm}

    for split <- 0..byte_size(@overlong_gsm) do
      assert stream_source(@overlong_gsm, split, :strict) ==
               {{:error, :invalid_sequence, @max_bytes, "B"}, []}

      assert stream_source(@overlong_gsm, split, :discard) == {{:ok, @max_gsm}, []}

      assert stream_source(@overlong_gsm, split, :substitute) ==
               {{:ok, @max_gsm <> "<42><43>"}, []}

      assert stream_source(@overlong_gsm, split, :callback) ==
               {{:ok, @max_gsm <> "??"},
                [
                  {:invalid_sequence, @max_bytes, ?B, "B"},
                  {:invalid_sequence, @max_bytes + 1, ?C, "C"}
                ]}
    end
  end

  test "source errors within the bounded record precede later physical overflow" do
    invalid_gsm = "A" <> <<0x80>> <> :binary.copy("B", @max_bytes - 1)

    assert byte_size(invalid_gsm) == @max_bytes + 1

    assert SIMAlphaIdentifier.decode(invalid_gsm) ==
             {:error, :invalid_sequence, 1, <<0x80>>}

    assert SIMAlphaIdentifierCodec.decode(invalid_gsm) ==
             {:error, :invalid_sequence, 1, <<0x80>>}

    surrogate = <<0x80, 0xD8, 0x00>> <> :binary.copy(<<0x00>>, @max_bytes - 2)

    assert byte_size(surrogate) == @max_bytes + 1
    assert SIMAlphaIdentifier.decode(surrogate) == {:error, {:invalid_ucs2, 0xD800}}

    assert SIMAlphaIdentifierCodec.decode(surrogate) ==
             {:error, :invalid_sequence, 1, <<0xD8, 0x00>>}

    compressed_escape =
      <<0x81, 253, 0x00>> <>
        :binary.copy("A", @max_bytes - 4) <>
        <<0x1B, 0x0A>>

    assert byte_size(compressed_escape) == @max_bytes + 1

    assert SIMAlphaIdentifierCodec.decode(compressed_escape) ==
             {:error, :incomplete_sequence, @max_bytes - 1, <<0x1B>>}

    for input <- [invalid_gsm, surrogate, compressed_escape], split <- 0..byte_size(input) do
      expected = SIMAlphaIdentifierCodec.decode(input)

      error =
        assert_raise Iconvex.Error, fn ->
          input
          |> split_at(split)
          |> Iconvex.stream!(SIMAlphaIdentifierCodec, "UTF-8")
          |> Enum.to_list()
        end

      assert {:error, error.kind, error.offset, error.sequence} == expected
    end
  end

  test "an intrinsic target error precedes later record-capacity overflow" do
    input = <<0x1F600::utf8>> <> @max_gsm <> "B"
    codepoints = [0x1F600 | :binary.bin_to_list(@max_gsm <> "B")]

    assert SIMAlphaIdentifierCodec.encode(codepoints) ==
             {:error, :unrepresentable_character, 0x1F600}

    assert {:error,
            %Iconvex.Error{
              kind: :unrepresentable_character,
              encoding: "SIM-ALPHA-IDENTIFIER",
              codepoint: 0x1F600
            }} = Iconvex.convert(input, "UTF-8", SIMAlphaIdentifierCodec)

    for split <- 0..byte_size(input) do
      error =
        assert_raise Iconvex.Error, fn ->
          input
          |> split_at(split)
          |> Iconvex.stream!("UTF-8", SIMAlphaIdentifierCodec)
          |> Enum.to_list()
        end

      assert %Iconvex.Error{
               kind: :unrepresentable_character,
               encoding: "SIM-ALPHA-IDENTIFIER",
               codepoint: 0x1F600
             } = error
    end
  end

  test "the maximum valid record is one-shot exact at every source and target split" do
    assert Iconvex.convert(@max_gsm, SIMAlphaIdentifierCodec, "UTF-8") == {:ok, @max_gsm}
    assert Iconvex.convert(@max_gsm, "UTF-8", SIMAlphaIdentifierCodec) == {:ok, @max_gsm}

    ucs2 = String.duplicate(<<0x0100::utf8>>, 127)
    compressed_81 = String.duplicate(<<0x0400::utf8>>, 252)
    compressed_82 = String.duplicate(<<0x9000::utf8>>, 251)

    assert {:ok, ucs2_record} = SIMAlphaIdentifier.encode(ucs2, mode: :ucs2)

    assert {:ok, compressed_81_record} =
             SIMAlphaIdentifier.encode(compressed_81, mode: :compressed_81)

    assert {:ok, compressed_82_record} =
             SIMAlphaIdentifier.encode(compressed_82, mode: :compressed_82)

    records = [
      {@max_gsm, @max_gsm},
      {ucs2_record, ucs2},
      {compressed_81_record, compressed_81},
      {compressed_82_record, compressed_82}
    ]

    for {record, expected} <- records, split <- 0..byte_size(record) do
      assert record
             |> split_at(split)
             |> Iconvex.stream!(SIMAlphaIdentifierCodec, "UTF-8")
             |> Enum.join() == expected
    end

    for split <- 0..byte_size(@max_gsm) do
      assert @max_gsm
             |> split_at(split)
             |> Iconvex.stream!("UTF-8", SIMAlphaIdentifierCodec)
             |> Enum.join() == @max_gsm
    end
  end

  defp assert_source_error(result) do
    assert {:error,
            %Iconvex.Error{
              kind: :invalid_sequence,
              encoding: "SIM-ALPHA-IDENTIFIER",
              offset: @max_bytes,
              sequence: "B"
            }} = result
  end

  defp stream_source(input, split, policy) do
    Process.put(:sim_bound_events, [])

    result =
      try do
        {:ok,
         input
         |> split_at(split)
         |> Iconvex.stream!(SIMAlphaIdentifierCodec, "UTF-8", source_options(policy))
         |> Enum.join()}
      rescue
        error in Iconvex.Error ->
          {:error, error.kind, error.offset, error.sequence}
      end

    {result, Process.get(:sim_bound_events) |> Enum.reverse()}
  end

  defp source_options(:strict), do: []
  defp source_options(:discard), do: [invalid: :discard]
  defp source_options(:substitute), do: [byte_substitute: "<%02x>"]

  defp source_options(:callback) do
    [
      on_invalid_byte: fn event ->
        frame = {event.kind, event.offset, event.byte, event.sequence}
        Process.put(:sim_bound_events, [frame | Process.get(:sim_bound_events)])
        {:replace, "?"}
      end
    ]
  end

  defp split_at(input, split) do
    [
      binary_part(input, 0, split),
      binary_part(input, split, byte_size(input) - split)
    ]
  end

  defp assert_decoder_bound({:sim_alpha_identifier, total, _inner_state}, pending) do
    assert total in 0..@max_bytes
    assert total + byte_size(pending) <= @max_bytes
    total
  end
end

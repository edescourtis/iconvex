defmodule Iconvex.StreamRecoveryGlobalOrderTest.StatefulSource do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-STREAM-RECOVERY-STATEFUL-SOURCE"

  @impl true
  def stateful?, do: true

  @impl true
  def decode(input), do: decode_valid(input, :base, true, 0, [])

  @impl true
  def decode_discard(input), do: decode_discard(input, :base, [])

  @impl true
  def encode(codepoints), do: {:ok, :erlang.list_to_binary(codepoints)}

  @impl true
  def encode_discard(codepoints), do: encode(codepoints)

  @impl true
  def encode_substitute(codepoints, _replacer), do: encode(codepoints)

  @impl true
  def stream_decoder_init, do: :base

  @impl true
  def decode_chunk(input, state, final?), do: decode_valid(input, state, final?, 0, [])

  @impl true
  def decode_recovery_state(_state, _kind, "^", "^"), do: :base
  def decode_recovery_state(state, _kind, _sequence, _consumed), do: state

  @impl true
  def stream_encoder_init, do: nil

  @impl true
  def encode_chunk(codepoints, state, _final?, _policy),
    do: {:ok, :erlang.list_to_binary(codepoints), state, []}

  defp decode_valid(<<>>, state, final?, _offset, acc) do
    next_state = if final?, do: :base, else: state
    {:ok, :lists.reverse(acc), next_state, <<>>}
  end

  defp decode_valid(<<?!, _rest::binary>>, _state, _final?, offset, _acc),
    do: {:error, :invalid_sequence, offset, <<?!>>}

  defp decode_valid(<<?^, _rest::binary>>, _state, _final?, offset, _acc),
    do: {:error, :invalid_sequence, offset, <<?^>>}

  defp decode_valid(<<?A, rest::binary>>, _state, final?, offset, acc),
    do: decode_valid(rest, :after_a, final?, offset + 1, [?A | acc])

  defp decode_valid(<<?B, rest::binary>>, :after_a, final?, offset, acc),
    do: decode_valid(rest, :base, final?, offset + 1, [?B | acc])

  defp decode_valid(<<?B, rest::binary>>, :base, final?, offset, acc),
    do: decode_valid(rest, :base, final?, offset + 1, [?b | acc])

  defp decode_valid(<<byte, rest::binary>>, state, final?, offset, acc),
    do: decode_valid(rest, state, final?, offset + 1, [byte | acc])

  defp decode_discard(<<>>, _state, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard(<<?!, rest::binary>>, state, acc),
    do: decode_discard(rest, state, acc)

  defp decode_discard(<<?^, rest::binary>>, _state, acc),
    do: decode_discard(rest, :base, acc)

  defp decode_discard(<<?A, rest::binary>>, _state, acc),
    do: decode_discard(rest, :after_a, [?A | acc])

  defp decode_discard(<<?B, rest::binary>>, :after_a, acc),
    do: decode_discard(rest, :base, [?B | acc])

  defp decode_discard(<<?B, rest::binary>>, :base, acc),
    do: decode_discard(rest, :base, [?b | acc])

  defp decode_discard(<<byte, rest::binary>>, state, acc),
    do: decode_discard(rest, state, [byte | acc])
end

defmodule Iconvex.StreamRecoveryGlobalOrderTest.StatefulTarget do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-STREAM-GLOBAL-FIRST-STATEFUL-TARGET"

  @impl true
  def stateful?, do: true

  @impl true
  def decode(input), do: {:ok, :binary.bin_to_list(input)}

  @impl true
  def decode_discard(input), do: decode(input)

  @impl true
  def encode(codepoints), do: encode_all(codepoints, :base, [])

  @impl true
  def encode_discard(codepoints), do: encode(codepoints)

  @impl true
  def encode_substitute(codepoints, _replacer), do: encode(codepoints)

  @impl true
  def encode_from_utf8(input) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        encode(codepoints)

      {kind, codepoints, rest} when kind in [:error, :incomplete] ->
        case encode(codepoints) do
          {:error, :unrepresentable_character, _codepoint} = target_error ->
            target_error

          {:ok, _prefix} ->
            source_kind = if kind == :error, do: :invalid_sequence, else: :incomplete_sequence
            offset = byte_size(input) - byte_size(rest)
            {:decode_error, source_kind, offset, binary_part(rest, 0, 1)}
        end
    end
  end

  @impl true
  def stream_decoder_init, do: nil

  @impl true
  def decode_chunk(input, state, _final?),
    do: {:ok, :binary.bin_to_list(input), state, <<>>}

  @impl true
  def stream_encoder_init, do: :base

  @impl true
  def encode_chunk(codepoints, state, _final?, _policy),
    do: encode_stream(codepoints, state, [])

  defp encode_all([], _state, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_all([codepoint | rest], state, acc) do
    case encode_one(codepoint, state) do
      {:ok, byte, next_state} -> encode_all(rest, next_state, [byte | acc])
      error -> error
    end
  end

  defp encode_stream([], state, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary(), state, []}

  defp encode_stream([codepoint | rest], state, acc) do
    case encode_one(codepoint, state) do
      {:ok, byte, next_state} -> encode_stream(rest, next_state, [byte | acc])
      error -> error
    end
  end

  defp encode_one(?A, _state), do: {:ok, ?A, :armed}
  defp encode_one(0xAB, :armed), do: {:error, :unrepresentable_character, 0xAB}
  defp encode_one(0xAB, :base), do: {:ok, ?x, :base}
  defp encode_one(codepoint, state) when codepoint in 0..0x7F, do: {:ok, codepoint, state}
  defp encode_one(codepoint, _state), do: {:error, :unrepresentable_character, codepoint}
end

defmodule Iconvex.StreamRecoveryGlobalOrderTest do
  use ExUnit.Case, async: false

  alias __MODULE__.{StatefulSource, StatefulTarget}

  setup_all do
    Iconvex.unregister_codec(StatefulSource)
    Iconvex.unregister_codec(StatefulTarget)
    assert :ok = Iconvex.register_codec(StatefulSource)
    assert :ok = Iconvex.register_codec(StatefulTarget)

    on_exit(fn ->
      Iconvex.unregister_codec(StatefulTarget)
      Iconvex.unregister_codec(StatefulSource)
    end)

    :ok
  end

  test "C99 recovery retains a valid literal prefix at every byte split" do
    input = <<?\\, 0xFF>>
    options = [invalid: :discard]

    assert {:ok, "\\"} = Iconvex.convert(input, "C99", "UTF-8", options)

    for split <- 0..byte_size(input) do
      assert "\\" == stream_join(input, split, "C99", "UTF-8", options)
    end
  end

  test "stateful external recovery continues from the non-terminal prefix state" do
    input = "A!B"
    options = [invalid: :discard]

    assert {:ok, "AB"} = Iconvex.convert(input, StatefulSource, "UTF-8", options)

    for split <- 0..byte_size(input) do
      assert "AB" == stream_join(input, split, StatefulSource, "UTF-8", options)
    end
  end

  test "stateful external one-shot replacement resumes from the recovered prefix state" do
    input = "A!B"

    assert {:ok, "A<21>B"} =
             Iconvex.convert(input, StatefulSource, "UTF-8", byte_substitute: "<%02x>")

    parent = self()

    callback = fn event ->
      send(parent, {:stateful_replacement_event, event})
      {:replace, "?"}
    end

    assert {:ok, "A?B"} =
             Iconvex.convert(input, StatefulSource, "UTF-8", on_invalid_byte: callback)

    assert_receive {:stateful_replacement_event,
                    %Iconvex.InvalidByte{
                      offset: 1,
                      byte: ?!,
                      sequence: "!"
                    }}

    refute_receive {:stateful_replacement_event, _additional_event}
  end

  test "stateful external recovery advances codec-owned state after consumption" do
    input = "A^B"

    assert {:ok, "Ab"} =
             Iconvex.convert(input, StatefulSource, "UTF-8", invalid: :discard)

    assert {:ok, "A<5e>b"} =
             Iconvex.convert(input, StatefulSource, "UTF-8", byte_substitute: "<%02x>")

    for split <- 0..byte_size(input) do
      assert "Ab" ==
               stream_join(input, split, StatefulSource, "UTF-8", invalid: :discard)
    end
  end

  test "the chronologically earlier HZ target error wins at every split" do
    input = <<0xC2, 0xAB, 0xFF>>

    assert_target_error(Iconvex.convert(input, "UTF-8", "HZ"), "HZ", 0xAB)

    for split <- 0..byte_size(input) do
      assert_stream_target_error(input, split, "HZ", [], "HZ", 0xAB)
    end
  end

  test "stateful direct target state and callback arbitration preserve global order" do
    input = <<?A, 0xC2, 0xAB, 0xFF>>

    assert_target_error(
      Iconvex.convert(input, "UTF-8", StatefulTarget),
      StatefulTarget.canonical_name(),
      0xAB
    )

    for callback? <- [false, true], split <- 0..byte_size(input) do
      parent = self()

      options =
        if callback? do
          [
            on_invalid_byte: fn event ->
              send(parent, {:unexpected_invalid_callback, split, event})
              :error
            end
          ]
        else
          []
        end

      assert_stream_target_error(
        input,
        split,
        StatefulTarget,
        options,
        StatefulTarget.canonical_name(),
        0xAB
      )

      refute_receive {:unexpected_invalid_callback, ^split, _event}
    end
  end

  defp assert_target_error(
         {:error,
          %Iconvex.Error{
            kind: :unrepresentable_character,
            encoding: encoding,
            codepoint: codepoint
          }},
         encoding,
         codepoint
       ),
       do: :ok

  defp assert_stream_target_error(input, split, target, options, encoding, codepoint) do
    chunks = split_binary(input, split)

    error =
      assert_raise Iconvex.Error, fn ->
        chunks
        |> Iconvex.stream!("UTF-8", target, options)
        |> Enum.to_list()
      end

    assert error.kind == :unrepresentable_character
    assert error.encoding == encoding
    assert error.codepoint == codepoint
  end

  defp stream_join(input, split, source, target, options) do
    input
    |> split_binary(split)
    |> Iconvex.stream!(source, target, options)
    |> Enum.join()
  end

  defp split_binary(input, split) do
    [
      binary_part(input, 0, split),
      binary_part(input, split, byte_size(input) - split)
    ]
  end
end

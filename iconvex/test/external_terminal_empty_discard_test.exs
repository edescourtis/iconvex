defmodule Iconvex.ExternalTerminalEmptyDiscardTest.CountedCodec do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-COUNTED-TERMINAL-EMPTY"

  @impl true
  def stateful?, do: true

  @impl true
  def decode(<<>>), do: {:ok, []}

  def decode(<<count, payload::binary>> = input) do
    if byte_size(payload) < count do
      {:error, :incomplete_sequence, byte_size(input), <<>>}
    else
      <<declared::binary-size(count), _suffix::binary>> = payload
      {:ok, :binary.bin_to_list(declared)}
    end
  end

  @impl true
  def decode_discard(<<>>), do: {:ok, []}

  def decode_discard(<<count, payload::binary>>) do
    retained = binary_part(payload, 0, min(count, byte_size(payload)))
    {:ok, :binary.bin_to_list(retained)}
  end

  @impl true
  def stream_decoder_init, do: :header

  @impl true
  def decode_chunk(<<>>, :header, _final?), do: {:ok, [], :header, <<>>}

  def decode_chunk(<<count, payload::binary>>, :header, final?),
    do: decode_payload(payload, count, final?, 1)

  def decode_chunk(input, {:payload, remaining}, final?),
    do: decode_payload(input, remaining, final?, 0)

  def decode_chunk(_input, :done, _final?), do: {:ok, [], :done, <<>>}

  @impl true
  def encode(codepoints) when is_list(codepoints), do: encode_ascii(codepoints, [])

  @impl true
  def encode_discard(codepoints) when is_list(codepoints) do
    output = for codepoint <- codepoints, codepoint < 0x80, into: <<>>, do: <<codepoint>>
    {:ok, output}
  end

  @impl true
  def encode_substitute(codepoints, replacer) when is_list(codepoints) do
    codepoints
    |> Enum.flat_map(fn
      codepoint when codepoint < 0x80 -> [codepoint]
      codepoint -> replacer.(codepoint)
    end)
    |> encode()
  end

  defp decode_payload(input, remaining, final?, header_size) do
    retained_size = min(remaining, byte_size(input))
    <<retained::binary-size(retained_size), _suffix::binary>> = input
    codepoints = :binary.bin_to_list(retained)

    case remaining - retained_size do
      0 ->
        {:ok, codepoints, :done, <<>>}

      _next_remaining when final? ->
        {:error, :incomplete_sequence, header_size + retained_size, <<>>}

      next_remaining ->
        {:ok, codepoints, {:payload, next_remaining}, <<>>}
    end
  end

  defp encode_ascii([], acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_ascii([codepoint | rest], acc) when codepoint < 0x80,
    do: encode_ascii(rest, [codepoint | acc])

  defp encode_ascii([codepoint | _rest], _acc),
    do: {:error, :unrepresentable_character, codepoint}
end

defmodule Iconvex.ExternalTerminalEmptyDiscardTest do
  use ExUnit.Case, async: false

  alias __MODULE__.CountedCodec

  @input <<2, ?A>>

  setup do
    assert :ok = Iconvex.register_codec(CountedCodec)
    on_exit(fn -> Iconvex.unregister_codec(CountedCodec) end)
    :ok
  end

  test "discard absorbs a declared but absent terminal unit at every split" do
    assert Iconvex.convert(@input, CountedCodec, "UTF-8", invalid: :discard) == {:ok, "A"}

    for split <- 0..byte_size(@input) do
      assert @input
             |> split_at(split)
             |> Iconvex.stream!(CountedCodec, "UTF-8", invalid: :discard)
             |> Enum.join() == "A"
    end
  end

  test "strict, substitution, and callback policies retain the terminal incomplete error" do
    assert_incomplete(fn ->
      Iconvex.convert(@input, CountedCodec, "UTF-8", byte_substitute: "<%02x>")
    end)

    parent = self()

    callback = fn event ->
      send(parent, {:unexpected_callback, event})
      :discard
    end

    assert_incomplete(fn ->
      Iconvex.convert(@input, CountedCodec, "UTF-8", on_invalid_byte: callback)
    end)

    for options <- [[], [byte_substitute: "<%02x>"], [on_invalid_byte: callback]],
        split <- 0..byte_size(@input) do
      error =
        assert_raise Iconvex.Error, fn ->
          @input
          |> split_at(split)
          |> Iconvex.stream!(CountedCodec, "UTF-8", options)
          |> Enum.to_list()
        end

      assert %Iconvex.Error{
               kind: :incomplete_sequence,
               encoding: "X-COUNTED-TERMINAL-EMPTY",
               offset: 2,
               sequence: <<>>
             } = error
    end

    refute_receive {:unexpected_callback, _event}
  end

  defp assert_incomplete(convert) do
    assert {:error,
            %Iconvex.Error{
              kind: :incomplete_sequence,
              encoding: "X-COUNTED-TERMINAL-EMPTY",
              offset: 2,
              sequence: <<>>
            }} = convert.()
  end

  defp split_at(input, split) do
    [
      binary_part(input, 0, split),
      binary_part(input, split, byte_size(input) - split)
    ]
  end
end

defmodule Iconvex.ExternalTerminalEmptyStrictTest.CountedCodec do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-COUNTED-STRICT-EOF"

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
    output = for codepoint <- codepoints, codepoint < 0x100, into: <<>>, do: <<codepoint>>
    {:ok, output}
  end

  @impl true
  def encode_substitute(codepoints, replacer) when is_list(codepoints) do
    codepoints
    |> Enum.flat_map(fn
      codepoint when codepoint < 0x100 -> [codepoint]
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

  defp encode_ascii([codepoint | rest], acc) when codepoint < 0x100,
    do: encode_ascii(rest, [codepoint | acc])

  defp encode_ascii([codepoint | _rest], _acc),
    do: {:error, :unrepresentable_character, codepoint}
end

defmodule Iconvex.ExternalTerminalEmptyStrictTest do
  use ExUnit.Case, async: false

  alias __MODULE__.CountedCodec

  @input <<2, 0xA3>>

  setup do
    assert :ok = Iconvex.register_codec(CountedCodec)
    on_exit(fn -> Iconvex.unregister_codec(CountedCodec) end)
    :ok
  end

  test "strict one-shot returns a typed structural-EOF source error" do
    assert {:error,
            %Iconvex.Error{
              kind: :incomplete_sequence,
              encoding: "X-COUNTED-STRICT-EOF",
              offset: 2,
              sequence: <<>>
            }} = Iconvex.convert(@input, CountedCodec, "UTF-8")
  end

  test "every strict Stream split returns the same structural-EOF source error" do
    for split <- 0..byte_size(@input) do
      error =
        assert_raise Iconvex.Error, fn ->
          @input
          |> split_at(split)
          |> Iconvex.stream!(CountedCodec, "UTF-8")
          |> Enum.to_list()
        end

      assert %Iconvex.Error{
               kind: :incomplete_sequence,
               encoding: "X-COUNTED-STRICT-EOF",
               offset: 2,
               sequence: <<>>
             } = error
    end
  end

  test "one-shot target arbitration preserves the earlier unrepresentable prefix" do
    assert {:error,
            %Iconvex.Error{
              kind: :unrepresentable_character,
              encoding: "US-ASCII",
              codepoint: 0xA3
            }} = Iconvex.convert(@input, CountedCodec, "ASCII")
  end

  test "every Stream split preserves the earlier unrepresentable prefix" do
    for split <- 0..byte_size(@input) do
      error =
        assert_raise Iconvex.Error, fn ->
          @input
          |> split_at(split)
          |> Iconvex.stream!(CountedCodec, "ASCII")
          |> Enum.to_list()
        end

      assert %Iconvex.Error{
               kind: :unrepresentable_character,
               encoding: "US-ASCII",
               codepoint: 0xA3
             } = error
    end
  end

  defp split_at(input, split) do
    [
      binary_part(input, 0, split),
      binary_part(input, split, byte_size(input) - split)
    ]
  end
end

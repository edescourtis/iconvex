defmodule Iconvex.ReviewRigorStreamRecoveryTest.TwoByteCodec do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-REVIEW-TWO-BYTE-RECOVERY"

  @impl true
  def decode(input), do: decode(input, 0, [])

  @impl true
  def decode_discard(input) do
    case input do
      <<0xFF, 0x00, rest::binary>> -> decode_discard(rest)
      <<0xFE>> -> {:ok, []}
      _other -> {:ok, :binary.bin_to_list(input)}
    end
  end

  @impl true
  def decode_chunk(input, _final?) do
    case decode(input) do
      {:ok, codepoints} -> {:ok, codepoints, <<>>}
      error -> error
    end
  end

  @impl true
  def decode_error_consumption(_kind, _sequence), do: 2

  @impl true
  def encode(codepoints), do: {:ok, :erlang.list_to_binary(codepoints)}

  @impl true
  def encode_discard(codepoints), do: encode(codepoints)

  @impl true
  def encode_substitute(codepoints, _replacer), do: encode(codepoints)

  @impl true
  def encode_chunk(codepoints, _final?, _policy),
    do: {:ok, :erlang.list_to_binary(codepoints), []}

  defp decode(<<>>, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode(<<0xFF, 0x00, _rest::binary>>, offset, _acc),
    do: {:error, :invalid_sequence, offset, <<0xFF, 0x00>>}

  defp decode(<<0xFF>>, offset, _acc),
    do: {:error, :invalid_sequence, offset, <<0xFF>>}

  defp decode(<<0xFE>>, offset, _acc),
    do: {:error, :incomplete_sequence, offset, <<0xFE>>}

  defp decode(<<byte, rest::binary>>, offset, acc),
    do: decode(rest, offset + 1, [byte | acc])
end

defmodule Iconvex.ReviewRigorStreamRecoveryTest do
  use ExUnit.Case, async: false

  alias __MODULE__.TwoByteCodec

  setup_all do
    Iconvex.unregister_codec(TwoByteCodec)
    assert :ok = Iconvex.register_codec(TwoByteCodec)
    on_exit(fn -> Iconvex.unregister_codec(TwoByteCodec) end)
    :ok
  end

  test "stream discard preserves built-in multibyte recovery boundaries at every split" do
    cases = [
      {"UTF-16BE", <<0xDC, 0x00, 0x00, 0x41>>, "A"},
      {"UTF-32BE", <<0x00, 0x11, 0x00, 0x00, 0x00, 0x00, 0x00, 0x41>>, "A"},
      {"GB18030", <<0x81, 0x30>>, ""}
    ]

    for {source, input, expected} <- cases do
      assert {:ok, ^expected} = Iconvex.convert(input, source, "UTF-8", invalid: :discard)

      for split <- 1..(byte_size(input) - 1) do
        chunks = split_binary(input, split)

        assert expected ==
                 chunks
                 |> Iconvex.stream!(source, "UTF-8", invalid: :discard)
                 |> Enum.join()
      end
    end
  end

  test "byte substitution remains per byte while recovery consumes complete native units" do
    cases = [
      {"UTF-16BE", <<0xDC, 0x00, 0x00, 0x41>>, "<dc><00>A"},
      {"UTF-32BE", <<0x00, 0x11, 0x00, 0x00, 0x00, 0x00, 0x00, 0x41>>, "<00><11><00><00>A"},
      {"GB18030", <<0x81, 0x30>>, "<81><30>"}
    ]

    for {source, input, expected} <- cases do
      options = [byte_substitute: "<%02x>"]
      assert {:ok, ^expected} = Iconvex.convert(input, source, "UTF-8", options)

      for split <- 1..(byte_size(input) - 1) do
        assert expected ==
                 input
                 |> split_binary(split)
                 |> Iconvex.stream!(source, "UTF-8", options)
                 |> Enum.join()
      end
    end
  end

  test "invalid-byte callbacks observe one complete UTF-16 unit" do
    parent = self()

    callback = fn event ->
      send(parent, {:invalid_utf16_unit, event})
      {:replace, "?"}
    end

    input = <<0xDC, 0x00, 0x00, 0x41>>

    assert {:ok, "?A"} =
             Iconvex.convert(input, "UTF-16BE", "UTF-8", on_invalid_byte: callback)

    assert_receive {:invalid_utf16_unit,
                    %Iconvex.InvalidByte{
                      offset: 0,
                      byte: 0xDC,
                      sequence: <<0xDC, 0x00>>
                    }}

    refute_receive {:invalid_utf16_unit, _event}
  end

  test "one-shot substitution retains the absolute offset after multibyte recovery" do
    assert {:error,
            %Iconvex.Error{
              kind: :incomplete_sequence,
              encoding: "X-REVIEW-TWO-BYTE-RECOVERY",
              offset: 2,
              sequence: <<0xFE>>
            }} =
             Iconvex.convert(
               <<0xFF, 0x00, 0xFE>>,
               TwoByteCodec,
               "UTF-8",
               byte_substitute: "<%02x>"
             )
  end

  test "non-final short recovery units remain pending until the next chunk" do
    assert "A" ==
             [<<0xFF>>, <<0x00, 0x41>>]
             |> Iconvex.stream!(TwoByteCodec, "UTF-8", invalid: :discard)
             |> Enum.join()
  end

  defp split_binary(input, split) do
    [
      binary_part(input, 0, split),
      binary_part(input, split, byte_size(input) - split)
    ]
  end
end

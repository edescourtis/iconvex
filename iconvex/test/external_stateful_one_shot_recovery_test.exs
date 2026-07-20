defmodule Iconvex.ExternalStatefulOneShotRecoveryTest.NoIncrementalCodec do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-STATEFUL-NO-INCREMENTAL"

  @impl true
  def stateful?, do: true

  @impl true
  def decode(input) when is_binary(input), do: decode(input, 0, [])

  @impl true
  def decode_discard(input) when is_binary(input) do
    {:ok, for(<<byte <- input>>, byte < 0x80, do: byte)}
  end

  @impl true
  def encode(codepoints) when is_list(codepoints), do: encode(codepoints, [])

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

  defp decode(<<>>, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode(<<byte, rest::binary>>, offset, acc) when byte < 0x80,
    do: decode(rest, offset + 1, [byte | acc])

  defp decode(<<byte, _rest::binary>>, offset, _acc),
    do: {:error, :invalid_sequence, offset, <<byte>>}

  defp encode([], acc), do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode([codepoint | rest], acc) when codepoint < 0x80,
    do: encode(rest, [codepoint | acc])

  defp encode([codepoint | _rest], _acc),
    do: {:error, :unrepresentable_character, codepoint}
end

defmodule Iconvex.ExternalStatefulOneShotRecoveryTest do
  use ExUnit.Case, async: false

  alias __MODULE__.NoIncrementalCodec

  setup do
    assert :ok = Iconvex.register_codec(NoIncrementalCodec)
    on_exit(fn -> Iconvex.unregister_codec(NoIncrementalCodec) end)
    :ok
  end

  test "valid one-shot callback policies do not require optional Stream callbacks" do
    assert Iconvex.convert("AB", NoIncrementalCodec, "UTF-8", byte_substitute: "<%02x>") ==
             {:ok, "AB"}

    assert Iconvex.convert("AB", NoIncrementalCodec, "UTF-8",
             on_invalid_byte: fn _event -> flunk("valid input invoked invalid-byte callback") end
           ) == {:ok, "AB"}
  end

  test "malformed one-shot input retains generic substitution and callback recovery" do
    input = <<?A, 0xFF, ?B>>

    assert Iconvex.convert(input, NoIncrementalCodec, "UTF-8", byte_substitute: "<%02x>") ==
             {:ok, "A<ff>B"}

    parent = self()

    assert Iconvex.convert(input, NoIncrementalCodec, "UTF-8",
             on_invalid_byte: fn event ->
               send(parent, {:invalid_byte, event})
               {:replace, "?"}
             end
           ) == {:ok, "A?B"}

    assert_receive {:invalid_byte,
                    %Iconvex.InvalidByte{
                      encoding: "X-STATEFUL-NO-INCREMENTAL",
                      kind: :invalid_sequence,
                      offset: 1,
                      byte: 0xFF,
                      sequence: <<0xFF>>
                    }}

    refute_receive {:invalid_byte, _additional_event}
  end

  test "lazy Stream alone rejects a source without incremental callbacks" do
    assert Iconvex.stream(["AB"], NoIncrementalCodec, "UTF-8") ==
             {:error, {:streaming_unsupported, :source, "X-STATEFUL-NO-INCREMENTAL"}}
  end
end

defmodule Iconvex.Telecom.SIMAlphaPrefixParityTest do
  use ExUnit.Case, async: false

  alias Iconvex.Telecom.{SIMAlphaIdentifier, SIMAlphaIdentifierCodec}

  @records [
    <<0x81, 2, 0x08, ?A, 0x90>>,
    <<0x82, 2, 0x04, 0x00, ?A, 0x90>>,
    <<0x82, 2, 0xD8, 0x00, 0x80, ?A>>,
    <<0x82, 2, 0xFF, 0xFF, 0x80, ?A>>,
    <<0x81, 3, 0x08, 0x1B, 0x0A, ?A>>,
    <<0x82, 3, 0x04, 0x00, 0x1B, 0x0A, ?A>>
  ]

  @policies [:strict, :discard, :substitute, :callback]

  test "proper compressed-header prefixes retain their exact diagnostic frame" do
    for input <- [<<0x81>>, <<0x81, 2>>, <<0x82>>, <<0x82, 2>>, <<0x82, 2, 0x04>>] do
      assert SIMAlphaIdentifierCodec.decode(input) ==
               {:error, :incomplete_sequence, 0, input}

      assert SIMAlphaIdentifierCodec.decode_to_utf8(input) ==
               {:error, :incomplete_sequence, 0, input}
    end
  end

  test "a trailing compressed GSM escape is the physical incomplete frame" do
    for input <- [<<0x81, 3, 0x08, 0x1B>>, <<0x82, 3, 0x04, 0x00, 0x1B>>] do
      offset = byte_size(input) - 1

      assert SIMAlphaIdentifierCodec.decode(input) ==
               {:error, :incomplete_sequence, offset, <<0x1B>>}

      assert SIMAlphaIdentifierCodec.decode_to_utf8(input) ==
               {:error, :incomplete_sequence, offset, <<0x1B>>}
    end
  end

  test "an invalid compressed code point precedes a later declared-payload EOF" do
    input = <<0x82, 2, 0xD8, 0x00, 0x80>>

    assert SIMAlphaIdentifier.decode(input) == {:error, {:invalid_ucs2, 0xD800}}

    assert SIMAlphaIdentifierCodec.decode(input) ==
             {:error, :invalid_sequence, 4, <<0x80>>}

    assert SIMAlphaIdentifierCodec.decode_to_utf8(input) ==
             {:error, :invalid_sequence, 4, <<0x80>>}

    assert {:error,
            %Iconvex.Error{
              kind: :invalid_sequence,
              encoding: "SIM-ALPHA-IDENTIFIER",
              offset: 4,
              sequence: <<0x80>>
            }} = Iconvex.convert(input, SIMAlphaIdentifierCodec, "UTF-8")
  end

  test "every proper 0x81/0x82 prefix is one-shot exact at every Stream split" do
    inputs = proper_prefixes(@records)
    assert length(inputs) == 25

    for input <- inputs, policy <- @policies do
      expected = one_shot(input, policy)

      for split <- 0..byte_size(input) do
        assert stream(input, split, policy) == expected,
               "prefix=#{Base.encode16(input)} policy=#{policy} split=#{split}"
      end
    end
  end

  defp proper_prefixes(records) do
    records
    |> Enum.flat_map(fn record ->
      for size <- 0..(byte_size(record) - 1), do: binary_part(record, 0, size)
    end)
    |> Enum.uniq()
  end

  defp one_shot(input, policy) do
    Process.put(:sim_prefix_events, [])

    result =
      normalize(fn ->
        Iconvex.convert(input, SIMAlphaIdentifierCodec, "UTF-8", options(policy))
      end)

    {result, events()}
  end

  defp stream(input, split, policy) do
    Process.put(:sim_prefix_events, [])

    chunks = [
      binary_part(input, 0, split),
      binary_part(input, split, byte_size(input) - split)
    ]

    result =
      normalize(fn ->
        {:ok,
         chunks
         |> Iconvex.stream!(SIMAlphaIdentifierCodec, "UTF-8", options(policy))
         |> Enum.join()}
      end)

    {result, events()}
  end

  defp options(:strict), do: []
  defp options(:discard), do: [invalid: :discard]
  defp options(:substitute), do: [byte_substitute: "<%02x>"]

  defp options(:callback) do
    [
      on_invalid_byte: fn event ->
        Process.put(:sim_prefix_events, [event_frame(event) | Process.get(:sim_prefix_events)])
        {:replace, "?"}
      end
    ]
  end

  defp normalize(convert) do
    case convert.() do
      {:ok, output} -> {:ok, output}
      {:error, %Iconvex.Error{} = error} -> error_frame(error)
      other -> other
    end
  rescue
    error in Iconvex.Error -> error_frame(error)
  end

  defp error_frame(error) do
    {:error, error.kind, error.encoding, error.offset, error.sequence, error.codepoint}
  end

  defp event_frame(event) do
    {event.kind, event.encoding, event.offset, event.byte, event.sequence}
  end

  defp events, do: Process.get(:sim_prefix_events) |> Enum.reverse()
end

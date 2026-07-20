defmodule Iconvex.Extras.DecodeRecoveryAtomicityTest do
  use ExUnit.Case, async: false

  @cases [
    {"DEC-HANYU", Iconvex.Extras.Codecs.DecHanyu, <<0xC2, 0xCB, 0xA1>>},
    {"DEC-HANYU", Iconvex.Extras.Codecs.DecHanyu, <<0xC2, 0xCB>>},
    {"EUC-JISX0213", Iconvex.Extras.Codecs.EucJisx0213, <<0x8F, 0xA1>>},
    {"ISO-2022-JP-3", Iconvex.Extras.Codecs.Iso2022Jp3, <<0x1B, 0x24>>}
  ]

  test "public recovery consumes each codec-native terminal unit atomically" do
    for {encoding, codec, input} <- @cases do
      assert {:error,
              %Iconvex.Error{
                kind: :incomplete_sequence,
                offset: 0,
                sequence: ^input
              }} = Iconvex.convert(input, encoding, "UTF-8")

      assert codec.decode_discard(input) == {:ok, []}
      assert Iconvex.convert(input, encoding, "UTF-8", invalid: :discard) == {:ok, ""}

      assert_callback_recovery(encoding, input, :discard, "")
      assert_callback_recovery(encoding, input, {:replace, "?"}, "?")

      expected_substitution =
        input
        |> :binary.bin_to_list()
        |> Enum.map_join(&"<#{Base.encode16(<<&1>>, case: :lower)}>")

      assert Iconvex.convert(input, encoding, "UTF-8", byte_substitute: "<%02x>") ==
               {:ok, expected_substitution}
    end
  end

  defp assert_callback_recovery(encoding, input, decision, expected) do
    tag = make_ref()
    parent = self()

    callback = fn event ->
      send(parent, {tag, event})
      decision
    end

    assert Iconvex.convert(input, encoding, "UTF-8", on_invalid_byte: callback) ==
             {:ok, expected}

    assert_receive {^tag,
                    %Iconvex.InvalidByte{
                      encoding: ^encoding,
                      kind: :incomplete_sequence,
                      offset: 0,
                      byte: first,
                      sequence: ^input
                    }}

    assert first == :binary.first(input)
    refute_receive {^tag, _event}
  end
end

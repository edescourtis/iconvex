defmodule Iconvex.GB18030MalformedRecoveryTest do
  use ExUnit.Case, async: true

  alias Iconvex.GB18030Codec

  @entries [%{id: :gb18030_2005}, %{id: :gb18030_2022}]

  test "strict decoding frames malformed GB18030 candidates without trailing valid text" do
    for entry <- @entries do
      assert {:error, :invalid_sequence, 0, <<0x81, 0x30, 0x81, 0x41>>} =
               GB18030Codec.decode(entry, <<0x81, 0x30, 0x81, 0x41>>)

      assert {:error, :invalid_sequence, 0, <<0x81, 0x30, 0x20>>} =
               GB18030Codec.decode(entry, <<0x81, 0x30, 0x20, ?A>>)

      assert {:error, :invalid_sequence, 0, <<0x81, 0x20>>} =
               GB18030Codec.decode(entry, <<0x81, 0x20, ?A>>)

      assert {:error, :invalid_sequence, 0, <<0x80>>} =
               GB18030Codec.decode(entry, <<0x80, ?A, ?B, ?C>>)

      for sequence <- [<<0x85, 0x30>>, <<0xE4, 0x30>>] do
        assert {:error, :invalid_sequence, 0, ^sequence} =
                 GB18030Codec.decode(entry, sequence)
      end
    end
  end

  test "discard and byte substitution skip one malformed lead like GNU libiconv 1.19" do
    cases = [
      {<<0x81, 0x30, 0x81, 0x41>>, "0丄", "<81>0丄"},
      {<<0x81, 0x30, 0x20, ?A>>, "0 A", "<81>0 A"},
      {<<0x80, ?A, ?B, ?C>>, "ABC", "<80>ABC"},
      {<<0x81, 0x20, ?A>>, " A", "<81> A"},
      {<<0x81, 0xFF, ?A, ?B>>, "AB", "<81><ff>AB"}
    ]

    for encoding <- ["GB18030:2005", "GB18030:2022"],
        {input, discarded, substituted} <- cases do
      assert {:ok, ^discarded} =
               Iconvex.convert(input, encoding, "UTF-8", invalid: :discard)

      assert {:ok, ^substituted} =
               Iconvex.convert(input, encoding, "UTF-8", byte_substitute: "<%02x>")
    end
  end

  test "malformed error frames and one-byte recovery are invariant at every chunk split" do
    cases = [
      {<<0x81, 0x30, 0x81, 0x41>>, 0x81, <<0x81, 0x30, 0x81, 0x41>>, "0丄"},
      {<<0x81, 0x30, 0x20, ?A>>, 0x81, <<0x81, 0x30, 0x20>>, "0 A"},
      {<<0x80, ?A>>, 0x80, <<0x80>>, "A"},
      {<<0x81, 0x20, ?A>>, 0x81, <<0x81, 0x20>>, " A"}
    ]

    for {input, byte, sequence, expected} <- cases,
        split <- 1..(byte_size(input) - 1) do
      callback = fn event ->
        send(self(), {:gb18030_invalid, event})
        :discard
      end

      assert expected ==
               input
               |> split_binary(split)
               |> Iconvex.stream!("GB18030", "UTF-8", on_invalid_byte: callback)
               |> Enum.join()

      assert_receive {:gb18030_invalid,
                      %Iconvex.InvalidByte{
                        kind: :invalid_sequence,
                        offset: 0,
                        byte: ^byte,
                        sequence: ^sequence
                      }}

      refute_receive {:gb18030_invalid, _event}
    end
  end

  defp split_binary(input, split) do
    <<left::binary-size(split), right::binary>> = input
    [left, right]
  end
end

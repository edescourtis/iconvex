defmodule Iconvex.Specs.ISCIITest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.ISCII

  @variants [
    {"x-iscii-de", 0x0905},
    {"x-iscii-be", 0x0985},
    {"x-iscii-as", 0x0985},
    {"x-iscii-pa", 0x0A05},
    {"x-iscii-gu", 0x0A85},
    {"x-iscii-or", 0x0B05},
    {"x-iscii-ta", 0x0B85},
    {"x-iscii-te", 0x0C05},
    {"x-iscii-ka", 0x0C85},
    {"x-iscii-ma", 0x0D05}
  ]

  test "publishes all Microsoft/ICU ISCII-91 initial-script variants" do
    assert ISCII.encodings() == ["ISCII-91" | Enum.map(@variants, &elem(&1, 0))]

    for {name, letter_a} <- @variants do
      assert ISCII.decode(name, <<0xA4>>) == {:ok, [letter_a]}
      assert Iconvex.canonical_name(name) == {:ok, name}
    end
  end

  test "implements ATR script switching and canonical script announcements" do
    assert ISCII.decode("ISCII-91", <<0xA4, 0xEF, 0x43, 0xA4>>) ==
             {:ok, [0x0905, 0x0985]}

    assert ISCII.encode("ISCII-91", [0x0905, 0x0985, 0x0A15, 0x0B85]) ==
             {:ok, <<0xEF, 0x42, 0xA4, 0xEF, 0x43, 0xA4, 0xEF, 0x4B, 0xB3, 0xEF, 0x44, 0xA4>>}
  end

  test "implements explicit and soft halants for every supported script" do
    for {name, base} <- @variants do
      virama = base + 0x48

      assert ISCII.decode(name, <<0xE8, 0xE8>>) == {:ok, [virama, 0x200C]}
      assert ISCII.decode(name, <<0xE8, 0xE9>>) == {:ok, [virama, 0x200D]}

      assert ISCII.encode(name, [virama, 0x200C])
             |> then(fn {:ok, bytes} ->
               ISCII.decode(name, bytes)
             end) == {:ok, [virama, 0x200C]}
    end
  end

  test "strictly reports malformed and incomplete ATR/EXT sequences" do
    assert ISCII.decode("ISCII-91", <<0xEF>>) ==
             {:error, :incomplete_sequence, 0, <<0xEF>>}

    assert ISCII.decode("ISCII-91", <<0xEF, 0x70>>) ==
             {:error, :invalid_sequence, 0, <<0xEF, 0x70>>}

    assert ISCII.decode("ISCII-91", <<0xF0>>) ==
             {:error, :incomplete_sequence, 0, <<0xF0>>}
  end

  test "matches every generated ICU 78.1 decode and encode oracle vector" do
    for vector <- ISCII.oracle_vectors() do
      assert ISCII.decode(vector.encoding, vector.bytes) == {:ok, vector.codepoints},
             "decode #{vector.encoding} #{Base.encode16(vector.bytes)}"

      if vector.canonical do
        assert ISCII.encode(vector.encoding, vector.codepoints) == {:ok, vector.bytes},
               "encode #{vector.encoding} #{inspect(vector.codepoints)}"
      end
    end
  end
end

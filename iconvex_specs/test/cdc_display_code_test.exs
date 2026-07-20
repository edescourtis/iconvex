defmodule Iconvex.Specs.CDCDisplayCodeTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.{
    CDCDisplayCode63,
    CDCDisplayCode64,
    CDCDisplayCodeASCII63,
    CDCDisplayCodeASCII64,
    Packed
  }

  @source_path Path.expand(
                 "../priv/sources/cdc-display-code/60435600L_NOS_Version_1_Operators_Guide_May1980.pdf",
                 __DIR__
               )
  @source_sha256 "86980dc43cd81f8666241277c56ab1f7c07f11b6c900c0a5d73a77cee4421be6"

  @cdc64 [?:] ++
           Enum.to_list(?A..?Z) ++
           Enum.to_list(?0..?9) ++
           [?+, ?-, ?*, ?/, ?(, ?), ?$, ?=, 0x20, ?,, ?.] ++
           [0x2261, ?[, ?], ?%, 0x2260, 0x2192, 0x2228, 0x2227] ++
           [0x2191, 0x2193, ?<, ?>, 0x2264, 0x2265, 0x00AC, ?;]

  @ascii64 [?:] ++
             Enum.to_list(?A..?Z) ++
             Enum.to_list(?0..?9) ++
             [?+, ?-, ?*, ?/, ?(, ?), ?$, ?=, 0x20, ?,, ?.] ++
             [?#, ?[, ?], ?%, ?", ?_, ?!, ?&, ?', ??, ?<, ?>, ?@, ?\\, ?^, ?;]

  test "RED: pins and identifies the official CDC NOS display-code tables" do
    assert sha256(File.read!(@source_path)) == @source_sha256
    assert CDCDisplayCode64.source_pages() == [165, 166, 167, 168]
    assert CDCDisplayCode64.printed_source_pages() == ["A-1", "A-2", "A-3", "A-4"]
    assert CDCDisplayCode64.unit_bits() == 6
    assert CDCDisplayCode64.source_url() =~ "60435600L_NOS_Version_1_Operators_Guide"
  end

  test "implements every official CDC and ASCII graphic 64-character assignment" do
    units = :binary.list_to_bin(Enum.to_list(0..63))

    assert CDCDisplayCode64.decode(units) == {:ok, @cdc64}
    assert CDCDisplayCode64.encode(@cdc64) == {:ok, units}
    assert CDCDisplayCodeASCII64.decode(units) == {:ok, @ascii64}
    assert CDCDisplayCodeASCII64.encode(@ascii64) == {:ok, units}

    assert CDCDisplayCode64.decode(<<0o60, 0o64, 0o74, 0o76>>) ==
             {:ok, [0x2261, 0x2260, 0x2264, 0x00AC]}

    assert CDCDisplayCodeASCII64.decode(<<0o60, 0o64, 0o74, 0o76>>) ==
             {:ok, ~c"#\"@^"}
  end

  test "implements the documented 63-character anomaly as separate strict profiles" do
    for {codec, full_table} <- [
          {CDCDisplayCode63, @cdc64},
          {CDCDisplayCodeASCII63, @ascii64}
        ] do
      expected = full_table |> tl() |> List.replace_at(0o63 - 1, ?:)
      units = :binary.list_to_bin(Enum.to_list(1..63))

      assert codec.decode(units) == {:ok, expected}
      assert codec.encode(expected) == {:ok, units}
      assert codec.decode(<<0>>) == {:error, :invalid_sequence, 0, <<0>>}
      assert codec.decode(<<1, 0>>) == {:error, :invalid_sequence, 1, <<0>>}
      assert codec.encode([?%]) == {:error, :unrepresentable_character, ?%}
      assert codec.encode([?:]) == {:ok, <<0o63>>}
    end
  end

  test "strict, discard, and direct UTF-8 paths preserve profile semantics" do
    for codec <- [
          CDCDisplayCode63,
          CDCDisplayCode64,
          CDCDisplayCodeASCII63,
          CDCDisplayCodeASCII64
        ] do
      assert codec.decode(<<64>>) == {:error, :invalid_sequence, 0, <<64>>}
      assert codec.decode_discard(<<1, 255, 2>>) == {:ok, ~c"AB"}
      assert codec.encode_discard([?A, 0x2603, ?B]) == {:ok, <<1, 2>>}
      assert codec.decode_to_utf8(<<1, 2, 3>>) == {:ok, "ABC"}
      assert codec.encode_from_utf8("ABC") == {:ok, <<1, 2, 3>>}
      assert codec.encode_from_utf8("☃") == {:error, :unrepresentable_character, 0x2603}

      assert codec.encode_from_utf8(<<?A, 0xFF>>) ==
               {:decode_error, :invalid_sequence, 1, <<0xFF>>}
    end

    assert CDCDisplayCode63.decode_discard(<<0, 1>>) == {:ok, ~c"A"}
    assert CDCDisplayCodeASCII63.decode_discard(<<0, 1>>) == {:ok, ~c"A"}
  end

  test "registers all profiles and round-trips exact packed MSB/LSB transports" do
    assert Iconvex.canonical_name("CDC-DISPLAY-CODE") == {:ok, "CDC-DISPLAY-CODE-64"}
    assert Iconvex.canonical_name("CDC-DISPLAY-CODE-63") == {:ok, "CDC-DISPLAY-CODE-63"}

    samples = %{
      "CDC-DISPLAY-CODE-63" => "ABC≡",
      "CDC-DISPLAY-CODE-64" => ":ABC≡",
      "CDC-DISPLAY-CODE-ASCII-63" => "ABC#",
      "CDC-DISPLAY-CODE-ASCII-64" => ":ABC#"
    }

    for {name, text} <- samples, order <- [:msb, :lsb] do
      assert Packed.profile(name).unit_bits == 6
      assert {:ok, packed} = Packed.encode_from_utf8(text, name, order)
      assert Packed.decode_to_utf8(packed, name, order) == {:ok, text}
    end
  end

  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end

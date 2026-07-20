defmodule Iconvex.Specs.MicrosoftCP51950Test do
  use ExUnit.Case, async: false

  test "registers Microsoft's EUC-TW identifier" do
    for name <- ["CP51950", "windows-51950"] do
      assert {:ok, %{canonical: "CP51950"}} = Iconvex.Registry.resolve(name)
    end
  end

  @tag timeout: 120_000
  test "matches GNU EUC-TW over every Unicode scalar" do
    all_scalars =
      0..0x10FFFF
      |> Stream.reject(&(&1 in 0xD800..0xDFFF))
      |> Stream.chunk_every(4_096)
      |> Enum.map(&List.to_string/1)
      |> IO.iodata_to_binary()

    assert Iconvex.convert(all_scalars, "UTF-8", "CP51950", unrepresentable: :discard) ==
             Iconvex.convert(all_scalars, "UTF-8", "EUC-TW", unrepresentable: :discard)
  end

  test "matches EUC-TW strict errors and complete decoding" do
    samples = [<<0>>, <<?A>>, <<0xA1, 0xA1>>, <<0x8E, 0xA2, 0xA1, 0xA1>>, <<0x8E>>, <<0xFF>>]

    for bytes <- samples do
      case {Iconvex.convert(bytes, "CP51950", "UTF-8"), Iconvex.convert(bytes, "EUC-TW", "UTF-8")} do
        {{:ok, result}, {:ok, result}} ->
          :ok

        {{:error, left}, {:error, right}} ->
          assert {left.kind, left.offset, left.sequence} ==
                   {right.kind, right.offset, right.sequence}
      end
    end
  end
end

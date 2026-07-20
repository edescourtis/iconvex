defmodule Iconvex.Specs.ISOIR169Test do
  use ExUnit.Case, async: false

  @source Path.expand("../priv/sources/iso-ir-169/169.pdf", __DIR__)
  @normalized Path.expand("../priv/sources/iso-ir-169/mappings.txt", __DIR__)
  @source_sha256 "4c3383874ef94677111b025ca9a56ddeee282fcad9b03d9cbf3fc3d73167a75e"

  test "registers the Blissymbolics two-byte graphic set" do
    for name <- [
          "ISO-IR-169",
          "ISOIR169",
          "ISO_169",
          "BLISSYMBOLICS",
          "CSISO169BLISS"
        ] do
      assert {:ok, %{canonical: "ISO-IR-169"}} = Iconvex.Registry.resolve(name)
    end
  end

  test "pins the complete registration and generated normalized map" do
    manifest = Iconvex.Specs.ISOIR169.manifest()

    assert sha256(File.read!(@source)) == @source_sha256
    assert manifest.registration_sha256 == @source_sha256
    assert manifest.registration == 169
    assert manifest.decode_mappings == 2_304
    assert manifest.encode_mappings == 2_304
    assert manifest.direct_unicode_mappings == 17
    assert manifest.private_use_mappings == 2_287
    assert manifest.normalized_sha256 == sha256(File.read!(@normalized))
  end

  test "covers exactly the 2,304 registered code positions" do
    expected = expected_mappings()
    normalized = normalized_mappings()

    assert map_size(expected) == 2_304
    assert normalized == expected

    assert Enum.count(expected, fn {_bytes, codepoint} -> private_use?(codepoint) end) == 2_287
    assert Enum.count(expected, fn {_bytes, codepoint} -> not private_use?(codepoint) end) == 17

    assert expected[<<0x21, 0x21>>] == 0x0020
    assert expected[<<0x21, 0x22>>] == 0xF0001
    assert expected[<<0x21, 0x23>>] == 0x0021
    assert expected[<<0x21, 0x30>>] == 0x0030
    assert expected[<<0x21, 0x39>>] == 0x0039
    assert expected[<<0x23, 0x21>>] == pua(0x23, 0x21)
    assert expected[<<0x30, 0x21>>] == pua(0x30, 0x21)
    assert expected[<<0x47, 0x7E>>] == pua(0x47, 0x7E)
    assert expected[<<0x48, 0x2B>>] == pua(0x48, 0x2B)
    refute Map.has_key?(expected, <<0x48, 0x2C>>)
  end

  @tag timeout: 120_000
  test "exhausts every possible two-byte input word" do
    codec = Iconvex.Specs.ISOIR169
    expected = expected_mappings()

    for value <- 0..0xFFFF do
      bytes = <<value::16>>

      case Map.fetch(expected, bytes) do
        {:ok, codepoint} -> assert codec.decode(bytes) == {:ok, [codepoint]}
        :error -> assert match?({:error, _, _, _}, codec.decode(bytes))
      end
    end
  end

  test "distinguishes every incomplete lead from every malformed single byte" do
    leads = MapSet.new([0x21, 0x23] ++ Enum.to_list(0x30..0x48))

    for byte <- 0..255 do
      result = Iconvex.Specs.ISOIR169.decode(<<byte>>)

      if MapSet.member?(leads, byte),
        do: assert(match?({:error, :incomplete_sequence, 0, _}, result)),
        else: assert(match?({:error, :invalid_sequence, 0, _}, result))
    end
  end

  test "round-trips the complete registered repertoire in one conversion" do
    mappings = Enum.sort(expected_mappings())
    bytes = mappings |> Enum.map(&elem(&1, 0)) |> IO.iodata_to_binary()
    unicode = mappings |> Enum.map(&elem(&1, 1)) |> List.to_string()

    assert Iconvex.convert(bytes, "ISO-IR-169", "UTF-8") == {:ok, unicode}
    assert Iconvex.convert(unicode, "UTF-8", "ISO-IR-169") == {:ok, bytes}
  end

  @tag timeout: 120_000
  test "checks canonical encoding over every Unicode scalar" do
    all_scalars =
      0..0x10FFFF
      |> Stream.reject(&(&1 in 0xD800..0xDFFF))
      |> Stream.chunk_every(4_096)
      |> Enum.map(&List.to_string/1)
      |> IO.iodata_to_binary()

    output =
      expected_mappings()
      |> Enum.map(fn {bytes, codepoint} -> {codepoint, bytes} end)
      |> Enum.sort()
      |> Enum.map(fn {_codepoint, bytes} -> bytes end)
      |> IO.iodata_to_binary()

    assert Iconvex.convert(all_scalars, "UTF-8", "ISO-IR-169", unrepresentable: :discard) ==
             {:ok, output}
  end

  defp expected_mappings do
    direct = %{
      <<0x21, 0x21>> => 0x0020,
      <<0x21, 0x23>> => 0x0021,
      <<0x21, 0x24>> => 0x0025,
      <<0x21, 0x25>> => 0x003F,
      <<0x21, 0x26>> => 0x002E,
      <<0x21, 0x27>> => 0x002C,
      <<0x21, 0x28>> => 0x003A
    }

    digits = Map.new(0..9, fn digit -> {<<0x21, 0x30 + digit>>, 0x30 + digit} end)

    indicators =
      Map.new(0x21..0x33, fn second ->
        {<<0x23, second>>, pua(0x23, second)}
      end)

    dictionary =
      Enum.reduce(0x30..0x47, %{}, fn first, result ->
        Enum.reduce(0x21..0x7E, result, fn second, result ->
          Map.put(result, <<first, second>>, pua(first, second))
        end)
      end)
      |> then(fn result ->
        Enum.reduce(0x21..0x2B, result, fn second, result ->
          Map.put(result, <<0x48, second>>, pua(0x48, second))
        end)
      end)

    direct
    |> Map.merge(digits)
    |> Map.put(<<0x21, 0x22>>, pua(0x21, 0x22))
    |> Map.merge(indicators)
    |> Map.merge(dictionary)
  end

  defp normalized_mappings do
    @normalized
    |> File.read!()
    |> :binary.split("\n", [:global])
    |> Enum.reduce(%{}, fn line, result ->
      case :binary.split(line, "\t") do
        [encoded, unicode] when byte_size(encoded) == 4 ->
          Map.put(result, Base.decode16!(encoded), String.to_integer(unicode, 16))

        _ ->
          result
      end
    end)
  end

  defp pua(first, second), do: 0xF0000 + (first - 0x21) * 94 + second - 0x21
  defp private_use?(codepoint), do: codepoint in 0xF0000..0xFFFFD
  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

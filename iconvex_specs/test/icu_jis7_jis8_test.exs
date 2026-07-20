defmodule Iconvex.Specs.ICUJIS7JIS8Test do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.ICUJIS

  @source_directory Path.expand("../priv/sources/icu-78.3-jis", __DIR__)

  @variants [jis7: "JIS7", jis8: "JIS8"]
  @source_files %{
    sjis: "ibm-943_P15A-2003.ucm",
    jis212: "jisx-212.ucm",
    gb: "ibm-5478_P100-1995.ucm",
    ksc: "windows-949-2000.ucm",
    greek: "ibm-9005_X110-2007.ucm"
  }

  test "registers both ICU public names and their complete converter names" do
    expected = %{
      "JIS7" => "JIS7",
      "ISO_2022,locale=ja,version=3" => "JIS7",
      "JIS8" => "JIS8",
      "ISO_2022,locale=ja,version=4" => "JIS8"
    }

    for {name, canonical} <- expected do
      assert {:ok, %{canonical: ^canonical}} = Iconvex.Registry.resolve(name)
    end
  end

  test "decodes every source mapping reachable through every ICU designation" do
    maps = component_maps()

    cases =
      Enum.concat([
        Enum.map(maps.jis208.decode, fn {bytes, cp} -> {<<0x1B, "$B">>, bytes, cp} end),
        Enum.map(maps.jis212.decode, fn {bytes, cp} -> {<<0x1B, "$(D">>, bytes, cp} end),
        Enum.map(maps.gb.decode, fn {bytes, cp} -> {<<0x1B, "$A">>, bytes, cp} end),
        Enum.map(maps.ksc.decode, fn {bytes, cp} -> {<<0x1B, "$(C">>, bytes, cp} end),
        Enum.map(maps.greek.decode, fn {bytes, cp} -> {<<0x1B, ".F", 0x1B, ?N>>, bytes, cp} end),
        for(cp <- 0xA0..0xFF, do: {<<0x1B, ".A", 0x1B, ?N>>, <<cp - 0x80>>, cp})
      ])

    for {variant, _name} <- @variants, {prefix, bytes, codepoint} <- cases do
      assert ICUJIS.decode(variant, prefix <> bytes) == {:ok, [codepoint]},
             "#{variant} failed to decode #{inspect(prefix <> bytes)} as U+#{hex(codepoint)}"
    end
  end

  test "encodes every source-backed character using ICU's exact initial preference order" do
    maps = component_maps()

    codepoints =
      [
        Map.keys(maps.jis208.encode),
        Map.keys(maps.jis212.encode),
        Map.keys(maps.gb.encode),
        Map.keys(maps.ksc.encode),
        Map.keys(maps.greek.encode),
        Enum.to_list(0..0xFF),
        Enum.to_list(0xFF61..0xFF9F),
        [0x00A5, 0x203E]
      ]
      |> List.flatten()
      |> Enum.uniq()

    for {variant, _name} <- @variants, codepoint <- codepoints do
      case expected_single(variant, codepoint, maps) do
        {:ok, expected} ->
          assert ICUJIS.encode(variant, [codepoint]) == {:ok, expected},
                 "#{variant} selected the wrong mapping for U+#{hex(codepoint)}"

        :unrepresentable ->
          assert ICUJIS.encode(variant, [codepoint]) ==
                   {:error, :unrepresentable_character, codepoint}
      end
    end
  end

  test "implements JIS7 shifted septets and JIS8 one-octet kana without conflating them" do
    assert ICUJIS.encode(:jis7, [?A, 0xFF71, ?B]) == {:ok, <<?A, 0x0E, 0x31, 0x0F, ?B>>}
    assert ICUJIS.decode(:jis7, <<?A, 0x0E, 0x31, 0x0F, ?B>>) == {:ok, [?A, 0xFF71, ?B]}

    assert ICUJIS.encode(:jis8, [?A, 0xFF71, ?B]) == {:ok, <<?A, 0xB1, ?B>>}
    assert ICUJIS.decode(:jis8, <<?A, 0xB1, ?B>>) == {:ok, [?A, 0xFF71, ?B]}

    for {variant, _name} <- @variants do
      assert ICUJIS.decode(variant, <<0x1B, "(I", 0x21, 0x5F>>) ==
               {:ok, [0xFF61, 0xFF9F]}
    end

    # JIS8 treats A1..DF as kana in any single-byte mode, even during SS2.
    assert ICUJIS.decode(:jis8, <<0x1B, ".A", 0x1B, ?N, 0xA1>>) == {:ok, [0xFF61]}
  end

  test "preserves current G0/G2 preference and resets line state exactly like ICU" do
    maps = component_maps()

    {gb_only_cp, gb_only_bytes} =
      Enum.find(maps.gb.encode, fn {cp, _bytes} ->
        not Map.has_key?(maps.jis208.encode, cp) and cp > 0xFF
      end)

    {common_cp, common_gb_bytes} =
      Enum.find(maps.gb.encode, fn {cp, _bytes} -> Map.has_key?(maps.jis208.encode, cp) end)

    assert ICUJIS.encode(:jis7, [gb_only_cp, common_cp]) ==
             {:ok, <<0x1B, "$A", gb_only_bytes::binary, common_gb_bytes::binary, 0x1B, "(B">>}

    greek = maps.greek.encode
    euro = Map.fetch!(greek, 0x20AC)
    pound = Map.fetch!(greek, 0x00A3)

    assert ICUJIS.encode(:jis7, [0x20AC, 0x00A3]) ==
             {:ok, <<0x1B, ".F", 0x1B, ?N, euro::binary, 0x1B, ?N, pound::binary>>}

    assert ICUJIS.encode(:jis7, [0x20AC, ?\n, 0x20AC]) ==
             {:ok,
              <<0x1B, ".F", 0x1B, ?N, euro::binary, ?\n, 0x1B, ".F", 0x1B, ?N, euro::binary>>}
  end

  test "handles Roman, alternate JIS 0208, SS2, newline reset, and terminal reset" do
    assert ICUJIS.decode(
             :jis7,
             <<0x1B, "(J", 0x5C, 0x7E, 0x1B, "$@", 0x24, 0x22, ?\n, ?A>>
           ) == {:ok, [0x00A5, 0x203E, 0x3042, ?\n, ?A]}

    assert ICUJIS.encode(:jis7, [0x00A5, 0x203E, 0x3042]) ==
             {:ok, <<0x1B, "(J", 0x5C, 0x7E, 0x1B, "$B", 0x24, 0x22, 0x1B, "(B">>}

    assert ICUJIS.encode(:jis7, []) == {:ok, <<>>}
  end

  test "reports illegal controls, unsupported states, truncation, and invalid octets" do
    for control <- [0x0E, 0x0F, 0x1B] do
      assert ICUJIS.encode(:jis7, [control]) ==
               {:error, :unrepresentable_character, control}
    end

    assert ICUJIS.decode(:jis7, <<0x80>>) == {:error, :invalid_sequence, 0, <<0x80>>}
    assert ICUJIS.decode(:jis8, <<0x0E>>) == {:error, :invalid_sequence, 0, <<0x0E>>}

    assert ICUJIS.decode(:jis7, <<0x1B, ?$>>) ==
             {:error, :incomplete_sequence, 0, <<0x1B, ?$>>}

    assert ICUJIS.decode(:jis7, <<0x1B, "$B", 0x24>>) ==
             {:error, :incomplete_sequence, 3, <<0x24>>}

    assert ICUJIS.decode(:jis7, <<0x1B, ?N>>) ==
             {:error, :invalid_sequence, 0, <<0x1B, ?N>>}

    assert ICUJIS.decode(:jis7, <<0x1B, ")B">>) ==
             {:error, :invalid_sequence, 0, <<0x1B, ?), ?B>>}
  end

  test "pins the exact ICU state machine and every component mapping source" do
    assert ICUJIS.release() == "78.3"
    assert ICUJIS.revision() == "21d1eb0f306e1141c10931e914dfc038c06121da"

    assert ICUJIS.aggregate_sha256() ==
             "1769c631b4d3bc50af77cd15ce41167b6df9151542285b03a3c4a1880a53ddcc"

    expected = %{
      "ucnv2022.cpp" => "c6dd94f63a9a78c30f7c1c43378e278ca9bad701a7aad3dafa57b8c04e69c83c",
      "ibm-943_P15A-2003.ucm" =>
        "6fe621b57d4d9f7aa13ba9629fbdbda11467c4e9a74d3ae79ba3dedc876bfd8f",
      "jisx-212.ucm" => "a3ad8492609c8fc8766f64610ef298b71ac872051fad5cd88802509fd6ee5f7b",
      "ibm-5478_P100-1995.ucm" =>
        "a0de779206672f548f14ea3f82cbc22e316a7bffac0b5eba662473469bd2d2ab",
      "windows-949-2000.ucm" =>
        "954a3fe3c8e3d0cbd7559dd8c7c3c4ca1fa7ffdfd7374f7259fa0f237908cb16",
      "ibm-9005_X110-2007.ucm" =>
        "f103a0c2043b658323884026f5f4328dc10a451ccccfe521018e88d88b17e5f3",
      "convrtrs.txt" => "29340d12f664416d51c9b9d8d34e6364a10b456e668eb3155fd5f59beaf743e9"
    }

    assert Map.new(ICUJIS.sources()) == expected

    for {filename, sha} <- expected do
      assert sha256(File.read!(Path.join(@source_directory, filename))) == sha
    end
  end

  defp component_maps do
    sjis = directional_maps(ucm_rows(@source_files.sjis))
    jis212 = directional_maps(ucm_rows(@source_files.jis212))
    gb = directional_maps(ucm_rows(@source_files.gb))
    ksc = directional_maps(ucm_rows(@source_files.ksc))
    greek = directional_maps(ucm_rows(@source_files.greek))

    %{
      jis208: transform(sjis, &sjis_to_jis/1),
      jis212: only_pairs(jis212, fn <<a, b>> -> a in 0x21..0x7E and b in 0x21..0x7E end),
      gb: only_pairs(gb, fn <<a, b>> -> a in 0x21..0x7E and b in 0x21..0x7E end),
      ksc:
        transform(
          only_pairs(ksc, fn <<a, b>> -> a in 0xA1..0xFE and b in 0xA1..0xFE end),
          fn <<a, b>> -> <<a - 0x80, b - 0x80>> end
        ),
      greek:
        transform(
          only_bytes(greek, fn <<byte>> -> byte in 0xA0..0xFF end),
          fn <<byte>> -> <<byte - 0x80>> end
        )
    }
  end

  defp expected_single(_variant, cp, _maps) when cp in [0x0E, 0x0F, 0x1B],
    do: :unrepresentable

  defp expected_single(:jis7, cp, _maps) when cp in 0xFF61..0xFF9F,
    do: {:ok, <<0x0E, cp - 0xFF40, 0x0F>>}

  defp expected_single(:jis8, cp, _maps) when cp in 0xFF61..0xFF9F,
    do: {:ok, <<cp - 0xFEC0>>}

  defp expected_single(_variant, cp, _maps) when cp <= 0x7F, do: {:ok, <<cp>>}

  defp expected_single(_variant, 0x00A5, _maps),
    do: {:ok, <<0x1B, "(J", 0x5C, 0x1B, "(B">>}

  defp expected_single(_variant, 0x203E, _maps),
    do: {:ok, <<0x1B, "(J", 0x7E, 0x1B, "(B">>}

  defp expected_single(_variant, cp, _maps) when cp in 0xA0..0xFF,
    do: {:ok, <<0x1B, ".A", 0x1B, ?N, cp - 0x80>>}

  defp expected_single(_variant, cp, maps) do
    choices = [
      {:jis208, maps.jis208.encode, <<0x1B, "$B">>, true},
      {:greek, maps.greek.encode, <<0x1B, ".F", 0x1B, ?N>>, false},
      {:jis212, maps.jis212.encode, <<0x1B, "$(D">>, true},
      {:gb, maps.gb.encode, <<0x1B, "$A">>, true},
      {:ksc, maps.ksc.encode, <<0x1B, "$(C">>, true}
    ]

    Enum.find_value(choices, :unrepresentable, fn {_mode, mapping, prefix, reset?} ->
      case Map.fetch(mapping, cp) do
        {:ok, bytes} -> {:ok, prefix <> bytes <> if(reset?, do: <<0x1B, "(B">>, else: <<>>)}
        :error -> false
      end
    end)
  end

  defp directional_maps(rows) do
    decode =
      rows
      |> Enum.filter(&(&1.precision in [0, 3]))
      |> Enum.sort_by(&precision_priority/1)
      |> Enum.reduce(%{}, fn row, acc -> Map.put_new(acc, row.bytes, row.codepoint) end)

    encode =
      rows
      |> Enum.filter(
        &(&1.precision in [0, 4] or (&1.precision == 1 and private_use?(&1.codepoint)))
      )
      |> Enum.sort_by(&precision_priority/1)
      |> Enum.reduce(%{}, fn row, acc -> Map.put_new(acc, row.codepoint, row.bytes) end)

    %{decode: decode, encode: encode}
  end

  defp transform(maps, fun) do
    decode =
      Enum.reduce(maps.decode, %{}, fn {bytes, cp}, acc ->
        case fun.(bytes) do
          nil -> acc
          transformed -> Map.put_new(acc, transformed, cp)
        end
      end)

    encode =
      Enum.reduce(maps.encode, %{}, fn {cp, bytes}, acc ->
        case fun.(bytes) do
          nil -> acc
          transformed -> Map.put_new(acc, cp, transformed)
        end
      end)

    %{decode: decode, encode: encode}
  end

  defp only_pairs(maps, predicate),
    do: filter_bytes(maps, &(byte_size(&1) == 2 and predicate.(&1)))

  defp only_bytes(maps, predicate),
    do: filter_bytes(maps, &(byte_size(&1) == 1 and predicate.(&1)))

  defp filter_bytes(maps, predicate) do
    %{
      decode: Map.new(Enum.filter(maps.decode, fn {bytes, _cp} -> predicate.(bytes) end)),
      encode: Map.new(Enum.filter(maps.encode, fn {_cp, bytes} -> predicate.(bytes) end))
    }
  end

  defp sjis_to_jis(<<lead, trail>>) do
    value = lead * 0x100 + trail

    if value > 0xEFFC do
      nil
    else
      row = if lead <= 0x9F, do: lead - 0x70, else: lead - 0xB0
      row = row * 2

      cond do
        trail <= 0x7E -> <<row - 1, trail - 0x1F>>
        trail <= 0x9E -> <<row - 1, trail - 0x20>>
        trail <= 0xFC -> <<row, trail - 0x7E>>
        true -> nil
      end
    end
  end

  defp sjis_to_jis(_bytes), do: nil

  defp ucm_rows(filename) do
    Path.join(@source_directory, filename)
    |> File.stream!()
    |> Enum.flat_map(fn line ->
      case Regex.run(
             ~r/^<U([0-9A-Fa-f]+)>\s+((?:\\x[0-9A-Fa-f]{2})+)(?:\s+\|(\d))?/,
             line,
             capture: :all_but_first
           ) do
        [unicode, encoded, precision] -> [row(unicode, encoded, precision)]
        [unicode, encoded] -> [row(unicode, encoded, "0")]
        nil -> []
      end
    end)
  end

  defp row(unicode, encoded, precision) do
    bytes =
      Regex.scan(~r/\\x([0-9A-Fa-f]{2})/, encoded, capture: :all_but_first)
      |> List.flatten()
      |> Enum.map(&String.to_integer(&1, 16))
      |> :binary.list_to_bin()

    %{
      codepoint: String.to_integer(unicode, 16),
      bytes: bytes,
      precision: String.to_integer(precision)
    }
  end

  defp precision_priority(%{precision: 0}), do: 0
  defp precision_priority(%{precision: precision}) when precision in [3, 4], do: 1
  defp precision_priority(%{precision: 1}), do: 2

  defp private_use?(cp),
    do: cp in 0xE000..0xF8FF or cp in 0xF0000..0xFFFFD or cp in 0x100000..0x10FFFD

  defp hex(codepoint),
    do: codepoint |> Integer.to_string(16) |> String.upcase() |> String.pad_leading(4, "0")

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

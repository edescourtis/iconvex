defmodule Iconvex.Specs.ICULMBCS1Test do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.ICULMBCS1

  @source_directory Path.expand("../priv/sources/icu-78.3-lmbcs1", __DIR__)

  @groups %{
    0x00 => "lmb-excp.ucm",
    0x01 => "ibm-850_P100-1995.ucm",
    0x02 => "ibm-851_P100-1995.ucm",
    0x03 => "ibm-9447_P100-2002.ucm",
    0x04 => "ibm-9448_X100-2005.ucm",
    0x05 => "ibm-5347_P100-1998.ucm",
    0x06 => "ibm-852_P100-1995.ucm",
    0x08 => "ibm-5350_P100-1998.ucm",
    0x0B => "windows-874-2000.ucm",
    0x10 => "ibm-943_P15A-2003.ucm",
    0x11 => "windows-949-2000.ucm",
    0x12 => "windows-950-2000.ucm",
    0x13 => "windows-936-2000.ucm"
  }

  @source_hashes %{
    "ucnv_lmb.cpp" => "0ca62b7469713bb992f418dc216e0395b175e51047f6a56e67b7524b1452f39b",
    "lmb-excp.ucm" => "00d997212a95f5c3869c9b292fd5425f91c45f07e312e3d4cc964e907de881a4",
    "ibm-850_P100-1995.ucm" => "15bbc9b79c1082c6a5ded898de123c062bd67fccfc0ac62bac9d96f73bfa8435",
    "ibm-851_P100-1995.ucm" => "0615cde485e324ea9b2c4a2d3c1d7e5d1c1e6a073f79fbdcacf58814f7474679",
    "ibm-9447_P100-2002.ucm" =>
      "71d9ca4f957563b9ac538e77b73860477a2f63191f2123b9f25e5602d0c8b107",
    "ibm-9448_X100-2005.ucm" =>
      "25702303dda09f3e7fcaaaf09536baa06ce6e3fb746b603865585f4525005fce",
    "ibm-5347_P100-1998.ucm" =>
      "d6aaee1a97b0b1ba6a160aa782621c23a5bc69ab2f968f1ee4d70a3abd630896",
    "ibm-852_P100-1995.ucm" => "8e654ed3ab6638f2d55b4da2b14928339bdf745a51f0dbb37e6dcba7075a59a3",
    "ibm-5350_P100-1998.ucm" =>
      "c7fb7d076cf2d79c9db2e8ca102781df2e24aef9380231431ff634c0d37dccd8",
    "windows-874-2000.ucm" => "852cedb7949991c60c4d9e37fbea31110919a46761e35e702e9b26889029d204",
    "ibm-943_P15A-2003.ucm" => "6fe621b57d4d9f7aa13ba9629fbdbda11467c4e9a74d3ae79ba3dedc876bfd8f",
    "windows-949-2000.ucm" => "954a3fe3c8e3d0cbd7559dd8c7c3c4ca1fa7ffdfd7374f7259fa0f237908cb16",
    "windows-950-2000.ucm" => "6611b22712f101597c790b6bcd6aa1b9e3220e0e3707a7a0485d236d89e03e7e",
    "windows-936-2000.ucm" => "40348ea8fdeb62dec8abfdfb8384a75e4ee8c6c641fd85f23f6eaa8cdb4fdad0",
    "convrtrs.txt" => "29340d12f664416d51c9b9d8d34e6364a10b456e668eb3155fd5f59beaf743e9"
  }

  test "registers the Lotus, ICU, and IBM public names" do
    for name <- ["LMBCS-1", "lmbcs", "ibm-65025"] do
      assert {:ok, %{canonical: "LMBCS-1"}} = Iconvex.Registry.resolve(name)
    end
  end

  test "matches the canonical ICU encodings for each rule family" do
    expected = %{
      0x00E9 => <<0x82>>,
      0x00B1 => <<0xF1>>,
      0x03A9 => <<0x02, 0xD5>>,
      0x0416 => <<0x05, 0xC6>>,
      0x05D0 => <<0x03, 0xE0>>,
      0x0634 => <<0x04, 0xD4>>,
      0x0E01 => <<0x0B, 0xA1>>,
      0x3042 => <<0x10, 0x82, 0xA0>>,
      0xAC00 => <<0x11, 0xB0, 0xA1>>,
      0x4E2D => <<0x10, 0x92, 0x86>>,
      0xF600 => <<0x12, 0x8C, 0xEB>>,
      0x1F600 => <<0x14, 0xD8, 0x3D, 0x14, 0xF6, 0xDE>>,
      0xFFFE => <<0x14, 0xFF, 0xFE>>,
      0xFFFF => <<0x14, 0xFF, 0xFF>>
    }

    for {codepoint, bytes} <- expected do
      assert ICULMBCS1.encode([codepoint]) == {:ok, bytes}
    end

    assert ICULMBCS1.encode([?A, 0, 1, ?\t, ?\n, ?\r, 0x19]) ==
             {:ok, <<?A, 0, 0x0F, 0x21, ?\t, ?\n, ?\r, 0x19>>}
  end

  test "decodes every reachable row from all thirteen exact subconverters" do
    for {group, filename} <- @groups do
      maps = directional_maps(source(filename))

      for {bytes, codepoint} <- maps.decode,
          encoded <- lmbcs_forms(group, bytes) do
        assert ICULMBCS1.decode(encoded) == {:ok, [codepoint]},
               "group #{Integer.to_string(group, 16)} failed #{inspect(encoded)}"
      end
    end
  end

  @tag timeout: 120_000
  test "matches ICU's canonical encoding over all 1,112,064 Unicode scalar values" do
    codepoints = scalar_codepoints()
    assert length(codepoints) == 1_112_064

    assert {:ok, encoded} = ICULMBCS1.encode(codepoints)
    assert byte_size(encoded) == 6_480_823
    # One `ucnv_fromUnicode` call over the same UTF-16 scalar corpus.
    assert sha256(encoded) == "16908926c8667f1fc3b82f31698a4ea746a4a9dfd9c9bb8fffcd66010f4eac13"

    assert ICULMBCS1.decode(encoded) ==
             {:error, :invalid_sequence, 189_361, <<0x14, 0xFF, 0xFE>>}

    assert {:ok, decoded} = ICULMBCS1.decode_discard(encoded)
    assert length(decoded) == 1_112_062

    utf32 = for codepoint <- decoded, into: <<>>, do: <<codepoint::32-big>>
    assert sha256(utf32) == "0b35a3bffebd578da5b94b31303bdc692a0b7420dfa60f3955e18abd92fa88f2"
  end

  test "supports alternate group spellings, doubled MBCS bytes, controls, and Unicode pairs" do
    assert ICULMBCS1.decode(<<0x01, 0x82>>) == {:ok, [0x00E9]}
    assert ICULMBCS1.decode(<<0x10, 0x10, 0xA6>>) == {:ok, [0xFF66]}
    assert ICULMBCS1.decode(<<0x0F, 0x21, 0x0F, 0x80>>) == {:ok, [0x01, 0x80]}

    assert ICULMBCS1.decode(<<0x14, 0xD8, 0x3D, 0x14, 0xF6, 0xDE>>) ==
             {:ok, [0x1F600]}
  end

  test "reports malformed groups, truncated characters, and unpaired Unicode surrogates" do
    assert ICULMBCS1.decode(<<0x07, 0x80>>) == {:error, :invalid_sequence, 0, <<0x07>>}
    assert ICULMBCS1.decode(<<0x01>>) == {:error, :incomplete_sequence, 0, <<0x01>>}
    assert ICULMBCS1.decode(<<0x10, 0x82>>) == {:error, :incomplete_sequence, 0, <<0x10, 0x82>>}

    assert ICULMBCS1.decode(<<0x14, 0xD8, 0x3D>>) ==
             {:error, :invalid_sequence, 0, <<0x14, 0xD8, 0x3D>>}
  end

  test "pins the annotated ICU implementation and every loaded mapping source" do
    assert ICULMBCS1.release() == "78.3"
    assert ICULMBCS1.revision() == "21d1eb0f306e1141c10931e914dfc038c06121da"

    assert ICULMBCS1.aggregate_sha256() ==
             "8d7070af86babdf51973219367d85130b996f757cb7a8081068385dfed8502fb"

    assert Map.new(ICULMBCS1.sources()) == @source_hashes
    refute function_exported?(ICULMBCS1, :source_directory, 0)

    for {filename, expected_sha} <- @source_hashes do
      assert sha256(File.read!(source(filename))) == expected_sha
    end
  end

  defp lmbcs_forms(0x00, bytes), do: if(byte_size(bytes) == 2, do: [bytes], else: [])
  defp lmbcs_forms(0x01, <<byte>>) when byte >= 0x80, do: [<<byte>>, <<0x01, byte>>]

  defp lmbcs_forms(group, <<byte>>) when group < 0x10 and byte >= 0x80,
    do: [<<group, byte>>]

  defp lmbcs_forms(group, <<byte>>) when group >= 0x10,
    do: [<<group, group, byte>>]

  defp lmbcs_forms(group, <<first, second>>) when group >= 0x10,
    do: [<<group, first, second>>]

  defp lmbcs_forms(_group, _bytes), do: []

  defp scalar_codepoints do
    for <<codepoint::32-big <- File.read!("test/fixtures/all-unicode-scalars.utf32be")>>,
      do: codepoint
  end

  defp directional_maps(path) do
    rows =
      path
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

    decode =
      rows
      |> Enum.filter(&(&1.precision in [0, 3]))
      |> Enum.sort_by(&precision_priority/1)
      |> Enum.reduce(%{}, fn row, acc -> Map.put_new(acc, row.bytes, row.codepoint) end)

    %{decode: decode}
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
  defp source(filename), do: Path.join(@source_directory, filename)
  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

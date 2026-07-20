defmodule Iconvex.Specs.IANAISO10646ProfilesTest do
  use ExUnit.Case, async: false

  @unicode_data Path.expand(
                  "../priv/sources/iana-iso10646/UnicodeData-1.1.5.txt",
                  __DIR__
                )
  @jis0208 Path.expand("../priv/sources/JIS0208.TXT", __DIR__)
  @manifest Path.expand("../priv/iana_iso10646_profiles_manifest.etf", __DIR__)

  @profiles [
    {"ISO-10646-UCS-Basic", ["csUnicodeASCII"], :basic},
    {"ISO-10646-Unicode-Latin1", ["csUnicodeLatin1", "ISO-10646"], :latin1},
    {"ISO-10646-J-1", ["csUnicodeJapanese"], :japanese}
  ]

  test "registers all official IANA names" do
    for {canonical, aliases, _profile} <- @profiles,
        name <- [canonical | aliases] do
      assert {:ok, %{canonical: ^canonical}} = Iconvex.Registry.resolve(name)
    end
  end

  test "pins RFC 1815, Unicode 1.1.5, and the Unicode JIS X 0208 mapping" do
    manifest = @manifest |> File.read!() |> :erlang.binary_to_term()

    assert manifest.rfc1815_sha256 ==
             "9f693fb29bbbc64d2aea04a98b10e53c0440f741f83a3e32cb49c41c8a00fc1f"

    assert manifest.unicode_data_sha256 == sha256(File.read!(@unicode_data))
    assert manifest.jis0208_sha256 == sha256(File.read!(@jis0208))
  end

  @tag timeout: 120_000
  test "exhausts all 65,536 UCS-2 code units for each profile" do
    expected_sets = expected_sets()

    for {canonical, _aliases, profile} <- @profiles,
        codepoint <- 0..0xFFFF do
      encoded = <<codepoint::16-big>>

      expected =
        if MapSet.member?(expected_sets[profile], codepoint),
          do: {:ok, <<codepoint::utf8>>},
          else: {:error, :invalid_sequence}

      assert normalized(Iconvex.convert(encoded, canonical, "UTF-8")) == expected
    end
  end

  @tag timeout: 120_000
  test "checks encoding over every Unicode scalar for every profile" do
    expected_sets = expected_sets()

    all_scalars =
      0..0x10FFFF
      |> Stream.reject(&(&1 in 0xD800..0xDFFF))
      |> Stream.chunk_every(4_096)
      |> Enum.map(&List.to_string/1)
      |> IO.iodata_to_binary()

    for {canonical, _aliases, profile} <- @profiles do
      expected =
        expected_sets[profile]
        |> Enum.sort()
        |> Enum.map(fn codepoint -> <<codepoint::16-big>> end)
        |> IO.iodata_to_binary()

      assert Iconvex.convert(all_scalars, "UTF-8", canonical, unrepresentable: :discard) ==
               {:ok, expected}
    end
  end

  test "uses strict fixed-width error offsets and discards whole code units" do
    assert {:error, %{kind: :incomplete_sequence, offset: 2, sequence: <<0>>}} =
             Iconvex.convert(<<0, ?A, 0>>, "ISO-10646-UCS-Basic", "UTF-8")

    assert {:error, %{kind: :invalid_sequence, offset: 2, sequence: <<1, 0>>}} =
             Iconvex.convert(<<0, ?A, 1, 0>>, "ISO-10646-UCS-Basic", "UTF-8")

    assert Iconvex.convert(
             <<0, ?A, 1, 0, 0, ?B, 0>>,
             "ISO-10646-UCS-Basic",
             "UTF-8",
             invalid: :discard
           ) == {:ok, "AB"}
  end

  defp expected_sets do
    controls = MapSet.new(Enum.concat([0x00..0x1F, 0x80..0x9F]))
    basic = Enum.reduce(0x20..0x7E, controls, &MapSet.put(&2, &1))
    latin1 = Enum.reduce(0xA0..0xFF, basic, &MapSet.put(&2, &1))
    unicode = unicode_1_1_assignments()
    jis = jis0208_codepoints()

    unrestricted_ranges = [
      0x370..0x3CF,
      0x400..0x4FF,
      0x2500..0x257F,
      0x3040..0x309F,
      0x30A0..0x30FF,
      0xFE30..0xFE4F,
      0xFF00..0xFFEF
    ]

    restricted_ranges = [
      0x2000..0x206F,
      0x2200..0x22FF,
      0x3000..0x303F,
      0x4E00..0x9FFF,
      0xF900..0xFAFF
    ]

    japanese =
      Enum.reduce(unrestricted_ranges, latin1, fn range, result ->
        Enum.reduce(range, result, fn codepoint, set ->
          case unicode do
            %{^codepoint => category} when category not in ["Mn", "Mc", "Me"] ->
              MapSet.put(set, codepoint)

            _ ->
              set
          end
        end)
      end)

    japanese =
      Enum.reduce(restricted_ranges, japanese, fn range, result ->
        Enum.reduce(range, result, fn codepoint, set ->
          if MapSet.member?(jis, codepoint), do: MapSet.put(set, codepoint), else: set
        end)
      end)

    %{basic: basic, japanese: japanese, latin1: latin1}
  end

  defp unicode_1_1_assignments do
    @unicode_data
    |> File.stream!()
    |> Enum.reduce(%{}, fn line, result ->
      case String.split(line, ";") do
        [codepoint, _name, category | _rest] ->
          Map.put(result, String.to_integer(codepoint, 16), category)

        _ ->
          result
      end
    end)
  end

  defp jis0208_codepoints do
    @jis0208
    |> File.stream!()
    |> Enum.reduce(MapSet.new(), fn line, result ->
      case Regex.run(~r/^0x[0-9A-F]+\s+0x[0-9A-F]+\s+0x([0-9A-F]+)/, line,
             capture: :all_but_first
           ) do
        [unicode] -> MapSet.put(result, String.to_integer(unicode, 16))
        nil -> result
      end
    end)
  end

  defp normalized({:ok, output}), do: {:ok, output}
  defp normalized({:error, %{kind: kind}}), do: {:error, kind}
  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

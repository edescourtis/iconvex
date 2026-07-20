defmodule Iconvex.Specs.Tools.ImportIANAISO10646Profiles do
  @moduledoc false

  @rfc_url "https://www.rfc-editor.org/rfc/rfc1815.txt"
  @rfc_sha256 "9f693fb29bbbc64d2aea04a98b10e53c0440f741f83a3e32cb49c41c8a00fc1f"
  @unicode_url "https://www.unicode.org/Public/1.1-Update/UnicodeData-1.1.5.txt"
  @unicode_sha256 "b0aa30303db3c13701967320550952e7368470776e304b52270fdb9256e4bd5b"
  @jis0208_sha256 "1c571870457f19c97720631fa83ee491549a96ba1436da1296786a67d8632e87"

  @profiles [
    %{
      aliases: ["csUnicodeASCII"],
      id: :iana_iso10646_basic,
      name: "ISO-10646-UCS-Basic",
      profile: :basic
    },
    %{
      aliases: ["csUnicodeLatin1", "ISO-10646"],
      id: :iana_iso10646_latin1,
      name: "ISO-10646-Unicode-Latin1",
      profile: :latin1
    },
    %{
      aliases: ["csUnicodeJapanese"],
      id: :iana_iso10646_japanese,
      name: "ISO-10646-J-1",
      profile: :japanese
    }
  ]

  def run do
    root = Path.expand("..", __DIR__)
    source_dir = Path.join(root, "priv/sources/iana-iso10646")
    File.mkdir_p!(source_dir)
    rfc_path = materialize_source(source_dir, "rfc1815.txt", "RFC1815_SOURCE", @rfc_sha256)

    unicode_path =
      materialize_source(
        source_dir,
        "UnicodeData-1.1.5.txt",
        "UNICODE_1_1_DATA_SOURCE",
        @unicode_sha256
      )

    jis_path = Path.join(root, "priv/sources/JIS0208.TXT")
    assert_sha!(jis_path, @jis0208_sha256)
    validate_rfc!(File.read!(rfc_path))

    sets = build_sets(unicode_path, jis_path)
    bitsets = Map.new(sets, fn {profile, set} -> {profile, to_bitset(set)} end)

    File.write!(
      Path.join(root, "priv/iana_iso10646_profiles.etf"),
      :erlang.term_to_binary(bitsets, [:deterministic, :compressed])
    )

    manifest = %{
      format: 1,
      profiles:
        Enum.map(@profiles, fn entry ->
          Map.put(entry, :representable, Map.fetch!(sets, entry.profile) |> MapSet.size())
        end),
      rfc1815_sha256: @rfc_sha256,
      rfc1815_url: @rfc_url,
      unicode_data_sha256: @unicode_sha256,
      unicode_data_url: @unicode_url,
      jis0208_sha256: @jis0208_sha256,
      jis0208_url: "https://www.unicode.org/Public/MAPPINGS/OBSOLETE/EASTASIA/JIS/JIS0208.TXT"
    }

    File.write!(
      Path.join(root, "priv/iana_iso10646_profiles_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic, :compressed])
    )

    IO.puts("wrote #{length(@profiles)} IANA ISO-10646 profile codecs")
  end

  defp materialize_source(directory, filename, environment, sha256) do
    destination = Path.join(directory, filename)

    case System.get_env(environment) do
      nil ->
        assert_sha!(destination, sha256)

      source ->
        assert_sha!(source, sha256)
        File.cp!(source, destination)
    end

    destination
  end

  defp validate_rfc!(source) do
    source = String.replace(source, ~r/\s+/, " ")

    required = [
      "The text with \"ISO-10646\" encodes text in 16 bit big endian form.",
      "The text with \"ISO-10646-J-1\" encodes text in 16 bit big endian form.",
      "only those characters of JIS X 0208"
    ]

    unless Enum.all?(required, &String.contains?(source, &1)),
      do: Mix.raise("RFC 1815 profile statements are missing")
  end

  defp build_sets(unicode_path, jis_path) do
    controls = MapSet.new(Enum.concat([0x00..0x1F, 0x80..0x9F]))
    basic = Enum.reduce(0x20..0x7E, controls, &MapSet.put(&2, &1))
    latin1 = Enum.reduce(0xA0..0xFF, basic, &MapSet.put(&2, &1))
    unicode = unicode_assignments(unicode_path)
    jis = jis0208_codepoints(jis_path)

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

  defp unicode_assignments(path) do
    path
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

  defp jis0208_codepoints(path) do
    path
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

  defp to_bitset(set) do
    for byte_index <- 0..8191, into: <<>> do
      byte =
        Enum.reduce(0..7, 0, fn bit, result ->
          codepoint = byte_index * 8 + bit
          if MapSet.member?(set, codepoint), do: result + Bitwise.bsl(1, bit), else: result
        end)

      <<byte>>
    end
  end

  defp assert_sha!(path, expected) do
    actual = path |> File.read!() |> sha256()

    unless actual == expected,
      do: Mix.raise("#{path}: expected SHA-256 #{expected}, got #{actual}")
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

Iconvex.Specs.Tools.ImportIANAISO10646Profiles.run()

defmodule Iconvex.Specs.Tools.ImportISOIR169 do
  @moduledoc false

  @registration_sha256 "4c3383874ef94677111b025ca9a56ddeee282fcad9b03d9cbf3fc3d73167a75e"
  @n1866_sha256 "f6fe0782185d9f58ec12ab09c35ab61be5e1dd893b1e8ecbcc860a0b271390d6"
  @n5228_sha256 "c6fc3ac979f8a52ab2c8212711936b93cc6ee4cc65ec54e784c2db9f7e114764"

  def run do
    root = Path.expand("..", __DIR__)
    source_dir = Path.join(root, "priv/sources/iso-ir-169")

    assert_sha!(Path.join(source_dir, "169.pdf"), @registration_sha256)
    assert_sha!(Path.join(source_dir, "n1866.pdf"), @n1866_sha256)
    assert_sha!(Path.join(source_dir, "n5228.pdf"), @n5228_sha256)

    mappings = mappings()
    normalized = serialize_normalized(mappings)
    File.write!(Path.join(source_dir, "mappings.txt"), normalized)

    table = build_table(mappings)
    table_path = Path.join(root, "priv/tables/iso_ir_169.etf")

    File.write!(
      table_path,
      :erlang.term_to_binary(table, [:deterministic, :compressed])
    )

    private_use_mappings =
      Enum.count(mappings, fn {_bytes, {codepoint}} -> private_use?(codepoint) end)

    manifest = %{
      aliases: ["ISOIR169", "ISO_169", "BLISSYMBOLICS", "CSISO169BLISS"],
      decode_mappings: map_size(mappings),
      direct_unicode_mappings: map_size(mappings) - private_use_mappings,
      encode_mappings: map_size(table.encode),
      id: :iso_ir_169,
      n1866_sha256: @n1866_sha256,
      n1866_url: "https://www.unicode.org/wg2/docs/n1866.pdf",
      n5228_sha256: @n5228_sha256,
      n5228_url: "https://www.unicode.org/wg2/docs/n5228-blissymbols.pdf",
      name: "ISO-IR-169",
      normalized_sha256: sha256(normalized),
      private_use_formula: "U+F0000 + (first_byte - 0x21) * 94 + second_byte - 0x21",
      private_use_mappings: private_use_mappings,
      registration: 169,
      registration_sha256: @registration_sha256,
      registration_url: "https://itscj.ipsj.or.jp/ir/169.pdf"
    }

    File.write!(
      Path.join(root, "priv/iso_ir_169_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic, :compressed])
    )

    write_documentation(root, manifest)
    IO.puts("wrote ISO-IR-169 with #{map_size(mappings)} registered mappings")
  end

  defp mappings do
    direct = %{
      <<0x21, 0x21>> => {0x0020},
      <<0x21, 0x23>> => {0x0021},
      <<0x21, 0x24>> => {0x0025},
      <<0x21, 0x25>> => {0x003F},
      <<0x21, 0x26>> => {0x002E},
      <<0x21, 0x27>> => {0x002C},
      <<0x21, 0x28>> => {0x003A}
    }

    digits =
      Map.new(0..9, fn digit ->
        {<<0x21, 0x30 + digit>>, {0x30 + digit}}
      end)

    indicators =
      Map.new(0x21..0x33, fn second ->
        {<<0x23, second>>, {pua(0x23, second)}}
      end)

    dictionary =
      Enum.reduce(0x30..0x47, %{}, fn first, result ->
        Enum.reduce(0x21..0x7E, result, fn second, result ->
          Map.put(result, <<first, second>>, {pua(first, second)})
        end)
      end)
      |> then(fn result ->
        Enum.reduce(0x21..0x2B, result, fn second, result ->
          Map.put(result, <<0x48, second>>, {pua(0x48, second)})
        end)
      end)

    direct
    |> Map.merge(digits)
    |> Map.put(<<0x21, 0x22>>, {pua(0x21, 0x22)})
    |> Map.merge(indicators)
    |> Map.merge(dictionary)
  end

  defp build_table(decode) do
    encode =
      decode
      |> Enum.sort()
      |> Enum.reduce(%{}, fn {bytes, codepoints}, result ->
        Map.put_new(result, codepoints, bytes)
      end)

    prefixes =
      MapSet.new(decode, fn {<<first, _second>>, _codepoints} -> <<first>> end)

    %{
      encode: encode,
      many: decode,
      max_codepoints: 1,
      max_input: 2,
      one: List.duplicate(nil, 256) |> List.to_tuple(),
      prefixes: prefixes
    }
  end

  defp serialize_normalized(mappings) do
    header =
      "# ISO-IR-169 normalized Unicode/PUA mapping.\n" <>
        "# PUA formula: U+F0000 + (first-0x21)*94 + (second-0x21).\n"

    rows =
      mappings
      |> Enum.sort()
      |> Enum.map_join("", fn {bytes, {codepoint}} ->
        Base.encode16(bytes) <> "\t" <> hex(codepoint, 4) <> "\n"
      end)

    header <> rows
  end

  defp write_documentation(root, manifest) do
    File.write!(
      Path.join(root, "ISO_IR_169.md"),
      """
      # ISO-IR-169 Blissymbolics

      `ISO-IR-169` is the registered raw two-byte, 94-by-94 graphic-set form,
      without an ISO-2022 designation escape. The official sheet defines
      exactly 2,304 characters:

      - 8 general characters, 10 ordinal digits, and 19 indicators;
      - 2,267 dictionary words at rows 16 through 40;
      - no mappings for any unassigned code-table position.

      Seventeen general characters have exact Unicode equivalents. Unicode
      still has no published Blissymbolics block, and both WG2 N1866 and the
      newer N5228 propose an ideographic/decomposed model rather than assigning
      the lexical ISO-IR-169 words one-for-one. The remaining 2,287 registered
      characters therefore use Supplementary Private Use Area-A with this
      stable reversible formula:

      `#{manifest.private_use_formula}`

      This retains every original code position without claiming a false
      semantic equivalence. The generated mapping, every 16-bit input word,
      every prefix byte, the complete repertoire, and every Unicode scalar are
      covered by tests.

      | Property | Value |
      |---|---:|
      | Decoder mappings | #{manifest.decode_mappings} |
      | Encoder mappings | #{manifest.encode_mappings} |
      | Direct Unicode mappings | #{manifest.direct_unicode_mappings} |
      | Stable PUA mappings | #{manifest.private_use_mappings} |

      - Registration SHA-256: `#{manifest.registration_sha256}`
      - Normalized mapping SHA-256: `#{manifest.normalized_sha256}`
      - WG2 N1866 SHA-256: `#{manifest.n1866_sha256}`
      - WG2 N5228 SHA-256: `#{manifest.n5228_sha256}`
      """
    )
  end

  defp pua(first, second), do: 0xF0000 + (first - 0x21) * 94 + second - 0x21
  defp private_use?(codepoint), do: codepoint in 0xF0000..0xFFFFD

  defp assert_sha!(path, expected) do
    actual = path |> File.read!() |> sha256()

    unless actual == expected,
      do: Mix.raise("#{path}: expected SHA-256 #{expected}, got #{actual}")
  end

  defp hex(integer, width),
    do: integer |> Integer.to_string(16) |> String.upcase() |> String.pad_leading(width, "0")

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

Iconvex.Specs.Tools.ImportISOIR169.run()

defmodule Iconvex.Specs.Tools.ImportISOIRCNS11643 do
  @moduledoc false

  @mapping_sha256 "01449447b44a01ba7f75983bebc0b269c2f23aef277eb32d04e303b8193af269"
  @registrations [
    {171, 1, "34b607d97fe86c8f8533dfad0f0469026f5d33ec14127387d7941a92acd478c7"},
    {172, 2, "a765ba6eac366a58ebfc72570723f4b6d6eb51f7bbe3399cee47712f29fe1c9c"},
    {183, 3, "59bd313414239f9544d707e89e27efe3749c461fd99aea81fe3a603788c9f0fe"},
    {184, 4, "a5b4aa297116b2f5499a02e0ac37b656a436b21aedd61a2695fb16a483b13bd9"},
    {185, 5, "a04883c2d378b77a5b047e53f80bbb5ecbe6f603fde67c11f7399a1cd85891b2"},
    {186, 6, "045da2b90ed0d3f8522253302e4b1396720ec49549076c0ebe667f4d28e096f7"},
    {187, 7, "f7c80adf0495d8abf0227c092f7b762b1e604e2d872b2ffc2018c6b12decae83"}
  ]

  def run do
    root = Path.expand("..", __DIR__)
    mapping_path = Path.join(root, "priv/sources/icu-data-archive/cns-11643-1992.ucm")
    assert_sha!(mapping_path, @mapping_sha256)
    registration_dir = Path.join(root, "priv/sources/iso-ir-cns11643")
    materialize_registrations(registration_dir)
    mappings = parse_mappings(mapping_path)
    table_dir = Path.join(root, "priv/tables")
    File.mkdir_p!(table_dir)

    encodings =
      @registrations
      |> Enum.with_index(1)
      |> Enum.map(fn {{registration, plane, registration_sha256}, index} ->
        id = String.to_atom("iso_ir_cns11643_plane_#{plane}")
        {table, decode_mappings, encode_mappings} = build_table(Map.fetch!(mappings, plane))

        File.write!(
          Path.join(table_dir, "#{id}.etf"),
          :erlang.term_to_binary(table, [:deterministic, :compressed])
        )

        %{
          aliases: ["CNS-11643-1992-PLANE-#{plane}", "CNS11643-#{plane}"],
          decode_mappings: decode_mappings,
          encode_mappings: encode_mappings,
          id: id,
          index: index,
          name: "ISO-IR-#{registration}",
          plane: plane,
          registration: registration,
          registration_sha256: registration_sha256,
          registration_url: "https://itscj.ipsj.or.jp/ir/#{registration}.pdf"
        }
      end)

    manifest = %{
      encodings: encodings,
      format: 1,
      mapping_sha256: @mapping_sha256,
      mapping_url:
        "https://github.com/unicode-org/icu-data/blob/main/charset/data/ucm/cns-11643-1992.ucm"
    }

    File.write!(
      Path.join(root, "priv/iso_ir_cns11643_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic, :compressed])
    )

    write_documentation(root, manifest)
    IO.puts("wrote #{length(encodings)} CNS 11643 ISO-IR plane codecs")
  end

  defp materialize_registrations(destination) do
    source_dir = System.get_env("ISO_IR_CNS_SOURCE_DIR") || destination
    File.mkdir_p!(destination)

    Enum.each(@registrations, fn {registration, _plane, sha256} ->
      filename = "#{registration}.pdf"
      source = Path.join(source_dir, filename)
      assert_sha!(source, sha256)

      if Path.expand(source) != Path.expand(Path.join(destination, filename)),
        do: File.cp!(source, Path.join(destination, filename))
    end)
  end

  defp parse_mappings(path) do
    initial = Map.new(1..7, &{&1, []})

    path
    |> File.stream!()
    |> Enum.reduce(initial, fn line, result ->
      case Regex.run(
             ~r/^<U([0-9A-F]+)> \\x8([1-7])\\x([0-9A-F]{2})\\x([0-9A-F]{2}) \|0$/,
             String.trim(line),
             capture: :all_but_first
           ) do
        [unicode, plane, first, second] ->
          plane = String.to_integer(plane)
          bytes = <<String.to_integer(first, 16), String.to_integer(second, 16)>>
          codepoint = String.to_integer(unicode, 16)
          Map.update!(result, plane, &[{bytes, codepoint} | &1])

        nil ->
          result
      end
    end)
    |> Map.new(fn {plane, rows} -> {plane, Enum.reverse(rows)} end)
  end

  defp build_table(rows) do
    decode =
      Enum.reduce(rows, %{}, fn {bytes, codepoint}, result ->
        Map.put_new(result, bytes, {codepoint})
      end)

    encode =
      Enum.reduce(rows, %{}, fn {bytes, codepoint}, result ->
        Map.put_new(result, {codepoint}, bytes)
      end)

    prefixes = decode |> Map.keys() |> Enum.map(&:binary.part(&1, 0, 1)) |> MapSet.new()

    table = %{
      encode: encode,
      many: decode,
      max_codepoints: 1,
      max_input: 2,
      one: List.duplicate(nil, 256) |> List.to_tuple(),
      prefixes: prefixes
    }

    {table, map_size(decode), map_size(encode)}
  end

  defp write_documentation(root, manifest) do
    rows =
      Enum.map_join(manifest.encodings, "", fn entry ->
        "| `#{entry.name}` | #{entry.plane} | #{entry.decode_mappings} | " <>
          "#{entry.encode_mappings} | `#{entry.registration_sha256}` |\n"
      end)

    document = """
    # CNS 11643-1992 ISO-IR planes

    Each registered 94×94 graphic set is exposed in its native two-byte
    `0x21..0x7E` form. Official ISO-IR registration sheets and the complete
    pinned ICU CNS 11643 mapping are retained for auditability.

    | Encoding | Plane | Decode mappings | Encode mappings | Registration SHA-256 |
    |---|---:|---:|---:|---|
    #{rows}
    """

    File.write!(Path.join(root, "ISO_IR_CNS11643.md"), document)
  end

  defp assert_sha!(path, expected) do
    actual = path |> File.read!() |> sha256()

    unless actual == expected,
      do: Mix.raise("#{path}: expected SHA-256 #{expected}, got #{actual}")
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

Iconvex.Specs.Tools.ImportISOIRCNS11643.run()

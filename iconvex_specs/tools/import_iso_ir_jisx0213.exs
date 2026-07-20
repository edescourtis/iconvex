defmodule Iconvex.Specs.Tools.ImportISOIRJISX0213 do
  @moduledoc false

  @extras_table_sha256 "7b18dc27b8dd37021c9dfc22e38b1d3718ab1d766b53af22003facfd16bec1f3"
  @gnu_jisx0213_sha256 "44a434978af14a99cf30eb89c915f8dff05d006a7bf636b329d48ccdb88b6531"
  @cpython_delta_sha256 "b8db3dce0aac8d433ea5f3ba057547c52727b9e3391971b278c9eb4cb61a7aca"
  @registrations [
    {228, ["JIS-X-0213-2000-PLANE-1"],
     "5cf9fc6a3abdeda88b3c2de98e33ecca6cb58c9c15b42e3f950dd358ccdd5eda"},
    {229, ["JIS-X-0213-2000-PLANE-2", "JIS-X-0213-2004-PLANE-2"],
     "ed763e79de0c71156c67fef58469913c53ff80c2a63019e4fb7a67d52486e9dc"},
    {233, ["JIS-X-0213-2004-PLANE-1"],
     "28a57cecf24042569ebfc4892fb9e8479e33bb8ca7e43c83b4339cc8ea6e8abf"}
  ]
  @jis2004_plane1_additions [
    <<0x2E, 0x21>>,
    <<0x2F, 0x7E>>,
    <<0x4F, 0x54>>,
    <<0x4F, 0x7E>>,
    <<0x74, 0x27>>,
    <<0x7E, 0x7A>>,
    <<0x7E, 0x7B>>,
    <<0x7E, 0x7C>>,
    <<0x7E, 0x7D>>,
    <<0x7E, 0x7E>>
  ]

  def run do
    root = Path.expand("..", __DIR__)
    normalized = Path.join(root, "priv/sources/iso-ir-jisx0213/mappings.txt")
    mappings = load_mappings(normalized)
    registration_dir = Path.join(root, "priv/sources/iso-ir-jisx0213/registrations")
    materialize_registrations(registration_dir)
    table_dir = Path.join(root, "priv/tables")
    File.mkdir_p!(table_dir)

    encodings =
      @registrations
      |> Enum.with_index(1)
      |> Enum.map(fn {{registration, aliases, registration_sha256}, index} ->
        id = String.to_atom("iso_ir_jisx0213_#{registration}")
        {table, decode_mappings, encode_mappings} = build_table(mappings[registration])

        File.write!(
          Path.join(table_dir, "#{id}.etf"),
          :erlang.term_to_binary(table, [:deterministic, :compressed])
        )

        %{
          aliases: aliases,
          decode_mappings: decode_mappings,
          encode_mappings: encode_mappings,
          id: id,
          index: index,
          name: "ISO-IR-#{registration}",
          registration: registration,
          registration_sha256: registration_sha256,
          registration_url: "https://itscj.ipsj.or.jp/ir/#{registration}.pdf"
        }
      end)

    manifest = %{
      cpython_2000_delta_sha256: @cpython_delta_sha256,
      cpython_2000_delta_url:
        "https://github.com/python/cpython/blob/main/Modules/cjkcodecs/emu_jisx0213_2000.h",
      encodings: encodings,
      extras_table_sha256: @extras_table_sha256,
      format: 1,
      gnu_jisx0213_sha256: @gnu_jisx0213_sha256,
      gnu_jisx0213_url:
        "https://git.savannah.gnu.org/cgit/libiconv.git/tree/lib/jisx0213.h?h=v1.19",
      normalized_sha256: sha256(File.read!(normalized))
    }

    File.write!(
      Path.join(root, "priv/iso_ir_jisx0213_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic, :compressed])
    )

    write_documentation(root, manifest)
    IO.puts("wrote #{length(encodings)} JIS X 0213 ISO-IR component codecs")
  end

  defp load_mappings(normalized) do
    case System.get_env("ICONVEX_EXTRAS_EUC_JISX0213_TABLE") do
      nil ->
        normalized |> File.read!() |> parse_normalized()

      table_path ->
        assert_sha!(table_path, @extras_table_sha256)
        assert_optional_source!("GNU_JISX0213_SOURCE", @gnu_jisx0213_sha256)
        assert_optional_source!("CPYTHON_JISX0213_2000_SOURCE", @cpython_delta_sha256)
        table = table_path |> File.read!() |> :erlang.binary_to_term()

        plane1 =
          Map.new(table.many, fn
            {<<first, second>>, codepoints} when first in 0xA1..0xFE and second in 0xA1..0xFE ->
              {<<first - 0x80, second - 0x80>>, codepoints}

            _ ->
              {nil, nil}
          end)
          |> Map.delete(nil)

        plane2 =
          table.many
          |> Enum.reduce(%{}, fn
            {<<0x8F, first, second>>, codepoints}, result ->
              Map.put(result, <<first - 0x80, second - 0x80>>, codepoints)

            _, result ->
              result
          end)

        mappings = %{
          228 => Map.drop(plane1, @jis2004_plane1_additions),
          229 => Map.put(plane2, <<0x7D, 0x3B>>, {0x9B1D}),
          233 => plane1
        }

        File.mkdir_p!(Path.dirname(normalized))
        File.write!(normalized, serialize_normalized(mappings))
        mappings
    end
  end

  defp serialize_normalized(mappings) do
    header =
      "# JIS X 0213 ISO-IR raw graphic-set mappings\n" <>
        "# GNU jisx0213.h SHA-256: #{@gnu_jisx0213_sha256}\n" <>
        "# CPython 2000 delta SHA-256: #{@cpython_delta_sha256}\n"

    body =
      Enum.map_join([228, 229, 233], "", fn registration ->
        rows =
          mappings[registration]
          |> Enum.sort()
          |> Enum.map_join("", fn {bytes, codepoints} ->
            encoded = Base.encode16(bytes)
            unicode = codepoints |> Tuple.to_list() |> Enum.map_join(",", &hex(&1, 4))
            "#{encoded}\t#{unicode}\n"
          end)

        "\n[#{registration}]\n" <> rows
      end)

    header <> body
  end

  defp parse_normalized(source) do
    source
    |> String.split(~r/^\[([0-9]+)\]\s*$/m, include_captures: true, trim: true)
    |> Enum.drop(1)
    |> Enum.chunk_every(2)
    |> Map.new(fn [header, rows] ->
      registration =
        header |> String.trim_leading("[") |> String.trim_trailing("]") |> String.to_integer()

      mapping =
        rows
        |> String.split("\n", trim: true)
        |> Enum.reject(&String.starts_with?(&1, "#"))
        |> Map.new(fn row ->
          [encoded, unicode] = String.split(row, "\t")

          codepoints =
            unicode
            |> String.split(",")
            |> Enum.map(&String.to_integer(&1, 16))
            |> List.to_tuple()

          {Base.decode16!(encoded), codepoints}
        end)

      {registration, mapping}
    end)
  end

  defp build_table(decode) do
    encode =
      decode
      |> Enum.sort()
      |> Enum.reduce(%{}, fn {bytes, codepoints}, result ->
        Map.put_new(result, codepoints, bytes)
      end)

    prefixes = decode |> Map.keys() |> Enum.map(&:binary.part(&1, 0, 1)) |> MapSet.new()

    table = %{
      encode: encode,
      many: decode,
      max_codepoints: decode |> Map.values() |> Enum.map(&tuple_size/1) |> Enum.max(),
      max_input: 2,
      one: List.duplicate(nil, 256) |> List.to_tuple(),
      prefixes: prefixes
    }

    {table, map_size(decode), map_size(encode)}
  end

  defp materialize_registrations(destination) do
    source_dir = System.get_env("ISO_IR_JISX0213_SOURCE_DIR") || destination
    File.mkdir_p!(destination)

    Enum.each(@registrations, fn {registration, _aliases, sha256} ->
      filename = "#{registration}.pdf"
      source = Path.join(source_dir, filename)
      assert_sha!(source, sha256)
      target = Path.join(destination, filename)
      if Path.expand(source) != Path.expand(target), do: File.cp!(source, target)
    end)
  end

  defp assert_optional_source!(environment, expected) do
    case System.get_env(environment) do
      nil -> :ok
      path -> assert_sha!(path, expected)
    end
  end

  defp write_documentation(root, manifest) do
    rows =
      Enum.map_join(manifest.encodings, "", fn entry ->
        "| `#{entry.name}` | #{entry.decode_mappings} | #{entry.encode_mappings} | " <>
          "`#{entry.registration_sha256}` |\n"
      end)

    document = """
    # JIS X 0213 ISO-IR planes

    These codecs expose each registered 94×94 graphic set in native two-byte
    form. ISO-IR 228 is the 2000 plane 1, ISO-IR 229 is the plane 2 repertoire,
    and ISO-IR 233 is the updated 2004 plane 1.

    | Encoding | Decode mappings | Encode mappings | Registration SHA-256 |
    |---|---:|---:|---|
    #{rows}
    """

    File.write!(Path.join(root, "ISO_IR_JISX0213.md"), document)
  end

  defp assert_sha!(path, expected) do
    actual = path |> File.read!() |> sha256()

    unless actual == expected,
      do: Mix.raise("#{path}: expected SHA-256 #{expected}, got #{actual}")
  end

  defp hex(integer, width),
    do: integer |> Integer.to_string(16) |> String.upcase() |> String.pad_leading(width, "0")

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

Iconvex.Specs.Tools.ImportISOIRJISX0213.run()

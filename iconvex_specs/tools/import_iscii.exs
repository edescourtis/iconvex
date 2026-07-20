defmodule Iconvex.Specs.Tools.ImportISCII do
  @moduledoc false

  @fixture_sha256 "525247203d8ed1cac666edbc24cfd907c475671db915ce63af7d29d83cd6e283"
  @fixture_source %{
    name: "ICU4J 78.1 CharsetISCII exhaustive fixture",
    sha256: @fixture_sha256,
    url:
      "https://github.com/unicode-org/icu/blob/release-78-1/icu4j/main/charset/src/main/java/com/ibm/icu/charset/CharsetISCII.java"
  }

  @encodings [
    %{name: "ISCII-91", version: 0, aliases: ["ISCII91"]},
    %{name: "x-iscii-de", version: 0, aliases: ["windows-57002", "iscii-dev"]},
    %{name: "x-iscii-be", version: 1, aliases: ["windows-57003", "iscii-bng"]},
    %{name: "x-iscii-as", version: 1, aliases: ["windows-57006", "iscii-asm"]},
    %{name: "x-iscii-pa", version: 2, aliases: ["windows-57011", "iscii-gur"]},
    %{name: "x-iscii-gu", version: 3, aliases: ["windows-57010", "iscii-guj"]},
    %{name: "x-iscii-or", version: 4, aliases: ["windows-57007", "iscii-ori"]},
    %{name: "x-iscii-ta", version: 5, aliases: ["windows-57004", "iscii-tml"]},
    %{name: "x-iscii-te", version: 6, aliases: ["windows-57005", "iscii-tlg"]},
    %{name: "x-iscii-ka", version: 7, aliases: ["windows-57008", "iscii-knd"]},
    %{name: "x-iscii-ma", version: 8, aliases: ["windows-57009", "iscii-mlm"]}
  ]

  def run do
    root = Path.expand("..", __DIR__)
    path = Path.join([root, "priv", "sources", "iscii", "icu4j-78.1.tsv"])
    source = File.read!(path)
    assert_digest!(source)

    rows = parse_rows(source)

    versions =
      Map.new(0..8, fn version ->
        decode =
          rows
          |> Enum.filter(&(&1.kind == :decode and &1.version == version))
          |> Map.new(&{&1.bytes, List.to_tuple(&1.codepoints)})

        encode =
          rows
          |> Enum.filter(&(&1.kind == :encode and &1.version == version))
          |> Map.new(&{List.to_tuple(&1.codepoints), &1.bytes})

        {version,
         %{
           decode: decode,
           encode: encode,
           max_bytes: decode |> Map.keys() |> Enum.map(&byte_size/1) |> Enum.max(),
           max_codepoints: encode |> Map.keys() |> Enum.map(&tuple_size/1) |> Enum.max(),
           prefixes:
             Enum.reduce(decode, MapSet.new(), fn {bytes, _value}, prefixes ->
               if byte_size(bytes) > 1 do
                 Enum.reduce(1..(byte_size(bytes) - 1), prefixes, fn size, set ->
                   MapSet.put(set, binary_part(bytes, 0, size))
                 end)
               else
                 prefixes
               end
             end)
         }}
      end)

    vectors = oracle_vectors(rows, versions)

    data = %{
      encodings: @encodings,
      fixture_source: @fixture_source,
      format: 1,
      oracle_vectors: vectors,
      versions: versions
    }

    File.write!(
      Path.join(root, "priv/iscii.etf"),
      :erlang.term_to_binary(data, [:deterministic])
    )

    IO.puts(
      "wrote #{length(@encodings)} ISCII codecs, #{length(vectors)} oracle vectors, " <>
        "#{Enum.sum(Enum.map(versions, fn {_v, table} -> map_size(table.decode) end))} decode mappings"
    )
  end

  defp parse_rows(source) do
    source
    |> String.split("\n")
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
    |> Enum.map(fn line ->
      case String.split(line, "\t", trim: false) do
        ["D", version, bytes, codepoints] ->
          %{
            bytes: decode_hex!(bytes),
            codepoints: parse_codepoints(codepoints),
            kind: :decode,
            version: String.to_integer(version)
          }

        ["E", version, codepoints, bytes] ->
          %{
            bytes: decode_hex!(bytes),
            codepoints: parse_codepoints(codepoints),
            kind: :encode,
            version: String.to_integer(version)
          }
      end
    end)
  end

  defp oracle_vectors(rows, versions) do
    decode_vectors =
      rows
      |> Enum.filter(&(&1.kind == :decode))
      |> Enum.map(fn row ->
        %{
          bytes: row.bytes,
          canonical: false,
          codepoints: row.codepoints,
          encoding: oracle_encoding(row.version)
        }
      end)

    encode_vectors =
      rows
      |> Enum.filter(&(&1.kind == :encode and &1.bytes != <<>>))
      |> Enum.filter(fn row ->
        decode_fixture(versions, row.version, row.bytes) == {:ok, row.codepoints}
      end)
      |> Enum.map(fn row ->
        %{
          bytes: row.bytes,
          canonical: true,
          codepoints: row.codepoints,
          encoding: oracle_encoding(row.version)
        }
      end)

    decode_vectors ++ encode_vectors
  end

  defp decode_fixture(versions, version, bytes), do: decode_fixture(versions, version, bytes, [])

  defp decode_fixture(_versions, _version, <<>>, acc),
    do: {:ok, acc |> Enum.reverse() |> List.flatten()}

  defp decode_fixture(versions, version, <<0xEF, selector, rest::binary>>, acc) do
    case selector_version(selector, version) do
      {:ok, next} -> decode_fixture(versions, next, rest, acc)
      :error -> :error
    end
  end

  defp decode_fixture(versions, version, bytes, acc) do
    table = versions[version]

    case longest(bytes, table.decode, min(byte_size(bytes), table.max_bytes)) do
      {value, rest} -> decode_fixture(versions, version, rest, [Tuple.to_list(value) | acc])
      nil -> :error
    end
  end

  defp longest(_bytes, _map, 0), do: nil

  defp longest(bytes, map, size) do
    key = binary_part(bytes, 0, size)

    case Map.fetch(map, key) do
      {:ok, value} -> {value, binary_part(bytes, size, byte_size(bytes) - size)}
      :error -> longest(bytes, map, size - 1)
    end
  end

  defp selector_version(0x40, default), do: {:ok, default}
  defp selector_version(0x42, _default), do: {:ok, 0}
  defp selector_version(selector, _default) when selector in [0x43, 0x46], do: {:ok, 1}
  defp selector_version(0x4B, _default), do: {:ok, 2}
  defp selector_version(0x4A, _default), do: {:ok, 3}
  defp selector_version(0x47, _default), do: {:ok, 4}
  defp selector_version(0x44, _default), do: {:ok, 5}
  defp selector_version(0x45, _default), do: {:ok, 6}
  defp selector_version(0x48, _default), do: {:ok, 7}
  defp selector_version(0x49, _default), do: {:ok, 8}
  defp selector_version(_selector, _default), do: :error

  defp oracle_encoding(0), do: "ISCII-91"
  defp oracle_encoding(version), do: Enum.find(@encodings, &(&1.version == version)).name

  defp parse_codepoints(""), do: []

  defp parse_codepoints(value),
    do: value |> String.split(",") |> Enum.map(&String.to_integer(&1, 16))

  defp decode_hex!(""), do: <<>>

  defp decode_hex!(value) do
    case Base.decode16(value, case: :mixed) do
      {:ok, bytes} -> bytes
      :error -> Mix.raise("invalid fixture hex #{inspect(value)}")
    end
  end

  defp assert_digest!(source) do
    actual = :crypto.hash(:sha256, source) |> Base.encode16(case: :lower)
    unless actual == @fixture_sha256, do: Mix.raise("ISCII fixture SHA-256 mismatch: #{actual}")
  end
end

Iconvex.Specs.Tools.ImportISCII.run()

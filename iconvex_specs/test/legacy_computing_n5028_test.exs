defmodule Iconvex.Specs.LegacyComputingN5028Test do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.LegacyComputingN5028, as: Legacy

  @source_directory Path.expand("../priv/sources/wg2-n5028", __DIR__)
  @proposal_sha256 "e64a54b4b223b5e6a9d686a7a7ddd1fc98d0bc88585059be02078b082a760e61"
  @mapping_aggregate "db0d977777647f236d685df6043a784b5d5325e6f780b08167fba3138e9edc84"
  @all_source_aggregate "2fee08a531eed1d49b46887fe733281736d53e41c275e1b837f187ac6f275eb8"
  @readme_sha256 "8a46ca0c17d9bf17ea961d56cbe5d6a19d0e53ba34b53ebd71fc43118474ce01"

  test "pins official WG2 N5028 PDF and all 72 embedded attachments" do
    assert Legacy.document() == "WG2 N5028 / L2/19-025"
    assert Legacy.proposal_sha256() == @proposal_sha256
    assert Legacy.attachment_count() == 72
    assert Legacy.mapping_aggregate_sha256() == @mapping_aggregate

    root = @source_directory
    assert sha256(File.read!(Path.join(root, "ReadMe.txt"))) == @readme_sha256

    paths = root |> Path.join("*.TXT") |> Path.wildcard() |> Enum.sort()
    assert length(paths) == 70
    assert aggregate([Path.join(root, "ReadMe.txt") | paths]) == @all_source_aggregate

    for source <- Legacy.sources() do
      assert sha256(File.read!(Path.join(root, source.file))) == source.sha256
    end
  end

  test "exports and registers all 70 mappings, including research names" do
    assert length(Legacy.entries()) == 70
    assert length(Legacy.codecs()) == 70
    assert Enum.uniq(Legacy.encodings()) == Legacy.encodings()

    expected = %{
      "ATASCII" => "ATASCII-GRAPHICS-INTERCHANGE",
      "ATARI-ASCII" => "ATASCII-GRAPHICS-INTERCHANGE",
      "PETSCII" => "PETSCII-C64-PRIMARY-INTERCHANGE",
      "MSX" => "MSX-INTERNATIONAL",
      "ZX80" => "ZX80",
      "ZX81" => "ZX81",
      "ZX-SPECTRUM" => "ZX-SPECTRUM",
      "ZX-SPECTRUM-PLUS3" => "AMSTRAD-CPM-PLUS",
      "TRS-80-MODEL-I" => "TRS-80-MODEL-I-INTERCHANGE",
      "TELETEXT-G0" => "TELETEXT-G0",
      "MINITEL-G1" => "MINITEL-G1"
    }

    for {name, canonical} <- expected do
      assert {:ok, %{canonical: ^canonical, kind: :external}} = Iconvex.Registry.resolve(name)
    end
  end

  @tag timeout: 180_000
  test "every one of 12,197 declared byte sequences decodes exactly" do
    total =
      Enum.reduce(Legacy.entries(), 0, fn entry, count ->
        codec = Legacy.codec(entry)
        mappings = parse_mappings(source_path(entry))

        for {encoded, codepoints} <- mappings do
          assert codec.decode(encoded) == {:ok, codepoints},
                 "#{entry.source_file} #{Base.encode16(encoded)}"
        end

        count + length(mappings)
      end)

    assert total == 12_197
  end

  @tag timeout: 180_000
  test "all byte holes, complete cells, and incomplete prefixes have exact classification" do
    for entry <- Legacy.entries() do
      codec = Legacy.codec(entry)
      mappings = parse_mappings(source_path(entry))
      decode = Map.new(mappings)
      prefixes = prefixes(mappings)

      inputs =
        for(byte <- 0..255, do: <<byte>>) ++
          for prefix <- prefixes, byte <- 0..255, do: prefix <> <<byte>>

      mismatches =
        Enum.reduce(inputs, [], fn input, acc ->
          expected =
            case Map.fetch(decode, input) do
              {:ok, codepoints} -> {:ok, codepoints}
              :error -> if MapSet.member?(prefixes, input), do: :incomplete, else: :invalid
            end

          actual = normalize_decode(codec.decode(input))
          if expected == actual, do: acc, else: [{input, expected, actual} | acc]
        end)

      assert Enum.take(mismatches, 10) == [], entry.source_file
    end
  end

  @tag timeout: 180_000
  test "every Unicode sequence uses source-order canonical reverse mapping" do
    for entry <- Legacy.entries() do
      codec = Legacy.codec(entry)

      canonical =
        source_path(entry)
        |> parse_mappings()
        |> Enum.reduce(%{}, fn {encoded, codepoints}, acc ->
          Map.put_new(acc, codepoints, encoded)
        end)

      for {codepoints, encoded} <- canonical do
        assert codec.encode(codepoints) == {:ok, encoded},
               "#{entry.source_file} #{inspect(codepoints)}"
      end
    end
  end

  test "multi-byte and multi-codepoint mappings use generic fast paths" do
    entries = Legacy.entries()
    msx = Enum.find(entries, &(&1.source_file == "MSX.TXT"))
    amscpm = Enum.find(entries, &(&1.source_file == "AMSCPM.TXT"))

    assert Legacy.codec(msx).decode(<<0x01, 0x40>>) == {:ok, [0x00A0]}
    assert Legacy.codec(msx).encode([0x00A0]) == {:ok, <<0x01, 0x40>>}
    assert Legacy.codec(amscpm).decode(<<0x30>>) == {:ok, [0x0030, 0xFE00]}

    utf8 = <<0x0030::utf8, 0xFE00::utf8>>
    assert Legacy.codec(amscpm).decode_to_utf8(<<0x30>>) == {:ok, utf8}
    assert Legacy.codec(amscpm).encode_from_utf8(utf8) == {:ok, <<0x30>>}
  end

  test "PETSCII control bytes can be translated by caller in one-shot and Stream conversion" do
    input = <<0x9B, 0x0D, ?A, 0x12, ?B>>

    handler = fn
      %Iconvex.InvalidByte{byte: 0x9B} -> {:replace, "<gray3>"}
      %Iconvex.InvalidByte{byte: 0x0D} -> {:replace, "\n"}
      %Iconvex.InvalidByte{byte: 0x12} -> {:replace, "<reverse-on>"}
      %Iconvex.InvalidByte{} -> :error
    end

    expected = "<gray3>\nA<reverse-on>B"

    assert Iconvex.convert(input, "PETSCII", "UTF-8", on_invalid_byte: handler) ==
             {:ok, expected}

    assert input
           |> :binary.bin_to_list()
           |> Enum.map(&<<&1>>)
           |> Iconvex.stream!("PETSCII", "UTF-8", on_invalid_byte: handler)
           |> Enum.join() == expected
  end

  test "PETSCII control callback receives absolute byte positions" do
    parent = self()
    input = <<?A, 0x0D, ?B, 0x12>>

    output =
      input
      |> :binary.bin_to_list()
      |> Enum.map(&<<&1>>)
      |> Iconvex.stream!("PETSCII", "UTF-8",
        on_invalid_byte: fn event ->
          send(parent, {:control, event})
          :discard
        end
      )
      |> Enum.join()

    assert output == "AB"

    assert_received {:control,
                     %Iconvex.InvalidByte{
                       encoding: "PETSCII-C64-PRIMARY-INTERCHANGE",
                       offset: 1,
                       byte: 0x0D
                     }}

    assert_received {:control, %Iconvex.InvalidByte{offset: 3, byte: 0x12}}
  end

  defp source_path(entry), do: Path.join(@source_directory, entry.source_file)

  defp parse_mappings(path) do
    path
    |> File.stream!()
    |> Enum.flat_map(fn line ->
      case Regex.run(
             ~r/^0x([0-9A-Fa-f]+)\s+((?:0x[0-9A-Fa-f]+)(?:\+0x[0-9A-Fa-f]+)*)/,
             line
           ) do
        [_, encoded, unicode] ->
          bytes = if rem(byte_size(encoded), 2) == 0, do: encoded, else: "0" <> encoded

          codepoints =
            unicode
            |> String.split("+")
            |> Enum.map(fn "0x" <> hex -> String.to_integer(hex, 16) end)

          [{Base.decode16!(bytes, case: :mixed), codepoints}]

        nil ->
          []
      end
    end)
  end

  defp prefixes(mappings) do
    Enum.reduce(mappings, MapSet.new(), fn {bytes, _codepoints}, acc ->
      if byte_size(bytes) > 1 do
        Enum.reduce(1..(byte_size(bytes) - 1), acc, fn size, inner ->
          MapSet.put(inner, binary_part(bytes, 0, size))
        end)
      else
        acc
      end
    end)
  end

  defp normalize_decode({:ok, codepoints}), do: {:ok, codepoints}
  defp normalize_decode({:error, :incomplete_sequence, _offset, _sequence}), do: :incomplete
  defp normalize_decode({:error, :invalid_sequence, _offset, _sequence}), do: :invalid

  defp aggregate(paths) do
    paths
    |> Enum.sort_by(&Path.basename/1)
    |> Enum.reduce(:crypto.hash_init(:sha256), fn path, context ->
      context
      |> :crypto.hash_update(Path.basename(path))
      |> :crypto.hash_update(<<0>>)
      |> :crypto.hash_update(File.read!(path))
    end)
    |> :crypto.hash_final()
    |> Base.encode16(case: :lower)
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

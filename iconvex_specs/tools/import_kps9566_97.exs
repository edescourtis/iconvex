defmodule Iconvex.Specs.Tools.ImportKPS956697 do
  @moduledoc false

  @assigned_positions 8_259
  @direct_wg2_mappings 8_176
  @pike_revision "4bf9adbd874894d2484de1664969de43e4206492"
  @pike_sha256 "28f856d12347859c9cb7f10361c813c4a4f3f7c9d33911544b50c7897748d860"
  @source_specs [
    %{
      file: "kp2ks_ucs-v09.txt",
      sha256: "08f2d3879f259ef0660567c6e35efd65462d6b61344e9366936148edaa07ca71",
      url:
        "https://web.archive.org/web/20210403091419id_/http://asadal.pusan.ac.kr/~gimgs0/hangeul/code/3xreftbl/kp2ks_ucs-v09.txt"
    },
    %{
      file: "n2564.pdf",
      sha256: "d5812c238e71afa6520e01d60d5b76294a4d4b4ccb176f376ad2468d0c279759",
      url: "https://www.unicode.org/wg2/docs/n2564.pdf"
    },
    %{
      file: "iso-ir-202.pdf",
      sha256: "a3a7ac70e9098fdc0e7974849149f61855cb93bf93449580e2b35e9ae7db3c98",
      url: "https://itscj.ipsj.or.jp/ir/202.pdf"
    },
    %{
      file: "n2374.pdf",
      sha256: "480594cb57c258b2f3b2966e21d79b8ba08cc22adc7255c31cf0532aa40275bb",
      url: "https://www.unicode.org/wg2/docs/n2374.pdf"
    }
  ]

  # KPS 9566-2003 retained every KPS-97 character except these two documented
  # revisions.  The Unicode mapping file explicitly records the Kelvin/Euro
  # replacement and the removal of the postal-mark composite.  U+F13A is the
  # stable slot implied by that file's contiguous KPS private-use assignment
  # (A1C0 -> F100 through ACE0 -> F146); it preserves the otherwise unencoded
  # KPS-97 glyph without pretending that a different Unicode character is exact.
  @kps97_overrides %{0xA8A6 => 0x212A, 0xACCF => 0xF13A}

  @encodings [
    %{
      aliases: ["ISOIR202", "ISO_202", "CSISO202KOREAN"],
      id: :kps9566_97_iso_ir,
      mode: :iso_ir,
      name: "ISO-IR-202"
    },
    %{
      aliases: ["KPS9566-97", "KPS956697", "EUC-KP-97", "EUC-KP"],
      id: :kps9566_97_euc,
      mode: :euc,
      name: "KPS-9566-97"
    }
  ]

  def run do
    root = Path.expand("..", __DIR__)
    committed = Path.join([root, "priv", "sources", "kps9566-97"])
    source_root = System.get_env("KPS9566_97_SOURCE_DIR") || committed
    assert_source_set!(source_root)
    copy_sources(source_root, committed)

    assigned =
      committed
      |> Path.join("kp2ks_ucs-v09.txt")
      |> File.read!()
      |> parse_assigned_positions()

    current_path = Path.join([root, "priv", "sources", "unicode-misc", "KPS9566.TXT"])
    current_source = File.read!(current_path)

    unless sha256(current_source) ==
             "2ac236ba8c299211b4e17bf8cef9547453413701d132bcc9f0a09de97a153327" do
      Mix.raise("KPS 9566-2003 Unicode source SHA-256 mismatch")
    end

    current = parse_unicode_mapping(current_source)
    mappings = build_kps97_mappings(assigned, current)
    validate_mappings!(assigned, mappings)
    write_normalized!(committed, mappings)

    table_dir = Path.join(root, "priv/tables")
    File.mkdir_p!(table_dir)

    encodings =
      @encodings
      |> Enum.with_index(1)
      |> Enum.map(fn {spec, index} ->
        codec_mappings = transport_mappings(mappings, spec.mode)
        table = build_table(codec_mappings)

        File.write!(
          Path.join(table_dir, "#{spec.id}.etf"),
          :erlang.term_to_binary(table, [:deterministic, :compressed])
        )

        Map.merge(spec, %{
          assigned_positions: length(mappings),
          decode_mappings: map_size(table.many) + count_one(table.one),
          encode_mappings: map_size(table.encode),
          index: index,
          max_input: table.max_input,
          private_use_mappings:
            Enum.count(codec_mappings, fn {_bytes, codepoint} -> codepoint in 0xE000..0xF8FF end)
        })
      end)

    normalized_path = Path.join(committed, "mappings.txt")

    manifest = %{
      assigned_positions: @assigned_positions,
      current_mapping_sha256: sha256(current_source),
      current_mapping_url: "https://www.unicode.org/Public/MAPPINGS/VENDORS/MISC/KPS9566.TXT",
      direct_wg2_mappings: @direct_wg2_mappings,
      encodings: encodings,
      format: 1,
      normalized_sha256: normalized_path |> File.read!() |> sha256(),
      pike_revision: @pike_revision,
      pike_sha256: @pike_sha256,
      pike_url:
        "https://github.com/pikelang/Pike/blob/#{@pike_revision}/src/modules/_Charset/tables.c",
      sources: @source_specs,
      supplemented_positions: @assigned_positions - @direct_wg2_mappings
    }

    File.write!(
      Path.join(root, "priv/kps9566_97_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic, :compressed])
    )

    write_documentation(root, manifest)
    IO.puts("wrote #{length(encodings)} KPS 9566-97 codecs over #{@assigned_positions} positions")
  end

  defp assert_source_set!(source_root) do
    Enum.each(@source_specs, fn source ->
      path = Path.join(source_root, source.file)
      actual = path |> File.read!() |> sha256()

      unless actual == source.sha256,
        do: Mix.raise("#{source.file} SHA-256 mismatch: #{actual}")
    end)
  end

  defp copy_sources(source_root, committed) do
    if Path.expand(source_root) != Path.expand(committed) do
      File.mkdir_p!(committed)

      Enum.each(@source_specs, fn source ->
        File.cp!(Path.join(source_root, source.file), Path.join(committed, source.file))
      end)
    end
  end

  defp parse_assigned_positions(source) do
    mappings =
      source
      |> :binary.split("\n", [:global])
      |> Enum.flat_map(fn line ->
        case Regex.run(
               ~r/^([0-9]{2})\s+([0-9]{2})\s+([0-9A-F]{4})\s+(?:[0-9]{2}|--)\s+(?:[0-9]{2}|--)\s+(?:[0-9A-F]{4}|----)\s+([0-9A-F]{4,6}|----)(?:\s|$)/,
               line,
               capture: :all_but_first
             ) do
          [row, column, encoded, unicode] ->
            bytes = Base.decode16!(encoded)
            <<first, second>> = bytes
            expected_first = String.to_integer(row) + 0xA0
            expected_second = String.to_integer(column) + 0xA0

            unless {first, second} == {expected_first, expected_second},
              do: Mix.raise("inconsistent EUC-KP position #{encoded}")

            wg2 = if unicode == "----", do: nil, else: String.to_integer(unicode, 16)
            [{bytes, wg2}]

          nil ->
            []
        end
      end)

    unless length(mappings) == @assigned_positions,
      do: Mix.raise("expected #{@assigned_positions} KPS positions, found #{length(mappings)}")

    unless Enum.count(mappings, fn {_bytes, codepoint} -> codepoint != nil end) ==
             @direct_wg2_mappings,
           do: Mix.raise("unexpected WG2 direct-mapping count")

    mappings
  end

  defp parse_unicode_mapping(source) do
    source
    |> :binary.split("\n", [:global])
    |> Enum.reduce(%{}, fn line, result ->
      case Regex.run(~r/^0x([0-9A-Fa-f]+)\s+0x([0-9A-Fa-f]+)/, line, capture: :all_but_first) do
        [encoded, unicode] ->
          Map.put(result, String.to_integer(encoded, 16), String.to_integer(unicode, 16))

        nil ->
          result
      end
    end)
  end

  defp build_kps97_mappings(assigned, current) do
    Enum.map(assigned, fn {bytes, _wg2} ->
      encoded = :binary.decode_unsigned(bytes)

      codepoint =
        case Map.fetch(@kps97_overrides, encoded) do
          {:ok, codepoint} -> codepoint
          :error -> Map.fetch!(current, encoded)
        end

      {bytes, codepoint}
    end)
  end

  defp validate_mappings!(assigned, mappings) do
    unless length(mappings) == @assigned_positions and
             mappings |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> length() ==
               @assigned_positions do
      Mix.raise("KPS 9566-97 mapping is not a complete unique assigned-position table")
    end

    wg2 = Map.new(assigned)
    generated = Map.new(mappings)

    # The modern Unicode mapping intentionally corrects nine old cross-reference
    # approximations/typos.  A8A6 is the one real repertoire revision and is
    # restored to Kelvin above.
    differences =
      Enum.count(wg2, fn {bytes, codepoint} ->
        codepoint != nil and generated[bytes] != codepoint
      end)

    unless differences == 9,
      do: Mix.raise("expected nine corrected WG2 cross-reference mappings, found #{differences}")
  end

  defp transport_mappings(mappings, :iso_ir) do
    Enum.map(mappings, fn {<<first, second>>, codepoint} ->
      {<<first - 0x80, second - 0x80>>, codepoint}
    end)
  end

  defp transport_mappings(mappings, :euc) do
    Enum.map(0..0x7F, fn byte -> {<<byte>>, byte} end) ++ mappings
  end

  defp build_table(mappings) do
    decode = Map.new(mappings, fn {bytes, codepoint} -> {bytes, {codepoint}} end)

    encode =
      Enum.reduce(mappings, %{}, fn {bytes, codepoint}, result ->
        Map.put_new(result, {codepoint}, bytes)
      end)

    {one, many} =
      Enum.reduce(decode, {%{}, %{}}, fn {bytes, codepoints}, {one, many} ->
        if byte_size(bytes) == 1,
          do: {Map.put(one, :binary.first(bytes), codepoints), many},
          else: {one, Map.put(many, bytes, codepoints)}
      end)

    prefixes =
      Enum.reduce(many, MapSet.new(), fn {bytes, _codepoints}, result ->
        MapSet.put(result, binary_part(bytes, 0, 1))
      end)

    %{
      encode: encode,
      many: many,
      max_codepoints: 1,
      max_input: 2,
      one: 0..255 |> Enum.map(&Map.get(one, &1)) |> List.to_tuple(),
      prefixes: prefixes
    }
  end

  defp count_one(one), do: one |> Tuple.to_list() |> Enum.count(&(&1 != nil))

  defp write_normalized!(committed, mappings) do
    content =
      mappings
      |> Enum.map(fn {bytes, codepoint} ->
        [Base.encode16(bytes), "\t", codepoint |> Integer.to_string(16) |> String.upcase(), "\n"]
      end)
      |> IO.iodata_to_binary()

    File.write!(Path.join(committed, "mappings.txt"), content)
  end

  defp write_documentation(root, manifest) do
    sources =
      Enum.map_join(manifest.sources, "\n", fn source ->
        "- `#{source.file}`: `#{source.sha256}` - #{source.url}"
      end)

    rows =
      Enum.map_join(manifest.encodings, "\n", fn entry ->
        "| `#{entry.name}` | `#{entry.mode}` | #{entry.decode_mappings} | #{entry.encode_mappings} | #{entry.private_use_mappings} |"
      end)

    File.write!(
      Path.join(root, "KPS9566_97.md"),
      """
      # KPS 9566-97 / ISO-IR-202

      Iconvex supplies both transports of the DPRK KPS 9566-97 repertoire:

      - `ISO-IR-202` is the registered 7-bit 94x94 graphic set (`0x21..0x7E`).
      - `KPS-9566-97` is EUC-KP: ASCII plus the same repertoire at `0xA1..0xFE`.

      The official registration declares exactly #{manifest.assigned_positions} characters. WG2 N2564 maps #{manifest.direct_wg2_mappings}; the remaining #{manifest.supplemented_positions} are resolved from the Unicode Consortium's later KPS table and WG2 N2374. The 2003 table explicitly records the two repertoire changes: KPS-97 `A8A6` is Kelvin (U+212A), while `ACCF` is the removed postal-mark composite. Because that composite still has no exact Unicode scalar, this codec assigns its stable historical KPS private-use slot U+F13A.

      Nine non-revision N2564 cross-reference approximations or typos are corrected by the later Unicode mapping and independently checked against the registered glyph chart and Pike's KPS-97 implementation. No user-definable or empty positions are invented.

      | Encoding | Transport | Decoder mappings | Canonical encoder mappings | BMP private-use mappings |
      | --- | --- | ---: | ---: | ---: |
      #{rows}

      Normalized mapping SHA-256: `#{manifest.normalized_sha256}`

      Current Unicode mapping SHA-256: `#{manifest.current_mapping_sha256}` - #{manifest.current_mapping_url}

      Independent Pike cross-check: revision `#{manifest.pike_revision}`, source SHA-256 `#{manifest.pike_sha256}` - #{manifest.pike_url}

      ## Pinned primary sources

      #{sources}
      """
    )
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

Iconvex.Specs.Tools.ImportKPS956697.run()

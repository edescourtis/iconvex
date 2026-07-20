defmodule Iconvex.Specs.Tools.ImportVendorMappings do
  @moduledoc false

  @adobe_base "https://www.unicode.org/Public/MAPPINGS/VENDORS/ADOBE/"
  @apple_base "https://www.unicode.org/Public/MAPPINGS/VENDORS/APPLE/"

  @adobe [
    {"stdenc.txt", "ADOBE-STANDARD-ENCODING",
     ["Adobe-Standard-Encoding", "AdobeStandardEncoding", "csAdobeStandardEncoding"],
     "4bcda13f60f43b79fa403240f3557dc3f8018e80495d61e2b089b2607a372a9d"},
    {"symbol.txt", "ADOBE-SYMBOL-ENCODING", ["Adobe-Symbol-Encoding", "AdobeSymbolEncoding"],
     "deb78ca840a429311939b9d165890873f71fb23ef223ceeb144a6c6d641a7e52"},
    {"zdingbat.txt", "ZAPF-DINGBATS-ENCODING", ["Zapf-Dingbats", "Adobe-Zapf-Dingbats"],
     "2d8128a7280cdd47d93272f13c580d7f31fb34586ff65eaf29c7457c224974c0"}
  ]

  @apple [
    {"ARABIC.TXT", "MacArabic", ["Mac-Arabic"],
     "c66a997335e65f40aeee8fd63cd1d3b04b74ad50bf32fbf3e4d7214c9497d428"},
    {"CELTIC.TXT", "MacCeltic", ["Mac-Celtic", "x-mac-celtic"],
     "cbc9da3acce632533cf4b8661b4ee3ab16dc510f782aca99bad8a4fa1a0cc99e"},
    {"CENTEURO.TXT", "MacCentralEurope", ["Mac-Central-Europe", "MacCentEuro"],
     "5f2e262a66a7d08317555835dcc8445f4666928f13f84a19951b19b42fe0b623"},
    {"CHINSIMP.TXT", "MacChineseSimp", ["Mac-Simplified-Chinese", "x-mac-chinesesimp"],
     "0f60d32fc7b4f026ac365ccece18b3031c03be72131ef19ee51ae566851855e3"},
    {"CHINTRAD.TXT", "MacChineseTrad", ["Mac-Traditional-Chinese", "x-mac-chinesetrad"],
     "7e541bfa1d7774bb33cb3de558102b65e1c4dcf76acbbfc263b2288f4d993569"},
    {"CROATIAN.TXT", "MacCroatian", ["Mac-Croatian"],
     "cd3b6a79271664df7e4a935766906961bcfc6bf85cc8b9c877381a22044cf84e"},
    {"CYRILLIC.TXT", "MacCyrillic", ["Mac-Cyrillic"],
     "092ca7d0fe584b3fde176af4f2a175ceeba07b4c1a1c0b472c2016a6c92eafcc"},
    {"DEVANAGA.TXT", "MacDevanagari", ["Mac-Devanagari", "x-mac-devanagari"],
     "65ae8bfdfb279f95d075003256832927a78bd32825970f7098ee90cf503abe6a"},
    {"DINGBATS.TXT", "MacDingbats", ["Mac-Dingbats"],
     "bed8a47f01f770b3175790a35ad6cf9ee118832f6a31dfa86d2947e1a56043a5"},
    {"FARSI.TXT", "MacFarsi", ["Mac-Farsi", "x-mac-farsi"],
     "ae9ed45404c3ecf617fbd4a910717eabe5b811a2b216c5503410c42be3616bce"},
    {"GAELIC.TXT", "MacGaelic", ["Mac-Gaelic", "x-mac-gaelic"],
     "d4a4f0db7de96f2c66d929dafb55045eebdcfb77f426f4fd4b8a4ca560b33641"},
    {"GREEK.TXT", "MacGreek", ["Mac-Greek"],
     "d57b3e0644a54f33396d53f3ca63a8483e96526de0d62be1dcd6eb40399a398e"},
    {"GUJARATI.TXT", "MacGujarati", ["Mac-Gujarati", "x-mac-gujarati"],
     "ab820f324e5e12f6a612289401e4d4c178962c8f5e6930b93cd8de9737ab55b5"},
    {"GURMUKHI.TXT", "MacGurmukhi", ["Mac-Gurmukhi", "x-mac-gurmukhi"],
     "da5a0002ef60c33054d9c52b934af29757f86bf2fac4669fe2e825c1b6aa2f69"},
    {"HEBREW.TXT", "MacHebrew", ["Mac-Hebrew"],
     "1d3e6c3ca5e0f242df9c22fd5d8ddc669f6b60015bac1c3b7cead487523bf9bf"},
    {"ICELAND.TXT", "MacIceland", ["Mac-Iceland"],
     "39b8d242bd0995a3b9f205273f098c1ff9bab4505a213c4e0313a700e47f26ce"},
    {"INUIT.TXT", "MacInuit", ["Mac-Inuit", "x-mac-inuit"],
     "c530d850057be2641415091543c1b0cbb504138fd1773a2fd6bf2a2538d45a58"},
    {"JAPANESE.TXT", "MacJapanese", ["Mac-Japanese", "x-mac-japanese"],
     "a0443474f88dd56c8de52189b8c07c9098b77a396607afe46ed05ff1e8356af4"},
    {"KEYBOARD.TXT", "MacKeyboard", ["Mac-Keyboard", "x-mac-keyboard"],
     "b9b0aca8210c5fe24e2b58bac31d0ef121a4494e3c55cd2bf60e431d665a15dc"},
    {"KOREAN.TXT", "MacKorean", ["Mac-Korean", "x-mac-korean"],
     "23a9bbc95c5dc668a945a6ac07fd2697d353836312df35e3398e0af4c946ebcd"},
    {"ROMAN.TXT", "MacRoman", ["Mac-Roman", "macintosh"],
     "18e571645be895e9553ed5c842ea8f65f9c5d3c9ccb43e66e0c33a132ed0d721"},
    {"ROMANIAN.TXT", "MacRomanian", ["Mac-Romanian", "MacRomania", "x-mac-romanian"],
     "a05436e00507e757e8badb5d582985b3c9d765b07609c2aeae9033dcfa02f43a"},
    {"SYMBOL.TXT", "MacSymbol", ["Mac-Symbol", "x-mac-symbol"],
     "b8c529daba09a45872ec3b493e944680528206b829193594dcdd774a02d49d12"},
    {"THAI.TXT", "MacThai", ["Mac-Thai"],
     "ab10c28e8b2b3ee72ea67eed920d67ca8cb2ee86980294769633dc5d1cc9dbd5"},
    {"TURKISH.TXT", "MacTurkish", ["Mac-Turkish"],
     "afce027def8db108de0607a76f1aae00787a4b2c7a44f68a359d9053c50a30bf"}
  ]

  @documentation_sources [
    %{
      file: "ReadMe.txt",
      vendor: "Adobe",
      sha256: "9a881fa4d86f744685eb59bb534ee56cbe6581748c3f7f3ab4f58e03e54c5391",
      url: @adobe_base <> "ReadMe.txt"
    },
    %{
      file: "ReadMe.txt",
      vendor: "Apple",
      sha256: "238758a906d84ec9bd2c5934738768ea96a9c9f9b1a7465741720cdf3ca48391",
      url: @apple_base <> "ReadMe.txt"
    }
  ]

  @exclusions [
    %{
      file: "CORPCHAR.TXT",
      reason: "Unicode corporate-zone constants without encoded byte mappings"
    },
    %{
      file: "UKRAINE.TXT",
      reason: "notes only; Mac Ukrainian was merged into the Cyrillic mapping"
    }
  ]

  @symbol_files MapSet.new(["DINGBATS.TXT", "KEYBOARD.TXT", "SYMBOL.TXT"])

  def run do
    root = Path.expand("..", __DIR__)
    table_dir = Path.join(root, "priv/tables")
    File.mkdir_p!(table_dir)

    sources = source_specs()
    ensure_sources!(root, sources ++ @documentation_sources)

    encodings =
      sources
      |> Enum.with_index(1)
      |> Enum.map(fn {source, index} -> import_source!(root, table_dir, source, index) end)

    manifest = %{
      format: 1,
      documentation_sources: @documentation_sources,
      encodings: encodings,
      exclusions: @exclusions,
      sources: Enum.map(sources, &Map.drop(&1, [:aliases, :name, :parser]))
    }

    File.write!(
      Path.join(root, "priv/vendor_mappings_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic])
    )

    expected = MapSet.new(Enum.map(encodings, &"#{&1.id}.etf"))

    table_dir
    |> Path.join("vendor_*.etf")
    |> Path.wildcard()
    |> Enum.reject(&MapSet.member?(expected, Path.basename(&1)))
    |> Enum.each(&File.rm!/1)

    IO.puts(
      "wrote #{length(encodings)} vendor codecs, " <>
        "#{Enum.sum(Enum.map(encodings, & &1.decode_mappings))} decode mappings, " <>
        "#{Enum.sum(Enum.map(encodings, & &1.encode_mappings))} encoder mappings"
    )
  end

  defp source_specs do
    adobe =
      Enum.map(@adobe, fn {file, name, aliases, sha256} ->
        %{
          aliases: aliases,
          file: file,
          name: name,
          parser: :adobe,
          sha256: sha256,
          url: @adobe_base <> file,
          vendor: "Adobe"
        }
      end)

    apple =
      Enum.map(@apple, fn {file, name, aliases, sha256} ->
        %{
          aliases: aliases,
          file: file,
          name: name,
          parser: :apple,
          sha256: sha256,
          url: @apple_base <> file,
          vendor: "Apple"
        }
      end)

    adobe ++ apple
  end

  defp ensure_sources!(root, sources) do
    Enum.each(sources, fn source ->
      path = source_path(root, source)
      File.mkdir_p!(Path.dirname(path))

      unless File.exists?(path) do
        case System.cmd("curl", ["-fsSL", source.url], stderr_to_stdout: true) do
          {content, 0} ->
            File.write!(path, content)

          {message, status} ->
            Mix.raise("download failed (#{status}) for #{source.url}: #{message}")
        end
      end

      assert_digest!(File.read!(path), source.sha256, "#{source.vendor}/#{source.file}")
    end)
  end

  defp import_source!(root, table_dir, source, index) do
    mappings =
      root
      |> source_path(source)
      |> File.read!()
      |> parse(source.parser)
      |> maybe_fill_apple_ascii(source)

    {table, metadata} = build_table(mappings)
    id = String.to_atom("vendor_#{String.pad_leading(Integer.to_string(index), 3, "0")}")

    File.write!(
      Path.join(table_dir, "#{id}.etf"),
      :erlang.term_to_binary(table, [:deterministic])
    )

    Map.merge(metadata, %{
      aliases: source.aliases,
      file: source.file,
      id: id,
      index: index,
      name: source.name,
      sha256: source.sha256,
      url: source.url,
      vendor: source.vendor
    })
  end

  defp parse(source, :adobe) do
    source
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      case line |> strip_comment() |> String.split() do
        [unicode, byte | _] ->
          with {codepoint, ""} <- Integer.parse(unicode, 16),
               {encoded, ""} <- Integer.parse(byte, 16),
               true <- encoded <= 0xFF,
               true <- scalar?(codepoint) do
            [{<<encoded>>, {codepoint}}]
          else
            _ -> []
          end

        _ ->
          []
      end
    end)
  end

  defp parse(source, :apple) do
    source
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      case line |> strip_comment() |> String.split() do
        [encoded, unicode | _] ->
          with {:ok, bytes} <- source_bytes(encoded),
               [_ | _] = codepoints <- hex_values(unicode),
               true <- Enum.all?(codepoints, &scalar?/1) do
            [{bytes, List.to_tuple(codepoints)}]
          else
            _ -> []
          end

        _ ->
          []
      end
    end)
  end

  defp maybe_fill_apple_ascii(mappings, %{parser: :apple, file: file}) do
    if MapSet.member?(@symbol_files, file) do
      mappings
    else
      mapped_single_bytes =
        mappings
        |> Enum.flat_map(fn
          {<<byte>>, _codepoints} -> [byte]
          _mapping -> []
        end)
        |> MapSet.new()

      missing_identity =
        0x00..0x7F
        |> Enum.reject(&MapSet.member?(mapped_single_bytes, &1))
        |> Enum.map(&{<<&1>>, {&1}})

      mappings ++ missing_identity
    end
  end

  defp maybe_fill_apple_ascii(mappings, _source), do: mappings

  defp source_bytes(token) do
    values = hex_strings(token)

    if values == [] do
      :error
    else
      values
      |> Enum.reduce_while({:ok, []}, fn hex, {:ok, acc} ->
        if rem(byte_size(hex), 2) == 0 do
          case Base.decode16(hex, case: :mixed) do
            {:ok, bytes} -> {:cont, {:ok, [bytes | acc]}}
            :error -> {:halt, :error}
          end
        else
          {:halt, :error}
        end
      end)
      |> case do
        {:ok, parts} -> {:ok, parts |> Enum.reverse() |> IO.iodata_to_binary()}
        :error -> :error
      end
    end
  end

  defp hex_values(token) do
    token
    |> hex_strings()
    |> Enum.map(&String.to_integer(&1, 16))
  end

  defp hex_strings(token) do
    Regex.scan(~r/0x([0-9A-F]+)/i, token, capture: :all_but_first)
    |> List.flatten()
  end

  defp strip_comment(line), do: line |> String.split("#", parts: 2) |> hd() |> String.trim()

  defp build_table(mappings) do
    {one_map, many, encode} =
      Enum.reduce(mappings, {%{}, %{}, %{}}, fn {bytes, codepoints}, {one, many, encode} ->
        {one, many} =
          if byte_size(bytes) == 1 do
            {Map.put_new(one, :binary.first(bytes), codepoints), many}
          else
            {one, Map.put_new(many, bytes, codepoints)}
          end

        {one, many, Map.put_new(encode, codepoints, bytes)}
      end)

    one = 0x00..0xFF |> Enum.map(&Map.get(one_map, &1)) |> List.to_tuple()

    prefixes =
      Enum.reduce(many, MapSet.new(), fn {bytes, _codepoints}, prefixes ->
        Enum.reduce(1..(byte_size(bytes) - 1), prefixes, fn size, set ->
          MapSet.put(set, binary_part(bytes, 0, size))
        end)
      end)

    max_input =
      mappings |> Enum.map(fn {bytes, _} -> byte_size(bytes) end) |> Enum.max(fn -> 1 end)

    max_codepoints =
      encode |> Map.keys() |> Enum.map(&tuple_size/1) |> Enum.max(fn -> 1 end)

    table = %{
      encode: encode,
      many: many,
      max_codepoints: max_codepoints,
      max_input: max_input,
      one: one,
      prefixes: prefixes
    }

    metadata = %{
      decode_mappings: map_size(one_map) + map_size(many),
      duplicate_decode_rows: length(mappings) - map_size(one_map) - map_size(many),
      encode_mappings: map_size(encode),
      mapping_rows: length(mappings),
      max_codepoints: max_codepoints,
      max_input: max_input
    }

    {table, metadata}
  end

  defp source_path(root, source) do
    vendor = String.downcase(source.vendor)
    Path.join([root, "priv", "sources", "vendor", vendor, source.file])
  end

  defp assert_digest!(content, expected, label) do
    actual = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
    unless actual == expected, do: Mix.raise("#{label} SHA-256 mismatch: #{actual}")
  end

  defp scalar?(codepoint) do
    codepoint in 0..0xD7FF or codepoint in 0xE000..0x10FFFF
  end
end

Iconvex.Specs.Tools.ImportVendorMappings.run()

defmodule Iconvex.Specs.Tools.ImportDotnetCodePages do
  @moduledoc false

  @revision "dbb2178288bb4e1e8f1fde3958be3bd75573c459"
  @aggregate_sha256 "710a341a09f90bec6ec66e01d44620bf6485b4420b92a6075e45f5e38f860cdf"
  @source_url "https://github.com/dotnet/runtime/tree/#{@revision}/src/libraries/System.Text.Encoding.CodePages"
  @files [
    {"LICENSE.TXT", "LICENSE.TXT"},
    {"codepages.nlp", "src/libraries/System.Text.Encoding.CodePages/src/Data/codepages.nlp"},
    {"CodePageNameMappings.csv",
     "src/libraries/System.Text.Encoding.CodePages/src/Data/CodePageNameMappings.csv"},
    {"PreferredCodePageNames.csv",
     "src/libraries/System.Text.Encoding.CodePages/src/Data/PreferredCodePageNames.csv"},
    {"BaseCodePageEncoding.cs",
     "src/libraries/System.Text.Encoding.CodePages/src/System/Text/BaseCodePageEncoding.cs"},
    {"SBCSCodePageEncoding.cs",
     "src/libraries/System.Text.Encoding.CodePages/src/System/Text/SBCSCodePageEncoding.cs"},
    {"EncodingCodePages.cs",
     "src/libraries/System.Text.Encoding.CodePages/tests/EncodingCodePages.cs"},
    {"CodePagesEncodingProvider.cs",
     "src/libraries/System.Text.Encoding.CodePages/src/System/Text/CodePagesEncodingProvider.cs"}
  ]

  def run do
    root = Path.expand("..", __DIR__)
    committed = Path.join([root, "priv", "sources", "dotnet-runtime-codepages"])
    source_root = System.get_env("DOTNET_RUNTIME_SOURCE_DIR") || committed

    sources =
      Enum.map(@files, fn {name, relative} ->
        path =
          if Path.expand(source_root) == Path.expand(committed),
            do: Path.join(committed, name),
            else: Path.join(source_root, relative)

        {name, path}
      end)

    assert_sources!(sources)
    copy_sources(sources, committed)

    nlp = File.read!(Path.join(committed, "codepages.nlp"))
    decode = extract_sbcs!(nlp, 29_001)

    encode =
      decode |> Tuple.to_list() |> Enum.with_index() |> Map.new(fn {cp, byte} -> {cp, byte} end)

    table = %{decode: decode, encode: encode}

    File.write!(
      Path.join(root, "priv/dotnet_codepages.etf"),
      :erlang.term_to_binary(table, [:deterministic, :compressed])
    )

    manifest = %{
      aggregate_sha256: @aggregate_sha256,
      encodings: [
        %{aliases: ["CP29001", "windows-29001", "Europa"], id: :dotnet_x_europa, name: "x-Europa"}
      ],
      format: 1,
      release: ".NET runtime #{@revision}",
      revision: @revision,
      source_url: @source_url,
      sources:
        Enum.map(sources, fn {name, _path} ->
          {name, sha256(File.read!(Path.join(committed, name)))}
        end)
    }

    File.write!(
      Path.join(root, "priv/dotnet_codepages_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic, :compressed])
    )

    IO.puts("wrote .NET x-Europa (CP29001) codec")
  end

  defp extract_sbcs!(binary, wanted) do
    <<_file_name::binary-size(32), _file_version::binary-size(8), count::little-16,
      _unused::little-16, rest::binary>> = binary

    indexes = binary_part(rest, 0, count * 40)

    {_code_page_name, byte_count, offset} =
      indexes
      |> for_each_index([])
      |> Enum.find_value(fn {name, code_page, byte_count, offset} ->
        if code_page == wanted, do: {name, byte_count, offset}
      end) || Mix.raise("code page #{wanted} is absent from codepages.nlp")

    unless byte_count == 1, do: Mix.raise("code page #{wanted} is not SBCS")

    <<_::binary-size(offset), _cp_name::binary-size(32), _version::binary-size(8),
      ^wanted::little-16, 1::little-16, _unicode_replace::little-16, _byte_replace::little-16,
      mappings::binary-size(512), _::binary>> =
      binary

    mappings
    |> then(fn data -> for <<codepoint::little-16 <- data>>, do: codepoint end)
    |> List.to_tuple()
  end

  defp for_each_index(<<>>, result), do: Enum.reverse(result)

  defp for_each_index(
         <<name::binary-size(32), code_page::little-16, byte_count::little-16, offset::little-32,
           rest::binary>>,
         result
       ) do
    name = name |> :unicode.characters_to_binary({:utf16, :little}) |> String.trim_trailing(<<0>>)
    for_each_index(rest, [{name, code_page, byte_count, offset} | result])
  end

  defp assert_sources!(sources) do
    Enum.each(sources, fn {_name, path} ->
      unless File.regular?(path), do: Mix.raise("missing .NET code-page source: #{path}")
    end)

    digest =
      Enum.reduce(sources, :crypto.hash_init(:sha256), fn {name, path}, context ->
        context
        |> :crypto.hash_update(name)
        |> :crypto.hash_update(<<0>>)
        |> :crypto.hash_update(File.read!(path))
      end)
      |> :crypto.hash_final()
      |> Base.encode16(case: :lower)

    unless digest == @aggregate_sha256,
      do: Mix.raise("unexpected .NET code-page source-set SHA-256: #{digest}")
  end

  defp copy_sources(sources, committed) do
    File.mkdir_p!(committed)

    Enum.each(sources, fn {name, path} ->
      target = Path.join(committed, name)
      if Path.expand(path) != Path.expand(target), do: File.cp!(path, target)
    end)
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

Iconvex.Specs.Tools.ImportDotnetCodePages.run()

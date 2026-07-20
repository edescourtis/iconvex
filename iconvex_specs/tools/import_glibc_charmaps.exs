defmodule Iconvex.Specs.Tools.ImportGlibcCharmaps do
  @moduledoc false

  @revision "cdfa80fad3d52217ae986f9acdcbdbfc94b3da3e"
  @source_base "https://sourceware.org/git/?p=glibc.git;a=blob_plain;f=localedata/charmaps"

  @sources [
    {"TSCII", "7c6fbda96b4ec82701d330926b5d3ef710d37a53dd33daccb6f758fb76bbffbb", ["TSCII-1.7"]},
    {"BRF", "99c43b9b82fe6c030fa3ae77cf5b77affb2ae7afbc508f0a9bd7fc10b5c5aac8",
     ["Braille-Ready-Format", "Braille-ASCII"]},
    {"CP770", "3ad3fbdb0bfb64f2c4bcc57fe1990b770c036e0ad29462c82a6f90df59bd30ee", []},
    {"CP771", "7b3b2f9ab3a79c76a13af24d6ef941a4c071aea5097262b621ef622487abe74e", []},
    {"CP772", "0164ca34adeae4e20df664244790567c1c7f926321edd5c4749cb8cbd5e0a710", []},
    {"CP773", "e333143fc6055ee0e859e1896f847efd3127e47c200793ec7d58178f4b2b9746", []},
    {"CP774", "6782c602262aefc262ad181bf70d4276486598539b54366952087ef09b2e83ee", []},
    {"CWI", "9db1d52c1715a58d6c6087e27e71ad00130583e131dd635313494447b4afef09", []},
    {"EBCDIC-IS-FRISS", "ec3c96ff1890be4a967a72cb6bd862ad69379b519208006cb5e91a294ccd875f", []},
    {"EUC-JP-MS", "6332f84614653fa07eb5a0f85d7c4b33a893d001e0897b0bf1851428d312831a", []},
    {"HP-GREEK8", "1ad34a6ac36498df141c9167dadb9cf8d763c59c6b0ecf06d574f3920c44f479", []},
    {"HP-ROMAN9", "def3a05b4f76619805d0fa166450e0706c018c27645265bc1b0ec3a499ae4ae2", []},
    {"HP-THAI8", "5dd136ccaa7ae5af57fdff51a89f8d01985bf1210a03a44b73fe9f28ff147d8e", []},
    {"HP-TURKISH8", "f2bd7c0ff44cccefe41a7adb28922b3e72a44c11b52396b7a9a0ea2343880322", []},
    {"IBM1004", "8cb639c1a6d8379846fa57e17788751d162093f5bc34fe51e5c3344807d7f269", []},
    {"IBM256", "d8e9478224815aa1fefc19dec218baf5424d74c3e66ea3602f90c15c6a3fe5c6", []},
    {"IBM866NAV", "6833d2535df35a0b0727dfe7b34a79cbc092ca1c3e78860f1fae34bb95edf3b1", []},
    {"ISIRI-3342", "629a77aaef08bcfd748df04aa3860a783535e2a275476975ad46ec5506256a1d", []},
    {"ISO-8859-9E", "e368178471f3e8e39f3c33f97ad48dfb4219e7ca3039052b86a75adbc46ea5a8", []},
    {"ISO-IR-197", "d3dc8184fda4c6bf29bee0b39913d5319728be42bf5d05a08cbe2a425d24c938", []},
    {"ISO-IR-209", "a05ea18e6cba72bd760962bbff62b5d565ea47a92700a08f56e7027a67785d0c", []},
    {"ISO_11548-1", "22875150c840de85c6540eef1de37d6f7f80fe557df30ed3ece8e2d88449bc30", []},
    {"ISO_6937", "c23ed54e7eb6d1fc5c07a2a36bd54d4d2160dc1754aa964727ba60d49ee4e638", []},
    {"KOI-8", "093460d5fc6a36e09b2f979fc77fad1e26a777c868e86a9661e1767e3dba708b", []},
    {"MAC-IS", "0776bc66ff835ed599df9d8890f2b46801ae59cb57e9bdcf3e525fb68de93cd6", []},
    {"MAC-SAMI", "7d4ff8ebf5703dedaed283198110680e995be798138d8522027974a9af26e1ab", []},
    {"MAC-UK", "850568cea44108e85df6d1835d0079a47f870e99d5cc01acc89aa1f2cdea3083", []},
    {"MIK", "7379b739a932b265715c6051464cd07078975089622ee57908a899af39c2bc57", []},
    {"SAMI-WS2", "2148faaedbe5021633fe61805978730458ba612b996a71aeeddb01bab1dc714e", []}
  ]

  def run do
    root = Path.expand("..", __DIR__)
    table_dir = Path.join(root, "priv/tables")

    sources = Enum.map(@sources, &source/1)

    encodings =
      sources
      |> Enum.with_index(1)
      |> Enum.map(fn {source, index} -> import(root, table_dir, source, index) end)

    manifest = %{
      format: 1,
      encodings: encodings,
      revision: @revision,
      sources:
        Enum.zip_with(sources, encodings, fn source, encoding ->
          source
          |> Map.drop([:extra_aliases])
          |> Map.put(:name, encoding.name)
        end)
    }

    File.write!(
      Path.join(root, "priv/glibc_charmaps_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic])
    )

    IO.puts("wrote #{length(encodings)} glibc charmap codecs")
  end

  defp import(root, table_dir, source, index) do
    path = Path.join([root, "priv", "sources", "glibc", source.file])
    File.mkdir_p!(Path.dirname(path))

    unless File.exists?(path) do
      case System.cmd("curl", ["-fsSL", source.url], stderr_to_stdout: true) do
        {content, 0} -> File.write!(path, content)
        {message, status} -> Mix.raise("download failed (#{status}): #{message}")
      end
    end

    content = File.read!(path)
    assert_digest!(content, source)
    metadata = parse_metadata(content, source.extra_aliases)
    mappings = parse(content)
    table = build_table(mappings)
    id = String.to_atom("glibc_charmap_#{index}")

    File.write!(
      Path.join(table_dir, "#{id}.etf"),
      :erlang.term_to_binary(table, [:deterministic])
    )

    %{
      aliases: metadata.aliases,
      decode_mappings: count_decode(table),
      encode_mappings: map_size(table.encode),
      excluded_aliases: metadata.excluded_aliases,
      id: id,
      index: index,
      name: metadata.name,
      source_file: source.file
    }
  end

  defp source({file, sha256, extra_aliases}) do
    %{
      extra_aliases: extra_aliases,
      file: file,
      sha256: sha256,
      url: "#{@source_base}/#{file};hb=#{@revision}"
    }
  end

  defp parse_metadata(content, extra_aliases) do
    [name] = Regex.run(~r/^<code_set_name>\s+(.+)$/m, content, capture: :all_but_first)

    source_aliases =
      content
      |> then(&Regex.scan(~r/^% alias\s+(.+)$/m, &1, capture: :all_but_first))
      |> List.flatten()
      |> Kernel.++(extra_aliases)
      |> Enum.uniq()

    {aliases, excluded_aliases} = Enum.split_with(source_aliases, &registerable_name?/1)

    %{
      name: name,
      aliases: aliases,
      excluded_aliases: excluded_aliases
    }
  end

  defp registerable_name?(name) do
    not String.contains?(name, "/") and String.match?(name, ~r/^[\x21-\x7e]+$/)
  end

  defp parse(content) do
    content
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      case Regex.run(
             ~r/^(?:%IRREVERSIBLE%)?((?:<U[0-9A-Fa-f]+>)+)\s+((?:\/x[0-9A-Fa-f]{2})+)/,
             line,
             capture: :all_but_first
           ) do
        [unicode, encoded] ->
          codepoints =
            Regex.scan(~r/<U([0-9A-Fa-f]+)>/, unicode, capture: :all_but_first)
            |> List.flatten()
            |> Enum.map(&String.to_integer(&1, 16))

          bytes =
            Regex.scan(~r/\/x([0-9A-Fa-f]{2})/, encoded, capture: :all_but_first)
            |> List.flatten()
            |> Enum.map(&String.to_integer(&1, 16))
            |> :binary.list_to_bin()

          [{bytes, List.to_tuple(codepoints)}]

        nil ->
          []
      end
    end)
  end

  defp build_table(mappings) do
    {one, many, encode} =
      Enum.reduce(mappings, {%{}, %{}, %{}}, fn {bytes, codepoints}, {one, many, encode} ->
        {one, many} =
          if byte_size(bytes) == 1,
            do: {Map.put_new(one, :binary.first(bytes), codepoints), many},
            else: {one, Map.put_new(many, bytes, codepoints)}

        {one, many, Map.put_new(encode, codepoints, bytes)}
      end)

    prefixes =
      Enum.reduce(many, MapSet.new(), fn {bytes, _}, set ->
        Enum.reduce(1..(byte_size(bytes) - 1), set, &MapSet.put(&2, binary_part(bytes, 0, &1)))
      end)

    %{
      encode: encode,
      many: many,
      max_codepoints: encode |> Map.keys() |> Enum.map(&tuple_size/1) |> Enum.max(),
      max_input: mappings |> Enum.map(fn {bytes, _} -> byte_size(bytes) end) |> Enum.max(),
      one: 0..255 |> Enum.map(&Map.get(one, &1)) |> List.to_tuple(),
      prefixes: prefixes
    }
  end

  defp count_decode(table),
    do: map_size(table.many) + Enum.count(Tuple.to_list(table.one), &(not is_nil(&1)))

  defp assert_digest!(content, source) do
    actual = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
    unless actual == source.sha256, do: Mix.raise("#{source.file} SHA-256 mismatch: #{actual}")
  end
end

Iconvex.Specs.Tools.ImportGlibcCharmaps.run()

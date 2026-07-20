defmodule Iconvex.Specs.Tools.ICUArchiveDifferential do
  @moduledoc false

  @source_directory Path.expand("../priv/sources/icu-data-archive", __DIR__)

  def run do
    root = Path.expand("..", __DIR__)
    makeconv = executable!("ICU_MAKECONV", "/opt/homebrew/opt/icu4c/bin/makeconv")
    pkgdata = executable!("ICU_PKGDATA", "/opt/homebrew/opt/icu4c/bin/pkgdata")
    oracle = executable!("ICU_UCM_ORACLE", Path.join(System.tmp_dir!(), "iconvex_icu_ucm_oracle"))

    work =
      Path.join(System.tmp_dir!(), "iconvex-icu-archive-#{System.unique_integer([:positive])}")

    File.mkdir_p!(work)

    try do
      {accepted, rejected, digest} = compile_sources(work, makeconv)
      package = package!(work, pkgdata, accepted)
      {cases, digest} = audit(root, oracle, package, accepted, digest)
      compiled = length(accepted)
      digest = digest |> :crypto.hash_final() |> Base.encode16(case: :lower)
      write_report(root, compiled, rejected, cases, digest)

      IO.puts(
        "ICU archive differential: #{compiled} compiled, #{length(rejected)} rejected, " <>
          "#{cases} cases, SHA-256 #{digest}"
      )
    after
      File.rm_rf!(work)
    end
  end

  defp compile_sources(work, makeconv) do
    Iconvex.Specs.ICUArchive.encodings()
    |> Enum.reduce({[], [], :crypto.hash_init(:sha256)}, fn entry, {accepted, rejected, digest} ->
      source = Path.join(@source_directory, entry.source_file)

      case System.cmd(
             makeconv,
             ["-q", "--ignore-siso-check", "-d", work, source],
             stderr_to_stdout: true
           ) do
        {_output, 0} ->
          {[entry | accepted], rejected, digest}

        {reason, _status} ->
          normalized = normalize_reason(reason)
          digest = :crypto.hash_update(digest, entry.name <> <<0, 0>> <> normalized)
          {accepted, [{entry.name, normalized} | rejected], digest}
      end
    end)
    |> then(fn {accepted, rejected, digest} ->
      {Enum.reverse(accepted), Enum.reverse(rejected), digest}
    end)
  end

  defp package!(work, pkgdata, accepted) do
    package_name = "iconvex_archive"
    list_path = Path.join(work, "package-list.txt")
    package_path = Path.join(work, package_name)

    File.write!(
      list_path,
      Enum.map_join(accepted, "\n", &(Path.rootname(&1.source_file) <> ".cnv")) <> "\n"
    )

    case System.cmd(
           pkgdata,
           [
             "-q",
             "-m",
             "common",
             "-p",
             package_name,
             "-s",
             work,
             "-d",
             work,
             list_path
           ],
           stderr_to_stdout: true
         ) do
      {_output, 0} -> package_path
      {output, status} -> raise("pkgdata failed with #{status}: #{output}")
    end
  end

  defp audit(root, oracle, package, accepted, digest) do
    accepted_indexes = MapSet.new(accepted, & &1.index)

    Iconvex.Specs.ICUArchive.encodings()
    |> Enum.zip(Iconvex.Specs.ICUArchive.codecs())
    |> Enum.reduce({0, 0, digest}, fn {entry, codec}, {validated, count, digest} ->
      if MapSet.member?(accepted_indexes, entry.index) do
        table =
          root
          |> Path.join("priv/tables/#{entry.id}.etf")
          |> File.read!()
          |> :erlang.binary_to_term()

        requests = requests(entry, table)
        request_path = Path.join(System.tmp_dir!(), "iconvex-archive-#{entry.index}.requests")
        File.write!(request_path, Enum.map_join(requests, "\n", &request_line/1) <> "\n")

        {output, 0} =
          System.cmd(oracle, [entry.source_name, request_path],
            env: [{"ICU_UCM_PACKAGE", package}],
            stderr_to_stdout: true
          )

        File.rm!(request_path)
        results = String.split(output, "\n", trim: true)

        unless length(results) == length(requests),
          do: raise("#{entry.name}: oracle returned the wrong result count")

        Enum.zip(requests, results)
        |> Enum.each(fn {request, result} -> compare!(codec, entry.name, request, result) end)

        digest =
          digest
          |> :crypto.hash_update(entry.name)
          |> :crypto.hash_update(<<0>>)
          |> :crypto.hash_update(output)

        if rem(validated + 1, 100) == 0,
          do: IO.puts("validated #{validated + 1} archive converters")

        {validated + 1, count + length(requests), digest}
      else
        {validated, count, digest}
      end
    end)
    |> then(fn {validated, cases, digest} ->
      unless validated == length(accepted),
        do: raise("not every compiled converter was validated")

      {cases, digest}
    end)
  end

  defp requests(%{stateful: true}, table) do
    sbcs =
      table.sbcs_decode
      |> Tuple.to_list()
      |> Enum.with_index()
      |> Enum.reject(fn {mapping, byte} -> is_nil(mapping) or byte in [0x0E, 0x0F] end)
      |> Enum.map(fn {_mapping, byte} -> {:decode, <<byte>>} end)

    dbcs =
      table.dbcs_decode
      |> Map.keys()
      |> Enum.sort()
      |> Enum.map(&{:decode, <<0x0E, &1::binary, 0x0F>>})

    encodes = table.encode |> Map.keys() |> Enum.sort() |> Enum.map(&{:encode, &1})
    sbcs ++ dbcs ++ encodes
  end

  defp requests(_entry, table) do
    one =
      table.one
      |> Tuple.to_list()
      |> Enum.with_index()
      |> Enum.reject(fn {mapping, _byte} -> is_nil(mapping) end)
      |> Enum.map(fn {_mapping, byte} -> {:decode, <<byte>>} end)

    many = table.many |> Map.keys() |> Enum.sort() |> Enum.map(&{:decode, &1})
    encodes = table.encode |> Map.keys() |> Enum.sort() |> Enum.map(&{:encode, &1})
    one ++ many ++ encodes
  end

  defp request_line({:decode, bytes}), do: "D " <> Base.encode16(bytes)

  defp request_line({:encode, codepoints}),
    do: "E " <> (codepoints |> Tuple.to_list() |> Enum.map_join(",", &hex/1))

  defp compare!(codec, name, {:decode, bytes}, "OK " <> codepoints) do
    expected = codepoints |> String.split(",") |> Enum.map(&String.to_integer(&1, 16))

    unless codec.decode(bytes) == {:ok, expected},
      do: raise("#{name}: decode #{Base.encode16(bytes)} differs from ICU")
  end

  defp compare!(codec, name, {:encode, codepoints}, "OK " <> bytes) do
    expected = Base.decode16!(bytes, case: :mixed)

    unless codec.encode(Tuple.to_list(codepoints)) == {:ok, expected},
      do: raise("#{name}: encode #{inspect(codepoints)} differs from ICU")
  end

  defp compare!(_codec, name, request, result),
    do: raise("#{name}: unexpected ICU result #{inspect(result)} for #{inspect(request)}")

  defp executable!(variable, default) do
    path = System.get_env(variable) || default
    unless File.exists?(path), do: raise("set #{variable} to the required executable")
    path
  end

  defp normalize_reason(reason) do
    diagnostics =
      reason
      |> String.split(~r/\R/, trim: true)
      |> Enum.map(fn line ->
        line
        |> String.trim()
        |> String.replace(~r/"[^"\r\n]*\/([^"\/]+\.(?:ucm|cnv))"/, "\"\\1\"")
      end)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    summary = diagnostics |> Enum.take(3) |> Enum.join("; ")

    if length(diagnostics) > 3,
      do: summary <> " (+#{length(diagnostics) - 3} more unique diagnostics)",
      else: summary
  end

  defp write_report(root, compiled, rejected, cases, digest) do
    lines = [
      "# ICU historical archive differential",
      "",
      "ICU 78.3 `makeconv` independently compiled #{compiled} of the 1,050 pinned UCM",
      "sources. All #{cases} strict mappings from the accepted sources matched ICU's C",
      "runtime oracle. The remaining #{length(rejected)} legacy files are retained and",
      "exhaustively tested from source, but modern `makeconv` rejects their old metadata.",
      "",
      "Oracle transcript SHA-256: `#{digest}`.",
      "",
      "## Modern makeconv rejections",
      "",
      "| Canonical archive codec | Normalized diagnostic |",
      "|---|---|"
    ]

    rows =
      Enum.map(rejected, fn {name, reason} ->
        escaped = String.replace(reason, "|", "\\|")
        "| `#{name}` | #{escaped} |"
      end)

    File.write!(
      Path.join(root, "ICU_ARCHIVE_DIFFERENTIAL.md"),
      Enum.join(lines ++ rows, "\n") <> "\n"
    )
  end

  defp hex(integer), do: integer |> Integer.to_string(16) |> String.upcase()
end

Iconvex.Specs.Tools.ICUArchiveDifferential.run()

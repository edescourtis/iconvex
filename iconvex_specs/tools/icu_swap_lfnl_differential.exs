defmodule Iconvex.Specs.Tools.ICUSwapLFNLDifferential do
  @moduledoc false

  def run do
    root = Path.expand("..", __DIR__)
    uconv = find_uconv!()
    oracle = compile_oracle!(root)
    {version, 0} = System.cmd(uconv, ["--version"], stderr_to_stdout: true)
    temp = Path.join(System.tmp_dir!(), "iconvex-swaplfnl-#{System.unique_integer([:positive])}")
    File.mkdir_p!(temp)

    try do
      custom_data = build_ibm_924_data!(root, temp)

      {rows, digest, decode_cases, encode_cases} =
        Iconvex.Specs.ICUSwapLFNL.encodings()
        |> Enum.zip(Iconvex.Specs.ICUSwapLFNL.codecs())
        |> Enum.reduce({[], :crypto.hash_init(:sha256), 0, 0}, fn {entry, codec},
                                                                  {rows, digest, dc, ec} ->
          {row, transcript, decoded, encoded} =
            audit_one!(oracle, temp, custom_data, entry, codec)

          {[row | rows], :crypto.hash_update(digest, transcript), dc + decoded, ec + encoded}
        end)

      transcript_sha256 =
        digest |> :crypto.hash_final() |> Base.encode16(case: :lower)

      write_report(
        root,
        String.trim(version),
        Enum.reverse(rows),
        decode_cases,
        encode_cases,
        transcript_sha256
      )

      IO.puts(
        "verified #{decode_cases} decode + #{encode_cases} encode mappings; " <>
          "transcript #{transcript_sha256}"
      )
    after
      File.rm_rf!(temp)
    end
  end

  defp audit_one!(oracle, temp, custom_data, entry, codec) do
    base_table = Iconvex.Tables.fetch!(%{id: entry.base_id, table_app: :iconvex_specs})
    codepoints = base_table.encode |> Map.keys() |> Enum.sort()
    requests = Enum.map(0..255, &{:decode, <<&1>>}) ++ Enum.map(codepoints, &{:encode, &1})
    request_path = Path.join(temp, "requests-#{entry.index}.txt")
    request_lines = Enum.map(requests, &request_line/1)
    File.write!(request_path, Enum.join(request_lines, "\n") <> "\n")

    {output, 0} =
      System.cmd(oracle, [entry.name, request_path],
        env: oracle_env(entry, custom_data),
        stderr_to_stdout: true
      )

    results = String.split(output, "\n", trim: true)

    unless length(results) == length(requests),
      do: raise("#{entry.name}: oracle returned #{length(results)}/#{length(requests)} results")

    Enum.zip(requests, results)
    |> Enum.each(fn {request, result} -> compare!(codec, entry.name, request, result) end)

    transcript =
      Enum.zip(request_lines, results)
      |> Enum.map(fn {request, result} -> [entry.name, <<0>>, request, <<0>>, result, <<0>>] end)
      |> IO.iodata_to_binary()

    row =
      "| `#{entry.name}` | 256/256 | #{length(codepoints)}/#{length(codepoints)} | exact |"

    {row, transcript, 256, length(codepoints)}
  end

  defp request_line({:decode, bytes}), do: "D " <> Base.encode16(bytes)

  defp request_line({:encode, codepoints}) do
    "E " <> (codepoints |> Tuple.to_list() |> Enum.map_join(",", &Integer.to_string(&1, 16)))
  end

  defp compare!(codec, name, {:decode, bytes}, result) do
    ours = codec.decode(bytes)

    oracle =
      case result do
        "ERR" -> :error
        "OK " <> values -> {:ok, parse_codepoints(values)}
      end

    unless (match?({:ok, _}, ours) and ours == oracle) or
             (match?({:error, _, _, _}, ours) and oracle == :error) do
      raise "#{name}: decode #{Base.encode16(bytes)} ours=#{inspect(ours)} ICU=#{inspect(oracle)}"
    end
  end

  defp compare!(codec, name, {:encode, codepoints}, result) do
    ours = codec.encode(Tuple.to_list(codepoints))

    oracle =
      case result do
        "ERR" -> :error
        "OK " <> bytes -> {:ok, Base.decode16!(bytes)}
      end

    unless ours == oracle do
      raise "#{name}: encode #{inspect(codepoints)} ours=#{inspect(ours)} ICU=#{inspect(oracle)}"
    end
  end

  defp parse_codepoints(""), do: []

  defp parse_codepoints(values),
    do: values |> String.split(",") |> Enum.map(&String.to_integer(&1, 16))

  defp build_ibm_924_data!(root, temp) do
    makeconv = executable!("ICU_MAKECONV", "/opt/homebrew/opt/icu4c/bin/makeconv")
    pkgdata = executable!("ICU_PKGDATA", "/opt/homebrew/opt/icu4c/bin/pkgdata")
    source = Path.join(root, "priv/sources/icu-data-archive/ibm-924_P100-1998.ucm")
    {_, 0} = System.cmd(makeconv, ["-q", "-d", temp, source], stderr_to_stdout: true)
    list = Path.join(temp, "package-list.txt")
    File.write!(list, "ibm-924_P100-1998.cnv\n")

    {_, 0} =
      System.cmd(
        pkgdata,
        ["-q", "-m", "common", "-p", "icudt78l", "-s", temp, "-d", temp, list],
        stderr_to_stdout: true
      )

    temp
  end

  defp oracle_env(%{base_name: "ibm-924_P100-1998"}, custom_data),
    do: [{"ICU_DATA", custom_data}]

  defp oracle_env(_entry, _custom_data), do: []

  defp write_report(root, version, rows, decode_cases, encode_cases, digest) do
    contents = [
      "# ICU `swaplfnl` differential",
      "",
      "Independent oracle: **#{version}**.",
      "",
      "All #{decode_cases} possible byte decodes and all #{encode_cases} canonical encoder",
      "mappings matched byte-for-byte. Transcript SHA-256: `#{digest}`.",
      "",
      "| Encoding | Decode mappings | Encode mappings | Result |",
      "|---|---:|---:|---|"
      | rows
    ]

    File.write!(
      Path.join(root, "ICU_SWAP_LFNL_DIFFERENTIAL.md"),
      Enum.join(contents, "\n") <> "\n"
    )
  end

  defp find_uconv! do
    System.get_env("ICU_UCONV") ||
      System.find_executable("uconv") ||
      Path.wildcard("/opt/homebrew/Cellar/icu4c*/**/bin/uconv")
      |> Enum.sort()
      |> List.last() ||
      raise "set ICU_UCONV to an ICU uconv executable"
  end

  defp executable!(environment, default) do
    executable = System.get_env(environment) || default
    if File.exists?(executable), do: executable, else: raise("missing executable #{executable}")
  end

  defp compile_oracle!(root) do
    output = Path.join(System.tmp_dir!(), "iconvex_icu_ucm_oracle")
    source = Path.join(root, "tools/icu_ucm_oracle.c")
    pkg_config = System.find_executable("pkg-config") || raise "pkg-config is required"
    cc = System.find_executable("cc") || raise "a C compiler is required"
    pkg_env = [{"PKG_CONFIG_PATH", "/opt/homebrew/opt/icu4c/lib/pkgconfig"}]
    {cflags, 0} = System.cmd(pkg_config, ["--cflags", "icu-uc"], env: pkg_env)
    {libs, 0} = System.cmd(pkg_config, ["--libs", "icu-uc"], env: pkg_env)
    args = String.split(cflags) ++ [source, "-o", output] ++ String.split(libs)
    {compiler_output, status} = System.cmd(cc, args, stderr_to_stdout: true)
    unless status == 0, do: raise("oracle compilation failed: #{compiler_output}")
    output
  end
end

Iconvex.Specs.Tools.ICUSwapLFNLDifferential.run()

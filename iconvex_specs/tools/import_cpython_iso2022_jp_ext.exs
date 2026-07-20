defmodule Iconvex.Specs.Tools.ImportCPythonISO2022JPExt do
  @moduledoc false

  @version "3.14.6"
  @revision "c63aec69bd59c55314c06c23f4c22c03de76fe45"
  @sources %{
    "_codecs_iso2022.c" => "1dec516ad16a9aa179770b5accdd20efa77e7265c0a2a06d8d8913e4524c4010",
    "mappings_jp.h" => "09012ff9eb963073d42a8bce375c05484219537caa0cc2aa74baa63d5f3f1658",
    "iso2022_jp_ext.py" => "f4c9ed8f3031995faa224bcb10153d2b6144944477d1f27d1a6cc4a879fac34c"
  }

  def run do
    root = Path.expand("..", __DIR__)
    destination = Path.join([root, "priv", "sources", "cpython-#{@version}-iso2022-jp-ext"])
    source_dir = System.get_env("CPYTHON_ISO2022_SOURCE_DIR")
    File.mkdir_p!(destination)

    sources =
      Enum.map(@sources, fn {filename, digest} ->
        content = load(filename, source_dir)
        assert_digest!(filename, content, digest)
        File.write!(Path.join(destination, filename), content)
        %{file: filename, sha256: digest, url: url(filename)}
      end)
      |> Enum.sort_by(& &1.file)

    manifest = %{
      codec: "iso2022_jp_ext",
      cpython_version: @version,
      designations: [:jisx0208, :jisx0212, :jisx0201_roman, :jisx0201_kana, :jisx0208_1978],
      flags: [:no_shift, :use_jisx0208_ext],
      revision: @revision,
      sources: sources
    }

    File.write!(
      Path.join(destination, "manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic])
    )

    IO.puts("pinned CPython #{@version} iso2022_jp_ext sources at #{@revision}")
  end

  defp load(filename, nil) do
    case System.cmd("curl", ["-fsSL", url(filename)], stderr_to_stdout: true) do
      {content, 0} -> content
      {message, status} -> raise("download #{filename} failed (#{status}): #{message}")
    end
  end

  defp load(filename, directory), do: File.read!(Path.join(directory, filename))

  defp url("iso2022_jp_ext.py"),
    do:
      "https://raw.githubusercontent.com/python/cpython/v#{@version}/Lib/encodings/iso2022_jp_ext.py"

  defp url(filename),
    do:
      "https://raw.githubusercontent.com/python/cpython/v#{@version}/Modules/cjkcodecs/#{filename}"

  defp assert_digest!(filename, content, expected) do
    actual = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
    unless actual == expected, do: raise("#{filename} SHA-256 mismatch: #{actual}")
  end
end

Iconvex.Specs.Tools.ImportCPythonISO2022JPExt.run()

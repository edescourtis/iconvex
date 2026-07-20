defmodule Iconvex.Specs.Tools.ImportIBMUnicodeCCSIDs do
  @moduledoc false

  @ibm_url "https://www.ibm.com/docs/en/i/7.4.0?topic=information-ccsid-values-defined-i"
  @ibm_sha256 "d0682e71d66de77bd518cda1e82377474bdb78cd6dd87b0c17cbccdc25c67dfb"

  def run do
    root = Path.expand("..", __DIR__)
    output = Path.join([root, "priv", "sources", "ibm-unicode-ccsids"])
    File.mkdir_p!(output)
    destination = Path.join(output, "ccsid-values-defined-i.html")
    source = System.get_env("IBM_CCSID_SOURCE")

    contents =
      cond do
        source -> File.read!(source)
        File.regular?(destination) -> File.read!(destination)
        true -> download!(@ibm_url)
      end

    assert_hash!(contents)
    assert_rows!(contents)
    File.write!(destination, contents)

    File.write!(
      Path.join(root, "IBM_UNICODE_CCSIDS.md"),
      """
      # IBM Unicode CCSIDs

      ICU 78.3 classifies `ibm-1200` and `ibm-13488` as byte-identical
      aliases of BOM-less UTF-16BE. Iconvex exposes both IBM names through
      one native Elixir codec and preserves the explicit IBM namespace.

      `ibm-61952` is intentionally not registered: ICU's primary converter
      registry says it is not a valid CCSID because it denotes Unicode 1.1,
      while IBM i labels it an obsolete UCS CCSID and recommends 13488.

      | Encoding | Aliases | Wire semantics |
      |---|---|---|
      | `IBM-1200` | `IBM-1201`, `IBM-13488`, `IBM-13489`, `IBM-17584`, `IBM-17585`, `IBM-21680`, `IBM-21681`, `IBM-25776`, `IBM-25777`, `IBM-29872`, `IBM-29873`, `IBM-61955`, `IBM-61956`; each also accepts `IBMnnn` and `CCSIDnnn` | BOM-less UTF-16BE |

      - IBM source: #{@ibm_url}
      - IBM source SHA-256: `#{@ibm_sha256}`
      - ICU source: pinned `priv/sources/icu-78.3-unicode-variants/convrtrs.txt`
      """
    )

    IO.puts("pinned IBM UTF-16BE CCSID aliases")
  end

  defp download!(url) do
    case System.cmd("curl", ["-fsSL", url], stderr_to_stdout: true) do
      {contents, 0} -> contents
      {message, status} -> Mix.raise("IBM CCSID download failed (#{status}): #{message}")
    end
  end

  defp assert_hash!(contents) do
    actual = sha256(contents)
    unless actual == @ibm_sha256, do: Mix.raise("IBM CCSID source SHA-256 mismatch: #{actual}")
  end

  defp assert_rows!(contents) do
    for {ccsid, description} <- [
          {"01200", "Unicode: UTF-16, big endian"},
          {"13488", "Unicode: UTF-16 as defined in the Unicode Standard"},
          {"61952", "old CCSID for UCS"}
        ] do
      unless contents =~ ccsid and contents =~ description,
        do: Mix.raise("IBM CCSID #{ccsid} source row changed")
    end
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

Iconvex.Specs.Tools.ImportIBMUnicodeCCSIDs.run()

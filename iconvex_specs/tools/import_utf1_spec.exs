defmodule Iconvex.Specs.Tools.ImportUTF1Spec do
  @moduledoc false

  @sha256 "8dec8d49819ad66e7433cbe71ae476bd5d4aad2fc8c81d641b289fb5c0adb9a0"
  @url "https://itscj.ipsj.or.jp/ir/178.pdf"

  def run do
    root = Path.expand("..", __DIR__)
    committed = Path.join([root, "priv", "sources", "iso-ir-178.pdf"])
    source_path = System.get_env("UTF1_SPEC_PDF") || committed
    contents = File.read!(source_path)
    actual = :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)
    unless actual == @sha256, do: Mix.raise("ISO-IR-178 SHA-256 mismatch: #{actual}")
    if Path.expand(source_path) != Path.expand(committed), do: File.cp!(source_path, committed)

    manifest = %{
      format: 1,
      registration: 178,
      registered: "1993-01-21",
      source: %{name: "ISO-IR-178", sha256: @sha256, url: @url}
    }

    File.write!(
      Path.join(root, "priv/utf1_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic])
    )

    IO.puts("pinned ISO-IR-178 UTF-1 specification")
  end
end

Iconvex.Specs.Tools.ImportUTF1Spec.run()

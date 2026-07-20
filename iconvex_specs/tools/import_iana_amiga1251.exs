defmodule Iconvex.Specs.Tools.ImportIANAAmiga1251 do
  @moduledoc false

  @source_url "https://www.iana.org/assignments/charset-reg/Amiga-1251"
  @source_sha256 "3ca52cd54dbbbe861bdfcbf4bd7a6a1c8521d5d8ccd3291e17f4b5d50083cd0d"

  def run do
    root = Path.expand("..", __DIR__)
    committed = Path.join([root, "priv", "sources", "iana", "Amiga-1251"])
    source = load_source(committed)

    unless sha256(source) == @source_sha256,
      do: Mix.raise("IANA Amiga-1251 source SHA-256 mismatch")

    mappings =
      Regex.scan(~r/^0x([0-9A-Fa-f]{2})\s+0x([0-9A-Fa-f]{4,6})\b/m, source,
        capture: :all_but_first
      )
      |> Map.new(fn [byte, codepoint] ->
        {String.to_integer(byte, 16), String.to_integer(codepoint, 16)}
      end)

    unless map_size(mappings) == 256 and Enum.sort(Map.keys(mappings)) == Enum.to_list(0..255),
      do: Mix.raise("IANA Amiga-1251 table is incomplete")

    decode = 0..255 |> Enum.map(&Map.fetch!(mappings, &1)) |> List.to_tuple()
    encode = Map.new(mappings, fn {byte, codepoint} -> {codepoint, byte} end)

    File.write!(
      Path.join(root, "priv/iana_amiga1251.etf"),
      :erlang.term_to_binary(%{decode: decode, encode: encode}, [:deterministic, :compressed])
    )

    manifest = %{
      encodings: [
        %{
          aliases: ["Ami1251", "Amiga1251", "Ami-1251", "csAmiga1251"],
          id: :iana_amiga1251,
          name: "Amiga-1251"
        }
      ],
      format: 1,
      source_sha256: @source_sha256,
      source_url: @source_url
    }

    File.write!(
      Path.join(root, "priv/iana_amiga1251_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic, :compressed])
    )

    IO.puts("wrote IANA Amiga-1251 codec")
  end

  defp load_source(committed) do
    case System.get_env("IANA_AMIGA1251_SOURCE") do
      nil ->
        if File.regular?(committed) do
          File.read!(committed)
        else
          {body, 0} = System.cmd("curl", ["-fsSL", @source_url])

          File.mkdir_p!(Path.dirname(committed))
          File.write!(committed, body)
          body
        end

      path ->
        source = File.read!(path)
        File.mkdir_p!(Path.dirname(committed))
        if Path.expand(path) != Path.expand(committed), do: File.write!(committed, source)
        source
    end
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

Iconvex.Specs.Tools.ImportIANAAmiga1251.run()

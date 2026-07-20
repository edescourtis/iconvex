defmodule Iconvex.Specs.Tools.ImportVIQR do
  @moduledoc false

  @source_sha256 "4bd921e49d84cf4e265ae8eb201f87fbe9ea596943464605b3010b634bf6f87d"
  @source_url "https://www.rfc-editor.org/rfc/rfc1456.txt"

  @base_shapes [
    {?A, [{"", []}, {"(", [0x0306]}, {"^", [0x0302]}]},
    {?a, [{"", []}, {"(", [0x0306]}, {"^", [0x0302]}]},
    {?E, [{"", []}, {"^", [0x0302]}]},
    {?e, [{"", []}, {"^", [0x0302]}]},
    {?I, [{"", []}]},
    {?i, [{"", []}]},
    {?O, [{"", []}, {"^", [0x0302]}, {"+", [0x031B]}]},
    {?o, [{"", []}, {"^", [0x0302]}, {"+", [0x031B]}]},
    {?U, [{"", []}, {"+", [0x031B]}]},
    {?u, [{"", []}, {"+", [0x031B]}]},
    {?Y, [{"", []}]},
    {?y, [{"", []}]}
  ]

  @tones [
    {"", []},
    {"'", [0x0301]},
    {"`", [0x0300]},
    {"?", [0x0309]},
    {"~", [0x0303]},
    {".", [0x0323]}
  ]

  def run do
    root = Path.expand("..", __DIR__)
    committed = Path.join([root, "priv", "sources", "rfc1456.txt"])
    source_path = System.get_env("RFC1456_SOURCE") || committed
    source = File.read!(source_path)
    assert_sha256!(source)
    if Path.expand(source_path) != Path.expand(committed), do: File.cp!(source_path, committed)

    mappings = build_mappings()
    true = length(mappings) == 134
    true = Enum.uniq_by(mappings, & &1.token) == mappings
    true = Enum.uniq_by(mappings, & &1.codepoint) == mappings

    manifest = %{
      format: 1,
      mappings: mappings,
      source: %{name: "RFC 1456", sha256: @source_sha256, url: @source_url}
    }

    File.write!(
      Path.join(root, "priv/viqr_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic, :compressed])
    )

    IO.puts("wrote #{length(mappings)} VIQR Vietnamese assignments")
  end

  defp build_mappings do
    vowel_mappings =
      for {base, shapes} <- @base_shapes,
          {shape_token, shape_marks} <- shapes,
          {tone_token, tone_marks} <- @tones,
          shape_token != "" or tone_token != "" do
        [codepoint] =
          [base | shape_marks ++ tone_marks]
          |> List.to_string()
          |> String.normalize(:nfc)
          |> String.to_charlist()

        %{codepoint: codepoint, token: <<base>> <> shape_token <> tone_token}
      end

    vowel_mappings ++ [%{codepoint: 0x0110, token: "DD"}, %{codepoint: 0x0111, token: "dd"}]
  end

  defp assert_sha256!(contents) do
    actual = :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)
    unless actual == @source_sha256, do: Mix.raise("RFC 1456 SHA-256 mismatch: #{actual}")
  end
end

Iconvex.Specs.Tools.ImportVIQR.run()

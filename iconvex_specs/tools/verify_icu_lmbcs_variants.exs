defmodule Iconvex.Specs.Tools.VerifyICULMBCSVariants do
  @moduledoc false

  @variants [
    {1, Iconvex.Specs.ICULMBCS1},
    {2, Iconvex.Specs.ICULMBCS2},
    {3, Iconvex.Specs.ICULMBCS3},
    {4, Iconvex.Specs.ICULMBCS4},
    {5, Iconvex.Specs.ICULMBCS5},
    {6, Iconvex.Specs.ICULMBCS6},
    {8, Iconvex.Specs.ICULMBCS8},
    {11, Iconvex.Specs.ICULMBCS11},
    {16, Iconvex.Specs.ICULMBCS16},
    {17, Iconvex.Specs.ICULMBCS17},
    {18, Iconvex.Specs.ICULMBCS18},
    {19, Iconvex.Specs.ICULMBCS19}
  ]

  def run do
    uconv = verified_uconv!()
    root = Path.expand("..", __DIR__)
    fixture = Path.join(root, "test/fixtures/all-unicode-scalars.utf32be")
    codepoints = for <<codepoint::32-big <- File.read!(fixture)>>, do: codepoint

    unless length(codepoints) == 1_112_064,
      do: Mix.raise("Unicode scalar fixture is incomplete")

    results =
      Enum.map(@variants, fn {group, module} ->
        {:ok, encoded} = module.encode(codepoints)

        {oracle_encoded, 0} =
          System.cmd(uconv, [
            "--block-size",
            "5000000",
            "--from-callback",
            "stop",
            "--to-callback",
            "stop",
            "-f",
            "UTF-32BE",
            "-t",
            "LMBCS-#{group}",
            fixture
          ])

        unless encoded == oracle_encoded,
          do: Mix.raise("LMBCS-#{group} exhaustive encoding differs from ICU 78.3")

        {:ok, decoded} = module.decode_discard(encoded)
        native_utf32 = for codepoint <- decoded, into: <<>>, do: <<codepoint::32-big>>
        encoded_path = temporary_path(group)

        try do
          File.write!(encoded_path, encoded)

          {oracle_utf32, 0} =
            System.cmd(uconv, [
              "--block-size",
              "7000000",
              "-i",
              "-f",
              "LMBCS-#{group}",
              "-t",
              "UTF-32BE",
              encoded_path
            ])

          unless native_utf32 == oracle_utf32,
            do: Mix.raise("LMBCS-#{group} exhaustive decoding differs from ICU 78.3")
        after
          File.rm(encoded_path)
        end

        verify_malformed_boundaries!(uconv, group, module)

        IO.puts(
          "LMBCS-#{group}: #{byte_size(encoded)} encoded bytes, " <>
            "#{length(decoded)} decoded scalars, SHA-256 #{sha256(encoded)}"
        )

        %{
          decoded_scalars: length(decoded),
          decoded_sha256: sha256(native_utf32),
          encoded_bytes: byte_size(encoded),
          encoded_sha256: sha256(encoded),
          group: group
        }
      end)

    write_report(root, uconv, results)

    IO.puts("ICU 78.3 LMBCS variant differential: PASS")
  end

  defp verify_malformed_boundaries!(uconv, group, module) do
    common = [
      {<<0x07>>, :invalid},
      {<<group>>, :incomplete},
      {<<0x14>>, :incomplete},
      {<<0x14, 0xD8>>, :incomplete},
      {<<0x14, 0xFF, 0xFE>>, :invalid},
      {<<0x14, 0xFF, 0xFF>>, :invalid}
    ]

    mbcs =
      if group >= 0x10,
        do: [{<<0x81>>, :incomplete}, {<<0x81, 0x30>>, :invalid}],
        else: []

    Enum.each(common ++ mbcs, fn {input, expected} ->
      native =
        case module.decode(input) do
          {:error, :incomplete_sequence, 0, _fragment} -> :incomplete
          {:error, :invalid_sequence, 0, _fragment} -> :invalid
          other -> Mix.raise("unexpected native malformed result: #{inspect(other)}")
        end

      oracle = oracle_error_class(uconv, group, input)

      unless native == expected and oracle == expected do
        Mix.raise(
          "LMBCS-#{group} malformed mismatch for #{Base.encode16(input)}: " <>
            "native=#{native} ICU=#{oracle} expected=#{expected}"
        )
      end
    end)
  end

  defp oracle_error_class(uconv, group, input) do
    path = temporary_path("error-#{group}")

    try do
      File.write!(path, input)

      {diagnostic, _status} =
        System.cmd(
          uconv,
          [
            "--from-callback",
            "stop",
            "--to-callback",
            "stop",
            "-f",
            "LMBCS-#{group}",
            "-t",
            "UTF-32BE",
            path
          ],
          stderr_to_stdout: true
        )

      cond do
        diagnostic =~ "Truncated character found" -> :incomplete
        diagnostic =~ "Invalid character found" -> :invalid
        diagnostic =~ "Illegal character found" -> :invalid
        true -> Mix.raise("ICU accepted malformed LMBCS-#{group} input #{Base.encode16(input)}")
      end
    after
      File.rm(path)
    end
  end

  defp verified_uconv! do
    candidates = [
      System.get_env("ICONVEX_ICU_UCONV"),
      "/opt/homebrew/Cellar/icu4c@78/78.3/bin/uconv",
      "/opt/homebrew/opt/icu4c@78/bin/uconv",
      System.find_executable("uconv")
    ]

    Enum.find(candidates, fn
      nil ->
        false

      path ->
        File.regular?(path) and
          case System.cmd(path, ["--version"]) do
            {version, 0} -> version =~ "ICU 78.3"
            _other -> false
          end
    end) || Mix.raise("an independently executable ICU 78.3 uconv is required")
  end

  defp temporary_path(label) do
    Path.join(
      System.tmp_dir!(),
      "iconvex-lmbcs-#{label}-#{System.unique_integer([:positive, :monotonic])}"
    )
  end

  defp write_report(root, uconv, results) do
    {version, 0} = System.cmd(uconv, ["--version"])

    lines = [
      "# ICU 78.3 LMBCS differential",
      "",
      "Generated by `tools/verify_icu_lmbcs_variants.exs` from the pinned file containing all 1,112,064 Unicode scalars.",
      "Each native encoder is byte-identical to one ICU conversion call; each native discard decoder is byte-identical to ICU UTF-32BE output after both skip U+FFFE/U+FFFF sentinels.",
      "The runner also differentially checks invalid groups, explicit and implicit truncated prefixes, malformed MBCS pairs, and Unicode-group sentinel boundaries.",
      "",
      "- Independent oracle: **#{String.trim(version)}** (`#{uconv}`)",
      "- ICU input block: **5,000,000 bytes** (one conversion callback)",
      "- Unicode scalars encoded: **1,112,064/1,112,064 per profile**",
      "- Unicode scalars decoded after sentinel discard: **1,112,062/1,112,062 per profile**",
      "- Profiles passed: **12/12**",
      "- Mismatches: **0**",
      "",
      "| Profile | Encoded bytes | Encoded SHA-256 | Decoded scalars | Decoded UTF-32BE SHA-256 |",
      "|---|---:|---|---:|---|"
    ]

    rows =
      Enum.map(results, fn result ->
        "| `LMBCS-#{result.group}` | #{result.encoded_bytes} | `#{result.encoded_sha256}` | " <>
          "#{result.decoded_scalars} | `#{result.decoded_sha256}` |"
      end)

    note = [
      "",
      "ICU's `lastConverterIndex` is local to a conversion callback. The verifier therefore overrides `uconv`'s 4,096-byte default block; otherwise callback boundaries can choose a different valid national group for ambiguous characters and do not represent the one-call native API being compared."
    ]

    File.write!(
      Path.join(root, "ICU_LMBCS_DIFFERENTIAL.md"),
      Enum.join(lines ++ rows ++ note, "\n") <> "\n"
    )
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

Iconvex.Specs.Tools.VerifyICULMBCSVariants.run()

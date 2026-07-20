defmodule Iconvex.Specs.Tools.ImportICUUnicodeVariants do
  @moduledoc false

  @revision "21d1eb0f306e1141c10931e914dfc038c06121da"
  @aggregate_sha256 "ff926070b332b264d5bc7312c842e5b30298dc68f292ea5f17ea14ffaf35463a"
  @source_files ~w(convrtrs.txt ucnv_u16.cpp ucnv_u32.cpp ucnv_bld.cpp)

  @entries [
    %{id: :icu_utf16_platform, name: "UTF16_PlatformEndian", variant: :utf16_platform},
    %{id: :icu_utf16_opposite, name: "UTF16_OppositeEndian", variant: :utf16_opposite},
    %{id: :icu_utf32_platform, name: "UTF32_PlatformEndian", variant: :utf32_platform},
    %{id: :icu_utf32_opposite, name: "UTF32_OppositeEndian", variant: :utf32_opposite},
    %{id: :icu_utf16_v1, name: "UTF-16,version=1", variant: :utf16_v1},
    %{id: :icu_utf16_v2, name: "UTF-16,version=2", variant: :utf16_v2}
  ]

  def run do
    root = Path.expand("..", __DIR__)
    committed = Path.join([root, "priv", "sources", "icu-78.3-unicode-variants"])
    source_root = System.get_env("ICU_SOURCE_DIR") || committed
    assert_source_set!(source_root)
    copy_sources(source_root, committed)
    assert_semantics!(committed)

    manifest = %{
      aggregate_sha256: @aggregate_sha256,
      encodings: Enum.map(@entries, &Map.put(&1, :aliases, [])),
      format: 1,
      revision: @revision,
      source_url: "https://github.com/unicode-org/icu/tree/#{@revision}",
      sources: Map.new(@source_files, &{&1, sha256(File.read!(Path.join(committed, &1)))})
    }

    File.write!(
      Path.join(root, "priv/icu_unicode_variants_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic, :compressed])
    )

    rows =
      Enum.map_join(@entries, "\n", fn entry ->
        "| `#{entry.name}` | `#{entry.variant}` |"
      end)

    File.write!(
      Path.join(root, "ICU_UNICODE_VARIANTS.md"),
      """
      # ICU Unicode converter variants

      Generated from ICU 78.3 commit `#{@revision}`. The platform/opposite
      names are resolved from ICU's compile-time endianness routing. UTF-16
      versions 1 and 2 reproduce ICU's BOM-required Java `Unicode` behavior
      and its always-big-endian Java compatibility variant, respectively.

      | Encoding | Variant |
      |---|---|
      #{rows}

      Source-set SHA-256: `#{@aggregate_sha256}`.
      """
    )

    IO.puts("wrote #{length(@entries)} ICU Unicode converter variants")
  end

  defp assert_source_set!(source_root) do
    digest =
      Enum.reduce(@source_files, :crypto.hash_init(:sha256), fn file, context ->
        context
        |> :crypto.hash_update(file)
        |> :crypto.hash_update(<<0>>)
        |> :crypto.hash_update(File.read!(Path.join(source_root, file)))
      end)
      |> :crypto.hash_final()
      |> Base.encode16(case: :lower)

    unless digest == @aggregate_sha256,
      do: Mix.raise("ICU Unicode-variant source-set SHA-256 mismatch: #{digest}")
  end

  defp copy_sources(source_root, committed) do
    if Path.expand(source_root) != Path.expand(committed) do
      File.mkdir_p!(committed)
      Enum.each(@source_files, &File.cp!(Path.join(source_root, &1), Path.join(committed, &1)))
    end
  end

  defp assert_semantics!(root) do
    registry = File.read!(Path.join(root, "convrtrs.txt"))
    utf16 = File.read!(Path.join(root, "ucnv_u16.cpp"))
    utf32 = File.read!(Path.join(root, "ucnv_u32.cpp"))
    builder = File.read!(Path.join(root, "ucnv_bld.cpp"))

    unless Enum.all?(@entries, &String.contains?(registry, &1.name)),
      do: Mix.raise("ICU Unicode converter registry changed")

    unless utf16 =~
             "UTF-16,version=1 (Java \"Unicode\" encoding) treats a missing BOM as an error" and
             utf16 =~ "UTF-16,version=2 fromUnicode() always writes a big-endian byte stream" and
             utf16 =~ "state=9; /* detect UTF-16LE */" and
             utf32 =~ "UTF-32 (Detect BOM)",
           do: Mix.raise("ICU UTF-16/32 semantics changed")

    unless builder =~ "utf16oppositeendian" and builder =~ "utf16platformendian" and
             builder =~ "utf32oppositeendian" and builder =~ "utf32platformendian" and
             builder =~ "#if U_IS_BIG_ENDIAN",
           do: Mix.raise("ICU platform-endian routing changed")
  end

  defp sha256(contents), do: :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)
end

Iconvex.Specs.Tools.ImportICUUnicodeVariants.run()

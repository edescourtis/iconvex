ExUnit.start()

defmodule Iconvex.UpstreamFixture do
  @moduledoc false

  @root Path.expand("fixtures/gnu-libiconv-1.19", __DIR__)
  @derived_names ["Makefile"]

  def root, do: @root

  def corpus_files do
    @root
    |> Path.join("*")
    |> Path.wildcard()
    |> Enum.filter(&File.regular?/1)
    |> Enum.sort()
  end

  def upstream_files do
    derived = MapSet.new(@derived_names)
    Enum.reject(corpus_files(), &(Path.basename(&1) in derived))
  end

  def derived_files do
    corpus_files()
    |> Enum.filter(&(Path.basename(&1) in @derived_names))
  end

  def corpus_digest, do: manifest_digest(corpus_files())
  def upstream_digest, do: manifest_digest(upstream_files())
  def derived_digest, do: manifest_digest(derived_files())

  defp manifest_digest(files) do
    files
    |> Enum.map(fn path ->
      digest =
        path |> File.read!() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

      [digest, "  ./", Path.basename(path), "\n"]
    end)
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  def mapping_files do
    @root
    |> Path.join("*.TXT")
    |> Path.wildcard()
    |> Enum.reject(&String.ends_with?(&1, ".IRREVERSIBLE.TXT"))
    |> Enum.sort()
  end

  def snippet_names do
    @root
    |> Path.join("*-snippet")
    |> Path.wildcard()
    |> Enum.map(&(Path.basename(&1) |> String.replace_suffix("-snippet", "")))
    |> Enum.sort()
  end

  def encoding_for(path) do
    path
    |> Path.basename(".TXT")
    |> String.replace_suffix("-BMP", "")
    |> case do
      "GB18030-2005" -> "GB18030:2005"
      "GB18030-2022" -> "GB18030:2022"
      "BIG5-HKSCS-" <> version -> "BIG5-HKSCS:" <> version
      encoding -> encoding
    end
  end

  def snippet_encoding("BIG5-HKSCS-" <> version), do: "BIG5-HKSCS:" <> version
  def snippet_encoding(name), do: name

  def mappings(path) do
    path
    |> File.stream!([], :line)
    |> Enum.map(&parse_mapping/1)
  end

  def inverse_mappings(path) do
    reversible =
      Enum.filter(mappings(path), fn {_bytes, codepoints} -> length(codepoints) == 1 end)

    entries =
      case irreversible_path(path) do
        nil -> reversible
        irreversible -> reversible ++ mappings(irreversible)
      end

    entries
    |> Enum.frequencies()
    |> Enum.flat_map(fn {entry, count} -> if count == 1, do: [entry], else: [] end)
    |> Enum.sort()
  end

  def interspersed_decode_input(mappings) do
    {separator_bytes, [separator_codepoint]} =
      Enum.find(mappings, fn {_bytes, codepoints} -> codepoints == [0] end) ||
        Enum.find(mappings, fn {_bytes, codepoints} -> length(codepoints) == 1 end)

    input = mappings |> Enum.map(&elem(&1, 0)) |> Enum.intersperse(separator_bytes)
    expected = mappings |> Enum.map(&elem(&1, 1)) |> Enum.intersperse([separator_codepoint])
    {IO.iodata_to_binary(input), List.flatten(expected)}
  end

  def interspersed_encode_input(mappings) do
    {separator_bytes, [separator_codepoint]} =
      Enum.find(mappings, fn {_bytes, codepoints} -> codepoints == [0] end) || hd(mappings)

    input = mappings |> Enum.map(&elem(&1, 1)) |> Enum.intersperse([separator_codepoint])
    expected = mappings |> Enum.map(&elem(&1, 0)) |> Enum.intersperse(separator_bytes)
    {List.flatten(input), IO.iodata_to_binary(expected)}
  end

  defp irreversible_path(path) do
    base = path |> Path.basename(".TXT") |> String.replace_suffix("-BMP", "")
    candidate = Path.join(@root, base <> ".IRREVERSIBLE.TXT")
    if File.regular?(candidate), do: candidate
  end

  defp parse_mapping(line) do
    [encoded, unicode] = line |> String.trim() |> String.split("\t", parts: 2)

    bytes =
      encoded
      |> String.trim_leading("0x")
      |> then(fn hex -> if rem(byte_size(hex), 2) == 0, do: hex, else: "0" <> hex end)
      |> Base.decode16!(case: :mixed)

    codepoints =
      unicode
      |> String.split()
      |> Enum.map(fn "0x" <> hex -> String.to_integer(hex, 16) end)

    {bytes, codepoints}
  end
end

defmodule Iconvex.Specs.Tools.ImportMARC8 do
  @moduledoc false
  import Bitwise

  @source %{
    name: "MARC 21 Code Tables",
    sha256: "3e54ea62d494671cb07b3c931eda76c7f5052b204722bf576038ecbb8fb958c5",
    url: "https://www.loc.gov/marc/specifications/codetables.xml"
  }

  @set_specs %{
    "Basic Latin (ASCII)" => %{id: :ascii, final: "B", width: 1, custom: false, rank: 0},
    "Extended Latin (ANSEL)" => %{id: :ansel, final: "!E", width: 1, custom: false, rank: 1},
    "Greek Symbols" => %{id: :greek_symbols, final: "g", width: 1, custom: true, rank: 10},
    "Subscripts" => %{id: :subscripts, final: "b", width: 1, custom: true, rank: 11},
    "Superscripts" => %{id: :superscripts, final: "p", width: 1, custom: true, rank: 12},
    "Basic Hebrew" => %{id: :basic_hebrew, final: "2", width: 1, custom: false, rank: 5},
    "Basic Cyrillic" => %{id: :basic_cyrillic, final: "N", width: 1, custom: false, rank: 2},
    "Extended Cyrillic" => %{id: :extended_cyrillic, final: "Q", width: 1, custom: false, rank: 3},
    "Basic Arabic" => %{id: :basic_arabic, final: "3", width: 1, custom: false, rank: 6},
    "Extended Arabic" => %{id: :extended_arabic, final: "4", width: 1, custom: false, rank: 7},
    "Basic Greek" => %{id: :basic_greek, final: "S", width: 1, custom: false, rank: 4},
    "Chinese, Japanese, Korean (EACC)" => %{
      id: :eacc,
      final: "1",
      width: 3,
      custom: false,
      rank: 8
    }
  }

  def run do
    root = Path.expand("..", __DIR__)
    source_path = Path.join([root, "priv", "sources", "marc8", "codetables.xml"])
    File.mkdir_p!(Path.dirname(source_path))

    unless File.exists?(source_path) do
      case System.cmd("curl", ["-fsSL", @source.url], stderr_to_stdout: true) do
        {content, 0} ->
          File.write!(source_path, content)

        {message, status} ->
          Mix.raise("download failed (#{status}) for #{@source.url}: #{message}")
      end
    end

    source = File.read!(source_path)
    assert_digest!(source)
    data = parse(source)

    File.write!(
      Path.join(root, "priv/marc8.etf"),
      :erlang.term_to_binary(Map.put(data, :source, @source), [:deterministic])
    )

    summary = data.coverage

    IO.puts(
      "wrote MARC-8: #{summary.character_sets} sets, #{summary.primary_mappings} primary " <>
        "mappings, #{summary.combining_mappings} combining mappings, " <>
        "#{summary.second_half_markers} spanning-mark half markers"
    )
  end

  defp parse(source) do
    parsed_sets =
      Regex.scan(~r/<characterSet\b([^>]*)>(.*?)<\/characterSet>/s, source,
        capture: :all_but_first
      )
      |> Enum.map(fn [attributes, body] -> parse_set(attributes, body) end)

    unless length(parsed_sets) == map_size(@set_specs) do
      Mix.raise(
        "expected #{map_size(@set_specs)} MARC character sets, got #{length(parsed_sets)}"
      )
    end

    entries = Enum.flat_map(parsed_sets, & &1.entries)

    sets =
      Map.new(parsed_sets, fn parsed ->
        decode = Map.new(parsed.entries, &{&1.lookup_bytes, decode_value(&1)})
        {parsed.id, Map.merge(Map.drop(parsed, [:entries]), %{decode: decode})}
      end)

    candidates =
      entries
      |> Enum.flat_map(&entry_candidates/1)
      |> Enum.reduce(%{}, fn {codepoint, candidate}, acc ->
        Map.update(acc, codepoint, [candidate], &[candidate | &1])
      end)
      |> Map.new(fn {codepoint, values} ->
        {codepoint, Enum.sort_by(values, &{&1.rank, &1.alternate, &1.bytes})}
      end)

    combining =
      entries
      |> Enum.filter(& &1.combining)
      |> Enum.flat_map(fn entry -> [entry.codepoint | entry.alternates] end)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    controls =
      entries
      |> Enum.filter(&(&1.invocation == :control and &1.kind != :second_half))
      |> Map.new(&{:binary.first(&1.bytes), &1.codepoint})

    coverage = %{
      character_sets: length(parsed_sets),
      combining_mappings: Enum.count(entries, &(&1.kind == :primary and &1.combining)),
      primary_mappings: Enum.count(entries, &(&1.kind == :primary)),
      reserved_escape_mappings: Enum.count(entries, &(&1.kind == :reserved_escape)),
      second_half_markers: Enum.count(entries, &(&1.kind == :second_half))
    }

    %{
      candidates: candidates,
      combining: combining,
      controls: controls,
      coverage: coverage,
      entries: entries,
      format: 1,
      sets: sets
    }
  end

  defp parse_set(attributes, body) do
    name = attribute!(attributes, "name")
    spec = Map.fetch!(@set_specs, name)

    entries =
      Regex.scan(~r/<code>(.*?)<\/code>/s, body, capture: :all_but_first)
      |> Enum.map(&parse_entry(hd(&1), spec))

    Map.merge(spec, %{name: name, entries: entries})
  end

  defp parse_entry(body, spec) do
    bytes = body |> tag!("marc") |> hex_binary!()
    unicode = tag(body, "ucs")
    alternates = Regex.scan(~r/<alt>(.*?)<\/alt>/s, body, capture: :all_but_first)

    alternates =
      Enum.map(alternates, fn [value] -> value |> compact() |> String.to_integer(16) end)

    combining = tag(body, "isCombining") == "true" or unicode == "0670"

    {kind, codepoint, span_codepoint} =
      cond do
        unicode != "" ->
          codepoint = String.to_integer(unicode, 16)
          kind = if spec.id == :ascii and codepoint == 0x1B, do: :reserved_escape, else: :primary
          {kind, codepoint, nil}

        bytes == <<0xEC>> ->
          {:second_half, nil, 0x0361}

        bytes == <<0xFB>> ->
          {:second_half, nil, 0x0360}

        true ->
          Mix.raise("unmapped MARC row #{Base.encode16(bytes)} in #{spec.id}")
      end

    invocation = invocation(spec, bytes)

    %{
      alternate: false,
      alternates: alternates,
      bytes: bytes,
      codepoint: codepoint,
      combining: combining,
      invocation: invocation,
      kind: kind,
      lookup_bytes: normalize_bytes(bytes, invocation),
      rank: spec.rank,
      set: spec.id,
      span_codepoint: span_codepoint
    }
  end

  defp invocation(%{id: :ascii}, <<byte>>) when byte < 0x20, do: :control
  defp invocation(%{id: :ansel}, <<byte>>) when byte in 0x80..0x9F, do: :control
  defp invocation(_spec, <<byte, _::binary>>) when byte >= 0x80, do: :g1
  defp invocation(_spec, _bytes), do: :g0

  defp normalize_bytes(bytes, :g1), do: for(<<byte <- bytes>>, into: <<>>, do: <<byte &&& 0x7F>>)
  defp normalize_bytes(bytes, _invocation), do: bytes

  defp decode_value(%{kind: :second_half, span_codepoint: codepoint}),
    do: {:second_half, codepoint}

  defp decode_value(entry), do: {:primary, entry.codepoint, entry.combining}

  defp entry_candidates(%{kind: kind}) when kind not in [:primary, :reserved_escape], do: []

  defp entry_candidates(entry) do
    candidate = Map.take(entry, [:alternate, :bytes, :combining, :invocation, :rank, :set])

    [{entry.codepoint, candidate}] ++
      Enum.map(entry.alternates, fn codepoint ->
        {codepoint, %{candidate | alternate: true}}
      end)
  end

  defp attribute!(attributes, name) do
    case Regex.run(~r/#{name}="([^"]+)"/, attributes, capture: :all_but_first) do
      [value] -> value
      nil -> Mix.raise("missing #{name} attribute")
    end
  end

  defp tag!(body, name) do
    case tag(body, name) do
      "" -> Mix.raise("missing #{name} value")
      value -> value
    end
  end

  defp tag(body, name) do
    case Regex.run(~r/<#{name}>(.*?)<\/#{name}>/s, body, capture: :all_but_first) do
      [value] -> compact(value)
      nil -> ""
    end
  end

  defp compact(value), do: String.replace(value, ~r/\s+/, "")

  defp hex_binary!(hex) do
    case Base.decode16(hex, case: :mixed) do
      {:ok, bytes} -> bytes
      :error -> Mix.raise("invalid MARC hex #{inspect(hex)}")
    end
  end

  defp assert_digest!(content) do
    actual = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
    unless actual == @source.sha256, do: Mix.raise("MARC code-table SHA-256 mismatch: #{actual}")
  end
end

Iconvex.Specs.Tools.ImportMARC8.run()

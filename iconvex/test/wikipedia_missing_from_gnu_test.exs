defmodule Iconvex.WikipediaMissingFromGnuTest do
  use ExUnit.Case, async: true

  @catalog Path.expand("../research/known_encodings.csv", __DIR__)
  @csv Path.expand("../research/WIKIPEDIA_MISSING_FROM_GNU.csv", __DIR__)
  @markdown Path.expand("../research/WIKIPEDIA_MISSING_FROM_GNU.md", __DIR__)
  @catalog_summary Path.expand("../research/KNOWN_ENCODINGS.md", __DIR__)
  @generator Path.expand("../tools/generate_wikipedia_gap_report.py", __DIR__)

  @columns [
    "catalog_id",
    "name",
    "aliases",
    "kinds",
    "confidence",
    "gnu_libiconv_1_19",
    "iconvex",
    "coverage_status",
    "implementation_disposition",
    "wikipedia_source_ids",
    "wikipedia_urls",
    "all_source_ids",
    "all_source_urls",
    "statuses"
  ]

  @remaining_dispositions %{
    "codec_gap" => 15,
    "research_candidate" => 121,
    "encoding_family" => 14,
    "repertoire_abstraction" => 1,
    "repertoire_profile" => 1,
    "withdrawn_unassigned_part" => 1
  }

  test "Wikipedia clusters absent from GNU have an exhaustive source-bound report" do
    python = System.find_executable("python3") || flunk("python3 is unavailable")

    {output, status} =
      System.cmd(python, [@generator, "--check"],
        cd: Path.dirname(@generator),
        stderr_to_stdout: true
      )

    assert status == 0, output

    source_rows = read_csv(@catalog)

    expected =
      source_rows
      |> Enum.filter(fn row ->
        row["gnu_libiconv_1_19"] == "no" and
          "wikipedia" in pipe_values(row["sources"])
      end)
      |> Enum.sort_by(& &1["catalog_id"])

    report_rows = read_csv(@csv)

    assert length(expected) == 394
    assert length(report_rows) == 394
    assert Enum.map(report_rows, & &1["catalog_id"]) == Enum.map(expected, & &1["catalog_id"])
    assert Enum.uniq_by(report_rows, & &1["catalog_id"]) == report_rows

    source_by_id = Map.new(expected, &{&1["catalog_id"], &1})

    for row <- report_rows do
      source = Map.fetch!(source_by_id, row["catalog_id"])

      assert row["gnu_libiconv_1_19"] == "no"
      assert row["iconvex"] == source["iconvex"]

      assert row["coverage_status"] ==
               if(source["iconvex"] == "yes", do: "implemented", else: "remaining")

      assert row["implementation_disposition"] == source["implementation_disposition"]
      assert row["all_source_ids"] == source["source_ids"]
      assert row["all_source_urls"] == source["source_urls"]

      wikipedia_ids = pipe_values(row["wikipedia_source_ids"])
      wikipedia_urls = pipe_values(row["wikipedia_urls"])

      assert wikipedia_ids != []
      assert Enum.all?(wikipedia_ids, &String.starts_with?(&1, "wikipedia:"))
      assert length(wikipedia_urls) == length(wikipedia_ids)
      assert Enum.all?(wikipedia_urls, &String.starts_with?(&1, "https://en.wikipedia.org/wiki/"))
    end

    assert Enum.count(report_rows, &(&1["coverage_status"] == "implemented")) == 241

    remaining = Enum.filter(report_rows, &(&1["coverage_status"] == "remaining"))
    assert length(remaining) == 153

    assert Enum.frequencies_by(remaining, & &1["implementation_disposition"]) ==
             @remaining_dispositions

    markdown = File.read!(@markdown)
    catalog_sha256 = sha256(File.read!(@catalog))

    assert markdown =~ "Wikipedia-sourced clusters absent from GNU libiconv 1.19: **394**"
    assert markdown =~ "Implemented by Iconvex: **241**"
    assert markdown =~ "Remaining: **153**"
    assert markdown =~ "Codec gaps: **15**"
    assert markdown =~ "Research candidates: **121**"
    assert markdown =~ "Encoding families: **14**"
    assert markdown =~ "Repertoire abstraction: **1**"
    assert markdown =~ "Repertoire profile: **1**"
    assert markdown =~ "Withdrawn/unassigned part: **1**"
    assert markdown =~ "Source catalog SHA-256: `#{catalog_sha256}`"

    for row <- report_rows do
      assert markdown =~ "| #{row["catalog_id"]} |"
    end

    catalog_summary = File.read!(@catalog_summary)

    assert catalog_summary =~
             "[Direct Wikipedia character-set clusters absent from GNU libiconv 1.19](WIKIPEDIA_MISSING_FROM_GNU.md)"

    assert catalog_summary =~ "[machine-readable CSV](WIKIPEDIA_MISSING_FROM_GNU.csv)"
  end

  defp read_csv(path) do
    [header | lines] = path |> File.read!() |> String.split("\n", trim: true)
    columns = csv_fields(header)
    assert columns == @columns or path == @catalog

    Enum.map(lines, fn line ->
      fields = csv_fields(line)
      assert length(fields) == length(columns)
      Map.new(Enum.zip(columns, fields))
    end)
  end

  defp pipe_values(""), do: []
  defp pipe_values(value), do: String.split(value, " | ", trim: true)

  defp sha256(binary) do
    binary
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp csv_fields(line),
    do: parse_csv_fields(String.trim_trailing(line, "\r"), false, [], [])

  defp parse_csv_fields(<<>>, false, field, fields),
    do: :lists.reverse([csv_field(field) | fields])

  defp parse_csv_fields(<<?\", ?\", rest::binary>>, true, field, fields),
    do: parse_csv_fields(rest, true, [?\" | field], fields)

  defp parse_csv_fields(<<?\", rest::binary>>, true, field, fields),
    do: parse_csv_fields(rest, false, field, fields)

  defp parse_csv_fields(<<?\", rest::binary>>, false, [], fields),
    do: parse_csv_fields(rest, true, [], fields)

  defp parse_csv_fields(<<?,, rest::binary>>, false, field, fields),
    do: parse_csv_fields(rest, false, [], [csv_field(field) | fields])

  defp parse_csv_fields(<<byte, rest::binary>>, quoted?, field, fields),
    do: parse_csv_fields(rest, quoted?, [byte | field], fields)

  defp csv_field(reversed_bytes),
    do: reversed_bytes |> :lists.reverse() |> :erlang.list_to_binary()
end

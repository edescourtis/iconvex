workspace = Path.expand("../..", __DIR__)
gnu_report = Path.join(workspace, "iconvex/SUPPORTED_ENCODINGS.md")

gnu_exhaustive_report =
  System.get_env("ICONVEX_GNU_EXHAUSTIVE_REPORT") ||
    Path.join(workspace, "iconvex_extras/EXHAUSTIVE_UNICODE_DIFFERENTIAL.md")

output = Path.join(workspace, "ICONVEX_FULL_STACK_SUPPORT.md")
output = System.get_env("ICONVEX_FULL_STACK_SUPPORT_OUTPUT") || output

for app <- [:iconvex, :iconvex_extras, :iconvex_telecom, :iconvex_specs] do
  case Application.ensure_all_started(app) do
    {:ok, _started} -> :ok
    {:error, reason} -> raise "could not start #{inspect(app)}: #{inspect(reason)}"
  end
end

started_apps = Application.started_applications() |> Enum.map(&elem(&1, 0)) |> MapSet.new()

for app <- [:iconvex, :iconvex_extras, :iconvex_telecom, :iconvex_specs] do
  unless MapSet.member?(started_apps, app), do: raise("#{inspect(app)} is not running")
end

gnu_exhaustive_document = File.read!(gnu_exhaustive_report)

gnu_exhaustive_evidence =
  with [_, passed, total] <-
         Regex.run(~r/- Codecs passed: \*\*(\d+)\/(\d+)\*\*/, gnu_exhaustive_document),
       [_, mismatches] <-
         Regex.run(~r/- Mismatches: \*\*(\d+)\*\*/, gnu_exhaustive_document),
       [_, performance_failures] <-
         Regex.run(~r/- Performance failures: \*\*(\d+)\*\*/, gnu_exhaustive_document),
       [_, reference] <-
         Regex.run(~r/- Reference: \*\*(.+)\*\*/, gnu_exhaustive_document) do
    %{
      passed: String.to_integer(passed),
      total: String.to_integer(total),
      mismatches: String.to_integer(mismatches),
      performance_failures: String.to_integer(performance_failures),
      reference: reference,
      sha256:
        gnu_exhaustive_document
        |> then(&:crypto.hash(:sha256, &1))
        |> Base.encode16(case: :lower)
    }
  else
    _ -> raise "combined exhaustive GNU differential is missing required evidence fields"
  end

unless Map.drop(gnu_exhaustive_evidence, [:sha256]) == %{
         passed: 198,
         total: 198,
         mismatches: 0,
         performance_failures: 0,
         reference: "iconv (GNU libiconv 1.19)"
       } and
         String.contains?(
           gnu_exhaustive_document,
           "- Reference: **iconv (GNU libiconv 1.19)**, built with `--enable-extra-encodings`"
         ) do
  raise "combined exhaustive GNU differential is not a clean 198-codec GNU libiconv 1.19 run: " <>
          inspect(gnu_exhaustive_evidence)
end

gnu =
  gnu_report
  |> File.read!()
  |> String.split("\n")
  |> Enum.flat_map(fn line ->
    case String.split(line, "|", trim: true) |> Enum.map(&String.trim/1) do
      ["`" <> codec, _core, _extras, "Yes", _definition, _default] ->
        [String.trim_trailing(codec, "`")]

      _ ->
        []
    end
  end)
  |> Enum.sort()

ours = Iconvex.encodings() |> Enum.sort()
normalize = &String.upcase(&1, :ascii)

expected_package_counts = %{
  "iconvex" => 112,
  "iconvex_extras" => 86,
  "iconvex_telecom" => 54,
  "iconvex_specs" => 1_841
}

package_codecs = [
  {"iconvex", Iconvex.Registry.builtin_canonical_names()},
  {"iconvex_extras", Iconvex.Extras.encodings()},
  {"iconvex_telecom", Iconvex.Telecom.encodings()},
  {"iconvex_specs", Iconvex.Specs.encodings()}
]

actual_package_counts =
  Map.new(package_codecs, fn {package, codecs} -> {package, length(codecs)} end)

unless actual_package_counts == expected_package_counts do
  raise "unexpected package codec counts: #{inspect(actual_package_counts)}"
end

archive_entries = Iconvex.Specs.ICUArchive.encodings()
archive_ids_list = Enum.map(archive_entries, & &1.id)
archive_ids = MapSet.new(archive_ids_list)

unless length(archive_ids_list) == MapSet.size(archive_ids) do
  raise "ICU archive manifest contains duplicate provider IDs"
end

archive_provider_apps = [
  :iconvex_specs_icu_archive_a,
  :iconvex_specs_icu_archive_b,
  :iconvex_specs_icu_archive_c
]

archive_provider_memberships =
  Enum.reduce(archive_provider_apps, %{}, &Map.put(&2, &1, MapSet.new()))

archive_provider_memberships =
  Enum.reduce(:persistent_term.get(), archive_provider_memberships, fn
    {{{Iconvex.Tables, :provider}, id}, {app, {:owned, token}}}, memberships ->
      if app in archive_provider_apps do
        unless is_reference(token) do
          raise "invalid ICU archive provider token for #{inspect(id)}: #{inspect(token)}"
        end

        Map.update!(memberships, app, &MapSet.put(&1, id))
      else
        memberships
      end

    {{{Iconvex.Tables, :provider}, id}, {app, ownership}}, memberships ->
      if app in archive_provider_apps do
        raise "invalid ICU archive provider ownership for #{inspect(id)}: " <>
                inspect({app, ownership})
      else
        memberships
      end

    _entry, memberships ->
      memberships
  end)

archive_provider_union =
  archive_provider_memberships
  |> Map.values()
  |> Enum.reduce(MapSet.new(), &MapSet.union/2)

unless archive_provider_union == archive_ids do
  raise "ICU archive provider union differs from manifest IDs: " <>
          inspect(%{
            missing: MapSet.difference(archive_ids, archive_provider_union) |> Enum.sort(),
            extra: MapSet.difference(archive_provider_union, archive_ids) |> Enum.sort()
          })
end

for {app, ids} <- archive_provider_memberships do
  if MapSet.size(ids) == 0, do: raise("ICU archive provider #{inspect(app)} owns no tables")

  priv_dir = :code.priv_dir(app)

  unless is_list(priv_dir) do
    raise "ICU archive provider #{inspect(app)} has no release priv directory"
  end

  for id <- ids do
    unless File.regular?(Path.join([priv_dir, "tables", "#{id}.etf"])) do
      raise "ICU archive provider #{inspect(app)} is missing table #{inspect(id)}"
    end
  end
end

archive_provider_counts =
  Map.new(archive_provider_memberships, fn {app, ids} -> {app, MapSet.size(ids)} end)

unless Enum.sum(Map.values(archive_provider_counts)) == length(archive_entries) do
  raise "ICU archive provider ownership is not one-to-one with manifest entries"
end

owner_by_codec =
  Enum.reduce(package_codecs, %{}, fn {package, codecs}, owners ->
    Enum.reduce(codecs, owners, fn codec, owners ->
      case Map.fetch(owners, codec) do
        :error -> Map.put(owners, codec, package)
        {:ok, existing} -> raise "canonical codec #{codec} is owned by #{existing} and #{package}"
      end
    end)
  end)

unless MapSet.new(Map.keys(owner_by_codec)) == MapSet.new(ours) do
  raise "package-owned canonical set differs from the running full-stack registry"
end

gnu_definition_root =
  Path.join(workspace, "iconvex/test/fixtures/gnu-libiconv-1.19-encodings")

gnu_definition_files = ~w(
  encodings.def encodings_extra.def encodings_aix.def encodings_dos.def
  encodings_osf1.def encodings_zos.def
)

{gnu_entries, gnu_spelling_claims} =
  Enum.reduce(gnu_definition_files, {%{}, %{}}, fn filename, {entries, aliases} ->
    source =
      gnu_definition_root
      |> Path.join(filename)
      |> File.read!()
      |> then(&Regex.replace(~r{/\*.*?\*/}s, &1, ""))

    definitions =
      Regex.scan(~r/DEFENCODING\(\(\s*(.*?)\),\s*([a-z0-9_]+)\s*,/s, source,
        capture: :all_but_first
      )

    {entries, aliases} =
      Enum.reduce(definitions, {entries, aliases}, fn [names_source, id], {entries, aliases} ->
        names =
          Regex.scan(~r/"([^"]+)"/, names_source, capture: :all_but_first)
          |> List.flatten()

        aliases =
          Enum.reduce(names, aliases, fn source_name, acc ->
            Map.put(acc, normalize.(source_name), %{source_name: source_name, id: id})
          end)

        {Map.put_new(entries, id, hd(names)), aliases}
      end)

    aliases =
      Regex.scan(~r/DEFALIAS\(\s*"([^"]+)"\s*,\s*([a-z0-9_]+)\s*\)/s, source,
        capture: :all_but_first
      )
      |> Enum.reduce(aliases, fn [source_name, id], acc ->
        Map.put(acc, normalize.(source_name), %{source_name: source_name, id: id})
      end)

    {entries, aliases}
  end)

gnu_spellings =
  Map.new(gnu_spelling_claims, fn {normalized, claim} ->
    {normalized, Map.put(claim, :gnu_canonical, Map.fetch!(gnu_entries, claim.id))}
  end)

unless map_size(gnu_spellings) == 758 do
  raise "unexpected parsed GNU spelling count: #{map_size(gnu_spellings)}"
end

unless gnu_entries |> Map.values() |> Enum.uniq() |> Enum.sort() == gnu do
  raise "GNU definition canonical set differs from the parity report"
end

gnu_reclaimed_spellings = %{
  "IBM037" => %{gnu_canonical: "IBM-037", rfc_qualified: "RFC1345:IBM037"},
  "IBM1026" => %{gnu_canonical: "IBM-1026", rfc_qualified: "RFC1345:IBM1026"},
  "IBM273" => %{gnu_canonical: "IBM-273", rfc_qualified: "RFC1345:IBM273"},
  "IBM277" => %{gnu_canonical: "IBM-277", rfc_qualified: "RFC1345:IBM277"},
  "IBM278" => %{gnu_canonical: "IBM-278", rfc_qualified: "RFC1345:IBM278"},
  "IBM280" => %{gnu_canonical: "IBM-280", rfc_qualified: "RFC1345:IBM280"},
  "IBM284" => %{gnu_canonical: "IBM-284", rfc_qualified: "RFC1345:IBM284"},
  "IBM285" => %{gnu_canonical: "IBM-285", rfc_qualified: "RFC1345:IBM285"},
  "IBM297" => %{gnu_canonical: "IBM-297", rfc_qualified: "RFC1345:IBM297"},
  "IBM424" => %{gnu_canonical: "IBM-424", rfc_qualified: "RFC1345:IBM424"},
  "IBM437" => %{gnu_canonical: "CP437", rfc_qualified: "RFC1345:IBM437"},
  "IBM500" => %{gnu_canonical: "IBM-500", rfc_qualified: "RFC1345:IBM500"},
  "IBM852" => %{gnu_canonical: "CP852", rfc_qualified: "RFC1345:IBM852"},
  "IBM855" => %{gnu_canonical: "CP855", rfc_qualified: "RFC1345:IBM855"},
  "IBM857" => %{gnu_canonical: "CP857", rfc_qualified: "RFC1345:IBM857"},
  "IBM860" => %{gnu_canonical: "CP860", rfc_qualified: "RFC1345:IBM860"},
  "IBM861" => %{gnu_canonical: "CP861", rfc_qualified: "RFC1345:IBM861"},
  "IBM863" => %{gnu_canonical: "CP863", rfc_qualified: "RFC1345:IBM863"},
  "IBM864" => %{gnu_canonical: "CP864", rfc_qualified: "RFC1345:IBM864"},
  "IBM865" => %{gnu_canonical: "CP865", rfc_qualified: "RFC1345:IBM865"},
  "IBM869" => %{gnu_canonical: "CP869", rfc_qualified: "RFC1345:IBM869"},
  "IBM870" => %{gnu_canonical: "IBM-870", rfc_qualified: "RFC1345:IBM870"},
  "IBM871" => %{gnu_canonical: "IBM-871", rfc_qualified: "RFC1345:IBM871"},
  "IBM880" => %{gnu_canonical: "IBM-880", rfc_qualified: "RFC1345:IBM880"},
  "IBM905" => %{gnu_canonical: "IBM-905", rfc_qualified: "RFC1345:IBM905"}
}

unless map_size(gnu_reclaimed_spellings) == 25 do
  raise "unexpected explicit GNU/RFC 1345 collision count"
end

for {source_name, expected} <- gnu_reclaimed_spellings do
  claim = Map.fetch!(gnu_spellings, normalize.(source_name))

  unless claim.gnu_canonical == expected.gnu_canonical do
    raise "GNU collision target changed for #{source_name}: #{claim.gnu_canonical}"
  end

  registration =
    Enum.find(Iconvex.Specs.registrations(), fn registration ->
      registration.source == "RFC1345" and registration.declared_canonical == source_name
    end)

  rfc_entry = Enum.find(Iconvex.Specs.RFC1345.encodings(), &(&1.name == source_name))
  expected_rfc_aliases = Enum.map(rfc_entry.aliases, &"RFC1345:#{&1}")

  unless registration.canonical == expected.rfc_qualified and
           Enum.sort(registration.aliases) == Enum.sort(expected_rfc_aliases) do
    raise "RFC 1345 identity is not fully source-qualified for #{source_name}"
  end

  unless Iconvex.canonical_name(expected.rfc_qualified) == {:ok, expected.rfc_qualified} do
    raise "qualified RFC 1345 identity does not resolve: #{expected.rfc_qualified}"
  end
end

gnu_resolution_results =
  gnu_spellings
  |> Enum.sort_by(&elem(&1, 0))
  |> Enum.map(fn {normalized, claim} ->
    source_name = claim.source_name

    actual = Iconvex.canonical_name(source_name)

    unless actual == {:ok, claim.gnu_canonical} do
      raise "GNU spelling #{source_name} resolved as #{inspect(actual)}, expected #{claim.gnu_canonical}"
    end

    Map.put(claim, :normalized, normalized)
  end)

direct_gnu_winner_count =
  Enum.count(
    gnu_resolution_results,
    &(Iconvex.canonical_name(&1.source_name) == {:ok, &1.gnu_canonical})
  )

unless direct_gnu_winner_count == 758 do
  raise "unexpected direct GNU canonical winner count: #{direct_gnu_winner_count}"
end

decode_single_byte = fn encoding, byte ->
  case Iconvex.convert(<<byte>>, encoding, "UTF-8") do
    {:error, %Iconvex.Error{} = error} ->
      {:error, error.kind, error.offset, error.sequence, error.codepoint}

    result ->
      result
  end
end

iconvex_alias_routing_equivalence =
  gnu_reclaimed_spellings
  |> Enum.sort_by(&elem(&1, 0))
  |> Enum.map(fn {source_name, expected} ->
    for byte <- 0..255 do
      alias_result = decode_single_byte.(source_name, byte)
      canonical_result = decode_single_byte.(expected.gnu_canonical, byte)

      unless alias_result == canonical_result do
        raise "Iconvex alias route #{source_name} differs at byte #{byte}: " <>
                "#{inspect(alias_result)} != #{inspect(canonical_result)}"
      end
    end

    {source_name, expected.gnu_canonical, expected.rfc_qualified, 256}
  end)

if length(ours) != MapSet.size(MapSet.new(ours, normalize)) do
  raise "full-stack canonical names are not unique under ASCII case folding"
end

claims = fn canonical, aliases ->
  canonical = normalize.(canonical)

  [{canonical, :canonical} | Enum.map(aliases, &{normalize.(&1), :alias})]
  |> Enum.reduce(%{}, fn {name, kind}, acc ->
    Map.update(acc, name, kind, fn existing ->
      if kind == :canonical, do: :canonical, else: existing
    end)
  end)
end

specs_claims =
  for registration <- Iconvex.Specs.registrations(),
      {name, kind} <- claims.(registration.canonical, registration.aliases),
      into: %{} do
    {name, %{codec: registration.codec, kind: kind, priority: 0}}
  end

extras_claims =
  for codec <- Iconvex.Extras.codecs(),
      {name, kind} <- claims.(codec.canonical_name(), codec.aliases()),
      into: %{} do
    {name, %{codec: codec, kind: kind, priority: 100}}
  end

overlap_names =
  specs_claims
  |> Map.keys()
  |> MapSet.new()
  |> MapSet.intersection(MapSet.new(Map.keys(extras_claims)))
  |> Enum.sort()

overlap_categories =
  Enum.frequencies_by(overlap_names, fn name ->
    {Map.fetch!(specs_claims, name).kind, Map.fetch!(extras_claims, name).kind}
  end)

unless overlap_categories == %{
         {:alias, :alias} => 164,
         {:alias, :canonical} => 63
       } do
  raise "unexpected Specs/Extras overlap categories: #{inspect(overlap_categories)}"
end

winner_counts =
  Enum.frequencies_by(overlap_names, fn name ->
    specs = Map.fetch!(specs_claims, name)
    extras = Map.fetch!(extras_claims, name)

    expected =
      Enum.max_by([{:specs, specs}, {:extras, extras}], fn {_package, claim} ->
        {if(claim.kind == :canonical, do: 1, else: 0), claim.priority}
      end)
      |> elem(0)

    {:ok, %{codec: actual_codec}} = Iconvex.Registry.resolve(name)
    expected_codec = if expected == :specs, do: specs.codec, else: extras.codec

    unless actual_codec == expected_codec do
      raise "wrong overlap winner for #{name}: #{inspect(actual_codec)}"
    end

    expected
  end)

unless winner_counts == %{extras: 227} do
  raise "unexpected Specs/Extras winner counts: #{inspect(winner_counts)}"
end

gnu_set = MapSet.new(gnu)
ours_set = MapSet.new(ours)
common = MapSet.intersection(gnu_set, ours_set) |> Enum.sort()
ours_only = MapSet.difference(ours_set, gnu_set) |> Enum.sort()
gnu_only = MapSet.difference(gnu_set, ours_set) |> Enum.sort()

core_and_extras =
  package_codecs
  |> Enum.filter(fn {package, _codecs} -> package in ["iconvex", "iconvex_extras"] end)
  |> Enum.flat_map(&elem(&1, 1))
  |> MapSet.new()

unless core_and_extras == gnu_set do
  raise "Core and Extras canonical union differs from GNU's fixed-codec union"
end

format_count = fn count ->
  Regex.replace(~r/\B(?=(\d{3})+(?!\d))/, Integer.to_string(count), ",")
end

owner_rows =
  Enum.map(ours, fn codec ->
    owner = Map.fetch!(owner_by_codec, codec)
    gnu_support = if MapSet.member?(gnu_set, codec), do: "Yes", else: "No"
    "| `#{codec}` | `#{owner}` | #{gnu_support} |\n"
  end)

gnu_only_rows = Enum.map(gnu_only, &"| `#{&1}` |\n")

gnu_alias_rows =
  Enum.map(iconvex_alias_routing_equivalence, fn {
                                                   source_name,
                                                   gnu_canonical,
                                                   rfc_qualified,
                                                   byte_count
                                                 } ->
    "| `#{source_name}` | `#{gnu_canonical}` | `#{rfc_qualified}` | #{byte_count}/256 |\n"
  end)

document = [
  "# Iconvex Full-Stack Support vs GNU libiconv 1.19\n\n",
  "Generated by `iconvex_specs/tools/full_stack_support.exs` with `iconvex`, ",
  "`iconvex_extras`, `iconvex_telecom`, and `iconvex_specs` started together. ",
  "GNU's set is parsed from the byte-exact 1.19 definition parity report.\n\n",
  "## Exact package ownership totals\n\n",
  "- Core `iconvex`: **#{format_count.(actual_package_counts["iconvex"])}**\n",
  "- `iconvex_extras`: **#{format_count.(actual_package_counts["iconvex_extras"])}**\n",
  "- `iconvex_telecom`: **#{format_count.(actual_package_counts["iconvex_telecom"])}**\n",
  "- `iconvex_specs`: **#{format_count.(actual_package_counts["iconvex_specs"])}**\n",
  "- Full Iconvex stack canonical codecs: **#{format_count.(length(ours))}**\n",
  "- GNU libiconv 1.19 `--enable-extra-encodings` fixed codecs: **#{format_count.(length(gnu))}**\n",
  "- Shared canonical codecs: **#{format_count.(length(common))}**\n",
  "- Iconvex-only canonical codecs: **#{format_count.(length(ours_only))}**\n",
  "- GNU-only canonical codecs: **#{format_count.(length(gnu_only))}**\n\n",
  "- Archive codecs measured from `Iconvex.Specs.ICUArchive.encodings/0`: ",
  "**#{format_count.(length(archive_entries))}**\n",
  Enum.map(archive_provider_apps, fn app ->
    "- `#{app}`: **#{format_count.(Map.fetch!(archive_provider_counts, app))}** provider-owned tables\n"
  end),
  "\nThe runtime provider union exactly equals the ",
  "#{format_count.(length(archive_entries))} manifest IDs, every ID has one live ownership token, ",
  "and every owned table exists in its provider's release storage. These codecs are included in ",
  "`iconvex_specs`; the shards are storage providers, not additional public owners.\n\n",
  "All #{format_count.(length(ours))} canonical names are unique under ASCII case folding. Specs and Extras retain ",
  "all **227** overlapping external name claims: 63 Specs-alias/Extras-canonical and ",
  "164 alias/alias. Extras' GNU identity wins every overlap, while displaced RFC 1345 ",
  "identities and aliases remain directly addressable with the `RFC1345:` prefix. The six start ",
  "orders and stop/fallback lifecycle are enforced by ",
  "`iconvex_integration/test/full_stack_registration_test.exs`.\n\n",
  "Name comparison is canonical and conservative. The six byte-exact GNU definition ",
  "snapshots are parsed before report emission, and every source spelling is resolved ",
  "against the running four-package stack:\n\n",
  "- Parsed GNU spellings verified: **#{map_size(gnu_spellings)}/#{map_size(gnu_spellings)}**\n",
  "- Direct GNU canonical targets: **#{direct_gnu_winner_count}**\n",
  "- GNU spellings reclaimed from RFC 1345 identities: **#{map_size(gnu_reclaimed_spellings)}**\n\n",
  "The 25 formerly ambiguous RFC 1345 identities are now source-qualified. The 256/256 values ",
  "below are internal Iconvex alias-routing checks: each reclaimed spelling and canonical target ",
  "intentionally resolve through the same running Iconvex codec, and all one-byte inputs are ",
  "compared. They are not an independent GNU invocation. Independent byte correctness against ",
  "the pinned GNU implementation is recorded by the ",
  "[198-codec exhaustive GNU differential](iconvex_extras/EXHAUSTIVE_UNICODE_DIFFERENTIAL.md): ",
  "**#{gnu_exhaustive_evidence.passed}/#{gnu_exhaustive_evidence.total}** codecs, ",
  "**#{gnu_exhaustive_evidence.mismatches}** mismatches, ",
  "**#{gnu_exhaustive_evidence.performance_failures}** performance failures, reference ",
  "**#{gnu_exhaustive_evidence.reference}**, report SHA-256 ",
  "`#{gnu_exhaustive_evidence.sha256}`. RFC 1345 and telecom aliases add further names outside ",
  "GNU's fixed-codec definitions.\n\n",
  "| GNU spelling | GNU target | Qualified RFC 1345 identity | Iconvex alias-routing equivalence |\n",
  "|---|---|---|---:|\n",
  gnu_alias_rows,
  "\n",
  "## Complete Iconvex canonical codec ownership (#{format_count.(length(ours))})\n\n",
  "| Codec | Owning package | GNU libiconv 1.19 fixed codec |\n",
  "|---|---|:---:|\n",
  owner_rows,
  "\n## GNU-only codecs (#{format_count.(length(gnu_only))})\n\n",
  if(gnu_only == [], do: "None.\n", else: ["| Codec |\n|---|\n", gnu_only_rows])
]

File.write!(output, document)

IO.puts(
  "wrote #{output}: #{format_count.(length(ours))} Iconvex, #{length(gnu)} GNU, " <>
    "#{length(common)} shared, exact owners #{inspect(actual_package_counts)}; " <>
    "#{map_size(gnu_spellings)} GNU spellings verified"
)

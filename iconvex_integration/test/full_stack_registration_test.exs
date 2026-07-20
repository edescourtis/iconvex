defmodule IconvexIntegration.FullStackRegistrationTest do
  use ExUnit.Case, async: false

  @moduletag timeout: 300_000
  @workspace Path.expand("../..", __DIR__)
  @extensions [:iconvex_extras, :iconvex_telecom, :iconvex_specs]
  @gnu_reclaimed_rfc_names ~w(
    IBM037 IBM1026 IBM273 IBM277 IBM278 IBM280 IBM284 IBM285 IBM297 IBM424
    IBM437 IBM500 IBM852 IBM855 IBM857 IBM860 IBM861 IBM863 IBM864 IBM865
    IBM869 IBM870 IBM871 IBM880 IBM905
  )

  setup_all do
    stop_extensions()
    assert {:ok, _started} = Application.ensure_all_started(:iconvex)

    on_exit(fn -> stop_extensions() end)
    :ok
  end

  test "every extension start order has one deterministic complete registry" do
    {overlaps, expected_all_loaded} = overlap_contract()
    assert length(overlaps) == 227
    expected_canonicals = expected_canonical_names()
    assert length(expected_canonicals) == 2_093

    snapshots =
      Enum.map(permutations(@extensions), fn order ->
        stop_extensions()

        Enum.each(order, fn app ->
          assert {:ok, started} = Application.ensure_all_started(app)
          assert app in started
        end)

        encodings = Iconvex.encodings()
        assert encodings |> Enum.map(&normalize/1) |> Enum.sort() == expected_canonicals
        assert length(Enum.uniq_by(encodings, &normalize/1)) == length(expected_canonicals)

        snapshot = complete_name_snapshot()

        Enum.each(expected_all_loaded, fn {name, expected_codec} ->
          assert Map.fetch!(snapshot, name) == expected_codec
        end)

        Enum.each(@gnu_reclaimed_rfc_names, fn name ->
          assert extras_codec?(resolved_codec(name))
          assert specs_codec?(resolved_codec("RFC1345:#{name}"))
        end)

        snapshot
      end)

    assert length(Enum.uniq(snapshots)) == 1
  end

  test "stopping either overlapping package exposes the other package's claims" do
    stop_extensions()
    Enum.each(@extensions, &assert_started/1)

    {overlaps, expected_all_loaded} = overlap_contract()
    assert Enum.count(expected_all_loaded, fn {_name, codec} -> extras_codec?(codec) end) == 227
    assert Enum.count(expected_all_loaded, fn {_name, codec} -> specs_codec?(codec) end) == 0

    assert :ok = Application.stop(:iconvex_extras)
    Enum.each(overlaps, fn {name, specs, _extras} -> assert_resolves(name, specs.codec) end)

    assert_started(:iconvex_extras)

    Enum.each(expected_all_loaded, fn {name, codec} ->
      assert_resolves(name, codec)
    end)

    assert :ok = Application.stop(:iconvex_specs)
    Enum.each(overlaps, fn {name, _specs, extras} -> assert_resolves(name, extras.codec) end)
  end

  test "current release documents derive overlap and packed-profile counts from runtime" do
    {overlaps, _expected_all_loaded} = overlap_contract()
    overlap_count = length(overlaps)
    packed_profile_count = length(Iconvex.Telecom.Packed.profiles())

    assert overlap_count == 227
    assert packed_profile_count == 51

    overlap_documents = [
      "ICONVEX_FULL_STACK_SUPPORT.md",
      "iconvex/README.md",
      "iconvex/EXTENDING.md",
      "iconvex/CHANGELOG.md",
      "iconvex_extras/README.md",
      "iconvex_extras/CHANGELOG.md",
      "iconvex_specs/README.md",
      "iconvex_integration/README.md"
    ]

    for relative <- overlap_documents do
      document =
        @workspace
        |> Path.join(relative)
        |> File.read!()
        |> String.replace(~r/\s+/, " ")

      assert Regex.match?(
               ~r/(?:\b#{overlap_count}\b.{0,100}\boverlap|\boverlap.{0,100}\b#{overlap_count}\b)/iu,
               document
             ),
             "#{relative} does not publish the runtime-derived #{overlap_count}-overlap count"

      refute Regex.match?(
               ~r/(?:\b231\b.{0,100}\boverlap|\boverlap.{0,100}\b231\b)/iu,
               document
             ),
             "#{relative} still publishes the superseded 231-overlap count"
    end

    support_document =
      @workspace
      |> Path.join("iconvex/SUPPORTED_ENCODINGS.md")
      |> File.read!()
      |> String.replace(~r/\s+/, " ")

    assert support_document =~
             "exact #{packed_profile_count}-codec packed-profile inventory"

    refute support_document =~ "exact 49-codec packed-profile inventory"
  end

  defp overlap_contract do
    specs =
      for registration <- Iconvex.Specs.registrations(),
          {name, kind} <- registration_claims(registration),
          into: %{} do
        {name, %{codec: registration.codec, kind: kind, priority: 0}}
      end

    extras =
      for codec <- Iconvex.Extras.codecs(),
          {name, kind} <- module_claims(codec),
          into: %{} do
        {name, %{codec: codec, kind: kind, priority: 100}}
      end

    overlap_names =
      specs
      |> Map.keys()
      |> MapSet.new()
      |> MapSet.intersection(MapSet.new(Map.keys(extras)))
      |> Enum.sort()

    overlaps =
      Enum.map(overlap_names, fn name ->
        {name, Map.fetch!(specs, name), Map.fetch!(extras, name)}
      end)

    categories =
      Enum.frequencies_by(overlaps, fn {_name, specs, extras} -> {specs.kind, extras.kind} end)

    assert categories == %{
             {:alias, :alias} => 164,
             {:alias, :canonical} => 63
           }

    expected =
      Map.new(overlaps, fn {name, specs, extras} ->
        winner = Enum.max_by([specs, extras], &{kind_rank(&1.kind), &1.priority})
        {name, winner.codec}
      end)

    {overlaps, expected}
  end

  defp complete_name_snapshot do
    names =
      for(
        registration <- Iconvex.Specs.registrations(),
        {name, _kind} <- registration_claims(registration),
        do: name
      ) ++
        for(codec <- Iconvex.Extras.codecs(), {name, _kind} <- module_claims(codec), do: name) ++
        for codec <- Iconvex.Telecom.codecs(), {name, _kind} <- module_claims(codec), do: name

    names
    |> Enum.uniq()
    |> Enum.sort()
    |> Map.new(fn name -> {name, resolved_codec(name)} end)
  end

  defp expected_canonical_names do
    (Iconvex.Registry.builtin_canonical_names() ++
       Enum.map(Iconvex.Specs.registrations(), & &1.canonical) ++
       Iconvex.Extras.encodings() ++ Iconvex.Telecom.encodings())
    |> Enum.map(&normalize/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp registration_claims(registration) do
    claims(registration.canonical, registration.aliases)
  end

  defp module_claims(codec), do: claims(codec.canonical_name(), codec.aliases())

  defp claims(canonical, aliases) do
    canonical = normalize(canonical)

    [{canonical, :canonical} | Enum.map(aliases, &{normalize(&1), :alias})]
    |> Enum.reduce(%{}, fn {name, kind}, acc ->
      Map.update(acc, name, kind, fn existing ->
        if kind_rank(kind) > kind_rank(existing), do: kind, else: existing
      end)
    end)
  end

  defp permutations([]), do: [[]]

  defp permutations(items) do
    for item <- items, rest <- permutations(List.delete(items, item)), do: [item | rest]
  end

  defp assert_started(app) do
    assert {:ok, started} = Application.ensure_all_started(app)
    assert app in started
  end

  defp stop_extensions do
    Enum.each(Enum.reverse(@extensions), fn app ->
      if List.keymember?(Application.started_applications(), app, 0) do
        assert :ok = Application.stop(app)
      end
    end)
  end

  defp assert_resolves(name, codec) do
    assert {:ok, %{codec: ^codec}} = Iconvex.Registry.resolve(name)
  end

  defp resolved_codec(name) do
    assert {:ok, %{codec: codec}} = Iconvex.Registry.resolve(name)
    codec
  end

  defp extras_codec?(codec), do: codec in Iconvex.Extras.codecs()
  defp specs_codec?(codec), do: codec in Iconvex.Specs.codecs()
  defp kind_rank(:canonical), do: 1
  defp kind_rank(:alias), do: 0
  defp normalize(name), do: String.upcase(name, :ascii)
end

defmodule Iconvex.Extras.PackageTest.LateConflictCodec do
  @moduledoc false

  alias Iconvex.Extras.Codecs.Tds565

  def canonical_name, do: "X-EXTRAS-LATE-CONFLICT"
  def aliases, do: ["TDS565"]
  def codec_id, do: :extras_late_conflict
  def decode(input), do: Tds565.decode(input)
  def decode_discard(input), do: Tds565.decode_discard(input)
  def encode(codepoints), do: Tds565.encode(codepoints)
  def encode_discard(codepoints), do: Tds565.encode_discard(codepoints)
  def encode_substitute(codepoints, replacer), do: Tds565.encode_substitute(codepoints, replacer)
end

defmodule Iconvex.Extras.PackageTest do
  use ExUnit.Case, async: false

  alias Iconvex.Extras.TestFixture
  alias Iconvex.Extras.PackageTest.LateConflictCodec

  @fixed_files ~w(
    encodings.def encodings_extra.def encodings_aix.def encodings_dos.def
    encodings_osf1.def encodings_zos.def
  )

  @readme Path.expand("../README.md", __DIR__)
  @changelog Path.expand("../CHANGELOG.md", __DIR__)

  test "RED: release documents state current Specs and full-stack cardinalities" do
    readme = File.read!(@readme)
    changelog = File.read!(@changelog)

    assert readme =~ "all 1,841 runtime Specs codecs"
    assert readme =~ "2,093 unique canonical"
    assert changelog =~ "all 1,841 runtime Specs codecs"
  end

  test "consumer package excludes development corpora" do
    package_files = Mix.Project.config() |> Keyword.fetch!(:package) |> Keyword.fetch!(:files)

    for development_directory <- ~w(test bench tools) do
      refute development_directory in package_files
    end
  end

  test "extras package is exact 86-codec complement of 112-codec core" do
    {core_entries, _core_aliases} = TestFixture.parse_definitions(["encodings.def"])
    {union_entries, aliases} = TestFixture.parse_definitions(@fixed_files)

    core = core_entries |> Map.values() |> MapSet.new()
    union = union_entries |> Map.values() |> MapSet.new()
    extras = MapSet.difference(union, core)

    assert MapSet.size(core) == 112
    assert MapSet.size(extras) == 86
    assert map_size(aliases) == 758
    assert MapSet.new(Iconvex.Extras.encodings()) == extras
    assert MapSet.new(Iconvex.encodings()) == union
    assert length(Iconvex.Extras.codecs()) == 86

    for {name, id} <- aliases do
      assert Iconvex.canonical_name(name) == {:ok, Map.fetch!(union_entries, id)}, name

      assert Iconvex.canonical_name(String.downcase(name, :ascii)) ==
               {:ok, Map.fetch!(union_entries, id)}
    end
  end

  test "all extra implementations resolve externally and all tables live outside core" do
    for module <- Iconvex.Extras.codecs() do
      assert {:ok, %{kind: :external, codec: ^module}} = Iconvex.Registry.resolve(module)
    end

    extras_tables =
      :iconvex_extras
      |> :code.priv_dir()
      |> Path.join("tables/*.etf")
      |> Path.wildcard()

    assert length(extras_tables) == 85

    for path <- extras_tables do
      refute File.exists?(Application.app_dir(:iconvex, "priv/tables/#{Path.basename(path)}"))
    end
  end

  test "generated inventory is an exact runtime canonical-name and alias snapshot" do
    csv_field = fn value ->
      if String.contains?(value, [",", "\"", "\n", "\r"]) do
        "\"" <> String.replace(value, "\"", "\"\"") <> "\""
      else
        value
      end
    end

    rows =
      Iconvex.Extras.codecs()
      |> Enum.sort_by(&{&1.canonical_name(), inspect(&1)})
      |> Enum.map(fn codec ->
        [
          codec.canonical_name(),
          codec.aliases() |> Enum.sort() |> Enum.join("|"),
          inspect(codec),
          to_string(codec.stateful?())
        ]
        |> Enum.map_join(",", csv_field)
      end)

    expected = Enum.join(["canonical,aliases,module,stateful" | rows], "\n") <> "\n"

    assert length(rows) == 86
    assert File.read!("SUPPORTED_CODEC_INVENTORY.csv") == expected
  end

  test "stopping extras restores exact core set and restart restores union" do
    assert length(Iconvex.encodings()) == 198
    assert :ok = Application.stop(:iconvex_extras)
    assert length(Iconvex.encodings()) == 112
    assert Iconvex.canonical_name("IBM-1047") == :error
    assert {:ok, started} = Application.ensure_all_started(:iconvex_extras)
    assert :iconvex_extras in started
    assert length(Iconvex.encodings()) == 198
  end

  test "stopping extras preserves codec registrations it did not create" do
    codec = hd(Iconvex.Extras.codecs())
    canonical = codec.canonical_name()

    assert :ok = Application.stop(:iconvex_extras)
    assert :ok = Iconvex.register_codec(codec)

    try do
      assert {:ok, started} = Application.ensure_all_started(:iconvex_extras)
      assert :iconvex_extras in started
      assert {:ok, %{codec: ^codec}} = Iconvex.ExternalRegistry.resolve(codec)

      assert :ok = Application.stop(:iconvex_extras)
      assert {:ok, %{codec: ^codec}} = Iconvex.ExternalRegistry.resolve(codec)
      assert Iconvex.canonical_name(canonical) == {:ok, canonical}
    after
      Application.stop(:iconvex_extras)
      Iconvex.unregister_codec(codec)
      assert {:ok, _started} = Application.ensure_all_started(:iconvex_extras)
    end
  end

  test "stopping extras preserves a table provider registration it did not create" do
    provider = :euc_jisx0213
    provider_key = {{Iconvex.Tables, :provider}, provider}

    assert :ok = Application.stop(:iconvex_extras)
    assert :ok = Iconvex.Tables.register_provider(provider, :iconvex_extras)

    try do
      assert {:ok, started} = Application.ensure_all_started(:iconvex_extras)
      assert :iconvex_extras in started
      assert :ok = Application.stop(:iconvex_extras)

      assert :persistent_term.get(provider_key) == {:iconvex_extras, :unowned}
    after
      Application.stop(:iconvex_extras)
      Iconvex.Tables.unregister_provider(provider, :iconvex_extras)
      assert {:ok, _started} = Application.ensure_all_started(:iconvex_extras)
    end
  end

  test "stopping extras preserves a codec that a caller replaces after startup" do
    codec = hd(Iconvex.Extras.codecs())

    assert :ok = Iconvex.register_codec(codec, canonical: "X-CALLER-EXTRAS")

    try do
      assert :ok = Application.stop(:iconvex_extras)
      assert Iconvex.canonical_name(codec) == {:ok, "X-CALLER-EXTRAS"}
    after
      Application.stop(:iconvex_extras)
      Iconvex.unregister_codec(codec)
      assert {:ok, _started} = Application.ensure_all_started(:iconvex_extras)
    end
  end

  test "stopping extras preserves a provider that a caller replaces after startup" do
    provider = :euc_jisx0213
    provider_key = {{Iconvex.Tables, :provider}, provider}

    assert :ok = Iconvex.Tables.unregister_provider(provider, :iconvex_extras)
    assert :ok = Iconvex.Tables.register_provider(provider, :iconvex_extras)

    try do
      assert :ok = Application.stop(:iconvex_extras)
      assert :persistent_term.get(provider_key) == {:iconvex_extras, :unowned}
    after
      Application.stop(:iconvex_extras)
      Iconvex.Tables.unregister_provider(provider, :iconvex_extras)
      assert {:ok, _started} = Application.ensure_all_started(:iconvex_extras)
    end
  end

  test "a conflict at the final codec rolls back the complete partial startup" do
    codecs = Iconvex.Extras.codecs()
    final_codec = List.last(codecs)
    earlier_codecs = Enum.drop(codecs, -1)
    provider_key = {{Iconvex.Tables, :provider}, :euc_jisx0213}
    provider_token_key = {{Iconvex.Tables, :provider_token}, :euc_jisx0213}

    assert final_codec == Iconvex.Extras.Codecs.Tds565
    assert length(earlier_codecs) == 85
    assert :ok = Application.stop(:iconvex_extras)
    assert :persistent_term.get(provider_key, :missing) == :missing
    assert :persistent_term.get(provider_token_key, :missing) == :missing
    assert {:ok, conflict_token} = Iconvex.ExternalRegistry.register_owned(LateConflictCodec)

    try do
      assert {:error, {:iconvex_extras, start_failure}} =
               Application.ensure_all_started(:iconvex_extras)

      assert unwrap_start_failure(start_failure) == {:name_conflict, "TDS565"}

      refute Enum.any?(Application.started_applications(), &(elem(&1, 0) == :iconvex_extras))

      for codec <- earlier_codecs do
        assert Iconvex.ExternalRegistry.resolve(codec) == :error

        for name <- [codec.canonical_name() | codec.aliases()] do
          assert Iconvex.ExternalRegistry.resolve(name) == :error
        end
      end

      assert Iconvex.ExternalRegistry.resolve(final_codec) == :error

      assert {:ok, %{codec: LateConflictCodec, registration_token: ^conflict_token}} =
               Iconvex.ExternalRegistry.resolve("TDS565")

      assert Iconvex.canonical_name("TDS565") == {:ok, "X-EXTRAS-LATE-CONFLICT"}
      assert :persistent_term.get(provider_key, :missing) == :missing
      assert :persistent_term.get(provider_token_key, :missing) == :missing
    after
      Application.stop(:iconvex_extras)
      Iconvex.ExternalRegistry.unregister(LateConflictCodec, conflict_token)
    end

    assert {:ok, started} = Application.ensure_all_started(:iconvex_extras)
    assert :iconvex_extras in started

    assert {:iconvex_extras, {:owned, provider_token}} =
             :persistent_term.get(provider_key)

    assert is_reference(provider_token)
    assert :persistent_term.get(provider_token_key, :missing) == :missing
    assert length(Iconvex.encodings()) == 198

    for codec <- codecs do
      assert {:ok, %{codec: ^codec}} = Iconvex.ExternalRegistry.resolve(codec)
    end
  end

  test "registry restart preserves extras registrations and their ownership tokens" do
    old_registry = Process.whereis(Iconvex.ExternalRegistry)
    monitor = Process.monitor(old_registry)
    Process.exit(old_registry, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^old_registry, :killed}, 1_000

    try do
      assert is_pid(wait_for_registry_restart(old_registry))
      assert Iconvex.canonical_name("IBM-1047") == {:ok, "IBM-1047"}
      assert length(Iconvex.encodings()) == 198

      assert :ok = Application.stop(:iconvex_extras)
      assert Iconvex.canonical_name("IBM-1047") == :error
      assert length(Iconvex.encodings()) == 112
    after
      assert {:ok, _started} = Application.ensure_all_started(:iconvex_extras)
    end
  end

  test "all shipped codecs use the native linear substitution callback" do
    assert Enum.all?(Iconvex.Extras.codecs(), &function_exported?(&1, :encode_substitute, 2))

    input = :binary.copy(<<0x1F600::utf8>>, 400)
    mfas = [{Iconvex.TableCodec, :encode, 2}, {Iconvex.TableCodec, :encode_substitute, 3}]

    Code.ensure_loaded!(Iconvex.TableCodec)
    Enum.each(mfas, &:erlang.trace_pattern(&1, true, [:local, :call_count]))

    try do
      assert Iconvex.convert(input, "UTF-8", "CP437", unicode_substitute: "<U+%04X>") ==
               {:ok, :binary.copy("<U+1F600>", 400)}

      assert {:call_count, substitute_calls} =
               :erlang.trace_info({Iconvex.TableCodec, :encode_substitute, 3}, :call_count)

      assert substitute_calls == 1

      assert {:call_count, encode_calls} =
               :erlang.trace_info({Iconvex.TableCodec, :encode, 2}, :call_count)

      assert encode_calls <= 1
    after
      Enum.each(mfas, &:erlang.trace_pattern(&1, false, [:local, :call_count]))
    end
  end

  defp wait_for_registry_restart(old_registry, attempts \\ 1_000)

  defp wait_for_registry_restart(_old_registry, 0), do: nil

  defp wait_for_registry_restart(old_registry, attempts) do
    case Process.whereis(Iconvex.ExternalRegistry) do
      pid when is_pid(pid) and pid != old_registry ->
        pid

      _missing_or_same ->
        Process.sleep(1)
        wait_for_registry_restart(old_registry, attempts - 1)
    end
  end

  defp unwrap_start_failure({reason, {_module, :start, _arguments}}), do: reason
  defp unwrap_start_failure(reason), do: reason
end

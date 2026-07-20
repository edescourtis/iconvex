defmodule Iconvex.Specs.RegistrationIdentityTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs

  defmodule RollbackConflictCodec do
    @behaviour Iconvex.Codec

    @impl true
    def canonical_name, do: "x-iscii-ma"

    @impl true
    def aliases, do: []

    @impl true
    def stateful?, do: false

    @impl true
    def decode(input), do: {:ok, :binary.bin_to_list(input)}

    @impl true
    def decode_discard(input), do: decode(input)

    @impl true
    def encode(codepoints), do: {:ok, :erlang.list_to_binary(codepoints)}

    @impl true
    def encode_discard(codepoints), do: encode(codepoints)

    @impl true
    def encode_substitute(codepoints, replacer) do
      Enum.reduce_while(codepoints, {:ok, []}, fn
        codepoint, {:ok, acc} when codepoint in 0..0xFF ->
          {:cont, {:ok, [<<codepoint>> | acc]}}

        codepoint, {:ok, acc} ->
          replacement = replacer.(codepoint)

          if is_list(replacement) and Enum.all?(replacement, &(&1 in 0..0xFF)) do
            {:cont, {:ok, [:erlang.list_to_binary(replacement) | acc]}}
          else
            {:halt, {:error, :unrepresentable_character, codepoint}}
          end
      end)
      |> case do
        {:ok, reversed} -> {:ok, reversed |> Enum.reverse() |> IO.iodata_to_binary()}
        {:error, _kind, _codepoint} = error -> error
      end
    end
  end

  @first_codec Iconvex.Specs.RFC1345.Codecs.C001
  @last_codec :"Elixir.Iconvex.Specs.ISCII.Codecs.x_iscii_ma"
  @first_provider :rfc1345_001
  @last_provider :iso_ir_169
  @conflict_owner :iconvex_specs_rollback_fixture
  @archive_shards [
    {:iconvex_specs_icu_archive_a, 1, 350},
    {:iconvex_specs_icu_archive_b, 351, 700},
    {:iconvex_specs_icu_archive_c, 701, 1050}
  ]
  @gnu_conflicting_rfc_names ~w(
    IBM037 IBM1026 IBM273 IBM277 IBM278 IBM280 IBM284 IBM285 IBM297 IBM424
    IBM437 IBM500 IBM852 IBM855 IBM857 IBM860 IBM861 IBM863 IBM864 IBM865
    IBM869 IBM870 IBM871 IBM880 IBM905
  )

  test "every supported module resolves through its exact declared registry identity" do
    registrations = Specs.registrations()
    assert length(registrations) == 1_841
    assert Enum.uniq_by(registrations, &String.upcase(&1.canonical, :ascii)) == registrations

    for %{codec: codec, canonical: canonical, aliases: aliases} <- registrations do
      assert {:ok, %{codec: ^codec, canonical: ^canonical}} = Iconvex.Registry.resolve(canonical)

      for alias_name <- aliases do
        assert {:ok, %{codec: ^codec, canonical: ^canonical}} =
                 Iconvex.Registry.resolve(alias_name)
      end
    end
  end

  test "new source-qualified codecs resolve only their exact public identities" do
    assert {:ok, %{codec: Iconvex.Specs.LotusLICS, canonical: "LICS"}} =
             Iconvex.Registry.resolve("LICS")

    assert {:ok, %{codec: Iconvex.Specs.LotusLICS, canonical: "LICS"}} =
             Iconvex.Registry.resolve("LOTUS-INTERNATIONAL-CHARACTER-SET")

    canonical = "US-ARMY-GTA-31-70-001-TAP-CODE-PAIR-VALUES"

    for identity <- [
          canonical,
          "US-ARMY-POW-TAP-CODE-PAIR-VALUES",
          "GTA-31-70-001-TAP-CODE-PAIR-VALUES",
          "POW-TAP-CODE-5X5-PAIR-VALUES"
        ] do
      assert {:ok,
              %{
                codec: Iconvex.Specs.USArmyTapCodePairValues,
                canonical: ^canonical
              }} = Iconvex.Registry.resolve(identity)
    end

    for unsupported <- ["TAP-CODE", "KNOCK-CODE", "POLYBIUS-SQUARE"] do
      assert Iconvex.Registry.resolve(unsupported) == :error
    end
  end

  test "all 58 qualified collisions have stable identities and exact mappings" do
    qualified =
      Specs.registrations()
      |> Enum.filter(&(&1.canonical != &1.codec.canonical_name()))

    assert length(qualified) == 58
    assert Enum.count(qualified, &String.starts_with?(&1.canonical, "RFC1345:")) == 47
    assert Enum.count(qualified, &String.starts_with?(&1.canonical, "UNICODE-APPLE:")) == 10
    assert Enum.count(qualified, &String.starts_with?(&1.canonical, "ICU-MULTIBYTE:")) == 1

    assert {:ok, %{codec: Iconvex.Specs.VendorMappings.Codecs.C018}} =
             Iconvex.Registry.resolve("Mac-Hebrew")

    assert Iconvex.canonical_name("Mac-Hebrew") == {:ok, "UNICODE-APPLE:MacHebrew"}

    for registration <- qualified do
      for byte <- 0..255 do
        assert_public_decode_matches_module(registration, <<byte>>)
      end

      table = Iconvex.Tables.fetch!(registration.codec.codec_id())

      case table.many |> Map.keys() |> Enum.sort() |> List.first() do
        nil -> :ok
        sequence -> assert_public_decode_matches_module(registration, sequence)
      end
    end
  end

  test "RED: GNU-conflicting RFC 1345 identities and every alias are source-qualified" do
    registrations = Specs.registrations()

    for declared <- @gnu_conflicting_rfc_names do
      registration =
        Enum.find(registrations, &(&1.source == "RFC1345" and &1.declared_canonical == declared))

      entry = Enum.find(Iconvex.Specs.RFC1345.encodings(), &(&1.name == declared))
      expected_aliases = Enum.map(entry.aliases, &"RFC1345:#{&1}")

      assert registration.canonical == "RFC1345:#{declared}"
      assert registration.aliases != []
      assert Enum.sort(registration.aliases) == Enum.sort(expected_aliases)

      assert {:ok, %{codec: codec, canonical: canonical}} =
               Iconvex.Registry.resolve(registration.canonical)

      assert codec == registration.codec
      assert canonical == registration.canonical

      for alias_name <- registration.aliases do
        assert {:ok, %{codec: alias_codec, canonical: alias_canonical}} =
                 Iconvex.Registry.resolve(alias_name)

        assert alias_codec == registration.codec
        assert alias_canonical == registration.canonical
      end
    end

    assert Enum.count(
             registrations,
             &(&1.source == "RFC1345" and
                 &1.declared_canonical in @gnu_conflicting_rfc_names and
                 String.starts_with?(&1.canonical, "RFC1345:"))
           ) == 25
  end

  test "stopping Specs preserves caller-owned codec and provider registrations" do
    provider = :rfc1345_001
    assert :ok = Application.stop(:iconvex_specs)
    assert :ok = Iconvex.register_codec(Specs.CESU8)
    assert :ok = Iconvex.Tables.register_provider(provider, :iconvex_specs)

    try do
      assert {:ok, _started} = Application.ensure_all_started(:iconvex_specs)
      assert :ok = Application.stop(:iconvex_specs)
      assert {:ok, %{codec: Specs.CESU8}} = Iconvex.ExternalRegistry.resolve(Specs.CESU8)

      assert provider_owner(provider) == :iconvex_specs
    after
      Application.stop(:iconvex_specs)
      Iconvex.unregister_codec(Specs.CESU8)
      Iconvex.Tables.unregister_provider(provider, :iconvex_specs)
      {:ok, _started} = Application.ensure_all_started(:iconvex_specs)
    end
  end

  test "stopping Specs does not remove codec or provider replacements installed after start" do
    provider = :rfc1345_001
    assert :ok = Application.stop(:iconvex_specs)

    try do
      assert {:ok, _started} = Application.ensure_all_started(:iconvex_specs)

      # Replace registrations after the application receives its ownership tokens.
      assert :ok = Iconvex.register_codec(Specs.CESU8)
      assert :ok = Iconvex.Tables.unregister_provider(provider, :iconvex_specs)
      assert :ok = Iconvex.Tables.register_provider(provider, :iconvex_specs)

      assert :ok = Application.stop(:iconvex_specs)
      assert {:ok, %{codec: Specs.CESU8}} = Iconvex.ExternalRegistry.resolve(Specs.CESU8)

      assert provider_owner(provider) == :iconvex_specs
    after
      Application.stop(:iconvex_specs)
      Iconvex.unregister_codec(Specs.CESU8)
      Iconvex.Tables.unregister_provider(provider, :iconvex_specs)
      {:ok, _started} = Application.ensure_all_started(:iconvex_specs)
    end
  end

  test "Specs rolls back every newly acquired provider when its last provider conflicts" do
    assert :ok = Application.stop(:iconvex_specs)
    assert :ok = Iconvex.Tables.register_provider(@last_provider, @conflict_owner)

    try do
      assert_start_failure(
        :iconvex_specs,
        {:table_provider_conflict, @last_provider, @conflict_owner}
      )

      assert provider_owner(@first_provider) == :missing
      assert provider_owner(@last_provider) == @conflict_owner
      assert providers_owned_by(:iconvex_specs) == []
      assert Iconvex.ExternalRegistry.resolve(@first_codec) == :error

      assert :ok =
               Iconvex.Tables.unregister_provider(@last_provider, @conflict_owner)

      assert {:ok, _started} = Application.ensure_all_started(:iconvex_specs)
      assert provider_owner(@first_provider) == :iconvex_specs
      assert provider_owner(@last_provider) == :iconvex_specs
      assert {:ok, %{codec: @first_codec}} = Iconvex.ExternalRegistry.resolve(@first_codec)
    after
      Application.stop(:iconvex_specs)
      Iconvex.Tables.unregister_provider(@last_provider, @conflict_owner)
      {:ok, _started} = Application.ensure_all_started(:iconvex_specs)
    end
  end

  test "Specs rolls back every codec and provider when its last codec conflicts" do
    assert :ok = Application.stop(:iconvex_specs)
    assert {:ok, fixture_token} = Iconvex.register_codec_owned(RollbackConflictCodec)

    try do
      assert_start_failure(:iconvex_specs, {:name_conflict, "X-ISCII-MA"})

      assert Iconvex.ExternalRegistry.resolve(@first_codec) == :error
      assert Iconvex.ExternalRegistry.resolve(@last_codec) == :error
      assert length(Specs.registrations()) == 1_841

      for %{codec: codec} <- Specs.registrations() do
        assert Iconvex.ExternalRegistry.resolve(codec) == :error
      end

      assert provider_owner(@first_provider) == :missing
      assert provider_owner(@last_provider) == :missing
      assert providers_owned_by(:iconvex_specs) == []

      assert {:ok,
              %{
                codec: RollbackConflictCodec,
                canonical: "x-iscii-ma",
                registration_token: ^fixture_token
              }} = Iconvex.ExternalRegistry.resolve(RollbackConflictCodec)

      assert Iconvex.canonical_name("x-iscii-ma") == {:ok, "x-iscii-ma"}

      assert :ok = Iconvex.unregister_codec(RollbackConflictCodec, fixture_token)
      assert {:ok, _started} = Application.ensure_all_started(:iconvex_specs)
      assert {:ok, %{codec: @first_codec}} = Iconvex.ExternalRegistry.resolve(@first_codec)
      assert {:ok, %{codec: @last_codec}} = Iconvex.ExternalRegistry.resolve(@last_codec)
      assert provider_owner(@first_provider) == :iconvex_specs
      assert provider_owner(@last_provider) == :iconvex_specs
    after
      Application.stop(:iconvex_specs)
      Iconvex.unregister_codec(RollbackConflictCodec, fixture_token)
      {:ok, _started} = Application.ensure_all_started(:iconvex_specs)
    end
  end

  for {app, first_index, conflict_index} <- @archive_shards do
    test "#{app} rolls back its provider range when its last provider conflicts" do
      app = unquote(app)
      first_index = unquote(first_index)
      conflict_index = unquote(conflict_index)
      first_provider = String.to_atom("icu_archive_#{first_index}")
      conflict_provider = String.to_atom("icu_archive_#{conflict_index}")

      assert :ok = Application.stop(:iconvex_specs)
      assert :ok = Application.stop(app)
      assert :ok = Iconvex.Tables.register_provider(conflict_provider, @conflict_owner)

      try do
        assert_start_failure(
          app,
          {:table_provider_conflict, conflict_provider, @conflict_owner}
        )

        assert provider_owner(first_provider) == :missing
        assert provider_owner(conflict_provider) == @conflict_owner

        for index <- first_index..(conflict_index - 1) do
          assert provider_owner(String.to_atom("icu_archive_#{index}")) == :missing
        end

        assert :ok =
                 Iconvex.Tables.unregister_provider(conflict_provider, @conflict_owner)

        assert {:ok, _started} = Application.ensure_all_started(app)
        assert provider_owner(first_provider) == app
        assert provider_owner(conflict_provider) == app
      after
        Application.stop(:iconvex_specs)
        Application.stop(app)
        Iconvex.Tables.unregister_provider(conflict_provider, @conflict_owner)
        {:ok, _started} = Application.ensure_all_started(app)
        {:ok, _started} = Application.ensure_all_started(:iconvex_specs)
      end
    end
  end

  test "stopping each ICU archive shard preserves caller-owned provider registrations" do
    assert :ok = Application.stop(:iconvex_specs)

    shards = [
      {:iconvex_specs_icu_archive_a, :icu_archive_1},
      {:iconvex_specs_icu_archive_b, :icu_archive_351},
      {:iconvex_specs_icu_archive_c, :icu_archive_701}
    ]

    try do
      for {app, provider} <- shards do
        assert :ok = Application.stop(app)
        assert :ok = Iconvex.Tables.register_provider(provider, app)
        assert {:ok, _started} = Application.ensure_all_started(app)
        assert :ok = Application.stop(app)
        assert provider_owner(provider) == app
        Iconvex.Tables.unregister_provider(provider, app)
        assert {:ok, _started} = Application.ensure_all_started(app)
      end
    after
      for {app, provider} <- shards do
        Application.stop(app)
        Iconvex.Tables.unregister_provider(provider, app)
        {:ok, _started} = Application.ensure_all_started(app)
      end

      {:ok, _started} = Application.ensure_all_started(:iconvex_specs)
    end
  end

  test "stopping each ICU archive shard preserves providers replaced after start" do
    assert :ok = Application.stop(:iconvex_specs)

    shards = [
      {:iconvex_specs_icu_archive_a, :icu_archive_1},
      {:iconvex_specs_icu_archive_b, :icu_archive_351},
      {:iconvex_specs_icu_archive_c, :icu_archive_701}
    ]

    try do
      for {app, provider} <- shards do
        assert :ok = Application.stop(app)
        assert {:ok, _started} = Application.ensure_all_started(app)
        assert :ok = Iconvex.Tables.unregister_provider(provider, app)
        assert :ok = Iconvex.Tables.register_provider(provider, app)
        assert :ok = Application.stop(app)
        assert provider_owner(provider) == app
        Iconvex.Tables.unregister_provider(provider, app)
        assert {:ok, _started} = Application.ensure_all_started(app)
      end
    after
      for {app, provider} <- shards do
        Application.stop(app)
        Iconvex.Tables.unregister_provider(provider, app)
        {:ok, _started} = Application.ensure_all_started(app)
      end

      {:ok, _started} = Application.ensure_all_started(:iconvex_specs)
    end
  end

  test "registry restart preserves Specs and archive-shard ownership state" do
    shards = [
      {:iconvex_specs_icu_archive_a, :icu_archive_1},
      {:iconvex_specs_icu_archive_b, :icu_archive_351},
      {:iconvex_specs_icu_archive_c, :icu_archive_701}
    ]

    old_registry = Process.whereis(Iconvex.ExternalRegistry)
    monitor = Process.monitor(old_registry)
    Process.exit(old_registry, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^old_registry, :killed}, 1_000

    try do
      assert is_pid(wait_for_registry_restart(old_registry))
      assert Iconvex.canonical_name(Specs.CESU8) == {:ok, "CESU-8"}
      assert Iconvex.canonical_name("Mac-Hebrew") == {:ok, "UNICODE-APPLE:MacHebrew"}

      assert provider_owner(:rfc1345_001) == :iconvex_specs

      for {app, provider} <- shards do
        assert provider_owner(provider) == app
      end

      assert :ok = Application.stop(:iconvex_specs)
      assert Iconvex.canonical_name(Specs.CESU8) == :error

      assert :persistent_term.get(
               {{Iconvex.Tables, :provider}, :rfc1345_001},
               :missing
             ) == :missing

      for {app, provider} <- shards do
        assert :ok = Application.stop(app)

        assert :persistent_term.get({{Iconvex.Tables, :provider}, provider}, :missing) ==
                 :missing
      end
    after
      for {app, _provider} <- shards do
        {:ok, _started} = Application.ensure_all_started(app)
      end

      {:ok, _started} = Application.ensure_all_started(:iconvex_specs)
    end
  end

  defp assert_public_decode_matches_module(
         %{codec: codec, canonical: canonical},
         sequence
       ) do
    case codec.decode_to_utf8(sequence) do
      {:ok, expected} ->
        assert Iconvex.convert(sequence, canonical, "UTF-8") == {:ok, expected}

      {:error, reason, offset, offending} ->
        assert {:error,
                %Iconvex.Error{
                  kind: ^reason,
                  offset: ^offset,
                  sequence: ^offending
                }} = Iconvex.convert(sequence, canonical, "UTF-8")
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

  defp assert_start_failure(app, expected_reason) do
    assert {:error, {^app, start_failure}} = Application.ensure_all_started(app)
    assert unwrap_start_failure(start_failure) == expected_reason
  end

  defp unwrap_start_failure({reason, {_module, :start, _arguments}}), do: reason
  defp unwrap_start_failure(reason), do: reason

  defp provider_owner(provider) do
    case :persistent_term.get({{Iconvex.Tables, :provider}, provider}, :missing) do
      {app, {:owned, token}} when is_atom(app) and is_reference(token) -> app
      {app, :unowned} when is_atom(app) -> app
      app -> app
    end
  end

  defp providers_owned_by(app) do
    for {{{Iconvex.Tables, :provider}, provider}, record} <- :persistent_term.get(),
        provider_record_app(record) == app,
        do: provider
  end

  defp provider_record_app({app, {:owned, token}})
       when is_atom(app) and is_reference(token),
       do: app

  defp provider_record_app({app, :unowned}) when is_atom(app), do: app
  defp provider_record_app(app), do: app
end

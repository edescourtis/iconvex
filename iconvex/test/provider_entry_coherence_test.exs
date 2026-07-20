defmodule Iconvex.ProviderEntryCoherenceTest.OldCodec do
  use Iconvex.Codec

  @config_key {__MODULE__, :config}

  def configure(table_id, canonical), do: :persistent_term.put(@config_key, {table_id, canonical})
  def clear, do: :persistent_term.erase(@config_key)

  @impl true
  def canonical_name, do: elem(:persistent_term.get(@config_key), 1)

  @impl true
  def codec_id, do: elem(:persistent_term.get(@config_key), 0)

  @impl true
  def decode(<<>>), do: {:ok, []}

  def decode(_input),
    do: {:ok, [Map.fetch!(Iconvex.Tables.fetch!(codec_id()), :old_codepoint)]}

  @impl true
  def decode_discard(input), do: decode(input)

  @impl true
  def encode(codepoints), do: {:ok, :erlang.list_to_binary(codepoints)}

  @impl true
  def encode_discard(codepoints), do: encode(codepoints)

  @impl true
  def encode_substitute(codepoints, _replacer), do: encode(codepoints)

  @impl true
  def decode_chunk(input, _final?) do
    case decode(input) do
      {:ok, codepoints} -> {:ok, codepoints, <<>>}
      error -> error
    end
  end
end

defmodule Iconvex.ProviderEntryCoherenceTest.NewCodec do
  use Iconvex.Codec

  @config_key {__MODULE__, :config}

  def configure(table_id, canonical), do: :persistent_term.put(@config_key, {table_id, canonical})
  def clear, do: :persistent_term.erase(@config_key)

  @impl true
  def canonical_name, do: elem(:persistent_term.get(@config_key), 1)

  @impl true
  def codec_id, do: elem(:persistent_term.get(@config_key), 0)

  @impl true
  def decode(<<>>), do: {:ok, []}

  def decode(_input),
    do: {:ok, [Map.fetch!(Iconvex.Tables.fetch!(codec_id()), :new_codepoint)]}

  @impl true
  def decode_discard(input), do: decode(input)

  @impl true
  def encode(codepoints), do: {:ok, :erlang.list_to_binary(codepoints)}

  @impl true
  def encode_discard(codepoints), do: encode(codepoints)

  @impl true
  def encode_substitute(codepoints, _replacer), do: encode(codepoints)

  @impl true
  def decode_chunk(input, _final?) do
    case decode(input) do
      {:ok, codepoints} -> {:ok, codepoints, <<>>}
      error -> error
    end
  end
end

defmodule Iconvex.ProviderEntryCoherenceTest.BarrierCodec do
  use Iconvex.Codec

  @name "X-ICONVEX-PROVIDER-ENTRY-BARRIER"

  @impl true
  def canonical_name, do: @name

  @impl true
  def decode(input), do: {:ok, :binary.bin_to_list(input)}

  @impl true
  def decode_discard(input), do: decode(input)

  @impl true
  def encode(codepoints), do: {:ok, :erlang.list_to_binary(codepoints)}

  @impl true
  def encode_discard(codepoints), do: encode(codepoints)

  @impl true
  def encode_substitute(codepoints, _replacer), do: encode(codepoints)

  @impl true
  def encode_chunk(codepoints, _final?, _policy) do
    case encode(codepoints) do
      {:ok, output} -> {:ok, output, []}
      error -> error
    end
  end
end

defmodule Iconvex.ProviderEntryCoherenceTest.ChurnCodec do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-ICONVEX-ROUTE-CAPTURE-CHURN"

  @impl true
  def decode(input), do: {:ok, :binary.bin_to_list(input)}

  @impl true
  def decode_discard(input), do: decode(input)

  @impl true
  def encode(codepoints), do: {:ok, :erlang.list_to_binary(codepoints)}

  @impl true
  def encode_discard(codepoints), do: encode(codepoints)

  @impl true
  def encode_substitute(codepoints, _replacer), do: encode(codepoints)
end

defmodule Iconvex.ProviderEntryCoherenceTest do
  use ExUnit.Case, async: false

  alias Iconvex.ExternalRegistry
  alias Iconvex.ProviderEntryCoherenceTest.{BarrierCodec, ChurnCodec, NewCodec, OldCodec}

  @barrier_name "X-ICONVEX-PROVIDER-ENTRY-BARRIER"
  @old_app :iconvex_provider_entry_old
  @new_app :iconvex_provider_entry_new

  setup do
    cleanup_registrations()
    {:ok, barrier_token} = ExternalRegistry.register_owned(BarrierCodec)

    on_exit(fn ->
      cleanup_registrations()
      ExternalRegistry.unregister(BarrierCodec, barrier_token)
      OldCodec.clear()
      NewCodec.clear()
    end)

    :ok
  end

  test "converter construction never splices an old codec entry to a replacement provider" do
    for operation <- [:convert, :new, :stream] do
      table_id = unique_table_id(operation)
      canonical = "X-ICONVEX-PROVIDER-ENTRY-#{String.upcase(to_string(operation))}"
      on_exit(fn -> cleanup_provider(table_id) end)
      OldCodec.configure(table_id, canonical)
      NewCodec.configure(table_id, canonical)

      {old_codec_token, old_provider_token} = start_old_generation(table_id)
      parent = self()
      reference = make_ref()

      constructor =
        Task.async(fn ->
          Process.put({ExternalRegistry, :after_name_lookup}, {parent, reference})
          run_operation(operation)
        end)

      assert_receive {
                       :external_registry_name_read,
                       constructor_pid,
                       @barrier_name,
                       BarrierCodec,
                       ^reference
                     },
                     1_000

      stop_old_generation(table_id, old_codec_token, old_provider_token)
      {_new_codec_token, _new_provider_token} = start_new_generation(table_id)
      send(constructor_pid, {:continue_external_registry_name_read, reference})

      assert Task.await(constructor, 5_000) == {:error, :unknown_encoding},
             "#{operation} returned a converter that mixed the old codec with the new provider"

      stop_new_generation(table_id)
    end
  end

  test "route capture falls back after eight invalidated lock-free attempts" do
    parent = self()
    reference = make_ref()

    constructor =
      Task.async(fn ->
        Process.put({Iconvex, :after_route_capture}, {parent, reference, 8})
        Iconvex.new("UTF-8", "UTF-8")
      end)

    final_token =
      Enum.reduce(1..8, nil, fn attempt, token ->
        assert_receive {:iconvex_route_capture_read, constructor_pid, ^reference, ^attempt},
                       1_000

        next_token = toggle_churn_registration(token)
        send(constructor_pid, {:continue_iconvex_route_capture, reference})
        next_token
      end)

    if is_reference(final_token), do: ExternalRegistry.unregister(ChurnCodec, final_token)
    assert {:ok, %Iconvex.Converter{}} = Task.await(constructor, 5_000)
  end

  test "route updates invalidate captures before publishing provider state" do
    table_id = unique_table_id(:prepublish)
    app = :iconvex_provider_entry_prepublish
    parent = self()
    reference = make_ref()

    on_exit(fn -> Iconvex.Tables.unregister_provider(table_id, app) end)

    writer =
      Task.async(fn ->
        Process.put(
          {Iconvex.RouteSnapshot, :after_invalidate},
          {parent, reference}
        )

        Iconvex.Tables.register_provider_owned(table_id, app)
      end)

    assert_receive {:iconvex_route_update_invalid, writer_pid, ^reference}, 1_000

    reader = Task.async(fn -> Iconvex.new("UTF-8", "UTF-8") end)
    refute Task.yield(reader, 50)

    send(writer_pid, {:continue_iconvex_route_update, reference})
    assert {:ok, provider_token} = Task.await(writer, 5_000)
    assert {:ok, %Iconvex.Converter{}} = Task.await(reader, 5_000)
    assert :ok = Iconvex.Tables.unregister_provider(table_id, app, provider_token)

    assert_raise RuntimeError, "route update failure", fn ->
      Iconvex.RouteSnapshot.with_update(fn -> raise "route update failure" end)
    end

    generation = Iconvex.RouteSnapshot.generation()
    assert Iconvex.RouteSnapshot.generation_current?(generation)
    assert {:ok, %Iconvex.Converter{}} = Iconvex.new("UTF-8", "UTF-8")
  end

  test "a killed provider updater cannot strand route capture" do
    table_id = unique_table_id(:killed_provider)
    app = :iconvex_provider_entry_killed
    parent = self()
    reference = make_ref()

    writer =
      spawn(fn ->
        Process.put(
          {Iconvex.Tables, :after_provider_invalidate},
          {parent, reference}
        )

        Iconvex.Tables.register_provider_owned(table_id, app)
      end)

    writer_monitor = Process.monitor(writer)
    assert_receive {:iconvex_provider_update_invalid, ^writer, ^reference}, 1_000

    reader = Task.async(fn -> Iconvex.new("UTF-8", "UTF-8") end)
    refute Task.yield(reader, 50)

    Process.exit(writer, :kill)
    assert_receive {:DOWN, ^writer_monitor, :process, ^writer, :killed}, 1_000

    result = Task.yield(reader, 1_000)
    if result == nil, do: Task.shutdown(reader, :brutal_kill)
    assert {:ok, {:ok, %Iconvex.Converter{}}} = result
  end

  test "abandoned repair keeps the old generation invalid until active is closed" do
    table_id = unique_table_id(:abandoned_close)
    app = :iconvex_provider_entry_abandoned_close
    parent = self()
    writer_reference = make_ref()
    repair_reference = make_ref()
    stale_generation = Iconvex.RouteSnapshot.generation()

    writer =
      spawn(fn ->
        Process.put(
          {Iconvex.Tables, :after_provider_invalidate},
          {parent, writer_reference}
        )

        Iconvex.Tables.register_provider_owned(table_id, app)
      end)

    writer_monitor = Process.monitor(writer)
    assert_receive {:iconvex_provider_update_invalid, ^writer, ^writer_reference}, 1_000
    Process.exit(writer, :kill)
    assert_receive {:DOWN, ^writer_monitor, :process, ^writer, :killed}, 1_000

    repairer =
      Task.async(fn ->
        Process.put(
          {Iconvex.RouteSnapshot, :abandoned_close_barrier},
          {parent, repair_reference}
        )

        Iconvex.RouteSnapshot.serialized(fn -> :ok end)
      end)

    assert_receive {:iconvex_abandoned_route_close_barrier, repairer_pid, ^repair_reference},
                   1_000

    stale_generation_current? =
      Iconvex.RouteSnapshot.generation_current?(stale_generation)

    send(repairer_pid, {:continue_iconvex_abandoned_route_close, repair_reference})
    assert :ok = Task.await(repairer, 5_000)
    refute stale_generation_current?
  end

  test "Heir-owned lookup without a registry PID still honors the route epoch" do
    table_id = unique_table_id(:heir_lookup)
    app = :iconvex_provider_entry_heir_lookup
    parent = self()
    reference = make_ref()
    registry = Process.whereis(ExternalRegistry)
    {:links, [registry_supervisor]} = Process.info(registry, :links)
    registry_monitor = Process.monitor(registry)

    on_exit(fn ->
      Iconvex.Tables.unregister_provider(table_id, app)
      if Process.alive?(registry_supervisor), do: :sys.resume(registry_supervisor)
      wait_for_registry_restart(registry)
      restart_iconvex_application()
    end)

    :ok = :sys.suspend(registry_supervisor)
    Process.exit(registry, :kill)
    assert_receive {:DOWN, ^registry_monitor, :process, ^registry, :killed}, 1_000
    assert Process.whereis(ExternalRegistry) == nil

    writer =
      Task.async(fn ->
        Process.put({Iconvex.RouteSnapshot, :after_invalidate}, {parent, reference})
        Iconvex.Tables.register_provider_owned(table_id, app)
      end)

    assert_receive {:iconvex_route_update_invalid, writer_pid, ^reference}, 1_000
    reader = Task.async(fn -> ExternalRegistry.resolve(BarrierCodec) end)
    early_result = Task.yield(reader, 50)

    send(writer_pid, {:continue_iconvex_route_update, reference})
    assert {:ok, provider_token} = Task.await(writer, 5_000)

    reader_result = early_result || Task.yield(reader, 5_000)
    assert :ok = Iconvex.Tables.unregister_provider(table_id, app, provider_token)
    refute early_result
    assert {:ok, {:ok, %{codec: BarrierCodec}}} = reader_result
  end

  test "serialized lookup releases the route lock while registry init becomes ready" do
    parent = self()
    reference = make_ref()
    registry = Process.whereis(ExternalRegistry)
    registry_monitor = Process.monitor(registry)
    on_exit(&restart_iconvex_application/0)

    holder =
      Task.async(fn ->
        Iconvex.RouteSnapshot.serialized(fn ->
          send(parent, {:iconvex_serialized_route_held, self(), reference})

          receive do
            {:resolve_during_registry_init, ^reference} ->
              ExternalRegistry.resolve(BarrierCodec)
          end
        end)
      end)

    assert_receive {:iconvex_serialized_route_held, holder_pid, ^reference}, 1_000
    Process.exit(registry, :kill)
    assert_receive {:DOWN, ^registry_monitor, :process, ^registry, :killed}, 1_000

    replacement = wait_for_registry_restart(registry)
    wait_for_table_owner(replacement)
    send(holder_pid, {:resolve_during_registry_init, reference})

    holder_result = Task.yield(holder, 250)
    if holder_result == nil, do: Task.shutdown(holder, :brutal_kill)

    assert {:ok, :route_retry} = holder_result
    assert {:ok, %{codec: BarrierCodec}} = ExternalRegistry.resolve(BarrierCodec)
  end

  test "public construction releases fallback lock and recaptures repaired registry state" do
    parent = self()
    capture_reference = make_ref()
    serialized_reference = make_ref()
    provider_id = unique_table_id(:fallback_restart)
    provider_app = :iconvex_provider_entry_fallback_restart
    registry = Process.whereis(ExternalRegistry)
    registry_monitor = Process.monitor(registry)
    {:ok, pending_token} = ExternalRegistry.register_owned(ChurnCodec)

    on_exit(fn ->
      Iconvex.Tables.unregister_provider(provider_id, provider_app)
      restart_iconvex_application()
    end)

    :sys.replace_state(registry, fn state ->
      true =
        :ets.insert(
          ExternalRegistry,
          {{:set, pending_token},
           %{status: :pending, modules: [ChurnCodec], owner: :pending_test, priority: 0}}
        )

      state
    end)

    constructor =
      Task.async(fn ->
        Process.put({Iconvex, :after_route_capture}, {parent, capture_reference, 8})

        Process.put(
          {Iconvex, :before_serialized_route_resolve},
          {parent, serialized_reference}
        )

        Iconvex.new(ChurnCodec, "UTF-8")
      end)

    final_provider_token =
      Enum.reduce(1..8, nil, fn attempt, provider_token ->
        assert_receive {
                         :iconvex_route_capture_read,
                         constructor_pid,
                         ^capture_reference,
                         ^attempt
                       },
                       1_000

        next_token =
          toggle_provider_registration(provider_id, provider_app, provider_token)

        send(constructor_pid, {:continue_iconvex_route_capture, capture_reference})
        next_token
      end)

    assert final_provider_token == nil

    assert_receive {
                     :iconvex_serialized_route_resolve,
                     constructor_pid,
                     ^serialized_reference
                   },
                   1_000

    Process.exit(registry, :kill)
    assert_receive {:DOWN, ^registry_monitor, :process, ^registry, :killed}, 1_000
    replacement = wait_for_registry_restart(registry)
    wait_for_table_owner(replacement)

    send(constructor_pid, {:continue_iconvex_serialized_route_resolve, serialized_reference})

    assert {:error, :unknown_encoding} = Task.await(constructor, 5_000)
    assert ExternalRegistry.resolve(ChurnCodec) == :error
    assert :ets.lookup(ExternalRegistry, {:set, pending_token}) == []
  end

  defp run_operation(:convert), do: Iconvex.convert("input", OldCodec, @barrier_name)

  defp run_operation(:new) do
    with {:ok, converter} <- Iconvex.new(OldCodec, @barrier_name),
         {:ok, <<>>, converter} <- Iconvex.feed(converter, "input") do
      Iconvex.finish(converter)
    end
  end

  defp run_operation(:stream) do
    case Iconvex.stream(["input"], OldCodec, @barrier_name) do
      {:ok, stream} -> {:ok, stream |> Enum.to_list() |> IO.iodata_to_binary()}
      error -> error
    end
  end

  defp start_old_generation(table_id) do
    {:ok, provider_token} = Iconvex.Tables.register_provider_owned(table_id, @old_app)
    publish_table(@old_app, table_id, %{old_codepoint: ?A, new_codepoint: ?X})
    {:ok, codec_token} = ExternalRegistry.register_owned(OldCodec)
    {codec_token, provider_token}
  end

  defp stop_old_generation(table_id, codec_token, provider_token) do
    :ok = ExternalRegistry.unregister(OldCodec, codec_token)
    :ok = Iconvex.Tables.unregister_provider(table_id, @old_app, provider_token)
  end

  defp start_new_generation(table_id) do
    {:ok, provider_token} = Iconvex.Tables.register_provider_owned(table_id, @new_app)
    publish_table(@new_app, table_id, %{old_codepoint: ?X, new_codepoint: ?B})
    {:ok, codec_token} = ExternalRegistry.register_owned(NewCodec)
    {codec_token, provider_token}
  end

  defp stop_new_generation(table_id) do
    ExternalRegistry.unregister(NewCodec)
    Iconvex.Tables.unregister_provider(table_id, @new_app)
  end

  defp publish_table(app, table_id, table) do
    key = {{Iconvex.Tables, :table}, app, table_id}
    :persistent_term.put(key, {1, {1, ~c"unloaded"}, make_ref(), table})
  end

  defp toggle_churn_registration(nil) do
    {:ok, token} = ExternalRegistry.register_owned(ChurnCodec)
    token
  end

  defp toggle_churn_registration(token) when is_reference(token) do
    :ok = ExternalRegistry.unregister(ChurnCodec, token)
    nil
  end

  defp toggle_provider_registration(table_id, app, nil) do
    {:ok, token} = Iconvex.Tables.register_provider_owned(table_id, app)
    token
  end

  defp toggle_provider_registration(table_id, app, token) when is_reference(token) do
    :ok = Iconvex.Tables.unregister_provider(table_id, app, token)
    nil
  end

  defp cleanup_registrations do
    Enum.each([OldCodec, NewCodec, BarrierCodec, ChurnCodec], &ExternalRegistry.unregister/1)
  end

  defp cleanup_provider(table_id) do
    Iconvex.Tables.unregister_provider(table_id, @old_app)
    Iconvex.Tables.unregister_provider(table_id, @new_app)
    :persistent_term.erase({{Iconvex.Tables, :table}, @old_app, table_id})
    :persistent_term.erase({{Iconvex.Tables, :table}, @new_app, table_id})
  end

  defp unique_table_id(operation) do
    String.to_atom("iconvex_provider_entry_#{operation}_#{System.unique_integer([:positive])}")
  end

  defp wait_for_registry_restart(previous, attempts \\ 1_000)
  defp wait_for_registry_restart(_previous, 0), do: flunk("external registry did not restart")

  defp wait_for_registry_restart(previous, attempts) do
    case Process.whereis(ExternalRegistry) do
      registry when is_pid(registry) and registry != previous ->
        registry

      _missing_or_previous ->
        Process.sleep(1)
        wait_for_registry_restart(previous, attempts - 1)
    end
  end

  defp wait_for_table_owner(expected, attempts \\ 1_000)
  defp wait_for_table_owner(_expected, 0), do: flunk("registry did not reclaim its table")

  defp wait_for_table_owner(expected, attempts) do
    if :ets.info(ExternalRegistry, :owner) == expected do
      :ok
    else
      Process.sleep(1)
      wait_for_table_owner(expected, attempts - 1)
    end
  end

  defp restart_iconvex_application do
    Application.stop(:iconvex)
    {:ok, _started} = Application.ensure_all_started(:iconvex)
    :ok
  end
end

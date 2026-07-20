defmodule Iconvex.PackageClaimRegistryTest.CodecA do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-PACKAGE-CODEC-A"

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

defmodule Iconvex.PackageClaimRegistryTest.CodecB do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-PACKAGE-CODEC-B"

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

defmodule Iconvex.PackageClaimRegistryTest.StrictCodec do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-STRICT-PACKAGE-CONFLICT"

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

defmodule Iconvex.PackageClaimRegistryTest do
  use ExUnit.Case, async: false

  alias Iconvex.ExternalRegistry
  alias Iconvex.PackageClaimRegistryTest.{CodecA, CodecB, StrictCodec}

  @codec_a [
    {CodecA, canonical: "X-CLAIM-PRIMARY", aliases: ["X-CLAIM-SHARED", "X-CLAIM-LOW-ONLY"]}
  ]
  @codec_b [
    {CodecB,
     canonical: "X-CLAIM-HIGH",
     aliases: ["X-CLAIM-PRIMARY", "X-CLAIM-SHARED", "X-CLAIM-HIGH-ONLY"]}
  ]

  setup do
    Enum.each([CodecA, CodecB, StrictCodec], &ExternalRegistry.unregister/1)

    on_exit(fn ->
      Enum.each([CodecA, CodecB, StrictCodec], &ExternalRegistry.unregister/1)
    end)

    :ok
  end

  test "managed package claims elect canonical before alias and priority within a kind" do
    assert {:ok, low_token} =
             ExternalRegistry.register_set_owned(@codec_a, owner: :low_package, priority: 10)

    assert {:ok, high_token} =
             ExternalRegistry.register_set_owned(@codec_b, owner: :high_package, priority: 20)

    assert_resolves("X-CLAIM-PRIMARY", CodecA)
    assert_resolves("X-CLAIM-SHARED", CodecB)
    assert_resolves("X-CLAIM-LOW-ONLY", CodecA)
    assert_resolves("X-CLAIM-HIGH-ONLY", CodecB)
    assert_resolves(CodecA, CodecA)
    assert_resolves(CodecB, CodecB)

    assert :ok = ExternalRegistry.unregister_set(make_ref())
    assert_resolves("X-CLAIM-SHARED", CodecB)

    assert :ok = ExternalRegistry.unregister_set(high_token)
    assert_resolves("X-CLAIM-PRIMARY", CodecA)
    assert_resolves("X-CLAIM-SHARED", CodecA)
    assert ExternalRegistry.resolve("X-CLAIM-HIGH-ONLY") == :error

    assert :ok = ExternalRegistry.unregister_set(low_token)
    assert ExternalRegistry.resolve("X-CLAIM-PRIMARY") == :error
    assert ExternalRegistry.resolve("X-CLAIM-SHARED") == :error
  end

  test "managed winner snapshot is independent of registration order" do
    first = register_and_snapshot([{@codec_a, :low_package, 10}, {@codec_b, :high_package, 20}])
    second = register_and_snapshot([{@codec_b, :high_package, 20}, {@codec_a, :low_package, 10}])

    assert first == second
    assert first == %{primary: CodecA, shared: CodecB}
  end

  test "managed set validation returns every typed registration-set reason exactly" do
    cases = [
      {@codec_a, :not_a_keyword_list, :options_must_be_a_keyword_list},
      {@codec_a, [owner: :package, priority: 10, unsupported: true], :unknown_options},
      {@codec_a, [owner: "package", priority: 10], :owner_must_be_an_atom},
      {@codec_a, [owner: :package, priority: 10.0], :priority_must_be_an_integer},
      {:not_a_registration_list, [owner: :package, priority: 10], :registrations_must_be_a_list},
      {[{CodecA, :not_codec_options}], [owner: :package, priority: 10], :invalid_registration},
      {[CodecA, {CodecA, []}], [owner: :package, priority: 10], :duplicate_module}
    ]

    Enum.each(cases, fn {registrations, options, reason} ->
      assert ExternalRegistry.register_set_owned(registrations, options) ==
               {:error, {:invalid_registration_set, reason}}
    end)

    assert ExternalRegistry.resolve(CodecA) == :error
  end

  test "equal-rank ambiguity rejects the later package without disturbing the winner" do
    assert {:ok, low_token} =
             ExternalRegistry.register_set_owned(@codec_a, owner: :low_package, priority: 10)

    assert {:error, {:ambiguous_name_conflict, "X-CLAIM-SHARED", claims}} =
             ExternalRegistry.register_set_owned(@codec_b, owner: :peer_package, priority: 10)

    assert Enum.sort(claims) == Enum.sort([CodecA, CodecB])
    assert_resolves("X-CLAIM-SHARED", CodecA)
    assert ExternalRegistry.resolve(CodecB) == :error
    assert :ok = ExternalRegistry.unregister_set(low_token)
  end

  test "strict caller registrations conflict with hidden managed claims" do
    assert {:ok, low_token} =
             ExternalRegistry.register_set_owned(@codec_a, owner: :low_package, priority: 10)

    assert {:ok, high_token} =
             ExternalRegistry.register_set_owned(@codec_b, owner: :high_package, priority: 20)

    assert {:error, {:name_conflict, "X-CLAIM-SHARED"}} =
             ExternalRegistry.register_owned(StrictCodec,
               aliases: ["X-CLAIM-SHARED"]
             )

    assert :ok = ExternalRegistry.unregister_set(high_token)
    assert_resolves("X-CLAIM-SHARED", CodecA)
    assert :ok = ExternalRegistry.unregister_set(low_token)
  end

  test "a strict late conflict rejects a whole managed set without partial registration" do
    assert {:ok, strict_token} =
             ExternalRegistry.register_owned(StrictCodec,
               aliases: ["X-CLAIM-HIGH-ONLY"]
             )

    registrations = @codec_a ++ @codec_b

    assert {:error, {:name_conflict, "X-CLAIM-HIGH-ONLY"}} =
             ExternalRegistry.register_set_owned(registrations,
               owner: :managed_package,
               priority: 10
             )

    assert ExternalRegistry.resolve(CodecA) == :error
    assert ExternalRegistry.resolve(CodecB) == :error
    assert_resolves("X-CLAIM-HIGH-ONLY", StrictCodec)
    assert :ok = ExternalRegistry.unregister(StrictCodec, strict_token)
  end

  test "a pre-existing module is skipped and survives managed set shutdown" do
    assert {:ok, strict_token} =
             ExternalRegistry.register_owned(CodecA, canonical: "X-PREEXISTING-CODEC-A")

    assert {:ok, set_token} =
             ExternalRegistry.register_set_owned(@codec_a,
               owner: :managed_package,
               priority: 10
             )

    assert_resolves("X-PREEXISTING-CODEC-A", CodecA)
    assert ExternalRegistry.resolve("X-CLAIM-PRIMARY") == :error

    assert :ok = ExternalRegistry.unregister_set(set_token)
    assert_resolves("X-PREEXISTING-CODEC-A", CodecA)
    assert :ok = ExternalRegistry.unregister(CodecA, strict_token)
  end

  test "same-owner restart adopts its committed managed set after losing the token" do
    assert {:ok, lost_token} =
             ExternalRegistry.register_set_owned(@codec_a,
               owner: :managed_package,
               priority: 10
             )

    on_exit(fn -> ExternalRegistry.unregister_set(lost_token) end)

    assert {:ok, adopted_token} =
             ExternalRegistry.register_set_owned(@codec_a,
               owner: :managed_package,
               priority: 10
             )

    on_exit(fn -> ExternalRegistry.unregister_set(adopted_token) end)

    assert adopted_token == lost_token
    assert_resolves("X-CLAIM-PRIMARY", CodecA)

    assert :ok = ExternalRegistry.unregister_set(adopted_token)
    assert ExternalRegistry.resolve(CodecA) == :error
    assert ExternalRegistry.resolve("X-CLAIM-PRIMARY") == :error
    assert :ets.lookup(ExternalRegistry, {:set, lost_token}) == []
  end

  test "same-owner restart rejects partial or metadata-changed managed sets" do
    original = [
      {CodecA, canonical: "X-RESTART-EXACT-A"},
      {CodecB, canonical: "X-RESTART-EXACT-B"}
    ]

    assert {:ok, lost_token} =
             ExternalRegistry.register_set_owned(original,
               owner: :managed_package,
               priority: 10
             )

    on_exit(fn -> ExternalRegistry.unregister_set(lost_token) end)

    assert ExternalRegistry.register_set_owned(
             [{CodecA, canonical: "X-RESTART-EXACT-A"}],
             owner: :managed_package,
             priority: 10
           ) == {:error, {:managed_registration_conflict, CodecA}}

    assert ExternalRegistry.register_set_owned(
             [
               {CodecA, canonical: "X-RESTART-CHANGED-A"},
               {CodecB, canonical: "X-RESTART-EXACT-B"}
             ],
             owner: :managed_package,
             priority: 10
           ) == {:error, {:managed_registration_conflict, CodecA}}

    assert_resolves("X-RESTART-EXACT-A", CodecA)
    assert_resolves("X-RESTART-EXACT-B", CodecB)
    assert ExternalRegistry.resolve("X-RESTART-CHANGED-A") == :error
    assert :ets.lookup(ExternalRegistry, {:set, lost_token}) != []

    assert :ok = ExternalRegistry.unregister_set(lost_token)
    assert ExternalRegistry.resolve(CodecA) == :error
    assert ExternalRegistry.resolve(CodecB) == :error
  end

  test "caller replacement detaches a managed module and survives set shutdown" do
    assert {:ok, set_token} =
             ExternalRegistry.register_set_owned(@codec_a,
               owner: :managed_package,
               priority: 10
             )

    assert {:ok, caller_token} =
             ExternalRegistry.register_owned(CodecA, canonical: "X-CALLER-REPLACEMENT")

    assert_resolves("X-CALLER-REPLACEMENT", CodecA)
    assert ExternalRegistry.resolve("X-CLAIM-PRIMARY") == :error

    assert :ok = ExternalRegistry.unregister_set(set_token)
    assert_resolves("X-CALLER-REPLACEMENT", CodecA)
    assert :ok = ExternalRegistry.unregister(CodecA, caller_token)
  end

  test "managed claims and tokens survive restart and Heir removal exposes fallback" do
    on_exit(&restart_iconvex_application/0)

    assert {:ok, low_token} =
             ExternalRegistry.register_set_owned(@codec_a, owner: :low_package, priority: 10)

    assert {:ok, high_token} =
             ExternalRegistry.register_set_owned(@codec_b, owner: :high_package, priority: 20)

    old_registry = Process.whereis(ExternalRegistry)
    {:links, [registry_supervisor]} = Process.info(old_registry, :links)
    monitor = Process.monitor(old_registry)
    :ok = :sys.suspend(registry_supervisor)

    try do
      Process.exit(old_registry, :kill)
      assert_receive {:DOWN, ^monitor, :process, ^old_registry, :killed}, 1_000

      assert :ets.info(ExternalRegistry, :owner) ==
               Process.whereis(Iconvex.ExternalRegistry.Heir)

      assert :ok = ExternalRegistry.unregister_set(high_token)
      assert_resolves("X-CLAIM-PRIMARY", CodecA)
      assert_resolves("X-CLAIM-SHARED", CodecA)
    after
      :ok = :sys.resume(registry_supervisor)
    end

    assert is_pid(wait_for_registry_restart(old_registry))
    assert_resolves("X-CLAIM-SHARED", CodecA)
    assert ExternalRegistry.resolve(CodecB) == :error
    assert :ok = ExternalRegistry.unregister_set(low_token)
  end

  test "managed package sets survive the heir replacement crash window" do
    on_exit(&restart_iconvex_application/0)

    assert {:ok, low_token} =
             ExternalRegistry.register_set_owned(@codec_a, owner: :low_package, priority: 10)

    assert {:ok, high_token} =
             ExternalRegistry.register_set_owned(@codec_b, owner: :high_package, priority: 20)

    registry = Process.whereis(ExternalRegistry)
    registry_monitor = Process.monitor(registry)
    old_heir = Process.whereis(Iconvex.ExternalRegistry.Heir)
    heir_monitor = Process.monitor(old_heir)

    :ok = :sys.suspend(registry)
    Process.exit(old_heir, :kill)
    assert_receive {:DOWN, ^heir_monitor, :process, ^old_heir, :killed}, 1_000
    assert is_pid(wait_for_heir_restart(old_heir))
    assert :ets.info(ExternalRegistry, :heir) == old_heir

    Process.exit(registry, :kill)
    assert_receive {:DOWN, ^registry_monitor, :process, ^registry, :killed}, 1_000

    replacement_registry = wait_for_registry_restart(registry)
    assert is_pid(replacement_registry)
    assert %{} = :sys.get_state(replacement_registry)
    assert_resolves("X-CLAIM-PRIMARY", CodecA)
    assert_resolves("X-CLAIM-SHARED", CodecB)

    assert :ok = ExternalRegistry.unregister_set(high_token)
    assert_resolves("X-CLAIM-SHARED", CodecA)
    assert :ok = ExternalRegistry.unregister_set(low_token)
  end

  test "restart rolls back a legacy inherited pending registration set" do
    on_exit(&restart_iconvex_application/0)

    assert {:ok, committed_token} =
             ExternalRegistry.register_set_owned(@codec_a,
               owner: :legacy_package,
               priority: 10
             )

    registry = Process.whereis(ExternalRegistry)
    pending_token = make_ref()

    :sys.replace_state(registry, fn state ->
      [{{:module, CodecA}, entry}] = :ets.lookup(ExternalRegistry, {:module, CodecA})

      pending_entry = %{
        entry
        | registration_token: pending_token,
          registration_mode: {:managed, :legacy_package, 10}
      }

      :ets.delete(ExternalRegistry, {:set, committed_token})
      :ets.insert(ExternalRegistry, {{:module, CodecA}, pending_entry})

      :ets.insert(
        ExternalRegistry,
        {{:set, pending_token},
         %{status: :pending, owner: :legacy_package, priority: 10, modules: [CodecA]}}
      )

      state
    end)

    monitor = Process.monitor(registry)
    Process.exit(registry, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^registry, :killed}, 1_000

    replacement = wait_for_registry_restart(registry)
    assert is_pid(replacement)
    assert %{} = :sys.get_state(replacement)
    assert ExternalRegistry.resolve(CodecA) == :error
    assert :ets.lookup(ExternalRegistry, {:set, pending_token}) == []
  end

  test "managed set removal keeps every fallback name continuously resolvable" do
    assert {:ok, low_token} =
             ExternalRegistry.register_set_owned(@codec_a, owner: :low_package, priority: 10)

    bulk_aliases = ["X-CLAIM-SHARED" | Enum.map(1..2_000, &"X-BULK-CLAIM-#{&1}")]

    assert {:ok, high_token} =
             ExternalRegistry.register_set_owned(
               [{CodecB, canonical: "X-CLAIM-HIGH", aliases: bulk_aliases}],
               owner: :high_package,
               priority: 20
             )

    control = :atomics.new(2, [])
    parent = self()

    readers =
      for _ <- 1..2 do
        Task.async(fn ->
          send(parent, {:reader_ready, self()})
          count_resolution_gaps(control, "X-CLAIM-SHARED")
        end)
      end

    Enum.each(readers, fn _reader -> assert_receive {:reader_ready, _pid}, 1_000 end)

    assert :ok = ExternalRegistry.unregister_set(high_token)
    :atomics.put(control, 1, 1)
    Enum.each(readers, &Task.await(&1, 5_000))

    assert :atomics.get(control, 2) == 0
    assert_resolves("X-CLAIM-SHARED", CodecA)
    assert :ok = ExternalRegistry.unregister_set(low_token)
  end

  test "a reader paused on the removed winner retries the atomic fallback" do
    assert {:ok, low_token} =
             ExternalRegistry.register_set_owned(@codec_a, owner: :low_package, priority: 10)

    assert {:ok, high_token} =
             ExternalRegistry.register_set_owned(@codec_b, owner: :high_package, priority: 20)

    parent = self()
    reference = make_ref()

    reader =
      Task.async(fn ->
        Process.put({ExternalRegistry, :after_name_lookup}, {parent, reference})
        ExternalRegistry.resolve("X-CLAIM-SHARED")
      end)

    assert_receive {
                     :external_registry_name_read,
                     reader_pid,
                     "X-CLAIM-SHARED",
                     CodecB,
                     ^reference
                   },
                   1_000

    assert :ok = ExternalRegistry.unregister_set(high_token)
    send(reader_pid, {:continue_external_registry_name_read, reference})

    assert {:ok, %{codec: CodecA}} = Task.await(reader, 1_000)
    assert :ok = ExternalRegistry.unregister_set(low_token)
  end

  test "registry repair never exposes an empty managed-name index" do
    on_exit(&restart_iconvex_application/0)
    aliases = Enum.map(1..2_000, &"X-REPAIR-CLAIM-#{&1}")

    assert {:ok, token} =
             ExternalRegistry.register_set_owned(
               [{CodecA, canonical: "X-REPAIR-CANONICAL", aliases: aliases}],
               owner: :repair_package,
               priority: 10
             )

    control = :atomics.new(2, [])
    parent = self()

    reader =
      Task.async(fn ->
        send(parent, {:reader_ready, self()})
        count_resolution_gaps(control, "X-REPAIR-CLAIM-1000")
      end)

    assert_receive {:reader_ready, _pid}, 1_000
    old_registry = Process.whereis(ExternalRegistry)
    monitor = Process.monitor(old_registry)
    Process.exit(old_registry, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^old_registry, :killed}, 1_000
    assert is_pid(wait_for_registry_restart(old_registry))
    :atomics.put(control, 1, 1)
    Task.await(reader, 5_000)

    assert :atomics.get(control, 2) == 0
    assert_resolves("X-REPAIR-CLAIM-1000", CodecA)
    assert :ok = ExternalRegistry.unregister_set(token)
  end

  test "managed set registration adopts an atomic commit whose reply was lost" do
    on_exit(&restart_iconvex_application/0)
    registry = Process.whereis(ExternalRegistry)
    {:links, [registry_supervisor]} = Process.info(registry, :links)
    monitor = Process.monitor(registry)
    hook_reference = make_ref()
    parent = self()

    :sys.replace_state(registry, fn state ->
      Map.put(state, :after_commit, {parent, hook_reference})
    end)

    :ok = :sys.suspend(registry_supervisor)

    try do
      spawn(fn ->
        result =
          ExternalRegistry.register_set_owned(@codec_a,
            owner: :managed_package,
            priority: 10
          )

        send(parent, {:managed_set_registration_result, result})
      end)

      assert_receive {
                       :external_registry_committed,
                       ^registry,
                       {:set, committed_token},
                       ^hook_reference
                     },
                     1_000

      Process.exit(registry, :kill)
      assert_receive {:DOWN, ^monitor, :process, ^registry, :killed}, 1_000
      :ok = :sys.resume(registry_supervisor)

      assert_receive {:managed_set_registration_result, {:ok, ^committed_token}}, 2_000
      assert_resolves("X-CLAIM-PRIMARY", CodecA)
      assert :ok = ExternalRegistry.unregister_set(committed_token)
    after
      if Process.alive?(registry_supervisor), do: :sys.resume(registry_supervisor)
    end
  end

  test "managed set registration and removal scan claims a constant number of times" do
    aliases = Enum.map(1..512, &"X-LINEAR-CLAIM-#{&1}")
    registry = Process.whereis(ExternalRegistry)

    try do
      assert 1 ==
               :erlang.trace_pattern(
                 {:ets, :match, 2},
                 true,
                 []
               )

      assert 1 == :erlang.trace_pattern({Enum, :filter, 2}, true, [])
      assert 1 == :erlang.trace(registry, true, [:call, {:tracer, self()}])

      assert {:ok, token} =
               ExternalRegistry.register_set_owned(
                 [{CodecA, canonical: "X-LINEAR-CANONICAL", aliases: aliases}],
                 owner: :linear_package,
                 priority: 10
               )

      assert 1 == :erlang.trace(registry, false, [:call])
      %{claim_scans: claim_scans, candidate_filters: candidate_filters} = collect_trace_counts()

      assert claim_scans <= 1
      assert candidate_filters <= 8

      assert 1 == :erlang.trace(registry, true, [:call, {:tracer, self()}])
      assert :ok = ExternalRegistry.unregister_set(token)
      assert 1 == :erlang.trace(registry, false, [:call])

      %{claim_scans: removal_claim_scans, candidate_filters: removal_filters} =
        collect_trace_counts()

      assert removal_claim_scans <= 1
      assert removal_filters <= 8
    after
      :erlang.trace(registry, false, [:call])
      :erlang.trace_pattern({:ets, :match, 2}, false, [])
      :erlang.trace_pattern({Enum, :filter, 2}, false, [])
    end
  end

  defp register_and_snapshot(specifications) do
    tokens =
      Enum.map(specifications, fn {registrations, owner, priority} ->
        assert {:ok, token} =
                 ExternalRegistry.register_set_owned(registrations,
                   owner: owner,
                   priority: priority
                 )

        token
      end)

    snapshot = %{
      primary: resolved_codec("X-CLAIM-PRIMARY"),
      shared: resolved_codec("X-CLAIM-SHARED")
    }

    Enum.each(Enum.reverse(tokens), &ExternalRegistry.unregister_set/1)
    snapshot
  end

  defp collect_trace_counts(counts \\ %{claim_scans: 0, candidate_filters: 0}) do
    receive do
      {:trace, _pid, :call, {:ets, :match, [_table, _pattern]}} ->
        collect_trace_counts(%{counts | claim_scans: counts.claim_scans + 1})

      {:trace, _pid, :call, {Enum, :filter, [_enumerable, _function]}} ->
        collect_trace_counts(%{counts | candidate_filters: counts.candidate_filters + 1})

      {:trace, _pid, :call, _other} ->
        collect_trace_counts(counts)
    after
      0 -> counts
    end
  end

  defp assert_resolves(name, codec) do
    assert {:ok, %{codec: ^codec}} = ExternalRegistry.resolve(name)
  end

  defp resolved_codec(name) do
    assert {:ok, %{codec: codec}} = ExternalRegistry.resolve(name)
    codec
  end

  defp wait_for_registry_restart(old_registry, attempts \\ 1_000)
  defp wait_for_registry_restart(_old_registry, 0), do: nil

  defp wait_for_registry_restart(old_registry, attempts) do
    case Process.whereis(ExternalRegistry) do
      registry when is_pid(registry) and registry != old_registry ->
        registry

      _missing_or_same ->
        Process.sleep(1)
        wait_for_registry_restart(old_registry, attempts - 1)
    end
  end

  defp wait_for_heir_restart(old_heir, attempts \\ 1_000)
  defp wait_for_heir_restart(_old_heir, 0), do: nil

  defp wait_for_heir_restart(old_heir, attempts) do
    case Process.whereis(Iconvex.ExternalRegistry.Heir) do
      heir when is_pid(heir) and heir != old_heir ->
        heir

      _missing_or_same ->
        Process.sleep(1)
        wait_for_heir_restart(old_heir, attempts - 1)
    end
  end

  defp restart_iconvex_application do
    Application.stop(:iconvex)
    {:ok, _started} = Application.ensure_all_started(:iconvex)
    :ok
  end

  defp count_resolution_gaps(control, name) do
    if :atomics.get(control, 1) == 0 do
      if ExternalRegistry.resolve(name) == :error, do: :atomics.add(control, 2, 1)
      Process.sleep(0)
      count_resolution_gaps(control, name)
    end
  end
end

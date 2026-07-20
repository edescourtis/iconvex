defmodule Iconvex.CoverageCodecCallbacks do
  @moduledoc false

  defmacro __using__(_options) do
    quote do
      use Iconvex.Codec

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
  end
end

defmodule Iconvex.CoverageCodec do
  @moduledoc false
  use Iconvex.CoverageCodecCallbacks

  @impl true
  def canonical_name, do: "X-COVERAGE-CODEC"

  @impl true
  def aliases, do: ["X-COVERAGE-ALIAS"]

  @impl true
  def stateful?, do: true

  @impl true
  def codec_id, do: :coverage_codec

  @impl true
  def decode_error_recovery, do: :stop
end

defmodule Iconvex.CoverageBadStatefulCodec do
  @moduledoc false
  use Iconvex.CoverageCodecCallbacks

  @impl true
  def canonical_name, do: "X-COVERAGE-BAD-STATEFUL"

  @impl true
  def stateful?, do: :yes
end

defmodule Iconvex.CoverageBadIdCodec do
  @moduledoc false
  use Iconvex.CoverageCodecCallbacks

  @impl true
  def canonical_name, do: "X-COVERAGE-BAD-ID"

  @impl true
  def codec_id, do: "not-an-atom"
end

defmodule Iconvex.CoverageBadAliasesCodec do
  @moduledoc false
  use Iconvex.CoverageCodecCallbacks

  @impl true
  def canonical_name, do: "X-COVERAGE-BAD-ALIASES"

  @impl true
  def aliases, do: :not_a_list
end

defmodule Iconvex.CoverageBadNameCodec do
  @moduledoc false
  use Iconvex.CoverageCodecCallbacks

  @impl true
  def canonical_name, do: :not_a_binary
end

defmodule Iconvex.CoverageRaisingMetadataCodec do
  @moduledoc false
  use Iconvex.CoverageCodecCallbacks

  @impl true
  def canonical_name, do: raise("metadata boom")
end

defmodule Iconvex.CoverageThrowingMetadataCodec do
  @moduledoc false
  use Iconvex.CoverageCodecCallbacks

  @impl true
  def canonical_name, do: throw(:metadata_boom)
end

defmodule Iconvex.CoverageMissingCallbacksCodec do
  @moduledoc false
  def canonical_name, do: "X-COVERAGE-MISSING-CALLBACKS"
end

defmodule Iconvex.StatefulUTF7RegistryCoverageTest do
  use ExUnit.Case, async: false

  alias Iconvex.{ExternalRegistry, StatefulCodec, UTF7Codec}

  @coverage_codecs [
    Iconvex.CoverageCodec,
    Iconvex.CoverageBadStatefulCodec,
    Iconvex.CoverageBadIdCodec,
    Iconvex.CoverageBadAliasesCodec,
    Iconvex.CoverageBadNameCodec,
    Iconvex.CoverageRaisingMetadataCodec,
    Iconvex.CoverageThrowingMetadataCodec,
    Iconvex.CoverageMissingCallbacksCodec
  ]

  setup do
    Enum.each(@coverage_codecs, &ExternalRegistry.unregister/1)
    on_exit(fn -> Enum.each(@coverage_codecs, &ExternalRegistry.unregister/1) end)
    :ok
  end

  test "UTF-7 incremental decoder handles direct, shifted, surrogate, and final states" do
    initial = UTF7Codec.stream_init()

    assert {:ok, ~c"+", %{mode: :direct}, <<>>} =
             UTF7Codec.decode_chunk("+-", initial, true, 0)

    assert {:ok, ~c"B!", %{mode: :direct}, <<>>} =
             UTF7Codec.decode_chunk("+AEI!", initial, true, 0)

    assert {:ok, [0xF800], %{mode: :direct}, <<>>} =
             UTF7Codec.decode_chunk("++AA-", initial, true, 0)

    assert {:ok, [0xFC00], %{mode: :direct}, <<>>} =
             UTF7Codec.decode_chunk("+/AA-", initial, true, 0)

    assert {:error, :invalid_sequence, 0, "+"} = UTF7Codec.decode_chunk("+", initial, true, 0)

    assert {:error, :invalid_sequence, 0, "+A"} =
             UTF7Codec.decode_chunk("+A!", initial, true, 0)

    assert {:error, :invalid_sequence, 0, "+3AA"} =
             UTF7Codec.decode_chunk("+3AA-", initial, true, 0)

    assert {:error, :invalid_sequence, 0, "+2AAAQQ"} =
             UTF7Codec.decode_chunk("+2AAAQQ-", initial, true, 0)

    assert {:error, :invalid_sequence, 0, <<0>>} =
             UTF7Codec.decode_chunk(<<0>>, initial, true, 0)

    assert {:error, :invalid_sequence, 0, <<0xFF>>} =
             UTF7Codec.decode_chunk(<<0xFF>>, initial, true, 0)

    assert {:ok, [], %{mode: :plus}, <<>>} = UTF7Codec.decode_chunk("+", initial, false, 0)
  end

  test "UTF-7 one-shot malformed policies recover byte-for-byte" do
    entry = %{id: :utf7}

    assert UTF7Codec.decode(entry, <<0, ?A, 0xFF>>) ==
             {:error, :invalid_sequence, 0, <<0>>}

    assert UTF7Codec.decode_discard(entry, <<0, ?A, 0xFF>>) == {:ok, ~c"A"}

    assert UTF7Codec.decode_substitute(entry, <<0, ?A, 0xFF>>, fn byte -> [byte + 0x100] end) ==
             {:ok, [0x100, ?A, 0x1FF]}

    assert UTF7Codec.decode_substitute(entry, "+A!", fn _byte -> [?x] end) ==
             {:ok, ~c"xA!"}
  end

  test "UTF-7 incremental encoder applies every invalid-scalar policy without losing order" do
    initial = UTF7Codec.stream_encode_init()

    assert UTF7Codec.encode_chunk([0x110000, ?B], initial, true, :error) ==
             {:error, :unrepresentable_character, 0x110000}

    assert UTF7Codec.encode_chunk([0x110000, ?B], initial, true, :discard) ==
             {:ok, "B", initial, []}

    assert UTF7Codec.encode_chunk(
             [0x110000, ?B],
             initial,
             true,
             {:replace, fn _ -> [?A] end}
           ) == {:ok, "AB", initial, []}

    assert UTF7Codec.encode_chunk(
             [0x110000],
             initial,
             true,
             {:replace, fn _ -> [0x110000] end}
           ) == {:error, :unrepresentable_character, 0x110000}

    for {codepoint, encoded} <- [{?+, "+-"}, {0xF800, "++AA-"}, {0xFC00, "+/AA-"}] do
      assert UTF7Codec.encode_chunk([codepoint], initial, true, :error) ==
               {:ok, encoded, initial, []}

      assert UTF7Codec.encode(%{id: :utf7}, [codepoint]) == {:ok, encoded}
    end

    assert {:ok, streamed, _state, []} =
             UTF7Codec.encode_chunk([0xE9, ?\s], initial, true, :error)

    assert UTF7Codec.decode(%{id: :utf7}, streamed) == {:ok, [0xE9, ?\s]}
  end

  test "UTF-7 one-shot substitution accepts surrogate units and rejects values above Unicode" do
    entry = %{id: :utf7}

    assert UTF7Codec.encode(entry, [0x110000]) ==
             {:error, :unrepresentable_character, 0x110000}

    assert UTF7Codec.encode_substitute(entry, [0x110000], fn _ -> [0xD800] end) ==
             {:ok, "+2AA-"}

    assert UTF7Codec.encode_substitute(entry, [0x110000], fn _ -> [0x110000] end) ==
             {:error, :unrepresentable_character, 0x110000}

    assert UTF7Codec.encode_substitute(entry, [?A, 0x110000, ?B], fn _ -> ~c"<U>" end) ==
             UTF7Codec.encode(entry, ~c"A<U>B")
  end

  test "stateful stream scanners retain HZ and ISO-2022 variant modes" do
    assert StatefulCodec.decode_chunk(%{id: :hz}, "~~", {:hz, false}, true, 0) ==
             {:ok, ~c"~", {:hz, false}, <<>>}

    assert StatefulCodec.decode_chunk(%{id: :hz}, "~\n", {:hz, false}, true, 0) ==
             {:ok, [], {:hz, false}, <<>>}

    assert {:ok, [0xA1], {:jp, :ascii, :iso8859_1}, <<>>} =
             StatefulCodec.decode_chunk(
               %{id: :iso2022_jp2},
               <<0x1B, ".A", 0x1B, ?N, 0x21>>,
               {:jp, :ascii, nil},
               true,
               0
             )

    assert {:ok, [], {:jp, :roman, nil}, <<>>} =
             StatefulCodec.decode_chunk(
               %{id: :iso2022_jpms},
               <<0x0E, 0x0F>>,
               {:jp, :roman, nil},
               true,
               0
             )

    for {entry, input, expected_state} <- [
          {%{id: :iso2022_jp1}, <<0x1B, "$(D">>, {:jp, :jis0212, nil}},
          {%{id: :iso2022_jp3}, <<0x1B, "$(O">>, {:jp, :jis0213_1, nil}},
          {%{id: :iso2022_jpms}, <<0x1B, "$B">>, {:jp, :jis0208ms, nil}}
        ] do
      assert StatefulCodec.decode_chunk(entry, input, StatefulCodec.stream_init(entry), true, 0) ==
               {:ok, [], expected_state, <<>>}
    end
  end

  test "stateful prefixes preserve mode while reporting absolute stream offsets" do
    cases = [
      {%{id: :iso2022_jp1}, {:jp, :roman, nil}},
      {%{id: :iso2022_jp2}, {:jp, :kana, nil}},
      {%{id: :iso2022_jp2}, {:jp, :jis0208, nil}},
      {%{id: :iso2022_jp1}, {:jp, :jis0212, nil}},
      {%{id: :iso2022_jp2}, {:jp, :gb2312, nil}},
      {%{id: :iso2022_jp2}, {:jp, :ksc5601, nil}},
      {%{id: :iso2022_jp3}, {:jp, :jis0213_1, nil}},
      {%{id: :iso2022_jp3}, {:jp, :jis0213_2, nil}},
      {%{id: :iso2022_jpms}, {:jp, :jis0208ms, nil}},
      {%{id: :iso2022_jpms}, {:jp, :jis0212ms, nil}},
      {%{id: :iso2022_jp2}, {:jp, :ascii, :iso8859_1}},
      {%{id: :iso2022_jp2}, {:jp, :ascii, :iso8859_7}},
      {%{id: :iso2022_cn_ext}, {:cn, :ascii, 1, 2, 3}},
      {%{id: :iso2022_cn_ext}, {:cn, :ascii, :iso_ir_165, nil, nil}}
    ]

    for {entry, state} <- cases do
      assert {:error, _kind, 17, <<0xFF>>} =
               StatefulCodec.decode_chunk(entry, <<0xFF>>, state, true, 17)
    end
  end

  test "stateful strict and substitution paths retain framing around malformed units" do
    assert StatefulCodec.decode(%{id: :hz}, "~{\"!") ==
             {:error, :invalid_sequence, 2, "\"!"}

    assert StatefulCodec.decode_substitute(%{id: :hz}, "~~~\n", fn _ -> [?x] end) ==
             {:ok, ~c"~"}

    assert StatefulCodec.encode(%{id: :hz}, [0x110000]) ==
             {:error, :unrepresentable_character, 0x110000}

    assert StatefulCodec.decode(%{id: :iso2022_kr}, <<0x0E>>) ==
             {:error, :invalid_sequence, 0, <<0x0E>>}

    assert StatefulCodec.decode(%{id: :iso2022_kr}, <<0x1B, "$)C", 0x0E, 0, 0>>) ==
             {:error, :invalid_sequence, 5, <<0, 0>>}

    assert StatefulCodec.decode_substitute(
             %{id: :iso2022_kr},
             <<0x1B, "$)C", 0x0E, 0x21>>,
             fn _ -> [?x] end
           ) == {:ok, ~c"x"}

    assert StatefulCodec.encode(%{id: :iso2022_kr}, [0x110000]) ==
             {:error, :unrepresentable_character, 0x110000}

    assert StatefulCodec.encode_substitute(%{id: :unknown}, [], fn _ -> [] end) ==
             {:error, :unsupported_conversion, 0}
  end

  test "HZ and ISO-2022-KR stream encoders apply error, discard, and replacement policies" do
    for id <- [:hz, :iso2022_kr] do
      entry = %{id: id}
      initial = StatefulCodec.stream_encode_init(entry)

      assert StatefulCodec.encode_chunk(entry, [0x110000, ?B], initial, true, :error) ==
               {:error, :unrepresentable_character, 0x110000}

      assert {:ok, "B", _state, []} =
               StatefulCodec.encode_chunk(entry, [0x110000, ?B], initial, true, :discard)

      assert {:ok, "AB", _state, []} =
               StatefulCodec.encode_chunk(
                 entry,
                 [0x110000, ?B],
                 initial,
                 true,
                 {:replace, fn _ -> [?A] end}
               )

      assert StatefulCodec.encode_chunk(
               entry,
               [0x110000],
               initial,
               true,
               {:replace, fn _ -> [0x110000] end}
             ) == {:error, :unrepresentable_character, 0x110000}
    end
  end

  test "external registry validates every metadata boundary and public fallback" do
    assert :ok = ExternalRegistry.register(Iconvex.CoverageCodec)
    assert {:ok, :existing} = ExternalRegistry.register_if_absent(Iconvex.CoverageCodec)

    assert {:error, {:invalid_argument, :registration_token}} =
             ExternalRegistry.unregister(:not_a_module, :not_a_reference)

    assert {:error, {:invalid_argument, :module}} = ExternalRegistry.unregister("not-an-atom")
    assert :error = ExternalRegistry.resolve(123)

    assert ExternalRegistry.register(Iconvex.CoverageCodec, :not_a_keyword) ==
             {:error, {:invalid_codec, :options_must_be_a_keyword_list}}

    assert ExternalRegistry.register(Iconvex.CoverageCodec, unknown: true) ==
             {:error, {:invalid_codec, :unknown_options}}

    assert ExternalRegistry.register(:iconvex_coverage_module_not_loaded) ==
             {:error, {:invalid_codec, :module_not_loaded}}

    assert ExternalRegistry.register("not-an-atom") ==
             {:error, {:invalid_codec, :module_must_be_an_atom}}

    assert {:error, {:invalid_codec, {:missing_callback, _callback}}} =
             ExternalRegistry.register(Iconvex.CoverageMissingCallbacksCodec)

    assert ExternalRegistry.register(Iconvex.CoverageBadStatefulCodec) ==
             {:error, {:invalid_codec, :stateful_must_be_boolean}}

    assert ExternalRegistry.register(Iconvex.CoverageBadIdCodec) ==
             {:error, {:invalid_codec, :codec_id_must_be_an_atom}}

    assert ExternalRegistry.register(Iconvex.CoverageBadStatefulCodec, aliases: :not_a_list) ==
             {:error, {:invalid_codec, :aliases_must_be_a_list}}

    assert {:error, {:invalid_codec, {:metadata_exception, "argument error"}}} =
             ExternalRegistry.register(Iconvex.CoverageBadAliasesCodec)

    assert ExternalRegistry.register(Iconvex.CoverageBadNameCodec) ==
             {:error, {:invalid_codec, {:invalid_name, :not_a_binary}}}

    assert {:error, {:invalid_codec, {:metadata_exception, "metadata boom"}}} =
             ExternalRegistry.register(Iconvex.CoverageRaisingMetadataCodec)

    assert {:error, {:invalid_codec, {:metadata_throw, {:throw, :metadata_boom}}}} =
             ExternalRegistry.register(Iconvex.CoverageThrowingMetadataCodec)
  end

  test "external registry retry messages adopt only the committed ownership token" do
    module = Iconvex.CoverageCodec
    registry = Process.whereis(ExternalRegistry)
    token = make_ref()
    expected = :missing

    assert GenServer.call(registry, {:register, module, [], token, :adopt, expected}) ==
             {:ok, token}

    committed = {:registered, token}

    assert GenServer.call(registry, {:register, module, [], token, :adopt, committed}) ==
             {:ok, token}

    assert GenServer.call(registry, {:register, module, [], make_ref(), :adopt, expected}) ==
             {:error, :registration_replaced_during_retry}

    assert GenServer.call(registry, {:register_if_absent, module, [], token}) == {:ok, token}
    assert GenServer.call(registry, {:unregister, module, make_ref()}) == :ok
    assert {:ok, %{registration_token: ^token}} = ExternalRegistry.resolve(module)
  end

  test "external registry reads and removes a pre-ownership name index" do
    module = Iconvex.CoverageCodec
    registry = Process.whereis(ExternalRegistry)

    assert :ok = ExternalRegistry.register(module, aliases: ["X-COVERAGE-OLD", "X-COVERAGE-KEEP"])

    :sys.replace_state(registry, fn state ->
      [{{:module, ^module}, entry}] = :ets.lookup(ExternalRegistry, {:module, module})
      legacy_entry = Map.delete(entry, :name_index)
      :ets.insert(ExternalRegistry, {{:module, module}, legacy_entry})
      :ets.insert(ExternalRegistry, {{:name, "X-COVERAGE-OLD"}, legacy_entry})
      state
    end)

    assert {:ok, %{codec: ^module}} = ExternalRegistry.resolve("X-COVERAGE-OLD")

    assert :ok =
             ExternalRegistry.register(module, aliases: ["X-COVERAGE-KEEP", "X-COVERAGE-NEW"])

    assert ExternalRegistry.resolve("X-COVERAGE-OLD") == :error
    assert {:ok, %{codec: ^module}} = ExternalRegistry.resolve("X-COVERAGE-NEW")
  end

  test "external registry configuration rejects bad starts and reconciles inherited state" do
    previous = Application.fetch_env(:iconvex, :external_codecs)

    on_exit(fn ->
      Application.stop(:iconvex)

      case previous do
        {:ok, value} -> Application.put_env(:iconvex, :external_codecs, value)
        :error -> Application.delete_env(:iconvex, :external_codecs)
      end

      Application.ensure_all_started(:iconvex)
    end)

    assert :ok = Application.stop(:iconvex)
    assert ExternalRegistry.resolve("X-COVERAGE-CODEC") == :error
    assert ExternalRegistry.canonical_names() == []
    assert ExternalRegistry.register(Iconvex.CoverageCodec) == {:error, :registry_not_started}
    assert ExternalRegistry.unregister(Iconvex.CoverageCodec) == {:error, :registry_not_started}

    Application.put_env(:iconvex, :external_codecs, :not_a_list)

    assert {:error,
            {:iconvex,
             {{:shutdown,
               {:failed_to_start_child, ExternalRegistry,
                {:invalid_external_codec,
                 {:invalid_configuration, :external_codecs_must_be_a_list}}}},
              {Iconvex.Application, :start, [:normal, []]}}}} =
             Application.ensure_all_started(:iconvex)

    Application.put_env(:iconvex, :external_codecs, [Iconvex.CoverageMissingCallbacksCodec])

    assert {:error,
            {:iconvex,
             {{:shutdown,
               {:failed_to_start_child, ExternalRegistry,
                {:invalid_external_codec, {:invalid_codec, {:missing_callback, {:decode, 1}}}}}},
              {Iconvex.Application, :start, [:normal, []]}}}} =
             Application.ensure_all_started(:iconvex)

    Application.put_env(
      :iconvex,
      :external_codecs,
      [{Iconvex.CoverageCodec, [aliases: ["X-COVERAGE-CONFIGURED"]]}]
    )

    assert {:ok, _started} = Application.ensure_all_started(:iconvex)

    assert {:ok, %{codec: Iconvex.CoverageCodec}} =
             ExternalRegistry.resolve("X-COVERAGE-CONFIGURED")

    restart_registry!()

    assert {:ok, %{codec: Iconvex.CoverageCodec}} =
             ExternalRegistry.resolve("X-COVERAGE-CONFIGURED")

    Application.put_env(:iconvex, :external_codecs, [Iconvex.CoverageCodec])
    assert :ok = ExternalRegistry.unregister(Iconvex.CoverageCodec)
    restart_registry!()
    assert {:ok, %{codec: Iconvex.CoverageCodec}} = ExternalRegistry.resolve("X-COVERAGE-CODEC")
  end

  test "failed configured batch leaves no valid prefix in recovery state" do
    previous = Application.fetch_env(:iconvex, :external_codecs)
    recovery_key = {ExternalRegistry, :recovery_snapshot}

    on_exit(fn ->
      Application.stop(:iconvex)

      case previous do
        {:ok, value} -> Application.put_env(:iconvex, :external_codecs, value)
        :error -> Application.delete_env(:iconvex, :external_codecs)
      end

      Application.ensure_all_started(:iconvex)
    end)

    assert :ok = Application.stop(:iconvex)
    before_snapshot = :persistent_term.get(recovery_key, :missing)
    assert before_snapshot == :missing

    Application.put_env(
      :iconvex,
      :external_codecs,
      [Iconvex.CoverageCodec, Iconvex.CoverageDefinitelyUnloadedCodec]
    )

    assert {:error,
            {:iconvex,
             {{:shutdown,
               {:failed_to_start_child, ExternalRegistry,
                {:invalid_external_codec, {:invalid_codec, :module_not_loaded}}}},
              {Iconvex.Application, :start, [:normal, []]}}}} =
             Application.ensure_all_started(:iconvex)

    assert :persistent_term.get(recovery_key, :missing) == before_snapshot

    Application.put_env(:iconvex, :external_codecs, [])
    assert {:ok, started} = Application.ensure_all_started(:iconvex)
    assert :iconvex in started
    assert ExternalRegistry.resolve("X-COVERAGE-CODEC") == :error
    assert ExternalRegistry.canonical_names() == []
  end

  defp restart_registry! do
    previous = Process.whereis(ExternalRegistry)
    monitor = Process.monitor(previous)
    Process.exit(previous, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^previous, :killed}, 1_000
    wait_for_registry(previous)
  end

  defp wait_for_registry(previous, attempts \\ 1_000)
  defp wait_for_registry(_previous, 0), do: flunk("external registry did not restart")

  defp wait_for_registry(previous, attempts) do
    case Process.whereis(ExternalRegistry) do
      current when is_pid(current) and current != previous ->
        current

      _ ->
        Process.sleep(1)
        wait_for_registry(previous, attempts - 1)
    end
  end
end

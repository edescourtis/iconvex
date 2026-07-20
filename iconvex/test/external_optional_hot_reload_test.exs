defmodule Iconvex.ExternalOptionalHotReloadTest do
  use ExUnit.Case, async: false

  alias Iconvex.ExternalCallbacks

  @codec Iconvex.ExternalOptionalHotReloadTest.Codec
  @missing Iconvex.ExternalOptionalHotReloadTest.MissingCallbackTarget

  setup do
    Iconvex.unregister_codec(@codec)
    unload(@codec)

    on_exit(fn ->
      Iconvex.unregister_codec(@codec)
      unload(@codec)
    end)

    :ok
  end

  test "RED: removing optional UTF-8 and UCS-4 callbacks after registration falls back" do
    for callback <- optional_cases() do
      reload([callback.name])
      assert :ok = Iconvex.register_codec(@codec)

      reload([])
      assert callback.invoke.() == callback.fallback
    end
  end

  test "RED: adding optional UTF-8 and UCS-4 callbacks after registration is observed" do
    for callback <- optional_cases() do
      reload([])
      assert :ok = Iconvex.register_codec(@codec)

      reload([callback.name])
      assert callback.invoke.() == callback.direct
    end
  end

  test "RED: pinned converters survive removal of optional UTF-8 and UCS-4 callbacks" do
    for callback <- optional_cases() do
      reload([callback.name])
      assert :ok = Iconvex.register_codec(@codec)
      converter = new_converter(callback)

      reload([])
      assert finish_converter(converter, callback.input) == callback.fallback
    end
  end

  test "RED: pinned converters observe added optional UTF-8 and UCS-4 callbacks" do
    for callback <- optional_cases() do
      reload([])
      assert :ok = Iconvex.register_codec(@codec)
      converter = new_converter(callback)

      reload([callback.name])
      assert finish_converter(converter, callback.input) == callback.direct
    end
  end

  test "UndefinedFunctionError raised by optional callback internals is never swallowed" do
    for callback <- optional_cases() do
      reload([{callback.name, :internal_undef}])
      assert :ok = Iconvex.register_codec(@codec)

      error = assert_raise UndefinedFunctionError, callback.invoke
      assert error.module == @missing
      assert error.function == :boom
      assert error.arity == 0
    end
  end

  test "shared optional dispatcher distinguishes removal races from callback-internal undef" do
    reload([:decode_to_utf8])

    assert ExternalCallbacks.call(@codec, :decode_to_utf8, ["a"]) ==
             {:called, {:ok, "OPT-D8"}}

    reload([])
    assert ExternalCallbacks.call(@codec, :decode_to_utf8, ["a"]) == :missing

    reload([{:decode_to_utf8, :exact_undef}])
    assert ExternalCallbacks.call(@codec, :decode_to_utf8, ["a"]) == :missing

    reload([{:decode_to_utf8, :internal_undef}])

    error =
      assert_raise UndefinedFunctionError, fn ->
        ExternalCallbacks.call(@codec, :decode_to_utf8, ["a"])
      end

    assert error.module == @missing
    assert error.function == :boom
  end

  test "RED: removing stateless incremental callbacks after stream creation is typed" do
    reload([:decode_chunk_2, :encode_chunk_3])
    assert :ok = Iconvex.register_codec(@codec)

    source_stream = Iconvex.stream!(["a"], @codec, "UTF-8")
    target_stream = Iconvex.stream!(["a"], "UTF-8", @codec)
    reload([])

    assert_streaming_unsupported(:source, fn -> Enum.to_list(source_stream) end)
    assert_streaming_unsupported(:target, fn -> Enum.to_list(target_stream) end)
  end

  test "RED: removing stateful incremental callbacks after stream creation is typed" do
    reload([:stream_decoder_init, :decode_chunk_3, :stream_encoder_init, :encode_chunk_4],
      stateful?: true
    )

    assert :ok = Iconvex.register_codec(@codec)

    source_stream = Iconvex.stream!(["a"], @codec, "UTF-8")
    target_stream = Iconvex.stream!(["a"], "UTF-8", @codec)
    reload([], stateful?: true)

    assert_streaming_unsupported(:source, fn -> Enum.to_list(source_stream) end)
    assert_streaming_unsupported(:target, fn -> Enum.to_list(target_stream) end)
  end

  test "incremental callback-internal UndefinedFunctionError propagates" do
    reload([{:decode_chunk_2, :internal_undef}])
    assert :ok = Iconvex.register_codec(@codec)
    stream = Iconvex.stream!(["a"], @codec, "UTF-8")

    error = assert_raise UndefinedFunctionError, fn -> Enum.to_list(stream) end
    assert error.module == @missing
    assert error.function == :boom
    assert error.arity == 0
  end

  test "decode_error_consumption removal falls back and callback-internal undef propagates" do
    reload([:decode_error_consumption])
    assert :ok = Iconvex.register_codec(@codec)
    assert {:ok, converter} = Iconvex.new(@codec, "UTF-8")
    entry = converter.from_entry

    assert Iconvex.__decode_error_consumption__(entry, :invalid_sequence, <<0xFF>>) == 7

    reload([])
    assert Iconvex.__decode_error_consumption__(entry, :invalid_sequence, <<0xFF>>) == 1

    reload([{:decode_error_consumption, :internal_undef}])

    error =
      assert_raise UndefinedFunctionError, fn ->
        Iconvex.__decode_error_consumption__(entry, :invalid_sequence, <<0xFF>>)
      end

    assert error.module == @missing
    assert error.function == :boom
  end

  defp optional_cases do
    [
      %{
        name: :decode_to_utf8,
        invoke: fn -> Iconvex.convert!("a", @codec, "UTF-8") end,
        input: "a",
        from: @codec,
        to: "UTF-8",
        options: [],
        fallback: "a",
        direct: "OPT-D8"
      },
      %{
        name: :encode_from_utf8,
        invoke: fn -> Iconvex.convert!("a", "UTF-8", @codec) end,
        input: "a",
        from: "UTF-8",
        to: @codec,
        options: [],
        fallback: "a",
        direct: "OPT-E8"
      },
      %{
        name: :decode_to_ucs4_discard,
        invoke: fn ->
          Iconvex.convert!("a", @codec, "UCS-4BE", invalid: :discard)
        end,
        input: "a",
        from: @codec,
        to: "UCS-4BE",
        options: [invalid: :discard],
        fallback: <<?a::unsigned-big-32>>,
        direct: <<?Z::unsigned-big-32>>
      },
      %{
        name: :encode_from_ucs4_discard,
        invoke: fn ->
          Iconvex.convert!(<<?a::unsigned-big-32>>, "UCS-4BE", @codec, unrepresentable: :discard)
        end,
        input: <<?a::unsigned-big-32>>,
        from: "UCS-4BE",
        to: @codec,
        options: [unrepresentable: :discard],
        fallback: "a",
        direct: "OPT-E4"
      }
    ]
  end

  defp reload(callbacks, options \\ []) do
    unload(@codec)
    [{@codec, _bytecode}] = Code.compile_string(codec_source(callbacks, options))
    assert Code.ensure_loaded?(@codec)
  end

  defp unload(module) do
    :code.purge(module)
    :code.delete(module)
  end

  defp codec_source(callbacks, options) do
    optional_source = Enum.map_join(callbacks, "\n", &callback_source/1)
    stateful? = Keyword.get(options, :stateful?, false)

    """
    defmodule #{inspect(@codec)} do
      @behaviour Iconvex.Codec

      def canonical_name, do: "X-OPTIONAL-HOT-RELOAD"
      def aliases, do: []
      def stateful?, do: #{inspect(stateful?)}

      def decode(input), do: {:ok, :binary.bin_to_list(input)}
      def decode_discard(input), do: {:ok, :binary.bin_to_list(input)}

      def encode(codepoints) do
        case Enum.find(codepoints, &(&1 not in 0..0xFF)) do
          nil -> {:ok, :erlang.list_to_binary(codepoints)}
          codepoint -> {:error, :unrepresentable_character, codepoint}
        end
      end

      def encode_discard(codepoints) do
        {:ok, codepoints |> Enum.filter(&(&1 in 0..0xFF)) |> :erlang.list_to_binary()}
      end

      def encode_substitute(codepoints, _replacer), do: encode_discard(codepoints)

      #{optional_source}
    end
    """
  end

  defp callback_source({:decode_chunk_2, :internal_undef}) do
    """
    def decode_chunk(_input, _final?) do
      apply(#{inspect(@missing)}, :boom, [])
    end
    """
  end

  defp callback_source({name, :internal_undef}) do
    arguments = callback_arguments(name)

    """
    def #{name}(#{arguments}) do
      apply(#{inspect(@missing)}, :boom, [])
    end
    """
  end

  defp callback_source({name, :exact_undef}) do
    arguments = callback_arguments(name)
    arity = if name in [:decode_to_utf8, :encode_from_utf8], do: 1, else: 2

    """
    def #{name}(#{arguments}) do
      raise UndefinedFunctionError,
        module: __MODULE__,
        function: #{inspect(name)},
        arity: #{arity}
    end
    """
  end

  defp callback_source(:decode_to_utf8),
    do: ~S|def decode_to_utf8(_input), do: {:ok, "OPT-D8"}|

  defp callback_source(:encode_from_utf8),
    do: ~S|def encode_from_utf8(_input), do: {:ok, "OPT-E8"}|

  defp callback_source(:decode_to_ucs4_discard) do
    ~S"""
    def decode_to_ucs4_discard(_input, :big), do: {:ok, <<?Z::unsigned-big-32>>}
    def decode_to_ucs4_discard(_input, :little), do: {:ok, <<?Z::unsigned-little-32>>}
    """
  end

  defp callback_source(:encode_from_ucs4_discard),
    do: ~S|def encode_from_ucs4_discard(_input, _endian), do: {:ok, "OPT-E4"}|

  defp callback_source(:decode_chunk_2) do
    ~S"""
    def decode_chunk(input, _final?), do: {:ok, :binary.bin_to_list(input), <<>>}
    """
  end

  defp callback_source(:encode_chunk_3) do
    ~S"""
    def encode_chunk(codepoints, _final?, _policy),
      do: {:ok, :erlang.list_to_binary(codepoints), []}
    """
  end

  defp callback_source(:stream_decoder_init), do: "def stream_decoder_init, do: :decoder"

  defp callback_source(:decode_chunk_3) do
    ~S"""
    def decode_chunk(input, state, _final?),
      do: {:ok, :binary.bin_to_list(input), state, <<>>}
    """
  end

  defp callback_source(:stream_encoder_init), do: "def stream_encoder_init, do: :encoder"

  defp callback_source(:encode_chunk_4) do
    ~S"""
    def encode_chunk(codepoints, state, _final?, _policy),
      do: {:ok, :erlang.list_to_binary(codepoints), state, []}
    """
  end

  defp callback_source(:decode_error_consumption),
    do: "def decode_error_consumption(_kind, _sequence), do: 7"

  defp callback_arguments(name) when name in [:decode_to_utf8, :encode_from_utf8],
    do: "_input"

  defp callback_arguments(_name), do: "_input, _endian"

  defp new_converter(callback) do
    assert {:ok, converter} = Iconvex.new(callback.from, callback.to, callback.options)
    converter
  end

  defp finish_converter(converter, input) do
    assert {:ok, <<>>, converter} = Iconvex.feed(converter, input)
    assert {:ok, output} = Iconvex.finish(converter)
    output
  end

  defp assert_streaming_unsupported(direction, fun) do
    error = assert_raise ArgumentError, fun
    assert Exception.message(error) =~ "streaming_unsupported"
    assert Exception.message(error) =~ inspect(direction)
  end
end

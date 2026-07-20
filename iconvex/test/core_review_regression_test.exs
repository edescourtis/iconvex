defmodule Iconvex.CoreReviewRegressionTest.CountedSubstitutionCodec do
  @behaviour Iconvex.Codec

  @mark 0x0304

  def canonical_name, do: "X-COUNTED-SUBSTITUTION"
  def aliases, do: []
  def stateful?, do: false

  def decode(input), do: {:ok, :binary.bin_to_list(input)}
  def decode_discard(input), do: decode(input)

  def encode(codepoints) do
    mark(:encode)
    encode_loop(codepoints, [])
  end

  def encode_discard(codepoints), do: encode(codepoints)

  # This optional callback is deliberately present before core learns to call it:
  # the RED run proves the old fallback performs quadratically many encode calls.
  def encode_substitute(codepoints, replacer) do
    mark(:encode_substitute)
    encode_substitute_loop(codepoints, replacer, [])
  end

  def clear_calls, do: Process.delete({__MODULE__, :calls})
  def calls(name), do: Process.get({__MODULE__, :calls}, %{}) |> Map.get(name, 0)

  defp encode_loop([], acc), do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_loop([0x00CA, @mark | rest], acc),
    do: encode_loop(rest, ["P" | acc])

  defp encode_loop([codepoint | rest], acc) when codepoint in 0..0x7F,
    do: encode_loop(rest, [<<codepoint>> | acc])

  defp encode_loop([codepoint | _rest], _acc),
    do: {:error, :unrepresentable_character, codepoint}

  defp encode_substitute_loop([], _replacer, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute_loop([0x00CA, @mark | rest], replacer, acc),
    do: encode_substitute_loop(rest, replacer, ["P" | acc])

  defp encode_substitute_loop([codepoint | rest], replacer, acc)
       when codepoint in 0..0x7F,
       do: encode_substitute_loop(rest, replacer, [<<codepoint>> | acc])

  defp encode_substitute_loop([codepoint | rest], replacer, acc) do
    mark(:replacement)

    with {:ok, replacement} <- encode_loop(replacer.(codepoint), []) do
      encode_substitute_loop(rest, replacer, [replacement | acc])
    end
  end

  defp mark(name) do
    key = {__MODULE__, :calls}
    Process.put(key, Map.update(Process.get(key, %{}), name, 1, &(&1 + 1)))
  end
end

defmodule Iconvex.CoreReviewRegressionTest.MalformedFastCodec do
  @behaviour Iconvex.Codec

  def canonical_name, do: "X-MALFORMED-FAST"
  def aliases, do: []
  def stateful?, do: false

  def decode(input), do: {:ok, :binary.bin_to_list(input)}
  def decode_discard(input), do: decode(input)

  def encode(codepoints) do
    if Enum.all?(codepoints, &(&1 in 0..0xFF)),
      do: {:ok, :erlang.list_to_binary(codepoints)},
      else: {:error, :unrepresentable_character, Enum.find(codepoints, &(&1 > 0xFF))}
  end

  def encode_discard(codepoints),
    do: {:ok, codepoints |> Enum.filter(&(&1 in 0..0xFF)) |> :erlang.list_to_binary()}

  def encode_substitute(_codepoints, _replacer),
    do: Process.get({__MODULE__, :substitute_result}, :malformed)

  def decode_to_utf8(_input), do: Process.get({__MODULE__, :decode_result}, :malformed)
  def encode_from_utf8(_input), do: Process.get({__MODULE__, :encode_result}, :malformed)

  def encode_from_ucs4_discard(_input, _endian),
    do: Process.get({__MODULE__, :ucs4_encode_result}, :miss)

  def set_decode_result(result), do: Process.put({__MODULE__, :decode_result}, result)
  def set_encode_result(result), do: Process.put({__MODULE__, :encode_result}, result)

  def set_ucs4_encode_result(result),
    do: Process.put({__MODULE__, :ucs4_encode_result}, result)

  def set_substitute_result(result), do: Process.put({__MODULE__, :substitute_result}, result)

  def clear_results do
    Process.delete({__MODULE__, :decode_result})
    Process.delete({__MODULE__, :encode_result})
    Process.delete({__MODULE__, :ucs4_encode_result})
    Process.delete({__MODULE__, :substitute_result})
  end
end

defmodule Iconvex.CoreReviewRegressionTest do
  use ExUnit.Case, async: false

  alias Iconvex.{ISO2022JPCodec, StatefulCodec, TableCodec, Tables}

  alias Iconvex.CoreReviewRegressionTest.{
    CountedSubstitutionCodec,
    MalformedFastCodec
  }

  setup do
    Iconvex.unregister_codec(CountedSubstitutionCodec)
    CountedSubstitutionCodec.clear_calls()
    assert :ok = Iconvex.register_codec(CountedSubstitutionCodec)
    Iconvex.unregister_codec(MalformedFastCodec)
    MalformedFastCodec.clear_results()
    assert :ok = Iconvex.register_codec(MalformedFastCodec)

    on_exit(fn ->
      Iconvex.unregister_codec(CountedSubstitutionCodec)
      Iconvex.unregister_codec(MalformedFastCodec)
    end)

    :ok
  end

  test "MacKeyboard three-codepoint entries use the UTF-8 table fast path" do
    id = :iconvex_test_mac_keyboard
    cache_key = {{Tables, :table}, :iconvex, id}
    cache_version = {1, Application.spec(:iconvex, :vsn) || ~c"unloaded"}

    one =
      nil
      |> List.duplicate(256)
      |> List.replace_at(0x6F, {0xF860, ?F, ?1})
      |> List.to_tuple()

    table = %{
      one: one,
      many: %{},
      encode: %{},
      prefixes: MapSet.new(),
      max_input: 1,
      max_codepoints: 3
    }

    :persistent_term.put(cache_key, {1, cache_version, table})
    on_exit(fn -> :persistent_term.erase(cache_key) end)

    assert TableCodec.decode_to_utf8(%{id: id}, <<0x6F>>) ==
             {:ok, <<0xF860::utf8, ?F, ?1>>}
  end

  test "Unicode substitution replaces the reported occurrence, not an equal earlier codepoint" do
    input = <<0x00CA::utf8, 0x0304::utf8, 0x0304::utf8>>

    assert Iconvex.convert(input, "UTF-8", "BIG5-HKSCS:1999", unicode_substitute: "<U+%04X>") ==
             {:ok, <<0x88, 0x62, "<U+0304>">>}
  end

  test "external native substitution is linear and preserves multi-codepoint matches" do
    repeated = List.duplicate(0x1F600, 96)
    input = :unicode.characters_to_binary([0x00CA, 0x0304, 0x0304 | repeated])
    replacement = "<U+1F600>"

    assert Iconvex.convert(input, "UTF-8", CountedSubstitutionCodec,
             unicode_substitute: "<U+%04X>"
           ) == {:ok, "P<U+0304>" <> :binary.copy(replacement, length(repeated))}

    assert CountedSubstitutionCodec.calls(:encode_substitute) == 1
    assert CountedSubstitutionCodec.calls(:encode) == 0
    assert CountedSubstitutionCodec.calls(:replacement) == length(repeated) + 1
  end

  test "external repeated substitution uses one codec pass at every input scale" do
    for repeated <- [100, 200, 400, 800] do
      CountedSubstitutionCodec.clear_calls()
      input = :binary.copy(<<0x1F600::utf8>>, repeated)

      assert Iconvex.convert(input, "UTF-8", CountedSubstitutionCodec,
               unicode_substitute: "<U+%04X>"
             ) == {:ok, :binary.copy("<U+1F600>", repeated)}

      assert CountedSubstitutionCodec.calls(:encode_substitute) == 1
      assert CountedSubstitutionCodec.calls(:encode) == 0
      assert CountedSubstitutionCodec.calls(:replacement) == repeated
    end
  end

  test "built-in table substitution does not re-encode candidate prefixes" do
    repeated = 400
    input = :binary.copy(<<0x1F600::utf8>>, repeated)

    trace_call_counts([{TableCodec, :encode, 2}, {TableCodec, :encode_substitute, 3}], fn ->
      assert Iconvex.convert(input, "UTF-8", "ASCII", unicode_substitute: "<U+%04X>") ==
               {:ok, :binary.copy("<U+1F600>", repeated)}

      assert trace_call_count({TableCodec, :encode, 2}) <= 1
      assert trace_call_count({TableCodec, :encode_substitute, 3}) == 1
    end)
  end

  test "built-in stateful substitution preserves state in one pass" do
    repeated = 200
    input = :binary.copy(<<0x1F600::utf8>>, repeated)

    trace_call_counts(
      [
        {StatefulCodec, :encode, 2},
        {StatefulCodec, :encode_substitute, 3},
        {ISO2022JPCodec, :encode, 2},
        {ISO2022JPCodec, :encode_substitute, 3}
      ],
      fn ->
        assert Iconvex.convert(input, "UTF-8", "ISO-2022-JP", unicode_substitute: "<U+%04X>") ==
                 {:ok, :binary.copy("<U+1F600>", repeated)}

        assert trace_call_count({StatefulCodec, :encode, 2}) <= 1
        assert trace_call_count({StatefulCodec, :encode_substitute, 3}) == 1
        assert trace_call_count({ISO2022JPCodec, :encode, 2}) == 0
        assert trace_call_count({ISO2022JPCodec, :encode_substitute, 3}) == 1
      end
    )
  end

  test "every core-resident stateful engine substitutes without losing designation state" do
    replacement = ~c"<U+110000>"

    for {id, represented} <- [
          {:hz, 0x4E2D},
          {:iso2022_kr, 0xD55C},
          {:iso2022_jp, 0x65E5},
          {:iso2022_jp1, 0x65E5},
          {:iso2022_jp2, 0x65E5},
          {:iso2022_jpms, 0x65E5},
          {:iso2022_cn, 0x4E2D},
          {:iso2022_cn_ext, 0x4E2D},
          {:utf7, 0x00E9}
        ] do
      assert {:ok, encoded} =
               StatefulCodec.encode_substitute(
                 %{id: id},
                 [represented, 0x110000, represented],
                 fn _ -> replacement end
               )

      assert StatefulCodec.decode(%{id: id}, encoded) ==
               {:ok, [represented] ++ replacement ++ [represented]}
    end

    assert StatefulCodec.encode_substitute(%{id: :hz}, [0x110000], fn _ -> [0x110000] end) ==
             {:error, :unrepresentable_character, 0x110000}
  end

  test "malformed external UTF-8 fast-path results safely fall back" do
    MalformedFastCodec.set_decode_result(:malformed)
    assert Iconvex.convert("A", MalformedFastCodec, "UTF-8") == {:ok, "A"}

    assert Iconvex.convert("A", MalformedFastCodec, "UCS-4BE", invalid: :discard) ==
             {:ok, <<?A::unsigned-big-32>>}

    MalformedFastCodec.set_decode_result({:ok, <<0xFF>>})
    assert Iconvex.convert("B", MalformedFastCodec, "UTF-8") == {:ok, "B"}

    assert Iconvex.convert("B", MalformedFastCodec, "UCS-4BE", invalid: :discard) ==
             {:ok, <<?B::unsigned-big-32>>}

    MalformedFastCodec.set_encode_result(:malformed)
    assert Iconvex.convert("C", "UTF-8", MalformedFastCodec) == {:ok, "C"}

    MalformedFastCodec.set_encode_result({:ok, :not_a_binary})
    assert Iconvex.convert("D", "UTF-8", MalformedFastCodec) == {:ok, "D"}
  end

  test "external UCS-4 adapters cannot hide incomplete input or invalid-byte callbacks" do
    MalformedFastCodec.set_ucs4_encode_result({:ok, "WRONG"})
    malformed = <<?A::unsigned-big-32, 0xAA>>

    assert {:error,
            %Iconvex.Error{
              kind: :incomplete_sequence,
              offset: 4,
              sequence: <<0xAA>>
            }} =
             Iconvex.convert(malformed, "UCS-4BE", MalformedFastCodec, unrepresentable: :discard)

    parent = self()

    assert Iconvex.convert(malformed, "UCS-4BE", MalformedFastCodec,
             unrepresentable: :discard,
             on_invalid_byte: fn event ->
               send(parent, {:invalid, event})
               {:replace, ??}
             end
           ) == {:ok, "A?"}

    assert_receive {:invalid,
                    %Iconvex.InvalidByte{
                      kind: :incomplete_sequence,
                      offset: 4,
                      sequence: <<0xAA>>
                    }}
  end

  test "malformed external substitution results return a stable typed request error" do
    MalformedFastCodec.set_substitute_result(:malformed)

    assert Iconvex.convert("😀", "UTF-8", MalformedFastCodec, unicode_substitute: "<U+%04X>") ==
             {:error,
              {:invalid_codec_callback_return, MalformedFastCodec, {:encode_substitute, 2},
               :malformed}}
  end

  test "the extras registry generator emits the required substitution callback" do
    generator = File.read!(Path.expand("../tools/generate_registry.exs", __DIR__))

    assert length(Regex.scan(~r/def encode_substitute\(codepoints, replacer\)/, generator)) == 2
    assert generator =~ "CodecSupport.encode_substitute("
    assert generator =~ "direct_adapter: Iconvex.Extras.CodecSupport"
  end

  test "well-formed external UTF-8 fast-path errors retain their typed contracts" do
    MalformedFastCodec.set_decode_result({:error, :invalid_sequence, 0, <<0xFF>>})

    assert {:error, %Iconvex.Error{kind: :invalid_sequence, offset: 0, sequence: <<0xFF>>}} =
             Iconvex.convert(<<0xFF>>, MalformedFastCodec, "UTF-8")

    MalformedFastCodec.set_encode_result({:error, :unrepresentable_character, 0x1F600})

    assert {:error, %Iconvex.Error{kind: :unrepresentable_character, codepoint: 0x1F600}} =
             Iconvex.convert("😀", "UTF-8", MalformedFastCodec)

    MalformedFastCodec.set_encode_result({:decode_error, :incomplete_sequence, 0, <<0xE2, 0x82>>})

    assert {:error, %Iconvex.Error{kind: :incomplete_sequence, offset: 0}} =
             Iconvex.convert(<<0xE2, 0x82>>, "UTF-8", MalformedFastCodec)
  end

  test "substitution formats must be valid UTF-8 strings" do
    invalid_prefix = <<0xFF, "%02x">>
    invalid_suffix = <<"%04X", 0xFF>>

    assert Iconvex.convert(<<0xFF>>, "ASCII", "UTF-8", byte_substitute: invalid_prefix) ==
             {:error, {:invalid_option, :byte_substitute, :invalid_utf8}}

    assert Iconvex.convert("😀", "UTF-8", "ASCII", unicode_substitute: invalid_suffix) ==
             {:error, {:invalid_option, :unicode_substitute, :invalid_utf8}}
  end

  test "flat non-strict one-shot decode successes do not call List.flatten/1" do
    trace_call_counts([{List, :flatten, 1}], fn ->
      assert Iconvex.convert("plain", "UTF-8", "ASCII", invalid: :discard) ==
               {:ok, "plain"}

      assert Iconvex.convert("plain", "ASCII", "UTF-8", byte_substitute: "<%02X>") ==
               {:ok, "plain"}

      assert Iconvex.convert("plain", "ASCII", "UTF-8", on_invalid_byte: fn _event -> :error end) ==
               {:ok, "plain"}

      assert trace_call_count({List, :flatten, 1}) == 0
    end)
  end

  test "flat non-strict stream decode successes do not call List.flatten/1" do
    trace_call_counts([{List, :flatten, 1}], fn ->
      assert ["ab", "cd"]
             |> Iconvex.stream!("ASCII", "UTF-8", on_invalid_byte: fn _event -> :error end)
             |> Enum.join() == "abcd"

      assert trace_call_count({List, :flatten, 1}) == 0
    end)
  end

  defp trace_call_counts(mfas, function) do
    Enum.each(mfas, fn {module, _name, _arity} -> Code.ensure_loaded!(module) end)
    Enum.each(mfas, &:erlang.trace_pattern(&1, true, [:local, :call_count]))

    try do
      function.()
    after
      Enum.each(mfas, &:erlang.trace_pattern(&1, false, [:local, :call_count]))
    end
  end

  defp trace_call_count(mfa) do
    {:call_count, count} = :erlang.trace_info(mfa, :call_count)
    count
  end
end

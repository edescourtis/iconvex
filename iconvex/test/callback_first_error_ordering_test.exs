defmodule Iconvex.CallbackFirstErrorOrderingTest.ExternalASCII do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-CALLBACK-ORDER-ASCII"

  @impl true
  def decode(input), do: {:ok, :binary.bin_to_list(input)}

  @impl true
  def decode_discard(input), do: decode(input)

  @impl true
  def encode(codepoints) do
    send(self(), {:external_encode, codepoints})

    case Enum.find(codepoints, &(&1 > 0x7F)) do
      nil -> {:ok, :erlang.list_to_binary(codepoints)}
      codepoint -> {:error, :unrepresentable_character, codepoint}
    end
  end

  @impl true
  def encode_discard(codepoints),
    do: {:ok, codepoints |> Enum.filter(&(&1 <= 0x7F)) |> :erlang.list_to_binary()}

  @impl true
  def encode_substitute(codepoints, replacer) do
    codepoints
    |> Enum.flat_map(fn codepoint ->
      if codepoint <= 0x7F, do: [codepoint], else: replacer.(codepoint)
    end)
    |> encode()
  end

  @impl true
  def encode_from_utf8(input) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        encode(codepoints)

      {:error, _converted, rest} ->
        {:decode_error, :invalid_sequence, byte_size(input) - byte_size(rest), rest}

      {:incomplete, _converted, rest} ->
        {:decode_error, :incomplete_sequence, byte_size(input) - byte_size(rest), rest}
    end
  end
end

defmodule Iconvex.CallbackFirstErrorOrderingTest.ExternalLongPrefix do
  use Iconvex.Codec

  @lead 0x1000
  @continuation 0x1001
  @terminator 0x1002

  @impl true
  def canonical_name, do: "X-CALLBACK-ORDER-LONG-PREFIX"

  @impl true
  def decode(input), do: {:ok, :binary.bin_to_list(input)}

  @impl true
  def decode_discard(input), do: decode(input)

  @impl true
  def encode(codepoints) do
    case encode_chunk(codepoints, true, :error) do
      {:ok, output, []} -> {:ok, output}
      error -> error
    end
  end

  @impl true
  def encode_discard(codepoints) do
    case encode_chunk(codepoints, true, :discard) do
      {:ok, output, []} -> {:ok, output}
      error -> error
    end
  end

  @impl true
  def encode_substitute(codepoints, _replacer), do: encode(codepoints)

  @impl true
  def decode_chunk(input, _final?), do: {:ok, :binary.bin_to_list(input), <<>>}

  @impl true
  def encode_chunk([@lead], false, _policy), do: {:ok, <<>>, [@lead]}

  def encode_chunk([@lead, @continuation], false, _policy),
    do: {:ok, <<>>, [@lead, @continuation]}

  def encode_chunk([@lead, @continuation, @terminator | rest], final?, policy) do
    with {:ok, output, pending} <- encode_chunk(rest, final?, policy) do
      {:ok, "x" <> output, pending}
    end
  end

  def encode_chunk([@lead | rest], final?, :discard),
    do: encode_chunk(rest, final?, :discard)

  def encode_chunk([@lead | _rest], _final?, :error),
    do: {:error, :unrepresentable_character, @lead}

  def encode_chunk([codepoint | rest], final?, policy) when codepoint <= 0x7F do
    with {:ok, output, pending} <- encode_chunk(rest, final?, policy) do
      {:ok, <<codepoint>> <> output, pending}
    end
  end

  def encode_chunk([_codepoint | rest], final?, :discard),
    do: encode_chunk(rest, final?, :discard)

  def encode_chunk([codepoint | _rest], _final?, :error),
    do: {:error, :unrepresentable_character, codepoint}

  def encode_chunk([], _final?, _policy), do: {:ok, <<>>, []}
end

defmodule Iconvex.CallbackFirstErrorOrderingTest.ExternalOpaqueContext do
  use Iconvex.Codec

  @shift 0x1000
  @shift_only 0x1001

  @impl true
  def canonical_name, do: "X-CALLBACK-ORDER-OPAQUE-CONTEXT"

  @impl true
  def stateful?, do: true

  @impl true
  def decode(input), do: {:ok, :binary.bin_to_list(input)}

  @impl true
  def decode_discard(input), do: decode(input)

  @impl true
  def encode(codepoints) do
    send(self(), {:opaque_context_encode, codepoints})
    encode_with_policy(codepoints, :error)
  end

  @impl true
  def encode_discard(codepoints), do: encode_with_policy(codepoints, :discard)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: encode_with_policy(codepoints, {:replace, replacer})

  defp encode_with_policy(codepoints, policy) do
    case encode_open(codepoints, :ascii, policy, []) do
      {:ok, state, acc} ->
        suffix = if state == :shifted, do: [<<0x0F>>], else: []
        {:ok, acc |> :lists.reverse(suffix) |> IO.iodata_to_binary()}

      error ->
        error
    end
  end

  defp encode_open([], state, _policy, acc), do: {:ok, state, acc}

  defp encode_open([@shift | rest], :ascii, policy, acc),
    do: encode_open(rest, :shifted, policy, [<<0x0E>> | acc])

  defp encode_open([@shift_only | rest], :shifted, policy, acc),
    do: encode_open(rest, :shifted, policy, [<<0x01>> | acc])

  defp encode_open([?Z = codepoint | rest], :shifted, policy, acc),
    do: recover_unrepresentable(codepoint, rest, :shifted, policy, acc)

  defp encode_open([codepoint | rest], state, policy, acc) when codepoint <= 0x7F,
    do: encode_open(rest, state, policy, [<<codepoint>> | acc])

  defp encode_open([codepoint | rest], state, policy, acc),
    do: recover_unrepresentable(codepoint, rest, state, policy, acc)

  defp recover_unrepresentable(codepoint, _rest, _state, :error, _acc),
    do: {:error, :unrepresentable_character, codepoint}

  defp recover_unrepresentable(_codepoint, rest, state, :discard, acc),
    do: encode_open(rest, state, :discard, acc)

  defp recover_unrepresentable(codepoint, rest, state, {:replace, replacer} = policy, acc) do
    case encode_open(replacer.(codepoint), state, :error, acc) do
      {:ok, next_state, next_acc} -> encode_open(rest, next_state, policy, next_acc)
      error -> error
    end
  end
end

defmodule Iconvex.CallbackFirstErrorOrderingTest do
  use ExUnit.Case, async: false

  alias Iconvex.CallbackFirstErrorOrderingTest.{
    ExternalASCII,
    ExternalLongPrefix,
    ExternalOpaqueContext
  }

  setup do
    :ok = Iconvex.unregister_codec(ExternalASCII)
    :ok = Iconvex.unregister_codec(ExternalLongPrefix)
    :ok = Iconvex.unregister_codec(ExternalOpaqueContext)
    {:ok, token} = Iconvex.register_codec_owned(ExternalASCII)
    {:ok, prefix_token} = Iconvex.register_codec_owned(ExternalLongPrefix)
    {:ok, context_token} = Iconvex.register_codec_owned(ExternalOpaqueContext)

    on_exit(fn ->
      Iconvex.unregister_codec(ExternalOpaqueContext, context_token)
      Iconvex.unregister_codec(ExternalLongPrefix, prefix_token)
      Iconvex.unregister_codec(ExternalASCII, token)
    end)

    :ok
  end

  test "an earlier built-in target error suppresses a later invalid-byte callback" do
    parent = self()
    input = <<0xC3, 0xA9, 0xFF>>

    result =
      Iconvex.convert(input, "UTF-8", "ASCII",
        on_invalid_byte: fn event ->
          send(parent, {:invalid_byte, event})
          :error
        end
      )

    refute_receive {:invalid_byte, _event}

    assert {:error,
            %Iconvex.Error{
              kind: :unrepresentable_character,
              encoding: "US-ASCII",
              codepoint: 0xE9
            }} = result
  end

  test "recovery invokes only invalid callbacks preceding the first target error" do
    parent = self()
    input = <<0xFF, 0xC3, 0xA9, 0xFE>>

    result =
      Iconvex.convert(input, "UTF-8", "ASCII",
        on_invalid_byte: fn event ->
          send(parent, {:invalid_byte, event.offset})
          if event.offset == 0, do: {:replace, ?A}, else: :error
        end
      )

    assert_receive {:invalid_byte, 0}
    refute_receive {:invalid_byte, 3}

    assert {:error,
            %Iconvex.Error{
              kind: :unrepresentable_character,
              encoding: "US-ASCII",
              codepoint: 0xE9
            }} = result
  end

  test "external stateless targets preserve the same callback ordering" do
    parent = self()
    input = <<0xC3, 0xA9, 0xFF>>

    result =
      Iconvex.convert(input, "UTF-8", ExternalASCII,
        on_invalid_byte: fn event ->
          send(parent, {:invalid_byte, event})
          :error
        end
      )

    refute_receive {:invalid_byte, _event}
    assert_receive {:external_encode, [0xE9]}
    refute_receive {:external_encode, _codepoints}

    assert {:error,
            %Iconvex.Error{
              kind: :unrepresentable_character,
              encoding: "X-CALLBACK-ORDER-ASCII",
              codepoint: 0xE9
            }} = result
  end

  test "opaque external arbitration probes cumulative prefixes at invalid boundaries" do
    parent = self()

    assert {:ok, "BAC"} =
             Iconvex.convert(<<0xFF, ?A, 0xFE, ?C>>, "UTF-8", ExternalASCII,
               on_invalid_byte: fn event ->
                 send(parent, {:invalid_byte, event.offset})
                 if event.offset == 0, do: {:replace, ?B}, else: :discard
               end
             )

    assert_receive {:invalid_byte, 0}
    assert_receive {:external_encode, [?B, ?A]}
    assert_receive {:invalid_byte, 2}
    assert_receive {:external_encode, [?B, ?A, ?C]}
    refute_receive {:external_encode, _codepoints}
  end

  test "opaque external arbitration does not re-encode an unchanged prefix" do
    parent = self()

    assert {:ok, "A"} =
             Iconvex.convert(<<?A, 0xFF, 0xFE, 0xFD>>, "UTF-8", ExternalASCII,
               on_invalid_byte: fn event ->
                 send(parent, {:invalid_byte, event.offset})
                 :discard
               end
             )

    assert_receive {:invalid_byte, 1}
    assert_receive {:invalid_byte, 2}
    assert_receive {:invalid_byte, 3}

    # One arbitration probe plus the final conversion. The two later malformed
    # units add no Unicode and therefore must not replay the identical prefix.
    assert_receive {:external_encode, [?A]}
    assert_receive {:external_encode, [?A]}
    refute_receive {:external_encode, _codepoints}
  end

  test "opaque stateful arbitration needs the complete context for a later success" do
    parent = self()
    shift = 0x1000
    shift_only = 0x1001

    input = <<shift::utf8, ?A, 0xFF, shift_only::utf8, 0xFE>>

    assert {:ok, <<0x0E, ?A, 0x01, 0x0F>>} =
             Iconvex.convert(input, "UTF-8", ExternalOpaqueContext,
               on_invalid_byte: fn event ->
                 send(parent, {:context_invalid_byte, event.offset})
                 :discard
               end
             )

    assert_receive {:opaque_context_encode, [^shift, ?A]}
    assert_receive {:context_invalid_byte, 4}
    assert_receive {:opaque_context_encode, [^shift, ?A, ^shift_only]}
    assert_receive {:context_invalid_byte, 8}
    assert_receive {:opaque_context_encode, [^shift, ?A, ^shift_only]}
    refute_receive {:opaque_context_encode, _codepoints}
  end

  test "opaque stateful arbitration needs the complete context for a later error" do
    parent = self()
    shift = 0x1000
    input = <<shift::utf8, ?A, 0xFF, ?Z, 0xFE>>

    assert {:error,
            %Iconvex.Error{
              kind: :unrepresentable_character,
              encoding: "X-CALLBACK-ORDER-OPAQUE-CONTEXT",
              codepoint: ?Z
            }} =
             Iconvex.convert(input, "UTF-8", ExternalOpaqueContext,
               on_invalid_byte: fn event ->
                 send(parent, {:context_invalid_byte, event.offset})
                 :discard
               end
             )

    assert_receive {:opaque_context_encode, [^shift, ?A]}
    assert_receive {:context_invalid_byte, 4}
    assert_receive {:opaque_context_encode, [^shift, ?A, ?Z]}
    refute_receive {:context_invalid_byte, 6}
    refute_receive {:opaque_context_encode, _codepoints}
  end

  test "a valid source with a handler does not add an external prefix probe" do
    parent = self()

    assert {:ok, "AB"} =
             Iconvex.convert("AB", "UTF-8", ExternalASCII,
               on_invalid_byte: fn event ->
                 send(parent, {:invalid_byte, event})
                 :error
               end
             )

    refute_receive {:invalid_byte, _event}
    assert_receive {:external_encode, [?A, ?B]}
    refute_receive {:external_encode, _codepoints}
  end

  test "built-in target arbitration remains linear across many invalid boundaries" do
    handler = fn _event -> :discard end
    small = :binary.copy(<<?A, 0xFF>>, 512)
    large = :binary.copy(<<?A, 0xFF>>, 4_096)

    assert {:ok, "A"} =
             Iconvex.convert(<<?A, 0xFF>>, "UTF-8", "ASCII", on_invalid_byte: handler)

    {small_result, small_reductions} =
      reductions(fn ->
        Iconvex.convert(small, "UTF-8", "ASCII", on_invalid_byte: handler)
      end)

    {large_result, large_reductions} =
      reductions(fn ->
        Iconvex.convert(large, "UTF-8", "ASCII", on_invalid_byte: handler)
      end)

    assert small_result == {:ok, :binary.copy("A", 512)}
    assert large_result == {:ok, :binary.copy("A", 4_096)}
    assert large_reductions < small_reductions * 16
  end

  test "one-shot and every stream split preserve the ASCII target error before a later callback" do
    parent = self()
    input = <<0xC3, 0xA9, 0xFF>>

    assert {:error, %Iconvex.Error{} = one_shot_error} =
             Iconvex.convert(input, "UTF-8", "ASCII",
               on_invalid_byte: fn event ->
                 send(parent, {:one_shot_ascii_invalid_byte, event})
                 :error
               end
             )

    assert_target_error(one_shot_error, "US-ASCII", 0xE9)
    refute_receive {:one_shot_ascii_invalid_byte, _event}

    for split <- 0..byte_size(input) do
      chunks = [binary_part(input, 0, split), binary_part(input, split, byte_size(input) - split)]

      assert {:ok, stream} =
               Iconvex.stream(chunks, "UTF-8", "ASCII",
                 on_invalid_byte: fn event ->
                   send(parent, {:stream_invalid_byte, split, event})
                   :error
                 end
               )

      stream_error = assert_raise Iconvex.Error, fn -> Enum.to_list(stream) end
      assert_target_error(stream_error, one_shot_error.encoding, one_shot_error.codepoint)
      refute_receive {:stream_invalid_byte, ^split, _event}
    end
  end

  test "one-shot and every stream split reject a two-codepoint unresolved target prefix before a later callback" do
    parent = self()
    input = <<0x1000::utf8, 0x1001::utf8, 0xFF>>

    assert {:error, %Iconvex.Error{} = one_shot_error} =
             Iconvex.convert(input, "UTF-8", ExternalLongPrefix,
               on_invalid_byte: fn event ->
                 send(parent, {:one_shot_long_prefix_invalid_byte, event})
                 :error
               end
             )

    assert_target_error(one_shot_error, ExternalLongPrefix.canonical_name(), 0x1000)
    refute_receive {:one_shot_long_prefix_invalid_byte, _event}

    for split <- 0..byte_size(input) do
      chunks = [binary_part(input, 0, split), binary_part(input, split, byte_size(input) - split)]

      assert {:ok, stream} =
               Iconvex.stream(chunks, "UTF-8", ExternalLongPrefix,
                 on_invalid_byte: fn event ->
                   send(parent, {:stream_long_prefix_invalid_byte, split, event})
                   :error
                 end
               )

      stream_error = assert_raise Iconvex.Error, fn -> Enum.to_list(stream) end

      assert_target_error(
        stream_error,
        ExternalLongPrefix.canonical_name(),
        one_shot_error.codepoint
      )

      refute_receive {:stream_long_prefix_invalid_byte, ^split, _event}
    end
  end

  test "only callbacks chronologically preceding a two-codepoint target prefix run at every split" do
    parent = self()
    input = <<0xFF, 0x1000::utf8, 0x1001::utf8, 0xFE>>

    assert {:error, %Iconvex.Error{} = one_shot_error} =
             Iconvex.convert(input, "UTF-8", ExternalLongPrefix,
               on_invalid_byte: fn event ->
                 send(parent, {:one_shot_ordered_invalid_byte, event.offset})
                 if event.offset == 0, do: {:replace, ?A}, else: :error
               end
             )

    assert_target_error(one_shot_error, ExternalLongPrefix.canonical_name(), 0x1000)
    assert_receive {:one_shot_ordered_invalid_byte, 0}
    refute_receive {:one_shot_ordered_invalid_byte, 7}

    for split <- 0..byte_size(input) do
      chunks = [binary_part(input, 0, split), binary_part(input, split, byte_size(input) - split)]

      assert {:ok, stream} =
               Iconvex.stream(chunks, "UTF-8", ExternalLongPrefix,
                 on_invalid_byte: fn event ->
                   send(parent, {:stream_ordered_invalid_byte, split, event.offset})
                   if event.offset == 0, do: {:replace, ?A}, else: :error
                 end
               )

      stream_error = assert_raise Iconvex.Error, fn -> Enum.to_list(stream) end

      assert_target_error(
        stream_error,
        ExternalLongPrefix.canonical_name(),
        one_shot_error.codepoint
      )

      assert_receive {:stream_ordered_invalid_byte, ^split, 0}
      refute_receive {:stream_ordered_invalid_byte, ^split, 7}
    end
  end

  defp assert_target_error(error, encoding, codepoint) do
    assert error.kind == :unrepresentable_character
    assert error.encoding == encoding
    assert error.codepoint == codepoint
  end

  defp reductions(function) do
    {:reductions, before_reductions} = Process.info(self(), :reductions)
    result = function.()
    {:reductions, after_reductions} = Process.info(self(), :reductions)
    {result, after_reductions - before_reductions}
  end
end

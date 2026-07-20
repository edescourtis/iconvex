defmodule Iconvex.CoverageGapStatelessCodec do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-COVERAGE-GAP-STATELESS"

  @impl true
  def decode(input), do: {:ok, :binary.bin_to_list(input)}

  @impl true
  def decode_discard(input), do: decode(input)

  @impl true
  def encode(codepoints) do
    case Enum.find(codepoints, &(&1 > 0xFF)) do
      nil -> {:ok, :erlang.list_to_binary(codepoints)}
      codepoint -> {:error, :unrepresentable_character, codepoint}
    end
  end

  @impl true
  def encode_discard(codepoints),
    do: {:ok, codepoints |> Enum.filter(&(&1 <= 0xFF)) |> :erlang.list_to_binary()}

  @impl true
  def encode_substitute(codepoints, replacer), do: substitute_bytes(codepoints, replacer, [])

  @impl true
  def decode_chunk(<<"S">>, _final?), do: {:error, :invalid_sequence, 0, "XX"}
  def decode_chunk(<<"F">>, _final?), do: {:error, :invalid_sequence, 99, "F"}
  def decode_chunk(<<"I">>, _final?), do: {:error, :invalid_sequence, 0, "I"}
  def decode_chunk(<<"R">>, _final?), do: {:error, :test_failure, 0, "R"}
  def decode_chunk(<<"M">>, _final?), do: :malformed
  def decode_chunk(input, _final?), do: {:ok, :binary.bin_to_list(input), <<>>}

  @impl true
  def decode_error_consumption(_kind, "XX"), do: 2
  def decode_error_consumption(_kind, _sequence), do: 1

  @impl true
  def encode_chunk(codepoints, _final?, _policy) do
    case encode(codepoints) do
      {:ok, output} -> {:ok, output, []}
      error -> error
    end
  end

  defp substitute_bytes([], _replacer, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp substitute_bytes([codepoint | rest], replacer, acc) when codepoint <= 0xFF,
    do: substitute_bytes(rest, replacer, [<<codepoint>> | acc])

  defp substitute_bytes([codepoint | rest], replacer, acc) do
    case encode(replacer.(codepoint)) do
      {:ok, replacement} -> substitute_bytes(rest, replacer, [replacement | acc])
      error -> error
    end
  end
end

defmodule Iconvex.CoverageGapNoStreamCodec do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-COVERAGE-GAP-NO-STREAM"

  @impl true
  def decode(input), do: {:ok, :binary.bin_to_list(input)}

  @impl true
  def decode_discard(input), do: decode(input)

  @impl true
  def encode(codepoints), do: {:ok, :erlang.list_to_binary(codepoints)}

  @impl true
  def encode_discard(codepoints), do: encode(codepoints)

  @impl true
  def encode_substitute(codepoints, replacer), do: substitute_bytes(codepoints, replacer, [])

  defp substitute_bytes([], _replacer, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp substitute_bytes([codepoint | rest], replacer, acc) when codepoint <= 0xFF,
    do: substitute_bytes(rest, replacer, [<<codepoint>> | acc])

  defp substitute_bytes([codepoint | rest], replacer, acc) do
    case encode(replacer.(codepoint)) do
      {:ok, replacement} -> substitute_bytes(rest, replacer, [replacement | acc])
      error -> error
    end
  end
end

defmodule Iconvex.CoverageGapPrefixCodec do
  use Iconvex.Codec

  @prefix 0x1000
  @suffix 0x1001

  @impl true
  def canonical_name, do: "X-COVERAGE-GAP-PREFIX"

  @impl true
  def decode("x"), do: {:ok, [@prefix, @suffix]}
  def decode(input), do: {:error, :invalid_sequence, 0, input}

  @impl true
  def decode_discard("x"), do: {:ok, [@prefix, @suffix]}
  def decode_discard(_input), do: {:ok, []}

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
  def encode_substitute(codepoints, replacer), do: encode_substitute(codepoints, replacer, [])

  @impl true
  def encode_from_utf8(input) do
    case :unicode.characters_to_list(input) do
      codepoints when is_list(codepoints) ->
        encode(codepoints)

      {kind, codepoints, rest} when kind in [:error, :incomplete] ->
        case encode(codepoints) do
          {:error, :unrepresentable_character, _codepoint} = error ->
            error

          {:ok, _output} ->
            offset = byte_size(input) - byte_size(rest)
            sequence = binary_part(rest, 0, min(1, byte_size(rest)))
            decode_kind = if kind == :error, do: :invalid_sequence, else: :incomplete_sequence
            {:decode_error, decode_kind, offset, sequence}
        end
    end
  end

  @impl true
  def decode_chunk(input, _final?), do: {:ok, :binary.bin_to_list(input), <<>>}

  @impl true
  def encode_chunk([@prefix], false, _policy), do: {:ok, <<>>, [@prefix]}

  def encode_chunk([@prefix, @suffix | rest], final?, policy),
    do: prepend_encoded("x", encode_chunk(rest, final?, policy))

  def encode_chunk([@prefix | rest], final?, :discard),
    do: encode_chunk(rest, final?, :discard)

  def encode_chunk([@prefix | _rest], _final?, :error),
    do: {:error, :unrepresentable_character, @prefix}

  def encode_chunk([], _final?, _policy), do: {:ok, <<>>, []}

  defp encode_substitute([], _replacer, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute([@prefix, @suffix | rest], replacer, acc),
    do: encode_substitute(rest, replacer, ["x" | acc])

  defp encode_substitute([codepoint | rest], replacer, acc) do
    case encode(replacer.(codepoint)) do
      {:ok, replacement} -> encode_substitute(rest, replacer, [replacement | acc])
      error -> error
    end
  end

  defp prepend_encoded(prefix, {:ok, output, pending}), do: {:ok, prefix <> output, pending}
  defp prepend_encoded(_prefix, error), do: error
end

defmodule Iconvex.CoverageGapMalformedFastPathCodec do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-COVERAGE-GAP-MALFORMED-FAST-PATH"

  @impl true
  def decode(input), do: {:ok, :binary.bin_to_list(input)}

  @impl true
  def decode_discard(input), do: decode(input)

  @impl true
  def encode(codepoints) do
    case Enum.find(codepoints, &(&1 > 0xFF)) do
      nil -> {:ok, :erlang.list_to_binary(codepoints)}
      codepoint -> {:error, :unrepresentable_character, codepoint}
    end
  end

  @impl true
  def encode_discard(codepoints),
    do: {:ok, codepoints |> Enum.filter(&(&1 <= 0xFF)) |> :erlang.list_to_binary()}

  @impl true
  def encode_substitute(codepoints, replacer), do: substitute_bytes(codepoints, replacer, [])

  @impl true
  def encode_from_utf8(_input), do: {:error, :unrepresentable_character, -1}

  @impl true
  def decode_chunk(input, _final?), do: {:ok, :binary.bin_to_list(input), <<>>}

  @impl true
  def encode_chunk(codepoints, _final?, _policy) do
    case encode(codepoints) do
      {:ok, output} -> {:ok, output, []}
      error -> error
    end
  end

  defp substitute_bytes([], _replacer, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp substitute_bytes([codepoint | rest], replacer, acc) when codepoint <= 0xFF,
    do: substitute_bytes(rest, replacer, [<<codepoint>> | acc])

  defp substitute_bytes([codepoint | rest], replacer, acc) do
    case encode(replacer.(codepoint)) do
      {:ok, replacement} -> substitute_bytes(rest, replacer, [replacement | acc])
      error -> error
    end
  end
end

defmodule Iconvex.CoverageGapStatefulDirectCodec do
  use Iconvex.Codec

  @prefix 0x1000

  @impl true
  def canonical_name, do: "X-COVERAGE-GAP-STATEFUL-DIRECT"

  @impl true
  def stateful?, do: true

  @impl true
  def decode(input), do: {:ok, :binary.bin_to_list(input)}

  @impl true
  def decode_discard(input), do: decode(input)

  @impl true
  def encode(codepoints) do
    count(:fallback_encode)
    encode_all(codepoints, :base, [])
  end

  @impl true
  def encode_discard(codepoints), do: encode(codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: encode_substitute(codepoints, :base, replacer, [])

  @impl true
  def encode_from_utf8(input) do
    count(:direct_encode)
    encode_utf8(input, :base, 0, [])
  end

  def clear_calls do
    Process.delete({__MODULE__, :direct_encode})
    Process.delete({__MODULE__, :fallback_encode})
  end

  def calls(call), do: Process.get({__MODULE__, call}, 0)

  @impl true
  def stream_decoder_init, do: nil

  @impl true
  def decode_chunk(input, state, _final?),
    do: {:ok, :binary.bin_to_list(input), state, <<>>}

  @impl true
  def stream_encoder_init, do: :base

  @impl true
  def encode_chunk(codepoints, state, final?, _policy),
    do: encode_stream(codepoints, state, final?, [])

  defp encode_all([], _state, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_all([codepoint | rest], state, acc) do
    case encode_one(codepoint, state) do
      {:ok, byte, next_state} -> encode_all(rest, next_state, [byte | acc])
      error -> error
    end
  end

  defp encode_substitute([], _state, _replacer, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute([codepoint | rest], state, replacer, acc) do
    case encode_one(codepoint, state) do
      {:ok, byte, next_state} ->
        encode_substitute(rest, next_state, replacer, [byte | acc])

      {:error, :unrepresentable_character, ^codepoint} ->
        case encode_replacement(replacer.(codepoint), state, []) do
          {:ok, replacement, next_state} ->
            encode_substitute(rest, next_state, replacer, [replacement | acc])

          error ->
            error
        end
    end
  end

  defp encode_replacement([], state, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary(), state}

  defp encode_replacement([codepoint | rest], state, acc) do
    case encode_one(codepoint, state) do
      {:ok, byte, next_state} -> encode_replacement(rest, next_state, [byte | acc])
      error -> error
    end
  end

  defp encode_stream([], state, _final?, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary(), state, []}

  defp encode_stream([@prefix], state, false, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary(), state, [@prefix]}

  defp encode_stream([codepoint | rest], state, final?, acc) do
    case encode_one(codepoint, state) do
      {:ok, byte, next_state} -> encode_stream(rest, next_state, final?, [byte | acc])
      error -> error
    end
  end

  defp encode_utf8(<<>>, _state, _offset, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_utf8(<<codepoint::utf8, rest::binary>>, state, offset, acc) do
    case encode_one(codepoint, state) do
      {:ok, byte, next_state} ->
        encoded_size = byte_size(<<codepoint::utf8>>)
        encode_utf8(rest, next_state, offset + encoded_size, [byte | acc])

      error ->
        error
    end
  end

  defp encode_utf8(input, _state, offset, _acc),
    do: {:decode_error, :invalid_sequence, offset, binary_part(input, 0, 1)}

  defp encode_one(?A, _state), do: {:ok, ?A, :armed}
  defp encode_one(@prefix, :base), do: {:ok, ?x, :base}
  defp encode_one(@prefix, :armed), do: {:error, :unrepresentable_character, @prefix}
  defp encode_one(codepoint, state) when codepoint in 0..0xFF, do: {:ok, codepoint, state}
  defp encode_one(codepoint, _state), do: {:error, :unrepresentable_character, codepoint}

  defp count(call), do: Process.put({__MODULE__, call}, calls(call) + 1)
end

defmodule Iconvex.CoverageGapISOUNicodeStreamTest do
  use ExUnit.Case, async: false

  alias Iconvex.{
    CoverageGapNoStreamCodec,
    CoverageGapStatelessCodec,
    ISO2022CNCodec,
    ISO2022CNEncoder,
    ISO2022JPCodec,
    ISO2022JPEncoder,
    UnicodeCodec
  }

  setup_all do
    Iconvex.unregister_codec(CoverageGapStatelessCodec)
    Iconvex.unregister_codec(CoverageGapNoStreamCodec)
    Iconvex.unregister_codec(Iconvex.CoverageGapPrefixCodec)
    Iconvex.unregister_codec(Iconvex.CoverageGapMalformedFastPathCodec)
    Iconvex.unregister_codec(Iconvex.CoverageGapStatefulDirectCodec)
    assert :ok = Iconvex.register_codec(CoverageGapStatelessCodec)
    assert :ok = Iconvex.register_codec(CoverageGapNoStreamCodec)
    assert :ok = Iconvex.register_codec(Iconvex.CoverageGapPrefixCodec)
    assert :ok = Iconvex.register_codec(Iconvex.CoverageGapMalformedFastPathCodec)
    assert :ok = Iconvex.register_codec(Iconvex.CoverageGapStatefulDirectCodec)

    on_exit(fn ->
      Iconvex.unregister_codec(CoverageGapStatelessCodec)
      Iconvex.unregister_codec(CoverageGapNoStreamCodec)
      Iconvex.unregister_codec(Iconvex.CoverageGapPrefixCodec)
      Iconvex.unregister_codec(Iconvex.CoverageGapMalformedFastPathCodec)
      Iconvex.unregister_codec(Iconvex.CoverageGapStatefulDirectCodec)
    end)

    :ok
  end

  test "stream reports an earlier unresolved target prefix before a later malformed source byte" do
    prefix = <<0x1000::utf8>>

    assert {:ok, stream} =
             Iconvex.stream([prefix, <<0xFF>>], "UTF-8", "X-COVERAGE-GAP-PREFIX")

    error = assert_raise Iconvex.Error, fn -> Enum.to_list(stream) end
    assert error.kind == :unrepresentable_character
    assert error.encoding == "X-COVERAGE-GAP-PREFIX"
    assert error.codepoint == 0x1000
  end

  test "stream reports a same-chunk target prefix before a later malformed source byte" do
    input = <<0x1000::utf8, 0xFF>>

    assert {:error,
            %Iconvex.Error{
              kind: :unrepresentable_character,
              encoding: "X-COVERAGE-GAP-PREFIX",
              codepoint: 0x1000
            }} = Iconvex.convert(input, "UTF-8", "X-COVERAGE-GAP-PREFIX")

    assert {:ok, stream} = Iconvex.stream([input], "UTF-8", "X-COVERAGE-GAP-PREFIX")

    error = assert_raise Iconvex.Error, fn -> Enum.to_list(stream) end
    assert error.kind == :unrepresentable_character
    assert error.encoding == "X-COVERAGE-GAP-PREFIX"
    assert error.codepoint == 0x1000
  end

  test "an unresolved target prefix suppresses a later invalid-byte callback" do
    parent = self()
    input = <<0x1000::utf8, 0xFF>>

    result =
      Iconvex.convert(input, "UTF-8", "X-COVERAGE-GAP-PREFIX",
        on_invalid_byte: fn event ->
          send(parent, {:invalid_byte, event})
          {:replace, 0x1001}
        end
      )

    refute_receive {:invalid_byte, _event}

    assert {:error,
            %Iconvex.Error{
              kind: :unrepresentable_character,
              encoding: "X-COVERAGE-GAP-PREFIX",
              codepoint: 0x1000
            }} = result
  end

  test "stream callback arbitration finalizes an unresolved target prefix at every split" do
    parent = self()
    input = <<0x1000::utf8, 0xFF>>

    for split <- 0..byte_size(input) do
      chunks = [binary_part(input, 0, split), binary_part(input, split, byte_size(input) - split)]

      assert {:ok, stream} =
               Iconvex.stream(chunks, "UTF-8", "X-COVERAGE-GAP-PREFIX",
                 on_invalid_byte: fn event ->
                   send(parent, {:stream_invalid_byte, split, event})
                   {:replace, 0x1001}
                 end
               )

      error = assert_raise Iconvex.Error, fn -> Enum.to_list(stream) end
      assert error.kind == :unrepresentable_character
      assert error.encoding == "X-COVERAGE-GAP-PREFIX"
      assert error.codepoint == 0x1000
      refute_receive {:stream_invalid_byte, ^split, _event}
    end
  end

  test "stream falls back to target chronology when a declared direct callback misses" do
    input = <<0x1000::utf8, 0xFF>>
    target = "X-COVERAGE-GAP-MALFORMED-FAST-PATH"

    assert {:error,
            %Iconvex.Error{
              kind: :unrepresentable_character,
              encoding: ^target,
              codepoint: 0x1000
            }} = Iconvex.convert(input, "UTF-8", target)

    assert {:ok, stream} = Iconvex.stream([input], "UTF-8", target)

    error = assert_raise Iconvex.Error, fn -> Enum.to_list(stream) end
    assert error.kind == :unrepresentable_character
    assert error.encoding == target
    assert error.codepoint == 0x1000
  end

  test "stateful direct targets preserve an earlier target error before malformed UTF-8" do
    stable = "A" <> <<0x1000::utf8>>
    input = stable <> <<0xFF>>
    target = "X-COVERAGE-GAP-STATEFUL-DIRECT"

    assert {:error,
            %Iconvex.Error{
              kind: :unrepresentable_character,
              encoding: ^target,
              codepoint: 0x1000
            }} = Iconvex.convert(input, "UTF-8", target)

    assert {:ok, stream} = Iconvex.stream([stable, <<0xFF>>], "UTF-8", target)

    error = assert_raise Iconvex.Error, fn -> Enum.to_list(stream) end
    assert error.kind == :unrepresentable_character
    assert error.encoding == target
    assert error.codepoint == 0x1000

    Iconvex.CoverageGapStatefulDirectCodec.clear_calls()
    assert {:ok, "A"} = Iconvex.convert("A", "UTF-8", target)
    assert Iconvex.CoverageGapStatefulDirectCodec.calls(:direct_encode) == 1
    assert Iconvex.CoverageGapStatefulDirectCodec.calls(:fallback_encode) == 0
  end

  test "Unicode substitution handles valid scalars, replacements, and invalid replacements" do
    utf8 = %{id: :utf8}

    assert {:ok, "AxB"} =
             UnicodeCodec.encode_substitute(utf8, [?A, 0x110000, ?B], fn _ -> [?x] end)

    assert {:ok, <<>>} =
             UnicodeCodec.encode_substitute(utf8, [0x110000], fn _ -> [] end)

    assert {:error, :unrepresentable_character, 0x110000} =
             UnicodeCodec.encode_substitute(utf8, [0x110000], fn _ -> [0x110000] end)

    assert {:ok, utf16} =
             UnicodeCodec.encode_substitute(%{id: :utf16}, [?A, 0x1F600, 0x110000], fn _ ->
               [?x]
             end)

    assert {:ok, [?A, 0x1F600, ?x]} = UnicodeCodec.decode(%{id: :utf16}, utf16)

    assert {:ok, utf32} =
             UnicodeCodec.encode_substitute(%{id: :utf32}, [?A, 0x110000], fn _ -> [?x] end)

    assert {:ok, [?A, ?x]} = UnicodeCodec.decode(%{id: :utf32}, utf32)
  end

  test "Unicode replacement decoders cover surrogates, BOMs, UCS-4, and stream offsets" do
    assert {:ok, [0x1F600]} =
             UnicodeCodec.decode_substitute(
               %{id: :utf16be},
               <<0xD8, 0x3D, 0xDE, 0x00>>,
               fn _ -> [?x] end
             )

    assert {:ok, [?A]} =
             UnicodeCodec.decode_discard(%{id: :utf32}, <<0, 0, 0xFE, 0xFF, 0, 0, 0, ?A>>)

    assert {:ok, [0x110000]} =
             UnicodeCodec.decode_discard(%{id: :ucs4be}, <<0, 0x11, 0, 0>>)

    assert {:error, :invalid_sequence, 0, <<0xDC, 0>>} =
             UnicodeCodec.decode_chunk(
               %{id: :utf16},
               <<0xDC, 0>>,
               {:unicode16, :big},
               true
             )
  end

  test "ISO-2022-JP streaming covers G2 reuse, tags, and every encode policy" do
    entry = %{id: :iso2022_jp2}
    g2_codepoint = jp_g2_codepoint()
    state = ISO2022JPCodec.stream_encode_init(entry)

    assert {:ok, encoded, {:jp, :ascii, _g2}, []} =
             ISO2022JPCodec.encode_chunk(
               entry,
               [0xE0001, g2_codepoint, g2_codepoint, 0xE007F, ?A],
               state,
               true,
               :error
             )

    assert {:ok, [^g2_codepoint, ^g2_codepoint, ?A]} = ISO2022JPCodec.decode(entry, encoded)

    assert {:error, :unrepresentable_character, 0x110000} =
             ISO2022JPCodec.encode_chunk(entry, [0x110000], state, true, :error)

    assert {:ok, "A", {:jp, :ascii, nil}, []} =
             ISO2022JPCodec.encode_chunk(entry, [0x110000, ?A], state, true, :discard)

    assert {:ok, "xA", {:jp, :ascii, nil}, []} =
             ISO2022JPCodec.encode_chunk(
               entry,
               [0x110000, ?A],
               state,
               true,
               {:replace, fn _ -> [?x] end}
             )

    assert {:error, :unrepresentable_character, 0x110000} =
             ISO2022JPCodec.encode_chunk(
               entry,
               [0x110000],
               state,
               true,
               {:replace, fn _ -> [0x110000] end}
             )
  end

  test "ISO-2022-JP substitution covers G2 reuse, language tags, and replacement failure" do
    entry = %{id: :iso2022_jp2}
    g2_codepoint = jp_g2_codepoint()

    assert {:ok, encoded} =
             ISO2022JPCodec.encode_substitute(
               entry,
               [0xE0001, g2_codepoint, g2_codepoint, 0xE007F],
               fn _ -> [?x] end
             )

    assert {:ok, [^g2_codepoint, ^g2_codepoint]} = ISO2022JPCodec.decode(entry, encoded)

    assert {:error, :unrepresentable_character, 0x110000} =
             ISO2022JPCodec.encode_substitute(entry, [0x110000], fn _ -> [0x110000] end)
  end

  test "ISO-2022-JP-MS rejects holes and out-of-range pairs in both planes" do
    entry = %{id: :iso2022_jpms}

    assert {:error, :invalid_sequence, 3, <<0x2D, 0x3F>>} =
             ISO2022JPCodec.decode(entry, <<0x1B, "$B", 0x2D, 0x3F>>)

    assert {:error, :invalid_sequence, 4, <<0x73, 0x2B>>} =
             ISO2022JPCodec.decode(entry, <<0x1B, "$(D", 0x73, 0x2B>>)

    assert {:error, :invalid_sequence, 3, <<0, 0>>} =
             ISO2022JPCodec.decode(entry, <<0x1B, "$B", 0, 0>>)

    assert {:error, :invalid_sequence, 4, <<0, 0>>} =
             ISO2022JPCodec.decode(entry, <<0x1B, "$(D", 0, 0>>)
  end

  test "ISO-2022-CN streaming covers G2, G3, replacement resume, and every policy" do
    entry = %{id: :iso2022_cn_ext}
    g2_codepoint = cn_codepoint(fn action -> match?({:g2, 2, _pair}, action) end)
    g3_codepoint = cn_codepoint(fn action -> match?({:g3, 3, _pair}, action) end)
    state = ISO2022CNCodec.stream_encode_init(entry)

    assert {:ok, encoded, {:cn, :ascii, nil, 2, 3}, []} =
             ISO2022CNCodec.encode_chunk(
               entry,
               [g2_codepoint, g2_codepoint, g3_codepoint, g3_codepoint],
               state,
               true,
               :error
             )

    assert {:ok, [^g2_codepoint, ^g2_codepoint, ^g3_codepoint, ^g3_codepoint]} =
             ISO2022CNCodec.decode(entry, encoded)

    assert {:error, :unrepresentable_character, 0x110000} =
             ISO2022CNCodec.encode_chunk(entry, [0x110000], state, true, :error)

    assert {:ok, "A", {:cn, :ascii, nil, nil, nil}, []} =
             ISO2022CNCodec.encode_chunk(entry, [0x110000, ?A], state, true, :discard)

    assert {:ok, "xA", {:cn, :ascii, nil, nil, nil}, []} =
             ISO2022CNCodec.encode_chunk(
               entry,
               [0x110000, ?A],
               state,
               true,
               {:replace, fn _ -> [?x] end}
             )

    assert {:error, :unrepresentable_character, 0x110000} =
             ISO2022CNCodec.encode_chunk(
               entry,
               [0x110000],
               state,
               true,
               {:replace, fn _ -> [0x110000] end}
             )
  end

  test "ISO-2022-CN substitution covers repeated G2/G3 designations and replacement failure" do
    entry = %{id: :iso2022_cn_ext}
    g2_codepoint = cn_codepoint(fn action -> match?({:g2, 2, _pair}, action) end)
    g3_codepoint = cn_codepoint(fn action -> match?({:g3, 3, _pair}, action) end)

    assert {:ok, encoded} =
             ISO2022CNCodec.encode_substitute(
               entry,
               [g2_codepoint, g2_codepoint, g3_codepoint, g3_codepoint],
               fn _ -> [?x] end
             )

    assert {:ok, [^g2_codepoint, ^g2_codepoint, ^g3_codepoint, ^g3_codepoint]} =
             ISO2022CNCodec.decode(entry, encoded)

    assert {:error, :unrepresentable_character, 0x110000} =
             ISO2022CNCodec.encode_substitute(entry, [0x110000], fn _ -> [0x110000] end)
  end

  test "ISO-2022-CN malformed G1/G2/G3 and truncated pairs obey strict and replacement policies" do
    cn = %{id: :iso2022_cn}
    ext = %{id: :iso2022_cn_ext}

    assert {:error, :invalid_sequence, 5, <<0, 0>>} =
             ISO2022CNCodec.decode(cn, <<0x1B, "$)A", 0x0E, 0, 0>>)

    invalid_g2 = <<0x1B, "$*H", 0x1B, ?N, 0, 0>>
    assert {:ok, [?N, 0, 0]} = ISO2022CNCodec.decode_discard(cn, invalid_g2)

    assert {:ok, [?x, ?N, 0, 0]} =
             ISO2022CNCodec.decode_substitute(cn, invalid_g2, fn _ -> [?x] end)

    invalid_g3 = <<0x1B, "$+I", 0x1B, ?O, 0, 0>>
    assert {:ok, [?O, 0, 0]} = ISO2022CNCodec.decode_discard(ext, invalid_g3)

    assert {:ok, [?x, ?O, 0, 0]} =
             ISO2022CNCodec.decode_substitute(ext, invalid_g3, fn _ -> [?x] end)

    truncated = <<0x1B, "$)A", 0x0E, 0x21>>
    assert {:ok, []} = ISO2022CNCodec.decode_discard(cn, truncated)
    assert {:ok, [?x]} = ISO2022CNCodec.decode_substitute(cn, truncated, fn _ -> [?x] end)

    {ir_codepoint, {:g1, :iso_ir_165, ir_pair}} =
      Enum.find(ISO2022CNEncoder.fetch(:iso2022_cn_ext), fn
        {_codepoint, {:g1, :iso_ir_165, _pair}} -> true
        _other -> false
      end)

    assert {:ok, [^ir_codepoint]} =
             ISO2022CNCodec.decode_discard(ext, <<0x1B, "$)E", 0x0E, ir_pair::binary, 0x0F>>)
  end

  test "Stream opts stateless external codecs in and rejects missing callbacks" do
    assert {:error, {:streaming_unsupported, :source, "X-COVERAGE-GAP-NO-STREAM"}} =
             Iconvex.stream([], CoverageGapNoStreamCodec, "UTF-8")

    assert {:error, {:streaming_unsupported, :target, "X-COVERAGE-GAP-NO-STREAM"}} =
             Iconvex.stream([], "UTF-8", CoverageGapNoStreamCodec)

    assert "ABC" ==
             ["ABC"]
             |> Iconvex.stream!(CoverageGapStatelessCodec, CoverageGapStatelessCodec)
             |> Enum.join()
  end

  test "Stream normalizes external decoder failures and invalid callback results" do
    short =
      assert_raise Iconvex.Error, fn ->
        ["S"]
        |> Iconvex.stream!(CoverageGapStatelessCodec, "UTF-8")
        |> Enum.to_list()
      end

    assert short.kind == :invalid_sequence
    assert short.offset == 0
    assert short.sequence == "XX"

    far =
      assert_raise Iconvex.Error, fn ->
        ["F"]
        |> Iconvex.stream!(CoverageGapStatelessCodec, "UTF-8")
        |> Enum.to_list()
      end

    assert far.offset == 99

    raw =
      assert_raise Iconvex.Error, fn ->
        ["R"]
        |> Iconvex.stream!(CoverageGapStatelessCodec, "UTF-8")
        |> Enum.to_list()
      end

    assert raw.kind == :test_failure

    assert_raise ArgumentError, ~r/invalid streaming codec result: :malformed/, fn ->
      ["M"]
      |> Iconvex.stream!(CoverageGapStatelessCodec, "UTF-8")
      |> Enum.to_list()
    end

    assert_raise ArgumentError, ~r/invalid streaming callback result/, fn ->
      ["I"]
      |> Iconvex.stream!(CoverageGapStatelessCodec, "UTF-8",
        on_invalid_byte: fn _event -> :not_a_valid_result end
      )
      |> Enum.to_list()
    end
  end

  test "Stream rejects non-binaries and raises normalized target errors" do
    assert_raise ArgumentError, ~r/stream input enumerable must emit binaries/, fn ->
      [123]
      |> Iconvex.stream!("UTF-8", "UTF-8")
      |> Enum.to_list()
    end

    assert [<<0xFF, 0xFD>>] =
             "😀"
             |> List.wrap()
             |> Iconvex.stream!("UTF-8", "UCS-2BE")
             |> Enum.to_list()

    for target <- ["ASCII", CoverageGapStatelessCodec] do
      error =
        assert_raise Iconvex.Error, fn ->
          ["😀"]
          |> Iconvex.stream!("UTF-8", target)
          |> Enum.to_list()
        end

      assert error.kind == :unrepresentable_character
      assert error.codepoint == 0x1F600
    end
  end

  test "Stream computes local offsets for a strict built-in stateful source error" do
    error =
      assert_raise Iconvex.Error, fn ->
        [<<0x0E>>]
        |> Iconvex.stream!("ISO-2022-CN", "UTF-8")
        |> Enum.to_list()
      end

    assert error.kind == :invalid_sequence
    assert error.offset == 0
    assert error.sequence == <<0x0E>>
  end

  defp jp_g2_codepoint do
    {codepoint, _action} =
      Enum.find(ISO2022JPEncoder.fetch(:iso2022_jp2).singles, fn
        {_codepoint, {:g2, _id, _byte}} -> true
        _other -> false
      end)

    codepoint
  end

  defp cn_codepoint(predicate) do
    {codepoint, _action} =
      Enum.find(ISO2022CNEncoder.fetch(:iso2022_cn_ext), fn {_codepoint, action} ->
        predicate.(action)
      end)

    codepoint
  end
end

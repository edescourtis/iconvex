defmodule Iconvex.ExternalCodecTest.ROT13 do
  @behaviour Iconvex.Codec

  def canonical_name, do: "X-ROT13"
  def aliases, do: ["ROT13"]
  def stateful?, do: false

  def decode(input) do
    mark(:decode)
    decode_raw(input, 0, [])
  end

  def decode_discard(input) do
    mark(:decode_discard)

    output =
      for <<byte <- input>>, byte < 0x80 do
        rotate(byte)
      end

    {:ok, output}
  end

  def encode(codepoints) do
    mark(:encode)
    encode_raw(codepoints, [])
  end

  def encode_discard(codepoints) do
    mark(:encode_discard)

    output =
      codepoints
      |> Enum.flat_map(fn codepoint -> if codepoint < 0x80, do: [rotate(codepoint)], else: [] end)
      |> :erlang.list_to_binary()

    {:ok, output}
  end

  def encode_substitute(codepoints, replacer) do
    mark(:encode_substitute)
    encode_substitute_raw(codepoints, replacer, [])
  end

  def decode_to_utf8(input) do
    mark(:decode_to_utf8)

    with {:ok, codepoints} <- decode_raw(input, 0, []) do
      {:ok, List.to_string(codepoints)}
    end
  end

  def encode_from_utf8(input) do
    mark(:encode_from_utf8)

    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) -> encode_raw(codepoints, [])
      {:error, _converted, rest} -> {:decode_error, :invalid_sequence, 0, rest}
      {:incomplete, _converted, rest} -> {:decode_error, :incomplete_sequence, 0, rest}
    end
  end

  def decode_to_ucs4_discard(input, endian) do
    mark(:decode_to_ucs4_discard)

    output =
      for <<byte <- input>>, byte < 0x80, into: <<>> do
        word32(rotate(byte), endian)
      end

    {:ok, output}
  end

  def encode_from_ucs4_discard(input, endian) when rem(byte_size(input), 4) == 0 do
    mark(:encode_from_ucs4_discard)
    {:ok, encode_ucs4_discard(input, endian, [])}
  end

  def encode_from_ucs4_discard(_input, _endian) do
    mark(:encode_from_ucs4_discard)
    :miss
  end

  def calls, do: Process.get({__MODULE__, :calls}, [])
  def clear_calls, do: Process.delete({__MODULE__, :calls})

  defp decode_raw(<<>>, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_raw(<<byte, rest::binary>>, offset, acc) when byte < 0x80,
    do: decode_raw(rest, offset + 1, [rotate(byte) | acc])

  defp decode_raw(<<byte, _rest::binary>>, offset, _acc),
    do: {:error, :invalid_sequence, offset, <<byte>>}

  defp encode_raw([], acc), do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_raw([codepoint | rest], acc) when codepoint < 0x80,
    do: encode_raw(rest, [rotate(codepoint) | acc])

  defp encode_raw([codepoint | _rest], _acc),
    do: {:error, :unrepresentable_character, codepoint}

  defp encode_substitute_raw([], _replacer, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute_raw([codepoint | rest], replacer, acc) when codepoint < 0x80,
    do: encode_substitute_raw(rest, replacer, [<<rotate(codepoint)>> | acc])

  defp encode_substitute_raw([codepoint | rest], replacer, acc) do
    case encode_raw(replacer.(codepoint), []) do
      {:ok, replacement} -> encode_substitute_raw(rest, replacer, [replacement | acc])
      error -> error
    end
  end

  defp rotate(byte) when byte in ?A..?M, do: byte + 13
  defp rotate(byte) when byte in ?N..?Z, do: byte - 13
  defp rotate(byte) when byte in ?a..?m, do: byte + 13
  defp rotate(byte) when byte in ?n..?z, do: byte - 13
  defp rotate(byte), do: byte

  defp encode_ucs4_discard(<<>>, _endian, acc),
    do: acc |> :lists.reverse() |> IO.iodata_to_binary()

  defp encode_ucs4_discard(<<codepoint::unsigned-big-32, rest::binary>>, :big, acc) do
    acc = if codepoint < 0x80, do: [<<rotate(codepoint)>> | acc], else: acc
    encode_ucs4_discard(rest, :big, acc)
  end

  defp encode_ucs4_discard(<<codepoint::unsigned-little-32, rest::binary>>, :little, acc) do
    acc = if codepoint < 0x80, do: [<<rotate(codepoint)>> | acc], else: acc
    encode_ucs4_discard(rest, :little, acc)
  end

  defp word32(codepoint, :big), do: <<codepoint::unsigned-big-32>>
  defp word32(codepoint, :little), do: <<codepoint::unsigned-little-32>>

  defp mark(call), do: Process.put({__MODULE__, :calls}, [call | calls()])
end

defmodule Iconvex.ExternalCodecTest.PairCodec do
  @behaviour Iconvex.Codec

  def canonical_name, do: "X-PAIR"
  def aliases, do: []
  def stateful?, do: true

  def decode(<<>>), do: {:ok, []}
  def decode(<<"AB", rest::binary>>), do: prepend_decode(rest)
  def decode(input), do: {:error, :incomplete_sequence, 0, input}

  def decode_discard(input), do: decode(input)

  def encode(codepoints), do: encode_pairs(codepoints, [])
  def encode_discard(codepoints), do: encode(codepoints)

  def encode_substitute(codepoints, replacer),
    do: encode_substitute_pairs(codepoints, replacer, [])

  def stream_decoder_init, do: nil

  def decode_chunk(input, state, true) do
    case decode(input) do
      {:ok, codepoints} -> {:ok, codepoints, state, <<>>}
      error -> error
    end
  end

  def decode_chunk(input, state, false) do
    stable_size = byte_size(input) - rem(byte_size(input), 2)
    stable = binary_part(input, 0, stable_size)
    pending = binary_part(input, stable_size, byte_size(input) - stable_size)

    case decode(stable) do
      {:ok, codepoints} -> {:ok, codepoints, state, pending}
      error -> error
    end
  end

  def stream_encoder_init, do: nil

  def encode_chunk(codepoints, state, _final?, _policy) do
    case encode(codepoints) do
      {:ok, output} -> {:ok, output, state, []}
      error -> error
    end
  end

  defp prepend_decode(rest) do
    case decode(rest) do
      {:ok, codepoints} -> {:ok, [?x | codepoints]}
      error -> error
    end
  end

  defp encode_pairs([], acc), do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}
  defp encode_pairs([?x | rest], acc), do: encode_pairs(rest, ["AB" | acc])

  defp encode_pairs([codepoint | _rest], _acc),
    do: {:error, :unrepresentable_character, codepoint}

  defp encode_substitute_pairs([], _replacer, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute_pairs([?x | rest], replacer, acc),
    do: encode_substitute_pairs(rest, replacer, ["AB" | acc])

  defp encode_substitute_pairs([codepoint | rest], replacer, acc) do
    case encode_pairs(replacer.(codepoint), []) do
      {:ok, replacement} -> encode_substitute_pairs(rest, replacer, [replacement | acc])
      error -> error
    end
  end
end

defmodule Iconvex.ExternalCodecTest.LegacyEncodeErrorCodec do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-LEGACY-ENCODE-ERROR"

  @impl true
  def decode(input), do: {:ok, :binary.bin_to_list(input)}

  @impl true
  def decode_discard(input), do: decode(input)

  @impl true
  def encode([codepoint | _rest]) do
    count(:fallback_encode)
    {:error, :unrepresentable_character, codepoint}
  end

  def encode([]) do
    count(:fallback_encode)
    {:ok, <<>>}
  end

  @impl true
  def encode_discard(codepoints), do: encode(codepoints)

  @impl true
  def encode_substitute(codepoints, replacer), do: substitute_every(codepoints, replacer, [])

  @impl true
  def encode_from_utf8(input) do
    count(:direct_encode)
    [codepoint | _rest] = String.to_charlist(input)
    {:encode_error, :unrepresentable_character, codepoint}
  end

  def count(call), do: Process.put({__MODULE__, call}, calls(call) + 1)
  def calls(call), do: Process.get({__MODULE__, call}, 0)

  def clear_calls do
    Process.delete({__MODULE__, :direct_encode})
    Process.delete({__MODULE__, :fallback_encode})
  end

  defp substitute_every([], _replacer, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp substitute_every([codepoint | rest], replacer, acc) do
    case encode(replacer.(codepoint)) do
      {:ok, replacement} -> substitute_every(rest, replacer, [replacement | acc])
      error -> error
    end
  end
end

defmodule Iconvex.ExternalCodecTest.InvalidCodec do
  def canonical_name, do: "X-INVALID"
end

defmodule Iconvex.ExternalCodecTest.MissingSubstituteCodec do
  def canonical_name, do: "X-MISSING-SUBSTITUTE"
  def aliases, do: []
  def stateful?, do: false
  def decode(input), do: {:ok, :binary.bin_to_list(input)}
  def decode_discard(input), do: decode(input)
  def encode(codepoints), do: {:ok, :erlang.list_to_binary(codepoints)}
  def encode_discard(codepoints), do: encode(codepoints)
end

defmodule Iconvex.ExternalCodecTest.DuplicateCodec do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "rot13"

  @impl true
  def decode(input), do: Iconvex.ExternalCodecTest.ROT13.decode(input)

  @impl true
  def decode_discard(input), do: Iconvex.ExternalCodecTest.ROT13.decode_discard(input)

  @impl true
  def encode(codepoints), do: Iconvex.ExternalCodecTest.ROT13.encode(codepoints)

  @impl true
  def encode_discard(codepoints), do: Iconvex.ExternalCodecTest.ROT13.encode_discard(codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: Iconvex.ExternalCodecTest.ROT13.encode_substitute(codepoints, replacer)
end

defmodule Iconvex.ExternalCodecTest.BuiltinCollisionCodec do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "UTF-8"

  @impl true
  def aliases, do: ["SOURCE-UTF8"]

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

defmodule Iconvex.ExternalCodecTest.SlashCodec do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X/BAD"

  @impl true
  def decode(_input), do: {:ok, []}

  @impl true
  def decode_discard(_input), do: {:ok, []}

  @impl true
  def encode(_codepoints), do: {:ok, <<>>}

  @impl true
  def encode_discard(_codepoints), do: {:ok, <<>>}

  @impl true
  def encode_substitute(codepoints, _replacer), do: encode(codepoints)
end

defmodule Iconvex.ExternalCodecTest.InvalidRecoveryCodec do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-INVALID-RECOVERY"

  @impl true
  def decode_error_recovery, do: :restart_from_the_middle

  @impl true
  def decode(_input), do: {:ok, []}

  @impl true
  def decode_discard(_input), do: {:ok, []}

  @impl true
  def encode(_codepoints), do: {:ok, <<>>}

  @impl true
  def encode_discard(_codepoints), do: {:ok, <<>>}

  @impl true
  def encode_substitute(codepoints, _replacer), do: encode(codepoints)
end

defmodule Iconvex.ExternalCodecTest.StopRecoveryCodec do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-STOP-RECOVERY"

  @impl true
  def decode_error_recovery, do: :stop

  @impl true
  def decode("a-z!more"), do: {:error, :invalid_sequence, 3, "!"}
  def decode("a-z"), do: {:error, :incomplete_sequence, 2, "z"}
  def decode(input), do: {:ok, :binary.bin_to_list(input)}

  @impl true
  def decode_discard("a-z!more"), do: {:ok, ~c"a"}
  def decode_discard(input), do: decode(input)

  @impl true
  def decode_chunk(input, _final?), do: {:ok, :binary.bin_to_list(input), <<>>}

  @impl true
  def encode(codepoints), do: {:ok, :erlang.list_to_binary(codepoints)}

  @impl true
  def encode_discard(codepoints), do: encode(codepoints)

  @impl true
  def encode_substitute(codepoints, _replacer), do: encode(codepoints)
end

defmodule Iconvex.ExternalCodecTest.DiscardFailureCodec do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-DISCARD-FAILURE"

  @impl true
  def decode(_input), do: {:ok, []}

  @impl true
  def decode_discard(_input), do: {:ok, []}

  @impl true
  def encode([]), do: {:ok, <<>>}
  def encode([codepoint | _rest]), do: {:error, :unrepresentable_character, codepoint}

  @impl true
  def encode_discard([]), do: {:ok, <<>>}
  def encode_discard([codepoint | _rest]), do: {:error, :unrepresentable_character, codepoint}

  @impl true
  def encode_substitute([], _replacer), do: {:ok, <<>>}

  def encode_substitute([codepoint | rest], replacer) do
    case encode(replacer.(codepoint)) do
      {:ok, replacement} ->
        case encode_substitute(rest, replacer) do
          {:ok, output} -> {:ok, replacement <> output}
          error -> error
        end

      error ->
        error
    end
  end
end

defmodule Iconvex.ExternalCodecTest do
  use ExUnit.Case, async: false

  alias Iconvex.ExternalCodecTest.{
    BuiltinCollisionCodec,
    DiscardFailureCodec,
    DuplicateCodec,
    InvalidCodec,
    InvalidRecoveryCodec,
    LegacyEncodeErrorCodec,
    MissingSubstituteCodec,
    PairCodec,
    ROT13,
    SlashCodec,
    StopRecoveryCodec
  }

  setup do
    Iconvex.unregister_codec(ROT13)
    ROT13.clear_calls()
    assert :ok = Iconvex.register_codec(ROT13)

    on_exit(fn ->
      Iconvex.unregister_codec(ROT13)
      Iconvex.unregister_codec(PairCodec)
      Iconvex.unregister_codec(DiscardFailureCodec)
      Iconvex.unregister_codec(BuiltinCollisionCodec)
    end)

    :ok
  end

  test "registers an external codec under canonical, alias, and module names" do
    assert :ok = Iconvex.register_codec(ROT13)
    assert Iconvex.canonical_name("x-rot13") == {:ok, "X-ROT13"}
    assert Iconvex.canonical_name("RoT13") == {:ok, "X-ROT13"}
    assert Iconvex.canonical_name(ROT13) == {:ok, "X-ROT13"}
    assert "X-ROT13" in Iconvex.encodings()
    assert length(Iconvex.encodings()) == 113

    assert :ok = Iconvex.unregister_codec(ROT13)
    assert Iconvex.canonical_name("ROT13") == :error
  end

  test "converts through external codecs and uses their UTF-8 fast paths" do
    assert Iconvex.convert("Uryyb, jbeyq!", "ROT13", "UTF-8") == {:ok, "Hello, world!"}
    assert :decode_to_utf8 in ROT13.calls()
    refute :decode in ROT13.calls()

    ROT13.clear_calls()
    assert Iconvex.convert("Hello, world!", "UTF-8", "X-ROT13") == {:ok, "Uryyb, jbeyq!"}
    assert :encode_from_utf8 in ROT13.calls()
    refute :encode in ROT13.calls()

    assert Iconvex.convert("Uryyb", ROT13, ROT13) == {:ok, "Uryyb"}

    assert {:error,
            %Iconvex.Error{
              kind: :unrepresentable_character,
              encoding: "X-ROT13",
              codepoint: 0x1F600
            }} = Iconvex.convert("😀", "UTF-8", "ROT13")

    assert {:error, %Iconvex.Error{kind: :invalid_sequence, encoding: "X-ROT13", offset: 0}} =
             Iconvex.convert(<<0xFF>>, "ROT13", "UTF-8")

    assert {:error, %Iconvex.Error{kind: :invalid_sequence, encoding: "UTF-8", offset: 0}} =
             Iconvex.convert(<<0xFF>>, "UTF-8", "ROT13")
  end

  test "legacy direct encode errors stay on the fast path without invoking fallback encode" do
    Iconvex.unregister_codec(LegacyEncodeErrorCodec)
    LegacyEncodeErrorCodec.clear_calls()
    assert :ok = Iconvex.register_codec(LegacyEncodeErrorCodec)
    on_exit(fn -> Iconvex.unregister_codec(LegacyEncodeErrorCodec) end)

    assert {:error,
            %Iconvex.Error{
              kind: :unrepresentable_character,
              encoding: "X-LEGACY-ENCODE-ERROR",
              codepoint: 0x2603
            }} = Iconvex.convert("☃", "UTF-8", LegacyEncodeErrorCodec)

    assert LegacyEncodeErrorCodec.calls(:direct_encode) == 1
    assert LegacyEncodeErrorCodec.calls(:fallback_encode) == 0
  end

  test "delegates discard policies to linear codec callbacks" do
    assert Iconvex.convert(<<"Uryyb", 0xFF, "!">>, "ROT13", "UTF-8", invalid: :discard) ==
             {:ok, "Hello!"}

    assert :decode_discard in ROT13.calls()

    ROT13.clear_calls()

    assert Iconvex.convert("Hello😀!", "UTF-8", "ROT13", unrepresentable: :discard) ==
             {:ok, "Uryyb!"}

    assert :encode_discard in ROT13.calls()

    assert :ok = Iconvex.register_codec(DiscardFailureCodec)

    assert {:error,
            %Iconvex.Error{
              kind: :unrepresentable_character,
              encoding: "X-DISCARD-FAILURE",
              codepoint: 0x1F600
            }} =
             Iconvex.convert("😀", "UTF-8", DiscardFailureCodec, unrepresentable: :discard)
  end

  test "valid direct UTF-8 decode feeds explicit UCS-4 without bypassing error recovery" do
    ROT13.clear_calls()

    expected = for codepoint <- ~c"Hello", into: <<>>, do: <<codepoint::unsigned-big-32>>

    assert Iconvex.convert("Uryyb", "ROT13", "UCS-4BE", invalid: :discard) ==
             {:ok, expected}

    assert :decode_to_ucs4_discard in ROT13.calls()
    refute :decode_to_utf8 in ROT13.calls()
    refute :decode_discard in ROT13.calls()

    ROT13.clear_calls()

    assert Iconvex.convert(<<"Uryyb", 0xFF, "!">>, "ROT13", "UCS-4BE", invalid: :discard) ==
             {:ok, expected <> <<?!::unsigned-big-32>>}

    assert :decode_to_ucs4_discard in ROT13.calls()
    refute :decode_to_utf8 in ROT13.calls()
    refute :decode_discard in ROT13.calls()

    ROT13.clear_calls()
    parent = self()

    assert Iconvex.convert(<<"Uryyb", 0xFF>>, "ROT13", "UCS-4BE",
             invalid: :discard,
             on_invalid_byte: fn event ->
               send(parent, {:invalid, event})
               {:replace, ??}
             end
           ) == {:ok, expected <> <<??::unsigned-big-32>>}

    refute :decode_to_utf8 in ROT13.calls()
    refute :decode_discard in ROT13.calls()
    assert :decode in ROT13.calls()
    assert_receive {:invalid, %Iconvex.InvalidByte{offset: 5, byte: 0xFF}}
  end

  test "explicit UCS-4 discard uses an external codec's direct encoder callback" do
    ROT13.clear_calls()

    source = <<?H::unsigned-big-32, 0x1F600::unsigned-big-32, ?i::unsigned-big-32>>

    assert Iconvex.convert(source, "UCS-4BE", ROT13, unrepresentable: :discard) ==
             {:ok, "Uv"}

    assert :encode_from_ucs4_discard in ROT13.calls()
    refute :encode_discard in ROT13.calls()
    refute :encode in ROT13.calls()
  end

  test "buffers an external stateful source until finish" do
    assert :ok = Iconvex.register_codec(PairCodec, aliases: ["PAIR"])
    assert Iconvex.canonical_name("pair") == {:ok, "X-PAIR"}
    assert {:ok, converter} = Iconvex.new("X-PAIR", "UTF-8")
    assert {:ok, <<>>, converter} = Iconvex.feed(converter, "A")
    assert {:ok, <<>>, converter} = Iconvex.feed(converter, "B")
    assert {:ok, "x"} = Iconvex.finish(converter)
  end

  test "streams an external stateful codec through explicit state callbacks" do
    assert :ok = Iconvex.register_codec(PairCodec, aliases: ["PAIR"])

    assert ["A", "B"]
           |> Iconvex.stream!("PAIR", "UTF-8")
           |> Enum.join() == "x"

    assert ["x"]
           |> Iconvex.stream!("UTF-8", "PAIR")
           |> Enum.join() == "AB"
  end

  test "rejects incomplete codecs and all built-in name collisions" do
    assert {:error, {:invalid_codec, _reason}} = Iconvex.register_codec(InvalidCodec)

    assert {:error, {:invalid_codec, {:missing_callback, {:encode_substitute, 2}}}} =
             Iconvex.register_codec(MissingSubstituteCodec)

    assert {:error, {:name_conflict, "UTF-8"}} = Iconvex.register_codec(ROT13, aliases: ["UTF-8"])
    assert {:error, {:name_conflict, "ROT13"}} = Iconvex.register_codec(DuplicateCodec)

    assert {:error, {:invalid_codec, {:invalid_name, "X/BAD"}}} =
             Iconvex.register_codec(SlashCodec)

    assert {:error, {:invalid_codec, :invalid_decode_error_recovery}} =
             Iconvex.register_codec(InvalidRecoveryCodec)

    assert Iconvex.canonical_name("UTF-8") == {:ok, "UTF-8"}

    assert :ok = Iconvex.unregister_codec(:utf8)
    assert Iconvex.canonical_name("UTF-8") == {:ok, "UTF-8"}
  end

  test "whole-string codecs stop recovery without decoding an incomplete prefix or tail" do
    assert :ok = Iconvex.register_codec(StopRecoveryCodec)
    on_exit(fn -> Iconvex.unregister_codec(StopRecoveryCodec) end)
    parent = self()

    handler = fn event ->
      send(parent, {:stop_recovery_event, event})
      :discard
    end

    assert Iconvex.convert("a-z!more", StopRecoveryCodec, "UTF-8", on_invalid_byte: handler) ==
             {:ok, "a"}

    assert_receive {:stop_recovery_event,
                    %Iconvex.InvalidByte{
                      encoding: "X-STOP-RECOVERY",
                      offset: 3,
                      byte: ?!,
                      sequence: "!"
                    }}

    refute_receive {:stop_recovery_event, _}

    assert Iconvex.convert("a-z!more", StopRecoveryCodec, "UTF-8", byte_substitute: "<%02x>") ==
             {:ok, "a<21>"}

    assert {:ok, converter} =
             Iconvex.new(StopRecoveryCodec, "UTF-8", on_invalid_byte: handler)

    assert {:ok, <<>>, converter} = Iconvex.feed(converter, "a-z")
    assert {:ok, <<>>, converter} = Iconvex.feed(converter, "!more")
    assert {:ok, "a"} = Iconvex.finish(converter)

    assert_receive {:stop_recovery_event,
                    %Iconvex.InvalidByte{
                      encoding: "X-STOP-RECOVERY",
                      offset: 3,
                      byte: ?!,
                      sequence: "!"
                    }}

    refute_receive {:stop_recovery_event, _}

    assert Iconvex.stream(["a-z!more"], StopRecoveryCodec, "UTF-8") ==
             {:error, {:streaming_unsupported, :source, "X-STOP-RECOVERY"}}
  end

  test "canonical override registers a source-qualified collision codec safely" do
    assert :ok =
             Iconvex.register_codec(BuiltinCollisionCodec,
               canonical: "WHATWG-UTF-8",
               aliases: ["WHATWG-UTF8"]
             )

    assert Iconvex.canonical_name(BuiltinCollisionCodec) == {:ok, "WHATWG-UTF-8"}
    assert Iconvex.canonical_name("WHATWG-UTF-8") == {:ok, "WHATWG-UTF-8"}
    assert Iconvex.canonical_name("source-utf8") == {:ok, "WHATWG-UTF-8"}
    assert Iconvex.canonical_name("whatwg-utf8") == {:ok, "WHATWG-UTF-8"}
    assert Iconvex.canonical_name("UTF-8") == {:ok, "UTF-8"}
    assert Iconvex.convert("ABC", BuiltinCollisionCodec, "UTF-8") == {:ok, "ABC"}

    assert {:error, {:name_conflict, "UTF-8"}} =
             Iconvex.register_codec(BuiltinCollisionCodec, canonical: "UTF-8")

    assert {:error, {:invalid_codec, {:invalid_name, "SOURCE/UTF8"}}} =
             Iconvex.register_codec(BuiltinCollisionCodec, canonical: "SOURCE/UTF8")
  end

  test "an ownership token cannot remove a caller replacement" do
    assert :ok = Iconvex.unregister_codec(ROT13)
    assert {:ok, token} = Iconvex.ExternalRegistry.register_owned(ROT13)

    assert :ok = Iconvex.register_codec(ROT13, canonical: "X-CALLER-ROT13")
    assert :ok = Iconvex.ExternalRegistry.unregister(ROT13, token)

    assert Iconvex.canonical_name(ROT13) == {:ok, "X-CALLER-ROT13"}
    assert Iconvex.canonical_name("ROT13") == {:ok, "X-CALLER-ROT13"}
  end

  test "atomic owned registration never replaces an existing module" do
    assert {:ok, :existing} =
             Iconvex.ExternalRegistry.register_if_absent(ROT13,
               canonical: "X-SHOULD-NOT-REPLACE"
             )

    assert Iconvex.canonical_name(ROT13) == {:ok, "X-ROT13"}
    assert Iconvex.canonical_name("X-SHOULD-NOT-REPLACE") == :error
  end

  test "concurrent owned registration elects exactly one codec owner" do
    assert :ok = Iconvex.unregister_codec(ROT13)

    results =
      1..64
      |> Task.async_stream(fn _ -> Iconvex.register_codec_if_absent(ROT13) end,
        max_concurrency: 64,
        timeout: 5_000
      )
      |> Enum.map(fn {:ok, result} -> result end)

    tokens = for {:ok, token} <- results, is_reference(token), do: token

    assert length(tokens) == 1
    assert Enum.count(results, &(&1 == {:ok, :existing})) == 63
    assert :ok = Iconvex.unregister_codec(ROT13, hd(tokens))
    assert Iconvex.canonical_name(ROT13) == :error
  end

  test "public ownership API conditionally unregisters only its own registration" do
    assert :ok = Iconvex.unregister_codec(ROT13)
    assert {:ok, token} = Iconvex.register_codec_if_absent(ROT13)
    assert {:ok, :existing} = Iconvex.register_codec_if_absent(ROT13)

    assert :ok = Iconvex.unregister_codec(ROT13, make_ref())
    assert Iconvex.canonical_name(ROT13) == {:ok, "X-ROT13"}

    assert :ok = Iconvex.unregister_codec(ROT13, token)
    assert Iconvex.canonical_name(ROT13) == :error
  end

  test "unregister APIs reject invalid ownership arguments" do
    assert {:error, {:invalid_argument, :module}} = Iconvex.unregister_codec("not-a-module")

    assert {:error, {:invalid_argument, :registration_token}} =
             Iconvex.unregister_codec(ROT13, :not_a_reference)

    assert {:error, {:invalid_argument, :module}} =
             Iconvex.unregister_codec("not-a-module", make_ref())

    assert {:error, {:invalid_argument, :registration_token}} =
             Iconvex.ExternalRegistry.unregister_set(:not_a_reference)
  end

  test "codec replacement remains continuously readable" do
    aliases = Enum.map(1..2_000, &"X-ROT13-RACE-#{&1}")
    assert :ok = Iconvex.register_codec(ROT13, aliases: aliases)

    misses = :atomics.new(3, [])
    parent = self()
    retained_alias = hd(aliases)

    readers =
      for {lookup, miss_slot} <- [
            {ROT13, 2},
            {ROT13, 2},
            {retained_alias, 3},
            {retained_alias, 3}
          ] do
        Task.async(fn ->
          send(parent, :reader_ready)
          count_missing_reads(misses, lookup, miss_slot)
        end)
      end

    for _ <- readers, do: assert_receive(:reader_ready, 1_000)

    try do
      assert :ok =
               Iconvex.register_codec(ROT13,
                 canonical: "X-ROT13-REPLACED",
                 aliases: aliases
               )
    after
      :atomics.put(misses, 1, 1)
      Enum.each(readers, &Task.await(&1, 5_000))
    end

    assert :atomics.get(misses, 2) == 0
    assert :atomics.get(misses, 3) == 0
    assert Iconvex.canonical_name(ROT13) == {:ok, "X-ROT13-REPLACED"}
    assert Iconvex.canonical_name(retained_alias) == {:ok, "X-ROT13-REPLACED"}
  end

  test "owned registrations and tokens survive registry process restart" do
    on_exit(&restart_iconvex_application/0)
    assert :ok = Iconvex.unregister_codec(ROT13)
    assert {:ok, token} = Iconvex.register_codec_owned(ROT13)

    old_heir = Process.whereis(Iconvex.ExternalRegistry.Heir)
    heir_monitor = Process.monitor(old_heir)
    Process.exit(old_heir, :kill)
    assert_receive {:DOWN, ^heir_monitor, :process, ^old_heir, :killed}, 1_000
    new_heir = wait_for_process_restart(Iconvex.ExternalRegistry.Heir, old_heir)
    assert is_pid(new_heir)
    assert :sys.get_state(new_heir) == nil

    old_registry = Process.whereis(Iconvex.ExternalRegistry)
    {:links, [registry_supervisor]} = Process.info(old_registry, :links)
    monitor = Process.monitor(old_registry)

    :ok = :sys.suspend(registry_supervisor)

    try do
      Process.exit(old_registry, :kill)
      assert_receive {:DOWN, ^monitor, :process, ^old_registry, :killed}, 1_000

      assert :ets.info(Iconvex.ExternalRegistry, :owner) ==
               Process.whereis(Iconvex.ExternalRegistry.Heir)

      :sys.replace_state(Iconvex.ExternalRegistry.Heir, fn state ->
        :ets.delete(Iconvex.ExternalRegistry, {:name, "ROT13"})

        :ets.insert(
          Iconvex.ExternalRegistry,
          {{:name, "X-STALE-REGISTRY-INDEX"}, ROT13}
        )

        state
      end)
    after
      :ok = :sys.resume(registry_supervisor)
    end

    new_registry = wait_for_process_restart(Iconvex.ExternalRegistry, old_registry)
    assert is_pid(new_registry)
    assert Iconvex.canonical_name(ROT13) == {:ok, "X-ROT13"}
    assert Iconvex.canonical_name("ROT13") == {:ok, "X-ROT13"}
    assert Iconvex.canonical_name("X-STALE-REGISTRY-INDEX") == :error

    assert :ets.lookup(Iconvex.ExternalRegistry, {:name, "X-STALE-REGISTRY-INDEX"}) == []

    assert :ok = Iconvex.unregister_codec(ROT13, token)
    assert Iconvex.canonical_name(ROT13) == :error
  end

  test "reclaimed registry table keeps its heir across a second worker crash" do
    on_exit(&restart_iconvex_application/0)
    assert :ok = Iconvex.unregister_codec(ROT13)
    assert {:ok, token} = Iconvex.register_codec_owned(ROT13)

    first_registry = Process.whereis(Iconvex.ExternalRegistry)
    Process.exit(first_registry, :kill)
    second_registry = wait_for_process_restart(Iconvex.ExternalRegistry, first_registry)
    heir = Process.whereis(Iconvex.ExternalRegistry.Heir)

    # OTP preserves the configured heir when the inherited table is given
    # back, so another registry-only crash cannot open a lookup gap.
    assert :ets.info(Iconvex.ExternalRegistry, :heir) == heir

    {:links, [registry_supervisor]} = Process.info(second_registry, :links)
    second_monitor = Process.monitor(second_registry)
    :ok = :sys.suspend(registry_supervisor)

    try do
      Process.exit(second_registry, :kill)
      assert_receive {:DOWN, ^second_monitor, :process, ^second_registry, :killed}, 1_000
      assert :ets.info(Iconvex.ExternalRegistry, :owner) == heir
      assert Iconvex.canonical_name(ROT13) == {:ok, "X-ROT13"}
    after
      :ok = :sys.resume(registry_supervisor)
    end

    assert is_pid(wait_for_process_restart(Iconvex.ExternalRegistry, second_registry))
    assert :ok = Iconvex.unregister_codec(ROT13, token)
  end

  test "owned registrations survive the heir replacement crash window" do
    on_exit(&restart_iconvex_application/0)
    assert :ok = Iconvex.unregister_codec(ROT13)
    assert {:ok, token} = Iconvex.register_codec_owned(ROT13)

    registry = Process.whereis(Iconvex.ExternalRegistry)
    registry_monitor = Process.monitor(registry)
    old_heir = Process.whereis(Iconvex.ExternalRegistry.Heir)
    heir_monitor = Process.monitor(old_heir)

    assert {1, recovery_rows} =
             :persistent_term.get({Iconvex.ExternalRegistry, :recovery_snapshot})

    assert {{:module, ROT13}, %{registration_token: ^token}} =
             List.keyfind(recovery_rows, {:module, ROT13}, 0)

    # Hold the registry before killing its current heir. On the pre-fix path,
    # the replacement registered its name and then blocked while synchronously
    # installing itself, exposing the exact interval in which ETS still named
    # the dead old heir.
    :ok = :sys.suspend(registry)
    Process.exit(old_heir, :kill)
    assert_receive {:DOWN, ^heir_monitor, :process, ^old_heir, :killed}, 1_000

    replacement_heir =
      wait_for_process_restart(Iconvex.ExternalRegistry.Heir, old_heir)

    assert is_pid(replacement_heir)
    assert :ets.info(Iconvex.ExternalRegistry, :heir) == old_heir

    Process.exit(registry, :kill)
    assert_receive {:DOWN, ^registry_monitor, :process, ^registry, :killed}, 1_000

    replacement_registry = wait_for_process_restart(Iconvex.ExternalRegistry, registry)
    assert is_pid(replacement_registry)
    assert %{} = :sys.get_state(replacement_registry)

    assert :ets.info(Iconvex.ExternalRegistry, :owner) == replacement_registry
    assert :ets.info(Iconvex.ExternalRegistry, :heir) == replacement_heir

    assert [{{:module, ROT13}, %{registration_token: ^token}}] =
             :ets.lookup(Iconvex.ExternalRegistry, {:module, ROT13})

    assert Iconvex.canonical_name(ROT13) == {:ok, "X-ROT13"}
    assert :ok = Iconvex.unregister_codec(ROT13, token)
    assert Iconvex.canonical_name(ROT13) == :error
  end

  test "if-absent registration adopts a commit whose reply was lost" do
    on_exit(&restart_iconvex_application/0)
    assert :ok = Iconvex.unregister_codec(ROT13)

    registry = Process.whereis(Iconvex.ExternalRegistry)
    {:links, [registry_supervisor]} = Process.info(registry, :links)
    monitor = Process.monitor(registry)
    hook_reference = make_ref()
    parent = self()

    :sys.replace_state(registry, fn state ->
      Map.put(state, :after_commit, {parent, hook_reference})
    end)

    :ok = :sys.suspend(registry_supervisor)

    token =
      try do
        spawn(fn ->
          Process.put({Iconvex.ExternalRegistry, :registration_restart_attempts}, 5)

          result =
            try do
              Iconvex.register_codec_if_absent(ROT13)
            catch
              :exit, reason -> {:caller_exit, reason}
            end

          send(parent, {:registration_result, result})
        end)

        assert_receive {
                         :external_registry_committed,
                         ^registry,
                         ROT13,
                         ^hook_reference
                       },
                       1_000

        Process.exit(registry, :kill)
        assert_receive {:DOWN, ^monitor, :process, ^registry, :killed}, 1_000

        assert_receive {:registration_result, {:ok, token}}, 1_000
        token
      after
        :ok = :sys.resume(registry_supervisor)
      end

    assert is_reference(token)
    assert is_pid(wait_for_process_restart(Iconvex.ExternalRegistry, registry))
    assert Iconvex.canonical_name(ROT13) == {:ok, "X-ROT13"}
    assert :ok = Iconvex.unregister_codec(ROT13, token)
    assert Iconvex.canonical_name(ROT13) == :error
  end

  test "owned replacement retries when the worker dies before handling its queued call" do
    on_exit(&restart_iconvex_application/0)
    assert :ok = Iconvex.register_codec(ROT13, canonical: "X-QUEUED-OLD")

    registry = Process.whereis(Iconvex.ExternalRegistry)
    monitor = Process.monitor(registry)
    parent = self()
    :ok = :sys.suspend(registry)

    caller =
      spawn(fn ->
        result = Iconvex.register_codec_owned(ROT13, canonical: "X-QUEUED-REPLACEMENT")
        send(parent, {:queued_replacement_result, result})
      end)

    try do
      assert :ok = wait_for_pending_message(registry)
      Process.exit(registry, :kill)
      assert_receive {:DOWN, ^monitor, :process, ^registry, :killed}, 1_000

      assert_receive {:queued_replacement_result, {:ok, token}}, 2_000
      assert is_reference(token)
      assert Iconvex.canonical_name(ROT13) == {:ok, "X-QUEUED-REPLACEMENT"}
      assert :ok = Iconvex.unregister_codec(ROT13, token)
    after
      if Process.alive?(registry), do: :sys.resume(registry)
      if Process.alive?(caller), do: Process.exit(caller, :kill)
    end
  end

  test "owned registration cannot time out after a live worker commits" do
    on_exit(&restart_iconvex_application/0)
    assert :ok = Iconvex.unregister_codec(ROT13)

    registry = Process.whereis(Iconvex.ExternalRegistry)
    hook_reference = make_ref()
    release_key = {__MODULE__, :released_registration_hook, hook_reference}
    parent = self()
    Process.put(release_key, false)

    :sys.replace_state(registry, fn state ->
      Map.put(state, :after_commit, {parent, hook_reference})
    end)

    caller =
      spawn(fn ->
        result =
          try do
            Iconvex.register_codec_owned(ROT13)
          catch
            :exit, reason -> {:caller_exit, reason}
          end

        send(parent, {:slow_registration_result, result})
      end)

    result =
      try do
        assert_receive {
                         :external_registry_committed,
                         ^registry,
                         ROT13,
                         ^hook_reference
                       },
                       1_000

        # GenServer's default timeout is 5 seconds. The call must remain
        # pending beyond that boundary because a timed-out call is not
        # cancelled and this registration has already committed.
        refute_receive {:slow_registration_result, _result}, 5_200
        send(registry, {:continue_external_registry, hook_reference})
        Process.put(release_key, true)
        assert_receive {:slow_registration_result, result}, 1_000
        result
      after
        unless Process.get(release_key) do
          send(registry, {:continue_external_registry, hook_reference})
        end

        Process.delete(release_key)
        if Process.alive?(caller), do: Process.exit(caller, :kill)
      end

    :sys.replace_state(registry, &Map.delete(&1, :after_commit))

    token =
      case result do
        {:ok, token} -> token
        _error -> nil
      end

    assert :ok = Iconvex.unregister_codec(ROT13)
    assert is_reference(token)
  end

  test "unconditional unregister cannot time out while its delete remains queued" do
    on_exit(&restart_iconvex_application/0)
    registry = Process.whereis(Iconvex.ExternalRegistry)
    parent = self()
    :ok = :sys.suspend(registry)
    Process.put({__MODULE__, :registry_resumed}, false)

    caller =
      spawn(fn ->
        result =
          try do
            Iconvex.unregister_codec(ROT13)
          catch
            :exit, reason -> {:caller_exit, reason}
          end

        send(parent, {:unconditional_unregister_result, result})
      end)

    try do
      assert :ok = wait_for_pending_message(registry)

      # A default GenServer call would return after five seconds although its
      # queued delete would remain live and could remove a later replacement.
      refute_receive {:unconditional_unregister_result, _result}, 5_200
      :ok = :sys.resume(registry)
      Process.put({__MODULE__, :registry_resumed}, true)
      assert_receive {:unconditional_unregister_result, :ok}, 1_000
    after
      unless Process.get({__MODULE__, :registry_resumed}) do
        :sys.resume(registry)
      end

      Process.delete({__MODULE__, :registry_resumed})
      if Process.alive?(caller), do: Process.exit(caller, :kill)
    end

    assert Iconvex.canonical_name(ROT13) == :error
  end

  test "token-owned unregister survives a registry crash before the call is handled" do
    on_exit(&restart_iconvex_application/0)
    assert :ok = Iconvex.unregister_codec(ROT13)
    assert {:ok, token} = Iconvex.register_codec_owned(ROT13)

    registry = Process.whereis(Iconvex.ExternalRegistry)
    monitor = Process.monitor(registry)
    parent = self()
    :ok = :sys.suspend(registry)

    caller =
      spawn(fn ->
        result =
          try do
            Iconvex.unregister_codec(ROT13, token)
          catch
            :exit, reason -> {:caller_exit, reason}
          end

        send(parent, {:owned_unregister_result, result})
      end)

    try do
      assert :ok = wait_for_pending_message(registry)
      Process.exit(registry, :kill)
      assert_receive {:DOWN, ^monitor, :process, ^registry, :killed}, 1_000
      assert_receive {:owned_unregister_result, :ok}, 2_000
    after
      if Process.alive?(registry), do: :sys.resume(registry)
      if Process.alive?(caller), do: Process.exit(caller, :kill)
    end

    assert is_pid(wait_for_process_restart(Iconvex.ExternalRegistry, registry))
    assert Iconvex.canonical_name(ROT13) == :error
  end

  test "token-owned unregister completes while the registry supervisor remains suspended" do
    on_exit(&restart_iconvex_application/0)
    assert :ok = Iconvex.unregister_codec(ROT13)
    assert {:ok, token} = Iconvex.register_codec_owned(ROT13)

    registry = Process.whereis(Iconvex.ExternalRegistry)
    {:links, [registry_supervisor]} = Process.info(registry, :links)
    monitor = Process.monitor(registry)
    parent = self()
    :ok = :sys.suspend(registry_supervisor)

    try do
      Process.exit(registry, :kill)
      assert_receive {:DOWN, ^monitor, :process, ^registry, :killed}, 1_000

      assert :ets.info(Iconvex.ExternalRegistry, :owner) ==
               Process.whereis(Iconvex.ExternalRegistry.Heir)

      assert :ok =
               Iconvex.ExternalRegistry.Heir.unregister_owned(ROT13, make_ref())

      assert [{_, %{registration_token: ^token}}] =
               :ets.lookup(Iconvex.ExternalRegistry, {:module, ROT13})

      spawn(fn ->
        Process.put({Iconvex.ExternalRegistry, :registration_restart_attempts}, 5)
        send(parent, {:suspended_unregister_result, Iconvex.unregister_codec(ROT13, token)})
      end)

      assert_receive {:suspended_unregister_result, :ok}, 1_000
      assert :ets.lookup(Iconvex.ExternalRegistry, {:module, ROT13}) == []
    after
      :ok = :sys.resume(registry_supervisor)
    end

    assert is_pid(wait_for_process_restart(Iconvex.ExternalRegistry, registry))
    assert Iconvex.canonical_name(ROT13) == :error
  end

  test "only the registered registry process can reclaim the inherited table" do
    on_exit(&restart_iconvex_application/0)
    registry = Process.whereis(Iconvex.ExternalRegistry)
    {:links, [registry_supervisor]} = Process.info(registry, :links)
    monitor = Process.monitor(registry)
    :ok = :sys.suspend(registry_supervisor)

    result =
      try do
        Process.exit(registry, :kill)
        assert_receive {:DOWN, ^monitor, :process, ^registry, :killed}, 1_000

        heir = Process.whereis(Iconvex.ExternalRegistry.Heir)
        assert :ets.info(Iconvex.ExternalRegistry, :owner) == heir
        result = GenServer.call(heir, {:take_table, self()})

        if :ets.info(Iconvex.ExternalRegistry, :owner) == self() do
          true = :ets.give_away(Iconvex.ExternalRegistry, heir, :registry_heir)
        end

        result
      after
        :ok = :sys.resume(registry_supervisor)
      end

    assert is_pid(wait_for_process_restart(Iconvex.ExternalRegistry, registry))
    assert result == {:error, :unauthorized_registry_owner}
    assert Iconvex.canonical_name(ROT13) == {:ok, "X-ROT13"}
  end

  test "loads codec modules from application configuration" do
    previous = Application.fetch_env(:iconvex, :external_codecs)

    try do
      assert :ok = Application.stop(:iconvex)
      Application.put_env(:iconvex, :external_codecs, [ROT13])
      assert {:ok, started} = Application.ensure_all_started(:iconvex)
      assert :iconvex in started
      assert Iconvex.canonical_name("ROT13") == {:ok, "X-ROT13"}
    after
      Application.stop(:iconvex)

      case previous do
        {:ok, value} -> Application.put_env(:iconvex, :external_codecs, value)
        :error -> Application.delete_env(:iconvex, :external_codecs)
      end

      Application.ensure_all_started(:iconvex)
    end
  end

  test "clean application shutdown does not resurrect dynamic registrations" do
    on_exit(&restart_iconvex_application/0)
    assert :ok = Iconvex.unregister_codec(ROT13)
    assert {:ok, _token} = Iconvex.register_codec_owned(ROT13)
    assert Iconvex.canonical_name(ROT13) == {:ok, "X-ROT13"}

    assert :ok = Application.stop(:iconvex)
    assert {:ok, started} = Application.ensure_all_started(:iconvex)
    assert :iconvex in started
    assert Iconvex.canonical_name(ROT13) == :error
  end

  defp count_missing_reads(state, lookup, miss_slot) do
    if :atomics.get(state, 1) == 1 do
      :ok
    else
      if Iconvex.ExternalRegistry.resolve(lookup) == :error do
        :atomics.add_get(state, miss_slot, 1)
      end

      count_missing_reads(state, lookup, miss_slot)
    end
  end

  defp wait_for_process_restart(module, old_process, attempts \\ 1_000)

  defp wait_for_process_restart(_module, _old_process, 0), do: nil

  defp wait_for_process_restart(module, old_process, attempts) do
    case Process.whereis(module) do
      pid when is_pid(pid) and pid != old_process ->
        pid

      _missing_or_same ->
        Process.sleep(1)
        wait_for_process_restart(module, old_process, attempts - 1)
    end
  end

  defp wait_for_pending_message(process, attempts \\ 1_000)

  defp wait_for_pending_message(_process, 0), do: {:error, :timeout}

  defp wait_for_pending_message(process, attempts) do
    case Process.info(process, :message_queue_len) do
      {:message_queue_len, count} when count > 0 ->
        :ok

      _empty_or_dead ->
        Process.sleep(1)
        wait_for_pending_message(process, attempts - 1)
    end
  end

  defp restart_iconvex_application do
    Application.stop(:iconvex)
    {:ok, _started} = Application.ensure_all_started(:iconvex)
    :ok
  end
end

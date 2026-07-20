defmodule Iconvex.TerminalIncompleteTargetOrderTest.UTF8Codec do
  @moduledoc false

  def decode(input) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        {:ok, codepoints}

      {:error, _prefix, rest} ->
        {:error, :invalid_sequence, byte_size(input) - byte_size(rest), rest}

      {:incomplete, _prefix, rest} ->
        {:error, :incomplete_sequence, byte_size(input) - byte_size(rest), rest}
    end
  end

  def decode_discard(input) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) -> {:ok, codepoints}
      {_kind, prefix, _rest} -> {:ok, prefix}
    end
  end

  def encode(codepoints), do: encode_utf8(codepoints)
  def encode_discard(codepoints), do: encode_utf8(codepoints)
  def encode_substitute(codepoints, _replacer), do: encode_utf8(codepoints)

  # This test codec intentionally defers its complete input until finalization.
  # Its incomplete error declares the complete two-byte unit width, which
  # exercises the terminal branch where fewer bytes than that width remain.
  def decode_chunk(input, false), do: {:ok, [], input}

  def decode_chunk(input, true) do
    case decode(input) do
      {:ok, codepoints} -> {:ok, codepoints, <<>>}
      error -> error
    end
  end

  def encode_chunk(codepoints, _final?, _policy) do
    case encode_utf8(codepoints) do
      {:ok, output} -> {:ok, output, []}
      error -> error
    end
  end

  def decode_error_consumption(:incomplete_sequence, <<lead>>) when lead in 0xC2..0xDF,
    do: 2

  def decode_error_consumption(_kind, _sequence), do: 1

  defp encode_utf8(codepoints) do
    case :unicode.characters_to_binary(codepoints, :unicode, :utf8) do
      output when is_binary(output) -> {:ok, output}
      _invalid_codepoints -> {:error, :unrepresentable_character, List.first(codepoints)}
    end
  end
end

defmodule Iconvex.TerminalIncompleteTargetOrderTest.ResynchronizingUTF8 do
  use Iconvex.Codec

  alias Iconvex.TerminalIncompleteTargetOrderTest.UTF8Codec

  @impl true
  def canonical_name, do: "X-TERMINAL-UTF8-RESYNCHRONIZING"

  @impl true
  defdelegate decode(input), to: UTF8Codec

  @impl true
  defdelegate decode_discard(input), to: UTF8Codec

  @impl true
  defdelegate encode(codepoints), to: UTF8Codec

  @impl true
  defdelegate encode_discard(codepoints), to: UTF8Codec

  @impl true
  defdelegate encode_substitute(codepoints, replacer), to: UTF8Codec

  @impl true
  defdelegate decode_chunk(input, final?), to: UTF8Codec

  @impl true
  defdelegate encode_chunk(codepoints, final?, policy), to: UTF8Codec

  @impl true
  defdelegate decode_error_consumption(kind, sequence), to: UTF8Codec
end

defmodule Iconvex.TerminalIncompleteTargetOrderTest.StoppingUTF8 do
  use Iconvex.Codec

  alias Iconvex.TerminalIncompleteTargetOrderTest.UTF8Codec

  @impl true
  def canonical_name, do: "X-TERMINAL-UTF8-STOPPING"

  @impl true
  def decode_error_recovery, do: :stop

  @impl true
  defdelegate decode(input), to: UTF8Codec

  @impl true
  defdelegate decode_discard(input), to: UTF8Codec

  @impl true
  defdelegate encode(codepoints), to: UTF8Codec

  @impl true
  defdelegate encode_discard(codepoints), to: UTF8Codec

  @impl true
  defdelegate encode_substitute(codepoints, replacer), to: UTF8Codec

  @impl true
  defdelegate decode_error_consumption(kind, sequence), to: UTF8Codec
end

defmodule Iconvex.TerminalIncompleteTargetOrderTest do
  use ExUnit.Case, async: false

  alias __MODULE__.{ResynchronizingUTF8, StoppingUTF8}

  @input <<0xC4, 0x80, 0xC4>>

  setup_all do
    for codec <- [ResynchronizingUTF8, StoppingUTF8] do
      Iconvex.unregister_codec(codec)
      assert :ok = Iconvex.register_codec(codec)
    end

    on_exit(fn ->
      for codec <- [StoppingUTF8, ResynchronizingUTF8], do: Iconvex.unregister_codec(codec)
    end)

    :ok
  end

  test "strict built-in UTF-8 reports the earlier ASCII target error at every split" do
    assert_target_error(Iconvex.convert(@input, "UTF-8", "ASCII"))

    for split <- 0..byte_size(@input) do
      assert_stream_target_error("UTF-8", split)

      {:ok, converter} = Iconvex.new("UTF-8", "ASCII")
      {left, right} = split_at(@input, split)
      {:ok, <<>>, converter} = Iconvex.feed(converter, left)
      {:ok, <<>>, converter} = Iconvex.feed(converter, right)
      assert_target_error(Iconvex.finish(converter))
    end
  end

  test "terminal resynchronizing source arbitration reports the earlier target error" do
    parent = self()

    options_sets = [
      [],
      [byte_substitute: "<%02x>"],
      [
        on_invalid_byte: fn event ->
          send(parent, {:unexpected_source_callback, event})
          :error
        end
      ]
    ]

    for options <- options_sets do
      assert_target_error(Iconvex.convert(@input, ResynchronizingUTF8, "ASCII", options))

      for split <- 0..byte_size(@input) do
        assert_stream_target_error(ResynchronizingUTF8, split, options)
      end
    end

    refute_received {:unexpected_source_callback, _event}
  end

  test "terminal stopping-source arbitration reports the earlier target error" do
    assert_target_error(Iconvex.convert(@input, StoppingUTF8, "ASCII"))

    assert_target_error(Iconvex.convert(@input, StoppingUTF8, "ASCII", byte_substitute: "<%02x>"))
  end

  test "a representable terminal prefix preserves the original incomplete-source error" do
    input = <<?A, 0xC4>>

    for source <- [ResynchronizingUTF8, StoppingUTF8] do
      assert {:error,
              %Iconvex.Error{
                kind: :incomplete_sequence,
                encoding: encoding,
                offset: 1,
                sequence: <<0xC4>>
              }} = Iconvex.convert(input, source, "ASCII")

      assert encoding == source.canonical_name()
    end

    for split <- 0..byte_size(input) do
      {left, right} = split_at(input, split)

      error =
        assert_raise Iconvex.Error, fn ->
          [left, right]
          |> Iconvex.stream!(ResynchronizingUTF8, "ASCII")
          |> Enum.to_list()
        end

      assert error.kind == :incomplete_sequence
      assert error.encoding == ResynchronizingUTF8.canonical_name()
      assert error.offset == 1
      assert error.sequence == <<0xC4>>
    end
  end

  defp assert_stream_target_error(source, split, options \\ []) do
    {left, right} = split_at(@input, split)

    error =
      assert_raise Iconvex.Error, fn ->
        source
        |> then(&Iconvex.stream!([left, right], &1, "ASCII", options))
        |> Enum.to_list()
      end

    assert_target_error(error)
  end

  defp assert_target_error({:error, %Iconvex.Error{} = error}), do: assert_target_error(error)

  defp assert_target_error(%Iconvex.Error{} = error) do
    assert error.kind == :unrepresentable_character
    assert error.encoding == "US-ASCII"
    assert error.codepoint == 0x100
    assert error.offset == nil
    assert error.sequence == nil
  end

  defp split_at(input, offset) do
    {
      binary_part(input, 0, offset),
      binary_part(input, offset, byte_size(input) - offset)
    }
  end
end

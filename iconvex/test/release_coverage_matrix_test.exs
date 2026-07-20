defmodule Iconvex.ReleaseCoverageMatrixTest.FallbackCodec do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-RELEASE-COVERAGE-FALLBACK"

  @impl true
  def decode(input), do: {:ok, :binary.bin_to_list(input)}

  @impl true
  def decode_discard(input), do: decode(input)

  @impl true
  def encode(codepoints), do: encode_loop(codepoints, [])

  @impl true
  def encode_discard(codepoints) do
    {:ok,
     codepoints
     |> Enum.filter(&(&1 in 0..0x7F))
     |> :erlang.list_to_binary()}
  end

  @impl true
  def encode_substitute(codepoints, replacer), do: encode_substitute(codepoints, replacer, [])

  defp encode_loop([], acc), do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_binary()}

  defp encode_loop([codepoint | rest], acc) when codepoint in 0..0x7F,
    do: encode_loop(rest, [codepoint | acc])

  defp encode_loop([codepoint | _rest], _acc),
    do: {:error, :unrepresentable_character, codepoint}

  defp encode_substitute([], _replacer, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute([codepoint | rest], replacer, acc) when codepoint in 0..0x7F,
    do: encode_substitute(rest, replacer, [<<codepoint>> | acc])

  defp encode_substitute([codepoint | rest], replacer, acc) do
    case encode_loop(replacer.(codepoint), []) do
      {:ok, replacement} -> encode_substitute(rest, replacer, [replacement | acc])
      error -> error
    end
  end
end

defmodule Iconvex.ReleaseCoverageMatrixTest.InvalidSourceCodec do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-RELEASE-COVERAGE-INVALID-SOURCE"

  @impl true
  def decode("escape"), do: {:ok, [0x100000000]}
  def decode("wide"), do: {:ok, [0x110000]}
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

defmodule Iconvex.ReleaseCoverageMatrixTest.InvalidByteCodec do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-RELEASE-COVERAGE-INVALID-BYTE"

  @impl true
  def decode(input) do
    case :binary.match(input, <<0xFF>>) do
      :nomatch -> {:ok, :binary.bin_to_list(input)}
      {offset, 1} -> {:error, :invalid_sequence, offset, <<0xFF>>}
    end
  end

  @impl true
  def decode_discard(input),
    do: {:ok, input |> :binary.bin_to_list() |> Enum.reject(&(&1 == 0xFF))}

  @impl true
  def encode(codepoints), do: {:ok, :erlang.list_to_binary(codepoints)}

  @impl true
  def encode_discard(codepoints), do: encode(codepoints)

  @impl true
  def encode_substitute(codepoints, _replacer), do: encode(codepoints)
end

defmodule Iconvex.ReleaseCoverageMatrixTest.ShortConsumptionCodec do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-RELEASE-COVERAGE-SHORT-CONSUMPTION"

  @impl true
  def decode(<<0xFF>>), do: {:error, :invalid_sequence, 0, <<0xFF>>}
  def decode(input), do: {:ok, :binary.bin_to_list(input)}

  @impl true
  def decode_discard(_input), do: {:ok, []}

  @impl true
  def decode_error_consumption(_kind, _sequence), do: 2

  @impl true
  def encode(codepoints), do: {:ok, :erlang.list_to_binary(codepoints)}

  @impl true
  def encode_discard(codepoints), do: encode(codepoints)

  @impl true
  def encode_substitute(codepoints, _replacer), do: encode(codepoints)
end

defmodule Iconvex.ReleaseCoverageMatrixTest do
  use ExUnit.Case, async: false

  alias Iconvex.{EscapeCodec, GB18030Codec, Packed, TableCodec}

  @external_codecs [
    __MODULE__.FallbackCodec,
    __MODULE__.InvalidSourceCodec,
    __MODULE__.InvalidByteCodec,
    __MODULE__.ShortConsumptionCodec
  ]

  setup do
    for codec <- @external_codecs do
      Iconvex.unregister_codec(codec)
      assert :ok = Iconvex.register_codec(codec)
    end

    on_exit(fn -> Enum.each(@external_codecs, &Iconvex.unregister_codec/1) end)
    :ok
  end

  test "six-bit packing covers every optimized group and tail boundary" do
    for position <- 0..3, packer <- [&Packed.pack(&1, 6), &Packed.pack_lsb(&1, 6)] do
      units = List.duplicate(0, 4) |> List.replace_at(position, 64) |> :erlang.list_to_binary()
      assert {:error, :unit_out_of_range, ^position, 64} = packer.(units)
    end

    for units <- [<<>>, <<1>>, <<1, 2>>, <<1, 2, 3>>, <<1, 2, 3, 4>>, <<1, 2, 3, 4, 5>>] do
      assert {:ok, msb} = Packed.pack(units, 6)
      assert {:ok, ^units} = Packed.unpack(msb, 6)
      assert {:ok, lsb} = Packed.pack_lsb(units, 6)
      assert {:ok, ^units} = Packed.unpack_lsb(lsb.data, lsb.bit_size, 6)
    end

    for {units, offset} <- [{<<64>>, 0}, {<<1, 64>>, 1}, {<<1, 2, 64>>, 2}] do
      assert {:error, :unit_out_of_range, ^offset, 64} = Packed.pack(units, 6)
      assert {:error, :unit_out_of_range, ^offset, 64} = Packed.pack_lsb(units, 6)
    end

    exact_chunk = :binary.copy(<<1, 2, 3, 4>>, 1_024)
    assert {:ok, packed} = Packed.pack(exact_chunk, 6)
    assert {:ok, ^exact_chunk} = Packed.unpack(packed, 6)
  end

  test "table chunk and replacement APIs cover strict, discard, replace, and pending paths" do
    cp1252 = %{id: :cp1252}
    hkscs = %{id: :big5hkscs2008}

    assert {:ok, ~c"AB", <<>>} = TableCodec.decode_chunk(cp1252, "AB", true)

    assert {:error, :invalid_sequence, 0, <<0x81>>} =
             TableCodec.decode_chunk(cp1252, <<0x81>>, true)

    assert {:ok, [0xEA, 0x030C], "A"} =
             TableCodec.decode_chunk(hkscs, <<0x88, 0xA5, ?A>>, false)

    assert {:error, :invalid_sequence, 0, <<0xFF, 0xFF>>} =
             TableCodec.decode_chunk(hkscs, <<0xFF, 0xFF>>, false)

    assert {:ok, "A", []} = TableCodec.encode_chunk(cp1252, [?A], true, :error)

    assert {:error, :unrepresentable_character, 0x1F600} =
             TableCodec.encode_chunk(cp1252, [0x1F600], true, :error)

    assert {:ok, "A", []} = TableCodec.encode_chunk(cp1252, [0x1F600, ?A], true, :discard)

    assert {:ok, "?", []} =
             TableCodec.encode_chunk(cp1252, [0x1F600], true, {:replace, fn _ -> ~c"?" end})

    assert {:error, :unrepresentable_character, 0x1F600} =
             TableCodec.encode_chunk(cp1252, [0x1F600], true, {
               :replace,
               fn _ -> [0x1F600] end
             })

    assert {:ok, <<>>, [0xEA]} = TableCodec.encode_chunk(hkscs, [0xEA], false, :error)

    assert {:ok, <<0x88, 0xA5>>, [?A]} =
             TableCodec.encode_chunk(hkscs, [0xEA, 0x030C, ?A], false, :error)

    assert {:ok, <<>>, [?A]} =
             TableCodec.encode_chunk(hkscs, [0x110000, ?A], false, :discard)

    assert {:error, :unrepresentable_character, 0x110000} =
             TableCodec.encode_chunk(hkscs, [0x110000, ?A], false, :error)

    assert {:ok, "?"} =
             TableCodec.encode_substitute(hkscs, [0x110000], fn _ -> ~c"?" end)

    assert {:error, :unrepresentable_character, 0x110000} =
             TableCodec.encode_substitute(hkscs, [0x110000], fn _ -> [0x110000] end)
  end

  test "escape and GB18030 substitution loops cover replacement success and failure" do
    for {id, unrepresentable} <- [{:c99, 0x100000000}, {:java, 0x80000000}] do
      entry = %{id: id}

      assert {:ok, "A?B"} =
               EscapeCodec.encode_substitute(entry, [?A, unrepresentable, ?B], fn _ -> ~c"?" end)

      assert {:error, :unrepresentable_character, ^unrepresentable} =
               EscapeCodec.encode_substitute(entry, [unrepresentable], fn _ ->
                 [unrepresentable]
               end)
    end

    assert {:ok, [0xAF]} = EscapeCodec.decode(%{id: :c99}, ~S(\u00Af))

    assert {:ok, [0x100]} = EscapeCodec.decode(%{id: :c99}, ~S(\u00G0))

    assert {:ok, java_literal} = EscapeCodec.decode(%{id: :java}, ~S(\ud800abcdef))
    assert java_literal == String.to_charlist(~S(\ud800abcdef))

    entry = %{id: :gb18030_2005}

    assert {:ok, "A?B"} =
             GB18030Codec.encode_substitute(entry, [?A, 0x110000, ?B], fn _ -> ~c"?" end)

    assert {:error, :unrepresentable_character, 0x110000} =
             GB18030Codec.encode_substitute(entry, [0x110000], fn _ -> [0x110000] end)
  end

  test "public request, lifecycle, callback, and substitution failures retain typed contracts" do
    assert {:error, {:invalid_argument, :input}} =
             Iconvex.convert(~c"not binary", "UTF-8", "UTF-8")

    assert {:error, :unknown_encoding} = Iconvex.convert("", "NO-SUCH-CODEC", "UTF-8")
    assert {:error, :unknown_encoding} = Iconvex.new("UTF-8", "NO-SUCH-CODEC")

    assert_raise ArgumentError, ~r/unknown character encoding/, fn ->
      Iconvex.convert!("", "NO-SUCH-CODEC", "UTF-8")
    end

    assert_raise ArgumentError, ~r/invalid conversion request/, fn ->
      Iconvex.convert!("", "UTF-8", "UTF-8", invalid: :bad)
    end

    assert_raise ArgumentError, ~r/unknown character encoding/, fn ->
      Iconvex.stream!([], "NO-SUCH-CODEC", "UTF-8")
    end

    assert_raise ArgumentError, ~r/invalid streaming request/, fn ->
      Iconvex.stream!([], "UTF-8", "UTF-8", invalid: :bad)
    end

    assert {:ok, converter} = Iconvex.new("UTF-8", "UTF-8")
    assert {:error, {:invalid_argument, :chunk}} = Iconvex.feed(converter, ~c"not binary")
    assert {:ok, <<>>, converter} = Iconvex.feed(converter, <<0xFF>>)
    assert {:error, %Iconvex.Error{kind: :invalid_sequence}} = Iconvex.finish(converter)

    finished = %{converter | finished?: true}
    assert {:error, :already_finished} = Iconvex.feed(finished, "")
    assert {:error, :already_finished} = Iconvex.finish(finished)
    assert {:error, :already_finished} = Iconvex.finish_with_state(finished)

    invalid_name = __MODULE__.InvalidByteCodec

    for {replacement, expected} <- [
          {"é", {:ok, "AéB"}},
          {?é, {:ok, "AéB"}},
          {[?x, ?y], {:ok, "AxyB"}}
        ] do
      assert Iconvex.convert("A\xFFB", invalid_name, "UTF-8",
               on_invalid_byte: fn _ -> {:replace, replacement} end
             ) == expected
    end

    for invalid <- [<<0xFF>>, 0xD800, [0x110000], {:not, :text}] do
      assert {:error, {:invalid_callback_return, :on_invalid_byte, ^invalid}} =
               Iconvex.convert("\xFF", invalid_name, "UTF-8",
                 on_invalid_byte: fn _ -> {:replace, invalid} end
               )
    end

    assert {:error, {:invalid_callback_return, :on_invalid_byte, :bogus}} =
             Iconvex.convert("\xFF", invalid_name, "UTF-8", on_invalid_byte: fn _ -> :bogus end)

    assert {:error, %Iconvex.Error{kind: :invalid_sequence}} =
             Iconvex.convert("\xFF", __MODULE__.ShortConsumptionCodec, "UTF-8",
               on_invalid_byte: fn _ -> :discard end
             )

    assert {:error, %Iconvex.Error{kind: :invalid_sequence}} =
             Iconvex.convert("\xFF", __MODULE__.ShortConsumptionCodec, "UTF-8",
               byte_substitute: "<%02x>"
             )

    assert {:ok, "A<1F600>B"} =
             Iconvex.convert("A😀B", "UTF-8", __MODULE__.FallbackCodec, unicode_substitute: "<%X>")

    expected_utf16 = :unicode.characters_to_binary("110000", :utf8, {:utf16, :big})

    assert {:ok, ^expected_utf16} =
             Iconvex.convert("wide", __MODULE__.InvalidSourceCodec, "UTF-16BE",
               unicode_substitute: "%X"
             )

    assert {:ok, "100000000"} =
             Iconvex.convert("escape", __MODULE__.InvalidSourceCodec, "C99",
               unicode_substitute: "%X"
             )

    assert {:ok, "110000"} =
             Iconvex.convert("wide", __MODULE__.InvalidSourceCodec, "GB18030",
               unicode_substitute: "%X"
             )

    assert {:ok, "<1F600>"} =
             Iconvex.convert("😀", "UTF-8", "ISO-2022-JP", unicode_substitute: "<%X>")

    swapped_input =
      <<?A::native-unsigned-integer-size(32)>>
      |> :binary.bin_to_list()
      |> Enum.reverse()
      |> :erlang.list_to_binary()

    assert {:ok, "A"} = Iconvex.convert(swapped_input, "UCS-4-SWAPPED", "UTF-8")
  end
end

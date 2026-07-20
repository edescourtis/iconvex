defmodule Iconvex.EscapeToUCS4FastPathTest do
  use ExUnit.Case, async: false

  alias Iconvex.{EscapeCodec, UnicodeCodec}

  @explicit_ucs4 ~w(UCS-4BE UCS-4LE UCS-4-INTERNAL UCS-4-SWAPPED)
  @short_alphabet [?\\, ?u, ?U, ?0, ?9, ?a, ?f, ?g, ?x, 0x9F, 0xA0]

  test "discard conversion matches callback-forced native recovery over escape fragments" do
    short_inputs =
      [<<>>] ++
        for(a <- @short_alphabet, do: <<a>>) ++
        for(a <- @short_alphabet, b <- @short_alphabet, do: <<a, b>>) ++
        for(a <- @short_alphabet, b <- @short_alphabet, c <- @short_alphabet, do: <<a, b, c>>)

    c99_boundaries =
      for value <-
            [
              0,
              1,
              0x24,
              0x40,
              0x60,
              0x9F,
              0xA0,
              0xD7FF,
              0xD800,
              0xDFFF,
              0xE000,
              0xFFFF,
              0x10000,
              0x10FFFF,
              0x11_0000,
              0xFFFFFFFF
            ] do
        if value <= 0xFFFF,
          do: "\\u" <> hex(value, 4),
          else: "\\U" <> hex(value, 8)
      end

    java_surrogates =
      for high <- [0xD800, 0xDBFF],
          low <- [0x0000, 0xDBFF, 0xDC00, 0xDFFF, 0xE000] do
        "\\u" <> hex(high, 4) <> "\\u" <> hex(low, 4)
      end

    truncations =
      for prefix <- ["\\", "\\u", "\\u0", "\\u00", "\\u000", "\\U", "\\U0", "\\U0000"] do
        prefix
      end

    cases = Enum.uniq(short_inputs ++ c99_boundaries ++ java_surrogates ++ truncations)

    for source <- ["C99", "JAVA"], target <- @explicit_ucs4, input <- cases do
      assert Iconvex.convert(input, source, target, invalid: :discard) ==
               Iconvex.convert(input, source, target,
                 invalid: :discard,
                 on_invalid_byte: fn _event -> :discard end
               )
    end
  end

  test "escape discard preserves extended C99 values and Java surrogate pairing" do
    assert Iconvex.convert("\\Uffffffff", "C99", "UCS-4BE", invalid: :discard) ==
             {:ok, <<0xFFFFFFFF::unsigned-big-32>>}

    assert Iconvex.convert("\\ud800", "C99", "UCS-4BE", invalid: :discard) ==
             {:ok, encode32(~c"ud800", :big)}

    assert Iconvex.convert("\\ud83d\\ude00", "JAVA", "UCS-4BE", invalid: :discard) ==
             {:ok, <<0x1F600::unsigned-big-32>>}

    assert Iconvex.convert(<<0xA0>>, "C99", "UCS-4BE", invalid: :discard) == {:ok, <<>>}

    assert Iconvex.convert(<<0xA0>>, "JAVA", "UCS-4BE", invalid: :discard) ==
             {:ok, <<0xA0::unsigned-big-32>>}
  end

  test "escape direct route eliminates intermediate codepoint lists" do
    inputs = [
      {"JAVA", String.duplicate("\\u0041", 2_048)},
      {"C99", String.duplicate("\\u00a0", 2_048)}
    ]

    for {source, input} <- inputs do
      {{:ok, output}, decode_calls, encode_calls, encode_discard_calls, direct_calls,
       append_calls} =
        count_pipeline_calls(fn ->
          Iconvex.convert(input, source, "UCS-4BE", invalid: :discard)
        end)

      assert byte_size(output) == 2_048 * 4
      assert decode_calls == 0
      assert encode_calls == 0
      assert encode_discard_calls == 0
      assert direct_calls == 1
      assert append_calls == 2_048
    end
  end

  test "C99 encoding from explicit UCS-4 eliminates intermediate codepoint lists" do
    input =
      for codepoint <- [0, 0x9F, 0xA0, 0xD800, 0x10000, 0x10FFFF], into: <<>> do
        <<codepoint::unsigned-big-32>>
      end

    mfas = [
      {UnicodeCodec, :decode, 2},
      {EscapeCodec, :encode_discard, 2},
      {EscapeCodec, :encode_c99_explicit_ucs4_discard, 2}
    ]

    {{:ok, output}, decode_calls, encode_discard_calls, direct_calls} =
      count_calls(mfas, fn ->
        Iconvex.convert(input, "UCS-4BE", "C99", unrepresentable: :discard)
      end)

    assert output == <<0, 0x9F>> <> ~S(\u00a0\ud800\U00010000\U0010ffff)
    assert decode_calls == 0
    assert encode_discard_calls == 0
    assert direct_calls == 1

    little =
      for <<codepoint::unsigned-big-32 <- input>>,
        into: <<>>,
        do: <<codepoint::unsigned-little-32>>

    assert EscapeCodec.encode_c99_explicit_ucs4_discard(little, :little) == {:ok, output}
    assert EscapeCodec.encode_c99_explicit_ucs4_discard(<<0, 0, 0>>, :big) == :miss
  end

  test "strict and callback escape errors keep their original offset and unit" do
    for source <- ["C99", "JAVA"] do
      input = "A\\u12"

      assert {:error,
              %Iconvex.Error{
                kind: :incomplete_sequence,
                encoding: ^source,
                offset: 1,
                sequence: "\\u12"
              }} = Iconvex.convert(input, source, "UCS-4BE")

      parent = self()

      assert {:error,
              %Iconvex.Error{
                kind: :incomplete_sequence,
                encoding: ^source,
                offset: 1,
                sequence: "\\u12"
              }} =
               Iconvex.convert(input, source, "UCS-4BE",
                 invalid: :discard,
                 on_invalid_byte: fn event ->
                   send(parent, {:escape_error, event})
                   :error
                 end
               )

      assert_receive {:escape_error,
                      %Iconvex.InvalidByte{offset: 1, byte: ?\\, sequence: "\\u12"}}
    end
  end

  defp count_pipeline_calls(function) do
    mfas = [
      {EscapeCodec, :decode, 2},
      {UnicodeCodec, :encode, 2},
      {UnicodeCodec, :encode_discard, 2},
      {EscapeCodec, :decode_to_explicit_ucs4_discard, 3},
      {EscapeCodec, :append_ucs4, 3}
    ]

    Enum.each(mfas, fn {module, _name, _arity} = mfa ->
      Code.ensure_loaded!(module)
      :erlang.trace_pattern(mfa, true, [:local, :call_count])
    end)

    try do
      result = function.()
      counts = Enum.map(mfas, fn mfa -> elem(:erlang.trace_info(mfa, :call_count), 1) end)
      List.to_tuple([result | counts])
    after
      Enum.each(mfas, &:erlang.trace_pattern(&1, false, [:local, :call_count]))
    end
  end

  defp count_calls(mfas, function) do
    Enum.each(mfas, fn {module, _name, _arity} = mfa ->
      Code.ensure_loaded!(module)
      :erlang.trace_pattern(mfa, true, [:local, :call_count])
    end)

    try do
      result = function.()
      counts = Enum.map(mfas, fn mfa -> elem(:erlang.trace_info(mfa, :call_count), 1) end)
      List.to_tuple([result | counts])
    after
      Enum.each(mfas, &:erlang.trace_pattern(&1, false, [:local, :call_count]))
    end
  end

  defp encode32(codepoints, :big),
    do: Enum.map_join(codepoints, &<<&1::unsigned-big-32>>)

  defp hex(value, width),
    do: value |> Integer.to_string(16) |> String.pad_leading(width, "0")
end

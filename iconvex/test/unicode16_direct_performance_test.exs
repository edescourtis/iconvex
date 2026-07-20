defmodule Iconvex.Unicode16DirectPerformanceTest do
  use ExUnit.Case, async: false

  alias Iconvex.UnicodeCodec

  @explicit_ucs2 ~w(ucs2be ucs2le ucs2internal ucs2swapped)a
  @explicit_ucs4 ~w(ucs4be ucs4le ucs4internal ucs4swapped)a
  @explicit_utf32 ~w(utf32be utf32le)a

  test "explicit UCS-4 discard converts directly to every UCS-2 byte order" do
    codepoints =
      [?A, 0xD7FF, 0xD800, 0xDFFF, 0xE000, 0xFFFE, 0xFEFF, 0xFFFF, 0x10000, 0x10FFFF]

    retained = [?A, 0xD7FF, 0xE000, 0xFFFE, 0xFEFF, 0xFFFF]

    for source <- @explicit_ucs4, target <- @explicit_ucs2 do
      input = encode_words32(codepoints, endian(source))

      assert UnicodeCodec.direct_convert(input, source, target, :error, :discard) ==
               {:ok, encode_words16(retained, endian(target))}
    end

    for source <- @explicit_ucs4 do
      input = encode_words32(codepoints, endian(source))

      assert UnicodeCodec.direct_convert(input, source, :ucs2, :error, :discard) ==
               {:ok, encode_words16(List.delete(retained, 0xFFFE), :big)}
    end
  end

  test "every UCS-2 byte order discards malformed units directly to explicit UCS-4" do
    for source <- @explicit_ucs2, target <- @explicit_ucs4 do
      source_endian = endian(source)
      target_endian = endian(target)

      input =
        encode_words16([?A, 0xD800, ?B, 0xDC00, 0xFFFE, 0xFEFF], source_endian) <>
          <<0xAA>>

      assert UnicodeCodec.direct_convert(input, source, target, :discard, :error) ==
               {:ok, encode_words32([?A, ?B, 0xFFFE, 0xFEFF], target_endian)}
    end
  end

  test "generic UCS-2 direct decode consumes BOMs and switches byte order" do
    input =
      encode_words16([0xFEFF, ?A, 0xFFFE], :big) <>
        encode_words16([?B, 0xFEFF, ?C, 0xFFFE], :little) <>
        encode_words16([?D], :big) <>
        <<0xAA>>

    assert UnicodeCodec.direct_convert(input, :ucs2, :ucs4be, :discard, :error) ==
             {:ok, encode_words32(~c"ABCD", :big)}
  end

  test "direct UCS-2 decode exhaustively covers all 65,536 code units" do
    retained = Enum.reject(0..0xFFFF, &(&1 in 0xD800..0xDFFF))

    for source <- @explicit_ucs2, target <- @explicit_ucs4 do
      input = encode_words16(0..0xFFFF, endian(source))
      expected = encode_words32(retained, endian(target))

      assert UnicodeCodec.direct_convert(input, source, target, :discard, :error) ==
               {:ok, expected}
    end

    generic_input = encode_words16(0..0xFFFF, :big)
    {:ok, generic_codepoints} = UnicodeCodec.decode_discard(%{id: :ucs2}, generic_input)

    assert UnicodeCodec.direct_convert(
             generic_input,
             :ucs2,
             :ucs4be,
             :discard,
             :error
           ) == {:ok, encode_words32(generic_codepoints, :big)}
  end

  test "generic UCS-2 direct decode matches native recovery across marker interactions" do
    units = [
      <<0x00, 0x41>>,
      <<0x41, 0x00>>,
      <<0xD8, 0x00>>,
      <<0x00, 0xD8>>,
      <<0xDC, 0x00>>,
      <<0x00, 0xDC>>,
      <<0xFE, 0xFF>>,
      <<0xFF, 0xFE>>
    ]

    for first <- units, second <- units, third <- units, tail <- [<<>>, <<0xAA>>] do
      input = first <> second <> third <> tail
      {:ok, expected_codepoints} = UnicodeCodec.decode_discard(%{id: :ucs2}, input)

      assert UnicodeCodec.direct_convert(input, :ucs2, :ucs4be, :discard, :error) ==
               {:ok, encode_words32(expected_codepoints, :big)}
    end
  end

  test "UTF-16 direct discard preserves scalar, sentinel, and BOM policy" do
    codepoints = [?A, 0xD800, 0xFFFE, 0xFEFF, 0x10000, 0x10FFFF, 0x11_0000]

    for source <- @explicit_ucs4, target <- ~w(utf16be utf16le)a do
      expected =
        :unicode.characters_to_binary(
          [?A, 0xFFFE, 0xFEFF, 0x10000, 0x10FFFF],
          :unicode,
          {:utf16, endian(target)}
        )

      input = encode_words32(codepoints, endian(source))

      assert UnicodeCodec.direct_convert(input, source, target, :error, :discard) ==
               {:ok, expected}
    end

    expected_body =
      :unicode.characters_to_binary(
        [?A, 0xFEFF, 0x10000, 0x10FFFF],
        :unicode,
        {:utf16, :big}
      )

    for source <- @explicit_ucs4 do
      input = encode_words32(codepoints, endian(source))

      assert UnicodeCodec.direct_convert(input, source, :utf16, :error, :discard) ==
               {:ok, <<0xFE, 0xFF, expected_body::binary>>}
    end

    assert UnicodeCodec.direct_convert(
             encode_words32([0xD800, 0x11_0000], :big),
             :ucs4be,
             :utf16,
             :error,
             :discard
           ) == {:ok, <<>>}
  end

  test "public direct routes remain gated by default fallback and callback policy" do
    assert Iconvex.convert(encode_words32([0x10000], :big), "UCS-4BE", "UCS-2BE") ==
             {:ok, <<0xFF, 0xFD>>}

    parent = self()

    callback = fn event ->
      send(parent, {:invalid_ucs2, event})
      :error
    end

    assert {:error,
            %Iconvex.Error{
              kind: :invalid_sequence,
              encoding: "UCS-2BE",
              offset: 2,
              sequence: <<0xD8, 0x00>>
            }} =
             Iconvex.convert(
               encode_words16([?A, 0xD800, ?B], :big),
               "UCS-2BE",
               "UCS-4BE",
               invalid: :discard,
               on_invalid_byte: callback
             )

    assert_receive {:invalid_ucs2,
                    %Iconvex.InvalidByte{offset: 2, byte: 0xD8, sequence: <<0xD8, 0x00>>}}
  end

  test "explicit UCS-4 target writes contiguous non-scalar list values natively" do
    codepoints =
      [?A] ++
        List.duplicate(0xD800, 128) ++
        [?B] ++ List.duplicate(0x11_0000, 128) ++ [?C]

    {result, bif_calls} =
      count_calls({:unicode, :characters_to_binary, 3}, fn ->
        UnicodeCodec.encode_discard(%{id: :ucs4be}, codepoints)
      end)

    assert result == {:ok, encode_words32(codepoints, :big)}
    assert bif_calls == 0
  end

  test "explicit UCS-4 list targets preserve extended values, tags, errors, and byte order" do
    codepoints = [0, 0xD800, 0x10FFFF, 0x11_0000, 0xE0000, 0xFFFFFFFF]

    for target <- @explicit_ucs4 do
      expected = encode_words32(codepoints, endian(target))

      assert UnicodeCodec.encode(%{id: target}, codepoints) == {:ok, expected}

      assert UnicodeCodec.encode(%{id: target}, [?A, 0x1_0000_0000, ?B]) ==
               {:error, :unrepresentable_character, 0x1_0000_0000}

      assert UnicodeCodec.encode_discard(%{id: target}, [?A, 0x1_0000_0000, ?B]) ==
               {:ok, encode_words32(~c"AB", endian(target))}
    end
  end

  test "explicit UTF-32 discard converts directly to explicit UCS-4 with exact policy" do
    values = [?A, 0xD800, ?B, 0x11_0000, ?C]

    for source <- @explicit_utf32, target <- @explicit_ucs4 do
      input = encode_words32(values, endian(source)) <> <<0xAA>>

      assert UnicodeCodec.direct_convert(input, source, target, :discard, :error) ==
               {:ok, encode_words32(~c"ABC", endian(target))}
    end

    generic =
      encode_words32([0xFEFF, ?A, 0xFFFE0000], :big) <>
        encode_words32([?B, 0xFEFF, ?C, 0xFFFE0000], :little) <>
        encode_words32([?D], :big) <>
        <<0xAA>>

    for target <- @explicit_ucs4 do
      assert UnicodeCodec.direct_convert(generic, :utf32, target, :discard, :error) ==
               {:ok, encode_words32(~c"ABCD", endian(target))}
    end
  end

  test "UTF-32 and escape-source callbacks retain the first source error" do
    parent = self()

    callback = fn event ->
      send(parent, {:first_source_error, event})
      :error
    end

    assert {:error,
            %Iconvex.Error{
              kind: :invalid_sequence,
              encoding: "UTF-32BE",
              offset: 4,
              sequence: <<0x00, 0x00, 0xD8, 0x00>>
            }} =
             Iconvex.convert(
               encode_words32([?A, 0xD800, ?B], :big),
               "UTF-32BE",
               "UCS-4BE",
               invalid: :discard,
               on_invalid_byte: callback
             )

    assert_receive {:first_source_error,
                    %Iconvex.InvalidByte{offset: 4, byte: 0, sequence: <<0, 0, 0xD8, 0>>}}

    for {source, input} <- [{"C99", "\\u12"}, {"JAVA", "\\u12"}] do
      assert {:error,
              %Iconvex.Error{
                kind: :incomplete_sequence,
                encoding: ^source,
                offset: 0,
                sequence: ^input
              }} =
               Iconvex.convert(input, source, "UCS-4BE",
                 invalid: :discard,
                 on_invalid_byte: callback
               )

      assert_receive {:first_source_error,
                      %Iconvex.InvalidByte{offset: 0, byte: ?\\, sequence: ^input}}
    end
  end

  defp endian(:ucs2be), do: :big
  defp endian(:ucs2le), do: :little
  defp endian(:utf16be), do: :big
  defp endian(:utf16le), do: :little
  defp endian(:utf32be), do: :big
  defp endian(:utf32le), do: :little
  defp endian(:ucs4be), do: :big
  defp endian(:ucs4le), do: :little
  defp endian(:ucs2internal), do: :erlang.system_info(:endian)
  defp endian(:ucs4internal), do: :erlang.system_info(:endian)

  defp endian(:ucs2swapped),
    do: swap(:erlang.system_info(:endian))

  defp endian(:ucs4swapped),
    do: swap(:erlang.system_info(:endian))

  defp swap(:big), do: :little
  defp swap(:little), do: :big

  defp encode_words16(words, :big),
    do: Enum.map_join(words, &<<&1::unsigned-big-16>>)

  defp encode_words16(words, :little),
    do: Enum.map_join(words, &<<&1::unsigned-little-16>>)

  defp encode_words32(words, :big),
    do: Enum.map_join(words, &<<&1::unsigned-big-32>>)

  defp encode_words32(words, :little),
    do: Enum.map_join(words, &<<&1::unsigned-little-32>>)

  defp count_calls({module, _name, _arity} = mfa, function) do
    Code.ensure_loaded!(module)
    :erlang.trace_pattern(mfa, true, [:local, :call_count])

    try do
      result = function.()
      {:call_count, count} = :erlang.trace_info(mfa, :call_count)
      {result, count}
    after
      :erlang.trace_pattern(mfa, false, [:local, :call_count])
    end
  end
end

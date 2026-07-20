defmodule Iconvex.PerformanceFastPathTest do
  use ExUnit.Case, async: false

  alias Iconvex.{ISO2022CNCodec, ISO2022JPCodec, StatefulCodec, UnicodeCodec}

  test "UTF-32BE to generic UTF-16 discards U+FFFE without losing BOM semantics" do
    source =
      <<?A::unsigned-big-32, 0xFFFE::unsigned-big-32, 0xFEFF::unsigned-big-32,
        0x1F600::unsigned-big-32>>

    assert {:ok, encoded} =
             Iconvex.convert(source, "UTF-32BE", "UTF-16", unrepresentable: :discard)

    assert encoded == <<0xFE, 0xFF, 0, ?A, 0xFE, 0xFF, 0xD8, 0x3D, 0xDE, 0>>

    assert Iconvex.convert(encoded, "UTF-16", "UTF-32BE", invalid: :discard) ==
             {:ok, <<?A::unsigned-big-32, 0x1F600::unsigned-big-32>>}
  end

  test "generic UTF fast paths fall back for empty, unaligned, swapped, and malformed input" do
    assert Iconvex.convert(<<>>, "UTF-32BE", "UTF-16", unrepresentable: :discard) ==
             {:ok, <<>>}

    assert Iconvex.convert(<<0>>, "UTF-32BE", "UTF-16",
             invalid: :discard,
             unrepresentable: :discard
           ) == {:ok, <<>>}

    assert Iconvex.convert(<<0, 17, 0, 0>>, "UTF-32BE", "UTF-16",
             invalid: :discard,
             unrepresentable: :discard
           ) == {:ok, <<>>}

    assert Iconvex.convert(<<0xFF, 0xFE, ?A, 0>>, "UTF-16", "UTF-32BE", invalid: :discard) ==
             {:ok, <<?A::unsigned-big-32>>}

    assert Iconvex.convert(<<0xFE, 0xFF, 0>>, "UTF-16", "UTF-32BE", invalid: :discard) ==
             {:ok, <<>>}

    assert Iconvex.convert(<<0xFE, 0xFF, 0xD8, 0>>, "UTF-16", "UTF-32BE", invalid: :discard) ==
             {:ok, <<>>}

    # Marker byte pairs that straddle two code units are data, not BOMs.
    assert Iconvex.convert(<<0x00, 0xFE, 0xFF, 0x00>>, "UTF-16", "UTF-32BE") ==
             {:ok, <<0x00FE::unsigned-big-32, 0xFF00::unsigned-big-32>>}

    assert Iconvex.convert(<<0x00, 0xFF, 0xFE, 0x00>>, "UTF-16", "UTF-32BE") ==
             {:ok, <<0x00FF::unsigned-big-32, 0xFE00::unsigned-big-32>>}
  end

  test "generic UTF-16 fast path never joins surrogate halves across a BOM" do
    input = <<0xD800::unsigned-big-16, 0xFEFF::unsigned-big-16, 0xDC00::unsigned-big-16>>

    assert {:error,
            %Iconvex.Error{
              kind: :invalid_sequence,
              offset: 0,
              sequence: <<0xD8, 0x00>>
            }} = Iconvex.convert(input, "UTF-16", "UTF-32BE")

    assert Iconvex.convert(input, "UTF-16", "UTF-32BE", invalid: :discard) == {:ok, <<>>}
  end

  test "explicit Unicode direct conversion falls back for non-Unicode UCS-4 values" do
    source = <<0x11_0000::unsigned-big-32>>

    assert Iconvex.convert(source, "UCS-4BE", "UCS-4LE") ==
             {:ok, <<0x11_0000::unsigned-little-32>>}

    assert Iconvex.convert(<<0xD800::unsigned-big-32>>, "UCS-4BE", "UTF-8") == {:ok, "�"}
  end

  test "explicit UCS-4 discard paths avoid materializing a codepoint list" do
    codepoints = [?A, 0xD800, 0xFFFE, 0xFEFF, 0x10000, 0x10FFFF, 0x11_0000, 0x80000000]
    source = Enum.map_join(codepoints, &<<&1::unsigned-big-32>>)

    utf16be =
      <<?A::unsigned-big-16, 0xFFFE::unsigned-big-16, 0xFEFF::unsigned-big-16,
        0xD800::unsigned-big-16, 0xDC00::unsigned-big-16, 0xDBFF::unsigned-big-16,
        0xDFFF::unsigned-big-16>>

    utf16le =
      <<?A::unsigned-little-16, 0xFFFE::unsigned-little-16, 0xFEFF::unsigned-little-16,
        0xD800::unsigned-little-16, 0xDC00::unsigned-little-16, 0xDBFF::unsigned-little-16,
        0xDFFF::unsigned-little-16>>

    scalar_codepoints = [?A, 0xFFFE, 0xFEFF, 0x10000, 0x10FFFF]
    utf32be = Enum.map_join(scalar_codepoints, &<<&1::unsigned-big-32>>)
    utf32le = Enum.map_join(scalar_codepoints, &<<&1::unsigned-little-32>>)

    {results, decode_calls} =
      count_calls({UnicodeCodec, :decode, 2}, fn ->
        [
          Iconvex.convert!(source, "UCS-4BE", "UCS-4LE", unrepresentable: :discard),
          Iconvex.convert!(source, "UCS-4BE", "UCS-4", unrepresentable: :discard),
          Iconvex.convert!(source, "UCS-4BE", "UTF-16BE", unrepresentable: :discard),
          Iconvex.convert!(source, "UCS-4BE", "UTF-16LE", unrepresentable: :discard),
          Iconvex.convert!(source, "UCS-4BE", "UTF-16", unrepresentable: :discard),
          Iconvex.convert!(source, "UCS-4BE", "UTF-32BE", unrepresentable: :discard),
          Iconvex.convert!(source, "UCS-4BE", "UTF-32LE", unrepresentable: :discard),
          Iconvex.convert!(source, "UCS-4BE", "UTF-32", unrepresentable: :discard),
          Iconvex.convert!(source, "UCS-4BE", "JAVA", unrepresentable: :discard)
        ]
      end)

    assert results == [
             Enum.map_join(codepoints, &<<&1::unsigned-little-32>>),
             codepoints
             |> Enum.filter(&(&1 <= 0x7FFFFFFF))
             |> Enum.map_join(&<<&1::unsigned-big-32>>),
             utf16be,
             utf16le,
             <<0xFEFF::unsigned-big-16, ?A::unsigned-big-16, 0xFEFF::unsigned-big-16,
               0xD800::unsigned-big-16, 0xDC00::unsigned-big-16, 0xDBFF::unsigned-big-16,
               0xDFFF::unsigned-big-16>>,
             utf32be,
             utf32le,
             <<0xFEFF::unsigned-big-32, utf32be::binary>>,
             "A\\ud800\\ufffe\\ufeff\\ud800\\udc00\\udbff\\udfff"
           ]

    assert decode_calls == 0
  end

  test "generic UCS-4 and UTF-16 discard decode directly to explicit UCS-4" do
    generic_ucs4 =
      <<0xFEFF::unsigned-big-32, ?A::unsigned-big-32, 0xFFFE0000::unsigned-big-32,
        ?B::unsigned-little-32, 0xFEFF::unsigned-little-32, ?C::unsigned-little-32,
        0x80000000::unsigned-little-32>>

    generic_utf16 =
      <<0xFEFF::unsigned-big-16, ?A::unsigned-big-16, 0xFEFF::unsigned-big-16,
        ?B::unsigned-big-16>>

    generic_utf32 =
      <<0xFEFF::unsigned-big-32, ?A::unsigned-big-32, 0xFFFE0000::unsigned-big-32,
        ?B::unsigned-little-32, 0xFEFF::unsigned-little-32, ?C::unsigned-little-32,
        0xD800::unsigned-little-32, 0x11_0000::unsigned-little-32, 0xAA>>

    {results, decode_calls} =
      count_calls({UnicodeCodec, :decode_discard, 2}, fn ->
        [
          Iconvex.convert!(generic_ucs4, "UCS-4", "UCS-4BE", invalid: :discard),
          Iconvex.convert!(generic_utf16, "UTF-16", "UCS-4BE", invalid: :discard),
          Iconvex.convert!(generic_utf32, "UTF-32", "UCS-4BE", invalid: :discard)
        ]
      end)

    assert results == [
             <<?A::unsigned-big-32, ?B::unsigned-big-32, ?C::unsigned-big-32>>,
             <<?A::unsigned-big-32, ?B::unsigned-big-32>>,
             <<?A::unsigned-big-32, ?B::unsigned-big-32, ?C::unsigned-big-32>>
           ]

    assert decode_calls == 0
  end

  test "generic UCS-4 and UTF-32 direct discard defer to an invalid-byte callback" do
    assert {:error,
            %Iconvex.Error{
              kind: :invalid_sequence,
              offset: 0,
              sequence: <<0x80000000::unsigned-big-32>>
            }} =
             Iconvex.convert(<<0x80000000::unsigned-big-32>>, "UCS-4", "UCS-4BE",
               invalid: :discard,
               on_invalid_byte: fn _event -> :error end
             )

    assert {:error,
            %Iconvex.Error{
              kind: :invalid_sequence,
              offset: 0,
              sequence: <<0xD800::unsigned-big-32>>
            }} =
             Iconvex.convert(<<0xD800::unsigned-big-32>>, "UTF-32", "UCS-4BE",
               invalid: :discard,
               on_invalid_byte: fn _event -> :error end
             )
  end

  test "Unicode codec BIF fallbacks retain exact strict and discard contracts" do
    assert UnicodeCodec.encode(%{id: :utf16}, [0xFFFE]) ==
             {:error, :unrepresentable_character, 0xFFFE}

    assert UnicodeCodec.encode_discard(%{id: :utf16}, [?A, 0xFFFE, 0x11_0000]) ==
             {:ok, <<0xFE, 0xFF, 0, ?A>>}

    assert UnicodeCodec.encode(%{id: :utf16be}, [0x11_0000]) ==
             {:error, :unrepresentable_character, 0x11_0000}

    assert UnicodeCodec.encode(%{id: :ucs4le}, [0x11_0000]) ==
             {:ok, <<0x11_0000::unsigned-little-32>>}

    assert UnicodeCodec.decode(%{id: :ucs4le}, <<0x11_0000::unsigned-little-32>>) ==
             {:ok, [0x11_0000]}
  end

  test "explicit Unicode malformed input falls through to offset-aware native decoders" do
    assert UnicodeCodec.decode(%{id: :utf16be}, <<0xD8, 0>>) ==
             {:error, :incomplete_sequence, 0, <<0xD8, 0>>}

    assert UnicodeCodec.decode(%{id: :utf32le}, <<0, 0, 17, 0>>) ==
             {:error, :invalid_sequence, 0, <<0, 0, 17, 0>>}

    assert UnicodeCodec.decode_discard(%{id: :ucs2}, <<0xFE, 0xFF, 0xD8, 0, 0>>) ==
             {:ok, []}

    assert UnicodeCodec.decode_discard(%{id: :utf16}, <<0xFE, 0xFF, 0xD8, 0, 0, ?A>>) ==
             {:ok, [?A]}
  end

  test "stateful decoders check table application versions once per conversion" do
    repeated = 128

    cases = [
      {%{id: :iso2022_jp}, List.duplicate(0x65E5, repeated), &ISO2022JPCodec.encode/2,
       &ISO2022JPCodec.decode/2},
      {%{id: :iso2022_jp2}, List.duplicate([0xA0, 0x037A], repeated) |> List.flatten(),
       &ISO2022JPCodec.encode/2, &ISO2022JPCodec.decode/2},
      {%{id: :iso2022_cn}, List.duplicate(0x4E2D, repeated), &ISO2022CNCodec.encode/2,
       &ISO2022CNCodec.decode/2},
      {%{id: :hz}, List.duplicate(0x4E2D, repeated), &StatefulCodec.encode/2,
       &StatefulCodec.decode/2},
      {%{id: :iso2022_kr}, List.duplicate(0xD55C, repeated), &StatefulCodec.encode/2,
       &StatefulCodec.decode/2}
    ]

    for {entry, expected, encoder, decoder} <- cases do
      assert {:ok, encoded} = encoder.(entry, expected)

      {result, application_spec_calls} =
        count_application_spec_calls(fn -> decoder.(entry, encoded) end)

      assert result == {:ok, expected}

      assert application_spec_calls <= 1,
             "#{entry.id} called Application.spec/2 #{application_spec_calls} times"
    end
  end

  defp count_application_spec_calls(function) do
    Code.ensure_loaded!(Application)
    mfa = {Application, :spec, 2}
    :erlang.trace_pattern(mfa, true, [:local, :call_count])

    try do
      result = function.()
      {:call_count, count} = :erlang.trace_info(mfa, :call_count)
      {result, count}
    after
      :erlang.trace_pattern(mfa, false, [:local, :call_count])
    end
  end

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

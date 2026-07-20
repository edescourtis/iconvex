defmodule Iconvex.Specs.NativeSubstitutionTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs

  test "every registered Specs codec exports native substitution" do
    codecs = Specs.codecs()

    assert length(codecs) == 1_841

    assert [] ==
             Enum.reject(codecs, fn codec ->
               Code.ensure_loaded!(codec)
               function_exported?(codec, :encode_substitute, 2)
             end)
  end

  test "review-reproduction finite codecs use one native linear substitution pass" do
    repeated = 400
    input = :binary.copy(<<0x1F600::utf8>>, repeated)

    for {codec, canonical} <- [
          {Specs.VIQR, "VIQR"},
          {Specs.ANSEL, "ANSEL"},
          {Specs.DECSIXBIT, "DEC-SIXBIT"},
          {Specs.FieldataUNIVAC1100, "FIELDATA-UNIVAC-1100"},
          {Specs.FieldataUNIVAC4009Input, "FIELDATA-UNIVAC-4009-INPUT"},
          {Specs.FieldataUNIVAC4009Output, "FIELDATA-UNIVAC-4009-OUTPUT"},
          {Specs.FieldataUNIVAC4009LosslessVPUA, "FIELDATA-UNIVAC-4009-LOSSLESS-VPUA"}
        ] do
      {:ok, replacement} = codec.encode(~c"<U+1F600>")

      trace_call_counts(
        [{codec, :encode, 1}, {codec, :encode_substitute, 2}],
        fn ->
          assert Iconvex.convert(input, "UTF-8", canonical, unicode_substitute: "<U+%04X>") ==
                   {:ok, :binary.copy(replacement, repeated)}

          assert trace_call_count({codec, :encode_substitute, 2}) == 1
          assert trace_call_count({codec, :encode, 1}) <= 2 * repeated + 1
        end
      )
    end
  end

  test "table substitution preserves longest compound mappings in one pass" do
    registration =
      Enum.find(Specs.registrations(), &(&1.declared_canonical == "MacKeyboard"))

    table = Iconvex.Tables.fetch!(registration.codec.codec_id())

    {codepoints, bytes} =
      Enum.find(table.encode, fn {codepoints, _bytes} -> tuple_size(codepoints) in 3..4 end)

    {replacement, replacement_bytes} =
      Enum.find(table.encode, fn {codepoints, _bytes} -> tuple_size(codepoints) == 1 end)

    Process.put(:native_substitution_calls, 0)

    replacer = fn _codepoint ->
      Process.put(:native_substitution_calls, Process.get(:native_substitution_calls) + 1)
      Tuple.to_list(replacement)
    end

    input = Tuple.to_list(codepoints) ++ [0x1F600] ++ Tuple.to_list(codepoints)

    assert registration.codec.encode_substitute(input, replacer) ==
             {:ok, bytes <> replacement_bytes <> bytes}

    assert Process.get(:native_substitution_calls) == 1
  after
    Process.delete(:native_substitution_calls)
  end

  test "ISO-2022-JP-EXT substitution enters the stateful engine exactly once" do
    repeated = 400
    input = :binary.copy(<<0x1F600::utf8>>, repeated)

    trace_call_counts(
      [
        {Iconvex.ISO2022JPCodec, :encode, 2},
        {Iconvex.ISO2022JPCodec, :encode_substitute, 3}
      ],
      fn ->
        assert Iconvex.convert(input, "UTF-8", "ISO-2022-JP-EXT", unicode_substitute: "<U+%04X>") ==
                 {:ok, :binary.copy("<U+1F600>", repeated)}

        assert trace_call_count({Iconvex.ISO2022JPCodec, :encode, 2}) == 0
        assert trace_call_count({Iconvex.ISO2022JPCodec, :encode_substitute, 3}) == 1
      end
    )
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

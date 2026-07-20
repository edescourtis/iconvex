defmodule Iconvex.Specs.ExternalUTF8FirstErrorOrderTest do
  use ExUnit.Case, async: false

  @unrepresentable_candidates [0x2603, 0x30000, 0x10FFFF, 0x1F600, 0x0100, 0x20AC]
  @malformed_suffixes [
    {:invalid_sequence, <<0xFF>>},
    {:incomplete_sequence, <<0xF0, 0x9F>>}
  ]

  test "every direct Specs encoder preserves an earlier target error before malformed UTF-8" do
    codecs = direct_codecs()
    assert length(codecs) == 1_841

    cases =
      Enum.flat_map(codecs, fn registration ->
        case Enum.find(@unrepresentable_candidates, fn codepoint ->
               target_error?(registration.codec.encode([codepoint]), codepoint)
             end) do
          nil -> []
          codepoint -> [{registration, codepoint}]
        end
      end)

    assert length(cases) == 1_804

    failures =
      for {registration, codepoint} <- cases,
          {source_kind, suffix} <- @malformed_suffixes,
          path <- [:direct, :public],
          result = result(path, registration, <<codepoint::utf8, suffix::binary>>),
          not target_error?(result, codepoint) do
        {registration.canonical, registration.codec, source_kind, path, result}
      end

    assert failures == [],
           "#{length(failures)} first-error violations: #{inspect(Enum.take(failures, 30), limit: :infinity)}"
  end

  defp direct_codecs do
    Iconvex.Specs.registrations()
    |> Enum.uniq_by(& &1.codec)
    |> Enum.filter(&function_exported?(&1.codec, :encode_from_utf8, 1))
  end

  defp result(:direct, registration, input), do: registration.codec.encode_from_utf8(input)

  defp result(:public, registration, input),
    do: Iconvex.convert(input, "UTF-8", registration.canonical)

  defp target_error?({:error, :unrepresentable_character, codepoint}, codepoint), do: true
  defp target_error?({:encode_error, :unrepresentable_character, codepoint}, codepoint), do: true

  defp target_error?(
         {:error, %Iconvex.Error{kind: :unrepresentable_character, codepoint: codepoint}},
         codepoint
       ),
       do: true

  defp target_error?(_result, _codepoint), do: false
end

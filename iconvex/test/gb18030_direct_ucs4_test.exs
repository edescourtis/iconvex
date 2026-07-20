defmodule Iconvex.GB18030DirectUCS4Test do
  use ExUnit.Case, async: false

  alias Iconvex.GB18030Codec

  test "direct discard decode preserves malformed recovery and incomplete tails" do
    for {name, id} <- [{"GB18030", :gb18030_2005}, {"GB18030:2022", :gb18030_2022}] do
      valid = Iconvex.convert!("A一😀Z", "UTF-8", name)

      input =
        valid <>
          <<0x81, 0x30, 0x81, 0x41, 0xFF>> <>
          valid <>
          <<0x90, 0x30, 0x81>>

      for {target, endian} <- [{"UCS-4BE", :big}, {"UCS-4LE", :little}] do
        reference =
          Iconvex.convert!(input, name, target,
            invalid: :discard,
            on_invalid_byte: fn _event -> :discard end
          )

        assert GB18030Codec.decode_to_explicit_ucs4_discard(%{id: id}, input, endian) ==
                 {:ok, reference}

        {result, calls} =
          count_calls([{GB18030Codec, :decode, 2}], fn ->
            Iconvex.convert!(input, name, target, invalid: :discard)
          end)

        assert result == reference
        assert calls[{GB18030Codec, :decode, 2}] == 0
      end
    end
  end

  test "direct supplementary decode reductions scale linearly" do
    unit = <<0x90, 0x30, 0x81, 0x30>>
    small = :binary.copy(unit, 4_096)
    large = :binary.copy(unit, 8_192)
    entry = %{id: :gb18030_2005}

    assert {:ok, _output} = GB18030Codec.decode_to_explicit_ucs4_discard(entry, small, :big)

    small_reductions =
      reductions(fn -> GB18030Codec.decode_to_explicit_ucs4_discard(entry, small, :big) end)

    large_reductions =
      reductions(fn -> GB18030Codec.decode_to_explicit_ucs4_discard(entry, large, :big) end)

    assert large_reductions <= small_reductions * 2.25 + 1_000
  end

  defp count_calls(mfas, function) do
    Enum.each(mfas, fn {module, _name, _arity} = mfa ->
      Code.ensure_loaded!(module)
      :erlang.trace_pattern(mfa, true, [:local, :call_count])
    end)

    try do
      result = function.()

      calls =
        Map.new(mfas, fn mfa ->
          {:call_count, count} = :erlang.trace_info(mfa, :call_count)
          {mfa, count}
        end)

      {result, calls}
    after
      Enum.each(mfas, &:erlang.trace_pattern(&1, false, [:local, :call_count]))
    end
  end

  defp reductions(function) do
    {:reductions, before_count} = Process.info(self(), :reductions)
    function.()
    {:reductions, after_count} = Process.info(self(), :reductions)
    after_count - before_count
  end
end

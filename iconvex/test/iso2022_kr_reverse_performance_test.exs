defmodule Iconvex.ISO2022KRReversePerformanceTest do
  use ExUnit.Case, async: false

  alias Iconvex.StatefulPairCache

  @corpus Path.expand("fixtures/all-unicode-codepoints.ucs4be", __DIR__)
  @encoded_sha256 "ace54173454b6d2baaa97952a4d31f712e0bf9ef468eb9754ca56baac42d6e9f"
  @roundtrip_sha256 "d175c3852790a9bf22c978209c85abc3f827ed0ba150f256659bc4ff0bc98549"

  @tag timeout: 30_000
  test "RED: exhaustive ISO-2022-KR reverse decode has one bulk dense-table path" do
    encoded =
      @corpus
      |> File.read!()
      |> Iconvex.convert!("UCS-4BE", "ISO-2022-KR", unrepresentable: :discard)

    assert byte_size(encoded) == 16_588
    assert sha256(encoded) == @encoded_sha256

    {traced_output, pair_lookup_calls} = traced_reverse(encoded)

    assert byte_size(traced_output) == 33_408
    assert sha256(traced_output) == @roundtrip_sha256

    # A cache descriptor is acquired once per conversion. Dispatching through
    # a public lookup helper for every one of the 8,227 Korean pairs consumed
    # most of the reverse-decode budget despite retaining linear complexity.
    assert pair_lookup_calls == 0

    {measured_output, reductions} = measured_reverse(encoded)

    assert measured_output == traced_output
    assert reductions <= 25_000
  end

  defp traced_reverse(encoded) do
    Code.ensure_loaded!(StatefulPairCache)
    mfa = {StatefulPairCache, :lookup, 4}
    :erlang.trace_pattern(mfa, true, [:local, :call_count])

    try do
      output =
        Iconvex.convert!(encoded, "ISO-2022-KR", "UCS-4BE", invalid: :discard)

      {:call_count, call_count} = :erlang.trace_info(mfa, :call_count)
      {output, call_count}
    after
      :erlang.trace_pattern(mfa, false, [:local, :call_count])
    end
  end

  defp measured_reverse(encoded) do
    owner = self()
    reference = make_ref()

    {_pid, monitor} =
      :erlang.spawn_opt(
        fn ->
          _warm = Iconvex.convert!(encoded, "ISO-2022-KR", "UCS-4BE", invalid: :discard)
          {:reductions, before_count} = Process.info(self(), :reductions)
          output = Iconvex.convert!(encoded, "ISO-2022-KR", "UCS-4BE", invalid: :discard)
          {:reductions, after_count} = Process.info(self(), :reductions)
          send(owner, {reference, output, after_count - before_count})
        end,
        [:monitor, {:min_heap_size, 200_000}]
      )

    receive do
      {^reference, output, reductions} ->
        Process.demonitor(monitor, [:flush])
        {output, reductions}

      {:DOWN, ^monitor, :process, _pid, reason} ->
        flunk("isolated reverse-decode measurement exited: #{inspect(reason)}")
    after
      5_000 -> flunk("isolated reverse-decode measurement timed out")
    end
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

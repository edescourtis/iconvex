defmodule Iconvex.Telecom.PackedFacadeBenchmark do
  @iterations 9
  @warmups 2
  @input :binary.copy("hellohello", 6_554)

  def run do
    {:ok, dedicated} = Iconvex.Telecom.GSM0338.Packing.pack(@input)
    {:ok, generic} = Iconvex.Packed.pack_lsb(@input, 7)

    old_pack = measure(fn -> Iconvex.Telecom.GSM0338.Packing.pack(@input) end)
    new_pack = measure(fn -> Iconvex.Packed.pack_lsb(@input, 7) end)

    old_unpack =
      measure(fn ->
        Iconvex.Telecom.GSM0338.Packing.unpack(dedicated, byte_size(@input))
      end)

    new_unpack =
      measure(fn -> Iconvex.Packed.unpack_lsb(generic.data, generic.bit_size, 7) end)

    IO.puts("input bytes: #{byte_size(@input)}")
    result("integer GSM pack", old_pack, nil)
    result("streaming generic pack", new_pack, old_pack / new_pack)
    result("integer GSM unpack", old_unpack, nil)
    result("streaming generic unpack", new_unpack, old_unpack / new_unpack)

    Iconvex.Telecom.Packed.profile("GSM0338")

    lookup =
      measure(fn ->
        for _ <- 1..10_000, do: Iconvex.Telecom.Packed.profile("GSM0338")
        {:ok, :lookups}
      end)

    IO.puts(:io_lib.format("cached profile lookup ~12.2f ns/op", [lookup / 10.0]))
  end

  defp measure(function) do
    Enum.each(1..@warmups, fn _ -> assert_ok(function.()) end)

    for _ <- 1..@iterations do
      :erlang.garbage_collect()
      {microseconds, result} = :timer.tc(function)
      assert_ok(result)
      microseconds
    end
    |> Enum.sort()
    |> Enum.at(div(@iterations, 2))
  end

  defp result(name, microseconds, nil),
    do: IO.puts(:io_lib.format("~-26s ~10.2f ms", [name, microseconds / 1_000]))

  defp result(name, microseconds, speedup),
    do: IO.puts(:io_lib.format("~-26s ~10.2f ms  ~8.2fx", [name, microseconds / 1_000, speedup]))

  defp assert_ok({:ok, _result}), do: :ok
  defp assert_ok(error), do: raise("packed benchmark failed: #{inspect(error)}")
end

Iconvex.Telecom.PackedFacadeBenchmark.run()

defmodule Iconvex.PackedBenchmark do
  import Bitwise

  @iterations 7
  @warmups 2
  @bytes 1_048_576

  def run do
    for width <- [5, 6, 7] do
      mask = (1 <<< width) - 1
      input = for(index <- 0..(@bytes - 1), into: <<>>, do: <<index &&& mask>>)
      {:ok, msb} = Iconvex.Packed.pack(input, width)
      {:ok, lsb} = Iconvex.Packed.pack_lsb(input, width)

      measure("#{width}-bit MSB pack", input, fn -> Iconvex.Packed.pack(input, width) end)
      measure("#{width}-bit MSB unpack", input, fn -> Iconvex.Packed.unpack(msb, width) end)
      measure("#{width}-bit LSB pack", input, fn -> Iconvex.Packed.pack_lsb(input, width) end)

      measure("#{width}-bit LSB unpack", input, fn ->
        Iconvex.Packed.unpack_lsb(lsb.data, lsb.bit_size, width)
      end)
    end
  end

  defp measure(name, input, function) do
    Enum.each(1..@warmups, fn _ -> assert_ok(function.()) end)

    samples =
      for _ <- 1..@iterations do
        :erlang.garbage_collect()
        {microseconds, result} = :timer.tc(function)
        assert_ok(result)
        microseconds
      end

    median = samples |> Enum.sort() |> Enum.at(div(@iterations, 2))
    rate = byte_size(input) / 1_048_576 / (median / 1_000_000)
    IO.puts(:io_lib.format("~-24s ~8.2f MiB/s  ~8.2f ms", [name, rate, median / 1_000]))
  end

  defp assert_ok({:ok, _result}), do: :ok
  defp assert_ok(error), do: raise("packed benchmark failed: #{inspect(error)}")
end

Iconvex.PackedBenchmark.run()

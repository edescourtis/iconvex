defmodule Iconvex.Specs.NonOctetBenchmark do
  @iterations 9
  @warmups 2
  @scalars :lists.duplicate(4_096, [?A, 0x0391, 0x10330, 0xE0041]) |> List.flatten()
  @utf18_scalars Enum.filter(@scalars, &(&1 <= 0x2FFFF or &1 in 0xE0000..0xEFFFF))

  def run do
    {:ok, utf9_packed} = Iconvex.Specs.UTF9.encode_packed(@scalars)
    {:ok, utf9_words} = Iconvex.Specs.UTF9BE16.encode(@scalars)
    {:ok, utf18_packed} = Iconvex.Specs.UTF18.encode_packed(@utf18_scalars)
    {:ok, utf18_words} = Iconvex.Specs.UTF18BE24.encode(@utf18_scalars)

    bench("UTF-9 packed encode", length(@scalars), fn ->
      Iconvex.Specs.UTF9.encode_packed(@scalars)
    end)

    bench("UTF-9 packed decode", length(@scalars), fn ->
      Iconvex.Specs.UTF9.decode_packed(utf9_packed)
    end)

    bench("UTF-9 16BE encode", length(@scalars), fn ->
      Iconvex.Specs.UTF9BE16.encode(@scalars)
    end)

    bench("UTF-9 16BE decode", length(@scalars), fn ->
      Iconvex.Specs.UTF9BE16.decode(utf9_words)
    end)

    bench("UTF-18 packed encode", length(@utf18_scalars), fn ->
      Iconvex.Specs.UTF18.encode_packed(@utf18_scalars)
    end)

    bench("UTF-18 packed decode", length(@utf18_scalars), fn ->
      Iconvex.Specs.UTF18.decode_packed(utf18_packed)
    end)

    bench("UTF-18 24BE encode", length(@utf18_scalars), fn ->
      Iconvex.Specs.UTF18BE24.encode(@utf18_scalars)
    end)

    bench("UTF-18 24BE decode", length(@utf18_scalars), fn ->
      Iconvex.Specs.UTF18BE24.decode(utf18_words)
    end)
  end

  defp bench(name, scalar_count, function) do
    Enum.each(1..@warmups, fn _ -> assert_ok(function.()) end)

    median =
      for _ <- 1..@iterations do
        :erlang.garbage_collect()
        {microseconds, result} = :timer.tc(function)
        assert_ok(result)
        microseconds
      end
      |> Enum.sort()
      |> Enum.at(div(@iterations, 2))

    IO.puts(
      :io_lib.format("~-24s ~12.2f scalars/s  ~8.2f ms", [
        name,
        scalar_count * 1_000_000 / median,
        median / 1_000
      ])
    )
  end

  defp assert_ok({:ok, _result}), do: :ok
  defp assert_ok(error), do: raise("non-octet benchmark failed: #{inspect(error)}")
end

Iconvex.Specs.NonOctetBenchmark.run()

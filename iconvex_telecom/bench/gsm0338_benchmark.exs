Mix.Task.run("app.start")

defmodule Iconvex.Telecom.GSM0338Benchmark do
  @iterations 12
  @warmups 3
  @small_iterations 100_000

  alias Iconvex.Telecom.GSM0338.{Engine, Tables}

  def run do
    utf8 = String.duplicate("Merhaba €; Ğğ Şş İı ç ^ {x} [y] | ~\n", 30_000)
    encoded = Iconvex.convert!(utf8, "UTF-8", "GSM0338-TURKISH")
    small = binary_part(encoded, 0, min(byte_size(encoded), 160))

    locking_utf8 =
      Tables.locking(1) |> Tuple.to_list() |> Enum.map(&<<&1::utf8>>) |> List.to_tuple()

    single_utf8 =
      Tables.single_shift(1)
      |> Tuple.to_list()
      |> Enum.map(fn
        nil -> nil
        codepoint -> <<codepoint::utf8>>
      end)
      |> List.to_tuple()

    IO.puts("Iconvex Telecom GSM 03.38 benchmark")
    IO.puts("OTP #{System.otp_release()} / Elixir #{System.version()}")
    IO.puts("#{@iterations} measured iterations after #{@warmups} warmups")

    throughput("direct GSM -> UTF-8", encoded, fn -> Engine.decode_to_utf8(encoded, 1, 1) end)

    throughput("old binary-iolist decode", encoded, fn ->
      legacy_decode(encoded, locking_utf8, single_utf8, [])
    end)

    throughput("codepoints GSM -> UTF-8", encoded, fn ->
      {:ok, points} = Engine.decode(encoded, 1, 1)
      {:ok, List.to_string(points)}
    end)

    throughput("Iconvex GSM -> UTF-8", encoded, fn ->
      Iconvex.convert(encoded, "GSM0338-TURKISH", "UTF-8")
    end)

    throughput("direct UTF-8 -> GSM", utf8, fn -> Engine.encode_from_utf8(utf8, 1, 1) end)

    throughput("old tiny-binary encode", utf8, fn ->
      legacy_encode(
        String.to_charlist(utf8),
        Tables.locking_encode(1),
        Tables.single_encode(1),
        []
      )
    end)

    throughput("codepoints UTF-8 -> GSM", utf8, fn ->
      Engine.encode(String.to_charlist(utf8), 1, 1)
    end)

    throughput("Iconvex UTF-8 -> GSM", utf8, fn ->
      Iconvex.convert(utf8, "UTF-8", "GSM0338-TURKISH")
    end)

    operations("160-byte decode", fn -> Engine.decode_to_utf8(small, 1, 1) end)
    {:ok, small_utf8} = Engine.decode_to_utf8(small, 1, 1)
    operations("160-byte encode", fn -> Engine.encode_from_utf8(small_utf8, 1, 1) end)
  end

  defp throughput(name, input, function) do
    Enum.each(1..@warmups, fn _ -> function.() end)
    {before_reductions, _} = :erlang.statistics(:reductions)

    samples =
      Enum.map(1..@iterations, fn _ ->
        :erlang.garbage_collect()
        {microseconds, {:ok, output}} = :timer.tc(function)
        true = is_binary(output)
        microseconds
      end)

    {after_reductions, _} = :erlang.statistics(:reductions)
    median = samples |> Enum.sort() |> Enum.at(div(@iterations, 2))
    mib_per_second = byte_size(input) / 1_048_576 / (median / 1_000_000)
    reductions = div(after_reductions - before_reductions, @iterations)

    IO.puts(
      :io_lib.format("~-28s ~8.2f MiB/s  ~8.2f ms  ~10B reductions", [
        name,
        mib_per_second,
        median / 1000,
        reductions
      ])
    )
  end

  defp operations(name, function) do
    Enum.each(1..10_000, fn _ -> function.() end)

    {microseconds, _result} =
      :timer.tc(fn -> Enum.each(1..@small_iterations, fn _ -> function.() end) end)

    per_second = round(@small_iterations / (microseconds / 1_000_000))
    IO.puts(:io_lib.format("~-28s ~12B operations/s", [name, per_second]))
  end

  defp legacy_decode(<<>>, _locking, _single, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp legacy_decode(<<0x1B, 0x1B, rest::binary>>, locking, single, acc),
    do: legacy_decode(rest, locking, single, [" " | acc])

  defp legacy_decode(<<0x1B, byte, rest::binary>>, locking, single, acc),
    do: legacy_decode(rest, locking, single, [elem(single, byte) || elem(locking, byte) | acc])

  defp legacy_decode(<<byte, rest::binary>>, locking, single, acc),
    do: legacy_decode(rest, locking, single, [elem(locking, byte) | acc])

  defp legacy_encode([], _locking, _single, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp legacy_encode([codepoint | rest], locking, single, acc) do
    bytes =
      case locking do
        %{^codepoint => byte} -> <<byte>>
        _ -> Map.fetch!(single, codepoint)
      end

    legacy_encode(rest, locking, single, [bytes | acc])
  end
end

Iconvex.Telecom.GSM0338Benchmark.run()

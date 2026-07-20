Mix.Task.run("app.start")

defmodule Iconvex.Extras.Benchmark do
  @iterations 12
  @warmups 3

  def run do
    japanese = :binary.copy("日本語の文字コード変換を高速に。", 24_000)
    encoded = Iconvex.convert!(japanese, "UTF-8", "CP932")

    true = encoded == Iconvex.convert!(japanese, "UTF-8", "CP943")

    cases = [
      {"core CP932 -> UTF-8", encoded,
       fn -> Iconvex.convert!(encoded, "CP932", "UTF-8") end},
      {"extras CP943 -> UTF-8", encoded,
       fn -> Iconvex.convert!(encoded, "CP943", "UTF-8") end},
      {"UTF-8 -> core CP932", japanese,
       fn -> Iconvex.convert!(japanese, "UTF-8", "CP932") end},
      {"UTF-8 -> extras CP943", japanese,
       fn -> Iconvex.convert!(japanese, "UTF-8", "CP943") end}
    ]

    IO.puts("Iconvex Extras benchmark (#{@iterations} iterations, #{@warmups} warmups)")
    IO.puts("OTP #{System.otp_release()} / Elixir #{System.version()}")
    Enum.each(cases, fn {name, input, function} -> benchmark(name, input, function) end)
  end

  defp benchmark(name, input, function) do
    Enum.each(1..@warmups, fn _ -> function.() end)
    {before_reductions, _} = :erlang.statistics(:reductions)

    samples =
      Enum.map(1..@iterations, fn _ ->
        {microseconds, result} = :timer.tc(function)
        true = is_binary(result)
        microseconds
      end)

    {after_reductions, _} = :erlang.statistics(:reductions)
    median = samples |> Enum.sort() |> Enum.at(div(@iterations, 2))
    mib_per_second = byte_size(input) / 1_048_576 / (median / 1_000_000)
    reductions = div(after_reductions - before_reductions, @iterations)

    IO.puts(
      :io_lib.format("~-25s ~8.2f MiB/s  ~8.2f ms  ~10B reductions", [
        name,
        mib_per_second,
        median / 1000,
        reductions
      ])
    )
  end
end

Iconvex.Extras.Benchmark.run()

Mix.Task.run("app.start")

defmodule Iconvex.Benchmark do
  @iterations 12
  @warmups 3

  def run do
    latin = :binary.copy("The café costs £5 — déjà vu. ", 35_000)
    japanese = :binary.copy("日本語の文字コード変換を高速に。", 24_000)
    mixed = :binary.copy("中文 日本語 한글 café 😀 ", 25_000)

    cp1252 = Iconvex.convert!(latin, "UTF-8", "CP1252")
    shift_jis = Iconvex.convert!(japanese, "UTF-8", "SHIFT_JIS")
    gb18030 = Iconvex.convert!(mixed, "UTF-8", "GB18030")

    cases = [
      {"UTF-8 -> UTF-8", latin, fn -> Iconvex.convert!(latin, "UTF-8", "UTF-8") end},
      {"CP1252 -> UTF-8", cp1252, fn -> Iconvex.convert!(cp1252, "CP1252", "UTF-8") end},
      {"UTF-8 -> CP1252", latin, fn -> Iconvex.convert!(latin, "UTF-8", "CP1252") end},
      {"SHIFT_JIS -> UTF-8", shift_jis,
       fn -> Iconvex.convert!(shift_jis, "SHIFT_JIS", "UTF-8") end},
      {"UTF-8 -> SHIFT_JIS", japanese,
       fn -> Iconvex.convert!(japanese, "UTF-8", "SHIFT_JIS") end},
      {"GB18030 -> UTF-8", gb18030, fn -> Iconvex.convert!(gb18030, "GB18030", "UTF-8") end},
      {"UTF-8 -> GB18030", mixed, fn -> Iconvex.convert!(mixed, "UTF-8", "GB18030") end}
    ]

    IO.puts("Iconvex benchmark (#{@iterations} measured iterations, #{@warmups} warmups)")
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
      :io_lib.format("~-23s ~8.2f MiB/s  ~8.2f ms  ~10B reductions", [
        name,
        mib_per_second,
        median / 1000,
        reductions
      ])
    )
  end
end

Iconvex.Benchmark.run()

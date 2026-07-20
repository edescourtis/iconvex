defmodule Iconvex.Specs.ECMA44Benchmark do
  @quick "--quick" in System.argv()
  @iterations if(@quick, do: 1, else: 7)
  @warmups if(@quick, do: 1, else: 2)
  @sample_repetitions if(@quick, do: 64, else: 1_024)
  @reduction_samples 3
  @reduction_lower_bound 1.75
  @reduction_upper_bound 2.25
  @modes [
    {"7-bit", :seven_bit, 0..127 |> Enum.to_list() |> :erlang.list_to_binary()},
    {"8-bit", :eight_bit, 0..255 |> Enum.to_list() |> :erlang.list_to_binary()}
  ]

  alias Iconvex.Specs.ECMA44

  def run do
    IO.puts("native ECMA-44 raw code-combination transports")

    for {name, mode, alphabet} <- @modes do
      sample = :binary.copy(alphabet, @sample_repetitions)
      {:ok, masks} = ECMA44.encode_masks(sample, mode)
      {:ok, packed_msb} = ECMA44.encode_packed(sample, mode)
      {:ok, packed_lsb} = ECMA44.encode_packed_lsb(sample, mode)
      {:ok, words_be} = ECMA44.encode_words(sample, mode, :big)
      {:ok, words_le} = ECMA44.encode_words(sample, mode, :little)

      assert_round_trip_parity!(
        name,
        mode,
        sample,
        masks,
        packed_msb,
        packed_lsb,
        words_be,
        words_le
      )

      operations = [
        {"masks encode", fn -> ECMA44.encode_masks(sample, mode) end},
        {"masks decode", fn -> ECMA44.decode_masks(masks, mode) end},
        {"packed MSB encode", fn -> ECMA44.encode_packed(sample, mode) end},
        {"packed MSB decode", fn -> ECMA44.decode_packed(packed_msb, mode) end},
        {"packed LSB encode", fn -> ECMA44.encode_packed_lsb(sample, mode) end},
        {"packed LSB decode", fn -> ECMA44.decode_packed_lsb(packed_lsb, mode) end},
        {"16BE encode", fn -> ECMA44.encode_words(sample, mode, :big) end},
        {"16BE decode", fn -> ECMA44.decode_words(words_be, mode, :big) end},
        {"16LE encode", fn -> ECMA44.encode_words(sample, mode, :little) end},
        {"16LE decode", fn -> ECMA44.decode_words(words_le, mode, :little) end}
      ]

      Enum.each(operations, fn {operation, function} ->
        bench("#{name} #{operation}", byte_size(sample), function)
      end)
    end

    IO.puts("round-trip parity: 2/2 modes x 4 serialized transports plus masks")
    reduction_scaling_gates()
  end

  defp assert_round_trip_parity!(
         name,
         mode,
         sample,
         masks,
         packed_msb,
         packed_lsb,
         words_be,
         words_le
       ) do
    decoded = [
      ECMA44.decode_masks(masks, mode),
      ECMA44.decode_packed(packed_msb, mode),
      ECMA44.decode_packed_lsb(packed_lsb, mode),
      ECMA44.decode_words(words_be, mode, :big),
      ECMA44.decode_words(words_le, mode, :little)
    ]

    unless Enum.all?(decoded, &(&1 == {:ok, sample})) do
      raise "#{name} failed raw byte round-trip parity"
    end

    unless words_le == swap_word_bytes(words_be) do
      raise "#{name} 16BE and 16LE words do not carry identical twelve-bit masks"
    end
  end

  defp reduction_scaling_gates do
    for {name, mode, _alphabet} <- @modes do
      short = :binary.copy(<<0x6B>>, 20_000)
      long = :binary.copy(<<0x6B>>, 40_000)

      {:ok, short_masks} = ECMA44.encode_masks(short, mode)
      {:ok, long_masks} = ECMA44.encode_masks(long, mode)
      {:ok, short_msb} = ECMA44.encode_packed(short, mode)
      {:ok, long_msb} = ECMA44.encode_packed(long, mode)
      {:ok, short_lsb} = ECMA44.encode_packed_lsb(short, mode)
      {:ok, long_lsb} = ECMA44.encode_packed_lsb(long, mode)
      {:ok, short_be} = ECMA44.encode_words(short, mode, :big)
      {:ok, long_be} = ECMA44.encode_words(long, mode, :big)
      {:ok, short_le} = ECMA44.encode_words(short, mode, :little)
      {:ok, long_le} = ECMA44.encode_words(long, mode, :little)

      operations = [
        {"masks encode", fn -> ECMA44.encode_masks(short, mode) end,
         fn -> ECMA44.encode_masks(long, mode) end},
        {"masks decode", fn -> ECMA44.decode_masks(short_masks, mode) end,
         fn -> ECMA44.decode_masks(long_masks, mode) end},
        {"packed MSB encode", fn -> ECMA44.encode_packed(short, mode) end,
         fn -> ECMA44.encode_packed(long, mode) end},
        {"packed MSB decode", fn -> ECMA44.decode_packed(short_msb, mode) end,
         fn -> ECMA44.decode_packed(long_msb, mode) end},
        {"packed LSB encode", fn -> ECMA44.encode_packed_lsb(short, mode) end,
         fn -> ECMA44.encode_packed_lsb(long, mode) end},
        {"packed LSB decode", fn -> ECMA44.decode_packed_lsb(short_lsb, mode) end,
         fn -> ECMA44.decode_packed_lsb(long_lsb, mode) end},
        {"16BE encode", fn -> ECMA44.encode_words(short, mode, :big) end,
         fn -> ECMA44.encode_words(long, mode, :big) end},
        {"16BE decode", fn -> ECMA44.decode_words(short_be, mode, :big) end,
         fn -> ECMA44.decode_words(long_be, mode, :big) end},
        {"16LE encode", fn -> ECMA44.encode_words(short, mode, :little) end,
         fn -> ECMA44.encode_words(long, mode, :little) end},
        {"16LE decode", fn -> ECMA44.decode_words(short_le, mode, :little) end,
         fn -> ECMA44.decode_words(long_le, mode, :little) end}
      ]

      Enum.each(operations, fn {operation, short_function, long_function} ->
        short_reductions = reduction_median(short_function)
        long_reductions = reduction_median(long_function)
        ratio = long_reductions / short_reductions

        IO.puts(
          :io_lib.format("~s ~s reduction scaling 20k->40k: ~.3fx (~B -> ~B)", [
            name,
            operation,
            ratio,
            short_reductions,
            long_reductions
          ])
        )

        unless ratio > @reduction_lower_bound and ratio < @reduction_upper_bound do
          raise "#{name} #{operation} failed the linear reduction-scaling gate: #{ratio}x"
        end
      end)
    end

    IO.puts("all 20 reduction-scaling gates passed")
  end

  defp swap_word_bytes(input) do
    for <<high, low <- input>>, into: <<>>, do: <<low, high>>
  end

  defp bench(name, count, function) do
    microseconds = median(function)

    IO.puts(
      :io_lib.format("~-31s ~12B units/s  ~8.2f ms", [
        String.to_charlist(name),
        round(count * 1_000_000 / microseconds),
        microseconds / 1_000
      ])
    )
  end

  defp median(function) do
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

  defp reduction_median(function) do
    reductions = for _ <- 1..@reduction_samples, do: isolated_reductions(function)

    reductions
    |> Enum.sort()
    |> Enum.at(div(@reduction_samples, 2))
  end

  defp isolated_reductions(function) do
    parent = self()
    token = make_ref()

    {_pid, monitor} =
      spawn_monitor(fn ->
        :erlang.garbage_collect()
        {:reductions, before_count} = Process.info(self(), :reductions)
        assert_ok(function.())
        {:reductions, after_count} = Process.info(self(), :reductions)
        send(parent, {token, after_count - before_count})
      end)

    receive do
      {^token, count} ->
        receive do
          {:DOWN, ^monitor, :process, _pid, :normal} ->
            count

          {:DOWN, ^monitor, :process, _pid, reason} ->
            raise "reduction worker failed: #{inspect(reason)}"
        after
          30_000 -> raise "reduction worker did not terminate"
        end

      {:DOWN, ^monitor, :process, _pid, reason} ->
        raise "reduction worker failed before reporting: #{inspect(reason)}"
    after
      30_000 -> raise "reduction worker timed out"
    end
  end

  defp assert_ok({:ok, _result}), do: :ok
  defp assert_ok(error), do: raise("ECMA-44 benchmark failed: #{inspect(error)}")
end

Iconvex.Specs.ECMA44Benchmark.run()

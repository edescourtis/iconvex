defmodule Iconvex.Specs.IBM2426ArrangementsBenchmark do
  @quick "--quick" in System.argv()
  @iterations if(@quick, do: 3, else: 9)
  @warmups if(@quick, do: 1, else: 3)
  @sample_repetitions if(@quick, do: 128, else: 1_024)
  @scaling_batch if(@quick, do: 5, else: 25)
  @profiles (for letter <- ~w(A B C D E F G H J K) do
               {
                 letter,
                 Module.concat(Iconvex.Specs, "IBM2426Arrangement#{letter}"),
                 Module.concat(Iconvex.Specs, "IBM2426Arrangement#{letter}16BE"),
                 Module.concat(Iconvex.Specs, "IBM2426Arrangement#{letter}16LE")
               }
             end)
  @sample List.duplicate(~c"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ", @sample_repetitions)
          |> List.flatten()

  def run do
    IO.puts("IBM 24/26 native punched-card benchmark; #{length(@sample)} characters/operation")

    for {letter, logical, be, le} <- @profiles do
      {:ok, msb} = logical.encode_packed(@sample)
      {:ok, lsb} = logical.encode_packed_lsb(@sample)
      {:ok, words_be} = be.encode(@sample)
      {:ok, words_le} = le.encode(@sample)

      results = [
        logical.decode_packed(msb),
        logical.decode_packed_lsb(lsb),
        be.decode(words_be),
        le.decode(words_le)
      ]

      unless Enum.all?(results, &(&1 == {:ok, @sample})) do
        raise "arrangement #{letter} failed four-transport round-trip parity"
      end

      operations = [
        {"packed MSB encode", fn -> logical.encode_packed(@sample) end},
        {"packed MSB decode", fn -> logical.decode_packed(msb) end},
        {"packed LSB encode", fn -> logical.encode_packed_lsb(@sample) end},
        {"packed LSB decode", fn -> logical.decode_packed_lsb(lsb) end},
        {"16BE encode", fn -> be.encode(@sample) end},
        {"16BE decode", fn -> be.decode(words_be) end},
        {"16LE encode", fn -> le.encode(@sample) end},
        {"16LE decode", fn -> le.decode(words_le) end}
      ]

      for {operation, function} <- operations do
        microseconds = median(function)

        IO.puts(
          :io_lib.format("arrangement ~s ~-17s ~12B chars/s ~8.2f ms", [
            letter,
            String.to_charlist(operation),
            round(length(@sample) * 1_000_000 / microseconds),
            microseconds / 1_000
          ])
        )
      end
    end

    IO.puts("round-trip parity: 10/10 arrangements x 4 transports")
    scaling_gates!()
    dense_reference_gate!()
  end

  defp scaling_gates! do
    codec = Iconvex.Specs.IBM2426ArrangementA16BE
    short = List.duplicate(?A, 20_000)
    long = List.duplicate(?A, 40_000)

    short_reductions = isolated_reductions(fn -> codec.encode(short) end)
    long_reductions = isolated_reductions(fn -> codec.encode(long) end)
    reduction_ratio = long_reductions / short_reductions

    unless reduction_ratio > 1.75 and reduction_ratio < 2.25 do
      raise "reduction scaling gate failed: #{reduction_ratio}x"
    end

    short_us = median(fn -> batch_encode(codec, short) end) / @scaling_batch
    long_us = median(fn -> batch_encode(codec, long) end) / @scaling_batch
    wall_ratio = long_us / short_us

    unless wall_ratio > 1.35 and wall_ratio < 3.0 do
      raise "wall scaling gate failed: #{wall_ratio}x"
    end

    IO.puts(:io_lib.format("reduction scaling 20k->40k: ~.3fx", [reduction_ratio]))
    IO.puts(:io_lib.format("wall scaling 20k->40k: ~.3fx", [wall_ratio]))
  end

  defp dense_reference_gate! do
    logical = Iconvex.Specs.IBM2426ArrangementA

    encode =
      @sample
      |> Enum.uniq()
      |> Map.new(fn codepoint ->
        {:ok, <<mask::12>>} = logical.encode_packed([codepoint])
        {codepoint, mask}
      end)

    decode =
      Enum.reduce(encode, List.duplicate(nil, 4_096), fn {codepoint, mask}, table ->
        List.replace_at(table, mask, codepoint)
      end)
      |> List.to_tuple()

    reference_encode = fn ->
      {:ok,
       @sample
       |> Enum.map(fn codepoint -> <<Map.fetch!(encode, codepoint)::12>> end)
       |> :erlang.list_to_bitstring()}
    end

    {:ok, reference_packed} = reference_encode.()

    reference_decode = fn ->
      {:ok, for(<<mask::12 <- reference_packed>>, do: elem(decode, mask))}
    end

    encode_ratio = median(fn -> logical.encode_packed(@sample) end) / median(reference_encode)

    decode_ratio =
      median(fn -> logical.decode_packed(reference_packed) end) / median(reference_decode)

    worst = max(encode_ratio, decode_ratio)

    IO.puts(
      :io_lib.format("native / dense-table reference: encode ~.3fx decode ~.3fx worst ~.3fx", [
        encode_ratio,
        decode_ratio,
        worst
      ])
    )

    if worst > 30.0, do: raise("native path exceeds 30x dense-table reference ceiling")
    IO.puts("30x regression gate: pass")
  end

  defp batch_encode(codec, codepoints) do
    Enum.reduce(1..@scaling_batch, {:ok, <<>>}, fn _, _ -> codec.encode(codepoints) end)
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
      {^token, reductions} ->
        receive do
          {:DOWN, ^monitor, :process, _pid, :normal} ->
            reductions

          {:DOWN, ^monitor, :process, _pid, reason} ->
            raise "scaling worker failed: #{inspect(reason)}"
        after
          30_000 -> raise "scaling worker did not terminate"
        end

      {:DOWN, ^monitor, :process, _pid, reason} ->
        raise "scaling worker failed before reporting: #{inspect(reason)}"
    after
      30_000 -> raise "scaling worker timed out"
    end
  end

  defp median(function) do
    Enum.each(1..@warmups, fn _ -> assert_ok(function.()) end)

    for _ <- 1..@iterations do
      :erlang.garbage_collect()
      {microseconds, result} = :timer.tc(function)
      assert_ok(result)
      max(microseconds, 1)
    end
    |> Enum.sort()
    |> Enum.at(div(@iterations, 2))
  end

  defp assert_ok({:ok, _value}), do: :ok
  defp assert_ok(other), do: raise("benchmark operation failed: #{inspect(other)}")
end

Iconvex.Specs.IBM2426ArrangementsBenchmark.run()

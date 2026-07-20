defmodule Iconvex.Specs.VietUnicodeVNIBenchmark do
  @quick "--quick" in System.argv()
  @iterations if(@quick, do: 5, else: 11)
  @warmups if(@quick, do: 1, else: 3)
  @sample_repetitions if(@quick, do: 32, else: 256)
  @reduction_samples 3
  @reduction_lower_bound 1.65
  @reduction_upper_bound 2.35
  @native_reference_ceiling 30.0
  @mapping_sha256 "86389a581bf7fc71277fcf94cb7e793f5b072b2758fc3d8404ac02dc195695aa"
  @source_path Path.expand(
                 "../priv/sources/vietunicode-vni-2002/vni_profiles.csv",
                 __DIR__
               )

  @profiles [
    {:ascii, Iconvex.Specs.VietUnicodeVNI.ASCII2002},
    {:ansi, Iconvex.Specs.VietUnicodeVNI.ANSI2002},
    {:mac, Iconvex.Specs.VietUnicodeVNI.Mac2002},
    {:email, Iconvex.Specs.VietUnicodeVNI.InternetMail2002}
  ]

  def run do
    csv = File.read!(@source_path)
    actual_sha256 = :crypto.hash(:sha256, csv) |> Base.encode16(case: :lower)

    unless actual_sha256 == @mapping_sha256,
      do: raise("VNI normalized mapping digest changed: #{actual_sha256}")

    runs = Enum.map(@profiles, &prepare(&1, csv))
    row_count = Enum.sum(Enum.map(runs, &length(&1.rows)))

    unless row_count == 1_041,
      do: raise("source-bound VNI row count changed: #{row_count}")

    IO.puts("source-bound mapping coverage: 1041/1041 rows across 4/4 profiles")
    Enum.each(runs, &benchmark_profile/1)
    IO.puts("all 12 native/reference 30x ceiling gates passed")
    reduction_scaling_gates()
  end

  defp prepare({profile, codec}, csv) do
    rows = parse_mapping(csv, profile)
    decode = Map.new(rows, &{&1.token, &1.codepoint})
    encode = canonical_inverse(rows)
    max_token_bytes = rows |> Enum.map(&byte_size(&1.token)) |> Enum.max()
    token_pattern = rows |> Enum.map(& &1.token) |> IO.iodata_to_binary()
    scalar_pattern = Enum.map(rows, & &1.codepoint)
    bytes = :binary.copy(token_pattern, @sample_repetitions)
    codepoints = List.duplicate(scalar_pattern, @sample_repetitions) |> List.flatten()

    {:ok, reference_decoded} = reference_decode(bytes, decode, max_token_bytes)
    {:ok, reference_encoded} = reference_encode(codepoints, encode)
    reference_utf8 = List.to_string(reference_decoded)

    unless codec.decode(bytes) == {:ok, reference_decoded} and
             codec.encode(codepoints) == {:ok, reference_encoded} and
             codec.decode_to_utf8(bytes) == {:ok, reference_utf8} do
      raise "#{codec.canonical_name()} differs from independent source-table reference"
    end

    %{
      codec: codec,
      rows: rows,
      decode: decode,
      encode: encode,
      max_token_bytes: max_token_bytes,
      bytes: bytes,
      codepoints: codepoints
    }
  end

  defp benchmark_profile(run) do
    name = run.codec.canonical_name()

    compare(
      name,
      "decode",
      byte_size(run.bytes),
      fn -> run.codec.decode(run.bytes) end,
      fn -> reference_decode(run.bytes, run.decode, run.max_token_bytes) end
    )

    compare(
      name,
      "encode",
      length(run.codepoints),
      fn -> run.codec.encode(run.codepoints) end,
      fn -> reference_encode(run.codepoints, run.encode) end
    )

    compare(
      name,
      "decode_to_utf8",
      byte_size(run.bytes),
      fn -> run.codec.decode_to_utf8(run.bytes) end,
      fn -> reference_decode_to_utf8(run.bytes, run.decode, run.max_token_bytes) end
    )
  end

  defp compare(name, operation, units, native, reference) do
    native_us = timed_median(native)
    reference_us = timed_median(reference)
    ratio = native_us / max(reference_us, 1)
    rate = units / max(native_us, 1)

    unless ratio <= @native_reference_ceiling,
      do: raise("#{name} #{operation} is #{decimal(ratio)}x its independent reference")

    IO.puts(
      "#{name} #{operation} native/reference #{decimal(ratio)}x; native #{decimal(rate)} million units/s"
    )
  end

  defp parse_mapping(csv, profile) do
    ["profile,token,unicode,origin" | rows] = String.split(csv, "\n", trim: true)
    profile_name = Atom.to_string(profile)

    Enum.flat_map(rows, fn row ->
      [row_profile, token, codepoint, _origin] = String.split(row, ",", parts: 4)

      if row_profile == profile_name do
        [
          %{
            token: Base.decode16!(token, case: :mixed),
            codepoint: String.to_integer(codepoint, 16)
          }
        ]
      else
        []
      end
    end)
  end

  defp canonical_inverse(rows), do: Map.new(rows, &{&1.codepoint, &1.token})

  defp reference_decode(input, decode, max_token_bytes),
    do: reference_decode(input, decode, max_token_bytes, 0, [])

  defp reference_decode(<<>>, _decode, _max_token_bytes, _offset, result),
    do: {:ok, :lists.reverse(result)}

  defp reference_decode(input, decode, max_token_bytes, offset, result) do
    sizes = min(byte_size(input), max_token_bytes)..1//-1

    case Enum.find_value(sizes, fn size ->
           token = binary_part(input, 0, size)
           if Map.has_key?(decode, token), do: {token, Map.fetch!(decode, token)}
         end) do
      nil ->
        <<invalid, _::binary>> = input
        {:error, :invalid_sequence, offset, <<invalid>>}

      {token, codepoint} ->
        size = byte_size(token)
        <<_::binary-size(size), rest::binary>> = input
        reference_decode(rest, decode, max_token_bytes, offset + size, [codepoint | result])
    end
  end

  defp reference_encode(codepoints, encode), do: reference_encode(codepoints, encode, [])

  defp reference_encode([], _encode, result),
    do: {:ok, result |> :lists.reverse() |> IO.iodata_to_binary()}

  defp reference_encode([codepoint | rest], encode, result) do
    case Map.fetch(encode, codepoint) do
      {:ok, token} -> reference_encode(rest, encode, [token | result])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp reference_decode_to_utf8(input, decode, max_token_bytes) do
    case reference_decode(input, decode, max_token_bytes) do
      {:ok, codepoints} -> {:ok, List.to_string(codepoints)}
      error -> error
    end
  end

  defp timed_median(function) do
    for _ <- 1..@warmups, do: function.()

    for _ <- 1..@iterations do
      :erlang.garbage_collect()
      {microseconds, _result} = :timer.tc(function)
      microseconds
    end
    |> Enum.sort()
    |> Enum.at(div(@iterations, 2))
  end

  defp reduction_scaling_gates do
    codec = Iconvex.Specs.VietUnicodeVNI.ANSI2002
    short_bytes = :binary.copy(" ", 20_000)
    long_bytes = :binary.copy(" ", 40_000)
    short_codepoints = List.duplicate(0x20, 20_000)
    long_codepoints = List.duplicate(0x20, 40_000)

    operations = [
      {"decode", fn -> codec.decode(short_bytes) end, fn -> codec.decode(long_bytes) end},
      {"encode", fn -> codec.encode(short_codepoints) end,
       fn -> codec.encode(long_codepoints) end},
      {"decode_to_utf8", fn -> codec.decode_to_utf8(short_bytes) end,
       fn -> codec.decode_to_utf8(long_bytes) end}
    ]

    Enum.each(operations, fn {operation, short, long} ->
      short_reductions = reduction_median(short)
      long_reductions = reduction_median(long)
      ratio = long_reductions / max(short_reductions, 1)

      IO.puts(
        "#{operation} reduction scaling 20k->40k: #{decimal(ratio)}x (#{short_reductions} -> #{long_reductions})"
      )

      unless ratio > @reduction_lower_bound and ratio < @reduction_upper_bound,
        do: raise("#{operation} failed linear reduction scaling: #{ratio}x")
    end)

    IO.puts("all 3 reduction-scaling gates passed")
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
        function.()
        {:reductions, after_count} = Process.info(self(), :reductions)
        send(parent, {token, after_count - before_count})
      end)

    receive do
      {^token, reductions} ->
        receive do
          {:DOWN, ^monitor, :process, _pid, :normal} -> reductions
        after
          5_000 -> raise "benchmark worker did not terminate"
        end

      {:DOWN, ^monitor, :process, _pid, reason} ->
        raise "benchmark worker failed: #{inspect(reason)}"
    after
      30_000 -> raise "benchmark worker timed out"
    end
  end

  defp decimal(number), do: :erlang.float_to_binary(number / 1, decimals: 2)
end

Iconvex.Specs.VietUnicodeVNIBenchmark.run()

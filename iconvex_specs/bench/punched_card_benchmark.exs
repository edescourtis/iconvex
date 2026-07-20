defmodule Iconvex.Specs.PunchedCardBenchmark do
  import Bitwise
  alias Iconvex.Packed.LSB

  @quick "--quick" in System.argv()
  @iterations if(@quick, do: 1, else: 7)
  @warmups if(@quick, do: 1, else: 2)
  @sample_repetitions if(@quick, do: 64, else: 1_024)
  @benchmark_alphabet_units 64
  @scaling_batch if(@quick, do: 10, else: 100)
  @reduction_samples 3
  @reduction_lower_bound 1.75
  @reduction_upper_bound 2.25
  @source_dir Path.expand("../priv/sources/punched-card-codes", __DIR__)
  @canonical_sha256 "541347c32f7610d3830b9259a68891b6ae2a410b1251f039f37930b83c3476c7"
  @decode_aliases_sha256 "da98e499e2b860bea2f35b7fbd66e14db1142047a7ac9ffe5b84174875b65323"
  @expected_canonical_counts %{
    "IBM-7040-H-REPORT" => 64,
    "IBM-7040-H-PROGRAM" => 64,
    "IBM-1401-CARD" => 63,
    "CDC-167-BCD-HOLLERITH-1965" => 63,
    "CDC-6000-STANDARD-HOLLERITH-1970" => 63,
    "BCD-CDC-IOWA" => 64
  }
  @expected_alias_counts %{"CDC-6000-STANDARD-HOLLERITH-1970" => 2}
  @expected_canonical_total 381
  @expected_alias_total 2
  @profiles [
    {"IBM H report", "IBM-7040-H-REPORT", Iconvex.Specs.IBM7040HReport,
     Iconvex.Specs.IBM7040HReport16BE, Iconvex.Specs.IBM7040HReport16LE},
    {"IBM H program", "IBM-7040-H-PROGRAM", Iconvex.Specs.IBM7040HProgram,
     Iconvex.Specs.IBM7040HProgram16BE, Iconvex.Specs.IBM7040HProgram16LE},
    {"IBM 1401", "IBM-1401-CARD", Iconvex.Specs.IBM1401Card, Iconvex.Specs.IBM1401Card16BE,
     Iconvex.Specs.IBM1401Card16LE},
    {"CDC 167/166 1965", "CDC-167-BCD-HOLLERITH-1965", Iconvex.Specs.CDC167BCDHollerith1965,
     Iconvex.Specs.CDC167BCDHollerith1965_16BE, Iconvex.Specs.CDC167BCDHollerith1965_16LE},
    {"CDC 6000 1970", "CDC-6000-STANDARD-HOLLERITH-1970",
     Iconvex.Specs.CDC6000StandardHollerith1970, Iconvex.Specs.CDC6000StandardHollerith1970_16BE,
     Iconvex.Specs.CDC6000StandardHollerith1970_16LE},
    {"BCD CDC Iowa reconstruction", "BCD-CDC-IOWA", Iconvex.Specs.BCDCDCIowa,
     Iconvex.Specs.BCDCDCIowa16BE, Iconvex.Specs.BCDCDCIowa16LE}
  ]

  def run do
    profile_runs = prepare_profile_runs()
    characters_per_operation = profile_runs |> hd() |> Map.fetch!(:sample) |> length()

    IO.puts("native punched-card tables; #{characters_per_operation} characters per operation")

    IO.puts(
      "source-bound reference evidence: 381/381 canonical rows across 6/6 profiles; 2/2 decode aliases loaded"
    )

    IO.puts("complete-coverage benchmark alphabets: 6/6 profiles x 64 units")

    for run <- profile_runs do
      %{name: name, logical: logical, transport_be: transport_be, transport_le: transport_le} =
        run

      sample = run.sample
      {:ok, packed_msb} = logical.encode_packed(sample)
      {:ok, packed_lsb} = logical.encode_packed_lsb(sample)
      {:ok, words_be} = transport_be.encode(sample)
      {:ok, words_le} = transport_le.encode(sample)

      assert_round_trip_parity!(
        run,
        %{msb: packed_msb, lsb: packed_lsb, be: words_be, le: words_le}
      )

      operations = [
        {"packed MSB encode", fn -> logical.encode_packed(sample) end},
        {"packed MSB decode", fn -> logical.decode_packed(packed_msb) end},
        {"packed LSB encode", fn -> logical.encode_packed_lsb(sample) end},
        {"packed LSB decode", fn -> logical.decode_packed_lsb(packed_lsb) end},
        {"16BE encode", fn -> transport_be.encode(sample) end},
        {"16BE decode", fn -> transport_be.decode(words_be) end},
        {"16LE encode", fn -> transport_le.encode(sample) end},
        {"16LE decode", fn -> transport_le.decode(words_le) end}
      ]

      Enum.each(operations, fn {operation, function} ->
        bench("#{name} #{operation}", length(sample), function)
      end)
    end

    IO.puts(
      "round-trip parity: #{length(@profiles)}/#{length(@profiles)} profiles x 4 transports"
    )

    wall_scaling()
    reduction_scaling_gates()
    comparative_ceiling_gates(profile_runs)
  end

  defp assert_round_trip_parity!(run, encoded) do
    %{name: name, logical: logical, transport_be: transport_be, transport_le: transport_le} = run
    %{msb: packed_msb, lsb: packed_lsb, be: words_be, le: words_le} = encoded

    decoded = [
      logical.decode_packed(packed_msb),
      logical.decode_packed_lsb(packed_lsb),
      transport_be.decode(words_be),
      transport_le.decode(words_le)
    ]

    unless Enum.all?(decoded, &(&1 == {:ok, run.sample})) do
      raise "#{name} failed packed/word round-trip parity"
    end

    unless words_le == swap_word_bytes(words_be) do
      raise "#{name} 16BE and 16LE words do not carry identical twelve-bit masks"
    end

    expected = %{
      msb: reference_msb_encode(run.sample, run.evidence.encode),
      lsb: reference_lsb_encode(run.sample, run.evidence.encode),
      be: reference_word_encode(run.sample, run.evidence.encode, :big),
      le: reference_word_encode(run.sample, run.evidence.encode, :little)
    }

    unless expected == %{
             msb: {:ok, packed_msb},
             lsb: {:ok, packed_lsb},
             be: {:ok, words_be},
             le: {:ok, words_le}
           } do
      raise "#{name} native output differs from pinned source evidence"
    end

    assert_decode_alias_parity!(run)
  end

  defp swap_word_bytes(input) do
    for <<high, low <- input>>, into: <<>>, do: <<low, high>>
  end

  defp prepare_profile_runs do
    runs =
      for {name, profile_id, logical, transport_be, transport_le} <- @profiles do
        evidence = reference_evidence(profile_id)
        validate_reference_evidence!(profile_id, evidence)
        alphabet = complete_coverage_alphabet(evidence.canonical_rows)

        %{
          name: name,
          profile_id: profile_id,
          logical: logical,
          transport_be: transport_be,
          transport_le: transport_le,
          evidence: evidence,
          alphabet: alphabet,
          sample: List.duplicate(alphabet, @sample_repetitions) |> List.flatten()
        }
      end

    canonical_total = Enum.sum(Enum.map(runs, &length(&1.evidence.canonical_rows)))
    alias_total = Enum.sum(Enum.map(runs, &length(&1.evidence.alias_rows)))

    unless canonical_total == @expected_canonical_total and alias_total == @expected_alias_total do
      raise "punched-card benchmark evidence totals changed: #{canonical_total} canonical, #{alias_total} aliases"
    end

    runs
  end

  defp complete_coverage_alphabet(canonical_rows) do
    codepoints = Enum.map(canonical_rows, &elem(&1, 0))
    padding_count = @benchmark_alphabet_units - length(codepoints)

    if codepoints == [] or padding_count < 0 do
      raise "canonical evidence cannot form a #{@benchmark_alphabet_units}-unit alphabet"
    end

    padding = codepoints |> Stream.cycle() |> Enum.take(padding_count)
    alphabet = codepoints ++ padding

    unless length(alphabet) == @benchmark_alphabet_units and
             MapSet.subset?(MapSet.new(codepoints), MapSet.new(alphabet)) do
      raise "complete-coverage benchmark alphabet lost canonical rows"
    end

    alphabet
  end

  defp assert_decode_alias_parity!(run) do
    for {codepoint, mask} <- run.evidence.alias_rows do
      expected = {:ok, [codepoint]}

      unless run.logical.decode_packed(<<mask::12>>) == expected and
               run.transport_be.decode(<<mask::16-big>>) == expected and
               run.transport_le.decode(<<mask::16-little>>) == expected do
        raise "#{run.name} decode alias 0x#{Integer.to_string(mask, 16)} differs from evidence"
      end
    end
  end

  defp wall_scaling do
    short = List.duplicate(?A, 20_000)
    long = List.duplicate(?A, 40_000)
    transport = Iconvex.Specs.IBM7040HReport16BE
    short_us = median(fn -> batch_encode(transport, short) end) / @scaling_batch
    long_us = median(fn -> batch_encode(transport, long) end) / @scaling_batch

    IO.puts(
      :io_lib.format("16BE encode wall scaling 20k->40k: ~.3fx (~.2f ms -> ~.2f ms)", [
        long_us / short_us,
        short_us / 1_000,
        long_us / 1_000
      ])
    )
  end

  defp reduction_scaling_gates do
    logical = Iconvex.Specs.IBM7040HReport
    transport_be = Iconvex.Specs.IBM7040HReport16BE
    transport_le = Iconvex.Specs.IBM7040HReport16LE
    short = List.duplicate(?A, 20_000)
    long = List.duplicate(?A, 40_000)
    {:ok, short_msb} = logical.encode_packed(short)
    {:ok, long_msb} = logical.encode_packed(long)
    {:ok, short_lsb} = logical.encode_packed_lsb(short)
    {:ok, long_lsb} = logical.encode_packed_lsb(long)
    {:ok, short_be} = transport_be.encode(short)
    {:ok, long_be} = transport_be.encode(long)
    {:ok, short_le} = transport_le.encode(short)
    {:ok, long_le} = transport_le.encode(long)

    operations = [
      {"packed MSB encode", fn -> logical.encode_packed(short) end,
       fn -> logical.encode_packed(long) end},
      {"packed MSB decode", fn -> logical.decode_packed(short_msb) end,
       fn -> logical.decode_packed(long_msb) end},
      {"packed LSB encode", fn -> logical.encode_packed_lsb(short) end,
       fn -> logical.encode_packed_lsb(long) end},
      {"packed LSB decode", fn -> logical.decode_packed_lsb(short_lsb) end,
       fn -> logical.decode_packed_lsb(long_lsb) end},
      {"16BE encode", fn -> transport_be.encode(short) end, fn -> transport_be.encode(long) end},
      {"16BE decode", fn -> transport_be.decode(short_be) end,
       fn -> transport_be.decode(long_be) end},
      {"16LE encode", fn -> transport_le.encode(short) end, fn -> transport_le.encode(long) end},
      {"16LE decode", fn -> transport_le.decode(short_le) end,
       fn -> transport_le.decode(long_le) end}
    ]

    Enum.each(operations, fn {operation, short_function, long_function} ->
      short_reductions = reduction_median(short_function)
      long_reductions = reduction_median(long_function)
      ratio = long_reductions / short_reductions

      IO.puts(
        :io_lib.format("~s reduction scaling 20k->40k: ~.3fx (~B -> ~B)", [
          operation,
          ratio,
          short_reductions,
          long_reductions
        ])
      )

      unless ratio > @reduction_lower_bound and ratio < @reduction_upper_bound do
        raise "#{operation} failed the linear reduction-scaling gate: #{ratio}x"
      end
    end)

    IO.puts("all #{length(operations)} reduction-scaling gates passed")
  end

  defp batch_encode(codec, codepoints) do
    Enum.reduce(1..@scaling_batch, {:ok, <<>>}, fn _, _ -> codec.encode(codepoints) end)
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

  defp comparative_ceiling_gates(profile_runs) do
    gate_count =
      Enum.reduce(profile_runs, 0, fn run, count ->
        %{
          name: name,
          logical: logical,
          transport_be: transport_be,
          transport_le: transport_le,
          sample: sample,
          evidence: evidence
        } = run

        {:ok, packed_msb} = reference_msb_encode(sample, evidence.encode)
        {:ok, %LSB{} = packed_lsb} = reference_lsb_encode(sample, evidence.encode)
        {:ok, words_be} = reference_word_encode(sample, evidence.encode, :big)
        {:ok, words_le} = reference_word_encode(sample, evidence.encode, :little)

        operations = [
          {"packed MSB encode", fn -> logical.encode_packed(sample) end,
           fn -> reference_msb_encode(sample, evidence.encode) end},
          {"packed MSB decode", fn -> logical.decode_packed(packed_msb) end,
           fn -> reference_msb_decode(packed_msb, evidence.decode) end},
          {"packed LSB encode", fn -> logical.encode_packed_lsb(sample) end,
           fn -> reference_lsb_encode(sample, evidence.encode) end},
          {"packed LSB decode", fn -> logical.decode_packed_lsb(packed_lsb) end,
           fn -> reference_lsb_decode(packed_lsb, evidence.decode) end},
          {"16BE encode", fn -> transport_be.encode(sample) end,
           fn -> reference_word_encode(sample, evidence.encode, :big) end},
          {"16BE decode", fn -> transport_be.decode(words_be) end,
           fn -> reference_word_decode(words_be, evidence.decode, :big) end},
          {"16LE encode", fn -> transport_le.encode(sample) end,
           fn -> reference_word_encode(sample, evidence.encode, :little) end},
          {"16LE decode", fn -> transport_le.decode(words_le) end,
           fn -> reference_word_decode(words_le, evidence.decode, :little) end}
        ]

        Enum.each(operations, fn {operation, native, reference} ->
          native_result = native.()
          reference_result = reference.()

          unless native_result == reference_result do
            raise "#{name} #{operation} differs from its independent reference"
          end

          native_us = median(native)
          reference_us = max(median(reference), 1)
          ratio = native_us / reference_us

          IO.puts(
            :io_lib.format(
              "~s ~s native / independent reference: ~.2fx (~B us / ~B us)",
              [name, operation, ratio, native_us, reference_us]
            )
          )

          if ratio > 30.0 do
            raise "#{name} #{operation} exceeds the 30x independent-reference ceiling"
          end
        end)

        count + length(operations)
      end)

    IO.puts("all #{gate_count} native/reference 30x ceiling gates passed")
  end

  defp reference_evidence(profile_id) do
    canonical_rows = evidence_rows("canonical_maps.csv", @canonical_sha256, profile_id)
    alias_rows = evidence_rows("decode_aliases.csv", @decode_aliases_sha256, profile_id)
    encode = Map.new(canonical_rows)

    decode_map =
      Enum.reduce(canonical_rows ++ alias_rows, %{}, fn {codepoint, mask}, acc ->
        case Map.fetch(acc, mask) do
          :error -> Map.put(acc, mask, codepoint)
          {:ok, ^codepoint} -> acc
          {:ok, other} -> raise "conflicting evidence for mask #{mask}: #{other} and #{codepoint}"
        end
      end)

    decode = 0..0xFFF |> Enum.map(&Map.get(decode_map, &1)) |> List.to_tuple()

    %{canonical_rows: canonical_rows, alias_rows: alias_rows, encode: encode, decode: decode}
  end

  defp evidence_rows(filename, expected_sha256, profile_id) do
    bytes = File.read!(Path.join(@source_dir, filename))
    actual_sha256 = :sha256 |> :crypto.hash(bytes) |> Base.encode16(case: :lower)

    unless actual_sha256 == expected_sha256 do
      raise "punched-card benchmark evidence digest changed: #{filename}"
    end

    bytes
    |> String.split("\n", trim: true)
    |> tl()
    |> Enum.flat_map(fn line ->
      [profile, codepoint, _name, _punches, mask, _canonical, _decode, _source] =
        line
        |> String.trim_leading("\"")
        |> String.trim_trailing("\"")
        |> String.split("\",\"")

      if profile == profile_id do
        [{parse_hex(codepoint, "U+"), parse_hex(mask, "0x")}]
      else
        []
      end
    end)
  end

  defp validate_reference_evidence!(profile_id, evidence) do
    expected_canonical = Map.fetch!(@expected_canonical_counts, profile_id)
    expected_aliases = Map.get(@expected_alias_counts, profile_id, 0)

    unless length(evidence.canonical_rows) == expected_canonical and
             length(evidence.alias_rows) == expected_aliases and
             map_size(evidence.encode) == expected_canonical do
      raise "punched-card evidence count changed for #{profile_id}"
    end

    canonical_masks = evidence.canonical_rows |> Enum.map(&elem(&1, 1)) |> MapSet.new()

    unless MapSet.size(canonical_masks) == expected_canonical do
      raise "punched-card canonical masks are no longer one-to-one for #{profile_id}"
    end
  end

  defp parse_hex(value, prefix),
    do: value |> String.trim_leading(prefix) |> String.to_integer(16)

  defp reference_msb_encode(sample, encode) do
    packed =
      sample
      |> Enum.map(fn codepoint -> <<Map.fetch!(encode, codepoint)::12>> end)
      |> :erlang.list_to_bitstring()

    {:ok, packed}
  end

  defp reference_msb_decode(packed, decode) do
    {:ok, for(<<mask::12 <- packed>>, do: elem(decode, mask))}
  end

  defp reference_lsb_encode(sample, encode) do
    masks = Enum.map(sample, &Map.fetch!(encode, &1))

    data =
      masks
      |> Enum.chunk_every(2)
      |> Enum.map(fn
        [first, second] -> <<first + second * 0x1000::24-little>>
        [last] -> <<last::16-little>>
      end)
      |> IO.iodata_to_binary()

    {:ok, %LSB{data: data, bit_size: length(masks) * 12, unit_bits: 12}}
  end

  defp reference_lsb_decode(%LSB{data: data, bit_size: bit_size}, decode) do
    reference_lsb_units(data, div(bit_size, 12), decode, [])
  end

  defp reference_lsb_units(_data, 0, _decode, acc), do: {:ok, :lists.reverse(acc)}

  defp reference_lsb_units(<<value::24-little, rest::binary>>, units, decode, acc)
       when units >= 2 do
    first = value &&& 0xFFF
    second = value >>> 12 &&& 0xFFF

    reference_lsb_units(rest, units - 2, decode, [elem(decode, second), elem(decode, first) | acc])
  end

  defp reference_lsb_units(<<value::16-little, _tail::binary>>, 1, decode, acc) do
    {:ok, :lists.reverse([elem(decode, value &&& 0xFFF) | acc])}
  end

  defp reference_word_encode(sample, encode, endian) do
    words =
      sample
      |> Enum.map(fn codepoint -> reference_word(Map.fetch!(encode, codepoint), endian) end)
      |> IO.iodata_to_binary()

    {:ok, words}
  end

  defp reference_word_decode(words, decode, :big),
    do: {:ok, for(<<mask::16-big <- words>>, do: elem(decode, mask))}

  defp reference_word_decode(words, decode, :little),
    do: {:ok, for(<<mask::16-little <- words>>, do: elem(decode, mask))}

  defp reference_word(mask, :big), do: <<mask::16-big>>
  defp reference_word(mask, :little), do: <<mask::16-little>>

  defp bench(name, count, function) do
    microseconds = median(function)

    IO.puts(
      :io_lib.format("~-58s ~12B chars/s  ~8.2f ms", [
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

  defp assert_ok({:ok, _result}), do: :ok
  defp assert_ok(error), do: raise("punched-card benchmark failed: #{inspect(error)}")
end

Iconvex.Specs.PunchedCardBenchmark.run()

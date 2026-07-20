defmodule Iconvex.Specs.UnihanTelegraphPropertyTokenBenchmark do
  import Bitwise

  @quick "--quick" in System.argv()
  @logical_tokens if(@quick, do: 65_536, else: 262_144)
  @samples if(@quick, do: 3, else: 7)
  @warmups if(@quick, do: 1, else: 2)
  @reduction_samples 3
  @reduction_lower_bound 1.65
  @reduction_upper_bound 2.35

  @source_dir Path.expand("../priv/sources/unihan-17.0.0-telegraph", __DIR__)

  @profiles [
    {Iconvex.Specs.Unihan17MainlandTelegraphDecimalToken,
     "UNIHAN-17.0.0-KMAINLANDTELEGRAPH-DECIMAL-TOKEN"},
    {Iconvex.Specs.Unihan17TaiwanTelegraphDecimalTokenReadable,
     "UNIHAN-17.0.0-KTAIWANTELEGRAPH-DECIMAL-TOKEN-READABLE"},
    {Iconvex.Specs.Unihan17TaiwanTelegraphDecimalTokenLosslessVPUA1,
     "UNIHAN-17.0.0-KTAIWANTELEGRAPH-DECIMAL-TOKEN-LOSSLESS-VPUA-1"}
  ]

  @profile_names Enum.map(@profiles, &elem(&1, 1))
  @operations [
    "assigned decode",
    "unassigned decode",
    "reverse encode",
    "token_to_utf8",
    "utf8_to_token"
  ]

  # Production minima are the slowest profile medians across two independent
  # 262,144-token runs on OTP 28 / Elixir 1.19.5 / arm64. Floors round up to
  # 0.01 logical MiB/s, so no accepted slowdown can exceed 30x.
  @recorded_minimums %{
    "assigned decode" => 130.41,
    "unassigned decode" => 149.21,
    "reverse encode" => 54.45,
    "token_to_utf8" => 78.67,
    "utf8_to_token" => 42.68
  }
  @throughput_floors %{
    "assigned decode" => 4.35,
    "unassigned decode" => 4.98,
    "reverse encode" => 1.82,
    "token_to_utf8" => 2.63,
    "utf8_to_token" => 1.43
  }

  def run do
    profiles = load_profiles()

    Enum.each(profiles, &verify_profile!/1)
    verify_throughput_floors!()

    IO.puts("profile\toperation\ttokens/s\tlogical 4-byte MiB/s\tmedian us")

    gates =
      for profile <- profiles,
          operation <- @operations do
        benchmark_and_gate(profile, operation)
      end

    IO.puts("round-trip parity: 3/3 source-qualified property-token profiles")

    IO.puts(
      "all #{length(gates)} fresh-process reduction-scaling gates passed " <>
        "(#{@reduction_lower_bound}x..#{@reduction_upper_bound}x)"
    )

    IO.puts(
      "all #{length(gates)} conservative throughput floors passed " <>
        "(ceil(recorded production minimum / 30) to 0.01; " <>
        "logical four-byte token accounting)"
    )

    IO.puts(
      "Unicode property scope remains one token per call; no concatenated stream is benchmarked"
    )

    report_gnu_status()
  end

  def report_gnu_status do
    configured = System.get_env("GNU_ICONV", "/opt/homebrew/opt/libiconv/bin/iconv")

    case System.find_executable(configured) do
      nil ->
        IO.puts(
          "GNU comparison unavailable: set GNU_ICONV to a GNU libiconv executable; " <>
            "no equivalent converter performance comparison is defined"
        )

      executable ->
        case System.cmd(executable, ["-l"], stderr_to_stdout: true) do
          {listing, 0} -> report_gnu_listing(executable, listing)
          {_output, status} -> report_gnu_list_failure(status)
        end
    end
  end

  defp benchmark_and_gate(profile, operation) do
    small_count = div(@logical_tokens, 2)
    large_count = @logical_tokens
    small_fun = fn -> run_operation(profile, operation, small_count) end
    large_fun = fn -> run_operation(profile, operation, large_count) end

    microseconds = median_us(large_fun)
    seconds = max(microseconds, 1) / 1_000_000
    tokens_per_second = large_count / seconds
    logical_mib_per_second = tokens_per_second * 4 / 1_048_576

    IO.puts(
      Enum.join(
        [
          profile.name,
          operation,
          round(tokens_per_second),
          Float.round(logical_mib_per_second, 2),
          microseconds
        ],
        "\t"
      )
    )

    floor = Map.fetch!(@throughput_floors, operation)

    IO.puts(
      "#{profile.name} #{operation} throughput floor: " <>
        "#{Float.round(logical_mib_per_second, 2)} >= #{floor} logical 4-byte MiB/s"
    )

    if logical_mib_per_second < floor do
      raise "#{profile.name} #{operation} throughput #{logical_mib_per_second} is below #{floor}"
    end

    small_reductions = median_reductions(small_fun)
    large_reductions = median_reductions(large_fun)
    ratio = large_reductions / max(small_reductions, 1)

    IO.puts(
      "#{profile.name} #{operation} reduction scaling: " <>
        "#{Float.round(ratio, 3)}x (#{small_reductions} -> #{large_reductions})"
    )

    unless ratio >= @reduction_lower_bound and ratio <= @reduction_upper_bound do
      raise "#{profile.name} #{operation} failed linear reduction scaling: #{ratio}x"
    end

    {profile.name, operation, logical_mib_per_second, ratio}
  end

  defp median_us(function) do
    Enum.each(1..@warmups, fn _ -> isolated_measure(function, :microseconds) end)

    for(_ <- 1..@samples, do: isolated_measure(function, :microseconds))
    |> median()
  end

  defp median_reductions(function) do
    for(_ <- 1..@reduction_samples, do: isolated_measure(function, :reductions))
    |> median()
  end

  defp isolated_measure(function, measurement) do
    parent = self()
    token = make_ref()

    {_pid, monitor} =
      spawn_monitor(fn ->
        :erlang.garbage_collect()

        value =
          case measurement do
            :microseconds ->
              {microseconds, result} = :timer.tc(function)
              require_checksum!(result)
              microseconds

            :reductions ->
              {:reductions, before_count} = Process.info(self(), :reductions)
              result = function.()
              {:reductions, after_count} = Process.info(self(), :reductions)
              require_checksum!(result)
              after_count - before_count
          end

        send(parent, {token, value})
      end)

    receive do
      {^token, value} ->
        receive do
          {:DOWN, ^monitor, :process, _pid, :normal} ->
            value

          {:DOWN, ^monitor, :process, _pid, reason} ->
            raise "benchmark worker failed: #{inspect(reason)}"
        after
          30_000 -> raise "benchmark worker did not terminate"
        end

      {:DOWN, ^monitor, :process, _pid, reason} ->
        raise "benchmark worker failed before reporting: #{inspect(reason)}"
    after
      30_000 -> raise "benchmark worker timed out"
    end
  end

  defp median(values) do
    values = Enum.sort(values)
    Enum.at(values, div(length(values), 2))
  end

  defp require_checksum!(value) when is_integer(value), do: :ok
  defp require_checksum!(value), do: raise("invalid benchmark checksum: #{inspect(value)}")

  defp verify_throughput_floors! do
    for operation <- @operations do
      recorded = Map.fetch!(@recorded_minimums, operation)
      floor = Map.fetch!(@throughput_floors, operation)
      expected = Float.ceil(recorded / 30, 2)

      unless floor == expected and recorded / floor <= 30 do
        raise "#{operation} floor #{floor} is not the conservative derivative of #{recorded}"
      end
    end
  end

  defp run_operation(profile, "assigned decode", count),
    do: assigned_decode_loop(profile.module, profile.decode_samples, count, 0, 0)

  defp run_operation(profile, "unassigned decode", count),
    do: unassigned_decode_loop(profile.module, profile.unassigned_token, count, 0)

  defp run_operation(profile, "reverse encode", count),
    do: reverse_encode_loop(profile.module, profile.encode_samples, count, 0, 0)

  defp run_operation(profile, "token_to_utf8", count),
    do: token_to_utf8_loop(profile.module, profile.decode_utf8_samples, count, 0, 0)

  defp run_operation(profile, "utf8_to_token", count),
    do: utf8_to_token_loop(profile.module, profile.utf8_samples, count, 0, 0)

  defp assigned_decode_loop(_module, _samples, 0, _index, checksum), do: checksum

  defp assigned_decode_loop(module, samples, remaining, index, checksum) do
    {token, expected} = sample(samples, index)

    case module.decode_token(token) do
      {:ok, ^expected} ->
        assigned_decode_loop(module, samples, remaining - 1, index + 1, bxor(checksum, expected))

      result ->
        raise "assigned decode mismatch for #{inspect(token)}: #{inspect(result)}"
    end
  end

  defp unassigned_decode_loop(_module, _token, 0, checksum), do: checksum

  defp unassigned_decode_loop(module, token, remaining, checksum) do
    case module.decode_token(token) do
      {:error, {:unassigned_token, ^token}} ->
        unassigned_decode_loop(module, token, remaining - 1, checksum + 1)

      result ->
        raise "unassigned decode mismatch for #{inspect(token)}: #{inspect(result)}"
    end
  end

  defp reverse_encode_loop(_module, _samples, 0, _index, checksum), do: checksum

  defp reverse_encode_loop(module, samples, remaining, index, checksum) do
    {scalar, expected} = sample(samples, index)

    case module.encode_scalar(scalar) do
      {:ok, ^expected} ->
        reverse_encode_loop(
          module,
          samples,
          remaining - 1,
          index + 1,
          checksum + :binary.at(expected, 3)
        )

      result ->
        raise "reverse encode mismatch for U+#{Integer.to_string(scalar, 16)}: #{inspect(result)}"
    end
  end

  defp token_to_utf8_loop(_module, _samples, 0, _index, checksum), do: checksum

  defp token_to_utf8_loop(module, samples, remaining, index, checksum) do
    {token, expected} = sample(samples, index)

    case module.decode_token_to_utf8(token) do
      {:ok, ^expected} ->
        token_to_utf8_loop(
          module,
          samples,
          remaining - 1,
          index + 1,
          checksum + byte_size(expected)
        )

      result ->
        raise "token-to-UTF-8 mismatch for #{inspect(token)}: #{inspect(result)}"
    end
  end

  defp utf8_to_token_loop(_module, _samples, 0, _index, checksum), do: checksum

  defp utf8_to_token_loop(module, samples, remaining, index, checksum) do
    {utf8, expected} = sample(samples, index)

    case module.encode_utf8_to_token(utf8) do
      {:ok, ^expected} ->
        utf8_to_token_loop(
          module,
          samples,
          remaining - 1,
          index + 1,
          checksum + :binary.at(expected, 0)
        )

      result ->
        raise "UTF-8-to-token mismatch for #{inspect(utf8)}: #{inspect(result)}"
    end
  end

  defp sample(samples, index), do: elem(samples, rem(index, tuple_size(samples)))

  defp verify_profile!(profile) do
    unless profile.module.mapping_name() == profile.name do
      raise "property-token mapping-name drift for #{inspect(profile.module)}"
    end

    {token, scalar} = elem(profile.decode_samples, 0)

    unless profile.module.decode_token(token) == {:ok, scalar} and
             profile.module.decode_token_to_utf8(token) == {:ok, <<scalar::utf8>>} do
      raise "property-token decode preflight failed for #{profile.name}"
    end

    {reverse_scalar, reverse_token} = elem(profile.encode_samples, 0)

    unless profile.module.encode_scalar(reverse_scalar) == {:ok, reverse_token} and
             profile.module.encode_utf8_to_token(<<reverse_scalar::utf8>>) ==
               {:ok, reverse_token} do
      raise "property-token encode preflight failed for #{profile.name}"
    end

    unless profile.module.decode_token(profile.unassigned_token) ==
             {:error, {:unassigned_token, profile.unassigned_token}} do
      raise "property-token hole preflight failed for #{profile.name}"
    end
  end

  defp load_profiles do
    mainland = read_token_rows(Path.join(@source_dir, "mainland_tokens.csv"))
    taiwan = read_token_rows(Path.join(@source_dir, "taiwan_tokens.csv"))
    policy = read_policy_rows(Path.join(@source_dir, "taiwan_policy.csv"))

    mainland_pairs = Enum.map(mainland, fn {token, scalar} -> {token, scalar} end)

    readable_encode =
      for %{token: token, source: scalar, role: "canonical-minimum"} <- policy,
          do: {scalar, token}

    lossless_pairs = Enum.map(policy, fn row -> {row.token, row.output} end)
    lossless_encode = Enum.map(lossless_pairs, fn {token, scalar} -> {scalar, token} end)

    [
      profile_data(
        elem(Enum.at(@profiles, 0), 0),
        elem(Enum.at(@profiles, 0), 1),
        mainland_pairs,
        Enum.map(mainland_pairs, fn {token, scalar} -> {scalar, token} end)
      ),
      profile_data(
        elem(Enum.at(@profiles, 1), 0),
        elem(Enum.at(@profiles, 1), 1),
        taiwan,
        readable_encode
      ),
      profile_data(
        elem(Enum.at(@profiles, 2), 0),
        elem(Enum.at(@profiles, 2), 1),
        lossless_pairs,
        lossless_encode
      )
    ]
  end

  defp profile_data(module, name, decode_pairs, encode_pairs) do
    assigned = MapSet.new(decode_pairs, &elem(&1, 0))

    unassigned_token =
      Enum.find_value(0..9_999, fn value ->
        token = decimal_token(value)
        if not MapSet.member?(assigned, token), do: token
      end)

    %{
      module: module,
      name: name,
      decode_samples: List.to_tuple(decode_pairs),
      decode_utf8_samples:
        decode_pairs
        |> Enum.map(fn {token, scalar} -> {token, <<scalar::utf8>>} end)
        |> List.to_tuple(),
      encode_samples: List.to_tuple(encode_pairs),
      utf8_samples:
        encode_pairs
        |> Enum.map(fn {scalar, token} -> {<<scalar::utf8>>, token} end)
        |> List.to_tuple(),
      unassigned_token: unassigned_token
    }
  end

  defp read_token_rows(path) do
    ["decimal_token,unicode_scalar" | rows] =
      path |> File.read!() |> String.split("\n", trim: true)

    Enum.map(rows, fn row ->
      [token, scalar] = String.split(row, ",")
      {token, parse_scalar(scalar)}
    end)
  end

  defp read_policy_rows(path) do
    [
      "decimal_token,source_unicode_scalar,readable_reverse_role," <>
        "lossless_output_scalar,lossless_reason"
      | rows
    ] = path |> File.read!() |> String.split("\n", trim: true)

    Enum.map(rows, fn row ->
      [token, source, role, output, _reason] = String.split(row, ",")
      %{token: token, source: parse_scalar(source), role: role, output: parse_scalar(output)}
    end)
  end

  defp parse_scalar("U+" <> scalar), do: String.to_integer(scalar, 16)

  defp decimal_token(value) do
    <<div(value, 1_000) + ?0, div(rem(value, 1_000), 100) + ?0, div(rem(value, 100), 10) + ?0,
      rem(value, 10) + ?0>>
  end

  defp report_gnu_listing(executable, listing) do
    listed_by_normalized =
      listing
      |> String.split()
      |> Map.new(fn alias_name -> {normalize_alias(alias_name), alias_name} end)

    matches =
      @profile_names
      |> Enum.map(&normalize_alias/1)
      |> Enum.uniq()
      |> Enum.flat_map(fn normalized ->
        case listed_by_normalized do
          %{^normalized => listed} -> [listed]
          _ -> []
        end
      end)
      |> Enum.uniq()
      |> Enum.sort()

    version = gnu_version(executable)

    case matches do
      [] ->
        IO.puts(
          "GNU comparison unavailable: queried iconv -l (#{version}); " <>
            "no exact normalized Unihan property-token alias was listed; " <>
            "no equivalent converter performance comparison is defined"
        )

      aliases ->
        IO.puts(
          "GNU support listing includes exact normalized Unihan property-token aliases " <>
            "after querying iconv -l (#{version}): #{Enum.join(aliases, ", ")}"
        )
    end
  end

  defp report_gnu_list_failure(status) do
    IO.puts("GNU comparison unavailable: iconv -l exited with status #{status}")
  end

  defp gnu_version(executable) do
    case System.cmd(executable, ["--version"], stderr_to_stdout: true) do
      {output, 0} -> output |> String.split("\n") |> List.first()
      {_output, _status} -> Path.basename(executable)
    end
  end

  defp normalize_alias(alias_name) do
    alias_name
    |> String.upcase(:ascii)
    |> String.replace(~r/[^A-Z0-9]/, "")
  end
end

if "--gnu-probe-only" in System.argv() do
  Iconvex.Specs.UnihanTelegraphPropertyTokenBenchmark.report_gnu_status()
else
  Iconvex.Specs.UnihanTelegraphPropertyTokenBenchmark.run()
end

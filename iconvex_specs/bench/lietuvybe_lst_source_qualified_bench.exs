defmodule Iconvex.Specs.LietuvybeLSTSourceQualifiedBench do
  @moduledoc false

  @source_dir Path.expand("../priv/sources/lietuvybe-lst-source-qualified", __DIR__)
  @native_reference_ceiling 30.0
  @expected_mapping_rows 729

  @profiles [
    %{
      codec: Iconvex.Specs.Lietuvybe.LST1564Commit52A97895,
      canonical: "LIETUVYBE-52A97895-LST-1564-2000-STRICT-BLANKS",
      file: "lst1564.csv",
      sha256: "fdc7ccd7e311b4530d58606ea47deb30186c143f84fbecb01062d45bd5326d04"
    },
    %{
      codec: Iconvex.Specs.Lietuvybe.LST1590Part2Commit52A97895,
      canonical: "LIETUVYBE-52A97895-LST-1590-2-2000-STRICT-BLANKS",
      file: "lst1590_2.csv",
      sha256: "defee7782bcba01ea7b3f6d85a0103813f6e72d2aaab728892b6bfbfa3fd4240"
    },
    %{
      codec: Iconvex.Specs.Lietuvybe.LST1590Part4Commit52A97895,
      canonical: "LIETUVYBE-52A97895-LST-1590-4-2000-STRICT-BLANKS",
      file: "lst1590_4.csv",
      sha256: "8d7325c6785dd6a18af90e576c827ed8386f1f6b14e1aed97618e650c3214b13"
    }
  ]

  def run do
    quick? = "--quick" in System.argv()
    repetitions = if quick?, do: 256, else: 2_048
    samples = if quick?, do: 3, else: 9

    results =
      Enum.map(@profiles, fn profile ->
        source = File.read!(Path.join(@source_dir, profile.file))
        actual_sha256 = :crypto.hash(:sha256, source) |> Base.encode16(case: :lower)

        if actual_sha256 != profile.sha256 do
          raise "source SHA-256 mismatch for #{profile.canonical}"
        end

        table = parse_mapping(source)
        mapped_rows = table |> Tuple.to_list() |> Enum.count(&(&1 != nil))
        valid_bytes = for byte <- 0..255, elem(table, byte) != nil, do: byte
        payload = :binary.copy(:erlang.list_to_binary(valid_bytes), repetitions)
        {:ok, reference_codepoints} = reference_decode(payload, table)
        reference_utf8 = List.to_string(reference_codepoints)
        encoder = reference_encoder(table)

        assert_equal!(
          apply(profile.codec, :decode, [payload]),
          {:ok, reference_codepoints},
          profile.canonical,
          :decode
        )

        assert_equal!(
          apply(profile.codec, :encode, [reference_codepoints]),
          {:ok, payload},
          profile.canonical,
          :encode
        )

        assert_equal!(
          apply(profile.codec, :decode_to_utf8, [payload]),
          {:ok, reference_utf8},
          profile.canonical,
          :decode_to_utf8
        )

        assert_equal!(
          apply(profile.codec, :encode_from_utf8, [reference_utf8]),
          {:ok, payload},
          profile.canonical,
          :encode_from_utf8
        )

        gates = [
          measure_gate(
            profile.canonical,
            :decode,
            fn -> apply(profile.codec, :decode, [payload]) end,
            fn -> reference_decode(payload, table) end,
            samples
          ),
          measure_gate(
            profile.canonical,
            :encode,
            fn -> apply(profile.codec, :encode, [reference_codepoints]) end,
            fn -> reference_encode(reference_codepoints, encoder) end,
            samples
          ),
          measure_gate(
            profile.canonical,
            :decode_to_utf8,
            fn -> apply(profile.codec, :decode_to_utf8, [payload]) end,
            fn -> reference_decode_to_utf8(payload, table) end,
            samples
          ),
          measure_gate(
            profile.canonical,
            :encode_from_utf8,
            fn -> apply(profile.codec, :encode_from_utf8, [reference_utf8]) end,
            fn -> reference_encode_from_utf8(reference_utf8, encoder) end,
            samples
          )
        ]

        %{mapped_rows: mapped_rows, gates: gates}
      end)

    covered = Enum.sum(Enum.map(results, & &1.mapped_rows))
    gates = Enum.flat_map(results, & &1.gates)

    if covered != @expected_mapping_rows do
      raise "mapping coverage mismatch: expected #{@expected_mapping_rows}, got #{covered}"
    end

    failures = Enum.reject(gates, & &1.passed?)

    if failures != [] do
      raise "native/reference ceiling failures: #{inspect(failures)}"
    end

    IO.puts(
      "source-bound mapping coverage: #{covered}/#{@expected_mapping_rows} rows across #{length(results)}/#{length(@profiles)} profiles"
    )

    IO.puts("round-trip and direct UTF-8 parity: 3/3 profiles")
    IO.puts("all #{length(gates)} native/reference 30x ceiling gates passed")
  end

  defp measure_gate(canonical, operation, native, reference, samples) do
    native.()
    reference.()
    native_us = timed_median(native, samples)
    reference_us = timed_median(reference, samples)
    ratio = native_us / max(reference_us, 1)

    IO.puts(
      "#{canonical} #{operation} native/reference #{Float.round(ratio, 2)}x " <>
        "(#{native_us}us/#{reference_us}us)"
    )

    %{
      canonical: canonical,
      operation: operation,
      ratio: ratio,
      passed?: ratio <= @native_reference_ceiling
    }
  end

  defp parse_mapping(source) do
    ["byte_hex,unicode_sequence,status" | rows] = String.split(source, "\n", trim: true)

    rows
    |> Enum.with_index()
    |> Enum.map(fn {row, expected_byte} ->
      [byte, sequence, status] = String.split(row, ",", parts: 3)

      if String.to_integer(byte, 16) != expected_byte do
        raise "mapping order mismatch at #{byte}"
      end

      case {sequence, status} do
        {"", status} when status in ["undefined", "reserved_control"] ->
          nil

        {sequence, "assigned"} ->
          sequence |> String.split("+") |> Enum.map(&String.to_integer(&1, 16))
      end
    end)
    |> List.to_tuple()
  end

  defp reference_encoder(table) do
    table
    |> Tuple.to_list()
    |> Enum.with_index()
    |> Enum.reduce(%{single: %{}, sequence2: %{}, sequence3: %{}}, fn
      {nil, _byte}, encoder ->
        encoder

      {[codepoint], byte}, encoder ->
        put_in(encoder, [:single, codepoint], byte)

      {[first, second], byte}, encoder ->
        put_in(encoder, [:sequence2, {first, second}], byte)

      {[first, second, third], byte}, encoder ->
        put_in(encoder, [:sequence3, {first, second, third}], byte)
    end)
  end

  defp reference_decode(input, table), do: reference_decode_loop(input, table, 0, [])

  defp reference_decode_loop(<<>>, _table, _offset, result),
    do: {:ok, :lists.reverse(result)}

  defp reference_decode_loop(<<byte, rest::binary>>, table, offset, result) do
    case elem(table, byte) do
      nil -> {:error, :invalid_sequence, offset, <<byte>>}
      sequence -> reference_decode_loop(rest, table, offset + 1, :lists.reverse(sequence, result))
    end
  end

  defp reference_encode(codepoints, encoder),
    do: reference_encode_loop(codepoints, encoder, [])

  defp reference_encode_loop([], _encoder, result),
    do: {:ok, result |> :lists.reverse() |> :erlang.list_to_binary()}

  defp reference_encode_loop([first, second, third | rest], encoder, result) do
    case encoder.sequence3 do
      %{{^first, ^second, ^third} => byte} ->
        reference_encode_loop(rest, encoder, [byte | result])

      _ ->
        reference_encode_two([first, second, third | rest], encoder, result)
    end
  end

  defp reference_encode_loop(codepoints, encoder, result),
    do: reference_encode_two(codepoints, encoder, result)

  defp reference_encode_two([first, second | rest], encoder, result) do
    case encoder.sequence2 do
      %{{^first, ^second} => byte} ->
        reference_encode_loop(rest, encoder, [byte | result])

      _ ->
        reference_encode_single(first, [second | rest], encoder, result)
    end
  end

  defp reference_encode_two([first], encoder, result),
    do: reference_encode_single(first, [], encoder, result)

  defp reference_encode_single(codepoint, rest, encoder, result) do
    case encoder.single do
      %{^codepoint => byte} -> reference_encode_loop(rest, encoder, [byte | result])
      _ -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp reference_decode_to_utf8(input, table) do
    case reference_decode(input, table) do
      {:ok, codepoints} -> {:ok, List.to_string(codepoints)}
      error -> error
    end
  end

  defp reference_encode_from_utf8(input, encoder) do
    input
    |> :unicode.characters_to_list(:utf8)
    |> reference_encode(encoder)
  end

  defp timed_median(fun, samples) do
    nil
    |> List.duplicate(samples)
    |> Enum.map(fn _ ->
      {microseconds, _result} = :timer.tc(fun)
      microseconds
    end)
    |> Enum.sort()
    |> Enum.at(div(samples, 2))
  end

  defp assert_equal!(actual, expected, canonical, operation) do
    if actual != expected do
      raise "#{canonical} #{operation} parity failure"
    end
  end
end

Iconvex.Specs.LietuvybeLSTSourceQualifiedBench.run()

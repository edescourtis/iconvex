defmodule Iconvex.Specs.GlyphVectorTACEBenchmark do
  @moduledoc false

  @root Path.expand("..", __DIR__)
  @glyph_dir Path.join(@root, "priv/sources/glyph-vector-unicode")
  @tace_mapping Path.join(@root, "priv/sources/tace16-2010/appendix_d.csv")
  @quick not is_nil(System.get_env("ICONVEX_BENCH_SECONDS"))
  @timing_bytes if(@quick, do: 32_768, else: 262_144)
  @small_bytes if(@quick, do: 16_384, else: 65_536)
  @large_bytes @small_bytes * 2
  @samples if(@quick, do: 3, else: 7)
  @relative_ceiling 30.0
  @scaling_ceiling 2.35

  @glyph_profiles [
    {Iconvex.Specs.LY1TexnANSI11AGL4036A9CA, "ly1_agl_4036a9ca.csv"},
    {Iconvex.Specs.PostScript3ISOLatin1AGL4036A9CA, "postscript3_isolatin1_agl_4036a9ca.csv"}
  ]

  @tace_profiles [
    {Iconvex.Specs.TACE16AppendixD2010BE, :big},
    {Iconvex.Specs.TACE16AppendixD2010LE, :little}
  ]

  def run do
    IO.puts("schema\ticonvex-glyph-vector-tace-benchmark\t2")

    IO.puts(
      "columns\tprofile\toperation\tbytes\tnative_reductions\t" <>
        "reference_reductions\tnative_to_reference_reductions\tnative_us\t" <>
        "reference_us\tnative_to_reference_elapsed"
    )

    profiles =
      Enum.map(@glyph_profiles, fn {codec, filename} ->
        glyph_profile(codec, Path.join(@glyph_dir, filename), @timing_bytes)
      end) ++
        Enum.map(@tace_profiles, fn {codec, endian} ->
          tace_profile(codec, endian, @timing_bytes)
        end)

    operation_gates = Enum.flat_map(profiles, &benchmark_profile/1)
    scaling_gates = Enum.map(profiles, &scaling_gate/1)

    passed_reductions = Enum.count(operation_gates, & &1.reductions)
    passed_elapsed = Enum.count(operation_gates, & &1.elapsed)
    passed_scaling = Enum.count(scaling_gates, & &1)

    IO.puts("#{passed_reductions}/#{length(operation_gates)} reduction gates passed")
    IO.puts("#{passed_elapsed}/#{length(operation_gates)} elapsed-time gates passed")
    IO.puts("#{passed_scaling}/#{length(scaling_gates)} scaling gates passed")

    unless passed_reductions == 12 and passed_elapsed == 12 and passed_scaling == 4 do
      raise "glyph-vector/TACE benchmark gate FAILED"
    end

    IO.puts(
      "comparator\tindependent-table-reference\tGNU libiconv 1.19 has no exact " <>
        "source-qualified LY1, PostScript composite, or TACE16 profile"
    )
  end

  defp benchmark_profile(profile) do
    IO.puts("profile\t#{profile.codec.canonical_name()}")

    operations = [
      {"decode", fn -> profile.codec.decode(profile.source) end, profile.reference_decode,
       {:ok, profile.codepoints}},
      {"encode", fn -> profile.codec.encode(profile.codepoints) end, profile.reference_encode,
       {:ok, profile.canonical_source}},
      {"roundtrip", fn -> native_roundtrip(profile.codec, profile.source) end,
       profile.reference_roundtrip, {:ok, profile.canonical_source}}
    ]

    Enum.map(operations, fn {operation, native, reference, expected} ->
      native_reductions = reductions(native, expected)
      reference_reductions = reductions(reference, expected)
      reduction_ratio = native_reductions / max(reference_reductions, 1)
      native_us = median_us(native, expected)
      reference_us = median_us(reference, expected)
      elapsed_ratio = native_us / max(reference_us, 1)

      IO.puts(
        Enum.join(
          [
            "result",
            profile.codec.canonical_name(),
            operation,
            byte_size(profile.source),
            native_reductions,
            reference_reductions,
            decimal(reduction_ratio),
            native_us,
            reference_us,
            decimal(elapsed_ratio)
          ],
          "\t"
        )
      )

      %{
        reductions: reduction_ratio <= @relative_ceiling,
        elapsed: elapsed_ratio <= @relative_ceiling
      }
    end)
  end

  defp scaling_gate(%{kind: {:glyph, mapping}, codec: codec}) do
    small = glyph_profile(codec, mapping, @small_bytes)
    large = glyph_profile(codec, mapping, @large_bytes)
    scaling_result(codec, small, large)
  end

  defp scaling_gate(%{kind: {:tace, endian}, codec: codec}) do
    small = tace_profile(codec, endian, @small_bytes)
    large = tace_profile(codec, endian, @large_bytes)
    scaling_result(codec, small, large)
  end

  defp scaling_result(codec, small, large) do
    small_reductions =
      reductions(
        fn -> native_roundtrip(codec, small.source) end,
        {:ok, small.canonical_source}
      )

    large_reductions =
      reductions(
        fn -> native_roundtrip(codec, large.source) end,
        {:ok, large.canonical_source}
      )

    ratio = large_reductions / max(small_reductions, 1)
    passed? = ratio <= @scaling_ceiling

    IO.puts(
      Enum.join(
        [
          "scaling",
          codec.canonical_name(),
          byte_size(small.source),
          byte_size(large.source),
          small_reductions,
          large_reductions,
          decimal(ratio)
        ],
        "\t"
      )
    )

    passed?
  end

  defp glyph_profile(codec, mapping_path, bytes) do
    {decode, encode} = glyph_tables(mapping_path)
    alphabet = decode |> Map.keys() |> Enum.sort() |> :erlang.list_to_binary()
    source = repeat_to_size(alphabet, bytes)
    codepoints = glyph_decode(source, decode)
    canonical_source = glyph_encode(codepoints, encode)

    %{
      kind: {:glyph, mapping_path},
      codec: codec,
      source: source,
      codepoints: codepoints,
      canonical_source: canonical_source,
      reference_decode: fn -> {:ok, glyph_decode(source, decode)} end,
      reference_encode: fn -> {:ok, glyph_encode(codepoints, encode)} end,
      reference_roundtrip: fn -> {:ok, source |> glyph_decode(decode) |> glyph_encode(encode)} end
    }
  end

  defp tace_profile(codec, endian, bytes) do
    {decode, encode} = tace_tables()

    alphabet =
      decode
      |> Map.keys()
      |> Enum.sort()
      |> Enum.map(&word(&1, endian))
      |> IO.iodata_to_binary()

    source = alphabet |> repeat_to_size(bytes) |> even_prefix()
    codepoints = tace_decode(source, decode, endian)
    canonical_source = tace_encode(codepoints, encode, endian)

    %{
      kind: {:tace, endian},
      codec: codec,
      source: source,
      codepoints: codepoints,
      canonical_source: canonical_source,
      reference_decode: fn -> {:ok, tace_decode(source, decode, endian)} end,
      reference_encode: fn -> {:ok, tace_encode(codepoints, encode, endian)} end,
      reference_roundtrip: fn ->
        {:ok, source |> tace_decode(decode, endian) |> tace_encode(encode, endian)}
      end
    }
  end

  defp glyph_tables(path) do
    decode =
      path
      |> File.stream!()
      |> Stream.drop(1)
      |> Enum.reduce(%{}, fn line, acc ->
        [byte, codepoint] = line |> String.trim() |> String.split(",", parts: 2)
        Map.put(acc, String.to_integer(byte, 16), String.to_integer(codepoint, 16))
      end)

    encode =
      Enum.reduce(decode, %{}, fn {byte, codepoint}, acc ->
        Map.update(acc, codepoint, byte, &min(&1, byte))
      end)

    {decode, encode}
  end

  defp tace_tables do
    rows =
      @tace_mapping
      |> File.stream!()
      |> Stream.drop(1)
      |> Enum.map(fn line ->
        [unit, sequence, _status, _name] = line |> String.trim() |> String.split(",", parts: 4)

        codepoints =
          sequence
          |> String.split("+", trim: true)
          |> Enum.map(&String.to_integer(&1, 16))

        {String.to_integer(unit, 16), codepoints}
      end)

    decode = Map.new(rows)

    encode =
      Enum.reduce(rows, %{1 => %{}, 2 => %{}, 3 => %{}, 4 => %{}}, fn {unit, codepoints}, acc ->
        update_in(acc[length(codepoints)], &Map.put_new(&1, List.to_tuple(codepoints), unit))
      end)

    {decode, encode}
  end

  defp glyph_decode(source, decode),
    do: for(<<byte <- source>>, do: Map.fetch!(decode, byte))

  defp glyph_encode(codepoints, encode),
    do: codepoints |> Enum.map(&Map.fetch!(encode, &1)) |> :erlang.list_to_binary()

  defp tace_decode(source, decode, :big),
    do: for(<<unit::16-big <- source>>, codepoint <- Map.fetch!(decode, unit), do: codepoint)

  defp tace_decode(source, decode, :little),
    do: for(<<unit::16-little <- source>>, codepoint <- Map.fetch!(decode, unit), do: codepoint)

  defp tace_encode(codepoints, encode, endian),
    do:
      codepoints
      |> tace_encode_loop(encode, endian, [])
      |> :lists.reverse()
      |> IO.iodata_to_binary()

  defp tace_encode_loop([], _encode, _endian, acc), do: acc

  defp tace_encode_loop([a, b, c, d | rest], encode, endian, acc) do
    cond do
      unit = encode[4][{a, b, c, d}] ->
        tace_encode_loop(rest, encode, endian, [word(unit, endian) | acc])

      unit = encode[3][{a, b, c}] ->
        tace_encode_loop([d | rest], encode, endian, [word(unit, endian) | acc])

      unit = encode[2][{a, b}] ->
        tace_encode_loop([c, d | rest], encode, endian, [word(unit, endian) | acc])

      unit = encode[1][{a}] ->
        tace_encode_loop([b, c, d | rest], encode, endian, [word(unit, endian) | acc])

      true ->
        raise "unrepresentable TACE benchmark scalar U+#{Integer.to_string(a, 16)}"
    end
  end

  defp tace_encode_loop([a, b, c], encode, endian, acc) do
    cond do
      unit = encode[3][{a, b, c}] ->
        tace_encode_loop([], encode, endian, [word(unit, endian) | acc])

      unit = encode[2][{a, b}] ->
        tace_encode_loop([c], encode, endian, [word(unit, endian) | acc])

      unit = encode[1][{a}] ->
        tace_encode_loop([b, c], encode, endian, [word(unit, endian) | acc])

      true ->
        raise "unrepresentable TACE benchmark scalar U+#{Integer.to_string(a, 16)}"
    end
  end

  defp tace_encode_loop([a, b], encode, endian, acc) do
    cond do
      unit = encode[2][{a, b}] ->
        tace_encode_loop([], encode, endian, [word(unit, endian) | acc])

      unit = encode[1][{a}] ->
        tace_encode_loop([b], encode, endian, [word(unit, endian) | acc])

      true ->
        raise "unrepresentable TACE benchmark scalar U+#{Integer.to_string(a, 16)}"
    end
  end

  defp tace_encode_loop([a], encode, endian, acc) do
    case encode[1] do
      %{{^a} => unit} -> [word(unit, endian) | acc]
      _ -> raise "unrepresentable TACE benchmark scalar U+#{Integer.to_string(a, 16)}"
    end
  end

  defp native_roundtrip(codec, source) do
    with {:ok, codepoints} <- codec.decode(source), do: codec.encode(codepoints)
  end

  defp reductions(function, expected) do
    assert_result(function.(), expected)
    parent = self()
    token = make_ref()

    spawn(fn ->
      :erlang.garbage_collect()
      {:reductions, before_count} = Process.info(self(), :reductions)
      result = function.()
      {:reductions, after_count} = Process.info(self(), :reductions)

      if result == expected do
        send(parent, {token, :ok, after_count - before_count})
      else
        send(parent, {token, {:mismatch, result}, 0})
      end
    end)

    receive do
      {^token, :ok, count} -> count
      {^token, {:mismatch, result}, _count} -> assert_result(result, expected)
    after
      30_000 -> raise "benchmark reduction measurement timed out"
    end
  end

  defp median_us(function, expected) do
    for _ <- 1..@samples do
      :erlang.garbage_collect()
      {microseconds, result} = :timer.tc(function)
      assert_result(result, expected)
      microseconds
    end
    |> Enum.sort()
    |> Enum.at(div(@samples, 2))
  end

  defp assert_result(actual, expected) do
    unless actual == expected, do: raise("benchmark result mismatch")
  end

  defp repeat_to_size(alphabet, bytes) do
    copies = div(bytes + byte_size(alphabet) - 1, byte_size(alphabet))
    alphabet |> :binary.copy(copies) |> binary_part(0, bytes)
  end

  defp even_prefix(binary),
    do: binary_part(binary, 0, byte_size(binary) - rem(byte_size(binary), 2))

  defp word(unit, :big), do: <<unit::16-big>>
  defp word(unit, :little), do: <<unit::16-little>>
  defp decimal(value), do: :erlang.float_to_binary(value / 1, decimals: 3)
end

Iconvex.Specs.GlyphVectorTACEBenchmark.run()

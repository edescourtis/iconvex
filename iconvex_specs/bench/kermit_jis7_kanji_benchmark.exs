defmodule Iconvex.Specs.KermitJIS7KanjiBenchmark.Reference do
  @moduledoc false

  @mapping_path Path.expand("../priv/sources/JIS0208.TXT", __DIR__)
  @esc 0x1B
  @so 0x0E
  @si 0x0F

  @rows @mapping_path
        |> File.stream!()
        |> Stream.reject(&String.starts_with?(&1, "#"))
        |> Stream.map(&String.split/1)
        |> Stream.filter(&(length(&1) >= 3))
        |> Enum.map(fn [_shift_jis, "0x" <> jis, "0x" <> unicode | _comment] ->
          <<row::binary-size(2), cell::binary-size(2)>> = jis
          pair = String.to_integer(row <> cell, 16)
          {pair, String.to_integer(unicode, 16)}
        end)

  @decode Map.new(@rows)
  @encode @rows
          |> Enum.reject(fn {_pair, codepoint} ->
            codepoint in 0x039D..0x0400 or codepoint in [0xFFE3, 0xFFE5]
          end)
          |> Map.new(fn {pair, codepoint} -> {codepoint, pair} end)

  def alphabet, do: [?A, 0x00A5, 0x203E] ++ Enum.to_list(0xFF61..0xFF9F) ++ Map.keys(@encode)

  def decode_to_utf8(input) do
    {:ok, input |> decode(:roman, []) |> :lists.reverse() |> List.to_string()}
  end

  def encode_from_utf8(input) do
    codepoints = :unicode.characters_to_list(input, :utf8)

    {state, acc} =
      Enum.reduce(codepoints, {:roman, []}, fn codepoint, {state, acc} ->
        {charset, bytes} = encoded(codepoint)
        {output, next_state} = emit(state, charset, bytes)
        {next_state, [output | acc]}
      end)

    suffix = terminal_reset(state)
    {:ok, [Enum.reverse(acc), suffix] |> IO.iodata_to_binary()}
  end

  defp decode(<<>>, _state, acc), do: acc

  defp decode(<<@esc, @esc, rest::binary>>, state, acc),
    do: decode(rest, state, acc)

  defp decode(<<@esc, ?$, designation, rest::binary>>, _state, acc)
       when designation in [?@, ?B],
       do: decode(rest, :kanji, acc)

  defp decode(<<@esc, ?(, designation, rest::binary>>, _state, acc)
       when designation in [?B, ?J],
       do: decode(rest, :roman, acc)

  defp decode(<<@so, rest::binary>>, _state, acc), do: decode(rest, :kana, acc)
  defp decode(<<@si, rest::binary>>, _state, acc), do: decode(rest, :roman, acc)

  defp decode(<<byte, rest::binary>>, :roman, acc) do
    codepoint = if byte == 0x5C, do: 0x00A5, else: if(byte == 0x7E, do: 0x203E, else: byte)
    decode(rest, :roman, [codepoint | acc])
  end

  defp decode(<<byte, rest::binary>>, :kana, acc) when byte in 0x21..0x5F,
    do: decode(rest, :kana, [byte + 0xFF40 | acc])

  defp decode(<<byte, rest::binary>>, :kana, acc), do: decode(rest, :kana, [byte | acc])

  defp decode(<<first, second, rest::binary>>, :kanji, acc)
       when first in 0x21..0x7E and second in 0x21..0x7E do
    codepoint = Map.fetch!(@decode, Bitwise.bsl(first, 8) + second)
    decode(rest, :kanji, [codepoint | acc])
  end

  defp decode(<<byte, rest::binary>>, :kanji, acc), do: decode(rest, :kanji, [byte | acc])

  defp encoded(0x00A5), do: {:roman, <<0x5C>>}
  defp encoded(0x203E), do: {:roman, <<0x7E>>}

  defp encoded(codepoint) when codepoint in 0xFF61..0xFF9F,
    do: {:kana, <<codepoint - 0xFF40>>}

  defp encoded(codepoint)
       when codepoint in 0x00..0x7F and codepoint not in [0x5C, 0x7E],
       do: {:roman, <<codepoint>>}

  defp encoded(codepoint) do
    pair = Map.fetch!(@encode, codepoint)
    {:kanji, <<Bitwise.bsr(pair, 8), Bitwise.band(pair, 0xFF)>>}
  end

  defp emit(:roman, :roman, bytes), do: {bytes, :roman}
  defp emit(:roman, :kana, bytes), do: {<<@so, bytes::binary>>, :kana}
  defp emit(:roman, :kanji, bytes), do: {<<@esc, "$B", bytes::binary>>, :kanji}
  defp emit(:kana, :roman, bytes), do: {<<@si, bytes::binary>>, :roman}
  defp emit(:kana, :kana, bytes), do: {bytes, :kana}
  defp emit(:kana, :kanji, bytes), do: {<<@si, @esc, "$B", bytes::binary>>, :kanji}
  defp emit(:kanji, :roman, bytes), do: {<<@esc, "(J", bytes::binary>>, :roman}
  defp emit(:kanji, :kana, bytes), do: {<<@esc, "(J", @so, bytes::binary>>, :kana}
  defp emit(:kanji, :kanji, bytes), do: {bytes, :kanji}

  defp terminal_reset(:roman), do: <<>>
  defp terminal_reset(:kana), do: <<@si>>
  defp terminal_reset(:kanji), do: <<@esc, "(J">>
end

defmodule Iconvex.Specs.KermitJIS7KanjiBenchmark do
  @moduledoc false

  alias Iconvex.Specs.KermitJIS7Kanji
  alias Iconvex.Specs.KermitJIS7KanjiBenchmark.Reference

  @quick "--quick" in System.argv()
  @timing_bytes if(@quick, do: 131_072, else: 1_048_576)
  @samples if(@quick, do: 5, else: 9)
  @warmups 2
  @small_bytes 65_536
  @large_bytes 131_072
  @reduction_bounds {1.50, 2.60}
  @relative_ceiling 1.25
  @throughput_floor 1.0

  def run do
    IO.puts("schema\ticonvex-kermit-jis7-kanji-benchmark\t1")

    IO.puts(
      "columns\tcorpus\toperation\tencoded_bytes\tmedian_us\tmib_per_second\t" <>
        "small_reductions\tlarge_reductions\treduction_scaling\t" <>
        "composed_reference_us\tnative_to_composed"
    )

    for corpus_name <- [:roman, :complete_repertoire] do
      timing = corpus(corpus_name, @timing_bytes)
      small = corpus(corpus_name, @small_bytes)
      large = corpus(corpus_name, @large_bytes)

      benchmark(
        corpus_name,
        "decode_to_utf8",
        {fn -> KermitJIS7Kanji.decode_to_utf8(timing.source) end, {:ok, timing.text}},
        {fn -> KermitJIS7Kanji.decode_to_utf8(small.source) end, {:ok, small.text}},
        {fn -> KermitJIS7Kanji.decode_to_utf8(large.source) end, {:ok, large.text}},
        {fn -> Reference.decode_to_utf8(timing.source) end, {:ok, timing.text}},
        byte_size(timing.source)
      )

      benchmark(
        corpus_name,
        "encode_from_utf8",
        {fn -> KermitJIS7Kanji.encode_from_utf8(timing.text) end, {:ok, timing.source}},
        {fn -> KermitJIS7Kanji.encode_from_utf8(small.text) end, {:ok, small.source}},
        {fn -> KermitJIS7Kanji.encode_from_utf8(large.text) end, {:ok, large.source}},
        {fn -> Reference.encode_from_utf8(timing.text) end, {:ok, timing.source}},
        byte_size(timing.source)
      )
    end

    report_gnu_identity()
    IO.puts("summary\t2 corpora\t4 performance gates passed\tnative/composed <= 1.25x")
  end

  defp benchmark(corpus, operation, timing, small, large, reference, encoded_bytes) do
    median_us = median_us(timing)
    reference_us = median_us(reference)
    small_reductions = reductions(small)
    large_reductions = reductions(large)
    scaling = large_reductions / max(small_reductions, 1)
    relative = median_us / max(reference_us, 1)
    rate = encoded_bytes / 1_048_576 / (median_us / 1_000_000)

    gate!(corpus, operation, scaling, relative, rate)

    IO.puts(
      Enum.join(
        [
          "result",
          corpus,
          operation,
          encoded_bytes,
          median_us,
          decimal(rate),
          small_reductions,
          large_reductions,
          decimal(scaling),
          reference_us,
          decimal(relative)
        ],
        "\t"
      )
    )
  end

  defp gate!(corpus, operation, scaling, relative, rate) do
    label = "#{corpus} #{operation}"
    {minimum_scaling, maximum_scaling} = @reduction_bounds

    unless scaling >= minimum_scaling and scaling <= maximum_scaling do
      raise "#{label} reduction scaling #{scaling} is outside " <>
              "#{minimum_scaling}..#{maximum_scaling}"
    end

    if relative > @relative_ceiling do
      raise "#{label} native/composed #{relative} exceeds #{@relative_ceiling}"
    end

    if rate < @throughput_floor do
      raise "#{label} throughput #{rate} MiB/s is below #{@throughput_floor}"
    end
  end

  defp corpus(:roman, bytes) do
    source = :binary.copy(<<?A>>, bytes)
    %{source: source, text: source}
  end

  defp corpus(:complete_repertoire, minimum_bytes) do
    alphabet = Reference.alphabet()
    text_alphabet = List.to_string(alphabet)
    {:ok, source_alphabet} = KermitJIS7Kanji.encode(alphabet)
    copies = div(minimum_bytes + byte_size(source_alphabet) - 1, byte_size(source_alphabet))

    %{
      source: :binary.copy(source_alphabet, copies),
      text: :binary.copy(text_alphabet, copies)
    }
  end

  defp median_us({function, expected}) do
    for _ <- 1..@warmups, do: assert_result(function.(), expected)

    for _ <- 1..@samples do
      :erlang.garbage_collect()
      {microseconds, result} = :timer.tc(function)
      assert_result(result, expected)
      microseconds
    end
    |> Enum.sort()
    |> Enum.at(div(@samples, 2))
  end

  defp reductions({function, expected}) do
    parent = self()
    token = make_ref()

    spawn(fn ->
      :erlang.garbage_collect()
      {:reductions, before_count} = Process.info(self(), :reductions)
      result = function.()
      {:reductions, after_count} = Process.info(self(), :reductions)
      send(parent, {token, result, after_count - before_count})
    end)

    receive do
      {^token, result, count} ->
        assert_result(result, expected)
        count
    after
      30_000 -> raise "benchmark reduction measurement timed out"
    end
  end

  defp report_gnu_identity do
    executable = System.get_env("GNU_ICONV", "/opt/homebrew/opt/libiconv/bin/iconv")

    if File.exists?(executable) do
      {listing, status} = System.cmd(executable, ["-l"], stderr_to_stdout: true)
      normalized = listing |> String.upcase() |> String.replace(~r/[^A-Z0-9]/, "")

      if status == 0 and
           (String.contains?(normalized, "JIS7KANJI") or
              String.contains?(normalized, "ISO2022JPKANJI")) do
        raise "GNU libiconv unexpectedly advertises Kermit's exact source-qualified identity"
      end

      IO.puts(
        "comparator\tgnu-libiconv-1.19\tunavailable\t" <>
          "no JIS7-KANJI or ISO2022JP-KANJI identity; ISO-2022-JP has a different state contract"
      )
    else
      IO.puts("comparator\tgnu-libiconv\tunavailable\tset GNU_ICONV to verify identity listing")
    end
  end

  defp assert_result(actual, expected) do
    unless actual == expected, do: raise("benchmark result mismatch")
  end

  defp decimal(value), do: :erlang.float_to_binary(value / 1, decimals: 3)
end

Iconvex.Specs.KermitJIS7KanjiBenchmark.run()

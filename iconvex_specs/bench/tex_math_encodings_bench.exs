defmodule Iconvex.Specs.TeXMathEncodingsBench do
  @moduledoc false

  @samples 7
  @warmups 3

  def run do
    copies = System.get_env("TEX_MATH_BENCH_COPIES", "8192") |> String.to_integer()
    input = :binary.copy(:erlang.list_to_binary(Enum.to_list(0x00..0x7F)), copies)

    IO.puts("payload\t#{byte_size(input)} source bytes")
    IO.puts("path\tMiB/s\tmedian us\tdirect/composed")

    for module <- [
          Iconvex.Specs.TeXLiveOMLCMMI10ToUnicode2026,
          Iconvex.Specs.TeXLiveOMSCMSY10ToUnicode2026
        ] do
      benchmark_profile(module, input)
    end
  end

  defp benchmark_profile(module, input) do
    {:ok, expected_utf8} = module.decode_to_utf8(input)
    {:ok, expected_codepoints} = module.decode(input)
    {:ok, ^input} = module.encode_from_utf8(expected_utf8)
    {:ok, ^input} = module.encode(expected_codepoints)

    direct_decode = fn -> module.decode_to_utf8(input) end

    composed_decode = fn ->
      with {:ok, codepoints} <- module.decode(input), do: {:ok, List.to_string(codepoints)}
    end

    direct_encode = fn -> module.encode_from_utf8(expected_utf8) end

    composed_encode = fn ->
      case :unicode.characters_to_list(expected_utf8, :utf8) do
        codepoints when is_list(codepoints) -> module.encode(codepoints)
      end
    end

    direct_decode_us = measure(direct_decode, expected_utf8)
    composed_decode_us = measure(composed_decode, expected_utf8)
    direct_encode_us = measure(direct_encode, input)
    composed_encode_us = measure(composed_encode, input)
    label = module.canonical_name()

    report("#{label} decode direct", byte_size(input), direct_decode_us, composed_decode_us)
    report("#{label} decode composed", byte_size(input), composed_decode_us, direct_decode_us)
    report("#{label} encode direct", byte_size(input), direct_encode_us, composed_encode_us)
    report("#{label} encode composed", byte_size(input), composed_encode_us, direct_encode_us)
  end

  defp measure(fun, expected) do
    for _ <- 1..@warmups do
      assert_result!(fun.(), expected)
    end

    for _ <- 1..@samples do
      :erlang.garbage_collect()
      {microseconds, result} = :timer.tc(fun)
      assert_result!(result, expected)
      microseconds
    end
    |> Enum.sort()
    |> Enum.at(div(@samples, 2))
  end

  defp assert_result!({:ok, expected}, expected), do: :ok

  defp assert_result!(actual, expected) do
    raise "benchmark path returned #{inspect(actual, limit: 5)}; expected #{byte_size(expected)} bytes"
  end

  defp report(label, bytes, microseconds, comparison_us) do
    mib_per_second = bytes / 1_048_576 / (microseconds / 1_000_000)
    ratio = comparison_us / microseconds

    IO.puts(
      "#{label}\t#{Float.round(mib_per_second, 2)}\t#{microseconds}\t#{Float.round(ratio, 2)}x"
    )
  end
end

Iconvex.Specs.TeXMathEncodingsBench.run()

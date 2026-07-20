defmodule Iconvex.Specs.IBM029CardIowaBenchmark do
  import Bitwise

  alias Iconvex.Packed.LSB

  @quick "--quick" in System.argv()
  @iterations if(@quick, do: 1, else: 7)
  @warmups if(@quick, do: 1, else: 2)
  @sample_repetitions if(@quick, do: 64, else: 1_024)
  @reduction_samples 3
  @source_path Path.expand(
                 "../priv/sources/punched-card-codes/ibm_029_card_iowa_824e61a9.csv",
                 __DIR__
               )
  @source_sha256 "c7a394f8ed6b025b6058a10e23c35036b6b50c8fc70db6da07c9724967c45373"

  @profile Iconvex.Specs.IBM029CardIowa824E61A9
  @be Iconvex.Specs.IBM029CardIowa824E61A9_16BE
  @le Iconvex.Specs.IBM029CardIowa824E61A9_16LE

  def run do
    rows = source_rows()
    canonical = Enum.filter(rows, &(&1.disposition == :canonical))
    encode = Map.new(canonical, &{&1.codepoint, &1.mask})
    decode = Map.new(rows, &{&1.mask, &1.codepoint})
    alphabet = Enum.map(canonical, & &1.codepoint)
    sample = alphabet |> List.duplicate(@sample_repetitions) |> List.flatten()

    unless length(rows) == 64 and map_size(encode) == 63 and map_size(decode) == 64 do
      raise "IBM 029 Iowa benchmark source cardinality changed"
    end

    {:ok, packed_msb} = @profile.encode_packed(sample)
    {:ok, packed_lsb} = @profile.encode_packed_lsb(sample)
    {:ok, words_be} = @be.encode(sample)
    {:ok, words_le} = @le.encode(sample)

    operations = [
      {"packed MSB encode", fn -> @profile.encode_packed(sample) end,
       fn -> reference_msb_encode(sample, encode) end},
      {"packed MSB decode", fn -> @profile.decode_packed(packed_msb) end,
       fn -> reference_msb_decode(packed_msb, decode) end},
      {"packed LSB encode", fn -> @profile.encode_packed_lsb(sample) end,
       fn -> reference_lsb_encode(sample, encode) end},
      {"packed LSB decode", fn -> @profile.decode_packed_lsb(packed_lsb) end,
       fn -> reference_lsb_decode(packed_lsb, decode) end},
      {"16BE encode", fn -> @be.encode(sample) end,
       fn -> reference_word_encode(sample, encode, :big) end},
      {"16BE decode", fn -> @be.decode(words_be) end,
       fn -> reference_word_decode(words_be, decode, :big) end},
      {"16LE encode", fn -> @le.encode(sample) end,
       fn -> reference_word_encode(sample, encode, :little) end},
      {"16LE decode", fn -> @le.decode(words_le) end,
       fn -> reference_word_decode(words_le, decode, :little) end}
    ]

    IO.puts("IBM-029-CARD-IOWA-824E61A9; #{length(sample)} characters per timed operation")

    Enum.each(operations, fn {name, native, reference} ->
      native_result = native.()
      reference_result = reference.()

      unless native_result == reference_result do
        raise "#{name} differs from the source-derived reference"
      end

      native_us = median_us(native)
      reference_us = median_us(reference)
      ratio = native_us / max(reference_us, 1)

      IO.puts(
        :io_lib.format(
          "~s native / source-derived reference: ~.3fx (~.3f ms / ~.3f ms)",
          [name, ratio, native_us / 1_000, reference_us / 1_000]
        )
      )

      if ratio > 30.0 do
        raise "#{name} exceeded the 30x source-derived-reference ceiling: #{ratio}x"
      end
    end)

    IO.puts("all 8 native/reference 30x ceiling gates passed")
    reduction_scaling_gates()
  end

  defp source_rows do
    bytes = File.read!(@source_path)

    unless sha256(bytes) == @source_sha256 do
      raise "IBM 029 Iowa benchmark source digest changed"
    end

    bytes
    |> String.split("\n", trim: true)
    |> tl()
    |> Enum.map(fn line ->
      [_column, codepoint, mask, disposition] = String.split(line, ",")

      %{
        codepoint: codepoint |> String.trim_leading("U+") |> String.to_integer(16),
        mask: mask |> String.trim_leading("0x") |> String.to_integer(16),
        disposition: disposition(disposition)
      }
    end)
  end

  defp disposition("canonical"), do: :canonical
  defp disposition("decode_alias"), do: :decode_alias

  defp reference_msb_encode(codepoints, encode) do
    encoded = Enum.map(codepoints, fn codepoint -> <<Map.fetch!(encode, codepoint)::12>> end)
    {:ok, :erlang.list_to_bitstring(encoded)}
  end

  defp reference_msb_decode(input, decode) do
    {:ok, for(<<mask::12 <- input>>, do: Map.fetch!(decode, mask))}
  end

  defp reference_lsb_encode(codepoints, encode) do
    {bytes, buffer, buffered_bits} =
      Enum.reduce(codepoints, {[], 0, 0}, fn codepoint, state ->
        state
        |> append_lsb(Map.fetch!(encode, codepoint), 12)
        |> emit_lsb_bytes()
      end)

    bytes =
      if buffered_bits == 0,
        do: bytes,
        else: [buffer &&& 0xFF | bytes]

    {:ok,
     %LSB{
       data: bytes |> :lists.reverse() |> :erlang.list_to_binary(),
       bit_size: length(codepoints) * 12,
       unit_bits: 12
     }}
  end

  defp reference_lsb_decode(%LSB{data: data, bit_size: bit_size, unit_bits: 12}, decode) do
    decode_lsb_units(data, div(bit_size, 12), decode, 0, 0, [])
  end

  defp decode_lsb_units(_data, 0, _decode, _buffer, _buffered_bits, acc),
    do: {:ok, :lists.reverse(acc)}

  defp decode_lsb_units(data, units, decode, buffer, buffered_bits, acc)
       when buffered_bits < 12 do
    <<byte, rest::binary>> = data

    decode_lsb_units(
      rest,
      units,
      decode,
      buffer ||| byte <<< buffered_bits,
      buffered_bits + 8,
      acc
    )
  end

  defp decode_lsb_units(data, units, decode, buffer, buffered_bits, acc) do
    mask = buffer &&& 0xFFF

    decode_lsb_units(
      data,
      units - 1,
      decode,
      buffer >>> 12,
      buffered_bits - 12,
      [Map.fetch!(decode, mask) | acc]
    )
  end

  defp append_lsb({bytes, buffer, buffered_bits}, value, width),
    do: {bytes, buffer ||| value <<< buffered_bits, buffered_bits + width}

  defp emit_lsb_bytes({bytes, buffer, buffered_bits}) when buffered_bits >= 8,
    do: emit_lsb_bytes({[buffer &&& 0xFF | bytes], buffer >>> 8, buffered_bits - 8})

  defp emit_lsb_bytes(state), do: state

  defp reference_word_encode(codepoints, encode, :big) do
    {:ok,
     codepoints
     |> Enum.map(fn codepoint -> <<Map.fetch!(encode, codepoint)::16-big>> end)
     |> IO.iodata_to_binary()}
  end

  defp reference_word_encode(codepoints, encode, :little) do
    {:ok,
     codepoints
     |> Enum.map(fn codepoint -> <<Map.fetch!(encode, codepoint)::16-little>> end)
     |> IO.iodata_to_binary()}
  end

  defp reference_word_decode(input, decode, :big),
    do: {:ok, for(<<mask::16-big <- input>>, do: Map.fetch!(decode, mask))}

  defp reference_word_decode(input, decode, :little),
    do: {:ok, for(<<mask::16-little <- input>>, do: Map.fetch!(decode, mask))}

  defp median_us(function) do
    for(_ <- 1..@warmups, do: function.())

    1..@iterations
    |> Enum.map(fn _ -> function |> :timer.tc() |> elem(0) end)
    |> Enum.sort()
    |> Enum.at(div(@iterations, 2))
  end

  defp reduction_scaling_gates do
    short = List.duplicate(?A, 20_000)
    long = List.duplicate(?A, 40_000)
    {:ok, short_msb} = @profile.encode_packed(short)
    {:ok, long_msb} = @profile.encode_packed(long)
    {:ok, short_lsb} = @profile.encode_packed_lsb(short)
    {:ok, long_lsb} = @profile.encode_packed_lsb(long)
    {:ok, short_be} = @be.encode(short)
    {:ok, long_be} = @be.encode(long)
    {:ok, short_le} = @le.encode(short)
    {:ok, long_le} = @le.encode(long)

    operations = [
      {"packed MSB encode", fn -> @profile.encode_packed(short) end,
       fn -> @profile.encode_packed(long) end},
      {"packed MSB decode", fn -> @profile.decode_packed(short_msb) end,
       fn -> @profile.decode_packed(long_msb) end},
      {"packed LSB encode", fn -> @profile.encode_packed_lsb(short) end,
       fn -> @profile.encode_packed_lsb(long) end},
      {"packed LSB decode", fn -> @profile.decode_packed_lsb(short_lsb) end,
       fn -> @profile.decode_packed_lsb(long_lsb) end},
      {"16BE encode", fn -> @be.encode(short) end, fn -> @be.encode(long) end},
      {"16BE decode", fn -> @be.decode(short_be) end, fn -> @be.decode(long_be) end},
      {"16LE encode", fn -> @le.encode(short) end, fn -> @le.encode(long) end},
      {"16LE decode", fn -> @le.decode(short_le) end, fn -> @le.decode(long_le) end}
    ]

    Enum.each(operations, fn {name, short_fun, long_fun} ->
      short_reductions = reduction_median(short_fun)
      long_reductions = reduction_median(long_fun)
      ratio = long_reductions / short_reductions

      IO.puts(:io_lib.format("~s reduction scaling 20k->40k: ~.3fx", [name, ratio]))

      unless ratio > 1.70 and ratio < 2.30 do
        raise "#{name} failed the linear reduction-scaling gate: #{ratio}x"
      end
    end)

    IO.puts("all 8 reduction-scaling gates passed")
  end

  defp reduction_median(function) do
    1..@reduction_samples
    |> Enum.map(fn _ -> reductions(function) end)
    |> Enum.sort()
    |> Enum.at(div(@reduction_samples, 2))
  end

  defp reductions(function) do
    {:reductions, before_count} = Process.info(self(), :reductions)
    {:ok, _} = function.()
    {:reductions, after_count} = Process.info(self(), :reductions)
    after_count - before_count
  end

  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end

Iconvex.Specs.IBM029CardIowaBenchmark.run()

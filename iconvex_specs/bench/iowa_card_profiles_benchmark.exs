defmodule Iconvex.Specs.IowaCardProfilesBenchmark do
  import Bitwise

  alias Iconvex.Packed.LSB

  @quick "--quick" in System.argv()
  @iterations if(@quick, do: 1, else: 7)
  @warmups if(@quick, do: 1, else: 2)
  @sample_repetitions if(@quick, do: 32, else: 1_024)
  @reduction_samples 3

  @profiles [
    %{
      canonical: "DEC-026-CARD-IOWA-824E61A9",
      source: "dec_026_card_iowa_824e61a9.csv",
      digest: "b5e4bd965af2c72f2b643e2681792e2c39d5dc25819268181f74f2cac94cc5d4",
      logical: Iconvex.Specs.DEC026CardIowa824E61A9,
      be: Iconvex.Specs.DEC026CardIowa824E61A9_16BE,
      le: Iconvex.Specs.DEC026CardIowa824E61A9_16LE
    },
    %{
      canonical: "DEC-029-CARD-IOWA-824E61A9",
      source: "dec_029_card_iowa_824e61a9.csv",
      digest: "810293f09cc61dc043f122465edb13a85d319f0c5c494882b7e9a715dc5222ba",
      logical: Iconvex.Specs.DEC029CardIowa824E61A9,
      be: Iconvex.Specs.DEC029CardIowa824E61A9_16BE,
      le: Iconvex.Specs.DEC029CardIowa824E61A9_16LE
    },
    %{
      canonical: "EBCD-CARD-IOWA-824E61A9",
      source: "ebcd_card_iowa_824e61a9.csv",
      digest: "1a57f8721c556354d6b3dde76d62ab9fbe6d8e405d4d7bf93e053d989bc4f588",
      logical: Iconvex.Specs.EBCDCardIowa824E61A9,
      be: Iconvex.Specs.EBCDCardIowa824E61A9_16BE,
      le: Iconvex.Specs.EBCDCardIowa824E61A9_16LE
    },
    %{
      canonical: "GE-600-CARD-IOWA-824E61A9",
      source: "ge_600_card_iowa_824e61a9.csv",
      digest: "d2e0846ed24df4b20492191a781238fb9e507b0628173ca504091a0c38313c7d",
      logical: Iconvex.Specs.GE600CardIowa824E61A9,
      be: Iconvex.Specs.GE600CardIowa824E61A9_16BE,
      le: Iconvex.Specs.GE600CardIowa824E61A9_16LE
    }
  ]

  def run do
    gates = Enum.flat_map(@profiles, &run_profile/1)

    unless length(gates) == 32 and Enum.all?(gates, &(&1 <= 30.0)) do
      raise "Iowa punched-card native/reference gate count or ceiling changed"
    end

    IO.puts("all 32 native/reference 30x ceiling gates passed")
    reduction_scaling_gates()
  end

  defp run_profile(profile) do
    rows = source_rows(profile)
    encode = Map.new(rows, &{&1.codepoint, &1.mask})
    decode = Map.new(rows, &{&1.mask, &1.codepoint})
    alphabet = Enum.map(rows, & &1.codepoint)
    sample = alphabet |> List.duplicate(@sample_repetitions) |> List.flatten()

    unless length(rows) == 64 and map_size(encode) == 64 and map_size(decode) == 64 do
      raise "#{profile.canonical} benchmark source cardinality changed"
    end

    {:ok, packed_msb} = call(profile.logical, :encode_packed, [sample])
    {:ok, packed_lsb} = call(profile.logical, :encode_packed_lsb, [sample])
    {:ok, words_be} = call(profile.be, :encode, [sample])
    {:ok, words_le} = call(profile.le, :encode, [sample])

    operations = [
      {"packed MSB encode", fn -> call(profile.logical, :encode_packed, [sample]) end,
       fn -> reference_msb_encode(sample, encode) end},
      {"packed MSB decode", fn -> call(profile.logical, :decode_packed, [packed_msb]) end,
       fn -> reference_msb_decode(packed_msb, decode) end},
      {"packed LSB encode", fn -> call(profile.logical, :encode_packed_lsb, [sample]) end,
       fn -> reference_lsb_encode(sample, encode) end},
      {"packed LSB decode", fn -> call(profile.logical, :decode_packed_lsb, [packed_lsb]) end,
       fn -> reference_lsb_decode(packed_lsb, decode) end},
      {"16BE encode", fn -> call(profile.be, :encode, [sample]) end,
       fn -> reference_word_encode(sample, encode, :big) end},
      {"16BE decode", fn -> call(profile.be, :decode, [words_be]) end,
       fn -> reference_word_decode(words_be, decode, :big) end},
      {"16LE encode", fn -> call(profile.le, :encode, [sample]) end,
       fn -> reference_word_encode(sample, encode, :little) end},
      {"16LE decode", fn -> call(profile.le, :decode, [words_le]) end,
       fn -> reference_word_decode(words_le, decode, :little) end}
    ]

    IO.puts("#{profile.canonical}; #{length(sample)} characters per timed operation")

    Enum.map(operations, fn {name, native, reference} ->
      unless native.() == reference.() do
        raise "#{profile.canonical} #{name} differs from the source-derived reference"
      end

      native_us = median_us(native)
      reference_us = median_us(reference)
      ratio = native_us / max(reference_us, 1)

      IO.puts(
        :io_lib.format(
          "~s ~s native / source-derived reference: ~.3fx (~.3f ms / ~.3f ms)",
          [profile.canonical, name, ratio, native_us / 1_000, reference_us / 1_000]
        )
      )

      if ratio > 30.0 do
        raise "#{profile.canonical} #{name} exceeded the 30x ceiling: #{ratio}x"
      end

      ratio
    end)
  end

  defp source_rows(profile) do
    path = Path.expand("../priv/sources/punched-card-codes/#{profile.source}", __DIR__)
    bytes = File.read!(path)

    unless sha256(bytes) == profile.digest do
      raise "#{profile.canonical} benchmark source digest changed"
    end

    bytes
    |> String.split("\n", trim: true)
    |> tl()
    |> Enum.map(fn line ->
      [_column, codepoint, mask, "canonical"] = String.split(line, ",")

      %{
        codepoint: codepoint |> String.trim_leading("U+") |> String.to_integer(16),
        mask: mask |> String.trim_leading("0x") |> String.to_integer(16)
      }
    end)
  end

  defp reference_msb_encode(codepoints, encode) do
    encoded = Enum.map(codepoints, fn codepoint -> <<Map.fetch!(encode, codepoint)::12>> end)
    {:ok, :erlang.list_to_bitstring(encoded)}
  end

  defp reference_msb_decode(input, decode),
    do: {:ok, for(<<mask::12 <- input>>, do: Map.fetch!(decode, mask))}

  defp reference_lsb_encode(codepoints, encode) do
    {bytes, buffer, buffered_bits} =
      Enum.reduce(codepoints, {[], 0, 0}, fn codepoint, state ->
        state
        |> append_lsb(Map.fetch!(encode, codepoint), 12)
        |> emit_lsb_bytes()
      end)

    bytes = if buffered_bits == 0, do: bytes, else: [buffer &&& 0xFF | bytes]

    {:ok,
     %LSB{
       data: bytes |> :lists.reverse() |> :erlang.list_to_binary(),
       bit_size: length(codepoints) * 12,
       unit_bits: 12
     }}
  end

  defp reference_lsb_decode(%LSB{data: data, bit_size: bit_size, unit_bits: 12}, decode),
    do: decode_lsb_units(data, div(bit_size, 12), decode, 0, 0, [])

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
    for _ <- 1..@warmups, do: function.()

    1..@iterations
    |> Enum.map(fn _ -> function |> :timer.tc() |> elem(0) end)
    |> Enum.sort()
    |> Enum.at(div(@iterations, 2))
  end

  defp reduction_scaling_gates do
    lengths = if @quick, do: {5_000, 10_000}, else: {20_000, 40_000}
    {short_length, long_length} = lengths

    gates =
      Enum.flat_map(@profiles, fn profile ->
        short = List.duplicate(?A, short_length)
        long = List.duplicate(?A, long_length)
        {:ok, short_msb} = call(profile.logical, :encode_packed, [short])
        {:ok, long_msb} = call(profile.logical, :encode_packed, [long])
        {:ok, short_lsb} = call(profile.logical, :encode_packed_lsb, [short])
        {:ok, long_lsb} = call(profile.logical, :encode_packed_lsb, [long])
        {:ok, short_be} = call(profile.be, :encode, [short])
        {:ok, long_be} = call(profile.be, :encode, [long])
        {:ok, short_le} = call(profile.le, :encode, [short])
        {:ok, long_le} = call(profile.le, :encode, [long])

        operations = [
          {"packed MSB encode", fn -> call(profile.logical, :encode_packed, [short]) end,
           fn -> call(profile.logical, :encode_packed, [long]) end},
          {"packed MSB decode", fn -> call(profile.logical, :decode_packed, [short_msb]) end,
           fn -> call(profile.logical, :decode_packed, [long_msb]) end},
          {"packed LSB encode", fn -> call(profile.logical, :encode_packed_lsb, [short]) end,
           fn -> call(profile.logical, :encode_packed_lsb, [long]) end},
          {"packed LSB decode", fn -> call(profile.logical, :decode_packed_lsb, [short_lsb]) end,
           fn -> call(profile.logical, :decode_packed_lsb, [long_lsb]) end},
          {"16BE encode", fn -> call(profile.be, :encode, [short]) end,
           fn -> call(profile.be, :encode, [long]) end},
          {"16BE decode", fn -> call(profile.be, :decode, [short_be]) end,
           fn -> call(profile.be, :decode, [long_be]) end},
          {"16LE encode", fn -> call(profile.le, :encode, [short]) end,
           fn -> call(profile.le, :encode, [long]) end},
          {"16LE decode", fn -> call(profile.le, :decode, [short_le]) end,
           fn -> call(profile.le, :decode, [long_le]) end}
        ]

        Enum.map(operations, fn {name, short_fun, long_fun} ->
          ratio = reduction_median(long_fun) / reduction_median(short_fun)

          IO.puts(
            :io_lib.format("~s ~s reduction scaling ~B->~B: ~.3fx", [
              profile.canonical,
              name,
              short_length,
              long_length,
              ratio
            ])
          )

          unless ratio > 1.70 and ratio < 2.30 do
            raise "#{profile.canonical} #{name} failed linear scaling: #{ratio}x"
          end

          ratio
        end)
      end)

    unless length(gates) == 32 do
      raise "Iowa punched-card reduction gate count changed"
    end

    IO.puts("all 32 reduction-scaling gates passed")
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

  defp call(module, function, arguments), do: apply(module, function, arguments)
  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end

Iconvex.Specs.IowaCardProfilesBenchmark.run()

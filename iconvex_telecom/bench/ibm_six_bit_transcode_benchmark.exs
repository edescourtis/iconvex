defmodule Iconvex.Telecom.IBMSixBitTranscodeBenchmark do
  @moduledoc false

  import Bitwise

  alias Iconvex.Packed.LSB

  @relative_ceiling 30.0
  @reduction_bounds {1.60, 2.60}
  @reduction_heap_words 1_000_000
  @warmups 2
  @iterations 7

  @profiles [
    %{
      label: "2780",
      codec: Iconvex.Telecom.IBM2780SixBitTranscode,
      csv: "ga27-3005-3.csv",
      sha256: "cbb94188f9ac1a8b9a95dcff91d0744c84f77ad53377d62dd76eff4d6a476416"
    },
    %{
      label: "bsc",
      codec: Iconvex.Telecom.IBMBscSixBitTranscode,
      csv: "ga27-3004-2.csv",
      sha256: "5dccf290006224a0de51dddda9ec227183f1527610f61cf2f70b606ccea7c31e"
    }
  ]

  @unit_bits 6

  def run do
    Enum.each(@profiles, &run_profile/1)

    IO.puts("all 12 native/reference output-equality gates passed")
    IO.puts("all 12 native/reference ratios <= #{@relative_ceiling}x")
    IO.puts("all 12 reduction-scaling gates passed")
  end

  defp run_profile(%{label: label, codec: codec} = profile) do
    canonical = codec.canonical_name()
    units = repeat_to_size(:erlang.list_to_binary(Enum.to_list(0..63)), 65_536)
    text = units |> codec.decode_to_utf8() |> assert_ok_value!()
    lsb = text |> Iconvex.Telecom.Packed.encode_from_utf8(canonical, :lsb) |> assert_ok_value!()
    msb = text |> Iconvex.Telecom.Packed.encode_from_utf8(canonical, :msb) |> assert_ok_value!()

    small_units = binary_part(units, 0, 20_000)
    large_units = binary_part(units, 0, 40_000)
    small_text = small_units |> codec.decode_to_utf8() |> assert_ok_value!()
    large_text = large_units |> codec.decode_to_utf8() |> assert_ok_value!()

    small_lsb =
      small_text |> Iconvex.Telecom.Packed.encode_from_utf8(canonical, :lsb) |> assert_ok_value!()

    large_lsb =
      large_text |> Iconvex.Telecom.Packed.encode_from_utf8(canonical, :lsb) |> assert_ok_value!()

    small_msb =
      small_text |> Iconvex.Telecom.Packed.encode_from_utf8(canonical, :msb) |> assert_ok_value!()

    large_msb =
      large_text |> Iconvex.Telecom.Packed.encode_from_utf8(canonical, :msb) |> assert_ok_value!()

    {decode_table, encode_table} = reference_tables!(profile.csv, profile.sha256)

    operations = [
      %{
        name: "decode",
        bytes: byte_size(units),
        native: fn -> codec.decode_to_utf8(units) end,
        reference: fn -> reference_decode(units, decode_table) end,
        small: fn -> codec.decode_to_utf8(small_units) end,
        large: fn -> codec.decode_to_utf8(large_units) end
      },
      %{
        name: "encode",
        bytes: byte_size(text),
        native: fn -> codec.encode_from_utf8(text) end,
        reference: fn -> reference_encode(text, encode_table) end,
        small: fn -> codec.encode_from_utf8(small_text) end,
        large: fn -> codec.encode_from_utf8(large_text) end
      },
      %{
        name: "pack_lsb",
        bytes: byte_size(text),
        native: fn -> Iconvex.Telecom.Packed.encode_from_utf8(text, canonical, :lsb) end,
        reference: fn -> reference_pack_lsb_from_utf8(text, encode_table) end,
        small: fn -> Iconvex.Telecom.Packed.encode_from_utf8(small_text, canonical, :lsb) end,
        large: fn -> Iconvex.Telecom.Packed.encode_from_utf8(large_text, canonical, :lsb) end
      },
      %{
        name: "unpack_lsb",
        bytes: byte_size(lsb.data),
        native: fn -> Iconvex.Telecom.Packed.decode_to_utf8(lsb, canonical, :lsb) end,
        reference: fn -> reference_unpack_lsb_to_utf8(lsb, decode_table) end,
        small: fn -> Iconvex.Telecom.Packed.decode_to_utf8(small_lsb, canonical, :lsb) end,
        large: fn -> Iconvex.Telecom.Packed.decode_to_utf8(large_lsb, canonical, :lsb) end
      },
      %{
        name: "pack_msb",
        bytes: byte_size(text),
        native: fn -> Iconvex.Telecom.Packed.encode_from_utf8(text, canonical, :msb) end,
        reference: fn -> reference_pack_msb_from_utf8(text, encode_table) end,
        small: fn -> Iconvex.Telecom.Packed.encode_from_utf8(small_text, canonical, :msb) end,
        large: fn -> Iconvex.Telecom.Packed.encode_from_utf8(large_text, canonical, :msb) end
      },
      %{
        name: "unpack_msb",
        bytes: div(bit_size(msb), 8),
        native: fn -> Iconvex.Telecom.Packed.decode_to_utf8(msb, canonical, :msb) end,
        reference: fn -> reference_unpack_msb_to_utf8(msb, decode_table) end,
        small: fn -> Iconvex.Telecom.Packed.decode_to_utf8(small_msb, canonical, :msb) end,
        large: fn -> Iconvex.Telecom.Packed.decode_to_utf8(large_msb, canonical, :msb) end
      }
    ]

    Enum.each(operations, &compare_and_measure(label, codec, &1))
  end

  defp compare_and_measure(label, codec, operation) do
    native_output = operation.native.() |> assert_ok_value!()
    reference_output = operation.reference.() |> assert_ok_value!()

    unless native_output == reference_output do
      raise "#{label} #{operation.name} native/reference output mismatch"
    end

    IO.puts("comparison\t#{codec.canonical_name()}\t#{operation.name}\toutput_equal\tpass")

    native_us = measure(operation.native)
    reference_us = measure(operation.reference)
    relative = native_us / max(reference_us, 1)
    assert_relative!(label, operation.name, relative)
    result(codec, operation.name, operation.bytes, native_us, relative)
    reduction_gate(label, operation.name, operation.small, operation.large)
  end

  defp reference_tables!(csv, expected_sha256) do
    priv_dir = :code.priv_dir(:iconvex_telecom) |> List.to_string()
    path = Path.join([priv_dir, "sources", "ibm-six-bit-transcode", csv])
    contents = File.read!(path)

    actual_sha256 =
      contents
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    unless actual_sha256 == expected_sha256 do
      raise "reference CSV digest mismatch for #{csv}: #{actual_sha256}"
    end

    ["unit_hex,unicode_hex" | rows] = String.split(contents, "\n", trim: true)

    unless length(rows) == 64 do
      raise "reference CSV must contain exactly 64 rows: #{csv}"
    end

    vector =
      rows
      |> Enum.with_index()
      |> Enum.map(fn {row, expected_unit} ->
        [unit_hex, unicode_hex] = String.split(row, ",", parts: 2)
        unit = String.to_integer(unit_hex, 16)

        unless unit == expected_unit do
          raise "reference CSV unit order mismatch in #{csv}: #{unit} != #{expected_unit}"
        end

        String.to_integer(unicode_hex, 16)
      end)

    decode_table = vector |> Enum.with_index() |> Map.new(fn {cp, unit} -> {unit, cp} end)
    encode_table = vector |> Enum.with_index() |> Map.new()
    {decode_table, encode_table}
  end

  defp reference_decode(units, decode_table) do
    output =
      units
      |> :binary.bin_to_list()
      |> Enum.map(&Map.fetch!(decode_table, &1))
      |> List.to_string()

    {:ok, output}
  end

  defp reference_encode(text, encode_table) do
    output =
      text
      |> :unicode.characters_to_list(:utf8)
      |> Enum.map(&Map.fetch!(encode_table, &1))
      |> :erlang.list_to_binary()

    {:ok, output}
  end

  defp reference_pack_lsb_from_utf8(text, encode_table) do
    with {:ok, units} <- reference_encode(text, encode_table) do
      reference_pack_lsb(units, @unit_bits)
    end
  end

  defp reference_unpack_lsb_to_utf8(%LSB{} = packed, decode_table) do
    with {:ok, units} <- reference_unpack_lsb(packed.data, packed.bit_size, @unit_bits) do
      reference_decode(units, decode_table)
    end
  end

  defp reference_pack_msb_from_utf8(text, encode_table) do
    with {:ok, units} <- reference_encode(text, encode_table) do
      reference_pack_msb(units, @unit_bits)
    end
  end

  defp reference_unpack_msb_to_utf8(packed, decode_table) do
    with {:ok, units} <- reference_unpack_msb(packed, @unit_bits) do
      reference_decode(units, decode_table)
    end
  end

  defp reference_pack_msb(units, width),
    do: reference_pack_msb_units(units, width, (1 <<< width) - 1, 0, [])

  defp reference_pack_msb_units(<<>>, _width, _mask, _offset, acc),
    do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_bitstring()}

  defp reference_pack_msb_units(<<unit, rest::binary>>, width, mask, offset, acc)
       when unit <= mask,
       do:
         reference_pack_msb_units(
           rest,
           width,
           mask,
           offset + 1,
           [<<unit::size(width)>> | acc]
         )

  defp reference_pack_msb_units(<<unit, _rest::binary>>, _width, _mask, offset, _acc),
    do: {:error, :unit_out_of_range, offset, unit}

  defp reference_unpack_msb(input, width),
    do: reference_unpack_msb_units(input, width, 0, [])

  defp reference_unpack_msb_units(<<>>, _width, _offset, acc),
    do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_binary()}

  defp reference_unpack_msb_units(input, width, offset, _acc) when bit_size(input) < width,
    do: {:error, :incomplete_unit, offset, input}

  defp reference_unpack_msb_units(input, width, offset, acc) do
    <<unit::size(width), rest::bitstring>> = input
    reference_unpack_msb_units(rest, width, offset + width, [unit | acc])
  end

  defp reference_pack_lsb(units, width) do
    with {:ok, data} <-
           reference_pack_lsb_units(units, width, (1 <<< width) - 1, 0, 0, 0, []) do
      {:ok, %LSB{data: data, bit_size: byte_size(units) * width, unit_bits: width}}
    end
  end

  defp reference_pack_lsb_units(<<>>, _width, _mask, buffer, bits, _offset, acc) do
    acc = if bits == 0, do: acc, else: [buffer &&& 0xFF | acc]
    {:ok, acc |> :lists.reverse() |> :erlang.list_to_binary()}
  end

  defp reference_pack_lsb_units(<<unit, rest::binary>>, width, mask, buffer, bits, offset, acc)
       when unit <= mask do
    {buffer, bits, acc} = reference_emit_lsb(buffer ||| unit <<< bits, bits + width, acc)
    reference_pack_lsb_units(rest, width, mask, buffer, bits, offset + 1, acc)
  end

  defp reference_pack_lsb_units(
         <<unit, _rest::binary>>,
         _width,
         _mask,
         _buffer,
         _bits,
         offset,
         _acc
       ),
       do: {:error, :unit_out_of_range, offset, unit}

  defp reference_emit_lsb(buffer, bits, acc) when bits >= 8,
    do: reference_emit_lsb(buffer >>> 8, bits - 8, [buffer &&& 0xFF | acc])

  defp reference_emit_lsb(buffer, bits, acc), do: {buffer, bits, acc}

  defp reference_unpack_lsb(data, bit_size, width) do
    cond do
      byte_size(data) != div(bit_size + 7, 8) ->
        {:error, :invalid_bit_size}

      rem(bit_size, width) != 0 ->
        complete = bit_size - rem(bit_size, width)
        {:error, :incomplete_unit, complete, bit_size - complete}

      reference_nonzero_padding?(data, bit_size) ->
        {:error, :nonzero_padding_bits}

      true ->
        reference_unpack_lsb_units(
          data,
          width,
          (1 <<< width) - 1,
          div(bit_size, width),
          0,
          0,
          []
        )
    end
  end

  defp reference_unpack_lsb_units(
         _data,
         _width,
         _mask,
         0,
         _buffer,
         _bits,
         acc
       ),
       do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_binary()}

  defp reference_unpack_lsb_units(data, width, mask, remaining, buffer, bits, acc)
       when bits >= width,
       do:
         reference_unpack_lsb_units(
           data,
           width,
           mask,
           remaining - 1,
           buffer >>> width,
           bits - width,
           [buffer &&& mask | acc]
         )

  defp reference_unpack_lsb_units(
         <<byte, rest::binary>>,
         width,
         mask,
         remaining,
         buffer,
         bits,
         acc
       ),
       do:
         reference_unpack_lsb_units(
           rest,
           width,
           mask,
           remaining,
           buffer ||| byte <<< bits,
           bits + 8,
           acc
         )

  defp reference_nonzero_padding?(<<>>, 0), do: false

  defp reference_nonzero_padding?(data, bit_size) do
    case rem(bit_size, 8) do
      0 -> false
      used -> :binary.last(data) >>> used != 0
    end
  end

  defp measure(function) do
    Enum.each(1..@warmups, fn _ -> assert_ok!(function.()) end)

    for _ <- 1..@iterations do
      :erlang.garbage_collect()
      {microseconds, result} = :timer.tc(function)
      assert_ok!(result)
      microseconds
    end
    |> Enum.sort()
    |> Enum.at(div(@iterations, 2))
  end

  defp reduction_gate(label, operation, small_function, large_function) do
    small = reductions(small_function)
    large = reductions(large_function)
    ratio = large / max(small, 1)
    {minimum, maximum} = @reduction_bounds

    unless ratio >= minimum and ratio <= maximum do
      raise "#{label} #{operation} reduction scaling #{ratio} outside #{minimum}..#{maximum}"
    end

    IO.puts("gate\t#{label}\t#{operation}\treduction_scaling\t#{Float.round(ratio, 3)}")
  end

  defp reductions(function) do
    parent = self()
    token = make_ref()

    {pid, monitor} =
      :erlang.spawn_opt(
        fn ->
          :erlang.garbage_collect()
          {:reductions, before_count} = Process.info(self(), :reductions)
          result = function.()
          {:reductions, after_count} = Process.info(self(), :reductions)
          assert_ok!(result)
          send(parent, {token, self(), after_count - before_count})
        end,
        [:monitor, {:min_heap_size, @reduction_heap_words}]
      )

    receive do
      {^token, ^pid, count} ->
        Process.demonitor(monitor, [:flush])
        count

      {:DOWN, ^monitor, :process, ^pid, reason} ->
        raise "benchmark reduction worker failed: #{inspect(reason)}"
    after
      30_000 ->
        Process.exit(pid, :kill)
        raise "benchmark reduction worker timed out"
    end
  end

  defp result(codec, operation, bytes, microseconds, relative) do
    mib_per_second = bytes / max(microseconds, 1) * 1_000_000 / 1_048_576
    relative_text = if relative, do: "#{Float.round(relative, 3)}x", else: "n/a"

    IO.puts(
      "bench\t#{codec.canonical_name()}\t#{operation}\t" <>
        "#{Float.round(mib_per_second, 3)} MiB/s\tmedian_us=#{microseconds}\t" <>
        "relative=#{relative_text}"
    )
  end

  defp assert_relative!(label, operation, relative) do
    if relative > @relative_ceiling do
      raise "#{label} #{operation} is #{relative}x reference, above #{@relative_ceiling}x"
    end
  end

  defp assert_ok!({:ok, _value}), do: :ok
  defp assert_ok!(other), do: raise("benchmark operation failed: #{inspect(other)}")

  defp assert_ok_value!({:ok, value}), do: value
  defp assert_ok_value!(other), do: raise("benchmark operation failed: #{inspect(other)}")

  defp repeat_to_size(alphabet, size) do
    copies = div(size + byte_size(alphabet) - 1, byte_size(alphabet))
    alphabet |> :binary.copy(copies) |> binary_part(0, size)
  end
end

Iconvex.Telecom.IBMSixBitTranscodeBenchmark.run()

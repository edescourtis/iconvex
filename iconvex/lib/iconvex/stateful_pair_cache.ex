defmodule Iconvex.StatefulPairCache do
  @moduledoc false

  @size 94 * 94
  @schema 1

  def seven_bit(id, source) when is_atom(id) and is_map(source) do
    fetch({:seven_bit, id}, source, fn -> build_seven_bit(source) end)
  end

  def seven_bit(id, source, identity)
      when is_atom(id) and is_map(source) and is_reference(identity) do
    fetch({:seven_bit, id}, identity, fn -> build_seven_bit(source) end)
  end

  def euc_tw_planes(source) when is_map(source) do
    fetch(:euc_tw_planes, source, fn -> build_euc_tw_planes(source) end)
  end

  def euc_tw_planes(source, identity) when is_map(source) and is_reference(identity) do
    fetch(:euc_tw_planes, identity, fn -> build_euc_tw_planes(source) end)
  end

  def euc_jisx0213_planes(source) when is_map(source) do
    fetch(:euc_jisx0213_planes, source, fn -> build_euc_jisx0213_planes(source) end)
  end

  def euc_jisx0213_planes(source, identity)
      when is_map(source) and is_reference(identity) do
    fetch(:euc_jisx0213_planes, identity, fn -> build_euc_jisx0213_planes(source) end)
  end

  def lookup(dense, first, second, endian)
      when is_tuple(dense) and tuple_size(dense) == @size and first in 0x21..0x7E and
             second in 0x21..0x7E and
             endian in [:big, :little] do
    case elem(dense, (first - 0x21) * 94 + second - 0x21) do
      {big, little} when is_binary(big) and is_binary(little) ->
        if endian == :big, do: {:ok, big}, else: {:ok, little}

      _missing_or_malformed ->
        :error
    end
  end

  def lookup(_dense, _first, _second, _endian), do: :error

  def lookup_endians(dense, first, second)
      when is_tuple(dense) and tuple_size(dense) == @size and first in 0x21..0x7E and
             second in 0x21..0x7E do
    case elem(dense, (first - 0x21) * 94 + second - 0x21) do
      {big, little} = endians when is_binary(big) and is_binary(little) -> {:ok, endians}
      _missing_or_malformed -> :error
    end
  end

  def lookup_endians(_dense, _first, _second), do: :error

  defp fetch(id, generation, builder) do
    key = {__MODULE__, id, @schema}
    integrity_key = integrity_key(id)

    case cached_descriptor(key, integrity_key, id, generation) do
      {:ok, dense} ->
        dense

      :stale ->
        :global.trans({{__MODULE__, id, @schema}, self()}, fn ->
          case cached_descriptor(key, integrity_key, id, generation) do
            {:ok, dense} ->
              dense

            :stale ->
              dense = builder.()
              witness = make_ref()
              :persistent_term.put(integrity_key, {@schema, id, generation, witness})
              :persistent_term.put(key, {@schema, id, generation, dense, witness})
              dense
          end
        end)
    end
  end

  defp cached_descriptor(key, integrity_key, id, generation) do
    case :persistent_term.get(key, :missing) do
      {@schema, ^id, ^generation, dense, witness} when is_reference(witness) ->
        case :persistent_term.get(integrity_key, :missing) do
          {@schema, ^id, ^generation, ^witness} ->
            if valid_descriptor?(id, dense), do: {:ok, dense}, else: :stale

          _missing_or_mismatched_integrity_witness ->
            :stale
        end

      _legacy_missing_or_stale ->
        :stale
    end
  end

  defp integrity_key(id), do: {__MODULE__, :integrity, id, @schema}

  defp valid_descriptor?({:seven_bit, _id}, dense),
    do: is_tuple(dense) and tuple_size(dense) == @size

  defp valid_descriptor?(:euc_tw_planes, planes),
    do: valid_planes?(planes, 7)

  defp valid_descriptor?(:euc_jisx0213_planes, planes),
    do: valid_planes?(planes, 2)

  defp valid_descriptor?(_id, _dense), do: false

  defp valid_planes?(planes, count) when is_tuple(planes) and tuple_size(planes) == count do
    0..(count - 1)
    |> Enum.all?(fn index ->
      plane = elem(planes, index)
      is_tuple(plane) and tuple_size(plane) == @size
    end)
  end

  defp valid_planes?(_planes, _count), do: false

  defp build_seven_bit(source) do
    source
    |> Enum.reduce(empty(), fn
      {<<first, second>>, codepoints}, dense
      when first in 0x21..0x7E and second in 0x21..0x7E ->
        :array.set(index(first, second, 0x21), encoded_endians(codepoints), dense)

      _other, dense ->
        dense
    end)
    |> freeze()
  end

  defp build_euc_tw_planes(source) do
    planes = List.to_tuple(for _plane <- 1..7, do: empty())

    source
    |> Enum.reduce(planes, fn
      {<<first, second>>, codepoints}, planes
      when first in 0xA1..0xFE and second in 0xA1..0xFE ->
        put_plane(planes, 1, first, second, codepoints)

      {<<0x8E, plane_byte, first, second>>, codepoints}, planes
      when plane_byte in 0xA2..0xA7 and first in 0xA1..0xFE and second in 0xA1..0xFE ->
        put_plane(planes, plane_byte - 0xA0, first, second, codepoints)

      _other, planes ->
        planes
    end)
    |> Tuple.to_list()
    |> Enum.map(&freeze/1)
    |> List.to_tuple()
  end

  defp build_euc_jisx0213_planes(source) do
    empty = empty()

    {plane1, plane2} =
      Enum.reduce(source, {empty, empty}, fn
        {<<first, second>>, codepoints}, {plane1, plane2}
        when first in 0xA1..0xFE and second in 0xA1..0xFE ->
          index = index(first, second, 0xA1)
          {:array.set(index, encoded_endians(codepoints), plane1), plane2}

        {<<0x8F, first, second>>, codepoints}, {plane1, plane2}
        when first in 0xA1..0xFE and second in 0xA1..0xFE ->
          index = index(first, second, 0xA1)
          {plane1, :array.set(index, encoded_endians(codepoints), plane2)}

        _other, planes ->
          planes
      end)

    {freeze(plane1), freeze(plane2)}
  end

  defp put_plane(planes, plane, first, second, codepoints) do
    dense = elem(planes, plane - 1)
    dense = :array.set(index(first, second, 0xA1), encoded_endians(codepoints), dense)
    put_elem(planes, plane - 1, dense)
  end

  defp empty, do: :array.new(@size, default: nil, fixed: true)
  defp freeze(array), do: array |> :array.to_list() |> List.to_tuple()
  defp index(first, second, base), do: (first - base) * 94 + second - base

  defp encoded_endians(codepoints),
    do: {encode_tuple(codepoints, :big), encode_tuple(codepoints, :little)}

  defp encode_tuple(tuple, endian),
    do: tuple |> Tuple.to_list() |> Enum.map(&word(&1, endian)) |> IO.iodata_to_binary()

  defp word(codepoint, :big), do: <<codepoint::unsigned-big-32>>
  defp word(codepoint, :little), do: <<codepoint::unsigned-little-32>>
end

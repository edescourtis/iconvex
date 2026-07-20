defmodule Iconvex.Telecom.Packed do
  @moduledoc """
  Packed bitstream facade for every fixed non-octet-width telecom codec.

  Both explicit `:msb` and `:lsb` orders are available. The default uses the
  standard transmission order associated with the codec family.
  """

  alias Iconvex.Packed.LSB

  @five_bit [
    Iconvex.Telecom.ITA1,
    Iconvex.Telecom.ITA2,
    Iconvex.Telecom.ITA2S2,
    Iconvex.Telecom.ITA2USTTY,
    Iconvex.Telecom.MTK2
  ]

  @six_bit [
    Iconvex.Telecom.AIS6,
    Iconvex.Telecom.ITA4,
    Iconvex.Telecom.IBM2780SixBitTranscode,
    Iconvex.Telecom.IBMBscSixBitTranscode
  ]
  @seven_bit [Iconvex.Telecom.ITA3, Iconvex.Telecom.IA5, Iconvex.Telecom.CCIR476]
  @cache_key {__MODULE__, :profile_cache}

  def profiles do
    cache().profiles
  end

  def profile(name) when is_binary(name) do
    {metadata, _named_order} = resolve_profile(name)
    metadata
  end

  def profile(module) when is_atom(module), do: Map.get(cache().by_module, module)

  defp cache do
    case :persistent_term.get(@cache_key, nil) do
      nil -> build_cache()
      cache -> cache
    end
  end

  defp build_cache do
    gsm =
      Enum.map(Iconvex.Telecom.Codecs.specs(), fn spec ->
        profile(spec.module, 7, :lsb)
      end)

    fixed =
      Enum.map(@five_bit, &profile(&1, 5, :lsb)) ++
        Enum.map(@six_bit, &profile(&1, 6, standard_order(&1))) ++
        Enum.map(@seven_bit, &profile(&1, 7, standard_order(&1)))

    profiles = Enum.sort_by(gsm ++ fixed, & &1.canonical)

    by_name =
      Map.new(profiles, &{String.upcase(&1.canonical, :ascii), &1})
      |> then(fn initial ->
        Enum.reduce(profiles, initial, fn metadata, acc ->
          Enum.reduce(metadata.codec.aliases(), acc, fn name, names ->
            Map.put(names, String.upcase(name, :ascii), metadata)
          end)
        end)
      end)

    cache = %{
      profiles: profiles,
      by_name: by_name,
      by_module: Map.new(profiles, &{&1.codec, &1})
    }

    :persistent_term.put(@cache_key, cache)
    cache
  end

  def encode_from_utf8(input, encoding, order \\ :standard) do
    with {%{unit_bits: width} = metadata, named_order} <- resolve_profile(encoding),
         {:ok, actual_order} <- order(order, metadata, named_order),
         {:ok, units} <- Iconvex.convert(input, "UTF-8", metadata.canonical) do
      pack(units, width, actual_order)
    else
      {nil, _named_order} -> {:error, :unsupported_packed_encoding}
      error -> error
    end
  end

  def decode_to_utf8(input, encoding, order \\ :standard) do
    with {%{unit_bits: width} = metadata, named_order} <- resolve_profile(encoding),
         {:ok, actual_order} <- order(order, metadata, named_order),
         {:ok, units} <- unpack(input, width, actual_order),
         {:ok, utf8} <-
           packed_decode_result(
             Iconvex.convert(units, metadata.canonical, "UTF-8"),
             width,
             actual_order
           ) do
      {:ok, utf8}
    else
      {nil, _named_order} -> {:error, :unsupported_packed_encoding}
      error -> error
    end
  end

  defp packed_decode_result(
         {:error,
          %Iconvex.Error{
            kind: :invalid_sequence,
            offset: unit_offset,
            sequence: <<unit>>
          }},
         width,
         :msb
       )
       when is_integer(unit_offset),
       do: {:error, :invalid_sequence, unit_offset * width, <<unit::size(width)>>}

  defp packed_decode_result(
         {:error,
          %Iconvex.Error{
            kind: :invalid_sequence,
            offset: unit_offset,
            sequence: <<unit>>
          }},
         width,
         :lsb
       )
       when is_integer(unit_offset),
       do: {:error, :invalid_sequence, unit_offset * width, unit}

  defp packed_decode_result(result, _width, _order), do: result

  defp profile(codec, unit_bits, standard_order) do
    %{
      canonical: codec.canonical_name(),
      codec: codec,
      standard_order: standard_order,
      unit_bits: unit_bits
    }
  end

  defp standard_order(Iconvex.Telecom.AIS6), do: :msb
  defp standard_order(Iconvex.Telecom.IA5), do: :msb
  defp standard_order(_codec), do: :lsb

  defp order(:standard, metadata, nil), do: {:ok, metadata.standard_order}
  defp order(:standard, _metadata, named_order), do: {:ok, named_order}
  defp order(order, _metadata, nil) when order in [:msb, :lsb], do: {:ok, order}
  defp order(order, _metadata, order) when order in [:msb, :lsb], do: {:ok, order}

  defp order(order, _metadata, named_order)
       when order in [:msb, :lsb] and named_order in [:msb, :lsb],
       do: {:error, :bit_order_mismatch}

  defp order(order, _metadata, _named_order), do: {:error, {:invalid_order, order}}

  defp pack(units, width, :msb), do: Iconvex.Packed.pack(units, width)
  defp pack(units, width, :lsb), do: Iconvex.Packed.pack_lsb(units, width)

  defp unpack(input, width, :msb) when is_bitstring(input),
    do: Iconvex.Packed.unpack(input, width)

  defp unpack(%LSB{bit_order: bit_order}, _width, :lsb) when bit_order != :lsb,
    do: {:error, :bit_order_mismatch}

  defp unpack(%LSB{unit_bits: width} = input, width, :lsb),
    do: Iconvex.Packed.unpack_lsb(input.data, input.bit_size, width)

  defp unpack(%LSB{}, _width, :lsb), do: {:error, :unit_width_mismatch}
  defp unpack(_input, _width, _order), do: {:error, :invalid_packed_transport}

  defp resolve_profile(name) when is_binary(name) do
    {normalized, named_order} = packed_name(name)
    {Map.get(cache().by_name, normalized), named_order}
  end

  defp resolve_profile(module) when is_atom(module), do: {profile(module), nil}

  defp packed_name(name) do
    normalized = String.upcase(name, :ascii)

    cond do
      String.ends_with?(normalized, "-PACKED-MSB") ->
        {strip_packed_suffix(normalized, "-PACKED-MSB"), :msb}

      String.ends_with?(normalized, "-PACKED-LSB") ->
        {strip_packed_suffix(normalized, "-PACKED-LSB"), :lsb}

      true ->
        {normalized, nil}
    end
  end

  defp strip_packed_suffix(normalized, suffix) do
    binary_part(normalized, 0, byte_size(normalized) - byte_size(suffix))
  end
end

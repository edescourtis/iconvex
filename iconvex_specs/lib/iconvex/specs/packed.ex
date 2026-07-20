defmodule Iconvex.Specs.Packed do
  @moduledoc """
  Explicit packed transports for fixed-width non-octet historical codecs.

  The registry codecs use one unit per octet, while this facade packs the
  lower `unit_bits` bits contiguously in either MSB- or LSB-first order.
  """

  alias Iconvex.Packed.LSB

  @profiles [
    %{
      canonical: "CDC-6-12-DISPLAY-CODE-63",
      codec: Iconvex.Specs.CDC612DisplayCode63,
      standard_order: :msb,
      unit_bits: 6
    },
    %{
      canonical: "CDC-6-12-DISPLAY-CODE-64",
      codec: Iconvex.Specs.CDC612DisplayCode64,
      standard_order: :msb,
      unit_bits: 6
    },
    %{
      canonical: "CDC-DISPLAY-CODE-63",
      codec: Iconvex.Specs.CDCDisplayCode63,
      standard_order: :msb,
      unit_bits: 6
    },
    %{
      canonical: "CDC-DISPLAY-CODE-64",
      codec: Iconvex.Specs.CDCDisplayCode64,
      standard_order: :msb,
      unit_bits: 6
    },
    %{
      canonical: "CDC-DISPLAY-CODE-ASCII-63",
      codec: Iconvex.Specs.CDCDisplayCodeASCII63,
      standard_order: :msb,
      unit_bits: 6
    },
    %{
      canonical: "CDC-DISPLAY-CODE-ASCII-64",
      codec: Iconvex.Specs.CDCDisplayCodeASCII64,
      standard_order: :msb,
      unit_bits: 6
    },
    %{
      canonical: "DEC-SPECIAL",
      codec: Iconvex.Specs.DECSpecial,
      standard_order: :msb,
      unit_bits: 7
    },
    %{
      canonical: "DEC-TECHNICAL",
      codec: Iconvex.Specs.DECTechnical,
      standard_order: :msb,
      unit_bits: 7
    },
    %{
      canonical: "SI-960",
      codec: Iconvex.Specs.SI960,
      standard_order: :msb,
      unit_bits: 7
    },
    %{
      canonical: "SHORT-KOI",
      codec: Iconvex.Specs.ShortKOI,
      standard_order: :msb,
      unit_bits: 7
    },
    %{
      canonical: "greek7",
      codec: Iconvex.Specs.RFC1345.Codecs.C040,
      standard_order: :msb,
      unit_bits: 7
    },
    %{
      canonical: "KERMIT-ELOT927-GREEK",
      codec: Iconvex.Specs.KermitELOT927Greek,
      standard_order: :msb,
      unit_bits: 7
    },
    %{
      canonical: "DEC-NRC-UNITED-KINGDOM",
      codec: Iconvex.Specs.DECNRCUnitedKingdom,
      standard_order: :msb,
      unit_bits: 7
    },
    %{
      canonical: "DEC-NRC-DUTCH",
      codec: Iconvex.Specs.DECNRCDutch,
      standard_order: :msb,
      unit_bits: 7
    },
    %{
      canonical: "DEC-NRC-FINNISH",
      codec: Iconvex.Specs.DECNRCFinnish,
      standard_order: :msb,
      unit_bits: 7
    },
    %{
      canonical: "DEC-NRC-FRENCH",
      codec: Iconvex.Specs.DECNRCFrench,
      standard_order: :msb,
      unit_bits: 7
    },
    %{
      canonical: "DEC-NRC-FRENCH-CANADIAN",
      codec: Iconvex.Specs.DECNRCFrenchCanadian,
      standard_order: :msb,
      unit_bits: 7
    },
    %{
      canonical: "DEC-NRC-GERMAN",
      codec: Iconvex.Specs.DECNRCGerman,
      standard_order: :msb,
      unit_bits: 7
    },
    %{
      canonical: "DEC-NRC-ITALIAN",
      codec: Iconvex.Specs.DECNRCItalian,
      standard_order: :msb,
      unit_bits: 7
    },
    %{
      canonical: "DEC-NRC-NORWEGIAN-DANISH",
      codec: Iconvex.Specs.DECNRCNorwegianDanish,
      standard_order: :msb,
      unit_bits: 7
    },
    %{
      canonical: "DEC-NRC-PORTUGUESE",
      codec: Iconvex.Specs.DECNRCPortuguese,
      standard_order: :msb,
      unit_bits: 7
    },
    %{
      canonical: "DEC-NRC-SPANISH",
      codec: Iconvex.Specs.DECNRCSpanish,
      standard_order: :msb,
      unit_bits: 7
    },
    %{
      canonical: "DEC-NRC-SWEDISH",
      codec: Iconvex.Specs.DECNRCSwedish,
      standard_order: :msb,
      unit_bits: 7
    },
    %{
      canonical: "DEC-NRC-SWISS",
      codec: Iconvex.Specs.DECNRCSwiss,
      standard_order: :msb,
      unit_bits: 7
    },
    %{
      canonical: "DEC-SIXBIT",
      codec: Iconvex.Specs.DECSIXBIT,
      standard_order: :msb,
      unit_bits: 6
    },
    %{
      canonical: "ECMA-1",
      codec: Iconvex.Specs.ECMA1,
      standard_order: :msb,
      unit_bits: 6
    },
    %{
      canonical: "TEX-LIVE-OML-CMMI10-TOUNICODE-2026",
      codec: Iconvex.Specs.TeXLiveOMLCMMI10ToUnicode2026,
      standard_order: :msb,
      unit_bits: 7,
      nonstandard_orders: [:lsb]
    },
    %{
      canonical: "TEX-LIVE-OMS-CMSY10-TOUNICODE-2026",
      codec: Iconvex.Specs.TeXLiveOMSCMSY10ToUnicode2026,
      standard_order: :msb,
      unit_bits: 7,
      nonstandard_orders: [:lsb]
    },
    %{
      canonical: "PDP-1-CONCISE-1960-INITIAL-LOWER",
      codec: Iconvex.Specs.PDP1Concise1960InitialLower,
      standard_order: :msb,
      unit_bits: 6,
      nonstandard_orders: [:lsb]
    },
    %{
      canonical: "PDP-1-CONCISE-1960-INITIAL-UPPER",
      codec: Iconvex.Specs.PDP1Concise1960InitialUpper,
      standard_order: :msb,
      unit_bits: 6,
      nonstandard_orders: [:lsb]
    },
    %{
      canonical: "PDP-1-CONCISE-FIODEC-1963-INITIAL-LOWER",
      codec: Iconvex.Specs.PDP1ConciseFIODEC1963InitialLower,
      standard_order: :msb,
      unit_bits: 6,
      nonstandard_orders: [:lsb]
    },
    %{
      canonical: "PDP-1-CONCISE-FIODEC-1963-INITIAL-UPPER",
      codec: Iconvex.Specs.PDP1ConciseFIODEC1963InitialUpper,
      standard_order: :msb,
      unit_bits: 6,
      nonstandard_orders: [:lsb]
    },
    %{
      canonical: "UNIVAC-I-EXPANDED-1959",
      codec: Iconvex.Specs.UNIVACIExpanded1959,
      standard_order: :msb,
      unit_bits: 6,
      nonstandard_orders: [:lsb]
    },
    %{
      canonical: "UNIVAC-I-EXPANDED-1959-LOSSLESS-VPUA",
      codec: Iconvex.Specs.UNIVACIExpanded1959LosslessVPUA,
      standard_order: :msb,
      unit_bits: 6,
      nonstandard_orders: [:lsb]
    },
    %{
      canonical: "UNIVAC-I-EXPANDED-1959-RAW-VPUA",
      codec: Iconvex.Specs.UNIVACIExpanded1959RawVPUA,
      standard_order: :msb,
      unit_bits: 6,
      nonstandard_orders: [:lsb]
    },
    %{
      canonical: "UNIVAC-I-EXPANDED-1959-ODD-PARITY-7BIT",
      codec: Iconvex.Specs.UNIVACIExpanded1959OddParity7Bit,
      standard_order: :msb,
      unit_bits: 7,
      nonstandard_orders: [:lsb]
    },
    %{
      canonical: "FIELDATA-UNIVAC-1100",
      codec: Iconvex.Specs.FieldataUNIVAC1100,
      standard_order: :msb,
      unit_bits: 6,
      nonstandard_orders: [:lsb]
    },
    %{
      canonical: "FIELDATA-UNIVAC-4009-INPUT",
      codec: Iconvex.Specs.FieldataUNIVAC4009Input,
      standard_order: :msb,
      unit_bits: 6,
      nonstandard_orders: [:lsb]
    },
    %{
      canonical: "FIELDATA-UNIVAC-4009-OUTPUT",
      codec: Iconvex.Specs.FieldataUNIVAC4009Output,
      standard_order: :msb,
      unit_bits: 6,
      nonstandard_orders: [:lsb]
    },
    %{
      canonical: "FIELDATA-UNIVAC-4009-LOSSLESS-VPUA",
      codec: Iconvex.Specs.FieldataUNIVAC4009LosslessVPUA,
      standard_order: :msb,
      unit_bits: 6,
      nonstandard_orders: [:lsb]
    },
    %{
      canonical: "FIELDATA-UNIVAC-4009-RAW-VPUA",
      codec: Iconvex.Specs.FieldataUNIVAC4009RawVPUA,
      standard_order: :msb,
      unit_bits: 6,
      nonstandard_orders: [:lsb]
    }
  ]

  @wide_profile_base [
    %{
      canonical: "IBM-7040-H-REPORT",
      codec: Iconvex.Specs.IBM7040HReport,
      standard_order: :msb,
      unit_bits: 12,
      nonstandard_orders: [:lsb]
    },
    %{
      canonical: "IBM-7040-H-PROGRAM",
      codec: Iconvex.Specs.IBM7040HProgram,
      standard_order: :msb,
      unit_bits: 12,
      nonstandard_orders: [:lsb]
    },
    %{
      canonical: "IBM-1401-CARD",
      codec: Iconvex.Specs.IBM1401Card,
      standard_order: :msb,
      unit_bits: 12,
      nonstandard_orders: [:lsb]
    },
    %{
      canonical: "CDC-167-BCD-HOLLERITH-1965",
      codec: Iconvex.Specs.CDC167BCDHollerith1965,
      standard_order: :msb,
      unit_bits: 12,
      nonstandard_orders: [:lsb]
    },
    %{
      canonical: "CDC-6000-STANDARD-HOLLERITH-1970",
      codec: Iconvex.Specs.CDC6000StandardHollerith1970,
      standard_order: :msb,
      unit_bits: 12,
      nonstandard_orders: [:lsb]
    },
    %{
      canonical: "BCD-CDC-IOWA",
      codec: Iconvex.Specs.BCDCDCIowa,
      standard_order: :msb,
      unit_bits: 12,
      nonstandard_orders: [:lsb]
    },
    %{
      canonical: "IBM-029-CARD-IOWA-824E61A9",
      codec: Iconvex.Specs.IBM029CardIowa824E61A9,
      standard_order: :msb,
      unit_bits: 12,
      nonstandard_orders: [:lsb]
    },
    %{
      canonical: "DEC-026-CARD-IOWA-824E61A9",
      codec: Iconvex.Specs.DEC026CardIowa824E61A9,
      standard_order: :msb,
      unit_bits: 12,
      nonstandard_orders: [:lsb]
    },
    %{
      canonical: "DEC-029-CARD-IOWA-824E61A9",
      codec: Iconvex.Specs.DEC029CardIowa824E61A9,
      standard_order: :msb,
      unit_bits: 12,
      nonstandard_orders: [:lsb]
    },
    %{
      canonical: "EBCD-CARD-IOWA-824E61A9",
      codec: Iconvex.Specs.EBCDCardIowa824E61A9,
      standard_order: :msb,
      unit_bits: 12,
      nonstandard_orders: [:lsb]
    },
    %{
      canonical: "GE-600-CARD-IOWA-824E61A9",
      codec: Iconvex.Specs.GE600CardIowa824E61A9,
      standard_order: :msb,
      unit_bits: 12,
      nonstandard_orders: [:lsb]
    }
  ]

  @ibm_24_26_wide_profiles (for {canonical, codec} <- [
                                  {"IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-A",
                                   Iconvex.Specs.IBM2426ArrangementA},
                                  {"IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-B",
                                   Iconvex.Specs.IBM2426ArrangementB},
                                  {"IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-C",
                                   Iconvex.Specs.IBM2426ArrangementC},
                                  {"IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-D",
                                   Iconvex.Specs.IBM2426ArrangementD},
                                  {"IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-E",
                                   Iconvex.Specs.IBM2426ArrangementE},
                                  {"IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-F",
                                   Iconvex.Specs.IBM2426ArrangementF},
                                  {"IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-G",
                                   Iconvex.Specs.IBM2426ArrangementG},
                                  {"IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-H",
                                   Iconvex.Specs.IBM2426ArrangementH},
                                  {"IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-J",
                                   Iconvex.Specs.IBM2426ArrangementJ},
                                  {"IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-K",
                                   Iconvex.Specs.IBM2426ArrangementK}
                                ] do
                              %{
                                canonical: canonical,
                                codec: codec,
                                standard_order: :msb,
                                unit_bits: 12,
                                nonstandard_orders: [:lsb]
                              }
                            end)

  @wide_profiles @wide_profile_base ++ @ibm_24_26_wide_profiles

  def profiles, do: @profiles
  def wide_profiles, do: @wide_profiles
  def all_profiles, do: @profiles ++ @wide_profiles

  def profile(name) when is_binary(name) do
    {metadata, _named_order} = resolve_profile(name)
    metadata
  end

  def profile(module) when is_atom(module), do: Enum.find(all_profiles(), &(&1.codec == module))

  def encode_from_utf8(input, encoding, order \\ :standard) do
    with {%{} = metadata, named_order} <- resolve_profile(encoding),
         {:ok, actual_order} <- order(order, metadata, named_order) do
      encode_profile(input, metadata, actual_order)
    else
      {nil, _named_order} -> {:error, :unsupported_packed_encoding}
      error -> error
    end
  end

  def decode_to_utf8(input, encoding, order \\ :standard) do
    with {%{} = metadata, named_order} <- resolve_profile(encoding),
         {:ok, actual_order} <- order(order, metadata, named_order) do
      decode_profile(input, metadata, actual_order)
    else
      {nil, _named_order} -> {:error, :unsupported_packed_encoding}
      error -> error
    end
  end

  defp order(:standard, metadata, nil), do: {:ok, metadata.standard_order}
  defp order(:standard, _metadata, named_order), do: {:ok, named_order}
  defp order(order, _metadata, nil) when order in [:msb, :lsb], do: {:ok, order}
  defp order(order, _metadata, order) when order in [:msb, :lsb], do: {:ok, order}

  defp order(order, _metadata, named_order)
       when order in [:msb, :lsb] and named_order in [:msb, :lsb],
       do: {:error, :bit_order_mismatch}

  defp order(_order, _metadata, _named_order), do: {:error, :invalid_bit_order}

  defp encode_profile(input, %{unit_bits: 12, codec: codec}, order),
    do: codec.encode_packed_from_utf8(input, order)

  defp encode_profile(input, %{unit_bits: width} = metadata, order) do
    with {:ok, units} <- Iconvex.convert(input, "UTF-8", metadata.canonical) do
      pack(units, width, order)
    end
  end

  defp decode_profile(input, %{unit_bits: 12, codec: codec}, order),
    do: codec.decode_packed_to_utf8(input, order)

  defp decode_profile(input, %{unit_bits: width} = metadata, order) do
    with {:ok, units} <- unpack(input, width, order) do
      units
      |> Iconvex.convert(metadata.canonical, "UTF-8")
      |> packed_decode_result(width, order)
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

  defp direct_profile(normalized) do
    Enum.find(all_profiles(), fn profile ->
      Enum.any?([profile.canonical | profile.codec.aliases()], fn candidate ->
        String.upcase(candidate, :ascii) == normalized
      end)
    end)
  end

  defp resolve_profile(name) when is_binary(name) do
    {base_name, normalized, named_order} = packed_name(name)
    metadata = direct_profile(normalized) || registered_alias_profile(base_name, normalized)
    {metadata, named_order}
  end

  defp resolve_profile(module) when is_atom(module), do: {profile(module), nil}

  defp packed_name(name) do
    normalized = String.upcase(name, :ascii)

    cond do
      String.ends_with?(normalized, "-PACKED-MSB") ->
        strip_packed_suffix(name, normalized, "-PACKED-MSB", :msb)

      String.ends_with?(normalized, "-PACKED-LSB") ->
        strip_packed_suffix(name, normalized, "-PACKED-LSB", :lsb)

      true ->
        {name, normalized, nil}
    end
  end

  defp strip_packed_suffix(name, normalized, suffix, order) do
    base_size = byte_size(name) - byte_size(suffix)
    {binary_part(name, 0, base_size), binary_part(normalized, 0, base_size), order}
  end

  defp registered_alias_profile(name, normalized) do
    case Iconvex.canonical_name(name) do
      {:ok, canonical} ->
        canonical_normalized = String.upcase(canonical, :ascii)

        if canonical_normalized == normalized do
          nil
        else
          direct_profile(canonical_normalized)
        end

      :error ->
        nil
    end
  end
end
